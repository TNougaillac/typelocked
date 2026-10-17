#===============================================================================
# ProceduralEncounters - Encounter tables
# 1. Each table draws a few Pokémon by weight: biome of the table, tier,
#    stage, and how many tables already have them.
# 2. Types: between two lieutenants (same number of seals), every type of the
#    roster gets at least one Pokémon a Monotype run of that type can catch,
#    in a land, cave or surfing table (surfing once Surf is obtained).
# 3. Families: every family of the roster shows up at least once in the world.
# Plain Ruby: same zones + same seed = same tables.
#===============================================================================
module ProceduralEncounters
  # A map that gets encounters. levels: [min, max] of the place; land_biome:
  # biome of its Land table; types: encounter types to write (TABLES keys);
  # surf: Surf is obtained by then.
  Zone = Struct.new(:name, :index, :seals, :levels, :land_biome, :types, :surf)
  Entry = Struct.new(:species, :weight, :min_level, :max_level)
  Table = Struct.new(:zone, :type, :levels, :slots)
  # gaps: [seals, type] left without a Pokémon; missing: families nowhere
  Result = Struct.new(:tables, :gaps, :missing)

  module_function

  def generate(zones, species, seed)
    rng = Random.new(seed)
    uses = Hash.new(0)
    tables = zones.flat_map do |zone|
      zone.types.map { |type| Table.new(zone, type, table_levels(zone, type), []) }
    end
    tables.each do |table|
      rng.rand(TABLES[table.type][:species]).times do
        picks = species.values.filter_map { |sp| (w = weight(sp, table, uses)) > 0 && [sp, w] }
        break if picks.empty?
        sp, w = weighted(picks, rng)
        add(table, sp, w, uses)
      end
    end
    gaps = cover_types(tables, species, uses, rng)
    missing = cover_families(tables, species, uses, rng)
    tables.each { |t| t.slots.sort_by!.with_index { |e, i| [-e.weight, i] } }
    return Result.new(tables, gaps, missing)
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

  def biome_weight(sp, table)
    weights = BIOMES[biome_of(table)] || {}
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

  def add(table, sp, weight, uses)
    table.slots.push(Entry.new(sp, weight, [table.levels[0], sp.min_level].max, table.levels[1]))
    uses[sp.id] += 1
  end

  def room?(table)
    return table.slots.length < TABLES[table.type][:max]
  end

  # A Pokémon added by a coverage pass is rare in its table.
  def rare_weight(table)
    return (table.slots.map(&:weight).min || 1.0) * 0.5
  end

  # The best Pokémon among those that fit, for these tables: the most wanted
  # types first (score), then biome, the earliest stage, the least used, the
  # emptiest table, then by chance. Returns [table, species] or nil.
  def best_pick(tables, candidates, uses, rng, &score)
    score ||= proc { 0 }
    options = tables.select { |t| room?(t) }.flat_map do |table|
      candidates.select { |sp| fits?(sp, table) }.map { |sp| [table, sp] }
    end
    return nil if options.empty?
    keyed = options.map do |table, sp|
      [[-score.call(sp), -biome_weight(sp, table), sp.stage, uses[sp.id], table.slots.length, rng.rand], table, sp]
    end
    return keyed.min_by(&:first).drop(1)
  end

  # Picks first the Pokémon that bring the most missing types at once.
  def cover_types(tables, species, uses, rng)
    all_types = species.values.flat_map(&:monotype_types).uniq
    covering = tables.select do |t|
      cover = TABLES[t.type][:cover]
      cover == true || (cover == :surf && t.zone.surf)
    end
    gaps = []
    covering.group_by { |t| t.zone.seals }.sort.each do |seals, segment|
      missing = all_types.reject do |type|
        segment.any? { |t| t.slots.any? { |e| e.species.monotype_types.include?(type) } }
      end
      until missing.empty?
        candidates = species.values.select { |sp| sp.monotype_types.intersect?(missing) }
        table, sp = best_pick(segment, candidates, uses, rng) { |c| (c.monotype_types & missing).length }
        break gaps.concat(missing.map { |type| [seals, type] }) if !table
        add(table, sp, rare_weight(table), uses)
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
      add(table, sp, rare_weight(table), uses)
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

  # PBS lines of a zone's tables (encounters.txt format, under its [ID]).
  def zone_lines(tables)
    lines = []
    tables.each do |table|
      next if table.slots.empty?
      density = TABLES[table.type][:density]
      lines.push(density ? "#{table.type},#{density}" : table.type)
      percents(table.slots.map(&:weight)).zip(table.slots).each do |pct, e|
        levels = (e.min_level == e.max_level) ? e.min_level.to_s : "#{e.min_level},#{e.max_level}"
        lines.push("    #{pct},#{e.species.id},#{levels}")
      end
    end
    return lines
  end
end
