// Address of the room server and group key: config.json next to the bridge
// (sent by the person who deployed the server), or environment variables.
import { readFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

export const DEFAULT_PORT = 47120;

export function loadConfig(path = join(dirname(fileURLToPath(import.meta.url)), "..", "config.json"), env = process.env) {
  let file = {};
  try {
    file = JSON.parse(readFileSync(path, "utf8"));
  } catch {
    // No file: environment only.
  }
  const config = {
    server: (env.TYPELOCKED_SERVER || file.server || "").replace(/\/$/, ""),
    groupKey: env.TYPELOCKED_KEY || file.groupKey || "",
    port: Number(env.TYPELOCKED_PORT || file.port || DEFAULT_PORT),
  };
  if (!config.server || !config.groupKey) throw new Error(`Configuration incomplète : adresse du serveur et clé de groupe (${path}).`);
  return config;
}
