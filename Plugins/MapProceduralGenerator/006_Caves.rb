#===============================================================================
# MapProceduralGenerator - Caves keep their layout
# Essentials draws a random dungeon map (map metadata Dungeon = true) each time
# the map is set up, from $PokemonGlobal.dungeon_rng_seed if set. The caves of
# a generated world get their own seed here, so that a cave is the same on
# every visit for a given world seed. A cave with an excess (« grotte
# immense », « dédale ») is drawn from its own dungeon parameters.
#===============================================================================
module MapProceduralGenerator
  module_function

  # Map ID => seed, or [seed, area of PBS/dungeon_parameters.txt], written
  # when a world is generated.
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
    seed, area = MapProceduralGenerator.cave_seeds[map_id]
    return __mapproc_setup(map_id) if !seed || !$PokemonGlobal
    $PokemonGlobal.dungeon_rng_seed = seed
    # Only for this cave: other dungeons keep the area they were given
    old_area = $PokemonGlobal.instance_variable_get(:@dungeon_area)
    $PokemonGlobal.dungeon_area = area ? area.to_sym : nil
    begin
      __mapproc_setup(map_id)
    ensure
      $PokemonGlobal.dungeon_area = old_area
    end
  end
end
