#===============================================================================
# MapProceduralGenerator - Place assembler (bricks), see 003_Builder.rb
# Bricks: the buildings and decoration laid on the place (required ones
# first), the nooks and islets, the lakes and hills, and the checks of where a
# brick fits.
#===============================================================================
module MapProceduralGenerator
  class PlaceBuilder
    private

    def place_bricks
      required = []
      optional = []
      # The squares of a mask only; the beaches of a sea route only
      area = (@mask ? @mask.join.count("1") * @cell * @cell : @w * @h) / (CASE_SIZE * CASE_SIZE).to_f
      area = @water.sum { |row| row.count(false) } / (CASE_SIZE * CASE_SIZE).to_f if @place.crossing == "mer"
      @area = area
      @place.counts.each do |kind, range|
        # Along the quay only (place_port_bricks)
        next if QUAY_HQS.include?(kind)
        range = (range.min * area).round..(range.max * area).round if @place.per_case.include?(kind)
        count = (LAST_KINDS.include?(kind) ? @extra_rng : @rng).rand(range)
        boost = excess[:boost]&.[](kind)
        boost = [boost || 0, TOWN_PLANS.dig(@plan, :boost, kind) || 0].max
        count = [count, range.max * boost].max if boost > 0
        count = range.min if excess[:trim]&.include?(kind)
        range.min.times { required.push(kind) }
        (count - range.min).times { optional.push(kind) }
      end
      # Buildings before decoration, so decoration never blocks a door
      with_door = ->(kind) { @bricks.any? { |b| b.kind == kind && b.door } ? 0 : 1 }
      # The bricks an excess boosts go first among the optional ones
      boosted = ->(kind) { excess[:boost]&.key?(kind) ? 0 : 1 }
      # Required decoration after the other required bricks, so it never
      # takes the room of a meadow or a building
      # The optional bricks of LAST_KINDS after all the others, so that they
      # never take the room of a park or its grass
      last, optional = optional.partition { |k| LAST_KINDS.include?(k) }
      # The optional bricks of EARLY_KINDS (the unique buildings, big)
      # right after the required buildings but the houses, while there is
      # room; left out when they don't fit
      early, optional = optional.partition { |k| EARLY_KINDS.include?(k) }
      # A headquarters with no room on the quay among the required buildings,
      # before the houses take its room
      required = required.shuffle(random: @rng).sort_by { |k| [with_door.call(k), (k == "maison") ? 1 : 0, (k == DECOR) ? 1 : 0] }
      required.insert(required.count { |k| with_door.call(k) == 0 && k != "maison" }, *@inland_hqs)
      houses_at = required.count { |k| with_door.call(k) == 0 && k != "maison" }
      required.insert(houses_at, *early)
      early_at = houses_at...(houses_at + early.length)
      optional_at = ->(i) { i >= required.length || early_at.cover?(i) }
      order = required +
              optional.shuffle(random: @rng).sort_by { |k| [with_door.call(k), boosted.call(k)] } +
              last.shuffle(random: @extra_rng)
      # With « dense », the fill bricks may touch each other (not the others)
      @dense = excess[:fill] if excess[:dense]
      order.each_with_index do |kind, i|
        flood_ground if i == required.length
        # The nook right after the buildings, before the decoration
        place_nook if with_door.call(kind) == 1
        next if HIGHLAND.include?(kind) && !@level
        next if kind == HILL && @place.kind == "ville" && @rng.rand(100) >= HILL_TOWN_CHANCE
        next if @left_out.include?(kind)
        # A headquarters with no room on the quay is laid inland, or the
        # place is laid out again (generate_place)
        next if QUAY_HQS.include?(kind) && place_smallest(kind)
        error("impossible de placer le QG « #{kind} » hors du quai") if QUAY_HQS.include?(kind)
        # « pack »: the boosted bricks, the big ones first
        next place_big(kind) if optional_at.call(i) && excess[:pack] && boosted.call(kind) == 0
        next if place_brick(kind, kind == MONUMENT ? monument_spot : nil)
        # The rocks on a route's mesas go where they fit, or not at all
        next if HIGHLAND.include?(kind) && @mesas
        # A patch of grass drawn big shrinks until it fits
        next if GRASS_SHAPE.key?(kind) && (1..3).any? { |shrink| place_brick(kind, nil, shrink) }
        # A giant lake shrinks until it fits
        next if kind == LAKE && excess[:giant_lake] && (1..3).any? { |shrink| place_brick(kind, nil, shrink) }
        # A mountain route keeps little ground: what doesn't fit is left out;
        # so does a sea route, and a port town for its decoration
        next if (@level && @place.mountain) || @place.crossing == "mer" || (@port_depth && with_door.call(kind) == 1)
        # The monument goes where it can, or not at all
        if kind == MONUMENT
          place_brick(kind)
          next
        end
        next if optional_at.call(i) || place_smallest(kind)
        # A required brick under the leaves of the border rather than none
        # (the border keeps its ground there, see plant_border)
        @loose_canopy = true
        placed = place_brick(kind) || place_smallest(kind)
        @loose_canopy = false
        next if placed
        error("impossible de placer une brique « #{kind} » ; agrandis « Taille » ou réduis [Briques]")
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
      @nook = nook_kind
      case @nook
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
        @nooks.push([spot[0] + loot[0], spot[1] + loot[1], @nook])
      when "sombre"
        cave = @bricks.select { |b| b.kind == CAVE }.min_by(&:name) || return
        brick = Brick.new(DARK_CAVE, "Grotte sombre", DARK_CAVE, cave.door, 1, false, cave.rows, nil, nil, cave.door_side)
        spot = put_brick(brick) || return
        @nooks.push([spot[0] + brick.door[0], spot[1] + brick.door[1], @nook])
      else
        brick, loot = nook_brick
        spot = put_brick(brick) || return
        ox, oy = spot[0] + brick.door[0], spot[1] + brick.door[1]
        @nooks.push([spot[0] + loot[0], spot[1] + loot[1], @nook, ox, oy])
        # The Grappling Hook's wall, the ice: from the mouth to the inner face
        @nooks[-1].push(ox, oy - 1) if @nook == GRAPPLE || CROSSINGS[@nook]
      end
    end

    # The obstacle of the nook: in a place of their ambiance, some become a
    # crossing (CROSSINGS: ice, mud, a wall to climb, a cycle path).
    def nook_kind
      return @place.nook if !CROSSING_FROM.include?(@place.nook)
      kinds = CROSSINGS.select do |_kind, c|
        (!c[:ambiances] || c[:ambiances].include?(@place.ambiance)) && c[:kinds].include?(@place.kind)
      end.keys
      return @place.nook if kinds.empty?
      kind = kinds[@rng.rand(kinds.length)]
      return (@rng.rand(100) < CROSSINGS[kind][:chance]) ? kind : @place.nook
    end

    # A pocket of ground at the back of a block of rock, reached by a corridor
    # one tile wide from the south: the obstacle stands at its mouth (the
    # door, so a path leads to it). Three tiles wide, so that a pushed boulder
    # can be walked around. For the Grappling Hook, the corridor is rock too;
    # for a crossing, its symbol (3 tiles wide for a wide one).
    # Returns the brick and the loot cell (a back corner).
    def nook_brick
      rock = "^"
      ground = @place.ground
      depth = @rng.rand(2..3)
      rows = [" #{rock * 5} ", rock * 7]
      depth.times { rows.push("#{rock * 2}#{ground * 3}#{rock * 2}") }
      crossing = CROSSINGS[@nook]
      corridor = (crossing && ((crossing[:corridor] == :street) ? @place.street : crossing[:corridor])) ||
                 ((@nook == GRAPPLE) ? rock : ground)
      2.times { rows.push(crossing&.[](:wide) ? "#{rock * 2}#{corridor * 3}#{rock * 2}" : "#{rock * 3}#{corridor}#{rock * 3}") }
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
      starts = @exits.map { |_side, x, y| [x, y] } + @doors.map { |x, y, brick| door_front(x, y, brick) }
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
      mark_halo(brick, x, y, -1)
    end

    # Ground on the lowest level that nothing uses yet.
    def free_ground?(x, y)
      return false if level_at(x, y) > 0 || @zone&.[](y)&.[](x)
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
    # Lakes (« lac » in [Briques])
    #---------------------------------------------------------------------------
    # A brick of water made for this spot of the map: one to three rough
    # ovals (LAKE_SHAPE), each new one centred on the rim of one before it,
    # so that the lake stays in one piece; its empty rows and columns cut.
    # A giant lake (excess) that doesn't fit is retried smaller (shrink).
    def lake_brick(shrink = 0)
      w, h = @rng.rand(LAKE_SHAPE[:width]), @rng.rand(LAKE_SHAPE[:height])
      first = @rng.rand(LAKE_SHAPE[:first])
      if excess[:giant_lake]
        bw, bh = border_size
        w = @rng.rand(12..[12, @w - (2 * bw) - 4].max.clamp(12, 22)) * (5 - shrink) / 5
        h = @rng.rand(9..[9, @h - (2 * bh) - 4].max.clamp(9, 16)) * (5 - shrink) / 5
        first = 0.5
      end
      rows = blob_rows(w, h, first, LAKE_SHAPE, @place.water)
      return Brick.new(LAKE, "Lac", LAKE, nil, 1, false, rows)
    end

    # A blob of that symbol in a box of w by h: overlapping ovals (shape:
    # their count, the share of the box of each one after the first), the
    # first one first of the box; its empty rows and columns cut.
    def blob_rows(w, h, first, shape, symbol)
      ovals = [[w / 2.0, h / 2.0, w * first, h * first]]
      (@rng.rand(shape[:ovals]) - 1).times do
        cx, cy, rx, ry = ovals[@rng.rand(ovals.length)]
        angle = @rng.rand * 2 * Math::PI
        ovals.push([cx + (rx * Math.cos(angle)), cy + (ry * Math.sin(angle)),
                    w * @rng.rand(shape[:more]), h * @rng.rand(shape[:more])])
      end
      rows = Array.new(h) do |y|
        Array.new(w) do |x|
          inside = ovals.any? { |cx, cy, rx, ry| (((x + 0.5 - cx) / rx)**2) + (((y + 0.5 - cy) / ry)**2) <= 1.0 + (@rng.rand * 0.25) }
          inside ? symbol : " "
        end.join
      end
      rows.reject! { |row| row.strip.empty? }
      left = rows.map { |row| row.index(/\S/) }.min
      right = rows.map { |row| row.rindex(/\S/) }.max
      return rows.map { |row| row[left..right] }
    end

    # A patch of grass drawn for its spot (GRASS_SHAPE), of the main symbol
    # of the brick drawn from the files (tall grass, very tall grass and its
    # foot, marsh grass), much bigger and rounder than those; drawn big, a
    # quarter smaller each time it doesn't fit (shrink).
    def grass_brick(drawn, shrink = 0)
      symbol = drawn.rows.join.delete(" ").chars.tally.max_by(&:last)[0]
      shape = GRASS_SHAPE[drawn.kind]
      w = [@rng.rand(shape[:width]) * (4 - shrink) / 4, 3].max
      h = [@rng.rand(shape[:height]) * (4 - shrink) / 4, 2].max
      rows = blob_rows(w, h, @rng.rand(shape[:first]), shape, symbol)
      # The foot of very tall grass (the bottom row of its brick) under each
      # of its columns
      foot = drawn.rows.last.delete(" ").chars.uniq
      if foot.length == 1 && foot[0] != symbol
        rows.push(" " * rows[0].length)
        (rows.length - 1).downto(1) do |y|
          rows[0].length.times { |x| rows[y][x] = foot[0] if rows[y][x] == " " && rows[y - 1][x] == symbol }
        end
      end
      return Brick.new(drawn.file, drawn.name, drawn.kind, nil, 1, false, rows, drawn.ambiances)
    end

    # A ridge drawn for its spot (RIDGE_SHAPE): a massif (bowl_blocks), with
    # a stair up its south face when one fits there (its door).
    def ridge_brick
      rock = @place.levels&.first || "^"
      stair = @place.stairs&.first || "eɛ"
      blocks = bowl_blocks(@rng.rand(RIDGE_SHAPE[:width]), @rng.rand(RIDGE_SHAPE[:height]), @rng)
      rows = (0...blocks.length * 2).map { |y| (0...blocks[0].length * 2).map { |x| blocks[y / 2][x / 2] ? rock : " " }.join }
      # The stair: a block of the bottom row framed by a block on each side
      last = blocks.length - 1
      doors = (1...blocks[0].length - 1).select { |bx| blocks[last][bx - 1] && blocks[last][bx] && blocks[last][bx + 1] }
      door = nil
      if !doors.empty?
        bx = doors.sample(random: @rng)
        2.times { |k| rows[-1][(bx * 2) + k] = stair[k] }
        door = [bx * 2, rows.length - 1]
      end
      return Brick.new(RIDGE, "Crête", "montagne", door, 1, false, rows)
    end

    # A massif drawn as a map designer would, on a grid of 2x2 blocks (each
    # bend of its cliff at least 2 tiles long): its rows narrow, each side on
    # its own, more and more often towards the foot (BOWL_BEND), so that it
    # ends rounded; never towards the top (a row wider than the one above it
    # would make an inner corner facing north, which no tile draws); at
    # least 3 blocks wide at the foot for a framed stair. Rows of booleans,
    # cw blocks wide, ch high.
    def bowl_blocks(cw, ch, rng, foot = 3)
      cw = [cw, foot].max
      return bowl_sides(cw, ch, rng, BOWL_BEND, foot).map do |left, right|
        Array.new(cw) { |bx| bx.between?(left, right) }
      end
    end

    # The sides [left, right] of each row of a massif, row after row, each
    # narrowing by a block that often (bend, % from the first row to the
    # last), never below min blocks.
    def bowl_sides(cw, ch, rng, bend, min)
      left, right = 0, cw - 1
      return Array.new(ch) do |by|
        sides = [left, right]
        chance = bend.first + ((bend.last - bend.first) * by / [ch - 1, 1].max)
        left += 1 if rng.rand(100) < chance && right - left + 1 > min
        right -= 1 if rng.rand(100) < chance && right - left + 1 > min
        sides
      end
    end

    # A hill: a small massif made for this spot (bowl_blocks), with a stair (2 tiles: left, right) in the middle of its
    # south face (its door, so a path leads to it), framed by one block of
    # cliff on each side.
    def hill_brick
      rock = @place.levels&.first || "^"
      stair = @place.stairs&.first || "eɛ"
      blocks = bowl_blocks(@rng.rand(3..5), @rng.rand(2..3), @rng)
      foot = blocks.last
      door = (foot.index(true) + foot.rindex(true)) / 2
      cw, ch = foot.length, blocks.length
      rows = (0...ch * 2).map { |y| (0...cw * 2).map { |x| blocks[y / 2][x / 2] ? rock : " " }.join }
      2.times { |k| rows[-1][(door * 2) + k] = stair[k] }
      return Brick.new(HILL, "Colline", HILL, [door * 2, (ch * 2) - 1], 1, false, rows)
    end

    # The tiles around a hill (8 neighbours) but those below its stair: no
    # street may run there (the levels join the streets: its cliff would
    # open beside the stair), [dx, dy] from its top left corner.
    def hill_ring(brick)
      cells = brick_cells(brick)
      below = brick.door ? [[brick.door[0], brick.door[1] + 1], [brick.door[0] + 1, brick.door[1] + 1]] : []
      return cells.flat_map { |cx, cy| NEIGHBOURS8.map { |ox, oy| [cx + ox, cy + oy] } }.uniq - cells - below
    end

    # A hill or a ridge drawn for its spot: its cliff joins a path beside it
    # (no cliff drawn there), so none may run along it (hill_ring).
    def ringed?(brick)
      return brick.kind == HILL || brick.file == RIDGE
    end

    # What tops a hill: on a route, mostly tall grass (HILL_GRASS_CHANCE, all
    # of its top off the cliff), else a loot (hill_tops in the inventory).
    def crown_hill(brick, x, y)
      if @place.kind == "route" && @place.high_grass && @rng.rand(100) < HILL_GRASS_CHANCE
        hill_inside(brick).each do |dx, dy|
          @cells[y + dy][x + dx] = @place.high_grass
          @kinds[y + dy][x + dx] = "herbes"
        end
        return
      end
      top = hill_top(brick)
      @hill_tops.push([x + top[0], y + top[1]]) if top
    end

    # The cells of a hill off its cliff (all 8 neighbours are the hill).
    def hill_inside(brick)
      cells = brick_cells(brick)
      return cells.select { |cx, cy| NEIGHBOURS8.all? { |ox, oy| cells.include?([cx + ox, cy + oy]) } }
    end

    # The cell on top of a hill for its loot: off its cliff (all 8 neighbours
    # are the hill), on its top row, nearest the middle; nil if none.
    def hill_top(brick)
      middle = (brick.rows[0].length - 1) / 2.0
      return hill_inside(brick).min_by { |cx, cy| [cy, (cx - middle).abs, cx] }
    end

    def pick_brick(kind, shrink = 0)
      return lake_brick(shrink) if kind == LAKE
      return hill_brick if kind == HILL
      ridge = (kind == "montagne" && @rng.rand(100) < RIDGE_SHAPE[:chance]) ? ridge_brick : nil
      return ridge if ridge
      bricks = MODELS.key?(kind) ? models(kind) : @bricks.select { |b| b.kind == kind }
      roll = @rng.rand(bricks.sum(&:weight))
      drawn = bricks.find { |b| (roll -= b.weight) < 0 }
      return grass_brick(drawn, shrink) if drawn && GRASS_SHAPE.key?(kind) && @rng.rand(100) < GRASS_SHAPE[kind][:chance]
      return drawn
    end

    # The few models of buildings of that type the place draws from (MODELS),
    # more in a bigger place: the same houses again and a few others. The
    # first one drawn comes back more often (twice its weight).
    def models(kind)
      @models ||= {}
      return @models[kind] ||= begin
        pool = @bricks.select { |b| b.kind == kind }
        base, per_case = MODELS[kind]
        count = (base + (per_case * [(@area || 1) - 1, 0].max)).round
        chosen = []
        while chosen.length < count && !pool.empty?
          roll = @extra_rng.rand(pool.sum(&:weight))
          brick = pool.find { |b| (roll -= b.weight) < 0 }
          chosen.push(brick)
          pool.delete(brick)
        end
        chosen.empty? ? chosen : [chosen[0]] + chosen
      end
    end

    # Puts one brick of that type where it fits (and where allowed says so);
    # returns false if none does.
    def place_brick(kind, allowed = nil, shrink = 0)
      return put_brick(pick_brick(kind, shrink), allowed)
    end

    # A required brick whose drawn brick didn't fit: any brick of that type,
    # smallest first.
    def place_smallest(kind)
      return false if [LAKE, HILL].include?(kind)
      bricks = @bricks.select { |b| b.kind == kind }
      return bricks.sort_by { |b| [b.rows.sum { |r| r.delete(" ").length }, b.name] }.any? { |b| put_brick(b) }
    end

    # Excess « pack »: the bricks of that type tried from the biggest (give or
    # take PACK_JITTER), those not laid yet first, until one fits.
    def place_big(kind)
      @laid ||= Hash.new(0)
      bricks = @bricks.select { |b| b.kind == kind }.sort_by do |b|
        size = b.rows.sum { |r| r.delete(" ").length }
        [@laid[b.name], -size * (1 + (@rng.rand * PACK_JITTER)), b.name]
      end
      brick = bricks.find { |b| put_brick(b) }
      @laid[brick.name] += 1 if brick
      return !brick.nil?
    end

    # A town's house stands on a plot that often (PLOT_CHANCE), where one
    # has room (plot_room?), else as usual.
    def put_brick(brick, allowed = nil)
      if brick.door && !brick.door_side && plots? && @rng.rand(100) < PLOT_CHANCE
        spot = lay_brick(brick, ->(b, x, y) { (!allowed || allowed.call(b, x, y)) && plot_room?(b, x, y) }, true)
        return spot if spot
      end
      return lay_brick(brick, allowed)
    end

    def lay_brick(brick, allowed = nil, plot = false)
      bw, bh = brick.rows.map(&:length).max, brick.rows.length
      distances = brick.door ? street_distances : nil
      blocked = blocked_cells(brick)
      spots = []
      (0..@h - bh).each do |y|
        (0..@w - bw).each do |x|
          next if allowed && !allowed.call(brick, x, y)
          next if !fits?(brick, x, y, blocked)
          next if brick.by_street && !touches_street?(brick, x, y)
          next if brick.kind == FENCE && !lines_street?(brick, x, y)
          if brick.door
            ax, ay = brick.path_start
            d = distances[y + ay][x + ax]
            next if !d || d > MAX_DOOR_DISTANCE
            spots.push([x, y, d])
          else
            spots.push([x, y, 0])
          end
        end
      end
      return false if spots.empty?
      # Close to a street, but not always the closest spot (in a town, along
      # the street: DOOR_SLACK)
      best = spots.map { |s| s[2] }.min
      slack = DOOR_SLACK[@place.kind] || 2
      near = spots.select { |s| s[2] <= best + slack }
      if brick.door
        # A door whose only way to the street went through the brick itself
        # is skipped
        x, y, = near.shuffle(random: @rng).find { |sx, sy,| door_reachable?(brick, sx, sy) }
        return false if !x
      else
        x, y, = near.sample(random: @rng)
      end
      streets = @street.map(&:dup) if plot
      stamp(brick, x, y)
      raise_plot(brick, x, y, streets) if plot
      return [x, y]
    end

    # True if the street can still be reached from below the door once the
    # brick stands at x, y.
    def door_reachable?(brick, x, y)
      cells = []
      brick.rows.each_with_index do |row, dy|
        row.each_char.with_index { |c, dx| cells.push([x + dx, y + dy]) if c != " " && !@solid[y + dy][x + dx] }
      end
      cells.each { |cx, cy| @solid[cy][cx] = true }
      ax, ay = brick.path_start
      reached = street_distances[y + ay][x + ax]
      cells.each { |cx, cy| @solid[cy][cx] = false }
      return !reached.nil?
    end

    # The brick's cells must be free, with one free tile around it (streets
    # may touch it) so that two bricks never stick together. blocked: the
    # cells where none of its cells may go (blocked_cells).
    def fits?(brick, x, y, blocked = blocked_cells(brick))
      brick_cells(brick).each { |dx, dy| return false if blocked[y + dy][x + dx] || @halo[y + dy][x + dx] > 0 }
      return false if !bank_free?(brick, x, y) || !halo_free?(brick, x, y)
      return false if ringed?(brick) && hill_ring(brick).any? { |dx, dy| !inside?(x + dx, y + dy) || @street[y + dy][x + dx] }
      return true if !brick.door
      # The path in front of the door must be free or already a street
      ax, ay = brick.path_start
      fx, fy = x + ax, y + ay
      return false if !inside?(fx, fy) || !inside?(fx + STREET_WIDTH - 1, fy + STREET_WIDTH - 1)
      STREET_WIDTH.times do |oy|
        STREET_WIDTH.times { |ox| return false if @solid[fy + oy][fx + ox] }
      end
      return true
    end

    # The cells of a brick that are part of it: [dx, dy].
    def brick_cells(brick)
      @brick_cells ||= {}.compare_by_identity
      return @brick_cells[brick] ||= brick.rows.each_with_index.flat_map do |row, dy|
        row.each_char.with_index.filter_map { |c, dx| [dx, dy] if c != " " }
      end
    end

    # Cells where no cell of brick may go, worked out once for all its spots:
    # taken (solid, street, zone), on the wrong level, or next to another
    # brick (not the border; a cave entrance may lean against a cliff, fill
    # bricks of a « dense » excess against each other).
    def blocked_cells(brick)
      cave = brick.kind == CAVE
      dense = brick.kind == @dense
      near = Array.new(@h) { Array.new(@w, false) }
      @h.times do |y|
        @w.times do |x|
          next if !@solid[y][x] || @border[y][x]
          next if (cave && @face&.[](y)&.[](x)) || (dense && @kinds[y][x] == @dense)
          ([y - 1, 0].max..[y + 1, @h - 1].min).each do |ny|
            row = near[ny]
            row[x - 1] = true if x > 0
            row[x] = true
            row[x + 1] = true if x + 1 < @w
          end
        end
      end
      highland = HIGHLAND.include?(brick.kind)
      lowland = LOWLAND.include?(brick.kind)
      return Array.new(@h) do |y|
        Array.new(@w) do |x|
          next true if near[y][x] || @solid[y][x] || @street[y][x] || @zone&.[](y)&.[](x) || canopy?(x, y)
          raised = level_at(x, y) > 0
          highland ? !raised : (raised && lowland)
        end
      end
    end

    # The cells a brick's drawing covers beyond it (a roof, the eaves, a
    # tree's crown: its objects' halos, not their empty cells; a forest's
    # canopy), from its top left corner: [dx, dy]. So that no other brick goes
    # under that drawing and no drawing over another brick: each one is drawn
    # whole.
    def brick_halo(brick)
      @brick_halo ||= {}.compare_by_identity
      return @brick_halo[brick] ||= begin
        cells = brick_drawing(brick).dup
        brick.rows.each_with_index do |row, dy|
          row.each_char.with_index do |c, dx|
            cells.concat(forest_canopy(brick.rows, c, dx, dy)) if @palette.objects[c]&.forest
          end
        end
        cells.uniq - brick_cells(brick)
      end
    end

    # The halo cells of a brick's objects, its own cells under them included
    # (not its forests' canopy, which other leaves of that forest may join).
    def brick_drawing(brick)
      @brick_drawing ||= {}.compare_by_identity
      return @brick_drawing[brick] ||= begin
        cells = []
        brick.rows.each_with_index do |row, dy|
          row.each_char.with_index do |c, dx|
            object = @palette.objects[c]
            next if !object&.halo || object.forest
            # The top left cell of each object of that symbol (objects side
            # by side in a run of it)
            start = (0..dx).reverse_each.take_while { |tx| row[tx] == c }.last
            left = dx - ((dx - start) % object.width)
            top = (0..dy).reverse_each.take_while { |ty| brick.rows[ty][dx] == c }.last
            next if left != dx || (dy - top) % object.height != 0
            hw, hh, hx, hy, empty = object.halo
            hh.times do |j|
              hw.times do |i|
                next if empty.include?((j * hw) + i)
                next if i >= hx && i < hx + object.width && j >= hy && j < hy + object.height
                cells.push([dx + i - hx, dy + j - hy])
              end
            end
          end
        end
        cells.uniq
      end
    end

    # The cells a forest's canopy covers around its tree at x, y of rows
    # (MapGenerator's draw_forest): the 2 rows above its top trees, its leaves
    # on each side.
    def forest_canopy(rows, c, x, y)
      tree = ->(tx, ty) { tx >= 0 && ty >= 0 && rows[ty]&.[](tx) == c }
      cells = []
      cells.push([x, y - 1], [x, y - 2]) if !tree.call(x, y - 1)
      cells.push([x - 1, y]) if !tree.call(x - 1, y)
      cells.push([x + 1, y]) if !tree.call(x + 1, y)
      return cells
    end

    def mark_halo(brick, x, y, step)
      brick_halo(brick).each { |dx, dy| @halo[y + dy][x + dx] += step if inside?(x + dx, y + dy) }
      brick_drawing(brick).each { |dx, dy| @drawn[y + dy][x + dx] += step if inside?(x + dx, y + dy) }
    end

    # No roof over another brick or another roof, nor over an object laid
    # before the bricks (a wall of rocks), nor off the map, nor under the
    # leaves of the border (canopy?), over a cliff or the planks of a port:
    # each drawing whole.
    def halo_free?(brick, x, y)
      return brick_halo(brick).none? do |dx, dy|
        cx, cy = x + dx, y + dy
        next true if !inside?(cx, cy) || @halo[cy][cx] > 0 || canopy?(cx, cy)
        # Nor over a level's cliff or the rim above it (drawn on layer 3)
        next true if level_edge?(cx, cy)
        next true if @palette.terrains[@cells[cy][cx]]&.layer.to_i == 2
        next !@border[cy][cx] && (@kinds[cy][cx] || @palette.objects[@cells[cy][cx]])
      end
    end

    # A brick of water keeps the cells below its bottom edge off the streets
    # of a town (their paving can't show the bank).
    def bank_free?(brick, x, y)
      return true if @place.street == @place.ground || !wet_brick?(brick)
      brick.rows.each_with_index do |row, dy|
        row.each_char.with_index do |c, dx|
          next if !sea_symbols.include?(c) || wet_symbols.include?(brick.rows[dy + 1]&.[](dx))
          return false if inside?(x + dx, y + dy + 1) && @street[y + dy + 1][x + dx]
        end
      end
      return true
    end

    def wet_brick?(brick)
      @wet_bricks ||= {}.compare_by_identity
      return @wet_bricks.fetch(brick) { @wet_bricks[brick] = brick.rows.any? { |row| row.each_char.any? { |c| sea_symbols.include?(c) } } }
    end

    # A fence runs along a street: the street right below it or right above
    # it, all along.
    def lines_street?(brick, x, y)
      width = brick.rows[0].length
      return [1, -1].any? do |oy|
        (0...width).all? { |dx| inside?(x + dx, y + oy) && @street[y + oy][x + dx] && !@stairs_at&.key?([x + dx, y + oy]) }
      end
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
      mark_halo(brick, x, y, 1)
      # A unique building (« Unique = oui ») is laid once per place at most
      @bricks.delete(brick) if brick.unique
      @hq_cells.push([x + (brick.rows.map(&:length).max / 2), y + (brick.rows.length / 2), brick.kind]) if GUILD_HQS.key?(brick.kind)
      # Nothing (no path) against a hill or a ridge but below its stair
      hill_ring(brick).each { |dx, dy| @solid[y + dy][x + dx] = true } if ringed?(brick)
      crown_hill(brick, x, y) if brick.kind == HILL
      reserve_banks if brick.rows.any? { |row| row.each_char.any? { |c| sea_symbols.include?(c) } }
      return if !brick.door
      dx, dy = x + brick.door[0], y + brick.door[1]
      @doors.push([dx, dy, brick])
      street_distances   # again, now that the brick is in the way
      ax, ay = brick.path_start
      carve_path(x + ax, y + ay)
    end
  end
end
