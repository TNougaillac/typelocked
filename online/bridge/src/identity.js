// The player's nickname and secret code, kept on this PC. The secret tells
// two players with the same nickname apart; it is never shown.
import { randomBytes } from "node:crypto";
import { mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { homedir } from "node:os";
import { join } from "node:path";

export function dataDir(env = process.env) {
  return env.APPDATA ? join(env.APPDATA, "TypeLocked", "online") : join(homedir(), ".typelocked", "online");
}

// The saved identity, with a new nickname if one is given. A first launch
// needs a nickname.
export function loadIdentity(dir, name) {
  const file = join(dir, "player.json");
  let identity = null;
  try {
    identity = JSON.parse(readFileSync(file, "utf8"));
  } catch {
    // First launch.
  }
  if (!identity && !name) throw new Error("Premier lancement : choisis un pseudo avec --name.");
  identity = { secret: identity?.secret || randomBytes(24).toString("hex"), name: name || identity.name };
  mkdirSync(dir, { recursive: true });
  writeFileSync(file, JSON.stringify(identity, null, 2));
  return identity;
}
