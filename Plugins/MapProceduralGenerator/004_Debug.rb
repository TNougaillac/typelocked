#===============================================================================
# MapProceduralGenerator - Debug menu command
# Debug menu > Other editors... > Générer un lieu (MapProc)
# Prototype: writes the assembled place to a map of the editor, like MapGen,
# so each seed can be looked at. Generating while playing comes later.
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
    plan, text, = generate_place(place, load_bricks, seed)
    map_id, = MapGenerator.generate(plan)
    # The export overwrites the same map when copied to MapGen/
    text = text.sub(/^Seed/, "MapID   = #{map_id}\nSeed") if !place.map_id
    folder = File.join(FOLDER, EXPORT_FOLDER)
    Dir.mkdir(folder) unless File.directory?(folder)
    export = File.join(folder, "#{File.basename(path, '.txt')}_#{seed}.txt")
    File.write(export, text)
    return map_id, export
  end

  def debug_menu
    files = place_files
    if files.empty?
      pbMessage(_INTL("Aucun lieu trouvé dans le dossier {1}/.", FOLDER))
      return
    end
    index = pbShowCommands(nil, files.map { |f| File.basename(f) }, -1)
    return if index < 0
    text = pbMessageFreeText(_INTL("Graine ? (vide = au hasard)"), "", false, 9)
    seed = (text =~ /\A\d+\z/) ? text.to_i : rand(1_000_000)
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
  "description" => _INTL("Assemble un lieu à partir des briques du dossier MapProc, différent pour chaque graine."),
  "effect"      => proc { MapProceduralGenerator.debug_menu }
})
