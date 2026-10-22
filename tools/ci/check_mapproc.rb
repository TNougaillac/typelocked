#===============================================================================
# Validates the MapProc places, worlds and bricks with the plugin's own
# parsers, then assembles each place and world with a few seeds and checks the
# result like MapGen plans (symbols, objects, tiles, world grid).
#===============================================================================
require_relative "lib/ci"

%w[001_Settings 002_Parser 003_Builder].each { |f| require File.join(ROOT, "Plugins", "MapGenerator", f) }
require_relative "lib/essentials"
Essentials.load_scripts("Overworld_RandomDungeons")
%w[001_Settings 002_Parser 003_Builder 004_World 006_Caves 008_Names 009_Atlas 010_CavePainter 011_Interiors].each { |f| require File.join(ROOT, "Plugins", "MapProceduralGenerator", f) }
M = MapProceduralGenerator
SEEDS = 1..10
# Vegetation drawn over two tiles: tile => tiles allowed just below it, so
# that no half plant shows (very tall grass T7 needs itself or its base T15).
SPILL_BELOW = { 384 + 7 => [384 + 7, 384 + 15] }.freeze

# Raises if a tile of SPILL_BELOW lacks its lower part on the row below.
def check_spill(plan, name)
  tiles = ->(c) { (plan.legend[c] || []).flatten }
  plan.rows.each_with_index do |row, y|
    row.each_char.with_index do |c, x|
      tiles.call(c).each do |tile|
        next if !(below = SPILL_BELOW[tile])
        under = plan.rows[y + 1]&.[](x)
        next if under && tiles.call(under).intersect?(below)
        raise MapGenerator::Error, "#{name} : T#{tile - 384} colonne #{x + 1}, ligne #{y + 1} sans sa partie basse dessous (moitié de plante)"
      end
    end
  end
end

# Symbols a cell of the inventory may show: ground, streets, stairs, planks
# and the bricks walked through (grass).
def walkable_symbols(place, bricks)
  symbols = [place.ground, place.street, place.pier, place.high_grass, *place.levels, *place.stairs&.join&.chars]
  symbols += M::EXCESSES.values.filter_map { |e| e[:carpet] }
  bricks.each { |b| symbols.concat(b.rows.join.delete(" ").chars) if M::WALK_KINDS.include?(b.kind) }
  return symbols.compact.uniq
end

# Raises if the inventory of a place doesn't match its map: doors on brick
# cells, the other spots on walkable cells, grass on grass.
def check_spots(name, place, bricks, layout)
  spots = layout.spots
  walkable = walkable_symbols(place, bricks)
  grass = bricks.select { |b| M::GRASS_KINDS.include?(b.kind) }.flat_map { |b| b.rows.join.delete(" ").chars }.uniq + [place.high_grass]
  at = ->(x, y) { layout.rows[y]&.[](x) }
  fail = ->(msg) { raise M::Error, "#{name} : inventaire, #{msg}" }
  fail.call("portes différentes de celles posées") if spots[:doors] != layout.doors.map { |x, y, b| [x, y, b.kind] }
  layout.doors.each do |x, y, b|
    fail.call("porte #{b.kind} #{x},#{y} hors de sa brique") if at.call(x, y) != b.rows[b.door[1]][b.door[0]]
  end
  %i[street grass dead_ends].each do |key|
    spots[key].each { |x, y| fail.call("#{key} #{x},#{y} sur « #{at.call(x, y)} »") if !walkable.include?(at.call(x, y)) }
  end
  spots[:grass].each { |x, y| fail.call("herbe #{x},#{y} sur « #{at.call(x, y)} »") if !grass.include?(at.call(x, y)) }
  # A route may be all trees or grass (excesses); a town never
  fail.call("aucune case libre au bord des rues") if spots[:street].empty? && place.kind == "ville"
end

# The dungeon tileset as Essentials' painter sees it (only what draws walls).
CaveTileset = Struct.new(:snap_to_large_grid, :double_walls, :floor_patch_under_walls) do
  def has_decoration?(_deco) = false
end
CAVE_TILESET = CaveTileset.new(false, true, true)

