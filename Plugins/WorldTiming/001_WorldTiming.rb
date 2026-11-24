#===============================================================================
# WorldTiming - How long each step of a world's generation takes (#344)
# Wraps the steps of MapProceduralGenerator.generate_world_maps (and of the
# world drawn during the intro, compute_world) with a timer. Each step counts
# its own time only (time spent in a timed step it calls goes to that step),
# so the lines add up to the total. At the end of generate_world_maps, the
# report goes to the debug console and is appended to
# MapProc/Export/chronos.txt, to compare before / after a change.
# Measures only: the world drawn is the same (tools/ci/world_fingerprint.rb).
#===============================================================================
module WorldTiming
  module_function

  LOG_FILE = File.join(MapProceduralGenerator::FOLDER, MapProceduralGenerator::EXPORT_FOLDER, "chronos.txt")

  # [module, method, step], in the order of the report. A step listed twice
  # adds both methods' times.
  PLANS = "Plans des lieux (generate_world)".freeze
  STEPS = [
    [MapProceduralGenerator, :compute_world,        PLANS],
    [MapProceduralGenerator, :generate_world,       PLANS],
    [MapGenerator,           :parse,                "Palettes lues (MapGenerator.parse)"],
    [MapGenerator,           :generate,             "Écriture des cartes (MapGenerator.generate)"],
    [MapProceduralGenerator, :write_interior,       "Intérieurs (write_interior)"],
    [MapGenerator,           :relink_warps,         "Téléporteurs (relink_warps)"],
    [MapProceduralGenerator, :paint_cave,           "Grottes (paint_cave)"],
    [MapProceduralGenerator, :write_nook_events,    "Recoins (write_nook_events)"],
    [MapProceduralGenerator, :write_extra_metadata, "Métadonnées (write_extra_metadata)"],
    [MapProceduralGenerator, :remove_maps,          "Cartes d'avant supprimées (remove_maps)"],
    [MapProceduralGenerator, :save_atlas,           "Inventaire (save_atlas)"],
    [MapGenerator,           :generate_world,       "Monde MapGen : raccords, Town Map"],
    [MapGenerator,           :compile_world_pbs,    "PBS du monde compilés"],
    [ProceduralEncounters,   :write_world,          "Rencontres (ProceduralEncounters)"],
    [MapEvents,              :parse,                "Événements : plans relus (MapEvents.parse)"],
    [MapEvents,              :generate,             "Événements : écriture (MapEvents.generate)"],
    [WorldEvents,            :write_world,          "Événements : le reste (WorldEvents)"]
  ].freeze
  OTHER = "Autres (fichiers, nettoyage...)".freeze

  # Seconds per step of the generation under way.
  def times
    return (@times ||= Hash.new(0.0))
  end

  # Runs the block as the step; its time minus that of the timed steps it
  # calls goes to the step. The world drawn during the intro runs in another
  # thread: each thread has its own stack of steps.
  def measure(step)
    stack = (Thread.current[:world_timing] ||= [])
    stack.push(0.0)
    start = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    return yield
  ensure
    elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - start
    inner = stack.pop
    times[step] += elapsed - inner
    stack[-1] += elapsed if !stack.empty?
  end

  # Wraps each step's method (prepended, so it runs before the aliases of the
  # other plugins).
  def install
    STEPS.each do |mod, name, step|
      mod.singleton_class.prepend(Module.new do
        define_method(name) { |*args, **kwargs, &block| WorldTiming.measure(step) { super(*args, **kwargs, &block) } }
      end)
    end
  end

  # Report lines of a generation that took total seconds; drawn: seconds of
  # the world drawn during the intro (not in total), nil if drawn here.
  def report(seed, total, drawn)
    lines = [_INTL("Génération du monde, graine {1} : {2}", seed, seconds(total))]
    lines.push(_INTL("  dont dessiné pendant l'intro (hors total) : {1}", seconds(drawn))) if drawn
    counted = times.values.sum
    rows = STEPS.map(&:last).uniq.filter_map { |step| [step, times[step]] if times.key?(step) }
    rows.push([OTHER, total - counted])
    rows.each { |step, time| lines.push(format("  %-48s %8s %5.1f %%", step, seconds(time), total > 0 ? time * 100 / total : 0)) }
    return lines
  end

  def seconds(time)
    return format("%.2f s", time)
  end

  # Prints and logs the report; a log that can't be written is skipped.
  def finish(seed, total, drawn)
    lines = report(seed, total, drawn)
    lines.each { |line| Console.echoln_li(line) }
    begin
      File.open(LOG_FILE, "a") { |f| f.write("[#{Time.now.strftime('%Y-%m-%d %H:%M:%S')}] #{lines.join("\n")}\n\n") }
    rescue SystemCallError => e
      Console.echoln_li(_INTL("Chronos : {1} non écrit ({2})", LOG_FILE, e.message))
    end
  ensure
    @times = nil
  end
end

module MapProceduralGenerator
  class << self
    alias_method :__world_timing_generate_world_maps, :generate_world_maps

    # The whole generation: its report at the end. A world drawn during the
    # intro (computed) was timed in its thread, before this call.
    def generate_world_maps(path, seed, quiet: false, prune: false, computed: nil)
      drawn = computed ? WorldTiming.times.delete(WorldTiming::PLANS).to_f : nil
      start = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      result = __world_timing_generate_world_maps(path, seed, quiet: quiet, prune: prune, computed: computed)
      WorldTiming.finish(seed, Process.clock_gettime(Process::CLOCK_MONOTONIC) - start, drawn)
      return result
    rescue StandardError
      WorldTiming.times.clear   # a failed generation leaves no time behind
      raise
    end
  end
end

WorldTiming.install
