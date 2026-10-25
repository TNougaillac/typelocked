#===============================================================================
# Draws the events of each MapProc world with a few seeds (plugin
# WorldEvents) and checks them: plans read by MapEvents, events on cells the
# player can reach and never in the way (exits, doors), the professor and the
# gate of the first town, the same events for the same seed.
#===============================================================================
require_relative "lib/ci"

%w[001_Settings 002_Parser 003_Builder].each { |f| require File.join(ROOT, "Plugins", "MapGenerator", f) }
require_relative "lib/essentials"
Essentials.load_scripts("Overworld_RandomDungeons")
%w[001_Settings 002_Parser 003_Builder 004_World 006_Caves 008_Names 009_Atlas 010_CavePainter 011_Interiors].each { |f| require File.join(ROOT, "Plugins", "MapProceduralGenerator", f) }
%w[001_Settings 002_Parser].each { |f| require File.join(ROOT, "Plugins", "MapEvents", f) }
%w[001_Settings 002_World].each { |f| require File.join(ROOT, "Plugins", "WorldEvents", f) }
M = MapProceduralGenerator
W = WorldEvents
# WORLD_SEEDS=20 or WORLD_SEEDS=6..8 to try others locally
WORLD_SEEDS = (ENV["WORLD_SEEDS"] || "3").then { |s| s.include?("..") ? Range.new(*s.split("..").map(&:to_i)) : 1..s.to_i }

# [width, height] of a demo map (the template of an interior)
SIZES = Hash.new do |sizes, id|
  map = load_rxdata(File.join(ROOT, "Data", format("Map%03d.rxdata", id)))
  sizes[id] = [map.instance_variable_get(:@width), map.instance_variable_get(:@height)]
end

# Cells of each exit (a square as wide as a street).
def exit_cells(exits)
  width = M::STREET_WIDTH
  return exits.flat_map { |_side, x, y| (0...width).flat_map { |i| (0...width).map { |j| [x + i, y + j] } } }
end

# Raises unless every event of the plan stands where the player can reach it
# without being in the way.
def check_cells(plan, spots, gates)
  if spots[:kind] == "interieur"
    width, height = SIZES[spots[:template]]
    blocked = [spots[:arrival], *spots[:exits].map { |x, y, _owner| [x, y] }]
    plan.events.each do |entry|
      where = "[#{entry.kind.capitalize} #{entry.label}] en #{entry.x},#{entry.y}"
      raise MapEvents::Error, "#{where} : hors de l'intérieur (#{width}x#{height})" if entry.x >= width || entry.y >= height
      raise MapEvents::Error, "#{where} : sur l'arrivée ou la sortie" if blocked.include?([entry.x, entry.y])
    end
    return
  end
  free = (spots[:street] || []) + (spots[:grass] || []) + (spots[:dead_ends] || []) +
         (spots[:nooks] || []).map { |x, y, *| [x, y] } + [spots[:professor]].compact
  doors = (spots[:doors] || []).flat_map { |x, y, _kind| [[x, y], [x, y + 1]] }
  exits = exit_cells(spots[:exits] || [])
  plan.events.each do |entry|
    cell = [entry.x, entry.y]
    where = "[#{entry.kind.capitalize} #{entry.label}] en #{entry.x},#{entry.y}"
    next if gates.include?(cell) && entry.label.start_with?("Garde")
    raise MapEvents::Error, "#{where} : sur une porte ou devant" if doors.include?(cell)
    raise MapEvents::Error, "#{where} : sur une sortie" if exits.include?(cell)
    raise MapEvents::Error, "#{where} : case hors de l'inventaire (inaccessible ?)" if !free.include?(cell)
  end
end

# The professor (in the lab or outside, never both) and a gate on each exit
# of the first town, gone once the starter is chosen.
def check_start(atlas, plans)
  start = atlas[:start]
  spots = atlas[:maps][start]
  lab = atlas[:maps].find { |_name, map| map[:building] == M::LAB && map[:owner] == start }&.first
  professors = plans.select { |_name, plan| plan.events.any? { |e| e.label == "Professeur" } }.keys
  expected = atlas[:lab] ? lab : start
  raise MapEvents::Error, "professeur attendu sur #{expected}, trouvé sur #{professors.join(', ')}" if professors != [expected]
  if atlas[:lab]
    balls = plans[lab].events.count { |e| e.label.start_with?("Ball") && e.value("Script")[/starter_ball\(\d\)/] }
    raise MapEvents::Error, "#{lab} : #{balls} Poké Balls au lieu de #{W::LAB_BALLS.length}" if balls != W::LAB_BALLS.length
  end
  gates = plans[start].events.select { |e| e.label.start_with?("Garde") }
  W.gate_cells(spots[:exits]).each do |x, y|
    gate = gates.find { |e| [e.x, e.y] == [x, y] }
    raise MapEvents::Error, "#{start} : sortie #{x},#{y} sans garde" if !gate
    if gate.value("Trigger") != "contact" || gate.value("Hide") != "V#{W::STARTER_VARIABLE}>=1"
      raise MapEvents::Error, "#{start} : la garde #{x},#{y} doit se déclencher au contact et partir avec le starter"
    end
  end
end

folder = File.join(ROOT, M::FOLDER)
bricks = Dir.glob(File.join(folder, M::BRICK_FOLDER, "*.txt")).sort.map do |path|
  M.parse_brick(CI.read_text(path), File.basename(path))
end
count = 0
Dir.glob(File.join(folder, "*.txt")).sort.select { |path| M.world_file?(path) }.each do |path|
  world = M.parse_world(CI.read_text(path), File.basename(path))
  town, route = [world.town_file, world.route_file].map do |name|
    M.parse_place(CI.read_text(File.join(folder, name)), name)
  end
  WORLD_SEEDS.each do |seed|
    where = "#{File.basename(path)} (graine #{seed})"
    result = M.generate_world(world, town, route, bricks, seed)
    atlas = M.world_atlas(result)
    events = W.world_events(result, seed)
    CI.error(path, nil, "#{where} : la même graine donne d'autres événements") if W.world_events(result, seed) != events
    plans = {}
    events[:plans].each do |name, text|
      plans[name] = MapEvents.parse(text, "#{where}, #{name}")
      spots = atlas[:maps][name]
      raise MapEvents::Error, "#{name} : carte absente de l'inventaire" if !spots
      gates = (name == atlas[:start]) ? W.gate_cells(spots[:exits]) : []
      check_cells(plans[name], spots, gates)
    rescue MapEvents::Error => e
      CI.error(path, nil, "#{where} : #{e.message}")
    end
    begin
      check_start(atlas, plans)
    rescue MapEvents::Error => e
      CI.error(path, nil, "#{where} : #{e.message}")
    end
    count += 1
  rescue M::Error => e
    CI.error(path, nil, "#{where} : #{e.message}")
  end
end

puts "#{count} mondes, graines #{WORLD_SEEDS}"
CI.finish("Événements des mondes")
