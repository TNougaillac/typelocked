#===============================================================================
# FamilyCasino - Settings
# The Family's casino, after Celadon's Game Corner: coins bought with money
# (at a worse rate), slot machines, Voltorb Flip, roulette, heads or tails,
# and a prize counter. Its croupier is placed in some towns by WorldEvents.
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
  # Prize counter: [item, coins]. Machines by move, found in items.txt.
  PRIZES = [[:RARECANDY, 800], [:PPUP, 1_500], [:FIRESTONE, 1_000], [:WATERSTONE, 1_000],
            [:THUNDERSTONE, 1_000], [:LEAFSTONE, 1_000], [:MOONSTONE, 1_000], [:SUNSTONE, 1_000],
            [:ICESTONE, 1_000], [:DUSKSTONE, 1_000], [:DAWNSTONE, 1_000], [:SHINYSTONE, 1_000]].freeze
  PRIZE_MOVES = { EARTHQUAKE: 4_000, ICEBEAM: 3_000, THUNDERBOLT: 3_000, FLAMETHROWER: 3_000,
                  PSYCHIC: 3_000, SHADOWBALL: 3_000, SURF: 3_000, ENERGYBALL: 3_000 }.freeze
end
