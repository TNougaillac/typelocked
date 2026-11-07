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
  # [x, y] of the exit in the copy of template (a map ID of the demo);
  # arrival: [x, y] where the player lands inside; a room of the League (see
  # LEAGUE_ROOMS): role, onward ([x, y, next room's name, tx, ty]: its door to
  # the next room), and no door nor exit but in the entrance
  Interior = Struct.new(:name, :owner, :kind, :template, :door, :exit, :arrival, :role, :onward, :graphic)
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
      layout.doors.flat_map do |x, y, brick|
        next league_rooms(wp.name, [x, y]) if brick.kind == LEAGUE
        templates = INTERIORS[brick.kind]
        next [] if !templates || NO_INTERIOR.include?(brick.kind)
        count[brick.kind] += 1
        template, ex, ey = templates.sample(random: rng)
        graphic = DOOR_GRAPHICS[brick.rows[brick.door[1]][brick.door[0]]]
        [Interior.new("#{wp.name} - #{brick.kind} #{count[brick.kind]}", wp.name, brick.kind, template, [x, y], [ex, ey], [ex, ey - 1], nil, nil, graphic)]
      end
    end
  end

  # The rooms of the League behind that door, in order, each one's door
  # leading to the next.
  def league_rooms(owner, door)
    names = LEAGUE_ROOMS.map { |role, *| "#{owner} - #{role}" }
    return LEAGUE_ROOMS.each_with_index.map do |(role, template, ax, ay, nx, ny), i|
      onward = nx && [nx, ny, names[i + 1], *LEAGUE_ROOMS[i + 1][2, 2]]
      Interior.new(names[i], owner, LEAGUE, template, (i == 0) ? door : nil, (i == 0) ? LEAGUE_EXIT : nil, [ax, ay], role, onward)
    end
  end

  # [Warps] and [Events] of a place of that size: warps are
  # [x, y, target map name, tx, ty, facing (2, 4, 6, 8), door charset or nil].
  def warps_text(warps, width, height)
    return "" if warps.empty?
    raise Error, "plus de #{WARP_SYMBOLS.length} passages sur une carte" if warps.length > WARP_SYMBOLS.length
    text = +"\n[Warps]\n"
    events = Array.new(height) { "." * width }
    warps.each_with_index do |(x, y, target, tx, ty, facing, graphic), i|
      text << "#{WARP_SYMBOLS[i]} = #{target} #{tx},#{ty} #{WARP_FACING[facing]}#{" porte=#{graphic}" if graphic}\n"
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
  # it had one), its exit back to the door, its door to the next room (that
  # room written first). Returns its map ID.
  def write_interior(interior, map_ids)
    template = load_data(sprintf("Data/Map%03d.rxdata", interior.template))
    map = Marshal.load(Marshal.dump(template))
    map.events = {}
    map.tileset_id = INTERIOR_TILESETS.fetch(map.tileset_id, map.tileset_id)
    owner = map_ids[interior.owner]
    add_warp = lambda do |x, y, target, tx, ty, facing|
      event = RPG::Event.new(x, y)
      event.id = map.events.length + 1
      event.name = MapGenerator::WARP_EVENT_NAME
      event.pages[0].trigger = 1   # Player touch
      event.pages[0].list = [
        RPG::EventCommand.new(201, 0, [0, target, tx, ty, facing, 0]),
        RPG::EventCommand.new(0, 0, [])
      ]
      map.events[event.id] = event
    end
    add_warp.call(*interior.exit, owner, interior.door[0], interior.door[1] + 1, 2) if interior.exit
    if interior.onward
      x, y, target, tx, ty = interior.onward
      add_warp.call(x, y, map_ids[target], tx, ty, 8)
    end
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
