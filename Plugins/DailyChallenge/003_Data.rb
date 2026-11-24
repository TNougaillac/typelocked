#===============================================================================
# DailyChallenge - Save data and best scores
# $daily_challenge: the day of this game's challenge ("2026-11-02"), nil for a
# game with a random seed. The best game of each day (a RunHistory entry) is
# kept in FILE_NAME, outside the save.
#===============================================================================
module DailyChallenge
  module_function

  # Day chosen on the title screen, taken by the new game's save data.
  def pending=(date)
    @pending = date
  end

  def take_pending
    date = @pending
    @pending = nil
    return date
  end

  def active?
    return !$daily_challenge.nil?
  end

  def file
    dir = System.data_directory
    return File.directory?(dir) ? File.join(dir, FILE_NAME) : FILE_NAME
  end

  # { date => RunHistory::Entry }, the best game of each day.
  def bests
    return {} if !File.exist?(file)
    data = File.open(file, "rb") { |f| Marshal.load(f) }
    return data.is_a?(Hash) ? data : {}
  rescue StandardError
    return {}
  end

  def write(bests)
    kept = bests.sort_by { |date, _entry| date }.last(DAYS_KEPT).to_h
    File.open(file, "wb") { |f| Marshal.dump(kept, f) }
  rescue StandardError => e
    echoln("DailyChallenge : écriture impossible (#{e.message})")
  end

  # [date, entry] of the days kept, the most recent first.
  def best_days
    return bests.sort_by { |date, _entry| date }.reverse
  end

  # After RunHistory recorded this game: it becomes its day's best if it
  # scores more than the day's best (or is that game).
  def keep_best
    return if !active? || !$run_history_id
    entry = RunHistory.entries.find { |e| e.id == $run_history_id }
    return if !entry
    list = bests
    old = list[$daily_challenge]
    return if old && old.id != entry.id && old.score.to_i >= entry.score.to_i
    list[$daily_challenge] = entry
    write(list)
  end

  # Version of the world generator: the same day gives the same world only
  # with the same version.
  def generator_version
    return PluginManager.version("MapProceduralGenerator") || "?"
  end
end

SaveData.register(:daily_challenge) do
  save_value { $daily_challenge }
  load_value { |value| $daily_challenge = value }
  new_game_value { DailyChallenge.take_pending }
end
