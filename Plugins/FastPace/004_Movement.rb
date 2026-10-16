#===============================================================================
# FastPace - Faster player movement and faster defaults
# Move routes from events (cutscenes) keep the speed they set.
#===============================================================================
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
