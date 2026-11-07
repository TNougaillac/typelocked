#===============================================================================
# MapProceduralGenerator - Whole world
# World file (MapProc/*.txt with a Monde key):
#   Monde    = TypeLocked      (required: region name, as MapGen's World)
#   Region   = 0               (Town Map region, 0 by default)
#   Image    = typelocked.png  (Town Map image drawn by MapGen, optional)
#   Origin   = 0,0             (Town Map square of the grid's top-left)
#   Taille   = 32x24           (required: grid size in Town Map squares; 32x24
#                               fills the Town Map screen)
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
#   Largeur  = 1..2            (route width in squares, 1 by default)
#   TaillesVilles = 1x1, 1x2, 2x2, L
#                              (town sizes drawn from, 2x2 by default; 1x2
#                               is 1x2 or 2x1; L is 3 squares of a 2x2, its
#                               streets going through the corner. A 1x1 town
#                               is a village with no gym, so there are at
#                               most as many as towns without one; the first
#                               town is 1x2 at least)
#   FormesRoutes = droite, L, U (route shapes drawn from, droite by default:
#                               straight; in L, turning once, a length of its
#                               width + 2 squares at least; in U, coming back
#                               to a place beside the one it leaves, on the
#                               same side, legs of its length)
#   Surf     = 2               (Surf is obtained in a town with a gym, drawn
#                               from the town of that gym onwards, 2 by
#                               default; water that blocks a route only
#                               appears after that town)
#   Chenaux  = 0..2            (routes crossed by a straight channel, only by
#                               surfing; 0 by default)
#   Lacs     = 0..1            (routes crossed by a lake, only by surfing;
#                               0 by default)
#   Mers     = 0..2            (sea routes: the sea over nearly all their
#                               length, a beach at each end, rocks and
#                               sandbanks, only by surfing; 0 by default)
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
#   Machette = 1               (each field item of FIELD_ITEMS is obtained in
#   Pioche   = 3                a town with a gym, the n-th gym's or the next
#   ...                         one, in the order of these numbers; defaults
#                               in FIELD_ITEMS)
#   Recoins  = 30              (chance in % that a place has an optional nook
#                               behind an obstacle, see NOOKS; 0 by default)
#   Noms     = Bourg Typelock, Ville Rubis, ...
#                              (optional town names, in order; "Ville
#                               générée 1"... otherwise; routes are "Route
#                               générée 1"...)
#   Toponymie = Lore/noms.txt  (optional: names shown in game, drawn with the
#                               seed from this file, see 008_Names; the map
#                               names otherwise)
# The towns (2x2 squares by default) form a chain linked by routes (1 or 2 squares wide), each
# town a little further from the start, so the gyms come in that order. A
# route in L keeps its whole rectangle on the grid (MapGen needs one per map)
# with a mask of the squares it covers: the others are filled like the map's
# border, and the exits only lie on the edges of its squares. Each
# place is assembled from its place file with the exits facing its
# neighbours, then MapGen writes the maps, the connections and the Town Map
# from the world plan made here. Only routes of 2 squares or more can be
# crossed by water or a cave. A cave is two maps of its own (« Grotte générée
# N » and its « (sous-sol) », for route N), see 006_Caves.rb. After the last
# town, every world ends with the Victory Road and the League's plateau
# (« Plateau généré »), see VICTORY_ROAD.
#===============================================================================
module MapProceduralGenerator
  World = Struct.new(:file, :name, :region, :image, :origin, :width, :height, :cell,
                     :town_file, :route_file, :towns, :gyms, :route_length, :names, :no_gym,
                     :surf, :channels, :lakes, :caves, :dive, :dives, :mountains, :mountain_cave, :excess, :mountain_river,
                     :ports, :islands, :island_gyms, :names_file, :field_items, :nooks, :route_shapes, :route_width, :town_sizes, :loops, :shortcuts,
                     :margin, :seas)
  # kind: "ville" or "route"; x, y, w, h in squares; exits: [side, offset]
  # crossing: nil, "chenal", "lac", "mer" or "grotte" (routes); surf, dive: the town
  # where Surf, Dive is obtained; deep: a route with a dive spot; mountain: a
  # route climbing by levels (with a crossing or not); cave: a mountain route
  # with a cave; port: the sea side of a port town; island: name of the island
  # its boat goes to; island_gym: the town whose gym went to that island;
  # title, cave_title: names shown in game (see 008_Names); professor: the
  # first town, drawn without its lab (it didn't fit): the professor waits
  # outside; victory: the Victory Road; league: the League's plateau, at the
  # end of the chain (see VICTORY_ROAD); items: the field items obtained in
  # that town; nook: the obstacle of its nook (a key of NOOKS); shape,
  # span: of a route (see ROUTE_SHAPES), its length in squares; mask: rows of
  # "1" (square covered) and "0" of
  # its rectangle, nil = all of it; joints: [x, y, w, h] the blocks of squares
  # where its streets meet (its corners), from its top-left; trace: its line
  # on the Town Map, in half squares from its top-left; extra: a route off
  # the chain, "boucle" or "raccourci" (see add_extra_routes), ends: [the
  # place of its end nearer the start, the other one], tier: the index of the
  # place of the chain from which it can be walked (nil: its own index),
  # lock: the obstacle of a shortcut (a key of LOCKS)
  WorldPlace = Struct.new(:symbol, :kind, :name, :x, :y, :w, :h, :exits, :gym, :index, :crossing, :surf,
                          :dive, :deep, :mountain, :cave, :excess, :river, :port, :island,
                          :island_gym, :title, :cave_title, :professor, :victory, :league, :items, :nook,
                          :shape, :mask, :joints, :trace, :span, :extra, :ends, :tier, :lock)
  # text: MapGen world plan; places: [WorldPlace, Place, MapGen plan text, Layout];
  # caves: [WorldPlace of the route, name, MapGen plan text, CaveFloor, excess],
  # one per floor;
  # seabeds: [WorldPlace of the route, name, MapGen plan text];
  # islands: [WorldPlace of the island, WorldPlace of its port, Place,
  # MapGen plan text, Layout]; interiors: Interior (see 011_Interiors.rb)
  # notes: lines for the console (routes off the chain that found no room);
  # fillers: Filler (see 013_Fillers.rb)
  WorldResult = Struct.new(:text, :places, :caves, :seabeds, :islands, :interiors, :notes, :fillers)

  TOWN_SIZE = 2
  # Times the world is laid out again when a place can't be assembled
  WORLD_TRIES = 10
  # Town sizes in squares (1x2: 1x2 or 2x1; L: 3 squares of a 2x2)
  TOWN_SIZES = %w[1x1 1x2 2x2 L].freeze
  # Route shapes: straight, in L (one turn), in U (two turns, back the way
  # it came)
  ROUTE_SHAPES = %w[droite L U].freeze
  # Map name of the League's plateau (its route is « Route générée N »)
  PLATEAU_NAME = "Plateau généré"
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
    world = World.new(file, nil, 0, nil, [0, 0], nil, nil, 20, nil, nil, nil, nil, 2..4, [], [], 2, 0..0, 0..0, 0..0, 3, 0..0, 0..0, 50, 0, 0, 0..0, 0, 0, nil,
                      FIELD_ITEMS.transform_values(&:last), 0, ["droite"], 1..1, ["2x2"], 0..0, 0..0, 0, 0..0)
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
      when "largeur"  then world.route_width = range(value, fail_at)
      when "boucles"  then world.loops = range(value, fail_at)
      when "raccourcis" then world.shortcuts = range(value, fail_at)
      when "marge"    then world.margin = integer(value, fail_at)
      when "taillesvilles" then world.town_sizes = choices(value, TOWN_SIZES, fail_at)
      when "formesroutes" then world.route_shapes = choices(value, ROUTE_SHAPES, fail_at)
      when "noms"     then world.names = value.split(",").map(&:strip)
      when "toponymie" then world.names_file = value
      when "sansarene" then world.no_gym = value.split(",").map { |n| integer(n.strip, fail_at) }
      when "surf"     then world.surf = integer(value, fail_at)
      when "chenaux"  then world.channels = range(value, fail_at)
      when "lacs"     then world.lakes = range(value, fail_at)
      when "mers"     then world.seas = range(value, fail_at)
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
      when "recoins"  then world.nooks = integer(value, fail_at)
      else
        item = FIELD_ITEMS.keys.find { |name| name.casecmp?(key) }
        fail_at.call("clé inconnue « #{key} »") if !item
        world.field_items[item] = integer(value, fail_at)
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
    # One more town symbol for the League's plateau
    raise Error, "#{file} : « Villes » doit être entre 1 et #{TOWN_SYMBOLS.length - 1}" if !(1...TOWN_SYMBOLS.length).include?(world.towns)
    raise Error, "#{file} : « Longueur » doit commencer à 1 au moins" if world.route_length.min < 1
    raise Error, "#{file} : « Largeur » doit valoir 1 ou 2" if !(1..2).cover?(world.route_width.min) || !(1..2).cover?(world.route_width.max)
    raise Error, "#{file} : « Surf » doit valoir 1 au moins" if world.surf < 1
    raise Error, "#{file} : « Plongee » doit dépasser « Surf » (il faut Surf pour plonger)" if world.dive <= world.surf
    return world
  end

  # Values of a list key among those allowed (« FormesRoutes = droite, L »).
  def choices(value, allowed, fail_at)
    list = value.split(",").map(&:strip).uniq
    list.each { |v| fail_at.call("« #{v} » inconnu (#{allowed.join(', ')})") if !allowed.include?(v) }
    return list
  end

  # Lays the towns and routes on the grid, then assembles every place.
  # map_ids: name => map ID to overwrite (places of an earlier world); names:
  # NameTable of the names shown in game (nil = the map names).
  def generate_world(world, town, route, bricks, seed, map_ids = {}, names = nil)
    rng = Random.new(seed)
    places = built = region = notes = islands = nil
    # A place whose bricks never fit (a short route with a wide channel...)
    # lays the whole world out again, further on in the seed's numbers
    WORLD_TRIES.times do |attempt|
      50.times do
        places, notes = lay_out_world(world, rng)
        break if places
      end
      raise Error, "#{world.file} (graine #{seed}) : impossible de placer #{world.towns} villes dans #{world.width}x#{world.height} cases ; agrandis « Taille »" if !places
      # Own random numbers: the names don't change the rest of the world
      region = names ? name_world(world, places, names, Random.new((seed * 1000) + 999)) : world.name
      places.each do |wp|
        wp.title ||= (wp.victory && VICTORY_ROAD) || (wp.league && PLATEAU) || wp.name
        wp.cave_title ||= VICTORY_CAVE if wp.victory
      end
      built = build_world_places(world, places, town, route, bricks, seed, map_ids)
      # Islands in the loop too: a town built again without its boat (or
      # given back its gym) may not fit
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
        island
      end
      break
    rescue Error
      raise if attempt == WORLD_TRIES - 1
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
    # The dark caves of the nooks
    caves += built.flat_map do |wp, _place, _text, layout|
      door = layout.doors.find { |_x, _y, brick| brick.kind == DARK_CAVE }
      next [] if !door
      floor = dark_cave_floor("#{wp.name} - grotte sombre", wp.name, door, Random.new((seed * 1000) + 600 + wp.index))
      ex, ey = floor.spots[:exits][0]
      warps[wp.name].push([door[0], door[1], floor.name, ex, ey + 1, 2])
      [[wp, floor.name, cave_floor_text(floor, wp.name), floor, nil]]
    end
    seabeds = built.filter_map do |wp, place, _text, layout|
      next if !wp.deep
      name = "#{wp.name} (fonds)"
      excess = side_excess(world, "fonds", Random.new((seed * 1000) + 800 + wp.index))
      [wp, name, seabed_text(name, place, layout, Random.new((seed * 1000) + 700 + wp.index), excess), excess]
    end
    # The boats between each port and its island
    islands.each do |island|
      port = built.find { |wp, *| wp.equal?(island[1]) }[3]
      warps[island[1].name].push(ferry_warp(port, island[0].name, island[4]))
      warps[island[0].name].push(ferry_warp(island[4], island[1].name, port))
    end
    interiors = place_interiors(built.map { |wp, _place, _text, layout| [wp, layout, wp.index] } +
                                islands.map { |wp, _port, _place, _text, layout| [wp, layout, 50 + wp.index] }, seed)
    interiors.each { |it| warps[it.owner].push([*it.door, it.name, *it.arrival, 8, it.graphic]) if it.door }
    built.each { |wp, place, text, _layout| text << warps_text(warps[wp.name], place.width, place.height) }
    islands.each { |wp, _port, place, text, _layout| text << warps_text(warps[wp.name], place.width, place.height) }
    fillers = world_fillers(world, built, seed, map_ids)
    return WorldResult.new(world_text(world, built, seed, caves, seabeds, islands, region, notes, fillers), built, caves, seabeds, islands, interiors,
                           extra_notes(built) + notes, fillers)
  end

  # Assembles each place of the world: [WorldPlace, Place, MapGen plan text,
  # Layout].
  def build_world_places(world, places, town, route, bricks, seed, map_ids)
    return places.map do |wp|
      base = (wp.kind == "ville") ? town : route
      place = base.dup
      place.name = wp.name
      place.width, place.height = wp.w * world.cell, wp.h * world.cell
      place.exits = wp.exits
      place.mask = wp.mask
      place.joints = wp.joints
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
      place.nook = wp.nook
      # A shortcut is closed at its exit towards its end nearer the start (its
      # first one)
      place.lock = wp.lock && [wp.lock, 0]
      if wp.league
        place.counts = PLATEAU_BRICKS.select { |k, _| bricks.any? { |b| b.kind == k } }
        place.per_case = []
        place.fixed_counts = true
      end
      # The professor's lab in the first town, left out if it doesn't fit
      place.counts[LAB] = 1..1 if wp.index == 0 && bricks.any? { |b| b.kind == LAB }
      begin
        [wp, place, *generate_world_place(place, bricks, (seed * 1000) + wp.index, cave: wp.victory)]
      rescue Error
        raise if !place.counts.delete(LAB)
        wp.professor = true
        [wp, place, *generate_world_place(place, bricks, (seed * 1000) + wp.index)]
      end
    end
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
    place.fixed_counts = true
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
  # same for a given seed. cave: the place must have its cave entrance (the
  # Victory Road). Returns [text, layout].
  def generate_world_place(place, bricks, place_seed, cave: false)
    4.times do |retry_index|
      _plan, text, layout = generate_place(place, bricks, place_seed + (retry_index * 100_000))
      raise Error, "#{place.name} : entrée de grotte impossible à placer" if cave && layout.doors.none? { |_x, _y, b| b.kind == CAVE }
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

  # Returns the WorldPlaces of a chain of towns and routes (and the routes
  # added off it) and notes for the console, or nil if the chain ran into the
  # edges or into itself.
  def lay_out_world(world, rng)
    taken = Array.new(world.height) { Array.new(world.width) }
    places = []
    # Free if inside the grid (« Marge » squares off its edges) with one
    # empty square around, so that only intended neighbours touch (corners:
    # also diagonally; the maps of places that only meet at a corner are not
    # connected)
    free = lambda do |x, y, w, h, allowed, corners = true|
      m = world.margin
      next false if x < m || y < m || x + w > world.width - m || y + h > world.height - m
      (y - 1..y + h).all? do |cy|
        (x - 1..x + w).all? do |cx|
          next true if cx < 0 || cy < 0 || cx >= world.width || cy >= world.height
          next true if !corners && [x - 1, x + w].include?(cx) && [y - 1, y + h].include?(cy)
          inside = cx >= x && cy >= y && cx < x + w && cy < y + h
          taken[cy][cx].nil? || (!inside && allowed.include?(taken[cy][cx]))
        end
      end
    end
    take = lambda do |wp|
      wp.h.times { |dy| wp.w.times { |dx| taken[wp.y + dy][wp.x + dx] = wp } }
      places.push(wp)
    end
    town_name = ->(i) { world.names[i] || "Ville générée #{i + 1}" }
    # Size of the i-th town: a village (1x1) only where there may be a town
    # without a gym (a listed one, or one of those left), never the first
    villages = world.towns - world.gyms - (world.no_gym | [1]).length
    town_size = lambda do |i|
      listed = world.no_gym.include?(i + 1)
      sizes = world.town_sizes
      sizes -= ["1x1"] if i == 0 || (!listed && villages <= 0)
      sizes = ["1x2"] if sizes.empty?
      size = (sizes.length > 1) ? sizes[rng.rand(sizes.length)] : sizes[0]
      villages -= 1 if size == "1x1" && !listed
      next [1, 1] if size == "1x1"
      next [2, 2] if size == "2x2"
      next [[1, 2], [2, 1]][rng.rand(2)] if size == "1x2"
      # An L: a 2x2 without one of its squares, the corner across from it
      gone = rng.rand(4)
      mask = Array.new(2) { |y| Array.new(2) { |x| ((y * 2) + x == gone) ? "0" : "1" }.join }
      [2, 2, mask, [[1 - (gone % 2), 1 - (gone / 2), 1, 1]]]
    end
    w, h, mask, joints = town_size.call(0)
    x = rng.rand(world.margin..world.width - w - world.margin)
    y = rng.rand(world.margin..world.height - h - world.margin)
    current = WorldPlace.new(TOWN_SYMBOLS[0], "ville", town_name.call(0), x, y, w, h, [], false)
    current.mask, current.joints = mask, joints
    take.call(current)
    # The i-th route and town of the chain, on the first of those sides and
    # lengths that fits; nil if none does
    extend_chain = lambda do |i, sides, lengths, town, size, shapes = world.route_shapes, widths = world.route_width|
      sides.product(lengths).each do |side, length|
        rt, nt, out = route_and_town(current, side, length, shapes, widths, size, rng)
        next if !rt
        # The route only touches the current town, the new town only its route
        # (not laid yet, so nothing may be around the new town)
        next if !free.call(rt.x, rt.y, rt.w, rt.h, [current]) || !free.call(nt.x, nt.y, nt.w, nt.h, [])
        take.call(rt.tap { |r| r.symbol = ROUTE_SYMBOLS[i - 1]; r.name = "Route générée #{i}" })
        take.call(nt.tap { |t| t.symbol = TOWN_SYMBOLS[i]; t.name = town })
        link(world, current, rt, side, rng)
        link(world, rt, nt, out, rng)
        current = nt
        return rt
      end
      nil
    end
    (1...world.towns).each do |i|
      lengths = world.route_length.to_a.shuffle(random: rng)
      # « route interminable »: three times the longest length, when it fits
      long = rng.rand(100) < world.excess && rng.rand(EXCESSES.count { |_n, e| CHAIN_KINDS.include?(e[:kind]) }) == 0
      lengths.unshift(world.route_length.max * 3) if long
      size = town_size.call(i)
      rt = extend_chain.call(i, DIRECTIONS.keys.shuffle(random: rng), lengths, town_name.call(i), size) || (return nil)
      rt.excess = "route interminable" if long && rt.span > world.route_length.max
    end
    towns = places.select { |p| p.kind == "ville" }
    # The towns without a gym: the first one, the listed ones and the
    # villages, then others drawn at random
    no_gym = (world.no_gym | [1]).map { |n| n - 1 }
    no_gym |= towns.each_index.select { |i| towns[i].w * towns[i].h == 1 }
    others = (0...world.towns).to_a - no_gym
    no_gym += others.sample(world.towns - world.gyms - no_gym.length, random: rng)
    towns.each_with_index { |t, i| t.gym = !no_gym.include?(i) }
    places.each_with_index { |p, i| p.index = i }
    choose_crossings(world, places, rng)
    choose_ports(world, places, rng)
    choose_excesses(world, places, rng)
    choose_field_towns(world, places, rng)
    # Then the Victory Road, north-south (only these climb level after level),
    # and the plateau: after the draws above, which leave them alone
    sides = %w[nord sud].shuffle(random: rng)
    victory = extend_chain.call(world.towns, sides, [world.route_length.max], PLATEAU_NAME, [TOWN_SIZE, TOWN_SIZE], ["droite"], 1..1) || (return nil)
    victory.mountain = victory.cave = victory.victory = true
    current.league = true
    places.each_with_index { |p, i| p.index ||= i }
    notes = add_extra_routes(world, places, free, take, rng)
    choose_nooks(world, places, rng)
    center_world(world, places)
    return places, notes
  end

  # Moves every place so that the world lies in the middle of its grid (the
  # Town Map), whatever corner the chain wandered to.
  def center_world(world, places)
    x0, y0 = places.map(&:x).min, places.map(&:y).min
    x1, y1 = places.map { |p| p.x + p.w }.max, places.map { |p| p.y + p.h }.max
    dx = ((world.width - (x1 - x0)) / 2) - x0
    dy = ((world.height - (y1 - y0)) / 2) - y0
    places.each do |p|
      p.x += dx
      p.y += dy
    end
  end

  # Routes added off the chain, once it is laid: loops (« Boucles »), open
  # from the start, between two places of the chain with no town with a gym
  # between them; then shortcuts (« Raccourcis ») between two places with a
  # gym between them, closed at the end nearer the start by an obstacle (see
  # LOCKS) whose field item is obtained no earlier than the last gym before
  # the far end, so that they never skip a gym. Their ends are towns or
  # plain straight routes. Each one gets its tier: the index of the place of
  # the chain from which it can be walked (a loop: its end nearer the start;
  # a shortcut: the town of its item, or its far end if that comes first).
  # Returns the notes of those that found no room.
  def add_extra_routes(world, places, free, take, rng)
    loops, shortcuts = rng.rand(world.loops), rng.rand(world.shortcuts)
    return [] if loops + shortcuts == 0
    ends = places.select do |p|
      next false if p.victory || p.league
      p.kind == "ville" || (!p.mask && !p.crossing && !p.mountain)
    end
    # A town that gives its gym to an island gets it back if the island
    # can't be built: it counts too
    gym_at = places.select { |p| p.kind == "ville" && (p.gym || p.island_gym) }.map(&:index) |
             places.filter_map { |p| p.island_gym&.index }
    obtained = {}
    places.each do |p|
      (p.items || []).each { |item| obtained[item] = p.index }
      obtained[SURF_ITEM] = p.index if p.surf
    end
    pairs = ends.combination(2).map { |a, b| (a.index < b.index) ? [a, b] : [b, a] }
    pairs.select! { |a, b| b.index - a.index >= 2 && near?(a, b, EXTRA_REACH) }
    open, far = pairs.partition { |a, b| gym_at.none? { |g| g > a.index && g < b.index } }
    notes = []
    [["boucle", loops, open], ["raccourci", shortcuts, far]].each do |kind, wanted, candidates|
      laid = 0
      candidates.shuffle(random: rng).each do |a, b|
        break if laid == wanted
        next if places.any? { |p| p.extra && p.ends == [a, b] }
        # A town keeps room for its streets: no more exits than squares
        next if [a, b].any? { |t| t.kind == "ville" && t.exits.length >= (t.mask ? t.mask.join.count("1") : t.w * t.h) }
        lock = nil
        if kind == "raccourci"
          last_gym = gym_at.select { |g| g < b.index }.max
          locks = LOCKS.select { |_obstacle, item| obtained[item] && obtained[item] >= last_gym }.keys
          next if locks.empty?
          lock = locks[rng.rand(locks.length)]
        end
        route, side, out = route_between(world, a, b, free, rng) || next
        laid += 1
        n = places.count { |p| p.kind == "route" } + 1
        route.symbol = ROUTE_SYMBOLS[n - 1]
        route.name = "Route générée #{n}"
        route.index = places.length
        route.extra = kind
        route.ends = [a, b]
        route.tier = lock ? [obtained[LOCKS[lock]], b.index].min : a.index
        route.lock = lock
        take.call(route)
        link(world, a, route, side, rng)
        link(world, route, b, out, rng)
      end
      notes.push("#{kind} : #{wanted - laid} sur #{wanted} sans place") if laid < wanted
    end
    return notes
  end

  # True if the rectangles of a and b are at most that many squares apart.
  def near?(a, b, reach)
    dx = [a.x - (b.x + b.w), b.x - (a.x + a.w), 0].max
    dy = [a.y - (b.y + b.h), b.y - (a.y + a.h), 0].max
    return dx + dy <= reach
  end

  # A route from place a to place b among those the world allows, where it
  # touches nothing else: [route, side of a, side of the route towards b],
  # nil if none fits. Never on the sea side of a port. Its legs may be up to
  # EXTRA_REACH squares long, to go round the chain.
  def route_between(world, a, b, free, rng)
    options = []
    lengths = (world.route_length.min..[world.route_length.max, EXTRA_REACH].max).to_a
    DIRECTIONS.each_key do |side|
      next if side == a.port
      turns = DIRECTIONS.keys.select { |k| DIRECTIONS[k].map(&:abs) != DIRECTIONS[side].map(&:abs) }
      world.route_width.each do |width|
        world.route_shapes.each do |shape|
          frames = case shape
                   when "droite"
                     lengths.map { |l| [route_frame(shape, l, 0, width), turns.find { |k| DIRECTIONS[k].sum > 0 }] }
                   when "L"
                     # Each leg up to the longest
                     (width + 1..lengths.max).to_a.product(lengths).flat_map do |first, second|
                       turns.map { |t| [route_frame(shape, first, second, width), t] }
                     end
                   else
                     (width + 1..lengths.max).flat_map do |l|
                       (1..EXTRA_REACH).flat_map { |gap| turns.map { |t| [route_frame(shape, l, gap, width), t] } }
                     end
                   end
          frames.each do |frame, turn|
            route_spots(a, side, turn, frame).each do |route, far, out, squares|
              next if OPPOSITE[out] == b.port
              dx, dy = DIRECTIONS[out]
              next if far.none? { |x, y| on_place?(b, x + dx, y + dy) }
              next if !free.call(route.x, route.y, route.w, route.h, [a, b], false)
              mask_route(route, squares)
              route.shape = shape
              route.span = frame[0].map(&:first).max + 1
              options.push([route, side, out])
            end
          end
        end
      end
    end
    return options.empty? ? nil : options[rng.rand(options.length)]
  end

  # Each field item in a town with a gym: the one of its minimum (FIELD_ITEMS,
  # or its world key) or the next one, never before an item of a lower
  # minimum.
  def choose_field_towns(world, places, rng)
    gyms = places.select { |p| p.kind == "ville" && p.gym }
    after = 0
    world.field_items.sort_by.with_index { |(_name, min), i| [min, i] }.each do |name, min|
      town = gyms.drop(min - 1).select { |t| t.index >= after }.first(2).sample(random: rng) || next
      (town.items ||= []).push(FIELD_ITEMS[name][0])
      after = town.index
    end
  end

  # Places with a nook (« Recoins », in %): its obstacle drawn among those
  # whose item was obtained in an earlier town of the chain (a dark cave on a
  # route only).
  def choose_nooks(world, places, rng)
    obtained = {}
    places.each do |p|
      (p.items || []).each { |item| obtained[item] = p.index }
      obtained[SURF_ITEM] = p.index if p.surf
      obtained[DIVE_ITEM] = p.index if p.dive
    end
    places.each do |wp|
      next if rng.rand(100) >= world.nooks
      kinds = NOOKS.select { |kind, item| obtained[item]&.<(wp.tier || wp.index) && (kind != "sombre" || wp.kind == "route") }.keys
      wp.nook = kinds.sample(random: rng)
    end
  end

  # Port towns: those named like one (Port, Dock, Harbour), then others drawn
  # at random. The sea lies on a side with no exit, as far as can be from the
  # exits of the sides next to it; north only when no other side will do (the
  # ferry terminal needs the sea south, east or west).
  def choose_ports(world, places, rng)
    towns = places.select { |p| p.kind == "ville" }
    named = towns.select { |t| t.name =~ PORT_NAME }
    # Never a village: its sea would leave no room for its streets
    others = (towns - named).reject { |t| t.w * t.h == 1 || t.mask }.shuffle(random: rng).first([rng.rand(world.ports), towns.length].min)
    (named + others).each do |town|
      # The sea would cover the squares an L leaves out
      next if town.mask
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
    # Only straight routes of 2 squares or more are crossed or climb
    routes = places.select { |p| p.kind == "route" && p.span.to_i >= 2 && !p.mask }
    gyms = places.select { |p| p.kind == "ville" && p.gym }
    route_after = ->(town) { routes.any? { |r| r.index > town.index } }
    candidates = gyms.drop(world.surf - 1)
    # A town with a water route after it, when water is wanted
    if world.channels.max + world.lakes.max + world.seas.max > 0
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
    rng.rand(world.seas).times { (wet.shift || break).crossing = "mer" } if world.seas.max > 0
    dry = routes.select { |r| !r.crossing }.shuffle(random: rng)
    rng.rand(world.caves).times { (dry.shift || break).crossing = "grotte" }
    # Mountains on any route but those of a cave, a river or a lake included;
    # north-south routes first: they climb best
    climbs = routes.select { |r| !%w[grotte mer].include?(r.crossing) }.shuffle(random: rng)
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
    deep = routes.select { |r| %w[chenal lac mer].include?(r.crossing) && r.index > dive_town.index }.shuffle(random: rng)
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

  # Route of that length leaving the town on that side, of a shape drawn
  # among those, and the next town (of that size [w, h]) at its far end (both shifted at random
  # along the side, fully against the place they touch when they can).
  # Returns [route, town, side of the route towards the town], nil if no
  # spot fits.
  def route_and_town(town, side, length, shapes, widths, size, rng)
    shape = (shapes.length > 1) ? shapes[rng.rand(shapes.length)] : shapes[0]
    width = (widths.size > 1) ? rng.rand(widths) : widths.min
    # An L or a U turns after a first leg longer than the route is wide
    shape = "droite" if (shape == "L" && length < width + 2) || (shape == "U" && length < width + 1)
    turns = DIRECTIONS.keys.select { |k| DIRECTIONS[k].map(&:abs) != DIRECTIONS[side].map(&:abs) }
    # A straight route turns nowhere: across it, towards the east or south
    turn = (shape == "droite") ? turns.find { |k| DIRECTIONS[k].sum > 0 } : turns[rng.rand(2)]
    frame = case shape
            when "droite" then route_frame(shape, length, 0, width)
            when "L"
              first = rng.rand(width + 1..length - 1)
              route_frame(shape, first, length - first, width)
            else
              # Room between its legs for the two towns, a square apart
              route_frame(shape, length, rng.rand(TOWN_SIZE + 1 - width..TOWN_SIZE + 2 - width), width)
            end
    spots = route_spots(town, side, turn, frame)
    return nil if spots.empty?
    route, ends, out, squares = spots[rng.rand(spots.length)]
    mask_route(route, squares)
    route.shape = shape
    route.span = length
    spots = town_spots(ends, out, *size)
    return nil if spots.empty?
    return route, spots[rng.rand(spots.length)], out
  end

  # A route of that shape in its own frame: u away from the place it leaves
  # (u = 0 against it), v across, each leg width squares thick; a: length of
  # the first leg (u), b: of the second (v), between the two others for a U.
  # Returns [squares [u, v], squares of its far end, way out (:ahead, :turn,
  # :back), joints [u, v, du, dv], line on the Town Map (half squares, nil if
  # straight)].
  def route_frame(shape, a, b, width)
    rect = ->(u, v, du, dv) { (u...u + du).flat_map { |cu| (v...v + dv).map { |cv| [cu, cv] } } }
    return [rect.call(0, 0, a, width), (0...width).map { |v| [a - 1, v] }, :ahead, [], nil] if shape == "droite"
    middle = (2 * a) - width
    legs = rect.call(0, 0, a, width) | rect.call(a - width, width, width, b)
    corner = [a - width, 0, width, width]
    if shape == "L"
      return [legs, (a - width...a).map { |u| [u, width + b - 1] }, :turn,
              [corner], [[0, width], [middle, width], [middle, 2 * (width + b)]]]
    end
    back = (2 * (width + b)) + width
    return [legs | rect.call(0, width + b, a, width), (0...width).map { |v| [0, width + b + v] }, :back,
            [corner, [a - width, width + b, width, width]], [[0, width], [middle, width], [middle, back], [0, back]]]
  end

  # The routes of that frame against place a on that side, the frame's v
  # going towards turn: [route, far squares, side towards the next place,
  # squares (for mask_route, once the route is kept)] for
  # each spot along the side, those fully against a first, then those that
  # only touch it, from the top or left.
  def route_spots(a, side, turn, frame)
    squares, ends, way, joints, trace = frame
    du, dv = DIRECTIONS[side], DIRECTIONS[turn]
    horizontal = du[1] == 0
    entry = squares.select { |u, _v| u == 0 }
    # Origin along the side, then the shift across
    base = case side
           when "est" then a.x + a.w
           when "ouest" then a.x - 1
           when "sud" then a.y + a.h
           else a.y - 1
           end
    lo, hi = horizontal ? [a.y, a.y + a.h] : [a.x, a.x + a.w]
    width = entry.length
    spots = (lo - width..hi + width).filter_map do |t|
      origin = horizontal ? [base, t] : [t, base]
      cell = ->(u, v) { [origin[0] + (u * du[0]) + (v * dv[0]), origin[1] + (u * du[1]) + (v * dv[1])] }
      facing = entry.map { |u, v| x, y = cell.call(u, v); on_place?(a, x - du[0], y - du[1]) }
      next if facing.none?
      cells = squares.map { |u, v| cell.call(u, v) }
      xs, ys = cells.map(&:first), cells.map(&:last)
      route = WorldPlace.new(nil, "route", nil, xs.min, ys.min, xs.max - xs.min + 1, ys.max - ys.min + 1, [], false)
      route.joints = joints.map do |ju, jv, jdu, jdv|
        corners = [cell.call(ju, jv), cell.call(ju + jdu - 1, jv + jdv - 1)]
        jx, jy = corners.map(&:first).min, corners.map(&:last).min
        horizontal ? [jx - route.x, jy - route.y, jdu, jdv] : [jx - route.x, jy - route.y, jdv, jdu]
      end
      route.trace = trace&.map do |pu, pv|
        px = (2 * origin[0]) + half_step(pu, du[0]) + half_step(pv, dv[0])
        py = (2 * origin[1]) + half_step(pu, du[1]) + half_step(pv, dv[1])
        [px - (2 * route.x), py - (2 * route.y)]
      end
      out = { ahead: side, turn: turn, back: OPPOSITE[side] }[way]
      first = horizontal ? ys.min : xs.min
      [facing.all? ? 0 : 1, first, route, ends.map { |u, v| cell.call(u, v) }, out, cells]
    end
    return spots.sort_by { |full, first, *| [full, first] }.map { |_full, _first, *spot| spot }
  end

  # The mask of a route that doesn't fill its rectangle (squares: all of
  # its squares).
  def mask_route(route, squares)
    return if squares.length >= route.w * route.h
    covered = squares.to_h { |c| [c, true] }
    route.mask = Array.new(route.h) { |y| Array.new(route.w) { |x| covered[[route.x + x, route.y + y]] ? "1" : "0" }.join }
  end

  # A coordinate in half squares of the frame (p) along an axis of the grid,
  # where the frame goes that way (d: 1 or -1; 0 if it goes across).
  def half_step(p, d)
    return p if d > 0
    return 2 - p if d < 0
    return 0
  end

  # The w x h towns (with that mask and joints) beyond those far squares of a
  # route, on that side: those
  # fully against the route first, then those that only touch it, from the
  # bottom or right.
  def town_spots(ends, side, w, h, mask = nil, joints = nil)
    dx, dy = DIRECTIONS[side]
    horizontal = dy == 0
    xs, ys = ends.map(&:first), ends.map(&:last)
    near = case side
           when "est" then xs.max + 1
           when "ouest" then xs.min - w
           when "sud" then ys.max + 1
           else ys.min - h
           end
    lo, hi = horizontal ? [ys.min, ys.max] : [xs.min, xs.max]
    size = horizontal ? h : w
    spots = (lo - size + 1..hi).to_a.reverse.filter_map do |t|
      town = WorldPlace.new(nil, "ville", nil, horizontal ? near : t, horizontal ? t : near, w, h, [], false)
      town.mask, town.joints = mask, joints
      facing = ends.map { |x, y| on_place?(town, x + dx, y + dy) }
      next if facing.none?
      [facing.all? ? 0 : 1, town]
    end
    return spots.sort_by.with_index { |(full, _town), i| [full, i] }.map(&:last)
  end

  # True if the square x, y of the grid is part of that place (its
  # rectangle, and its mask if it has one).
  def on_place?(wp, x, y)
    return false if x < wp.x || y < wp.y || x >= wp.x + wp.w || y >= wp.y + wp.h
    return !wp.mask || wp.mask[y - wp.y][x - wp.x] == "1"
  end

  # One opening on the edge shared by a and b (b lies on that side of a), at
  # the same spot for both: offsets count from each map's own top/left. With
  # a mask, only where both places cover their squares.
  def link(world, a, b, side, rng)
    horizontal = %w[est ouest].include?(side)
    dx, dy = DIRECTIONS[side]
    edge = horizontal ? ((dx > 0) ? a.x + a.w - 1 : a.x) : ((dy > 0) ? a.y + a.h - 1 : a.y)
    shared = (horizontal ? (a.y...a.y + a.h) : (a.x...a.x + a.w)).select do |k|
      x, y = horizontal ? [edge, k] : [k, edge]
      on_place?(a, x, y) && on_place?(b, x + dx, y + dy)
    end
    runs = shared.slice_when { |i, j| j != i + 1 }.to_a
    run = (runs.length > 1) ? runs[rng.rand(runs.length)] : runs[0]
    from, to = run.first, run.last + 1
    at = (from * world.cell) + rng.rand(4..((to - from) * world.cell) - 4 - STREET_WIDTH)
    a.exits.push([side, at - ((horizontal ? a.y : a.x) * world.cell)])
    b.exits.push([OPPOSITE[side], at - ((horizontal ? b.y : b.x) * world.cell)])
  end

  # A line for each route off the chain: its kind, its ends and the obstacle
  # of a shortcut.
  def extra_notes(built)
    return built.filter_map do |wp, *|
      next if !wp.extra
      lock = wp.lock ? ", fermé par #{wp.lock} (#{LOCKS[wp.lock]})" : ""
      "#{wp.extra} : #{wp.title}, entre #{wp.ends[0].title} et #{wp.ends[1].title}#{lock}"
    end
  end

  # MapGen world plan of the generated places. Towns can be flown to, landing
  # in front of their Pokémon Centre.
  def world_text(world, built, seed, caves = [], seabeds = [], islands = [], region = world.name, notes = [], fillers = [])
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
    built.each { |wp, *| text << "# Objets de terrain à #{wp.title} : #{wp.items.join(', ')}.\n" if wp.items }
    built.each { |wp, _place, _text, layout| text << "# Recoin : #{wp.title}, #{wp.nook}.\n" if !layout.spots[:nooks].empty? }
    (extra_notes(built) + notes).each { |note| text << "# #{note.sub(/\A./, &:upcase)}.\n" }
    built.each do |wp, *|
      text << "# Île : #{wp.island}, en bateau depuis #{wp.title}#{wp.island_gym ? ', avec une arène' : ''}.\n" if wp.island
    end
    text << "\n[Places]\n"
    built.each do |wp, _place, _text, layout|
      line = "#{wp.symbol} = #{wp.name}  type=#{wp.kind}"
      line += "  nom=#{wp.title}" if wp.title != wp.name
      centre = layout.doors.find { |_x, _y, brick| brick.kind == "centre" }
      line += "  vol=#{centre[0]},#{centre[1] + 1}" if centre
      line += "  masque=#{wp.mask.join('/')}" if wp.mask
      line += "  trace=#{wp.trace.map { |point| point.join(',') }.join('/')}" if wp.trace
      text << line << "\n"
    end
    fillers.each { |f| text << "#{f.symbol} = #{f.name}  type=decor\n" }
    text << "\n[World]\n"
    grid = Array.new(world.height) { "." * world.width }
    built.each do |wp, *|
      wp.h.times { |dy| wp.w.times { |dx| grid[wp.y + dy][wp.x + dx] = wp.symbol } }
    end
    fillers.each { |f| f.h.times { |dy| f.w.times { |dx| grid[f.y + dy][f.x + dx] = f.symbol } } }
    grid.each { |row| text << row << "\n" }
    return text
  end
end
