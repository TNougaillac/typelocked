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

  # The monument of a town (« monument » in [Briques]) stands within that
  # many tiles of its square, when it has one.
  MONUMENT_REACH = 3

  # A stretch of sand across a long plain route (see
  # PlaceBuilder#lay_transition), that often (%) on routes of these
  # ambiances at least min_length tiles long: size tiles along the route,
  # rocks % of its cells; ground and rock: symbols of route.txt.
  # TRANSITION_SALT: its own draws.
  TRANSITION = { chance: 40, ambiances: ["verdoyante", "automne"], min_length: 60, size: 14..22,
                 rocks: 3, ground: "§", rock: "¤" }.freeze
  TRANSITION_SALT = 0x5A4D

  # Plans of the towns big enough for a square (see PlaceBuilder#choose_plan),
  # by weight; boost: [Briques] types raised to that many times their
  # highest count. GRID: tiles between two streets of a « grille » (across,
  # down); CANAL: width of the canal of a « canal ». PLAN_SALT: their own
  # draws.
  TOWN_PLANS = {
    "carrefour" => { weight: 4 },
    "grille"    => { weight: 2 },
    "canal"     => { weight: 1 },
    "clairière" => { weight: 1, boost: { "arbre" => 3 } }
  }.freeze
  GRID = { across: 14..16, down: 12..14 }.freeze
  CANAL = { width: 4..5 }.freeze
  PLAN_SALT = 0x91A45

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
  # A raised band stops short of a side of the map that often (%), at least
  # SIDE_GAP tiles from its streets; peaks (one level above the ground
  # around them) per 20x20 tiles.
  SIDE_TRIM = 60
  SIDE_GAP = 4
  # Slopes, as on the official maps: that often (%) a boundary runs
  # diagonally (each step goes its way SLOPE_BIAS % of the time) and wanders
  # up to SLOPE_WAVE rows; the cut side of a mesa wanders up to SIDE_WAVE
  # columns. Their own draws (RELIEF_SALT).
  SLOPE_CHANCE = 60
  SLOPE_BIAS = 80
  SLOPE_WAVE = 5
  SIDE_WAVE = 3
  RELIEF_SALT = 0x5E1F
  # Towns in terraces: that often (%) a town big enough for a square (and not
  # a port, an island, a canal or a mask) climbs in steps, bands between
  # TERRACE_FACES boundaries, TERRACE_DEPTH rows deep at least, up to as many
  # levels as its « Relief » has symbols, their sides cut like a mesa. Drawn
  # with TERRACE_SALT; drawn again (TERRACE_TRIES in all), then built flat,
  # when its bricks don't fit.
  TERRACE_CHANCE = 65
  TERRACE_TRIES = 4
  TERRACE_PEAKS = 0.5..1.0
  TERRACE_FACES = 2..4
  TERRACE_DEPTH = 7
  TERRACE_SALT = 0x7E44
  MOUNTAIN_PEAKS = 0.5..1.5
  # Lakes (« lac » in [Briques]): drawn for their spot, one to three
  # overlapping ovals (round, long, bean or L-shaped ponds) in a box of that
  # size; the ovals added after the first are that much smaller (share of
  # the box, per side).
  LAKE_SHAPE = { width: 4..14, height: 4..10, ovals: 1..3, first: 0.35..0.5, more: 0.2..0.4 }.freeze
  # Hills (« colline » in [Briques]): drawn for the spot like the lakes, a
  # stair on their south face. In a town, only that often (%) when drawn.
  HILL_TOWN_CHANCE = 20
  # On a route with tall grass (« HerbeHaute »), that often (%) a hill's top
  # is tall grass (wild Pokémon up there); otherwise a loot lies on it.
  HILL_GRASS_CHANCE = 70

  # Caves of a world (2 floors each, see 006_Caves.rb): tileset of their maps
  # (it needs a section in PBS/dungeon_tilesets.txt, and its dungeon
  # parameters CAVE_AREA in PBS/dungeon_parameters.txt for the decorations),
  # its floor and rock tiles. Cave 4G (HGSS, tools/art/caves_4g.py) keeps
  # the rock, floor and ladder tiles of Dungeon cave (7), with single walls.
  CAVE_TILESET = 25
  CAVE_AREA = :cave
  CAVE_FLOOR = "T42"
  CAVE_ROCK = "T40"
  # Graphic of the cave exits and ladders (a hole with its ladder).
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
  HOUSE_INTERIORS = [[6, 6, 8], [8, 3, 9], [26, 5, 11], [27, 4, 8]].freeze
  INTERIORS = {
    "centre"   => [[9, 7, 9], [24, 7, 9], [53, 7, 9]],
    "boutique" => [[25, 4, 8], [54, 4, 8]],
    "maison"   => HOUSE_INTERIORS,
    "refuge"   => HOUSE_INTERIORS,
    "immeuble" => [[12, 6, 10], [11, 7, 10]],
    "arene"    => [[10, 6, 15]],
    "port"     => [[27, 4, 8]],
    "special"  => [[30, 5, 9], [11, 7, 10]],
    "labo"     => [[4, 6, 13]]
  }.freeze
  # Tileset of an interior copied from a template on that tileset (#194):
  # Interior general (houses, flats, warehouses, lab) => Interior 4G, its
  # floors redrawn by tools/art/interiors_4g.py.
  INTERIOR_TILESETS = { 3 => 26 }.freeze
  # The professor's lab (brick type), only in the first town of a world. When
  # it doesn't fit, the town is drawn without it and the professor waits
  # outside (see the inventory).
  LAB = "labo"
  # Buildings without a door (town decor): their roof is kept free like the
  # others' (see PlaceBuilder#brick_halo)
  BUILDING_NO_DOOR = "batisse"
  # Models of buildings a place draws from, so that its houses look alike:
  # brick type => [models in a place of one square (20x20 tiles), more models
  # for each other square]. A village has 2 house models, a big town more.
  MODELS = { "maison" => [2, 0.6], "immeuble" => [1, 0.4], "batisse" => [1, 0.4] }.freeze
  # Optional bricks placed after all the others (town decor that must not
  # take the room of a park)
  LAST_KINDS = %w[batisse special].freeze
  EXTRA_SALT = 7951
  # Doors that lead elsewhere than an interior (caves, ferry, stairs)
  NO_INTERIOR = %w[grotte gare montagne colline].freeze
  # Animated doors of the 4G buildings (SirMalo's charsets, scaled by
  # tools/art/doors_4g.py): building symbol => charset in Graphics/Characters.
  # The door opens when the player walks in; other buildings draw their own.
  DOOR_GRAPHICS = {
    "C" => "Door_PC", "M" => "Door_PC", "N" => "Door_PC",
    "G" => "Door_Gym01", "H" => "Door_Gym01",
    "V" => "Door_Newbark01", "W" => "Door_Newbark01", "u" => "Door_Newbark01",
    "r" => "Door_Newbark01", "o" => "Door_Newbark01",
    "U" => "Door_Olivine01",
    "E" => "Door_Violet01", "K" => "Door_Violet01", "h" => "Door_Violet01", "g" => "Door_Violet01",
    "D" => "Door_Goldenrod01", "O" => "Door_Goldenrod01",
    "Q" => "Door_PC", "X" => "Door_Violet01", "Y" => "Door_Violet01", "B" => "Door_Violet01",
    "Z" => "Door_Goldenrod01", "A" => "Door_Newbark01",
    # The other 4G buildings (MORE_BUILDINGS), by the colour of their walls
    "Α" => "Door_PC", "Ψ" => "Door_PC",
    "Β" => "Door_Violet01", "Ε" => "Door_Violet01", "Λ" => "Door_Violet01", "Μ" => "Door_Violet01",
    "Ο" => "Door_Violet01", "Ρ" => "Door_Violet01", "η" => "Door_Violet01", "ο" => "Door_Violet01",
    "Γ" => "Door_Gym01", "Θ" => "Door_Gym01", "Ν" => "Door_Gym01", "Υ" => "Door_Gym01", "Χ" => "Door_Gym01",
    "Ω" => "Door_Gym01", "γ" => "Door_Gym01", "δ" => "Door_Gym01", "ε" => "Door_Gym01", "θ" => "Door_Gym01",
    "λ" => "Door_Gym01", "ξ" => "Door_Gym01",
    "Δ" => "Door_Olivine01", "Ξ" => "Door_Olivine01", "Π" => "Door_Olivine01", "α" => "Door_Olivine01",
    "β" => "Door_Olivine01", "ζ" => "Door_Olivine01", "κ" => "Door_Olivine01",
    "R" => "Door_Goldenrod01", "Ζ" => "Door_Goldenrod01", "Η" => "Door_Goldenrod01",
    "Κ" => "Door_Goldenrod01", "Φ" => "Door_Goldenrod01", "ι" => "Door_Goldenrod01",
    "Ι" => "Door_Newbark01", "Σ" => "Door_Newbark01", "Τ" => "Door_Newbark01",
    "L" => "Door_Goldenrod01", "J" => "Door_Newbark01"
  }.freeze

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

  # Weather of the towns and routes of a world (#202), drawn at the seed by
  # ambiance (nil: the default one; MOUNTAIN_WEATHER for a mountain route):
  # [weather of Essentials, weight], :None for no weather. The weather drawn
  # is written in the map's metadata (« Weather = Rain,50 »): it comes back
  # with WEATHER_CHANCE % chance each time the player enters the map.
  WEATHER = {
    nil               => [[:None, 70], [:Rain, 25], [:Storm, 5]],
    "verdoyante"      => [[:None, 65], [:Rain, 30], [:Storm, 5]],
    "chemins de terre" => [[:None, 75], [:Rain, 20], [:Fog, 5]],
    "prairie"         => [[:None, 60], [:Sun, 25], [:Rain, 15]],
    "sable"           => [[:None, 40], [:Sandstorm, 35], [:Sun, 25]],
    "minérale"        => [[:None, 60], [:Sandstorm, 20], [:Fog, 20]],
    "terre battue"    => [[:None, 60], [:Sun, 30], [:Sandstorm, 10]],
    "automne"         => [[:None, 55], [:Rain, 25], [:Fog, 20]],
    "forêt tropicale" => [[:None, 30], [:Rain, 35], [:HeavyRain, 20], [:Storm, 15]],
    "neige"           => [[:None, 30], [:Snow, 45], [:Blizzard, 20], [:Fog, 5]],
    "marais"          => [[:None, 35], [:Rain, 40], [:HeavyRain, 10], [:Fog, 15]],
    "montagne"        => [[:None, 40], [:Snow, 35], [:Blizzard, 15], [:Fog, 10]]
  }.freeze
  MOUNTAIN_WEATHER = "montagne"
  WEATHER_CHANCE = 50
  WEATHER_SALT = 0x3E7E0

  # Seabeds of a world (under routes with deep water): tileset and palette.
  # « . » = floor, « s » = seaweed, « R » = rock (walls, edges drawn by MapGen).
  SEABED_TILESET = 27
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
  # The same in the sea of a port and in the water crossing a route (their
  # own draws, SEA_LIFE_SALT), when the place has « Recif » and « Banc »
  SEA_LIFE = { banks: 0..2, reefs: 1..3 }.freeze
  SEA_LIFE_SALT = 0x5EA1
  # Sea routes (« mer », see « Mers » in a world): a beach of shore rows
  # (wavering) at each end, the sea between; on it, per CASE_SIZE square,
  # ridges of rocks (2 wide, ridge stamps long, along the route as on
  # Hoenn's sea routes), masses of rock (mass stamps), small rocks and
  # sandbanks, off a lane kept free
  # along the route's way (lane tiles on each side). Their own draws
  # (SEA_ROUTE_SALT).
  SEA_ROUTE = { shore: 3..6, ridges: 0.8..1.4, ridge: 3..7, masses: 0.5..1.0, mass: 4..10,
                rocks: 0.6..1.2, banks: 0.3..0.8, lane: 2 }.freeze
  SEA_ROUTE_SALT = 0x5EA2
  # Island names: « Île » and a name, or a name alone, from these sections of
  # this file
  ISLAND_NAMES_FILE = "Lore/noms.txt"
  ISLAND_NAME_SECTIONS = %w[Italien Americain Francais].freeze

  # Decor maps (see 013_Fillers.rb): the empty squares of the world next to a
  # place become maps that can't be walked, so the screen never shows black
  # past a place's edge. Their map names; rocks on a mountain decor (share of
  # its tiles, [Legend] symbols of rocks on rock); symbols of the world grid
  # for them (one per map, the decor squares left over stay empty).
  FILLERS = true
  FILLER_NAME = "Décor généré"
  FILLER_ROCKS = 0.04
  FILLER_ROCK_SYMBOLS = %w[ø ö õ ó].freeze
  FILLER_SYMBOLS = ((0x3B1..0x3C9).to_a + (0x391..0x3A9).to_a - [0x3A2] + (0x410..0x44F).to_a).map { |c| c.chr(Encoding::UTF_8) }.freeze
end
