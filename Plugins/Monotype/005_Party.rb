#===============================================================================
# Monotype - Unusable Pokémon: starter grace, gifts and trades, lost type
#===============================================================================
module Monotype
  module_function

  # The first Pokémon received once the mode is on is the starter.
  def claim_starter(pkmn)
    return if !pkmn || !active? || data.starter_claimed
    pkmn.monotype_starter = true
    data.starter_claimed  = true
  end

  def unusable_message(pkmn, box)
    box_name = $PokemonStorage[box].name
    if pkmn.monotype_starter
      _INTL("{1} retourne dans la boîte « {2} » : seuls les Pokémon de type {3} peuvent combattre.",
            pkmn.name, box_name, type_name)
    else
      _INTL("{1} n'est pas de type {2}. Il est envoyé dans la boîte « {3} » et ne peut pas être utilisé.",
            pkmn.name, type_name, box_name)
    end
  end

  def send_to_pc(pkmn)
    box = $PokemonStorage.pbStoreCaught(pkmn)
    pbMessage(unusable_message(pkmn, box)) if box >= 0
    box >= 0
  end

  # Moves unusable party members to the PC. The party can't be left empty.
  def enforce_party
    return if !active?
    claim_starter($player.party[0])
    $player.party.reject { |pkmn| usable?(pkmn) }.each do |pkmn|
      break if $player.party.length <= 1 || $PokemonStorage.full?
      next if pkmn.respond_to?(:nuzlocke_dead?) && pkmn.nuzlocke_dead?   # Goes to the graveyard
      $player.party.delete(pkmn)
      send_to_pc(pkmn)
    end
  end

  # Event script at the first gym's entrance (conditional branch):
  # ends the starter's grace and returns false if no usable Pokémon is in the party.
  def gym_check
    return true if !active?
    data.grace = false
    enforce_party
    return true if $player.party.any? { |pkmn| !pkmn.egg? && usable?(pkmn) }
    pbMessage(_INTL("Seuls les Pokémon de type {1} peuvent combattre dans l'arène.", type_name))
    false
  end
end

# Gifts and events (pbAddPokemon, pbAddToParty, pbAddForeignPokemon...): Pokémon
# outside the type go straight to the PC.
alias __monotype_pbStorePokemon pbStorePokemon
def pbStorePokemon(pkmn)
  Monotype.claim_starter(pkmn) if $player.party.empty?
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
