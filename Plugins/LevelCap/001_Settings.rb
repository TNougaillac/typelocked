#===============================================================================
# LevelCap - Settings
# A Pokémon stops gaining Exp. once it reaches the cap, which rises with each
# seal (badge) won. Pokémon above the cap keep their level.
#===============================================================================
module LevelCap
  # Cap with n seals = level of the strongest Pokémon of LEADERS[n] (the next
  # lieutenant; with 8 seals, the Parrain), read from PBS/trainers.txt.
  # Each entry: [trainer type, name] or [trainer type, name, version].
  LEADERS = [nil, nil, nil, nil, nil, nil, nil, nil, nil]
  # Used when LEADERS[n] is nil or missing from trainers.txt. nil = no cap.
  # Placeholder: Kanto gym leaders of the demo, +2 on the first gym and the
  # others raised by the same factor (16/14).
  FALLBACK_CAPS = [16, 24, 27, 33, 41, 49, 54, 57, 72]
  # Items that give levels or Exp. outside battle, blocked at the cap.
  LEVEL_ITEMS = %i[RARECANDY EXPCANDYXS EXPCANDYS EXPCANDYM EXPCANDYL EXPCANDYXL]
  # Game switch of the postgame (WorldEvents::POSTGAME_SWITCH, #106): no cap
  # once it is on.
  POSTGAME_SWITCH = 65
end
