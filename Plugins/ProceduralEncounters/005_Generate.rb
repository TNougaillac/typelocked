#===============================================================================
# ProceduralEncounters - Written with the world
# When MapProceduralGenerator writes a world (debug menu or new game), the
# encounters of its maps replace their sections in PBS/encounters.txt (the
# other maps are left alone), then the file is recompiled. The sections of
# the maps it deletes are removed. A copy goes next to the world's
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

  # quiet: console only (world of a new game).
  # The dungeons of the guilds draw from their pools (WorldEvents, when
  # installed).
  def write_world(result, map_ids, seed, export, quiet: false)
    species = load_species
    pools = defined?(WorldEvents) ? WorldEvents.guild_pools(WorldEvents.load_guilds(".", species)) : {}
    lines, generated = world_encounters(result, species, level_caps, seed, pools)
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
    report(generated, lines.count { |_name, body| !body.empty? }, quiet)
  end

  # Removes the sections of these deleted maps.
  def remove_maps(ids)
    pbs = MapGenerator.read_pbs(ENCOUNTERS_PBS)
    ids.each { |id| set_section(pbs, id, nil, []) }
    MapGenerator.write_pbs(ENCOUNTERS_PBS, pbs)
    Compiler.compile_encounters(ENCOUNTERS_PBS)
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

  def report(generated, maps, quiet = false)
    Console.echoln_li(_INTL("Rencontres sauvages écrites pour {1} cartes.", maps)) if quiet
    pbMessage(_INTL("Rencontres sauvages écrites pour {1} cartes.", maps)) if !quiet
    generated.gaps.each do |seals, type|
      Console.echoln_li(_INTL("Rencontres : aucun Pokémon {1} capturable avec {2} sceau(x).", type, seals))
    end
    return if quiet || generated.gaps.empty?
    pbMessage(_INTL("Attention : {1} type(s) sans Pokémon sur un tronçon. Détail dans la console.", generated.gaps.length))
  end
end

module MapProceduralGenerator
  class << self
    alias_method :__encounters_generate_world, :generate_world
    alias_method :__encounters_generate_world_maps, :generate_world_maps
    alias_method :__encounters_remove_maps, :remove_maps

    # Keeps the last world, for its encounters once its maps are written.
    def generate_world(*args)
      @encounters_world = __encounters_generate_world(*args)
      return @encounters_world
    end

    # computed: the world drawn beforehand (compute_world, during the intro)
    def generate_world_maps(path, seed, quiet: false, prune: false, computed: nil)
      @encounters_world = computed[2] if computed
      export, start = __encounters_generate_world_maps(path, seed, quiet: quiet, prune: prune, computed: computed)
      ProceduralEncounters.write_world(@encounters_world, read_world_maps(path), seed, export, quiet: quiet)
      return export, start
    end

    # Maps of an unsaved game's world, deleted: their encounters go too.
    def remove_maps(ids, compile: true)
      __encounters_remove_maps(ids, compile: compile)
      ProceduralEncounters.remove_maps(ids) if !ids.empty?
    end
  end
end
