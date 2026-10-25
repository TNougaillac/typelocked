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
