#===============================================================================
# Validates the MapProc places, worlds and bricks with the plugin's own
# parsers, then assembles each place and world with a few seeds and checks the
# result like MapGen plans (symbols, objects, tiles, world grid).
#===============================================================================
require_relative "lib/ci"

%w[001_Settings 002_Parser 003_Builder].each { |f| require File.join(ROOT, "Plugins", "MapGenerator", f) }
require_relative "lib/essentials"
Essentials.load_scripts("Overworld_RandomDungeons")
%w[001_Settings 002_Parser 003_Builder 003_Builder_Bricks 003_Builder_Crossings 003_Builder_Relief 003_Builder_Sea 003_Builder_Streets 004_World 006_Caves 008_Names 009_Atlas 010_CavePainter 011_Interiors 013_Fillers].each { |f| require File.join(ROOT, "Plugins", "MapProceduralGenerator", f) }
M = MapProceduralGenerator
SEEDS = 1..10
# Seeds of the worlds (WORLD_SEEDS=20 or WORLD_SEEDS=6..8 to try others
# locally)
# Gap allowed between the share of nooks to come back to and « Revisiter »
REVISIT_MARGIN = 30
WORLD_SEEDS = (ENV["WORLD_SEEDS"] || "3").then { |s| s.include?("..") ? Range.new(*s.split("..").map(&:to_i)) : 1..s.to_i }
# Vegetation drawn over two tiles: tile => tiles allowed just below it, so
# that no half plant shows (very tall grass T18063 needs itself or its base: T15, or
# T151, T175, T181, T189, T14637 on the meadow, sand, dirt, gravel and snow).
# The very tall grass (its top row T18063, the rows below T14915) has its foot
# (or more of it) on the row below
VERY_TALL_BELOW = [14915, 15, 151, 175, 181, 189, 14637].map { |n| 384 + n }.freeze
SPILL_BELOW = { 384 + 18_063 => VERY_TALL_BELOW, 384 + 14915 => VERY_TALL_BELOW }.freeze

# Records the bricks each builder lays (with its place), to check that a
# brick kept for some ambiances is never laid elsewhere.
module LaidBricks
  def put_brick(brick, *rest)
    spot = super
    if spot && brick.ambiances && !brick.ambiances.include?(@place.ambiance)
      raise M::Error, "#{@place.name} : brique « #{brick.name} » (#{brick.ambiances.join(', ')}) posée en ambiance « #{@place.ambiance} »"
    end
    return spot
  end
end
M::PlaceBuilder.prepend(LaidBricks)

# Stairs drawn in a cliff face, 2 tiles wide: left halves, right halves.
STAIR_LEFT = [769, 777].map { |n| 384 + n }.freeze
STAIR_RIGHT = [770, 778].map { |n| 384 + n }.freeze
# Cells of a cliff in a plan: its terrains, and the relief cells (a level's
# cliff, drawn by MapGen from the levels, or a border tree joined to them)
RELIEF_CELLS = %w[ɸ ʘ].freeze

# Raises on a stair that isn't whole (each left half followed by a right
# half, nothing else in the run) or that leaves the cliff (the cells beside
# the run are a cliff or a rock, not the ground).
def check_stairs(plan, name)
  side = lambda do |c|
    t = (plan.legend[c] || []).flatten
    return nil if plan.terrains.key?(c)
    return :left if t.intersect?(STAIR_LEFT)
    return :right if t.intersect?(STAIR_RIGHT)
    return nil
  end
  plan.rows.each_with_index do |row, y|
    x = 0
    while x < row.length
      if !side.call(row[x])
        x += 1
        next
      end
      start = x
      x += 1 while x < row.length && side.call(row[x])
      halves = (start...x).map { |i| side.call(row[i]) }
      whole = halves.each_slice(2).all? { |pair| pair == %i[left right] }
      raise MapGenerator::Error, "#{name} : escalier incomplet ligne #{y + 1}, colonnes #{start + 1}-#{x}" if !whole
      [start - 1, x].each do |i|
        next if i < 0 || i >= row.length || plan.terrains.key?(row[i]) || RELIEF_CELLS.include?(row[i])
        raise MapGenerator::Error, "#{name} : escalier hors de la falaise ligne #{y + 1}, colonne #{i + 1}"
      end
    end
  end
end

# Raises unless every patch of tall grass has the tips of its blades on its
# top row only and their foot on its bottom row only (GRASS_EDGES: middle,
# top, bottom, lone row), and very tall grass its tips on its top row only.
def check_grass_edges(plan, name)
  family = M::GRASS_EDGES.flat_map { |c, edges| [c, *edges.chars] }
  M::GRASS_EDGES.each do |middle, edges|
    next if !edges.each_char.all? { |e| plan.legend[e] }
    roles = { middle => [true, true], edges[0] => [false, true], edges[1] => [true, false], edges[2] => [false, false] }
    plan.rows.each_with_index do |row, y|
      row.each_char.with_index do |c, x|
        next if !(role = roles[c])
        found = [y > 0 && family.include?(plan.rows[y - 1][x]), family.include?(plan.rows[y + 1]&.[](x))]
        next if found == role
        raise MapGenerator::Error, "#{name} : hautes herbes « #{c} » colonne #{x + 1}, ligne #{y + 1} : mauvais bord (pointes en haut, pied en bas)"
      end
    end
  end
  M::VERY_TALL.each do |top, below|
    next if !plan.legend[below]
    plan.rows.each_with_index do |row, y|
      row.each_char.with_index do |c, x|
        above = y > 0 ? plan.rows[y - 1][x] : nil
        bad = (c == top && [top, below].include?(above)) || (c == below && ![top, below].include?(above))
        raise MapGenerator::Error, "#{name} : herbes très hautes colonne #{x + 1}, ligne #{y + 1} : pointes ailleurs qu'en haut de la touffe" if bad
      end
    end
  end
end

# Raises if a tile of SPILL_BELOW lacks its lower part on the row below.
# The rocks in the water (autotile A6, HGSS Rocks) are drawn only whole, 2x2:
# a lone cell draws nothing, wider the autotile draws its unused middle pieces.
ROCK_AUTOTILE = 48 * 6

def check_water_rocks(plan, name)
  rocks = plan.legend.select { |_c, layers| layers.flatten.include?(ROCK_AUTOTILE) }.keys
  return if rocks.empty?
  rows = plan.rows
  rock = ->(x, y) { y >= 0 && y < rows.length && x >= 0 && x < rows[y].length && rocks.include?(rows[y][x]) }
  seen = {}
  rows.each_with_index do |row, y|
    row.length.times do |x|
      next if seen[[x, y]] || !rock.call(x, y)
      group = [[x, y]]
      seen[[x, y]] = true
      group.each do |cx, cy|
        [[1, 0], [-1, 0], [0, 1], [0, -1]].each do |dx, dy|
          n = [cx + dx, cy + dy]
          next if seen[n] || !rock.call(*n)
          seen[n] = true
          group.push(n)
        end
      end
      w = group.map(&:first).minmax.then { |lo, hi| hi - lo + 1 }
      h = group.map(&:last).minmax.then { |lo, hi| hi - lo + 1 }
      next if w == 2 && h == 2 && group.length == 4
      raise MapGenerator::Error, "#{name} : rocher dans l'eau de #{w}x#{h} colonne #{x + 1}, ligne #{y + 1} (2x2 seulement)"
    end
  end
end

