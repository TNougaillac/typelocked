#===============================================================================
# Nuzlocke - Settings
#===============================================================================
module Nuzlocke
  # A zone is a map. To merge several maps into one zone, map the secondary
  # map ID to the main one: { secondary_id => main_id }.
  ZONE_GROUPS = {}

  # Duplicates clause compares whole evolution families (true) or species (false).
  DUPLICATE_BY_FAMILY = true

  # Shinies are always catchable. When a shiny is the first encounter of a free
  # zone, it consumes that zone.
  SHINY_CONSUMES_FREE_ZONE = true

  # Name of the graveyard boxes ("Cimetière 1", "Cimetière 2"...).
  GRAVEYARD_NAME = "Cimetière"
end
