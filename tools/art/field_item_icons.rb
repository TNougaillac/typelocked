#===============================================================================
# Draws the icons of the field items (FieldItems, F12) in Graphics/Items/:
# 24x24 pixel art doubled to 48x48, like Essentials' icons. Each shape is filled
# with three tones (light on its top-left rim, dark on its bottom-right rim) and
# outlined in Essentials' dark grey; a later shape is drawn over the earlier.
# Usage: ruby tools/art/field_item_icons.rb [output folder]
#===============================================================================
require "zlib"

ROOT = File.expand_path("../..", __dir__)
SIZE = 24
OUTLINE = 0x303030

# Tones: [light, middle, dark]
STEEL  = [0xe8f0f0, 0xa8b4b8, 0x687880].freeze
DARK   = [0x8890a0, 0x586070, 0x383c48].freeze
WOOD   = [0xd8a060, 0xa87030, 0x704010].freeze
LEATHER = [0xc87850, 0x985030, 0x603018].freeze
BRASS  = [0xf8e080, 0xd0a838, 0x886818].freeze
ROPE   = [0xf0e0b0, 0xc8b078, 0x8c7448].freeze
SEA    = [0x90d0f8, 0x4890e0, 0x285898].freeze
SKY    = [0xf8f8f8, 0xc8d8f0, 0x8898c0].freeze
RED    = [0xf07858, 0xc84030, 0x802018].freeze
GLASS  = [0xd8f0ff, 0x88c0e8, 0x4878b0].freeze
GLOW   = [0xfff8c0, 0xf8e070, 0xe0a830].freeze
FLAME  = [0xffffff, 0xf8a838, 0xd85820].freeze

class Icon
  def initialize
    @pixels = Array.new(SIZE) { Array.new(SIZE) }
  end

  # Fills the cells for which the block is true with the tones, outlined.
  def shape(tones, outline: true)
    mask = Array.new(SIZE) { |y| Array.new(SIZE) { |x| yield(x + 0.5, y + 0.5) } }
    inside = ->(x, y) { x >= 0 && y >= 0 && x < SIZE && y < SIZE && mask[y][x] }
    SIZE.times do |y|
      SIZE.times do |x|
        if mask[y][x]
          tone = if !inside.call(x - 1, y) || !inside.call(x, y - 1) then 0
                 elsif !inside.call(x + 1, y) || !inside.call(x, y + 1) then 2
                 else 1
                 end
          @pixels[y][x] = tones[tone]
        elsif outline && [[1, 0], [-1, 0], [0, 1], [0, -1]].any? { |dx, dy| inside.call(x + dx, y + dy) }
          @pixels[y][x] = OUTLINE
        end
      end
    end
  end

  # A segment of the given half-width.
  def bar(tones, ax, ay, bx, by, width, **opts)
    dx, dy = bx - ax, by - ay
    len2 = (dx * dx) + (dy * dy)
    shape(tones, **opts) do |x, y|
      t = (((x - ax) * dx) + ((y - ay) * dy)) / len2
      t = t.clamp(0.0, 1.0)
      ((x - ax - (t * dx))**2) + ((y - ay - (t * dy))**2) <= width * width
    end
  end

  def disc(tones, cx, cy, rx, ry = rx, **opts)
    shape(tones, **opts) { |x, y| (((x - cx) / rx)**2) + (((y - cy) / ry)**2) <= 1 }
  end

  def ring(tones, cx, cy, rx, ry, thickness, **opts)
    shape(tones, **opts) do |x, y|
      d = Math.sqrt((((x - cx) / rx)**2) + (((y - cy) / ry)**2))
      d <= 1 && d >= 1 - (thickness / [rx, ry].min)
    end
  end

  def poly(tones, points, **opts)
    shape(tones, **opts) do |x, y|
      inside = false
      points.each_with_index do |(x1, y1), i|
        x2, y2 = points[i - 1]
        inside = !inside if (y1 > y) != (y2 > y) && x < ((x2 - x1) * (y - y1) / (y2 - y1)) + x1
      end
      inside
    end
  end

  def dot(color, x, y) = @pixels[y][x] = color

  # 48x48 RGBA PNG, each pixel doubled.
  def png
    raw = (0...SIZE * 2).map do |y|
      "\0" + (0...SIZE * 2).map do |x|
        c = @pixels[y / 2][x / 2]
        c ? [c >> 16, (c >> 8) & 0xff, c & 0xff, 255].pack("C4") : "\0\0\0\0"
      end.join
    end.join
    chunk = ->(type, data) { [data.bytesize].pack("N") + type + data + [Zlib.crc32(type + data)].pack("N") }
    return "\x89PNG\r\n\x1a\n".b + chunk.call("IHDR", [SIZE * 2, SIZE * 2, 8, 6, 0, 0, 0].pack("N2C5")) +
           chunk.call("IDAT", Zlib::Deflate.deflate(raw)) + chunk.call("IEND", "")
  end
end

