#===============================================================================
# MapGenerator - Draws the Town Map image of a world plan
# Sea, land around the places, routes as white paths that follow the
# connections, towns as red blocks and other places as orange blocks. The image
# is a plain PNG written with Zlib, and an existing image is only replaced if
# MapGen drew it (it carries a "MapGen" text chunk).
#===============================================================================
module MapGenerator
  REGION_SQUARE = 16            # Town Map square size in pixels (UI_RegionMap)
  REGION_SIZE = [30, 20]        # Default image size in squares (480x320)
  REGION_COLORS = {
    sea:     [80, 184, 216],
    shore:   [56, 160, 184],
    land:    [96, 192, 144],
    outline: [80, 80, 80],
    route:   [248, 248, 248],
    town:    [248, 80, 96],
    place:   [240, 176, 128]
  }

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
    width = [REGION_SIZE[0], plan.origin[0] + plan.rows.map(&:length).max + 1].max * REGION_SQUARE
    height = [REGION_SIZE[1], plan.origin[1] + plan.rows.length + 1].max * REGION_SQUARE
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
    # Land: one square around every place, with a shore line
    plan.places.each_value do |place|
      x, y, w, h = box.call(place)
      canvas.fill(x - sq - 2, y - sq - 2, w + (sq * 2) + 4, h + (sq * 2) + 4, REGION_COLORS[:shore])
    end
    plan.places.each_value do |place|
      x, y, w, h = box.call(place)
      canvas.fill(x - sq, y - sq, w + (sq * 2), h + (sq * 2), REGION_COLORS[:land])
    end
    # Paths: along each route, and from each connection to the places it joins
    segments = []
    center = proc do |place|
      x, y, w, h = box.call(place)
      [x + (w / 2), y + (h / 2)]
    end
    plan.places.each_value do |place|
      next if place_kind(place) != "route"
      x, y, w, h = box.call(place)
      if w >= h
        segments.push([x + (sq / 2), y + (h / 2), x + w - (sq / 2), y + (h / 2)])
      else
        segments.push([x + (w / 2), y + (sq / 2), x + (w / 2), y + h - (sq / 2)])
      end
    end
    links.each do |a, edge, _pa, b, _eb, _pb|
      ax, ay, aw, ah = box.call(a)
      bx, by, bw, bh = box.call(b)
      if edge == "E"
        top = [ay, by].max
        point = [ax + aw, (top + [ay + ah, by + bh].min) / 2]
      else
        left = [ax, bx].max
        point = [(left + [ax + aw, bx + bw].min) / 2, ay + ah]
      end
      [a, b].each do |place|
        # To the route's middle line (or the block's centre), in two straight
        # pieces that leave the edge at a right angle
        target = (place_kind(place) == "route") ? route_point(box.call(place), point) : center.call(place)
        corner = (edge == "E") ? [target[0], point[1]] : [point[0], target[1]]
        segments.push(point + corner, corner + target)
      end
    end
    segments.each { |s| canvas.segment(*s, 4, REGION_COLORS[:outline]) }
    segments.each { |s| canvas.segment(*s, 2, REGION_COLORS[:route]) }
    # Towns and other places on top
    plan.places.each_value do |place|
      kind = place_kind(place)
      next if kind == "route"
      x, y, w, h = box.call(place)
      canvas.fill(x + 1, y + 1, w - 2, h - 2, REGION_COLORS[:outline])
      canvas.fill(x + 3, y + 3, w - 6, h - 6, REGION_COLORS[(kind == "ville") ? :town : :place])
    end
  end

  # Closest point of a route's middle line to a point.
  def route_point(box, point)
    x, y, w, h = box
    half = REGION_SQUARE / 2
    return [point[0].clamp(x + half, x + w - half), y + (h / 2)] if w >= h
    return [x + (w / 2), point[1].clamp(y + half, y + h - half)]
  end

  #-----------------------------------------------------------------------------
  # Minimal RGB canvas saved as PNG
  #-----------------------------------------------------------------------------
  class RegionCanvas
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
