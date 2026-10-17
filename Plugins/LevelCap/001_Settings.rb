#===============================================================================
# LevelCap - Settings
# A Pokémon stops gaining Exp. once it reaches the cap, which rises with each
# seal (badge) won. Pokémon above the cap keep their level.
#===============================================================================
module LevelCap
  # Cap with n seals = level of the strongest Pokémon of LEADERS[n] (the next
  # lieutenant; with 8 seals, the Parrain), read from PBS/trainers.txt.
  # Each entry: [trainer type, name] or [trainer type, name, version].
  LEADERS = [
    [:LEADER_Brock, "Brock"],
    nil, nil, nil, nil, nil, nil, nil,
    [:CHAMPION, "Blue"]
  ]
  # Used when LEADERS[n] is nil or missing from trainers.txt. nil = no cap.
  # Placeholder: Kanto gym leaders of the demo.
  FALLBACK_CAPS = [14, 21, 24, 29, 43, 43, 47, 50, 63]
  # Items that give levels or Exp. outside battle, blocked at the cap.
  LEVEL_ITEMS = %i[RARECANDY EXPCANDYXS EXPCANDYS EXPCANDYM EXPCANDYL EXPCANDYXL]
end
