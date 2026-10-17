#===============================================================================
# FastPace - Exp. multiplier
# Pokemon#base_exp is only read by Battle#pbGainExpOne (Exp. = level x base Exp.
# x modifiers), so scaling it scales every Exp. gain in battle.
#===============================================================================
class Pokemon
  alias __fastpace_base_exp base_exp

  def base_exp
    return __fastpace_base_exp * FastPace::EXP_MULTIPLIER
  end
end
