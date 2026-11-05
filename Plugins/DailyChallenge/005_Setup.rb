#===============================================================================
# DailyChallenge - The challenge's type and starters
# Before the Monotype dialog: the day's type and three starters, drawn from
# its seed, so every player gets the same. The Nuzlocke stays a free choice
# (a game without it scores less, see RunHistory). A game started in a room
# (Online) is not a challenge.
#===============================================================================
module DailyChallenge
  module_function

  def apply
    return if !active? || Monotype.data.chosen
    if defined?(Online) && Online.multi?
      $daily_challenge = nil
      return
    end
    type, starters = draw(seed_for($daily_challenge), Monotype.available_types,
                          ->(t) { Monotype.data.type = t; Monotype.starter_pool },
                          Monotype::STARTER_COUNT)
    Monotype.activate(type)
    Monotype.data.starters = starters
    pbMessage(_INTL("Défi du {1} : ton type et tes starters sont les mêmes que ceux des autres joueurs.",
                    short_date($daily_challenge)))
  end
end

NewGameSetup.add(:daily_challenge, 15) { DailyChallenge.apply }
