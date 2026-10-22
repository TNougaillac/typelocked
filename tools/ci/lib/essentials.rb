#===============================================================================
# Loads a few of Essentials' own scripts (from Data/Scripts.rxdata) into the
# CI, with the bare stubs they need, so that plugins built on them can be
# checked with the real code (no game window: nothing is drawn).
#===============================================================================
require "zlib"

module Graphics
  def self.width = 512    # Settings::SCREEN_WIDTH
  def self.height = 384   # Settings::SCREEN_HEIGHT
end

class Game_Map
  TILE_WIDTH = 32
  TILE_HEIGHT = 32
end

module Console
  def self.markup_style(text, **_options) = text
end

module EventHandlers
  def self.add(*_args) = nil
end

module Essentials
  module_function

  # Evaluates the base scripts with these names (e.g. "Overworld_RandomDungeons").
  def load_scripts(*names)
    scripts = File.open(File.join(ROOT, "Data", "Scripts.rxdata"), "rb") { |f| Marshal.load(f) }
    names.each do |name|
      _id, _title, data = scripts.find { |_i, title, _d| title == name } || raise("script #{name} absent de Data/Scripts.rxdata")
      code = Zlib::Inflate.inflate(data).force_encoding("UTF-8")
      TOPLEVEL_BINDING.eval(code, name)
    end
  end
end
