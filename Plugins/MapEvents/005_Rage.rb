#===============================================================================
# MapEvents - Rage
# A trainer whose name holds « Rage(switch,sight) » (key Rage of a plan) sees
# that many cells ahead once the game switch is on: the « Trainer(n) » of its
# name, read by Essentials for its sight, says so then.
#===============================================================================
class Game_Event
  alias_method :__map_events_name, :name

  def name
    text = __map_events_name
    return text if !text.include?("Rage(") || !$game_switches
    switch, sight = text[/Rage\((\d+),(\d+)\)/, 0] && [$1.to_i, $2.to_i]
    return text if !switch || !$game_switches[switch]
    return text.sub(/trainer\(\d+\)/i, "Trainer(#{sight})")
  end
end
