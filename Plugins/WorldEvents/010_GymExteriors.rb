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
  # lieutenant's type, on the town's map.
  def paint_gyms(leaders)
    infos = load_data("Data/MapInfos.rxdata")
    leaders.each do |leader|
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
end