# The drawing of an object beyond its block (its halo, not its empty cells)
# never covers another object's block or drawing: each one is drawn whole.
def check_object_halos(plan, name)
  owner = {}   # cell => [instance, :block or :halo]
  rows = plan.rows
  rows.each_with_index do |row, y|
    row.each_char.with_index do |c, x|
      object = plan.objects[c]
      next if !object&.halo || object.forest
      start = (0..x).reverse_each.take_while { |tx| row[tx] == c }.last
      left = x - ((x - start) % object.width)
      top = (0..y).reverse_each.take_while { |ty| rows[ty][x] == c }.last
      next if left != x || (y - top) % object.height != 0
      hw, hh, hx, hy, empty = object.halo
      hh.times do |j|
        hw.times do |i|
          next if empty.include?((j * hw) + i)
          role = (i >= hx && i < hx + object.width && j >= hy && j < hy + object.height) ? :block : :halo
          cell = [x + i - hx, y + j - hy]
          other = owner[cell]
          if other && other[0] != [x, y] && (role == :halo || other[1] == :halo)
            raise MapGenerator::Error, "#{name} : le dessin de « #{c} » colonne #{x + 1}, ligne #{y + 1} recouvre celui d'un autre objet " \
                                       "(colonne #{cell[0] + 1}, ligne #{cell[1] + 1})"
          end
          owner[cell] = [[x, y], role] if !other || role == :block
        end
      end
    end
  end
  check_forest_canopies(plan, name, owner)
end

# A forest's canopy (2 rows above its top trees, a column of leaves on each
# side, MapGenerator's draw_forest) never covers another object or its drawing.
def check_forest_canopies(plan, name, owner)
  rows = plan.rows
  at = ->(x, y) { y >= 0 && x >= 0 ? rows[y]&.[](x) : nil }
  rows.each_with_index do |row, y|
    row.each_char.with_index do |c, x|
      next if !plan.objects[c]&.forest
      cells = []
      cells.push([x, y - 1], [x, y - 2]) if at.call(x, y - 1) != c
      cells.push([x - 1, y]) if at.call(x - 1, y) != c
      cells.push([x + 1, y]) if at.call(x + 1, y) != c
      cells.each do |cx, cy|
        other = at.call(cx, cy)
        next if !other || (other != c && !plan.objects[other] && !owner[[cx, cy]])
        next if other == c
        raise MapGenerator::Error, "#{name} : la cime de la forêt « #{c} » colonne #{x + 1}, ligne #{y + 1} recouvre un autre objet " \
                                   "(colonne #{cx + 1}, ligne #{cy + 1})"
      end
    end
  end
end

# True if one of those bricks stands whole somewhere in the rows (its
# spaces left out).
def hq_drawn?(rows, hq_bricks)
  hq_bricks.any? do |brick|
    cells = brick.rows.each_with_index.flat_map { |row, dy| row.each_char.with_index.filter_map { |c, dx| [dx, dy, c] if c != " " } }
    (0...rows.length).any? do |y|
      (0...rows[0].length).any? { |x| cells.all? { |dx, dy, c| rows[y + dy]&.[](x + dx) == c } }
    end
  end
end

# A cliff terrain (it draws a rim, oN) has its « V » pieces just right of its
# SW corner on SirMalo's sheet (SW+10, SW+11). They are no north inner corner:
# drawn, they leave a notch in a level's rim or corner tiles in a filled
# mound. Levels never make a north inner corner (thicken, bare_border) and a
# mound with a top (centre tile) takes it there: no generated map holds one.
def check_cliff_corners(plan, name)
  cliffs = plan.terrains.select { |_symbol, terrain| terrain.roles["oN"] && terrain.roles["SW"] }
  cliffs.each do |symbol, terrain|
    next if terrain.center == 0 || !(terrain.roles.keys & %w[iNW iNE]).any?
    raise MapGenerator::Error, "#{name} : le massif « #{symbol} » a un dessus mais déclare iNW/iNE : ses marches prennent son remplissage"
  end
  pieces = cliffs.values.flat_map { |terrain| [terrain.roles["SW"] + 10, terrain.roles["SW"] + 11] }.uniq
  return if pieces.empty?
  # The terrain tiles as the builder picks them, on a bare grid (the CI's
  # Table only loads)
  data = Hash.new(0)
  def data.[](x, y, z) = fetch([x, y, z], 0)
  def data.[]=(x, y, z, id)
    store([x, y, z], id)
  end
  MapGenerator.apply_terrains(plan, plan.rows, data, nil)
  plan.overlays.each { |z, rows| MapGenerator.apply_terrains(plan, rows, data, z) }
  data.each do |(x, y, _z), id|
    next if !pieces.include?(id)
    raise MapGenerator::Error, "#{name} : coin rentrant nord (pointe de falaise T#{id - 384}) colonne #{x + 1}, ligne #{y + 1} : un niveau garde un bord droit, une butte se remplit"
  end
end

def check_spill(plan, name)
  check_stairs(plan, name)
  check_cliff_corners(plan, name)
  check_grass_edges(plan, name)
  check_water_rocks(plan, name)
  check_object_halos(plan, name)
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

# Raises on a sea cell (autotile A1 or A7) with a dirty edge: below it, only more
# water, the place's bank tiles, a mountain level (it draws its own top) or
# the map's edge (anything when the water draws its own bank, « EauBordee »);
# and every sea cell in some 2x2 block of water (edges count).
def check_water(plan, name, place)
  sea = plan.legend.select { |_c, layers| layers.flatten.any? { |t| M::SEA_TILES.include?(t) } }.keys
  wet = sea + plan.objects.select { |_c, o| sea.include?(o.ground) }.keys + plan.terrains.select { |_c, t| sea.include?(t.ground) }.keys
  clean = wet + place.banks.to_s.chars + place.levels.to_a + [M::CLIFF]
  rows = plan.rows
  at = ->(x, y) { y < 0 || y >= rows.length || x < 0 || x >= rows[y].length || wet.include?(rows[y][x]) }
  rows.each_with_index do |row, y|
    row.each_char.with_index do |c, x|
      next if !sea.include?(c)
      below = rows[y + 1]&.[](x)
      if below && !place.edged_water && !clean.include?(below)
        raise MapGenerator::Error, "#{name} : eau colonne #{x + 1}, ligne #{y + 1} sans rive dessous (#{below.inspect})"
      end
      block = [[-1, -1], [0, -1], [-1, 0], [0, 0]].any? { |ox, oy| [[0, 0], [1, 0], [0, 1], [1, 1]].all? { |dx, dy| at.call(x + ox + dx, y + oy + dy) } }
      raise MapGenerator::Error, "#{name} : eau trop fine colonne #{x + 1}, ligne #{y + 1}" if !block
    end
  end
end

# Symbols a cell of the inventory may show: ground, streets, banks, stairs, planks
# and the bricks walked through (grass).
def walkable_symbols(place, bricks)
  symbols = [place.ground, place.street, place.pier, place.high_grass, *place.levels, *place.stairs&.join&.chars]
  symbols += M::EXCESSES.values.filter_map { |e| e[:carpet] }
  symbols += place.banks.to_s.chars  # the bank below the water (blocked only upwards)
  symbols += (M::GRASS_EDGES.values + M::VERY_TALL.values).join.chars  # the edges of the tall grass
  symbols.push(M::TRANSITION[:ground]) if place.kind == "route"  # a stretch of sand
  bricks.each { |b| symbols.concat(b.rows.join.delete(" ").chars) if M::WALK_KINDS.include?(b.kind) }
  return symbols.compact.uniq
