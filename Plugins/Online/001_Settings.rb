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
  # Seconds between two checks of this player's progress (sent when changed).
  STATUS_INTERVAL = 2
  # Seconds an announcement of another player stays on screen.
  NEWS_TIME = 3
  # Seconds before the host can remove a disconnected player (same as the
  # server's KICK_AFTER_MS), or a player cut off can leave the room.
  KICK_AFTER = 300
  # Seconds a challenge to a duel waits for the other player's answer.
  CHALLENGE_TIME = 30
end
