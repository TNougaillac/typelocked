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
#   Arenes   = 8               (towns with a gym, the last ones of the chain;
#                               Villes - 1 by default)
#   Longueur = 2..4            (route length in squares, 2..4 by default)
#   Noms     = Bourg Typelock, Ville Rubis, ...
#                              (optional town names, in order; "Ville
#                               générée 1"... otherwise; routes are "Route
#                               générée 1"...)
# The towns (2x2 squares) form a chain linked by routes (1 square wide), each
# town a little further from the start, so the gyms come in that order. Each
# place is assembled from its place file with the exits facing its
# neighbours, then MapGen writes the maps, the connections and the Town Map
# from the world plan made here.
#===============================================================================
module MapProceduralGenerator
  World = Struct.new(:file, :name, :region, :image, :origin, :width, :height, :cell,
                     :town_file, :route_file, :towns, :gyms, :route_length, :names)
  # kind: "ville" or "route"; x, y, w, h in squares; exits: [side, offset]
  WorldPlace = Struct.new(:symbol, :kind, :name, :x, :y, :w, :h, :exits, :gym, :index)
  # text: MapGen world plan; places: [WorldPlace, Place, MapGen plan text, Layout]
  WorldResult = Struct.new(:text, :places)

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
    world = World.new(file, nil, 0, nil, [0, 0], nil, nil, 20, nil, nil, nil, nil, 2..4, [])
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
      else fail_at.call("clé inconnue « #{key} »")
      end
    end
    { "Monde" => world.name, "Taille" => world.width, "Ville" => world.town_file,
      "Route" => world.route_file, "Villes" => world.towns }.each do |key, value|
      raise Error, "#{file} : « #{key} » manquant" if !value
    end
    world.gyms ||= world.towns - 1
    raise Error, "#{file} : « Arenes » dépasse « Villes »" if world.gyms > world.towns
    raise Error, "#{file} : « Villes » doit être entre 1 et #{TOWN_SYMBOLS.length}" if !(1..TOWN_SYMBOLS.length).include?(world.towns)
    raise Error, "#{file} : « Longueur » doit commencer à 1 au moins" if world.route_length.min < 1
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
      place_seed = (seed * 1000) + wp.index
      _plan, text, layout = generate_place(place, bricks, place_seed)
      [wp, place, text, layout]
    end
    return WorldResult.new(world_text(world, built, seed), built)
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
    towns.each_with_index { |t, i| t.gym = i >= world.towns - world.gyms }
    places.each_with_index { |p, i| p.index = i }
    return places
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
