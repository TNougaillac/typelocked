#===============================================================================
# Prints a fingerprint of the worlds drawn for a few seeds (every place's plan
# and the world plan). Two runs that print the same fingerprint drew the same
# worlds: run it before and after a change of MapProc that must not change
# the worlds (a refactor). WORLD_SEEDS=10 or WORLD_SEEDS=4..8 for other seeds.
#===============================================================================
require "digest"
require_relative "lib/ci"

%w[001_Settings 002_Parser 003_Builder 006_World].each { |f| require File.join(ROOT, "Plugins", "MapGenerator", f) }
require_relative "lib/essentials"
Essentials.load_scripts("Overworld_RandomDungeons")
Dir.glob(File.join(ROOT, "Plugins", "MapProceduralGenerator", "*.rb")).sort.each do |path|
  next if %w[005_Debug 007_NewGame 012_Nooks 014_TerrainTags 015_Tone].include?(File.basename(path, ".rb"))
  require path
end
M = MapProceduralGenerator

seeds = (ENV["WORLD_SEEDS"] || "5").then { |s| s.include?("..") ? Range.new(*s.split("..").map(&:to_i)) : 1..s.to_i }
folder = File.join(ROOT, M::FOLDER)
bricks = Dir.glob(File.join(folder, M::BRICK_FOLDER, "*.txt")).sort.map { |path| M.parse_brick(CI.read_text(path), File.basename(path)) }
all = Digest::SHA256.new
Dir.glob(File.join(folder, "*.txt")).sort.select { |path| M.world_file?(path) }.each do |path|
  world = M.parse_world(CI.read_text(path), File.basename(path))
  town, route = [world.town_file, world.route_file].map { |name| M.parse_place(CI.read_text(File.join(folder, name)), name) }
  names = world.names_file && M.parse_names(CI.read_text(File.join(folder, world.names_file)), world.names_file)
  seeds.each do |seed|
    result = M.generate_world(world, town, route, bricks, seed, {}, names)
    one = Digest::SHA256.new
    one << result.text
    result.places.each { |_wp, _place, text, layout| one << text << layout.levels.to_a.join("\n") << layout.spots.inspect }
    all << one.digest
    puts "#{File.basename(path)} graine #{seed} : #{one.hexdigest[0, 16]}"
  end
end
puts "Empreinte : #{all.hexdigest[0, 16]}"
