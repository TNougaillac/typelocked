#===============================================================================
# ProceduralEncounters - Zones of a generated world
# From MapProceduralGenerator's WorldResult: one zone per town and route that
# has tall grass or water, one per cave. Seals = lieutenants beaten on the way
# there (the chain order); levels climb along the chain. Plain Ruby.
#===============================================================================
module ProceduralEncounters
  WATER_TYPES = %w[Water OldRod GoodRod SuperRod].freeze

  module_function

  # Zones of the world, in the chain's order (each cave after its route).
  def world_zones(result, caps)
    places = result.places.sort_by { |wp, *| wp.index }
    gym_indexes = places.filter_map { |wp, *| wp.index if wp.gym }
    seals = ->(wp) { gym_indexes.count { |i| i < wp.index } }
    surf_town = places.find { |wp, *| wp.surf }&.first
    segments = places.group_by { |wp, *| seals.call(wp) }
    zones = {}
    places.each do |wp, place, text, _layout|
      segment = segments[seals.call(wp)]
      position = segment.index { |other, *| other.equal?(wp) } / [segment.length - 1, 1].max.to_f
      levels = zone_levels(seals.call(wp), position, caps)
      plan = MapGenerator.parse(text, place.file)
      types = []
      types.push("Land") if cells?(plan, GRASS_TILES)
      types.concat(WATER_TYPES) if cells?(plan, WATER_TILES)
      surf = surf_town && wp.index >= surf_town.index
      zones[wp.name] = Zone.new(wp.name, wp.index, seals.call(wp), levels, land_biome(wp, place, plan), types, surf)
    end
    result.caves.each do |wp, name, *|
      route = zones[wp.name]
      zones[name] = Zone.new(name, wp.index, route.seals, route.levels, nil, ["Cave"], route.surf)
    end
    return zones.values.sort_by { |z| [z.index, z.types == ["Cave"] ? 1 : 0] }
  end

  # Does any cell of the map show one of those tiles?
  def cells?(plan, tiles)
    symbols = plan.legend.select { |_c, layers| layers.flatten.intersect?(tiles) }.keys
    return plan.rows.any? { |row| symbols.any? { |c| row.include?(c) } }
  end

  def land_biome(wp, place, plan)
    return EXCESS_BIOMES[wp.excess] if EXCESS_BIOMES[wp.excess]
    return "montagne" if wp.mountain
    return "ville" if wp.kind == "ville"
    ground = (plan.legend[place.ground] || []).flatten
    return ground.filter_map { |tile| GROUND_BIOMES[tile] }.first || "herbe"
  end

  # name => PBS lines of every zone of the world.
  def world_encounters(result, species, caps, seed)
    zones = world_zones(result, caps)
    generated = generate(zones, species, (seed * 1000) + 900)
    lines = zones.to_h { |zone| [zone.name, zone_lines(generated.tables.select { |t| t.zone.equal?(zone) })] }
    return lines, generated
  end
end
