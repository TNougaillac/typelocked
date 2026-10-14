#===============================================================================
# MapGenerator - Writes maps and adds the debug menu command
# Debug menu > Other editors... > Générer des cartes (MapGen)
#===============================================================================
module MapGenerator
  module_function

  def plan_files
    return Dir.glob(File.join(FOLDER, "*.txt")).sort
  end

  # Writes the plan to Data/MapXXX.rxdata and returns [map_id, notes, missing]
  # (missing = warp targets that don't exist yet).
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
    missing = place_warps(plan, map, infos)
    save_data(map, sprintf("Data/Map%03d.rxdata", map_id))
    save_data(infos, "Data/MapInfos.rxdata")
    return map_id, notes, missing
  end

  WARP_EVENT_NAME = "MapGen warp"

  # Replaces the transfer events made by an earlier generation with the ones
  # in [Events]. Essentials turns them into animated doors when it compiles
  # the map (Compiler.likely_passage?) if the cell looks like a doorway.
  # Returns the targets that are not in the map tree yet.
  def place_warps(plan, map, infos)
    missing = []
    map.events.delete_if { |_id, event| event.name == WARP_EVENT_NAME }
    plan.events.each_with_index do |row, y|
      row.each_char.with_index do |c, x|
        next if !(warp = plan.warps[c])
        target_id = warp_target_id(plan, warp, infos)
        if !target_id
          missing.push(warp.target)
          next
        end
        event = RPG::Event.new(x, y)
        event.id = (map.events.keys.max || 0) + 1
        event.name = WARP_EVENT_NAME
        page = event.pages[0]
        page.trigger = 1   # Player touch
        page.list = [
          RPG::EventCommand.new(201, 0, [0, target_id, warp.x, warp.y, warp.direction, 0]),
          RPG::EventCommand.new(0, 0, [])
        ]
        map.events[event.id] = event
      end
    end
    return missing.uniq
  end

  # Second pass for plans generated before their warp targets existed.
  def relink_warps(plan, map_id)
    path = sprintf("Data/Map%03d.rxdata", map_id)
    map = load_data(path)
    missing = place_warps(plan, map, load_data("Data/MapInfos.rxdata"))
    save_data(map, path)
    return missing
  end

  # Target map ID from a number or from a map name in the map tree.
  def warp_target_id(plan, warp, infos)
    return (infos[warp.target] ? warp.target : nil) if warp.target.is_a?(Integer)
    return plan.map_id if warp.target == plan.name && plan.map_id
    found = infos.select { |_id, info| info.name == warp.target }.keys
    return found.min
  end

  def debug_menu
    files = plan_files
    if files.empty?
      pbMessage(_INTL("Aucun plan trouvé dans le dossier {1}/.", FOLDER))
      return
    end
    worlds = files.select { |f| world_file?(f) }
    commands = files.map { |f| (worlds.include?(f) ? "[Monde] " : "") + File.basename(f) } + [_INTL("Tous")]
    index = pbShowCommands(nil, commands, -1)
    return if index < 0
    chosen = (index == files.length) ? files : [files[index]]
    generated = 0
    unlinked = []
    # Maps first, so the worlds find them by name
    (chosen - worlds).each do |path|
      begin
        plan = parse_file(path)
        map_id, notes, missing = generate(plan)
        generated += 1
        unlinked.push([plan, map_id]) if !missing.empty?
        Console.echoln_li(_INTL("{1} -> carte {2} « {3} »", File.basename(path), map_id, plan.name))
        pbMessage(_INTL("{1} : carte {2} « {3} » générée.", File.basename(path), map_id, plan.name))
        notes.each { |n| pbMessage(n) }
      rescue Error => e
        pbMessage(_INTL("Erreur : {1}", e.message))
      end
    end
    unlinked.each do |plan, map_id|
      relink_warps(plan, map_id).each do |target|
        pbMessage(_INTL("{1} : porte vers « {2} » ignorée, cette carte n'existe pas.", plan.file, target))
      end
    end
    (chosen & worlds).each do |path|
      begin
        run_world(path)
        generated += 1
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
