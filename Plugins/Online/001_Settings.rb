#===============================================================================
# Online - Settings
# Multiplayer games (spec #141, ADR 0002). The game never talks to the network:
# the bridge (later the launcher) runs on the same PC and holds the room.
#===============================================================================
module Online
  # Local service of the bridge (online/bridge, port 47120 by default).
  BRIDGE_URL = "http://127.0.0.1:47120"
  # Seconds between two reads of the other players' events on the map.
  POLL_INTERVAL = 0.5
  # Seconds without asking the bridge after it did not answer.
  RETRY_AFTER = 10
end
