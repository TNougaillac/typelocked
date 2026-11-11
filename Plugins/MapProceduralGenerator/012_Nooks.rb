#===============================================================================
# MapProceduralGenerator - Obstacles of the nooks and shortcuts
# Once a place is written, the obstacle of its nook or shortcut (a cut tree, a
# cracked rock, a boulder) is copied from its event of the demo (NOOK_EVENTS)
# onto the mouth of the nook. The Grappling Hook's wall gets an event on each
# face, made here (pbMapProcGrapple), and so does each middle tile of the
# corridor of a crossing (ice, mud, a wall to climb, a cycle path:
# pbMapProcCross, #270, #272). The islets, the water and the dark
# caves need no event. The loot itself is left to MapEvents (inventory).
# open_nook_events lets a game switch open an obstacle (a rallied guild, #186).
#===============================================================================
module MapProceduralGenerator
  NOOK_EVENT_PREFIX = "MapProc "

  module_function

  # Writes the obstacles of these nooks (inventory entries [x, y, obstacle,
  # ox, oy], and fx, fy for the Grappling Hook) on that map, after taking away
  # those of an earlier world.
  def write_nook_events(map_id, nooks)
    path = sprintf("Data/Map%03d.rxdata", map_id)
    map = load_data(path)
    map.events.delete_if { |_id, event| event.name.start_with?(NOOK_EVENT_PREFIX) }
    nooks.each do |_x, _y, obstacle, ox, oy, fx, fy|
      if obstacle == GRAPPLE || CROSSINGS[obstacle]
        # Over the wall (along the ice) and one tile past it, from either face
        distance = (fx - ox).abs + (fy - oy).abs + 2
        [[ox, oy], [fx, fy]].each { |x, y| add_crossing_event(map, x, y, distance, obstacle) }
        next
      end
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

  # The obstacles on these cells ([[x, y]]) of that map give way once that
  # game switch is on: a last page, empty and walked through; the Grappling
  # Hook's wall is then crossed without the hook.
  def open_nook_events(map_id, cells, switch)
    path = sprintf("Data/Map%03d.rxdata", map_id)
    map = load_data(path)
    map.events.each_value do |event|
      next if !event.name.start_with?(NOOK_EVENT_PREFIX) || !cells.include?([event.x, event.y])
      if [GRAPPLE_EVENT, *CROSSINGS.values.map { |c| c[:event] }].any? { |name| event.name == NOOK_EVENT_PREFIX + name }
        event.pages[0].list[0].parameters[0].sub!(/\)\z/, ", #{switch})")
        next
      end
      page = RPG::Event::Page.new
      page.through = true
      page.condition.switch1_valid = true
      page.condition.switch1_id = switch
      event.pages.push(page)
    end
    save_data(map, path)
  end

  # An invisible event on a tile of the wall (or of the ice), run by the
  # action button.
  def add_crossing_event(map, x, y, distance, obstacle)
    event = RPG::Event.new(x, y)
    event.id = (map.events.keys.max || 0) + 1
    crossing = CROSSINGS[obstacle]
    name, call = crossing ? [crossing[:event], "pbMapProcCross(#{obstacle.inspect}, #{distance})"] :
                            [GRAPPLE_EVENT, "pbMapProcGrapple(#{distance})"]
    event.name = NOOK_EVENT_PREFIX + name
    event.pages[0].trigger = 0
    event.pages[0].graphic.tile_id = 384 + crossing[:barrier] if crossing&.[](:barrier)
    event.pages[0].list = [RPG::EventCommand.new(355, 0, [call]),
                           RPG::EventCommand.new(0, 0, [])]
    map.events[event.id] = event
  end
end

module MapProceduralGenerator
  # What the player reads at a crossing: without its item, asked, crossing
  CROSSING_TEXTS = {
  "glace" => ["Une plaque de glace très lisse. Avec des patins, on pourrait la traverser.",
              "Une plaque de glace très lisse. Chausser les Patins ?", "{1} chausse les Patins !"],
  "boue"  => ["Une boue épaisse. On s'y enfoncerait sans de bonnes bottes.",
              "Une boue épaisse. Enfiler les Bottes ?", "{1} enfile les Bottes !"],
  "paroi" => ["Une paroi abrupte. Avec des griffes d'escalade, on pourrait la gravir.",
              "Une paroi abrupte. Utiliser les Griffes d'escalade ?", "{1} grimpe avec les Griffes d'escalade !"],
  "piste" => ["Une barrière ferme la piste cyclable. Seuls les vélos passent le portillon.",
              "Une piste cyclable. Prendre le Vélo ?", "{1} enfourche le Vélo !"]
  }.freeze
end

# Crosses the obstacle of a crossing the player faces (CROSSINGS: ice, mud,
# a wall to climb, a cycle path) with its field item: that many tiles,
# through its events. Returns true if the player went across. switch: a game
# switch that, once on, lets the player across without the item (see
# open_nook_events).
def pbMapProcCross(obstacle, distance, switch = nil)
  lent = switch && $game_switches[switch]
  missing, ask, done = MapProceduralGenerator::CROSSING_TEXTS[obstacle]
  if !$DEBUG && !lent && !$bag.has?(MapProceduralGenerator::CROSSINGS[obstacle][:item])
    pbMessage(_INTL(missing))
    return false
  end
  return false if !pbConfirmMessage(_INTL(ask))
  pbMessage(_INTL(done, $player.name))
  x, y = $game_player.x, $game_player.y
  $game_player.walk_anime = false if obstacle == "glace"
  pbMoveRoute($game_player, [PBMoveRoute::FORWARD] * distance)
  pbWait(0.05) while $game_player.move_route_forcing
  $game_player.walk_anime = true
  return $game_player.x != x || $game_player.y != y
end

# Crosses the rock wall the player faces, with the Grappling Hook: a jump of
# that many tiles. Returns true if the player went over. switch: a game
# switch that, once on, lends a hook (a guild's rope, see open_nook_events).
def pbMapProcGrapple(distance, switch = nil)
  lent = switch && $game_switches[switch]
  if !$DEBUG && !lent && !$bag.has?(MapProceduralGenerator::LOCKS[MapProceduralGenerator::GRAPPLE])
    pbMessage(_INTL("Une paroi rocheuse. Avec un grappin, on pourrait la franchir."))
    return false
  end
  return false if !pbConfirmMessage(_INTL("Une paroi rocheuse. Utiliser le Grappin ?"))
  pbMessage(_INTL("{1} utilise le Grappin !", $player.name))
  dx, dy = { 2 => [0, 1], 4 => [-1, 0], 6 => [1, 0], 8 => [0, -1] }[$game_player.direction]
  x, y = $game_player.x, $game_player.y
  pbSEPlay("Player jump")
  $game_player.jump(dx * distance, dy * distance)
  pbWait(0.05) while $game_player.jumping?
  return $game_player.x != x || $game_player.y != y
end
