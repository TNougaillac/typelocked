#===============================================================================
# ProceduralEncounters - Encounter tables
# 1. Each land or cave table draws its dominant types from its biome (less
#    likely those of the previous place), then a few Pokémon by weight: biome,
#    tier, stage, and how many tables already have them. Pokémon of the
#    dominant types make DOMINANT_SHARE of the encounters.
# 2. Types: in each tronçon (same number of seals), every type of the roster
#    gets at least one Pokémon a Monotype run of that type can catch, in a
#    land, cave or surfing table (surfing once Surf is obtained) of that
#    tronçon or of the previous ones within COVER_WINDOW.
# 3. Families: every family of the roster shows up at least once in the world.
# Coverage first fills tables up to their max, then up to their overflow.
# Plain Ruby: same zones + same seed = same tables.
#===============================================================================
module ProceduralEncounters
  # A map that gets encounters. levels: [min, max] of the place; land_biome:
  # biome of its Land table; types: encounter types to write (TABLES keys);
  # surf: Surf is obtained by then.
  Zone = Struct.new(:name, :index, :seals, :levels, :land_biome, :types, :surf)
  # role: :dominant (of a dominant type), :biome or :cover (added by a
  # coverage pass)
  Entry = Struct.new(:species, :weight, :min_level, :max_level, :role)
  Table = Struct.new(:zone, :type, :levels, :slots, :dominant)
  # gaps: [seals, type] left without a Pokémon; missing: families nowhere
  Result = Struct.new(:tables, :gaps, :missing)

  module_function

  def generate(zones, species, seed)
    rng = Random.new(seed)
    uses = Hash.new(0)
    tables = zones.flat_map do |zone|
      zone.types.map { |type| Table.new(zone, type, table_levels(zone, type), [], []) }
    end
    previous = []
    tables.each do |table|
      if TABLES[table.type][:dominant]
        table.dominant = draw_dominant(table, previous, rng)
        previous = table.dominant
      end
      count = rng.rand(TABLES[table.type][:species])
      dominant_count = table.dominant.empty? ? 0 : (count * DOMINANT_SHARE).round
      count.times do |i|
        picks = species.values.filter_map { |sp| (w = weight(sp, table, uses)) > 0 && [sp, w] }
        wanted = picks.select { |sp, _w| sp.types.intersect?(table.dominant) }
        picks = wanted if i < dominant_count && !wanted.empty?
        break if picks.empty?
        sp, w = weighted(picks, rng)
        add(table, sp, w, uses, sp.types.intersect?(table.dominant) ? :dominant : :biome)
      end
    end
    gaps = cover_types(tables, species, uses, rng)
    missing = cover_families(tables, species, uses, rng)
    tables.each { |t| t.slots.sort_by!.with_index { |e, i| [-e.weight, i] } }
    return Result.new(tables, gaps, missing)
  end

  # DOMINANT_TYPES types of the table's biome, by weight, those of the
  # previous place DOMINANT_REPEAT times as likely.
  def draw_dominant(table, previous, rng)
    picks = type_weights(table).map { |type, w| [type, previous.include?(type) ? w * DOMINANT_REPEAT : w] }
    picks.reject! { |_type, w| w <= 0 }
    chosen = []
    DOMINANT_TYPES.times do
      break if picks.empty?
      type, = weighted(picks, rng)
      chosen.push(type)
      picks.reject! { |t, _w| t == type }
    end
    return chosen
  end

  # Wild levels of a place, from its seals and its position (0 to 1) among
  # the places between the same two lieutenants.
  def zone_levels(seals, position, caps)
    lo = seals.zero? ? START_LEVEL : caps[seals - 1] || caps.last
    hi = caps[seals] || caps.last
    center = (lo + ((hi - lo) * position * LEVEL_REACH)).round
    max = [center + 2, hi].min
    return [[[center - 1, 2].max, max].min, max]
  end

  def table_levels(zone, type)
    shift = TABLES[type][:shift]
    min = [zone.levels[0] + shift, 2].max
    return [min, [zone.levels[1] + shift, min].max]
  end

  def biome_of(table)
    return "grotte" if table.type == "Cave"
    return "eau" if TABLES[table.type][:type] == :WATER
    return table.zone.land_biome
  end

  # Type => weight in that table (its biome's).
  def type_weights(table)
    return BIOMES[biome_of(table)] || {}
  end

  def biome_weight(sp, table)
    weights = type_weights(table)
    return sp.types.map { |t| weights[t] || 0 }.max
  end

  # Can that Pokémon be in that table at all (type, stage, levels, family)?
  def fits?(sp, table)
    conf = TABLES[table.type]
    return false if conf[:type] && !sp.types.include?(conf[:type])
    return false if conf[:weak] && (sp.tier != "faible" || sp.stage > 1)
    return false if sp.min_seals > table.zone.seals || sp.min_level > table.levels[1]
    return table.slots.none? { |e| e.species.family == sp.family }
  end

  def weight(sp, table, uses)
    return 0 if !fits?(sp, table)
    tier = TIER_WEIGHTS[sp.tier] || 1.0
    tier += table.zone.seals * FORT_PER_SEAL if sp.tier == "fort"
    return biome_weight(sp, table) * tier / sp.stage / (1 + (uses[sp.id] * REUSE_PENALTY))
  end

  def weighted(picks, rng)
    roll = rng.rand * picks.sum { |_sp, w| w }
    picks.each do |pick|
      roll -= pick[1]
      return pick if roll < 0
    end
    return picks.last
  end

  def add(table, sp, weight, uses, role)
    table.slots.push(Entry.new(sp, weight, [table.levels[0], sp.min_level].max, table.levels[1], role))
    uses[sp.id] += 1
  end

  def room?(table, limit = :max)
    return table.slots.length < (TABLES[table.type][limit] || TABLES[table.type][:max])
  end

  # The best Pokémon among those that fit, for these tables: the most wanted
  # types first (score), then biome, the earliest stage, the least used, the
  # emptiest table, then by chance. Tables up to their max first, up to their
  # overflow as a last resort. Returns [table, species] or nil.
  def best_pick(tables, candidates, uses, rng, &score)
    score ||= proc { 0 }
    [:max, :overflow].each do |limit|
      options = tables.select { |t| room?(t, limit) }.flat_map do |table|
        candidates.select { |sp| fits?(sp, table) }.map { |sp| [table, sp] }
      end
      next if options.empty?
      keyed = options.map do |table, sp|
        [[-score.call(sp), -biome_weight(sp, table), sp.stage, uses[sp.id], table.slots.length, rng.rand], table, sp]
      end
      return keyed.min_by(&:first).drop(1)
    end
    return nil
  end

  # Picks first the Pokémon that bring the most missing types at once. A type
  # caught in the previous tronçons of the window counts.
  def cover_types(tables, species, uses, rng)
    all_types = species.values.flat_map(&:monotype_types).uniq
    covering = tables.select do |t|
      cover = TABLES[t.type][:cover]
      cover == true || (cover == :surf && t.zone.surf)
    end
    gaps = []
    # The window counts tronçons, not seals: a port and its island may both
    # have a gym, two seals at once with no tronçon between them
    tiers = covering.map { |t| t.zone.seals }.uniq.sort
    tiers.each_with_index do |seals, i|
      segment = covering.select { |t| t.zone.seals == seals }
      first = tiers[[i - COVER_WINDOW + 1, 0].max]
      window = covering.select { |t| t.zone.seals.between?(first, seals) }
      missing = all_types.reject do |type|
        window.any? { |t| t.slots.any? { |e| e.species.monotype_types.include?(type) } }
      end
      until missing.empty?
        candidates = species.values.select { |sp| sp.monotype_types.intersect?(missing) }
        table, sp = best_pick(segment, candidates, uses, rng) { |c| (c.monotype_types & missing).length }
        break gaps.concat(missing.map { |type| [seals, type] }) if !table
        add(table, sp, 0, uses, :cover)
        missing -= sp.monotype_types
      end
    end
    return gaps
  end

  def cover_families(tables, species, uses, rng)
    missing = []
    species.values.group_by(&:family).each do |family, members|
      next if tables.any? { |t| t.slots.any? { |e| e.species.family == family } }
      table, sp = best_pick(tables, members, uses, rng)
      next missing.push(family) if !table
      add(table, sp, 0, uses, :cover)
    end
    return missing
  end

  # Whole percents adding up to 100, at least 1 each (largest remainders).
  def percents(weights)
    exact = weights.map { |w| w * (100 - weights.length) / weights.sum.to_f }
    shares = exact.map { |p| p.floor + 1 }
    order = exact.each_index.sort_by { |i| [exact[i].floor - exact[i], i] }
    order.first(100 - shares.sum).each { |i| shares[i] += 1 }
    return shares
  end

  # [percent, slot] of a table, most common first: each coverage slot gets
  # COVER_PERCENT, the dominant ones share DOMINANT_SHARE of the encounters
  # (all that is left when no other is drawn), the others what remains, each
  # group by weight.
  def slot_percents(table)
    slots = table.slots
    cover = slots.count { |e| e.role == :cover }
    left = [100 - (cover * COVER_PERCENT), slots.length - cover].max.to_f
    groups = slots.reject { |e| e.role == :cover }.partition { |e| e.role == :dominant }
    dominant_total = [100 * DOMINANT_SHARE, left - groups[1].length].min
    dominant_total = 0.0 if groups[0].empty?
    dominant_total = left if groups[1].empty?
    totals = [dominant_total, left - dominant_total]
    weights = slots.map do |e|
      next COVER_PERCENT.to_f if e.role == :cover
      group = groups[(e.role == :dominant) ? 0 : 1]
      sum = group.sum(&:weight)
      totals[(e.role == :dominant) ? 0 : 1] * ((sum > 0) ? e.weight / sum : 1.0 / group.length)
    end
    return percents(weights).zip(slots).sort_by.with_index { |(pct, _e), i| [-pct, i] }
  end

  # PBS lines of a zone's tables (encounters.txt format, under its [ID]).
  def zone_lines(tables)
    lines = []
    tables.each do |table|
      next if table.slots.empty?
      density = TABLES[table.type][:density]
      lines.push(density ? "#{table.type},#{density}" : table.type)
      slot_percents(table).each do |pct, e|
        levels = (e.min_level == e.max_level) ? e.min_level.to_s : "#{e.min_level},#{e.max_level}"
        lines.push("    #{pct},#{e.species.id},#{levels}")
      end
    end
    return lines
  end
end
