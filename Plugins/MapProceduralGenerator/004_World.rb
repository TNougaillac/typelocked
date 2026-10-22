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
#   Montagnes = 0..2           (mountain routes, climbing from level to level
#                               by stairs; 0 by default)
#   GrotteMontagne = 50        (chance in % that a mountain route has a cave,
#                               a dead end; 50 by default)
#   RiviereMontagne = 50       (chance in % that a north-south mountain route
#                               with no crossing has a river alongside the
#                               climb, at the foot of the cliffs; 0 by default)
#   Demesure = 25              (chance in % that a place goes over the top,
#                               see EXCESSES; 0 by default)
#   Ports    = 1..2            (port towns, with the sea on a side with no
#                               exit; a town named Port, Dock or Harbour is
#                               always one, on top of these; 0 by default)
#   Iles     = 50              (chance in % that a port town with a ferry
#                               terminal has a boat to an island, a map of
#                               its own off the grid: a village or a wild
#                               island, see ISLAND_KINDS; 0 by default)
#   IlesArene = 50             (chance in % that the island of a port town
#                               has a gym too: the island is then a village,
#                               and the gym is taken from a town further in
#                               the chain (else from the port), never from
#                               the Surf or Dive town; 0 by default)
#   Plongee  = 3               (Dive is obtained in a town with a gym, drawn
#                               from the town of that gym onwards and after
#                               the Surf town, needed to dive; 3 by default)
#   Fonds    = 0..1            (water routes with deep water and an underwater
#                               map, after the towns of Surf and Dive; 0 by
#                               default)
#   Noms     = Bourg Typelock, Ville Rubis, ...
#                              (optional town names, in order; "Ville
#                               générée 1"... otherwise; routes are "Route
#                               générée 1"...)
#   Toponymie = Lore/noms.txt  (optional: names shown in game, drawn with the
#                               seed from this file, see 008_Names; the map
#                               names otherwise)
# The towns (2x2 squares) form a chain linked by routes (1 square wide), each
# town a little further from the start, so the gyms come in that order. Each
# place is assembled from its place file with the exits facing its
# neighbours, then MapGen writes the maps, the connections and the Town Map
# from the world plan made here. Only routes of 2 squares or more can be
# crossed by water or a cave. A cave is two maps of its own (« Grotte générée
# N » and its « (sous-sol) », for route N), see 006_Caves.rb.
#===============================================================================
module MapProceduralGenerator
  World = Struct.new(:file, :name, :region, :image, :origin, :width, :height, :cell,
                     :town_file, :route_file, :towns, :gyms, :route_length, :names, :no_gym,
                     :surf, :channels, :lakes, :caves, :dive, :dives, :mountains, :mountain_cave, :excess, :mountain_river,
                     :ports, :islands, :island_gyms, :names_file)
  # kind: "ville" or "route"; x, y, w, h in squares; exits: [side, offset]
  # crossing: nil, "chenal", "lac" or "grotte" (routes); surf, dive: the town
  # where Surf, Dive is obtained; deep: a route with a dive spot; mountain: a
  # route climbing by levels (with a crossing or not); cave: a mountain route
  # with a cave; port: the sea side of a port town; island: name of the island
  # its boat goes to; island_gym: the town whose gym went to that island;
  # title, cave_title: names shown in game (see 008_Names); professor: the
  # first town, drawn without its lab (it didn't fit): the professor waits
  # outside
  WorldPlace = Struct.new(:symbol, :kind, :name, :x, :y, :w, :h, :exits, :gym, :index, :crossing, :surf,
                          :dive, :deep, :mountain, :cave, :excess, :river, :port, :island,
                          :island_gym, :title, :cave_title, :professor)
  # text: MapGen world plan; places: [WorldPlace, Place, MapGen plan text, Layout];
  # caves: [WorldPlace of the route, name, MapGen plan text, CaveFloor, excess],
  # one per floor;
  # seabeds: [WorldPlace of the route, name, MapGen plan text];
  # islands: [WorldPlace of the island, WorldPlace of its port, Place,
  # MapGen plan text, Layout]; interiors: Interior (see 011_Interiors.rb)
  WorldResult = Struct.new(:text, :places, :caves, :seabeds, :islands, :interiors)

  TOWN_SIZE = 2
  TOWN_SYMBOLS = ("A".."Z").to_a
  ROUTE_SYMBOLS = ("1".."9").to_a + ("a".."z").to_a
  DIRECTIONS = { "est" => [1, 0], "ouest" => [-1, 0], "sud" => [0, 1], "nord" => [0, -1] }
  OPPOSITE = { "est" => "ouest", "ouest" => "est", "sud" => "nord", "nord" => "sud" }
  # Towns named like a port always are one
  PORT_NAME = /\b(port|dock|harbou?r)\b/i
  # Tiles needed between the sea edge and the exits next to it
  PORT_ROOM = 11

  module_function

  def world_file?(path)
    return File.foreach(path, encoding: "UTF-8").any? { |line| line =~ /\A﻿?\s*Monde\s*=/i }
  end

  def parse_world(text, file = "monde")
    world = World.new(file, nil, 0, nil, [0, 0], nil, nil, 20, nil, nil, nil, nil, 2..4, [], [], 2, 0..0, 0..0, 0..0, 3, 0..0, 0..0, 50, 0, 0, 0..0, 0, 0, nil)
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
      when "toponymie" then world.names_file = value
      when "sansarene" then world.no_gym = value.split(",").map { |n| integer(n.strip, fail_at) }
      when "surf"     then world.surf = integer(value, fail_at)
      when "chenaux"  then world.channels = range(value, fail_at)
      when "lacs"     then world.lakes = range(value, fail_at)
      when "grottes"  then world.caves = range(value, fail_at)
      when "montagnes" then world.mountains = range(value, fail_at)
      when "grottemontagne" then world.mountain_cave = integer(value, fail_at)
      when "demesure" then world.excess = integer(value, fail_at)
      when "rivieremontagne" then world.mountain_river = integer(value, fail_at)
      when "ports"    then world.ports = range(value, fail_at)
      when "iles"     then world.islands = integer(value, fail_at)
      when "ilesarene" then world.island_gyms = integer(value, fail_at)
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
    raise Error, "#{file} : « Plongee » doit dépasser « Surf » (il faut Surf pour plonger)" if world.dive <= world.surf
    return world
  end

  # Lays the towns and routes on the grid, then assembles every place.
  # map_ids: name => map ID to overwrite (places of an earlier world); names:
  # NameTable of the names shown in game (nil = the map names).
  def generate_world(world, town, route, bricks, seed, map_ids = {}, names = nil)
    rng = Random.new(seed)
    places = nil
    50.times do
      places = lay_out_world(world, rng)
      break if places
    end
    raise Error, "#{world.file} (graine #{seed}) : impossible de placer #{world.towns} villes dans #{world.width}x#{world.height} cases ; agrandis « Taille »" if !places
    # Own random numbers: the names don't change the rest of the world
    region = names ? name_world(world, places, names, Random.new((seed * 1000) + 999)) : world.name
    places.each { |wp| wp.title ||= wp.name }
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
      place.mountain = wp.mountain
      place.cave = wp.cave
      place.river = wp.river
      place.port = wp.port
      place.ferry = !wp.island.nil?
      place.excess = wp.excess
      wanted = EXCESSES.dig(wp.excess, :ambiance)
      place.ambiance = wanted if base.ambiances.any? { |a| a.name == wanted }
      place.dive = wp.deep
      # The professor's lab in the first town, left out if it doesn't fit
      place.counts[LAB] = 1..1 if wp.index == 0 && bricks.any? { |b| b.kind == LAB }
      begin
        [wp, place, *generate_world_place(place, bricks, (seed * 1000) + wp.index)]
      rescue Error
        raise if !place.counts.delete(LAB)
        wp.professor = true
        [wp, place, *generate_world_place(place, bricks, (seed * 1000) + wp.index)]
      end
    end
    # Warps of each place by name, written once all are known
    warps = Hash.new { |hash, name| hash[name] = [] }
    caves = built.flat_map do |wp, _place, _text, layout|
      next [] if wp.crossing != "grotte" && !wp.cave
      doors = layout.doors.select { |_x, _y, brick| brick.kind == CAVE }
      next [] if doors.empty?
      rng = Random.new((seed * 1000) + 500 + wp.index)
      excess = side_excess(world, "grotte", rng)
      floors = cave_floors(wp.name.sub("Route", "Grotte"), wp.name, doors, excess, rng)
      warps[wp.name].concat(cave_warps(doors, floors))
      floors.map { |floor| [wp, floor.name, cave_floor_text(floor, wp.name), floor, excess] }
    end
    seabeds = built.filter_map do |wp, place, _text, layout|
      next if !wp.deep
      name = "#{wp.name} (fonds)"
      excess = side_excess(world, "fonds", Random.new((seed * 1000) + 800 + wp.index))
      [wp, name, seabed_text(name, place, layout, Random.new((seed * 1000) + 700 + wp.index), excess), excess]
    end
    islands = built.each_with_index.filter_map do |(wp, place, _text, layout), i|
      next if !wp.island
      island = build_island(world, town, bricks, wp, layout, (seed * 1000) + 900 + wp.index, map_ids)
      if !island
        # No island: no boat is moored, and the town that gave its gym to
        # the island gets it back
        wp.island = nil
        place.ferry = false
        built[i] = [wp, place, *generate_world_place(place, bricks, (seed * 1000) + wp.index)]
        donor = wp.island_gym
        wp.island_gym = nil
        if donor
          donor.gym = true
          j = built.index { |other, *| other.equal?(donor) }
          other = built[j][1]
          other.counts["arene"] = 1..1
          built[j] = [donor, other, *generate_world_place(other, bricks, (seed * 1000) + donor.index)]
        end
        next
      end
      warps[wp.name].push(ferry_warp(layout, island[0].name, island[4]))
      warps[island[0].name].push(ferry_warp(island[4], wp.name, layout))
      island
    end
    interiors = place_interiors(built.map { |wp, _place, _text, layout| [wp, layout, wp.index] } +
                                islands.map { |wp, _port, _place, _text, layout| [wp, layout, 50 + wp.index] }, seed)
    interiors.each { |it| warps[it.owner].push([*it.door, it.name, it.exit[0], it.exit[1] - 1, 8]) }
    built.each { |wp, place, text, _layout| text << warps_text(warps[wp.name], place.width, place.height) }
    islands.each { |wp, _port, place, text, _layout| text << warps_text(warps[wp.name], place.width, place.height) }
    return WorldResult.new(world_text(world, built, seed, caves, seabeds, islands, region), built, caves, seabeds, islands, interiors)
  end

  # The island that the boat of that port town goes to, nil if the town got
  # no ferry terminal or the island could not be built. Half the islands are
  # villages, half are wild; an island with the gym of its port is a village.
  def build_island(world, town, bricks, port_wp, port_layout, island_seed, map_ids)
    return nil if !port_layout.terminal
    rng = Random.new(island_seed)
    kind = ISLAND_KINDS.keys.sample(random: rng)
    kind = "village" if port_wp.island_gym
    wp = WorldPlace.new(nil, (kind == "village") ? "ville" : "route", port_wp.island, port_wp.x, port_wp.y, 1, 1, [],
                        !port_wp.island_gym.nil?)
    wp.index = port_wp.index
    place = town.dup
    place.name = wp.name
    place.width, place.height = ISLAND_SIZE
    place.exits = []
    place.border = nil
    place.port = "sud"
    place.island = true
    place.map_id = map_ids[wp.name]
    place.counts = ISLAND_KINDS[kind].select { |k, _| bricks.any? { |b| b.kind == k } || k == LAKE }
    [PORT, TERMINAL].each { |k| place.counts[k] = 0..0 if town.counts.key?(k) }
    place.counts["arene"] = 1..1 if wp.gym && town.counts.key?("arene")
    place.per_case = []
    place.crossing = place.river = nil
    place.mountain = place.cave = place.dive = false
    place.ambiance = (rng.rand(2) == 0 && town.ambiances.any? { |a| a.name == ISLAND_AMBIANCE }) ? ISLAND_AMBIANCE : nil
    # An excess of a town (village) or of a route (wild island)
    wp.excess = place.excess = side_excess(world, wp.kind, rng)
    wanted = EXCESSES.dig(wp.excess, :ambiance)
    place.ambiance = wanted if town.ambiances.any? { |a| a.name == wanted }
    text, layout = generate_world_place(place, bricks, island_seed)
    return [wp, port_wp, place, text, layout]
  rescue Error
    # An island whose bricks never fit is left out, the port keeps its boat
    # terminal without a boat
    return nil
  end

  # The excess of a place off the chain (island, cave, seabed), nil if none:
  # of that kind, the length and the colossal mountain left aside.
  def side_excess(world, kind, rng)
    return nil if rng.rand(100) >= world.excess
    names = EXCESSES.select { |_name, e| e[:kind] == kind && !e[:long] && !e[:colossal] }.keys
    return names.sample(random: rng)
  end

  # Warp of a ferry terminal: walking into its door takes the boat, to the
  # pier in front of the other terminal.
  def ferry_warp(layout, target, target_layout)
    tx, ty = target_layout.terminal
    return [*layout.terminal, target, tx, ty - 1, 8]
  end

  # A name for an island: « Île » and a name, or a name alone, drawn from
  # the names of the lore and not taken yet.
  def island_name(taken, rng)
    path = File.join(FOLDER, ISLAND_NAMES_FILE)
    names = []
    if File.exist?(path)
      section = nil
      File.foreach(path, encoding: "UTF-8") do |line|
        line = line.sub(/#.*/, "").strip
        if line =~ /\A\[(.+)\]\z/
          section = $1
        elsif ISLAND_NAME_SECTIONS.include?(section) && !line.empty?
          names.concat(line.split(",").map(&:strip))
        end
      end
    end
    forms = names.shuffle(random: rng).flat_map { |n| (rng.rand(5) < 3) ? ["Île #{n}", n] : [n, "Île #{n}"] }
    return forms.find { |n| !taken.include?(n) } || "Île générée #{taken.length + 1}"
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
  def seabed_text(name, place, layout, rng, excess = nil)
    w, h = place.width, place.height
    deep = layout.deep.to_h { |cell| [cell, true] }
    dist = distances(layout.deep, w, h)
    # Open within a reach that changes every 5 tiles, then smoothed
    reach_range = EXCESSES.dig(excess, :reach) || (4..9)
    reach = Array.new((h / 5) + 1) { Array.new((w / 5) + 1) { rng.rand(reach_range) } }
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
    # « forêt d'algues »: far more and bigger spots
    forest = EXCESSES.dig(excess, :weed)
    rng.rand(forest ? 8..12 : 1..3).times do
      cx, cy = floor.sample(random: rng) || break
      r = rng.rand(forest ? 3.0..5.0 : 1.5..3.0)
      floor.each { |x, y| weed[[x, y]] = true if ((x - cx)**2) + ((y - cy)**2) <= r * r }
    end
    text = +"# Fonds de #{place.name}, générés par MapProceduralGenerator. On y plonge depuis\n"
    text << "# l'eau profonde de la route, et on remonte là où l'eau au-dessus est profonde.\n"
    text << "Name    = #{name}\n"
    text << "Tileset = #{SEABED_TILESET}\n"
    text << "Ground  = .\n"
    # The floor variants too, so the seabed is the same for a world seed
    text << "Seed    = #{rng.rand(1_000_000)}\n"
    text << SEABED_PALETTE
    text << "\n[Map]\n"
    h.times do |y|
      text << Array.new(w) { |x| open[y][x] ? (weed[[x, y]] ? "s" : ".") : "R" }.join << "\n"
    end
    return text
  end

  # Warps of a route's cave entrances: the first one to 1F, the second one
  # to the basement, in front of the cave's exit.
  def cave_warps(doors, floors)
    return doors.each_with_index.map do |(x, y, _brick), i|
      ex, ey = floors[i].spots[:exits][0]
      [x, y, floors[i].name, ex, ey + 1, 2]
    end
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
      lengths = world.route_length.to_a.shuffle(random: rng)
      # « route interminable »: three times the longest length, when it fits
      long = rng.rand(100) < world.excess && rng.rand(EXCESSES.count { |_n, e| CHAIN_KINDS.include?(e[:kind]) }) == 0
      lengths.unshift(world.route_length.max * 3) if long
      found = DIRECTIONS.keys.shuffle(random: rng).product(lengths).find do |side, length|
        rt, nt = route_and_town(current, side, length, rng)
        # The route only touches the current town, the new town only its route
        # (not laid yet, so nothing may be around the new town)
        next false if !free.call(rt.x, rt.y, rt.w, rt.h, [current]) || !free.call(nt.x, nt.y, nt.w, nt.h, [])
        take.call(rt.tap { |r| r.symbol = ROUTE_SYMBOLS[i - 1]; r.name = "Route générée #{i}" })
        rt.excess = "route interminable" if long && length > world.route_length.max
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
    choose_ports(world, places, rng)
    choose_excesses(world, places, rng)
    return places
  end

  # Port towns: those named like one (Port, Dock, Harbour), then others drawn
  # at random. The sea lies on a side with no exit, as far as can be from the
  # exits of the sides next to it; north only when no other side will do (the
  # ferry terminal needs the sea south, east or west).
  def choose_ports(world, places, rng)
    towns = places.select { |p| p.kind == "ville" }
    named = towns.select { |t| t.name =~ PORT_NAME }
    others = (towns - named).shuffle(random: rng).first([rng.rand(world.ports), towns.length].min)
    (named + others).each do |town|
      side = port_side(world, town, rng)
      town.port = side if side
    end
    # A boat to an island from the ports with a ferry terminal (not north)
    taken = places.map(&:name)
    towns.select { |t| t.port && t.port != "nord" }.each do |town|
      next if rng.rand(100) >= world.islands
      town.island = island_name(taken, rng)
      taken.push(town.island)
      next if world.island_gyms <= 0 || rng.rand(100) >= world.island_gyms
      # The island has a gym too: the number of gyms stays the same, so a town
      # further in the chain gives its own (the gyms between keep at least as
      # many before them, Surf and Dive stay in their place), else the port
      donors = towns.select { |t| t.gym && !t.surf && !t.dive && t.index > town.index }
      donors = [town] if donors.empty? && town.gym && !town.surf && !town.dive
      donor = donors.sample(random: rng)
      next if !donor
      donor.gym = false
      town.island_gym = donor
    end
  end

  # Room left between the sea and the exits on the sides next to it, in tiles.
  def port_side(world, town, rng)
    w, h = town.w * world.cell, town.h * world.cell
    room = lambda do |side|
      town.exits.filter_map do |exit_side, offset|
        next if %w[nord sud].include?(side) == %w[nord sud].include?(exit_side)
        case side
        when "nord", "ouest" then offset
        when "sud" then h - offset - STREET_WIDTH
        else w - offset - STREET_WIDTH
        end
      end.min || 99
    end
    sides = (SIDES - town.exits.map(&:first)).select { |side| room.call(side) >= PORT_ROOM }
    return (sides - ["nord"]).sample(random: rng) || sides.first
  end

  # Now and then a place goes over the top (« Demesure »): an excess of its
  # kind, drawn at random.
  def choose_excesses(world, places, rng)
    places.each do |wp|
      next if wp.excess || rng.rand(100) >= world.excess
      names = EXCESSES.select do |_name, e|
        e[:kind] == wp.kind && !e[:long] && (!e[:colossal] || wp.mountain)
      end.keys
      wp.excess = names.sample(random: rng)
    end
  end

  # Surf is obtained in a town with a gym, the Surf-th one or a later one;
  # water only blocks routes after that town, so that the player can always go
  # on without surfing before. Caves anywhere.
  def choose_crossings(world, places, rng)
    routes = places.select { |p| p.kind == "route" && [p.w, p.h].max >= 2 }
    gyms = places.select { |p| p.kind == "ville" && p.gym }
    route_after = ->(town) { routes.any? { |r| r.index > town.index } }
    candidates = gyms.drop(world.surf - 1)
    # A town with a water route after it, when water is wanted
    if world.channels.max + world.lakes.max > 0
      wet_after = candidates.select(&route_after)
      candidates = wet_after if !wet_after.empty?
    end
    # A town with a later Dive town and a route after that one, when seabeds
    # are wanted
    if world.dives.max > 0
      dive_after = candidates.select { |t| gyms.drop(world.dive - 1).any? { |g| g.index > t.index && route_after.call(g) } }
      candidates = dive_after if !dive_after.empty?
    end
    surf_town = candidates.sample(random: rng)
    surf_town.surf = true if surf_town
    dive_town = choose_dive_town(world, gyms, surf_town, route_after, rng)
    wet = surf_town ? routes.select { |r| r.index > surf_town.index }.shuffle(random: rng) : []
    # The first water goes after the Dive town, so that a seabed can lie there
    if dive_town && world.dives.max > 0
      first = wet.find { |r| r.index > dive_town.index }
      wet.unshift(wet.delete(first)) if first
    end
    rng.rand(world.channels).times { (wet.shift || break).crossing = "chenal" }
    rng.rand(world.lakes).times { (wet.shift || break).crossing = "lac" }
    dry = routes.select { |r| !r.crossing }.shuffle(random: rng)
    rng.rand(world.caves).times { (dry.shift || break).crossing = "grotte" }
    # Mountains on any route but those of a cave, a river or a lake included;
    # north-south routes first: they climb best
    climbs = routes.select { |r| r.crossing != "grotte" }.shuffle(random: rng)
    climbs = climbs.sort_by.with_index { |r, i| [(r.h > r.w) ? 0 : 1, i] }
    rng.rand(world.mountains).times do
      route = climbs.shift || break
      route.mountain = true
      route.cave = rng.rand(100) < world.mountain_cave
      # A river alongside, on a north-south route that nothing crosses
      route.river = rng.rand(100) < world.mountain_river if !route.crossing && route.h > route.w
    end
    return if !dive_town
    # Deep water only on water routes after the Dive town
    deep = routes.select { |r| %w[chenal lac].include?(r.crossing) && r.index > dive_town.index }.shuffle(random: rng)
    rng.rand(world.dives).times { (deep.shift || break).deep = true }
  end

  # Dive is obtained in a town with a gym, the Plongee-th one or a later one,
  # after the Surf town (Dive needs Surf).
  def choose_dive_town(world, gyms, surf_town, route_after, rng)
    return nil if !surf_town
    candidates = gyms.drop(world.dive - 1).select { |t| t.index > surf_town.index }
    if world.dives.max > 0
      with_route = candidates.select(&route_after)
      candidates = with_route if !with_route.empty?
    end
    dive_town = candidates.sample(random: rng)
    dive_town.dive = true if dive_town
    return dive_town
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
  def world_text(world, built, seed, caves = [], seabeds = [], islands = [], region = world.name)
    text = +"# Monde généré par MapProceduralGenerator, graine #{seed}.\n"
    text << "World   = #{region}\n"
    text << "Region  = #{world.region}\n"
    text << "Image   = #{world.image}\n" if world.image
    text << "Cell    = #{world.cell}\n"
    text << "Origin  = #{world.origin.join(',')}\n"
    surf = built.find { |wp, *| wp.surf }
    text << "# Surf s'obtient à #{surf[0].title}.\n" if surf
    dive = built.find { |wp, *| wp.dive }
    text << "# Plongée s'obtient à #{dive[0].title}.\n" if dive
    built.each { |wp, *| text << "# Démesure : #{wp.title}, #{wp.excess}.\n" if wp.excess }
    caves.each { |wp, name, _text, floor, excess| text << "# Démesure : #{wp.cave_title || name}, #{excess}.\n" if excess && floor.level == 0 }
    seabeds.each { |wp, _name, _text, excess| text << "# Démesure : fonds de #{wp.title}, #{excess}.\n" if excess }
    islands.each { |wp, *| text << "# Démesure : #{wp.name}, #{wp.excess}.\n" if wp.excess }
    built.each { |wp, *| text << "# Port : #{wp.title}, la mer au #{wp.port}.\n" if wp.port }
    built.each do |wp, *|
      text << "# Île : #{wp.island}, en bateau depuis #{wp.title}#{wp.island_gym ? ', avec une arène' : ''}.\n" if wp.island
    end
    text << "\n[Places]\n"
    built.each do |wp, _place, _text, layout|
      line = "#{wp.symbol} = #{wp.name}  type=#{wp.kind}"
      line += "  nom=#{wp.title}" if wp.title != wp.name
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