# Raises if a cave floor is not one piece of 2x2 blocks, if a warp is not on
# its floor, or if Essentials' painter can't draw its walls (or eats floor).
def check_cave(name, floor, map_names)
  rows = floor.rows
  fail = ->(msg) { raise M::Error, "#{name} : #{msg}" }
  cells = rows.each_with_index.flat_map { |row, y| row.each_index.select { |x| row[x] }.map { |x| [x, y] } }
  seen = { cells[0] => true }
  queue = [cells[0]]
  until queue.empty?
    cx, cy = queue.shift
    [[0, -1], [1, 0], [0, 1], [-1, 0]].each do |ox, oy|
      next if !rows[cy + oy]&.[](cx + ox) || seen[[cx + ox, cy + oy]]
      seen[[cx + ox, cy + oy]] = true
      queue.push([cx + ox, cy + oy])
    end
  end
  fail.call("étage en plusieurs morceaux") if seen.length != cells.length
  (rows.length - 1).times do |y|
    (rows[0].length - 1).times do |x|
      a, b, c, d = rows[y][x], rows[y][x + 1], rows[y + 1][x], rows[y + 1][x + 1]
      fail.call("cases reliées en diagonale seulement en #{x},#{y}") if a == d && b == c && a != b
    end
  end
  floor.warps.each do |x, y, target, _tx, _ty|
    fail.call("sortie #{x},#{y} hors du sol") if !rows[y][x] || !rows[y + 1][x]
    fail.call("sortie vers « #{target} », carte inconnue") if !map_names.include?(target)
  end
  dungeon = M::CaveDungeon.new(rows, CAVE_TILESET, Object.new, floor.seed)   # parameters: decorations only
  dungeon.instance_exec do
    Random.srand(@rng_seed)
    width, height = @usable_width - (@buffer_x * 2), @usable_height - (@buffer_y * 2)
    generate_layout(width, height)
    generate_walls(width, height)
    fail.call("murs impossibles à dessiner par Essentials") if @need_redraw
    cells.each { |x, y| fail.call("le mur mange le sol en #{x},#{y}") if !coord_is_ground?(x, y) }
  end
rescue RuntimeError => e
  fail.call("murs impossibles à dessiner par Essentials (#{e.message})")
end

# Interiors: every building type with a door has templates, each template
# map has its exit (a transfer event) where INTERIORS says.
def check_interiors(bricks)
  bricks.select(&:door).map(&:kind).uniq.each do |kind|
    next if M::NO_INTERIOR.include?(kind) || M::INTERIORS[kind]
    CI.error(File.join(ROOT, "Plugins/MapProceduralGenerator/001_Settings.rb"), nil, "INTERIORS : aucun gabarit pour les bâtiments « #{kind} »")
  end
  M::INTERIORS.values.flatten(1).uniq.each do |id, x, y|
    file = File.join(ROOT, format("Data/Map%03d.rxdata", id))
    exits = File.exist?(file) ? load_rxdata(file).instance_variable_get(:@events).values.select do |event|
      event.instance_variable_get(:@pages).any? do |page|
        (page.instance_variable_get(:@list) || []).any? { |c| c.instance_variable_get(:@code) == 201 }
      end
    end : []
    next if exits.any? { |e| [e.instance_variable_get(:@x), e.instance_variable_get(:@y)] == [x, y] }
    CI.error(File.join(ROOT, "Plugins/MapProceduralGenerator/001_Settings.rb"), nil, "INTERIORS : la carte #{id} n'a pas de sortie en #{x},#{y}")
  end
end

tilesets = load_rxdata(File.join(ROOT, "Data", "Tilesets.rxdata"))
folder = File.join(ROOT, M::FOLDER)
bricks = Dir.glob(File.join(folder, M::BRICK_FOLDER, "*.txt")).sort.filter_map do |path|
  M.parse_brick(CI.read_text(path), File.basename(path))
rescue M::Error => e
  CI.error(path, e.message[/\A[^:]*, ligne (\d+) :/, 1]&.to_i, e.message)
  nil
end

