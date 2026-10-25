#===============================================================================
# RunHistory - The games and their file
# One entry per game (its id is drawn at the new game and saved with it),
# updated at each save while it is going on, frozen once it ends.
#===============================================================================
module RunHistory
  Entry = Struct.new(:id, :seed, :region, :type, :outcome, :seals, :place, :team, :play_time,
                     :started, :updated)
  # A Pokémon of the team: dead (Nuzlocke) or not.
  Member = Struct.new(:species, :name, :level, :dead)

  module_function

  def file
    dir = System.data_directory
    return File.directory?(dir) ? File.join(dir, FILE_NAME) : FILE_NAME
  end

  # [Entry], the most recent first.
  def entries
    return [] if !File.exist?(file)
    return File.open(file, "rb") { |f| Marshal.load(f) }
  rescue StandardError
    return []
  end

  def write(list)
    File.open(file, "wb") { |f| Marshal.dump(list.first(SIZE), f) }
  rescue StandardError => e
    echoln("RunHistory : écriture impossible (#{e.message})")
  end

  # Records the current game with that outcome (team: the Pokémon to keep,
  # the party by default); an ended game is not changed any more.
  def record(outcome, team = $player.party)
    return if !$run_history_id
    list = entries
    old = list.find { |e| e.id == $run_history_id }
    return if old && old.outcome != :playing
    list.delete(old)
    list.unshift(snapshot(outcome, team, old&.started || Time.now))
    write(list)
  end

  # Turns a game still going on into an abandon (its save is overwritten).
  def abandon(id)
    list = entries
    entry = list.find { |e| e.id == id && e.outcome == :playing }
    return if !entry
    entry.outcome = :abandon
    write(list)
  end

  def snapshot(outcome, team, started)
    members = team.map { |pkmn| Member.new(pkmn.species, pkmn.name, pkmn.level, pkmn.nuzlocke_dead? ? true : false) }
    return Entry.new($run_history_id, $mapproc_world, region_name, Monotype.data.type, outcome, $player.badge_count,
                     $game_map&.name, members, $stats.play_time.to_i, started, Time.now)
  end

  # The Town Map name of the region the player is in (nil: none).
  def region_name
    position = $game_map&.metadata&.town_map_position
    return position ? GameData::TownMap.try_get(position[0])&.name : nil
  end
end

SaveData.register(:run_history_id) do
  save_value { $run_history_id }
  load_value { |value| $run_history_id = value }
  new_game_value { rand(1 << 30) }
end
