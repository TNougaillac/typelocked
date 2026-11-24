#===============================================================================
# WorldEvents - Gym exteriors of the lieutenants' types
# A town draws its gym in Normal (MapProc/ville.txt, SirMalo's gyms: one
# drawing per type, in two styles). Once the lieutenants' types are drawn,
# each gym is painted in its lieutenant's type: every tile of the Normal
# drawing on the town's map becomes the same tile of that type's drawing.
#===============================================================================
module WorldEvents
  # Gyms of the tileset Outside 4G (tools/art/outside_4g.py prints them):
  # style => { type => first tile of its drawing (T<n>) }. Each drawing is
  # GYM_DRAWING_SIZE tiles; the town's is NORMAL's.
  GYM_EXTERIORS = {
    round:  { BUG: 6664, DARK: 6720, DRAGON: 6776, ELECTRIC: 6832, FAIRY: 6888, FIGHTING: 6944, FIRE: 7000,
              FLYING: 7056, GHOST: 7112, GRASS: 7168, GROUND: 7224, ICE: 7280, NORMAL: 7336, POISON: 7392,
              PSYCHIC: 7448, ROCK: 7504, STEEL: 7560, WATER: 7616 },
    square: { BUG: 7672, DARK: 7728, DRAGON: 7784, ELECTRIC: 7840, FAIRY: 7896, FIGHTING: 7952, FIRE: 8008,
              FLYING: 8064, GHOST: 8120, GRASS: 8176, GROUND: 8232, ICE: 8288, NORMAL: 8344, POISON: 8400,
              PSYCHIC: 8456, ROCK: 8512, STEEL: 8568, WATER: 8624 }
  }.freeze
  GYM_DRAWING_SIZE = [8, 7].freeze
  # A generated gym's interior (#121) wears its lieutenant's type: tileset
  # by type (tools/art/gym_interiors_4g.py), drawn on the same grid as the
  # Normal one (MapProceduralGenerator::GYM_TILESET).
  GYM_INTERIOR_TILESETS = %i[NORMAL FIRE WATER GRASS ELECTRIC ICE FIGHTING POISON GROUND FLYING PSYCHIC BUG ROCK
                             GHOST DRAGON DARK STEEL FAIRY].each_with_index.to_h { |type, i| [type, 37 + i] }.freeze
  # Generated gyms left in the dark (#121, tranche 3), like the dark caves:
  # DarkMap in their map metadata.
  GYM_DARK = %i[GHOST DARK].freeze

  module_function

  # The tile ID showing that type's gym in place of a Normal gym's tile, or
  # nil when the tile is not part of a Normal gym (or the type has none).
  def gym_tile(id, type)
    width, height = GYM_DRAWING_SIZE
    GYM_EXTERIORS.each_value do |types|
      offset = id - 384 - types[:NORMAL]
      next if offset < 0 || offset >= width + ((height - 1) * 8) || offset % 8 >= width
      first = types[type]
      return first ? 384 + first + offset : nil
    end
    return nil
  end

  # Paints the gym of each lieutenant's town (leaders: gym_events) in the
  # lieutenant's type, on the town's map, and its generated interior.
  def paint_gyms(leaders)
    infos = load_data("Data/MapInfos.rxdata")
    darken_gyms(infos, leaders)
    leaders.each do |leader|
      paint_gym_interior(infos, leader)
      map_id = infos.select { |_id, info| info.name == leader[:town] }.keys.min
      next if !map_id
      path = sprintf("Data/Map%03d.rxdata", map_id)
      map = load_data(path)
      data = map.data
      changed = false
      data.zsize.times do |z|
        data.ysize.times do |y|
          data.xsize.times do |x|
            id = gym_tile(data[x, y, z], leader[:type])
            next if !id
            data[x, y, z] = id
            changed = true
          end
        end
      end
      save_data(map, path) if changed
    end
  end

  # The interiors of the GYM_DARK lieutenants get DarkMap (their metadata is
  # written with the world's maps, before the types are drawn).
  def darken_gyms(infos, leaders)
    ids = leaders.select { |leader| GYM_DARK.include?(leader[:type]) }
                 .filter_map { |leader| infos.select { |_id, info| info.name == leader[:map] }.keys.min }
    return if ids.empty?
    file = MapGenerator::MAP_METADATA_PBS
    MapGenerator.write_pbs(file, dark_metadata(MapGenerator.read_pbs(file), ids))
    Compiler.compile_map_metadata(file)
  end

  # The lines of map_metadata.txt with « DarkMap = true » under the sections
  # of these map ids (none twice).
  def dark_metadata(lines, ids)
    out = []
    section = nil
    lines.each do |line|
      if line =~ /\A\[0*(\d+)\]/
        section = $1.to_i
      elsif line.strip == "DarkMap = true" && ids.include?(section)
        next
      end
      out.push(line)
      out.push("DarkMap = true") if line.start_with?("[") && ids.include?(section)
    end
    return out
  end

  # The tileset of the lieutenant's type on a generated gym's interior.
  def paint_gym_interior(infos, leader)
    tileset = GYM_INTERIOR_TILESETS[leader[:type]]
    map_id = infos.select { |_id, info| info.name == leader[:map] }.keys.min
    return if !tileset || !map_id
    path = sprintf("Data/Map%03d.rxdata", map_id)
    map = load_data(path)
    return if map.tileset_id != MapProceduralGenerator::GYM_TILESET || map.tileset_id == tileset
    map.tileset_id = tileset
    save_data(map, path)
  end
end
