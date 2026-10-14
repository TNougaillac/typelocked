#===============================================================================
# Validates the MapGen plans with the plugin's own parser and tile checks,
# against the real tilesets and map tree in Data/.
#===============================================================================
require_relative "lib/ci"

PLUGIN = File.join(ROOT, "Plugins", "MapGenerator")
%w[001_Settings 002_Parser 003_Builder].each { |f| require File.join(PLUGIN, f) }

tilesets = load_rxdata(File.join(ROOT, "Data", "Tilesets.rxdata"))
infos = load_rxdata(File.join(ROOT, "Data", "MapInfos.rxdata"))
paths = Dir.glob(File.join(ROOT, MapGenerator::FOLDER, "*.txt")).sort

plans = paths.filter_map do |path|
  plan = MapGenerator.parse_file(path)
  MapGenerator.check_tiles(plan, tilesets[plan.tileset_id])
  plan
rescue MapGenerator::Error => e
  CI.error(path, e.message[/\A[^:]*, ligne (\d+) :/, 1]&.to_i, e.message)
  nil
end

# A warp may target an existing map or a map another plan will create.
names = infos.values.map(&:name) + plans.map(&:name)
plans.each do |plan|
  path = File.join(ROOT, MapGenerator::FOLDER, plan.file)
  if plan.map_id && !infos[plan.map_id]
    CI.error(path, nil, "MapID = #{plan.map_id} : cette carte n'existe pas dans Data/MapInfos.rxdata")
  end
  if plan.parent_id && plan.parent_id != 0 && !infos[plan.parent_id]
    CI.error(path, nil, "Parent = #{plan.parent_id} : cette carte n'existe pas dans Data/MapInfos.rxdata")
  end
  plan.warps.each do |symbol, warp|
    next if warp.target.is_a?(Integer) ? infos[warp.target] : names.include?(warp.target)
    CI.error(path, nil, "porte « #{symbol} » : la carte « #{warp.target} » n'existe pas et aucun plan ne la crée")
  end
end

puts "#{paths.length} plans lus"
CI.finish("Plans MapGen")
