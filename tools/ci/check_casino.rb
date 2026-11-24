#===============================================================================
# FamilyCasino card games (#330): the rules (hand values, poker hands) on
# known hands, then HANDS simulated hands of blackjack and of video poker with
# a plain strategy. The Family keeps a slight edge: the player gets back
# between MIN_RETURN and 100 % of his bets, and gets something back often
# enough (MIN_WINS % of the hands, a push included) to keep playing.
#===============================================================================
require_relative "lib/ci"

%w[001_Settings 005_Cards].each { |f| require File.join(ROOT, "Plugins", "FamilyCasino", f) }
C = FamilyCasino
SETTINGS = File.join(ROOT, "Plugins", "FamilyCasino", "001_Settings.rb")
HANDS = (ENV["CASINO_HANDS"] || 200_000).to_i
MIN_RETURN = 0.85
MIN_WINS = 30

# Card of a rank (0 = 2 ... 12 = As) and a suit (0..3)
def card(rank, suit = 0) = (suit * 13) + rank

def expect(what, got, wanted)
  CI.error(SETTINGS, nil, "#{what} : #{got.inspect} au lieu de #{wanted.inspect}") if got != wanted
end

#-------------------------------------------------------------------------------
# Rules on known hands
#-------------------------------------------------------------------------------
expect("As + Roi", C.hand_value([card(12), card(11)]), 21)
expect("As + As + 9", C.hand_value([card(12), card(12, 1), card(7)]), 21)
expect("Roi + Dame + 5", C.hand_value([card(11), card(10), card(3)]), 25)
expect("blackjack payé 6:5", C.blackjack_return([card(12), card(11)], [card(8), card(7)], 10), 22)
expect("blackjack contre blackjack", C.blackjack_return([card(12), card(11)], [card(12, 1), card(9)], 10), 10)
expect("égalité", C.blackjack_return([card(8), card(7)], [card(8, 1), card(7, 1)], 10), 10)
expect("croupier sauté", C.blackjack_return([card(8), card(7)], [card(8, 1), card(4), card(11)], 10), 20)
expect("joueur sauté", C.blackjack_return([card(8), card(7), card(11)], [card(8, 1), card(4)], 10), 0)
{
  [card(8), card(9), card(10), card(11), card(12)]                => :royal_flush,
  [card(12), card(0), card(1), card(2), card(3)]                  => :straight_flush,
  [card(5), card(5, 1), card(5, 2), card(5, 3), card(0)]          => :four_of_a_kind,
  [card(5), card(5, 1), card(5, 2), card(0, 3), card(0)]          => :full_house,
  [card(0), card(3), card(5), card(7), card(11)]                  => :flush,
  [card(12), card(0, 1), card(1), card(2), card(3)]               => :straight,
  [card(8, 1), card(9), card(10), card(11), card(12)]             => :straight,
  [card(5), card(5, 1), card(5, 2), card(0, 3), card(1)]          => :three_of_a_kind,
  [card(5), card(5, 1), card(0, 2), card(0, 3), card(1)]          => :two_pairs,
  [card(9), card(9, 1), card(0, 2), card(2, 3), card(4)]          => :jacks_or_better,
  [card(8), card(8, 1), card(0, 2), card(2, 3), card(4)]          => nil,
  [card(11, 1), card(0), card(1), card(2), card(3)]               => nil
}.each { |cards, hand| expect("main #{cards.inspect}", C.poker_hand(cards), hand) }

#-------------------------------------------------------------------------------
# A plain blackjack strategy: double 10 and 11 against a weak card, hit a
# soft 17 or less, stand from 12 against 2..6, from 17 otherwise.
#-------------------------------------------------------------------------------
def soft?(cards)
  aces = cards.count { |c| c % 13 == C::ACE }
  return (cards.sum { |c| C.card_points(c) } - C.hand_value(cards)) / 10 < aces
end

def play_blackjack(rng, bet)
  deck = C.new_deck(rng)
  player = [deck.pop, deck.pop]
  dealer = [deck.pop, deck.pop]
  up = C.card_points(dealer[0])
  if !C.blackjack?(player) && !C.blackjack?(dealer)
    total = C.hand_value(player)
    if [10, 11].include?(total) && up < total
      bet *= 2
      player.push(deck.pop)
    else
      loop do
        total = C.hand_value(player)
        hit = soft?(player) ? total <= 17 : (total < 12 || (total < 17 && up >= 7))
        break if !hit || total >= 21
        player.push(deck.pop)
      end
    end
    C.dealer_play(dealer, deck) if C.hand_value(player) <= 21
  end
  return [bet, C.blackjack_return(player, dealer, bet)]
end

#-------------------------------------------------------------------------------
# A plain video poker strategy: keep a paying hand's cards (all for a straight
# or better), else four to a flush, else a pair, else the Valets and above.
#-------------------------------------------------------------------------------
def poker_holds(cards)
  hand = C.poker_hand(cards)
  return [true] * 5 if %i[royal_flush straight_flush full_house flush straight].include?(hand)
  ranks = cards.map { |c| c % 13 }
  counts = ranks.tally
  return ranks.map { |r| counts[r] >= 2 } if counts.values.max >= 2
  suits = cards.map { |c| c / 13 }.tally
  suit, count = suits.max_by { |_s, n| n }
  return cards.map { |c| c / 13 == suit } if count == 4
  return ranks.map { |r| r >= C::JACK }
end

def play_poker(rng, bet)
  deck = C.new_deck(rng)
  cards = Array.new(5) { deck.pop }
  cards = C.poker_draw(cards, poker_holds(cards), deck)
  return [bet, C.poker_return(cards, bet)]
end

#-------------------------------------------------------------------------------
# Simulation
#-------------------------------------------------------------------------------
{ "Blackjack" => method(:play_blackjack), "Vidéo-poker" => method(:play_poker) }.each_with_index do |(name, game), i|
  rng = Random.new(330 + i)
  bets = 0
  back = 0
  wins = 0
  HANDS.times do
    bet, got = game.call(rng, 10)
    bets += bet
    back += got
    wins += 1 if got > 0
  end
  rate = back.to_f / bets
  share = wins * 100.0 / HANDS
  puts format("%s : %d mains, %.1f %% des mises rendues, %.1f %% de mains payées", name, HANDS, rate * 100, share)
  CI.error(SETTINGS, nil, "#{name} : le joueur gagne en moyenne (#{(rate * 100).round(1)} %)") if rate >= 1
  CI.error(SETTINGS, nil, "#{name} : la banque prend trop (#{(rate * 100).round(1)} % rendus)") if rate < MIN_RETURN
  CI.error(SETTINGS, nil, "#{name} : trop peu de mains payées (#{share.round(1)} %)") if share < MIN_WINS
end
CI.finish("Jeux de cartes du casino")
