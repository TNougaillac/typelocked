#===============================================================================
# Nuzlocke - Mandatory nicknames
#===============================================================================
module Nuzlocke
  module_function

  # Asks again until the name is neither empty nor the species name.
  def force_nickname(pkmn)
    species = pkmn.speciesName
    loop do
      name = yield(_INTL("Surnom de {1} ? (obligatoire)", species)).to_s.strip
      if !name.empty? && name.downcase != species.downcase
        pkmn.name = name
        return
      end
      pbMessage(_INTL("En mode Nuzlocke, chaque Pokémon doit recevoir un surnom."))
    end
  end
end

# Captures (Bug Catching Contest: forced when the kept Pokémon is given, through
# pbNicknameAndStore => pbNickname)
module Nuzlocke::BattleNicknameHooks
  def pbStorePokemon(pkmn)
    return super if !Nuzlocke.active? || pkmn.shadowPokemon?
    Nuzlocke.force_nickname(pkmn) { |text| @scene.pbNameEntry(text, pkmn) }
    old_setting = $PokemonSystem.givenicknames
    $PokemonSystem.givenicknames = 1   # Skip the base "nickname?" prompt
    begin
      super
    ensure
      $PokemonSystem.givenicknames = old_setting
    end
  end
end

Battle.prepend(Nuzlocke::BattleNicknameHooks)
SafariBattle.prepend(Nuzlocke::BattleNicknameHooks)

# Gifts and events (pbAddPokemon, pbAddToParty...)
alias __nuzlocke_pbNickname pbNickname
def pbNickname(pkmn)
  return __nuzlocke_pbNickname(pkmn) if !Nuzlocke.active?
  Nuzlocke.force_nickname(pkmn) { |text| pbEnterPokemonName(text, 1, Pokemon::MAX_NAME_SIZE, "", pkmn) }
end
