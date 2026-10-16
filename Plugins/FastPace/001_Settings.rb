#===============================================================================
# FastPace - Settings
# The game must be finishable quickly: more Exp., faster movement.
#===============================================================================
module FastPace
  # Multi Exp. always on. false gives back the Exp. All item / debug toggle.
  EXP_ALL_ALWAYS_ON = true
  # Multiplies all Exp. gained in battle. 1 = Essentials' normal amount.
  EXP_MULTIPLIER = 4
  # Running shoes from the start of the game.
  RUNNING_SHOES_ALWAYS = true
  # Defaults for new games (the player can still change them in Options).
  DEFAULT_RUN_STYLE  = 1   # 0 = walk, 1 = run (hold the Back key to walk)
  DEFAULT_TEXT_SPEED = 2   # 0 = slow, 1 = medium, 2 = fast, 3 = instant
  # Player speed per movement type (Game_Character#move_speed: seconds/tile).
  # 3 = 0.25, 4 = 0.125, 5 = 0.1, 6 = 0.05. Missing types keep Essentials' speed.
  # Essentials: walking 3, running 4, cycling 5, surfing 4.
  MOVE_SPEEDS = {
    running:      5,
    cycling:      6,
    cycling_fast: 6,
    surfing:      5,
    surfing_fast: 5
  }
end
