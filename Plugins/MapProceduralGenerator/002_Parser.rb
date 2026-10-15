#===============================================================================
# MapProceduralGenerator - Place and brick file parsers
# Place file (MapProc/*.txt):
#   Lieu    = ville            (required: kind of place, only "ville" for now)
#   Nom     = Ville générée    (required: map name, the seed is added to it)
#   Tileset = 1                (required, as in MapGen)
#   Taille  = 40x32            (required: map size in tiles)
#   Sol     = .                (required: [Legend] symbol of the ground)
#   Rue     = P                (required: symbol of the streets, a [Terrains]
#                               symbol gets its edges drawn)
#   Bordure = t                (optional: [Objects] symbol planted along the
#                               edges of the map, exits excepted)
#   Sorties = nord sud         (exits: nord, sud, est, ouest; later given by
#                               the region)
#   Rues    = 1..2             (optional: extra dead-end streets, 1 by default)
#   MapID   = 52               (optional: overwrite this map instead of
#                               creating a new one each time)
#   [Briques]
#   centre  = 1                (brick type = how many: n or min..max)
#   maison  = 3..6
#   [Legend] [Terrains] [Objects]
#   ...                        (MapGen palette, shared by every brick)
# Brick file (MapProc/Briques/*.txt):
#   Brique = Centre Pokémon    (required: name, for error messages)
#   Type   = centre            (required: the type named in [Briques])
#   Porte  = 2,4               (optional: door cell, column,row from 0, on the
#                               bottom row; a street is drawn to the cell below)
#   Poids  = 2                 (optional: how often it is picked among the
#                               bricks of its type, 1 by default)
#   Contre = rue               (optional: the brick touches a street, for
#                               lamps, benches, signs)
#   [Map]
#   CCCCC                      (palette symbols; " " = not part of the brick)
#===============================================================================
module MapProceduralGenerator
  class Error < StandardError; end

  Place = Struct.new(:file, :kind, :name, :tileset_id, :width, :height, :ground, :street,
                     :border, :exits, :spurs, :map_id, :counts, :palette)
  Brick = Struct.new(:file, :name, :kind, :door, :weight, :by_street, :rows)
  PLACE_KINDS = %w[ville]
  SIDES = %w[nord sud est ouest]

  module_function

  def read(path)
    return File.read(path, encoding: "UTF-8").sub(/\A﻿/, "")
  end

  def place_files
    return Dir.glob(File.join(FOLDER, "*.txt")).sort
  end

  def brick_files
    return Dir.glob(File.join(FOLDER, BRICK_FOLDER, "*.txt")).sort
  end

  def parse_place(text, file = "lieu")
    place = Place.new(file, nil, nil, nil, nil, nil, nil, nil, nil, [], 1..1, nil, {}, +"")
    section = :header
    text.each_line.with_index(1) do |raw, lineno|
      fail_at = proc { |msg| raise Error, "#{file}, ligne #{lineno} : #{msg}" }
      if raw.strip =~ /\A\[(\w+)\]\z/
        section = ($1.downcase == "briques") ? :bricks : :palette
      end
      if section == :palette
        place.palette << raw.chomp << "\n"
        next
      end
      content = raw.chomp.sub(/#.*\z/, "").strip
      next if content.empty? || content =~ /\A\[\w+\]\z/
      fail_at.call("attendu « Clé = valeur »") unless content =~ /\A(\w+)\s*=\s*(.+)\z/
      key, value = $1, $2.strip
      if section == :bricks
        place.counts[key] = range(value, fail_at)
        next
      end
      case key.downcase
      when "lieu"
        fail_at.call("lieu « #{value} » inconnu (#{PLACE_KINDS.join(', ')})") unless PLACE_KINDS.include?(value)
        place.kind = value
      when "nom"     then place.name = value
      when "tileset" then place.tileset_id = integer(value, fail_at)
      when "taille"
        fail_at.call("attendu « largeur x hauteur », ex. 40x32") unless value =~ /\A(\d+)x(\d+)\z/
        place.width, place.height = $1.to_i, $2.to_i
      when "sol"     then place.ground = symbol(value, fail_at)
      when "rue"     then place.street = symbol(value, fail_at)
      when "bordure" then place.border = symbol(value, fail_at)
      when "sorties"
        place.exits = value.split
        bad = place.exits - SIDES
        fail_at.call("sortie « #{bad[0]} » inconnue (#{SIDES.join(', ')})") unless bad.empty?
      when "rues"    then place.spurs = range(value, fail_at)
      when "mapid"   then place.map_id = integer(value, fail_at)
      else fail_at.call("clé inconnue « #{key} »")
      end
    end
    { "Lieu" => place.kind, "Nom" => place.name, "Tileset" => place.tileset_id,
      "Taille" => place.width, "Sol" => place.ground, "Rue" => place.street }.each do |key, value|
      raise Error, "#{file} : « #{key} » manquant" if !value
    end
    raise Error, "#{file} : section [Briques] vide" if place.counts.empty?
    return place
  end

  def parse_brick(text, file = "brique")
    brick = Brick.new(file, nil, nil, nil, 1, false, [])
    section = :header
    text.each_line.with_index(1) do |raw, lineno|
      fail_at = proc { |msg| raise Error, "#{file}, ligne #{lineno} : #{msg}" }
      if raw.strip =~ /\A\[(\w+)\]\z/
        fail_at.call("section inconnue [#{$1}] (seulement [Map])") unless $1.downcase == "map"
        section = :map
        next
      end
      if section == :map
        brick.rows.push(raw.chomp.rstrip) if !raw.strip.empty?
        next
      end
      content = raw.chomp.sub(/#.*\z/, "").strip
      next if content.empty?
      fail_at.call("attendu « Clé = valeur »") unless content =~ /\A(\w+)\s*=\s*(.+)\z/
      key, value = $1, $2.strip
      case key.downcase
      when "brique" then brick.name = value
      when "type"   then brick.kind = value
      when "porte"
        fail_at.call("attendu « colonne,ligne », ex. 2,4") unless value =~ /\A(\d+),(\d+)\z/
        brick.door = [$1.to_i, $2.to_i]
      when "poids"  then brick.weight = integer(value, fail_at)
      when "contre"
        fail_at.call("seule valeur possible : « Contre = rue »") unless value == "rue"
        brick.by_street = true
      else fail_at.call("clé inconnue « #{key} »")
      end
    end
    raise Error, "#{file} : « Brique » manquant" if !brick.name
    raise Error, "#{file} : « Type » manquant" if !brick.kind
    raise Error, "#{file} : section [Map] vide" if brick.rows.empty?
    width = brick.rows.map(&:length).max
    brick.rows.map! { |row| row.ljust(width) }
    if brick.door
      x, y = brick.door
      if y != brick.rows.length - 1 || x >= width || brick.rows[y][x] == " "
        raise Error, "#{file} : la porte #{x},#{y} doit être une case de la dernière ligne de [Map]"
      end
    end
    return brick
  end

  # Checks the bricks against the palette of a place, through MapGen's own
  # parser: returns the palette as a parsed MapGen plan.
  def check_palette(place, bricks)
    palette = MapGenerator.parse(plan_text(place, 0, [place.ground]), place.file)
    known = palette.legend.keys + palette.objects.keys + palette.terrains.keys
    raise Error, "#{place.file} : « Rue = #{place.street} » absent de la palette" if !known.include?(place.street)
    if place.border && !palette.objects[place.border]
      raise Error, "#{place.file} : « Bordure = #{place.border} » doit être un symbole de [Objects]"
    end
    place.counts.each_key do |kind|
      next if bricks.any? { |b| b.kind == kind }
      raise Error, "#{place.file} : aucune brique de type « #{kind} » dans #{FOLDER}/#{BRICK_FOLDER}/"
    end
    bricks.each do |brick|
      next if !place.counts[brick.kind]
      brick.rows.each_with_index do |row, y|
        row.each_char.with_index do |c, x|
          next if c == " " || known.include?(c)
          raise Error, "#{brick.file} : symbole « #{c} » (colonne #{x + 1}, ligne #{y + 1}) absent de la palette de #{place.file}"
        end
      end
    end
    return palette
  end

  # MapGen plan text of a place: header, palette, then the assembled rows.
  def plan_text(place, seed, rows)
    text = +"Name    = #{place.name} #{seed}\n"
    text << "Tileset = #{place.tileset_id}\n"
    text << "MapID   = #{place.map_id}\n" if place.map_id
    text << "Seed    = #{seed}\n"
    text << "Ground  = #{place.ground}\n"
    text << place.palette
    text << "\n[Map]\n"
    rows.each { |row| text << row << "\n" }
    return text
  end

  def range(value, fail_at)
    return (value.to_i..value.to_i) if value =~ /\A\d+\z/
    fail_at.call("attendu un nombre ou « min..max », trouvé « #{value} »") unless value =~ /\A(\d+)\.\.(\d+)\z/
    fail_at.call("« #{value} » : le minimum dépasse le maximum") if $1.to_i > $2.to_i
    return ($1.to_i..$2.to_i)
  end

  def integer(value, fail_at)
    fail_at.call("nombre attendu, trouvé « #{value} »") unless value =~ /\A\d+\z/
    return value.to_i
  end

  def symbol(value, fail_at)
    fail_at.call("un seul caractère attendu, trouvé « #{value} »") unless value.length == 1
    return value
  end
end
