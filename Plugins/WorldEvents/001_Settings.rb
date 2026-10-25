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
  # The clerk of each shop template ([x, y]), a member of the Family.
  MART_CLERK = { 25 => [2, 3], 54 => [2, 3] }.freeze
  CLERK_GRAPHIC = "trainer_GENTLEMAN"
  # Stock of a shop by the seals won on the way there: each line adds its
  # items from that number of seals on.
  MART_STOCK = {
    0 => %i[POKEBALL POTION ANTIDOTE PARALYZEHEAL REPEL ESCAPEROPE],
    1 => %i[AWAKENING BURNHEAL ICEHEAL],
    2 => %i[GREATBALL SUPERPOTION SUPERREPEL REVIVE],
    4 => %i[ULTRABALL HYPERPOTION FULLHEAL MAXREPEL],
    6 => %i[MAXPOTION],
    7 => %i[FULLRESTORE]
  }.freeze

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
  # Pokémon of a trainer by the seals won on the way (0 to 8).
  PARTY_SIZES = [1..2, 1..2, 2..3, 2..3, 3..4, 3..4, 4..5, 4..6, 5..6].freeze
  # Their levels: up to the highest of the zone's wild Pokémon, this much less.
  PARTY_LEVEL_SPREAD = 2
  # Trainer types by ambiance of the route (nil: grass), mountain and cave.
  TRAINER_TYPES = {
    nil               => %i[YOUNGSTER LASS CAMPER PICNICKER BUGCATCHER BIRDKEEPER POKEMONBREEDER],
    "verdoyante"      => %i[CAMPER PICNICKER BUGCATCHER POKEMONRANGER_M POKEMONRANGER_F],
    "prairie"         => %i[LASS YOUNGSTER AROMALADY BIRDKEEPER PAINTER],
    "sable"           => %i[RUINMANIAC HIKER PICNICKER CAMPER],
    "minérale"        => %i[HIKER BLACKBELT CRUSHGIRL ENGINEER],
    "terre battue"    => %i[CAMPER PICNICKER BIKER ROCKER],
    "automne"         => %i[PAINTER LADY GENTLEMAN BIRDKEEPER],
    "forêt tropicale" => %i[BUGCATCHER AROMALADY POKEMONRANGER_M POKEMONRANGER_F],
    "montagne"        => %i[HIKER BLACKBELT CRUSHGIRL],
    "grotte"          => %i[HIKER POKEMANIAC SUPERNERD ENGINEER]
  }.freeze
  COUSIN_TYPES = %i[COUSIN_M COUSIN_F].freeze
  # Women's types (the others are men's), for their names.
  FEMALE_TYPES = %i[LEADER_Misty LEADER_Erika LEADER_Sabrina ELITEFOUR_Lorelei ELITEFOUR_Agatha LASS PICNICKER
                    POKEMONBREEDER POKEMONRANGER_F AROMALADY PAINTER CRUSHGIRL LADY COUSIN_F].freeze
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
  # Trainer types of the lieutenants (gym leaders for the Monotype), one per
  # gym, and of the members of the gyms.
  LEADER_TYPES = %i[LEADER_Brock LEADER_Misty LEADER_Surge LEADER_Erika LEADER_Koga LEADER_Sabrina
                    LEADER_Blaine LEADER_Giovanni].freeze
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

  # The rooms of the League (LEAGUE_ROOMS of MapProceduralGenerator), by
  # template: where the fighter stands, and the cell in front of the door to
  # the next room, closed until the room is won.
  LEAGUE_LAYOUTS = { 37 => { boss: [6, 6], gate: [6, 3] } }.freeze
  # Game switch turned on by the n-th fight of the League (Anciens 1 to 4,
  # Parrain, Arceus): LEAGUE_SWITCH + n, 59 to 64.
  LEAGUE_SWITCH = 58
  # The four Anciens: their trainer types (Elite Four for the Monotype), one
  # drawn type each, never the same; their Pokémon.
  ELDER_TYPES = %i[ELITEFOUR_Lorelei ELITEFOUR_Bruno ELITEFOUR_Agatha ELITEFOUR_Lance].freeze
  ELDER_PARTY_SIZES = [5, 5, 6, 6].freeze
  # The Parrain (Champion for the Monotype): no type, the most evolved
  # Pokémon of the roster, the strongest at the cap with every seal.
  PARRAIN_TYPE = :CHAMPION
  PARRAIN_PARTY_SIZE = 6
  # Arceus, boss of OverworldBoss: this many levels above the Parrain's top.
  ARCEUS_GRAPHIC = "boss_ARCEUS"
  ARCEUS_LEVEL_BONUS = 5
  ARCEUS_BOSS = { stats: { HP: 3, ATTACK: 1.2, SPECIAL_ATTACK: 1.2 },
                  moves: %i[JUDGMENT EXTREMESPEED RECOVER COSMICPOWER] }.freeze

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
  # What they are, by the seals won before the map: the table of the highest
  # line at most that many seals, item => weight. TM: a TM of the game drawn
  # at random (never twice, nor a lieutenant's).
  ITEM_TABLE = {
    0 => { POTION: 10, POKEBALL: 10, ANTIDOTE: 4, PARALYZEHEAL: 4, ORANBERRY: 6, PECHABERRY: 3,
           CHERIBERRY: 3, REPEL: 3, ESCAPEROPE: 2, TM: 1 },
    2 => { SUPERPOTION: 10, GREATBALL: 8, POKEBALL: 3, AWAKENING: 3, BURNHEAL: 3, ICEHEAL: 3,
           SITRUSBERRY: 5, REVIVE: 3, ETHER: 3, SUPERREPEL: 3, TM: 3, FIRESTONE: 1, WATERSTONE: 1,
           THUNDERSTONE: 1, LEAFSTONE: 1, MOONSTONE: 1, RARECANDY: 1, NUGGET: 1 },
    4 => { HYPERPOTION: 8, ULTRABALL: 8, FULLHEAL: 5, REVIVE: 5, LUMBERRY: 4, SITRUSBERRY: 4,
           ELIXIR: 3, MAXREPEL: 3, TM: 4, RARECANDY: 2, PPUP: 2, NUGGET: 2, PROTEIN: 1, IRON: 1,
           CALCIUM: 1, ZINC: 1, CARBOS: 1, SUNSTONE: 1, DUSKSTONE: 1, SHINYSTONE: 1, DAWNSTONE: 1, ICESTONE: 1 },
    6 => { MAXPOTION: 8, FULLRESTORE: 3, ULTRABALL: 8, FULLHEAL: 4, MAXREVIVE: 3, MAXETHER: 3,
           LUMBERRY: 4, TM: 5, RARECANDY: 3, PPUP: 2, BIGNUGGET: 1, HPUP: 1, PROTEIN: 1, IRON: 1,
           CALCIUM: 1, ZINC: 1, CARBOS: 1 }
  }.freeze
  # The loot of a nook, by the seals won when it opens (its map's, or those
  # before the field item that opens it, whichever is more): rarer.
  NOOK_TABLE = {
    0 => { RARECANDY: 3, NUGGET: 3, TM: 4, PPUP: 1, EVERSTONE: 1, MOONSTONE: 1, FIRESTONE: 1,
           WATERSTONE: 1, THUNDERSTONE: 1, LEAFSTONE: 1 },
    4 => { RARECANDY: 4, BIGNUGGET: 2, TM: 4, PPUP: 2, LEFTOVERS: 1, LIFEORB: 1, CHOICESCARF: 1,
           FOCUSSASH: 1, EXPSHARE: 1, LUCKYEGG: 1, HPUP: 1 }
  }.freeze
  # Heart Scales of a world: spread along the way and among the sources, in
  # place of other items.
  HEART_SCALES = 10
  HEART_SCALE  = :HEARTSCALE
  # Move Relearners (a Heart Scale per move): one in a town reached with at
  # most each number of seals (the first one before the 2nd seal).
  RELEARNERS = [1, 4, 7].freeze
  RELEARNER_GRAPHIC = "NPC 13"
  # Inhabitants who give an item, and the member of the Family who gives a
  # field item once the lieutenant of the town is beaten.
  GIFT_GRAPHICS = (1..29).map { |i| format("NPC %02d", i) }.freeze
  FIELD_GRAPHIC = "trainer_COUSIN_M"

  # Inhabitants: by the streets of each town (islands too, not the first
  # town), and in the houses, on these cells of their template ([x, y,
  # facing], where the demo has its people).
  TOWN_HABITANTS  = 2..4
  HOUSE_HABITANTS = 1..2
  HOUSE_BUILDINGS = %w[maison immeuble port special].freeze
  HOUSE_SPOTS = {
    6  => [[7, 4, "bas"]],
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
    "habitant" => PLACE_TOKENS, "dresseur_combat" => PLACE_TOKENS, "dresseur_fin" => BATTLE_TOKENS,
    "cousin_combat" => PLACE_TOKENS, "cousin_fin" => BATTLE_TOKENS,
    "professeur_intro" => %w[joueur type], "professeur_balls" => %w[joueur type],
    "professeur_apres" => %w[joueur type], "ball" => [], "garde" => %w[joueur],
    "vendeur" => [], "maitre_intro" => %w[joueur], "maitre_sans_ecaille" => %w[joueur],
    "maitre_aucun" => %w[joueur], "maitre_fin" => %w[joueur],
    "don" => PLACE_TOKENS, "don_apres" => PLACE_TOKENS, "terrain_attente" => PLACE_TOKENS,
    "terrain_don" => PLACE_TOKENS, "terrain_apres" => PLACE_TOKENS,
    "lieutenant_combat" => PLACE_TOKENS, "lieutenant_fin" => BATTLE_TOKENS,
    "lieutenant_victoire" => PLACE_TOKENS, "lieutenant_ct" => PLACE_TOKENS,
    "membre_combat" => PLACE_TOKENS, "membre_fin" => BATTLE_TOKENS,
    "ancien_combat" => PLACE_TOKENS, "ancien_fin" => BATTLE_TOKENS,
    "parrain_combat" => PLACE_TOKENS, "parrain_fin" => BATTLE_TOKENS,
    "arceus_intro" => PLACE_TOKENS, "arceus_fin" => %w[joueur], "porte_ligue" => %w[joueur]
  }.freeze
end
