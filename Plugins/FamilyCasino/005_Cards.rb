#===============================================================================
# FamilyCasino - The rules of the card games (#330)
# Plain Ruby (no game window): the CI simulates many hands with them. A card
# is 0..51: suit card / 13 (Fire, Water, Grass, Electric, the rows of
# cards.png), rank card % 13 (0 = 2 ... 8 = 10, 9 Valet, 10 Dame, 11 Roi,
# 12 As, its column).
#===============================================================================
module FamilyCasino
  ACE = 12
  JACK = 9

  module_function

  def new_deck(rng = Random)
    return (0...52).to_a.shuffle(random: rng)
  end

  #-----------------------------------------------------------------------------
  # Blackjack
  #-----------------------------------------------------------------------------
  def card_points(card)
    rank = card % 13
    return 11 if rank == ACE
    return [rank + 2, 10].min
  end

  # Best total of a hand, an Ace counting 1 when 11 would bust it.
  def hand_value(cards)
    total = cards.sum { |card| card_points(card) }
    aces = cards.count { |card| card % 13 == ACE }
    while total > 21 && aces > 0
      total -= 10
      aces -= 1
    end
    return total
  end

  def blackjack?(cards)
    return cards.length == 2 && hand_value(cards) == 21
  end

  # The dealer draws until DEALER_STANDS.
  def dealer_play(hand, deck)
    hand.push(deck.pop) while hand_value(hand) < DEALER_STANDS
    return hand
  end

  # Coins given back for a bet (already paid) once both hands are played.
  def blackjack_return(player, dealer, bet)
    mine = hand_value(player)
    theirs = hand_value(dealer)
    return 0 if mine > 21
    return blackjack?(dealer) ? bet : bet + (bet * BLACKJACK_PAYS[0] / BLACKJACK_PAYS[1]) if blackjack?(player)
    return 0 if blackjack?(dealer)
    return bet * 2 if theirs > 21 || mine > theirs
    return mine == theirs ? bet : 0
  end

  #-----------------------------------------------------------------------------
  # Video poker
  #-----------------------------------------------------------------------------
  # The best paying hand of five cards (a key of POKER_PAYS), nil if none.
  def poker_hand(cards)
    ranks = cards.map { |card| card % 13 }.sort
    flush = cards.map { |card| card / 13 }.uniq.length == 1
    straight = ranks.uniq.length == 5 && (ranks.last - ranks.first == 4 || ranks == [0, 1, 2, 3, ACE])
    counts = ranks.tally.sort_by { |rank, count| [-count, -rank] }
    return :royal_flush if flush && straight && ranks.first == 8
    return :straight_flush if flush && straight
    return :four_of_a_kind if counts[0][1] == 4
    return :full_house if counts[0][1] == 3 && counts[1][1] == 2
    return :flush if flush
    return :straight if straight
    return :three_of_a_kind if counts[0][1] == 3
    return :two_pairs if counts[0][1] == 2 && counts[1][1] == 2
    return :jacks_or_better if counts[0][1] == 2 && counts[0][0] >= JACK
    return nil
  end

  # Coins given back for a bet (already paid).
  def poker_return(cards, bet)
    hand = poker_hand(cards)
    return hand ? bet * POKER_PAYS.to_h[hand] : 0
  end

  # Five cards: the held ones stay, the others are drawn again from the deck.
  def poker_draw(cards, held, deck)
    return cards.each_with_index.map { |card, i| held[i] ? card : deck.pop }
  end
end
