#===============================================================================
# MapProceduralGenerator - Place assembler (streets), see 003_Builder.rb
# Streets and plans: the exits, the streets to the hub, the town's plan (grid,
# plaza, canal), the dead ends, the stretch of sand, and the paths a brick's
# door takes to its street.
#===============================================================================
module MapProceduralGenerator
  class PlaceBuilder
    private

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
    # east-west mountain route, so that the street climbs at the hub; at the
    # end that keeps it on the squares of a mask).
    # wide: one tile wider (an avenue), but not near the map's edges, so that
    # the exit keeps its width.
    def carve_line(x0, y0, x1, y1, wide = false)
      far_bend = @rng.rand(2) == 0
      return carve_trail(x0, y0, x1, y1) if trail?
      far_bend = true if @place.mountain && !vertical_route?
      far_bend = !far_bend if @mask && !line_covered?(x0, y0, x1, y1, far_bend)
      line_steps(x0, y0, x1, y1, far_bend).each do |x, y|
        paint(x, y)
        next if !wide || [x, y, @w - x, @h - y].min <= AVENUE_MARGIN
        paint(x + 1, y + 1)
      end
    end

    # The streets of a plain route wind (TRAIL): not on a mountain route, with
    # a mask, a lock or a crossing, whose streets must stay straight.
    def trail?
      return @place.kind == "route" && !@mask && !@place.mountain && !@place.lock && !@place.crossing && !@place.island
    end

    # A winding street: along the longer way, drifting one tile sideways now
    # and then (TRAIL), never more than half the steps from either end nor
    # into the border, so that it leaves and reaches its ends straight. Its
    # own draws (TRAIL_SALT), so the rest of the route stays the same.
    def carve_trail(x0, y0, x1, y1)
      @trail_rng ||= Random.new(@seed ^ TRAIL_SALT)
      across = (x1 - x0).abs < (y1 - y0).abs   # the trail runs down the map
      length = across ? (y1 - y0).abs : (x1 - x0).abs
      step = across ? (y1 <=> y0) : (x1 <=> x0)
      drift = 0
      wait = @trail_rng.rand(TRAIL[:every])
      last = nil
      (0..length).each do |i|
        t = (length == 0) ? 1.0 : i / length.to_f
        main = (across ? y0 : x0) + (i * step)
        line = ((across ? x0 : y0) + (((across ? x1 : y1) - (across ? x0 : y0)) * t)).round
        if (wait -= 1) <= 0
          drift += @trail_rng.rand(-1..1)
          wait = @trail_rng.rand(TRAIL[:every])
        end
        limit = [TRAIL[:sway], i / 2, (length - i) / 2].min
        drift = drift.clamp(-limit, limit)
        side = line + drift
        x, y = across ? [side, main] : [main, side]
        # Back towards the line where the border is in the way
        while drift != 0 && !brush_clear?(x, y)
          drift -= (drift <=> 0)
          side = line + drift
          x, y = across ? [side, main] : [main, side]
        end
        # Sideways steps join up with the step before
        if last
          lx, ly = last
          line_steps(lx, ly, x, y, false).each { |px, py| paint(px, py) }
        end
        paint(x, y)
        last = [x, y]
      end
    end

    # True if a brush at x, y stays inside the map and off the border.
    def brush_clear?(x, y)
      return (0...STREET_WIDTH).all? do |oy|
        (0...STREET_WIDTH).all? { |ox| inside?(x + ox, y + oy) && !@border[y + oy][x + ox] }
      end
    end

    # Brush steps of an L-shaped street, bending at the far end or not.
    def line_steps(x0, y0, x1, y1, far_bend)
      xs = (x0 < x1 ? x0.upto(x1) : x0.downto(x1)).to_a
      ys = (y0 < y1 ? y0.upto(y1) : y0.downto(y1)).to_a
      return xs.map { |x| [x, y0] } + ys.map { |y| [x1, y] } if far_bend
      return ys.map { |y| [x0, y] } + xs.map { |x| [x, y1] }
    end

    # True if that street stays on the squares the mask covers.
    def line_covered?(x0, y0, x1, y1, far_bend)
      return line_steps(x0, y0, x1, y1, far_bend).all? do |x, y|
        (0...STREET_WIDTH).all? { |oy| (0...STREET_WIDTH).all? { |ox| covered?(x + ox, y + oy) } }
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
      # A shortcut's lock: the street first goes straight in across its band
      if @place.lock && @place.lock[1] == @exits.length - 1
        dx, dy = INLAND[side]
        reach = lock_band[0] + lock_band[1] + STREET_WIDTH
        line_steps(x, y, x + (dx * reach), y + (dy * reach), true).each { |cx, cy| paint(cx, cy) }
        x, y = x + (dx * reach), y + (dy * reach)
      end
      # With a mask, to the closest joint the street can reach on its squares
      if @mask
        hub = @hubs.sort_by { |hx, hy| (hx - x).abs + (hy - y).abs }.find do |hx, hy|
          line_covered?(x, y, hx, hy, true) || line_covered?(x, y, hx, hy, false)
        end || hub
      end
      # In a town, the streets of the first two exits make its avenue
      avenue = @place.kind == "ville" && !@mask && !@place.port && !@place.island && @exits.length <= 2
      carve_line(x, y, hub[0], hub[1], avenue)
    end

    # Where the monument of a town goes: by the square (within MONUMENT_REACH
    # tiles of it) when the town has one; nil = anywhere.
    def monument_spot
      return nil if !@plaza
      x0, y0, x1, y1 = @plaza
      return lambda do |brick, x, y|
        w, h = brick.rows.map(&:length).max, brick.rows.length
        x + w > x0 - MONUMENT_REACH && x < x1 + MONUMENT_REACH && y + h > y0 - MONUMENT_REACH && y < y1 + MONUMENT_REACH
      end
    end

    # A stretch of another ground across a long plain route (TRANSITION),
    # like the desert in the middle of Hoenn's Route 111: its edges waver,
    # the trail crosses it on that ground, no brick goes there, only a few
    # rocks away from the trail. Its own draws (TRANSITION_SALT).
    def lay_transition
      return if @plain || !trail? || @place.excess || !TRANSITION[:ambiances].include?(@place.ambiance)
      return if !@palette.legend[TRANSITION[:ground]] || !@palette.legend[TRANSITION[:rock]]
      rng = Random.new(@seed ^ TRANSITION_SALT)
      return if rng.rand(100) >= TRANSITION[:chance]
      down = @h >= @w
      length, across = down ? [@h, @w] : [@w, @h]
      return if length < TRANSITION[:min_length]
      size = rng.rand(TRANSITION[:size])
      start = rng.rand((length * 0.3).to_i..[(length * 0.3).to_i, (length * 0.7).to_i - size].max)
      @zone = Array.new(@h) { Array.new(@w, false) }
      top, bottom = start, start + size
      across.times do |b|
        top = (top + rng.rand(-1..1)).clamp(start - 5, start + 5)
        bottom = (bottom + rng.rand(-1..1)).clamp(start + size - 5, start + size + 5)
        (top...bottom).each do |a|
          x, y = down ? [b, a] : [a, b]
          @zone[y][x] = true if !@border[y][x] && !@water[y][x] && !@solid[y][x]
        end
      end
      # Rocks, one tile each, two tiles off the trail and from each other
      cells = (0...@h).to_a.product((0...@w).to_a).select do |y, x|
        @zone[y][x] && !near?(x, y, 2) { |nx, ny| @street[ny][nx] || @border[ny][nx] }
      end
      (cells.length * TRANSITION[:rocks] / 100.0).round.times do
        y, x = cells.sample(random: rng)
        next if near?(x, y, 2) { |nx, ny| @cells[ny][nx] == TRANSITION[:rock] }
        @cells[y][x] = TRANSITION[:rock]
        @solid[y][x] = true
      end
    end

    # The plan of a town (TOWN_PLANS, by weight; its own draws, PLAN_SALT):
    # « carrefour » (streets from the exits to a square), « grille » (a grid
    # of streets as well), « canal » (a canal from north to south, crossed
    # by bridges) or « clairière » (no square, trees everywhere). Only in
    # towns big enough for a square, not in a port, on an island or with a
    # mask; nil for the others. A town whose bricks don't fit its plan is
    # built again as a « carrefour » (generate_place).
    def choose_plan
      @plan = nil
      return if @place.kind != "ville" || @place.port || @place.island || @mask || [@w, @h].min < PLAZA[:min_side]
      rng = Random.new(@seed ^ PLAN_SALT)
      roll = rng.rand(TOWN_PLANS.values.sum { |plan| plan[:weight] })
      @plan = TOWN_PLANS.find { |_name, plan| (roll -= plan[:weight]) < 0 }[0]
      # An excess draws among its own plans, the next one if a canal can't be
      # laid
      plans = excess[:plans]
      @plan = plans[rng.rand(plans.length)] if plans
      @plan = @place.plan if @place.plan
      @plan = "carrefour" if @plain
      @plan = (plans && plans.find { |p| p != "canal" }) || "carrefour" if @plan == "canal" && !canal?
    end

    # Whether the place can have a canal (water, its wooden bridges and their lips)
    def canal?
      return @place.water && @place.pier && @place.lips
    end

    # A grid of straight streets (GRID: tiles between two streets), each
    # running between the border's trees, so that the blocks hold one or
    # two buildings each.
    def lay_grid
      rng = Random.new(@seed ^ PLAN_SALT ^ 1)
      sx, sy = rng.rand(GRID[:across]), rng.rand(GRID[:down])
      (rng.rand(sx)...@w).step(sx) { |x| @h.times { |y| paint(x, y) if brush_clear?(x, y) && grid_free?(x, y) } }
      (rng.rand(sy)...@h).step(sy) { |y| @w.times { |x| paint(x, y) if brush_clear?(x, y) && grid_free?(x, y) } }
    end

    # The brush at x, y lies on free ground or streets only.
    def grid_free?(x, y)
      return (0...STREET_WIDTH).all? { |oy| (0...STREET_WIDTH).all? { |ox| !@solid[y + oy][x + ox] || @street[y + oy][x + ox] } }
    end

    # A canal (CANAL wide) from the northern to the southern edge, 2 tiles
    # off the square and away from the exits of those sides; the streets that cross it
    # become wooden bridges (« Ponton », with their « Rebord » lips).
    def lay_canal(hub)
      rng = Random.new(@seed ^ PLAN_SALT ^ 2)
      width = rng.rand(excess[:river] || CANAL[:width])
      left, right = @plaza ? [@plaza[0], @plaza[2]] : [hub[0], hub[0] + STREET_WIDTH]
      ends = @exits.select { |side, *| %w[nord sud].include?(side) }.map { |_side, x, _y| x }
      spots = ((@w * 0.15).to_i..(@w * 0.85).to_i - width).select do |x0|
        (x0 + width + 2 <= left || x0 >= right + 2) &&
          ends.none? { |ex| ex + STREET_WIDTH + 2 > x0 && ex < x0 + width + 2 }
      end
      return if spots.empty?
      x0 = spots.sample(random: rng)
      @h.times do |y|
        # With a grid, only the streets right across become bridges (not a
        # grid's street from north to south, cut by the canal)
        across = !excess[:grid] || (x0...x0 + width).all? { |x| @street[y][x] }
        (x0...x0 + width).each do |x|
          if @street[y][x] && across
            @cells[y][x] = @place.pier
          else
            @cells[y][x] = @place.water
            @water[y][x] = @solid[y][x] = true
          end
          @border[y][x] = false
        end
      end
      lay_pier_lips
    end

    # A paved square around the hub of a town (PLAZA), its fountain in the
    # middle with the street all around; none in a village, a port, on an
    # island or with a mask, nor where the square would not be free ground.
    def lay_plaza(hub)
      return if @place.kind != "ville" || @place.port || @place.island || @mask
      return if !@palette.objects[PLAZA[:fountain]] || [@w, @h].min < PLAZA[:min_side]
      rng = Random.new(@seed ^ PLAZA_SALT)
      pw, ph = rng.rand(PLAZA[:width]), rng.rand(PLAZA[:height])
      x0 = hub[0] + (STREET_WIDTH / 2) - (pw / 2)
      y0 = hub[1] + (STREET_WIDTH / 2) - (ph / 2)
      cells = (y0...y0 + ph).to_a.product((x0...x0 + pw).to_a)
      return if cells.any? { |y, x| !inside?(x, y) || (@solid[y][x] && !@street[y][x]) }
      cells.each { |y, x| @street[y][x] = true }
      @plaza = [x0, y0, x0 + pw, y0 + ph]
      fountain = @palette.objects[PLAZA[:fountain]]
      fx, fy = x0 + ((pw - fountain.width) / 2), y0 + ((ph - fountain.height) / 2)
      rows = Array.new(fountain.height) { PLAZA[:fountain] * fountain.width }
      fountain.height.times { |dy| fountain.width.times { |dx| @street[fy + dy][fx + dx] = false } }
      stamp(Brick.new(PLAZA_KIND, "Fontaine", PLAZA_KIND, nil, 1, false, rows), fx, fy)
    end

    # Dead end from the square towards a random point of the inner area (in a
    # port town, a point inland of the promenade, else no dead end).
    def carve_spur(hub)
      bw, bh = border_size
      bw = bh = ISLAND_SHORE.max + 2 if @place.island
      inland = ->(x, y) { !@port_depth || port_depth_at(x, y) >= @port_depth + STREET_WIDTH }
      # With a mask, the street must stay on its squares
      covered = ->(x, y) { !@mask || line_covered?(hub[0], hub[1], x, y, true) || line_covered?(hub[0], hub[1], x, y, false) }
      x, y = nil
      10.times do
        x = @rng.rand(bw + 2..@w - bw - 2 - STREET_WIDTH)
        y = @rng.rand(bh + 2..@h - bh - 2 - STREET_WIDTH)
        break if inland.call(x, y) && covered.call(x, y)
      end
      return if !inland.call(x, y) || !covered.call(x, y)
      carve_line(hub[0], hub[1], x, y)
      @dead_ends.push([x, y])
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

    # Brush steps from every street cell outward: distances[y][x] (nil = no
    # path), parents for carve_path.
    def street_distances
      @parents = Array.new(@h) { Array.new(@w) }
      distances = Array.new(@h) { Array.new(@w) }
      free = Array.new(@h) { |y| Array.new(@w) { |x| brush_free?(x, y) } }
      queue = []
      @h.times do |y|
        @w.times do |x|
          next if !free[y][x] || !brush_on_street?(x, y)
          distances[y][x] = 0
          queue.push([x, y])
        end
      end
      head = 0
      while head < queue.length
        x, y = queue[head]
        head += 1
        NEIGHBOURS.each do |ox, oy|
          nx, ny = x + ox, y + oy
          next if nx < 0 || ny < 0 || nx >= @w || ny >= @h || !free[ny][nx] || distances[ny][nx]
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
  end
end
