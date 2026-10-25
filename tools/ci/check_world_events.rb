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
%w[001_Settings 002_World 003_Trainers 004_Gyms].each { |f| require File.join(ROOT, "Plugins", "WorldEvents", f) }
M = MapProceduralGenerator
E = ProceduralEncounters
W = WorldEvents
# WORLD_SEEDS=20 or WORLD_SEEDS=6..8 to try others locally
WORLD_SEEDS = (ENV["WORLD_SEEDS"] || "3").then { |s| s.include?("..") ? Range.new(*s.split("..").map(&:to_i)) : 1..s.to_i }

# Tables with their data, to read the tiles of the demo maps
class Table
  def self._load(data)
    table = allocate
    _dim, x, y, z, size = data.unpack("V5")
    table.instance_variable_set(:@xsize, x)
    table.instance_variable_set(:@ysize, y)
    table.instance_variable_set(:@zsize, z)
    table.instance_variable_set(:@data, data[20, size * 2].unpack("s<*"))
    return table
  end

  def [](x, y = 0, z = 0) = @data[x + (y * @xsize) + (z * @xsize * @ysize)]
end

TILESETS = load_rxdata(File.join(ROOT, "Data", "Tilesets.rxdata"))
# Cells walkable on a demo map: PASSABLE[id][y][x] (tiles only, as RMXP
# reads them: from the top layer down to the first one under the hero)
PASSABLE = Hash.new do |grids, id|
  map = load_rxdata(File.join(ROOT, "Data", format("Map%03d.rxdata", id)))
  tileset = TILESETS[map.instance_variable_get(:@tileset_id)]
  passages = tileset.passages
  priorities = tileset.instance_variable_get(:@priorities)
  data = map.instance_variable_get(:@data)
  grids[id] = Array.new(data.ysize) do |y|
    Array.new(data.xsize) do |x|
      2.downto(0).each_with_object([true]) do |z, ok|
        tile = data[x, y, z]
        next if !tile || tile == 0
        if passages[tile] & 0x0f == 0x0f
          ok[0] = false
          break ok
        end
        break ok if priorities[tile] == 0
      end[0]
    end
  end
end

# Cells reached from start on that grid without stepping on blocked.
def reach(grid, start, blocked)
  seen = { start => true }
  queue = [start]
  until queue.empty?
    x, y = queue.shift
    [[0, -1], [1, 0], [0, 1], [-1, 0]].each do |dx, dy|
      cell = [x + dx, y + dy]
      next if seen[cell] || blocked.include?(cell) || cell.min < 0 || !grid[cell[1]]&.[](cell[0])
      seen[cell] = true
      queue.push(cell)
    end
  end
  return seen
end

