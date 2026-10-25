#===============================================================================
# Draws the events of each MapProc world with a few seeds (plugin
# WorldEvents) and checks them: plans read by MapEvents, events on cells the
# player can reach and never in the way (exits, doors), the professor and the
# gate of the first town, the services of the Centres and shops, the
# trainers (teams, levels, sight), the same events for the same seed.
#===============================================================================
require_relative "lib/ci"

%w[001_Settings 002_Parser 003_Builder].each { |f| require File.join(ROOT, "Plugins", "MapGenerator", f) }
require_relative "lib/essentials"
Essentials.load_scripts("Overworld_RandomDungeons")
%w[001_Settings 002_Parser 003_Builder 004_World 006_Caves 008_Names 009_Atlas 010_CavePainter 011_Interiors].each { |f| require File.join(ROOT, "Plugins", "MapProceduralGenerator", f) }
%w[001_Settings 002_Parser].each { |f| require File.join(ROOT, "Plugins", "MapEvents", f) }
%w[001_Settings 002_Species 003_Tables 004_World].each { |f| require File.join(ROOT, "Plugins", "ProceduralEncounters", f) }
%w[001_Settings 002_World 003_Trainers].each { |f| require File.join(ROOT, "Plugins", "WorldEvents", f) }
M = MapProceduralGenerator
E = ProceduralEncounters
W = WorldEvents
# WORLD_SEEDS=20 or WORLD_SEEDS=6..8 to try others locally
WORLD_SEEDS = (ENV["WORLD_SEEDS"] || "3").then { |s| s.include?("..") ? Range.new(*s.split("..").map(&:to_i)) : 1..s.to_i }

# [width, height] of a demo map (the template of an interior)
SIZES = Hash.new do |sizes, id|
  map = load_rxdata(File.join(ROOT, "Data", format("Map%03d.rxdata", id)))
  sizes[id] = [map.instance_variable_get(:@width), map.instance_variable_get(:@height)]
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
  free = (spots[:street] || []) + (spots[:grass] || []) + (spots[:dead_ends] || []) + (spots[:floor] || []) +
         (spots[:nooks] || []).map { |x, y, *| [x, y] } + [spots[:professor]].compact
  blocked = W.blocked_cells(spots)
  plan.events.each do |entry|
    cell = [entry.x, entry.y]
    where = "[#{entry.kind.capitalize} #{entry.label}] en #{entry.x},#{entry.y}"
    next if gates.include?(cell) && entry.label.start_with?("Garde")
    raise MapEvents::Error, "#{where} : sur une sortie, une porte ou devant" if blocked.include?(cell)
    raise MapEvents::Error, "#{where} : case hors de l'inventaire (inaccessible ?)" if !free.include?(cell)
    next if entry.kind != :trainer
    # A trainer never sees an exit or a door
    dx, dy = W::STEPS[entry.value("Facing")]
    sight = (1..entry.value("Sight").to_i).map { |i| [entry.x + (dx * i), entry.y + (dy * i)] }
    raise MapEvents::Error, "#{where} : sa vue atteint une sortie ou une porte" if sight.any? { |c| blocked.include?(c) }
  end
end

# Every trainer has its team (PARTY_SIZES Pokémon of existing species, at
# most at the level cap of its seals), each type and name once; every route
# has trainers; the strongest trainer of each stretch is never weaker than
# the one of the stretch before.
def check_trainers(result, zones, plans, sections, species, ttypes)
  teams = {}
  sections.each do |text|
    head, *lines = text.split("\n")
    raise MapEvents::Error, "dresseur « #{head} » : en-tête attendu [TYPE,Nom,#{W::TRAINER_VERSION}]" unless head =~ /\A\[(\w+),([^,\]]+),(\d+)\]\z/
    key = [$1, $2]
    raise MapEvents::Error, "dresseur #{head} en double" if teams[key]
    raise MapEvents::Error, "dresseur #{head} : version #{$3} au lieu de #{W::TRAINER_VERSION}" if $3.to_i != W::TRAINER_VERSION
    raise MapEvents::Error, "dresseur #{head} : type inconnu" if !ttypes.include?($1)
    team = lines.filter_map { |l| [$1, $2.to_i] if l =~ /\APokemon = (\w+),(\d+)\z/ }
    team.each { |sp, _| raise MapEvents::Error, "dresseur #{head} : espèce #{sp} inconnue" if !species.include?(sp) }
    teams[key] = team
  end
  top = Hash.new(0)
  plans.each do |name, plan|
    trainers = plan.events.select { |e| e.kind == :trainer }
    zone = zones[name]
    trainers.each do |entry|
      team = teams.delete([entry.value("Type"), entry.value("Name")])
      where = "#{name} : [Trainer #{entry.label}]"
      raise MapEvents::Error, "#{where} : pas d'équipe dans trainers.txt" if !team
      raise MapEvents::Error, "#{where} : BattleID #{entry.value('BattleID')}" if entry.value("BattleID").to_i != W::TRAINER_VERSION
      sizes = W::PARTY_SIZES[[zone.seals, W::PARTY_SIZES.length - 1].min]
      raise MapEvents::Error, "#{where} : #{team.length} Pokémon (#{sizes} avec #{zone.seals} sceaux)" if !sizes.include?(team.length)
      highest = team.map(&:last).max
      cap = E::CAPS[zone.seals] || E::CAPS.last
      raise MapEvents::Error, "#{where} : niveau #{highest} au-dessus du plafond #{cap}" if highest > cap
      top[zone.seals] = [top[zone.seals], highest].max
    end
  end
  raise MapEvents::Error, "équipes sans dresseur : #{teams.keys.map { |k| k.join(',') }.join(' ; ')}" if !teams.empty?
  top.keys.sort.each_cons(2) do |a, b|
    raise MapEvents::Error, "dresseurs plus faibles avec #{b} sceaux (#{top[b]}) qu'avec #{a} (#{top[a]})" if top[b] < top[a]
  end
  result.places.each do |wp, *|
    next if wp.kind != "route" || plans[wp.name]&.events&.any? { |e| e.kind == :trainer }
    raise MapEvents::Error, "#{wp.name} : route sans dresseur"
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

