#===============================================================================
# Online - Settings
# Multiplayer games (spec #141, ADR 0002). The game never talks to the network:
# the bridge (later the launcher) runs on the same PC and holds the room.
#===============================================================================
module Online
  # Room server and group key, read by the bridge too (online/bridge). The
  # values below are those of the local server (cd online/server, npm run
  # dev); a copy of the game given to friends gets the deployed server's
  # address and the group key instead.
  SERVER_URL = "http://127.0.0.1:8787"
  GROUP_KEY  = "test"
  # Port of the bridge's local service on this PC.
  BRIDGE_PORT = 47120
  BRIDGE_URL  = "http://127.0.0.1:#{BRIDGE_PORT}"
  # Seconds between two reads of the other players' events on the map.
  POLL_INTERVAL = 0.5
  # Seconds without asking the bridge after it did not answer.
  RETRY_AFTER = 10
end
