#===============================================================================
# WorldEvents - The Family's casinos
# A croupier by a street in CASINO_CHANCE % of the towns but the first (at
# least one per world), after every other event so that no one else moves.
# Talking to him runs FamilyCasino.croupier (FamilyCasino plugin). Plain Ruby.
#===============================================================================
module WorldEvents
  module_function

  def casino_events(result, atlas, plans, rng)
    towns = result.places.select { |wp, *| wp.kind == "ville" }.map(&:first).sort_by(&:index)
    towns = towns.reject { |town| town.name == atlas[:start] || !atlas[:maps][town.name] }
    chosen = towns.select { rng.rand(100) < CASINO_CHANCE }
    chosen = [towns.sample(random: rng)].compact if chosen.empty?
    chosen.each do |town|
      cell = item_cell(atlas[:maps][town.name], npc_cells(atlas[:maps][town.name], rng), plans[town.name])
      next if !cell
      x, y, facing = cell
      add(plans, town.name, "Npc", "Croupier", x, y, ["Graphic", CROUPIER_GRAPHIC], ["Facing", facing],
          ["Script", "FamilyCasino.croupier"])
    end
  end
end