check_interiors(bricks)
paths = Dir.glob(File.join(folder, "*.txt")).sort
worlds, places = paths.partition { |path| M.world_file?(path) }
places.each do |path|
  place = M.parse_place(CI.read_text(path), File.basename(path))
  SEEDS.each do |seed|
    plan, = M.generate_place(place, bricks, seed)
    MapGenerator.check_tiles(plan, tilesets[plan.tileset_id])
    check_spill(plan, "#{File.basename(path)} (graine #{seed})")
  end
  # Every ambiance at least once
  place.ambiances.each do |ambiance|
    plan, = M.generate_place(place.dup.tap { |p| p.ambiance = ambiance.name }, bricks, 1)
    MapGenerator.check_tiles(plan, tilesets[plan.tileset_id])
  end
  # A port on each side with no exit, at the size of a world's town
  next if !place.pier
  (M::SIDES - place.exits.map(&:first)).each do |side|
    port = place.dup.tap { |p| p.port = side; p.width = p.height = 40 }
    SEEDS.each do |seed|
      plan, = M.generate_place(port, bricks, seed)
      MapGenerator.check_tiles(plan, tilesets[plan.tileset_id])
      check_spill(plan, "#{File.basename(path)} (port #{side}, graine #{seed})")
    end
  end
rescue M::Error, MapGenerator::Error => e
  CI.error(path, e.message[/\A[^:]*, ligne (\d+) :/, 1]&.to_i, e.message)
end