end

# Symbols that block the way (the marsh's mud, #205; lava, #206): never on a cell walked
# from the exits, and every exit and door still reached past them.
BLOCKING = %w[ɓ ɫ].freeze

def check_blocking(name, layout)
  spots = layout.spots
  ground = spots[:ground].to_h { |cell| [cell, true] }
  spots[:ground].each do |x, y|
    raise M::Error, "#{name} : boue ou lave #{x + 1},#{y + 1} sur un passage" if BLOCKING.include?(layout.rows[y][x])
  end
  needed = spots[:exits].map { |_side, x, y| [x, y] } + layout.doors.map { |x, y, brick| M.door_front(x, y, brick) }
  needed.each { |cell| raise M::Error, "#{name} : #{cell.map { |v| v + 1 }.join(',')} coupé du reste par la boue ou la lave" if !ground[cell] }
end

# Raises if the inventory of a place doesn't match its map: doors on brick
# cells, the other spots on walkable cells, grass on grass.
def check_spots(name, place, bricks, layout)
  spots = layout.spots
  walkable = walkable_symbols(place, bricks)
  grass = bricks.select { |b| M::GRASS_KINDS.include?(b.kind) }.flat_map { |b| b.rows.join.delete(" ").chars }.uniq + [place.high_grass] +
          (M::GRASS_EDGES.values + M::VERY_TALL.values).join.chars
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

# Cells walked to from the exits of a place over its walkable symbols (a
# level only through its stairs, water by surfing when surf), the cell
# blocked (a nook's obstacle) left out, the cells through (a wall crossed
# with the Grappling Hook) walked.
def reached(place, bricks, layout, surf:, blocked: nil, exits: layout.exits, through: [])
  stairs = place.stairs&.join&.chars || []
  walkable = walkable_symbols(place, bricks) - stairs
  walkable += [place.water, place.deep, place.bank].compact if surf  # a sandbank is surfed to
  height = ->(c) { place.levels&.index(c) || -1 }
  rows = layout.rows
  ok = lambda do |x, y|
    next true if through.include?([x, y])
    y >= 0 && x >= 0 && rows[y] && x < rows[y].length && [x, y] != blocked && (walkable.include?(rows[y][x]) || stairs.include?(rows[y][x]))
  end
  seen = {}
  queue = exits.map { |_side, x, y| [x, y] }.select { |x, y| ok.call(x, y) }
  queue.each { |cell| seen[cell] = true }
  until queue.empty?
    x, y = queue.shift
    [[0, -1], [1, 0], [0, 1], [-1, 0]].each do |ox, oy|
      nx, ny = x + ox, y + oy
      next if seen[[nx, ny]] || !ok.call(nx, ny)
      a, b = rows[y][x], rows[ny][nx]
      next if height.call(a) != height.call(b) && !stairs.include?(a) && !stairs.include?(b) && !through.include?([nx, ny]) && !through.include?([x, y])
      seen[[nx, ny]] = true
      queue.push([nx, ny])
    end
  end
  return seen
end

# Raises if the loot of a nook can be reached without its obstacle (opened
# or surfed), or not with it.
def check_nooks(name, place, bricks, layout)
  layout.spots[:nooks].each do |x, y, obstacle, ox, oy, fx, fy|
    next if obstacle == "sombre"   # the loot is in the dark cave
    closed = (obstacle == "ilot") ? reached(place, bricks, layout, surf: false) : reached(place, bricks, layout, surf: true, blocked: [ox, oy])
    raise M::Error, "#{name} : le butin du recoin #{obstacle} (#{x},#{y}) s'atteint sans son obstacle" if closed[[x, y]]
    # The Grappling Hook's wall, the ice slid across with the Skates
    wall = (obstacle == M::GRAPPLE || M::CROSSINGS[obstacle]) ? grapple_wall(ox, oy, fx, fy) : []
    raise M::Error, "#{name} : le butin du recoin #{obstacle} (#{x},#{y}) ne s'atteint pas avec son objet" if !reached(place, bricks, layout, surf: true, through: wall)[[x, y]]
  end
end

# The cells of a wall crossed with the Grappling Hook, from one face to the
# other.
def grapple_wall(ox, oy, fx, fy)
  return (([ox, fx].min..[ox, fx].max).to_a.product(([oy, fy].min..[oy, fy].max).to_a))
end

# Raises if a shortcut's lock lets the player through from its exit without
# its obstacle (opened or surfed), or not with it.
def check_lock(name, place, bricks, layout)
  return if !place.lock
  raise M::Error, "#{name} : raccourci sans obstacle" if !layout.spots[:lock]
  obstacle, x, y, fx, fy = layout.spots[:lock]
  from = [layout.exits[place.lock[1]]]
  others = layout.exits - from
  closed = (obstacle == "eau") ? reached(place, bricks, layout, surf: false, exits: from) : reached(place, bricks, layout, surf: true, blocked: [x, y], exits: from)
  raise M::Error, "#{name} : le raccourci se passe sans son obstacle #{obstacle}" if others.any? { |_side, ex, ey| closed[[ex, ey]] }
  wall = (obstacle == M::GRAPPLE) ? grapple_wall(x, y, fx, fy) : []
  open = reached(place, bricks, layout, surf: true, exits: from, through: wall)
  raise M::Error, "#{name} : le raccourci ne se passe pas avec son objet" if !others.all? { |_side, ex, ey| open[[ex, ey]] }
end

# Raises if a place with a mask can be walked outside the squares it covers,
# or has an exit off them.
def check_mask(name, place, bricks, layout)
  return if !place.mask
  cell = place.width / place.mask[0].length
  covered = ->(x, y) { place.mask[y / cell]&.[](x / cell) == "1" }
  layout.exits.each do |side, x, y|
    next if (0...M::STREET_WIDTH).all? { |o| covered.call(x + o, y) && covered.call(x, y + o) }
    raise M::Error, "#{name} : sortie #{side} (#{x},#{y}) hors du tracé"
  end
  outside = reached(place, bricks, layout, surf: true).keys.find { |x, y| !covered.call(x, y) }
  raise M::Error, "#{name} : case #{outside.join(',')} atteinte hors du tracé" if outside
end

