# Sets the 7 autotile names of a tileset of Data/Tilesets.rxdata (files of
# Graphics/Autotiles, without extension), e.g. the HGSS autotiles of the
# Outside 4G tileset (tools/art/autotiles_4g.py).
# Usage: ruby tools/art/tileset_autotiles.rb ID "Name 1" ... "Name 7"

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

abort "Usage: ruby tools/art/tileset_autotiles.rb ID NAME1 ... NAME7" if ARGV.length != 8
file = "Data/Tilesets.rxdata"
tilesets = Marshal.load(File.binread(file))
tilesets[ARGV[0].to_i].instance_variable_set(:@autotile_names, ARGV[1..])
File.binwrite(file, Marshal.dump(tilesets))
