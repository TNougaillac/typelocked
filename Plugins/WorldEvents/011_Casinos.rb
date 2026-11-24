#===============================================================================
# WorldEvents - The Family's casinos
# CASINOS croupiers per world (1 or 2), each by a street of a different town
# (never the first), after every other event so that no one else moves.
# Talking to him runs FamilyCasino.croupier (FamilyCasino plugin). Plain Ruby.
#===============================================================================
module WorldEvents
  module_function

  def casino_events(result, atlas, plans, rng)
    towns = result.places.select { |wp, *| wp.kind == "ville" }.map(&:first).sort_by(&:index)
    towns = towns.reject { |town| town.name == atlas[:start] || !atlas[:maps][town.name] }
    towns.sample(rng.rand(CASINOS), random: rng).each do |town|
      cell = item_cell(atlas[:maps][town.name], npc_cells(atlas[:maps][town.name], rng), plans[town.name])
      next if !cell
      x, y, facing = cell
      add(plans, town.name, "Npc", "Croupier", x, y, ["Graphic", CROUPIER_GRAPHIC], ["Facing", facing],
          ["Script", "FamilyCasino.croupier"])
    end
  end
end
