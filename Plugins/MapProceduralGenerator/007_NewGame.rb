#===============================================================================
# MapProceduralGenerator - A new world for each new game
# Starting a new game draws the world of NEW_GAME_WORLD with a random seed
# (maps only, no events) and the game starts in its first town, the player
# only choosing a name. The world is drawn in a thread while the intro plays
# (IntroScene), then written once it is over, before the first map shows
# (with the busy screen only if it is not drawn yet). The seed is saved with
# the game. At each start of
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

  # Starts drawing the world of a new game in a thread (plain Ruby, nothing
  # written yet): { path:, seed:, thread: }, nil if there is no world.
  def begin_new_game_world
    return nil if !NEW_GAME_WORLD
    path = File.join(FOLDER, NEW_GAME_WORLD)
    return nil if !File.exist?(path)
    seed = rand(1_000_000)
    thread = Thread.new { compute_world(path, seed) }
    thread.report_on_exception = false
    # Short time slices: the intro keeps its frame rate
    thread.priority = WORLD_THREAD_PRIORITY
    return { path: path, seed: seed, thread: thread }
  end

  # Once the intro is over, before the first map shows: writes the world begun
  # by begin_new_game_world and puts the player at its start. Without a world
  # (drawing failed), the game stays on the editor's start map.
  def enter_new_game_world
    pending = $game_temp.mapproc_pending
    $game_temp.mapproc_pending = nil
    start = draw_game_world(pending[:path], pending[:seed], thread: pending[:thread])
    if !start
      $game_temp.mapproc_name_entry = false
      return
    end
    $mapproc_world = pending[:seed]
    map_id, x, y = start
    $map_factory = PokemonMapFactory.new(map_id)
    $game_player.moveto(x, y)
    $game_player.refresh
    $PokemonEncounters.setup(map_id)
    $game_map.autoplay
    $game_map.update
  end

  # What the thread drew, waiting for it with the window alive; nil if it
  # failed (the world is then drawn here, as without a thread).
  def thread_world(thread)
    thread.priority = 0
    Graphics.update until thread.join(0.05)
    return thread.value
  rescue StandardError => e
    Console.echoln_li(_INTL("Monde : tirage pendant l'intro raté ({1}), tirage maintenant", e.message))
    return nil
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

  # When the game closes: the map files of a world that no save holds are
  # deleted at once (they no longer pile up in Data/), and their PBS lines. The
  # rest (compiled data, Town Map) is left to sync_game_world at the next
  # start: it needs the compiler, which refreshes the window, gone by then.
  def remove_unsaved_maps
    world = game_world
    return if !world || saved_world_seed
    ids = read_world_maps(world[:path]).values
    return if ids.empty?
    infos = load_data("Data/MapInfos.rxdata")
    names = ids.filter_map { |id| infos[id]&.name }
    ids.each do |id|
      infos.delete(id)
      delete_file(sprintf("Data/Map%03d.rxdata", id))
    end
    save_data(infos, "Data/MapInfos.rxdata")
    # Their PBS lines too, or a compile at the next start (Ctrl held) warns
    # about the missing maps
    pbs = [MapGenerator::CONNECTIONS_PBS, MapGenerator::MAP_METADATA_PBS, MapGenerator::TOWN_MAP_PBS]
    keeping_times(pbs) { remove_map_lines(ids, names) }
  rescue StandardError => e
    echoln("MapProc : nettoyage à la fermeture impossible (#{e.message})")
  end

  # Seed of the world in the save file, nil if none (no save, or no world).
  def saved_world_seed
    return nil if !SaveData.exists?
    # Read only: read_from_file could rewrite the save (conversions)
    data = SaveData.get_data_from_file(SaveData::FILE_PATH)
    return data.is_a?(Hash) ? data[:mapproc_world] : nil
  rescue StandardError
    return nil
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
  # have (more caves...); thread: the thread already drawing it (see
  # begin_new_game_world). Returns the world's start, nil if it failed.
  def draw_game_world(path, seed, prune: false, thread: nil)
    return with_busy_screen do
      computed = thread_world(thread) if thread
      draw_game_world_now(path, seed, prune, computed)
    end
  end

  def draw_game_world_now(path, seed, prune, computed = nil)
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
      _export, start = generate_world_maps(path, seed, quiet: true, prune: prune, computed: computed)
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
    forget_atlas
    delete_exports(path, state[:seed])
    world = load_world(path)
    restore_town_map(world.region, state[:town_map])
    restore_region_image(MapGenerator.region_image_path(world), state[:image])
    MapGenerator.compile_world_pbs
  end

  # Plans exported for that seed (world, encounters, inventory).
  def delete_exports(path, seed)
    world_plan = export_path(path, seed)
    %w[_rencontres _inventaire].each { |suffix| delete_file(world_plan.sub(/\.txt\z/, "#{suffix}.txt")) }
    delete_file(world_plan)
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
  # files (connections, map metadata, Town Map points).
  def remove_maps(ids, compile: true)
    return if ids.empty?
    infos = load_data("Data/MapInfos.rxdata")
    names = ids.filter_map { |id| infos[id]&.name }
    ids.each do |id|
      # Not in the map tree: its file went when the game closed (remove_unsaved_maps)
      next if !infos.delete(id)
      delete_file(sprintf("Data/Map%03d.rxdata", id))
    end
    save_data(infos, "Data/MapInfos.rxdata")
    $game_temp.map_infos = nil if $game_temp
    remove_map_lines(ids, names)
    MapGenerator.compile_world_pbs if compile
  end

  # Lines of these maps in the PBS files (connections, map metadata, Town Map
  # points named after them).
  def remove_map_lines(ids, names)
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
  end

  # Runs the block, then puts these files' times back: the compiler sees no
  # change at the next start, and sync_game_world compiles them later.
  def keeping_times(files)
    times = files.to_h { |f| [f, File.mtime(f)] if File.exist?(f) }.compact
    yield
    times.each { |f, t| File.utime(t, t, f) }
  end
end

# Closing the window ends the scripts with SystemExit: the at_exit blocks run.
at_exit { MapProceduralGenerator.remove_unsaved_maps }

SaveData.register(:mapproc_world) do
  save_value { $mapproc_world }
  load_value { |value| $mapproc_world = value }
  new_game_value { nil }
end

module Game
  class << self
    alias_method :__mapproc_start_new, :start_new

    # The world starts drawing in a thread, and the game on the editor's start
    # map; the player is moved to the world's first town once the intro is
    # over (Scene_Map#main below), without the intro of the editor's start
    # map: the player only chooses a name (see below).
    def start_new
      pending = MapProceduralGenerator.begin_new_game_world
      __mapproc_start_new
      $mapproc_world = nil
      $game_temp.mapproc_pending = pending
      $game_temp.mapproc_name_entry = !pending.nil?
    end
  end
end

class Game_Temp
  # The player of a new game in a generated world still has to be named.
  attr_accessor :mapproc_name_entry
  # The world of a new game being drawn ({ path:, seed:, thread: })
  attr_accessor :mapproc_pending
end

# The world of a new game is written before the map scene draws anything (its
# map events don't run before update). Messages must not update the scene.
class Scene_Map
  alias_method :__mapproc_main, :main

  def main
    if $game_temp.mapproc_pending
      scene = $scene
      $scene = nil
      begin
        MapProceduralGenerator.enter_new_game_world
      ensure
        $scene = scene
      end
    end
    __mapproc_main
  end
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
