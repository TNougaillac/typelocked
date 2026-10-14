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
#   [Map]
#   ....~~~~                   (one char per tile, all rows the same width)
#   ..HHH...
#   [Layer2]                   (optional grids drawn over [Map], same size:
#   ....f...                    "." = nothing, a [Legend] symbol is drawn from
#   [Layer3]                    this layer up, an object goes on this layer)
#   ........                   (an object's symbol covers its whole footprint;
#   ..HHH...                    a wider or taller area holds several copies,
#   ..HHH...                    split from the top-left: HHHHHH = two houses)
#   ..HHH...
#===============================================================================
module MapGenerator
  class Error < StandardError; end

  Plan = Struct.new(:file, :name, :tileset_id, :map_id, :parent_id, :seed,
                    :ground, :legend, :objects, :rows, :anchors, :overlays)
  # Multi-tile block: first tileset tile, size in tiles, layer index (0-2)
  MapObject = Struct.new(:tile, :width, :height, :layer, :ground)

  module_function

  def parse_file(path)
    text = File.read(path, encoding: "UTF-8").sub(/\A﻿/, "")
    return parse(text, File.basename(path))
  end

  def parse(text, file = "plan")
    plan = Plan.new(file, nil, nil, nil, nil, nil, nil, {}, {}, [], [], {})
    section = :header
    text.each_line.with_index(1) do |raw, lineno|
      line = raw.chomp
      fail_at = proc { |msg| raise Error, "#{file}, ligne #{lineno} : #{msg}" }
      if line.strip =~ /\A\[(\w+)\]\z/
        section = $1.downcase.to_sym
        fail_at.call("section inconnue [#{$1}]") unless [:legend, :objects, :map, :layer2, :layer3].include?(section)
        next
      end
      case section
      when :map
        next if line.strip.empty?
        plan.rows.push(line.rstrip)
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
        unless content =~ /\A(\S)\s*=\s*T(\d+)\s+(\d+)x(\d+)(?:\s+L([1-3]))?(?:\s+@(\S))?\z/
          fail_at.call("attendu « symbole = T<n> <L>x<H> [L1-L3] [@symbole] »")
        end
        object = MapObject.new($2.to_i, $3.to_i, $4.to_i, ($5 || 2).to_i - 1, $6)
        fail_at.call("taille nulle pour « #{$1} »") if object.width == 0 || object.height == 0
        if object.tile % 8 + object.width > 8
          fail_at.call("« #{$1} » dépasse le bord droit du tileset (8 tuiles de large)")
        end
        plan.objects[$1] = object
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
    plan.objects.each_key do |symbol|
      next if !plan.legend[symbol]
      raise Error, "#{plan.file} : « #{symbol} » est à la fois dans [Legend] et [Objects]"
    end
    plan.objects.each_value { |object| object.ground ||= plan.ground }
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
        if (layers = plan.legend[c])
          next if !z || z + layers.length <= 3
          raise Error, "#{plan.file} : « #{c} » #{where} a #{layers.length} calques, trop pour partir du calque #{z + 1}"
        end
        raise Error, "#{plan.file} : symbole « #{c} » #{where} absent de [Legend] et [Objects]"
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
