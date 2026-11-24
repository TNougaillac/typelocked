#===============================================================================
# FamilyDebt - The collectors
# Late with the debt: on entering a route, COLLECTOR_CHANCE % that a collector
# stops the player after COLLECTOR_STEPS steps (once per visit). Beaten, he
# erases COLLECTOR_CUT % of the debt; lost to, he takes all the money.
#===============================================================================
module FamilyDebt
  module_function

  def collecting?
    return @collecting ? true : false
  end

  # Steps left before this route's collector (nil: none on this visit).
  def entered_map
    @collector_steps = nil
    return if !late? || !route?
    @collector_steps = COLLECTOR_STEPS if rand(100) < COLLECTOR_CHANCE
  end

  def route?
    return false if !$game_map.metadata&.outdoor_map
    return !GameData::Encounter.get($game_map.map_id, $PokemonGlobal.encounter_version).nil?
  end

  def step_taken
    return if !@collector_steps || pbMapInterpreterRunning? || $game_temp.in_menu
    @collector_steps -= 1
    return if @collector_steps > 0
    @collector_steps = nil
    collector_battle if late?
  end

  def collector_team
    encounters = GameData::Encounter.get($game_map.map_id, $PokemonGlobal.encounter_version)
    species = encounters.types.values.flatten(1).map { |slot| slot[1] }.uniq
    level = [LevelCap.current || 1, $player.party.map(&:level).max || 1].max + COLLECTOR_LEVEL_BONUS
    level = level.clamp(1, GameData::GrowthRate.max_level)
    return Array.new(rand(COLLECTOR_PARTY)) { Pokemon.new(species.sample, level) }
  end

  def collector_battle
    trainer = NPCTrainer.new(COLLECTOR_NAMES.sample, COLLECTOR_TYPES.sample)
    trainer.party = collector_team
    trainer.lose_text = _INTL("Ça ne change rien. Tu dois toujours payer.")
    pbMessage(_INTL("Un Cousin te barre la route. « La Famille veut son argent. ${1}, tout de suite. »",
                    debt.amount.to_s_formatted))
    setBattleRule("canLose")
    @collecting = true
    outcome = TrainerBattle.start_core(trainer)
    @collecting = false
    if outcome == 1
      cut = (debt.amount * COLLECTOR_CUT / 100.0).ceil
      left = pay_off(cut)
      pbMessage(left == 0 ? _INTL("Le Cousin efface ta dette. « Ne reviens pas. »") :
                            _INTL("Le Cousin efface ${1} de ta dette. Il reste ${2}.", cut.to_s_formatted, left.to_s_formatted))
    else
      taken = [$player.money, debt.amount].min
      $player.money = 0
      left = pay_off(taken)
      pbMessage(_INTL("Le Cousin vide tes poches : ${1}. Il reste ${2} à payer.", taken.to_s_formatted, left.to_s_formatted))
    end
  ensure
    @collecting = false
  end
end

EventHandlers.add(:on_enter_map, :family_debt_collector,
  proc { |_old_map_id| FamilyDebt.entered_map }
)

EventHandlers.add(:on_player_step_taken, :family_debt_collector,
  proc { FamilyDebt.step_taken }
)
