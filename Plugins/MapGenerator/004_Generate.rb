#===============================================================================
# MapGenerator - Writes maps and adds the debug menu command
# Debug menu > Other editors... > Générer des cartes (MapGen)
#===============================================================================
module MapGenerator
  module_function

  def plan_files
    return Dir.glob(File.join(FOLDER, "*.txt")).sort
  end

  # Writes the plan to Data/MapXXX.rxdata and returns [map_id, notes].
  def generate(plan)
    tilesets = load_data("Data/Tilesets.rxdata")
    check_tiles(plan, tilesets[plan.tileset_id])
    infos = load_data("Data/MapInfos.rxdata")
    if plan.parent_id && plan.parent_id != 0 && !infos[plan.parent_id]
      raise Error, "#{plan.file} : la carte parente #{plan.parent_id} n'existe pas"
    end
    data = build_data(plan)
    notes = []
    if plan.map_id
      raise Error, "#{plan.file} : la carte #{plan.map_id} n'existe pas" if !infos[plan.map_id]
      map_id = plan.map_id
      map = load_data(sprintf("Data/Map%03d.rxdata", map_id))
      # Keep events, drop the ones that fall outside the new size
      map.events.delete_if do |_id, event|
        outside = event.x >= data.xsize || event.y >= data.ysize
        notes.push(_INTL("Événement « {1} » supprimé (hors de la carte).", event.name)) if outside
        outside
      end
    else
      map_id = (infos.keys.max || 0) + 1
      map = RPG::Map.new(data.xsize, data.ysize)
      info = RPG::MapInfo.new
      info.order = (infos.values.map { |i| i.order }.max || 0) + 1
      infos[map_id] = info
      notes.push(_INTL("Ajoute « MapID = {1} » au fichier pour la regénérer sans créer de doublon.", map_id))
    end
    infos[map_id].name = plan.name
    infos[map_id].parent_id = plan.parent_id if plan.parent_id
    map.tileset_id = plan.tileset_id
    map.width = data.xsize
    map.height = data.ysize
    map.data = data
    save_data(map, sprintf("Data/Map%03d.rxdata", map_id))
    save_data(infos, "Data/MapInfos.rxdata")
    return map_id, notes
  end

  def debug_menu
    files = plan_files
    if files.empty?
      pbMessage(_INTL("Aucun plan trouvé dans le dossier {1}/.", FOLDER))
      return
    end
    commands = files.map { |f| File.basename(f) } + [_INTL("Tous")]
    index = pbShowCommands(nil, commands, -1)
    return if index < 0
    chosen = (index == files.length) ? files : [files[index]]
    generated = 0
    chosen.each do |path|
      begin
        plan = parse_file(path)
        map_id, notes = generate(plan)
        generated += 1
        Console.echoln_li(_INTL("{1} -> carte {2} « {3} »", File.basename(path), map_id, plan.name))
        pbMessage(_INTL("{1} : carte {2} « {3} » générée.", File.basename(path), map_id, plan.name))
        notes.each { |n| pbMessage(n) }
      rescue Error => e
        pbMessage(_INTL("Erreur : {1}", e.message))
      end
    end
    offer_editor_restart if generated > 0
  end
end

MenuHandlers.add(:debug_menu, :map_generator, {
  "name"        => _INTL("Générer des cartes (MapGen)"),
  "parent"      => :editors_menu,
  "description" => _INTL("Crée ou met à jour des cartes à partir des plans du dossier MapGen."),
  "effect"      => proc { MapGenerator.debug_menu }
})

MenuHandlers.add(:debug_menu, :map_generator_restart, {
  "name"        => _INTL("Rouvrir RPG Maker XP (MapGen)"),
  "parent"      => :editors_menu,
  "description" => _INTL("Ferme RPG Maker XP sans enregistrer et rouvre le projet pour charger les cartes générées."),
  "effect"      => proc {
    next pbMessage(_INTL("RPG Maker XP n'est pas ouvert.")) if !MapGenerator.editor_running?
    if pbConfirmMessage(_INTL("Fermer RPG Maker XP sans enregistrer et rouvrir le projet ?")) &&
       !MapGenerator.restart_editor
      pbMessage(_INTL("Impossible de relancer RPG Maker XP."))
    end
  }
})
