#===============================================================================
# Nuzlocke - Dead Pokémon stay visible in the PC but can't be used
#===============================================================================
class PokemonStorageScreen
  def nuzlocke_refuse_dead?(pkmn)
    return false if !pkmn&.nuzlocke_dead?
    pbDisplay(_INTL("{1} est mort. Il ne peut plus quitter le cimetière.", pkmn.name))
    true
  end

  alias_method :__nuzlocke_pbWithdraw, :pbWithdraw
  def pbWithdraw(selected, heldpoke = nil)
    return false if nuzlocke_refuse_dead?(heldpoke || @storage[selected[0], selected[1]])
    __nuzlocke_pbWithdraw(selected, heldpoke)
  end

  # Box -1 is the party
  alias_method :__nuzlocke_pbPlace, :pbPlace
  def pbPlace(selected)
    return false if selected[0] == -1 && nuzlocke_refuse_dead?(@heldpkmn)
    __nuzlocke_pbPlace(selected)
  end

  alias_method :__nuzlocke_pbSwap, :pbSwap
  def pbSwap(selected)
    return false if selected[0] == -1 && nuzlocke_refuse_dead?(@heldpkmn)
    __nuzlocke_pbSwap(selected)
  end

  alias_method :__nuzlocke_pbRelease, :pbRelease
  def pbRelease(selected, heldpoke = nil)
    return if nuzlocke_refuse_dead?(heldpoke || @storage[selected[0], selected[1]])
    __nuzlocke_pbRelease(selected, heldpoke)
  end
end
