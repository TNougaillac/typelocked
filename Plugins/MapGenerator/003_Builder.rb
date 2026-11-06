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
        ground = c
        ground = plan.objects[c].ground if plan.objects[c]
        ground = (plan.terrains[c].layer > 0 ? plan.terrains[c].ground : nil) if plan.terrains[c]
        next if !(layers = plan.legend[ground])
        layers.each_with_index do |variants, z|
          data[x, y, z] = variants[rng.rand(variants.length)]
        end
      end
    end
    plan.overlays.each do |z, rows|
      rows.each_with_index do |row, y|
        row.each_char.with_index do |c, x|
          next if c == OVERLAY_EMPTY || !(layers = plan.legend[c])
          layers.each_with_index do |variants, i|
            data[x, y, z + i] = variants[rng.rand(variants.length)]
          end
        end
      end
    end
    apply_terrains(plan, plan.rows, data, nil)
    plan.overlays.each { |z, rows| apply_terrains(plan, rows, data, z) }
    apply_autotile_patterns(data)
    # Objects go last so autotile neighbours only see the ground
    plan.anchors.each do |x, y, symbol, z|
      object = plan.objects[symbol]
      next if object.forest
      object.height.times do |dy|
        object.width.times do |dx|
          data[x + dx, y + dy, z] = 384 + object.tile + (dy * 8) + dx
        end
      end
    end
    # Halos last, on layer 3, only where it is empty: a drawing never covers
    # what a plan put there
    plan.anchors.each { |x, y, symbol, _z| draw_halo(plan.objects[symbol], x, y, data) }
    plan.objects.each { |symbol, object| draw_forest(plan, symbol, object, data) if object.forest }
    return data
  end

  # Rows of a forest drawing (SirMalo's 2x2 pair of trees): 0 tips, 1 upper
  # canopy, 2 lower canopy over the tips of the tree in front, 3 upper
  # canopy over the tree behind, 4 lower canopy, 5 trunks. Columns: 0 left
  # spill, 1 left half, 2 right half under the next tree, 3 left half over
  # the previous tree, 4 right half, 5 right spill. The spills only hold
  # leaves on rows 3 and 4: the other rows take theirs.
  FOREST_SPILL_ROWS = { 1 => 3, 2 => 4, 3 => 3, 4 => 4 }

  # Draws every tree of a forest symbol by its place among the others: a
  # tree with a tree below shows that tree's upper canopy in its lower row,
  # one at the edge its trunk; two trees side by side join when their rows
  # match. The canopy above the forest and the spills on its sides are a
  # halo, on layer 3 where it is empty, then on layer 2 under it (the front
  # drawing on top).
  def draw_forest(plan, symbol, object, data)
    trees = {}   # [x, y] => [drawing row, drawing column, layer]
    plan.anchors.each do |x, y, s, z|
      next if s != symbol
      2.times { |dy| 2.times { |dx| trees[[x + dx, y + dy]] = [dy, dx, z] } }
    end
    trees.each { |(x, y), tree| tree[0] += trees[[x, y + 2 - tree[0]]] ? 2 : 4 }
    trees.each do |(x, y), tree|
      side = trees[[x + (tree[1] == 0 ? -1 : 1), y]]
      joined = side && side[0] == tree[0]
      tree[1] = tree[1] == 0 ? (joined ? 3 : 1) : (joined ? 2 : 4)
    end
    halos = Hash.new { |hash, cell| hash[cell] = [] }   # [x, y] => [[row, column], ...]
    trees.each do |(x, y), (row, column, _z)|
      next if row.odd? || trees[[x, y - 1]]
      halos[[x, y - 1]].push([1, column])
      halos[[x, y - 2]].push([0, column]) if !trees[[x, y - 2]]
    end
    (trees.map { |cell, (row, column, _z)| [cell, [row, column]] } +
     halos.flat_map { |cell, list| list.map { |role| [cell, role] } }).each do |(x, y), (row, column)|
      next if !(spill = FOREST_SPILL_ROWS[row])
      halos[[x - 1, y]].push([spill, 0]) if column == 1
      halos[[x + 1, y]].push([spill, 5]) if column == 4
    end
    trees.each { |(x, y), (row, column, z)| data[x, y, z] = 384 + object.tile + (row * 8) + column }
    halos.each do |(x, y), list|
      next if x < 0 || y < 0 || x >= data.xsize || y >= data.ysize
      layers = (trees[[x, y]] ? [2] : [2, 1]).select { |z| data[x, y, z] == 0 }
      list.zip(layers) { |(row, column), z| data[x, y, z] = 384 + object.forest + (row * 8) + column if z }
    end
  end

  def draw_halo(object, x, y, data)
    return if !object.halo
    first, width, height = object.drawing
    ox, oy = object.halo[2], object.halo[3]
    height.times do |dy|
      width.times do |dx|
        next if dx >= ox && dx < ox + object.width && dy >= oy && dy < oy + object.height
        next if object.halo[4].include?((dy * width) + dx)
        cx, cy = x - ox + dx, y - oy + dy
        next if cx < 0 || cy < 0 || cx >= data.xsize || cy >= data.ysize || data[cx, cy, 2] != 0
        data[cx, cy, 2] = 384 + first + (dy * 8) + dx
      end
    end
  end

  # Picks each terrain cell's tile from which neighbours belong to the same
  # terrain (or to one it joins with). Map edges count as inside.
  def apply_terrains(plan, rows, data, z)
    return if plan.terrains.empty?
    rows.each_with_index do |row, y|
      row.each_char.with_index do |c, x|
        next if (z && c == OVERLAY_EMPTY) || !(terrain = plan.terrains[c])
        inside = lambda do |dx, dy|
          nx, ny = x + dx, y + dy
          next true if ny < 0 || ny >= rows.length || nx < 0 || nx >= row.length
          next terrain.with.include?(rows[ny][nx])
        end
        n, s, e, w = !inside.call(0, -1), !inside.call(0, 1), !inside.call(1, 0), !inside.call(-1, 0)
        role = if n && w then "NW"
               elsif n && e then "NE"
               elsif s && w then "SW"
               elsif s && e then "SE"
               elsif n then "N"
               elsif s then "S"
               elsif w then "W"
               elsif e then "E"
               elsif !inside.call(-1, -1) then "iNW"
               elsif !inside.call(1, -1) then "iNE"
               elsif !inside.call(-1, 1) then "iSW"
               elsif !inside.call(1, 1) then "iSE"
               end
        data[x, y, z || terrain.layer] = terrain.roles[role] || terrain.center
      end
    end
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
    plan.terrains.each do |symbol, terrain|
      ([terrain.center] + terrain.roles.values).each do |id|
        next if id < tileset.passages.xsize
        raise Error, "#{plan.file} : le terrain « #{symbol} » utilise T#{id - 384}, absent du tileset « #{tileset.name} »"
      end
    end
    plan.objects.each do |symbol, object|
      first, width, height = object.drawing
      last = 384 + first + ((height - 1) * 8) + width - 1
      last = [last, 384 + object.forest + ((FOREST_SIZE - 1) * 9)].max if object.forest
      next if last < tileset.passages.xsize
      raise Error, "#{plan.file} : l'objet « #{symbol} » sort du tileset « #{tileset.name} »"
    end
  end
end
