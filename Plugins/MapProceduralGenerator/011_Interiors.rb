#===============================================================================
# MapProceduralGenerator - Interiors and warps
# Each door of a building leads to its interior: a copy of a map of the demo
# drawn among those of its brick type (INTERIORS), without its events, its
# exit leading back in front of the door. The interiors are maps of the world
# like the others (deleted and drawn again with it). Every warp of a place
# (doors, caves, ferry) goes into one [Warps] section of its plan.
#===============================================================================
module MapProceduralGenerator
  # owner: name of the map with the door; door: [x, y] of the door; exit:
  # [x, y] of the exit in the copy of template (a map ID of the demo)
  Interior = Struct.new(:name, :owner, :kind, :template, :door, :exit)
  # Symbols of the warps in a plan's [Events] (one per warp of a place)
  WARP_SYMBOLS = (("1".."9").to_a + ("a".."z").to_a + ("A".."Z").to_a).freeze
  WARP_FACING = { 2 => "bas", 4 => "gauche", 6 => "droite", 8 => "haut" }.freeze

  module_function

  # The interiors behind the doors of these places ([WorldPlace, Layout, salt]),
  # each place drawing from its own seed.
  def place_interiors(places, seed)
    return places.flat_map do |wp, layout, salt|
      rng = Random.new((seed * 1000) + 300 + salt)
      count = Hash.new(0)
      layout.doors.filter_map do |x, y, brick|
        templates = INTERIORS[brick.kind]
        next if !templates || NO_INTERIOR.include?(brick.kind)
        count[brick.kind] += 1
        template, ex, ey = templates.sample(random: rng)
        Interior.new("#{wp.name} - #{brick.kind} #{count[brick.kind]}", wp.name, brick.kind, template, [x, y], [ex, ey])
      end
    end
  end

  # [Warps] and [Events] of a place of that size: warps are
  # [x, y, target map name, tx, ty, facing (2, 4, 6, 8)].
  def warps_text(warps, width, height)
    return "" if warps.empty?
    raise Error, "plus de #{WARP_SYMBOLS.length} passages sur une carte" if warps.length > WARP_SYMBOLS.length
    text = +"\n[Warps]\n"
    events = Array.new(height) { "." * width }
    warps.each_with_index do |(x, y, target, tx, ty, facing), i|
      text << "#{WARP_SYMBOLS[i]} = #{target} #{tx},#{ty} #{WARP_FACING[facing]}\n"
      events[y][x] = WARP_SYMBOLS[i]
    end
    text << "\n[Events]\n"
    events.each { |row| text << row << "\n" }
    return text
  end

  #-----------------------------------------------------------------------------
  # In game
  #-----------------------------------------------------------------------------
  # Writes the interior as a copy of its template (same map ID as before if
  # it had one), its exit back to the door. Returns its map ID.
  def write_interior(interior, map_ids)
    template = load_data(sprintf("Data/Map%03d.rxdata", interior.template))
    map = Marshal.load(Marshal.dump(template))
    map.events = {}
    owner = map_ids[interior.owner]
    event = RPG::Event.new(*interior.exit)
    event.id = 1
    event.name = MapGenerator::WARP_EVENT_NAME
    event.pages[0].trigger = 1   # Player touch
    event.pages[0].list = [
      RPG::EventCommand.new(201, 0, [0, owner, interior.door[0], interior.door[1] + 1, 2, 0]),
      RPG::EventCommand.new(0, 0, [])
    ]
    map.events[event.id] = event
    infos = load_data("Data/MapInfos.rxdata")
    id = map_ids[interior.name]
    id = nil if id && !infos[id]
    if !id
      id = (infos.keys.max || 0) + 1
      infos[id] = RPG::MapInfo.new
      infos[id].order = (infos.values.map(&:order).max || 0) + 1
    end
    infos[id].name = interior.name
    infos[id].parent_id = owner
    save_data(map, sprintf("Data/Map%03d.rxdata", id))
    save_data(infos, "Data/MapInfos.rxdata")
    return id
  end

  # Map metadata of an interior: that of its template (its battle backdrop...)
  # with the name of its place, a centre being the healing spot of its town.
  def interior_metadata(interior, title, owner_id, lines)
    start = lines.index { |l| l =~ /\A\[0*#{interior.template}\]/ }
    body = []
    if start
      finish = start + 1
      finish += 1 while finish < lines.length && lines[finish] !~ /\A\[|\A#-/
      body = lines[start + 1...finish].reject { |l| l =~ /\A(Name|HealingSpot|MapPosition)\s*=/ || l.strip.empty? }
    end
    body.unshift("Name = #{title}")
    body.push("HealingSpot = #{owner_id},#{interior.door[0]},#{interior.door[1] + 1}") if interior.kind == "centre"
    return body
  end
end
