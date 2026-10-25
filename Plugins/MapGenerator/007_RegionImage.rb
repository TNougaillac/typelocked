#===============================================================================
# MapGenerator - Draws the Town Map image of a world plan
# Same colours and shapes as Essentials' mapRegion0.png: round coast with sand
# and shallow sea, routes as white paths in a dark band that follow the
# connections, towns as red blocks, other places as dark squares with a spot.
# The image is a plain PNG written with Zlib, and an existing image is only
# replaced if MapGen drew it (it carries a "MapGen" text chunk).
#===============================================================================
module MapGenerator
  REGION_SQUARE = 16            # Town Map square size in pixels (UI_RegionMap)
  REGION_SIZE = [30, 20]        # Default image size in squares (480x320)
  # Colours and shapes taken from Essentials' mapRegion0.png (2-pixel art)
  REGION_COLORS = {
    sea:       [80, 184, 216],
    sea_light: [64, 176, 200],
    sea_dark:  [56, 160, 184],
    sand:      [192, 144, 104],
    land:      [96, 192, 144],
    outline:   [80, 80, 80],
    route:     [248, 248, 248],
    town:      [248, 80, 96],
    town_mid:  [200, 56, 72],
    town_low:  [160, 48, 72],
    spot:      [112, 200, 144],
    dot:       [144, 144, 144]
  }
  # Distance from a place (pixels) where the land, sand and shallow sea end
  REGION_COAST = [[14, :land], [18, :sand], [22, :sea_dark], [26, :sea_light]]

  module_function

  # Kind given by type=..., else a route if its name says so, a town if it has
  # a fly destination, a place otherwise.
  def place_kind(place)
    return place.kind if place.kind
    return "route" if place.name =~ /\Aroute\b/i
    return (place.fly) ? "ville" : "lieu"
  end

  def region_image_path(plan)
    return File.join("Graphics/UI/Town Map", plan.image || "mapRegion#{plan.region}.png")
  end

  def drawn_by_mapgen?(path)
    return File.binread(path, 4096).include?("MapGen")
  end

  # Returns a note for the player.
  def draw_region_image(plan, links)
    path = region_image_path(plan)
    if File.exist?(path) && !drawn_by_mapgen?(path)
      return _INTL("Image {1} gardée : elle n'a pas été dessinée par MapGen (choisis un autre nom avec Image).", path)
    end
    # No margin past the plan: 32x24 squares fill the Town Map screen
    width = [REGION_SIZE[0], plan.origin[0] + plan.rows.map(&:length).max].max * REGION_SQUARE
    height = [REGION_SIZE[1], plan.origin[1] + plan.rows.length].max * REGION_SQUARE
    canvas = RegionCanvas.new(width, height, REGION_COLORS[:sea])
    paint_region(canvas, plan, links)
    canvas.save(path)
    return _INTL("Carte de région dessinée : {1}.", path)
  end

  def paint_region(canvas, plan, links)
    sq = REGION_SQUARE
    box = proc do |place|
      [(plan.origin[0] + place.x) * sq, (plan.origin[1] + place.y) * sq, place.width * sq, place.height * sq]
    end
    paint_coast(canvas, plan.places.values.flat_map { |place| square_boxes(plan, place) })
    # Routes: a dark 16-pixel band with a white 8-pixel core, along each route
    # (its trace if it has one) and from each connection to the places it joins
    segments = []
    plan.places.each_value do |place|
      next if place_kind(place) != "route"
      line = route_line(plan, place)
      line.each_cons(2) { |a, b| segments.push(a + b) }
    end
    links.each do |a, edge, _pa, b, _eb, _pb|
      point = link_point(plan, a, edge, b)
      [a, b].each do |place|
        # To the route's line (or the block's centre), in two straight pieces
        # that leave the edge at a right angle
        target = (place_kind(place) == "route") ? route_point(route_line(plan, place), point) : place_centre(plan, place, point)
        corner = (edge == "E") ? [target[0], point[1]] : [point[0], target[1]]
        segments.push(point + corner, corner + target)
      end
    end
    segments.each { |s| canvas.segment(*s, sq / 2, REGION_COLORS[:outline]) }
    segments.each { |s| canvas.segment(*s, sq / 4, REGION_COLORS[:route]) }
    # Other places: dark squares with a green spot, towns: red blocks
    plan.places.each_value do |place|
      next if place_kind(place) != "lieu"
      square_boxes(plan, place).each { |b| paint_spots(canvas, *b) }
    end
    plan.places.each_value do |place|
      next if place_kind(place) != "ville"
      if place.mask
        paint_town_squares(canvas, square_boxes(plan, place))
      else
        paint_town(canvas, *box.call(place))
      end
    end
  end

  # Pixel boxes of a place: its rectangle, or one per square of its mask.
  def square_boxes(plan, place)
    sq = REGION_SQUARE
    x0, y0 = (plan.origin[0] + place.x) * sq, (plan.origin[1] + place.y) * sq
    return [[x0, y0, place.width * sq, place.height * sq]] if !place.mask
    return (0...place.height).flat_map do |dy|
      (0...place.width).select { |dx| place.covers?(dx, dy) }.map { |dx| [x0 + (dx * sq), y0 + (dy * sq), sq, sq] }
    end
  end

  # The line of a route in pixels: its trace, else along its longer side.
  def route_line(plan, place)
    sq = REGION_SQUARE
    x, y = (plan.origin[0] + place.x) * sq, (plan.origin[1] + place.y) * sq
    return place.trace.map { |tx, ty| [x + (tx * sq / 2), y + (ty * sq / 2)] } if place.trace
    w, h = place.width * sq, place.height * sq
    return [[x + (sq / 2), y + (h / 2)], [x + w - (sq / 2), y + (h / 2)]] if w >= h
    return [[x + (w / 2), y + (sq / 2)], [x + (w / 2), y + h - (sq / 2)]]
  end

  # Middle of the edge shared by a and b (b east or south of a), in pixels:
  # of the squares both cover when they have a mask.
  def link_point(plan, a, edge, b)
    sq = REGION_SQUARE
    east = (edge == "E")
    from = east ? [a.y, b.y].max : [a.x, b.x].max
    to = east ? [a.y + a.height, b.y + b.height].min : [a.x + a.width, b.x + b.width].min
    if a.mask || b.mask
      shared = (from...to).select do |k|
        east ? a.covers?(a.width - 1, k - a.y) && b.covers?(0, k - b.y) : a.covers?(k - a.x, a.height - 1) && b.covers?(k - b.x, 0)
      end
      from, to = shared.first, shared.first + 1 if !shared.empty?
      to += 1 while shared.include?(to)
    end
    middle = ((from + to) * sq / 2) + ((east ? plan.origin[1] : plan.origin[0]) * sq)
    return east ? [(plan.origin[0] + a.x + a.width) * sq, middle] : [middle, (plan.origin[1] + a.y + a.height) * sq]
  end

  # Centre of a block, or of its square closest to that point with a mask.
  def place_centre(plan, place, point)
    x, y, w, h = square_boxes(plan, place).min_by do |bx, by, bw, bh|
      ((bx + (bw / 2) - point[0])**2) + ((by + (bh / 2) - point[1])**2)
    end
    return [x + (w / 2), y + (h / 2)]
  end

  # Land, sand and shallow sea by distance to the nearest place, in 2-pixel
  # blocks so the coast is round and pixelated like the base map.
  def paint_coast(canvas, boxes)
    (0...canvas.height).step(2) do |py|
      (0...canvas.width).step(2) do |px|
        cx, cy = px + 1, py + 1
        dist = boxes.map do |x, y, w, h|
          dx = [x - cx, 0, cx - (x + w)].max
          dy = [y - cy, 0, cy - (y + h)].max
          Math.sqrt((dx * dx) + (dy * dy))
        end.min
        band = REGION_COAST.find { |limit, _| dist <= limit }
        canvas.fill(px, py, 2, 2, REGION_COLORS[band[1]]) if band
      end
    end
  end

  # One dark square per cell, grey dots in the corners, green spot in the middle.
  def paint_spots(canvas, x, y, w, h)
    c = REGION_COLORS
    canvas.fill(x, y, w, h, c[:outline])
    (0...h).step(REGION_SQUARE) do |oy|
      (0...w).step(REGION_SQUARE) do |ox|
        [[2, 2], [12, 2], [2, 12], [12, 12]].each { |dx, dy| canvas.fill(x + ox + dx, y + oy + dy, 2, 2, c[:dot]) }
        canvas.fill(x + ox + 6, y + oy + 4, 4, 8, c[:spot])
        canvas.fill(x + ox + 4, y + oy + 6, 8, 4, c[:spot])
      end
    end
  end

  # Red block with a 4-pixel dark rounded frame, shaded per row of cells.
  def paint_town(canvas, x, y, w, h)
    c = REGION_COLORS
    canvas.fill(x - 4, y - 2, w + 8, h + 4, c[:outline])
    canvas.fill(x - 2, y - 4, w + 4, h + 8, c[:outline])
    (0...h).step(REGION_SQUARE) do |oy|
      canvas.fill(x, y + oy, w, 8, c[:town])
      canvas.fill(x, y + oy + 8, w, 2, c[:town_mid])
      canvas.fill(x, y + oy + 10, w, 6, c[:town_low])
    end
    # Rounded inner corners
    [[x, y], [x + w - 2, y], [x, y + h - 2], [x + w - 2, y + h - 2]].each do |cx, cy|
      canvas.fill(cx, cy, 2, 2, c[:outline])
    end
  end

  # Closest point of a route's line (axis-aligned pieces) to a point.
  def route_point(line, point)
    return line.each_cons(2).map do |(x1, y1), (x2, y2)|
      [point[0].clamp(*[x1, x2].minmax), point[1].clamp(*[y1, y2].minmax)]
    end.min_by { |px, py| ((px - point[0])**2) + ((py - point[1])**2) }
  end

  # A town of several squares (a mask): the frame around each square, then
  # each square red, so that no frame shows between two squares.
  def paint_town_squares(canvas, boxes)
    c = REGION_COLORS
    boxes.each do |x, y, w, h|
      canvas.fill(x - 4, y - 2, w + 8, h + 4, c[:outline])
      canvas.fill(x - 2, y - 4, w + 4, h + 8, c[:outline])
    end
    boxes.each do |x, y, w, _h|
      canvas.fill(x, y, w, 8, c[:town])
      canvas.fill(x, y + 8, w, 2, c[:town_mid])
      canvas.fill(x, y + 10, w, 6, c[:town_low])
    end
  end

  #-----------------------------------------------------------------------------
  # Minimal RGB canvas saved as PNG
  #-----------------------------------------------------------------------------
  class RegionCanvas
    attr_reader :width, :height

    def initialize(width, height, color)
      @width = width
      @height = height
      @pixels = Array.new(width * height) { color }
    end

    def fill(x, y, w, h, color)
      x0, y0 = [x, 0].max, [y, 0].max
      x1, y1 = [x + w, @width].min, [y + h, @height].min
      (y0...y1).each { |py| (x0...x1).each { |px| @pixels[(py * @width) + px] = color } }
    end

    # Axis-aligned segment of half-width r between two points.
    def segment(x1, y1, x2, y2, r, color)
      left, right = [x1, x2].minmax
      top, bottom = [y1, y2].minmax
      fill(left - r, top - r, right - left + (r * 2), bottom - top + (r * 2), color)
    end

    def save(path)
      raw = "".b
      @height.times do |y|
        raw << "\0"
        raw << @pixels[y * @width, @width].flatten.pack("C*")
      end
      png = "\x89PNG\r\n\x1A\n".b
      png << chunk("IHDR", [@width, @height, 8, 2, 0, 0, 0].pack("NNCCCCC"))
      png << chunk("tEXt", "Software\0MapGen")
      png << chunk("IDAT", Zlib::Deflate.deflate(raw))
      png << chunk("IEND", "")
      File.binwrite(path, png)
    end

    def chunk(type, data)
      data = data.b
      return [data.length].pack("N") + type.b + data + [Zlib.crc32(type + data)].pack("N")
    end
  end
end
