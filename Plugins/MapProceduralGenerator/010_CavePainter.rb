#===============================================================================
# MapProceduralGenerator - Cave walls
# Once MapGen has written a cave floor, Essentials' dungeon painter draws its
# walls and decorations around the galleries made by 006_Caves.rb (instead of
# its own rooms and corridors), from the floor's own seed. The map is then
# saved as it is: no Dungeon = true, the cave never changes.
#===============================================================================
module MapProceduralGenerator
  class CaveDungeon < RandomDungeon::Dungeon
    # rows: true = floor, the map's size (margin included).
    def initialize(rows, tileset, parameters, seed)
      super(rows[0].length, rows.length, tileset, parameters)
      @floor_rows = rows
      @buffer_x, @buffer_y = CAVE_MARGIN
      @rng_seed = seed
    end

    # Drawn once, from the floor's seed: a wall that can't be drawn is an
    # error (Essentials would draw another layout, but this one is fixed).
    def generate
      Random.srand(@rng_seed)
      max_width = @usable_width - (@buffer_x * 2)
      max_height = @usable_height - (@buffer_y * 2)
      @need_redraw = false
      @map_data.clear
      generate_layout(max_width, max_height)
      generate_walls(max_width, max_height)
      raise Error, "grotte : murs impossibles à dessiner (graine #{@rng_seed})" if @need_redraw
      paint_decorations(max_width, max_height)
      paint_wall_top_tiles(max_width, max_height)
    ensure
      Random.srand
    end

    def generate_layout(_max_width, _max_height)
      @floor_rows.each_with_index do |row, y|
        row.each_with_index { |floor, x| @map_data[x, y, 0] = :room if floor }
      end
    end
  end

  module_function

  # Draws the walls of a written cave floor, and shows its exits and ladders
  # as ladders.
  def paint_cave(map_id, floor)
    path = sprintf("Data/Map%03d.rxdata", map_id)
    map = load_data(path)
    tileset = GameData::DungeonTileset.try_get(CAVE_TILESET)
    dungeon = CaveDungeon.new(floor.rows, tileset, GameData::DungeonParameters.try_get(CAVE_AREA), floor.seed)
    dungeon.generate
    map.width, map.height = dungeon.width, dungeon.height
    map.data.resize(map.width, map.height, 3)
    dungeon.generateMapInPlace(map)
    map.events.each_value do |event|
      next if event.name != MapGenerator::WARP_EVENT_NAME
      event.pages[0].graphic.tile_id = CAVE_EXIT_TILE
    end
    save_data(map, path)
  end
end
