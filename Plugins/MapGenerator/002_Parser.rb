#===============================================================================
# MapGenerator - Plan file parser
# File format:
#   Name    = Route 1          (required)
#   Tileset = 1                (required, ID in the RMXP Tilesets database)
#   MapID   = 52               (optional: overwrite this map, events are kept)
#   Parent  = 3                (optional: parent map in the map tree, 0 = root)
#   Seed    = 42               (optional: makes random variants reproducible)
#   Ground  = .                (required with [Objects]: legend symbol drawn
#                               under objects)
#   [Legend]
#   . = T8                     (one char = up to 3 layer tokens)
#   ~ = A1                     (A1..A7 = autotile slot, T<n> = tileset tile n)
#   , = T8|T9|T10              (| = random variant)
#   [Objects]
#   H = T400 3x4               (block of 3x4 tiles from tileset tile 400;
#   F = T600 2x2 L3 @,          L1..L3 = layer, L2 by default; @<symbol> =
#                               ground under it, Ground by default)
#   t = T500 2x3 halo=4x4@1,1  (the drawing goes beyond the block: a 4x4
#                               drawing whose block starts at column 1, row
#                               1; its other tiles are drawn on layer 3 around
#                               the block, where that layer is empty;
#                               halo=4x4@1,1/0,3 : cells 0 and 3 of the
#                               drawing, counted row by row from 0, are empty
#                               and never drawn)
#   t = T5000 2x2 forest=T5048 (a tree of a forest: the 6x6 drawing of
#                               SirMalo's pair of trees at T5000, its copy
#                               with the passages of a halo at T5048; each
#                               cell is drawn by its place in the forest, the
#                               overlaps as the sheet draws them, see
#                               003_Builder.rb)
#   [Terrains]                 (edge-aware tiles: one symbol, borders picked
#   P = T274 N=T266 S=T282 W=T273 E=T275 NW=T265 NE=T267 SW=T281 SE=T283
#       iNW=T286 iNE=T284 iSW=T270 iSE=T268 with=D L1 @.
#                               from the neighbours. T<n> = inside tile (- for
#                               none: edges only); N..SE
#                               = outer edges/corners, iNW..iSE = inner corners
#                               (missing ones fall back to the inside tile);
#                               oN oNW oNE oiNW oiNE = rim drawn on the cell
#                               above a north edge, where it is empty (oiNW:
#                               the terrain rises on its right, oiNE on its
#                               left; missing ones fall back to oN);
#                               with=<symbols> = other terrains that join it;
#                               L1..L3 = layer in [Map], L1 by default; @<symbol>
#                               = ground under it when not on L1)
#   [Map]
#   ....~~~~                   (one char per tile, all rows the same width)
#   ..HHH...
#   [Layer2]                   (optional grids drawn over [Map], same size:
#   ....f...                    "." = nothing, a [Legend] symbol is drawn from
#   [Layer3]                    this layer up, an object goes on this layer)
#   ........
#   [Warps]                    (doors and stairs: a symbol, then the target map
#   1 = Maison 1 4,7 haut       by its Name or its ID, the x,y cell there
#   2 = 12 10,3                 (from 0) and the facing: haut, bas, gauche,
#   3 = Centre 7,8 haut porte=Door_PC   droite, or kept when omitted; porte=:
#                               an animated door, its charset)
#   [Events]                   (optional grid, same size as [Map]: "." =
#   ..1.....                    nothing, a [Warps] symbol = a transfer event)
# In [Map], an object's symbol covers its whole footprint; a wider or taller
# area holds several copies, split from the top-left (HHHHHH = two houses).
# A plan with a World key is a world plan instead, see 006_World.rb.
#===============================================================================
module MapGenerator
  class Error < StandardError; end

  Plan = Struct.new(:file, :name, :tileset_id, :map_id, :parent_id, :seed,
                    :ground, :legend, :objects, :rows, :anchors, :overlays, :terrains, :warps, :events)
  # graphic: the charset of an animated door (« porte=Door_PC »), nil = none
  Warp = Struct.new(:target, :x, :y, :direction, :graphic)
  WARP_DIRECTIONS = { "bas" => 2, "gauche" => 4, "droite" => 6, "haut" => 8 }
  Terrain = Struct.new(:center, :roles, :with, :layer, :ground)
  TERRAIN_ROLES = %w[N S E W NW NE SW SE iNW iNE iSW iSE]
  # Drawn on the cell above a north edge (outside the terrain): the rim of a
  # plateau whose sheet draws it there (SirMalo's cliffs), see 003_Builder.rb
  OUTER_ROLES = %w[oN oNW oNE oiNW oiNE]
  # A forest drawing is 6x6 tiles; a tree of a forest covers 2x2 cells
  FOREST_SIZE = 6
  # Multi-tile block: first tileset tile, size in tiles, layer index (0-2);
  # halo: [width, height, x, y, empty cells] of a larger drawing around it
  # (or nil); forest: first tile of the halo copy of a forest drawing (or nil)
  MapObject = Struct.new(:tile, :width, :height, :layer, :ground, :halo, :forest) do
    # First tile of the whole drawing, and its size
    def drawing
      return [tile, FOREST_SIZE, FOREST_SIZE] if forest
      return [tile, width, height] if !halo
      return [tile - (halo[3] * 8) - halo[2], halo[0], halo[1]]
    end
  end

  module_function

  def parse_file(path)
    text = File.read(path, encoding: "UTF-8").sub(/\A﻿/, "")
    return parse(text, File.basename(path))
  end

  def parse(text, file = "plan")
    plan = Plan.new(file, nil, nil, nil, nil, nil, nil, {}, {}, [], [], {}, {}, {}, [])
    section = :header
    text.each_line.with_index(1) do |raw, lineno|
      line = raw.chomp
      fail_at = proc { |msg| raise Error, "#{file}, ligne #{lineno} : #{msg}" }
      if line.strip =~ /\A\[(\w+)\]\z/
        section = $1.downcase.to_sym
        fail_at.call("section inconnue [#{$1}]") unless [:legend, :objects, :terrains, :warps, :map, :layer2, :layer3, :events].include?(section)
        next
      end
      case section
      when :map
        next if line.strip.empty?
        plan.rows.push(line.rstrip)
      when :events
        next if line.strip.empty?
        plan.events.push(line.rstrip)
      when :warps
        content = line.sub(/#.*\z/, "").strip
        next if content.empty?
        unless content =~ /\A(\S)\s*=\s*(.+?)\s+(\d+),(\d+)(?:\s+(haut|bas|gauche|droite|\S+?))?(?:\s+porte=(\S+))?\z/
          fail_at.call("attendu « symbole = carte x,y [haut|bas|gauche|droite] [porte=charset] »")
        end
        symbol, target, x, y, facing, graphic = $1, $2, $3.to_i, $4.to_i, $5, $6
        if facing && !WARP_DIRECTIONS[facing]
          fail_at.call("direction « #{facing} » inconnue (haut, bas, gauche, droite)")
        end
        target = target.to_i if target =~ /\A\d+\z/
        plan.warps[symbol] = Warp.new(target, x, y, WARP_DIRECTIONS[facing] || 0, graphic)
      when :layer2, :layer3
        next if line.strip.empty?
        (plan.overlays[section == :layer2 ? 1 : 2] ||= []).push(line.rstrip)
      when :legend
        content = line.sub(/#.*\z/, "").strip
        next if content.empty?
        fail_at.call("attendu « symbole = calques »") unless content =~ /\A(\S)\s*=\s*(.+)\z/
        symbol, tokens = $1, $2.split
        fail_at.call("3 calques maximum pour « #{symbol} »") if tokens.length > 3
        plan.legend[symbol] = tokens.map { |t| parse_layer(t, fail_at) }
      when :objects
        content = line.sub(/#.*\z/, "").strip
        next if content.empty?
        halo = %r{(?:\s+halo=(\d+)x(\d+)@(\d+),(\d+)(?:/([\d,]+))?)?}
        unless content =~ /\A(\S)\s*=\s*T(\d+)\s+(\d+)x(\d+)#{halo}(?:\s+forest=T(\d+))?(?:\s+L([1-3]))?(?:\s+@(\S))?\z/
          fail_at.call("attendu « symbole = T<n> <L>x<H> [halo=<L>x<H>@<x>,<y>[/cases vides] | forest=T<n>] [L1-L3] [@symbole] »")
        end
        symbol = $1
        halo = $5 && ([$5, $6, $7, $8].map(&:to_i) << ($9 || "").split(",").map(&:to_i))
        object = MapObject.new($2.to_i, $3.to_i, $4.to_i, ($11 || 2).to_i - 1, $12, halo, $10&.to_i)
        fail_at.call("taille nulle pour « #{symbol} »") if object.width == 0 || object.height == 0
        if object.forest && (halo || object.width != 2 || object.height != 2)
          fail_at.call("un arbre de forêt « #{symbol} » fait 2x2, sans halo")
        end
        if object.forest && object.forest % 8 + FOREST_SIZE > 8
          fail_at.call("« #{symbol} » : forest=T#{object.forest} dépasse le bord droit du tileset (8 tuiles de large)")
        end
        if (h = object.halo) && (h[2] + object.width > h[0] || h[3] + object.height > h[1] || object.tile < (h[3] * 8) + h[2])
          fail_at.call("le halo de « #{symbol} » doit contenir son bloc")
        end
        first, width, _height = object.drawing
        if first % 8 + width > 8
          fail_at.call("« #{symbol} » dépasse le bord droit du tileset (8 tuiles de large)")
        end
        plan.objects[symbol] = object
      when :terrains
        content = line.sub(/#.*\z/, "").strip
        next if content.empty?
        fail_at.call("attendu « symbole = T<n> N=T<n> ... »") unless content =~ /\A(\S)\s*=\s*(?:T(\d+)|#{EMPTY_TOKEN})(.*)\z/
        symbol = $1
        # « - » inside: only the edges are drawn (nothing over what lies below)
        terrain = Terrain.new($2 ? 384 + $2.to_i : 0, {}, symbol, 0, nil)
        $3.split.each do |option|
          case option
          when /\A(\w+)=T(\d+)\z/
            roles = TERRAIN_ROLES + OUTER_ROLES
            fail_at.call("bord « #{$1} » inconnu (#{roles.join(', ')})") unless roles.include?($1)
            terrain.roles[$1] = 384 + $2.to_i
          when /\Awith=(\S+)\z/ then terrain.with += $1
          when /\AL([1-3])\z/    then terrain.layer = $1.to_i - 1
          when /\A@(\S)\z/      then terrain.ground = $1
          else fail_at.call("option « #{option} » invalide pour « #{symbol} »")
          end
        end
        plan.terrains[symbol] = terrain
      else
        content = line.sub(/#.*\z/, "").strip
        next if content.empty?
        fail_at.call("attendu « Clé = valeur »") unless content =~ /\A(\w+)\s*=\s*(.+)\z/
        key, value = $1.downcase, $2.strip
        case key
        when "name"    then plan.name = value
        when "tileset" then plan.tileset_id = integer(value, fail_at)
        when "mapid"   then plan.map_id = integer(value, fail_at)
        when "parent"  then plan.parent_id = integer(value, fail_at)
        when "seed"    then plan.seed = integer(value, fail_at)
        when "ground"  then plan.ground = value
        else fail_at.call("clé inconnue « #{$1} »")
        end
      end
    end
    validate(plan)
    return plan
  end

  # Returns an array of tile IDs (random variants) for one layer.
  # Autotiles are stored as their base ID (48 * slot); patterns come later.
  def parse_layer(token, fail_at)
    return [0] if token == EMPTY_TOKEN
    token.split("|").map do |t|
      case t
      when /\AA([1-7])\z/ then 48 * $1.to_i
      when /\AT(\d+)\z/   then 384 + $1.to_i
      else fail_at.call("calque « #{t} » invalide (A1 à A7, T<n> ou #{EMPTY_TOKEN})")
      end
    end
  end

  def integer(value, fail_at)
    fail_at.call("nombre attendu, trouvé « #{value} »") unless value =~ /\A\d+\z/
    return value.to_i
  end

  def validate(plan)
    raise Error, "#{plan.file} : « Name » manquant" if !plan.name
    raise Error, "#{plan.file} : « Tileset » manquant" if !plan.tileset_id
    raise Error, "#{plan.file} : section [Map] vide" if plan.rows.empty?
    (plan.objects.keys + plan.terrains.keys).tally.each do |symbol, count|
      next if count == 1 && !plan.legend[symbol]
      raise Error, "#{plan.file} : « #{symbol} » est défini dans plusieurs sections ([Legend], [Objects], [Terrains])"
    end
    plan.objects.each_value { |object| object.ground ||= plan.ground }
    plan.terrains.each_value { |terrain| terrain.ground ||= plan.ground }
    width = plan.rows[0].length
    plan.rows.each_with_index do |row, y|
      next if row.length == width
      raise Error, "#{plan.file} : la ligne #{y + 1} de [Map] fait #{row.length} cases au lieu de #{width}"
    end
    scan_grid(plan, plan.rows, "[Map]", nil)
    plan.overlays.each do |z, rows|
      name = "[Layer#{z + 1}]"
      if rows.length != plan.rows.length || rows.any? { |row| row.length != width }
        raise Error, "#{plan.file} : #{name} doit faire la même taille que [Map] (#{width}x#{plan.rows.length})"
      end
      scan_grid(plan, rows, name, z)
    end
    return if plan.events.empty?
    if plan.events.length != plan.rows.length || plan.events.any? { |row| row.length != width }
      raise Error, "#{plan.file} : [Events] doit faire la même taille que [Map] (#{width}x#{plan.rows.length})"
    end
    plan.events.each_with_index do |row, y|
      row.each_char.with_index do |c, x|
        next if c == OVERLAY_EMPTY || plan.warps[c]
        raise Error, "#{plan.file} : symbole « #{c} » (colonne #{x + 1}, ligne #{y + 1} de [Events]) absent de [Warps]"
      end
    end
  end

  # Checks every symbol of one grid and records the objects it places.
  # z = layer forced by an overlay grid (nil for [Map]).
  def scan_grid(plan, rows, name, z)
    claimed = Array.new(rows.length) { Array.new(rows[0].length, false) }
    rows.each_with_index do |row, y|
      row.each_char.with_index do |c, x|
        where = "(colonne #{x + 1}, ligne #{y + 1} de #{name})"
        next if z && c == OVERLAY_EMPTY
        if (object = plan.objects[c])
          next if claimed[y][x]
          if !z && !plan.legend[object.ground]
            raise Error, "#{plan.file} : l'objet « #{c} » n'a pas de sol valide (« Ground » ou @symbole de [Legend])"
          end
          claim_object(plan, rows, claimed, c, object, x, y, where, z)
          next
        end
        if (terrain = plan.terrains[c])
          next if z || terrain.layer == 0 || plan.legend[terrain.ground]
          raise Error, "#{plan.file} : le terrain « #{c} » n'a pas de sol valide (« Ground » ou @symbole de [Legend])"
        end
        if (layers = plan.legend[c])
          next if !z || z + layers.length <= 3
          raise Error, "#{plan.file} : « #{c} » #{where} a #{layers.length} calques, trop pour partir du calque #{z + 1}"
        end
        raise Error, "#{plan.file} : symbole « #{c} » #{where} absent de [Legend], [Objects] et [Terrains]"
      end
    end
  end

  # The first unclaimed cell of an object symbol (reading order) is the
  # top-left corner of one copy; its whole footprint must use that symbol.
  def claim_object(plan, rows, claimed, symbol, object, x, y, where, z)
    object.height.times do |dy|
      object.width.times do |dx|
        cx, cy = x + dx, y + dy
        next if cy < rows.length && rows[cy][cx] == symbol && !claimed[cy][cx]
        raise Error, "#{plan.file} : l'objet « #{symbol} » commencé #{where} doit couvrir " \
                     "#{object.width}x#{object.height} cases ; la case colonne #{cx + 1}, ligne #{cy + 1} ne convient pas"
      end
    end
    object.height.times { |dy| object.width.times { |dx| claimed[y + dy][x + dx] = true } }
    plan.anchors.push([x, y, symbol, z || object.layer])
  end
end
