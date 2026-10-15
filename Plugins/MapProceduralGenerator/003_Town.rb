#===============================================================================
# MapProceduralGenerator - Town assembler
# 1. A border of trees with openings for the exits.
# 2. Streets from each exit to a square near the middle, plus dead ends.
# 3. Bricks with a door (buildings), required ones first, each linked to the
#    nearest street by a path; then bricks without a door (decoration).
# 4. Every door and exit must be reachable, or the generation fails.
# Same place + same bricks + same seed = same town.
#===============================================================================
module MapProceduralGenerator
  # rows: MapGen [Map] rows; doors: [x, y, brick] (door cells); exits:
  # side => [x, y] (first street cell on the map edge)
  Town = Struct.new(:rows, :doors, :exits)

  class TownBuilder
    def initialize(place, bricks, palette, seed)
      @place = place
      @bricks = bricks.select { |b| place.counts[b.kind] }
      @palette = palette
      @seed = seed
      @rng = Random.new(seed)
      @w, @h = place.width, place.height
      @cells = Array.new(@h) { Array.new(@w) }          # brick or border symbols
      @solid = Array.new(@h) { Array.new(@w, false) }   # nothing else may go there
      @street = Array.new(@h) { Array.new(@w, false) }
      @border = Array.new(@h) { Array.new(@w, false) }
      @doors = []
      @exits = {}
    end

    def build
      reserve_border
      hub = [@rng.rand((@w * 0.35).to_i..(@w * 0.65).to_i - STREET_WIDTH),
             @rng.rand((@h * 0.35).to_i..(@h * 0.65).to_i - STREET_WIDTH)]
      @place.exits.each { |side| carve_exit(side, hub) }
      @rng.rand(@place.spurs).times { carve_spur(hub) }
      place_bricks
      plant_border
      check_reachable
      rows = Array.new(@h) do |y|
        Array.new(@w) { |x| @street[y][x] ? @place.street : (@cells[y][x] || @place.ground) }.join
      end
      return Town.new(rows, @doors, @exits)
    end

    private

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

    # L-shaped street, bending at a random end.
    def carve_line(x0, y0, x1, y1)
      if @rng.rand(2) == 0
        (x0 < x1 ? x0.upto(x1) : x0.downto(x1)).each { |x| paint(x, y0) }
        (y0 < y1 ? y0.upto(y1) : y0.downto(y1)).each { |y| paint(x1, y) }
      else
        (y0 < y1 ? y0.upto(y1) : y0.downto(y1)).each { |y| paint(x0, y) }
        (x0 < x1 ? x0.upto(x1) : x0.downto(x1)).each { |x| paint(x, y1) }
      end
    end

    def carve_exit(side, hub)
      along = ->(size) { @rng.rand((size * 0.25).to_i..(size * 0.75).to_i - STREET_WIDTH) }
      x, y = case side
             when "nord"  then [along.call(@w), 0]
             when "sud"   then [along.call(@w), @h - STREET_WIDTH]
             when "ouest" then [0, along.call(@h)]
             when "est"   then [@w - STREET_WIDTH, along.call(@h)]
             end
      @exits[side] = [x, y]
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
      @place.counts.each do |kind, range|
        count = @rng.rand(range)
        range.min.times { required.push(kind) }
        (count - range.min).times { optional.push(kind) }
      end
      # Buildings before decoration, so decoration never blocks a door
      with_door = ->(kind) { @bricks.any? { |b| b.kind == kind && b.door } ? 0 : 1 }
      order = required.shuffle(random: @rng).sort_by { |k| with_door.call(k) } +
              optional.shuffle(random: @rng).sort_by { |k| with_door.call(k) }
      order.each_with_index do |kind, i|
        next if place_brick(kind)
        error("impossible de placer une brique « #{kind} » ; agrandis « Taille » ou réduis [Briques]") if i < required.length
      end
    end

    def pick_brick(kind)
      bricks = @bricks.select { |b| b.kind == kind }
      roll = @rng.rand(bricks.sum(&:weight))
      return bricks.find { |b| (roll -= b.weight) < 0 }
    end

    # Puts one brick of that type where it fits; returns false if none does.
    def place_brick(kind)
      brick = pick_brick(kind)
      bw, bh = brick.rows[0].length, brick.rows.length
      distances = brick.door ? street_distances : nil
      spots = []
      (0..@h - bh).each do |y|
        (0..@w - bw).each do |x|
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
      return true
    end

    # The brick's cells must be free, with one free tile around it (streets
    # may touch it) so that two bricks never stick together.
    def fits?(brick, x, y)
      brick.rows.each_with_index do |row, dy|
        row.each_char.with_index do |c, dx|
          next if c == " "
          cx, cy = x + dx, y + dy
          return false if @solid[cy][cx] || @street[cy][cx]
          (-1..1).each do |oy|
            (-1..1).each do |ox|
              nx, ny = cx + ox, cy + oy
              return false if inside?(nx, ny) && @solid[ny][nx] && !@border[ny][nx]
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

    # Walks from the first exit over ground and streets: every exit and the
    # cell below every door must be reached.
    def check_reachable
      walkable = ->(x, y) { inside?(x, y) && (@street[y][x] || (!@cells[y][x] && !@border[y][x])) }
      return if @exits.empty? && @doors.empty?
      start = @exits.values.first || [@doors[0][0], @doors[0][1] + 1]
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
      @exits.each { |side, (ex, ey)| error("la sortie #{side} est inaccessible") if !seen[ey][ex] }
      @doors.each do |dx, dy, brick|
        error("la porte de « #{brick.name} » est inaccessible") if !seen[dy + 1][dx]
      end
    end
  end

  module_function

  # Returns [MapGen plan, its text, Town] for that seed.
  def generate_place(place, bricks, seed)
    palette = check_palette(place, bricks)
    town = TownBuilder.new(place, bricks, palette, seed).build
    text = plan_text(place, seed, town.rows)
    return MapGenerator.parse(text, place.file), text, town
  end
end
