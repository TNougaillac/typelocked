#===============================================================================
# MapProceduralGenerator - Place assembler (sea), see 003_Builder.rb
# Sea and port: the banks of the water, a port town's quay, piers and ferry
# terminal, an island's shore, the moored boat and the reefs.
#===============================================================================
module MapProceduralGenerator
  class PlaceBuilder
    private

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
      # On the ground (an islet's too) or a carpet of grass, and on a route's
      # trail where the water comes down to it
      under = [@place.ground, excess[:carpet]]
      under.push(@place.street) if @place.kind == "route"
      cells = bank_cells.select { |x, y| under.include?(rows[y][x]) }.to_h { |cell| [cell, true] }
      cells.each_key do |x, y|
        left, right = cells[[x - 1, y]], cells[[x + 1, y]]
        part = (left == right) ? 1 : (left ? 2 : 0)
        rows[y][x] = @place.banks[part]
      end
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
    # island or a port, or in the water crossing a route: off the shore, the
    # piers, the way across and one another. Returns the [x, y, w, h, symbol]
    # placed.
    def scatter_reefs(banks, reefs, rng, lane = nil)
      placed = []
      # The rock autotile draws nothing on a lone cell: 2x2 at least, as on
      # the hand-made maps
      [[@place.bank, banks, [2, 4], [2, 3]], [@place.reef, reefs, [2, 3], [2, 2]]].each do |sym, count, ws, hs|
        next if !sym
        rng.rand(count).times do
          w, h = rng.rand(ws[0]..ws[1]), rng.rand(hs[0]..hs[1])
          spots = (0..@h - h).flat_map { |y| (0..@w - w).map { |x| [x, y] } }
          spot = spots.shuffle(random: rng).find do |x, y|
            open_sea?(x, y, w, h, 2) && !(lane && near_lane?(lane, x, y, w, h)) && (y - 3...y + h + 3).none? do |cy|
              (x - 3...x + w + 3).any? { |cx| inside?(cx, cy) && @street[cy][cx] }
            end
          end
          break if !spot
          reef(*spot, w, h, sym)
          placed.push([*spot, w, h, sym])
        end
      end
      return placed
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
  end
end
