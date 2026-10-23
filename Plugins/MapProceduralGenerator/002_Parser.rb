#===============================================================================
# MapProceduralGenerator - Place and brick file parsers
# Place file (MapProc/*.txt):
#   Lieu    = ville            (required: ville or route)
#   Nom     = Ville générée    (required: map name; the debug menu adds the
#                               seed, a world gives its own names)
#   Tileset = 1                (required, as in MapGen)
#   Taille  = 40x32            (required: map size in tiles)
#   Sol     = .                (required: [Legend] symbol of the ground)
#   Rue     = P                (required: symbol of the streets, a [Terrains]
#                               symbol gets its edges drawn)
#   Bordure = t                (optional: [Objects] symbol planted along the
#                               edges of the map, exits excepted)
#   Sorties = nord sud         (exits: nord, sud, est, ouest; in a world, the
#                               world sets them and the size)
#   Rues    = 1..2             (optional: extra dead-end streets, 1 by default)
#   Eau     = ~                (optional: [Legend] symbol of water, for the
#                               « lac » bricks and the crossings of a world)
#   Profond = %                (optional: [Legend] symbol of deep water, where
#                               the player can dive, in a world)
#   Roche   = R                (optional: [Objects] symbol of the rock wall that
#                               blocks a route crossed through a cave)
#   Caillou = o                (optional: 1x1 [Legend] symbol filling the gaps
#                               of that wall)
#   Relief  = ^ & k K          (optional: [Terrains] symbols of the levels of a
#                               mountain route of a world, from the 1st up, 2
#                               at least; each joins the higher ones so that
#                               only the higher level shows its edge)
#   Escalier = ef gh EF GH     (optional, with Relief: pairs of [Legend]
#                               symbols for 2-wide stairs, in a south face of
#                               level 1, a north edge of level 1, then the same
#                               for level 2 and up)
#   HerbeHaute = n             (optional: [Legend] symbol of the tall grass on
#                               the raised levels)
#   Ponton  = |                (optional: [Terrains] symbol of the wooden piers
#                               of a port town, over the water)
#   Rive    = !'?              (optional: [Legend] symbols of the bank drawn
#                               on the ground below the water, left end,
#                               middle and right end; an [Ambiance] may give
#                               its own tiles: « Rive = T832 T833 T834 »)
#   Rebord  = (_)              (with Ponton: [Legend] symbols of water with the
#                               south lip of a pier drawn on it, left, middle
#                               and right: the row below the last planks)
#   Bateau  = b                (optional: [Objects] symbol of the boat moored
#                               by a ferry terminal that leads to an island)
#   Recif   = %                (optional: [Legend] symbols of rocks and of
#   Banc    = $                 sandbanks in the sea around an island)
#   Port    = sud              (optional: a port town, the sea on that side;
#                               in a world, the world picks its port towns)
#   MapID   = 52               (optional: overwrite this map instead of
#                               creating a new one each time)
#   [Briques]
#   centre  = 1                (brick type = how many: n or min..max)
#   maison  = 3..6
#   herbes  = 1..2 par case    ("par case": per 20x20 tiles of the map)
#   lac     = 0..1             (a lake drawn with Eau, never in the way: no
#                               brick file for it)
#   [Ambiance verdoyante]      (optional, as many as wanted: each place draws
#   Poids = 6                   one, by weight, 1 by default)
#   Sol   = T1|T2|T3           (tiles of the ground symbol, as in [Legend])
#   Rue   = T274 N=T266 ...    (tiles of the street symbol: as in [Terrains]
#                               with edges N=..., else as in [Legend]; not
#                               needed when Rue and Sol are the same symbol)
#   t     = T520 2x3           (a symbol of the palette below redefined for
#                               this ambiance, in its own section's syntax)
#   arbre = 0..1 par case      (a type of [Briques] with another quantity for
#                               this ambiance)
#   [Legend] [Terrains] [Objects]
#   ...                        (MapGen palette, shared by every brick; with
#                               ambiances, « {sol} » stands for the first tile
#                               of the drawn ground, under flowers, water...)
# Brick file (MapProc/Briques/*.txt):
#   Brique = Centre Pokémon    (required: name, for error messages)
#   Type   = centre            (required: the type named in [Briques])
#   Porte  = 2,4               (optional: door cell, column,row from 0, on the
#                               bottom row; a street is drawn to the cell below)
#   Poids  = 2                 (optional: how often it is picked among the
#                               bricks of its type, 1 by default)
#   Contre = rue               (optional: the brick touches a street, for
#                               lamps, benches, signs)
#   Ambiances = sable, minérale (optional: only drawn in places of one of
#                               these [Ambiance], comma-separated)
#   [Map]
#   CCCCC                      (palette symbols; " " = not part of the brick)
#===============================================================================
module MapProceduralGenerator
  class Error < StandardError; end

  Place = Struct.new(:file, :kind, :name, :tileset_id, :width, :height, :ground, :street,
                     :border, :exits, :spurs, :map_id, :counts, :per_case, :palette,
                     :water, :rock, :pebble, :crossing, :ambiances, :ambiance,
                     :deep, :dive, :levels, :stairs, :mountain, :cave, :excess, :river, :port, :pier,
                     :lips, :island, :boat, :reef, :bank, :ferry, :high_grass, :nook, :banks, :fixed_counts,
                     :mask, :joints)
  # mask, joints: the squares of its rectangle a place of a world covers and
  # where its streets meet (see WorldPlace), nil = the whole rectangle;
  # island: an island of a world (set by the world, the sea all around);
  # ferry: its ferry terminal leads to an island (set by the world); nook:
  # the obstacle of its optional nook, a key of NOOKS (set by the world);
  # banks: « Rive », the 3 symbols of the bank below the water;
  # fixed_counts: quantities set by the world (plateau, islands), which the
  # ambiance doesn't change
  # ground, street: tile text of the ground and street symbols; banks: tiles
  # of the 3 bank symbols on that ground (nil = those of the palette);
  # palette: symbol => its definition for this ambiance; counts, per_case:
  # quantities of brick types for this ambiance, as in [Briques]
  Ambiance = Struct.new(:name, :weight, :ground, :street, :banks, :palette, :counts, :per_case)
  Brick = Struct.new(:file, :name, :kind, :door, :weight, :by_street, :rows, :ambiances)
  PLACE_KINDS = %w[ville route]
  LAKE = "lac"   # brick type drawn by the builder, not read from a file
  HILL = "colline"   # idem
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
    place = Place.new(file, nil, nil, nil, nil, nil, nil, nil, nil, [], 1..1, nil, {}, [], +"", nil, nil, nil, nil, [], nil, nil, false, nil, nil, false, false, nil, false, nil, nil, nil, false, nil, nil, nil, false)
    section = :header
    text.each_line.with_index(1) do |raw, lineno|
      fail_at = proc { |msg| raise Error, "#{file}, ligne #{lineno} : #{msg}" }
      if raw.strip =~ /\A\[Ambiance\s+(.+?)\]\z/i
        place.ambiances.push(Ambiance.new($1.strip, 1, nil, nil, nil, {}, {}, []))
        section = :ambiance
        next
      elsif raw.strip =~ /\A\[(\w+)\]\z/
        section = ($1.downcase == "briques") ? :bricks : :palette
      end
      if section == :palette
        place.palette << raw.chomp << "\n"
        next
      end
      content = raw.chomp.sub(/#.*\z/, "").strip
      next if content.empty? || content =~ /\A\[\w+\]\z/
      # A palette symbol redefined by an ambiance (one character, then « = »)
      if section == :ambiance && content =~ /\A(\S)\s+=\s*(.+)\z/
        place.ambiances.last.palette[$1] = [$2.strip, lineno]
        next
      end
      fail_at.call("attendu « Clé = valeur »") unless content =~ /\A(\w+)\s*=\s*(.+)\z/
      key, value = $1, $2.strip
      if section == :bricks
        place.per_case.push(key) if value.sub!(/\s+par\s+case\z/, "")
        place.counts[key] = range(value, fail_at)
        next
      end
      if section == :ambiance
        ambiance = place.ambiances.last
        case key.downcase
        when "poids" then ambiance.weight = integer(value, fail_at)
        when "sol"   then ambiance.ground = value
        when "rue"   then ambiance.street = value
        when "rive"
          ambiance.banks = value.split
          fail_at.call("3 tuiles attendues (gauche, milieu, droite), ex. « T832 T833 T834 »") unless ambiance.banks.length == 3
        else
          fail_at.call("clé inconnue « #{key} » dans [Ambiance] (Poids, Sol, Rue, Rive, un type de [Briques] ou un symbole)") if !place.counts.key?(key)
          ambiance.per_case.push(key) if value.sub!(/\s+par\s+case\z/, "")
          ambiance.counts[key] = range(value, fail_at)
        end
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
        bad = value.split - SIDES
        fail_at.call("sortie « #{bad[0]} » inconnue (#{SIDES.join(', ')})") unless bad.empty?
        place.exits = value.split.map { |side| [side, nil] }
      when "rues"    then place.spurs = range(value, fail_at)
      when "mapid"   then place.map_id = integer(value, fail_at)
      when "eau"     then place.water = symbol(value, fail_at)
      when "ponton"  then place.pier = symbol(value, fail_at)
      when "bateau"  then place.boat = symbol(value, fail_at)
      when "recif"   then place.reef = symbol(value, fail_at)
      when "banc"    then place.bank = symbol(value, fail_at)
      when "rive"
        fail_at.call("3 symboles attendus (gauche, milieu, droite), trouvé « #{value} »") unless value.length == 3
        place.banks = value
      when "rebord"
        fail_at.call("3 symboles attendus (gauche, milieu, droite), trouvé « #{value} »") unless value.length == 3
        place.lips = value
      when "port"
        fail_at.call("côté « #{value} » inconnu (#{SIDES.join(', ')})") unless SIDES.include?(value)
        place.port = value
      when "profond" then place.deep = symbol(value, fail_at)
      when "roche"   then place.rock = symbol(value, fail_at)
      when "caillou" then place.pebble = symbol(value, fail_at)
      when "relief"
        place.levels = value.split
        fail_at.call("attendu un symbole par niveau, ex. « ^ & k K »") unless place.levels.length >= 2 && place.levels.all? { |v| v.length == 1 }
      when "herbehaute" then place.high_grass = symbol(value, fail_at)
      when "escalier"
        place.stairs = value.split
        fail_at.call("attendu quatre paires de symboles, ex. « ef gh EF GH »") unless place.stairs.length == 4 && place.stairs.all? { |v| v.length == 2 }
      else fail_at.call("clé inconnue « #{key} »")
      end
    end
    { "Lieu" => place.kind, "Nom" => place.name, "Tileset" => place.tileset_id,
      "Taille" => place.width, "Sol" => place.ground, "Rue" => place.street }.each do |key, value|
      raise Error, "#{file} : « #{key} » manquant" if !value
    end
    raise Error, "#{file} : section [Briques] vide" if place.counts.empty?
    place.ambiances.each do |ambiance|
      raise Error, "#{file} : [Ambiance #{ambiance.name}] sans « Sol »" if !ambiance.ground
      if !ambiance.street && place.street != place.ground
        raise Error, "#{file} : [Ambiance #{ambiance.name}] sans « Rue »"
      end
    end
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
      when "ambiances" then brick.ambiances = value.split(",").map(&:strip)
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
    place.ambiances.each do |ambiance|
      ambiance.palette.each do |sym, (_value, lineno)|
        next if palette_section(place, sym)
        raise Error, "#{place.file}, ligne #{lineno} : [Ambiance #{ambiance.name}] redéfinit « #{sym} », absent de la palette"
      end
    end
    palette = MapGenerator.parse(plan_text(place, 0, [place.ground]), place.file)
    # With ambiances, the ground and street are defined by each ambiance only
    if place.ambiances.any?
      [place.ground, place.street].uniq.each do |sym|
        next if place.palette !~ /^\s*#{Regexp.escape(sym)}\s*=/
        raise Error, "#{place.file} : avec des [Ambiance], « #{sym} » se définit dans chaque ambiance (Sol, Rue), pas dans la palette"
      end
    end
    known = palette.legend.keys + palette.objects.keys + palette.terrains.keys
    raise Error, "#{place.file} : « Rue = #{place.street} » absent de la palette" if !known.include?(place.street)
    if place.border && !palette.objects[place.border]
      raise Error, "#{place.file} : « Bordure = #{place.border} » doit être un symbole de [Objects]"
    end
    if place.water && !palette.legend[place.water]
      raise Error, "#{place.file} : « Eau = #{place.water} » doit être un symbole de [Legend]"
    end
    if place.deep && !palette.legend[place.deep]
      raise Error, "#{place.file} : « Profond = #{place.deep} » doit être un symbole de [Legend]"
    end
    if place.rock && !palette.objects[place.rock]
      raise Error, "#{place.file} : « Roche = #{place.rock} » doit être un symbole de [Objects]"
    end
    if place.pebble && !palette.legend[place.pebble]
      raise Error, "#{place.file} : « Caillou = #{place.pebble} » doit être un symbole de [Legend]"
    end
    raise Error, "#{place.file} : « lac » dans [Briques] demande « Eau »" if place.counts["lac"] && !place.water
    if place.pier && !palette.terrains[place.pier]
      raise Error, "#{place.file} : « Ponton = #{place.pier} » doit être un symbole de [Terrains]"
    end
    raise Error, "#{place.file} : « Port » demande « Eau », « Ponton » et « Rebord »" if place.port && (!place.water || !place.pier || !place.lips)
    place.banks&.each_char do |sym|
      raise Error, "#{place.file} : « Rive » : « #{sym} » doit être un symbole de [Legend]" if !palette.legend[sym]
    end
    place.lips&.each_char do |sym|
      raise Error, "#{place.file} : « Rebord » : « #{sym} » doit être un symbole de [Legend]" if !palette.legend[sym]
    end
    raise Error, "#{place.file} : « Port = #{place.port} » est aussi une sortie" if place.port && place.exits.any? { |side, _| side == place.port }
    if place.boat && !palette.objects[place.boat]
      raise Error, "#{place.file} : « Bateau = #{place.boat} » doit être un symbole de [Objects]"
    end
    { "Recif" => place.reef, "Banc" => place.bank }.each do |key, sym|
      raise Error, "#{place.file} : « #{key} = #{sym} » doit être un symbole de [Legend]" if sym && !palette.legend[sym]
    end
    raise Error, "#{place.file} : « Relief » demande « Escalier »" if !place.levels != !place.stairs
    place.levels&.each do |sym|
      raise Error, "#{place.file} : « Relief » : « #{sym} » doit être un symbole de [Terrains]" if !palette.terrains[sym]
    end
    raise Error, "#{place.file} : « HerbeHaute = #{place.high_grass} » doit être un symbole de [Legend]" if place.high_grass && !palette.legend[place.high_grass]
    place.stairs&.join&.each_char do |sym|
      raise Error, "#{place.file} : « Escalier » : « #{sym} » doit être un symbole de [Legend]" if !palette.legend[sym]
    end
    place.counts.each_key do |kind|
      next if [LAKE, HILL].include?(kind) || bricks.any? { |b| b.kind == kind }
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

  # The place's ambiance (place.ambiance names it, else the first one).
  def ambiance(place)
    return place.ambiances.find { |a| a.name == place.ambiance } || place.ambiances.first
  end

  # Draws an ambiance by weight; nil if the place has none.
  def draw_ambiance(place, rng)
    return nil if place.ambiances.empty?
    roll = rng.rand(place.ambiances.sum(&:weight))
    return place.ambiances.find { |a| (roll -= a.weight) < 0 }.name
  end

  # Palette with the ambiance's ground and street.
  def palette_text(place)
    chosen = ambiance(place)
    return place.palette if !chosen
    ground = chosen.ground.split("|").first.split.first
    text = place.palette.gsub("{sol}", ground)
    text << "\n# Ambiance #{chosen.name}\n[Legend]\n#{place.ground} = #{chosen.ground}\n"
    if chosen.street && place.street != place.ground
      section = (chosen.street =~ /\s\w+=/) ? "Terrains" : "Legend"
      text << "[#{section}]\n#{place.street} = #{chosen.street}\n"
    end
    if chosen.banks && place.banks
      text << "[Legend]\n"
      place.banks.each_char.with_index { |sym, i| text << "#{sym} = #{chosen.banks[i]}\n" }
    end
    chosen.palette.each do |sym, (value, _lineno)|
      text << "[#{palette_section(place, sym)}]\n#{sym} = #{value.gsub('{sol}', ground)}\n"
    end
    return text
  end

  # Section of the place's palette ([Legend], [Objects], [Terrains]) where
  # that symbol is defined; nil if it isn't.
  def palette_section(place, sym)
    section = nil
    place.palette.each_line do |line|
      if line.strip =~ /\A\[(\w+)\]\z/ then section = $1
      elsif line.start_with?("#{sym} ") || line.start_with?("#{sym}=") then return section
      end
    end
    return nil
  end

  # The place with its ambiance's quantities of bricks (only the types it
  # still has: a world may have changed the quantities first).
  def with_ambiance_counts(place)
    chosen = ambiance(place)
    return place if !chosen || chosen.counts.empty? || place.fixed_counts
    place = place.dup
    place.counts = place.counts.dup
    place.per_case = place.per_case.dup
    chosen.counts.each do |kind, range|
      next if !place.counts.key?(kind)
      place.counts[kind] = range
      place.per_case.delete(kind)
      place.per_case.push(kind) if chosen.per_case.include?(kind)
    end
    return place
  end

  # MapGen plan text of a place: header, palette, then the assembled rows.
  def plan_text(place, seed, rows)
    text = +"Name    = #{place.name}\n"
    text << "Tileset = #{place.tileset_id}\n"
    text << "MapID   = #{place.map_id}\n" if place.map_id
    text << "Seed    = #{seed}\n"
    text << "Ground  = #{place.ground}\n"
    text << palette_text(place)
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
