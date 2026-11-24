#===============================================================================
# WorldEvents - The Family's usurers
# One in each town but the first (the player has no money to owe there yet),
# by a street, after every other event so that no one else moves. Talking to
# him runs FamilyDebt.usurer (FamilyDebt plugin). Plain Ruby.
#===============================================================================
module WorldEvents
  module_function

  def usurer_events(result, atlas, plans, rng)
    towns = result.places.select { |wp, *| wp.kind == "ville" }.map(&:first).sort_by(&:index)
    towns.each do |town|
      next if town.name == atlas[:start] || !atlas[:maps][town.name]
      cell = item_cell(atlas[:maps][town.name], npc_cells(atlas[:maps][town.name], rng), plans[town.name])
      next if !cell
      x, y, facing = cell
      add(plans, town.name, "Npc", "Usurier", x, y, ["Graphic", USURER_GRAPHIC], ["Facing", facing],
          ["Script", "FamilyDebt.usurer"])
    end
  end
end
