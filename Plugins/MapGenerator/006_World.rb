#===============================================================================
# MapGenerator - World plans (the region as a whole: towns, routes, places)
# File format:
#   World   = TypeLocked       (required: region name on the Town Map)
#   Region  = 0                (Town Map region number, 0 by default)
#   Cell    = 20               (map tiles per world cell, 20 by default)
#   Origin  = 2,3              (Town Map square of the plan's top-left cell,
#                               0,0 by default)
#   Image   = monde.png        (Town Map image in Graphics/UI/Town Map, drawn
#                               from the plan; mapRegion<Region>.png by default)
#   Tileset = 1                (tileset and ground of the maps created empty,
#   Ground  = T1                1 and T1 by default)
#   [Places]
#   A = Bourg Typelock  vol=12,8   (one symbol = one map, found by its name;
#   1 = Route 1                     vol=x,y = fly destination on that map;
#   L = Lac  type=lieu              type=ville|route|lieu = drawing on the
#   B = Ville 2  nom=Port Lucca     Town Map, guessed from the name and vol
#                                   (decor: scenery around the places, never
#                                   walked: off the Town Map, linked to the
#                                   places it touches, corners included);
#                                   nom=... = name shown in game, the map's
#                                   name by default; masque=10/11 = the
#                                   squares of its rectangle it covers, row
#                                   by row, the others left out of the Town
#                                   Map; trace=1,1/3,1/3,4 = the line of a
#                                   route on the Town Map, in half squares
#                                   from the top-left of its rectangle;
#                                   meteo=Rain,50 = the map's Weather)
#   [World]
#   ..1..                      (one char per Town Map square, "." = nothing;
#   AAB..                       each place is one solid rectangle, places that
#                               touch are connected edge to edge)
#   [NoLinks]
#   A B                        (optional: places that touch but stay apart)
# A place whose map doesn't exist is generated from the plan of the same Name
# in MapGen/ if there is one, else created empty (Cell x size of its rectangle).
#===============================================================================
module MapGenerator
  WorldPlan = Struct.new(:file, :name, :region, :cell, :origin, :image, :tileset_id,
                         :ground, :places, :rows, :no_links)
  # x, y, width, height in world cells
  # title: name shown in game (map metadata, Town Map), nil = the map's name;
  # mask: rows of "1" (square covered) and "0", nil = the whole rectangle;
  # trace: [[x, y]...] the route's line on the Town Map, in half squares
  Place = Struct.new(:symbol, :name, :fly, :kind, :x, :y, :width, :height, :map_id, :title, :mask, :trace, :weather) do
    def display_name
      return title || name
    end

    # True if the square dx, dy of its rectangle is part of the place.
    def covers?(dx, dy)
      return !mask || mask[dy]&.[](dx) == "1"
    end
  end
  WORLD_EMPTY = "."
  PLACE_KINDS = %w[ville route lieu decor]

  module_function

  def world_file?(path)
    File.foreach(path, encoding: "UTF-8").any? { |line| line =~ /\A\uFEFF?\s*World\s*=/i }
  end

  def parse_world_file(path)
    text = File.read(path, encoding: "UTF-8").sub(/\A﻿/, "")
    return parse_world(text, File.basename(path))
  end

  def parse_world(text, file = "monde")
    plan = WorldPlan.new(file, nil, 0, 20, [0, 0], nil, 1, 384 + 1, {}, [], [])
    section = :header
    text.each_line.with_index(1) do |raw, lineno|
      line = raw.chomp
      fail_at = proc { |msg| raise Error, "#{file}, ligne #{lineno} : #{msg}" }
      if line.strip =~ /\A\[(\w+)\]\z/
        section = $1.downcase.to_sym
        fail_at.call("section inconnue [#{$1}]") unless [:places, :world, :nolinks].include?(section)
        next
      end
      if section == :world
        plan.rows.push(line.rstrip) if !line.strip.empty?
        next
      end
      content = line.sub(/#.*\z/, "").strip
      next if content.empty?
      case section
      when :places
        fail_at.call("attendu « symbole = nom de la carte [vol=x,y] »") unless content =~ /\A(\S)\s*=\s*(.+)\z/
        symbol, rest = $1, $2
        fail_at.call("« #{WORLD_EMPTY} » est réservé aux cases vides") if symbol == WORLD_EMPTY
        fly = kind = title = mask = trace = weather = nil
        # Options from the end; a value may hold spaces (nom=Port Lucca)
        while rest =~ /\A(.+?)\s+(\w+)=(\S+(?:\s+[^\s=]+)*)\z/
          rest, key, value = $1, $2, $3
          case key
          when "vol"
            fail_at.call("attendu « vol=x,y »") unless value =~ /\A(\d+),(\d+)\z/
            fly = [$1.to_i, $2.to_i]
          when "type"
            fail_at.call("type « #{value} » inconnu (#{PLACE_KINDS.join(', ')})") unless PLACE_KINDS.include?(value)
            kind = value
          when "nom"
            title = value
          when "masque"
            fail_at.call("attendu « masque=10/11 »") unless value =~ %r{\A[01]+(/[01]+)*\z}
            mask = value.split("/")
          when "trace"
            fail_at.call("attendu « trace=x,y/x,y... »") unless value =~ %r{\A\d+,\d+(/\d+,\d+)+\z}
            trace = value.split("/").map { |point| point.split(",").map(&:to_i) }
          when "meteo"
            fail_at.call("attendu « meteo=Rain,50 »") unless value =~ /\A\w+,\d+\z/
            weather = value
          else fail_at.call("option « #{key} » inconnue (vol, type, nom, masque, trace, meteo)")
          end
        end
        plan.places[symbol] = Place.new(symbol, rest.strip, fly, kind)
        plan.places[symbol].title = title
        plan.places[symbol].mask = mask
        plan.places[symbol].trace = trace
        plan.places[symbol].weather = weather
      when :nolinks
        fail_at.call("attendu deux symboles, par exemple « A B »") unless content =~ /\A(\S)\s+(\S)\z/
        plan.no_links.push([$1, $2].sort)
      else
        fail_at.call("attendu « Clé = valeur »") unless content =~ /\A(\w+)\s*=\s*(.+)\z/
        key, value = $1.downcase, $2.strip
        case key
        when "world"   then plan.name = value
        when "region"  then plan.region = value.to_i
        when "cell"    then plan.cell = value.to_i
        when "image"   then plan.image = value
        when "tileset" then plan.tileset_id = value.to_i
        when "origin"
          fail_at.call("attendu « Origin = x,y »") unless value =~ /\A(\d+)\s*,\s*(\d+)\z/
          plan.origin = [$1.to_i, $2.to_i]
        when "ground"
          fail_at.call("attendu « Ground = T<n> »") unless value =~ /\AT(\d+)\z/
          plan.ground = 384 + $1.to_i
        else fail_at.call("clé « #{$1} » inconnue")
        end
      end
    end
    raise Error, "#{file} : la clé « World » est obligatoire" if !plan.name
    raise Error, "#{file} : « Cell » doit être au moins 1" if plan.cell < 1
    raise Error, "#{file} : la section [World] est vide" if plan.rows.empty?
    find_world_rectangles(plan)
    return plan
  end

  # Each symbol must fill exactly one rectangle of the [World] grid.
  def find_world_rectangles(plan)
    cells = {}
    plan.rows.each_with_index do |row, y|
      row.each_char.with_index do |c, x|
        next if c == WORLD_EMPTY || c == " "
        raise Error, "#{plan.file} : le symbole « #{c} » (#{x},#{y}) n'est pas dans [Places]" if !plan.places[c]
        (cells[c] ||= []).push([x, y])
      end
    end
    plan.places.each_value do |place|
      list = cells[place.symbol]
      raise Error, "#{plan.file} : « #{place.symbol} » (#{place.name}) n'est pas placé dans [World]" if !list
      xs = list.map { |p| p[0] }
      ys = list.map { |p| p[1] }
      place.x, place.y = xs.min, ys.min
      place.width, place.height = xs.max - xs.min + 1, ys.max - ys.min + 1
      if list.length != place.width * place.height
        raise Error, "#{plan.file} : « #{place.symbol} » (#{place.name}) doit former un seul rectangle plein"
      end
      next if !place.mask
      if place.mask.length != place.height || place.mask.any? { |row| row.length != place.width } || place.mask.join.count("1") == 0
        raise Error, "#{plan.file} : le masque de « #{place.symbol} » (#{place.name}) ne couvre pas son rectangle (#{place.width}x#{place.height})"
      end
    end
    plan.no_links.each do |pair|
      pair.each { |s| raise Error, "#{plan.file} : [NoLinks] « #{s} » n'est pas dans [Places]" if !plan.places[s] }
    end
  end

  # Edge-to-edge connections between places that touch, as PBS records:
  # [map1, edge1, pos1, map2, edge2, pos2], positions in tiles along the edge.
  # A decor touching a place by a corner is linked too (east side, past the
  # corner), so it shows from there; two decors are never linked.
  def world_links(plan)
    links = []
    places = plan.places.values
    places.each do |a|
      places.each do |b|
        next if a.equal?(b) || plan.no_links.include?([a.symbol, b.symbol].sort)
        decor = [a, b].count { |place| place.kind == "decor" }
        next if decor == 2
        if decor == 1 && a.x + a.width == b.x
          if a.y + a.height == b.y
            links.push([a, "E", a.height * plan.cell, b, "W", 0])
            next
          elsif b.y + b.height == a.y
            links.push([a, "E", 0, b, "W", b.height * plan.cell])
            next
          end
        end
        if a.x + a.width == b.x && a.y < b.y + b.height && b.y < a.y + a.height
          d = (b.y - a.y) * plan.cell
          links.push([a, "E", [d, 0].max, b, "W", [-d, 0].max])
        elsif a.y + a.height == b.y && a.x < b.x + b.width && b.x < a.x + a.width
          d = (b.x - a.x) * plan.cell
          links.push([a, "S", [d, 0].max, b, "N", [-d, 0].max])
        end
      end
    end
    return links
  end

  #-----------------------------------------------------------------------------
  # Maps
  #-----------------------------------------------------------------------------
  # Finds or creates the map of each place. Returns notes for the player.
  def resolve_world_maps(plan)
    notes = []
    infos = load_data("Data/MapInfos.rxdata")
    micro = nil
    plan.places.each_value do |place|
      place.map_id = infos.select { |_id, info| info.name == place.name }.keys.min
      if !place.map_id
        micro ||= plan_files.reject { |f| world_file?(f) }.map { |f| parse_file(f) rescue nil }.compact
        source = micro.find { |p| p.name == place.name }
        if source
          place.map_id, = generate(source)
          notes.push(_INTL("« {1} » : carte {2} générée depuis {3}.", place.name, place.map_id, source.file))
        else
          place.map_id = create_empty_map(plan, place)
          notes.push(_INTL("« {1} » : carte vide {2} créée ({3}x{4}).", place.name, place.map_id,
                           place.width * plan.cell, place.height * plan.cell))
        end
        infos = load_data("Data/MapInfos.rxdata")
      end
      map = load_data(sprintf("Data/Map%03d.rxdata", place.map_id))
      want_w, want_h = place.width * plan.cell, place.height * plan.cell
      # Each place covers as many squares as its map holds cells, at its scale
      cells_w = [(map.width + (plan.cell / 2)) / plan.cell, 1].max
      cells_h = [(map.height + (plan.cell / 2)) / plan.cell, 1].max
      if cells_w != place.width || cells_h != place.height
        notes.push(_INTL("« {1} » ({2}x{3} tuiles) doit couvrir {4}x{5} cases dans [World], pas {6}x{7}.",
                         place.name, map.width, map.height, cells_w, cells_h, place.width, place.height))
      elsif map.width != want_w || map.height != want_h
        notes.push(_INTL("« {1} » mesure {2}x{3}, le plan du monde attend {4}x{5} : les raccords peuvent être décalés.",
                         place.name, map.width, map.height, want_w, want_h))
      end
    end
    return notes
  end

  def create_empty_map(plan, place)
    infos = load_data("Data/MapInfos.rxdata")
    map_id = (infos.keys.max || 0) + 1
    map = RPG::Map.new(place.width * plan.cell, place.height * plan.cell)
    map.tileset_id = plan.tileset_id
    map.width.times { |x| map.height.times { |y| map.data[x, y, 0] = plan.ground } }
    info = RPG::MapInfo.new
    info.name = place.name
    info.order = (infos.values.map { |i| i.order }.max || 0) + 1
    infos[map_id] = info
    save_data(map, sprintf("Data/Map%03d.rxdata", map_id))
    save_data(infos, "Data/MapInfos.rxdata")
    return map_id
  end

  #-----------------------------------------------------------------------------
  # PBS files (only the lines about the world's maps are rewritten)
  #-----------------------------------------------------------------------------
  def read_pbs(path)
    return [] if !File.exist?(path)
    return File.read(path, encoding: "UTF-8").sub(/\A﻿/, "").split("\n", -1).tap { |l| l.pop if l.last == "" }
  end

  def write_pbs(path, lines)
    File.write(path, "﻿" + lines.join("\n") + "\n", encoding: "UTF-8")
  end

  # Drops the old connections between two maps of the world (and their comment
  # line), then adds the new ones.
  def update_connections(lines, plan, links)
    ids = plan.places.values.map(&:map_id)
    kept = []
    lines.each do |line|
      fields = line.split(",")
      if fields.length == 6 && ids.include?(fields[0].to_i) && ids.include?(fields[3].to_i)
        kept.pop if kept.last && kept.last.start_with?("#") && !kept.last.start_with?("#-")
        next
      end
      kept.push(line)
    end
    links.each do |a, edge_a, pos_a, b, edge_b, pos_b|
      kept.push("# #{a.name} (#{a.map_id}) - #{b.name} (#{b.map_id})")
      kept.push("#{a.map_id},#{edge_a},#{pos_a},#{b.map_id},#{edge_b},#{pos_b}")
    end
    return kept
  end

  # Sets Name, Outdoor, ShowArea, MapPosition, MapSize and Weather in each
  # place's section, other keys are kept.
  def update_map_metadata(lines, plan)
    plan.places.each_value do |place|
      x = plan.origin[0] + place.x
      y = plan.origin[1] + place.y
      shown = place.kind != "decor"
      values = {
        "Name"        => place.display_name,
        "Outdoor"     => "true",
        "ShowArea"    => shown ? "true" : nil,
        "MapPosition" => shown ? "#{plan.region},#{x},#{y}" : nil,
        "MapSize"     => (shown && place.width * place.height > 1) ? "#{place.width},#{place.mask&.join || ('1' * (place.width * place.height))}" : nil,
        "Weather"     => place.weather
      }
      start = lines.index { |l| l =~ /\A\[0*#{place.map_id}\]/ }
      if !start
        lines.push("#-------------------------------") if !lines.empty?
        lines.push(sprintf("[%03d]   # %s", place.map_id, place.name))
        start = lines.length - 1
      end
      finish = start + 1
      finish += 1 while finish < lines.length && lines[finish] !~ /\A\[|\A#-/
      body = lines[start + 1...finish].reject { |l| values.key?(l[/\A(\w+)\s*=/, 1]) }
      values.each { |key, value| body.push("#{key} = #{value}") if value }
      lines[start + 1...finish] = body
    end
    return lines
  end

  # Replaces the region's Points on the world's squares or with a place name.
  def update_town_map(lines, plan)
    start = lines.index { |l| l.strip == "[#{plan.region}]" }
    if !start
      lines.push("#-------------------------------") if !lines.empty?
      lines.push("[#{plan.region}]")
      start = lines.length - 1
    end
    finish = start + 1
    finish += 1 while finish < lines.length && lines[finish] !~ /\A\[|\A#-/
    squares = {}
    plan.places.each_value do |place|
      next if place.kind == "decor"
      place.height.times do |dy|
        place.width.times do |dx|
          next if !place.covers?(dx, dy)
          squares[[plan.origin[0] + place.x + dx, plan.origin[1] + place.y + dy]] = place
        end
      end
    end
    names = plan.places.values.flat_map { |p| [p.name, p.display_name] }
    body = lines[start + 1...finish].reject do |l|
      next true if l.start_with?("Name") || (plan.image && l.start_with?("Filename"))
      next false unless l =~ /\APoint\s*=\s*(\d+),(\d+),([^,]*)/
      # A region drawn from the plan (Image) only has the plan's places: the
      # points of an earlier world with other names go too
      plan.image || squares[[$1.to_i, $2.to_i]] || names.include?($3)
    end
    head = ["Name = #{plan.name}"]
    if !body.any? { |l| l.start_with?("Filename") }
      head.push("Filename = #{plan.image || "mapRegion#{plan.region}.png"}")
    end
    points = squares.sort_by { |(x, y), _| [y, x] }.map do |(x, y), place|
      point = "Point = #{x},#{y},#{place.display_name}"
      point += ",,#{place.map_id},#{place.fly[0]},#{place.fly[1]}" if place.fly
      point
    end
    lines[start + 1...finish] = head + body + points
    return lines
  end

  #-----------------------------------------------------------------------------
  # Generation
  #-----------------------------------------------------------------------------
  CONNECTIONS_PBS = "PBS/map_connections.txt"
  MAP_METADATA_PBS = "PBS/map_metadata.txt"
  TOWN_MAP_PBS = "PBS/town_map.txt"

  # Returns [links, notes].
  def generate_world(plan)
    notes = resolve_world_maps(plan)
    links = world_links(plan)
    write_pbs(CONNECTIONS_PBS, update_connections(read_pbs(CONNECTIONS_PBS), plan, links))
    write_pbs(MAP_METADATA_PBS, update_map_metadata(read_pbs(MAP_METADATA_PBS), plan))
    write_pbs(TOWN_MAP_PBS, update_town_map(read_pbs(TOWN_MAP_PBS), plan))
    notes.push(draw_region_image(plan, links))
    return links, notes
  end

  # Recompiles the three PBS files so the game uses them right away.
  def compile_world_pbs
    Compiler.compile_town_map(TOWN_MAP_PBS)
    Compiler.compile_connections(CONNECTIONS_PBS)
    Compiler.compile_map_metadata(MAP_METADATA_PBS)
    MapFactoryHelper.clear
  end

  # quiet: notes go to the console only (world made while playing).
  def run_world(path, quiet: false)
    plan = parse_world_file(path)
    links, notes = generate_world(plan)
    compile_world_pbs
    Console.echoln_li(_INTL("{1} : {2} lieux, {3} raccords", File.basename(path), plan.places.length, links.length))
    if quiet
      notes.compact.each { |n| Console.echoln_li(n) }
      return
    end
    pbMessage(_INTL("{1} : monde « {2} » généré, {3} lieux et {4} raccords.",
                    File.basename(path), plan.name, plan.places.length, links.length))
    notes.each { |n| pbMessage(n) }
  end
end
