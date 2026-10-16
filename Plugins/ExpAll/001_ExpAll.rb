#===============================================================================
# ExpAll - Multi Exp. always on, from the very start of the game
# Uses Essentials' own Exp. All (Battle#pbGainExp): with MECHANICS_GENERATION 8,
# every able party member that didn't battle gains half the Exp., like the
# Exp. Share of recent games. Battlers still gain their full share.
#===============================================================================
module ExpAll
  # false gives back the normal behaviour (Exp. All item / debug toggle).
  ALWAYS_ON = true
end

class Player
  alias __expall_has_exp_all has_exp_all

  # Also covers saves made before the plugin was installed.
  def has_exp_all
    return true if ExpAll::ALWAYS_ON
    return __expall_has_exp_all
  end
end
