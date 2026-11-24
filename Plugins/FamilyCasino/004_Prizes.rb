#===============================================================================
# FamilyCasino - The prize counter
# PRIZES, then the machines of PRIZE_MOVES found in items.txt, for coins.
#===============================================================================
module FamilyCasino
  module_function

  # [[item, coins]] on sale.
  def prizes
    list = PRIZES.select { |item, _coins| GameData::Item.exists?(item) }
    GameData::Item.each do |item|
      next if !item.is_machine? || !PRIZE_MOVES.key?(item.move)
      list.push([item.id, PRIZE_MOVES[item.move]])
    end
    return list
  end

  def prize_name(item)
    data = GameData::Item.get(item)
    return data.is_machine? ? _INTL("{1} ({2})", data.name, GameData::Move.get(data.move).name) : data.name
  end

  def prize_counter
    list = prizes
    loop do
      commands = list.map { |item, coins| _INTL("{1} : {2} jetons", prize_name(item), coins.to_s_formatted) } +
                 [_INTL("Retour")]
      index = pbMessage(_INTL("Jetons : {1}. Un lot ?", $player.coins.to_s_formatted), commands, commands.length)
      return if index >= list.length
      item, coins = list[index]
      if $player.coins < coins
        pbMessage(_INTL("Pas assez de jetons."))
        next
      end
      next if !pbConfirmMessage(_INTL("{1} pour {2} jetons ?", prize_name(item), coins.to_s_formatted))
      next if !$bag.can_add?(item)
      $player.coins -= coins
      pbReceiveItem(item)
    end
  end
end
