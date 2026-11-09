#===============================================================================
# WorldEvents - Guilds
# The guilds of MapProc/Lore/guildes.txt (spec #181): read and checked (an
# error names the file and the line), then, for each guild whose
# headquarters MapProceduralGenerator drew in the world (WORLD_GUILDS), its
# leader inside (by the street when its headquarters has no door) and 2 to 4
# members outside, their teams drawn from its pool at the level of the
# Tronçon. Plain Ruby.
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

  #-----------------------------------------------------------------------------
  # On the routes
  #-----------------------------------------------------------------------------
  # { route name => [Guild] }: the guilds of the world (a headquarters in
  # atlas[:hqs]) whose members walk each route: those of its ambiance, and,
  # for a guild without biomes (its headquarters in a town), the routes next
  # to its headquarters' place.
  def guild_routes(result, atlas, guilds)
    hqs = atlas[:hqs] || {}
    present = guilds.select { |guild| hqs[guild.hq] }
    index = result.places.to_h { |wp, *| [wp.name, wp.index] }
    routes = {}
    result.places.sort_by { |wp, *| wp.index }.each do |wp, _place, _text, layout|
      next if wp.kind != "route" || wp.victory
      list = present.select do |guild|
        next guild.biomes.include?(layout.ambiance) if !guild.biomes.empty?
        (index[hqs[guild.hq]] - wp.index).abs == 1
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
  def guild_events(atlas, guilds, species, zones, caps, plans, trainers, names, lines, sets, rng)
    zones = zones.to_h { |zone| [zone.name, zone] }
    return guilds.filter_map do |guild|
      route = (atlas[:hqs] || {})[guild.hq]
      zone = route && zones[route]
      outside = route && atlas[:maps][route]
      anchor = outside && (outside[:doors].find { |_x, _y, kind| kind == guild.hq } ||
                           (outside[:hqs] || []).find { |_x, _y, kind| kind == guild.hq })
      next if !zone || !anchor
      # Its leader inside (a headquarters with a door), else by the street
      # nearest it, like its members
      map, spots = atlas[:maps].find { |_name, m| m[:kind] == "interieur" && m[:building] == guild.hq && m[:owner] == route }
      x, y, facing = spots && GUILD_LEADER_SPOTS[spots[:template]]
      cell = x ? [x, y, facing, 1] : hq_cell(outside, anchor, plans[route], rng)
      next if !cell
      map = route if !x
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
      add(plans, map, "Trainer", "Chef#{label}", cell[0], cell[1], ["Facing", cell[2]], ["Sight", cell[3]], ["Type", guild.leader],
          ["Name", name], ["BattleID", TRAINER_VERSION], ["Battle", lines.text("#{tag}_chef_combat", title)], ["EndBattle", lose])
      members = guild_members(outside, anchor, guild, pool, species, zone, level, route, plans, trainers, names,
                              [lines, tag, title], rng)
      { id: guild.id, name: guild.name, position: guild.position, hq: route, map: map, seals: seals, level: level,
        leader: { type: guild.leader, name: name, team: team, sets: team_sets, label: "Chef#{label}" }, members: members,
        routes: [] }
    end
  end

  # A cell for a trainer by the street nearest the headquarters (anchor: its
  # door or its middle), else anywhere by a street of the place.
  def hq_cell(spots, anchor, taken, rng)
    ax, ay, = anchor
    cells = facing_cells(spots)
    near = cells.min_by(GUILD_NEAR_CELLS) { |x, y, _facing| [(x - ax).abs + (y - ay).abs, y, x] }
    return trainer_cell(spots, near, taken, rng) || trainer_cell(spots, cells, taken, rng)
  end

  # Level of a guild's leader: the strongest trainer of the Tronçon of its
  # zone (the top of the wild Pokémon of its zones), under the cap.
  def guild_level(zones, zone, caps)
    top = zones.values.select { |z| z.seals == zone.seals }.map { |z| z.levels[1] }.max
    return [top, caps[zone.seals] || caps.last].min
  end

  # The members by the street, nearest the headquarters first.
  def guild_members(spots, anchor, guild, pool, species, zone, level, route, plans, trainers, names, (lines, tag, title), rng)
    sizes = PARTY_SIZES[[zone.seals, PARTY_SIZES.length - 1].min]
    members = []
    rng.rand(GUILD_MEMBERS).times do
      cell = hq_cell(spots, anchor, plans[route], rng)
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
      add(plans, route, "Trainer", label, x, y, ["Facing", facing], ["Sight", sight], ["Type", type],
          ["Name", name], ["BattleID", TRAINER_VERSION], ["Battle", lines.text("#{tag}_membre_combat", title)],
          ["EndBattle", lose])
      members.push({ type: type, name: name, team: team, label: label })
    end
    return members
  end
end
