#===============================================================================
# WorldEvents - Written with the world
# When MapProceduralGenerator writes a world (debug menu or new game), the
# events drawn for it are placed by MapEvents on its maps, after the maps and
# their encounters. The plans go next to the world's export
# (MapProc/Export/<world>_<seed>_evenements.txt), to read them or run them
# again from the MapEvents folder.
#===============================================================================
module WorldEvents
  module_function

  def write_world(result, seed, export)
    plans = world_events(result, seed)[:plans]
    plans.each_value do |text|
      plan = MapEvents.parse(text, File.basename(export))
      _map_id, notes = MapEvents.generate(plan)
      notes.each { |note| Console.echoln_li(note) }
      MapProceduralGenerator.busy_update
    end
    File.write(export.sub(/\.txt\z/, "_evenements.txt"), plans.values.join("\n#-------------------------------\n"))
    Console.echoln_li(_INTL("Événements placés sur {1} cartes.", plans.length))
  end
end

module MapProceduralGenerator
  class << self
    alias_method :__world_events_generate_world, :generate_world
    alias_method :__world_events_generate_world_maps, :generate_world_maps

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
  end
end
