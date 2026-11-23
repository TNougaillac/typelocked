#===============================================================================
# FamilyDebt - Settings
# The Family lends money (its usurer, placed in each town by WorldEvents),
# with interest at each trainer won, to be paid back before the next seal.
# Late, its collectors wait on the routes.
#===============================================================================
module FamilyDebt
  # The three loans offered: base x (1 + seals of the player).
  LOANS = [1_000, 3_000, 6_000].freeze
  # Interest (%) added to the debt at each trainer battle won, drawn at the
  # loan. A high rate can make the debt impossible to pay back.
  INTEREST = 2..8
  # Late (a seal won since the loan, the debt not paid back): on entering a
  # route (an outdoor map with wild encounters), COLLECTOR_CHANCE % that a
  # collector stops the player after COLLECTOR_STEPS steps.
  COLLECTOR_CHANCE = 35
  COLLECTOR_STEPS  = 3
  # A collector beaten erases COLLECTOR_CUT % of the debt; lost to, he takes
  # all the player's money (counted against the debt). No whiteout.
  COLLECTOR_CUT = 30
  # His team: Pokémon of the route's encounters, at the level cap (LevelCap)
  # or the player's best level if higher, plus COLLECTOR_LEVEL_BONUS.
  COLLECTOR_TYPES       = %i[COUSIN_M COUSIN_F].freeze
  COLLECTOR_NAMES       = %w[Tonio Sal Vinnie Rocco Lucia Gina Carla Teresa].freeze
  COLLECTOR_PARTY       = 2..3
  COLLECTOR_LEVEL_BONUS = 2
end
