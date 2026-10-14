#===============================================================================
# Nuzlocke - Save data
#===============================================================================
module Nuzlocke
  class Data
    attr_accessor :active, :hardcore, :chosen
    attr_reader   :used_zones, :graveyard_boxes

    def initialize
      @active          = false
      @hardcore        = false
      @chosen          = false
      @used_zones      = []
      @graveyard_boxes = []
    end

    def zone_used?(zone)
      @used_zones.include?(zone)
    end

    def use_zone(zone)
      @used_zones.push(zone) if !zone_used?(zone)
    end
  end

  module_function

  def data
    $nuzlocke ||= Data.new
  end

  def active?
    data.active
  end

  def hardcore?
    active? && data.hardcore
  end

  def current_zone
    ZONE_GROUPS[$game_map.map_id] || $game_map.map_id
  end
end

SaveData.register(:nuzlocke) do
  save_value { $nuzlocke }
  load_value { |value| $nuzlocke = value }
  new_game_value { Nuzlocke::Data.new }
end
