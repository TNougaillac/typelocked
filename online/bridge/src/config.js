// Address of the room server, group key and local port. Read from the game's
// Online settings (Plugins/Online/001_Settings.rb), so the game and its
// bridge are set up in one place; config.json next to the bridge or the
// environment variables override them.
import { readFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const BRIDGE_DIR = join(dirname(fileURLToPath(import.meta.url)), "..");
export const DEFAULT_PORT = 47120;

// SERVER_URL, GROUP_KEY and BRIDGE_PORT of the plugin's settings file.
export function readPluginSettings(path) {
  let text = "";
  try {
    text = readFileSync(path, "utf8");
  } catch {
    return {};
  }
  const string = (name) => text.match(new RegExp(`^\\s*${name}\\s*=\\s*"([^"]*)"`, "m"))?.[1];
  const port = text.match(/^\s*BRIDGE_PORT\s*=\s*(\d+)/m)?.[1];
  return { server: string("SERVER_URL"), groupKey: string("GROUP_KEY"), port: port && Number(port) };
}

export function loadConfig(path = join(BRIDGE_DIR, "config.json"), env = process.env,
  pluginPath = join(BRIDGE_DIR, "..", "..", "Plugins", "Online", "001_Settings.rb")) {
  let file = {};
  try {
    file = JSON.parse(readFileSync(path, "utf8"));
  } catch {
    // No file: plugin settings and environment.
  }
  const plugin = readPluginSettings(pluginPath);
  const config = {
    server: (env.TYPELOCKED_SERVER || file.server || plugin.server || "").replace(/\/$/, ""),
    groupKey: env.TYPELOCKED_KEY || file.groupKey || plugin.groupKey || "",
    port: Number(env.TYPELOCKED_PORT || file.port || plugin.port || DEFAULT_PORT),
  };
  if (!config.server || !config.groupKey) throw new Error(`Configuration incomplète : SERVER_URL et GROUP_KEY dans ${pluginPath}.`);
  return config;
}
