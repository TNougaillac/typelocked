#===============================================================================
# ProceduralEncounters - Pokémon of the roster
# Read from the roster CSV and the PBS (plain Ruby, so the CI runs it too).
# min_level: lowest wild level (its evolution levels); min_seals: seals needed
# before it shows up (evolutions by stone, friendship, trade...).
#===============================================================================
module ProceduralEncounters
  Species = Struct.new(:id, :types, :monotype_types, :tier, :family, :prevo, :stage,
                       :min_level, :min_seals, :generation)

  module_function

  def read_text(path)
    return File.read(path, encoding: "UTF-8").sub(/\A﻿/, "")
  end

  # id => Species, in the roster's order.
  def load_species(root = ".")
    rows = read_text(File.join(root, ROSTER_FILE)).lines.drop(1).map { |l| l.chomp.split(",") }
    species = rows.to_h do |r|
      [r[0].to_sym, Species.new(r[0].to_sym, r[2].split("/").map(&:to_sym), r[3].split("/").map(&:to_sym),
                                r[7], r[8], nil, 1, 1, 0, r[4].to_i)]
    end
    evolutions = read_evolutions(File.join(root, POKEMON_PBS)) + read_evolutions(File.join(root, POKEMON_FORMS_PBS))
    evolutions.each do |from, to, param|
      next if !species[from] || !species[to] || species[to].prevo
      species[to].prevo = [from, param]
    end
    species.each_value { |sp| resolve_stage(species, sp) }
    return species
  end

  # [from, to, level or nil] for every evolution of the file.
  def read_evolutions(path)
    return [] if !File.exist?(path)
    from = nil
    list = []
    read_text(path).each_line do |line|
      if line =~ /\A\[(\w+)(?:,\d+)?\]/
        from = $1.to_sym
      elsif line =~ /\AEvolutions\s*=\s*(.+)/
        $1.split(",").map(&:strip).each_slice(3) do |to, _method, param|
          list.push([from, to.to_sym, (param.to_s =~ /\A\d+\z/) ? param.to_i : nil])
        end
      end
    end
    return list
  end

  # The Pokémon of a world (id => Species, in the roster's order): whole
  # families, first TYPE_FAMILIES per type, then up to WORLD_SPECIES, each
  # time the family among WORLD_SAMPLE drawn by chance that keeps types,
  # tiers and generations the most even.
  def world_species(species, seed)
    return species if species.length <= WORLD_SPECIES
    rng = Random.new(seed)
    families = species.values.group_by(&:family).values.shuffle(random: rng)
    buckets = { type: species.values.flat_map(&:monotype_types).uniq.length,
                tier: species.values.map(&:tier).uniq.length,
                gen: species.values.map(&:generation).uniq.length }
    keys = ->(sp) { sp.monotype_types.map { |t| [:type, t] } + [[:tier, sp.tier], [:gen, sp.generation]] }
    counts = Hash.new(0)
    chosen = []
    fits = ->(family) { chosen.sum(&:length) + family.length <= WORLD_SPECIES }
    take = lambda do |family|
      next if !fits.call(family)
      chosen.push(family)
      family.each { |sp| keys.call(sp).each { |k| counts[k] += 1 } }
    end
    cost = lambda do |family|
      family.sum { |sp| keys.call(sp).sum { |k| counts[k] * buckets[k[0]] } }.fdiv(family.length)
    end
    species.values.flat_map(&:monotype_types).uniq.shuffle(random: rng).each do |type|
      catching = families.select { |f| f.any? { |sp| sp.monotype_types.include?(type) } }
      (catching - chosen).first([TYPE_FAMILIES - (catching & chosen).length, 0].max).each(&take)
    end
    loop do
      options = (families - chosen).select(&fits)
      break if options.empty?
      take.call(options.sample(WORLD_SAMPLE, random: rng).min_by(&cost))
    end
    ids = chosen.flatten.to_h { |sp| [sp.id, true] }
    return species.select { |id, _sp| ids[id] }
  end

  def resolve_stage(species, sp)
    return if !sp.prevo || sp.stage > 1
    prevo = species[sp.prevo[0]]
    resolve_stage(species, prevo)
    sp.stage = prevo.stage + 1
    level = sp.prevo[1]
    sp.min_level = [prevo.min_level, level || 1].max
    sp.min_seals = [prevo.min_seals, level ? 0 : STAGE_SEALS[sp.stage] || STAGE_SEALS.values.max].max
  end
end
