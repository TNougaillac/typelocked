#===============================================================================
# DailyChallenge - Settings
# One world a day, the same for everyone with the same version of the game:
# its seed comes from the computer's date, and so do the imposed type and the
# three starters. As many tries as wanted; the best score of each day is kept.
#===============================================================================
module DailyChallenge
  # Next to the save file, like RunHistory's file.
  FILE_NAME = "DailyChallenge.rxdata"
  # Days whose best score is kept, the most recent first.
  DAYS_KEPT = 30
  # Mixed into the date to make the seed (changing it changes every day's
  # world).
  SEED_SALT = "TypeLocked"
  # Seeds of the worlds, like a random new game (MapProceduralGenerator).
  SEED_RANGE = 1_000_000
  # The type and the starters are drawn from the seed with this mixed in.
  DRAW_SALT = 0x5EED
end
