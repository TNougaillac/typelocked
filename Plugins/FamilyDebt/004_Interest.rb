#===============================================================================
# FamilyDebt - Interest
# Each trainer battle won (but a collector's) adds the debt's interest.
#===============================================================================
class << TrainerBattle
  alias_method :__family_debt_start_core, :start_core

  def start_core(*args)
    outcome = __family_debt_start_core(*args)
    FamilyDebt.add_interest if outcome == 1 && !FamilyDebt.collecting?
    return outcome
  end
end
