#===============================================================================
# Nuzlocke - Poison in the field
# Replaces the base :poison_party handler (same key). Poison leaves the Pokémon
# at 1 HP, except in hardcore mode where it kills.
#===============================================================================
EventHandlers.add(:on_player_step_taken_can_transfer, :poison_party,
  proc { |handled|
    next if handled[0]
    next if !Settings::POISON_IN_FIELD || $PokemonGlobal.stepcount % 4 != 0
    can_faint = Nuzlocke.active? ? Nuzlocke.hardcore? : Settings::POISON_FAINT_IN_FIELD
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
        if Nuzlocke.active?
          pkmn.nuzlocke_dead = true
          $player.party.delete(pkmn)
          Nuzlocke.bury(pkmn)
        end
      end
      if $player.able_pokemon_count == 0
        handled[0] = true
        Nuzlocke.hardcore? ? Nuzlocke.game_over : pbCheckAllFainted
      end
    end
  }
)
