#===============================================================================
# FrenchTexts - Battle messages
# A move four times as effective (or more) says so: « C'est hyper efficace ! ».
# Loaded before the Deluxe Battle Kit, which aliases this method again for its
# midbattle triggers.
#===============================================================================
module FrenchTexts
  HYPER_EFFECTIVE_MULTIPLIER = Effectiveness::SUPER_EFFECTIVE_MULTIPLIER**2
end

class Battle::Move
  alias_method :__french_pbEffectivenessMessage, :pbEffectivenessMessage

  def pbEffectivenessMessage(user, target, numTargets = 1)
    if target.damageState.typeMod < FrenchTexts::HYPER_EFFECTIVE_MULTIPLIER ||
       is_a?(Battle::Move::FixedDamageMove) || target.damageState.disguise || target.damageState.iceFace
      return __french_pbEffectivenessMessage(user, target, numTargets)
    end
    if numTargets > 1
      @battle.pbDisplay(_INTL("C'est hyper efficace sur {1} !", target.pbThis(true)))
    else
      @battle.pbDisplay(_INTL("C'est hyper efficace !"))
    end
  end
end
