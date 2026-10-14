#===============================================================================
# Nuzlocke - Poison in the field
# Replaces the base :poison_party handler (same key). In Nuzlocke mode, poison
# leaves the Pokémon at 1 HP instead of killing it.
#===============================================================================
EventHandlers.add(:on_player_step_taken_can_transfer, :poison_party,
  proc { |handled|
    next if handled[0]
    next if !Settings::POISON_IN_FIELD || $PokemonGlobal.stepcount % 4 != 0
    can_faint = !Nuzlocke.active? && Settings::POISON_FAINT_IN_FIELD
    flashed = false
    $player.able_party.each do |pkmn|
      next if pkmn.status != :POISON || pkmn.hasAbility?(:IMMUNITY)
      if !flashed
        pbFlash(Color.new(255, 0, 0, 128), 8)
        flashed = true
      end
      pkmn.hp -= 1 if pkmn.hp > 1 || can_faint
      if pkmn.hp == 1 && !can_faint
        pkmn.status = :NONE
        pbMessage(_INTL("{1} a survécu au poison.\\nLe poison a disparu !\\1", pkmn.name))
        next
      elsif pkmn.hp == 0
        pkmn.changeHappiness("faint")
        pkmn.status = :NONE
        pbMessage(_INTL("{1} est K.O. !", pkmn.name))
      end
      if $player.able_pokemon_count == 0
        handled[0] = true
        pbCheckAllFainted
      end
    end
  }
)
