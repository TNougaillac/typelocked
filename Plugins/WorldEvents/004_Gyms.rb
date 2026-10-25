#===============================================================================
# WorldEvents - Lieutenants and their gyms
# Each gym of the world (an island's too) gets its lieutenant, a gym leader
# with a favourite type drawn with the seed (never the same twice), who gives
# the seal of his stretch and a useful TM of his type, and 2 to 4 members of
# the Family of that type, one of them standing where the player must pass.
# Plain Ruby.
#===============================================================================
module WorldEvents
  module_function

  # Draws the gyms: events into plans, teams into trainers. species: the
  # roster (ProceduralEncounters.load_species); tms: [[item, move, type,
  # power, status?]]; caps: level cap by seals. Returns the lieutenants
  # drawn: [{ gym:, map:, type:, trainer:, name:, team:, tm: }].
  def gym_events(atlas, species, tms, caps, plans, trainers, names, rng)
    leaders = []
    used_tms = []
    types = leader_types(atlas[:gyms].length, species, tms, rng)
    leader_types = LEADER_TYPES.shuffle(random: rng)
    atlas[:gyms].each_with_index do |town, i|
      map, spots = atlas[:maps].find { |_name, m| m[:building] == "arene" && m[:owner] == town }
      layout = spots && GYM_LAYOUTS[spots[:template]]
      next if !layout
      type = types[i]
      cap = caps[i] || caps.last
      tm = (useful_tms(tms, type) - used_tms).sample(random: rng)
      used_tms.push(tm) if tm
      trainer = leader_types[i % leader_types.length]
      name = trainer_name(trainer, names, rng)
      next if !name
      size = LEADER_PARTY_SIZES[[i, LEADER_PARTY_SIZES.length - 1].min]
      team = typed_party(species, type, size, cap - LEADER_LEVEL_SPREAD, cap, rng)
      trainers.push(team_section(trainer, name, LEADER_END, team))
      add(plans, map, "Trainer", "Lieutenant", *layout[:leader], ["Facing", "bas"], ["Sight", 1],
          ["Type", trainer], ["Name", name], ["BattleID", TRAINER_VERSION], ["Battle", LEADER_BATTLE],
          ["EndBattle", LEADER_END], ["Win", LEADER_WIN], ["Badge", [i + 1, 8].min],
          *(tm ? [["Win", LEADER_GIFT], ["Gift", tm[0]]] : []), ["Switch", GYM_SWITCH + i + 1])
      members = gym_members(layout, rng)
      members.each_with_index do |(x, y, facing, sight), j|
        member = COUSIN_TYPES.sample(random: rng)
        member_name = trainer_name(member, names, rng)
        next if !member_name
        top = cap - rng.rand(MEMBER_LEVEL_GAP)
        member_team = typed_party(species, type, rng.rand(PARTY_SIZES[[i, PARTY_SIZES.length - 1].min]),
                                  top - PARTY_LEVEL_SPREAD, top, rng)
        lose = MEMBER_ENDS.sample(random: rng)
        trainers.push(team_section(member, member_name, lose, member_team))
        add(plans, map, "Trainer", "Membre#{j + 1}", x, y, ["Facing", facing], ["Sight", sight],
            ["Type", member], ["Name", member_name], ["BattleID", TRAINER_VERSION],
            ["Battle", MEMBER_BATTLES.sample(random: rng)], ["EndBattle", lose])
      end
      leaders.push({ gym: i + 1, map: map, town: town, type: type, trainer: trainer, name: name, team: team,
                     tm: tm, members: members.length })
    end
    return leaders
  end

  # One blocking cell, then the others drawn among the rest.
  def gym_members(layout, rng)
    count = rng.rand(GYM_MEMBERS)
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
  def useful_tms(tms, type)
    return tms.select do |_item, move, move_type, power, status|
      move_type == type && (status ? TM_STATUS.include?(move) : power.to_i >= TM_MIN_POWER)
    end
  end

  # [[species, level]] of that type, levels from low to high: species
  # reachable at that level first (else the type's earliest ones).
  def typed_party(species, type, size, low, high, rng)
    pool = species.values.select { |sp| sp.types.include?(type) }
    reachable = pool.select { |sp| sp.min_level <= high }
    reachable = pool.min_by(3, &:min_level) if reachable.empty?
    # The most evolved first, for a lieutenant that looks like one
    reachable = reachable.sort_by { |sp| [-sp.stage, sp.id.to_s] }
    picks = reachable.first([size * 2, reachable.length].max).sample(size, random: rng)
    picks += reachable.sample(size - picks.length, random: rng) while picks.length < size && !reachable.empty?
    levels = Array.new(size) { |k| (size == 1) ? high : low + (((high - low) * k) / (size - 1)) }
    return picks.each_with_index.map { |sp, k| [sp.id, [levels[k], 2].max] }
  end

  def trainer_name(type, names, rng)
    gender = FEMALE_TYPES.include?(type) ? :female : :male
    # Once every name is taken for that type: with an initial (« Paolo B. »)
    name = (TRAINER_NAMES[gender] - names[type]).sample(random: rng) ||
           (TRAINER_NAMES[gender].product(("A".."Z").to_a).map { |n, l| "#{n} #{l}." } - names[type]).sample(random: rng)
    names[type].push(name) if name
    return name
  end

  def team_section(type, name, lose, team)
    return "[#{type},#{name},#{TRAINER_VERSION}]\nLoseText = #{lose}\n" +
           team.map { |species, level| "Pokemon = #{species},#{level}\n" }.join
  end
end
