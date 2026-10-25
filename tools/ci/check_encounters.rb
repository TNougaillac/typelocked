#===============================================================================
# Generates the wild encounters of each MapProc world with a few seeds
# (plugin ProceduralEncounters) and checks them: PBS lines, levels, percents,
# every type catchable between two lieutenants, every family drawn for the world
# somewhere.
#===============================================================================
require_relative "lib/ci"

%w[001_Settings 002_Parser 003_Builder].each { |f| require File.join(ROOT, "Plugins", "MapGenerator", f) }
%w[001_Settings 002_Parser 003_Builder 004_World 006_Caves 011_Interiors].each { |f| require File.join(ROOT, "Plugins", "MapProceduralGenerator", f) }
%w[001_Settings 002_Species 003_Tables 004_World].each { |f| require File.join(ROOT, "Plugins", "ProceduralEncounters", f) }
M = MapProceduralGenerator
E = ProceduralEncounters
SEEDS = 1..3
LINE = /\A    (\d+),(\w+),(\d+)(?:,(\d+))?\z/

species = E.load_species(ROOT)
folder = File.join(ROOT, M::FOLDER)
bricks = Dir.glob(File.join(folder, M::BRICK_FOLDER, "*.txt")).sort.map do |path|
  M.parse_brick(CI.read_text(path), File.basename(path))
end
Dir.glob(File.join(folder, "*.txt")).sort.select { |path| M.world_file?(path) }.each do |path|
  world = M.parse_world(CI.read_text(path), File.basename(path))
  town, route = [world.town_file, world.route_file].map do |name|
    M.parse_place(CI.read_text(File.join(folder, name)), name)
  end
  # Each ambiance biome names an ambiance of the route file and a biome
  settings = File.join(ROOT, "Plugins/ProceduralEncounters/001_Settings.rb")
  E::AMBIANCE_BIOMES.each do |name, biome|
    CI.error(settings, nil, "AMBIANCE_BIOMES : ambiance « #{name} » absente de #{world.route_file}") if route.ambiances.none? { |a| a.name == name }
    CI.error(settings, nil, "AMBIANCE_BIOMES : biome « #{biome} » absent de BIOMES") if !E::BIOMES.key?(biome)
  end
  SEEDS.each do |seed|
    where = "#{File.basename(path)} (graine #{seed})"
    result = M.generate_world(world, town, route, bricks, seed)
    lines, generated = E.world_encounters(result, species, E::CAPS, seed)
    # A route off the chain has the seals and levels of the place of its tier
    zones = E.world_zones(result, E::CAPS).to_h { |zone| [zone.name, zone] }
    result.places.each do |wp, *|
      next if !wp.extra
      tier = result.places.find { |other, *| other.index == wp.tier && !other.extra }[0]
      zone, at = zones[wp.name], zones[tier.name]
      next if zone.seals == at.seals && zone.levels == at.levels
      CI.error(path, nil, "#{where}, #{wp.name} : rencontres hors du palier #{tier.name}")
    end
    lines.each do |name, body|
      total = nil
      check_total = lambda do
        CI.error(path, nil, "#{where}, #{name} : pourcentages à #{total} au lieu de 100") if total && total != 100
      end
      body.each do |line|
        if E::TABLES.key?(line[/\A\w+/])
          check_total.call
          total = 0
          next
        end
        m = LINE.match(line)
        if !m
          CI.error(path, nil, "#{where}, #{name} : ligne « #{line} » invalide")
          next
        end
        pct, id, min, max = m[1].to_i, m[2].to_sym, m[3].to_i, (m[4] || m[3]).to_i
        total += pct
        CI.error(path, nil, "#{where}, #{name} : #{id} hors de la liste") if !species[id]
        CI.error(path, nil, "#{where}, #{name} : #{id} à 0 %") if pct < 1
        CI.error(path, nil, "#{where}, #{name} : #{id} niveaux #{min},#{max} invalides") if min < 1 || max > 100 || min > max
      end
      check_total.call
    end
    generated.gaps.each do |seals, type|
      CI.error(path, nil, "#{where} : aucun Pokémon #{type} capturable avec #{seals} sceau(x)")
    end
    generated.missing.each { |family| CI.error(path, nil, "#{where} : famille #{family} absente du monde") }
  end
rescue M::Error, MapGenerator::Error => e
  CI.error(path, nil, e.message)
end

CI.finish("Rencontres générées")
