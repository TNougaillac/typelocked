#===============================================================================
# RunHistory - Settings
# The last games played, kept outside the save: their world's seed, team and
# progress when they ended (defeat, victory, abandon) or were last saved.
#===============================================================================
module RunHistory
  # Next to the save file (Game.rxdata), never in the game's folder: a new
  # version of the game does not erase it.
  FILE_NAME = "RunHistory.rxdata"
  # Games kept, the most recent first.
  SIZE = 20
  # Outcome of a game: shown in the list.
  OUTCOMES = { playing: "En cours", defeat: "Défaite", victory: "Victoire", abandon: "Abandon" }.freeze
  # Title screen: height of the « Dernières parties » panel (the last game
  # before the saved one, with its team's icons); in the list of every game,
  # height of a card and cards on screen. A dead Pokémon's icon is faded.
  PANEL_HEIGHT = 150
  CARD_HEIGHT  = 104
  CARDS_SHOWN  = 3
  DEAD_OPACITY = 110
end
