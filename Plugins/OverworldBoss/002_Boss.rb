#===============================================================================
# OverworldBoss - Strong wild Pokémon placed as map events
# Event script: boss_battle(:GYARADOS, 30, stats: { HP: 3, ATTACK: 1.5 },
#                           ability: :INTIMIDATE, moves: [:DRAGONDANCE, :WATERFALL])
#===============================================================================
module OverworldBoss
  # Non-HP stats; HP goes through the Deluxe Battle Kit's hp_level.
  STAT_VARIABLES = {
    ATTACK: :@attack, DEFENSE: :@defense, SPECIAL_ATTACK: :@spatk,
    SPECIAL_DEFENSE: :@spdef, SPEED: :@speed
  }

  module_function

  def create(species, level, stats: {}, ability: nil, moves: nil, immunities: DEFAULT_IMMUNITIES,
             ivs: DEFAULT_IVS, item: nil, nature: nil, shiny: false)
    pkmn = pbGenerateWildPokemon(species, level)
    GameData::Stat.each_main { |s| pkmn.iv[s.id] = ivs }
    pkmn.ability = ability if ability
    pkmn.item    = item if item
    pkmn.nature  = nature if nature
    pkmn.shiny   = shiny
    if moves
      pkmn.forget_all_moves
      moves.each { |move| pkmn.learn_move(move) }
    end
    pkmn.hp_level         = stats[:HP] || 0
    pkmn.stat_multipliers = stats.except(:HP)
    pkmn.immunities       = immunities.dup
    pkmn.calc_stats
    pkmn.hp = pkmn.totalhp
    pkmn
  end

  # Called before the Deluxe Battle Kit resets hp_level and immunities.
  def strip(pkmn)
    return if !pkmn.stat_multipliers
    pkmn.stat_multipliers = nil
    pkmn.ability = nil if !KEEP_ABILITY_ON_CAPTURE   # Back to its natural ability
    pkmn.calc_stats
  end
end

class Pokemon
  attr_accessor :stat_multipliers   # { ATTACK: 1.5, SPEED: 2 }, bosses only
end

module OverworldBoss::PokemonStats
  def calc_stats
    super
    @stat_multipliers&.each do |stat, mult|
      var = OverworldBoss::STAT_VARIABLES[stat]
      instance_variable_set(var, (instance_variable_get(var) * mult).round) if var
    end
  end
end

Pokemon.prepend(OverworldBoss::PokemonStats)

module OverworldBoss::BattleHooks
  def pbStorePokemon(pkmn)
    OverworldBoss.strip(pkmn)
    super
  end
end

Battle.prepend(OverworldBoss::BattleHooks)

class Interpreter
  # The boss can't be fled from. Defeated or caught: sets the event's self
  # switch, so a second page (blank, condition on that switch) hides it.
  # Returns the battle outcome (1 = defeated, 4 = caught).
  def boss_battle(species, level, **options)
    pkmn = OverworldBoss.create(species, level, **options)
    outcome_var = $game_temp.battle_rules["outcomeVar"] || 1
    setBattleRule("cannotRun")
    WildBattle.start(pkmn)
    outcome = pbGet(outcome_var)
    pbSetSelfSwitch(@event_id, OverworldBoss::SELF_SWITCH, true) if [1, 4].include?(outcome)
    outcome
  end
end
