#===============================================================================
# Writes Data/PluginScripts.rxdata like a debug launch of the game does, so the
# game also loads its plugins when started without debug mode (JoiPlay, a plain
# Game.exe). Runs Essentials' own PluginManager code, read from
# Data/Scripts.rxdata, so the load order and format stay those of the engine.
#
#   ruby tools/build/compile_plugins.rb
#===============================================================================
require "zlib"

ROOT = File.expand_path("../..", __dir__)
# Script sections needed by PluginManager.getPluginOrder and .compilePlugins:
# Array#swap, Dir.get/all/safe?, Compiler.pbCompilerEachPreppedLine.
SECTIONS = %w[RubyUtilities FileTests Compiler PluginManager].freeze

# Engine parts these sections touch, outside a running game
$DEBUG = true
def _INTL(*args)
  args[1..].each_with_index.reduce(args[0].dup) { |str, (arg, i)| str.gsub("{#{i + 1}}", arg.to_s) }
end

module Console
  def self.method_missing(*); end
  def self.respond_to_missing?(*) = true
end

Dir.chdir(ROOT) do
  sections = Marshal.load(File.binread("Data/Scripts.rxdata")).to_h do |_id, name, code|
    [name, Zlib::Inflate.inflate(code).force_encoding(Encoding::UTF_8)]
  end
  SECTIONS.each do |name|
    abort("Section #{name} absente de Data/Scripts.rxdata") unless sections[name]
    eval(sections[name], TOPLEVEL_BINDING, name)
  end
  PluginManager.define_singleton_method(:error) { |msg| abort(msg) }

  order, plugins = PluginManager.getPluginOrder
  PluginManager.compilePlugins(order, plugins)
  puts "Data/PluginScripts.rxdata : #{order.length} plugins (#{order.join(', ')})"
end
