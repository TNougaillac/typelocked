#===============================================================================
# MapProceduralGenerator - A new world for each new game
# Starting a new game draws the world of NEW_GAME_WORLD with a random seed
# (maps only, no events) and the game starts in its first town, the player
# only choosing a name. The seed is saved with the game. At each start of
# the game (load screen), the maps on disk are matched with the save: the
# maps of a game left without saving are deleted, or the saved world is drawn
# again from its seed if the save has one.
#===============================================================================
module MapProceduralGenerator
  module_function

  # { path:, seed:, town_map:, start: } of the world on disk if a new game
  # drew it, else nil.
  def game_world
    return nil if !File.exist?(GAME_WORLD_FILE)
    return load_data(GAME_WORLD_FILE)
  end

  def forget_game_world
    delete_file(GAME_WORLD_FILE)
  end

  def delete_file(file)
    File.delete(file)
  rescue Errno::ENOENT
    nil
  end

  # Draws the world of a new game. Returns its seed and start ([map ID, x, y]),
  # nil if there is none.
  def new_game_world
    return nil if !NEW_GAME_WORLD
    path = File.join(FOLDER, NEW_GAME_WORLD)
    return nil if !File.exist?(path)
    seed = rand(1_000_000)
    start = draw_game_world(path, seed)
    return start ? [seed, start] : nil
  end

  # Called with the seed of the save file (nil = no save, or a save without a
  # world): puts the maps on disk back in line with it.
  def sync_game_world(saved_seed)
    world = game_world
    return if !world || world[:seed] == saved_seed
    if saved_seed
      Console.echoln_li(_INTL("Monde de la sauvegarde redessiné (graine {1})", saved_seed))
      draw_game_world(world[:path], saved_seed, prune: true)
    else
      Console.echoln_li(_INTL("Monde d'une partie non sauvegardée supprimé (graine {1})", world[:seed]))
      remove_world(world[:path], world[:town_map])
      forget_game_world
    end
  end

  # prune: also deletes the maps of the unsaved world that this one doesn't
  # have (more caves...). Returns the world's start, nil if it failed.
  def draw_game_world(path, seed, prune: false)
    # The world rewrites its Town Map region: its lines from before the first
    # game world are kept, and put back before each new world is drawn
    region = load_world(path).region
    if game_world
      town_map = game_world[:town_map]
      restore_town_map(region, town_map)
    else
      town_map = town_map_section(region)
    end
    begin
      _export, start = generate_world_maps(path, seed, quiet: true, prune: prune)
    rescue Error, MapGenerator::Error => e
      pbMessage(_INTL("Le monde n'a pas pu être généré : {1}", e.message))
      return nil
    end
    $game_temp.map_infos = nil if $game_temp
    save_data({ path: path, seed: seed, town_map: town_map, start: start }, GAME_WORLD_FILE)
    return start
  end

  # Deletes every map made for this world file and puts its Town Map region
  # back.
  def remove_world(path, town_map)
    remove_maps(read_world_maps(path).values, compile: false)
    delete_file(world_maps_path(path))
    restore_town_map(load_world(path).region, town_map)
    MapGenerator.compile_world_pbs
  end

  # Puts back the lines of a Town Map region's section (nil = no section).
  def restore_town_map(region, town_map)
    lines = MapGenerator.read_pbs(MapGenerator::TOWN_MAP_PBS)
    start, finish = section_range(lines, "[#{region}]")
    if start
      lines.slice!(start...finish)
      start -= 1 if !town_map && start > 0 && lines[start - 1].start_with?("#-")
      lines.slice!(start) if !town_map && lines[start]&.start_with?("#-")
    end
    if town_map
      lines.push("#-------------------------------") if !start && !lines.empty?
      lines.insert(start || lines.length, *town_map)
    end
    MapGenerator.write_pbs(MapGenerator::TOWN_MAP_PBS, lines)
  end

  # Lines of a Town Map region's section, nil if it has none.
  def town_map_section(region)
    lines = MapGenerator.read_pbs(MapGenerator::TOWN_MAP_PBS)
    start, finish = section_range(lines, "[#{region}]")
    return start ? lines[start...finish] : nil
  end

  # [first line, line after the last] of the section with that header.
  def section_range(lines, header)
    start = lines.index { |l| l.strip == header }
    return nil if !start
    finish = start + 1
    finish += 1 while finish < lines.length && lines[finish] !~ /\A\[|\A#-/
    return start, finish
  end

  # Deletes these maps, their place in the map tree, their lines in the PBS
  # files (connections, map metadata, Town Map points) and their cave seeds.
  def remove_maps(ids, compile: true)
    return if ids.empty?
    infos = load_data("Data/MapInfos.rxdata")
    names = ids.filter_map { |id| infos[id]&.name }
    ids.each do |id|
      infos.delete(id)
      delete_file(sprintf("Data/Map%03d.rxdata", id))
    end
    save_data(infos, "Data/MapInfos.rxdata")
    $game_temp.map_infos = nil if $game_temp
    # Connections (and the comment line above each one)
    file = MapGenerator::CONNECTIONS_PBS
    kept = []
    MapGenerator.read_pbs(file).each do |line|
      fields = line.split(",")
      if fields.length == 6 && (ids.include?(fields[0].to_i) || ids.include?(fields[3].to_i))
        kept.pop if kept.last && kept.last.start_with?("#") && !kept.last.start_with?("#-")
        next
      end
      kept.push(line)
    end
    MapGenerator.write_pbs(file, kept)
    # Map metadata sections (and the separator above each one)
    file = MapGenerator::MAP_METADATA_PBS
    lines = MapGenerator.read_pbs(file)
    ids.each do |id|
      start = lines.index { |l| l =~ /\A\[0*#{id}\]/ }
      next if !start
      finish = start + 1
      finish += 1 while finish < lines.length && lines[finish] !~ /\A\[|\A#-/
      start -= 1 if start > 0 && lines[start - 1].start_with?("#-")
      lines.slice!(start...finish)
    end
    MapGenerator.write_pbs(file, lines)
    # Town Map points named after a deleted map
    file = MapGenerator::TOWN_MAP_PBS
    lines = MapGenerator.read_pbs(file).reject do |l|
      l =~ /\APoint\s*=\s*\d+,\d+,([^,]*)/ && names.include?($1.strip)
    end
    MapGenerator.write_pbs(file, lines)
    seeds = cave_seeds.reject { |id, _seed| ids.include?(id) }
    save_data(seeds, CAVE_SEEDS_FILE)
    @cave_seeds = seeds
    MapGenerator.compile_world_pbs if compile
  end
end

SaveData.register(:mapproc_world) do
  save_value { $mapproc_world }
  load_value { |value| $mapproc_world = value }
  new_game_value { nil }
end

module Game
  class << self
    alias_method :__mapproc_start_new, :start_new

    # The world is drawn before the game starts, so its data is ready. The
    # game then starts in its first town, without the intro of the editor's
    # start map: the player only chooses a name (see below).
    def start_new
      seed, start = MapProceduralGenerator.new_game_world
      system = $data_system
      editor_start = [system.start_map_id, system.start_x, system.start_y]
      system.start_map_id, system.start_x, system.start_y = start if start
      begin
        __mapproc_start_new
      ensure
        system.start_map_id, system.start_x, system.start_y = editor_start
      end
      $mapproc_world = seed
      $game_temp.mapproc_name_entry = true if start
    end
  end
end

class Game_Temp
  # The player of a new game in a generated world still has to be named.
  attr_accessor :mapproc_name_entry
end

# Name entry on the first frame of the map (character 1, as in the intro).
EventHandlers.add(:on_frame_update, :mapproc_player_name,
  proc {
    next if !$game_temp.mapproc_name_entry || pbMapInterpreterRunning?
    $game_temp.mapproc_name_entry = false
    pbTrainerName
  }
)

class PokemonLoadScreen
  alias_method :__mapproc_initialize, :initialize

  def initialize(scene)
    __mapproc_initialize(scene)
    MapProceduralGenerator.sync_game_world(@save_data[:mapproc_world])
  end
end
