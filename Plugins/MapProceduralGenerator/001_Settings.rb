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

  # Natural border: past its first row of trees, the border of a place of that
  # kind (« Lieu ») grows inwards by that many more rows of trees, changing by
  # one row every BORDER_STRETCH trees along each side, at most BORDER_SHARE
  # of the map across. BORDER_SALT: its own draws, apart from the place's.
  BORDER_DEPTH = { "ville" => 0..1, "route" => 0..2 }.freeze
  BORDER_STRETCH = 2..5
  BORDER_SHARE = 0.2
  BORDER_SALT = 0x5B0D

  # Paved square of a town around its hub (tiles across, tiles down), the
  # fountain object of ville.txt in the middle, only in towns at least
  # min_side tiles across both ways (not in villages). PLAZA_SALT: its own
  # draws.
  PLAZA = { width: 9..12, height: 8..10, fountain: "f", min_side: 30 }.freeze
  PLAZA_KIND = "fontaine"
  PLAZA_SALT = 0x91A2A

  # The avenue of a town (the streets of its first two exits) is one tile
  # wider than STREET_WIDTH, except within AVENUE_MARGIN tiles of the edges.
  AVENUE_MARGIN = 6

  # The streets of a plain route wind: one tile sideways every few steps
  # (every), at most sway tiles off the straight line. TRAIL_SALT: its own
  # draws.
  TRAIL = { every: 3..6, sway: 4 }.freeze
  TRAIL_SALT = 0x7EA11

  # A building goes at most that many tiles further from its street than the
  # closest spot found, by kind of place (2 for the others): towns line their
  # buildings along the streets.
  DOOR_SLACK = { "ville" => 0 }.freeze

  # A door is placed at most this many tiles away from an existing street.
  MAX_DOOR_DISTANCE = 6

  # Mountain routes: boundaries between levels (2 bands one level apart) on a
  # north-south route and on an east-west one, at least FACE_GAP rows apart
  # (BAND_MIN once wandering);
  # chance that the next band climbs rather than goes down; how far a
  # boundary wanders up and down (rows); tall grass patches on the raised
  # levels per 20x20 tiles of them. A band keeps BAND_MIN rows at least.
  MOUNTAIN_FACES = { vertical: 5..8, across: 2..3 }.freeze
  FACE_GAP = 5
  BAND_MIN = 3
  MOUNTAIN_CLIMB = 0.7
  FACE_WAVE = 2
  MOUNTAIN_GRASS = 1..3
  # Hills (« colline » in [Briques]): drawn for the spot like the lakes, a
  # stair on their south face. In a town, only that often (%) when drawn.
  HILL_TOWN_CHANCE = 20

  # Caves of a world (2 floors each, see 006_Caves.rb): tileset of their maps
  # (it needs a section in PBS/dungeon_tilesets.txt, and its dungeon
  # parameters CAVE_AREA in PBS/dungeon_parameters.txt for the decorations),
  # its floor and rock tiles.
  CAVE_TILESET = 7
  CAVE_AREA = :cave
  CAVE_FLOOR = "T42"
  CAVE_ROCK = "T40"
  # Graphic of the cave exits and ladders (a ladder, as in the example dungeon map).
  CAVE_EXIT_TILE = 384 + 47
  # Rock around the galleries: half the screen, as Essentials' dungeons.
  CAVE_MARGIN = [8, 6]
  # Galleries of a floor, by excess (nil = none), on a grid of 2x2-tile
  # blocks: size in blocks, number of chambers, their radius (blocks), extra
  # tunnels making loops, tunnel width (blocks).
  CAVE_SHAPES = {
    nil              => { size: [24, 19], rooms: 5..7, radius: 1.5..3.2, loops: 1..2, width: 1..2 },
    "grotte immense" => { size: [36, 28], rooms: 9..12, radius: 2.0..4.5, loops: 2..4, width: 1..2 },
    "dédale"         => { size: [30, 24], rooms: 10..14, radius: 0.8..1.6, loops: 4..7, width: 1..1 }
  }.freeze

  # Interiors: each door of a building leads to a copy of a map of the demo,
  # drawn among those of its brick type: [map ID, x, y of its exit (the door
  # mat, the player arrives just above it)]. The copy keeps the map's tiles,
  # not its events. A centre's copy is the healing spot of its town.
  INTERIORS = {
    "centre"   => [[9, 7, 9], [24, 7, 9], [53, 7, 9]],
    "boutique" => [[25, 4, 8], [54, 4, 8]],
    "maison"   => [[6, 6, 8], [8, 3, 9], [26, 5, 11], [27, 4, 8]],
    "immeuble" => [[12, 6, 10], [11, 7, 10]],
    "arene"    => [[10, 6, 15]],
    "port"     => [[27, 4, 8]],
    "special"  => [[30, 5, 9], [11, 7, 10]],
    "labo"     => [[4, 6, 13]]
  }.freeze
  # The professor's lab (brick type), only in the first town of a world. When
  # it doesn't fit, the town is drawn without it and the professor waits
  # outside (see the inventory).
  LAB = "labo"
  # Doors that lead elsewhere than an interior (caves, ferry, stairs)
  NO_INTERIOR = %w[grotte gare montagne colline].freeze

  # The end of every world's chain, after its last town: the Victory Road (a
  # mountain route of the longest « Longueur », with a cave) and the League's
  # plateau, a town with only these bricks. Names shown in game.
  VICTORY_ROAD = "Route Victoire"
  VICTORY_CAVE = "Grotte Victoire"
  PLATEAU = "Plateau de la Ligue"
  PLATEAU_BRICKS = { "centre" => 1..1, "ligue" => 1..1, "lampe" => 2..4, "arbre" => 2..5, "parc" => 0..1 }.freeze
  # The League's building (brick type): its door leads to the rooms of the
  # League, one after the other, copies of the demo's League maps: [role,
  # map ID, x, y where the player arrives, x, y of the door to the next room
  # (none in the last one)]. Only the entrance has a way out (LEAGUE_EXIT,
  # its door mat), back to the plateau.
  LEAGUE = "ligue"
  LEAGUE_ROOMS = [
    ["Entrée",   36, 11, 16, 4, 1],
    ["Ancien 1", 37, 6, 12, 6, 2],
    ["Ancien 2", 37, 6, 12, 6, 2],
    ["Ancien 3", 37, 6, 12, 6, 2],
    ["Ancien 4", 37, 6, 12, 6, 2],
    ["Parrain",  37, 6, 12, 6, 2],
    ["Arceus",   37, 6, 12, 6, 2],
    ["Panthéon", 38, 5, 12]
  ].freeze
  LEAGUE_EXIT = [11, 17].freeze

  # Field items (plugin FieldItems), each obtained in a town with a gym: that
  # gym's or a later one (world key: its name, e.g. « Pioche = 3 »), drawn in
  # the order of these minimums. Surf and Dive keep their own keys (Surf,
  # Plongee).
  FIELD_ITEMS = {
    "Machette" => [:MACHETE, 1],
    "Lanterne" => [:LANTERN, 2],
    "Pioche"   => [:PICKAXE, 3],
    "Harnais"  => [:HARNESS, 4],
    "Grappin"  => [:GRAPPLINGHOOK, 5],
    "Vol"      => [:FLYINGSADDLE, 6]
  }.freeze
  SURF_ITEM = :SURFSADDLE
  DIVE_ITEM = :DIVINGSUIT
  # Optional nooks (« Recoins » in a world, % per place), each behind an
  # obstacle opened by a field item obtained earlier in the chain: a cut
  # tree, a cracked rock or a boulder at the mouth of a pocket in the rock, a
  # rock wall to cross with the Grappling Hook, an islet in a pond (Surf), a
  # dark cave (Lantern, routes only). Their loot is in the inventory.
  NOOKS = {
    "arbre"   => :MACHETE,
    "rocher"  => :PICKAXE,
    "bloc"    => :HARNESS,
    "ilot"    => SURF_ITEM,
    "sombre"  => :LANTERN,
    "grappin" => :GRAPPLINGHOOK
  }.freeze
  # Obstacles closing a shortcut (« Raccourcis » in a world) at its end nearer
  # the start, and the field item that opens each: a cut tree, a cracked rock,
  # a boulder (in a gap of a wall across the route), a wall with no gap to
  # cross with the Grappling Hook, water to surf.
  LOCKS = {
    "arbre"   => :MACHETE,
    "rocher"  => :PICKAXE,
    "bloc"    => :HARNESS,
    "grappin" => :GRAPPLINGHOOK,
    "eau"     => SURF_ITEM
  }.freeze
  # The obstacle crossed with the Grappling Hook: events on both faces of its
  # wall, named so (see pbMapProcGrapple)
  GRAPPLE = "grappin"
  GRAPPLE_EVENT = "Grapple"
  # Squares at most between the two ends of a route off the chain, and its
  # length at most (and the gap between the legs of a U)
  EXTRA_REACH = 6
  # The obstacle events, copied from the demo: [map ID, event ID]. Their name
  # keeps what Essentials looks for (CutTree, SmashRock, StrengthBoulder).
  NOOK_EVENTS = {
    "arbre"  => [31, 1],
    "rocher" => [31, 22],
    "bloc"   => [34, 5]
  }.freeze
  # Galleries of a dark cave (one floor, see CAVE_SHAPES)
  DARK_CAVE_SHAPE = { size: [14, 11], rooms: 2..3, radius: 1.2..2.2, loops: 0..1, width: 1..1 }.freeze

  # World file (in FOLDER) drawn with a new seed at each new game, nil = none.
  # The game only keeps it if it is saved: at the next start, the maps of a
  # game left without saving are deleted (or the saved world is drawn again).
  NEW_GAME_WORLD = "monde.txt"
  # Which world the maps on disk belong to ({ path:, seed: }), written when a
  # new game draws its world.
  GAME_WORLD_FILE = "Data/MapProcWorld.rxdata"
  # Priority of the thread drawing the world during the intro (Ruby thread
  # priority: below 0, shorter time slices, so the intro keeps its frame rate)
  WORLD_THREAD_PRIORITY = -3

  # Excesses (« Demesure » in a world): now and then a place goes over the top.
  # kind: ville or route (an island takes those of a village or of a route),
  # grotte (cave, its galleries in CAVE_SHAPES) or fonds (seabed); boost:
  # brick type => times its usual most (optional bricks only, so the place
  # always fits); giant_lake: lakes far bigger; colossal: a mountain route
  # with as many levels as fit (mountain routes only); long: a route three
  # times as long as « Longueur » allows; fill: after the other bricks, that
  # type again wherever it still fits; dense: those may touch each other;
  # flood: water all over the free ground, the streets kept dry; carpet: that
  # symbol all over the free ground (over_street: over the streets too, not
  # the exits); ambiance: that [Ambiance] of the place file (its ground and
  # streets), if the file has it. Seabeds: reach: how far the floor opens from
  # the deep water (4..9 otherwise); weed: far more and bigger spots of seaweed.
  EXCESSES = {
    "forêt profonde"     => { kind: "route", boost: { "arbre" => 4 }, fill: "arbre", dense: true },
    "mer d'herbes"       => { kind: "route", boost: { "herbes" => 4, "prairie" => 3 }, fill: "herbes", dense: true, carpet: '"', over_street: true },
    "chaos rocheux"      => { kind: "route", boost: { "montagne" => 4, "corniche" => 3, "rocaille" => 2 }, fill: "montagne", dense: true },
    "lac géant"          => { kind: "route", boost: { "lac" => 1 }, giant_lake: true, flood: true },
    "montagne colossale" => { kind: "route", colossal: true, boost: { "rocaille" => 2 } },
    "route interminable" => { kind: "route", long: true },
    "ville-jardin"       => { kind: "ville", boost: { "parc" => 3, "arbre" => 3 }, fill: "arbre", carpet: "*", ambiance: "chemins de terre" },
    "cité lacustre"      => { kind: "ville", boost: { "lac" => 2 }, giant_lake: true, flood: true },
    "grande foire"       => { kind: "ville", boost: { "foire" => 4, "lampe" => 2 }, fill: "foire" },
    "grotte immense"     => { kind: "grotte" },
    "dédale"             => { kind: "grotte" },
    "abysse"             => { kind: "fonds", reach: 10..16 },
    "forêt d'algues"     => { kind: "fonds", weed: true }
  }.freeze
  # The kinds of the places of the chain (the others are off it)
  CHAIN_KINDS = %w[ville route].freeze

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

  # Decor maps (see 013_Fillers.rb): the empty squares of the world next to a
  # place become maps that can't be walked, so the screen never shows black
  # past a place's edge. Their map names; rocks on a mountain decor (share of
  # its tiles); symbols of the world grid for them (one per map, the decor
  # squares left over stay empty).
  FILLERS = true
  FILLER_NAME = "Décor généré"
  FILLER_ROCKS = 0.04
  FILLER_SYMBOLS = ((0x3B1..0x3C9).to_a + (0x391..0x3A9).to_a - [0x3A2] + (0x410..0x44F).to_a).map { |c| c.chr(Encoding::UTF_8) }.freeze
end
