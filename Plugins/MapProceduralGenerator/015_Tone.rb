#===============================================================================
# MapProceduralGenerator - Tone of an ambiance
#===============================================================================
# A map whose metadata has a flag of TONE_FLAGS (Flags = DarkForest, written by
# the world for its ambiance, AMBIANCE_FLAGS) is drawn with that tone added
# over the day and night shading: the tiles, the characters and their
# animations (everything pbDayNightTint tints).
module MapProceduralGenerator
  module_function

  # The extra tone of the current map: [red, green, blue, gray], nil if none
  # (looked up once per map metadata: it is asked for every sprite, every
  # frame; a new world reloads the metadata).
  def map_tone
    metadata = $game_map&.metadata
    return @tone if metadata.equal?(@tone_metadata)
    @tone_metadata = metadata
    @tone = metadata && TONE_FLAGS.find { |flag, _tone| metadata.has_flag?(flag) }&.last
    return @tone
  end
end

alias __mapproc_pbDayNightTint pbDayNightTint

def pbDayNightTint(object)
  __mapproc_pbDayNightTint(object)
  return if !$scene.is_a?(Scene_Map)
  red, green, blue, gray = MapProceduralGenerator.map_tone
  return if !red
  tone = object.tone
  tone.set(tone.red + red, tone.green + green, tone.blue + blue, [tone.gray + gray, 255].min)
end
