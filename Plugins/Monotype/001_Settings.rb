#===============================================================================
# Monotype - Settings
#===============================================================================
module Monotype
  # Types that can't be drawn or chosen (pseudo-types such as ??? are always excluded).
  EXCLUDED_TYPES = [:SHADOW]

  # Gym and League battles: every trainer on a map whose editor name matches
  # GYM_MAP_PATTERN, and gym leaders, Elite Four and Champion anywhere (trainer
  # type ID matching GYM_LEADER_PATTERN). They end the starter's grace.
  GYM_MAP_PATTERN    = /gym|ar[eè]ne|league|ligue/i
  GYM_LEADER_PATTERN = /\A(LEADER_|ELITEFOUR_|CHAMPION)/
end
