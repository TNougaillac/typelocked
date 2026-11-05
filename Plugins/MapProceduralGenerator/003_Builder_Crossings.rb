#===============================================================================
# MapProceduralGenerator - Place assembler (crossings), see 003_Builder.rb
# Crossings: what cuts a route from side to side (a channel, a lake, a sea
# route, a rock wall with its cave entrances) and the lock that closes a way.
#===============================================================================
module MapProceduralGenerator
  class PlaceBuilder
    private

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
      when "mer"
        error("« Eau » manquant pour traverser la mer") if !@place.water
        lay_sea_route(length)
      when "grotte"
        error("« Roche » et « Caillou » manquants pour traverser une grotte") if !@place.rock || !@place.pebble
        start = @rng.rand((length * 0.4).to_i..(length * 0.6).to_i - 3)
        wall_band(start, rock_size[vertical_route? ? 1 : 0])
        place_cave_entrances(start, rock_size[vertical_route? ? 1 : 0])
      else error("traversée « #{@place.crossing} » inconnue")
      end
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

    # A sea route: the sea from one beach to the other (SEA_ROUTE), its
    # shores wavering like a lake's, deep water where the player dives, then
    # ridges of rocks, lone rocks and sandbanks off the lane of its way.
    def lay_sea_route(length)
      rng = Random.new(@seed ^ SEA_ROUTE_SALT)
      bw, bh = border_size
      edge = vertical_route? ? bh : bw
      start = edge + rng.rand(SEA_ROUTE[:shore])
      thickness = length - edge - rng.rand(SEA_ROUTE[:shore]) - start
      error("route trop courte pour la mer") if thickness < 10
      # The way across, kept free of rocks
      lane = {}
      (0...@h).each do |y|
        (0...@w).each do |x|
          next if !@street[y][x]
          (-SEA_ROUTE[:lane]..SEA_ROUTE[:lane]).each { |o| lane[vertical_route? ? [x + o, y] : [x, y + o]] = true }
        end
      end
      flood_band(start, thickness, 1)
      deepen(start, thickness) if @place.dive
      cases = @w * @h / (CASE_SIZE * CASE_SIZE).to_f
      rock = @place.sea_rock || @place.reef
      if rock
        lay_ridges((cases * rng.rand(SEA_ROUTE[:ridges])).round, lane, rng, rock, true)
        lay_ridges((cases * rng.rand(SEA_ROUTE[:masses])).round, lane, rng, rock, false)
      end
      scatter_reefs(0..0, (cases * rng.rand(SEA_ROUTE[:rocks])).round.then { |n| n..n }, rng, lane)
      banks = scatter_reefs([(cases * rng.rand(SEA_ROUTE[:banks])).round, 1].max.then { |n| n..n }, 0..0, rng, lane)
      # Each sandbank is an islet with its loot, reached by surfing
      banks.each { |x, y, w, _h, _sym| @nooks.push([x + (w / 2), y, ISLET]) }
    end

    # Rocks on the sea, of 2x2 stamps one after the other, all on open sea
    # off the lane: ridges along the route, drifting sideways now and then,
    # or masses, the stamps wandering every way.
    def lay_ridges(count, lane, rng, sym, ridge)
      count.times do
        20.times.any? do
          x, y = rng.rand(@w), rng.rand(@h)
          stamps = []
          rng.rand(SEA_ROUTE[ridge ? :ridge : :mass]).times do
            stamps.push([x, y])
            if ridge
              step = rng.rand(1..2)
              drift = [-1, 0, 0, 1].sample(random: rng)
              x, y = vertical_route? ? [x + drift, y + step] : [x + step, y + drift]
            else
              x, y = stamps.sample(random: rng)
              x, y = [[x + 1, y], [x - 1, y], [x, y + 1], [x, y - 1]].sample(random: rng)
            end
          end
          next false if stamps.any? { |sx, sy| !open_sea?(sx, sy, 2, 2, 1) || near_lane?(lane, sx, sy, 2, 2) }
          stamps.each { |sx, sy| reef(sx, sy, 2, 2, sym) }
          true
        end
      end
    end

    # Whether that rectangle lies on the lane or within 1 of it.
    def near_lane?(lane, x, y, w, h)
      return (y - 1..y + h).any? { |cy| (x - 1..x + w).any? { |cx| lane[[cx, cy]] } }
    end

    # A wall of rocks across the whole map (border included), gaps filled with
    # border objects, then with pebbles.
    def wall_band(start, depth)
      across = vertical_route? ? @w : @h
      wall = {}
      depth.times { |a| across.times { |b| wall[band_cell(start + a, b)] = true } }
      fill_wall(wall)
    end

    # Rock on those cells ({[x, y] => true}): the rock objects where they fit,
    # pebbles in the gaps.
    def fill_wall(wall)
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

    #---------------------------------------------------------------------------
    # Shortcut locks (« Raccourcis » in a world)
    #---------------------------------------------------------------------------
    # [tiles from the edge of the lock's exit to its band, thickness of the
    # band]: past the border, water 4 tiles thick or rock as thick as its
    # objects.
    def lock_band
      bw, bh = border_size
      across = %w[nord sud].include?(@exits[@place.lock[1]][0])
      return [(across ? bh : bw) + 2, 4] if @place.lock[0] == "eau"
      rock = @place.rock && @palette.objects[@place.rock] ? rock_size : [2, 2]
      return [(across ? bh : bw) + 2, across ? rock[1] : rock[0]]
    end

    # A band across the leg of the locked exit, from border to border, that
    # only its obstacle opens: water to surf, or rock with a corridor one tile
    # wide on the street where the obstacle's event stands (a cut tree, a
    # cracked rock, a boulder pushed through the corridor), or with no gap
    # for the Grappling Hook. lock: [obstacle, x, y (its event), and for the
    # Grappling Hook x, y of the wall's other face].
    def close_lock
      obstacle, exit = @place.lock
      side, ex, ey = @exits[exit]
      start, thickness = lock_band
      dx, dy = INLAND[side]
      # Across the band: perpendicular to the way in
      ax, ay = dy.abs, dx.abs
      edge_x = (dx < 0) ? @w - 1 : ex
      edge_y = (dy < 0) ? @h - 1 : ey
      band = {}
      thickness.times do |t|
        d = start + t
        x0, y0 = (dx == 0) ? [ex, edge_y + (dy * d)] : [edge_x + (dx * d), ey]
        [-1, 1].each do |dir|
          x, y = x0, y0
          # Through the border too, which may leave gaps on a mask's squares;
          # water keeps the row under it (its bank) on the squares
          while covered?(x, y) && (obstacle != "eau" || !inside?(x, y + 1) || covered?(x, y + 1))
            band[[x, y]] = true
            x += ax * dir
            y += ay * dir
          end
        end
      end
      if obstacle == "eau"
        error("« Eau » manquant pour fermer un raccourci") if !@place.water
        band.each_key do |x, y|
          @cells[y][x] = @place.water
          @water[y][x] = @solid[y][x] = true
          @street[y][x] = @border[y][x] = false
        end
        first = band.keys.min_by { |x, y| ((x - ex).abs + (y - ey).abs) }
        @lock = [obstacle, *first]
        return
      end
      error("« Roche » et « Caillou » manquants pour fermer un raccourci") if !@place.rock || !@place.pebble
      # The corridor: on the street's first column (or row), through the band
      # (none for the Grappling Hook: its events stand on both faces)
      gap = (0...thickness).map do |t|
        d = start + t
        (dx == 0) ? [ex, edge_y + (dy * d)] : [edge_x + (dx * d), ey]
      end
      gap.each { |cell| band.delete(cell) } if obstacle != GRAPPLE
      fill_wall(band)
      # The event stands at the mouth of the corridor, on the exit's side
      @lock = [obstacle, *gap[0]]
      return if obstacle != GRAPPLE
      @lock.push(*gap[-1])
      @grapple = gap
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
  end
end