# Every Pokémon Centre has its nurse, PC and healing machine, every shop its
# clerk of the Family.
def check_services(atlas, plans)
  atlas[:maps].each do |name, map|
    next if map[:kind] != "interieur"
    labels = plans[name]&.events&.map(&:label) || []
    case map[:building]
    when "centre"
      missing = W::CENTRE_LABELS - labels
      raise MapEvents::Error, "#{name} : Centre sans #{missing.join(', ')}" if !missing.empty?
    when "boutique"
      raise MapEvents::Error, "#{name} : boutique sans vendeur" if !labels.include?("Vendeur")
    end
  end
end

# The settings name events and items that exist.
settings = File.join(ROOT, "Plugins", "WorldEvents", "001_Settings.rb")
W::CENTRE_EVENTS.each do |template, events|
  CI.error(settings, nil, "CENTRE_EVENTS : la carte #{template} n'est pas un gabarit de Centre") if !M::INTERIORS["centre"].any? { |t, *| t == template }
  map_events = load_rxdata(File.join(ROOT, "Data", format("Map%03d.rxdata", template))).instance_variable_get(:@events)
  events.each do |id, x, y|
    event = map_events[id]
    next if event && [event.instance_variable_get(:@x), event.instance_variable_get(:@y)] == [x, y]
    CI.error(settings, nil, "CENTRE_EVENTS : pas d'événement #{id} en #{x},#{y} sur la carte #{template}")
  end
end
(M::INTERIORS["centre"].map(&:first) - W::CENTRE_EVENTS.keys).each { |t| CI.error(settings, nil, "CENTRE_EVENTS : gabarit #{t} absent") }
(M::INTERIORS["boutique"].map(&:first) - W::MART_CLERK.keys).each { |t| CI.error(settings, nil, "MART_CLERK : gabarit #{t} absent") }
items = CI.read_text(File.join(ROOT, "PBS", "items.txt")).scan(/^\[\s*(\w+)\s*\]/).flatten
species = CI.read_text(File.join(ROOT, "PBS", "pokemon.txt")).scan(/^\[\s*(\w+)\s*\]/).flatten
types_text = CI.read_text(File.join(ROOT, "PBS", "trainer_types.txt"))
ttypes = types_text.scan(/^\[\s*(\w+)\s*\]/).flatten
genders = types_text.split(/^\[/).drop(1).to_h { |sec| [sec[/\A(\w+)/, 1], sec[/^Gender\s*=\s*(\w+)/, 1]] }
(W::TRAINER_TYPES.values.flatten + W::COUSIN_TYPES).uniq.each do |type|
  CI.error(settings, nil, "TRAINER_TYPES : type #{type} absent de trainer_types.txt") && next if !ttypes.include?(type.to_s)
  female = W::FEMALE_TYPES.include?(type)
  CI.error(settings, nil, "FEMALE_TYPES : #{type} est #{genders[type.to_s]}") if female != (genders[type.to_s] == "Female")
  %W[Graphics/Trainers/#{type}.png Graphics/Characters/trainer_#{type}.png].each do |file|
    CI.error(settings, nil, "#{type} : #{file} absent") if !File.exist?(File.join(ROOT, file))
  end
end
roster = E.load_species(ROOT)
W::MART_STOCK.values.flatten.each { |item| CI.error(settings, nil, "MART_STOCK : objet #{item} absent de items.txt") if !items.include?(item.to_s) }

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
    zones = E.world_zones(result, E::CAPS)
    _lines, generated = E.world_encounters(result, roster, E::CAPS, seed)
    events = W.world_events(result, seed, zones: zones, encounters: generated)
    if W.world_events(result, seed, zones: zones, encounters: generated) != events
      CI.error(path, nil, "#{where} : la même graine donne d'autres événements")
    end
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
      check_services(atlas, plans)
      check_trainers(result, zones.to_h { |z| [z.name, z] }, plans, events[:trainers], species, ttypes)
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