# Every gym has its lieutenant (seal in the order of the gyms, a useful TM of
# his type never given twice, the level cap of his seal, types all
# different) and 2 to 4 members; the lieutenant is reached with the members
# in place, and never without crossing a member's sight.
def check_gyms(atlas, plans, leaders, tms)
  types = leaders.map { |l| l[:type] }
  raise MapEvents::Error, "deux lieutenants du même type" if types.uniq.length != types.length
  given = leaders.filter_map { |l| l[:tm]&.first }
  raise MapEvents::Error, "CT donnée deux fois : #{given.join(', ')}" if given.uniq.length != given.length
  tops = leaders.map { |l| l[:team].map(&:last).max }
  raise MapEvents::Error, "lieutenants pas de plus en plus forts : #{tops.join(', ')}" if tops != tops.sort
  atlas[:gyms].each_with_index do |town, i|
    map, spots = atlas[:maps].find { |_name, m| m[:building] == "arene" && m[:owner] == town }
    raise MapEvents::Error, "#{town} : pas d'intérieur d'arène" if !map
    events = plans[map]&.events || []
    leader = events.find { |e| e.label == "Lieutenant" }
    raise MapEvents::Error, "#{map} : pas de lieutenant" if !leader
    raise MapEvents::Error, "#{map} : sceau #{leader.value('Badge')} au lieu de #{i + 1}" if leader.value("Badge").to_i != i + 1
    drawn = leaders.find { |l| l[:map] == map }
    raise MapEvents::Error, "#{map} : niveau #{tops[leaders.index(drawn)]} au lieu du plafond #{E::CAPS[i]}" if tops[leaders.index(drawn)] != E::CAPS[i]
    tm = tms.find { |item, *| item.to_s == leader.value("Gift") }
    if !tm || !W.useful_tms(tms, drawn[:type]).include?(tm)
      raise MapEvents::Error, "#{map} : CT #{leader.value('Gift')} absente ou inutile pour le type #{drawn[:type]}"
    end
    members = events.select { |e| e.kind == :trainer && e.label.start_with?("Membre") }
    raise MapEvents::Error, "#{map} : #{members.length} membres" if !W::GYM_MEMBERS.include?(members.length)
    grid = PASSABLE[spots[:template]]
    target = [leader.x, leader.y + 1]
    standing = events.map { |e| [e.x, e.y] }
    raise MapEvents::Error, "#{map} : le lieutenant est hors d'atteinte" if !reach(grid, spots[:arrival], standing)[target]
    seen = members.flat_map do |e|
      dx, dy = W::STEPS[e.value("Facing")]
      (1..e.value("Sight").to_i).map { |k| [e.x + (dx * k), e.y + (dy * k)] }.take_while { |x, y| grid[y]&.[](x) }
    end
    if reach(grid, spots[:arrival], standing + seen)[target]
      raise MapEvents::Error, "#{map} : on atteint le lieutenant sans passer devant un membre"
    end
  end
end

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
      next if !zone   # A gym's (check_gyms)
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
(W::TRAINER_TYPES.values.flatten + W::COUSIN_TYPES + W::LEADER_TYPES).uniq.each do |type|
  CI.error(settings, nil, "TRAINER_TYPES : type #{type} absent de trainer_types.txt") && next if !ttypes.include?(type.to_s)
  female = W::FEMALE_TYPES.include?(type)
  CI.error(settings, nil, "FEMALE_TYPES : #{type} est #{genders[type.to_s]}") if female != (genders[type.to_s] == "Female")
  %W[Graphics/Trainers/#{type}.png Graphics/Characters/trainer_#{type}.png].each do |file|
    CI.error(settings, nil, "#{type} : #{file} absent") if !File.exist?(File.join(ROOT, file))
  end
end
roster = E.load_species(ROOT)
# [[item, move, type, power, status?]] of every TM, from the PBS files
moves = CI.read_text(File.join(ROOT, "PBS", "moves.txt")).split(/^\[/).drop(1).to_h do |sec|
  [sec[/\A(\w+)/, 1].to_sym, [sec[/^Type\s*=\s*(\w+)/, 1]&.to_sym, sec[/^Power\s*=\s*(\d+)/, 1].to_i, sec[/^Category\s*=\s*Status/] ? true : false]]
end
tms = CI.read_text(File.join(ROOT, "PBS", "items.txt")).split(/^\[/).drop(1).filter_map do |sec|
  move = sec[/^Move\s*=\s*(\w+)/, 1]&.to_sym
  next if !move || !moves[move] || sec !~ /^FieldUse\s*=\s*(TM|HM|TR)\b/
  [sec[/\A(\w+)/, 1].to_sym, move, *moves[move]]
end
W::TM_STATUS.each { |move| CI.error(settings, nil, "TM_STATUS : capacité #{move} absente de moves.txt") if !moves[move] }
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
    args = { zones: zones, encounters: generated, species: roster, tms: tms, caps: E::CAPS }
    events = W.world_events(result, seed, **args)
    if W.world_events(result, seed, **args) != events
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
      check_gyms(atlas, plans, events[:leaders], tms)
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
