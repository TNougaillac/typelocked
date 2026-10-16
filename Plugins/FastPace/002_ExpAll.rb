#===============================================================================
# FastPace - Multi Exp. always on, from the very start of the game
# Uses Essentials' own Exp. All (Battle#pbGainExp): with MECHANICS_GENERATION 8,
# every able party member that didn't battle gains half the Exp., like the
# Exp. Share of recent games. Battlers still gain their full share.
#===============================================================================
class Player
  alias __fastpace_has_exp_all has_exp_all
  alias __fastpace_has_running_shoes has_running_shoes

  # Getters, so saves made before the plugin was installed are covered too.
  def has_exp_all
    return true if FastPace::EXP_ALL_ALWAYS_ON
    return __fastpace_has_exp_all
  end

  def has_running_shoes
    return true if FastPace::RUNNING_SHOES_ALWAYS
    return __fastpace_has_running_shoes
  end
end
