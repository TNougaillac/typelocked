#===============================================================================
# WorldEvents - Items found and given
# One draw of items for the whole world: each gets a source (on the ground,
# hidden, given by an inhabitant), its value follows the seals won before its
# map; each nook has its loot. Then the Heart Scales, spread along the way,
# the field items, given in their town once its lieutenant is beaten, and the
# Move Relearners. Plain Ruby.
#===============================================================================
module WorldEvents
  module_function

  # Draws the items of the world into plans. Returns [{ map:, source:, item: }]
  # (source: sol, cache, don, recoin, terrain).
  def item_events(result, atlas, zones, tms, leaders, plans, rng)
    zones = zones.to_h { |zone| [zone.name, zone] }
    used_tms = leaders.filter_map { |leader| leader[:tm]&.first }
    slots = item_slots(result, atlas, zones, rng)
    nooks = nook_slots(result, atlas, zones)
    # The sources: as many gifts as the setting asks, the rest by weight
    counts = source_counts(slots.length)
    sources = counts.flat_map { |source, n| [source] * n }.shuffle(random: rng)
    slots.each_with_index { |slot, i| slot[:source] = sources[i] }
    all = (slots + nooks).sort_by { |slot| [slot[:seals], slot[:index], slot[:map]] }
    all.each do |slot|
      table = (slot[:source] == "recoin") ? NOOK_TABLE : ITEM_TABLE
      slot[:item] = draw_item(table, slot[:seals], tms, used_tms, rng)
    end
    heart_scales(all)
    items = []
    # Gifts first: they need a cell by the street
    all.sort_by { |slot| (slot[:source] == "don") ? 0 : 1 }.each do |slot|
      placed = place_item(plans, atlas[:maps][slot[:map]], slot, rng)
      items.push({ map: slot[:map], source: placed, item: slot[:item] }) if placed
    end
    items.concat(field_item_events(atlas, plans, rng))
    relearner_events(result, atlas, zones, plans, rng)
    return items
  end

  # The slots of the routes, towns, islands and caves: { map:, seals:, index: }
  def item_slots(result, atlas, zones, rng)
    slots = []
    add = ->(name, count) { count.times { slots.push(slot(zones, name)) } if zones[name] }
    result.places.sort_by { |wp, *| wp.index }.each do |wp, *|
      count = (wp.kind == "route") ? (wp.mask ? wp.mask.join.count("1") : wp.w * wp.h).times.sum { rng.rand(ROUTE_ITEMS) } : rng.rand(TOWN_ITEMS)
      add.call(wp.name, count)
    end
    (result.islands || []).each { |wp, *| add.call(wp.name, rng.rand(TOWN_ITEMS)) }
    atlas[:maps].each do |name, spots|
      add.call(name, rng.rand(CAVE_ITEMS)) if spots[:kind] == "grotte" && !spots[:dark]
    end
    return slots
  end

  def slot(zones, name, source = nil)
    zone = zones[name]
    return { map: name, seals: zone.seals, index: zone.index, source: source }
  end

  # The loot of each nook, at the seals it opens with: a pocket or an islet
  # on its map, a dark cave at its far end.
  def nook_slots(result, atlas, zones)
    opened = field_item_seals(atlas)
    slots = []
    places = result.places.map(&:first) + (result.islands || []).map(&:first)
    places.each do |wp|
      spots = atlas[:maps][wp.name]
      next if !spots || !zones[wp.name]
      (spots[:nooks] || []).each do |x, y, kind, *|
        next if kind == "sombre"
        slots.push(nook_slot(zones, wp.name, [x, y], kind, opened))
      end
    end
    result.caves.each do |wp, name, *|
      spots = atlas[:maps][name]
      next if !spots[:dark] || !spots[:loot] || !zones[name]
      slots.push(nook_slot(zones, name, spots[:loot], "sombre", opened).merge(route: wp.name))
    end
    return slots
  end

  def nook_slot(zones, name, cell, kind, opened)
    found = slot(zones, name, "recoin")
    item = MapProceduralGenerator::NOOKS[kind]
    found[:seals] = [found[:seals], opened[item] || 0].max
    return found.merge(cell: cell)
  end

  # Seals won once each field item is given: its town's lieutenant's.
  def field_item_seals(atlas)
    return atlas[:items].to_h do |item, town|
      gym = atlas[:gyms].index(town)
      [item, gym ? gym + 1 : 0]
    end
  end

  # How many of each source among count slots: gifts at least GIFT_SHARE %,
  # the rest by weight.
  def source_counts(count)
    share = [ITEM_SOURCES["don"] * 100 / ITEM_SOURCES.values.sum, GIFT_SHARE].max
    gifts = (count * share / 100.0).ceil
    others = ITEM_SOURCES.reject { |source, _| source == "don" }
    counts = others.to_h { |source, weight| [source, (count - gifts) * weight / others.values.sum] }
    counts[others.keys.last] += count - gifts - counts.values.sum
    return counts.merge("don" => gifts)
  end

  # An item of the table's line for these seals; TM: one not given yet.
  def draw_item(table, seals, tms, used_tms, rng)
    line = table[table.keys.select { |from| from <= seals }.max]
    pick = rng.rand(line.values.sum)
    item = line.find { |_item, weight| (pick -= weight) < 0 }[0]
    return item if item != :TM
    tm = (tms.map(&:first) - used_tms).sample(random: rng)
    return line.keys.find { |other| other != :TM } if !tm
    used_tms.push(tm)
    return tm
  end

  # HEART_SCALES slots evenly spread along the way take a Heart Scale.
  def heart_scales(slots)
    return if slots.empty?
    count = [HEART_SCALES, slots.length].min
    count.times { |i| slots[((i + 0.5) * slots.length / count).floor][:item] = HEART_SCALE }
  end

  # Places one slot on its map: returns its source, nil if no cell is left
  # (a gift falls back to a hidden item when no NPC fits).
  def place_item(plans, spots, slot, rng)
    map = slot[:map]
    taken = plans[map]
    count = taken.count { |*, text| text.start_with?("[Item ", "[Npc Don") } + 1
    if slot[:cell]
      x, y = slot[:cell]
      add(plans, map, "Item", "Recoin#{count}", x, y, ["Item", slot[:item]])
      return "recoin"
    end
    if slot[:source] == "don"
      cell = item_cell(spots, npc_cells(spots, rng), taken)
      if cell
        x, y, facing = cell
        add(plans, map, "Npc", "Don#{count}", x, y, ["Graphic", GIFT_GRAPHICS.sample(random: rng)], ["Facing", facing],
            ["Text", GIFT_TEXTS.sample(random: rng)], ["Gift", slot[:item]], ["Once", GIFT_AFTER.sample(random: rng)])
        return "don"
      end
      slot[:source] = "cache"
    end
    cells = (slot[:source] == "sol") ? (spots[:dead_ends] || []).shuffle(random: rng) : []
    cells += ((spots[:grass] || []) + (spots[:street] || []) + (spots[:floor] || [])).shuffle(random: rng)
    cell = item_cell(spots, cells, taken)
    return nil if !cell
    hidden = slot[:source] == "cache"
    add(plans, map, "Item", "Objet#{count}", cell[0], cell[1], ["Item", slot[:item]], *(hidden ? [["Hidden", "oui"]] : []))
    return slot[:source]
  end

  # Cells for an NPC, [x, y, facing]: by the street, else on a cave floor.
  def npc_cells(spots, rng)
    return facing_cells(spots).shuffle(random: rng) if !facing_cells(spots).empty?
    return (spots[:floor] || []).map { |x, y| [x, y, FACINGS.sample(random: rng)] }.shuffle(random: rng)
  end

  # The first of these cells that is not blocked (blocked_cells), next to
  # another event, nor in a trainer's sight.
  def item_cell(spots, cells, taken)
    blocked = blocked_cells(spots) + sight_cells(taken)
    return cells.find do |x, y, *|
      !blocked.include?([x, y]) && taken.none? { |tx, ty, _text| (tx - x).abs + (ty - y).abs < 2 }
    end
  end

  # The cells the trainers of a map see.
  def sight_cells(taken)
    return taken.flat_map do |x, y, text|
      next [] if !text.start_with?("[Trainer ")
      dx, dy = STEPS[text[/^Facing = (\w+)/, 1]] || [0, 1]
      (1..text[/^Sight = (\d+)/, 1].to_i).map { |i| [x + (dx * i), y + (dy * i)] }
    end
  end

  # Each field item: a member of the Family in its town gives it once the
  # town's lieutenant is beaten (its switch).
  def field_item_events(atlas, plans, rng)
    items = []
    atlas[:items].each_with_index do |(item, town), i|
      spots = atlas[:maps][town]
      next if !spots
      cell = item_cell(spots, npc_cells(spots, rng), plans[town])
      next if !cell
      x, y, facing = cell
      gym = atlas[:gyms].index(town)
      wait = gym ? [["When", "S#{GYM_SWITCH + gym + 1}"], ["Wait", FIELD_WAIT]] : []
      add(plans, town, "Npc", "Terrain#{i + 1}", x, y, ["Graphic", FIELD_GRAPHIC], ["Facing", facing], *wait,
          ["Text", FIELD_GIFT], ["Gift", item], ["Once", FIELD_AFTER])
      items.push({ map: town, source: "terrain", item: item })
    end
    return items
  end

  # A Move Relearner in a town reached with at most each RELEARNERS seals
  # (the town with the most of them; never twice the same).
  def relearner_events(result, atlas, zones, plans, rng)
    towns = result.places.select { |wp, *| wp.kind == "ville" }.map(&:first).sort_by(&:index)
    used = []
    RELEARNERS.each_with_index do |seals, i|
      choices = towns.reject { |wp| used.include?(wp.name) || !zones[wp.name] || zones[wp.name].seals > seals }
      # Not the first town while another one fits: the player has no Pokémon yet
      choices = choices.reject { |wp| wp.name == atlas[:start] } if choices.length > 1
      town = choices.max_by { |wp| [zones[wp.name].seals, -wp.index] }
      next if !town
      cell = item_cell(atlas[:maps][town.name], npc_cells(atlas[:maps][town.name], rng), plans[town.name])
      next if !cell
      used.push(town.name)
      x, y, facing = cell
      add(plans, town.name, "Npc", "MaitreCapacites#{i + 1}", x, y, ["Graphic", RELEARNER_GRAPHIC], ["Facing", facing],
          ["Script", "WorldEvents.relearner"])
    end
  end
end
