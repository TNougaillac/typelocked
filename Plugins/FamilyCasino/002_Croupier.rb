#===============================================================================
# FamilyCasino - The croupier
# FamilyCasino.croupier, from his event: gives a Coin Case the first time,
# then the casino's menu.
#===============================================================================
module FamilyCasino
  module_function

  def croupier
    if !$bag.has?(:COINCASE)
      pbMessage(_INTL("Psst. La Famille tient une petite salle de jeux, ici. Discrète."))
      pbReceiveItem(:COINCASE)
    end
    commands = [_INTL("Jetons"), _INTL("Machines à sous"), _INTL("Voltorbataille"), _INTL("Roulette"),
                _INTL("Pile ou face"), _INTL("Comptoir des lots"), _INTL("Partir")]
    loop do
      index = pbMessage(_INTL("Jetons : {1}. À quoi tu joues ?", $player.coins.to_s_formatted), commands, commands.length)
      case index
      when 0 then buy_coins
      when 1 then pbSlotMachine(SLOT_DIFFICULTY)
      when 2 then pbVoltorbFlip
      when 3 then roulette
      when 4 then coin_flip
      when 5 then prize_counter
      else
        pbMessage(_INTL("Reviens quand tu veux. La maison gagne toujours."))
        return
      end
    end
  end

  def buy_coins
    commands = COIN_PACKS.map { |coins, price| _INTL("{1} jetons : ${2}", coins, price.to_s_formatted) } + [_INTL("Retour")]
    index = pbMessage(_INTL("Argent : ${1}.", $player.money.to_s_formatted), commands, commands.length)
    return if index >= COIN_PACKS.length
    coins, price = COIN_PACKS[index]
    if $player.money < price
      pbMessage(_INTL("Pas assez d'argent. La Famille ne fait pas crédit ici."))
    elsif $player.coins + coins > Settings::MAX_COINS
      pbMessage(_INTL("Ta Boîte Jetons est pleine."))
    else
      $player.money -= price
      $player.coins += coins
      pbSEPlay("Slots coin")
    end
  end

  # A bet among BETS the player can pay, nil if cancelled or none.
  def choose_bet
    bets = BETS.select { |bet| bet <= $player.coins }
    if bets.empty?
      pbMessage(_INTL("Il te faut des jetons pour jouer."))
      return nil
    end
    commands = bets.map { |bet| _INTL("{1} jetons", bet) } + [_INTL("Retour")]
    index = pbMessage(_INTL("Ta mise ?"), commands, commands.length)
    return bets[index]
  end

  def win(bet, payout)
    $player.coins += bet * payout
    pbSEPlay("Slots coin")
    pbMessage(_INTL("Gagné ! Tu remportes {1} jetons.", bet * payout))
  end
end
