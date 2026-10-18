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

  # World file (in FOLDER) drawn with a new seed at each new game, nil = none.
  # The game only keeps it if it is saved: at the next start, the maps of a
  # game left without saving are deleted (or the saved world is drawn again).
  NEW_GAME_WORLD = "monde.txt"
  # Which world the maps on disk belong to ({ path:, seed: }), written when a
  # new game draws its world.
  GAME_WORLD_FILE = "Data/MapProcWorld.rxdata"

  # Excesses (« Demesure » in a world): now and then a place goes over the top.
  # kind: ville or route; boost: brick type => times its usual most (optional
  # bricks only, so the place always fits); giant_lake: lakes far bigger;
  # colossal: a mountain route with as many levels as fit (mountain routes
  # only); long: a route three times as long as « Longueur » allows; fill: after the
  # other bricks, that type again wherever it still fits; dense: those may
  # touch each other; flood: water all over the free ground, the streets kept
  # dry; carpet: that symbol all over the free ground (over_street: over the
  # streets too, not the exits); ambiance: that [Ambiance] of the place file
  # (its ground and streets), if the file has it.
  EXCESSES = {
    "forêt profonde"     => { kind: "route", boost: { "arbre" => 4 }, fill: "arbre", dense: true },
    "mer d'herbes"       => { kind: "route", boost: { "herbes" => 4, "prairie" => 3 }, fill: "herbes", dense: true, carpet: '"', over_street: true },
    "chaos rocheux"      => { kind: "route", boost: { "montagne" => 4, "corniche" => 3, "rocaille" => 2 }, fill: "montagne", dense: true },
    "lac géant"          => { kind: "route", boost: { "lac" => 1 }, giant_lake: true, flood: true },
    "montagne colossale" => { kind: "route", colossal: true, boost: { "rocaille" => 2 } },
    "route interminable" => { kind: "route", long: true },
    "ville-jardin"       => { kind: "ville", boost: { "parc" => 3, "arbre" => 3 }, fill: "arbre", carpet: "*", ambiance: "chemins de terre" },
    "cité lacustre"      => { kind: "ville", boost: { "lac" => 2 }, giant_lake: true, flood: true },
    "grande foire"       => { kind: "ville", boost: { "foire" => 4, "lampe" => 2 }, fill: "foire" }
  }.freeze

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

  # Islands reached by boat from a port town (« Iles » in a world): a map of
  # their own, built from the town file with the sea all around, and its own
  # ferry terminal. Size, and the bricks of each kind of island: a village or
  # a wild island (grass, trees, rocks).
  ISLAND_SIZE = [40, 36]
  ISLAND_KINDS = {
    "village" => { "centre" => 1..1, "boutique" => 0..1, "maison" => 2..4, "parc" => 1..2,
                   "lampe" => 2..4, "arbre" => 3..6, "foire" => 0..1 },
    "sauvage" => { "maison" => 0..1, "herbes" => 3..5, "arbre" => 6..12, "parc" => 1..2,
                   "lac" => 0..1, "montagne" => 0..1 }
  }.freeze
  # Ground of half the islands (an [Ambiance] of the town file)
  ISLAND_AMBIANCE = "sable"
  # Width of the sea around an island, on its sides without a port
  ISLAND_SHORE = 4..7
  # Sandbanks and rocks in the sea around an island
  ISLAND_BANKS = 1..3
  ISLAND_REEFS = 3..6
  # Island names: « Île » and a name, or a name alone, from these sections of
  # this file
  ISLAND_NAMES_FILE = "Lore/noms.txt"
  ISLAND_NAME_SECTIONS = %w[Italien Americain Francais].freeze
end
