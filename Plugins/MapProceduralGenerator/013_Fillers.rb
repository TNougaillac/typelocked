#===============================================================================
# MapProceduralGenerator - Decor maps around the places
# Each empty square of the world grid next to a place (sides and corners)
# takes the scenery of that place: the sea beyond a port's sea side, the top
# of a mountain past a mountain route, a forest of its trees elsewhere, with
# its ambiance. Squares of the same scenery are merged into rectangles, one
# map each, put on the world plan as « type=decor »: MapGen links them to the
# places they touch, corners included, and leaves them off the Town Map.
# Their trees and water stop the player, so they are never walked.
#===============================================================================
module MapProceduralGenerator
  # name, symbol, x, y, w, h (squares), text: MapGen plan
  Filler = Struct.new(:name, :symbol, :x, :y, :w, :h, :text)
  # Neighbours of a square: sides weigh more than corners
  FILLER_REACH = [[0, -1, 2], [0, 1, 2], [-1, 0, 2], [1, 0, 2], [-1, -1, 1], [1, -1, 1], [-1, 1, 1], [1, 1, 1]].freeze

  module_function

  # built: [WorldPlace, Place, MapGen plan text, Layout] of the world grid.
  def world_fillers(world, built, seed, map_ids)
    return [] if !FILLERS
    owner = Array.new(world.height) { Array.new(world.width) }
    built.each_with_index do |(wp, *), i|
      wp.h.times { |dy| wp.w.times { |dx| owner[wp.y + dy][wp.x + dx] = i } }
    end
    # Squares drawn from the same file (town or route) with the same ambiance
    # can share a map: [kind, file, ambiance], and the place each copies
    sources = {}
    scenery = Array.new(world.height) do |y|
      Array.new(world.width) do |x|
        kind, i = !owner[y][x] && filler_scenery(built, owner, x, y)
        next nil if !kind
        key = [kind, built[i][0].kind, built[i][3].ambiance]
        sources[key] ||= i
        key
      end
    end
    rects = filler_rects(scenery)
    # Too many for the symbols: the largest first
    rects = rects.max_by(FILLER_SYMBOLS.length) { |_key, _x, _y, w, h| w * h } if rects.length > FILLER_SYMBOLS.length
    return rects.each_with_index.map do |(key, x, y, w, h), i|
      name = "#{FILLER_NAME} #{i + 1}"
      text = filler_text(world, built[sources[key]], key[0], name, w, h, map_ids[name], (seed * 1000) + 950 + i)
      Filler.new(name, FILLER_SYMBOLS[i], x, y, w, h, text)
    end
  end

  # [kind, index of the place it copies] of an empty square, nil if no place
  # is next to it. The sea beyond a port's sea side comes first.
  def filler_scenery(built, owner, x, y)
    weights = Hash.new(0)
    FILLER_REACH.each do |dx, dy, weight|
      i = owner[y + dy]&.[](x + dx) if y + dy >= 0 && x + dx >= 0
      weights[i] += weight if i
    end
    return nil if weights.empty?
    port = weights.keys.find { |i| beyond_port?(built[i][0], x, y) }
    return [:mer, port] if port
    source = weights.max_by { |i, weight| [weight, -i] }[0]
    return [built[source][0].mountain ? :montagne : :foret, source]
  end

  # True if the square is past the sea side of that port town.
  def beyond_port?(wp, x, y)
    case wp.port
    when "ouest" then x < wp.x
    when "est"   then x >= wp.x + wp.w
    when "nord"  then y < wp.y
    when "sud"   then y >= wp.y + wp.h
    else false
    end
  end

  # Rectangles of squares with the same scenery, row by row:
  # [key, x, y, w, h].
  def filler_rects(scenery)
    height = scenery.length
    width = scenery[0].length
    taken = Array.new(height) { Array.new(width, false) }
    rects = []
    height.times do |y|
      width.times do |x|
        key = scenery[y][x]
        next if !key || taken[y][x]
        same = ->(cx, cy) { cy < height && cx < width && !taken[cy][cx] && scenery[cy][cx] == key }
        w = 1
        w += 1 while same.call(x + w, y)
        h = 1
        h += 1 while (0...w).all? { |i| same.call(x + i, y + h) }
        h.times { |j| w.times { |i| taken[y + j][x + i] = true } }
        rects.push([key, x, y, w, h])
      end
    end
    return rects
  end

  # MapGen plan text of a decor map, in the palette of the place it copies.
  def filler_text(world, source, kind, name, w, h, map_id, seed)
    _wp, place, text, layout = source
    decor = place.dup
    decor.name = name
    decor.map_id = map_id
    decor.ambiance = layout.ambiance
    palette = MapGenerator.parse(text, place.file)
    rows = filler_rows(kind, decor, palette, w * world.cell, h * world.cell, Random.new(seed))
    return plan_text(decor, seed, rows)
  end

  def filler_rows(kind, place, palette, width, height, rng)
    if kind == :mer && place.water
      return Array.new(height) { place.water * width }
    elsif kind == :montagne && palette.legend["z"]
      rocks = FILLER_ROCK_SYMBOLS.select { |c| palette.legend[c] }
      return Array.new(height) do
        Array.new(width) { (!rocks.empty? && rng.rand < FILLER_ROCKS) ? rocks.sample(random: rng) : "z" }.join
      end
    end
    # A forest of its border trees; the rows and columns left over get its
    # bushes (or its ground)
    rows = Array.new(height) { Array.new(width, place.filler || place.ground) }
    tree = place.border && palette.objects[place.border]
    if tree
      (0..height - tree.height).step(tree.height) do |y|
        (0..width - tree.width).step(tree.width) do |x|
          tree.height.times { |dy| tree.width.times { |dx| rows[y + dy][x + dx] = place.border } }
        end
      end
    end
    return rows.map(&:join)
  end
end
