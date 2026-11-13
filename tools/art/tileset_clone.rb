# Copies a tileset of Data/Tilesets.rxdata to another ID, with a new name and
# graphic (passages, priorities, terrain tags and autotiles kept), e.g. the
# Outside 4G tileset (tools/art/outside_4g.py), drawn on the same grid.
# Running it again overwrites the target ID with a fresh copy.
# Usage: ruby tools/art/tileset_clone.rb SOURCE_ID TARGET_ID "Name" "Graphic"

# Loaded and dumped by Marshal as they are (their bytes are kept)
class Table
  def self._load(raw) = allocate.tap { |t| t.instance_variable_set(:@raw, raw) }
  def _dump(_level) = @raw
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
copy = Marshal.load(Marshal.dump(tilesets[ARGV[0].to_i]))
copy.instance_variable_set(:@id, ARGV[1].to_i)
copy.instance_variable_set(:@name, ARGV[2])
copy.instance_variable_set(:@tileset_name, ARGV[3])
tilesets[ARGV[1].to_i] = copy
File.binwrite(file, Marshal.dump(tilesets))
