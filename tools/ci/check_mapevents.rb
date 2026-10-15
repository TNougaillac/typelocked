#===============================================================================
# Validates the MapEvents plans with the plugin's own parser, and checks that
# their maps, trainer types, trainers, items and species exist.
#===============================================================================
require_relative "lib/ci"

PLUGIN = File.join(ROOT, "Plugins", "MapEvents")
%w[001_Settings 002_Parser].each { |f| require File.join(PLUGIN, f) }
require File.join(ROOT, "Plugins", "MapGenerator", "001_Settings")
require File.join(ROOT, "Plugins", "MapGenerator", "002_Parser")

# Section IDs of a PBS file ("[POTION]" -> "POTION").
def pbs_ids(base)
  text = CI.read_text(File.join(ROOT, "PBS", "#{base}.txt"))
  return text.scan(/^\[\s*(.+?)\s*\]/).flatten.map { |id| id.split(",").map(&:strip) }
end

items    = pbs_ids("items").map(&:first)
ttypes   = pbs_ids("trainer_types").map(&:first)
trainers = pbs_ids("trainers").map { |t, n, v| [t, n, v.to_i] }
species  = pbs_ids("pokemon").map(&:first)
infos    = load_rxdata(File.join(ROOT, "Data", "MapInfos.rxdata"))
# A plan may target an existing map or one a MapGen plan will create.
names = infos.values.map(&:name) + Dir.glob(File.join(ROOT, MapGenerator::FOLDER, "*.txt")).filter_map do |path|
  CI.read_text(path)[/^\s*Name\s*=\s*(.+?)\s*$/, 1]
end

paths = Dir.glob(File.join(ROOT, MapEvents::FOLDER, "*.txt")).sort
paths.each do |path|
  plan = MapEvents.parse_file(path)
  known = plan.target.is_a?(Integer) ? infos[plan.target] : names.include?(plan.target)
  CI.error(path, nil, "Map = #{plan.target} : cette carte n'existe pas et aucun plan MapGen ne la crée") if !known
  plan.events.each do |entry|
    where = "[#{entry.kind.capitalize} #{entry.label}]"
    %w[Item Gift].each do |key|
      value = entry.value(key)
      CI.error(path, entry.lineno, "#{where} : objet « #{value} » inconnu") if value && !items.include?(value)
    end
    next if entry.kind != :trainer
    type, name = entry.value("Type"), entry.value("Name")
    if !ttypes.include?(type)
      CI.error(path, entry.lineno, "#{where} : type de dresseur « #{type} » inconnu")
    else
      battles = entry.fields.count { |k, _| k == "Battle" }
      battles.times do |i|
        version = entry.value("BattleID").to_i + i
        next if trainers.include?([type, name, version])
        CI.error(path, entry.lineno, "#{where} : dresseur [#{type},#{name}#{version > 0 ? ",#{version}" : ''}] absent de PBS/trainers.txt")
      end
    end
  end
  plan.encounters.each do |line|
    next unless line =~ /\A\d+\s*,\s*(\w+)/
    CI.error(path, nil, "[Encounters] : espèce « #{$1} » inconnue") if !species.include?($1)
  end
rescue MapEvents::Error => e
  CI.error(path, e.message[/\A[^:]*, ligne (\d+) :/, 1]&.to_i, e.message)
end

puts "#{paths.length} plans lus"
CI.finish("Plans MapEvents")
