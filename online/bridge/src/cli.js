#!/usr/bin/env node
// The bridge, until the launcher (#52) takes it over.
//   node online/bridge/src/cli.js create --name Tom [--nuzlocke required] [--type-draw required] [--same-type]
//   node online/bridge/src/cli.js join ABC234 [--name Léo]
// Then launch the game: a new game starts in the room once the host types "go".
import { writeFileSync } from "node:fs";
import { createInterface } from "node:readline";
import { parseArgs } from "node:util";
import { loadConfig } from "./config.js";
import { dataDir, loadIdentity } from "./identity.js";
import { startLocalServer } from "./local-server.js";
import { RoomClient } from "./room-client.js";

const USAGE = `Utilisation :
  create --name <pseudo> [--nuzlocke required|free] [--type-draw required|free] [--same-type]
  join <code> [--name <pseudo>]`;

async function main() {
  const { values, positionals } = parseArgs({
    allowPositionals: true,
    options: {
      name: { type: "string" },
      config: { type: "string" },
      nuzlocke: { type: "string", default: "free" },
      "type-draw": { type: "string", default: "free" },
      "same-type": { type: "boolean", default: false },
      "code-file": { type: "string" }, // writes the room code there (online/test-multi.bat)
    },
  });
  const [command, code] = positionals;
  if (!["create", "join"].includes(command) || (command === "join" && !code)) {
    console.log(USAGE);
    process.exit(1);
  }
  const config = loadConfig(values.config);
  const identity = loadIdentity(dataDir(), values.name);
  const client = new RoomClient({ ...config, ...identity }, { log: (type, msg) => show(client, type, msg) });
  const roomCode = command === "create"
    ? await client.createRoom({ nuzlocke: values.nuzlocke, typeDraw: values["type-draw"], sameType: values["same-type"] })
    : code.toUpperCase();
  if (values["code-file"]) writeFileSync(values["code-file"], roomCode);
  await startLocalServer(client, config.port);
  client.connect(roomCode);
  console.log(`Salon ${roomCode} (${identity.name}). Laisse cette fenêtre ouverte pendant la partie.`);
  const input = createInterface({ input: process.stdin });
  input.on("line", (line) => {
    if (line.trim().toLowerCase() === "go") client.start();
    if (line.trim().toLowerCase() === "quit") {
      client.close();
      process.exit(0);
    }
  });
}

function show(client, type, msg) {
  const room = client.room;
  switch (type) {
    case "presence": {
      const names = msg.players.map((p) => `${p.name}${p.host ? " (hôte)" : ""}${p.connected ? "" : " [absent]"}`);
      console.log(`Joueurs : ${names.join(", ")}`);
      if (!room.started && room.you === room.host && msg.allConnected) console.log("Tout le monde est là : tape « go » pour lancer la partie.");
      break;
    }
    case "start":
      console.log("La partie est lancée : démarre une nouvelle partie dans le jeu.");
      break;
    case "error":
      console.log(`Refusé par le serveur : ${msg.error}`);
      break;
    case "connection_lost":
      console.log(`Connexion perdue, nouvel essai dans ${msg / 1000} s…`);
      break;
  }
}

main().catch((error) => {
  console.error(error.message);
  process.exit(1);
});
