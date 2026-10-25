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
  MART_SPEECH = "Bienvenue. La Famille tient ce commerce, comme les autres. Que veux-tu ?"

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
  FEMALE_TYPES = %i[LEADER_Misty LEADER_Erika LEADER_Sabrina LASS PICNICKER POKEMONBREEDER POKEMONRANGER_F AROMALADY PAINTER CRUSHGIRL LADY COUSIN_F].freeze
  TRAINER_NAMES = {
    male:   %w[Paolo Vito Enzo Salvatore Luca Marco Tony Frank Eddie Jimmy Rocco Sal Louis Pierre Julien Hugo
               Matteo Dario Nico Sonny Ray Jack Bobby Lucien Marcel Gino Carlo Franco Angelo Victor],
    female: %w[Giulia Rosa Lucia Carla Sofia Maria Gina Nina Peggy Betty Lola Ruby Claire Margot Elise Chloé
               Anna Teresa Bianca Vera Donna Rita Jeanne Louise Adèle Camille Sylvie Gloria Paula Livia]
  }.freeze
  BATTLE_TEXTS = [
    "Hé, toi ! On ne passe pas sans se battre.",
    "Je t'ai vu arriver. Montre-moi ce que vaut ton équipe.",
    "Un combat ? Ce n'est pas comme si j'avais le choix."
  ].freeze
  END_TEXTS = [
    "Bien joué...",
    "Tu es plus fort que tu n'en as l'air.",
    "D'accord, d'accord. Passe."
  ].freeze
  COUSIN_BATTLE_TEXTS = [
    "La Famille surveille la route. Et toi, je te surveille.",
    "Le Parrain veut savoir de quoi tu es capable."
  ].freeze
  COUSIN_END_TEXTS = [
    "Le Parrain en entendra parler.",
    "Tu as de la chance. Pour l'instant."
  ].freeze

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
  TM_STATUS = %i[SWORDSDANCE CALMMIND BULKUP DRAGONDANCE NASTYPLOT TOXIC WILLOWISP THUNDERWAVE
                 PROTECT SUBSTITUTE LIGHTSCREEN REFLECT ROOST TAILWIND TRICKROOM SPIKES STEALTHROCK
                 TOXICSPIKES QUIVERDANCE SHELLSMASH AGILITY ROCKPOLISH IRONDEFENSE AMNESIA
                 SLEEPPOWDER SPORE HYPNOSIS GLARE DRAININGKISS MOONLIGHT MORNINGSUN SYNTHESIS].freeze
  LEADER_BATTLE = "Tu es arrivé jusqu'à moi. Le Pacte veut que je te mette à l'épreuve."
  LEADER_END    = "La Famille t'a vu combattre. Le territoire suivant t'est ouvert."
  LEADER_WIN    = "\\me[Badge get]Le lieutenant te remet la chevalière de la Famille. Tu la passes à ton doigt."
  LEADER_GIFT   = "Prends aussi cette CT. Elle te servira."
  MEMBER_BATTLES = [
    "Personne ne voit le lieutenant sans passer par moi.",
    "La Famille garde cette arène. Montre ce que tu vaux."
  ].freeze
  MEMBER_ENDS = ["Le lieutenant t'attend.", "Va, il est au fond."].freeze

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

  # What the professor says ({1} = the imposed type; \PN = the player's
  # name). He already told the Pact during the intro (IntroScene). Moved to
  # MapProc/Lore/dialogues.txt with the other texts (#100).
  PROFESSOR_INTRO = [
    "Te voilà, \\PN. Comme promis, j'ai trois Pokémon de type {1} pour toi."
  ].freeze
  PROFESSOR_BALLS = "Ces trois Poké Balls contiennent des Pokémon de ton type. Choisis celui qui t'accompagnera."
  PROFESSOR_AFTER = "Prends soin de ton Pokémon. La Famille garde un œil sur toi, \\PN."
  BALL_TEXT       = "Une Poké Ball du professeur."
  GATE_TEXT       = "Tu ne peux pas partir sans Pokémon. Le professeur t'attend."
  GIFT_TEXTS = [
    "Tiens, prends ça. Moi, je n'en ai plus l'usage.",
    "Tu as l'air d'en avoir besoin plus que moi.",
    "La Famille prend tout, alors autant que ce soit toi qui l'aies.",
    "Je l'ai trouvé près de la route. Il est à toi."
  ].freeze
  GIFT_AFTER = ["Fais-en bon usage.", "Bonne route.", "Ne dis pas à la Famille que ça vient de moi."].freeze
  FIELD_WAIT  = "Tant que le lieutenant de cette ville ne t'a pas reconnu, je n'ai rien pour toi."
  FIELD_GIFT  = "Le lieutenant t'a remis sa chevalière. La Famille t'ouvre la route avec ceci."
  FIELD_AFTER = "Ne déçois pas la Famille."
  RELEARNER_INTRO    = "Je suis le Maître des Capacités. Une Écaille Cœur, et ton Pokémon se souviendra d'une capacité oubliée."
  RELEARNER_NO_SCALE = "Tu n'as pas d'Écaille Cœur. Reviens quand tu en auras une."
  RELEARNER_NONE     = "Aucun de tes Pokémon n'a de capacité à retrouver."
  RELEARNER_DONE     = "Voilà. Merci pour l'Écaille Cœur."
end
