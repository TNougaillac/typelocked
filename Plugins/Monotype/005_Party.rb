#===============================================================================
# Monotype - Unusable Pokémon: gifts and trades, lost type, gym battles
#===============================================================================
module Monotype
  module_function

  def unusable_message(pkmn, box)
    _INTL("{1} n'est pas de type {2}. Il est envoyé dans la boîte « {3} » et ne peut pas être utilisé.",
          pkmn.name, type_name, $PokemonStorage[box].name)
  end

  def send_to_pc(pkmn)
    box = $PokemonStorage.pbStoreCaught(pkmn)
    pbMessage(unusable_message(pkmn, box)) if box >= 0
    box >= 0
  end

  # Moves unusable party members to the PC. The party can't be left empty.
  def enforce_party
    return if !active?
    $player.party.reject { |pkmn| usable?(pkmn) }.each do |pkmn|
      break if $player.party.length <= 1 || $PokemonStorage.full?
      next if pkmn.respond_to?(:nuzlocke_dead?) && pkmn.nuzlocke_dead?   # Goes to the graveyard
      $player.party.delete(pkmn)
      send_to_pc(pkmn)
    end
  end

  # Called before each gym or League battle: returns false if no usable Pokémon
  # is in the party (e.g. its only Pokémon lost the type by evolving).
  def gym_check
    return true if !active?
    enforce_party
    return true if $player.party.any? { |pkmn| !pkmn.egg? && usable?(pkmn) }
    pbMessage(_INTL("Seuls les Pokémon de type {1} peuvent combattre dans les arènes et à la Ligue. Reviens avec l'un d'eux dans ton équipe.", type_name))
    false
  end

  def gym_battle?(args)
    map_name = pbGetBasicMapNameFromId($game_map.map_id).dup.force_encoding(Encoding::UTF_8)
    return true if GYM_MAP_PATTERN.match?(map_name)
    args.any? do |arg|
      type = case arg
             when NPCTrainer then arg.trainer_type
             when Array      then arg[0]
             when Symbol     then arg
             end
      type && GYM_LEADER_PATTERN.match?(type.to_s)
    end
  end
end

# Gym and League trainers: the battle doesn't take place without a Pokémon of
# the type in the party (the trainer isn't beaten).
class << TrainerBattle
  alias_method :__monotype_start_core, :start_core
  def start_core(*args)
    return __monotype_start_core(*args) if !Monotype.active? || !Monotype.gym_battle?(args) || Monotype.gym_check
    outcome_variable = $game_temp.battle_rules["outcomeVar"] || 1
    $game_temp.clear_battle_rules
    pbSet(outcome_variable, 0)   # Undecided
    0
  end
end

# Gifts and events (pbAddPokemon, pbAddToParty, pbAddForeignPokemon...): Pokémon
# outside the type go straight to the PC.
alias __monotype_pbStorePokemon pbStorePokemon
def pbStorePokemon(pkmn)
  return __monotype_pbStorePokemon(pkmn) if Monotype.usable?(pkmn) || $PokemonStorage.full?
  pkmn.record_first_moves
  Monotype.send_to_pc(pkmn)
end

# Evolutions, trades, silent gifts, Day Care: checked at the end of each battle
# and at each step.
EventHandlers.add(:on_end_battle, :monotype, proc { |*_args| Monotype.enforce_party })
EventHandlers.add(:on_player_step_taken, :monotype, proc { Monotype.enforce_party })

# Unusable Pokémon stay in the PC.
class PokemonStorageScreen
  def monotype_refuse?(pkmn)
    return false if !pkmn || Monotype.usable?(pkmn)
    pbDisplay(_INTL("{1} n'est pas de type {2}. Il ne peut pas rejoindre l'équipe.",
                    pkmn.name, Monotype.type_name))
    true
  end

  alias_method :__monotype_pbWithdraw, :pbWithdraw
  def pbWithdraw(selected, heldpoke = nil)
    return false if monotype_refuse?(heldpoke || @storage[selected[0], selected[1]])
    __monotype_pbWithdraw(selected, heldpoke)
  end

  # Box -1 is the party
  alias_method :__monotype_pbPlace, :pbPlace
  def pbPlace(selected)
    return false if selected[0] == -1 && monotype_refuse?(@heldpkmn)
    __monotype_pbPlace(selected)
  end

  alias_method :__monotype_pbSwap, :pbSwap
  def pbSwap(selected)
    return false if selected[0] == -1 && monotype_refuse?(@heldpkmn)
    __monotype_pbSwap(selected)
  end
end