# Raises (as CI errors) if a route off the chain lets the player skip a gym:
# every place is reached from the start without the shortcuts (places touch
# on the world grid only where they are linked); no town with a gym between
# the ends of a loop; a shortcut opens with an item obtained no earlier than
# the last gym before its far end, and its tier is where it can first be
# walked.
def check_extra_routes(path, seed, result)
  places = result.places.map(&:first)
  # A headquarters' place is linked to its route only (check_hqs)
  hq = ->(a, b) { a.extra == M::HQ_EXTRA && !b.equal?(a.ends[0]) }
  touch = ->(a, b) { M.touching?(a, b) && !hq.call(a, b) && !hq.call(b, a) }
  open = places.reject(&:lock)
  seen = [places.find { |wp| wp.index == 0 }]
  queue = seen.dup
  until queue.empty?
    a = queue.shift
    open.each do |b|
      next if seen.include?(b) || !touch.call(a, b)
      seen.push(b)
      queue.push(b)
    end
  end
  (open - seen).each { |wp| CI.error(path, nil, "#{wp.name} (graine #{seed}) : inaccessible sans les raccourcis") }
  gyms = places.select { |wp| wp.kind == "ville" && (wp.gym || wp.island_gym) }.map(&:index)
  obtained = {}
  places.each do |wp|
    (wp.items || []).each { |item| obtained[item] = wp.index }
    obtained[M::SURF_ITEM] = wp.index if wp.surf
  end
  places.select(&:extra).each do |wp|
    a, b = wp.ends
    where = "#{wp.name} (graine #{seed}), #{wp.extra}"
    CI.error(path, nil, "#{where} : ne touche pas ses deux bouts") if !touch.call(wp, a) || !touch.call(wp, b)
    if !wp.lock
      CI.error(path, nil, "#{where} : une ville à arène entre ses bouts") if gyms.any? { |g| g > a.index && g < b.index }
      CI.error(path, nil, "#{where} : palier #{wp.tier} au lieu de #{a.index}") if wp.tier != a.index
      next
    end
    giver = obtained[M::LOCKS[wp.lock]]
    last = gyms.select { |g| g < b.index }.max
    CI.error(path, nil, "#{where} : #{M::LOCKS[wp.lock]} obtenu avant la dernière arène avant #{b.name}") if !giver || (last && giver < last)
    CI.error(path, nil, "#{where} : palier #{wp.tier} au lieu de #{[giver, b.index].compact.min}") if wp.tier != [giver, b.index].compact.min
  end
end

# The guilds' headquarters (#334): each a place of its own (type=lieu), a
# dead end with one exit towards the plain route of the chain it branches
# off, of an ambiance its brick allows, kept apart ([NoLinks]) from any
# other place it touches, its brick drawn whole; every place of that kind
# is one of them.
def check_hqs(path, seed, result, bricks)
  touch = ->(a, b) { M.touching?(a, b) }
  apart = MapGenerator.parse_world(result.text, "graine #{seed}").no_links
  places = result.places.select { |wp, *| wp.extra == M::HQ_EXTRA }
  CI.error(path, nil, "graine #{seed} : #{places.length} lieux de QG pour #{result.hqs.length} QG") if places.length != result.hqs.length
  result.hqs.each do |kind, name|
    where = "#{name} (graine #{seed}), QG #{kind}"
    wp, _place, _text, layout = places.find { |w, *| w.name == name }
    next CI.error(path, nil, "#{where} : pas un lieu à part") if !wp || wp.kind != "lieu"
    parent = wp.ends[0]
    parent_layout = result.places.find { |w, *| w.equal?(parent) }[3]
    CI.error(path, nil, "#{where} : #{wp.exits.length} sorties au lieu d'une") if wp.exits.length != 1
    plain = parent.kind == "route" && !parent.extra && !parent.mask && !parent.crossing && !parent.mountain && !parent.victory && !parent.league
    CI.error(path, nil, "#{where} : branché sur #{parent.name}, pas une route simple de la chaîne") if !plain || wp.tier != parent.index
    allowed = M::GUILD_HQS[kind]
    CI.error(path, nil, "#{where} : route en ambiance #{parent_layout.ambiance}") if !allowed.empty? && !allowed.include?(parent_layout.ambiance)
    own = M::HQ_AMBIANCES[kind]
    CI.error(path, nil, "#{where} : lieu en ambiance #{layout.ambiance}, pas #{own}") if own && layout.ambiance != own
    others = result.places.map(&:first).reject { |w| w.equal?(wp) || w.equal?(parent) }.select { |w| touch.call(wp, w) }
    linked = others.reject { |w| apart.include?([wp.symbol, w.symbol].sort) }
    CI.error(path, nil, "#{where} : relié à #{linked.map(&:name).join(', ')}") if !linked.empty?
    CI.error(path, nil, "#{where} : ne touche pas sa route") if !touch.call(wp, parent)
    CI.error(path, nil, "#{where} : QG non dessiné entier") if !hq_drawn?(layout.rows, bricks.select { |b| b.kind == kind })
    check_dungeon(where, path, kind, layout)
    if M::HQ_ROOM_KINDS.include?(kind) && result.caves.none? { |_w, _n, _t, floor| floor.guild == kind }
      CI.error(path, nil, "#{where} : pas de donjon derrière la porte")
    end
  end
end

# A guild of rooms' dungeon (#337), behind its building's door: its
# tileset, one piece drawn by the painter with double walls, its exit to
# the door and back; HQ_GATES gates, each crossed only by its corridor
# (its cells cut, the leader is no longer reached from the entry), its
# guard's cell and the one he looks at on the floor; the exit held by the
# lock.
# A gym's interior (#121, building GYM) is checked the same way, on the
# Normal gym's tileset, GYM_GATES gates, its exit never held.
def check_guild_dungeon(path, where, wp, floor, result, map_names)
  gym = floor.guild == M::GYM
  tileset = gym ? M::GYM_TILESET : M::GUILD_DUNGEON_TILESETS[floor.guild]
  CI.error(path, nil, "#{where} : tileset #{floor.tileset.inspect}") if floor.tileset != tileset
  if gym
    CI.error(path, nil, "#{where} : arène hors d'une ville à arène") if (!wp.gym && !wp.island_gym && !result.islands.any? { |i, *| i.equal?(wp) }) || floor.owner != wp.name
  elsif result.hqs[floor.guild] != wp.name || floor.owner != wp.name
    CI.error(path, nil, "#{where} : QG #{floor.guild} sur #{wp.name}")
  end
  begin
    check_cave(where, floor, map_names, GUILD_DUNGEON_TILESET)
  rescue M::Error => e
    return CI.error(path, nil, e.message)
  end
  layout = (result.places + result.islands.map { |i, _port, place, text, lay| [i, place, text, lay] }).find { |p, *| p.equal?(wp) }[3]
  door = layout.doors.find { |_x, _y, brick| brick.kind == floor.guild }
  ex, ey = floor.spots[:exits][0]
  if !door || floor.warps.map { |w| w[0, 5] } != [[ex, ey, wp.name, door[0], door[1] + 1]]
    CI.error(path, nil, "#{where} : sortie mal reliée à la porte du QG")
  end
  spots = floor.spots
  ground = spots[:ground].to_h { |cell| [cell, true] }
  walk = lambda do |cut|
    seen = { spots[:entry] => true }
    queue = seen.keys
    until queue.empty?
      x, y = queue.shift
      [[1, 0], [-1, 0], [0, 1], [0, -1]].each do |dx, dy|
        cell = [x + dx, y + dy]
        next if seen[cell] || !ground[cell] || cut.include?(cell)
        seen[cell] = true
        queue.push(cell)
      end
    end
    seen
  end
  gates = gym ? M::GYM_GATES : M::HQ_GATES
  CI.error(path, nil, "#{where} : #{spots[:gates].length} goulets au lieu de #{gates}") if spots[:gates].length != gates
  CI.error(path, nil, "#{where} : chef hors d'atteinte") if !walk.call([])[spots[:leader]]
  spots[:gates].each_with_index do |(x, y), i|
    CI.error(path, nil, "#{where} : goulet #{i + 1} contournable") if walk.call(spots[:cuts][i])[spots[:leader]]
    front = [x + 1, y] if spots[:gate_facing][i] == "droite"
    CI.error(path, nil, "#{where} : garde du goulet #{i + 1} hors du sol") if !ground[[x, y]] || !front || !ground[front]
  end
  CI.error(path, nil, "#{where} : sortie non gardée") if !gym && spots[:locks] != [[ex, ey]]
  CI.error(path, nil, "#{where} : sortie de l'arène fermée") if gym && spots[:locks]
end

