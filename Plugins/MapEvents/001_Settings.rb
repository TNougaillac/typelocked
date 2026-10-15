#===============================================================================
# MapEvents - Settings
#===============================================================================
module MapEvents
  # Folder (relative to the game folder) holding the event plans (*.txt).
  FOLDER = "MapEvents"

  # Word added to the name of every event this plugin writes. Running a plan
  # again replaces the events of its map that carry it, and only those.
  TAG = "MapEvents"

  ENCOUNTERS_PBS   = "PBS/encounters.txt"
  MAP_METADATA_PBS = "PBS/map_metadata.txt"
end
