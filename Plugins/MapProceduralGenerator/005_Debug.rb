#===============================================================================
# MapProceduralGenerator - Debug menu command
# Debug menu > Other editors... > Générer un lieu (MapProc)
# Prototype: writes the assembled place, or every place of a world, to maps of
# the editor, like MapGen, so each seed can be looked at. Generating while
# playing comes later.
#===============================================================================
module MapProceduralGenerator
  module_function

  def load_place(path)
    return parse_place(read(path), File.basename(path))
  end

  def load_bricks
    return brick_files.map { |path| parse_brick(read(path), File.basename(path)) }
  end

  # Writes the place to a map and its plan to MapProc/Export/.
  # Returns [map_id, export path].
  def generate_map(path, seed)
    place = load_place(path)
    place.name = "#{place.name} #{seed}"
    plan, text, = generate_place(place, load_bricks, seed)
    map_id, = MapGenerator.generate(plan)
    # The export overwrites the same map when copied to MapGen/
    text = text.sub(/^Seed/, "MapID   = #{map_id}\nSeed") if !place.map_id
    export = export_path(path, seed)
    File.write(export, text)
    return map_id, export
  end

  def load_world(path)
    return parse_world(read(path), File.basename(path))
  end

  def export_path(path, seed, suffix = "")
    folder = File.join(FOLDER, EXPORT_FOLDER)
    Dir.mkdir(folder) unless File.directory?(folder)
    return File.join(folder, "#{File.basename(path, '.txt')}#{suffix}_#{seed}.txt")
  end

  # Maps made by earlier generations of this world, name => map ID, kept in
  # MapProc/Export/<world>_cartes.txt. Only these are ever overwritten.
  def world_maps_path(path)
    return File.join(FOLDER, EXPORT_FOLDER, "#{File.basename(path, '.txt')}_cartes.txt")
  end

  def read_world_maps(path)
    file = world_maps_path(path)
    return {} if !File.exist?(file)
    return read(file).each_line.filter_map { |l| [$2.strip, $1.to_i] if l =~ /\A(\d+)\s*=\s*(.+)\z/ }.to_h
  end

  # Writes every place of the world to its map, then runs the world plan
  # through MapGen (connections, map metadata, Town Map). Returns the export.
  def generate_world_maps(path, seed)
    world = load_world(path)
    town = load_place(File.join(FOLDER, world.town_file))
    route = load_place(File.join(FOLDER, world.route_file))
    map_ids = read_world_maps(path)
    result = generate_world(world, town, route, load_bricks, seed, map_ids)
    # MapGen finds the world's maps by name: another map with the same name
    # would be taken instead
    infos = load_data("Data/MapInfos.rxdata")
    names = result.places.map { |wp, *| wp.name } + result.caves.map { |_wp, name, *| name }
    names.each do |name|
      clash = infos.find { |id, info| info.name == name && map_ids[name] != id }
      next if !clash
      raise Error, "#{File.basename(path)} : la carte #{clash[0]} s'appelle déjà « #{name} » ; renomme-la ou change « Noms »"
    end
    # Routes first (their caves don't exist yet: their warps are linked after)
    plans = result.places.map { |_wp, _place, text, _layout| text } +
            result.caves.map { |_wp, name, text, _seed| text.sub(/^Tileset/, map_ids[name] ? "MapID   = #{map_ids[name]}\nTileset" : "Tileset") }
    unlinked = []
    plans.each do |text|
      plan = MapGenerator.parse(text, File.basename(path))
      map_ids[plan.name], _notes, missing = MapGenerator.generate(plan)
      unlinked.push(plan) if !missing.empty?
    end
    unlinked.each { |plan| MapGenerator.relink_warps(plan, map_ids[plan.name]) }
    result.caves.each { |_wp, name, _text, _seed| dress_cave(map_ids[name]) }
    save_cave_seeds(result.caves.to_h { |_wp, name, _text, cave_seed| [map_ids[name], cave_seed] })
    write_cave_metadata(world, result, map_ids)
    export_path(path, seed)   # creates the folder
    File.write(world_maps_path(path), map_ids.map { |name, id| "#{id} = #{name}\n" }.join)
    export = export_path(path, seed)
    File.write(export, result.text)
    MapGenerator.run_world(export)
    surf = result.places.find { |wp, *| wp.surf }
    pbMessage(_INTL("Surf s'obtient à {1}.", surf[0].name)) if surf
    return export
  end

  # Shows the cave exits as ladders.
  def dress_cave(map_id)
    path = sprintf("Data/Map%03d.rxdata", map_id)
    map = load_data(path)
    map.events.each_value do |event|
      next if event.name != MapGenerator::WARP_EVENT_NAME
      event.pages[0].graphic.tile_id = CAVE_EXIT_TILE
    end
    save_data(map, path)
  end

  # Caves are not on the world grid: MapGen doesn't write their metadata.
  # Dungeon = true makes Essentials draw a random layout on each visit.
  def write_cave_metadata(world, result, map_ids)
    file = MapGenerator::MAP_METADATA_PBS
    lines = MapGenerator.read_pbs(file)
    result.caves.each do |wp, name, *|
      id = map_ids[name]
      start = lines.index { |l| l =~ /\A\[0*#{id}\]/ }
      if start
        finish = start + 1
        finish += 1 while finish < lines.length && lines[finish] !~ /\A\[|\A#-/
        lines.slice!(start...finish)
      else
        lines.push("#-------------------------------") if !lines.empty?
        start = lines.length
      end
      lines.insert(start, sprintf("[%03d]   # %s", id, name), "Name = #{name}",
                   "MapPosition = #{world.region},#{world.origin[0] + wp.x},#{world.origin[1] + wp.y}",
                   "Dungeon = true", "BattleBack = cave1", "Environment = Cave")
    end
    MapGenerator.write_pbs(file, lines)
  end

  def debug_menu
    files = place_files
    if files.empty?
      pbMessage(_INTL("Aucun lieu trouvé dans le dossier {1}/.", FOLDER))
      return
    end
    index = pbShowCommands(nil, files.map { |f| (world_file?(f) ? "[Monde] " : "") + File.basename(f) }, -1)
    return if index < 0
    text = pbMessageFreeText(_INTL("Graine ? (vide = au hasard)"), "", false, 9)
    seed = (text =~ /\A\d+\z/) ? text.to_i : rand(1_000_000)
    if world_file?(files[index])
      begin
        export = generate_world_maps(files[index], seed)
      rescue Error, MapGenerator::Error => e
        pbMessage(_INTL("Erreur : {1}", e.message))
        return
      end
      pbMessage(_INTL("Monde généré avec la graine {1}, plan enregistré dans {2}.", seed, export))
      MapGenerator.offer_editor_restart
      return
    end
    begin
      map_id, export = generate_map(files[index], seed)
    rescue Error, MapGenerator::Error => e
      pbMessage(_INTL("Erreur : {1}", e.message))
      return
    end
    Console.echoln_li(_INTL("{1} graine {2} -> carte {3}", File.basename(files[index]), seed, map_id))
    pbMessage(_INTL("Carte {1} générée avec la graine {2}.", map_id, seed))
    pbMessage(_INTL("Plan enregistré dans {1} : copie-le dans MapGen/ pour le retoucher.", export))
    MapGenerator.offer_editor_restart
  end
end

MenuHandlers.add(:debug_menu, :map_procedural_generator, {
  "name"        => _INTL("Générer un lieu (MapProc)"),
  "parent"      => :editors_menu,
  "description" => _INTL("Assemble un lieu ou un monde entier à partir des briques du dossier MapProc, différent pour chaque graine."),
  "effect"      => proc { MapProceduralGenerator.debug_menu }
})
