#===============================================================================
# WorldEvents - Lieutenants and their gyms, the Anciens, the Parrain, Arceus
# Each gym of the world (an island's too) gets its lieutenant, a gym leader
# with a favourite type drawn with the seed (never the same twice), who gives
# the seal of his stretch and a choice of loot (his useful TM of his type, a
# held item or a pack of items: seal_loot), and 2 to 4 members of
# the Family of that type, one of them standing where the player must pass.
# Then the League: four Anciens of drawn types, the Parrain, Arceus.
# Plain Ruby.
#===============================================================================
module WorldEvents
  module_function

  # Draws the gyms: events into plans, teams into trainers. species: the
  # roster (ProceduralEncounters.load_species); tms: [[item, move, type,
  # power, status?]]; caps: level cap by seals. Returns the lieutenants
  # drawn: [{ gym:, map:, type:, trainer:, name:, team:, sets:, tm: }]; sets:
  # a Sets, for the lieutenant's team.
  def gym_events(atlas, species, tms, caps, plans, trainers, names, lines, sets, rng)
    leaders = []
    used_tms = []
    types = leader_types(atlas[:gyms].length, species, tms, rng)
    atlas[:gyms].each_with_index do |town, i|
      map, spots = atlas[:maps].find { |_name, m| m[:building] == "arene" && m[:owner] == town }
      layout = spots && (GYM_LAYOUTS[spots[:template]] || gym_floor_layout(spots, rng))
      next if !layout
      type = types[i]
      cap = caps[i] || caps.last
      tm = (useful_tms(tms, type, i) - used_tms).sample(random: rng)
      used_tms.push(tm) if tm
      trainer = LEADER_TYPES.fetch(type, :LIEUTENANT_NORMAL)
      name = trainer_name(trainer, names, rng)
      next if !name
      size = LEADER_PARTY_SIZES[[i, LEADER_PARTY_SIZES.length - 1].min]
      team = typed_party(species, type, size, cap - LEADER_LEVEL_SPREAD, cap, i, rng)
      team_sets = sets.draw(team, type, i, LEADER_IVS[[i, LEADER_IVS.length - 1].min])
      title = atlas[:maps][town][:title]
      lose = lines.text("lieutenant_fin", title)
      trainers.push(team_section(trainer, name, lose, team, team_sets))
      wins = lines.boxes("lieutenant_victoire", title) + lines.boxes("lieutenant_ct", title)
      add(plans, map, "Trainer", "Lieutenant", *layout[:leader], ["Facing", "bas"], ["Sight", 1],
          ["Type", trainer], ["Name", name], ["BattleID", TRAINER_VERSION], ["Battle", lines.text("lieutenant_combat", title)],
          ["EndBattle", lose], *wins.map { |box| ["Win", box] }, ["Badge", [i + 1, 8].min],
          ["Script", loot_script(i, tm, rng)], ["Switch", GYM_SWITCH + i + 1])
      members = gym_members(layout, rng)
      members.each_with_index do |(x, y, facing, sight), j|
        member = COUSIN_TYPES.sample(random: rng)
        member_name = trainer_name(member, names, rng)
        next if !member_name
        top = cap - rng.rand(MEMBER_LEVEL_GAP)
        member_team = typed_party(species, type, rng.rand(PARTY_SIZES[[i, PARTY_SIZES.length - 1].min]),
                                  top - PARTY_LEVEL_SPREAD, top, i, rng)
        lose = lines.text("membre_fin", title)
        trainers.push(team_section(member, member_name, lose, member_team))
        add(plans, map, "Trainer", "Membre#{j + 1}", x, y, ["Facing", facing], ["Sight", sight],
            ["Type", member], ["Name", member_name], ["BattleID", TRAINER_VERSION],
            ["Battle", lines.text("membre_combat", title)], ["EndBattle", lose])
      end
      statues = layout[:hold] ? gym_mechanic(plans, map, spots, layout, members, type, i, lines, title, rng) : 0
      leaders.push({ gym: i + 1, map: map, town: town, type: type, trainer: trainer, name: name, team: team,
                     sets: team_sets, tm: tm, members: members.length, statues: statues })
    end
    return leaders
  end

  # The layout of a generated gym (#121, MapProceduralGenerator.gym_floor,
  # one room): the lieutenant at its far end, the members on its floor cells
  # away from the entry, the lieutenant and each other, never seeing the
  # exit nor standing by it.
  def gym_floor_layout(spots, rng)
    near = [spots[:entry], spots[:leader]]
    blocked = blocked_cells(spots)
    cells = spots[:facing].select do |x, y, _f|
      near.all? { |nx, ny| (nx - x).abs + (ny - y).abs > GYM_MEMBER_ROOM } &&
        (0..GYM_MEMBER_SIGHT).none? { |i| blocked.include?([x, y + i]) }
    end
    others = []
    cells.shuffle(random: rng).each do |x, y, facing|
      next if others.any? { |ox, oy, *| (ox - x).abs + (oy - y).abs <= GYM_MEMBER_ROOM }
      others.push([x, y, facing, GYM_MEMBER_SIGHT])
      break if others.length >= GYM_MEMBERS.max
    end
    return { leader: spots[:leader], blocking: [], others: others, hold: true }
  end

  # The mechanic of a generated gym (#121): barriers on the cells around the
  # lieutenant, lifted once the room's statues are all touched (in their
  # order for GYM_ORDERED, invisible for GYM_HIDDEN). Returns the number of
  # statues placed (0: no mechanic, the room being too cramped).
  def gym_mechanic(plans, map, spots, layout, members, type, index, lines, title, rng)
    return 0 if index >= GYM_STATUE_LOCKS
    ground = spots[:ground].to_h { |cell| [cell, true] }
    lx, ly = layout[:leader]
    barriers = STEPS.values.map { |dx, dy| [lx + dx, ly + dy] }.select { |cell| ground[cell] }
    taken = [layout[:leader], *barriers, *members.map { |x, y, *| [x, y] }]
    open = gym_reach(ground, spots[:entry], taken)
    return 0 if barriers.none? { |bx, by| STEPS.values.any? { |dx, dy| open[[bx + dx, by + dy]] } }
    near = [spots[:entry], layout[:leader], *members.map { |x, y, *| [x, y] }]
    blocked = blocked_cells(spots)
    statues = []
    count = GYM_STATUES[[index, GYM_STATUES.length - 1].min]
    spots[:floor].shuffle(random: rng).each do |cell|
      break if statues.length >= count
      next if !open[cell] || blocked.include?(cell)
      next if (near + statues).any? { |nx, ny| (nx - cell[0]).abs + (ny - cell[1]).abs <= GYM_STATUE_ROOM }
      # Never cutting the room: every other cell still reached
      after = gym_reach(ground, spots[:entry], taken + statues + [cell])
      next if after.length != open.length - statues.length - 1
      statues.push(cell)
    end
    return 0 if statues.empty?
    switch = GYM_STATUE_SWITCH + index + 1
    ordered = GYM_ORDERED.include?(type)
    hidden = GYM_HIDDEN.include?(type)
    section = ordered ? "arene_barriere_ordre" : (hidden ? "arene_barriere_cachee" : "arene_barriere")
    barriers.each_with_index do |(x, y), k|
      add(plans, map, "NPC", "Barriere#{k + 1}", x, y, ["Graphic", GYM_BARRIERS.fetch(type, GYM_BARRIER)],
          ["Text", lines.text(section, title)], ["Hide", "S#{switch}"])
    end
    statues.each_with_index do |(x, y), k|
      add(plans, map, "NPC", "Statue#{k + 1}", x, y, *(hidden ? [] : [["Graphic", GYM_STATUE]]),
          ["Script", "WorldEvents.gym_statue(#{k + 1}, #{statues.length}, #{switch}, #{ordered})"])
    end
    return statues.length
  end

  # { cell => true } of the ground cells reached from start, not through taken.
  def gym_reach(ground, start, taken)
    seen = { start => true }
    queue = [start]
    until queue.empty?
      x, y = queue.shift
      STEPS.each_value do |dx, dy|
        cell = [x + dx, y + dy]
        next if seen[cell] || !ground[cell] || taken.include?(cell)
        seen[cell] = true
        queue.push(cell)
      end
    end
    return seen
  end

  # The lieutenant's loot, offered in game by seal_loot: his TM (nil: none),
  # a held item and a pack drawn from the seal's tier.
  def loot_script(gym, tm, rng)
    tier = SEAL_LOOT_TIERS[[gym, SEAL_LOOT_TIERS.length - 1].min]
    held = SEAL_HELD_ITEMS[tier].sample(random: rng)
    pack = SEAL_PACKS[tier].sample(random: rng)
    return "WorldEvents.seal_loot(#{tm ? ":#{tm[0]}" : 'nil'}, :#{held}, #{pack.inspect})"
  end

  # One blocking cell, then the others drawn among the rest.
  def gym_members(layout, rng)
    count = rng.rand(GYM_MEMBERS)
    # A generated gym (hold): among its free cells
    return layout[:others].shuffle(random: rng).first(count) if layout[:hold]
    blocking = layout[:blocking].shuffle(random: rng)
    rest = (blocking.drop(1) + layout[:others]).shuffle(random: rng)
    return [blocking.first] + rest.first(count - 1)
  end

  # A favourite type for each gym, all different: types with Pokémon in the
  # roster and a useful TM.
  def leader_types(count, species, tms, rng)
    types = species.values.flat_map(&:types).uniq.select { |type| !useful_tms(tms, type).empty? }
    return types.shuffle(random: rng).first(count)
  end

  # TMs of that type worth giving: strong enough, or a known status move.
  # gym: the lieutenant's (from 0), the first EARLY_GYMS ones need less power.
  def useful_tms(tms, type, gym = nil)
    min_power = (gym && gym < EARLY_GYMS) ? EARLY_TM_MIN_POWER : TM_MIN_POWER
    return tms.select do |_item, move, move_type, power, status|
      move_type == type && (status ? TM_STATUS.include?(move) : (TM_POWER_OVERRIDES[move] || power).to_i >= min_power)
    end
  end

  # [[species, level]] of that type, levels from low to high: species
  # reachable at that level first (else the pool's earliest ones).
  def typed_party(species, type, size, low, high, seals, rng)
    return pool_party(species, species.values.select { |sp| sp.types.include?(type) }, size, low, high, seals, rng)
  end

  # The same among the species of pool (a guild's).
  def pool_party(species, pool, size, low, high, seals, rng)
    reachable = final_forms(species, pool, high, seals)
    reachable = pool.min_by(3, &:min_level) if reachable.empty?
    # The most evolved first, for a lieutenant that looks like one
    reachable = reachable.sort_by { |sp| [-sp.stage, sp.id.to_s] }
    picks = reachable.first([size * 2, reachable.length].max).sample(size, random: rng)
    picks += reachable.sample(size - picks.length, random: rng) while picks.length < size && !reachable.empty?
    levels = Array.new(size) { |k| (size == 1) ? high : low + (((high - low) * k) / (size - 1)) }
    return picks.each_with_index.map { |sp, k| [sp.id, [levels[k], 2].max] }
  end

  # Those of the pool reachable at that level with that many seals, and not
  # evolved yet by then (no Togepi at level 55).
  def final_forms(species, pool, high, seals)
    reachable = ->(sp) { sp.min_level <= high && sp.min_seals <= seals }
    evolved = species.values.filter_map { |sp| sp.prevo&.first if reachable.call(sp) }
    return pool.select { |sp| reachable.call(sp) && !evolved.include?(sp.id) }
  end

  def trainer_name(type, names, rng)
    gender = FEMALE_TYPES.include?(type) ? :female : :male
    # Once every name is taken for that type: with an initial (« Paolo B. »)
    name = (TRAINER_NAMES[gender] - names[type]).sample(random: rng) ||
           (TRAINER_NAMES[gender].product(("A".."Z").to_a).map { |n, l| "#{n} #{l}." } - names[type]).sample(random: rng)
    names[type].push(name) if name
    return name
  end

  # sets: [set or nil] for each Pokémon (see Sets#draw), none for a member.
  def team_section(type, name, lose, team, sets = [])
    return "[#{type},#{name},#{TRAINER_VERSION}]\nLoseText = #{lose}\n" +
           team.each_with_index.map { |(species, level), k| "Pokemon = #{species},#{level}\n" + set_lines(sets[k]) }.join
  end

  # The League's rooms, in the order of the inventory: the four Anciens, the
  # Parrain, Arceus; the door of each room closed until it is won. Teams into
  # trainers. Returns [{ map:, role:, type:, trainer:, name:, team:, sets: }]
  # (Arceus: team [[:ARCEUS, level]], no sets).
  def league_events(atlas, species, caps, plans, trainers, names, lines, sets, rng)
    rooms = atlas[:league].filter_map do |name|
      spots = atlas[:maps][name]
      layout = LEAGUE_LAYOUTS[spots[:template]]
      [name, spots[:role], layout] if layout && spots[:role] != "Entrée" && spots[:role] != "Panthéon"
    end
    last = caps[[atlas[:gyms].length - 1, 0].max] || caps.last
    top = caps[atlas[:gyms].length] || caps.last
    types = species.values.flat_map(&:types).uniq.shuffle(random: rng)
    fights = []
    rooms.each_with_index do |(map, role, layout), i|
      x, y = layout[:boss]
      title = atlas[:maps][map][:title]
      switch = LEAGUE_SWITCH + i + 1
      gx, gy = layout[:gate]
      add(plans, map, "Npc", "Porte", gx, gy, ["Trigger", "contact"], ["Hide", "S#{switch}"],
          ["Script", "WorldEvents.league_door"])
      if role == "Arceus"
        level = top + ARCEUS_LEVEL_BONUS
        add(plans, map, "Npc", "Arceus", x, y, ["Graphic", ARCEUS_GRAPHIC],
            *lines.boxes("arceus_intro", title).map { |box| ["Text", box] },
            ["Script", "WorldEvents.arceus(self, #{level}, #{switch})"])
        fights.push({ map: map, role: role, type: nil, trainer: nil, name: "Arceus", team: [[:ARCEUS, level]] })
        next
      end
      elder = role.start_with?("Ancien") ? fights.length : nil
      if elder
        type = types[elder]
        trainer = ELDER_TYPES[elder % ELDER_TYPES.length]
        high = last + (((top - last) * (elder + 1)) / 5.0).round
        size = ELDER_PARTY_SIZES[[elder, ELDER_PARTY_SIZES.length - 1].min]
        team = typed_party(species, type, size, high - LEADER_LEVEL_SPREAD, high, atlas[:gyms].length, rng)
        battle, lose = lines.text("ancien_combat", title), lines.text("ancien_fin", title)
      else
        type = nil
        trainer = PARRAIN_TYPE
        team = parrain_party(species, top, atlas[:gyms].length, rng)
        battle, lose = lines.text("parrain_combat", title), lines.text("parrain_fin", title)
      end
      name = trainer_name(trainer, names, rng)
      next if !name
      team_sets = sets.draw(team, type, atlas[:gyms].length, LEAGUE_IVS)
      trainers.push(team_section(trainer, name, lose, team, team_sets))
      add(plans, map, "Trainer", role.delete(" "), x, y, ["Facing", "bas"], ["Sight", 4], ["Type", trainer],
          ["Name", name], ["BattleID", TRAINER_VERSION], ["Battle", battle], ["EndBattle", lose], ["Switch", switch])
      fights.push({ map: map, role: role, type: type, trainer: trainer, name: name, team: team, sets: team_sets })
    end
    return fights
  end

  # The Parrain's Pokémon: the most evolved of the roster reachable at that
  # level, of different types, the strongest at it.
  def parrain_party(species, high, seals, rng)
    pool = final_forms(species, species.values, high, seals).sort_by { |sp| [-sp.stage, sp.id.to_s] }
    best = pool.select { |sp| sp.stage == pool.first.stage }.shuffle(random: rng)
    picks = []
    (best + pool.shuffle(random: rng)).each do |sp|
      next if picks.include?(sp) || picks.any? { |other| other.types.first == sp.types.first }
      picks.push(sp)
      break if picks.length == PARRAIN_PARTY_SIZE
    end
    low = high - LEADER_LEVEL_SPREAD
    size = picks.length
    return picks.each_with_index.map { |sp, k| [sp.id, low + (((high - low) * k) / [size - 1, 1].max)] }
  end
end
