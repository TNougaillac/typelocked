#===============================================================================
# MapGenerator - Plan file parser
# File format:
#   Name    = Route 1          (required)
#   Tileset = 1                (required, ID in the RMXP Tilesets database)
#   MapID   = 52               (optional: overwrite this map, events are kept)
#   Parent  = 3                (optional: parent map in the map tree, 0 = root)
#   Seed    = 42               (optional: makes random variants reproducible)
#   Ground  = .                (required with [Objects]: legend symbol drawn
#                               under an object's anchor cell)
#   [Legend]
#   . = T8                     (one char = up to 3 layer tokens)
#   ~ = A1                     (A1..A7 = autotile slot, T<n> = tileset tile n)
#   , = T8|T9|T10              (| = random variant)
#   [Objects]
#   H = T400 3x4               (block of 3x4 tiles from tileset tile 400,
#   F = T600 2x2 L3 @,          anchored at its top-left cell; L1..L3 = layer,
#                               L2 by default; @<symbol> = ground under the
#                               anchor cell, Ground by default)
#   [Map]
#   ....~~~~                   (one char per tile, all rows the same width)
#===============================================================================
module MapGenerator
  class Error < StandardError; end

  Plan = Struct.new(:file, :name, :tileset_id, :map_id, :parent_id, :seed,
                    :ground, :legend, :objects, :rows)
  # Multi-tile block: first tileset tile, size in tiles, layer index (0-2)
  MapObject = Struct.new(:tile, :width, :height, :layer, :ground)

  module_function

  def parse_file(path)
    text = File.read(path, encoding: "UTF-8").sub(/\A﻿/, "")
    return parse(text, File.basename(path))
  end

  def parse(text, file = "plan")
    plan = Plan.new(file, nil, nil, nil, nil, nil, nil, {}, {}, [])
    section = :header
    text.each_line.with_index(1) do |raw, lineno|
      line = raw.chomp
      fail_at = proc { |msg| raise Error, "#{file}, ligne #{lineno} : #{msg}" }
      if line.strip =~ /\A\[(\w+)\]\z/
        section = $1.downcase.to_sym
        fail_at.call("section inconnue [#{$1}]") unless [:legend, :objects, :map].include?(section)
        next
      end
      case section
      when :map
        next if line.strip.empty?
        plan.rows.push(line.rstrip)
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
    plan.objects.each do |symbol, object|
      object.ground ||= plan.ground
      next if plan.legend[object.ground]
      raise Error, "#{plan.file} : l'objet « #{symbol} » n'a pas de sol valide (« Ground » ou @symbole de [Legend])"
    end
    width = plan.rows[0].length
    plan.rows.each_with_index do |row, y|
      if row.length != width
        raise Error, "#{plan.file} : la ligne #{y + 1} de [Map] fait #{row.length} cases au lieu de #{width}"
      end
      row.each_char.with_index do |c, x|
        if (object = plan.objects[c])
          next if x + object.width <= width && y + object.height <= plan.rows.length
          raise Error, "#{plan.file} : l'objet « #{c} » (colonne #{x + 1}, ligne #{y + 1} de [Map]) dépasse de la carte"
        end
        next if plan.legend[c]
        raise Error, "#{plan.file} : symbole « #{c} » (colonne #{x + 1}, ligne #{y + 1} de [Map]) absent de [Legend] et [Objects]"
      end
    end
  end
end
