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
  # (source: sol, cache, don, recoin, terrain; a nook holding a Pokémon has
  # pokemon: [species, level] and no item). weather: see weather_items.
  # pact: how many Pact Incenses. revisit: { species:, type:, caps:, rng: }
  # for the Pokémon and the lore of the nooks to come back to (none without).
  def item_events(result, atlas, zones, tms, leaders, weather, plans, lines, rng, pact = 0, revisit = nil)
    zones = zones.to_h { |zone| [zone.name, zone] }
    used_tms = leaders.filter_map { |leader| leader[:tm]&.first }
    weather -= used_tms
    used_tms += weather
    slots = item_slots(result, atlas, zones, rng)
    nooks = nook_slots(result, atlas, zones)
    # The sources: as many gifts as the setting asks, the rest by weight
    counts = source_counts(slots.length)
    sources = counts.flat_map { |source, n| [source] * n }.shuffle(random: rng)
    slots.each_with_index { |slot, i| slot[:source] = sources[i] }
    all = (slots + nooks).sort_by { |slot| [slot[:seals], slot[:index], slot[:map]] }
    all.each do |slot|
      table = slot[:revisit] ? REVISIT_TABLE : ((slot[:source] == "recoin") ? NOOK_TABLE : ITEM_TABLE)
      slot[:item] = draw_item(table, slot[:seals], tms, used_tms, rng)
    end
    heart_scales(all.reject { |slot| slot[:revisit] })
    weather_nooks(all, weather)
    pact_incenses(all, weather, pact)
    revisit_loot(all, zones, revisit) if revisit
    items = []
    # Gifts first: they need a cell by the street
    all.sort_by { |slot| (slot[:source] == "don") ? 0 : 1 }.each do |slot|
      placed = place_item(plans, atlas[:maps][slot[:map]], slot, lines, rng)
      next if !placed
      item = { map: slot[:map], source: placed, item: slot[:pokemon] ? nil : slot[:item] }
      item[:pokemon] = slot[:pokemon] if slot[:pokemon]
      item[:revisit] = true if slot[:revisit]
      items.push(item)
    end
    items.concat(field_item_events(atlas, plans, lines, rng))
    relearner_events(result, atlas, zones, plans, rng)
    return items
  end

  # The slots of the routes, towns, islands and caves: { map:, seals:, index: }
  def item_slots(result, atlas, zones, rng)
    slots = []
    add = ->(name, count) { count.times { slots.push(slot(zones, name)) } if zones[name] }
    result.places.sort_by { |wp, *| wp.index }.each do |wp, *|
      cells = (wp.mask ? wp.mask.join.count("1") : wp.w * wp.h)
      # A sea route's beaches hold its trainers: its items are the loot of
      # its sandbanks
      cells = 0 if wp.crossing == "mer"
      count = (wp.kind == "route") ? cells.times.sum { rng.rand(ROUTE_ITEMS) } : rng.rand(TOWN_ITEMS)
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
  # on its map, a dark cave at its far end; and of each hill top.
  def nook_slots(result, atlas, zones)
    opened = field_item_seals(atlas, zones)
    slots = []
    places = result.places.map(&:first) + (result.islands || []).map(&:first)
    places.each do |wp|
      spots = atlas[:maps][wp.name]
      next if !spots || !zones[wp.name]
      (spots[:nooks] || []).each do |x, y, kind, *|
        next if kind == "sombre"
        slots.push(nook_slot(zones, wp.name, [x, y], kind, opened))
      end
      # The top of a hill: a loot for whoever climbs it
      (spots[:hill_tops] || []).each { |cell| slots.push(nook_slot(zones, wp.name, cell, nil, opened)) }
    end
    result.caves.each do |wp, name, *|
      spots = atlas[:maps][name]
      next if !spots[:dark] || !spots[:loot] || !zones[name]
      slots.push(nook_slot(zones, name, spots[:loot], "sombre", opened).merge(route: wp.name))
    end
    return slots
  end

  # A nook whose field item is given after its map's seals is one to come
  # back to (revisit).
  def nook_slot(zones, name, cell, kind, opened)
    found = slot(zones, name, "recoin")
    item = MapProceduralGenerator::NOOKS[kind]
    found[:revisit] = true if opened[item].to_i > found[:seals]
    found[:seals] = [found[:seals], opened[item] || 0].max
    return found.merge(cell: cell)
  end

  # The nooks to come back to (#269): a Pokémon of the imposed type for REVISIT_POKEMON % of them, a trace of
  # the Pact before the item for REVISIT_LORE % of the others.
  def revisit_loot(slots, zones, revisit)
    rng = revisit[:rng]
    typed = (revisit[:species] || {}).values.select do |sp|
      revisit[:type] && sp.monotype_types.include?(revisit[:type]) && REVISIT_TIERS.include?(sp.tier)
    end
    slots.each do |slot|
      next if !slot[:revisit]
      if rng.rand(100) < REVISIT_POKEMON && !typed.empty?
        level = revisit_level(zones, slot[:seals], revisit[:caps])
        slot[:pokemon] = pool_party(revisit[:species], typed, 1, level, level, slot[:seals], rng)[0]
      elsif rng.rand(100) < REVISIT_LORE
        slot[:lore] = true
      end
    end
  end

  # Level of a Pokémon found in a nook opened with that many seals: the top
  # of the wild Pokémon of that Tronçon, under the cap.
  def revisit_level(zones, seals, caps)
    tops = zones.values.select { |zone| zone.seals == seals }.map { |zone| zone.levels[1] }
    top = tops.max || zones.values.map { |zone| zone.levels[1] }.max
    return caps ? [top, caps[seals] || caps.last].min : top
  end

  # Seals won once each field item is given: its town's lieutenant's; for
  # one given outside the gyms (the Skates, #270), the seals on the way to
  # its town.
  def field_item_seals(atlas, zones = {})
    return atlas[:items].to_h do |item, town|
      next [item, zones[town]&.seals || 0] if extra_field_item?(item)
      gym = atlas[:gyms].index(town)
      [item, gym ? gym + 1 : 0]
    end
  end

  def extra_field_item?(item)
    return MapProceduralGenerator::EXTRA_FIELD_ITEMS.key?(item)
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

  # The weather items of the imposed type (WEATHER_ITEMS), in WEATHER_CHANCE %
  # of the games; else none.
  def weather_items(type, rng)
    items = WEATHER_ITEMS.find { |types, _items| types.include?(type) }&.last
    return [] if !items || rng.rand(100) >= WEATHER_CHANCE
    return items.dup
  end

  # The weather items go to nooks evenly spread along the way (at most half
  # of them, so the nooks keep some rare loot; never one to come back to,
  # which keeps its own), the rest to other slots, in place of their item
  # (never of a Heart Scale).
  def weather_nooks(slots, weather)
    nooks = slots.select { |slot| slot[:source] == "recoin" && !slot[:revisit] && slot[:item] != HEART_SCALE }
    others = slots.select { |slot| slot[:source] != "recoin" && !slot[:revisit] && slot[:item] != HEART_SCALE }
    in_nooks = [weather.length, (nooks.length + 1) / 2].min
    spread(nooks, weather.first(in_nooks))
    spread(others, weather.drop(in_nooks))
  end

  # The Pact Incenses go to nooks and gifts evenly spread along the way, in
  # place of their item (never of a Heart Scale nor of a weather item, nor in
  # a nook to come back to).
  def pact_incenses(slots, weather, count)
    spots = slots.select do |slot|
      %w[recoin don].include?(slot[:source]) && !slot[:revisit] && slot[:item] != HEART_SCALE && !weather.include?(slot[:item])
    end
    spread(spots, [PACT_INCENSE] * count)
  end

  # Items evenly spread over these slots.
  def spread(slots, items)
    count = [items.length, slots.length].min
    count.times { |i| slots[((i + 0.5) * slots.length / count).floor][:item] = items[i] }
  end

  # Places one slot on its map: returns its source, nil if no cell is left
  # (a gift falls back to a hidden item when no NPC fits).
  def place_item(plans, spots, slot, lines, rng)
    map = slot[:map]
    taken = plans[map]
    count = taken.count { |*, text| text.start_with?("[Item ", "[Npc Don") } + 1
    if slot[:cell]
      x, y = slot[:cell]
      if slot[:pokemon]
        species, level = slot[:pokemon]
        add(plans, map, "Npc", "Recoin#{count}", x, y, ["Graphic", NOOK_GRAPHIC], *texts(lines, "recoin_pokemon", "Text", spots[:title]),
            ["Script", "pbSetSelfSwitch(@event_id, \"A\", true) if WorldEvents.nook_pokemon(:#{species}, #{level})"], ["Hide", "A"])
      elsif slot[:lore]
        add(plans, map, "Npc", "Recoin#{count}", x, y, ["Graphic", NOOK_GRAPHIC], *texts(lines, "recoin_lore", "Text", spots[:title]),
            ["Script", "pbSetSelfSwitch(@event_id, \"A\", true) if pbItemBall(:#{slot[:item]})"], ["Hide", "A"])
      else
        add(plans, map, "Item", "Recoin#{count}", x, y, ["Item", slot[:item]])
      end
      return "recoin"
    end
    if slot[:source] == "don"
      cell = item_cell(spots, npc_cells(spots, rng), taken)
      if cell
        x, y, facing = cell
        add(plans, map, "Npc", "Don#{count}", x, y, ["Graphic", GIFT_GRAPHICS.sample(random: rng)], ["Facing", facing],
            *texts(lines, "don", "Text", spots[:title]), ["Gift", slot[:item]], *texts(lines, "don_apres", "Once", spots[:title]))
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

  # A line of that section as [key, box] pairs, one per message box.
  def texts(lines, section, key, town)
    return lines.boxes(section, town).map { |box| [key, box] }
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
  # town's lieutenant is beaten (its switch). One obtained outside the gyms
  # (the Skates, #270): a hidden inhabitant gives it at once.
  def field_item_events(atlas, plans, lines, rng)
    items = []
    atlas[:items].each_with_index do |(item, town), i|
      spots = atlas[:maps][town]
      next if !spots
      if extra_field_item?(item)
        items.push({ map: town, source: "cache_terrain", item: item }) if hidden_giver(spots, item, i, town, plans, lines, rng)
        next
      end
      cell = item_cell(spots, npc_cells(spots, rng), plans[town])
      next if !cell
      x, y, facing = cell
      gym = atlas[:gyms].index(town)
      wait = gym ? [["When", "S#{GYM_SWITCH + gym + 1}"], *texts(lines, "terrain_attente", "Wait", spots[:title])] : []
      add(plans, town, "Npc", "Terrain#{i + 1}", x, y, ["Graphic", FIELD_GRAPHIC], ["Facing", facing], *wait,
          *texts(lines, "terrain_don", "Text", spots[:title]), ["Gift", item],
          *texts(lines, "terrain_apres", "Once", spots[:title]))
      items.push({ map: town, source: "terrain", item: item })
    end
    return items
  end

  # A hidden inhabitant who gives that field item: on the cell by a street
  # farthest from the town's Pokémon Centre (a dead end first).
  def hidden_giver(spots, item, index, town, plans, lines, rng)
    door = (spots[:doors] || []).find { |_x, _y, kind| kind == "centre" } || spots[:exits]&.first&.drop(1) || [0, 0]
    cells = npc_cells(spots, rng).sort_by { |x, y, _facing| [-((x - door[0]).abs + (y - door[1]).abs), y, x] }
    cell = item_cell(spots, cells, plans[town])
    return false if !cell
    x, y, facing = cell
    add(plans, town, "Npc", "Terrain#{index + 1}", x, y, ["Graphic", HIDDEN_GIVER_GRAPHIC], ["Facing", facing],
        *texts(lines, "terrain_cache", "Text", spots[:title]), ["Gift", item],
        *texts(lines, "terrain_cache_apres", "Once", spots[:title]))
    return true
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