# Worlds: a few seeds, each place assembled and the world plan read by MapGen
%w[006_World].each { |f| require File.join(ROOT, "Plugins", "MapGenerator", f) }
worlds.each do |path|
  world = M.parse_world(CI.read_text(path), File.basename(path))
  town, route = [world.town_file, world.route_file].map do |name|
    M.parse_place(CI.read_text(File.join(folder, name)), name)
  end
  name_table = world.names_file && M.parse_names(CI.read_text(File.join(folder, world.names_file)), world.names_file)
  highest = 0
  (1..3).each do |seed|
    result = M.generate_world(world, town, route, bricks, seed, {}, name_table)
    # Levels shown on the mountain routes (each level its own symbol)
    result.places.each do |wp, place, _text, layout|
      highest = [highest, (layout.rows.join.chars.uniq & place.levels).length].max if wp.mountain
    end
    plan = MapGenerator.parse_world(result.text, "#{File.basename(path)} (graine #{seed})")
    titles = plan.places.values.map(&:display_name)
    raise M::Error, "#{File.basename(path)} (graine #{seed}) : noms affichés en double" if titles.uniq.length != titles.length
    result.places.each do |wp, place, text, layout|
      plan = MapGenerator.parse(text, place.file)
      MapGenerator.check_tiles(plan, tilesets[place.tileset_id])
      check_spill(plan, "#{wp.name} (graine #{seed})")
      check_spots("#{wp.name} (graine #{seed})", place, bricks, layout)
    end
    # The inventory: the same for the same seed, every gym and the start in it
    atlas = M.world_atlas(result)
    if seed == 1
      again = M.world_atlas(M.generate_world(world, town, route, bricks, seed, {}, name_table))
      CI.error(path, nil, "graine #{seed} : inventaire différent pour la même graine") if Marshal.dump(again) != Marshal.dump(atlas)
    end
    CI.error(path, nil, "graine #{seed} : inventaire, #{atlas[:gyms].length} arène(s) au lieu de #{world.gyms}") if atlas[:gyms].length != world.gyms
    # The first town has the professor's lab (leading to the demo's lab), or a
    # spot where the professor waits outside, never neither nor both
    first = atlas[:maps][atlas[:start]]
    lab_door = first[:doors].find { |_x, _y, kind| kind == M::LAB }
    if !lab_door == !first[:professor]
      CI.error(path, nil, "graine #{seed} : la première ville a #{lab_door ? 'un labo et' : 'ni labo ni'} une place de professeur")
    elsif lab_door && atlas[:maps][lab_door[3]]&.[](:template) != M::INTERIORS[M::LAB][0][0]
      CI.error(path, nil, "graine #{seed} : le labo ne mène pas à l'intérieur du labo de la démo")
    end
    missing = ([atlas[:start]] + atlas[:gyms]).reject { |name| atlas[:maps][name] }
    CI.error(path, nil, "graine #{seed} : inventaire sans #{missing.join(', ')}") if !missing.empty?
    # Caves: two floors each, A -> 1F -> ladder -> basement (-> B)
    map_names = result.places.map { |wp, *| wp.name } + result.caves.map { |_wp, name, *| name }
    result.caves.each do |wp, name, text, floor|
      MapGenerator.check_tiles(MapGenerator.parse(text, name), tilesets[M::CAVE_TILESET])
      check_cave("#{name} (graine #{seed})", floor, map_names)
      other = result.caves.find { |w, _n, _t, f| w.equal?(wp) && f.level != floor.level }
      CI.error(path, nil, "#{name} (graine #{seed}) : pas d'échelle vers l'autre étage") if !other || floor.warps.none? { |w| w[2] == other[1] }
      exits = (wp.crossing == "grotte") ? 1 : 1 - floor.level
      CI.error(path, nil, "#{name} (graine #{seed}) : #{exits} sortie(s) vers la route attendue(s)") if floor.warps.count { |w| w[2] == wp.name } != exits
    end
    # Each island and its port lead to each other by boat
    names = result.places.map { |wp, *| wp.name } + result.caves.map { |_wp, name, *| name }
    result.islands.each do |wp, port, place, text, layout|
      plan = MapGenerator.parse(text, place.file)
      MapGenerator.check_tiles(plan, tilesets[place.tileset_id])
      check_spill(plan, "#{wp.name} (graine #{seed})")
      check_spots("#{wp.name} (graine #{seed})", place, bricks, layout)
      port_text = result.places.find { |p, *| p.equal?(port) }[2]
      inside = result.interiors.map(&:name)
      ok = (plan.warps.values.map(&:target) - inside) == [port.name] &&
           (MapGenerator.parse(port_text, place.file).warps.values.map(&:target) - inside) == [wp.name] && !names.include?(wp.name)
      CI.error(path, nil, "#{wp.name} (graine #{seed}) : le bateau ne relie pas l'île à #{port.name}") if !ok
    end
    result.seabeds.each do |_wp, name, text|
      MapGenerator.check_tiles(MapGenerator.parse(text, name), tilesets[M::SEABED_TILESET])
    end
    # Each building door leads to its interior, whose exit leads back
    plans = (result.places.map { |wp, place, text, _layout| [wp.name, MapGenerator.parse(text, place.file)] } +
             result.islands.map { |wp, _port, place, text, _layout| [wp.name, MapGenerator.parse(text, place.file)] }).to_h
    result.interiors.each do |it|
      plan = plans[it.owner]
      symbol = plan.events[it.door[1]]&.[](it.door[0])
      warp = plan.warps[symbol]
      next if warp && warp.target == it.name && [warp.x, warp.y] == [it.exit[0], it.exit[1] - 1]
      CI.error(path, nil, "#{it.name} (graine #{seed}) : la porte #{it.door.join(',')} ne mène pas à l'intérieur")
    end
    # Every gym is on a map, in a town of the chain or on an island
    gyms = (result.places + result.islands.map { |wp, _port, place, text, layout| [wp, place, text, layout] }).sum do |*, layout|
      layout.doors.count { |_x, _y, brick| brick.kind == "arene" }
    end
    CI.error(path, nil, "graine #{seed} : #{gyms} arène(s) posée(s) au lieu de #{world.gyms}") if gyms != world.gyms
  end
  CI.error(path, nil, "aucune route de montagne au-delà de 2 niveaux (graines 1..3)") if world.mountains.max > 0 && highest <= 2
rescue M::Error, MapGenerator::Error => e
  CI.error(path, e.message[/\A[^:]*, ligne (\d+) :/, 1]&.to_i, e.message)
end

puts "#{worlds.length} mondes, #{places.length} lieux et #{bricks.length} briques lus, graines #{SEEDS} assemblées"
CI.finish("Lieux MapProc")
