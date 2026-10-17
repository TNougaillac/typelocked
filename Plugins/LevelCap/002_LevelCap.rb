#===============================================================================
# LevelCap - Exp. stops at the current cap
# While a capped gain runs (battle Exp., level items), the Pokémon's growth rate
# is wrapped so its maximum Exp. is the one of the cap level. Essentials then
# clamps the gain itself.
#===============================================================================
module LevelCap
  module_function

  def current
    return nil if !$player
    return CAPS[$player.badge_count]
  end

  def reached?(pkmn)
    cap = current
    return cap && pkmn.level >= cap
  end

  # Runs the block with pkmn's Exp. limited to the cap.
  def apply(pkmn)
    cap = current
    return yield if !cap
    @capped = [pkmn, cap]
    return yield
  ensure
    @capped = nil
  end

  def cap_for(pkmn)
    return @capped[1] if @capped && @capped[0].equal?(pkmn)
    return nil
  end

  class CappedGrowthRate
    def initialize(growth_rate, cap)
      @growth_rate = growth_rate
      @maximum_exp = growth_rate.minimum_exp_for_level(cap)
    end

    attr_reader :maximum_exp

    def add_exp(exp1, exp2)
      return (exp1 + exp2).clamp(0, @maximum_exp)
    end

    def method_missing(name, *args, &block)
      return @growth_rate.send(name, *args, &block)
    end

    def respond_to_missing?(name, include_private = false)
      return @growth_rate.respond_to?(name, include_private) || super
    end
  end
end

class Pokemon
  alias __levelcap_growth_rate growth_rate

  def growth_rate
    ret = __levelcap_growth_rate
    cap = LevelCap.cap_for(self)
    return (cap) ? LevelCap::CappedGrowthRate.new(ret, cap) : ret
  end
end

class Battle
  alias __levelcap_pbGainExpOne pbGainExpOne

  # A Pokémon at the cap gains no Exp. (EVs are still gained).
  def pbGainExpOne(idxParty, *args)
    LevelCap.apply(pbParty(0)[idxParty]) { __levelcap_pbGainExpOne(idxParty, *args) }
  end
end

module ItemHandlers
  class << self
    alias_method :__levelcap_triggerUseOnPokemon, :triggerUseOnPokemon
    alias_method :__levelcap_triggerUseOnPokemonMaximum, :triggerUseOnPokemonMaximum

    def triggerUseOnPokemon(item, qty, pkmn, scene)
      return __levelcap_triggerUseOnPokemon(item, qty, pkmn, scene) if !LevelCap::LEVEL_ITEMS.include?(item)
      if LevelCap.reached?(pkmn)
        scene.pbDisplay(_INTL("{1} ne peut pas dépasser le niveau {2} pour l'instant.",
                              pkmn.name, LevelCap.current))
        return false
      end
      qty = [qty, LevelCap.current - pkmn.level].min if item == :RARECANDY && LevelCap.current
      return LevelCap.apply(pkmn) { __levelcap_triggerUseOnPokemon(item, qty, pkmn, scene) }
    end

    # Exp. Candies: the maximum quantity is computed from the capped Exp.
    def triggerUseOnPokemonMaximum(item, pkmn)
      return __levelcap_triggerUseOnPokemonMaximum(item, pkmn) if !LevelCap::LEVEL_ITEMS.include?(item)
      ret = LevelCap.apply(pkmn) { __levelcap_triggerUseOnPokemonMaximum(item, pkmn) }
      ret = [ret, LevelCap.current - pkmn.level].min if item == :RARECANDY && LevelCap.current
      return [ret, 1].max
    end
  end
end