# A guild of the outdoors has its dungeon (#335): HQ_GATES gates, each
# corridor the only way on (its cell cut, the headquarters is no longer
# reached from the exit), the headquarters past the last one.
def check_dungeon(where, path, kind, layout)
  gates = layout.spots[:gates]
  return CI.error(path, nil, "#{where} : barrières dans un QG de salle") if M::HQ_ROOM_KINDS.include?(kind) && gates
  return if M::HQ_ROOM_KINDS.include?(kind)
  return CI.error(path, nil, "#{where} : #{gates&.length.to_i} barrières au lieu de #{M::HQ_GATES}") if gates&.length != M::HQ_GATES
  ground = layout.spots[:ground].to_h { |cell| [cell, true] }
  walk = lambda do |cut|
    seen = { layout.spots[:exits][0][1, 2] => true }
    queue = seen.keys
    until queue.empty?
      x, y = queue.shift
      [[1, 0], [-1, 0], [0, 1], [0, -1]].each do |dx, dy|
        cell = [x + dx, y + dy]
        next if seen[cell] || !ground[cell] || cut.include?(cell)
        seen[cell] = true
        queue.push(cell)
      end
    end
    seen
  end
  hx, hy, = layout.spots[:doors].find { |_x, _y, k| k == kind } || layout.spots[:hqs].find { |_x, _y, k| k == kind }
  near = ->(seen) { seen.keys.any? { |x, y| (x - hx).abs + (y - hy).abs <= 2 } }
  CI.error(path, nil, "#{where} : QG hors d'atteinte") if !near.call(walk.call([]))
  gates.each_with_index do |gate, i|
    CI.error(path, nil, "#{where} : barrière #{i + 1} contournable") if near.call(walk.call([gate]))
  end
end

# The dungeon tileset as Essentials' painter sees it (only what draws walls).
CaveTileset = Struct.new(:snap_to_large_grid, :double_walls, :floor_patch_under_walls) do
  def has_decoration?(_deco) = false
end
CAVE_TILESET = CaveTileset.new(false, false, true)
# A guild's dungeon (#337): double walls ([33] to [36] of PBS/dungeon_tilesets.txt)
GUILD_DUNGEON_TILESET = CaveTileset.new(false, true, true)

# Raises if a cave floor is not one piece of 2x2 blocks, if a warp is not on
# its floor, or if Essentials' painter can't draw its walls (or eats floor).
def check_cave(name, floor, map_names, tileset = CAVE_TILESET)
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
  dungeon = M::CaveDungeon.new(rows, tileset, Object.new, floor.seed)   # parameters: decorations only
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
# map has its exit (a transfer event) where INTERIORS says; the League's
# rooms have their doors where LEAGUE_ROOMS says.
def check_interiors(bricks)
# Every house belongs to one style of HOUSE_STYLES, every name there to a house
house_names = bricks.select { |brick| brick.kind == "maison" }.map(&:name)
house_names.each do |name|
  styles = M::HOUSE_STYLES.count { |_style, rule| rule[:houses].include?(name) }
  CI.error(File.join(folder, M::BRICK_FOLDER), nil, "maison « #{name} » dans #{styles} styles de HOUSE_STYLES au lieu d'un") if styles != 1
end
(M::HOUSE_STYLES.flat_map { |_style, rule| rule[:houses] } - house_names).each do |name|
  CI.error("Plugins/MapProceduralGenerator/001_Settings.rb", nil, "HOUSE_STYLES : aucune maison « #{name} »")
end
  settings = File.join(ROOT, "Plugins/MapProceduralGenerator/001_Settings.rb")
  bricks.select(&:door).map(&:kind).uniq.each do |kind|
    next if M::NO_INTERIOR.include?(kind) || M::INTERIORS[kind] || kind == M::LEAGUE
    CI.error(settings, nil, "INTERIORS : aucun gabarit pour les bâtiments « #{kind} »")
  end
  transfers = M::INTERIORS.values.flatten(1).map { |id, x, y| ["INTERIORS", id, x, y] }
  transfers.push(["LEAGUE_EXIT", M::LEAGUE_ROOMS[0][1], *M::LEAGUE_EXIT])
  M::LEAGUE_ROOMS.each { |_role, id, _ax, _ay, x, y| transfers.push(["LEAGUE_ROOMS", id, x, y]) if x }
  transfers.uniq.each do |key, id, x, y|
    file = File.join(ROOT, format("Data/Map%03d.rxdata", id))
    exits = File.exist?(file) ? load_rxdata(file).instance_variable_get(:@events).values.select do |event|
      event.instance_variable_get(:@pages).any? do |page|
        (page.instance_variable_get(:@list) || []).any? { |c| c.instance_variable_get(:@code) == 201 }
      end
    end : []
    next if exits.any? { |e| [e.instance_variable_get(:@x), e.instance_variable_get(:@y)] == [x, y] }
    CI.error(settings, nil, "#{key} : la carte #{id} n'a pas de sortie en #{x},#{y}")
  end
end

tilesets = load_rxdata(File.join(ROOT, "Data", "Tilesets.rxdata"))
# The 4G tileset of an interior: in Tilesets.rxdata, with its image
M::INTERIOR_TILESETS.each_value do |id|
  name = tilesets[id]&.tileset_name.to_s
  next if !name.empty? && File.exist?(File.join(ROOT, "Graphics", "Tilesets", "#{name}.png"))
  CI.error(File.join(ROOT, "Plugins/MapProceduralGenerator/001_Settings.rb"), nil, "INTERIOR_TILESETS : tileset #{id} absent ou sans image")
end
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
# A brick names only ambiances of the place files
ambiance_names = places.flat_map do |path|
  M.parse_place(CI.read_text(path), File.basename(path)).ambiances.map(&:name)
rescue M::Error
  []
end
bricks.each do |brick|
  (brick.ambiances || []).each do |name|
    next if ambiance_names.include?(name)
    CI.error(File.join(folder, M::BRICK_FOLDER, brick.file), nil, "ambiance « #{name} » inconnue (#{ambiance_names.uniq.join(', ')})")
  end
