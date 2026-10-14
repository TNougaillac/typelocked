#===============================================================================
# Monotype - Settings
#===============================================================================
module Monotype
  # Types that can't be drawn or chosen (pseudo-types such as ??? are always excluded).
  EXCLUDED_TYPES = [:SHADOW]

  # Gym battles: every trainer on a map whose editor name matches
  # GYM_MAP_PATTERN, and gym leaders anywhere (trainer type ID matching
  # GYM_LEADER_PATTERN). They end the starter's grace.
  GYM_MAP_PATTERN    = /gym|ar[eè]ne/i
  GYM_LEADER_PATTERN = /\ALEADER_/
end
