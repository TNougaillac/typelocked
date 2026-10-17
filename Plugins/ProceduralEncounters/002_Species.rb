#===============================================================================
# ProceduralEncounters - Pokémon of the roster
# Read from the roster CSV and the PBS (plain Ruby, so the CI runs it too).
# min_level: lowest wild level (its evolution levels); min_seals: seals needed
# before it shows up (evolutions by stone, friendship, trade...).
#===============================================================================
module ProceduralEncounters
  Species = Struct.new(:id, :types, :monotype_types, :tier, :family, :prevo, :stage,
                       :min_level, :min_seals)

  module_function

  def read_text(path)
    return File.read(path, encoding: "UTF-8").sub(/\A﻿/, "")
  end

  # id => Species, in the roster's order.
  def load_species(root = ".")
    rows = read_text(File.join(root, ROSTER_FILE)).lines.drop(1).map { |l| l.chomp.split(",") }
    species = rows.to_h do |r|
      [r[0].to_sym, Species.new(r[0].to_sym, r[2].split("/").map(&:to_sym), r[3].split("/").map(&:to_sym),
                                r[7], r[8], nil, 1, 1, 0)]
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
