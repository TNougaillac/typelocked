#===============================================================================
# MapProceduralGenerator - Place assembler (towns and routes)
# 1. A border of trees with openings for the exits.
# 2. Streets from each exit to a square near the middle, plus dead ends (on a
#    route the "street" is plain ground: it only keeps the way clear).
# 3. Bricks with a door (buildings), required ones first, each linked to the
#    nearest street by a path; then bricks without a door (decoration).
# 4. Every door and exit must be reachable, or the generation fails.
# A route of a world may be crossed by water (chenal: a straight channel, lac:
# a lake from side to side), reached only by surfing, or by a rock wall with a
# cave entrance on each side (grotte); the exits then lie on both sides of it.
# A port town (« Port ») has the sea on one side with no exit: a wooden quay
# along the water, piers out to sea, a paved promenade behind the quay and
# its port buildings along it. An island (a map of a world reached by boat)
# is a port town with no exit and the sea on its other sides too.
# Same place + same bricks + same seed = same map.
#===============================================================================
module MapProceduralGenerator
  # rows: MapGen [Map] rows; doors: [x, y, brick] (door cells); exits:
  # [side, x, y] (first street cell on the map edge)
  # deep: cells of deep water, where the player can dive; terminal: [x, y] of
  # the ferry terminal's door (its top middle cell, entered from the pier);
  # spots: the place's inventory (see PlaceBuilder#inventory)
  Layout = Struct.new(:rows, :doors, :exits, :deep, :terminal, :spots, :ambiance)

  # Bricks counted "par case" in [Briques] are multiplied by the place's area
  # in squares of CASE_SIZE x CASE_SIZE tiles.
  CASE_SIZE = 20
  CAVE = "grotte"   # type of the cave entrance bricks
  # The only bricks on the raised levels of a mountain route (the others have
  # grass under them), and only there
  HIGHLAND = ["rocaille"].freeze
  # Most bricks an excess « fill » adds after the others (until none fits)
  FILL_LIMIT = 80
  PORT = "port"   # type of the port buildings, only put along the quay
  TERMINAL = "gare"   # type of the ferry terminal, on piles at the end of a pier
  # Sea depth of a port town, at most PORT_SHARE of the map across
  PORT_DEPTH = 9..11
  PORT_SHARE = 0.28
  # Tiles that make the map side towards the town, for each sea side
  INLAND = { "nord" => [0, 1], "sud" => [0, -1], "ouest" => [1, 0], "est" => [-1, 0] }.freeze
  # Brick types walked through (grass): their cells count as ground for the
  # inventory, those of GRASS_KINDS as tall grass
  WALK_KINDS = %w[herbes prairie].freeze
  GRASS_KINDS = %w[herbes].freeze
  # Brick types of the nooks, drawn by the builder: a pocket of ground in the
  # rock behind an obstacle (its door), an islet in a pond, a dark cave
  # (the entrance of a cave brick)
  # The sea autotile (A1), whose bottom edge is drawn by the bank below it
  # (« Rive » of the place file) on the ground of the row underneath
  SEA_TILES = (48...96).freeze
  NOOK = "recoin"
  ISLET = "ilot"
  DARK_CAVE = "grotte sombre"

  class PlaceBuilder
    def initialize(place, bricks, palette, seed)
      @place = place
      cave = place.crossing == "grotte" || place.cave || place.nook == "sombre"
      @bricks = bricks.select { |b| place.counts[b.kind] || (b.kind == CAVE && cave) }
      # Bricks kept for some ambiances; a type left with none of its bricks
      # is skipped
      @left_out = @bricks.map(&:kind).uniq
      @bricks.select! { |b| !b.ambiances || b.ambiances.include?(place.ambiance) }
      @left_out -= @bricks.map(&:kind)
      @palette = palette
      @seed = seed
      @rng = Random.new(seed)
      @w, @h = place.width, place.height
      @cells = Array.new(@h) { Array.new(@w) }          # brick or border symbols
      @solid = Array.new(@h) { Array.new(@w, false) }   # nothing else may go there
      @street = Array.new(@h) { Array.new(@w, false) }
      @border = Array.new(@h) { Array.new(@w, false) }
      @kinds = Array.new(@h) { Array.new(@w) }   # brick type of each cell
      @doors = []
      @exits = []
      @dead_ends = []
      @nooks = []
    end

    def build
      reserve_border
      hub = [@rng.rand((@w * 0.35).to_i..(@w * 0.65).to_i - STREET_WIDTH),
             @rng.rand((@h * 0.35).to_i..(@h * 0.65).to_i - STREET_WIDTH)]
      hub[1] = climbing_hub_row || hub[1] if @place.mountain
      hub = port_hub(hub) if @place.port
      @place.exits.each { |side, offset| carve_exit(side, offset, hub) }
      @water = Array.new(@h) { Array.new(@w, false) }
      lay_port(hub) if @place.port
      lay_shore if @place.island
      moor_boat if @terminal && (@place.ferry || @place.island)
      scatter_reefs if @place.island
      @rng.rand(@place.spurs).times { carve_spur(hub) }
      cross if @place.crossing
      if @place.mountain
        choose_river if @place.river
        raise_levels
        lay_river
        # Its cave is left out when no spot fits
        place_mountain_cave if @place.cave
      end
      reserve_banks
      place_port_bricks if @port_depth
      place_bricks
      grow_highland_grass
      trim_thin_water
      clear_banks
      plant_border
      check_reachable
      cover_ground
      rows = Array.new(@h) { |y| Array.new(@w) { |x| symbol_at(x, y) }.join }
      draw_banks(rows) if @place.banks
      return Layout.new(rows, @doors, @exits, @deep || [], @terminal, inventory, @place.ambiance)
    end

    # Where the events of the place can go (MapEvents, items, NPCs), every cell
    # reached on foot from the exits, doors and ferry terminal:
    #   exits: [side, x, y]; doors: [x, y, type] (door cells);
    #   street: free cells beside a street; grass: tall grass cells;
    #   dead_ends: last cell of each dead-end street;
    #   nooks: [x, y, obstacle (a key of NOOKS), ox, oy]: the loot cell and
    #   the obstacle's cell (a pocket); for an islet the loot only; for a dark
    #   cave its entrance (the loot is in the cave).
    def inventory
      starts = @exits.map { |_side, x, y| [x, y] } + @doors.map { |x, y, _| [x, y + 1] }
      starts.push([@terminal[0], @terminal[1] - 1]) if @terminal
      seen = Array.new(@h) { Array.new(@w, false) }
      starts.each { |start| walk_foot(start, seen) if !seen[start[1]][start[0]] }
      on_street = ->(x, y) { inside?(x, y) && @street[y][x] && !@stairs_at&.key?([x, y]) }
      return {
        exits:     @exits.map(&:dup),
        doors:     @doors.map { |x, y, brick| [x, y, brick.kind] },
        street:    cells_where(seen) { |x, y| !@street[y][x] && NEIGHBOURS.any? { |ox, oy| on_street.call(x + ox, y + oy) } },
        grass:     cells_where(seen) { |x, y| GRASS_KINDS.include?(@kinds[y][x]) },
        dead_ends: @dead_ends.select { |x, y| seen[y][x] },
        nooks:     @nooks.map(&:dup)
      }
    end

    # [x, y] of the cells marked in grid that pass the block, row by row.
    def cells_where(grid)
      return (0...@h).flat_map { |y| (0...@w).select { |x| grid[y][x] && yield(x, y) }.map { |x| [x, y] } }
    end

    # Like walk, on foot only (no surfing), through grass and carpets; marks
    # the cells reached in seen.
    def walk_foot(start, seen)
      foot = lambda do |x, y|
        next false if !inside?(x, y) || @water[y][x] || @border[y][x]
        next true if @street[y][x]
        next !@cells[y][x] || WALK_KINDS.include?(@kinds[y][x]) || (@cells[y][x] == excess[:carpet] && !@kinds[y][x])
      end
      return if !foot.call(*start)
      seen[start[1]][start[0]] = true
      queue = [start]
      until queue.empty?
        x, y = queue.shift
        NEIGHBOURS.each do |ox, oy|
          nx, ny = x + ox, y + oy
          next if !foot.call(nx, ny) || seen[ny][nx]
          seen[ny][nx] = true
          queue.push([nx, ny])
        end
      end
    end

    private

    def symbol_at(x, y)
      return @stairs_at[[x, y]] if @stairs_at&.key?([x, y])
      rock = (level_at(x, y) > 0) ? level_symbol(level_at(x, y)) : nil
      return @cells[y][x] || rock || @place.street if @street[y][x]
      return @cells[y][x] || rock || @place.ground
    end

    # What the place's excess (« Demesure ») changes, {} if none.
    def excess
      return EXCESSES[@place.excess] || {}
    end

    def error(msg)
      raise Error, "#{@place.file} (graine #{@seed}) : #{msg}"
    end

    def inside?(x, y)
      return x >= 0 && y >= 0 && x < @w && y < @h
    end

    def border_size
      object = @place.border && @palette.objects[@place.border]
      return object ? [object.width, object.height] : [0, 0]
    end

    def reserve_border
      bw, bh = border_size
      @h.times do |y|
        @w.times do |x|
          next unless x < bw || x >= @w - bw || y < bh || y >= @h - bh
          @border[y][x] = @solid[y][x] = true
        end
      end
    end

    # Square brush of STREET_WIDTH tiles, top-left at x, y.
    def paint(x, y)
      STREET_WIDTH.times do |dy|
        STREET_WIDTH.times do |dx|
          next if !inside?(x + dx, y + dy)
          @street[y + dy][x + dx] = true
          @solid[y + dy][x + dx] = false
        end
      end
    end

    # L-shaped street, bending at a random end (at the far end on an
    # east-west mountain route, so that the street climbs at the hub).
    def carve_line(x0, y0, x1, y1)
      far_bend = @rng.rand(2) == 0
      far_bend = true if @place.mountain && !vertical_route?
      if far_bend
        (x0 < x1 ? x0.upto(x1) : x0.downto(x1)).each { |x| paint(x, y0) }
        (y0 < y1 ? y0.upto(y1) : y0.downto(y1)).each { |y| paint(x1, y) }
      else
        (y0 < y1 ? y0.upto(y1) : y0.downto(y1)).each { |y| paint(x0, y) }
        (x0 < x1 ? x0.upto(x1) : x0.downto(x1)).each { |x| paint(x, y1) }
      end
    end

    # offset: position along the edge (tiles from the left or top end), set by
    # the world so that both sides of a connection line up; random if nil.
    def carve_exit(side, offset, hub)
      along = ->(size) { offset || @rng.rand((size * 0.25).to_i..(size * 0.75).to_i - STREET_WIDTH) }
      x, y = case side
             when "nord"  then [along.call(@w), 0]
             when "sud"   then [along.call(@w), @h - STREET_WIDTH]
             when "ouest" then [0, along.call(@h)]
             when "est"   then [@w - STREET_WIDTH, along.call(@h)]
             end
      @exits.push([side, x, y])
      carve_line(x, y, hub[0], hub[1])
    end

    # Dead end from the square towards a random point of the inner area (in a
    # port town, a point inland of the promenade, else no dead end).
    def carve_spur(hub)
      bw, bh = border_size
      bw = bh = ISLAND_SHORE.max + 2 if @place.island
      inland = ->(x, y) { !@port_depth || port_depth_at(x, y) >= @port_depth + STREET_WIDTH }
      x, y = nil
      10.times do
        x = @rng.rand(bw + 2..@w - bw - 2 - STREET_WIDTH)
        y = @rng.rand(bh + 2..@h - bh - 2 - STREET_WIDTH)
        break if inland.call(x, y)
      end
      return if !inland.call(x, y)
      carve_line(hub[0], hub[1], x, y)
      @dead_ends.push([x, y])
    end

    def place_bricks
      required = []
      optional = []
      area = @w * @h / (CASE_SIZE * CASE_SIZE).to_f
      @place.counts.each do |kind, range|
        range = (range.min * area).round..(range.max * area).round if @place.per_case.include?(kind)
        count = @rng.rand(range)
        boost = excess[:boost]&.[](kind)
        count = [count, range.max * boost].max if boost
        range.min.times { required.push(kind) }
        (count - range.min).times { optional.push(kind) }
      end
      # Buildings before decoration, so decoration never blocks a door
      with_door = ->(kind) { @bricks.any? { |b| b.kind == kind && b.door } ? 0 : 1 }
      # The bricks an excess boosts go first among the optional ones
      boosted = ->(kind) { excess[:boost]&.key?(kind) ? 0 : 1 }
      order = required.shuffle(random: @rng).sort_by { |k| with_door.call(k) } +
              optional.shuffle(random: @rng).sort_by { |k| [with_door.call(k), boosted.call(k)] }
      # With « dense », the fill bricks may touch each other (not the others)
      @dense = excess[:fill] if excess[:dense]
      order.each_with_index do |kind, i|
        flood_ground if i == required.length
        # The nook right after the buildings, before the decoration
        place_nook if with_door.call(kind) == 1
        next if HIGHLAND.include?(kind) && !@level
        next if kind == HILL && @place.kind == "ville" && @rng.rand(100) >= HILL_TOWN_CHANCE
        next if @left_out.include?(kind)
        next if place_brick(kind)
        # A giant lake shrinks until it fits
        next if kind == LAKE && excess[:giant_lake] && (1..3).any? { |shrink| place_brick(kind, nil, shrink) }
        # A mountain route keeps little ground: what doesn't fit is left out;
        # so does a port town, for its decoration
        next if @level || (@port_depth && with_door.call(kind) == 1)
        error("impossible de placer une brique « #{kind} » ; agrandis « Taille » ou réduis [Briques]") if i < required.length
      end
      flood_ground
      place_nook
      fill_with(excess[:fill]) if excess[:fill]
      @dense = nil
    end

    #---------------------------------------------------------------------------
    # Nooks (optional, behind an obstacle opened by a field item)
    #---------------------------------------------------------------------------
    # The place's nook, once its required bricks are in; left out if it
    # doesn't fit.
    def place_nook
      return if !@place.nook || @nook_tried
      @nook_tried = true
      case @place.nook
      when "ilot"
        return if !@place.water
        # Its pond must lie by ground walked to, to be surfed across
        ground = reachable_ground
        shore = lambda do |brick, x, y|
          w, h = brick.rows[0].length, brick.rows.length
          next (x...x + w).any? { |cx| (y > 0 && ground[y - 1][cx]) || ground[y + h]&.[](cx) } ||
               (y...y + h).any? { |cy| (x > 0 && ground[cy][x - 1]) || ground[cy][x + w] }
        end
        brick, loot = islet_brick
        spot = put_brick(brick, shore) || return
        @nooks.push([spot[0] + loot[0], spot[1] + loot[1], @place.nook])
      when "sombre"
        cave = @bricks.select { |b| b.kind == CAVE }.min_by(&:name) || return
        brick = Brick.new(DARK_CAVE, "Grotte sombre", DARK_CAVE, cave.door, 1, false, cave.rows)
        spot = put_brick(brick) || return
        @nooks.push([spot[0] + brick.door[0], spot[1] + brick.door[1], @place.nook])
      else
        brick, loot = nook_brick
        spot = put_brick(brick) || return
        @nooks.push([spot[0] + loot[0], spot[1] + loot[1], @place.nook, spot[0] + brick.door[0], spot[1] + brick.door[1]])
      end
    end

    # A pocket of ground at the back of a block of rock, reached by a corridor
    # one tile wide from the south: the obstacle stands at its mouth (the
    # door, so a path leads to it). Three tiles wide, so that a pushed boulder
    # can be walked around. Returns the brick and the loot cell (a back
    # corner).
    def nook_brick
      rock = @place.levels&.first || "^"
      ground = @place.ground
      depth = @rng.rand(2..3)
      rows = [" #{rock * 5} ", rock * 7]
      depth.times { rows.push("#{rock * 2}#{ground * 3}#{rock * 2}") }
      2.times { rows.push("#{rock * 3}#{ground}#{rock * 3}") }
      brick = Brick.new(NOOK, "Recoin", NOOK, [3, rows.length - 1], 1, false, rows)
      return brick, [(@rng.rand(2) == 0) ? 2 : 4, 2]
    end

    # An islet of ground (3x2) in a rough oval pond, two tiles of water
    # around it at least. Returns the brick and the loot cell (its middle).
    def islet_brick
      w, h = @rng.rand(7..9), @rng.rand(6..7)
      ix, iy = (w - 3) / 2, (h - 2) / 2
      rows = Array.new(h) do |y|
        Array.new(w) do |x|
          next @place.ground if (ix...ix + 3).include?(x) && (iy...iy + 2).include?(y)
          dx = (x + 0.5 - (w / 2.0)) / (w / 2.0)
          dy = (y + 0.5 - (h / 2.0)) / (h / 2.0)
          ((dx * dx) + (dy * dy) <= 1.0 + (@rng.rand * 0.25)) ? @place.water : " "
        end.join
      end
      return Brick.new(ISLET, "Îlot", ISLET, nil, 1, false, rows), [ix + 1, iy]
    end

    # Excess « fill »: more bricks of that type wherever they still fit.
    # The biggest bricks first, then the smaller ones in the gaps. A brick
    # that would cut off some ground from the exits and doors is taken back.
    def fill_with(kind)
      return if HIGHLAND.include?(kind) && !@level
      left = FILL_LIMIT
      @bricks.select { |b| b.kind == kind }.sort_by { |b| -b.rows.join.count("^ ") }.each do |brick|
        while left > 0
          before = reachable_ground
          spot = put_brick(brick)
          break if !spot
          left -= 1
          after = reachable_ground
          cut_off = (0...@h).any? { |y| (0...@w).any? { |x| before[y][x] && !after[y][x] && !@cells[y][x] } }
          unstamp(brick, *spot) if cut_off
        end
      end
    end

    # Free tiles that can be walked to from the exits and doors.
    def reachable_ground
      starts = @exits.map { |_side, x, y| [x, y] } + @doors.map { |x, y, _| [x, y + 1] }
      starts.push([@terminal[0], @terminal[1] - 1]) if @terminal
      seen = Array.new(@h) { Array.new(@w, false) }
      starts.each do |start|
        next if seen[start[1]][start[0]]
        walk(start).each_with_index { |row, y| row.each_index { |x| seen[y][x] ||= row[x] } }
      end
      return seen
    end

    # Takes back a brick without a door.
    def unstamp(brick, x, y)
      brick.rows.each_with_index do |row, dy|
        row.each_char.with_index do |c, dx|
          next if c == " "
          @cells[y + dy][x + dx] = nil
          @solid[y + dy][x + dx] = false
          @kinds[y + dy][x + dx] = nil
        end
      end
    end

    # Ground on the lowest level that nothing uses yet.
    def free_ground?(x, y)
      return false if level_at(x, y) > 0
      return !@border[y][x] && !@solid[y][x] && !@cells[y][x] && !@stairs_at&.key?([x, y])
    end

    # Excess « flood », once the required bricks are in: water over the free
    # ground, but 2 tiles off the streets and 1 off the bricks, so the way stays
    # dry. Only bodies of water at least 3 tiles thick, no thin ditches. The
    # other bricks then go on what is left.
    def flood_ground
      return if !excess[:flood] || @flooded
      @flooded = true
      open = Array.new(@h) do |y|
        Array.new(@w) do |x|
          free_ground?(x, y) && !near?(x, y, 2) { |nx, ny| @street[ny][nx] } &&
            !near?(x, y, 1) { |nx, ny| @solid[ny][nx] && !@border[ny][nx] && !@water[ny][nx] }
        end
      end
      block = ->(x, y) { (0..2).all? { |oy| (0..2).all? { |ox| open[y + oy]&.[](x + ox) } } }
      wet = Array.new(@h) { Array.new(@w, false) }
      (0..@h - 3).each do |y|
        (0..@w - 3).each do |x|
          next if !block.call(x, y)
          (0..2).each { |oy| (0..2).each { |ox| wet[y + oy][x + ox] = true } }
        end
      end
      @h.times do |y|
        @w.times do |x|
          next if !wet[y][x]
          @cells[y][x] = @place.water
          @water[y][x] = @solid[y][x] = true
        end
      end
      reserve_banks
    end

    #---------------------------------------------------------------------------
    # Banks: the row of ground below the water, where its bottom edge is drawn
    #---------------------------------------------------------------------------
    # Symbols showing the sea autotile.
    def sea_symbols
      @sea_symbols ||= @palette.legend.select { |_c, layers| layers.flatten.any? { |t| SEA_TILES.include?(t) } }.keys
    end

    # The sea and what stands on it with its own edges (piers, boats...).
    def wet_symbols
      @wet_symbols ||= sea_symbols + @palette.objects.select { |_c, o| sea_symbols.include?(o.ground) }.keys +
                       @palette.terrains.select { |_c, t| sea_symbols.include?(t.ground) }.keys
    end

    def sea_at?(x, y)
      return @water[y][x] || sea_symbols.include?(@cells[y][x])
    end

    def wet_at?(x, y)
      return @water[y][x] || wet_symbols.include?(@cells[y][x])
    end

    # The ground below the bottom of the sea ([x, y] of each cell).
    def bank_cells
      return (1...@h).flat_map do |y|
        (0...@w).select { |x| sea_at?(x, y - 1) && !wet_at?(x, y) }.map { |x| [x, y] }
      end
    end

    # Keeps the free ground below the water for its bank: no brick nor path
    # goes there (it stays walkable).
    def reserve_banks
      bank_cells.each { |x, y| @solid[y][x] = true if !@cells[y][x] && !@street[y][x] && !@border[y][x] }
    end

    # Sea too thin for its autotile (a cell in no 2x2 block of water, the map
    # edges counting as water) goes back to ground, until none is left.
    def trim_thin_water
      wet = ->(x, y) { !inside?(x, y) || wet_at?(x, y) }
      loop do
        thin = (0...@h).flat_map do |y|
          (0...@w).select do |x|
            sea_at?(x, y) && [[-1, -1], [0, -1], [-1, 0], [0, 0]].none? do |ox, oy|
              wet.call(x + ox, y + oy) && wet.call(x + ox + 1, y + oy) && wet.call(x + ox, y + oy + 1) && wet.call(x + ox + 1, y + oy + 1)
            end
          end.map { |x| [x, y] }
        end
        break if thin.empty?
        thin.each do |x, y|
          @cells[y][x] = @kinds[y][x] = nil
          @water[y][x] = @solid[y][x] = false
        end
      end
    end

    # No tree below the water: the border gives way to the bank.
    def clear_banks
      bank_cells.each do |x, y|
        next if !@border[y][x] || @cells[y][x]
        @border[y][x] = false
      end
    end

    # Draws the banks: the left end, middle and right end symbols of « Rive »
    # on the ground below the water.
    def draw_banks(rows)
      # On the ground (an islet's too) or a carpet of grass
      cells = bank_cells.select { |x, y| [@place.ground, excess[:carpet]].include?(rows[y][x]) }.to_h { |cell| [cell, true] }
      cells.each_key do |x, y|
        left, right = cells[[x - 1, y]], cells[[x + 1, y]]
        part = (left == right) ? 1 : (left ? 2 : 0)
        rows[y][x] = @place.banks[part]
      end
    end

    # Excess « carpet », once every door and exit is known to be reachable:
    # that symbol (grass, flowers) on the free ground, and over the streets too
    # with « over_street » (walkable, but kept off the exits).
    def cover_ground
      carpet = excess[:carpet]
      return if !carpet
      @h.times do |y|
        @w.times do |x|
          if @street[y][x]
            # Never on the planks of a port
            next if @cells[y][x]
            next if level_at(x, y) > 0 || @stairs_at&.key?([x, y]) || !excess[:over_street]
            next if near?(x, y, 3) { |nx, ny| exit_at?(nx, ny) }
          elsif !free_ground?(x, y)
            next
          end
          @cells[y][x] = carpet
        end
      end
    end

    # True if a tile within that distance (square around x, y) passes the block.
    def near?(x, y, distance)
      (-distance..distance).any? do |oy|
        (-distance..distance).any? { |ox| inside?(x + ox, y + oy) && yield(x + ox, y + oy) }
      end
    end

    def exit_at?(x, y)
      return @exits.any? { |_side, ex, ey| (ex..ex + STREET_WIDTH - 1).cover?(x) && (ey..ey + STREET_WIDTH - 1).cover?(y) }
    end

    #---------------------------------------------------------------------------
    # Port towns (« Port »)
    #---------------------------------------------------------------------------
    # Map cell of port coordinates: a along the sea side (from its left or top
    # end), d inland from the map edge on that side.
    def port_cell(a, d)
      case @place.port
      when "nord"  then [a, d]
      when "sud"   then [a, @h - 1 - d]
      when "ouest" then [d, a]
      else              [@w - 1 - d, a]
      end
    end

    # Smallest distance from the sea edge of the street brush at x, y.
    def port_depth_at(x, y)
      return [port_cell_d(x, y), port_cell_d(x + STREET_WIDTH - 1, y + STREET_WIDTH - 1)].min
    end

    # Distance of a cell from the sea edge.
    def port_cell_d(x, y)
      case @place.port
      when "nord"  then y
      when "sud"   then @h - 1 - y
      when "ouest" then x
      else              @w - 1 - x
      end
    end

    def along_sea
      return %w[nord sud].include?(@place.port) ? @w : @h
    end

    # Draws the sea depth and moves the square inland, far enough from the
    # promenade for streets to come down to it.
    def port_hub(hub)
      across = %w[nord sud].include?(@place.port) ? @h : @w
      @port_depth = [@rng.rand(PORT_DEPTH), (across * PORT_SHARE).to_i].min
      dx, dy = INLAND[@place.port]
      hub = [hub[0] + dx, hub[1] + dy] while port_depth_at(*hub) < @port_depth + STREET_WIDTH + 4
      return hub
    end

    # The sea, its quay (2 rows of planks over the water), the piers out to
    # sea and the promenade behind the quay, linked to the square. The sea
    # stops short of the streets already there (those of the exits on the
    # sides); a town whose exits leave no room for it gets no port.
    def lay_port(hub)
      streets = (0...@h).flat_map { |y| (0...@w).select { |x| @street[y][x] }.map { |x| port_depth_at(x, y) } }
      depth = ([@port_depth] + streets).min
      @port_depth = nil
      return if depth < 7
      @port_depth = depth
      bw, bh = border_size
      edge = %w[nord sud].include?(@place.port) ? bw : bh
      edge = ISLAND_SHORE.max if @place.island
      length = along_sea
      length.times do |a|
        depth.times do |d|
          x, y = port_cell(a, d)
          @border[y][x] = false
          @water[y][x] = @solid[y][x] = true
          @cells[y][x] = @place.water
        end
      end
      deck = lambda do |a, d|
        x, y = port_cell(a, d)
        @cells[y][x] = @place.pier
        @street[y][x] = true
        @water[y][x] = @solid[y][x] = false
      end
      (edge...length - edge).each do |a|
        (depth - 2...depth).each { |d| deck.call(a, d) }
        (depth...depth + STREET_WIDTH).each do |d|
          x, y = port_cell(a, d)
          @street[y][x] = true
          @solid[y][x] = false
        end
      end
      # Piers 3 tiles wide, at least 3 tiles of water between two of them;
      # taken: stretches along the sea kept for a pier or the terminal
      taken = []
      terminal = lay_terminal(depth, edge, length, deck)
      taken.push(terminal) if terminal
      piers = 0
      (edge + 1..length - edge - 4).to_a.shuffle(random: @rng).each do |a|
        break if piers >= @rng.rand(2..4)
        next if taken.any? { |range| range.cover?(a - 3) || range.cover?(a + 5) || (a - 3..a + 5).cover?(range.first) }
        taken.push(a..a + 2)
        piers += 1
        reach = @rng.rand(3..depth - 4)
        (depth - 2 - reach...depth - 2).each { |d| 3.times { |k| deck.call(a + k, d) } }
      end
      lay_pier_lips
      # The promenade comes up to the square in a straight street
      hub_a = %w[nord sud].include?(@place.port) ? hub[0] : hub[1]
      corners = [port_cell(hub_a, depth), port_cell(hub_a + STREET_WIDTH - 1, depth + STREET_WIDTH - 1)]
      carve_line(corners.map(&:first).min, corners.map(&:last).min, hub[0], hub[1])
    end

    # The ferry terminal on piles, entered from the top, at the end of a pier
    # (sea to the south) or under a pier near its end (sea to the east or
    # west); none with the sea to the north, it would face the land. Returns
    # its stretch along the sea, nil if none.
    def lay_terminal(depth, edge, length, deck)
      brick = @bricks.find { |b| b.kind == TERMINAL }
      return nil if !brick || @place.port == "nord" || depth < 9
      bw, bh = brick.rows[0].length, brick.rows.length
      if @place.port == "sud"
        tip = @rng.rand(bh..depth - 3)   # depth of the pier's last planks
        a = @rng.rand(edge + (bw / 2)..length - edge - (bw / 2) - 3)
        pier = [a, tip]
        span = a - (bw / 2) + 1..a + (bw / 2) + 1
        footprint = [[a + 1 - (bw / 2), tip - 1], [a + 1 + (bw / 2), tip - bh]]
      else
        tip = @rng.rand((bw / 2)..depth - 3 - (bw / 2))
        a = @rng.rand(edge + 1..length - edge - 3 - bh - 1)
        pier = [a, tip]
        span = a..a + 2 + bh
        footprint = [[a + 3, tip - (bw / 2)], [a + 2 + bh, tip + (bw / 2)]]
      end
      (pier[1]...depth - 2).each { |d| 3.times { |k| deck.call(pier[0] + k, d) } }
      cells = footprint.map { |fa, fd| port_cell(fa, fd) }
      x, y = cells.map(&:first).min, cells.map(&:last).min
      brick.rows.each_with_index do |row, dy|
        row.each_char.with_index do |c, dx|
          @cells[y + dy][x + dx] = c
          @solid[y + dy][x + dx] = true
          @water[y + dy][x + dx] = false
          @kinds[y + dy][x + dx] = TERMINAL
        end
      end
      @terminal = [x + (bw / 2), y]
      return span
    end

    # The sea around an island, on its sides without the port: a few tiles
    # wide, the width wandering by one tile now and then along the shore.
    def lay_shore
      sides = SIDES - [@place.port]
      width = sides.to_h do |side|
        length = %w[nord sud].include?(side) ? @w : @h
        current = @rng.rand(ISLAND_SHORE)
        [side, Array.new(length) { current = (current + [-1, 0, 0, 1].sample(random: @rng)).clamp(ISLAND_SHORE.min, ISLAND_SHORE.max) }]
      end
      @h.times do |y|
        @w.times do |x|
          next if @street[y][x] || @cells[y][x]
          wet = sides.any? do |side|
            along, depth = case side
                           when "nord"  then [x, y]
                           when "sud"   then [x, @h - 1 - y]
                           when "ouest" then [y, x]
                           else              [y, @w - 1 - x]
                           end
            depth < width[side][along]
          end
          next if !wet
          @cells[y][x] = @place.water
          @water[y][x] = @solid[y][x] = true
        end
      end
    end

    # The boat of a ferry terminal that leads to an island, on the water close
    # to the terminal, with water all around it.
    def moor_boat
      object = @place.boat && @palette.objects[@place.boat]
      return if !object
      bw, bh = object.width, object.height
      tx, ty = @terminal
      spots = []
      (0..@h - bh).each do |y|
        (0..@w - bw).each do |x|
          next if !open_sea?(x, y, bw, bh, 1)
          spots.push([x, y, (x + (bw / 2) - tx).abs + (y + (bh / 2) - ty).abs])
        end
      end
      return if spots.empty?
      x, y, = spots.min_by { |s| s[2] }
      reef(x, y, bw, bh, @place.boat)
    end

    # Sandbanks (walked on after surfing) and rocks in the sea around an
    # island, off the shore, the piers and one another.
    def scatter_reefs
      # The rock autotile draws nothing on a lone cell: 2x2 at least, as on
      # the hand-made maps
      [[@place.bank, ISLAND_BANKS, [2, 4], [2, 3]], [@place.reef, ISLAND_REEFS, [2, 3], [2, 2]]].each do |sym, count, ws, hs|
        next if !sym
        @rng.rand(count).times do
          w, h = @rng.rand(ws[0]..ws[1]), @rng.rand(hs[0]..hs[1])
          spots = (0..@h - h).flat_map { |y| (0..@w - w).map { |x| [x, y] } }
          spot = spots.shuffle(random: @rng).find { |x, y| open_sea?(x, y, w, h, 2) }
          break if !spot
          reef(*spot, w, h, sym)
        end
      end
    end

    # Only plain sea in that rectangle and the margin around it, off the map
    # edge.
    def open_sea?(x, y, w, h, margin)
      return false if x < 1 || y < 1 || x + w > @w - 1 || y + h > @h - 1
      (y - margin...y + h + margin).each do |cy|
        (x - margin...x + w + margin).each do |cx|
          next if !inside?(cx, cy)
          return false if !@water[cy][cx] || @cells[cy][cx] != @place.water
        end
      end
      return true
    end

    # A boat, rocks or a sandbank on the sea: the sand can be walked on (it
    # counts as water for the way, reached by surfing), the rest blocks.
    def reef(x, y, w, h, sym)
      h.times do |dy|
        w.times do |dx|
          @cells[y + dy][x + dx] = sym
          @water[y + dy][x + dx] = (sym == @place.bank)
          @solid[y + dy][x + dx] = true
          @kinds[y + dy][x + dx] = sym
        end
      end
    end

    # The south lip of the planks is drawn on the water under them.
    def lay_pier_lips
      plank = ->(x, y) { inside?(x, y) && @street[y][x] && @cells[y][x] == @place.pier }
      left, middle, right = @place.lips.chars
      (1...@h).each do |y|
        @w.times do |x|
          next if !@water[y][x] || @cells[y][x] != @place.water || !plank.call(x, y - 1)
          @cells[y][x] = if !plank.call(x - 1, y - 1)
                           left
                         elsif !plank.call(x + 1, y - 1)
                           right
                         else
                           middle
                         end
        end
      end
    end

    # One or two port buildings (warehouses) along the promenade, where they
    # fit.
    def place_port_bricks
      along = lambda do |brick, x, y|
        far = [x + brick.rows.map(&:length).max - 1, y + brick.rows.length - 1]
        gap = [port_cell_d(x, y), port_cell_d(*far)].min - @port_depth - STREET_WIDTH
        next gap >= 0 && gap <= 3
      end
      return if @bricks.none? { |b| b.kind == PORT }
      @rng.rand(1..2).times { place_brick(PORT, along) }
    end

    #---------------------------------------------------------------------------
    # Crossings (routes of a world)
    #---------------------------------------------------------------------------
    # Along: the route runs north-south (band across the rows) or east-west.
    def vertical_route?
      return @place.exits.any? { |side, _| %w[nord sud].include?(side) }
    end

    def cross
      length = vertical_route? ? @h : @w
      case @place.crossing
      when "chenal", "lac"
        error("« Eau » manquant pour traverser l'eau") if !@place.water
        # Wider water when it hides a dive spot
        thickness = @place.dive ? @rng.rand(10..[10, length * 3 / 10].max) : @rng.rand(6..[10, length / 4].max)
        low = (length * 0.35).to_i
        start = @rng.rand(low..[low, (length * 0.65).to_i - thickness].max)
        wobble = (@place.crossing == "lac") ? 1 : 0
        flood_band(start, thickness, wobble)
        deepen(start, thickness) if @place.dive
      when "grotte"
        error("« Roche » et « Caillou » manquants pour traverser une grotte") if !@place.rock || !@place.pebble
        start = @rng.rand((length * 0.4).to_i..(length * 0.6).to_i - 3)
        wall_band(start, rock_size[vertical_route? ? 1 : 0])
        place_cave_entrances(start, rock_size[vertical_route? ? 1 : 0])
      else error("traversée « #{@place.crossing} » inconnue")
      end
    end

    #---------------------------------------------------------------------------
    # Mountain routes
    #---------------------------------------------------------------------------
    # The map is cut into bands across the rows, two next bands one level apart
    # (as many levels as « Relief » has symbols, each level its own symbol so
    # that its edges show). The boundary between two bands wanders up and down
    # (FACE_WAVE), flat where a street crosses it. The cells of a level next to
    # a lower one are its cliff (or rim), crossed by stairs where a street
    # goes through. The bands of the exits and the water stay on the ground.
    def raise_levels
      error("« Relief » et « Escalier » manquants pour une route de montagne") if !@place.levels
      _bw, bh = border_size
      crossings = (bh + 3..@h - bh - 3).to_h { |r| [r, boundary_crossings(r)] }.compact
      # A north-south route must climb: every boundary is crossed by a street
      crossings.reject! { |_r, n| n == 0 } if vertical_route?
      # The exits and the water stay on the ground
      ground_rows = @exits.flat_map { |_side, _x, y| [y, y + 1] } +
                    (0...@h).select { |y| @water[y].any? }
      wanted = @rng.rand(vertical_route? ? MOUNTAIN_FACES[:vertical] : MOUNTAIN_FACES[:across])
      wanted = crossings.length if excess[:colossal]
      wanted = [wanted, crossings.length].min
      # East-west routes may end up with cliffs and no stairs; a route with no
      # room for levels stays flat
      [true, vertical_route?].uniq.product(wanted.downto(1).to_a).find do |stairs, count|
        20.times.any? { try_levels(crossings, ground_rows, count, stairs) }
      end
    end

    # Draws count boundaries picked among crossings; false if they don't fit
    # or if they would cut an exit off.
    def try_levels(crossings, ground_rows, count, stairs)
      picks = []
      crossings.keys.shuffle(random: @rng).each do |r|
        picks.push(r) if picks.none? { |p| (p - r).abs < FACE_GAP }
        break if picks.length == count
      end
      return false if picks.length < count
      # Stairs somewhere, even on an east-west route
      return false if stairs && picks.all? { |r| crossings[r] == 0 }
      picks.sort!
      ground = ground_rows.map { |y| picks.count { |p| p <= y } }.uniq
      levels = band_levels(count + 1, ground)
      return false if !levels
      waves = []
      picks.each_with_index { |r, i| waves.push(face_wave(r, i > 0 ? picks[i - 1] : nil, waves.last)) }
      level = Array.new(@h) do |y|
        Array.new(@w) { |x| levels[picks.each_index.count { |i| picks[i] + waves[i][x] <= y }] }
      end
      faces, stairs_at = draw_faces(level)
      return false if !faces
      @level, @face, @stairs_at = level, faces, stairs_at
      @h.times do |y|
        @w.times do |x|
          next if !faces[y][x]
          @cells[y][x] = level_symbol(level_at(x, y))
          @solid[y][x] = true
        end
      end
      return true
    end

    # Number of streets going straight across the boundary above row r, or nil
    # if a street runs along it or crosses it wider than the stairs.
    def boundary_crossings(r)
      crossings = 0
      [r - 1, r].each do |y|
        run = 0
        (0..@w).each do |x|
          if x < @w && @street[y][x]
            return nil if !(r - 2..r + 1).all? { |yy| @street[yy][x] }
            run += 1
            next
          end
          return nil if run != 0 && run != STREET_WIDTH
          crossings += 1 if run > 0 && y == r
          run = 0
        end
      end
      return crossings
    end

    # Level of each of n bands, one apart from band to band, 0 on the ground
    # bands, at most one per « Relief » symbol; climbing more often than not.
    # nil if none fits.
    def band_levels(n, ground)
      top = @place.levels.length
      allowed = Array.new(n) { |i| ground.include?(i) ? [0] : (0..top).to_a }
      # Levels from which the rest of the bands can still be drawn
      feasible = Array.new(n)
      feasible[n - 1] = allowed[n - 1]
      (n - 2).downto(0) do |i|
        feasible[i] = allowed[i].select { |l| feasible[i + 1].include?(l - 1) || feasible[i + 1].include?(l + 1) }
      end
      return nil if feasible[0].empty?
      levels = [feasible[0].sample(random: @rng)]
      (1...n).each do |i|
        options = [levels.last - 1, levels.last + 1] & feasible[i]
        up = levels.last + 1
        levels.push((options.include?(up) && @rng.rand < MOUNTAIN_CLIMB) ? up : options.sample(random: @rng))
      end
      return levels.max > 0 ? levels : nil
    end

    # Offset (rows) of the boundary above row r at each column: it wanders by
    # one now and then, up to FACE_WAVE, flat around the streets crossing it,
    # never moves past a street, the water or an exit, and keeps a band of
    # BAND_MIN rows at least below the boundary above (prev, its wave).
    def face_wave(r, prev = nil, prev_wave = nil)
      keep = ->(x, y) { inside?(x, y) && (@street[y][x] || @water[y][x] || exit_at?(x, y)) }
      crossing = (0...@w).select { |x| keep.call(x, r - 1) && keep.call(x, r) }
      offset = 0
      run = 0
      return Array.new(@w) do |x|
        # A step every few columns at most, so that the edges stay drawable
        run += 1
        if run >= 3 && @rng.rand(3) == 0
          offset = (offset + [-1, 1].sample(random: @rng)).clamp(-FACE_WAVE, FACE_WAVE)
          run = 0
        end
        offset = 0 if crossing.any? { |c| (c - x).abs <= STREET_WIDTH + 1 }
        # Back towards r until nothing to keep lies between
        offset -= (offset <=> 0) while offset != 0 && (offset > 0 ? (r...r + offset) : (r + offset...r)).any? { |y| keep.call(x, y) }
        offset += 1 while prev && r + offset < prev + prev_wave[x] + BAND_MIN
        offset
      end
    end

    # Cliffs: the cells of a level with a lower cell around them (8
    # neighbours). Where a street crosses a cliff from north to south, stairs.
    # Returns [faces, stairs] or nil if a street meets a cliff any other way,
    # or if the exits are no longer joined.
    def draw_faces(level)
      low = ->(x, y) { @low&.[](y)&.[](x) ? 0 : level[y][x] }
      faces = Array.new(@h) { Array.new(@w, false) }
      stairs = {}
      @h.times do |y|
        @w.times do |x|
          here = low.call(x, y)
          next if here == 0 || @border[y][x]
          next if !NEIGHBOURS8.any? { |ox, oy| inside?(x + ox, y + oy) && low.call(x + ox, y + oy) < here }
          faces[y][x] = true
          next if !@street[y][x]
          south = y + 1 < @h && low.call(x, y + 1) < here
          north = y > 0 && low.call(x, y - 1) < here
          side = [[-1, 0], [1, 0]].any? { |ox, _| inside?(x + ox, y) && low.call(x + ox, y) < here && !@street[y][x + ox] }
          return nil if north == south || side
          pair = @place.stairs[(([here, 2].min - 1) * 2) + (south ? 0 : 1)]
          stairs[[x, y]] = (x > 0 && @street[y][x - 1]) ? pair[1] : pair[0]
        end
      end
      # The exits still reach one another, through the stairs
      seen = walk_levels(@exits[0][1, 2], faces, stairs)
      return nil if @exits.any? { |_side, x, y| !seen[y][x] }
      return faces, stairs
    end

    # Like walk, with the cliffs in the way (stairs excepted).
    def walk_levels(start, faces, stairs)
      seen = Array.new(@h) { Array.new(@w, false) }
      seen[start[1]][start[0]] = true
      queue = [start]
      until queue.empty?
        x, y = queue.shift
        NEIGHBOURS.each do |ox, oy|
          nx, ny = x + ox, y + oy
          next if !inside?(nx, ny) || seen[ny][nx]
          next if faces[ny][nx] && !stairs[[nx, ny]]
          next if !@street[ny][nx] && !@water[ny][nx] && (@cells[ny][nx] || @border[ny][nx] || @solid[ny][nx])
          seen[ny][nx] = true
          queue.push([nx, ny])
        end
      end
      return seen
    end

    # Level of a tile (0 on the river and its outer bank).
    def level_at(x, y)
      return 0 if !@level || @low&.[](y)&.[](x)
      return @level[y][x]
    end

    # The « Relief » symbol of a level.
    def level_symbol(level)
      return @place.levels[level - 1]
    end

    # Tall grass on the raised levels of a mountain route, in a few patches
    # (MOUNTAIN_GRASS per CASE_SIZE square of raised ground), off the streets
    # and the cliffs.
    def grow_highland_grass
      return if !@level || !@place.high_grass
      free = ->(x, y) { inside?(x, y) && level_at(x, y) > 0 && !@solid[y][x] && !@street[y][x] && !@cells[y][x] && !@border[y][x] }
      raised = (0...@h).flat_map { |y| (0...@w).select { |x| free.call(x, y) }.map { |x| [x, y] } }
      return if raised.empty?
      (raised.length * @rng.rand(MOUNTAIN_GRASS) / (CASE_SIZE * CASE_SIZE)).ceil.times do
        cx, cy = raised.sample(random: @rng)
        r = @rng.rand(1.5..3.0)
        (cy - 3..cy + 3).each do |y|
          (cx - 3..cx + 3).each do |x|
            next if ((x - cx)**2) + ((y - cy)**2) > r * r || !free.call(x, y)
            @cells[y][x] = @place.high_grass
            @kinds[y][x] = "herbes"
          end
        end
      end
    end

    # The mountain cave at the foot of a cliff (the cells above it all cliff of
    # a higher level), anywhere it fits otherwise.
    def place_mountain_cave
      foot = lambda do |brick, x, y|
        next y > 0 && brick.rows[0].length.times.all? { |dx| @face&.[](y - 1)&.[](x + dx) && level_at(x + dx, y - 1) > level_at(x + dx, y) }
      end
      place_brick(CAVE, foot) || place_brick(CAVE)
    end

    # River alongside a north-south mountain route: a band 3 or 4 tiles wide
    # against the west or east border, winding a little, on the ground the
    # whole way (the cliffs stop at its bank), 2 tiles off the streets. It
    # runs from the northern to the southern trees; none if it doesn't fit.
    def choose_river
      bw, bh = border_size
      width = @rng.rand(3..4)
      rows = (bh...@h - bh)
      [:west, :east].shuffle(random: @rng).find do |side|
        cells = Array.new(@h) { Array.new(@w, false) }
        low = Array.new(@h) { Array.new(@w, false) }
        offset = 0
        ok = rows.all? do |y|
          offset = (offset + @rng.rand(-1..1)).clamp(0, 2) if y % 3 == 0
          x0 = (side == :west) ? bw + offset : @w - bw - width - offset
          band = (x0...x0 + width)
          next false if (x0 - 2..x0 + width + 1).any? { |x| inside?(x, y) && @street[y][x] }
          band.each { |x| cells[y][x] = true }
          # Between the river and the trees: ground, no thin strip of cliff
          outer = (side == :west) ? (0...x0 + width) : (x0...@w)
          outer.each { |x| low[y][x] = true }
          true
        end
        @river, @low = cells, low if ok
        ok
      end
    end

    # The river's water, once the levels are drawn.
    def lay_river
      return if !@river
      @h.times do |y|
        @w.times do |x|
          next if !@river[y][x]
          @cells[y][x] = @place.water
          @water[y][x] = @solid[y][x] = true
        end
      end
      reserve_banks
    end

    # On an east-west mountain route, a hub row away from the exits, so that the
    # streets climb to it.
    def climbing_hub_row
      return nil if vertical_route?
      _bw, bh = border_size
      exit_rows = @place.exits.filter_map { |_side, offset| offset }
      rows = (bh + 1..@h - bh - 1 - STREET_WIDTH).to_a
      return nil if rows.empty? || exit_rows.empty?
      distance = ->(y) { exit_rows.map { |e| (y - e).abs }.min }
      best = rows.map(&distance).max
      return nil if best < 3
      return rows.select { |y| distance.call(y) == best }.sample(random: @rng)
    end

    def rock_size
      object = @palette.objects[@place.rock]
      return [object.width, object.height]
    end

    # Cell of the band at position a along the route and b across it.
    def band_cell(along, across)
      return vertical_route? ? [across, along] : [along, across]
    end

    # Water from edge to edge of the inner area, between start and
    # start + thickness along the route; a lake's shores move by up to wobble
    # every 3 cells (no thinner bumps, they look odd in the water's edge).
    def flood_band(start, thickness, wobble)
      across = vertical_route? ? @w : @h
      top, bottom = start, start + thickness
      across.times do |b|
        if wobble > 0 && b % 3 == 0
          top = (top + @rng.rand(-wobble..wobble)).clamp(start - 3, start + 2)
          bottom = (bottom + @rng.rand(-wobble..wobble)).clamp(start + thickness - 2, start + thickness + 3)
        end
        (top...bottom).each do |a|
          x, y = band_cell(a, b)
          next if @border[y][x]
          @cells[y][x] = @place.water
          @water[y][x] = @solid[y][x] = true
          @street[y][x] = false
        end
      end
    end

    # An oval of deep water in the middle of the band, where the player can
    # dive (the map's DiveMap lies under it).
    def deepen(start, thickness)
      error("« Profond » manquant pour plonger") if !@place.deep
      across = vertical_route? ? @w : @h
      ra = (thickness / 2.0) - 1.5
      rb = @rng.rand(3.0..[6.0, across / 4.0].max)
      ca = start + (thickness / 2.0)
      cb = @rng.rand((across * 0.35)..(across * 0.65))
      @deep = []
      (start...start + thickness).each do |a|
        across.times do |b|
          da = (a + 0.5 - ca) / ra
          db = (b + 0.5 - cb) / rb
          next if (da * da) + (db * db) > 1.0
          x, y = band_cell(a, b)
          next if !@water[y][x]
          @cells[y][x] = @place.deep
          @deep.push([x, y])
        end
      end
      error("eau profonde vide ; élargis la route") if @deep.empty?
    end

    # A wall of rocks across the whole map (border included), gaps filled with
    # border objects, then with pebbles.
    def wall_band(start, depth)
      across = vertical_route? ? @w : @h
      wall = {}
      depth.times { |a| across.times { |b| wall[band_cell(start + a, b)] = true } }
      wall.each_key do |x, y|
        @cells[y][x] = nil
        @solid[y][x] = true
        @street[y][x] = @border[y][x] = false
      end
      fill = [@place.rock, @place.border].compact.map { |sym| [sym, @palette.objects[sym]] }
      wall.each_key do |x, y|
        fill.each do |sym, object|
          cells = (0...object.height).flat_map { |dy| (0...object.width).map { |dx| [x + dx, y + dy] } }
          next if !cells.all? { |cx, cy| wall[[cx, cy]] && !@cells[cy][cx] }
          cells.each { |cx, cy| @cells[cy][cx] = sym }
          break
        end
      end
      wall.each_key { |x, y| @cells[y][x] ||= @place.pebble }
    end

    # One cave entrance on each side of the wall, linked to that side's street.
    def place_cave_entrances(start, depth)
      return if !@bricks.any? { |b| b.kind == CAVE }
      [[0, start], [start + depth, vertical_route? ? @h : @w]].each do |from, to|
        side = lambda do |brick, x, y|
          a0 = vertical_route? ? y : x
          a1 = a0 + (vertical_route? ? brick.rows.length + STREET_WIDTH : brick.rows[0].length)
          next a0 >= from && a1 <= to
        end
        next if place_brick(CAVE, side)
        error("impossible de placer l'entrée de la grotte ; allonge la route")
      end
    end

    #---------------------------------------------------------------------------
    # Lakes (« lac » in [Briques])
    #---------------------------------------------------------------------------
    # A brick of water in a rough oval, made for this spot of the map.
    # A giant lake (excess) that doesn't fit is retried smaller (shrink).
    def lake_brick(shrink = 0)
      w, h = @rng.rand(6..11), @rng.rand(5..8)
      if excess[:giant_lake]
        bw, bh = border_size
        w = @rng.rand(12..[12, @w - (2 * bw) - 4].max.clamp(12, 22)) * (5 - shrink) / 5
        h = @rng.rand(9..[9, @h - (2 * bh) - 4].max.clamp(9, 16)) * (5 - shrink) / 5
      end
      rows = Array.new(h) do |y|
        Array.new(w) do |x|
          dx = (x + 0.5 - (w / 2.0)) / (w / 2.0)
          dy = (y + 0.5 - (h / 2.0)) / (h / 2.0)
          ((dx * dx) + (dy * dy) <= 1.0 + (@rng.rand * 0.25)) ? @place.water : " "
        end.join
      end
      return Brick.new(LAKE, "Lac", LAKE, nil, 1, false, rows)
    end

    # A hill: a brick of rock in a rough oval made for this spot, a stair in
    # the middle of its south face (its door, so a path leads to it).
    def hill_brick
      rock = @place.levels&.first || "^"
      stair = @place.stairs&.first&.[](0) || "e"
      w, h = @rng.rand(5..9), @rng.rand(4..6)
      rows = Array.new(h) do |y|
        Array.new(w) do |x|
          dx = (x + 0.5 - (w / 2.0)) / (w / 2.0)
          dy = (y + 0.5 - (h / 2.0)) / (h / 2.0)
          ((dx * dx) + (dy * dy) <= 1.0 + (@rng.rand * 0.2)) ? rock : " "
        end.join
      end
      door = w / 2
      rows[h - 1][door] = stair
      rows[h - 2][door] = rock
      return Brick.new(HILL, "Colline", HILL, [door, h - 1], 1, false, rows)
    end

    def pick_brick(kind, shrink = 0)
      return lake_brick(shrink) if kind == LAKE
      return hill_brick if kind == HILL
      bricks = @bricks.select { |b| b.kind == kind }
      roll = @rng.rand(bricks.sum(&:weight))
      return bricks.find { |b| (roll -= b.weight) < 0 }
    end

    # Puts one brick of that type where it fits (and where allowed says so);
    # returns false if none does.
    def place_brick(kind, allowed = nil, shrink = 0)
      return put_brick(pick_brick(kind, shrink), allowed)
    end

    def put_brick(brick, allowed = nil)
      bw, bh = brick.rows.map(&:length).max, brick.rows.length
      distances = brick.door ? street_distances : nil
      spots = []
      (0..@h - bh).each do |y|
        (0..@w - bw).each do |x|
          next if allowed && !allowed.call(brick, x, y)
          next if !fits?(brick, x, y)
          next if brick.by_street && !touches_street?(brick, x, y)
          if brick.door
            d = distances[y + bh][x + brick.door[0]]
            next if !d || d > MAX_DOOR_DISTANCE
            spots.push([x, y, d])
          else
            spots.push([x, y, 0])
          end
        end
      end
      return false if spots.empty?
      # Close to a street, but not always the closest spot
      best = spots.map { |s| s[2] }.min
      x, y, = spots.select { |s| s[2] <= best + 2 }.sample(random: @rng)
      stamp(brick, x, y)
      return [x, y]
    end

    # The brick's cells must be free, with one free tile around it (streets
    # may touch it) so that two bricks never stick together.
    def fits?(brick, x, y)
      brick.rows.each_with_index do |row, dy|
        row.each_char.with_index do |c, dx|
          next if c == " "
          cx, cy = x + dx, y + dy
          return false if @solid[cy][cx] || @street[cy][cx]
          raised = level_at(cx, cy) > 0
          return false if HIGHLAND.include?(brick.kind) != raised
          (-1..1).each do |oy|
            (-1..1).each do |ox|
              nx, ny = cx + ox, cy + oy
              next if !inside?(nx, ny) || !@solid[ny][nx] || @border[ny][nx]
              # A cave entrance may lean against a cliff
              next if brick.kind == CAVE && @face&.[](ny)&.[](nx)
              return false if brick.kind != @dense || @kinds[ny][nx] != @dense
            end
          end
        end
      end
      return false if !bank_free?(brick, x, y)
      return true if !brick.door
      # The path under the door must be free or already a street
      fx, fy = x + brick.door[0], y + brick.rows.length
      return false if !inside?(fx + STREET_WIDTH - 1, fy + STREET_WIDTH - 1)
      STREET_WIDTH.times do |oy|
        STREET_WIDTH.times { |ox| return false if @solid[fy + oy][fx + ox] }
      end
      return true
    end

    # A brick of water keeps the cells below its bottom edge off the streets
    # of a town (their paving can't show the bank).
    def bank_free?(brick, x, y)
      return true if @place.street == @place.ground
      brick.rows.each_with_index do |row, dy|
        row.each_char.with_index do |c, dx|
          next if !sea_symbols.include?(c) || wet_symbols.include?(brick.rows[dy + 1]&.[](dx))
          return false if inside?(x + dx, y + dy + 1) && @street[y + dy + 1][x + dx]
        end
      end
      return true
    end

    def touches_street?(brick, x, y)
      brick.rows.each_with_index do |row, dy|
        row.each_char.with_index do |c, dx|
          next if c == " "
          NEIGHBOURS.each do |ox, oy|
            nx, ny = x + dx + ox, y + dy + oy
            return true if inside?(nx, ny) && @street[ny][nx]
          end
        end
      end
      return false
    end

    def stamp(brick, x, y)
      brick.rows.each_with_index do |row, dy|
        row.each_char.with_index do |c, dx|
          next if c == " "
          # On a raised level, a brick's relief stands that much higher
          step = HIGHLAND.include?(brick.kind) ? @place.levels&.index(c) : nil
          c = level_symbol(level_at(x + dx, y + dy) + step) if step && level_at(x + dx, y + dy) + step <= @place.levels.length
          @cells[y + dy][x + dx] = c
          @solid[y + dy][x + dx] = true
          @kinds[y + dy][x + dx] = brick.kind
        end
      end
      reserve_banks if brick.rows.any? { |row| row.each_char.any? { |c| sea_symbols.include?(c) } }
      return if !brick.door
      dx, dy = x + brick.door[0], y + brick.door[1]
      @doors.push([dx, dy, brick])
      street_distances   # again, now that the brick is in the way
      carve_path(dx, dy + 1)
    end

    # Steps of the street brush between free cells.
    def brush_free?(x, y)
      return false if !inside?(x, y) || !inside?(x + STREET_WIDTH - 1, y + STREET_WIDTH - 1)
      STREET_WIDTH.times do |oy|
        STREET_WIDTH.times { |ox| return false if @solid[y + oy][x + ox] }
      end
      return true
    end

    def brush_on_street?(x, y)
      STREET_WIDTH.times do |oy|
        STREET_WIDTH.times { |ox| return true if @street[y + oy][x + ox] }
      end
      return false
    end

    NEIGHBOURS = [[0, -1], [1, 0], [0, 1], [-1, 0]]
    NEIGHBOURS8 = [[0, -1], [1, -1], [1, 0], [1, 1], [0, 1], [-1, 1], [-1, 0], [-1, -1]].freeze

    # Brush steps from every street cell outward: distances[y][x] (nil = no
    # path), parents for carve_path.
    def street_distances
      @parents = Array.new(@h) { Array.new(@w) }
      distances = Array.new(@h) { Array.new(@w) }
      queue = []
      @h.times do |y|
        @w.times do |x|
          next if !brush_free?(x, y) || !brush_on_street?(x, y)
          distances[y][x] = 0
          queue.push([x, y])
        end
      end
      until queue.empty?
        x, y = queue.shift
        NEIGHBOURS.each do |ox, oy|
          nx, ny = x + ox, y + oy
          next if !brush_free?(nx, ny) || distances[ny][nx]
          distances[ny][nx] = distances[y][x] + 1
          @parents[ny][nx] = [x, y]
          queue.push([nx, ny])
        end
      end
      return distances
    end

    def carve_path(x, y)
      while x
        paint(x, y)
        x, y = @parents[y][x]
      end
    end

    # Fills the border with copies of the border object; leftovers stay ground.
    def plant_border
      return if !@place.border
      bw, bh = border_size
      @h.times do |y|
        @w.times do |x|
          next if !(0...bh).all? { |dy| (0...bw).all? { |dx| free_border?(x + dx, y + dy) } }
          bh.times { |dy| bw.times { |dx| @cells[y + dy][x + dx] = @place.border } }
        end
      end
    end

    def free_border?(x, y)
      return inside?(x, y) && @border[y][x] && !@street[y][x] && !@cells[y][x]
    end

    # Walks over ground and streets (and water, by surfing) from the first
    # exit: every exit and the cell below every door must be reached. Across a
    # cave's wall, each side is walked from its own exit and must reach its
    # cave entrance.
    def check_reachable
      return if @exits.empty? && @doors.empty? && !@terminal && !@place.island
      if @place.crossing == "grotte"
        @exits.each do |side, ex, ey|
          seen = walk([ex, ey])
          next if @doors.any? { |dx, dy, brick| brick.kind == CAVE && seen[dy + 1][dx] }
          error("la sortie #{side} ne mène à aucune entrée de la grotte")
        end
        return
      end
      error("l'île n'a pas de gare maritime") if @place.island && !@terminal
      start = if !@exits.empty?
                @exits[0][1, 2]
              elsif @terminal
                [@terminal[0], @terminal[1] - 1]
              else
                [@doors[0][0], @doors[0][1] + 1]
              end
      seen = walk(start)
      error("la gare maritime est inaccessible") if @terminal && !seen[@terminal[1] - 1][@terminal[0]]
      @exits.each { |side, ex, ey| error("la sortie #{side} est inaccessible") if !seen[ey][ex] }
      @doors.each do |dx, dy, brick|
        error("la porte de « #{brick.name} » est inaccessible") if !seen[dy + 1][dx]
      end
    end

    def walk(start)
      walkable = lambda do |x, y|
        inside?(x, y) && (@street[y][x] || @water[y][x] || (!@cells[y][x] && !@border[y][x]))
      end
      seen = Array.new(@h) { Array.new(@w, false) }
      seen[start[1]][start[0]] = true
      queue = [start]
      until queue.empty?
        x, y = queue.shift
        NEIGHBOURS.each do |ox, oy|
          nx, ny = x + ox, y + oy
          next if !walkable.call(nx, ny) || seen[ny][nx]
          seen[ny][nx] = true
          queue.push([nx, ny])
        end
      end
      return seen
    end
  end

  module_function

  # Returns [MapGen plan, its text, Layout] for that seed. The ambiance is
  # drawn from the seed unless place.ambiance already names one.
  def generate_place(place, bricks, seed)
    if !place.ambiance && place.ambiances.any?
      place = place.dup
      place.ambiance = draw_ambiance(place, Random.new(seed + 7919))
    end
    place = with_ambiance_counts(place)
    palette = check_palette(place, bricks)
    layout = PlaceBuilder.new(place, bricks, palette, seed).build
    text = plan_text(place, seed, layout.rows)
    return MapGenerator.parse(text, place.file), text, layout
  end
end