end
places.each do |path|
  place = M.parse_place(CI.read_text(path), File.basename(path))
  SEEDS.each do |seed|
    plan, = M.generate_place(place, bricks, seed)
    MapGenerator.check_tiles(plan, tilesets[plan.tileset_id])
    check_spill(plan, "#{File.basename(path)} (graine #{seed})")
  end
  # Every ambiance on a few seeds, its decor and quantities with it
  place.ambiances.each do |ambiance|
    (1..3).each do |seed|
      themed = place.dup.tap { |p| p.ambiance = ambiance.name }
      plan, _text, layout = M.generate_place(themed, bricks, seed)
      name = "#{File.basename(path)} (ambiance #{ambiance.name}, graine #{seed})"
      MapGenerator.check_tiles(plan, tilesets[plan.tileset_id])
      check_spill(plan, name)
      check_water(plan, name, themed)
      check_spots(name, themed, bricks, layout)
      check_blocking(name, layout)
    end
  end
  # A crossing (#270, #272): in a place of its ambiance and kind, its nook
  # (forced here: the draw is luck) has a corridor of its symbol, its loot
  # reached only across it. A nook often lacks room in a dense town: the
  # seeds go on until one has it (up to 40)
  M::CROSSINGS.each do |kind, crossing|
    next if !crossing[:kinds].include?(place.kind)
    ambiance = place.ambiances.map(&:name).find { |a| !crossing[:ambiances] || crossing[:ambiances].include?(a) }
    next if !ambiance
    symbol = (crossing[:corridor] == :street) ? place.street : crossing[:corridor]
    found = (1..40).lazy.select do |seed|
      themed = place.dup.tap { |p| p.ambiance = ambiance; p.nook = kind }
      plan, _text, layout = begin
        M.generate_place(themed, bricks, seed)
      rescue M::Error
        next false   # a seed where the nook doesn't fit with the rest
      end
      nook = layout.spots[:nooks].find { |n| n[2] == kind }
      next false if !nook
      name = "#{File.basename(path)} (recoin #{kind}, ambiance #{ambiance}, graine #{seed})"
      MapGenerator.check_tiles(plan, tilesets[plan.tileset_id])
      check_nooks(name, themed, bricks, layout)
      _x, _y, _obstacle, ox, oy, fx, fy = nook
      corridor = [[ox, oy], [fx, fy]].map { |x, y| layout.rows[y][x] }
      raise M::Error, "#{name} : couloir du recoin sans « #{symbol} » (#{corridor.join})" if corridor.uniq != [symbol]
      true
    end.first(1).size
    raise M::Error, "#{File.basename(path)} : aucun recoin #{kind} sur 40 graines en ambiance #{ambiance}" if found.zero?
  end
  # A coastal ambiance (« Mer = oui ») is drawn only by the sea, and is drawn
  # there
  coastal = place.ambiances.select(&:coastal).map(&:name)
  if coastal.any?
    inland = (1..200).map { |s| M.draw_ambiance(place, Random.new(s)) }
    seaside = place.dup.tap { |p| p.port = "sud" }
    by_sea = (1..200).map { |s| M.draw_ambiance(seaside, Random.new(s)) }
    raise M::Error, "ambiance #{(inland & coastal).join(', ')} tirée loin de la mer" if (inland & coastal).any?
    raise M::Error, "ambiance #{coastal.join(', ')} jamais tirée au bord de la mer" if (by_sea & coastal).empty?
  end
  # Each guild's headquarters (GUILD_HQS), in each of its ambiances: placed,
  # whole, its door reached
  M::GUILD_HQS.each do |kind, hq_ambiances|
    next if !place.counts.key?(kind)
    quay = M::QUAY_HQS.include?(kind)
    hq_ambiances = [M::HQ_AMBIANCES[kind]] if M::HQ_AMBIANCES[kind]
    (hq_ambiances.empty? ? [place.ambiances.first.name] : hq_ambiances).each do |ambiance|
      (1..3).each do |seed|
        themed = place.dup.tap { |p| p.ambiance = ambiance; p.counts = place.counts.merge(kind => 1..1) }
        # By the sea: a headquarters on a quay, or in a coastal ambiance
        by_sea = quay || place.ambiances.find { |a| a.name == ambiance }&.coastal
        themed.port = (%w[est ouest sud] - place.exits.map(&:first)).first if by_sea && place.pier
        themed.crossing = "mer" if by_sea && !place.pier
        plan, _text, layout = M.generate_place(themed, bricks, seed)
        name = "#{File.basename(path)} (QG #{kind}, ambiance #{ambiance}, graine #{seed})"
        MapGenerator.check_tiles(plan, tilesets[plan.tileset_id])
        check_spill(plan, name)
        check_spots(name, themed, bricks, layout)
        check_blocking(name, layout)
        placed = layout.spots[:doors].any? { |_x, _y, door| door == kind } || bricks.none? { |b| b.kind == kind && b.door }
        raise M::Error, "#{name} : QG non posé" if !placed || !hq_drawn?(layout.rows, bricks.select { |b| b.kind == kind })
      end
    end
  end
  # The mountain's ambiance (MOUNTAIN_AMBIANCE) is drawn only on a mountain
  # route, and is drawn there; it is built on one, its levels and stairs
  # reached (check_reachable of the builder)
  if place.ambiances.any? { |a| a.name == M::MOUNTAIN_AMBIANCE }
    flat = (1..200).map { |s| M.draw_ambiance(place, Random.new(s)) }
    mountain = place.dup.tap { |p| p.mountain = true }
    high = (1..200).map { |s| M.draw_ambiance(mountain, Random.new(s)) }
    raise M::Error, "ambiance #{M::MOUNTAIN_AMBIANCE} tirée hors d'une route de montagne" if flat.include?(M::MOUNTAIN_AMBIANCE)
    raise M::Error, "ambiance #{M::MOUNTAIN_AMBIANCE} jamais tirée sur une route de montagne" if !high.include?(M::MOUNTAIN_AMBIANCE)
    (1..3).each do |seed|
      themed = mountain.dup.tap { |p| p.ambiance = M::MOUNTAIN_AMBIANCE }
      plan, _text, layout = M.generate_place(themed, bricks, seed)
      name = "#{File.basename(path)} (montagne, ambiance #{M::MOUNTAIN_AMBIANCE}, graine #{seed})"
      MapGenerator.check_tiles(plan, tilesets[plan.tileset_id])
      check_spill(plan, name)
      check_spots(name, themed, bricks, layout)
      check_blocking(name, layout)
      raise M::Error, "#{name} : aucun niveau de montagne" if (layout.levels.to_a.join.chars.uniq & themed.levels).empty?
    end
  end
  # Every plan of a town on a few seeds (a town whose bricks don't fit its
  # plan is built as a « carrefour »)
  if place.kind == "ville"
    M::TOWN_PLANS.each_key do |plan_name|
      (1..5).each do |seed|
        planned = place.dup.tap { |p| p.plan = plan_name }
        plan, _text, layout = M.generate_place(planned, bricks, seed)
        name = "#{File.basename(path)} (plan #{plan_name}, graine #{seed})"
        MapGenerator.check_tiles(plan, tilesets[plan.tileset_id])
        check_spill(plan, name)
        check_water(plan, name, planned)
        check_spots(name, planned, bricks, layout)
      end
    end
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
    # Its coastal ambiances, at the port
    coastal.each do |name|
      themed = port.dup.tap { |p| p.ambiance = name }
      plan, _text, layout = M.generate_place(themed, bricks, 1)
      label = "#{File.basename(path)} (port #{side}, ambiance #{name})"
      MapGenerator.check_tiles(plan, tilesets[plan.tileset_id])
      check_spill(plan, label)
      check_spots(label, themed, bricks, layout)
    end
  end
rescue M::Error, MapGenerator::Error => e
  CI.error(path, e.message[/\A[^:]*, ligne (\d+) :/, 1]&.to_i, e.message)
end