ICONS = {
  # A wide blade, its handle down to the left
  "MACHETE" => lambda do |i|
    i.poly(STEEL, [[7.5, 16.5], [17, 5], [20.5, 3], [21, 5.5], [19.5, 9], [10, 19]])
    i.bar(DARK, 6, 14, 11, 19, 1.1)
    i.bar(WOOD, 3, 21, 7.5, 16.5, 1.6)
  end,
  # Steel head curved over a wooden handle
  "PICKAXE" => lambda do |i|
    i.bar(WOOD, 4, 21, 14, 8, 1.4)
    i.poly(STEEL, [[3, 6], [9, 3], [15, 3], [20, 6], [22, 11], [21.5, 15], [19.5, 11], [16, 8], [11, 7], [6, 7.5]])
  end,
  # A leather loop, its brass buckle and a strap
  "HARNESS" => lambda do |i|
    i.ring(LEATHER, 12, 11, 9.5, 7.5, 3)
    i.bar(LEATHER, 9, 17, 6, 22, 1.6)
    i.poly(BRASS, [[8, 14.5], [16, 14.5], [16, 20.5], [8, 20.5]])
    i.poly(LEATHER, [[10, 16.5], [14, 16.5], [14, 18.5], [10, 18.5]])
  end,
  # A saddle on a sea-blue blanket
  "SURFSADDLE" => lambda do |i|
    i.poly(SEA, [[3, 12], [21, 12], [21, 19], [17, 21], [7, 21], [3, 19]])
    i.poly(LEATHER, [[4, 12], [5, 8], [5.5, 4], [8, 4], [8.5, 8], [11, 10], [16, 10], [19, 8], [21, 6.5], [22, 8.5], [20.5, 12], [17, 14.5], [7, 14.5]])
    i.bar(STEEL, 12, 15, 12, 20, 0.6, outline: false)
    i.disc(STEEL, 12, 20.5, 2, 1.2)
    [[5, 18], [6, 17], [7, 18], [16, 18], [17, 17], [18, 18]].each { |x, y| i.dot(0xf8f8f8, x, y) }
  end,
  # Three steel hooks and a coil of rope
  "GRAPPLINGHOOK" => lambda do |i|
    i.ring(ROPE, 7, 18, 5, 4, 1.8)
    i.bar(ROPE, 11, 15, 14, 5, 0.9)
    i.ring(STEEL, 15, 4, 2.2, 2.2, 1.2)
    i.bar(STEEL, 15, 6, 15, 16, 1.2)
    i.poly(STEEL, [[9, 9], [11, 12], [14, 16], [16, 16], [19, 12], [21, 9], [21.5, 13], [18, 18], [12, 18], [8.5, 13]])
    i.poly(STEEL, [[9, 9], [7.5, 11], [9.5, 11.5]])
    i.poly(STEEL, [[21, 9], [22.5, 11], [20.5, 11.5]])
  end,
  # A brass diving helmet with its round window
  "DIVINGSUIT" => lambda do |i|
    i.poly(BRASS, [[4, 17], [20, 17], [21, 22], [3, 22]])
    i.disc(BRASS, 12, 10, 8.5, 8)
    i.disc(DARK, 12, 10, 4.5)
    i.disc(GLASS, 12, 10, 3.5, outline: false)
    [[10, 8], [11, 8], [10, 9]].each { |x, y| i.dot(0xffffff, x, y) }
    [[5, 19], [12, 20], [18, 19], [5, 9], [19, 9]].each { |x, y| i.dot(OUTLINE, x, y) }
  end,
  # A saddle on a white blanket with wings
  "FLYINGSADDLE" => lambda do |i|
    i.poly(RED, [[4, 12], [20, 12], [20, 19], [17, 21], [7, 21], [4, 19]])
    i.poly(LEATHER, [[4, 12], [5, 8], [5.5, 4], [8, 4], [8.5, 8], [11, 10], [16, 10], [19, 8], [21, 6.5], [22, 8.5], [20.5, 12], [17, 14.5], [7, 14.5]])
    i.bar(STEEL, 12, 15, 12, 20, 0.6, outline: false)
    i.disc(STEEL, 12, 20.5, 2, 1.2)
    i.poly(SKY, [[0.5, 7], [4, 9], [7, 14], [5, 18], [2, 16], [0.5, 12]])
    i.poly(SKY, [[23.5, 7], [20, 9], [17, 14], [19, 18], [22, 16], [23.5, 12]])
  end,
  # A lantern: handle, cap, glowing glass and flame, base
  "LANTERN" => lambda do |i|
    i.ring(DARK, 12, 5, 4, 3.5, 1.2)
    i.poly(GLOW, [[7, 9], [17, 9], [17.5, 18], [6.5, 18]])
    i.disc(FLAME, 12, 14.5, 1.6, 2.6, outline: false)
    i.bar(DARK, 8, 9, 8, 18, 0.5, outline: false)
    i.bar(DARK, 16, 9, 16, 18, 0.5, outline: false)
    i.poly(DARK, [[6, 6.5], [18, 6.5], [19, 9.5], [5, 9.5]])
    i.poly(DARK, [[5, 18], [19, 18], [19, 21], [5, 21]])
  end
}.freeze

out = ARGV[0] || File.join(ROOT, "Graphics", "Items")
ICONS.each do |name, draw|
  icon = Icon.new
  draw.call(icon)
  File.binwrite(File.join(out, "#{name}.png"), icon.png)
end
puts "#{ICONS.length} icônes écrites dans #{out}"
