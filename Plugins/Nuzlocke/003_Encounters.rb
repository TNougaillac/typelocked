#===============================================================================
# Nuzlocke - One capture per zone, duplicates clause, shiny clause
#===============================================================================
module Nuzlocke
  @blocked = {}.compare_by_identity   # Wild Pokémon => reason it can't be caught

  module_function

  def duplicate?(species)
    family = DUPLICATE_BY_FAMILY ? GameData::Species.get(species).get_family_species : [species]
    family.any? { |sp| $player.owned?(sp) }
  end

  # Called before a wild battle starts (wild and scripted encounters alike).
  def evaluate_wild_battle(foes)
    @blocked.clear
    return if !active?
    zone      = current_zone
    zone_free = !data.zone_used?(zone)
    consume   = false
    foes.each do |pkmn|
      next if !pkmn
      if pkmn.shiny?
        consume = true if zone_free && SHINY_CONSUMES_FREE_ZONE
      elsif !zone_free
        @blocked[pkmn] = :zone_used
      elsif duplicate?(pkmn.species)
        @blocked[pkmn] = :duplicate   # Doesn't consume the zone
      else
        consume = true
      end
    end
    data.use_zone(zone) if consume
  end

  def catch_blocked_reason(pkmn)
    active? ? @blocked[pkmn] : nil
  end

  def any_catchable?(foes)
    foes.any? { |pkmn| pkmn && !pkmn.fainted? && !catch_blocked_reason(pkmn) }
  end

  def blocked_message(reason)
    case reason
    when :duplicate then _INTL("Espèce déjà capturée : clause des doublons, capture impossible.")
    else                 _INTL("Cette zone a déjà été utilisée : capture impossible.")
    end
  end

  def clear_battle
    @blocked.clear
  end
end

class Battle
  alias_method :__nuzlocke_pbStartBattle, :pbStartBattle
  def pbStartBattle
    Nuzlocke.evaluate_wild_battle(pbParty(1)) if wildBattle?
    __nuzlocke_pbStartBattle
  end

  # Double battles: refuse the throw at a blocked target and give the ball back.
  alias_method :__nuzlocke_pbThrowPokeBall, :pbThrowPokeBall
  def pbThrowPokeBall(idxBattler, ball, *args)
    battler = opposes?(idxBattler) ? @battlers[idxBattler] : @battlers[idxBattler].pbDirectOpposing(true)
    battler = battler.allAllies[0] if battler.fainted?
    reason = Nuzlocke.catch_blocked_reason(battler.pokemon) if battler
    if reason
      pbDisplay(Nuzlocke.blocked_message(reason))
      $bag.add(ball)
      return
    end
    __nuzlocke_pbThrowPokeBall(idxBattler, ball, *args)
  end
end

# Grey out Poké Balls when no foe can be caught.
# Args: item, pkmn, battler, move, firstAction, battle, scene, showMessages
module ItemHandlers
  class << self
    alias_method :__nuzlocke_triggerCanUseInBattle, :triggerCanUseInBattle
    def triggerCanUseInBattle(item, *args)
      battle = args[4]
      if Nuzlocke.active? && battle&.wildBattle? && GameData::Item.get(item).is_poke_ball? &&
         !Nuzlocke.any_catchable?(battle.pbParty(1))
        foe = battle.pbParty(1).find { |pkmn| pkmn && !pkmn.fainted? }
        args[5]&.pbDisplay(Nuzlocke.blocked_message(Nuzlocke.catch_blocked_reason(foe))) if args[6] != false
        return false
      end
      __nuzlocke_triggerCanUseInBattle(item, *args)
    end
  end
end
