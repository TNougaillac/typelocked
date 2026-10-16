#===============================================================================
# Monotype - Settings
#===============================================================================
module Monotype
  # Types that can't be drawn or chosen (pseudo-types such as ??? are always excluded).
  EXCLUDED_TYPES = [:SHADOW]

  # Starters: 3 drawn at random for each game among the base forms of ROSTER
  # that respect the Monotype rule (006_Roster.rb).
  STARTER_COUNT = 3
  STARTER_LEVEL = 5

  # true: the starter is chosen right after the type, in the start-of-game
  # dialog. false: an event (the professor) calls Monotype.starter_dialog.
  STARTER_AT_SETUP = true

  # Gym and League battles: every trainer on a map whose editor name matches
  # GYM_MAP_PATTERN, and gym leaders, Elite Four and Champion anywhere (trainer
  # type ID matching GYM_LEADER_PATTERN). Only Pokémon of the type can fight them.
  GYM_MAP_PATTERN    = /gym|ar[eè]ne|league|ligue/i
  GYM_LEADER_PATTERN = /\A(LEADER_|ELITEFOUR_|CHAMPION)/
end
