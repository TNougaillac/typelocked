#===============================================================================
# ProceduralEncounters - Written with the world
# When MapProceduralGenerator writes a world (debug menu, not yet the world of
# a new game), the encounters of its maps replace their sections in
# PBS/encounters.txt (the other maps are left alone), then the file is
# recompiled. A copy goes next to the world's
# export (MapProc/Export/<world>_<seed>_rencontres.txt).
#===============================================================================
module ProceduralEncounters
  module_function

  # Cap of each number of seals: LevelCap's when installed, else CAPS.
  def level_caps
    return CAPS.each_index.map do |seals|
      cap = LevelCap.cap_for_seals(seals) if defined?(LevelCap)
      cap || CAPS[seals]
    end
  end

  def write_world(result, map_ids, seed, export)
    lines, generated = world_encounters(result, load_species, level_caps, seed)
    pbs = MapGenerator.read_pbs(ENCOUNTERS_PBS)
    copy = +""
    lines.each do |name, body|
      next if !map_ids[name]
      set_section(pbs, map_ids[name], name, body)
      copy << sprintf("[%03d]   # %s\n", map_ids[name], name) << body.map { |l| "#{l}\n" }.join if !body.empty?
    end
    MapGenerator.write_pbs(ENCOUNTERS_PBS, pbs)
    Compiler.compile_encounters(ENCOUNTERS_PBS)
    File.write(export.sub(/\.txt\z/, "_rencontres.txt"), copy)
    report(generated, lines.count { |_name, body| !body.empty? })
  end

  # Replaces the map's [ID] section with body, or removes it when body is
  # empty (no grass, water nor cave there any more).
  def set_section(lines, id, name, body)
    start = lines.index { |l| l =~ /\A\[\s*0*#{id}\s*\]/ }
    if start
      finish = start + 1
      finish += 1 while finish < lines.length && lines[finish] !~ /\A\[|\A#-/
      if body.empty?
        start -= 1 if start > 0 && lines[start - 1].start_with?("#-")
        lines.slice!(start...finish)
      else
        lines[start + 1...finish] = body
      end
    elsif !body.empty?
      lines.push("#-------------------------------") if !lines.empty?
      lines.push(sprintf("[%03d]   # %s", id, name), *body)
    end
  end

  def report(generated, maps)
    pbMessage(_INTL("Rencontres sauvages écrites pour {1} cartes.", maps))
    generated.gaps.each do |seals, type|
      Console.echoln_li(_INTL("Rencontres : aucun Pokémon {1} capturable avec {2} sceau(x).", type, seals))
    end
    generated.missing.each { |family| Console.echoln_li(_INTL("Rencontres : famille {1} absente du monde.", family)) }
    return if generated.gaps.empty? && generated.missing.empty?
    pbMessage(_INTL("Attention : {1} type(s) sans Pokémon sur un tronçon, {2} famille(s) absente(s). Détail dans la console.",
                    generated.gaps.length, generated.missing.length))
  end
end

module MapProceduralGenerator
  class << self
    alias_method :__encounters_generate_world, :generate_world
    alias_method :__encounters_generate_world_maps, :generate_world_maps

    # Keeps the last world, for its encounters once its maps are written.
    def generate_world(*args)
      @encounters_world = __encounters_generate_world(*args)
      return @encounters_world
    end

    # Not for the world of a new game (quiet) for now.
    def generate_world_maps(path, seed, quiet: false, prune: false)
      export, start = __encounters_generate_world_maps(path, seed, quiet: quiet, prune: prune)
      ProceduralEncounters.write_world(@encounters_world, read_world_maps(path), seed, export) if !quiet
      return export, start
    end
  end
end
