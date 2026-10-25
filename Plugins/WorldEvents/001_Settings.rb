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
  FEMALE_TYPES = %i[LASS PICNICKER POKEMONBREEDER POKEMONRANGER_F AROMALADY PAINTER CRUSHGIRL LADY COUSIN_F].freeze
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
end
