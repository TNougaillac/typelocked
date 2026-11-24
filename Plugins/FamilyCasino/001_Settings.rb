#===============================================================================
# FamilyCasino - Settings
# The Family's casino, after Celadon's Game Corner: coins bought with money
# (at a worse rate), slot machines, Voltorb Flip, roulette, heads or tails,
# blackjack, video poker and a prize counter. Its croupier is placed in some
# towns by WorldEvents.
#===============================================================================
module FamilyCasino
  # Coins sold: [coins, price]. Celadon sells 50 for $1,000.
  COIN_PACKS = [[50, 1_500], [500, 14_000]].freeze
  # Bets (coins) of the roulette and of heads or tails.
  BETS = [10, 50, 100, 500].freeze
  # Roulette: one of the 18 types comes out, each red or black (in turn, in
  # their PBS order). A colour pays COLOUR_PAYOUT x the bet, a type
  # TYPE_PAYOUT x. Heads or tails pays COIN_FLIP_PAYOUT x.
  COLOUR_PAYOUT    = 2
  TYPE_PAYOUT      = 18
  COIN_FLIP_PAYOUT = 2
  # Slot machine difficulty (Essentials: 0 easy to 2 hard).
  SLOT_DIFFICULTY = 2
  # Prize counter: the items of MapProc/Lore/objets.txt with the « casino »
  # source (#331), priced in coins by their rarity (WorldEvents::RARITIES
  # weight => coins). Machines by move, found in items.txt.
  PRIZE_PRICES = { 8 => 300, 4 => 800, 2 => 1_200, 1 => 1_500 }.freeze
  PRIZE_MOVES = { EARTHQUAKE: 4_000, ICEBEAM: 3_000, THUNDERBOLT: 3_000, FLAMETHROWER: 3_000,
                  PSYCHIC: 3_000, SHADOWBALL: 3_000, SURF: 3_000, ENERGYBALL: 3_000 }.freeze
  # Card games (#330), with the deck of Graphics/UI/Casino/cards.png. The
  # Family rigs them a little: the bank keeps a slight edge (checked by
  # tools/ci/check_casino.rb), and its people let it show.
  # Blackjack: the dealer draws to DEALER_STANDS; a blackjack pays
  # BLACKJACK_PAYS (6:5 instead of 3:2); the player may double, never split.
  DEALER_STANDS  = 17
  BLACKJACK_PAYS = [6, 5].freeze
  # Video poker (Jacks or Better): 5 cards, hold some, draw once. Each hand
  # gives back its multiple of the bet (8/5 table, a smaller royal flush).
  POKER_PAYS = [[:royal_flush, 250], [:straight_flush, 50], [:four_of_a_kind, 25], [:full_house, 8],
                [:flush, 5], [:straight, 4], [:three_of_a_kind, 3], [:two_pairs, 2], [:jacks_or_better, 1]].freeze
end
