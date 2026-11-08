#===============================================================================
# MapProceduralGenerator - Place assembler (relief), see 003_Builder.rb
# Relief: the raised levels of a mountain route or a town in terraces, their
# cliffs and stairs, the peaks, the highland grass, the river and the
# mountain's cave.
#===============================================================================
module MapProceduralGenerator
  class PlaceBuilder
    private

    # [Layer3] of the map: each raised level's symbol on all its cells, its
    # stairs and the border trees HOLE (every level joins it: no cliff drawn
    # over the trees, which block anyway), "." elsewhere. The level terrains
    # draw their rims and cliffs there, whatever stands on them below.
    def level_rows
      return nil if !@level
      return Array.new(@h) do |y|
        Array.new(@w) do |x|
          next HOLE if @stairs_at.key?([x, y]) || (@border[y][x] && [@place.border, @place.filler].include?(@cells[y][x]))
          level_at(x, y) > 0 ? level_symbol(level_at(x, y)) : MapGenerator::OVERLAY_EMPTY
        end.join
      end
    end

    # A town in terraces (TERRACE_CHANCE): big enough for a square, with a
    # « Relief », not plain, a port, an island, a canal or a mask. A plain
    # route too (ROUTE_TERRACE_CHANCE): not a mountain, no water or cave
    # across it, no deep water, no shortcut, no mask, no flood.
    def terrace?
      return false if @plain || @terrace.nil? || !@place.levels || @place.mountain || @mask || excess[:flat]
      chance = TERRACE_CHANCE
      if @place.kind == "route"
        return false if @place.crossing || @place.dive || @place.lock || excess[:flood]
        chance = ROUTE_TERRACE_CHANCE
      else
        return false if @place.kind != "ville" || @place.port || @place.island || @plan.nil? || @plan == "canal"
      end
      return Random.new(@seed ^ TERRACE_SALT).rand(100) < chance
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
      # A town's terraces have their own draws, one set per try
      terraces = Random.new((@seed ^ TERRACE_SALT) + (@terrace.to_i * 7919)) if !@place.mountain
      wanted = terraces.rand(@place.kind == "route" ? ROUTE_TERRACE[:faces] : TERRACE_FACES) if terraces
      wanted = crossings.length if excess[:colossal]
      wanted = [wanted, crossings.length].min
      # East-west routes may end up with cliffs and no stairs; a route with no
      # room for levels stays flat
      [true, vertical_route?].uniq.product(wanted.downto(1).to_a).find do |stairs, count|
        20.times.any? { try_levels(crossings, ground_rows, count, stairs, terraces) }
      end
    end

    # Draws count boundaries picked among crossings; false if they don't fit
    # or if they would cut an exit off.
    def try_levels(crossings, ground_rows, count, stairs, terraces = nil)
      picks = []
      crossings.keys.shuffle(random: @rng).each do |r|
        picks.push(r) if picks.none? { |p| (p - r).abs < FACE_GAP }
        break if picks.length == count
      end
      picks = terrace_picks(crossings, ground_rows, count, terraces) if terraces
      return false if picks.length < count
      # Stairs somewhere, even on an east-west route
      return false if stairs && picks.all? { |r| crossings[r] == 0 }
      picks.sort!
      ground = ground_rows.map { |y| picks.count { |p| p <= y } }.uniq
      levels = band_levels(count + 1, ground)
      return false if !levels
      waves = []
      relief = Random.new(@seed ^ RELIEF_SALT)
      picks.each_with_index do |r, i|
        # The north rim of a level (the higher band to the south) stays nearly
        # flat: its steps would only show the rock of its corners
        rim = levels[i + 1] > levels[i]
        waves.push(face_wave(r, i > 0 ? picks[i - 1] : nil, waves.last, relief, rim))
      end
      band = Array.new(@h) do |y|
        Array.new(@w) { |x| picks.each_index.count { |i| picks[i] + waves[i][x] <= y } }
      end
      level = band.map { |row| row.map { |i| levels[i] } }
      trim_sides(level, band, levels, relief)
      raise_peaks(level) if @place.mountain
      raise_peaks(level, TERRACE_PEAKS, terraces, true) if terraces
      return false if !thicken(level)
      faces, stairs_at = draw_faces(level)
      return false if !faces
      # Never through what stands already (a square's fountain)
      return false if @h.times.any? { |y| @w.times.any? { |x| faces[y][x] && @solid[y][x] } }
      @level, @face, @stairs_at = level, faces, stairs_at
      @h.times do |y|
        @w.times do |x|
          next if !faces[y][x]
          @cells[y][x] = CLIFF
          @solid[y][x] = true
        end
      end
      return true
    end

    # The count boundaries of a town's (or route's) terraces, TERRACE_DEPTH
    # (ROUTE_TERRACE) rows apart at least, none right by an exit or the water
    # (ground_rows); [] if none fits. The bands of the exits and the water stay on the ground.
    def terrace_picks(crossings, ground_rows, count, terraces)
      depth = (@place.kind == "route") ? ROUTE_TERRACE[:depth] : TERRACE_DEPTH
      20.times do
        picks = []
        crossings.keys.shuffle(random: terraces).each do |r|
          picks.push(r) if picks.none? { |p| (p - r).abs < depth }
          break if picks.length == count
        end
        return picks if picks.length == count && ground_rows.none? { |y| picks.any? { |p| (y - p).between?(-1, 0) } }
      end
      return []
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
          # A town's stairs are as wide as its avenues and its square
          return nil if run != 0 && run != STREET_WIDTH && @place.mountain
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
    # one now and then, up to FACE_WAVE, or slopes one way up to SLOPE_WAVE
    # (SLOPE_CHANCE, drawn with relief); flat around the streets crossing it,
    # never moves past a street, the water or an exit, and keeps a band of
    # BAND_MIN rows at least below the boundary above (prev, its wave).
    def face_wave(r, prev = nil, prev_wave = nil, relief = @rng, rim = false)
      keep = ->(x, y) { inside?(x, y) && (@street[y][x] || @water[y][x] || exit_at?(x, y)) }
      crossing = (0...@w).select { |x| keep.call(x, r - 1) && keep.call(x, r) }
      slope = (relief.rand(100) < SLOPE_CHANCE) ? [-1, 1].sample(random: relief) : 0
      slope = 0 if rim
      wave = (slope == 0) ? FACE_WAVE : SLOPE_WAVE
      offset = (slope == 0) ? 0 : -slope * relief.rand(0..SLOPE_WAVE)
      run = 0
      return Array.new(@w) do |x|
        # A step every few columns at most, so that the edges stay drawable
        run += 1
        if run >= 3 && @rng.rand(3) == 0
          step = [-1, 1].sample(random: @rng)
          step = slope if slope != 0 && relief.rand(100) < SLOPE_BIAS
          offset = (offset + step).clamp(-wave, wave)
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
          stairs[[x, y]] = [@place.stairs[(([here, 2].min - 1) * 2) + (south ? 0 : 1)], here, south]
        end
      end
      stairs = whole_stairs(stairs, faces, low)
      return nil if !stairs
      # The exits still reach one another, through the stairs
      seen = walk_levels(@exits[0][1, 2], faces, stairs)
      return nil if @exits.any? { |_side, x, y| !seen[y][x] }
      return faces, stairs
    end

    # Stairs as whole pairs (left half, right half, again for a wider
    # street), framed by their cliff on both sides: a run of an odd width
    # takes one more cell of the same face beside it, on the right, else on
    # the left; nil if no run fits.
    # cells: [x, y] => [pair, level, south face]. Returns [x, y] => symbol.
    def whole_stairs(cells, faces, low)
      stairs = {}
      cells.keys.group_by(&:last).each do |y, row|
        row.map(&:first).sort.slice_when { |a, b| b != a + 1 }.each do |run|
          pair, here, south = cells[[run[0], y]]
          # A cell of that face (its cliff on the same side)
          face = lambda do |x|
            inside?(x, y) && faces[y][x] && !cells.key?([x, y]) && low.call(x, y) == here &&
              (y + 1 < @h && low.call(x, y + 1) < here) == south && (y > 0 && low.call(x, y - 1) < here) != south
          end
          # The run, its cliff on both sides
          framed = ->(r) { face.call(r.first - 1) && face.call(r.last + 1) }
          options = [run]
          options = [run.last + 1, run.first - 1].select { |x| face.call(x) }.map { |x| (run + [x]).sort } if run.length.odd?
          run = options.find(&framed)
          return nil if !run
          run.each_with_index { |x, i| stairs[[x, y]] = pair[i % 2] }
        end
      end
      return stairs
    end

    # A raised band no longer runs from side to side: it stops short of a
    # side (SIDE_TRIM % of the time) between that side and its streets,
    # one level lower beyond, so that it stands as a mesa.
    def trim_sides(level, band, levels, relief = @rng)
      levels.each_index do |i|
        next if levels[i] == 0
        cells = (0...@h).flat_map { |y| (0...@w).select { |x| band[y][x] == i }.map { |x| [x, y] } }
        streets = cells.select { |x, y| @street[y][x] }.map(&:first)
        left, right = streets.empty? ? [@w / 2, @w / 2] : [streets.min - SIDE_GAP, streets.max + SIDE_GAP]
        cut_left = (@rng.rand(100) < SIDE_TRIM && left > 3) ? @rng.rand(2..left) : 0
        cut_right = (@rng.rand(100) < SIDE_TRIM && right < @w - 3) ? @rng.rand(right..@w - 2) : @w
        next if cut_right - cut_left < SIDE_GAP * 2
        # The cut wanders from row to row (SIDE_WAVE), never past the streets
        shift = side_wave(relief)
        cells.each do |x, y|
          lo = cut_left.zero? ? 0 : (cut_left + shift[y % shift.length]).clamp(1, left)
          hi = (cut_right == @w) ? @w : (cut_right - shift[(y + 7) % shift.length]).clamp(right, @w - 1)
          level[y][x] = levels[i] - 1 if x < lo || x >= hi
        end
      end
    end

    # Column offsets of a cut side, row after row: a step of one every few
    # rows, up to SIDE_WAVE, sloping one way more often than not.
    def side_wave(relief)
      slope = [-1, 1].sample(random: relief)
      offset = 0
      run = 0
      return Array.new(@h) do
        run += 1
        if run >= 2 && relief.rand(2) == 0
          offset = (offset + ((relief.rand(100) < SLOPE_BIAS) ? slope : -slope)).clamp(-SIDE_WAVE, SIDE_WAVE)
          run = 0
        end
        offset
      end
    end

    # Peaks: rough ovals one level above the ground around them, away from the
    # streets, the water and the exits (MOUNTAIN_PEAKS per CASE_SIZE square);
    # in a town, boxes (a raised garden, TERRACE_PEAKS).
    def raise_peaks(level, per_case = MOUNTAIN_PEAKS, rng = @rng, box = false)
      top = @place.levels.length
      count = (@w * @h * rng.rand(per_case) / (CASE_SIZE * CASE_SIZE).to_f).round
      keep = ->(x, y) { !inside?(x, y) || @border[y][x] || @street[y][x] || @water[y][x] || @solid[y][x] || exit_at?(x, y) }
      (count * 20).times do
        break if count == 0
        rx, ry = rng.rand(2.5..5.0), rng.rand(2.0..3.5)
        cx, cy = rng.rand(@w), rng.rand(@h)
        here = level[cy][cx]
        next if here >= top
        cells = (cy - 4..cy + 4).flat_map do |y|
          (cx - 6..cx + 6).select { |x| box ? ((x - cx).abs <= rx && (y - cy).abs <= ry) : ((((x - cx) / rx)**2) + (((y - cy) / ry)**2)) <= 1.0 }.map { |x| [x, y] }
        end
        # A box keeps off the cliffs around it by two
        margin = box ? (-2..2) : (-1..1)
        next if cells.any? do |x, y|
          margin.any? { |oy| margin.any? { |ox| keep.call(x + ox, y + oy) || level[y + oy][x + ox] != here } }
        end
        cells.each { |x, y| level[y][x] = here + 1 }
        count -= 1
      end
    end

    # Every bend of a level's edge at least 2 tiles long, like its stairs: a
    # cell of a level in no 2x2 square of that level or higher (a tooth, a
    # lone step) goes one level down, until none is left. false if that
    # makes more rows with two levels side by side (a cliff two levels
    # high).
    def thicken(level)
      at = ->(x, y) { inside?(x, y) ? level[y][x] : Float::INFINITY }
      steep = steep_cells(level)
      loop do
        thin = (0...@h).flat_map { |y| (0...@w).map { |x| [x, y] } }.select do |x, y|
          here = level[y][x]
          here > 0 && [[0, 0], [-1, 0], [0, -1], [-1, -1]].none? do |ox, oy|
            [[0, 0], [1, 0], [0, 1], [1, 1]].all? { |ax, ay| at.call(x + ox + ax, y + oy + ay) >= here }
          end
        end
        break if thin.empty?
        thin.each { |x, y| level[y][x] -= 1 }
      end
      return steep_cells(level) <= steep
    end

    # Number of rows with two levels side by side (a cliff two levels high).
    def steep_cells(level)
      return (0...@h).count do |y|
        (0...@w).any? { |x| NEIGHBOURS8.any? { |ox, oy| inside?(x + ox, y + oy) && (level[y + oy][x + ox] - level[y][x]).abs > 1 } }
      end
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
  end
end
