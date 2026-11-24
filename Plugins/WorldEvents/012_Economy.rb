#===============================================================================
# WorldEvents - Economy (#176): the travelling merchants
#===============================================================================
module WorldEvents
  module_function

  # On MERCHANT_CHANCE % of the stretches (the routes reached with the same
  # seals, zones of ProceduralEncounters), a merchant by the path of one of
  # their routes. [{ map:, seals:, basics: [items], rares: [[item, price]] }].
  def merchant_events(result, atlas, zones, plans, rng)
    zones = zones.to_h { |zone| [zone.name, zone] }
    routes = result.places.select { |wp, *| wp.kind == "route" && zones[wp.name] }.map(&:first).sort_by(&:index)
    merchants = []
    routes.group_by { |wp| zones[wp.name].seals }.sort.each do |seals, stretch|
      next if rng.rand(100) >= MERCHANT_CHANCE
      wp = stretch.sample(random: rng)
      spots = atlas[:maps][wp.name]
      cell = item_cell(spots, npc_cells(spots, rng), plans[wp.name])
      next if !cell
      basics = mart_stock(seals).sample(MERCHANT_BASICS, random: rng)
      table = MERCHANT_RARE_TABLE.select { |from, _items| from <= seals }.values.reduce(:merge)
      rares = table.to_a.sample(MERCHANT_RARES, random: rng)
      x, y, facing = cell
      add(plans, wp.name, "Npc", "Marchand", x, y, ["Graphic", MERCHANT_GRAPHIC], ["Facing", facing],
          ["Script", "WorldEvents.merchant(%i[#{basics.join(' ')}], #{rares.map { |item, price| [item, price] }.inspect})"])
      merchants.push({ map: wp.name, seals: seals, basics: basics, rares: rares })
    end
    return merchants
  end
end
