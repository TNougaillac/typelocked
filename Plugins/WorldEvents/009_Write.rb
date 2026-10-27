#===============================================================================
# WorldEvents - Written with the world
# When MapProceduralGenerator writes a world (debug menu or new game), the
# trainers drawn for it replace those of the last world in PBS/trainers.txt
# (version TRAINER_VERSION), then its events are placed by MapEvents on its
# maps, after the maps and their encounters. The plans and the trainers go
# next to the world's export (MapProc/Export/<world>_<seed>_evenements.txt,
# _dresseurs.txt), to read them or run them again from the MapEvents folder.
# When the world is deleted, its trainers go too.
#===============================================================================
module WorldEvents
  EXPORT_SUFFIXES = %w[_evenements _dresseurs].freeze

  module_function

  def write_world(result, seed, export)
    caps = ProceduralEncounters.level_caps
    species = ProceduralEncounters.load_species
    zones = ProceduralEncounters.world_zones(result, caps)
    _lines, generated = ProceduralEncounters.world_encounters(result, species, caps, seed)
    type = Monotype.active? ? Monotype.data.type : nil
    events = world_events(result, seed, zones: zones, encounters: generated, species: species, tms: game_tms, caps: caps,
                                        type: type)
    write_trainers(events[:trainers])
    events[:plans].each_value do |text|
      plan = MapEvents.parse(text, File.basename(export))
      _map_id, notes = MapEvents.generate(plan)
      notes.each { |note| Console.echoln_li(note) }
      MapProceduralGenerator.busy_update
    end
    separator = "\n#-------------------------------\n"
    File.write(export.sub(/\.txt\z/, "_evenements.txt"), events[:plans].values.join(separator))
    File.write(export.sub(/\.txt\z/, "_dresseurs.txt"), events[:trainers].join(separator))
    Console.echoln_li(_INTL("Événements placés sur {1} cartes, {2} dresseurs, {3} objets.", events[:plans].length,
                                 events[:trainers].length, events[:items].length))
  end

  # Every TM of the game: [[item, move, type, power, status?]]
  def game_tms
    tms = []
    GameData::Item.each do |item|
      next if !item.is_machine? || !item.move
      move = GameData::Move.get(item.move)
      tms.push([item.id, move.id, move.type, move.power, move.status?])
    end
    return tms
  end

  # Replaces the trainers of the last world (version TRAINER_VERSION) with
  # these sections, then compiles the trainers (MapEvents checks them).
  def write_trainers(sections)
    lines = remove_trainer_lines(MapGenerator.read_pbs(TRAINERS_PBS))
    sections.each { |section| lines.push("#-------------------------------", *section.split("\n")) }
    MapGenerator.write_pbs(TRAINERS_PBS, lines)
    Compiler.compile_trainers(TRAINERS_PBS)
  end

  # The lines without the world's trainers (each section with the separator
  # line above it).
  def remove_trainer_lines(lines)
    kept = []
    skipping = false
    lines.each do |line|
      if line.start_with?("[")
        skipping = line.match?(/\A\[[^,\]]+,[^,\]]+,\s*#{TRAINER_VERSION}\s*\]/)
        kept.pop if skipping && kept.last&.start_with?("#-")
      elsif line.start_with?("#-")
        skipping = false
      end
      kept.push(line) if !skipping
    end
    return kept
  end

  def remove_trainers
    write_trainers([])
  end
end

module MapProceduralGenerator
  class << self
    alias_method :__world_events_generate_world, :generate_world
    alias_method :__world_events_generate_world_maps, :generate_world_maps
    alias_method :__world_events_remove_world_now, :remove_world_now
    alias_method :__world_events_delete_exports, :delete_exports

    # Keeps the last world, for its events once its maps are written.
    def generate_world(*args)
      @events_world = __world_events_generate_world(*args)
      return @events_world
    end

    def generate_world_maps(path, seed, quiet: false, prune: false, computed: nil)
      @events_world = computed[2] if computed
      export, start = __world_events_generate_world_maps(path, seed, quiet: quiet, prune: prune, computed: computed)
      WorldEvents.write_world(@events_world, seed, export)
      return export, start
    end

    # The world of an unsaved game, deleted: its trainers go too.
    def remove_world_now(state)
      __world_events_remove_world_now(state)
      WorldEvents.remove_trainers
    end

    def delete_exports(path, seed)
      __world_events_delete_exports(path, seed)
      WorldEvents::EXPORT_SUFFIXES.each { |suffix| delete_file(export_path(path, seed).sub(/\.txt\z/, "#{suffix}.txt")) }
    end
  end
end
