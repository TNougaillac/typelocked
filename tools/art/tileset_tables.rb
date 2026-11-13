# Grows the passages, priorities and terrain tags of a tileset in
# Data/Tilesets.rxdata by COUNT tiles, and gives each new tile the values of
# its source (JSON { "new tile" => source tile, -1 = walkable, nothing else,
# "=<n>" = passages n, no priority nor terrain tag; "=<n>/<t>" = passages n,
# terrain tag t; "A<n>" => "A<m>" = the autotile slot n takes the values of
# the slot m }).
# Tile numbers as in MapGen (T<n>, 384 is added here).
# Usage: ruby tools/art/tileset_tables.rb TILESET_ID COUNT JSON
require "json"

class Table
  attr_accessor :dims, :data

  def self._load(raw)
    table = allocate
    table.dims = raw[0, 20].unpack("V5")
    table.data = raw[20..].unpack("s*")
    return table
  end

  def _dump(_level) = [1, data.length, 1, 1, data.length].pack("V5") + data.pack("s*")
end

class Color
  def self._load(raw) = allocate.tap { |c| c.instance_variable_set(:@raw, raw) }
  def _dump(_level) = @raw
end

class Tone
  def self._load(raw) = allocate.tap { |c| c.instance_variable_set(:@raw, raw) }
  def _dump(_level) = @raw
end

# Loaded by Marshal (its fields are read as instance variables)
module RPG
  Tileset = Class.new
end

file = "Data/Tilesets.rxdata"
tilesets = Marshal.load(File.binread(file))
tileset = tilesets[ARGV[0].to_i]
copies = JSON.parse(ARGV[2])
%i[@passages @priorities @terrain_tags].each do |name|
  table = tileset.instance_variable_get(name)
  table.data.concat([0] * ARGV[1].to_i)
  copies.each do |dest, src|
    # An autotile slot: its 48 tiles take those of another slot
    if dest.start_with?("A")
      48.times { |i| table.data[(dest[1..].to_i * 48) + i] = table.data[(src[1..].to_i * 48) + i] }
      next
    end
    value = if src.to_s.start_with?("=")
              passages, tag = src[1..].split("/").map(&:to_i)
              { :@passages => passages, :@terrain_tags => tag || 0 }.fetch(name, 0)
            elsif src.to_i < 0
              0
            else
              table.data[384 + src.to_i]
            end
    table.data[384 + dest.to_i] = value
  end
end
File.binwrite(file, Marshal.dump(tilesets))
