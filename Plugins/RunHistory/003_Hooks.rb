#===============================================================================
# RunHistory - When a game is recorded
# At each save (going on); when the Nuzlocke run is lost (defeat, with the
# team before the last deaths were buried); when Arceus is beaten or caught
# (victory); a game still going on whose save is overwritten by another
# game's is an abandon.
#===============================================================================
module RunHistory
  module_function

  # Id of the game in the save file (nil: none, or saved before this plugin).
  def saved_id
    return nil if !SaveData.exists?
    data = SaveData.get_data_from_file(SaveData::FILE_PATH)
    return data.is_a?(Hash) ? data[:run_history_id] : nil
  rescue StandardError
    return nil
  end
end

module Game
  class << self
    alias_method :__run_history_save, :save

    def save(save_file = SaveData::FILE_PATH, safe: false)
      old = (save_file == SaveData::FILE_PATH) ? RunHistory.saved_id : nil
      saved = __run_history_save(save_file, safe: safe)
      if saved
        RunHistory.abandon(old) if old && old != $run_history_id
        RunHistory.record(:playing)
      end
      return saved
    end
  end
end

module Nuzlocke
  class << self
    alias_method :__run_history_bury_dead_party_members, :bury_dead_party_members

    def bury_dead_party_members
      team = $player.party.dup
      __run_history_bury_dead_party_members
      RunHistory.record(:defeat, team) if !data.active
    end
  end
end

module WorldEvents
  class << self
    alias_method :__run_history_arceus, :arceus

    def arceus(interpreter, level, switch)
      __run_history_arceus(interpreter, level, switch)
      RunHistory.record(:victory) if $game_switches[switch]
    end
  end
end
