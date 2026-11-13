#===============================================================================
# WorldEvents - Guilds
# The guilds of MapProc/Lore/guildes.txt (spec #181): read and checked (an
# error names the file and the line), then, for each guild whose
# headquarters MapProceduralGenerator drew in the world (WORLD_GUILDS, a
# place of its own off a route), its leader inside (by the street when its
# headquarters has no door) and 2 to 4 members outside, their teams drawn from its pool at the level of the
# Tronçon. Its leader beaten, the guild turns its switch on and rewards the
# player by its position (guild_reward, #186); an affiliated guild beaten
# frees the nearest town from the Family (guild_liberations, #187); in some
# worlds, a guild's members bar the route of its headquarters until its
# leader is beaten (guild_blockade, #188). Plain Ruby.
#===============================================================================
module WorldEvents
  # id: the section's (« ELEVEURS »); position: GUILD_POSITIONS; biomes:
  # ambiances (none: wherever its headquarters goes); hq: brick type; member_types: trainer types; leader: trainer type;
  # enemies: guild ids; pool: species ids; line: the line of its section.
  Guild = Struct.new(:id, :name, :position, :biomes, :hq, :member_types, :leader, :title, :enemies, :pool, :line)
  GUILD_KEYS = %w[Nom Position Biomes QG Membres Chef Titre Ennemis Pool].freeze

  module_function

  # [Guild], raising Error (file, line) on a format error, an unknown
  # position, biome, headquarters, enemy or species, a legendary, a trainer
  # type absent or without its sprites, a missing line of dialogue. known:
  # { species: ids of the roster, legendary: ids, trainer_types: { id =>
  # name }, sprite: ->(type) { both sprites exist }, dialogues: sections }.
  def parse_guilds(text, file, known)
    raw = []
    current = nil
    key = nil
    text.sub(/\A﻿/, "").each_line.with_index(1) do |source, lineno|
      line = source.strip
      next if line.empty? || line.start_with?("#")
      fail_at = ->(msg) { raise Error, "#{file}, ligne #{lineno} : #{msg}" }
      if line =~ /\A\[(.*)\]\z/
        id = $1
        fail_at.call("identifiant [#{id}] : MAJUSCULES sans accents attendues") if !id.match?(/\A[A-Z0-9_]+\z/)
        fail_at.call("guilde [#{id}] en double") if raw.any? { |g| g[:id] == id }
        current = { id: id, line: lineno, fields: {} }
        raw.push(current)
        key = nil
      elsif source =~ /\A\s/ && key
        current[:fields][key][0] << " " << line
      elsif line =~ /\A([^=]+?)\s*=\s*(.*)\z/
        key, value = $1, $2
        fail_at.call("« #{key} » hors d'une guilde") if !current
        fail_at.call("clé « #{key} » inconnue (#{GUILD_KEYS.join(', ')})") if !GUILD_KEYS.include?(key)
        fail_at.call("clé « #{key} » en double") if current[:fields][key]
        current[:fields][key] = [+value, lineno]
      else
        fail_at.call("ligne illisible (« Clé = valeur » attendu)")
      end
    end
    guilds = raw.map { |g| guild_from(g, file, known) }
    guilds.each do |guild|
      guild.enemies.each do |enemy|
        other = guilds.find { |g| g.id == enemy }
        raise Error, "#{file}, ligne #{guild.line} : ennemi #{enemy} inconnu" if !other
        raise Error, "#{file}, ligne #{guild.line} : #{enemy} ne compte pas #{guild.id} parmi ses ennemis" if !other.enemies.include?(guild.id)
      end
    end
    return guilds
  end

  def guild_from(raw, file, known)
    fields = raw[:fields]
    (GUILD_KEYS - %w[Biomes Ennemis]).each do |key|
      raise Error, "#{file}, ligne #{raw[:line]} : [#{raw[:id]}] sans « #{key} »" if !fields[key] || fields[key][0].strip.empty?
    end
    value = ->(key) { fields[key]&.first.to_s.strip }
    list = ->(key) { value.call(key).split(",").map(&:strip).reject(&:empty?) }
    fail_at = ->(key, msg) { raise Error, "#{file}, ligne #{fields[key][1]} : #{msg}" }
    position = value.call("Position")
    fail_at.call("Position", "position « #{position} » inconnue (#{GUILD_POSITIONS.join(', ')})") if !GUILD_POSITIONS.include?(position)
    hq = value.call("QG")
    allowed = MapProceduralGenerator::GUILD_HQS[hq]
    fail_at.call("QG", "QG « #{hq} » inconnu (#{MapProceduralGenerator::GUILD_HQS.keys.join(', ')})") if !allowed
    biomes = fields["Biomes"] ? list.call("Biomes") : []
    biomes.each { |biome| fail_at.call("Biomes", "biome « #{biome} » inconnu") if !guild_biomes.include?(biome) }
    # MapProc lays the headquarters where GUILD_HQS allows it
    if biomes.sort != allowed.sort
      where = allowed.empty? ? "partout (Biomes vide)" : "dans #{allowed.join(', ')}"
      fail_at.call(fields["Biomes"] ? "Biomes" : "QG", "biomes « #{biomes.join(', ')} » : le QG #{hq} se pose #{where} (GUILD_HQS)")
    end
    types = list.call("Membres").map(&:to_sym)
    leader = value.call("Chef").to_sym
    (types + [leader]).each do |type|
      key = (type == leader) ? "Chef" : "Membres"
      fail_at.call(key, "type de dresseur #{type} absent de trainer_types.txt") if !known[:trainer_types][type]
      fail_at.call(key, "type de dresseur #{type} sans sprite (Graphics/Trainers, Graphics/Characters/trainer_)") if !known[:sprite].call(type)
    end
    title = value.call("Titre")
    if known[:trainer_types][leader] != title
      fail_at.call("Titre", "titre « #{title} » : le type #{leader} s'appelle « #{known[:trainer_types][leader]} » dans trainer_types.txt")
    end
    pool = list.call("Pool").map(&:to_sym)
    pool.each do |id|
      fail_at.call("Pool", "espèce #{id} inconnue (absente du roster)") if !known[:species].include?(id)
      fail_at.call("Pool", "espèce #{id} légendaire") if known[:legendary].include?(id)
    end
    fail_at.call("Pool", "espèce en double : #{pool.tally.select { |_id, n| n > 1 }.keys.join(', ')}") if pool.uniq != pool
    GUILD_LINES.each_key do |role|
      section = "guilde_#{raw[:id].downcase}_#{role}"
      next if known[:dialogues][section] && !known[:dialogues][section].empty?
      raise Error, "#{file}, ligne #{raw[:line]} : section [#{section}] absente ou vide de dialogues.txt"
    end
    return Guild.new(raw[:id], value.call("Nom"), position, biomes, hq, types, leader, title, list.call("Ennemis"), pool, raw[:line])
  end

  # The ambiances a guild may live in: those of the routes and towns.
  def guild_biomes
    return (TRAINER_TYPES.keys.compact + MapProceduralGenerator::GUILD_HQS.values.flatten).uniq
  end

  def guilds_path(root = ".")
    return File.join(root, MapProceduralGenerator::FOLDER, GUILDS_FILE)
  end

  # The guilds of the game's folder (root), checked against its PBS files,
  # sprites, roster (species: ProceduralEncounters.load_species) and
  # dialogues (parse_dialogues).
  def load_guilds(root = ".", species = nil, dialogues = nil)
    read = ->(file) { ProceduralEncounters.read_text(File.join(root, file)) }
    sections = ->(file) { read.call(file).split(/^\[/).drop(1) }
    legendary = sections.call(ProceduralEncounters::POKEMON_PBS).filter_map do |sec|
      sec[/\A(\w+)\]/, 1]&.to_sym if sec =~ /^Flags\s*=.*\b(Legendary|Mythical)\b/
    end
    trainer_types = sections.call("PBS/trainer_types.txt").to_h do |sec|
      [sec[/\A(\w+)\]/, 1].to_sym, sec[/^Name\s*=\s*(.+?)\s*$/, 1]]
    end
    sprite = lambda do |type|
      %W[Graphics/Trainers/#{type}.png Graphics/Characters/trainer_#{type}.png].all? { |f| File.exist?(File.join(root, f)) }
    end
    known = { species: (species || ProceduralEncounters.load_species(root)).keys, legendary: legendary,
              trainer_types: trainer_types, sprite: sprite, dialogues: dialogues || load_dialogues(root) }
    path = guilds_path(root)
    return parse_guilds(File.read(path, encoding: "UTF-8"), path, known)
  end

  # { headquarters => species ids } of the guilds: the encounters of their
  # dungeons (ProceduralEncounters.world_zones).
  def guild_pools(guilds)
    return guilds.to_h { |guild| [guild.hq, guild.pool] }
  end

  #-----------------------------------------------------------------------------
  # On the routes
  #-----------------------------------------------------------------------------
  # { route name => [Guild] }: the guilds of the world (a headquarters in
  # atlas[:hqs]) whose members walk each route: those of its ambiance, and,
  # for a guild without biomes, the route its headquarters' place branches
  # off.
  def guild_routes(result, atlas, guilds)
    hqs = atlas[:hqs] || {}
    present = guilds.select { |guild| hqs[guild.hq] }
    index = result.places.to_h { |wp, *| [wp.name, chain_index(wp)] }
    routes = {}
    result.places.sort_by { |wp, *| wp.index }.each do |wp, _place, _text, layout|
      next if wp.kind != "route" || wp.victory
      list = present.select do |guild|
        next guild.biomes.include?(layout.ambiance) if !guild.biomes.empty?
        index[hqs[guild.hq]] == wp.index
      end
      routes[wp.name] = list if !list.empty?
    end
    return routes
  end

  #-----------------------------------------------------------------------------
  # At the headquarters
  #-----------------------------------------------------------------------------
  # The leader and the members of each guild whose headquarters is in the
  # world: events into plans, teams into trainers. zones: world_zones.
  # Returns [{ id:, name:, position:, hq: place, map: interior, seals:,
  # level:, leader: { type:, name:, team:, sets: }, members: [{ type:,
  # name:, team: }], routes: [] (its members on the routes, see
  # trainer_events) }].
  # switch: turned on once its leader is beaten; reward: guild_reward (type:
  # the imposed type, rewards: its own draw); freed: what it frees
  # (guild_liberations: { town:, maps: }), nil if nothing; blocks: the
  # blockade (guild_blockade) of the guild that bars its route, else nil.
  def guild_events(result, atlas, guilds, species, zones, caps, plans, trainers, names, lines, sets, rng, type = nil,
                   rewards = Random.new(0), blockade = nil, rivals = {})
    zones = zones.to_h { |zone| [zone.name, zone] }
    taken = []
    freed = guild_liberations(result, atlas, guilds)
    return guilds.filter_map do |guild|
      route = (atlas[:hqs] || {})[guild.hq]
      zone = route && zones[route]
      outside = route && atlas[:maps][route]
      anchor = outside && (outside[:doors].find { |_x, _y, kind| kind == guild.hq } ||
                           (outside[:hqs] || []).find { |_x, _y, kind| kind == guild.hq })
      next if !zone || !anchor
      # Its leader inside (a headquarters with a door), else by the street
      # nearest it, like its members; in a dungeon, past its gates: its
      # place for a guild of the outdoors (#335), behind its door for a
      # guild of rooms (room, #337), at its far end
      room, inner = atlas[:maps].find { |_name, m| m[:kind] == "donjon" && m[:building] == guild.hq && m[:owner] == route }
      dungeon = outside[:gates] ? outside : inner
      map, spots = !dungeon && atlas[:maps].find { |_name, m| m[:kind] == "interieur" && m[:building] == guild.hq && m[:owner] == route }
      x, y, facing = spots && GUILD_LEADER_SPOTS[spots[:template]]
      cell = if inner
               [*inner[:leader], "bas", 1]
             elsif x
               [x, y, facing, 1]
             else
               hq_cell(outside, anchor, plans[route], rng, dungeon && past_gate(outside, -1))
             end
      next if !cell
      map = room if room
      map = route if !x && !room
      seals = zone.seals
      level = guild_level(zones, zone, caps)
      pool = guild.pool.filter_map { |id| species[id] }
      size = GUILD_LEADER_PARTY_SIZES[[seals, GUILD_LEADER_PARTY_SIZES.length - 1].min]
      team = pool_party(species, pool, size, level - LEADER_LEVEL_SPREAD, level, seals, rng)
      team_sets = sets.draw(team, nil, seals, LEADER_IVS[[seals, LEADER_IVS.length - 1].min])
      name = trainer_name(guild.leader, names, rng)
      next if !name
      tag = "guilde_#{guild.id.downcase}"
      title = outside[:title]
      lose = lines.text("#{tag}_chef_fin", title)
      trainers.push(team_section(guild.leader, name, lose, team, team_sets))
      label = guild.id.capitalize
      switch = guild_switch(guilds, guild)
      reward = guild_reward(guild, route, result, atlas, species, type, level, seals, taken, rewards)
      taken.push(reward[:route] || reward[:item]) if reward
      add(plans, map, "Trainer", "Chef#{label}", cell[0], cell[1], ["Facing", cell[2]], ["Sight", cell[3]], ["Type", guild.leader],
          ["Name", name], ["BattleID", TRAINER_VERSION], ["Battle", lines.text("#{tag}_chef_combat", title)], ["EndBattle", lose],
          *lines.boxes("#{tag}_chef_victoire", title).map { |box| ["Win", box] }, *reward_lines(reward, lines),
          ["Switch", switch])
      lock = dungeon && guild_lock(guilds, guild)
      members = guild_members(dungeon || outside, inner ? inner[:gates][0] : anchor, guild, pool, species, zone, level,
                              room || route, plans, trainers, names, [lines, tag, title], rng, rivals, lock)
      close_exit(plans, dungeon, guild, room || route, lock, switch, lines, title) if lock
      blocks = (blockade && blockade[:id] == guild.id) ? blockade : nil
      bar_route(plans, blocks, guild, switch, lines, title) if blocks
      { id: guild.id, name: guild.name, position: guild.position, hq: route, map: map, seals: seals, level: level,
        leader: { type: guild.leader, name: name, team: team, sets: team_sets, label: "Chef#{label}" }, members: members,
        routes: [], switch: switch, reward: reward, freed: freed[guild.id]&.slice(:town, :maps), blocks: blocks }
    end
  end

  # The game switch of a guild: its rank in guildes.txt after GUILD_SWITCH.
  def guild_switch(guilds, guild)
    return GUILD_SWITCH + guilds.index(guild) + 1
  end

  #-----------------------------------------------------------------------------
  # Rivalries (#189)
  #-----------------------------------------------------------------------------
  # { guild id => { ally:, rage:, vanish: } } for each guild of the world
  # with an enemy of the world that rallies (GUILD_ALLY, the first one of
  # its « Ennemis »): its members turn on the player once the ally's switch
  # (rage) is on, and leave the routes once its own (vanish) is.
  def guild_rivals(atlas, guilds)
    present = guilds.select { |guild| (atlas[:hqs] || {})[guild.hq] }
    return present.each_with_object({}) do |guild, rivals|
      ally = guild.enemies.filter_map { |id| present.find { |g| g.id == id && g.position == GUILD_ALLY } }.first
      next if !ally
      rivals[guild.id] = { ally: ally.id, rage: guild_switch(guilds, ally), vanish: guild_switch(guilds, guild) }
    end
  end

  # The lines of a member of a guild of rivals on that cell ([x, y, facing,
  # sight]): its sight once the ally rallied (GUILD_RAGE_SIGHT ahead, until
  # an exit or a door), its lines of revenge; on a route, it leaves once its
  # leader is beaten.
  def rage_lines(rivals, guild, spots, cell, lines, town, route = false)
    rival = rivals[guild.id]
    return [] if !rival
    x, y, facing, sight = cell
    dx, dy = STEPS[facing]
    blocked = blocked_cells(spots)
    far = (1..GUILD_RAGE_SIGHT).take_while { |i| !blocked.include?([x + (dx * i), y + (dy * i)]) }.length
    return [["Rage", "#{rival[:rage]},#{[far, sight].max}"], ["RageBattle", lines.text("guilde_vengeance", town)],
            *(route ? [["VanishIfSwitch", rival[:vanish]]] : [])]
  end

  # Once an enemy's leader is beaten, a member of the ally (rallied or not)
  # gives one of GUILD_BONUS_ITEMS by its headquarters. drawn: guild_events,
  # each guild's bonuses go to its :bonuses ([{ enemy:, item:, label:,
  # map: }]).
  def rival_bonuses(atlas, guilds, drawn, plans, lines, rng)
    drawn.each { |g| g[:bonuses] = [] }
    drawn.each do |g|
      guild = guilds.find { |x| x.id == g[:id] }
      next if guild.position != GUILD_ALLY
      outside = atlas[:maps][g[:hq]]
      anchor = outside[:doors].find { |_x, _y, kind| kind == guild.hq } ||
               (outside[:hqs] || []).find { |_x, _y, kind| kind == guild.hq }
      drawn.each do |enemy|
        next if !guild.enemies.include?(enemy[:id])
        cell = hq_cell(outside, anchor, plans[g[:hq]], rng)
        next if !cell
        item = GUILD_BONUS_ITEMS.sample(random: rng)
        label = "Bonus#{guild.id.capitalize}#{g[:bonuses].length + 1}"
        add(plans, g[:hq], "Npc", label, cell[0], cell[1], ["Graphic", "trainer_#{guild.member_types.first}"],
            ["Facing", cell[2]], ["When", "S#{enemy[:switch]}"],
            *lines.boxes("guilde_bonus_attente", outside[:title]).map { |box| ["Wait", box] },
            *lines.boxes("guilde_bonus", outside[:title]).map { |box| ["Text", box] }, ["Gift", item],
            *lines.boxes("guilde_bonus_apres", outside[:title]).map { |box| ["Once", box] })
        g[:bonuses].push({ enemy: enemy[:id], item: item, label: label, map: g[:hq] })
      end
    end
  end

  # The settling of scores (#190): for each guild of the world with a
  # rallying enemy of the world (rivals), its right hand (a member, its team
  # into trainers) and, by its headquarters, the ally's leader, there once
  # the ally rallied and gone once the guild's switch is on, who starts the
  # double battle. Each guild's goes to its :showdown ({ ally:, partner:,
  # foes: [[type, name, team]], label:, map: }).
  def showdowns(atlas, guilds, drawn, rivals, species, zones, plans, trainers, names, lines, rng)
    zones = zones.to_h { |zone| [zone.name, zone] }
    drawn.each do |g|
      rival = rivals[g[:id]]
      ally = rival && drawn.find { |a| a[:id] == rival[:ally] }
      next if !ally
      guild = guilds.find { |x| x.id == g[:id] }
      outside = atlas[:maps][g[:hq]]
      anchor = outside[:doors].find { |_x, _y, kind| kind == guild.hq } ||
               (outside[:hqs] || []).find { |_x, _y, kind| kind == guild.hq }
      cell = hq_cell(outside, anchor, plans[g[:hq]], rng)
      type = guild.member_types.sample(random: rng)
      name = cell && trainer_name(type, names, rng)
      next if !name
      seals = zones[g[:hq]].seals
      top = [g[:level] - GUILD_SECOND_GAP, 2].max
      team = pool_party(species, guild.pool.filter_map { |id| species[id] }, rng.rand(GUILD_SECOND_SIZES),
                        top - PARTY_LEVEL_SPREAD, top, seals, rng)
      trainers.push(team_section(type, name, lines.text("guilde_#{guild.id.downcase}_membre_fin", outside[:title]), team))
      partner = [ally[:leader][:type], ally[:leader][:name]]
      foes = [[g[:leader][:type], g[:leader][:name], g[:leader][:team]], [type, name, team]]
      args = [*partner, *foes.flat_map { |t, n, _team| [t, n] }].map { |v| v.is_a?(Symbol) ? ":#{v}" : v.inspect }
      label = "Reglement#{guild.id.capitalize}"
      add(plans, g[:hq], "Npc", label, cell[0], cell[1], ["Graphic", "trainer_#{ally[:leader][:type]}"], ["Facing", cell[2]],
          ["Show", "S#{rival[:rage]}"], ["Hide", "S#{g[:switch]}"],
          *lines.boxes("guilde_reglement", outside[:title]).map { |box| ["Text", box] },
          ["Script", "WorldEvents.showdown(#{args.join(', ')}, #{g[:switch]})"])
      g[:showdown] = { ally: ally[:id], partner: partner, foes: foes, label: label, map: g[:hq] }
      # Its leader counts as beaten once the showdown is won
      leader = plans[g[:map]].find { |*, text| text.start_with?("[Trainer #{g[:leader][:label]}]") }
      leader[2] += "EndIfSwitch = #{g[:switch]}\n"
    end
  end

  #-----------------------------------------------------------------------------
  # Blocking headquarters (#188)
  #-----------------------------------------------------------------------------
  # The guild whose members bar its route, in GUILD_BLOCK_CHANCE % of the
  # worlds that have one that can (blockade_candidates): { id:, route:,
  # cells: [[x, y]], facing: }, else nil. zones: world_zones.
  def guild_blockade(result, atlas, guilds, zones, rng)
    candidates = blockade_candidates(result, atlas, guilds, zones)
    return nil if candidates.empty? || rng.rand(100) >= GUILD_BLOCK_CHANCE
    return candidates.sample(random: rng)
  end

  # Every blockade the world allows: a guild of GUILD_BLOCKING whose
  # headquarters' place branches off a route of the chain (no crossing,
  # cave, other branch, loop or shortcut by it nor around it) reached with
  # GUILD_BLOCK_SEALS seals or more, and whose members, across the inner row
  # of that route's exit onward, cut the way while the exit to the
  # headquarters (anchor) is still reached from the way in.
  def blockade_candidates(result, atlas, guilds, zones)
    seals = zones.to_h { |zone| [zone.name, zone.seals] }
    extras = result.places.map(&:first).select { |wp| wp.extra && wp.extra != MapProceduralGenerator::HQ_EXTRA }
    return guilds.filter_map do |guild|
      hq, = result.places.find { |w, *| w.name == (atlas[:hqs] || {})[guild.hq] }
      wp = hq&.ends&.first
      next if !wp || !GUILD_BLOCKING.include?(guild.position) || wp.kind != "route" || (seals[wp.name] || 0) < GUILD_BLOCK_SEALS
      next if wp.extra || wp.crossing || wp.cave || wp.victory || wp.league || wp.exits.length != 3
      next if extras.any? { |e| e.ends[0].index < wp.index && e.ends[1].index > wp.index }
      spots = atlas[:maps][wp.name]
      cells = gate_cells([spots[:exits][1]])
      anchor = spots[:exits][2][1, 2]
      next if !blockade_holds?(spots, cells, anchor)
      { id: guild.id, route: wp.name, cells: cells, facing: INWARD[spots[:exits][1][0]], anchor: anchor }
    end
  end

  # True if these cells (on the ground) cut the way from the exit in to the
  # exit onward, and the anchor (the exit to the headquarters' place) is
  # still reached from the way in, and the exit onward once they are gone.
  def blockade_holds?(spots, cells, anchor)
    ground = (spots[:ground] || []).to_h { |cell| [cell, true] }
    from, onward = spots[:exits].first(2).map { |_side, x, y| [x, y] }
    return false if !cells.all? { |cell| ground[cell] } || !ground[from] || !ground[onward]
    return false if walk_cells(ground, from, cells)[onward] || !walk_cells(ground, from, [])[onward]
    return walk_cells(ground, from, cells).key?(anchor)
  end

  INWARD = { "nord" => "bas", "sud" => "haut", "ouest" => "droite", "est" => "gauche" }.freeze

  # The members across the route: one on each cell, gone once the guild's
  # switch is on.
  def bar_route(plans, blocks, guild, switch, lines, title)
    blocks[:cells].each_with_index do |(x, y), i|
      add(plans, blocks[:route], "Npc", "Barrage#{guild.id.capitalize}#{i + 1}", x, y,
          ["Graphic", "trainer_#{guild.member_types[i % guild.member_types.length]}"], ["Facing", blocks[:facing]],
          ["Hide", "S#{switch}"], *lines.boxes("guilde_barrage", title).map { |box| ["Text", box] })
    end
  end

  #-----------------------------------------------------------------------------
  # Freed zones (#187)
  #-----------------------------------------------------------------------------
  # { guild id => { town:, maps:, switch: } } for each affiliated guild of
  # the world (GUILD_FREEING): the town nearest its headquarters along the
  # chain (its own if it is in one, never the first town), whose inhabitants
  # speak freely once the guild's switch is on, and the maps the Cousins
  # leave then: that town and the routes that touch it. A town or a route is
  # freed by one guild only (the first of guildes.txt).
  def guild_liberations(result, atlas, guilds)
    places = result.places.map(&:first)
    towns = places.select { |wp| wp.kind == "ville" && wp.name != atlas[:start] && !wp.league && !wp.victory }
    used = []
    freed = {}
    guilds.each do |guild|
      hq = places.find { |wp| wp.name == (atlas[:hqs] || {})[guild.hq] }
      next if !hq || guild.position != GUILD_FREEING
      at = chain_index(hq)
      town = towns.reject { |wp| used.include?(wp.name) }.min_by { |wp| [(wp.index - at).abs, wp.index] }
      next if !town
      routes = places.select do |wp|
        next false if wp.kind != "route" || used.include?(wp.name)
        wp.extra ? wp.ends.include?(town) : (wp.index - town.index).abs == 1
      end
      maps = [town.name, *routes.map(&:name)]
      used.concat(maps)
      freed[guild.id] = { town: town.name, maps: maps, switch: guild_switch(guilds, guild) }
    end
    return freed
  end

  #-----------------------------------------------------------------------------
  # Rewards (#186)
  #-----------------------------------------------------------------------------
  # What a guild gives once its leader is beaten, by its position. An ally
  # rallies: a Pokémon of its pool of the imposed type, at the leader's
  # level ({ kind: "pokemon", species:, level: }); else the nearest shortcut
  # still closed is opened ({ kind: "raccourci", route:, title:, obstacle:, cells:
  # of its obstacle's events }); else a field item ahead of its town ({
  # kind: "terrain", item: }). The others (and an ally with none of
  # those): an item and money ({ kind: "objet", item:, money: }). hq: its
  # headquarters' place; taken: the shortcuts and field items other guilds
  # give.
  def guild_reward(guild, hq, result, atlas, species, type, level, seals, taken, rng)
    if guild.position == GUILD_ALLY
      typed = guild.pool.filter_map { |id| species[id] }.select { |sp| type && sp.monotype_types.include?(type) }
      if !typed.empty?
        id, given = pool_party(species, typed, 1, level, level, seals, rng)[0]
        return { kind: "pokemon", species: id, level: given }
      end
      shortcut = guild_shortcuts(result, hq).find { |wp, _layout| !taken.include?(wp.name) }
      if shortcut
        obstacle, *cells = shortcut[1].spots[:lock]
        return { kind: "raccourci", route: shortcut[0].name, title: shortcut[0].title, obstacle: obstacle, cells: cells.each_slice(2).to_a }
      end
      item = (guild_field_items(result, atlas, hq) - taken).first
      return { kind: "terrain", item: item } if item
    end
    line = NOOK_TABLE[NOOK_TABLE.keys.select { |from| from <= seals }.max].reject { |loot, _weight| loot == :TM }
    pick = rng.rand(line.values.sum)
    return { kind: "objet", item: line.find { |_item, weight| (pick -= weight) < 0 }[0], money: GUILD_MONEY * (seals + 1) }
  end

  # Index along the chain of a place (a route off the chain: its end nearer
  # the start).
  def chain_index(wp)
    return wp.extra ? wp.ends[0].index : wp.index
  end

  # [[shortcut, its layout]] a guild at hq can open, the nearest first: an
  # obstacle with an event (GUILD_OPENABLE, not the water) that the player
  # can't pass yet when reaching the headquarters.
  def guild_shortcuts(result, hq)
    at = chain_index(result.places.find { |wp, *| wp.name == hq }[0])
    closed = result.places.select do |wp, _place, _text, layout|
      wp.extra == "raccourci" && GUILD_OPENABLE.include?(wp.lock) && layout.spots[:lock] && wp.tier > at
    end
    return closed.sort_by { |wp, *| [wp.ends.map { |e| (e.index - at).abs }.min, wp.index] }.map { |wp, *rest| [wp, rest.last] }
  end

  # The field items given in a town after the headquarters, in the order of
  # the chain.
  def guild_field_items(result, atlas, hq)
    index = result.places.to_h { |wp, *| [wp.name, wp.index] }
    at = chain_index(result.places.find { |wp, *| wp.name == hq }[0])
    return atlas[:items].select { |_item, town| index[town] && index[town] > at }.sort_by { |_item, town| index[town] }.map(&:first)
  end

  # The lines of the leader's plan for its reward.
  def reward_lines(reward, lines)
    case reward && reward[:kind]
    when "pokemon"   then [["Reward", "WorldEvents.guild_pokemon(:#{reward[:species]}, #{reward[:level]})"]]
    when "raccourci" then [["Win", lines.text("guilde_raccourci", reward[:title])]]
    when "terrain"   then [["Gift", reward[:item]]]
    when "objet"     then [["Gift", reward[:item]], ["Reward", "WorldEvents.guild_money(#{reward[:money]})"]]
    else []
    end
  end

  # A cell for a trainer by the street nearest the headquarters (anchor: its
  # door or its middle), else anywhere by a street of the place; only among
  # those cells when given ({ [x, y] => true }).
  def hq_cell(spots, anchor, taken, rng, allowed = nil)
    ax, ay, = anchor
    cells = facing_cells(spots)
    cells = cells.select { |x, y, _facing| allowed[[x, y]] } if allowed
    near = cells.min_by(GUILD_NEAR_CELLS) { |x, y, _facing| [(x - ax).abs + (y - ay).abs, y, x] }
    return trainer_cell(spots, near, taken, rng) || trainer_cell(spots, cells, taken, rng)
  end

  # Level of a guild's leader: the strongest trainer of the Tronçon of its
  # zone (the top of the wild Pokémon of its zones), under the cap.
  def guild_level(zones, zone, caps)
    top = zones.values.select { |z| z.seals == zone.seals }.map { |z| z.levels[1] }.max
    return [top, caps[zone.seals] || caps.last].min
  end

  # The members by the street, nearest the headquarters first (route: their
  # map). In a dungeon (lock: its switch), one in the corridor of each gate
  # first, facing the exit (across its corridor in a guild of rooms) and
  # gone once beaten (the first one closes the exit), the others past the
  # first gate.
  def guild_members(spots, anchor, guild, pool, species, zone, level, route, plans, trainers, names, (lines, tag, title), rng,
                    rivals = {}, lock = nil)
    sizes = PARTY_SIZES[[zone.seals, PARTY_SIZES.length - 1].min]
    members = []
    gates = (lock ? spots[:gates] : []).each_with_index.map do |(x, y), i|
      [x, y, spots[:gate_facing]&.[](i) || FACE_EXIT[spots[:exits][0][0]], GUILD_GATE_SIGHT]
    end
    inside = lock && past_gate(spots, 0)
    [rng.rand(GUILD_MEMBERS), gates.length].max.times do |i|
      cell = gates[i] || hq_cell(spots, anchor, plans[route], rng, inside)
      break if !cell
      type = guild.member_types.sample(random: rng)
      name = trainer_name(type, names, rng)
      next if !name
      top = level - rng.rand(MEMBER_LEVEL_GAP)
      team = pool_party(species, pool, rng.rand(sizes), top - PARTY_LEVEL_SPREAD, top, zone.seals, rng)
      lose = lines.text("#{tag}_membre_fin", title)
      trainers.push(team_section(type, name, lose, team))
      x, y, facing, sight = cell
      label = guild_label(plans[route], guild)
      gate = (i < gates.length) ? [["Hide", "A"], *((i == 0) ? [["Switch", lock]] : [])] : []
      add(plans, route, "Trainer", label, x, y, ["Facing", facing], ["Sight", sight], ["Type", type],
          ["Name", name], ["BattleID", TRAINER_VERSION], ["Battle", lines.text("#{tag}_membre_combat", title)],
          ["EndBattle", lose], *gate, *rage_lines(rivals, guild, spots, cell, lines, title))
      members.push({ type: type, name: name, team: team, label: label, map: route })
    end
    return members
  end

  #-----------------------------------------------------------------------------
  # Dungeons (#335)
  #-----------------------------------------------------------------------------
  FACE_EXIT = { "nord" => "haut", "sud" => "bas", "ouest" => "gauche", "est" => "droite" }.freeze
  FACE_IN = { "nord" => "bas", "sud" => "haut", "ouest" => "droite", "est" => "gauche" }.freeze

  # The game switch that closes a guild's dungeon: its rank in guildes.txt
  # after GUILD_LOCK_SWITCH.
  def guild_lock(guilds, guild)
    return GUILD_LOCK_SWITCH + guilds.index(guild) + 1
  end

  # The ground of a dungeon past that gate (an index of spots[:gates], -1:
  # the last one): { [x, y] => true }, the cells not reached from its exit
  # (where the player comes in: entry) through that gate's corridor (its
  # cells: cuts, else its guard's cell).
  def past_gate(spots, gate)
    ground = (spots[:ground] || []).to_h { |cell| [cell, true] }
    cut = spots[:cuts] ? spots[:cuts][gate] : [spots[:gates][gate]]
    near = walk_cells(ground, spots[:entry] || spots[:exits][0][1, 2], cut)
    return ground.reject { |cell, _| near[cell] }
  end

  # The exit of a dungeon closed once its first member is beaten (lock on)
  # until its leader is (switch on): a member of the guild on each cell of
  # its inner row (the exit itself in a guild of rooms: locks), facing in,
  # saying [guilde_sortie] when the player walks into it. Being seen, it
  # bars the way (Essentials lets the player walk through an unseen event).
  def close_exit(plans, spots, guild, route, lock, switch, lines, title)
    cells = spots[:locks] || gate_cells([spots[:exits][0]])
    facing = spots[:locks] ? "bas" : FACE_IN[spots[:exits][0][0]]
    cells.each_with_index do |(x, y), i|
      add(plans, route, "Npc", "Sortie#{guild.id.capitalize}#{i + 1}", x, y, ["Graphic", "trainer_#{guild.member_types.first}"],
          ["Facing", facing], ["Trigger", "contact"], ["Show", "S#{lock}"], ["Hide", "S#{switch}"],
          *lines.boxes("guilde_sortie", title).map { |box| ["Text", box] })
    end
  end
end
