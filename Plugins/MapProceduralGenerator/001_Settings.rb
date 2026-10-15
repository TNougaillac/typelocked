#===============================================================================
# MapProceduralGenerator - Settings
# Assembles places (towns for now) from hand-made bricks, differently for each
# seed. The result is a MapGen plan, written to a map by MapGenerator.
#===============================================================================
module MapProceduralGenerator
  # Folder (relative to the game folder) holding the place files (*.txt).
  FOLDER = "MapProc"

  # Subfolder of FOLDER holding the bricks (*.txt).
  BRICK_FOLDER = "Briques"

  # Subfolder of FOLDER where each generated place is also saved as a plain
  # MapGen plan, to be kept and retouched by hand.
  EXPORT_FOLDER = "Export"

  # Street width in tiles (exits, streets and paths to the doors).
  STREET_WIDTH = 2

  # A door is placed at most this many tiles away from an existing street.
  MAX_DOOR_DISTANCE = 6

  # Caves of a world: tileset of their maps (it needs a section in
  # PBS/dungeon_tilesets.txt) and its floor tile. Essentials draws a new random
  # layout each time the player walks in (map metadata Dungeon = true).
  CAVE_TILESET = 7
  CAVE_FLOOR = "T42"
  # Graphic of the cave exits (a ladder, as in the example dungeon map).
  CAVE_EXIT_TILE = 384 + 47
end
