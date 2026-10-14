#===============================================================================
# MapGenerator - Builds map tile data from a plan
#===============================================================================
module MapGenerator
  module_function

  # Returns a Table(width, height, 3) of tile IDs with autotile patterns set.
  def build_data(plan)
    width = plan.rows[0].length
    height = plan.rows.length
    rng = Random.new(plan.seed || Random.new_seed)
    data = Table.new(width, height, 3)
    plan.rows.each_with_index do |row, y|
      row.each_char.with_index do |c, x|
        layers = plan.legend[plan.objects[c] ? plan.objects[c].ground : c]
        layers.each_with_index do |variants, z|
          data[x, y, z] = variants[rng.rand(variants.length)]
        end
      end
    end
    apply_autotile_patterns(data)
    # Objects go last so autotile neighbours only see the ground
    plan.rows.each_with_index do |row, y|
      row.each_char.with_index do |c, x|
        next if !(object = plan.objects[c])
        object.height.times do |dy|
          object.width.times do |dx|
            data[x + dx, y + dy, object.layer] = 384 + object.tile + (dy * 8) + dx
          end
        end
      end
    end
    return data
  end

  # Autotile IDs are 48 * slot + pattern. Cells were filled with the base ID;
  # pick each pattern from the 8 neighbours that use the same autotile slot.
  # Map edges count as the same autotile, like Essentials' tableNeighbors.
  def apply_autotile_patterns(data)
    table = TileDrawingHelper::NEIGHBORS_TO_AUTOTILE_INDEX
    offsets = [[0, -1], [1, -1], [1, 0], [1, 1], [0, 1], [-1, 1], [-1, 0], [-1, -1]]
    3.times do |z|
      bases = Array.new(data.ysize) { |y| Array.new(data.xsize) { |x| data[x, y, z] } }
      data.ysize.times do |y|
        data.xsize.times do |x|
          base = bases[y][x]
          next if base < 48 || base >= 384
          mask = 0
          offsets.each_with_index do |(dx, dy), bit|
            nx = (x + dx).clamp(0, data.xsize - 1)
            ny = (y + dy).clamp(0, data.ysize - 1)
            mask |= (1 << bit) if bases[ny][nx] == base
          end
          data[x, y, z] = base + table[mask]
        end
      end
    end
  end

  # Checks that every tile exists in the chosen tileset.
  def check_tiles(plan, tileset)
    if !tileset || tileset.tileset_name.to_s.empty?
      raise Error, "#{plan.file} : tileset #{plan.tileset_id} introuvable ou sans image"
    end
    plan.legend.each do |symbol, layers|
      layers.flatten.each do |id|
        if id >= 48 && id < 384
          slot = id / 48
          name = tileset.autotile_names[slot - 1]
          next if name && !name.empty?
          raise Error, "#{plan.file} : « #{symbol} » utilise A#{slot}, mais cet emplacement est vide dans le tileset « #{tileset.name} »"
        elsif id >= 384 && id >= tileset.passages.xsize
          raise Error, "#{plan.file} : « #{symbol} » utilise T#{id - 384}, absent du tileset « #{tileset.name} » (#{tileset.passages.xsize - 384} tuiles)"
        end
      end
    end
    plan.objects.each do |symbol, object|
      last = 384 + object.tile + ((object.height - 1) * 8) + object.width - 1
      next if last < tileset.passages.xsize
      raise Error, "#{plan.file} : l'objet « #{symbol} » sort du tileset « #{tileset.name} »"
    end
  end
end
