#===============================================================================
# ProceduralEncounters - Zones of a generated world
# From MapProceduralGenerator's WorldResult: one zone per town and route that
# has tall grass or water, one per cave, one per island. Seals = lieutenants
# beaten on the way there (the chain order); levels climb along the chain.
# Plain Ruby.
#===============================================================================
module ProceduralEncounters
  WATER_TYPES = %w[Water OldRod GoodRod SuperRod].freeze

  module_function

  # Zones of the world, in the chain's order (each cave after its route). A
  # route off the chain (a loop, a shortcut) takes the seals and levels of
  # the place of its tier, where it can first be walked. pools: { guild
  # headquarters (MapProc GUILD_HQS) => species ids }: the place of that
  # headquarters (its dungeon) draws its encounters from them.
  def world_zones(result, caps, pools = {})
    places, extras = result.places.sort_by { |wp, *| wp.index }.partition { |wp, *| !wp.extra }
    # An island's gym counts at the place of its port
    gym_indexes = places.filter_map { |wp, *| wp.index if wp.gym } +
                  (result.islands || []).filter_map { |wp, *| wp.index if wp.gym }
    seals = ->(wp) { gym_indexes.count { |i| i < wp.index } }
    surf_town = places.find { |wp, *| wp.surf }&.first
    segments = places.group_by { |wp, *| seals.call(wp) }
    zones = {}
    places.each do |wp, _place, _text, layout|
      segment = segments[seals.call(wp)]
      position = segment.index { |other, *| other.equal?(wp) } / [segment.length - 1, 1].max.to_f
      levels = zone_levels(seals.call(wp), position, caps)
      types = map_types(layout.plan)
      surf = surf_town && wp.index >= surf_town.index
      zones[wp.name] = Zone.new(wp.name, wp.index, seals.call(wp), levels, land_biome(wp, layout), types, surf)
    end
    extras.each do |wp, _place, _text, layout|
      types = map_types(layout.plan)
      tier = zones[places.find { |other, *| other.index == wp.tier }[0].name]
      pool = pools[(result.hqs || {}).key(wp.name)]
      zones[wp.name] = Zone.new(wp.name, wp.tier, tier.seals, tier.levels, land_biome(wp, layout), types, tier.surf, pool)
    end
    result.caves.each do |wp, name, _text, floor|
      # A gym's interior (#121): no wild Pokémon
      next if floor.guild == MapProceduralGenerator::GYM
      route = zones[wp.name]
      # A guild's dungeon (#337) draws from the pool of its headquarters' place
      zones[name] = Zone.new(name, wp.index, route.seals, route.levels, nil, ["Cave"], route.surf, route.pool)
    end
    # An island by boat: the seals and levels of its port
    (result.islands || []).each do |wp, port, _place, _text, layout|
      types = map_types(layout.plan)
      town = zones[port.name]
      zones[wp.name] = Zone.new(wp.name, wp.index, town.seals, town.levels, land_biome(wp, layout), types, town.surf)
    end
    return zones.values.sort_by { |z| [z.index, z.types == ["Cave"] ? 1 : 0] }
  end

  # Encounter types of a map: grass, water (its plan as made, #345).
  def map_types(plan)
    types = []
    types.push("Land") if cells?(plan, GRASS_TILES)
    types.concat(WATER_TYPES) if cells?(plan, WATER_TILES)
    return types
  end

  # Does any cell of the map show one of those tiles?
  def cells?(plan, tiles)
    symbols = plan.legend.select { |_c, layers| layers.flatten.intersect?(tiles) }.keys
    return plan.rows.any? { |row| symbols.any? { |c| row.include?(c) } }
  end

  def land_biome(wp, layout)
    return EXCESS_BIOMES[wp.excess] if EXCESS_BIOMES[wp.excess]
    return "montagne" if MapProceduralGenerator.mountain_tables?(wp, layout)
    return "ville" if wp.kind == "ville"
    return AMBIANCE_BIOMES[layout.ambiance] || "herbe"
  end

  # name => PBS lines of every zone of the world, from the Pokémon drawn for
  # it among the roster (species). pools: see world_zones.
  def world_encounters(result, species, caps, seed, pools = {})
    zones = world_zones(result, caps, pools)
    generated = generate(zones, world_species(species, (seed * 1000) + 901), (seed * 1000) + 900, species)
    lines = zones.to_h { |zone| [zone.name, zone_lines(generated.tables.select { |t| t.zone.equal?(zone) })] }
    return lines, generated
  end
end
