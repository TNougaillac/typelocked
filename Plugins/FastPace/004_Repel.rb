#===============================================================================
# FastPace - Choice of the next Repel
# When a Repel wears off, the Repels in the Bag are listed with their quantity
# in the message, instead of opening the Bag.
#===============================================================================
EventHandlers.remove(:on_player_step_taken, :repel_counter)
EventHandlers.add(:on_player_step_taken, :repel_counter,
  proc {
    next if $PokemonGlobal.repel <= 0 || $game_player.terrain_tag.ice   # Shouldn't count down if on ice
    $PokemonGlobal.repel -= 1
    next if $PokemonGlobal.repel > 0
    repels = []
    GameData::Item.each { |itm| repels.push(itm.id) if itm.has_flag?("Repel") && $bag.has?(itm.id) }
    if repels.empty?
      pbMessage(_INTL("L'effet du Repousse est terminé !"))
      next
    end
    commands = repels.map { |item| _INTL("{1} ×{2}", GameData::Item.get(item).name, $bag.quantity(item)) }
    commands.push(_INTL("Non"))
    choice = pbMessage(_INTL("L'effet du Repousse est terminé ! En utiliser un autre ?"), commands, commands.length)
    pbUseItem($bag, repels[choice]) if choice < repels.length
  }
)
