#===============================================================================
# NewGameSetup - Start-of-game dialogs
# Game modes register their choice dialog here; they are shown in order, once
# the player has control or just before the first Pokémon is given.
#===============================================================================
module NewGameSetup
  @dialogs = {}

  module_function

  # Lower order is shown first. The block must return early once its choice
  # is made: it is called again at each step until the player has a Pokémon.
  def add(key, order, &block)
    @dialogs[key] = [order, block]
  end

  def run
    return if !$player || !$player.party.empty?
    @dialogs.values.sort_by(&:first).each { |_, block| block.call }
  end
end

# At the first step once the player has control (no event running)...
EventHandlers.add(:on_player_step_taken, :new_game_setup,
  proc { NewGameSetup.run if !pbMapInterpreterRunning? }
)

# ...or just before the first Pokémon is given, if that comes first.
%i[pbAddPokemon pbAddPokemonSilent pbAddToParty pbAddToPartySilent pbAddForeignPokemon].each do |name|
  Object.class_eval do
    alias_method :"__newgamesetup_#{name}", name
    define_method(name) do |*args|
      NewGameSetup.run
      send(:"__newgamesetup_#{name}", *args)
    end
    private name
  end
end
