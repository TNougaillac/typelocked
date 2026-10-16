#===============================================================================
# MapProceduralGenerator - Whole world
# World file (MapProc/*.txt with a Monde key):
#   Monde    = TypeLocked      (required: region name, as MapGen's World)
#   Region   = 0               (Town Map region, 0 by default)
#   Image    = typelocked.png  (Town Map image drawn by MapGen, optional)
#   Origin   = 1,1             (Town Map square of the grid's top-left)
#   Taille   = 28x18           (required: grid size in Town Map squares)
#   Cell     = 20              (tiles per square, 20 by default)
#   Ville    = ville.txt       (required: place file of the towns)
#   Route    = route.txt       (required: place file of the routes)
#   Villes   = 9               (required: number of towns)
#   Arenes   = 8               (towns with a gym, Villes - 1 at most and by
#                               default: the first town never has one; the
#                               other towns without one are drawn anywhere
#                               in the chain)
#   SansArene = 3, 5           (optional: these towns, counted from the start
#                               of the chain, have no gym either; the others
#                               without one are still drawn at random)
#   Longueur = 2..4            (route length in squares, 2..4 by default)
#   Surf     = 2               (Surf is obtained in a town with a gym, drawn
#                               from the town of that gym onwards, 2 by
#                               default; water that blocks a route only
#                               appears after that town)
#   Chenaux  = 0..2            (routes crossed by a straight channel, only by
#                               surfing; 0 by default)
#   Lacs     = 0..1            (routes crossed by a lake, only by surfing;
#                               0 by default)
#   Grottes  = 0..2            (routes blocked by a rock wall and passed
#                               through a cave; 0 by default)
#   Plongee  = 2               (Dive is obtained in a town with a gym, drawn
#                               from the town of that gym onwards, 2 by
#                               default)
#   Fonds    = 0..1            (water routes with deep water and an underwater
#                               map, after the towns of Surf and Dive; 0 by
#                               default)
#   Noms     = Bourg Typelock, Ville Rubis, ...
#                              (optional town names, in order; "Ville
#                               générée 1"... otherwise; routes are "Route
#                               générée 1"...)
# The towns (2x2 squares) form a chain linked by routes (1 square wide), each
# town a little further from the start, so the gyms come in that order. Each
# place is assembled from its place file with the exits facing its
# neighbours, then MapGen writes the maps, the connections and the Town Map
# from the world plan made here. Only routes of 2 squares or more can be
# crossed by water or a cave. A cave is a map of its own (« Grotte générée
# N », for route N) whose layout Essentials draws from a seed of the world, so
# it is the same on every visit.
#===============================================================================
module MapProceduralGenerator
  World = Struct.new(:file, :name, :region, :image, :origin, :width, :height, :cell,
                     :town_file, :route_file, :towns, :gyms, :route_length, :names, :no_gym,
                     :surf, :channels, :lakes, :caves, :dive, :dives)
  # kind: "ville" or "route"; x, y, w, h in squares; exits: [side, offset]
  # crossing: nil, "chenal", "lac" or "grotte" (routes); surf, dive: the town
  # where Surf, Dive is obtained; deep: a route with a dive spot
  WorldPlace = Struct.new(:symbol, :kind, :name, :x, :y, :w, :h, :exits, :gym, :index, :crossing, :surf,
                          :dive, :deep)
  # text: MapGen world plan; places: [WorldPlace, Place, MapGen plan text, Layout];
  # caves: [WorldPlace of the route, name, MapGen plan text, seed of its layout];
  # seabeds: [WorldPlace of the route, name, MapGen plan text]
  WorldResult = Struct.new(:text, :places, :caves, :seabeds)

  TOWN_SIZE = 2
  TOWN_SYMBOLS = ("A".."Z").to_a
  ROUTE_SYMBOLS = ("1".."9").to_a + ("a".."z").to_a
  DIRECTIONS = { "est" => [1, 0], "ouest" => [-1, 0], "sud" => [0, 1], "nord" => [0, -1] }
  OPPOSITE = { "est" => "ouest", "ouest" => "est", "sud" => "nord", "nord" => "sud" }

  module_function

  def world_file?(path)
    return File.foreach(path, encoding: "UTF-8").any? { |line| line =~ /\A﻿?\s*Monde\s*=/i }
  end

  def parse_world(text, file = "monde")
    world = World.new(file, nil, 0, nil, [0, 0], nil, nil, 20, nil, nil, nil, nil, 2..4, [], [], 2, 0..0, 0..0, 0..0, 2, 0..0)
    text.each_line.with_index(1) do |raw, lineno|
      fail_at = proc { |msg| raise Error, "#{file}, ligne #{lineno} : #{msg}" }
      content = raw.chomp.sub(/#.*\z/, "").strip
      next if content.empty?
      fail_at.call("attendu « Clé = valeur »") unless content =~ /\A(\w+)\s*=\s*(.+)\z/
      key, value = $1, $2.strip
      case key.downcase
      when "monde"    then world.name = value
      when "region"   then world.region = integer(value, fail_at)
      when "image"    then world.image = value
      when "origin"
        fail_at.call("attendu « Origin = x,y »") unless value =~ /\A(\d+)\s*,\s*(\d+)\z/
        world.origin = [$1.to_i, $2.to_i]
      when "taille"
        fail_at.call("attendu « largeur x hauteur », ex. 28x18") unless value =~ /\A(\d+)x(\d+)\z/
        world.width, world.height = $1.to_i, $2.to_i
      when "cell"     then world.cell = integer(value, fail_at)
      when "ville"    then world.town_file = value
      when "route"    then world.route_file = value
      when "villes"   then world.towns = integer(value, fail_at)
      when "arenes"   then world.gyms = integer(value, fail_at)
      when "longueur" then world.route_length = range(value, fail_at)
      when "noms"     then world.names = value.split(",").map(&:strip)
      when "sansarene" then world.no_gym = value.split(",").map { |n| integer(n.strip, fail_at) }
      when "surf"     then world.surf = integer(value, fail_at)
      when "chenaux"  then world.channels = range(value, fail_at)
      when "lacs"     then world.lakes = range(value, fail_at)
      when "grottes"  then world.caves = range(value, fail_at)
      when "plongee"  then world.dive = integer(value, fail_at)
      when "fonds"    then world.dives = range(value, fail_at)
      else fail_at.call("clé inconnue « #{key} »")
      end
    end
    { "Monde" => world.name, "Taille" => world.width, "Ville" => world.town_file,
      "Route" => world.route_file, "Villes" => world.towns }.each do |key, value|
      raise Error, "#{file} : « #{key} » manquant" if !value
    end
    world.gyms ||= world.towns - 1
    if world.gyms > world.towns - 1
      raise Error, "#{file} : « Arenes » dépasse Villes - 1 (la première ville n'a jamais d'arène)"
    end
    if world.no_gym.any? { |n| !(1..world.towns).include?(n) }
      raise Error, "#{file} : « SansArene » attend des numéros de ville entre 1 et #{world.towns}"
    end
    if (world.no_gym | [1]).length > world.towns - world.gyms
      raise Error, "#{file} : « SansArene » et la première ville dépassent Villes - Arenes (#{world.towns - world.gyms})"
    end
    raise Error, "#{file} : « Villes » doit être entre 1 et #{TOWN_SYMBOLS.length}" if !(1..TOWN_SYMBOLS.length).include?(world.towns)
    raise Error, "#{file} : « Longueur » doit commencer à 1 au moins" if world.route_length.min < 1
    raise Error, "#{file} : « Surf » doit valoir 1 au moins" if world.surf < 1
    raise Error, "#{file} : « Plongee » doit valoir 1 au moins" if world.dive < 1
    return world
  end

  # Lays the towns and routes on the grid, then assembles every place.
  # map_ids: name => map ID to overwrite (places of an earlier world).
  def generate_world(world, town, route, bricks, seed, map_ids = {})
    rng = Random.new(seed)
    places = nil
    50.times do
      places = lay_out_world(world, rng)
      break if places
    end
    raise Error, "#{world.file} (graine #{seed}) : impossible de placer #{world.towns} villes dans #{world.width}x#{world.height} cases ; agrandis « Taille »" if !places
    built = places.map do |wp|
      base = (wp.kind == "ville") ? town : route
      place = base.dup
      place.name = wp.name
      place.width, place.height = wp.w * world.cell, wp.h * world.cell
      place.exits = wp.exits
      place.map_id = map_ids[wp.name]
      place.counts = base.counts.dup
      place.counts["arene"] = wp.gym ? 1..1 : 0..0 if wp.kind == "ville" && base.counts.key?("arene")
      place.crossing = wp.crossing
      place.dive = wp.deep
      [wp, place, *generate_world_place(place, bricks, (seed * 1000) + wp.index)]
    end
    caves = built.filter_map do |wp, place, text, layout|
      next if wp.crossing != "grotte"
      name = wp.name.sub("Route", "Grotte")
      doors = layout.doors.select { |_x, _y, brick| brick.kind == CAVE }
      text << cave_warps(name, doors, place)
      [wp, name, cave_text(name, wp.name, doors), (seed * 1000) + 500 + wp.index]
    end
    seabeds = built.filter_map do |wp, place, _text, layout|
      next if !wp.deep
      name = "#{wp.name} (fonds)"
      [wp, name, seabed_text(name, place, layout, Random.new((seed * 1000) + 700 + wp.index))]
    end
    return WorldResult.new(world_text(world, built, seed), built, caves, seabeds)
  end

  # A place whose bricks don't fit (a narrow route cut by a wall or water) is
  # drawn again with another seed derived from its own, so the world stays the
  # same for a given seed. Returns [text, layout].
  def generate_world_place(place, bricks, place_seed)
    4.times do |retry_index|
      _plan, text, layout = generate_place(place, bricks, place_seed + (retry_index * 100_000))
      return text, layout
    rescue Error
      raise if retry_index == 3
    end
  end

  # Steps from the nearest of those cells, for each cell of a w x h map.
  def distances(cells, w, h)
    dist = Array.new(h) { Array.new(w) }
    queue = cells.dup
    queue.each { |x, y| dist[y][x] = 0 }
    until queue.empty?
      x, y = queue.shift
      [[0, -1], [1, 0], [0, 1], [-1, 0]].each do |ox, oy|
        nx, ny = x + ox, y + oy
        next if nx < 0 || ny < 0 || nx >= w || ny >= h || dist[ny][nx]
        dist[ny][nx] = dist[y][x] + 1
        queue.push([nx, ny])
      end
    end
    return dist
  end

  # MapGen plan of the seabed under a route: the same size, open around the
  # deep water (the player surfaces where the water above is deep), rock
  # elsewhere, with a few patches of seaweed.
  def seabed_text(name, place, layout, rng)
    w, h = place.width, place.height
    deep = layout.deep.to_h { |cell| [cell, true] }
    dist = distances(layout.deep, w, h)
    # Open within a reach that changes every 5 tiles, then smoothed
    reach = Array.new((h / 5) + 1) { Array.new((w / 5) + 1) { rng.rand(4..9) } }
    open = Array.new(h) do |y|
      Array.new(w) do |x|
        x > 1 && y > 1 && x < w - 2 && y < h - 2 && dist[y][x] && dist[y][x] <= reach[y / 5][x / 5]
      end
    end
    2.times do
      open = Array.new(h) do |y|
        Array.new(w) do |x|
          next false if x < 2 || y < 2 || x >= w - 2 || y >= h - 2
          next true if deep[[x, y]]
          (-1..1).sum { |oy| (-1..1).count { |ox| open[y + oy][x + ox] } } >= 5
        end
      end
    end
    # Seaweed in a few spots of the open floor, away from the deep water
    floor = (0...h).flat_map { |y| (0...w).select { |x| open[y][x] && !deep[[x, y]] }.map { |x| [x, y] } }
    weed = {}
    rng.rand(1..3).times do
      cx, cy = floor.sample(random: rng) || break
      r = rng.rand(1.5..3.0)
      floor.each { |x, y| weed[[x, y]] = true if ((x - cx)**2) + ((y - cy)**2) <= r * r }
    end
    text = +"# Fonds de #{place.name}, générés par MapProceduralGenerator. On y plonge depuis\n"
    text << "# l'eau profonde de la route, et on remonte là où l'eau au-dessus est profonde.\n"
    text << "Name    = #{name}\n"
    text << "Tileset = #{SEABED_TILESET}\n"
    text << "Ground  = .\n"
    text << SEABED_PALETTE
    text << "\n[Map]\n"
    h.times do |y|
      text << Array.new(w) { |x| open[y][x] ? (weed[[x, y]] ? "s" : ".") : "R" }.join << "\n"
    end
    return text
  end

  # [Warps] and [Events] of a route: each cave entrance leads into the cave
  # (Essentials puts the player in a random room of it).
  def cave_warps(cave, doors, place)
    text = +"\n[Warps]\n"
    events = Array.new(place.height) { "." * place.width }
    doors.each_with_index do |(x, y, _brick), i|
      text << "#{i + 1} = #{cave} 1,1\n"
      events[y][x] = (i + 1).to_s
    end
    text << "\n[Events]\n"
    events.each { |row| text << row << "\n" }
    return text
  end

  # MapGen plan of a cave: an empty floor that Essentials replaces with a random
  # layout, and one exit to each cave entrance of the route.
  def cave_text(name, route, doors)
    text = +"# Grotte de #{route}, générée par MapProceduralGenerator. Essentials\n"
    text << "# dessine la grotte à l'entrée (Dungeon = true), toujours depuis la même graine.\n"
    text << "Name    = #{name}\n"
    text << "Tileset = #{CAVE_TILESET}\n"
    text << "Ground  = .\n"
    text << "\n[Legend]\n. = #{CAVE_FLOOR}\n"
    text << "\n[Warps]\n"
    doors.each_with_index { |(x, y, _brick), i| text << "#{i + 1} = #{route} #{x},#{y + 1} bas\n" }
    text << "\n[Map]\n"
    10.times { text << ("." * 10) << "\n" }
    text << "\n[Events]\n"
    10.times { |y| text << ((y == 1) ? ".1.2......" : "..........") << "\n" }
    return text
  end

  # Returns the WorldPlaces of a chain of towns and routes, or nil if the chain
  # ran into the edges or into itself.
  def lay_out_world(world, rng)
    taken = Array.new(world.height) { Array.new(world.width) }
    places = []
    free = lambda do |x, y, w, h, allowed|
      next false if x < 0 || y < 0 || x + w > world.width || y + h > world.height
      # One empty square around, so that only intended neighbours touch
      (y - 1..y + h).all? do |cy|
        (x - 1..x + w).all? do |cx|
          next true if cx < 0 || cy < 0 || cx >= world.width || cy >= world.height
          taken[cy][cx].nil? || allowed.include?(taken[cy][cx])
        end
      end
    end
    take = lambda do |wp|
      wp.h.times { |dy| wp.w.times { |dx| taken[wp.y + dy][wp.x + dx] = wp } }
      places.push(wp)
    end
    town_name = ->(i) { world.names[i] || "Ville générée #{i + 1}" }
    x = rng.rand(0..world.width - TOWN_SIZE)
    y = rng.rand(0..world.height - TOWN_SIZE)
    current = WorldPlace.new(TOWN_SYMBOLS[0], "ville", town_name.call(0), x, y, TOWN_SIZE, TOWN_SIZE, [], false)
    take.call(current)
    (1...world.towns).each do |i|
      found = DIRECTIONS.keys.shuffle(random: rng).product(world.route_length.to_a.shuffle(random: rng)).find do |side, length|
        rt, nt = route_and_town(current, side, length, rng)
        # The route only touches the current town, the new town only its route
        # (not laid yet, so nothing may be around the new town)
        next false if !free.call(rt.x, rt.y, rt.w, rt.h, [current]) || !free.call(nt.x, nt.y, nt.w, nt.h, [])
        take.call(rt.tap { |r| r.symbol = ROUTE_SYMBOLS[i - 1]; r.name = "Route générée #{i}" })
        take.call(nt.tap { |t| t.symbol = TOWN_SYMBOLS[i]; t.name = town_name.call(i) })
        link(world, current, rt, side, rng)
        link(world, rt, nt, side, rng)
        current = nt
        true
      end
      return nil if !found
    end
    towns = places.select { |p| p.kind == "ville" }
    # The towns without a gym: the first one and the listed ones, then others
    # drawn at random
    no_gym = (world.no_gym | [1]).map { |n| n - 1 }
    others = (0...world.towns).to_a - no_gym
    no_gym += others.sample(world.towns - world.gyms - no_gym.length, random: rng)
    towns.each_with_index { |t, i| t.gym = !no_gym.include?(i) }
    places.each_with_index { |p, i| p.index = i }
    choose_crossings(world, places, rng)
    return places
  end

  # Surf is obtained in a town with a gym, the Surf-th one or a later one;
  # water only blocks routes after that town, so that the player can always go
  # on without surfing before. Caves anywhere.
  def choose_crossings(world, places, rng)
    routes = places.select { |p| p.kind == "route" && [p.w, p.h].max >= 2 }
    candidates = places.select { |p| p.kind == "ville" && p.gym }.drop(world.surf - 1)
    # A town with a water route after it, when water is wanted
    if world.channels.max + world.lakes.max > 0
      wet_after = candidates.select { |t| routes.any? { |r| r.index > t.index } }
      candidates = wet_after if !wet_after.empty?
    end
    surf_town = candidates.sample(random: rng)
    surf_town.surf = true if surf_town
    wet = surf_town ? routes.select { |r| r.index > surf_town.index }.shuffle(random: rng) : []
    rng.rand(world.channels).times { (wet.shift || break).crossing = "chenal" }
    rng.rand(world.lakes).times { (wet.shift || break).crossing = "lac" }
    dry = routes.select { |r| !r.crossing }.shuffle(random: rng)
    rng.rand(world.caves).times { (dry.shift || break).crossing = "grotte" }
    choose_dives(world, places, routes, surf_town, rng)
  end

  # Dive is obtained in a town with a gym, the Plongee-th one or a later one;
  # deep water only on water routes after the towns of Surf and Dive.
  def choose_dives(world, places, routes, surf_town, rng)
    candidates = places.select { |p| p.kind == "ville" && p.gym }.drop(world.dive - 1)
    wet = routes.select { |r| %w[chenal lac].include?(r.crossing) }
    if world.dives.max > 0
      wet_after = candidates.select { |t| wet.any? { |r| r.index > t.index } }
      candidates = wet_after if !wet_after.empty?
    end
    dive_town = candidates.sample(random: rng)
    return if !dive_town
    dive_town.dive = true
    after = [dive_town.index, surf_town&.index || 0].max
    deep = wet.select { |r| r.index > after }.shuffle(random: rng)
    rng.rand(world.dives).times { (deep.shift || break).deep = true }
  end

  # Route of that length leaving the town on that side, and the next town at
  # its far end (both shifted at random along the side).
  def route_and_town(town, side, length, rng)
    dx, dy = DIRECTIONS[side]
    if dx != 0
      ry = town.y + rng.rand(TOWN_SIZE)
      rx = (dx > 0) ? town.x + TOWN_SIZE : town.x - length
      route = WorldPlace.new(nil, "route", nil, rx, ry, length, 1, [], false)
      nx = (dx > 0) ? rx + length : rx - TOWN_SIZE
      ny = ry - rng.rand(TOWN_SIZE)
    else
      rx = town.x + rng.rand(TOWN_SIZE)
      ry = (dy > 0) ? town.y + TOWN_SIZE : town.y - length
      route = WorldPlace.new(nil, "route", nil, rx, ry, 1, length, [], false)
      ny = (dy > 0) ? ry + length : ry - TOWN_SIZE
      nx = rx - rng.rand(TOWN_SIZE)
    end
    return route, WorldPlace.new(nil, "ville", nil, nx, ny, TOWN_SIZE, TOWN_SIZE, [], false)
  end

  # One opening on the edge shared by a and b (b lies on that side of a), at
  # the same spot for both: offsets count from each map's own top/left.
  def link(world, a, b, side, rng)
    horizontal = %w[est ouest].include?(side)
    # The shared stretch of edge, in squares, is the overlap of the two places
    from = horizontal ? [a.y, b.y].max : [a.x, b.x].max
    to = horizontal ? [a.y + a.h, b.y + b.h].min : [a.x + a.w, b.x + b.w].min
    at = (from * world.cell) + rng.rand(4..((to - from) * world.cell) - 4 - STREET_WIDTH)
    a.exits.push([side, at - ((horizontal ? a.y : a.x) * world.cell)])
    b.exits.push([OPPOSITE[side], at - ((horizontal ? b.y : b.x) * world.cell)])
  end

  # MapGen world plan of the generated places. Towns can be flown to, landing
  # in front of their Pokémon Centre.
  def world_text(world, built, seed)
    text = +"# Monde généré par MapProceduralGenerator, graine #{seed}.\n"
    text << "World   = #{world.name}\n"
    text << "Region  = #{world.region}\n"
    text << "Image   = #{world.image}\n" if world.image
    text << "Cell    = #{world.cell}\n"
    text << "Origin  = #{world.origin.join(',')}\n"
    surf = built.find { |wp, *| wp.surf }
    text << "# Surf s'obtient à #{surf[0].name}.\n" if surf
    dive = built.find { |wp, *| wp.dive }
    text << "# Plongée s'obtient à #{dive[0].name}.\n" if dive
    text << "\n[Places]\n"
    built.each do |wp, _place, _text, layout|
      line = "#{wp.symbol} = #{wp.name}  type=#{wp.kind}"
      centre = layout.doors.find { |_x, _y, brick| brick.kind == "centre" }
      line += "  vol=#{centre[0]},#{centre[1] + 1}" if centre
      text << line << "\n"
    end
    text << "\n[World]\n"
    grid = Array.new(world.height) { "." * world.width }
    built.each do |wp, *|
      wp.h.times { |dy| wp.w.times { |dx| grid[wp.y + dy][wp.x + dx] = wp.symbol } }
    end
    grid.each { |row| text << row << "\n" }
    return text
  end
end
