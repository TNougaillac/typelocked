#===============================================================================
# MapProceduralGenerator - Caves on two floors
# A cave of a world is two fixed maps: its floors (1F, then the basement
# « sous-sol »), linked by a ladder. Their galleries are grown here by a
# cellular automaton on a grid of 2x2 blocks (no corridor 1 tile wide, no
# cells touching only diagonally), one piece per floor. The walls are drawn
# once, when the maps are written, by Essentials' dungeon painter
# (010_CavePainter.rb), then the maps are saved as they are: a cave is the same
# on every visit.
# A cave that blocks a route is crossed by both floors: entrance A on 1F,
# ladder down, entrance B in the basement. A mountain cave is a dead end:
# entrance and ladder on 1F, its far end in the basement.
# Plain Ruby.
#===============================================================================
module MapProceduralGenerator
  # rows: true = floor, map size (margin included); spots: inventory of the
  # floor (exits, ladders, floor, far; loot in a dark cave); warps: [[x, y,
  # target map name, tx, ty]]; seed: of the walls and decorations drawn by
  # the painter; dark: a dark cave (a nook, see NOOKS)
  CaveFloor = Struct.new(:name, :level, :rows, :spots, :warps, :seed, :dark, :tileset)

  module_function

  # The galleries of one floor, on the half-size grid of 2x2 blocks (true =
  # floor): chambers of rough round shape, joined by winding tunnels (each
  # chamber to the nearest one before it, plus a few loops), then the rock
  # nibbled where the floor almost surrounds it. shape: see CAVE_SHAPES.
  def cave_blocks(shape, rng)
    cw, ch = shape[:size]
    grid = Array.new(ch) { Array.new(cw, false) }
    inner = ->(x, y) { x >= 1 && y >= 1 && x < cw - 1 && y < ch - 1 }
    # Chambers apart from one another, when there is room
    rooms = []
    rng.rand(shape[:rooms]).times do
      r = rng.rand(shape[:radius])
      spot = nil
      30.times do
        spot = [rng.rand(2..cw - 3), rng.rand(2..ch - 3), r]
        break if rooms.none? { |x, y, r2| ((x - spot[0])**2) + ((y - spot[1])**2) < (r + r2 + 2)**2 }
      end
      rooms.push(spot)
    end
    rooms.each do |cx, cy, r|
      (cy - r.ceil..cy + r.ceil).each do |y|
        (cx - r.ceil..cx + r.ceil).each do |x|
          next if !inner.call(x, y) || ((x - cx)**2) + ((y - cy)**2) > (r + rng.rand(-0.4..0.6))**2
          grid[y][x] = true
        end
      end
    end
    links = (1...rooms.length).map { |i| [i, (0...i).min_by { |j| ((rooms[i][0] - rooms[j][0])**2) + ((rooms[i][1] - rooms[j][1])**2) }] }
    rng.rand(shape[:loops]).times { links.push(rooms.each_index.to_a.sample(2, random: rng)) }
    links.each { |i, j| tunnel(grid, rooms[i], rooms[j], rng.rand(shape[:width]), inner, rng) }
    # Rock almost surrounded by floor goes, for rounder walls
    grid = Array.new(ch) do |y|
      Array.new(cw) do |x|
        next grid[y][x] if grid[y][x] || !inner.call(x, y)
        (-1..1).sum { |oy| (-1..1).count { |ox| grid[y + oy][x + ox] } } >= 6
      end
    end
    grid = largest_region(grid, cw, ch)
    join_diagonals(grid, cw, ch, rng)
    return grid
  end

  # A tunnel 1 or 2 blocks wide from a to b, drifting at random on the way.
  def tunnel(grid, a, b, width, inner, rng)
    x, y = a[0], a[1]
    until x == b[0] && y == b[1]
      if rng.rand < 0.7
        if rng.rand((b[0] - x).abs + (b[1] - y).abs) < (b[0] - x).abs
          x += (b[0] <=> x)
        else
          y += (b[1] <=> y)
        end
      else
        dx, dy = [[1, 0], [-1, 0], [0, 1], [0, -1]].sample(random: rng)
        x, y = x + dx, y + dy if inner.call(x + dx + 1, y + dy + 1) && inner.call(x + dx, y + dy)
      end
      width.times { |k| width.times { |l| grid[y + l][x + k] = true if inner.call(x + k, y + l) } }
    end
  end

  # Only the biggest piece of floor (4-connected) is kept.
  def largest_region(grid, cw, ch)
    region = Array.new(ch) { Array.new(cw) }
    best, best_size = nil, 0
    ch.times do |y|
      cw.times do |x|
        next if !grid[y][x] || region[y][x]
        cells = flood_blocks(grid, cw, ch, [x, y], region, [x, y])
        best, best_size = [x, y], cells if cells > best_size
      end
    end
    return Array.new(ch) { |y| Array.new(cw) { |x| region[y][x] == best } }
  end

  # Marks with id the floor blocks reached from start; returns their count.
  def flood_blocks(grid, cw, ch, start, marks, id)
    marks[start[1]][start[0]] = id
    queue = [start]
    count = 0
    until queue.empty?
      x, y = queue.shift
      count += 1
      [[0, -1], [1, 0], [0, 1], [-1, 0]].each do |ox, oy|
        nx, ny = x + ox, y + oy
        next if nx < 0 || ny < 0 || nx >= cw || ny >= ch || !grid[ny][nx] || marks[ny][nx]
        marks[ny][nx] = id
        queue.push([nx, ny])
      end
    end
    return count
  end

  # Two floor blocks touching only by a corner: one of the rock blocks between
  # them becomes floor (the dungeon painter can't draw a wall there).
  def join_diagonals(grid, cw, ch, rng)
    loop do
      fixed = false
      (ch - 1).times do |y|
        (cw - 1).times do |x|
          a, b, c, d = grid[y][x], grid[y][x + 1], grid[y + 1][x], grid[y + 1][x + 1]
          next if a != d || b != c || a == b
          cells = a ? [[x + 1, y], [x, y + 1]] : [[x, y], [x + 1, y + 1]]
          fx, fy = cells.sample(random: rng)
          grid[fy][fx] = true
          fixed = true
        end
      end
      break if !fixed
    end
  end

  # Steps from a block to every floor block (nil = rock).
  def block_distances(grid, from)
    cw, ch = grid[0].length, grid.length
    dist = Array.new(ch) { Array.new(cw) }
    dist[from[1]][from[0]] = 0
    queue = [from]
    until queue.empty?
      x, y = queue.shift
      [[0, -1], [1, 0], [0, 1], [-1, 0]].each do |ox, oy|
        nx, ny = x + ox, y + oy
        next if nx < 0 || ny < 0 || nx >= cw || ny >= ch || !grid[ny][nx] || dist[ny][nx]
        dist[ny][nx] = dist[y][x] + 1
        queue.push([nx, ny])
      end
    end
    return dist
  end

  # The floor block farthest from that one (ties: the first).
  def farthest_block(grid, from)
    dist = block_distances(grid, from)
    best = from
    dist.each_with_index do |row, y|
      row.each_with_index { |d, x| best = [x, y] if d && d > dist[best[1]][best[0]] }
    end
    return best
  end

  # The floor block farthest from all those blocks (the most out of the way).
  def remotest_block(grid, blocks)
    dists = blocks.map { |b| block_distances(grid, b) }
    best, best_d = nil, -1
    grid.each_with_index do |row, y|
      row.each_index do |x|
        next if !row[x]
        d = dists.map { |dist| dist[y][x] }.min
        best, best_d = [x, y], d if d > best_d
      end
    end
    return best
  end

  # Map cell of a block: its top-left cell; the player lands on the cell below.
  def block_cell(block)
    return [CAVE_MARGIN[0] + (block[0] * 2), CAVE_MARGIN[1] + (block[1] * 2)]
  end

  # The two floors of a route's cave. doors: the cave entrances of the route
  # ([x, y, brick]): 2 for a cave across the route, 1 for a mountain cave.
  def cave_floors(name, route, doors, excess, rng)
    shape = CAVE_SHAPES[excess] || CAVE_SHAPES[nil]
    names = [name, "#{name} (sous-sol)"]
    grids = names.map { cave_blocks(shape, rng) }
    # 1F: entrance A far from the ladder down; basement: ladder up far from
    # entrance B (or from the dead end)
    start = grids[0].each_with_index.flat_map { |row, y| row.each_index.select { |x| row[x] }.map { |x| [x, y] } }.sample(random: rng)
    entrance_a = farthest_block(grids[0], start)
    ladder_down = farthest_block(grids[0], entrance_a)
    start = grids[1].each_with_index.flat_map { |row, y| row.each_index.select { |x| row[x] }.map { |x| [x, y] } }.sample(random: rng)
    ladder_up = farthest_block(grids[1], start)
    far_end = farthest_block(grids[1], ladder_up)
    below = ->(block) { block_cell(block).then { |x, y| [x, y + 1] } }
    door_a, door_b = doors.map { |x, y, _brick| [x, y + 1] }
    floors = [
      [entrance_a, door_a, ladder_down, ladder_up, names[1]],
      [door_b ? far_end : nil, door_b, ladder_up, ladder_down, names[0]]
    ].each_with_index.map do |(exit_block, door, ladder, other_ladder, other), level|
      warps = []
      warps.push([*block_cell(exit_block), route, *door]) if exit_block
      warps.push([*block_cell(ladder), other, *below.call(other_ladder)])
      events = [exit_block, ladder].compact
      grid = grids[level]
      spots = {
        exits:   exit_block ? [[*block_cell(exit_block), route]] : [],
        ladders: [block_cell(ladder)],
        floor:   grid.each_with_index.flat_map { |row, y| row.each_index.select { |x| row[x] && !events.include?([x, y]) }.map { |x| block_cell([x, y]) } },
        far:     [block_cell(remotest_block(grid, events))]
      }
      CaveFloor.new(names[level], level, cave_rows(grid), spots, warps, rng.rand(1_000_000))
    end
    return floors
  end

  # A dark cave behind that door of a route ([x, y, brick]): one small floor,
  # its loot at the far end from the entrance.
  def dark_cave_floor(name, route, door, rng)
    grid = cave_blocks(DARK_CAVE_SHAPE, rng)
    start = grid.each_with_index.flat_map { |row, y| row.each_index.select { |x| row[x] }.map { |x| [x, y] } }.sample(random: rng)
    entrance = farthest_block(grid, start)
    far = farthest_block(grid, entrance)
    spots = {
      exits: [[*block_cell(entrance), route]],
      floor: grid.each_with_index.flat_map { |row, y| row.each_index.select { |x| row[x] && [x, y] != entrance }.map { |x| block_cell([x, y]) } },
      far:   [block_cell(far)],
      loot:  block_cell(far)
    }
    warps = [[*block_cell(entrance), route, door[0], door[1] + 1]]
    return CaveFloor.new(name, 0, cave_rows(grid), spots, warps, rng.rand(1_000_000), true)
  end

  # Full map rows of a floor: the blocks doubled, with the margin around.
  def cave_rows(grid)
    mx, my = CAVE_MARGIN
    w, h = (grid[0].length * 2) + (2 * mx), (grid.length * 2) + (2 * my)
    return Array.new(h) do |y|
      Array.new(w) do |x|
        bx, by = (x - mx) / 2, (y - my) / 2
        x >= mx && y >= my && by < grid.length && bx < grid[0].length && grid[by][bx]
      end
    end
  end

  # MapGen plan of a cave floor: floor and rock (the painter draws the walls
  # when the map is written), and its warps (exit to the route, ladder).
  def cave_floor_text(floor, route)
    text = +"# Grotte de #{route}, générée par MapProceduralGenerator (#{floor.dark ? 'grotte sombre' : (floor.level == 0) ? '1er étage' : 'sous-sol'}).\n"
    text << "# Les murs sont dessinés par le générateur de donjon d'Essentials quand la carte est écrite.\n"
    text << "Name    = #{floor.name}\n"
    text << "Tileset = #{floor.tileset || CAVE_TILESET}\n"
    text << "Ground  = .\n"
    text << "\n[Legend]\n. = #{CAVE_FLOOR}\nx = #{CAVE_ROCK}\n"
    text << "\n[Warps]\n"
    floor.warps.each_with_index { |(_x, _y, target, tx, ty), i| text << "#{i + 1} = #{target} #{tx},#{ty} bas\n" }
    text << "\n[Map]\n"
    floor.rows.each { |row| text << row.map { |f| f ? "." : "x" }.join << "\n" }
    text << "\n[Events]\n"
    events = floor.rows.map { |row| "." * row.length }
    floor.warps.each_with_index { |(x, y), i| events[y][x] = (i + 1).to_s }
    events.each { |row| text << row << "\n" }
    return text
  end
end
