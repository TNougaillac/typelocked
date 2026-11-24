# Writes the Interior Mew tileset and its house rooms (tools/art/interior_mew.py
# gives the JSON on its input): the tileset (passages and priorities of each
# tile, no autotile) and each room as a map of the demo, made from Map006
# (its music, its exit event moved to the room's exit), listed in
# MapInfos.rxdata. Running it again writes them anew.
# Usage: python3 tools/art/interior_mew.py "<Mew sheet>" (runs this script)
require "json"

# A table of Marshal: its sizes and its values (int16)
class Table
  attr_accessor :dims, :data

  def self._load(raw)
    table = allocate
    table.dims = raw[0, 20].unpack("V5")
    table.data = raw[20..].unpack("s*")
    return table
  end

  def self.of(values, xsize, ysize = 1, zsize = 1)
    table = allocate
    table.dims = [(zsize > 1) ? 3 : (ysize > 1) ? 2 : 1, xsize, ysize, zsize, values.length]
    table.data = values
    return table
  end

  def _dump(_level) = dims.pack("V5") + data.pack("s*")
end

class Color
  def self._load(raw) = allocate.tap { |c| c.instance_variable_set(:@raw, raw) }
  def _dump(_level) = @raw
end

class Tone
  def self._load(raw) = allocate.tap { |c| c.instance_variable_set(:@raw, raw) }
  def _dump(_level) = @raw
end

# Loaded by Marshal (their fields are read as instance variables)
module RPG
  %w[Tileset Map MapInfo AudioFile Event MoveRoute MoveCommand EventCommand].each { |n| const_set(n, Class.new) }
  class Event
    Page = Class.new
    class Page
      Condition = Class.new
      Graphic = Class.new
    end
  end
end

spec = JSON.parse($stdin.read)
TEMPLATE = 6   # a house of the demo: its music and its exit event

# The tileset
file = "Data/Tilesets.rxdata"
tilesets = Marshal.load(File.binread(file))
tileset = Marshal.load(Marshal.dump(tilesets[26]))
count = 384 + spec["count"]
tileset.instance_variable_set(:@id, spec["tileset"])
tileset.instance_variable_set(:@name, spec["graphic"])
tileset.instance_variable_set(:@tileset_name, spec["graphic"])
tileset.instance_variable_set(:@autotile_names, [""] * 7)
tileset.instance_variable_set(:@passages, Table.of(([0] * 384) + spec["passages"], count))
tileset.instance_variable_set(:@priorities, Table.of(([0] * 384) + spec["priorities"], count))
tileset.instance_variable_set(:@terrain_tags, Table.of([0] * count, count))
tilesets[spec["tileset"]] = tileset
File.binwrite(file, Marshal.dump(tilesets))

# The rooms
template = Marshal.load(File.binread(format("Data/Map%03d.rxdata", TEMPLATE)))
exit_event = template.instance_variable_get(:@events).values.find { |e| e.instance_variable_get(:@name) == "Exit" }
infos = Marshal.load(File.binread("Data/MapInfos.rxdata"))
spec["rooms"].each do |id, room|
  id = id.to_i
  layers = room["layers"]
  height = layers[0].length
  width = layers[0][0].length
  map = Marshal.load(Marshal.dump(template))
  map.instance_variable_set(:@tileset_id, spec["tileset"])
  map.instance_variable_set(:@width, width)
  map.instance_variable_set(:@height, height)
  map.instance_variable_set(:@data, Table.of(layers.flatten, width, height, 3))
  event = Marshal.load(Marshal.dump(exit_event))
  event.instance_variable_set(:@id, 1)
  event.instance_variable_set(:@x, room["exit"][0])
  event.instance_variable_set(:@y, room["exit"][1])
  map.instance_variable_set(:@events, { 1 => event })
  File.binwrite(format("Data/Map%03d.rxdata", id), Marshal.dump(map))
  info = infos[id] || Marshal.load(Marshal.dump(infos[TEMPLATE])).tap do |i|
    i.instance_variable_set(:@order, infos.values.map { |v| v.instance_variable_get(:@order) }.max + 1)
  end
  info.instance_variable_set(:@name, room["name"])
  info.instance_variable_set(:@parent_id, 0)
  infos[id] = info
end
File.binwrite("Data/MapInfos.rxdata", Marshal.dump(infos))
