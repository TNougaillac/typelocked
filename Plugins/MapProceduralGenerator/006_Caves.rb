#===============================================================================
# MapProceduralGenerator - Caves keep their layout
# Essentials draws a random dungeon map (map metadata Dungeon = true) each time
# the map is set up, from $PokemonGlobal.dungeon_rng_seed if set. The caves of
# a generated world get their own seed here, so that a cave is the same on
# every visit for a given world seed.
#===============================================================================
module MapProceduralGenerator
  module_function

  # Map ID => seed, written by the debug menu when a world is generated.
  def cave_seeds
    return @cave_seeds if @cave_seeds
    @cave_seeds = File.exist?(CAVE_SEEDS_FILE) ? load_data(CAVE_SEEDS_FILE) : {}
    return @cave_seeds
  end

  # Adds or replaces the seeds of these caves.
  def save_cave_seeds(seeds)
    all = cave_seeds.merge(seeds)
    save_data(all, CAVE_SEEDS_FILE)
    @cave_seeds = all
  end
end

class Game_Map
  alias_method :__mapproc_setup, :setup

  def setup(map_id)
    seed = MapProceduralGenerator.cave_seeds[map_id]
    $PokemonGlobal.dungeon_rng_seed = seed if seed && $PokemonGlobal
    __mapproc_setup(map_id)
  end
end
