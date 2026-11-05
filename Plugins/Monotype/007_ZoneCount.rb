#===============================================================================
# Monotype - Species of the type in the zone
# On entering a map that has wild encounters, a small window at the top right
# says how many species of the imposed type can be caught there (every
# encounter method: grass, cave, water, fishing...). Nothing more. Not shown
# once the Nuzlocke zone is used (its one capture is spent).
#===============================================================================
module Monotype
  module_function

  # Species of this map's encounters that can be caught with the type.
  def zone_species(map_id = $game_map.map_id)
    encounters = GameData::Encounter.get(map_id, $PokemonGlobal.encounter_version)
    return nil if !encounters || encounters.types.empty?
    species = encounters.types.values.flatten(1).map { |slot| slot[1] }.uniq
    return species.select do |id|
      sp = GameData::Species.try_get(id)
      sp && species_eligible?(sp.species, sp.form)
    end.map { |id| GameData::Species.get(id).species }.uniq
  end

  # The Nuzlocke is on and this zone's capture is spent.
  def zone_spent?
    return defined?(Nuzlocke) && Nuzlocke.active? && Nuzlocke.data.zone_used?(Nuzlocke.current_zone)
  end

  def zone_count_text
    return nil if zone_spent?
    count = zone_species&.length
    return nil if count.nil?
    return _INTL("Type {1} : aucun Pokémon ici", type_name) if count == 0
    return _INTL("Type {1} : {2} Pokémon ici", type_name, count)
  end
end

# The location signpost's window, at the top right.
class MonotypeZoneWindow < LocationWindow
  def initialize(text)
    super
    @window.x = Graphics.width - @window.width
  end
end

EventHandlers.add(:on_map_or_spriteset_change, :monotype_zone_count,
  proc { |scene, map_changed|
    next if !Monotype::SHOW_ZONE_COUNT || !map_changed || !scene&.spriteset || !Monotype.active?
    text = Monotype.zone_count_text
    scene.spriteset.addUserSprite(MonotypeZoneWindow.new(text)) if text
  }
)
