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
  # down); CANAL: width of the canal of a « canal » that runs from north to
  # south. PLAN_SALT: their own
  # draws.
  TOWN_PLANS = {
    "carrefour" => { weight: 4 },
    "grille"    => { weight: 2 },
    "canal"     => { weight: 1 },
    "clairière" => { weight: 1, boost: { "arbre" => 3 } }
  }.freeze
  GRID = { across: 14..16, down: 12..14 }.freeze
  CANAL = { width: 4..5 }.freeze
  # The stone bridge of a canal that runs from west to east (see
  # PlaceBuilder#lay_stone_canal): its object in ville.txt (its block: the
  # parapets and the deck over the water; its halo: the posts on the banks),
  # that often (%) among the canals; kind: the type of its cells; apart: tiles
  # between two bridges at least (from deck to deck).
  STONE_BRIDGE = { symbol: "Ѫ", chance: 50, kind: "pont", apart: 8 }.freeze
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
  # A mountain river comes down the levels by cascades: it springs on the
  # highest band it can go down from, SPRING_GAP rows below its north rim
  # (no river above).
  SPRING_GAP = 3
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
  # The same for a plain route (see PlaceBuilder#terrace?): plateaus and
  # canyons along the way, the streets climbing them by stairs; faces and
  # depth: as TERRACE_FACES and TERRACE_DEPTH, a route being narrower;
  # mesas: per square, on a route that can't climb by bands (east-west, L, U),
  # mesa_width by mesa_height tiles, each one with chain more boxes joined to
  # it (a ridge). A mesa's stair: on its south face, a path from the street
  # of MESA_STAIR_REACH steps at most, around the mesa if need be.
  ROUTE_TERRACE_CHANCE = 60
  ROUTE_TERRACE = { faces: 1..3, depth: 5, mesas: 0.3..0.7, mesa_width: 6..12, mesa_height: 4..9, chain: 0..3 }.freeze
  # The smallest mesa (width, height in tiles): a smaller piece of a level is
  # lowered, its cliff would have no top behind it.
  MESA_MIN = [4, 3].freeze
  # Rounds of thicken at most (its fills and cuts could chase each other).
  THICKEN_ROUNDS = 200
  MESA_STAIR_REACH = 40
  TERRACE_TRIES = 4
  TERRACE_PEAKS = 1.0..2.0
  TERRACE_FACES = 2..4
  TERRACE_DEPTH = 7
  TERRACE_SALT = 0x7E44
  PLOT_SALT = 0x9107
  # A place that can't hold what it must (a required brick, a guild's
  # headquarters) is laid out again, up to PLACE_RETRIES times, each try
  # with the seed moved by PLACE_RETRY_STEP (its map, ambiance and plan text
  # keep the place's seed).
  PLACE_RETRIES = 8
  PLACE_RETRY_STEP = 104_729
  # A town's terraces, drawn as a map designer would: climbing from band to
  # band that often (climb, up to 4 levels, see « Relief »), their sides cut that
  # often (%), slanting in a column every few rows going down, their faces
  # wandering up to face_wave rows between the streets.
  # A ledge per building: a town's house stands on a plot one level up that
  # often (%), where the ground around it is free, its path going down by
  # stairs.
  PLOT_CHANCE = 50
  TOWN_TERRACE = { trim: 90, taper: 1..3, face_wave: 3, climb: 0.9 }.freeze
  MOUNTAIN_PEAKS = 0.5..1.5
  # Lakes (« lac » in [Briques]): drawn for their spot, one to three
  # overlapping ovals (round, long, bean or L-shaped ponds) in a box of that
  # size; the ovals added after the first are that much smaller (share of
  # the box, per side).
  LAKE_SHAPE = { width: 4..14, height: 4..10, ovals: 1..3, first: 0.35..0.5, more: 0.2..0.4 }.freeze
  # Patches of grass (« herbes », « prairie », the parks of « parc » in
  # [Briques]): that often (%)
  # drawn for the spot like the lakes, of the symbol of the brick drawn,
  # instead of that brick; width and height of their box, a quarter smaller
  # each time it doesn't fit (as big as the place allows).
  GRASS_SHAPE = {
    "herbes"  => { chance: 100, width: 12..26, height: 7..14, ovals: 3..6, first: 0.3..0.4, more: 0.2..0.35 },
    "prairie" => { chance: 100, width: 16..30, height: 9..16, ovals: 3..6, first: 0.3..0.4, more: 0.2..0.35 },
    "parc"    => { chance: 100, width: 6..12, height: 4..8, ovals: 2..3, first: 0.35..0.45, more: 0.25..0.4 }
  }.freeze
  # Ridges (« montagne » in [Briques]): that often (%) drawn for the spot, a
  # massif on a grid of 2x2 blocks, width by height blocks,
  # instead of a brick of the files; a stair on its south face when it fits.
  RIDGE_SHAPE = { chance: 70, width: 5..10, height: 2..4 }.freeze
  # How often a side of a massif narrows by a block, row after row (%, from
  # its top row to its foot): its foot ends rounded.
  BOWL_BEND = 30..80
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
  # the rock, floor and ladder tiles of the demo's Dungeon cave, with single walls.
  CAVE_TILESET = 25
  # Caves by biome (#300): the ambiance of the place a cave opens on => its
  # tileset, laid out like Cave 4G (tools/art/cave_styles_4g.py): ice, lava,
  # moss. The others keep CAVE_TILESET.
  CAVE_STYLES = { "neige" => 28, "volcan" => 29, "forêt sombre" => 30, "marais" => 30, "forêt tropicale" => 30 }.freeze
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
    # The ruins' temple (#210), the Order of the Pact's: the Battle Palace hall
    "temple"   => [[58, 7, 8]],
    # The Breeders' farm (#212): the Day Care
    "ferme"    => [[27, 4, 8]],
    # The Rangers' post (#215): a cabin
    "poste"    => [[8, 3, 9]],
    # The Swimmers' Circle's club (#218): a big house
    "nageurs"  => [[26, 5, 11]],
    # The Nest Keepers' guard hut (#219): a small house
    "pontes"   => [[6, 6, 8]],
    # The Dundees' hunting camp (#220): a hut
    "dundees"  => [[8, 3, 9]],
    # The Chromed's den (#221): the garage, a house
    "chromes"  => [[6, 6, 8]],
    "immeuble" => [[12, 6, 10], [11, 7, 10]],
    # The Showmen's fair (#217): the game hall, a building's
    "forains"  => [[12, 6, 10]],
    "arene"    => [[10, 6, 15]],
    "port"     => [[27, 4, 8]],
    # The Smugglers' warehouse (#214): the port's warehouse
    "contrebande" => [[27, 4, 8]],
    "special"  => [[30, 5, 9], [11, 7, 10]],
    "labo"     => [[4, 6, 13]]
  }.freeze
  # Headquarters of the guilds (#181): brick type => the ambiances it stands
  # in (none: any). Its quantity is 0 in [Briques]: the guilds' draw sets it
  # (#182).
  # The ruins' temple is always there (« temple = 1 » in the ruins); the
  # poachers' camp and the cemetery have no brick yet (#216, #211).
  GUILD_HQS = { "ferme" => %w[prairie], "chantier" => ["terre battue"],
                "carriere" => ["minérale", "haute montagne"], "contrebande" => [],
                "poste" => ["verdoyante", "automne", "forêt sombre"], "forains" => [],
                "nageurs" => %w[plage], "pontes" => %w[plage],
                "dundees" => %w[marais], "chromes" => [], "temple" => %w[ruines],
                "braconniers" => ["forêt sombre"], "cimetiere" => ["cimetière"] }.freeze
  # Headquarters laid along the quay of a port town, like its warehouses
  # (never elsewhere)
  QUAY_HQS = %w[contrebande].freeze
  # Guilds of a world (#183): once the world is built, this many
  # headquarters are drawn among those whose place exists (an ambiance it
  # allows, a port for a quay's), each laid on one of those places drawn by
  # the seed (fewer if fewer fit).
  WORLD_GUILDS = 3..5
  # Enemy guilds (#189), by the brick type of their headquarters (the
  # « Ennemis » of MapProc/Lore/guildes.txt, checked by the CI): once one is
  # drawn, each enemy whose place exists joins it in HQ_ENEMY_CHANCE % of
  # the worlds (while there is room among WORLD_GUILDS), on the place
  # nearest it along the chain.
  HQ_ENEMIES = { "poste" => %w[braconniers], "braconniers" => %w[poste pontes], "chantier" => %w[contrebande],
                 "contrebande" => %w[chantier], "pontes" => %w[nageurs dundees braconniers],
                 "nageurs" => %w[pontes], "dundees" => %w[pontes] }.freeze
  HQ_ENEMY_CHANCE = 70
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
  # Styles of towns: a place builds all its houses (« maison »), fences
  # (« barriere ») and street furniture (« lampe ») in one of them, so that
  # its roofs, walls, fences and lamps go together (#298). weight: how often
  # it is drawn, more in some ambiances; houses, fences, furniture: the names
  # of their bricks (a kind left with none of them in an ambiance keeps all
  # of its bricks).
  HOUSE_STYLES = {
    "rustique" => { weight: 1, ambiances: { "chemins de terre" => 3, "automne" => 3, "marais" => 4, "terre battue" => 2, "neige" => 2 },
                    houses: ["Case en paille", "Chalet rouge", "Chaumière", "Chaumière à cheminée", "Maison aux bardeaux",
                             "Maison en bois", "Maison ocre", "Maison en rondins"],
                    fences: ["Barrière le long du chemin", "Longue barrière le long du chemin", "Très longue barrière le long du chemin"],
                    furniture: ["Banc de bois", "Lanterne suspendue", "Lanternes en bois", "Jardinière", "Boîte aux lettres"] },
    "chaud"    => { weight: 2, ambiances: { "sable" => 3, "volcan" => 4, "plage" => 3, "terre battue" => 2 },
                    houses: ["Maison bordeaux à cheminée", "Maison orange à balustrade", "Maison crème", "Maison orange",
                             "Maison orange à escalier", "Maison rouge à auvent", "Maison au toit rouge", "Maison verte à cheminée",
                             "Petite maison bleue", "Petite maison orange", "Petite maison rouge"],
                    fences: ["Palissade le long du chemin", "Longue palissade le long du chemin"],
                    furniture: ["Réverbère rouge", "Bancs", "Jardinière", "Lampadaire", "Boîte aux lettres"] },
    "froid"    => { weight: 2, ambiances: { "neige" => 3, "minérale" => 3, "verdoyante" => 2, "prairie" => 2 },
                    houses: ["Garage", "Maison à auvent vert", "Maison bleue à cheminée", "Maison et jardin", "Maison mauve",
                             "Maison au toit de mousse", "Maison au pignon bleu", "Petite maison à toit plat", "Maison turquoise à annexe",
                             "Haute maison turquoise", "Maison violette", "Grande maison aux tuiles violettes", "Maison au toit vitré",
                             "Maison au toit vitré bleu", "Petite maison verte"],
                    fences: ["Barrière blanche le long du chemin", "Longue barrière blanche le long du chemin"],
                    furniture: ["Réverbère turquoise", "Bouche d'incendie", "Lampadaire d'Émeraude", "Distributeurs", "Bancs"] }
  }.freeze
  HOUSE_STYLE_SALT = 5381
  # Brick type => the key of HOUSE_STYLES that lists its bricks
  STYLE_KINDS = { "maison" => :houses, "barriere" => :fences, "lampe" => :furniture }.freeze
  # Optional bricks placed after all the others (town decor that must not
  # take the room of a park)
  LAST_KINDS = %w[batisse barriere].freeze
  # Optional bricks tried right after the required buildings but the
  # houses (the unique buildings, too big to find room once the town is
  # built, #299; the round square, which needs five tiles along a street,
  # #298)
  EARLY_KINDS = %w[special placette].freeze
  # Fences (« barriere » in [Briques]): along a street, all along it.
  FENCE = "barriere"
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
  # obstacle opened by a field item (obtained earlier in the chain, or later
  # for a nook to come back to, see REVISIT): a cut
  # tree, a cracked rock or a boulder at the mouth of a pocket in the rock, a
  # rock wall to cross with the Grappling Hook, an islet in a pond (Surf), a
  # dark cave (Lantern, routes only). Their loot is in the inventory.
  NOOKS = {
    "arbre"   => :MACHETE,
    "rocher"  => :PICKAXE,
    "bloc"    => :HARNESS,
    "ilot"    => SURF_ITEM,
    "sombre"  => :LANTERN,
    "grappin" => :GRAPPLINGHOOK,
    "glace"   => :SKATES,
    "boue"    => :WADERS,
    "paroi"   => :CLIMBINGCLAWS,
    "piste"   => :BICYCLE
  }.freeze
  # Nooks crossed with a field item obtained outside the gyms (#270, #272):
  # in a place of one of its ambiances (nil: any) and kinds, chance % of the
  # nooks of CROSSING_FROM become a pocket reached by a corridor of that
  # symbol (:street: the place's street), 3 tiles wide when wide, crossed
  # with the item (an event, « MapProc <event> », on each middle tile of the
  # corridor: pbMapProcCross; invisible, else drawn as tile T<barrier>, which
  # blocks a walkable corridor). Slippery ice (Skates), marsh mud (Waders), a
  # rock wall to climb (Climbing Claws), a cycle path behind its barriers
  # (Bicycle).
  CROSSINGS = {
    "glace" => { item: :SKATES, ambiances: %w[neige], kinds: %w[ville route], chance: 50,
                 corridor: "ǫ", wide: false, event: "Skate" },
    "boue"  => { item: :WADERS, ambiances: %w[marais], kinds: %w[ville route], chance: 50,
                 corridor: "ɓ", wide: true, event: "Wade" },
    "paroi" => { item: :CLIMBINGCLAWS, ambiances: ["haute montagne", "minérale"], kinds: %w[ville route], chance: 50,
                 corridor: "^", wide: false, event: "Climb" },
    "piste" => { item: :BICYCLE, ambiances: nil, kinds: %w[ville], chance: 25,
                 corridor: :street, wide: false, event: "Bike", barrier: 15292 }
  }.freeze
  CROSSING_FROM = %w[arbre rocher bloc].freeze
  # These items are never given in a gym town's chain of field items: each
  # world with a place of their ambiances (any world for the Bicycle) has a
  # town where a hidden inhabitant gives each (placed by WorldEvents), drawn
  # apart (seed x 1000 + 960) so the rest of the world stays the same.
  # item => ambiances (nil: any)
  EXTRA_FIELD_ITEMS = CROSSINGS.values.to_h { |c| [c[:item], c[:ambiances]] }.freeze
  # Share in % of the nooks closed by a field item obtained later in the chain
  # (« Revisiter » in a world): the player sees them and comes back.
  REVISIT = 50
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
  # The obstacle events, copied from the demo's onto map 31 « Modèles
  # d'événements » (#262): [map ID, event ID]. Their name keeps what
  # Essentials looks for (CutTree, SmashRock, StrengthBoulder).
  NOOK_EVENTS = {
    "arbre"  => [31, 1],
    "rocher" => [31, 22],
    "bloc"   => [31, 2]
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
  # streets), if the file has it; trim: those types kept to their fewest;
  # plans: the town's plan drawn among those (TOWN_PLANS, the next one when a
  # plan can't be laid); grid: the streets of a « grille » along its canal
  # too (many bridges); river: the width of its canal (CANAL otherwise);
  # pave: the town's street over the free ground that far from a street
  # (sidewalks); big: only in towns big enough for a square, not a port nor
  # with a mask; pack: the boosted bricks laid from the biggest of their
  # type (PACK_JITTER), the ones not laid yet first; flat: no terraces; without: those bricks (by name)
  # left out. Seabeds: reach: how far the floor opens from the deep water
  # (4..9 otherwise); weed: far more and bigger spots of seaweed.
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
    "métropole"          => { kind: "ville", boost: { "immeuble" => 4, "batisse" => 2, "special" => 2, "lampe" => 2 },
                              trim: %w[maison arbre parc], plans: %w[canal grille], grid: true, river: 6..8, pave: 2, pack: true,
                              flat: true, big: true,
                              without: ["Abri en bois", "Cabane en rondins", "Cabanon", "Abri au toit fleuri", "Longère"] },
    "grotte immense"     => { kind: "grotte" },
    "dédale"             => { kind: "grotte" },
    "abysse"             => { kind: "fonds", reach: 10..16 },
    "forêt d'algues"     => { kind: "fonds", weed: true }
  }.freeze
  # Excess « pack »: how much a brick's size is shuffled (times 1 to
  # 1 + PACK_JITTER) when the biggest ones go first
  PACK_JITTER = 0.6
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
    "volcan"          => [[:None, 40], [:Sun, 35], [:Sandstorm, 15], [:Fog, 10]],
    "plage"           => [[:None, 50], [:Sun, 35], [:Rain, 10], [:Storm, 5]],
    "forêt sombre"    => [[:None, 40], [:Fog, 35], [:Rain, 25]],
    "montagne"        => [[:None, 40], [:Snow, 35], [:Blizzard, 15], [:Fog, 10]],
    "haute montagne"  => [[:None, 35], [:Fog, 35], [:Snow, 20], [:Blizzard, 10]],
    "ruines"          => [[:None, 50], [:Fog, 25], [:Sandstorm, 15], [:Rain, 10]]
  }.freeze
  MOUNTAIN_WEATHER = "montagne"
  # Map metadata flags of an ambiance (Flags of map_metadata), e.g. the tone
  # of a dark forest (TONE_FLAGS)
  AMBIANCE_FLAGS = { "forêt sombre" => "DarkForest" }.freeze
  # Flag => tone added over the day and night shading of the map (red,
  # green, blue, gray), see 015_Tone.rb
  TONE_FLAGS = { "DarkForest" => [-56, -46, -60, 32] }.freeze
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
  ISLAND_AMBIANCE = "plage"
  # Ambiance drawn only on the mountain routes of a world (draw_ambiance);
  # there it keeps its own weather, encounters and trainers, where the other
  # ambiances take those of the mountain (MOUNTAIN_WEATHER)
  MOUNTAIN_AMBIANCE = "haute montagne"
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
