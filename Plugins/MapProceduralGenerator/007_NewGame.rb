#===============================================================================
# MapProceduralGenerator - A new world for each new game
# Starting a new game draws the world of NEW_GAME_WORLD with a random seed
# (maps only, no events) and the game starts in its first town, the player
# only choosing a name. The seed is saved with the game. At each start of
# the game (load screen), the maps on disk are matched with the save: the
# maps of a game left without saving are deleted, or the saved world is drawn
# again from its seed if the save has one. The world's Town Map region (its
# lines and its image) is put back as it was before, and the plans exported
# for the abandoned world are deleted.
#===============================================================================
module MapProceduralGenerator
  module_function

  # { path:, seed:, town_map:, image:, start: } of the world on disk if a new
  # game drew it, else nil. town_map, image: the region's lines and image file
  # before the first game world (nil = none).
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
      remove_world(world)
      forget_game_world
    end
  end

  # Shows a message on a black screen while the block runs (the window would
  # stay blank otherwise), then puts the PBS files written meanwhile just
  # before their compiled data: Essentials recompiles everything at the next
  # start when a PBS file is as recent as its data (same second).
  def with_busy_screen
    viewport = Viewport.new(0, 0, Graphics.width, Graphics.height)
    viewport.z = 999_999
    sprite = BitmapSprite.new(Graphics.width, Graphics.height, viewport)
    sprite.bitmap.fill_rect(0, 0, Graphics.width, Graphics.height, Color.new(0, 0, 0))
    pbSetSystemFont(sprite.bitmap)
    pbDrawTextPositions(sprite.bitmap, [[_INTL("Le monde se prépare..."), Graphics.width / 2, (Graphics.height / 2) - 16,
                                         :center, Color.new(248, 248, 248), Color.new(72, 72, 72)]])
    @busy = true
    Graphics.update
    return yield
  ensure
    @busy = false
    sprite&.dispose
    viewport&.dispose
    settle_pbs_times
  end

  # Lets the window refresh during a long generation.
  def busy_update
    Graphics.update if @busy
  end

  def settle_pbs_times
    time = Time.now - 5
    Dir.glob("PBS/*.txt").each do |file|
      File.utime(time, time, file) if File.mtime(file) > time
    end
  end

  # prune: also deletes the maps of the unsaved world that this one doesn't
  # have (more caves...). Returns the world's start, nil if it failed.
  def draw_game_world(path, seed, prune: false)
    return with_busy_screen { draw_game_world_now(path, seed, prune) }
  end

  def draw_game_world_now(path, seed, prune)
    # The world rewrites its Town Map region: its lines from before the first
    # game world are kept, and put back before each new world is drawn
    world = load_world(path)
    previous = game_world
    if previous
      town_map, image = previous[:town_map], previous[:image]
      restore_town_map(world.region, town_map)
      delete_exports(previous[:path], previous[:seed]) if previous[:seed] != seed
    else
      town_map = town_map_section(world.region)
      file = MapGenerator.region_image_path(world)
      image = File.exist?(file) ? File.binread(file) : nil
    end
    begin
      _export, start = generate_world_maps(path, seed, quiet: true, prune: prune)
    rescue Error, MapGenerator::Error => e
      pbMessage(_INTL("Le monde n'a pas pu être généré : {1}", e.message))
      return nil
    end
    $game_temp.map_infos = nil if $game_temp
    save_data({ path: path, seed: seed, town_map: town_map, image: image, start: start }, GAME_WORLD_FILE)
    return start
  end

  # Deletes every map made for this game world, its exported plans, and puts
  # its Town Map region (lines and image) back.
  def remove_world(state)
    with_busy_screen { remove_world_now(state) }
  end

  def remove_world_now(state)
    path = state[:path]
    remove_maps(read_world_maps(path).values, compile: false)
    delete_file(world_maps_path(path))
    delete_exports(path, state[:seed])
    world = load_world(path)
    restore_town_map(world.region, state[:town_map])
    restore_region_image(MapGenerator.region_image_path(world), state[:image])
    MapGenerator.compile_world_pbs
  end

  # Plans exported for that seed (world, encounters).
  def delete_exports(path, seed)
    world_plan = export_path(path, seed)
    [world_plan, world_plan.sub(/\.txt\z/, "_rencontres.txt")].each { |file| delete_file(file) }
  end

  # Writes the region image back (nil = there was none).
  def restore_region_image(file, image)
    if image
      File.binwrite(file, image)
    else
      delete_file(file)
    end
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

# Name entry once the map is on screen (character 1, as in the intro). Not in
# :on_frame_update: it already runs while the map scene is being set up, before
# the screen transition, so the name screen would stay invisible.
class Scene_Map
  alias_method :__mapproc_update, :update

  def update
    if $game_temp.mapproc_name_entry && !pbMapInterpreterRunning?
      $game_temp.mapproc_name_entry = false
      pbTrainerName
    end
    __mapproc_update
  end
end

class PokemonLoadScreen
  alias_method :__mapproc_initialize, :initialize

  def initialize(scene)
    __mapproc_initialize(scene)
    MapProceduralGenerator.sync_game_world(@save_data[:mapproc_world])
  end
end
