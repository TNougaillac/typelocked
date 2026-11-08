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
      # A headquarters with no room on the quay first among the optional ones
      order = required.shuffle(random: @rng).sort_by { |k| [with_door.call(k), (k == DECOR) ? 1 : 0] } + @inland_hqs +
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
        next place_smallest(kind) if QUAY_HQS.include?(kind)
        # « pack »: the boosted bricks, the big ones first
        next place_big(kind) if i >= required.length && excess[:pack] && boosted.call(kind) == 0
        next if place_brick(kind, kind == MONUMENT ? monument_spot : nil)
        # The rocks on a route's mesas go where they fit, or not at all
        next if HIGHLAND.include?(kind) && @mesas
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
        next if i >= required.length || place_smallest(kind)
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
        ox, oy = spot[0] + brick.door[0], spot[1] + brick.door[1]
        @nooks.push([spot[0] + loot[0], spot[1] + loot[1], @place.nook, ox, oy])
        # The Grappling Hook's wall: from its mouth to its inner face
        @nooks[-1].push(ox, oy - 1) if @place.nook == GRAPPLE
      end
    end

    # A pocket of ground at the back of a block of rock, reached by a corridor
    # one tile wide from the south: the obstacle stands at its mouth (the
    # door, so a path leads to it). Three tiles wide, so that a pushed boulder
    # can be walked around. For the Grappling Hook, the corridor is rock too.
    # Returns the brick and the loot cell (a back corner).
    def nook_brick
      rock = "^"
      ground = @place.ground
      depth = @rng.rand(2..3)
      rows = [" #{rock * 5} ", rock * 7]
      depth.times { rows.push("#{rock * 2}#{ground * 3}#{rock * 2}") }
      corridor = (@place.nook == GRAPPLE) ? rock : ground
      2.times { rows.push("#{rock * 3}#{corridor}#{rock * 3}") }
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
      ovals = [[w / 2.0, h / 2.0, w * first, h * first]]
      (@rng.rand(LAKE_SHAPE[:ovals]) - 1).times do
        cx, cy, rx, ry = ovals[@rng.rand(ovals.length)]
        angle = @rng.rand * 2 * Math::PI
        ovals.push([cx + (rx * Math.cos(angle)), cy + (ry * Math.sin(angle)),
                    w * @rng.rand(LAKE_SHAPE[:more]), h * @rng.rand(LAKE_SHAPE[:more])])
      end
      rows = Array.new(h) do |y|
        Array.new(w) do |x|
          wet = ovals.any? { |cx, cy, rx, ry| (((x + 0.5 - cx) / rx)**2) + (((y + 0.5 - cy) / ry)**2) <= 1.0 + (@rng.rand * 0.25) }
          wet ? @place.water : " "
        end.join
      end
      rows.reject! { |row| row.strip.empty? }
      left = rows.map { |row| row.index(/\S/) }.min
      right = rows.map { |row| row.rindex(/\S/) }.max
      rows.map! { |row| row[left..right] }
      return Brick.new(LAKE, "Lac", LAKE, nil, 1, false, rows)
    end

    # A hill: a brick of rock in a rough oval made for this spot, drawn on a
    # grid of 2x2 blocks (each bend of its cliff at least 2 tiles long, like
    # the stair), with a stair (2 tiles: left, right) in the middle of its
    # south face (its door, so a path leads to it), framed by one block of
    # cliff on each side.
    def hill_brick
      rock = @place.levels&.first || "^"
      stair = @place.stairs&.first || "eɛ"
      cw, ch = @rng.rand(3..5), @rng.rand(2..3)
      door = (cw - 1) / 2
      blocks = Array.new(ch) do |by|
        Array.new(cw) do |bx|
          dx = (bx + 0.5 - (cw / 2.0)) / (cw / 2.0)
          dy = (by + 0.5 - (ch / 2.0)) / (ch / 2.0)
          (by == ch - 1 && (bx - door).abs <= 1) || (dx * dx) + (dy * dy) <= 1.1 + (@rng.rand * 0.3)
        end
      end
      rows = (0...ch * 2).map { |y| (0...cw * 2).map { |x| blocks[y / 2][x / 2] ? rock : " " }.join }
      2.times { |k| rows[-1][(door * 2) + k] = stair[k] }
      return Brick.new(HILL, "Colline", HILL, [door * 2, (ch * 2) - 1], 1, false, rows)
    end

    # The tiles around a hill (8 neighbours) but those below its stair: no
    # street may run there (the levels join the streets: its cliff would
    # open beside the stair), [dx, dy] from its top left corner.
    def hill_ring(brick)
      cells = brick_cells(brick)
      below = [[brick.door[0], brick.door[1] + 1], [brick.door[0] + 1, brick.door[1] + 1]]
      return cells.flat_map { |cx, cy| NEIGHBOURS8.map { |ox, oy| [cx + ox, cy + oy] } }.uniq - cells - below
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
      bricks = MODELS.key?(kind) ? models(kind) : @bricks.select { |b| b.kind == kind }
      roll = @rng.rand(bricks.sum(&:weight))
      return bricks.find { |b| (roll -= b.weight) < 0 }
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

    def put_brick(brick, allowed = nil)
      bw, bh = brick.rows.map(&:length).max, brick.rows.length
      distances = brick.door ? street_distances : nil
      blocked = blocked_cells(brick)
      spots = []
      (0..@h - bh).each do |y|
        (0..@w - bw).each do |x|
          next if allowed && !allowed.call(brick, x, y)
          next if !fits?(brick, x, y, blocked)
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
      stamp(brick, x, y)
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
      reached = street_distances[y + brick.rows.length][x + brick.door[0]]
      cells.each { |cx, cy| @solid[cy][cx] = false }
      return !reached.nil?
    end

    # The brick's cells must be free, with one free tile around it (streets
    # may touch it) so that two bricks never stick together. blocked: the
    # cells where none of its cells may go (blocked_cells).
    def fits?(brick, x, y, blocked = blocked_cells(brick))
      brick_cells(brick).each { |dx, dy| return false if blocked[y + dy][x + dx] || @halo[y + dy][x + dx] > 0 }
      return false if !bank_free?(brick, x, y) || !halo_free?(brick, x, y)
      return false if brick.kind == HILL && hill_ring(brick).any? { |dx, dy| !inside?(x + dx, y + dy) || @street[y + dy][x + dx] }
      return true if !brick.door
      # The path under the door must be free or already a street
      fx, fy = x + brick.door[0], y + brick.rows.length
      return false if !inside?(fx + STREET_WIDTH - 1, fy + STREET_WIDTH - 1)
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
          next true if near[y][x] || @solid[y][x] || @street[y][x] || @zone&.[](y)&.[](x)
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
    # before the bricks (a wall of rocks), nor off the map.
    def halo_free?(brick, x, y)
      return brick_halo(brick).none? do |dx, dy|
        cx, cy = x + dx, y + dy
        next true if !inside?(cx, cy) || @halo[cy][cx] > 0
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
      # Nothing (no path) against a hill but below its stair
      if brick.kind == HILL
        hill_ring(brick).each { |dx, dy| @solid[y + dy][x + dx] = true }
        crown_hill(brick, x, y)
      end
      reserve_banks if brick.rows.any? { |row| row.each_char.any? { |c| sea_symbols.include?(c) } }
      return if !brick.door
      dx, dy = x + brick.door[0], y + brick.door[1]
      @doors.push([dx, dy, brick])
      street_distances   # again, now that the brick is in the way
      carve_path(dx, dy + 1)
    end
  end
end
