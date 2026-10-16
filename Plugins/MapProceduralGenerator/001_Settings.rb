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
  # PBS/dungeon_tilesets.txt) and its floor tile. Essentials draws their layout
  # when the player walks in (map metadata Dungeon = true), always from the
  # same seed (see CAVE_SEEDS_FILE).
  CAVE_TILESET = 7
  CAVE_FLOOR = "T42"
  # Graphic of the cave exits (a ladder, as in the example dungeon map).
  CAVE_EXIT_TILE = 384 + 47
  # Seed of each cave's layout (map ID => seed), so that a cave stays the same
  # for a given world seed.
  CAVE_SEEDS_FILE = "Data/MapProcCaves.rxdata"

  # Seabeds of a world (under routes with deep water): tileset and palette.
  # « . » = floor, « s » = seaweed, « R » = rock (walls, edges drawn by MapGen).
  SEABED_TILESET = 22
  SEABED_PALETTE = <<~PALETTE
    [Legend]
    . = T0|T1|T2|T3|T8|T9
    s = T0 A4
    [Terrains]
    R = T44 N=T36 S=T52 W=T43 E=T45 NW=T35 NE=T37 SW=T51 SE=T53 iNW=T47 iNE=T46 iSW=T39 iSE=T38
  PALETTE
end
