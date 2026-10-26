#===============================================================================
# Monotype - Save data and type rules
#===============================================================================
module Monotype
  class Data
    # starters: the species offered, drawn once per game.
    attr_accessor :active, :chosen, :type, :starters, :starter_given

    def initialize
      @active        = false
      @chosen        = false
      @type          = nil
      @starters      = nil
      @starter_given = false
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

  # Party and PC rule: same as the capture rule.
  def usable?(pkmn)
    catchable?(pkmn)
  end

  # Highest base stat total among the final evolutions of the species.
  def final_stats(species)
    sp = GameData::Species.get(species)
    evos = sp.get_evolutions(true)
    return sp.base_stats.values.sum if evos.empty?
    evos.map { |evo| final_stats(evo[0]) }.max
  end

  # Base forms of the roster (their prevolution isn't in it) that respect the
  # rule and evolve into a Pokémon of the roster, pseudo-legendaries excluded.
  def starter_pool
    ROSTER.select do |species|
      sp = GameData::Species.get(species)
      prevo = sp.get_previous_species
      (prevo == species || !ROSTER.include?(prevo)) && species_eligible?(species) &&
        sp.get_evolutions(true).any? { |evo| ROSTER.include?(evo[0]) } &&
        final_stats(species) <= STARTER_MAX_FINAL_STATS
    end
  end
end

SaveData.register(:monotype) do
  save_value { $monotype }
  load_value { |value| $monotype = value }
  new_game_value { Monotype::Data.new }
end
