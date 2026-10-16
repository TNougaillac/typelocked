#===============================================================================
# FastPace - Faster player movement and faster defaults
# Move routes from events (cutscenes) keep the speed they set.
#===============================================================================
class Player
  alias __fastpace_has_running_shoes has_running_shoes

  # Also covers saves made before the plugin was installed.
  def has_running_shoes
    return true if FastPace::RUNNING_SHOES_ALWAYS
    return __fastpace_has_running_shoes
  end
end

class Game_Player
  alias __fastpace_set_movement_type set_movement_type

  def set_movement_type(type)
    __fastpace_set_movement_type(type)
    return if @move_route_forcing || @bumping
    speed = FastPace::MOVE_SPEEDS[type]
    self.move_speed = speed if speed
  end
end

class PokemonSystem
  alias __fastpace_initialize initialize

  def initialize
    __fastpace_initialize
    @runstyle  = FastPace::DEFAULT_RUN_STYLE
    @textspeed = FastPace::DEFAULT_TEXT_SPEED
  end
end
