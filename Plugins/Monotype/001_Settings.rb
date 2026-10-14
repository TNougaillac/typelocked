#===============================================================================
# Monotype - Settings
#===============================================================================
module Monotype
  # Types that can't be drawn or chosen (pseudo-types such as ??? are always excluded).
  EXCLUDED_TYPES = [:SHADOW]

  # Trainer types of gym leaders (trainer type ID matched against this pattern).
  # Their battle ends the starter's grace.
  GYM_LEADER_PATTERN = /\ALEADER_/
end
