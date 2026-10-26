#===============================================================================
# Nuzlocke - Permadeath, graveyard boxes, team wipe
#===============================================================================
class Pokemon
  attr_writer :nuzlocke_dead

  def nuzlocke_dead?
    @nuzlocke_dead && Nuzlocke.active?
  end

  alias_method :__nuzlocke_hp_set, :hp=
  def hp=(value)
    __nuzlocke_hp_set(nuzlocke_dead? ? 0 : value)
  end

  alias_method :__nuzlocke_heal_HP, :heal_HP
  def heal_HP
    __nuzlocke_heal_HP if !nuzlocke_dead?
  end
end

module Nuzlocke
  module_function

  def graveyard_name(number)
    "#{GRAVEYARD_NAME} #{number}"
  end

  def create_graveyard_box
    boxes = $PokemonStorage.boxes
    boxes.push(PokemonBox.new(graveyard_name(data.graveyard_boxes.length + 1)))
    boxes.last.background = GRAVEYARD_BACKGROUND
    data.graveyard_boxes.push(boxes.length - 1)
    boxes.length - 1
  end

  def bury(pkmn)
    box = data.graveyard_boxes.find { |b| !$PokemonStorage[b].full? } || create_graveyard_box
    slot = $PokemonStorage[box].pokemon.index(nil)
    $PokemonStorage[box, slot] = pkmn
    with_panel(pkmn) do |panel|
      pbMessage(_INTL("{1} est mort. Il repose désormais dans la boîte {2}.",
                      pkmn.name, $PokemonStorage[box].name)) { panel.update }
    end
  end

  # Shows pkmn's party panel (icon, name, level, HP) above the message.
  def with_panel(pkmn)
    viewport = Viewport.new(0, 0, Graphics.width, Graphics.height)
    viewport.z = 99998
    panel = PokemonPartyPanel.new(pkmn, 1, viewport)
    panel.x = Graphics.width / 4
    panel.y = 96
    yield panel
  ensure
    panel&.dispose
    viewport&.dispose
  end

  # Moves dead party members to the graveyard.
  def bury_dead_party_members
    dead = $player.party.select { |pkmn| pkmn.nuzlocke_dead? }
    return if dead.empty?
    dead.each do |pkmn|
      $player.party.delete(pkmn)
      bury(pkmn)
    end
    check_run_lost
  end

  def living_pokemon?
    all = $player.party + $PokemonStorage.boxes.flat_map { |box| box.pokemon }
    all.any? { |pkmn| pkmn && !pkmn.egg? && !pkmn.nuzlocke_dead? }
  end

  # No living Pokémon left anywhere ends the run; the mode turns off so the
  # adventure can go on.
  def check_run_lost
    return if $player.able_pokemon_count > 0 || living_pokemon?
    pbMessage(_INTL("Plus aucun Pokémon en vie : le run Nuzlocke est perdu."))
    pbMessage(_INTL("Le mode Nuzlocke est désactivé. L'aventure continue normalement."))
    data.active = false
  end

  def blacked_out!
    @blacked_out = true if active?
  end

  # Once the dead are buried, so the save holds the graveyard.
  def save_after_defeat
    return if !@blacked_out
    @blacked_out = false
    return if !SAVE_ON_DEFEAT
    if Game.save
      pbMessage("\\se[]" + _INTL("La partie a été sauvegardée.") + "\\me[GUI save game]\\wtnp[20]")
    else
      pbMessage(_INTL("La sauvegarde a échoué."))
    end
  end
end

alias __nuzlocke_pbStartOver pbStartOver
def pbStartOver(*args)
  __nuzlocke_pbStartOver(*args)
  Nuzlocke.blacked_out!
end

# A fainted player Pokémon is dead at once, even if revived later in the battle.
class Battle::Battler
  alias_method :__nuzlocke_pbFaint, :pbFaint
  def pbFaint(*args)
    __nuzlocke_pbFaint(*args)
    return if !Nuzlocke.active? || !fainted? || !@pokemon
    @pokemon.nuzlocke_dead = true if $player.party.any? { |pkmn| pkmn.equal?(@pokemon) }
  end
end

# Runs after the base handler (evolutions, black out to the last Pokémon Center).
EventHandlers.add(:on_end_battle, :nuzlocke,
  proc { |*_args|
    Nuzlocke.clear_battle
    Nuzlocke.bury_dead_party_members if Nuzlocke.active?
    Nuzlocke.save_after_defeat
  }
)
