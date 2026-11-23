#===============================================================================
# FamilyDebt - The debt, saved with the game
# $family_debt: nil, or the current debt (one at a time).
#===============================================================================
module FamilyDebt
  # amount: money owed; rate: interest (%) per trainer won; seals: the
  # player's seals when he borrowed.
  Debt = Struct.new(:amount, :rate, :seals)

  module_function

  def debt
    return $family_debt
  end

  # A seal won since the loan, and the debt not paid back.
  def late?
    return debt && $player.badge_count > debt.seals
  end

  def borrow(amount, rate)
    $family_debt = Debt.new(amount, rate, $player.badge_count)
    $player.money += amount
  end

  # Takes money off the debt; ends it at 0. Returns what is left.
  def pay_off(money)
    return 0 if !debt
    debt.amount = [debt.amount - money, 0].max
    $family_debt = nil if debt.amount == 0
    return debt&.amount || 0
  end

  def add_interest
    return if !debt
    debt.amount += (debt.amount * debt.rate / 100.0).ceil
  end
end

SaveData.register(:family_debt) do
  save_value { $family_debt }
  load_value { |value| $family_debt = value }
  new_game_value { nil }
end