# Worlds: a few seeds, each place assembled and the world plan read by MapGen
%w[006_World].each { |f| require File.join(ROOT, "Plugins", "MapGenerator", f) }
# Weathers of Essentials (GameData::Weather), for the weather of the places
WEATHERS = Marshal.load(File.binread(File.join(ROOT, "Data", "Scripts.rxdata"))).flat_map do |_, _, code|
  Zlib::Inflate.inflate(code).scan(/GameData::Weather\.register\(\{\s*:id\s*=>\s*:(\w+)/).flatten
end
M::WEATHER.each_value do |table|
  table.each { |type, _| CI.error(File.join(ROOT, "Plugins/MapProceduralGenerator/001_Settings.rb"), nil, "WEATHER : météo #{type} inconnue") if !WEATHERS.include?(type.to_s) }
end
# Map flags of the ambiances (a tone each, a known ambiance)
settings = File.join(ROOT, "Plugins/MapProceduralGenerator/001_Settings.rb")
M::AMBIANCE_FLAGS.each do |ambiance, flag|
  CI.error(settings, nil, "AMBIANCE_FLAGS : #{flag} sans teinte (TONE_FLAGS)") if !M::TONE_FLAGS.key?(flag)
  CI.error(settings, nil, "AMBIANCE_FLAGS : ambiance « #{ambiance} » inconnue") if !ambiance_names.include?(ambiance)
end
# Nooks of each world opening now or later (« Revisiter »): [now, later]
revisits = Hash.new { |hash, key| hash[key] = [0, 0] }
crossings = Hash.new(0)
worlds.each do |path|
  world = M.parse_world(CI.read_text(path), File.basename(path))
  town, route = [world.town_file, world.route_file].map do |name|
    M.parse_place(CI.read_text(File.join(folder, name)), name)
  end
  name_table = world.names_file && M.parse_names(CI.read_text(File.join(folder, world.names_file)), world.names_file)
  highest = 0
  WORLD_SEEDS.each do |seed|
    result = M.generate_world(world, town, route, bricks, seed, {}, name_table)
    # Levels shown on the mountain routes (each level its own symbol)
    result.places.each do |wp, place, _text, layout|
      highest = [highest, (layout.levels.to_a.join.chars.uniq & place.levels).length].max if wp.mountain
    end
    plan = MapGenerator.parse_world(result.text, "#{File.basename(path)} (graine #{seed})")
    # Each weather written exists, and the same seed draws the same ones
    weathers = plan.places.values.map(&:weather)
    weathers.compact.each { |w| CI.error(path, nil, "graine #{seed} : météo #{w} inconnue") if !WEATHERS.include?(w[/\A\w+/]) }
    # Each map flag written is that of its place's ambiance
    result.places.each do |wp, _place, _text, layout|
      written = plan.places[wp.symbol]&.flags
      wanted = M::AMBIANCE_FLAGS[layout.ambiance]
      CI.error(path, nil, "graine #{seed} : #{wp.name} drapeaux=#{written.inspect} au lieu de #{wanted.inspect}") if written != wanted
    end
    if seed == WORLD_SEEDS.first
      again = MapGenerator.parse_world(M.generate_world(world, town, route, bricks, seed, {}, name_table).text, "#{File.basename(path)} (graine #{seed})")
      CI.error(path, nil, "graine #{seed} : météo différente pour la même graine") if again.places.values.map(&:weather) != weathers
    end
    titles = plan.places.values.map(&:display_name)
    raise M::Error, "#{File.basename(path)} (graine #{seed}) : noms affichés en double" if titles.uniq.length != titles.length
    result.places.each do |wp, place, text, layout|
      plan = MapGenerator.parse(text, place.file)
      MapGenerator.check_tiles(plan, tilesets[place.tileset_id])
      check_spill(plan, "#{wp.name} (graine #{seed})")
      check_water(plan, "#{wp.name} (graine #{seed})", place)
      check_spots("#{wp.name} (graine #{seed})", place, bricks, layout)
      check_nooks("#{wp.name} (graine #{seed})", place, bricks, layout)
      check_mask("#{wp.name} (graine #{seed})", place, bricks, layout)
      check_lock("#{wp.name} (graine #{seed})", place, bricks, layout)
    end
    check_extra_routes(path, seed, result)
    check_hqs(path, seed, result, bricks)
    # Every town has its Pokémon Centre and Mart, and its gym if it has one;
    # a town with a gym covers 2 squares at least (a village has none)
    result.places.each do |wp, _place, _text, layout|
      next if wp.kind != "ville" || wp.league
      kinds = layout.doors.map { |_x, _y, brick| brick.kind }
      missing = %w[centre boutique].reject { |kind| kinds.include?(kind) }
      missing.push("arene") if wp.gym && !kinds.include?("arene")
      CI.error(path, nil, "#{wp.name} (graine #{seed}) : sans #{missing.join(', ')}") if !missing.empty?
      covered = wp.mask ? wp.mask.join.count("1") : wp.w * wp.h
      CI.error(path, nil, "#{wp.name} (graine #{seed}) : ville à arène d'une seule case") if wp.gym && covered < 2
    end
    # Field items: in towns with a gym, in the order of their minimums, each
    # at its minimum gym or later; a nook only after the town of its item
    gyms = result.places.select { |wp, *| wp.gym }.map(&:first)
    obtained = result.places.flat_map { |wp, *| (wp.items || []).map { |item| [item, wp] } }.to_h
    order = world.field_items.sort_by.with_index { |(_n, min), i| [min, i] }
    order.each_cons(2) do |(a, _), (b, _)|
      ta, tb = obtained[M::FIELD_ITEMS[a][0]], obtained[M::FIELD_ITEMS[b][0]]
      CI.error(path, nil, "graine #{seed} : #{b} obtenu avant #{a}") if ta && tb && tb.index < ta.index
    end
    order.each do |name, min|
      giver = obtained[M::FIELD_ITEMS[name][0]]
      next CI.error(path, nil, "graine #{seed} : #{name} sans ville d'obtention") if !giver && gyms.length >= min
      CI.error(path, nil, "graine #{seed} : #{name} avant la #{min}e arène") if giver && gyms.index(giver).to_i < min - 1
    end
    # Crossings (#270, #272: ice, mud, a wall to climb, a cycle path): only
    # in their ambiances and kinds of place, and their item given in a town
    # whenever one of their ambiances is in the world (always for any)
    result.places.each do |wp, place, _text, layout|
      layout.spots[:nooks].each do |nook|
        crossing = M::CROSSINGS[nook[2]] || next
        crossings[nook[2]] += 1
        fits = (!crossing[:ambiances] || crossing[:ambiances].include?(layout.ambiance)) && crossing[:kinds].include?(place.kind)
        CI.error(path, nil, "#{wp.name} (graine #{seed}) : recoin #{nook[2]} en ambiance #{layout.ambiance}") if !fits
      end
    end
    M::EXTRA_FIELD_ITEMS.each do |item, ambiances|
      wanted = !ambiances || result.places.any? { |*, layout| ambiances.include?(layout.ambiance) }
      giver = result.places.find { |p, *| (p.items || []).include?(item) }&.first
      CI.error(path, nil, "graine #{seed} : #{item} sans ville où l'obtenir") if wanted && !giver
      CI.error(path, nil, "graine #{seed} : #{item} donné sans #{ambiances&.join(' ni ')} dans le monde") if !wanted && giver
      CI.error(path, nil, "graine #{seed} : #{item} donné hors d'une ville de la chaîne") if giver && (giver.kind != "ville" || giver.league)
    end
    # A nook opens with a field item obtained in a town of the chain (before
    # the League), earlier or later than its place (a nook to come back to)
    atlas_items = M.world_atlas(result)[:items]
    result.places.each do |wp, _place, _text, layout|
      layout.spots[:nooks].each do |_x, _y, obstacle|
        giver = result.places.find { |p, *| p.name == atlas_items[M::NOOKS[obstacle]] }&.first
        next CI.error(path, nil, "#{wp.name} (graine #{seed}) : recoin #{obstacle} sans ville pour son objet") if !giver
        next if obstacle == "ilot"
        revisits[world.file][giver.index >= (wp.tier || wp.index) ? 1 : 0] += 1
      end
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
    # (an island's gym leads back to its island, #121)
    map_names = result.places.map { |wp, *| wp.name } + result.caves.map { |_wp, name, *| name } + result.islands.map { |wp, *| wp.name }
    result.caves.each do |wp, name, text, floor|
      MapGenerator.check_tiles(MapGenerator.parse(text, name), tilesets[floor.tileset || M::CAVE_TILESET])
      next check_guild_dungeon(path, "#{name} (graine #{seed})", wp, floor, result, map_names) if floor.guild
      # Its style is its route's ambiance's (CAVE_STYLES)
      ambiance = result.places.find { |p, *| p.equal?(wp) }[3].ambiance
      CI.error(path, nil, "#{name} (graine #{seed}) : tileset #{floor.tileset.inspect} pour l'ambiance #{ambiance}") if floor.tileset != M::CAVE_STYLES[ambiance]
      check_cave("#{name} (graine #{seed})", floor, map_names)
      # A dark cave: one floor, its way out to its route, its loot
      if floor.dark
        door = result.places.find { |p, *| p.equal?(wp) }[3].spots[:nooks].find { |*, obstacle| obstacle == "sombre" }
        ok = door && floor.warps.map { |w| w[2, 3] } == [[wp.name, door[0], door[1] + 1]] && floor.spots[:loot]
        CI.error(path, nil, "#{name} (graine #{seed}) : grotte sombre mal reliée à #{wp.name}") if !ok
        next
      end
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
      check_water(plan, "#{wp.name} (graine #{seed})", place)
      check_spots("#{wp.name} (graine #{seed})", place, bricks, layout)
      port_text = result.places.find { |p, *| p.equal?(port) }[2]
      inside = result.interiors.map(&:name) + result.caves.map { |_wp, name, *| name }
      ok = (plan.warps.values.map(&:target) - inside) == [port.name] &&
           (MapGenerator.parse(port_text, place.file).warps.values.map(&:target) - inside) == [wp.name] && !names.include?(wp.name)
      CI.error(path, nil, "#{wp.name} (graine #{seed}) : le bateau ne relie pas l'île à #{port.name}") if !ok
    end
    result.seabeds.each do |_wp, name, text|
      MapGenerator.check_tiles(MapGenerator.parse(text, name), tilesets[M::SEABED_TILESET])
    end
    # Decor maps: their tiles, never walked (no ground tile, no warp), every
    # place's side and corner with an empty square next to it covered
    result.fillers.each do |f|
      decor = MapGenerator.parse(f.text, f.name)
      MapGenerator.check_tiles(decor, tilesets[decor.tileset_id])
      CI.error(path, nil, "#{f.name} (graine #{seed}) : #{f.w * world.cell}x#{f.h * world.cell} attendu") if decor.rows.length != f.h * world.cell || decor.rows.any? { |row| row.length != f.w * world.cell }
      CI.error(path, nil, "#{f.name} (graine #{seed}) : sol praticable") if decor.rows.join.include?(".")
    end
    grid = MapGenerator.parse_world(result.text, "#{File.basename(path)} (graine #{seed})").rows
    grid.each_with_index do |row, y|
      row.each_char.with_index do |c, x|
        next if c != MapGenerator::WORLD_EMPTY
        near = M::FILLER_REACH.any? do |dx, dy, _w|
          next false if y + dy < 0 || x + dx < 0
          other = grid[y + dy]&.[](x + dx)
          other && other != MapGenerator::WORLD_EMPTY && !M::FILLER_SYMBOLS.include?(other)
        end
        CI.error(path, nil, "graine #{seed} : case #{x},#{y} vide à côté d'un lieu (sans décor)") if near
      end
    end
    # Each building door leads to its interior, whose exit leads back
    plans = (result.places.map { |wp, place, text, _layout| [wp.name, MapGenerator.parse(text, place.file)] } +
             result.islands.map { |wp, _port, place, text, _layout| [wp.name, MapGenerator.parse(text, place.file)] }).to_h
    result.interiors.each do |it|
      next if !it.door   # a room of the League after the entrance
      plan = plans[it.owner]
      symbol = plan.events[it.door[1]]&.[](it.door[0])
      warp = plan.warps[symbol]
      next if warp && warp.target == it.name && [warp.x, warp.y] == it.arrival
      CI.error(path, nil, "#{it.name} (graine #{seed}) : la porte #{it.door.join(',')} ne mène pas à l'intérieur")
    end
    # The chain ends with the Victory Road (a mountain with a cave), then the
    # plateau, whose League leads from room to room in order
    chain = result.places.map(&:first).reject(&:extra)
    victory, plateau = chain.max_by(2, &:index).reverse
    if !victory&.victory || !victory.mountain || result.caves.none? { |wp, *| wp.equal?(victory) } || !plateau.league
      CI.error(path, nil, "graine #{seed} : la chaîne ne finit pas par la Route Victoire (avec sa grotte) et le plateau")
    end
    rooms = atlas[:league].map { |name| atlas[:maps][name] }
    roles = M::LEAGUE_ROOMS.map(&:first)
    chained = rooms.each_with_index.all? { |room, i| room&.[](:onward)&.[](2) == atlas[:league][i + 1] }
    if rooms.map { |room| room&.[](:role) } != roles || !chained || rooms[0][:owner] != plateau.name
      CI.error(path, nil, "graine #{seed} : salles de la Ligue mal enchaînées (#{rooms.map { |room| room&.[](:role) }.join(' > ')})")
    end
    # Every gym is on a map, in a town of the chain or on an island
    gyms = (result.places + result.islands.map { |wp, _port, place, text, layout| [wp, place, text, layout] }).sum do |*, layout|
      layout.doors.count { |_x, _y, brick| brick.kind == "arene" }
    end
    CI.error(path, nil, "graine #{seed} : #{gyms} arène(s) posée(s) au lieu de #{world.gyms}") if gyms != world.gyms
  end
  CI.error(path, nil, "aucune route de montagne au-delà de 2 niveaux (graines #{WORLD_SEEDS})") if world.mountains.max > 0 && highest <= 2
  # About « Revisiter » % of the nooks open with an item obtained later
  now, later = revisits[world.file]
  share = (now + later).zero? ? nil : 100 * later / (now + later)
  puts "#{world.file} : #{later} recoin(s) à revisiter sur #{now + later} (#{share || 0} %, réglé à #{world.revisit} %)"
  if share && (now + later) >= 8 && (share - world.revisit).abs > REVISIT_MARGIN
    CI.error(path, nil, "#{share} % de recoins à revisiter (graines #{WORLD_SEEDS}), #{world.revisit} % attendus à #{REVISIT_MARGIN} près")
  end
rescue M::Error, MapGenerator::Error => e
  CI.error(path, e.message[/\A[^:]*, ligne (\d+) :/, 1]&.to_i, e.message)
end

# Extra autotiles (#301): each one drawn in place of a first tile of its
# tileset has its file
M::EXTRA_AUTOTILES.each do |tileset, lists|
  lists.flatten.each do |name|
    file = File.join("Graphics", "Autotiles", "#{name}.png")
    CI.error(file, nil, "autotile supplémentaire du tileset #{tileset} absent") if !File.exist?(File.join(ROOT, file))
  end
end

puts "Recoins à franchir avec un objet hors arène : #{M::CROSSINGS.keys.map { |kind| "#{kind} #{crossings[kind]}" }.join(', ')}"
puts "#{worlds.length} mondes, #{places.length} lieux et #{bricks.length} briques lus, graines #{SEEDS} assemblées"
CI.finish("Lieux MapProc")
