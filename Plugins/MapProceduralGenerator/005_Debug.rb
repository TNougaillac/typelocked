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
    result.places.each do |wp, *|
      clash = infos.find { |id, info| info.name == wp.name && map_ids[wp.name] != id }
      next if !clash
      raise Error, "#{File.basename(path)} : la carte #{clash[0]} s'appelle déjà « #{wp.name} » ; renomme-la ou change « Noms »"
    end
    result.places.each do |wp, _place, text, _layout|
      map_ids[wp.name], = MapGenerator.generate(MapGenerator.parse(text, File.basename(path)))
    end
    export_path(path, seed)   # creates the folder
    File.write(world_maps_path(path), map_ids.map { |name, id| "#{id} = #{name}\n" }.join)
    export = export_path(path, seed)
    File.write(export, result.text)
    MapGenerator.run_world(export)
    return export
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
