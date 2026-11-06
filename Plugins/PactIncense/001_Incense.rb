#===============================================================================
# PactIncense - The next wild encounter is a Pokémon the player can catch
#===============================================================================
# The Pact Incense (#160) only chooses among the Pokémon already in the map's
# table for the current terrain, with their weights and levels: it never adds
# one. Catchable means allowed by Monotype (the imposed type, or gets it by
# evolving) and by Nuzlocke (free zone, not a duplicate), when they are active.
module PactIncense
  ITEM = :PACTINCENSE

  module_function

  def active?
    $PokemonGlobal.pact_incense
  end

  def catchable_species?(species)
    return false if defined?(Monotype) && Monotype.active? && !Monotype.species_eligible?(species)
    if defined?(Nuzlocke) && Nuzlocke.active?
      return false if Nuzlocke.data.zone_used?(Nuzlocke.current_zone)
      return false if Nuzlocke.duplicate?(species)
    end
    return true
  end

  # Entries [chance, species, min level, max level] of that table that can be caught.
  def catchable_entries(enc_type)
    return [] if !enc_type
    return $PokemonEncounters.table(enc_type).select { |enc| catchable_species?(enc[1]) }
  end

  # The encounter types of this map at this time of day (land, cave, water).
  def map_types
    time = pbGetTimeNow
    return %i[Land Cave Water].filter_map { |base| $PokemonEncounters.find_valid_encounter_type_for_time(base, time) }
  end

  # [species, level] among the catchable entries, by their weights.
  def choose(enc_type)
    list = catchable_entries(enc_type)
    return nil if list.empty?
    pick = rand(list.sum { |enc| enc[0] })
    enc = list.find { |chance, *| (pick -= chance) < 0 }
    return [enc[1], rand(enc[2]..enc[3])]
  end

  def use
    if active?
      pbMessage(_INTL("L'Encens du Pacte agit déjà."))
      return false
    end
    if map_types.none? { |enc_type| !catchable_entries(enc_type).empty? }
      pbMessage(_INTL("Aucun Pokémon d'ici ne peut vous être destiné. L'encens reste dans le Sac."))
      return false
    end
    pbUseItemMessage(ITEM)
    pbMessage(_INTL("Une fumée lourde s'élève. Le prochain Pokémon sauvage pourra être capturé."))
    $PokemonGlobal.pact_incense = true
    return true
  end
end

class PokemonGlobalMetadata
  attr_writer :pact_incense

  def pact_incense
    @pact_incense ||= false
    return @pact_incense
  end
end

# The species the incense chose for the encounter being set up.
class Game_Temp
  attr_accessor :pact_incense_species
end

class PokemonEncounters
  # The encounter list of that type on the current map (empty if none).
  def table(enc_type)
    return @encounter_tables[enc_type] || []
  end
end

ItemHandlers::UseInField.add(:PACTINCENSE, proc { |_item|
  next PactIncense.use
})

# Overworld encounters (grass, cave, water, fishing, Sweet Scent...): the
# incense replaces the species drawn when the table has a catchable entry,
# and the battle stays single. Otherwise it waits for the next encounter. It
# is spent once the Pokémon is created: a Repel can still cancel the encounter.
EventHandlers.add(:on_wild_species_chosen, :pact_incense,
  proc { |encounter|
    next if !encounter || !PactIncense.active? || $game_temp.roamer_index_for_encounter
    chosen = PactIncense.choose($game_temp.encounter_type)
    next if !chosen
    encounter[0] = chosen[0]
    encounter[1] = chosen[1]
    $game_temp.pact_incense_species = chosen[0]
    $game_temp.force_single_battle = true
  }
)

EventHandlers.add(:on_wild_pokemon_created, :pact_incense,
  proc { |pkmn|
    next if !$game_temp.pact_incense_species || pkmn.species != $game_temp.pact_incense_species
    $game_temp.pact_incense_species = nil
    $PokemonGlobal.pact_incense = false
  }
)
