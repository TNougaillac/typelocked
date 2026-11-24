#===============================================================================
# FamilyCasino - Roulette and heads or tails
# Roulette: the 18 types, each red or black in turn; bet on a colour (x2) or
# on a type (x18). Heads or tails: x2.
#===============================================================================
module FamilyCasino
  module_function

  # The roulette's types, in their PBS order (pseudo-types left out).
  def wheel
    types = []
    GameData::Type.each { |type| types.push(type.id) if !type.pseudo_type && type.id != :SHADOW }
    return types
  end

  def colour_of(types, type)
    return types.index(type).even? ? _INTL("rouge") : _INTL("noir")
  end

  def roulette
    bet = choose_bet
    return if !bet
    types = wheel
    names = types.map { |type| GameData::Type.get(type).name }
    case pbMessage(_INTL("Sur quoi tu mises ?"), [_INTL("Rouge (x{1})", COLOUR_PAYOUT), _INTL("Noir (x{1})", COLOUR_PAYOUT),
                                                  _INTL("Un type (x{1})", TYPE_PAYOUT), _INTL("Retour")], 4)
    when 0 then pick = [:colour, _INTL("rouge")]
    when 1 then pick = [:colour, _INTL("noir")]
    when 2
      index = pbMessage(_INTL("Quel type ?"), names + [_INTL("Retour")], names.length + 1)
      return if index >= types.length
      pick = [:type, types[index]]
    else
      return
    end
    $player.coins -= bet
    result = types.sample
    pbMessage(_INTL("La roue tourne...\\wt[16] ... {1}, {2} !", GameData::Type.get(result).name, colour_of(types, result)))
    if pick[0] == :colour && pick[1] == colour_of(types, result)
      win(bet, COLOUR_PAYOUT)
    elsif pick[0] == :type && pick[1] == result
      win(bet, TYPE_PAYOUT)
    else
      pbMessage(_INTL("Perdu. La maison remercie."))
    end
  end

  def coin_flip
    bet = choose_bet
    return if !bet
    side = pbMessage(_INTL("Pile ou face ?"), [_INTL("Pile"), _INTL("Face"), _INTL("Retour")], 3)
    return if side > 1
    $player.coins -= bet
    result = rand(2)
    pbMessage(_INTL("La pièce retombe...\\wt[16] {1} !", result == 0 ? _INTL("Pile") : _INTL("Face")))
    result == side ? win(bet, COIN_FLIP_PAYOUT) : pbMessage(_INTL("Perdu. La maison remercie."))
  end
end
