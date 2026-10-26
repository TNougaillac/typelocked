#===============================================================================
# Assembles a MapProc place with the plugin, outside the game, and writes its
# tile layers as JSON for tools/mapproc/render.py (to look at a seed).
# Usage: ruby tools/mapproc/dump_place.rb ville|route SEED [AMBIANCE] [key=value...] > out.json
#   key=value sets a field of the place first (ex. mountain=true, width=40).
#===============================================================================
require "json"
require "zlib"
ROOT = File.expand_path("../..", __dir__)

# Map data as MapGen builds it
class Table
  attr_reader :xsize, :ysize, :zsize

  def initialize(x, y = 1, z = 1)
    @xsize, @ysize, @zsize = x, y, z
    @data = Array.new(x * y * z, 0)
  end

  def [](x, y = 0, z = 0) = @data[x + (y * @xsize) + (z * @xsize * @ysize)]
  def []=(x, y, z, v)
    @data[x + (y * @xsize) + (z * @xsize * @ysize)] = v
  end
end

module Graphics
  def self.width = 512
  def self.height = 384
end

class Game_Map
  TILE_WIDTH = 32
  TILE_HEIGHT = 32
end

module EventHandlers
  def self.add(*_args) = nil
end

# Essentials' TileDrawingHelper (its autotile tables; nothing is drawn)
scripts = File.open(File.join(ROOT, "Data", "Scripts.rxdata"), "rb") { |f| Marshal.load(f) }
TOPLEVEL_BINDING.eval(Zlib::Inflate.inflate(scripts.find { |_i, title, _d| title == "TileDrawingHelper" }[2]).force_encoding("UTF-8"))
%w[001_Settings 002_Parser 003_Builder].each { |f| require File.join(ROOT, "Plugins", "MapGenerator", f) }
%w[001_Settings 002_Parser 003_Builder].each { |f| require File.join(ROOT, "Plugins", "MapProceduralGenerator", f) }
M = MapProceduralGenerator

kind, seed, ambiance, *sets = ARGV.map { |a| a.dup.force_encoding("UTF-8") }
read = ->(path) { File.read(path, encoding: "UTF-8").sub(/\A﻿/, "") }
folder = File.join(ROOT, M::FOLDER)
bricks = Dir.glob(File.join(folder, M::BRICK_FOLDER, "*.txt")).sort.map { |path| M.parse_brick(read.call(path), File.basename(path)) }
place = M.parse_place(read.call(File.join(folder, "#{kind}.txt")), "#{kind}.txt")
place.ambiance = ambiance if ambiance && ambiance != "-"
sets.each do |set|
  key, value = set.split("=", 2)
  value = { "true" => true, "false" => false }.fetch(value) { value =~ /\A\d+\z/ ? value.to_i : value }
  place.send("#{key}=", value)
end
plan, _text, layout = M.generate_place(place, bricks, seed.to_i)
data = MapGenerator.build_data(plan)
layers = Array.new(3) { |z| Array.new(data.ysize) { |y| Array.new(data.xsize) { |x| data[x, y, z] } } }
puts JSON.generate({ tileset: plan.tileset_id, ambiance: layout.ambiance, rows: layout.rows, layers: layers })
