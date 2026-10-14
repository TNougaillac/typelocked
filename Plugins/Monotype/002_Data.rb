#===============================================================================
# Monotype - Save data and type rules
#===============================================================================
module Monotype
  class Data
    # grace: the starter stays usable until the first capture or the first gym.
    attr_accessor :active, :chosen, :type, :grace, :starter_claimed

    def initialize
      @active          = false
      @chosen          = false
      @type            = nil
      @grace           = true
      @starter_claimed = false
    end
  end

  @eligible_cache = {}

  module_function

  def data
    $monotype ||= Data.new
  end

  def active?
    data.active
  end

  def type_name
    GameData::Type.get(data.type).name
  end

  def available_types
    types = []
    GameData::Type.each { |t| types.push(t.id) if !t.pseudo_type && !EXCLUDED_TYPES.include?(t.id) }
    types
  end

  # The form has the type, or one of its later evolutions has it (prevolutions
  # don't count).
  def species_eligible?(species, form = 0)
    key = [data.type, species, form]
    return @eligible_cache[key] if @eligible_cache.key?(key)
    sp = GameData::Species.get_species_form(species, form)
    @eligible_cache[key] = sp.types.include?(data.type) ||
                           sp.get_evolutions(true).any? { |evo| species_eligible?(evo[0], form) }
  end

  def catchable?(pkmn)
    !active? || species_eligible?(pkmn.species, pkmn.form)
  end

  def usable?(pkmn)
    catchable?(pkmn) || (pkmn.monotype_starter && data.grace)
  end
end

class Pokemon
  attr_accessor :monotype_starter
end

SaveData.register(:monotype) do
  save_value { $monotype }
  load_value { |value| $monotype = value }
  new_game_value { Monotype::Data.new }
end
