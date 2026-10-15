#===============================================================================
# MapEvents - Writes the events into the maps, updates the PBS files and adds
# the debug menu command.
# Debug menu > Other editors... > Placer les événements (MapEvents)
#===============================================================================
module MapEvents
  TAG_PATTERN = /\b#{TAG}\s+\S+\z/

  module_function

  def plan_files
    return Dir.glob(File.join(FOLDER, "*.txt")).sort
  end

  # Replaces the map's tagged events with the plan's. Returns [map_id, notes].
  def generate(plan)
    infos = load_data("Data/MapInfos.rxdata")
    map_id = (plan.target.is_a?(Integer)) ? (infos[plan.target] && plan.target) : infos.select { |_id, info| info.name == plan.target }.keys.min
    raise Error, "#{plan.file} : la carte « #{plan.target} » n'existe pas (génère-la d'abord avec MapGen)" if !map_id
    plan.events.each do |entry|
      gift = entry.value("Gift")
      next if !gift || GameData::Item.exists?(gift)
      raise Error, "#{plan.file} : [Trainer #{entry.label}] : objet « #{gift} » inconnu"
    end
    path = sprintf("Data/Map%03d.rxdata", map_id)
    map = load_data(path)
    map.events.delete_if { |_id, event| event.name[TAG_PATTERN] }
    notes = []
    checker = Compiler::TrainerChecker.new
    plan.events.each do |entry|
      label = "[#{entry.kind.capitalize} #{entry.label}]"
      if entry.x >= map.width || entry.y >= map.height
        raise Error, "#{plan.file} : #{label} en #{entry.x},#{entry.y}, hors de la carte (#{map.width}x#{map.height})"
      end
      other = map.events.values.find { |event| event.x == entry.x && event.y == entry.y }
      notes.push(_INTL("{1} : {2} est sur la même case que l'événement « {3} ».", plan.file, label, other.name)) if other
      event = build_event(entry, (map.events.keys.max || 0) + 1, checker)
      map.events[event.id] = event
    end
    set_bgm(map, plan.bgm) if plan.bgm
    save_data(map, path)
    update_pbs(plan, map_id, infos[map_id].name)
    return map_id, notes
  end

  def set_bgm(map, value)
    name, volume, pitch = value.split(",").map(&:strip)
    map.autoplay_bgm = true
    map.bgm = RPG::AudioFile.new(name, (volume || 100).to_i, (pitch || 100).to_i)
  end

  #-----------------------------------------------------------------------------
  # PBS files (only the map's own section is touched)
  #-----------------------------------------------------------------------------
  def update_pbs(plan, map_id, map_name)
    if !plan.encounters.empty?
      body = plan.encounters.map { |line| (line =~ /\A\d/) ? "    #{line}" : line }
      write_section(ENCOUNTERS_PBS, map_id, map_name, body, false)
      Compiler.compile_encounters(ENCOUNTERS_PBS)
    end
    if !plan.metadata.empty?
      write_section(MAP_METADATA_PBS, map_id, map_name, plan.metadata, true)
      Compiler.compile_map_metadata(MAP_METADATA_PBS)
    end
  end

  # Replaces the body of the map's [ID] section (merge = only the keys in body).
  def write_section(path, map_id, map_name, body, merge)
    lines = (File.exist?(path)) ? File.read(path, encoding: "UTF-8").sub(/\A﻿/, "").split("\n", -1) : []
    lines.pop if lines.last == ""
    start = lines.index { |l| l =~ /\A\[\s*0*#{map_id}\s*\]/ }
    if !start
      lines.push("#-------------------------------") if !lines.empty?
      lines.push(sprintf("[%03d]   # %s", map_id, map_name))
      start = lines.length - 1
    end
    finish = start + 1
    finish += 1 while finish < lines.length && lines[finish] !~ /\A\[|\A#-/
    if merge
      keys = body.map { |l| l[/\A\w+/] }
      body = lines[start + 1...finish].reject { |l| keys.include?(l[/\A(\w+)\s*=/, 1]) } + body
    end
    lines[start + 1...finish] = body
    File.write(path, "﻿" + lines.join("\n") + "\n", encoding: "UTF-8")
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
    done = []
    ((index == files.length) ? files : [files[index]]).each do |path|
      plan = parse_file(path)
      map_id, notes = generate(plan)
      done.push(map_id)
      Console.echoln_li(_INTL("{1} -> carte {2}, {3} événements", File.basename(path), map_id, plan.events.length))
      pbMessage(_INTL("{1} : {2} événements placés sur la carte {3}.", File.basename(path), plan.events.length, map_id))
      notes.each { |n| pbMessage(n) }
    rescue Error => e
      pbMessage(_INTL("Erreur : {1}", e.message))
    end
    return if done.empty?
    if $game_map && done.include?($game_map.map_id)
      pbMessage(_INTL("Quitte cette carte et reviens-y pour voir ses nouveaux événements."))
    end
    MapGenerator.offer_editor_restart if defined?(MapGenerator)
  end
end

MenuHandlers.add(:debug_menu, :map_events, {
  "name"        => _INTL("Placer les événements (MapEvents)"),
  "parent"      => :editors_menu,
  "description" => _INTL("Place PNJ, dresseurs et objets sur les cartes à partir des plans du dossier MapEvents."),
  "effect"      => proc { MapEvents.debug_menu }
})
