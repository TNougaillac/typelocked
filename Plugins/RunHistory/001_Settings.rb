#===============================================================================
# RunHistory - Settings
# The last games played, kept outside the save: their world's seed, team and
# progress when they ended (defeat, victory, abandon) or were last saved.
#===============================================================================
module RunHistory
  # Next to the save file (Game.rxdata), never in the game's folder: a new
  # version of the game does not erase it.
  FILE_NAME = "RunHistory.rxdata"
  # Games kept, the most recent first; the BEST_SIZE best scores are kept
  # too, however old (« Meilleurs scores »).
  SIZE      = 20
  BEST_SIZE = 5
  # Outcome of a game: shown in the list.
  OUTCOMES = { playing: "En cours", defeat: "Défaite", victory: "Victoire", abandon: "Abandon" }.freeze
  # Title screen: height of the « Dernières parties » panel (the last game
  # before the saved one, with its team's icons); in the list of every game,
  # height of a card and cards on screen. A dead Pokémon's icon is faded.
  PANEL_HEIGHT = 150
  CARD_HEIGHT  = 104
  CARDS_SHOWN  = 3
  DEAD_OPACITY = 110

  # Score of a game: points for each seal, Ancien, the Parrain and Arceus
  # beaten, for each trainer and gym member beaten (lieutenants, Anciens and
  # the Parrain only count above), less for each dead Pokémon (Nuzlocke). A
  # victory adds SPEED_BONUS less SPEED_BONUS_MINUTE per minute played (at
  # least 0). Then times the type's multiplier, and NO_NUZLOCKE without the
  # Nuzlocke. A defeat or an abandon keeps the score reached.
  SEAL_POINTS        = 100
  ELDER_POINTS       = 150
  PARRAIN_POINTS     = 300
  ARCEUS_POINTS      = 500
  TRAINER_POINTS     = 5
  MEMBER_POINTS      = 20
  DEATH_POINTS       = -25
  SPEED_BONUS        = 1000
  SPEED_BONUS_MINUTE = 1
  NO_NUZLOCKE        = 0.5
  TYPE_MULTIPLIERS = {
    NORMAL: 1.0, FIRE: 1.0, WATER: 1.0, GRASS: 1.0, ELECTRIC: 1.0, ICE: 1.0,
    FIGHTING: 1.0, POISON: 1.0, GROUND: 1.0, FLYING: 1.0, PSYCHIC: 1.0, BUG: 1.0,
    ROCK: 1.0, GHOST: 1.0, DRAGON: 1.0, DARK: 1.0, STEEL: 1.0, FAIRY: 1.0
  }.freeze
  # Trainer events made by MapEvents: a gym member, or a boss counted by its
  # seal or its switch (not as a trainer).
  MEMBER_EVENT = /MapEvents Membre/
  BOSS_EVENT   = /MapEvents (Lieutenant|Ancien|Parrain)/
end
