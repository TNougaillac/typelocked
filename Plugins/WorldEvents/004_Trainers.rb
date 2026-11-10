#===============================================================================
# WorldEvents - Trainers and Cousins
# Trainers on the routes and in the caves, Cousins of the Family on some
# routes and in the towns. Each one's team is drawn among the wild Pokémon of
# its zone (ProceduralEncounters), at the top of the zone's levels, and goes
# into PBS/trainers.txt with the world. Plain Ruby.
#===============================================================================
module WorldEvents
  module_function

  # Draws the trainers of the world: their events into plans, their teams
  # (sections of PBS/trainers.txt) into trainers. guilds: { route => [Guild] }
  # (guild_routes), species: the roster, for the members of the guilds on
  # the routes (#184). Returns those members: [{ id:, map:, label:, team: }].
  # freed: { map => game switch } (guild_liberations): the Cousins of these
  # maps are gone once the switch is on (#187).
  def trainer_events(result, atlas, zones, encounters, plans, trainers, names, lines, rng, guilds = {}, species = nil,
                     freed = {})
    zones = zones.to_h { |zone| [zone.name, zone] }
    pools = zone_pools(zones, encounters)
    members = []
    draw = lambda do |map, cells, types, count, cousin_chance|
      zone = zones[map]
      return if !zone || !pools[map]
      count.times do
        cell = trainer_cell(atlas[:maps][map], cells, plans[map], rng)
        break if !cell
        cousin = rng.rand(100) < cousin_chance
        town = atlas[:maps][map][:title]
        # About one trainer in three of a route of a guild's is its member
        guild = guilds[map]&.sample(random: rng) if !cousin && species
        if guild && rng.rand(100) < GUILD_ROUTE_CHANCE
          member = route_member(plans, trainers, names, map, cell, guild, zone, species, [lines, town], rng)
          members.push(member) if member
          next
        end
        type = (cousin ? COUSIN_TYPES : types).sample(random: rng)
        vanish = (cousin && freed[map]) ? [["VanishIfSwitch", freed[map]]] : []
        add_trainer(plans, trainers, names, map, cell, type, zone, pools[map], cousin, [lines, town], rng, vanish)
      end
    end
    places = result.places.sort_by { |wp, *| wp.index }
    map_giver(places, atlas, zones, pools, plans, trainers, names, lines, rng)
    places.each do |wp, _place, _text, layout|
      spots = atlas[:maps][wp.name]
      if wp.kind == "route"
        squares = wp.mask ? wp.mask.join.count("1") : wp.w * wp.h
        count = squares.times.sum { rng.rand(ROUTE_TRAINERS) }
        types = TRAINER_TYPES[MapProceduralGenerator.mountain_tables?(wp, layout) ? "montagne" : layout.ambiance] || TRAINER_TYPES[nil]
        draw.call(wp.name, facing_cells(spots), types, count, COUSIN_CHANCE)
      elsif wp.name != atlas[:start]
        # No Cousin in the first town: the player has no Pokémon yet
        draw.call(wp.name, facing_cells(spots), COUSIN_TYPES, rng.rand(TOWN_COUSINS), 100)
      end
    end
    atlas[:maps].each do |name, spots|
      next if spots[:kind] != "grotte" || spots[:dark]
      cells = spots[:floor].map { |x, y| [x, y, FACINGS.sample(random: rng)] }
      draw.call(name, cells, TRAINER_TYPES["grotte"], rng.rand(CAVE_TRAINERS), 0)
    end
    return members
  end

  # A member of that guild on a route: a trainer of the route (PARTY_SIZES
  # Pokémon at the top of the zone's levels) with the guild's look and lines,
  # its team from the guild's pool. { id:, map:, label:, team: }, nil without
  # a name left.
  def route_member(plans, trainers, names, map, cell, guild, zone, species, (lines, town), rng)
    type = guild.member_types.sample(random: rng)
    name = trainer_name(type, names, rng)
    return nil if !name
    x, y, facing, sight = cell
    tag = "guilde_#{guild.id.downcase}"
    size = rng.rand(PARTY_SIZES[[zone.seals, PARTY_SIZES.length - 1].min])
    top = zone.levels[1]
    team = pool_party(species, guild.pool.filter_map { |id| species[id] }, size, [top - PARTY_LEVEL_SPREAD, 2].max, top,
                      zone.seals, rng)
    lose = lines.text("#{tag}_membre_fin", town)
    trainers.push(team_section(type, name, lose, team))
    label = guild_label(plans[map], guild)
    add(plans, map, "Trainer", label, x, y, ["Facing", facing], ["Sight", sight], ["Type", type], ["Name", name],
        ["BattleID", TRAINER_VERSION], ["Battle", lines.text("#{tag}_membre_combat", town)], ["EndBattle", lose])
    return { id: guild.id, map: map, label: label, team: team }
  end

  # « GuildeEleveurs3 »: the next label of a member of that guild on a map.
  def guild_label(events, guild)
    prefix = "Guilde#{guild.id.capitalize}"
    return "#{prefix}#{events.count { |*, text| text.start_with?("[Trainer #{prefix}") } + 1}"
  end

  # The Cousin who gives the Town Map, on the first route where a cell cuts
  # the way (cutting_cell).
  def map_giver(places, atlas, zones, pools, plans, trainers, names, lines, rng)
    cell = nil
    wp, = places.find do |place, *|
      next false if place.kind != "route" || !zones[place.name] || !pools[place.name]
      cell = cutting_cell(atlas[:maps][place.name], rng)
    end
    return if !wp
    town = atlas[:maps][wp.name][:title]
    add_trainer(plans, trainers, names, wp.name, cell, COUSIN_TYPES.sample(random: rng), zones[wp.name], pools[wp.name],
                true, [lines, town], rng, [*lines.boxes("cousin_carte", town).map { |box| ["Win", box] }, ["Gift", MAP_ITEM]])
  end

  # [x, y, facing, sight] of a cell beside the street where a trainer stands
  # so that no one goes from an exit to another without crossing its sight
  # (nor stepping on the trainer); nil if there is none.
  def cutting_cell(spots, rng)
    ground = (spots[:ground] || []).to_h { |cell| [cell, true] }
    exits = (spots[:exits] || []).map { |_side, x, y| [x, y] }.select { |cell| ground[cell] }
    return nil if exits.length < 2
    blocked = blocked_cells(spots)
    facing_cells(spots).shuffle(random: rng).each do |x, y, facing|
      next if blocked.include?([x, y])
      dx, dy = STEPS[facing]
      seen = (1..MAP_GIVER_SIGHT).map { |i| [x + (dx * i), y + (dy * i)] }.take_while { |cell| ground[cell] }
      next if seen.empty? || seen.any? { |cell| blocked.include?(cell) }
      reached = walk_cells(ground, exits[0], [[x, y], *seen])
      return [x, y, facing, seen.length] if exits.any? { |cell| !reached[cell] }
    end
    return nil
  end

  # Cells of ground reached from start without stepping on cut.
  def walk_cells(ground, start, cut)
    seen = { start => true }
    queue = [start]
    until queue.empty?
      x, y = queue.shift
      STEPS.each_value do |dx, dy|
        cell = [x + dx, y + dy]
        next if seen[cell] || !ground[cell] || cut.include?(cell)
        seen[cell] = true
        queue.push(cell)
      end
    end
    return seen
  end

  FACINGS = %w[haut bas gauche droite].freeze
  STEPS = { "haut" => [0, -1], "bas" => [0, 1], "gauche" => [-1, 0], "droite" => [1, 0] }.freeze

  # The wild Pokémon a trainer of each zone can have: those of its tall grass
  # or cave (else its water), else those of the zone before it.
  def zone_pools(zones, encounters)
    by_zone = encounters.tables.group_by { |table| table.zone.name }
    pools = {}
    last = nil
    zones.values.sort_by(&:index).each do |zone|
      tables = by_zone[zone.name] || []
      land = tables.select { |table| %w[Land Cave].include?(table.type) }
      land = tables if land.empty?
      pool = land.flat_map { |table| table.slots.map { |entry| entry.species.id } }.uniq
      last = pool if !pool.empty?
      pools[zone.name] = last
    end
    first = pools.values.compact.first
    return pools.transform_values { |pool| pool || first }
  end

  # [x, y, facing] of the free cells beside the streets, facing the street.
  def facing_cells(spots)
    return spots[:facing] || []
  end

  # A free cell of these for a trainer: not on an exit, a door or in front
  # of one, nor next to another event, and whose sight never reaches an exit
  # or a door. [x, y, facing, sight], nil if none is left.
  def trainer_cell(spots, cells, taken, rng)
    blocked = blocked_cells(spots)
    sight = rng.rand(SIGHT)
    cells.shuffle(random: rng).each do |x, y, facing|
      next if blocked.include?([x, y])
      next if taken.any? { |tx, ty, _text| (tx - x).abs + (ty - y).abs < 3 }
      dx, dy = STEPS[facing]
      next if (1..sight).any? { |i| blocked.include?([x + (dx * i), y + (dy * i)]) }
      return [x, y, facing, sight]
    end
    return nil
  end

  # Cells no trainer stands on nor looks at: exits (as wide and deep as a
  # street), doors and the cell in front, ladders and the cells around them.
  def blocked_cells(spots)
    width = MapProceduralGenerator::STREET_WIDTH
    cells = []
    (spots[:exits] || []).each do |exit|
      if exit[0].is_a?(String)
        _side, x, y = exit
        width.times { |i| width.times { |j| cells.push([x + i, y + j]) } }
      else
        cells.concat(around(exit[0], exit[1]))
      end
    end
    (spots[:doors] || []).each { |x, y, *| cells.push([x, y], [x, y + 1]) }
    (spots[:ladders] || []).each { |x, y| cells.concat(around(x, y)) }
    return cells
  end

  def around(x, y)
    return (-1..1).flat_map { |i| (-1..1).map { |j| [x + i, y + j] } }
  end

  # One trainer: its event, and its team in PBS/trainers.txt (version
  # TRAINER_VERSION, one name per type in the world).
  # extra: more [key, value] lines (rewards).
  def add_trainer(plans, trainers, names, map, cell, type, zone, pool, cousin, (lines, town), rng, extra = [])
    x, y, facing, sight = cell
    name = trainer_name(type, names, rng)
    return if !name
    battle = lines.text(cousin ? "cousin_combat" : "dresseur_combat", town)
    lose = lines.text(cousin ? "cousin_fin" : "dresseur_fin", town)
    double = zone.seals >= DOUBLE_FROM && rng.rand(100) < DOUBLE_CHANCE
    trainers.push(team_section(type, name, lose, party(zone, pool, rng, double ? 2 : 1)))
    label = cousin ? "Cousin" : "Dresseur"
    add(plans, map, "Trainer", "#{label}#{plans[map].count { |*, text| text.start_with?("[Trainer #{label}") } + 1}",
        x, y, ["Facing", facing], ["Sight", sight], ["Type", type], ["Name", name],
        ["BattleID", TRAINER_VERSION], ["Battle", battle], ["EndBattle", lose], *(double ? [["DoubleBattle", "oui"]] : []), *extra)
  end

  # [[species, level]] of a trainer of that zone: PARTY_SIZES Pokémon (at
  # least min), up to the highest level of its wild Pokémon.
  def party(zone, pool, rng, min = 1)
    size = [rng.rand(PARTY_SIZES[[zone.seals, PARTY_SIZES.length - 1].min]), min].max
    top = zone.levels[1]
    return Array.new(size) { [pool.sample(random: rng), [top - rng.rand(0..PARTY_LEVEL_SPREAD), 2].max] }
  end
end
