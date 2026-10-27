#===============================================================================
# Online - Save data
# A multiplayer game keeps its room in the save; a solo game has none.
#===============================================================================
module Online
  class Data
    attr_reader :code, :you, :host, :rules, :seed
    attr_accessor :rules_applied

    # room: the room as the bridge describes it (Hash with string keys).
    def initialize(room)
      @code  = room["code"]
      @you   = room["you"]
      @host  = room["host"]
      @rules = room["rules"]
      @seed  = room["seed"]
      @rules_applied = false
    end
  end

  module_function

  def data
    $online
  end

  def multi?
    !$online.nil?
  end
end

SaveData.register(:online) do
  save_value { $online }
  load_value { |value| $online = value }
  new_game_value { nil }
end
