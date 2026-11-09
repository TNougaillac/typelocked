#===============================================================================
# MapProceduralGenerator - Place assembler (towns and routes)
# 1. A border of trees with openings for the exits.
# 2. Streets from each exit to a square near the middle, plus dead ends (on a
#    route the "street" is plain ground: it only keeps the way clear).
# 3. Bricks with a door (buildings), required ones first, each linked to the
#    nearest street by a path; then bricks without a door (decoration).
# 4. Every door and exit must be reachable, or the generation fails.
# A place of a world with a mask (a route in L) only covers some squares of
# its rectangle: the others are border, and the streets meet in its joints
# (its corners) so that they never leave its squares.
# A route of a world may be crossed by water (chenal: a straight channel, lac:
# a lake from side to side), reached only by surfing, or by a rock wall with a
# cave entrance on each side (grotte); the exits then lie on both sides of it.
# A port town (« Port ») has the sea on one side with no exit: a wooden quay
# along the water, piers out to sea, a paved promenade behind the quay and
# its port buildings along it. An island (a map of a world reached by boat)
# is a port town with no exit and the sea on its other sides too.
# Same place + same bricks + same seed = same map.
# This file holds the builder's core (its state, build, inventory, border and
# walks); its other parts reopen PlaceBuilder: 003_Builder_Streets (exits,
# streets, plans), 003_Builder_Bricks (bricks, nooks), 003_Builder_Sea (banks,
# port, island), 003_Builder_Crossings (channel, lake, wall, lock) and
# 003_Builder_Relief (levels, cliffs, river).
#===============================================================================
module MapProceduralGenerator
  # rows: MapGen [Map] rows; doors: [x, y, brick] (door cells); exits:
  # [side, x, y] (first street cell on the map edge)
  # deep: cells of deep water, where the player can dive; terminal: [x, y] of
  # the ferry terminal's door (on the quay, entered from the promenade below);
  # spots: the place's inventory (see PlaceBuilder#inventory); levels: the
  # [Layer3] rows of the raised levels (nil without), see level_rows
  Layout = Struct.new(:rows, :doors, :exits, :deep, :terminal, :spots, :ambiance, :levels)

  # Bricks counted "par case" in [Briques] are multiplied by the place's area
  # in squares of CASE_SIZE x CASE_SIZE tiles.
  CASE_SIZE = 20
  CAVE = "grotte"   # type of the cave entrance bricks
  # Bricks only on the raised levels of a mountain route; bricks never on a
  # raised level (water, rock, caves, the port)
  HIGHLAND = ["rocaille"].freeze
  LOWLAND = [LAKE, HILL, "montagne", CAVE, "port", "gare"].freeze
  # [Legend] symbols of a place with « Relief »: a cliff cell on the map (its
  # ground; the level draws the cliff on [Layer3]) and a stair on [Layer3]
  # (nothing, joined by the levels)
  CLIFF = "ɸ"
  HOLE = "ʘ"
  # [Legend] symbols of a mountain river's cascades on [Layer3], over its
  # water (still waterfall tiles, joined by every level): the crest above the
  # cliff, the fall on the cliff's row, the foam at its foot
  WATERFALL = { crest: "ǁ", fall: "ǂ", foot: "ǀ" }.freeze
  # Most bricks an excess « fill » adds after the others (until none fits)
  FILL_LIMIT = 80
  PORT = "port"   # type of the port buildings, only put along the quay
  MONUMENT = "monument"   # a town's monument, by its square
  DECOR = "decor"         # pure decoration of an ambiance, after the other required bricks
  TERMINAL = "gare"   # type of the ferry terminal, on the quay
  # Rows between the terminal and the promenade: the closest that fits
  TERMINAL_GAPS = [0..3, 4..8].freeze
  PORT_GAP = 0..3     # rows between a port building and the promenade
  # Sea depth of a port town, at most PORT_SHARE of the map across
  PORT_DEPTH = 9..11
  PORT_SHARE = 0.28
  # Tiles that make the map side towards the town, for each sea side
  INLAND = { "nord" => [0, 1], "sud" => [0, -1], "ouest" => [1, 0], "est" => [-1, 0] }.freeze
  # Brick types walked through (grass): their cells count as ground for the
  # inventory, those of GRASS_KINDS as tall grass
  WALK_KINDS = %w[herbes prairie].freeze
  GRASS_KINDS = %w[herbes].freeze
  # Tall grass symbols and their rows at the edge of a patch: its top row
  # (the blades' tips), its bottom row (their foot) and a lone row; used
  # where [Legend] has them.
  GRASS_EDGES = { '"' => "ˈˌˑ", "n" => "ʼʽˀ" }.freeze
  # Very tall grass: its top row keeps its symbol (the tips), the rows below
  # take this one (their foot is the row of « ; » below the patch)
  VERY_TALL = { ":" => "˸" }.freeze
  # Brick types of the nooks, drawn by the builder: a pocket of ground in the
  # rock behind an obstacle (its door), an islet in a pond, a dark cave
  # (the entrance of a cave brick)
  # The sea autotile (A1), whose bottom edge is drawn by the bank below it
  # (« Rive » of the place file) on the ground of the row underneath, unless
  # it draws its own (« EauBordee »)
  SEA_TILES = (48...96).freeze
  NOOK = "recoin"
  ISLET = "ilot"
  DARK_CAVE = "grotte sombre"

  class PlaceBuilder
    # The town's plan (see choose_plan); plain: always « carrefour », and
    # no stretch of sand (lay_transition).
    attr_reader :plan

    NEIGHBOURS = [[0, -1], [1, 0], [0, 1], [-1, 0]]
    FACING_NAMES = { [0, -1] => "haut", [1, 0] => "droite", [0, 1] => "bas", [-1, 0] => "gauche" }.freeze
    NEIGHBOURS8 = [[0, -1], [1, -1], [1, 0], [1, 1], [0, 1], [-1, 1], [-1, 0], [-1, -1]].freeze

    # Whether the place is worth building again plain, after an error: a
    # town with another plan than « carrefour », or a route with sand.
    def plain_retry?
      !@plain && (![nil, "carrefour"].include?(@plan) || !@zone.nil? || (!@level.nil? && !@place.mountain))
    end

    # Whether the town is in terraces: worth building again with other
    # terraces, then flat (same plan), before plain, after an error.
    def terraced?
      !@plain && !@level.nil? && !@place.mountain
    end

    # terrace: which draw of a town's terraces (TERRACE_TRIES), nil = flat
    def initialize(place, bricks, palette, seed, plain = false, terrace: 0)
      @place = place
      @plain = plain
      @terrace = terrace
      cave = place.crossing == "grotte" || place.cave || place.nook == "sombre"
      @bricks = bricks.select { |b| place.counts[b.kind] || (b.kind == CAVE && cave) }
      # Bricks kept for some ambiances; a type left with none of its bricks
      # is skipped
      @left_out = @bricks.map(&:kind).uniq
      @bricks.select! { |b| !b.ambiances || b.ambiances.include?(place.ambiance) }
      # and some left out by the place's excess
      @bricks.reject! { |b| excess[:without]&.include?(b.name) }
      # and the houses of another style than the place's (HOUSE_STYLES)
      houses = HOUSE_STYLES[house_style(place, seed)][:houses]
      @bricks.reject! { |b| b.kind == "maison" && !houses.include?(b.name) } if @bricks.any? { |b| b.kind == "maison" && houses.include?(b.name) }
      @left_out -= @bricks.map(&:kind)
      @palette = palette
      @seed = seed
      @rng = Random.new(seed)
      # Its own draws for the building models and the LAST_KINDS bricks, so
      # that they don't change the rest of the place
      @extra_rng = Random.new(seed + EXTRA_SALT)
      @w, @h = place.width, place.height
      @mask = place.mask
      @cell = @mask && @w / @mask[0].length
      @cells = Array.new(@h) { Array.new(@w) }          # brick or border symbols
      @solid = Array.new(@h) { Array.new(@w, false) }   # nothing else may go there
      @street = Array.new(@h) { Array.new(@w, false) }
      @border = Array.new(@h) { Array.new(@w, false) }
      @kinds = Array.new(@h) { Array.new(@w) }   # brick type of each cell
      @halo = Array.new(@h) { Array.new(@w, 0) }   # buildings' halos over each cell
      @drawn = Array.new(@h) { Array.new(@w, 0) }  # the same, but forests' canopies
      @doors = []
      @exits = []
      @dead_ends = []
      @nooks = []
      @inland_hqs = []
      @hill_tops = []
    end

    def build
      reserve_border
      hub = [@rng.rand((@w * 0.35).to_i..(@w * 0.65).to_i - STREET_WIDTH),
             @rng.rand((@h * 0.35).to_i..(@h * 0.65).to_i - STREET_WIDTH)]
      hub[1] = climbing_hub_row || hub[1] if @place.mountain
      hub = port_hub(hub) if @place.port
      if @mask
        # One square near the middle of each joint, the streets go through them
        @hubs = @place.joints.map do |jx, jy, jw, jh|
          [@rng.rand(((jx + (jw * 0.35)) * @cell).to_i..((jx + (jw * 0.65)) * @cell).to_i - STREET_WIDTH),
           @rng.rand(((jy + (jh * 0.35)) * @cell).to_i..((jy + (jh * 0.65)) * @cell).to_i - STREET_WIDTH)]
        end
        hub = @hubs[0]
      end
      @place.exits.each { |side, offset| carve_exit(side, offset, hub) }
      @hubs&.each_cons(2) { |a, b| carve_line(*a, *b) }
      @water = Array.new(@h) { Array.new(@w, false) }
      lay_port(hub) if @place.port
      lay_shore if @place.island
      scatter_reefs(ISLAND_BANKS, ISLAND_REEFS, @rng) if @place.island
      scatter_reefs(SEA_LIFE[:banks], SEA_LIFE[:reefs], Random.new(@seed ^ SEA_LIFE_SALT)) if @place.port
      @rng.rand(@place.spurs).times { carve_spur(hub) }
      choose_plan
      lay_grid if @plan == "grille" || (excess[:grid] && @plan == "canal")
      lay_plaza(hub) if @plan != "clairière"
      lay_canal(hub) if @plan == "canal"
      close_lock if @place.lock
      cross if @place.crossing
      scatter_reefs(SEA_LIFE[:banks], SEA_LIFE[:reefs], Random.new(@seed ^ SEA_LIFE_SALT)) if %w[chenal lac].include?(@place.crossing)
      raise_terraces if terrace?
      if @place.mountain
        choose_river if @place.river
        raise_levels
        lay_river
        # Its cave is left out when no spot fits
        place_mountain_cave if @place.cave
      end
      lay_transition
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
      draw_banks(rows) if @place.banks && !@place.edged_water
      edge_grass(rows)
      return Layout.new(rows, @doors, @exits, @deep || [], @terminal, inventory, @place.ambiance, level_rows)
    end

    # Where the events of the place can go (MapEvents, items, NPCs), every cell
    # reached on foot from the exits, doors and ferry terminal:
    #   exits: [side, x, y]; doors: [x, y, type] (door cells);
    #   street: free cells beside a street; facing: [x, y, direction] of
    #   each, towards its street (haut, bas, gauche, droite); grass: tall
    #   grass cells;
    #   dead_ends: last cell of each dead-end street;
    #   nooks: [x, y, obstacle (a key of NOOKS), ox, oy]: the loot cell and
    #   the obstacle's cell (a pocket); for an islet the loot only; for a dark
    #   cave its entrance (the loot is in the cave).
    #   hill_tops: the cell on top of each hill, away from its stair (a loot
    #   to climb for).
    def inventory
      starts = @exits.map { |_side, x, y| [x, y] } + @doors.map { |x, y, _| [x, y + 1] }
      seen = Array.new(@h) { Array.new(@w, false) }
      starts.each { |start| walk_foot(start, seen) if !seen[start[1]][start[0]] }
      on_street = ->(x, y) { inside?(x, y) && @street[y][x] && !@stairs_at&.key?([x, y]) }
      street = cells_where(seen) { |x, y| !@street[y][x] && NEIGHBOURS.any? { |ox, oy| on_street.call(x + ox, y + oy) } }
      return {
        exits:     @exits.map(&:dup),
        doors:     @doors.map { |x, y, brick| [x, y, brick.kind] },
        street:    street,
        facing:    street.map { |x, y| [x, y, FACING_NAMES[NEIGHBOURS.find { |ox, oy| on_street.call(x + ox, y + oy) }]] },
        grass:     cells_where(seen) { |x, y| GRASS_KINDS.include?(@kinds[y][x]) },
        dead_ends: @dead_ends.select { |x, y| seen[y][x] },
        nooks:     @nooks.map(&:dup),
        hill_tops: @hill_tops.map(&:dup),
        lock:      @lock&.dup,
        ground:    cells_where(seen) { true }
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
        # A street goes through the border at the exits (like walk)
        next false if !inside?(x, y) || @water[y][x]
        next true if @street[y][x]
        next false if @border[y][x]
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

    # The raised levels are drawn apart (level_rows): on the map, a level
    # shows its ground, streets and bricks, its cliffs CLIFF.
    def symbol_at(x, y)
      return @stairs_at[[x, y]] if @stairs_at&.key?([x, y])
      zone = @zone&.[](y)&.[](x) ? TRANSITION[:ground] : nil
      return @cells[y][x] || zone || @place.street if @street[y][x]
      return @cells[y][x] || @place.street if @paved&.[](y)&.[](x)
      return @cells[y][x] || zone || @place.ground
    end

    # The top and bottom rows of each patch of tall grass (GRASS_EDGES): its
    # tiles are drawn half a row low in the sheet, the tips of its top row
    # and the foot of its bottom row would be missing.
    def edge_grass(rows)
      edges = GRASS_EDGES.select { |_c, v| v.each_char.all? { |e| @palette.legend[e] } }
      grass = ->(x, y) { y >= 0 && y < @h && GRASS_EDGES.key?(rows[y][x]) }
      changed = rows.each_with_index.map do |row, y|
        row.each_char.with_index.map do |c, x|
          next VERY_TALL[c] if VERY_TALL.key?(c) && @palette.legend[VERY_TALL[c]] && y > 0 && rows[y - 1][x] == c
          next c if !edges.key?(c)
          north, south = grass.call(x, y - 1), grass.call(x, y + 1)
          next c if north && south
          edges[c][north ? 1 : (south ? 0 : 2)]
        end.join
      end
      rows.replace(changed)
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

    # Inside the map and on a square its mask covers.
    def covered?(x, y)
      return inside?(x, y) && (!@mask || @mask[y / @cell][x / @cell] == "1")
    end

    def border_size
      object = @place.border && @palette.objects[@place.border]
      return object ? [object.width, object.height] : [0, 0]
    end

    def reserve_border
      bw, bh = border_size
      # Within the border's size of the map's edge or of a square left out
      off = [[0, 0], [-bw, 0], [bw, 0], [0, -bh], [0, bh], [-bw, -bh], [bw, -bh], [-bw, bh], [bw, bh]]
      @h.times do |y|
        @w.times do |x|
          next unless off.any? { |ox, oy| !covered?(x + ox, y + oy) }
          @border[y][x] = @solid[y][x] = true
        end
      end
      deepen_border(bw, bh)
    end

    # The style of the place's houses, drawn by HOUSE_STYLES' weights (those
    # of its ambiance where it has some), apart from the other draws.
    def house_style(place, seed)
      rng = Random.new(seed ^ HOUSE_STYLE_SALT)
      weights = HOUSE_STYLES.map { |name, style| [name, style[:ambiances][place.ambiance] || style[:weight]] }
      roll = rng.rand(weights.sum(&:last))
      return weights.find { |_name, weight| (roll -= weight) < 0 }.first
    end

    # True if the leaves of a border forest may reach x, y off the border:
    # its canopy (2 rows above its trees) and its spills (a column beside
    # them). Nothing drawn there (a brick, flowers, grass), so that the
    # forest is drawn whole: no tile cut.
    def canopy?(x, y)
      return false if @loose_canopy || !@place.border || !@palette.objects[@place.border]&.forest
      @canopy ||= Array.new(@h) do |cy|
        Array.new(@w) do |cx|
          !@border[cy][cx] && [-1, 0, 1].any? { |ox| (0..2).any? { |oy| inside?(cx + ox, cy + oy) && @border[cy + oy][cx + ox] } }
        end
      end
      return @canopy[y][x]
    end

    # Natural border (BORDER_DEPTH): along each side of the map, the border
    # grows inwards by whole rows of its trees, in stretches of
    # BORDER_STRETCH trees, each one row deeper or shallower than the last,
    # so that its inner edge winds like the edge of a forest. At most
    # BORDER_SHARE of the map across, so that the bricks still fit. Its own
    # draws (BORDER_SALT), so the rest of the place stays the same.
    def deepen_border(bw, bh)
      depths = BORDER_DEPTH[@place.kind]
      return if !depths || @mask || @place.island || bw == 0 || bh == 0
      rng = Random.new(@seed ^ BORDER_SALT)
      sides = { "nord" => [@w, bw, bh, @h], "sud" => [@w, bw, bh, @h],
                "ouest" => [@h, bh, bw, @w], "est" => [@h, bh, bw, @w] }
      sides.each do |side, (length, step, unit, across)|
        deepest = [depths.max, ((across * BORDER_SHARE) / unit).floor - 1].min
        next if deepest <= 0
        low = [depths.min, deepest].min
        depth = rng.rand(low..deepest)
        a = 0
        while a < length
          stretch = rng.rand(BORDER_STRETCH) * step
          (a...[a + stretch, length].min).each do |along|
            (unit...unit * (depth + 1)).each do |d|
              x, y = case side
                     when "nord"  then [along, d]
                     when "sud"   then [along, @h - 1 - d]
                     when "ouest" then [d, along]
                     else              [@w - 1 - d, along]
                     end
              @border[y][x] = @solid[y][x] = true
            end
          end
          a += stretch
          depth = (depth + rng.rand(-1..1)).clamp(low, deepest)
        end
      end
    end

    # Excess « carpet », once every door and exit is known to be reachable:
    # that symbol (grass, flowers) on the free ground, and over the streets too
    # with « over_street » (walkable, but kept off the exits).
    def cover_ground
      pave_ground if excess[:pave]
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
          # Never under a drawing (a crown, a roof, the leaves of the border)
          next if canopy?(x, y) || @halo[y][x] > 0
          @cells[y][x] = carpet
        end
      end
    end

    # Excess « pave »: the town's street over the free ground that close to a
    # street (sidewalks, paved yards), walked like the ground.
    def pave_ground
      on_street = ->(x, y) { @street[y][x] && !@stairs_at&.key?([x, y]) && !@water[y][x] }
      @paved = Array.new(@h) do |y|
        Array.new(@w) { |x| free_ground?(x, y) && near?(x, y, excess[:pave]) { |nx, ny| on_street.call(nx, ny) } }
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

    # Fills the border with copies of the border object, first on a grid of
    # its size (the trees of a forest line up, see MapGenerator's forest
    # objects), then wherever one still fits; leftovers stay ground, but off
    # the squares of a mask they take « Comble », so that no way leads there.
    def plant_border
      return if !@place.border
      bw, bh = border_size
      forest = @palette.objects[@place.border].forest
      [true, false].each do |grid|
        @h.times do |y|
          @w.times do |x|
            next if grid && (x % bw != 0 || y % bh != 0)
            next if !(0...bh).all? { |dy| (0...bw).all? { |dx| free_border?(x + dx, y + dy) } }
            next if forest && !canopy_clear?(x, y, bw, bh)
            bh.times { |dy| bw.times { |dx| @cells[y + dy][x + dx] = @place.border } }
          end
        end
      end
      return if !@mask || !@place.filler
      @h.times { |y| @w.times { |x| @cells[y][x] = @place.filler if free_border?(x, y) && !covered?(x, y) } }
    end

    # A border tree at x, y (bw x bh) whose canopy (its leaves beside it and
    # at its corners, the 2 rows above) covers no drawing: an object, a brick's halo, the planks
    # of a port or a cliff. Where it would, the border keeps its ground.
    def canopy_clear?(x, y, bw, bh)
      sides = (-2...bh).flat_map { |dy| [[x - 1, y + dy], [x + bw, y + dy]] }
      above = (0...bw).flat_map { |dx| [[x + dx, y - 1], [x + dx, y - 2]] }
      return (sides + above).none? do |cx, cy|
        next false if !inside?(cx, cy)
        next true if @drawn[cy][cx] > 0 || @palette.terrains[@cells[cy][cx]]&.layer.to_i == 2
        # Beside it, its spills may join the canopy of the next tree: two
        # layers to draw, none taken already (a rock, a flower, a cliff);
        # above it, one at least (not a rock on two layers)
        side = sides.include?([cx, cy])
        upper = (@cells[cy][cx] == @place.border) ? 0 : @palette.legend[@cells[cy][cx]]&.length.to_i - 1
        next true if side && upper >= 1
        next true if upper >= 2
        # Nor over a cliff or a raised level: the border stays on the ground,
        # the edge of the level beside it takes a layer too
        next true if level_edge?(cx, cy) || (level_at(cx, cy) > 0 && !@border[cy][cx])
        object = @palette.objects[@cells[cy][cx]]
        next object && @cells[cy][cx] != @place.border
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
              else
                [@doors[0][0], @doors[0][1] + 1]
              end
      seen = walk(start)
      @exits.each { |side, ex, ey| error("la sortie #{side} est inaccessible") if !seen[ey][ex] }
      @doors.each do |dx, dy, brick|
        error("la porte de « #{brick.name} » est inaccessible") if !seen[dy + 1][dx]
      end
    end

    def walk(start)
      # The wall of a Grappling Hook lock is crossed
      walkable = lambda do |x, y|
        inside?(x, y) && (@street[y][x] || @water[y][x] || (!@cells[y][x] && !@border[y][x]) || @grapple&.include?([x, y]))
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

  # A town whose terraces failed, built again with other terraces
  # (TERRACE_TRIES), then flat; nil if none fits.
  def terrace_layout(builder, place, bricks, palette, seed)
    return nil if !builder.terraced?
    [*1...TERRACE_TRIES, nil].each do |terrace|
      return PlaceBuilder.new(place, bricks, palette, seed, terrace: terrace).build
    rescue Error
      next
    end
    return nil
  end

  # One layout of a place: as drawn, else with other terraces, else flat
  # (a plain retry).
  def build_layout(place, bricks, palette, seed)
    builder = PlaceBuilder.new(place, bricks, palette, seed)
    return builder.build
  rescue Error
    raise if !builder&.plain_retry?
    return terrace_layout(builder, place, bricks, palette, seed) || PlaceBuilder.new(place, bricks, palette, seed, true).build
  end

  # Returns [MapGen plan, its text, Layout] for that seed. The ambiance is
  # drawn from the seed unless place.ambiance already names one.
  def generate_place(place, bricks, seed)
    if !place.ambiance && place.ambiances.any?
      place = place.dup
      place.ambiance = draw_ambiance(place, Random.new(seed + 7919))
    end
    styles = ambiance(place)&.streets&.length.to_i
    if styles > 1 && !place.street_style
      place = place.dup
      place.street_style = Random.new(seed + 7927).rand(styles)
    end
    place = with_ambiance_counts(place)
    palette = check_palette(place, bricks)
    # A place never comes out missing what it must have: when it doesn't
    # fit, it is laid out again with other draws (PLACE_RETRIES), its seed
    # (and so its map) the same
    layout = nil
    (0..PLACE_RETRIES).each do |attempt|
      layout = build_layout(place, bricks, palette, seed + (attempt * PLACE_RETRY_STEP))
      break
    rescue Error
      raise if attempt == PLACE_RETRIES
    end
    text = plan_text(place, seed, layout.rows, layout.levels)
    return MapGenerator.parse(text, place.file), text, layout
  end
end
