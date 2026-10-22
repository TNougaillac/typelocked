#===============================================================================
# MapProceduralGenerator - Obstacles of the nooks
# Once a place is written, the obstacle of its nook (a cut tree, a cracked
# rock, a boulder) is copied from its event of the demo (NOOK_EVENTS) onto
# the mouth of the nook. The islets and the dark caves need no event (the
# water, the darkness). The loot itself is left to MapEvents (inventory).
#===============================================================================
module MapProceduralGenerator
  NOOK_EVENT_PREFIX = "MapProc "

  module_function

  # Writes the obstacles of these nooks (inventory entries [x, y, obstacle,
  # ox, oy]) on that map, after taking away those of an earlier world.
  def write_nook_events(map_id, nooks)
    path = sprintf("Data/Map%03d.rxdata", map_id)
    map = load_data(path)
    map.events.delete_if { |_id, event| event.name.start_with?(NOOK_EVENT_PREFIX) }
    nooks.each do |_x, _y, obstacle, ox, oy|
      next if !NOOK_EVENTS[obstacle]
      template_id, event_id = NOOK_EVENTS[obstacle]
      template = load_data(sprintf("Data/Map%03d.rxdata", template_id)).events[event_id]
      next if !template
      event = Marshal.load(Marshal.dump(template))
      event.id = (map.events.keys.max || 0) + 1
      event.x, event.y = ox, oy
      # Essentials finds them by name (CutTree, SmashRock, StrengthBoulder)
      event.name = NOOK_EVENT_PREFIX + template.name
      map.events[event.id] = event
    end
    save_data(map, path)
  end
end
