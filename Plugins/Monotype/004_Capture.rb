#===============================================================================
# Monotype - Only Pokémon of the type (or evolving into it) can be caught
#===============================================================================
module Monotype
  module_function

  def blocked_message
    _INTL("Seuls les Pokémon de type {1}, ou qui le deviennent en évoluant, peuvent être capturés.",
          type_name)
  end

  def any_catchable?(foes)
    foes.any? { |pkmn| pkmn && !pkmn.fainted? && catchable?(pkmn) }
  end
end

# Applied to Battle (and the Bug Catching Contest) and to SafariBattle, which
# doesn't inherit from Battle.
module Monotype::BattleHooks
  def pbThrowPokeBall(idxBattler, ball, *args)
    battler = opposes?(idxBattler) ? @battlers[idxBattler] : @battlers[idxBattler].pbDirectOpposing(true)
    battler = battler.allAllies[0] if battler.fainted?
    if battler && !Monotype.catchable?(battler.pokemon)
      pbDisplay(Monotype.blocked_message)
      respond_to?(:ballCount) ? @ballCount += 1 : $bag.add(ball)
      return
    end
    super
  end
end

Battle.prepend(Monotype::BattleHooks)
SafariBattle.prepend(Monotype::BattleHooks)

# Grey out Poké Balls when no foe can be caught.
# Args: item, pkmn, battler, move, firstAction, battle, scene, showMessages
module ItemHandlers
  class << self
    alias_method :__monotype_triggerCanUseInBattle, :triggerCanUseInBattle
    def triggerCanUseInBattle(item, *args)
      battle = args[4]
      if Monotype.active? && battle&.wildBattle? && GameData::Item.get(item).is_poke_ball? &&
         !Monotype.any_catchable?(battle.pbParty(1))
        args[5]&.pbDisplay(Monotype.blocked_message) if args[6] != false
        return false
      end
      __monotype_triggerCanUseInBattle(item, *args)
    end
  end
end
