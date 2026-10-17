#===============================================================================
# LevelCap - Settings
# A Pokémon stops gaining Exp. once it reaches the cap, which rises with each
# seal (badge) won. Pokémon above the cap keep their level.
#===============================================================================
module LevelCap
  # CAPS[n] = maximum level with n seals. A missing entry (or nil) = no cap.
  # Placeholder: level of each lieutenant's strongest Pokémon (Kanto demo
  # trainers), then the Champion/Parrain with 8 seals.
  CAPS = [14, 21, 24, 29, 43, 43, 47, 50, 63]
  # Items that give levels or Exp. outside battle, blocked at the cap.
  LEVEL_ITEMS = %i[RARECANDY EXPCANDYXS EXPCANDYS EXPCANDYM EXPCANDYL EXPCANDYXL]
end
