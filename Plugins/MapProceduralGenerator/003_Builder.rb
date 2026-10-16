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
# Same place + same bricks + same seed = same map.
#===============================================================================
module MapProceduralGenerator
  # rows: MapGen [Map] rows; doors: [x, y, brick] (door cells); exits:
  # [side, x, y] (first street cell on the map edge)
  # deep: cells of deep water, where the player can dive
  Layout = Struct.new(:rows, :doors, :exits, :deep)

  # Bricks counted "par case" in [Briques] are multiplied by the place's area
  # in squares of CASE_SIZE x CASE_SIZE tiles.
  CASE_SIZE = 20
  CAVE = "grotte"   # type of the cave entrance bricks
  # The only bricks on the raised levels of a mountain route (the others have
  # grass under them), and only there
  HIGHLAND = ["rocaille"].freeze
  # Most bricks an excess « fill » adds after the others (until none fits)
  FILL_LIMIT = 80

  class PlaceBuilder
    def initialize(place, bricks, palette, seed)
      @place = place
      @bricks = bricks.select { |b| place.counts[b.kind] || (b.kind == CAVE && (place.crossing == "grotte" || place.cave)) }
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
    end

    def build
      reserve_border
      hub = [@rng.rand((@w * 0.35).to_i..(@w * 0.65).to_i - STREET_WIDTH),
             @rng.rand((@h * 0.35).to_i..(@h * 0.65).to_i - STREET_WIDTH)]
      hub[1] = climbing_hub_row || hub[1] if @place.mountain
      @place.exits.each { |side, offset| carve_exit(side, offset, hub) }
      @rng.rand(@place.spurs).times { carve_spur(hub) }
      @water = Array.new(@h) { Array.new(@w, false) }
      cross if @place.crossing
      if @place.mountain
        choose_river if @place.river
        raise_levels
        lay_river
        # Its cave is left out when no spot fits
        place_brick(CAVE) if @place.cave
      end
      place_bricks
      plant_border
      check_reachable
      cover_ground
      rows = Array.new(@h) { |y| Array.new(@w) { |x| symbol_at(x, y) }.join }
      return Layout.new(rows, @doors, @exits, @deep || [])
    end

    private

    def symbol_at(x, y)
      return @stairs_at[[x, y]] if @stairs_at&.key?([x, y])
      rock = (level_at(x, y) > 0) ? @place.levels[level_at(x, y) - 1] : nil
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

    # Dead end from the square towards a random point of the inner area.
    def carve_spur(hub)
      bw, bh = border_size
      x = @rng.rand(bw + 2..@w - bw - 2 - STREET_WIDTH)
      y = @rng.rand(bh + 2..@h - bh - 2 - STREET_WIDTH)
      carve_line(hub[0], hub[1], x, y)
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
        next if HIGHLAND.include?(kind) && !@level
        next if place_brick(kind)
        # A giant lake shrinks until it fits
        next if kind == LAKE && excess[:giant_lake] && (1..3).any? { |shrink| place_brick(kind, nil, shrink) }
        # A mountain route keeps little ground: what doesn't fit is left out
        next if @level
        error("impossible de placer une brique « #{kind} » ; agrandis « Taille » ou réduis [Briques]") if i < required.length
      end
      flood_ground
      fill_with(excess[:fill]) if excess[:fill]
      @dense = nil
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
    # The map is cut into bands across the rows, each at level 0 (ground), 1 or
    # 2, two next bands one level apart. The higher one shows a cliff (its
    # south face) or a rim (its north edge), crossed by stairs where a street
    # goes through. The bands of the exits stay on the ground.
    def raise_levels
      error("« Relief » et « Escalier » manquants pour une route de montagne") if !@place.levels
      _bw, bh = border_size
      crossings = (bh + 3..@h - bh - 3).to_h { |r| [r, boundary_crossings(r)] }.compact
      # A north-south route must climb: every boundary is crossed by a street
      crossings.reject! { |_r, n| n == 0 } if vertical_route?
      # The exits and the water stay on the ground
      ground_rows = @exits.flat_map { |_side, _x, y| [y, y + 1] } +
                    (0...@h).select { |y| @water[y].any? }
      wanted = vertical_route? ? @rng.rand(3..4) : @rng.rand(1..2)
      wanted = vertical_route? ? 8 : 3 if excess[:colossal]
      # East-west routes may end up with cliffs and no stairs; a route with no
      # room for levels stays flat
      [true, vertical_route?].uniq.product(wanted.downto(1).to_a).find do |stairs, count|
        20.times.any? { try_levels(crossings, ground_rows, count, stairs) }
      end
    end

    # Draws count boundaries picked among crossings; false if they don't fit.
    def try_levels(crossings, ground_rows, count, stairs)
      picks = []
      crossings.keys.shuffle(random: @rng).each do |r|
        picks.push(r) if picks.none? { |p| (p - r).abs < 5 }
        break if picks.length == count
      end
      return false if picks.length < count
      # Stairs somewhere, even on an east-west route
      return false if stairs && picks.all? { |r| crossings[r] == 0 }
      picks.sort!
      band = ->(y) { picks.count { |p| p <= y } }
      ground = ground_rows.map(&band).uniq
      sequences = level_sequences(count + 1).select do |seq|
        seq.max > 0 && ground.all? { |i| seq[i] == 0 }
      end
      return false if sequences.empty?
      # Up to the 2nd level when possible, most of the time
      high = sequences.select { |seq| seq.max == 2 }
      sequences = high if !high.empty? && (excess[:colossal] || @rng.rand(3) > 0)
      levels = sequences.sample(random: @rng)
      @level = Array.new(@h) { |y| levels[band.call(y)] }
      picks.each { |r| draw_face(r) }
      return true
    end

    # Level sequences of n bands, one level apart from band to band.
    def level_sequences(n)
      sequences = [[0], [1], [2]]
      (n - 1).times do
        sequences = sequences.flat_map do |seq|
          [seq.last - 1, seq.last + 1].select { |l| l.between?(0, 2) }.map { |l| seq + [l] }
        end
      end
      return sequences
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

    # The higher band's row along the boundary above row r: a wall, with
    # stairs where the streets cross it.
    def draw_face(r)
      north, south = @level[r - 1], @level[r]
      y, level = (north > south) ? [r - 1, north] : [r, south]
      pair = @place.stairs[((level - 1) * 2) + ((north > south) ? 0 : 1)]
      @stairs_at ||= {}
      @w.times do |x|
        next if @border[y][x] || @low&.[](y)&.[](x)
        if @street[y][x]
          @stairs_at[[x, y]] = @street[y][x - 1] ? pair[1] : pair[0]
        else
          @cells[y][x] = @place.levels[level - 1]
          @solid[y][x] = true
        end
      end
    end

    # Level of a tile: that of its band, but the river and its outer bank stay
    # on the ground.
    def level_at(x, y)
      return 0 if !@level || @low&.[](y)&.[](x)
      return @level[y]
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

    def pick_brick(kind, shrink = 0)
      return lake_brick(shrink) if kind == LAKE
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
              return false if brick.kind != @dense || @kinds[ny][nx] != @dense
            end
          end
        end
      end
      return true if !brick.door
      # The path under the door must be free or already a street
      fx, fy = x + brick.door[0], y + brick.rows.length
      return false if !inside?(fx + STREET_WIDTH - 1, fy + STREET_WIDTH - 1)
      STREET_WIDTH.times do |oy|
        STREET_WIDTH.times { |ox| return false if @solid[fy + oy][fx + ox] }
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
          @cells[y + dy][x + dx] = c
          @solid[y + dy][x + dx] = true
          @kinds[y + dy][x + dx] = brick.kind
        end
      end
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
      return if @exits.empty? && @doors.empty?
      if @place.crossing == "grotte"
        @exits.each do |side, ex, ey|
          seen = walk([ex, ey])
          next if @doors.any? { |dx, dy, brick| brick.kind == CAVE && seen[dy + 1][dx] }
          error("la sortie #{side} ne mène à aucune entrée de la grotte")
        end
        return
      end
      start = @exits.empty? ? [@doors[0][0], @doors[0][1] + 1] : @exits[0][1, 2]
      seen = walk(start)
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
    palette = check_palette(place, bricks)
    layout = PlaceBuilder.new(place, bricks, palette, seed).build
    text = plan_text(place, seed, layout.rows)
    return MapGenerator.parse(text, place.file), text, layout
  end
end
