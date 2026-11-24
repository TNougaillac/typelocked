#===============================================================================
# DailyChallenge - New Game on the title screen
# New Game asks: today's challenge (its seed set for the new world) or a
# random seed. Playing a seed again from RunHistory's list already set the
# seed: no question then.
#===============================================================================
module DailyChallenge
  module_function

  # True to start the new game (the challenge or a random seed chosen), false
  # to go back to the title screen.
  def new_game_choice
    date = today
    best = bests[date]
    commands = [_INTL("Défi du jour ({1})", short_date(date)), _INTL("Graine au hasard"), _INTL("Retour")]
    case pbMessage(_INTL("Nouvelle partie : quel monde ?"), commands, 3)
    when 0
      pbMessage(_INTL("Défi du {1} : la même région, le même type et les mêmes starters pour tous les joueurs de la version {2}.",
                      short_date(date), generator_version))
      pbMessage(best ? _INTL("Ton meilleur score du jour : {1}.", RunHistory.score_text(best)) :
                       _INTL("Pas encore de score aujourd'hui."))
      return false if !pbConfirmMessage(_INTL("Lancer le défi du jour ?"))
      MapProceduralGenerator.next_game_seed = seed_for(date)
      self.pending = date
      return true
    when 1
      self.pending = nil
      return true
    end
    return false
  end
end

# The seed already set for the next new game (RunHistory's « Rejouer »), nil
# if none: read without changing MapProceduralGenerator.
module MapProceduralGenerator
  class << self
    attr_reader :next_game_seed
  end
end

class PokemonLoad_Scene
  alias_method :__daily_challenge_pbChoose, :pbChoose

  def pbChoose(commands)
    new_game = commands.index(_INTL("New Game"))
    loop do
      choice = __daily_challenge_pbChoose(commands)
      return choice if choice != new_game || MapProceduralGenerator.next_game_seed
      pbPlayDecisionSE
      return choice if DailyChallenge.new_game_choice
    end
  end
end
