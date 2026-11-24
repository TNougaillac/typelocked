#===============================================================================
# WorldEvents - Settings
# The events of a generated world (the professor, the gate of the first
# town...), drawn from its seed and its inventory, then written by MapEvents.
#===============================================================================
module WorldEvents
  # The professor in the lab (a copy of the demo's map 4) and its three Poké
  # Balls: [x, y] each.
  LAB_PROFESSOR = [6, 3].freeze
  LAB_BALLS     = [[8, 4], [9, 4], [10, 4]].freeze
  PROFESSOR_GRAPHIC = "trainer_PROFESSOR"
  BALL_GRAPHIC      = "Object ball"
  # Game switch on while the player picks a ball (« Choosing starter »), and
  # game variable holding the starter taken (1 to 3; « Starter choice »): the
  # gate of the first town opens once it is set.
  CHOOSING_STARTER_SWITCH = 3
  STARTER_VARIABLE        = 7

  # Services copied from the Pokémon Centres of the demo (the interior is a
  # copy of that map): template => [[event ID, x, y]] (nurse, PC, healing
  # machine; the nurse names the machine by its ID, kept by the copy).
  CENTRE_EVENTS = {
    9  => [[2, 7, 2], [3, 11, 1], [4, 5, 2]],
    24 => [[1, 7, 2], [3, 11, 1], [4, 5, 2]],
    53 => [[1, 7, 2], [3, 11, 1], [4, 5, 2]]
  }.freeze
  CENTRE_LABELS = %w[Infirmiere PC Machine].freeze
  # The nurse works for the Family (#114): her look, and the heals of each
  # Centre: FREE_HEALS free, then a price by the seals won (0 to 8).
  NURSE_GRAPHIC = "NPC Famille infirmiere"
  FREE_HEALS    = 3
  HEAL_PRICES   = [100, 200, 300, 400, 600, 800, 1000, 1200, 1500].freeze
  # The clerk of each shop template ([x, y]), a member of the Family.
  MART_CLERK = { 25 => [2, 3], 54 => [2, 3] }.freeze
  CLERK_GRAPHIC = "trainer_COUSIN_F"
  # Stock of a shop: the items of MapProc/Lore/objets.txt sold from the seals
  # won on the way there (boutique=N, 012_ItemPool.rb).
  # Economy (#176): the Family takes its margin, shops sell at their PBS
  # price times MART_PRICE_FACTOR (selling back is unchanged). A town freed
  # by a guild (#187) sells at the PBS price again.
  MART_PRICE_FACTOR = 1.5
  # A travelling merchant on MERCHANT_CHANCE % of the stretches (the routes
  # reached with the same seals), on one of their routes: MERCHANT_BASICS
  # items of the shops' stock a bit cheaper than the shop (shop price times
  # MERCHANT_BASIC_FACTOR), and MERCHANT_RARES items found in no shop, dear
  # (MERCHANT_RARE_TABLE: from that many seals, item => price).
  MERCHANT_CHANCE       = 60
  MERCHANT_BASICS       = 3
  MERCHANT_BASIC_FACTOR = 0.8
  MERCHANT_RARES        = 3
  MERCHANT_RARE_TABLE = {
    0 => { HEARTSCALE: 3000, EVERSTONE: 2500, FIRESTONE: 4000, WATERSTONE: 4000, THUNDERSTONE: 4000,
           LEAFSTONE: 4000, MOONSTONE: 5000, EXPSHARE: 6000, SCOPELENS: 6000, KINGSROCK: 6000 },
    2 => { SUNSTONE: 5000, METALCOAT: 6000, LEFTOVERS: 9000, EVIOLITE: 9000, PPUP: 8000, RARECANDY: 10000 },
    4 => { DUSKSTONE: 6000, SHINYSTONE: 6000, DAWNSTONE: 6000, ICESTONE: 6000, LIFEORB: 12000,
           CHOICEBAND: 12000, CHOICESPECS: 12000, CHOICESCARF: 12000, FOCUSSASH: 10000 },
    6 => { PPMAX: 15000, ASSAULTVEST: 14000, ROCKYHELMET: 12000, WEAKNESSPOLICY: 14000 }
  }.freeze
  MERCHANT_GRAPHIC = "NPC 22"

  # Trainers of the world, written in PBS/trainers.txt with this version
  # (one per type and name): a new world replaces them all.
  TRAINERS_PBS    = "PBS/trainers.txt"
  TRAINER_VERSION = 100
  # Trainers per square of a route, per cave floor,
  # Cousins per town; % of the trainers of a route who are Cousins.
  ROUTE_TRAINERS = 1..2
  CAVE_TRAINERS  = 1..2
  TOWN_COUSINS   = 0..1
  COUSIN_CHANCE  = 25
  SIGHT          = 3..4
  # Double battles (#123): from DOUBLE_FROM seals won on the way, this % of
  # the trainers of the routes, caves and towns fight two Pokémon at once
  # (at least 2 in their party). A player with one able Pokémon fights single.
  DOUBLE_FROM   = 3
  DOUBLE_CHANCE = 25

  # The Town Map (#115): a Cousin of the first route where one can stand so
  # that the sight (up to MAP_GIVER_SIGHT) cuts the way between two exits
  # gives it once beaten.
  MAP_ITEM        = :TOWNMAP
  MAP_GIVER_SIGHT = 6
  # Pokémon of a trainer by the seals won on the way (0 to 8).
  PARTY_SIZES = [1..2, 1..2, 2..3, 2..3, 3..4, 3..4, 4..5, 4..6, 5..6].freeze
  # Their levels: up to the highest of the zone's wild Pokémon, this much less.
  PARTY_LEVEL_SPREAD = 2
  # Trainer types by ambiance of the route (nil: grass), mountain and cave.
  # Never a sprite of the Family (tools/art/family_sprites.rb): its
  # characters exist only once (checked by the CI).
  TRAINER_TYPES = {
    nil               => %i[YOUNGSTER LASS CAMPER PICNICKER BUGCATCHER BIRDKEEPER POKEMONBREEDER],
    "verdoyante"      => %i[CAMPER PICNICKER BUGCATCHER POKEMONRANGER_F LASS],
    "prairie"         => %i[LASS YOUNGSTER AROMALADY BIRDKEEPER PAINTER],
    "sable"           => %i[RUINMANIAC HIKER PICNICKER CAMPER],
    "minérale"        => %i[HIKER CRUSHGIRL RUINMANIAC POKEMANIAC],
    "terre battue"    => %i[CAMPER PICNICKER YOUNGSTER LASS],
    "automne"         => %i[PAINTER LADY AROMALADY BIRDKEEPER],
    "forêt tropicale" => %i[BUGCATCHER AROMALADY POKEMONRANGER_F PICNICKER],
    "neige"           => %i[HIKER CRUSHGIRL CAMPER PICNICKER],
    "marais"          => %i[FISHERMAN BUGCATCHER CAMPER AROMALADY],
    "volcan"          => %i[HIKER RUINMANIAC CRUSHGIRL POKEMANIAC],
    "plage"           => %i[TUBER_M TUBER_F SAILOR FISHERMAN PICNICKER],
    "forêt sombre"    => %i[BUGCATCHER PSYCHIC_M POKEMANIAC CAMPER AROMALADY],
    "haute montagne"  => %i[HIKER CRUSHGIRL BIRDKEEPER CAMPER],
    "ruines"          => %i[RUINMANIAC PSYCHIC_M POKEMANIAC HIKER],
    "montagne"        => %i[HIKER CRUSHGIRL CAMPER],
    "grotte"          => %i[HIKER POKEMANIAC RUINMANIAC CAMPER]
  }.freeze
  COUSIN_TYPES = %i[COUSIN_M COUSIN_F].freeze
  # Women's types (the others are men's), for their names.
  FEMALE_TYPES = %i[LIEUTENANT_PSYCHIC LIEUTENANT_GHOST LIEUTENANT_FAIRY ANCIEN_1 LASS PICNICKER
                    POKEMONBREEDER POKEMONRANGER_F AROMALADY PAINTER CRUSHGIRL LADY COUSIN_F TUBER_F
                    SWIMMER_F TEAMROCKET_F CHEF_PONTES CHEF_BRACONNIERS CHEF_FORESTIERS CHEF_ENDEUILLES].freeze
  TRAINER_NAMES = {
    male:   %w[Paolo Vito Enzo Salvatore Luca Marco Tony Frank Eddie Jimmy Rocco Sal Louis Pierre Julien Hugo
               Matteo Dario Nico Sonny Ray Jack Bobby Lucien Marcel Gino Carlo Franco Angelo Victor],
    female: %w[Giulia Rosa Lucia Carla Sofia Maria Gina Nina Peggy Betty Lola Ruby Claire Margot Elise Chloé
               Anna Teresa Bianca Vera Donna Rita Jeanne Louise Adèle Camille Sylvie Gloria Paula Livia]
  }.freeze

  # Gyms (the interior is a copy of a demo map, by template): the
  # lieutenant's cell, then cells for the members of the Family, [x, y,
  # facing, sight]: those of blocking see a stretch the player must cross
  # (one of them is always taken), the others are drawn among the rest.
  GYM_LAYOUTS = {
    10 => {
      leader:   [6, 5],
      blocking: [[11, 6, "gauche", 10], [10, 10, "gauche", 8], [1, 13, "droite", 10]],
      others:   [[2, 4, "bas", 3], [10, 4, "bas", 3], [3, 8, "droite", 4], [9, 8, "gauche", 4]]
    }
  }.freeze
  GYM_MEMBERS = 2..4
  # A generated gym (#121): sight of its members, and their distance (cells)
  # from the entry, the lieutenant and each other
  GYM_MEMBER_SIGHT = 3
  GYM_MEMBER_ROOM = 3
  # The mechanic of a generated gym (#121): barriers on the cells around the
  # lieutenant, lifted once the statues of the room are all touched (game
  # switch GYM_STATUE_SWITCH + the gym's rank, 111 to 130). Statues by gym
  # (1st to 8th), never nearer than GYM_STATUE_ROOM cells to the entry, the
  # lieutenant, a member or each other, never cutting the room.
  GYM_STATUE_SWITCH = 110
  GYM_STATUE_LOCKS  = 20
  GYM_STATUES       = [1, 1, 2, 2, 2, 3, 3, 3].freeze
  GYM_STATUE_ROOM   = 2
  GYM_STATUE        = "Gym statue"
  # Types whose statues bear a number and must be touched in that order (a
  # mistake puts them all out), types whose statues are invisible (found by
  # bumping into the action key).
  GYM_ORDERED = %i[PSYCHIC ELECTRIC STEEL].freeze
  GYM_HIDDEN  = %i[GHOST DARK].freeze
  # Barrier charset by type (tools/art/gym_props_4g.py), GYM_BARRIER otherwise.
  GYM_BARRIERS = { ROCK: "Gym boulder", GROUND: "Gym boulder", FIGHTING: "Gym boulder", ICE: "Gym ice",
                   WATER: "Gym ice", GRASS: "Gym tree", BUG: "Gym tree", POISON: "Gym tree" }.freeze
  GYM_BARRIER = "Gym barrier"
  # Trainer type of a lieutenant (gym leader for the Monotype) by the type of
  # its gym: its sprite (tools/art/family_sprites.rb).
  LEADER_TYPES = {
    NORMAL: :LIEUTENANT_NORMAL, FIRE: :LIEUTENANT_FIRE, WATER: :LIEUTENANT_WATER, GRASS: :LIEUTENANT_GRASS,
    ELECTRIC: :LIEUTENANT_ELECTRIC, ICE: :LIEUTENANT_ICE, FIGHTING: :LIEUTENANT_FIGHTING,
    POISON: :LIEUTENANT_POISON, GROUND: :LIEUTENANT_GROUND, FLYING: :LIEUTENANT_FLYING,
    PSYCHIC: :LIEUTENANT_PSYCHIC, BUG: :LIEUTENANT_BUG, ROCK: :LIEUTENANT_ROCK, GHOST: :LIEUTENANT_GHOST,
    DRAGON: :LIEUTENANT_DRAGON, DARK: :LIEUTENANT_DARK, STEEL: :LIEUTENANT_STEEL, FAIRY: :LIEUTENANT_FAIRY
  }.freeze
  # Pokémon of a lieutenant by gym (1st to 8th), the strongest at the level
  # cap of the next seal; its members have PARTY_SIZES Pokémon, this much
  # lower.
  LEADER_PARTY_SIZES = [2, 3, 3, 4, 4, 5, 5, 6].freeze
  LEADER_LEVEL_SPREAD = 3
  MEMBER_LEVEL_GAP    = 2..4
  # Game switch turned on by the n-th lieutenant (« Defeated Gym n »)
  GYM_SWITCH = 3
  # A TM is « useful »: at least this power, or a status move of this list.
  TM_MIN_POWER = 70
  # Early in the game (the first EARLY_GYMS lieutenants): this power is enough.
  EARLY_GYMS = 3
  EARLY_TM_MIN_POWER = 50
  TM_STATUS = %i[SWORDSDANCE CALMMIND BULKUP DRAGONDANCE NASTYPLOT TOXIC WILLOWISP THUNDERWAVE
                 PROTECT SUBSTITUTE LIGHTSCREEN REFLECT ROOST TAILWIND TRICKROOM SPIKES STEALTHROCK
                 TOXICSPIKES QUIVERDANCE SHELLSMASH AGILITY ROCKPOLISH IRONDEFENSE AMNESIA
                 SLEEPPOWDER SPORE HYPNOSIS GLARE DRAININGKISS MOONLIGHT MORNINGSUN SYNTHESIS].freeze
  # Moves counted at this power for a useful TM (Weather Ball doubles in weather).
  TM_POWER_OVERRIDES = { WEATHERBALL: 100 }.freeze

  # The rooms of the League (LEAGUE_ROOMS of MapProceduralGenerator), by
  # template: where the fighter stands, and the cell in front of the door to
  # the next room, closed until the room is won.
  LEAGUE_LAYOUTS = { 37 => { boss: [6, 6], gate: [6, 3] } }.freeze
  # Game switch turned on by the n-th fight of the League (Anciens 1 to 4,
  # Parrain, Arceus): LEAGUE_SWITCH + n, 59 to 64.
  LEAGUE_SWITCH = 58
  # The four Anciens: their trainer types (Elite Four for the Monotype), one
  # drawn type each, never the same; their Pokémon.
  ELDER_TYPES = %i[ANCIEN_1 ANCIEN_2 ANCIEN_3 ANCIEN_4].freeze
  ELDER_PARTY_SIZES = [5, 5, 6, 6].freeze
  # The Parrain (Champion for the Monotype): no type, the most evolved
  # Pokémon of the roster, the strongest at the cap with every seal.
  PARRAIN_TYPE = :PARRAIN
  PARRAIN_PARTY_SIZE = 6
  # Arceus, boss of OverworldBoss: this many levels above the Parrain's top.
  ARCEUS_GRAPHIC = "boss_ARCEUS"
  ARCEUS_LEVEL_BONUS = 5
  ARCEUS_BOSS = { stats: { HP: 3, ATTACK: 1.2, SPECIAL_ATTACK: 1.2 },
                  moves: %i[JUDGMENT EXTREMESPEED RECOVER COSMICPOWER] }.freeze

  # Sets of the lieutenants and of the League: 4 moves (the trainer's type
  # first, then the Pokémon's other type, a coverage move, a status move),
  # an ability, a held item, a nature, IVs. Read from these PBS files.
  MOVES_PBS = "PBS/moves.txt"
  # Moves a set may take beside its level-up moves: the TMs of the game and,
  # from SET_EGG_SEALS seals, its egg moves; at most this power by seals of
  # the player (0 to 8).
  SET_MAX_POWER = [60, 65, 75, 80, 90, 100, 120, 120, 150].freeze
  SET_EGG_SEALS = 3
  # A status move from this many seals (TM_STATUS or these).
  SET_STATUS_SEALS = 2
  SET_STATUS = (TM_STATUS + %i[RECOVER SOFTBOILED SLACKOFF WISH LEECHSEED COIL WORKUP SHIFTGEAR]).freeze
  # The hidden ability (AbilityIndex 2) from this many seals, if it has one.
  SET_HIDDEN_SEALS = 4
  # Held items by seals (the last line reached): drawn without repeat in a
  # team while some are left. BOOSTER: the item of the type of its first move.
  SET_ITEMS = { 0 => %i[ORANBERRY], 3 => %i[SITRUSBERRY BOOSTER],
                6 => %i[SITRUSBERRY LEFTOVERS EXPERTBELT BOOSTER],
                8 => %i[LEFTOVERS LIFEORB FOCUSSASH SITRUSBERRY BOOSTER] }.freeze
  TYPE_BOOSTERS = { NORMAL: :SILKSCARF, FIRE: :CHARCOAL, WATER: :MYSTICWATER, ELECTRIC: :MAGNET,
                    GRASS: :MIRACLESEED, ICE: :NEVERMELTICE, FIGHTING: :BLACKBELT, POISON: :POISONBARB,
                    GROUND: :SOFTSAND, FLYING: :SHARPBEAK, PSYCHIC: :TWISTEDSPOON, BUG: :SILVERPOWDER,
                    ROCK: :HARDSTONE, GHOST: :SPELLTAG, DRAGON: :DRAGONFANG, DARK: :BLACKGLASSES,
                    STEEL: :METALCOAT, FAIRY: :PIXIEPLATE }.freeze
  # Loot of a seal: the lieutenant offers three rewards, the player keeps one:
  # his TM, a held item and a pack of items, drawn with the seed from the
  # lines of the seal's tier (SEAL_LOOT_TIERS, 1st to 8th seal). BOOSTER: the
  # item of the player's type (TYPE_BOOSTERS), known only in game.
  SEAL_LOOT_TIERS = [0, 0, 1, 1, 1, 2, 2, 2].freeze
  SEAL_HELD_ITEMS = [
    %i[BOOSTER QUICKCLAW SCOPELENS KINGSROCK BRIGHTPOWDER],
    %i[BOOSTER LEFTOVERS FOCUSSASH SHELLBELL MUSCLEBAND WISEGLASSES EVIOLITE ROCKYHELMET],
    %i[LIFEORB CHOICEBAND CHOICESPECS CHOICESCARF ASSAULTVEST EXPERTBELT WEAKNESSPOLICY]
  ].freeze
  SEAL_PACKS = [
    [[[:SUPERPOTION, 4], [:GREATBALL, 5]], [[:REVIVE, 2], [:FULLHEAL, 3]], [[:SUPERPOTION, 3], [:REVIVE, 1], [:GREATBALL, 3]]],
    [[[:HYPERPOTION, 4], [:ULTRABALL, 5]], [[:REVIVE, 3], [:HYPERPOTION, 2]], [[:RARECANDY, 1], [:ULTRABALL, 5]]],
    [[[:FULLRESTORE, 3], [:MAXREVIVE, 1]], [[:MAXPOTION, 4], [:REVIVE, 3]], [[:RARECANDY, 2], [:ULTRABALL, 10]]]
  ].freeze

  # Nature by the better attack stat of the species.
  SET_NATURES = { physical: :ADAMANT, special: :MODEST }.freeze
  # IVs (all six) of the lieutenants by gym (1st to 8th), of the League.
  LEADER_IVS = [10, 12, 15, 18, 21, 24, 27, 30].freeze
  LEAGUE_IVS = 31

  # Postgame (#106): game switch turned on once Arceus is beaten or caught;
  # it lifts the level cap (LevelCap::POSTGAME_SWITCH, the same) and wakes
  # the lieutenants for a rematch, with REMATCH_VERSION of their team in
  # PBS/trainers.txt: REMATCH_PARTY_SIZE Pokémon of their type at Arceus's
  # level, REMATCH_IVS; each gives one item of REMATCH_GIFTS (in turn).
  POSTGAME_SWITCH = 65
  REMATCH_VERSION = TRAINER_VERSION + 1
  REMATCH_PARTY_SIZE = 6
  REMATCH_IVS = 31
  REMATCH_GIFTS = %i[PPMAX ABILITYCAPSULE RARECANDY ABILITYPATCH].freeze

  # Items of a world. How many: per square of a route, per town (islands
  # too), per floor of a cave (not the dark ones), plus the loot of each nook.
  ROUTE_ITEMS = 1..2
  TOWN_ITEMS  = 2..3
  CAVE_ITEMS  = 1..2
  # Source of each of them (weights; the CI checks that gifts are at least
  # GIFT_SHARE % of them): on the ground (a Poké Ball), hidden (Itemfinder),
  # given by an inhabitant.
  ITEM_SOURCES = { "sol" => 30, "cache" => 25, "don" => 45 }.freeze
  GIFT_SHARE = 40
  # What they are, by the seals won before the map: drawn by rarity among the
  # items of MapProc/Lore/objets.txt (012_ItemPool.rb) of the source « sol »;
  # the loot of a nook (by the seals won when it opens: its map's, or those
  # before the field item that opens it, whichever is more) among « recoin »,
  # that of a nook to come back to (#269: opened by a field item obtained
  # after its map) among « revisite » (TMs, evolution stones, strong held
  # items only; never a Heart Scale nor a Pact Incense there). TM: a TM of
  # the game drawn at random (never twice, nor a lieutenant's).
  # Of the nooks to come back to: REVISIT_POKEMON % hold a Pokémon of the
  # imposed type instead (at the level of their Tronçon, under the cap; a
  # capture in Nuzlocke), and REVISIT_LORE % of the others a trace of the
  # Pact read before the item ([recoin_lore]). Drawn apart from the items.
  REVISIT_POKEMON = 25
  REVISIT_LORE = 35
  # Tiers of the Pokémon a nook can hold (never a « fort » one)
  REVISIT_TIERS = %w[faible moyen].freeze
  NOOK_GRAPHIC = "Object ball"
  # The hidden inhabitant who gives a field item obtained outside the gyms
  # (the Skates, #270)
  HIDDEN_GIVER_GRAPHIC = "NPC 09"
  # Weather (#120): when the imposed type plays with a weather, its TMs and
  # its rock go to nooks spread along the way (the TM that casts it first),
  # in WEATHER_CHANCE % of the games. Types => items.
  WEATHER_CHANCE = 85
  WEATHER_ITEMS = {
    %i[WATER ELECTRIC FLYING] => %i[TM18 TM25 TM102 TM103 DAMPROCK],
    %i[FIRE GRASS]            => %i[TM11 TM22 TM103 HEATROCK],
    %i[ROCK GROUND STEEL]     => %i[TM37 TM103 SMOOTHROCK],
    %i[ICE]                   => %i[TM07 TM14 TM103 ICYROCK]
  }.freeze
  # Heart Scales of a world: spread along the way and among the sources, in
  # place of other items.
  HEART_SCALES = 10
  HEART_SCALE  = :HEARTSCALE
  # Pact Incenses (#160): how many in a world (drawn by the seed), in nooks
  # or given by inhabitants, in place of other items.
  PACT_INCENSE  = :PACTINCENSE
  PACT_INCENSES = 0..3
  # Move Relearners (a Heart Scale per move): one in a town reached with at
  # most each number of seals (the first one before the 2nd seal).
  RELEARNERS = [1, 4, 7].freeze
  # The Family's casinos (FamilyCasino plugin): CASINOS croupiers per world,
  # each by a street of a town drawn among all but the first (never two in the
  # same town), placed after everyone else.
  CASINOS = 1..2
  CROUPIER_GRAPHIC = "trainer_COUSIN_F"
  # The Family's usurer (FamilyDebt plugin): in each town but the first, by
  # a street, placed after everyone else.
  USURER_GRAPHIC = "trainer_COUSIN_M"
  RELEARNER_GRAPHIC = "NPC 13"
  # Policemen (#122): POLICE_CHANCE % of the inhabitants of the streets wear
  # this uniform and say the lines of [policier]; no one else wears it.
  POLICE_GRAPHIC = "NPC 01"
  POLICE_CHANCE  = 20
  # Inhabitants who give an item, and the member of the Family who gives a
  # field item once the lieutenant of the town is beaten.
  GIFT_GRAPHICS = ((1..29).map { |i| format("NPC %02d", i) } - [POLICE_GRAPHIC]).freeze
  FIELD_GRAPHIC = "trainer_COUSIN_M"

  # Inhabitants: by the streets of each town (islands too, not the first
  # town), and in the houses, on these cells of their template ([x, y,
  # facing], where the demo has its people).
  TOWN_HABITANTS  = 2..4
  HOUSE_HABITANTS = 1..2
  HOUSE_BUILDINGS = %w[maison immeuble port special].freeze
  HOUSE_SPOTS = {
    6  => [[7, 4, "bas"]],
    # The rooms of Mew (#322, tools/art/interior_mew.py)
    21 => [[2, 5, "bas"], [8, 6, "gauche"]],
    22 => [[3, 5, "bas"], [7, 6, "bas"]],
    23 => [[5, 6, "bas"], [8, 7, "gauche"]],
    28 => [[4, 5, "bas"]],
    8  => [[1, 4, "bas"], [5, 4, "bas"], [8, 4, "bas"]],
    11 => [[5, 3, "bas"], [10, 3, "bas"]],
    12 => [[2, 7, "bas"], [6, 7, "bas"], [10, 7, "bas"]],
    26 => [[2, 6, "bas"], [9, 6, "bas"]],
    27 => [[4, 4, "bas"], [6, 5, "gauche"]]
  }.freeze

  # Every text of the events, in MapProc/Lore/dialogues.txt (in the folder
  # of MapProceduralGenerator): its sections, and the tokens each allows.
  # Those said in battle (*_fin, the lose text) can't name the player, those
  # said in game (professor, shops...) know no town nor region.
  DIALOGUES_FILE = "Lore/dialogues.txt"
  PLACE_TOKENS  = %w[joueur ville region].freeze
  BATTLE_TOKENS = %w[ville region].freeze
  DIALOGUE_SECTIONS = {
    "habitant" => PLACE_TOKENS, "habitant_libre" => PLACE_TOKENS, "policier" => PLACE_TOKENS, "dresseur_combat" => PLACE_TOKENS, "dresseur_fin" => BATTLE_TOKENS,
    "cousin_combat" => PLACE_TOKENS, "cousin_fin" => BATTLE_TOKENS, "cousin_carte" => PLACE_TOKENS,
    "professeur_intro" => %w[joueur type], "professeur_balls" => %w[joueur type],
    "professeur_apres" => %w[joueur type], "professeur_pokedex" => %w[joueur type], "ball" => [], "garde" => %w[joueur],
    "vendeur" => [], "vendeur_libre" => [], "marchand" => [], "casino_blackjack" => [], "casino_poker" => [],
    "casino_perdu" => [], "casino_client" => PLACE_TOKENS, "infirmiere_fin_gratuit" => %w[joueur prix], "infirmiere_prix" => %w[joueur prix],
    "infirmiere_sans_argent" => %w[joueur], "maitre_intro" => %w[joueur], "maitre_sans_ecaille" => %w[joueur],
    "maitre_aucun" => %w[joueur], "maitre_fin" => %w[joueur],
    "don" => PLACE_TOKENS, "don_apres" => PLACE_TOKENS, "terrain_attente" => PLACE_TOKENS,
    "terrain_don" => PLACE_TOKENS, "terrain_apres" => PLACE_TOKENS,
    "lieutenant_combat" => PLACE_TOKENS, "lieutenant_fin" => BATTLE_TOKENS,
    "lieutenant_victoire" => PLACE_TOKENS, "lieutenant_ct" => PLACE_TOKENS,
    "lieutenant_revanche" => PLACE_TOKENS, "lieutenant_revanche_fin" => BATTLE_TOKENS,
    "membre_combat" => PLACE_TOKENS, "membre_fin" => BATTLE_TOKENS,
    "arene_barriere" => PLACE_TOKENS, "arene_barriere_ordre" => PLACE_TOKENS, "arene_barriere_cachee" => PLACE_TOKENS,
    "arene_statue" => [], "arene_statue_deja" => [], "arene_statue_rang" => %w[rang], "arene_statue_erreur" => [],
    "arene_ouverte" => [],
    "ancien_combat" => PLACE_TOKENS, "ancien_fin" => BATTLE_TOKENS,
    "parrain_combat" => PLACE_TOKENS, "parrain_fin" => BATTLE_TOKENS,
    "guilde_raccourci" => PLACE_TOKENS, "guilde_barrage" => PLACE_TOKENS, "guilde_sortie" => PLACE_TOKENS,
    "guilde_vengeance" => PLACE_TOKENS, "guilde_bonus_attente" => PLACE_TOKENS, "guilde_bonus" => PLACE_TOKENS,
    "guilde_bonus_apres" => PLACE_TOKENS, "guilde_reglement" => PLACE_TOKENS, "guilde_reglement_fin" => %w[joueur],
    "recoin_lore" => PLACE_TOKENS, "recoin_pokemon" => PLACE_TOKENS, "terrain_cache" => PLACE_TOKENS, "terrain_cache_apres" => PLACE_TOKENS,
    "arceus_intro" => PLACE_TOKENS, "arceus_fin" => %w[joueur], "porte_ligue" => %w[joueur]
  }.freeze

  # Guilds (#181): read from MapProc/Lore/guildes.txt (in the folder of
  # MapProceduralGenerator). Each has its lines in dialogues.txt, sections
  # guilde_<id>_<role> (id in lowercase), roles and their tokens:
  GUILDS_FILE = "Lore/guildes.txt"
  GUILD_POSITIONS = %w[alliée neutre affiliée rivale].freeze
  GUILD_LINES = { "chef_combat" => PLACE_TOKENS, "chef_fin" => BATTLE_TOKENS, "chef_victoire" => PLACE_TOKENS,
                  "membre_combat" => PLACE_TOKENS, "membre_fin" => BATTLE_TOKENS }.freeze
  # At the headquarters: the leader inside, on this cell of its template ([x,
  # y, facing]; by the street when it has no door), and 2 to 4 members
  # outside, on the free cells by the street nearest it (among this many).
  GUILD_LEADER_SPOTS = { 27 => [4, 4, "bas"], 8 => [5, 4, "bas"], 26 => [9, 6, "bas"], 6 => [7, 4, "bas"],
                         12 => [6, 7, "bas"], 58 => [7, 4, "bas"] }.freeze
  GUILD_MEMBERS = 2..4
  GUILD_NEAR_CELLS = 16
  # On a route of a guild of the world (its biome, or next to its
  # headquarters' town): this % of the trainers are its members (#184).
  GUILD_ROUTE_CHANCE = 33
  # The leader: at the level of the strongest trainer of its Tronçon (never
  # above the cap), Pokémon by the seals won on the way (0 to 8), with sets
  # (IVs of the lieutenant of those seals).
  GUILD_LEADER_PARTY_SIZES = [4, 4, 4, 5, 5, 5, 6, 6, 6].freeze
  # Its leader beaten (#186), a guild turns on its game switch: GUILD_SWITCH
  # + its rank in guildes.txt (71 and up); the next tickets read it. An
  # ally rallies (a Pokémon of the imposed type, else a shortcut opened,
  # else a field item); the others give an item of the nooks and
  # GUILD_MONEY for each seal won on the way (plus one). An affiliated one
  # (GUILD_FREEING) also frees the nearest town (#187): its inhabitants say
  # the lines of [habitant_libre], the Cousins of the town and of the routes
  # that touch it are gone.
  GUILD_SWITCH   = 70
  # A guild's dungeon (#335, a headquarters' place with gates): a member
  # stands in the corridor of each gate (seeing GUILD_GATE_SIGHT cells
  # ahead), gone once beaten; the others and the leader past the gates. The
  # first member beaten turns on GUILD_LOCK_SWITCH + its rank: the exit says
  # [guilde_sortie] and stops the player until the leader is beaten (a
  # defeat turns those switches off, the player waking at a Centre).
  GUILD_LOCK_SWITCH = 90
  GUILD_LOCKS       = 20   # switches 91 to 110, one guild each at most
  GUILD_GATE_SIGHT  = 4
  GUILD_ALLY     = "alliée"
  GUILD_FREEING  = "affiliée"
  GUILD_MONEY    = 1000
  # A blocking headquarters (#188): in GUILD_BLOCK_CHANCE % of the worlds,
  # one guild of these positions, its headquarters on a route of the chain
  # reached with at least GUILD_BLOCK_SEALS seals, has members standing
  # across the route's exit onward (the inner row of the exit, like the
  # gate of the first town) until its leader is beaten. Lines: [guilde_barrage].
  # Rivalries (#189): once the player has rallied a guild (its switch on),
  # the members of its enemies see GUILD_RAGE_SIGHT cells ahead (never an
  # exit nor a door) and say [guilde_vengeance]; once an enemy's leader is
  # beaten, its members leave the routes and a member of the ally gives one
  # of the items « guilde » of MapProc/Lore/objets.txt by its headquarters.
  GUILD_RAGE_SIGHT  = 6
  # The settling of scores (#190): for each guild with a rallying enemy (its
  # « rivals »), once the ally rallied, its leader waits by the enemy's
  # headquarters for a double battle, side by side with the player against
  # the enemy's leader and its right hand (GUILD_SECOND_SIZES Pokémon of
  # its pool, GUILD_SECOND_GAP levels under its leader). Won, it turns the
  # enemy's switch on, like beating its leader.
  GUILD_SECOND_SIZES = 2..3
  GUILD_SECOND_GAP   = 2
  GUILD_BLOCKING     = %w[affiliée rivale].freeze
  GUILD_BLOCK_CHANCE = 50
  GUILD_BLOCK_SEALS  = 1
  # Obstacles of a shortcut a guild can open (those with an event).
  GUILD_OPENABLE = %w[arbre rocher bloc grappin].freeze
end
