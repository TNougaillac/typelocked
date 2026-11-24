#===============================================================================
# Draws the events of each MapProc world with a few seeds (plugin
# WorldEvents) and checks them: plans read by MapEvents, events on cells the
# player can reach and never in the way (exits, doors), the professor and the
# gate of the first town, the services of the Centres and shops, the
# trainers (teams, levels, sight), the guilds at their headquarters, the
# same events for the same seed.
#===============================================================================
require_relative "lib/ci"

%w[001_Settings 002_Parser 003_Builder].each { |f| require File.join(ROOT, "Plugins", "MapGenerator", f) }
require_relative "lib/essentials"
Essentials.load_scripts("Overworld_RandomDungeons")
%w[001_Settings 002_Parser 003_Builder 003_Builder_Bricks 003_Builder_Crossings 003_Builder_Relief 003_Builder_Sea 003_Builder_Streets 004_World 006_Caves 008_Names 009_Atlas 010_CavePainter 011_Interiors 013_Fillers].each { |f| require File.join(ROOT, "Plugins", "MapProceduralGenerator", f) }
%w[001_Settings 002_Parser].each { |f| require File.join(ROOT, "Plugins", "MapEvents", f) }
%w[001_Settings 002_Species 003_Tables 004_World].each { |f| require File.join(ROOT, "Plugins", "ProceduralEncounters", f) }
%w[001_Settings 002_Dialogues 003_World 004_Trainers 005_Gyms 006_Sets 007_Items 011_Guilds 012_ItemPool].each { |f| require File.join(ROOT, "Plugins", "WorldEvents", f) }
M = MapProceduralGenerator
M.check_plans = true   # plans made without text, fully validated (#345)
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
    if !tm || !W.useful_tms(tms, drawn[:type], drawn[:gym] - 1).include?(tm)
      raise MapEvents::Error, "#{map} : CT #{leader.value('Gift')} absente ou inutile pour le type #{drawn[:type]}"
    end
    members = events.select { |e| e.kind == :trainer && e.label.start_with?("Membre") }
    raise MapEvents::Error, "#{map} : #{members.length} membres" if !W::GYM_MEMBERS.include?(members.length)
    # A generated gym (#121): its floor, from its entry
    grid = spots[:template] ? PASSABLE[spots[:template]] : ground_grid(spots[:ground])
    arrival = spots[:template] ? spots[:arrival] : spots[:entry]
    target = [leader.x, leader.y + 1]
    standing = events.map { |e| [e.x, e.y] }
    barriers = events.select { |e| e.label.start_with?("Barriere") }
    check_gym_mechanic(map, events, barriers, drawn, i, grid, arrival, standing) if !spots[:template]
    # The barriers lift once the statues are lit
    open = standing - barriers.map { |e| [e.x, e.y] }
    raise MapEvents::Error, "#{map} : le lieutenant est hors d'atteinte" if !reach(grid, arrival, open)[target]
    seen = members.flat_map do |e|
      dx, dy = W::STEPS[e.value("Facing")]
      (1..e.value("Sight").to_i).map { |k| [e.x + (dx * k), e.y + (dy * k)] }.take_while { |x, y| grid[y]&.[](x) }
    end
    # (a generated gym is one open room: its members are fought or not)
    if spots[:template] && reach(grid, arrival, standing + seen)[target]
      raise MapEvents::Error, "#{map} : on atteint le lieutenant sans passer devant un membre"
    end
  end
end

# The mechanic of a generated gym (#121): barriers on every floor cell
# around the lieutenant, hidden by its switch, and its statues (touched to
# turn it on), each reachable while the barriers stand, in the number the
# lieutenant drew; none of them in a cramped room only.
def check_gym_mechanic(map, events, barriers, drawn, index, grid, arrival, standing)
  statues = events.select { |e| e.label.start_with?("Statue") }
  raise MapEvents::Error, "#{map} : #{statues.length} statues au lieu de #{drawn[:statues]}" if statues.length != drawn[:statues]
  if statues.empty?
    raise MapEvents::Error, "#{map} : barrières sans statue" if !barriers.empty?
    return puts("#{map} : salle trop étroite, pas de statue")
  end
  leader = events.find { |e| e.label == "Lieutenant" }
  around = W::STEPS.values.map { |dx, dy| [leader.x + dx, leader.y + dy] }.select { |x, y| grid[y]&.[](x) }
  if barriers.map { |e| [e.x, e.y] }.sort != around.sort
    raise MapEvents::Error, "#{map} : barrières #{barriers.map { |e| [e.x, e.y] }} au lieu de #{around}"
  end
  switch = "S#{W::GYM_STATUE_SWITCH + index + 1}"
  barriers.each { |e| raise MapEvents::Error, "#{map} : [NPC #{e.label}] sans Hide = #{switch}" if e.value("Hide") != switch }
  seen = reach(grid, arrival, standing)
  statues.each do |e|
    raise MapEvents::Error, "#{map} : [NPC #{e.label}] hors d'atteinte" if W::STEPS.values.none? { |dx, dy| seen[[e.x + dx, e.y + dy]] }
    script = "WorldEvents.gym_statue(#{e.label[/\d+/]}, #{statues.length}, #{switch[1..]}, #{W::GYM_ORDERED.include?(drawn[:type])})"
    raise MapEvents::Error, "#{map} : [NPC #{e.label}] Script #{e.value('Script')}" if e.value("Script") != script
    hidden = W::GYM_HIDDEN.include?(drawn[:type])
    raise MapEvents::Error, "#{map} : [NPC #{e.label}] statue visible/invisible à tort" if hidden == !e.value("Graphic").nil?
  end
end

# Rows of passable cells (true) of a generated floor's ground cells
def ground_grid(ground)
  grid = Array.new(ground.map(&:last).max + 1) { Array.new(ground.map(&:first).max + 1, false) }
  ground.each { |x, y| grid[y][x] = true }
  return grid
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
         (spots[:nooks] || []).map { |x, y, *| [x, y] } + (spots[:hill_tops] || []) + [spots[:professor]].compact
  blocked = W.blocked_cells(spots)
  plan.events.each do |entry|
    cell = [entry.x, entry.y]
    where = "[#{entry.kind.capitalize} #{entry.label}] en #{entry.x},#{entry.y}"
    next if gates.include?(cell) && entry.label.start_with?("Garde", "Barrage", "Sortie")
    # A guild member holding a dungeon gate stands in its 1-tile corridor
    next if (spots[:gates] || []).include?(cell) && entry.label.start_with?("Guilde")
    raise MapEvents::Error, "#{where} : sur une sortie, une porte ou devant" if blocked.include?(cell)
    # A gym's barrier on the ground around the lieutenant (check_gym_mechanic)
    next if entry.label.start_with?("Barriere") && (spots[:ground] || []).include?(cell)
    raise MapEvents::Error, "#{where} : case hors de l'inventaire (inaccessible ?)" if !free.include?(cell)
    next if entry.kind != :trainer
    # A trainer never sees an exit or a door
    dx, dy = W::STEPS[entry.value("Facing")]
    sight = (1..entry.value("Sight").to_i).map { |i| [entry.x + (dx * i), entry.y + (dy * i)] }
    raise MapEvents::Error, "#{where} : sa vue atteint une sortie ou une porte" if sight.any? { |c| blocked.include?(c) }
    next if !entry.value("Rage")
    rage = (1..entry.value("Rage").split(",")[1].to_i).map { |i| [entry.x + (dx * i), entry.y + (dy * i)] }
    raise MapEvents::Error, "#{where} : sa vue de vengeance atteint une sortie ou une porte" if rage.any? { |c| blocked.include?(c) }
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
      next if entry.label.start_with?("Chef")   # A guild's leader by the street (check_guilds)
      sizes = W::PARTY_SIZES[[zone.seals, W::PARTY_SIZES.length - 1].min]
      raise MapEvents::Error, "#{where} : #{team.length} Pokémon (#{sizes} avec #{zone.seals} sceaux)" if !sizes.include?(team.length)
      if entry.value("DoubleBattle") && (zone.seals < W::DOUBLE_FROM || team.length < 2)
        raise MapEvents::Error, "#{where} : combat double avec #{team.length} Pokémon et #{zone.seals} sceaux"
      end
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

# The Cousin who gives the Town Map: one, on a route, whose sight (with the
# cell where it stands) cuts the way between two exits.
def check_map_giver(atlas, plans)
  givers = plans.flat_map do |name, plan|
    plan.events.select { |e| e.kind == :trainer && e.value("Gift") == W::MAP_ITEM.to_s }.map { |e| [name, e] }
  end
  raise MapEvents::Error, "pas de Cousin qui donne la carte" if givers.empty?
  raise MapEvents::Error, "#{givers.length} Cousins donnent la carte" if givers.length > 1
  name, entry = givers[0]
  spots = atlas[:maps][name]
  ground = spots[:ground].to_h { |cell| [cell, true] }
  dx, dy = W::STEPS[entry.value("Facing")]
  cut = [[entry.x, entry.y], *(1..entry.value("Sight").to_i).map { |k| [entry.x + (dx * k), entry.y + (dy * k)] }]
  exits = spots[:exits].map { |_side, x, y| [x, y] }.select { |cell| ground[cell] }
  reached = W.walk_cells(ground, exits[0], cut)
  raise MapEvents::Error, "#{name} : on contourne le Cousin qui donne la carte" if exits.all? { |cell| reached[cell] }
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
      nurse = plans[name].events.find { |e| e.label == W::CENTRE_LABELS[0] }
      if nurse.value("Graphic") != W::NURSE_GRAPHIC || nurse.value("Confirm") != "WorldEvents.nurse_pay"
        raise MapEvents::Error, "#{name} : infirmière sans l'apparence ou les soins payants de la Famille"
      end
    when "boutique"
      raise MapEvents::Error, "#{name} : boutique sans vendeur" if !labels.include?("Vendeur")
    end
  end
end

# The nooks to come back to (#269: their field item is given after their
# map's seals): a rare item (revisite in objets.txt, or a TM), a
# Pokémon of the imposed type at most at the cap, or a trace of the Pact
# before a rare item, the ball gone once taken. Returns [nooks, Pokémon,
# lore].
def check_revisits(atlas, zones, plans, type, species, tms)
  opened = W.field_item_seals(atlas)
  rare = W.revisit_table.values.flat_map(&:keys).map(&:to_s) + tms.map { |tm| tm.first.to_s }
  counts = [0, 0, 0]
  atlas[:maps].each do |name, spots|
    nooks = (spots[:nooks] || []).reject { |nook| nook[2] == "sombre" }.map { |x, y, kind, *| [x, y, kind] }
    nooks.push([*spots[:loot], "sombre"]) if spots[:dark] && spots[:loot]
    nooks.each do |x, y, kind|
      item = M::NOOKS[kind]
      next if !zones[name] || opened[item].to_i <= zones[name].seals
      counts[0] += 1
      event = plans[name]&.events&.find { |e| e.x == x && e.y == y && e.label.start_with?("Recoin") }
      raise MapEvents::Error, "#{name} : recoin à revisiter (#{x},#{y}) sans butin" if !event
      next raise_if(!rare.include?(event.value("Item")), "#{name} : recoin à revisiter avec #{event.value('Item')}") if event.kind == :item
      script = event.value("Script").to_s
      if event.value("Hide") != "A" || event.value("Graphic") != W::NOOK_GRAPHIC || !script.start_with?('pbSetSelfSwitch(@event_id, "A", true) if ')
        raise MapEvents::Error, "#{name} : butin du recoin #{event.label} mal écrit (#{script})"
      end
      if (found = script[/WorldEvents\.nook_pokemon\(:(\w+), (\d+)\)/, 1])
        level = $2.to_i
        cap = E::CAPS[opened[item]] || E::CAPS.last
        raise MapEvents::Error, "#{name} : Pokémon de recoin sans type imposé" if !type
        raise MapEvents::Error, "#{name} : #{found} n'est pas du type #{type}" if !species[found.to_sym]&.monotype_types&.include?(type)
        raise MapEvents::Error, "#{name} : #{found} niveau #{level} au-dessus du plafond #{cap}" if level > cap
        counts[1] += 1
      elsif (found = script[/pbItemBall\(:(\w+)\)/, 1])
        raise_if(!rare.include?(found), "#{name} : recoin à revisiter avec #{found}")
        raise MapEvents::Error, "#{name} : trace du Pacte sans texte" if event.fields.none? { |key, _| key == "Text" }
        counts[2] += 1
      else
        raise MapEvents::Error, "#{name} : butin du recoin #{event.label} inconnu (#{script})"
      end
    end
  end
  return counts
end

def raise_if(condition, message)
  raise MapEvents::Error, message if condition
end

# Every nook and hill top has its loot, every field item is given in its town once its
# lieutenant is beaten, the Heart Scales reach their number, a Move
# Relearner stands in a town reached before the 2nd seal, gifts are given
# once and reach their share.
# The field items obtained outside the gyms (#274): each one the world has
# (hidden: MapProc's towns of their hidden inhabitants) has exactly one
# source, the leader of a guild of the world that declares it (« Objet »,
# on its headquarters' place, the hidden inhabitant gone), else its hidden
# inhabitant; a guild that declares one the world has, and whose leader is
# there, gives it.
def check_guild_field_items(hidden, atlas, drawn, plans)
  return hidden[:items].count do |item, town|
    next false if !W.extra_field_item?(item)
    sources = plans.sum do |_name, plan|
      plan.events.count do |e|
        (e.kind == :npc && e.value("Gift") == item.to_s) ||
          e.fields.any? { |key, value| key == "Reward" && value == "pbReceiveItem(:#{item})" }
      end
    end
    raise MapEvents::Error, "#{item} : #{sources} sources au lieu d'une" if sources != 1
    guild = GUILDS.find { |g| g.field_item == item && drawn.any? { |d| d[:id] == g.id } }
    giver = guild && drawn.find { |d| d[:id] == guild.id }
    if giver
      raise MapEvents::Error, "#{item} : la guilde #{guild.id} ne le donne pas" if giver[:field_item] != item || atlas[:items][item] != giver[:hq]
      # Its headquarters reached without it: no obstacle of that item there
      kind = M::NOOKS.key(item)
      [giver[:hq], giver[:map]].uniq.each do |name|
        if (atlas[:maps][name][:nooks] || []).any? { |nook| nook[2] == kind }
          raise MapEvents::Error, "#{item} : obstacle #{kind} au QG de #{guild.id} (#{name})"
        end
      end
    elsif atlas[:items][item] != town
      raise MapEvents::Error, "#{item} : donné à #{atlas[:items][item]} sans guilde (habitant caché à #{town})"
    end
    giver
  end
end

def check_items(atlas, zones, plans, items)
  loot = Hash.new(0)
  plans.each { |name, plan| loot[name] = plan.events.count { |e| %i[item npc].include?(e.kind) && e.label.start_with?("Recoin") } }
  atlas[:maps].each do |name, spots|
    nooks = (spots[:nooks] || []).count { |_x, _y, kind, *| kind != "sombre" }
    nooks = 1 if spots[:dark] && spots[:loot]
    nooks += (spots[:hill_tops] || []).length
    raise MapEvents::Error, "#{name} : #{loot[name]} butins pour #{nooks} recoins" if loot[name] != nooks
  end
  atlas[:items].each do |item, town|
    # Given by a guild's leader (check_guild_field_items)
    next if W.hq_place?(atlas, town)
    npc = plans[town]&.events&.find { |e| e.kind == :npc && e.value("Gift") == item.to_s }
    raise MapEvents::Error, "#{town} : personne ne donne #{item}" if !npc
    # Given outside the gyms (the Skates): at once, never sold
    if W.extra_field_item?(item)
      raise MapEvents::Error, "#{town} : #{item} attend un sceau (#{npc.value('When')})" if npc.value("When")
      next
    end
    gym = atlas[:gyms].index(town)
    if gym && npc.value("When") != "S#{W::GYM_SWITCH + gym + 1}"
      raise MapEvents::Error, "#{town} : #{item} donné sans attendre le sceau de la ville (#{npc.value('When')})"
    end
  end
  # Every drawn item comes from the pool (#331): its items, a TM (the draw of
  # :TM), Heart Scales, Pact Incenses and the field items
  pool = W.item_pool.map(&:id) + [W::HEART_SCALE, W::PACT_INCENSE] + atlas[:items].keys
  strays = items.map { |i| i[:item] }.uniq.reject { |item| pool.include?(item) || item.to_s.start_with?("TM") }
  raise MapEvents::Error, "objets hors de objets.txt : #{strays.join(', ')}" if !strays.empty?
  scales = items.count { |i| i[:item] == W::HEART_SCALE }
  raise MapEvents::Error, "#{scales} Écailles Cœur au lieu de #{W::HEART_SCALES}" if scales != W::HEART_SCALES
  early = plans.select { |name, plan| plan.events.any? { |e| e.label.start_with?("MaitreCapacites") } && zones[name].seals <= 1 }
  raise MapEvents::Error, "aucun Maître des Capacités avant le 2e sceau" if early.empty?
  plans.each do |name, plan|
    plan.events.each do |e|
      next if e.kind != :npc || !e.value("Gift") || e.value("Once")
      raise MapEvents::Error, "#{name} : [Npc #{e.label}] redonne son objet (pas de « Once »)"
    end
  end
  drawn = items.select { |i| W::ITEM_SOURCES.key?(i[:source]) }
  gifts = drawn.count { |i| i[:source] == "don" }
  if gifts * 100 < drawn.length * W::GIFT_SHARE
    raise MapEvents::Error, "#{gifts} dons sur #{drawn.length} objets (#{W::GIFT_SHARE} % au moins)"
  end
end

# The League: in the order of its rooms, the four Anciens (types all
# different), the Parrain and Arceus, each door closed until its room is
# won; the Anciens stronger than the last lieutenant, one after the other,
# the Parrain at the cap with every seal, Arceus above.
def check_league(atlas, plans, fights, leaders)
  rooms = atlas[:league].reject { |name| %w[Entrée Panthéon].include?(atlas[:maps][name][:role]) }
  return if rooms.empty?
  roles = rooms.map { |name| atlas[:maps][name][:role] }
  raise MapEvents::Error, "Ligue : salles #{roles.join(', ')}" if roles != ["Ancien 1", "Ancien 2", "Ancien 3", "Ancien 4", "Parrain", "Arceus"]
  raise MapEvents::Error, "Ligue : combats #{fights.map { |f| f[:role] }.join(', ')}" if fights.map { |f| f[:role] } != roles
  rooms.each_with_index do |name, i|
    events = plans[name]&.events || []
    switch = W::LEAGUE_SWITCH + i + 1
    door = events.find { |e| e.label == "Porte" }
    if !door || door.value("Hide") != "S#{switch}" || door.value("Trigger") != "contact"
      raise MapEvents::Error, "#{name} : porte absente ou pas fermée par l'interrupteur #{switch}"
    end
    fight = events.find { |e| e.label == roles[i].delete(" ") }
    raise MapEvents::Error, "#{name} : pas de #{roles[i]}" if !fight
    won = (fight.kind == :trainer) ? fight.value("Switch").to_i : fight.value("Script")[/, (\d+)\)\z/, 1].to_i
    raise MapEvents::Error, "#{name} : la victoire n'ouvre pas la porte (#{won} au lieu de #{switch})" if won != switch
  end
  elders = fights.first(4)
  raise MapEvents::Error, "Ligue : deux Anciens du même type" if elders.map { |f| f[:type] }.uniq.length != 4
  tops = fights.map { |f| f[:team].map(&:last).max }
  last = leaders.map { |l| l[:team].map(&:last).max }.max
  top = E::CAPS[atlas[:gyms].length] || E::CAPS.last
  raise MapEvents::Error, "Ligue : niveaux #{tops.join(', ')} pas croissants" if tops.each_cons(2).any? { |a, b| b < a }
  raise MapEvents::Error, "Ligue : premier Ancien (#{tops[0]}) pas plus fort que le dernier lieutenant (#{last})" if tops[0] <= last
  raise MapEvents::Error, "Ligue : Parrain au niveau #{tops[4]} au lieu du plafond #{top}" if tops[4] != top
  raise MapEvents::Error, "Ligue : Arceus (#{tops[5]}) pas au-dessus du Parrain" if tops[5] <= top
  elders.each do |f|
    next if f[:team].all? { |sp, _| ROSTER[sp].types.include?(f[:type]) }
    raise MapEvents::Error, "Ligue : #{f[:name]} a des Pokémon hors de son type #{f[:type]}"
  end
end

# No line of a section drawn twice while others are left: the pool left
# after each draw counts down from the section's size to 0, then again.
def check_lines(drawn)
  drawn.each do |section, lefts|
    size = DIALOGUES[section].length
    lefts.each_with_index do |left, i|
      expected = size - 1 - (i % size)
      raise MapEvents::Error, "dialogues [#{section}] : réplique redite avant d'avoir tout dit" if left != expected
    end
  end
end

# Inhabitants by the streets of every town but the first, in the houses.
def check_habitants(result, atlas, plans)
  result.places.each do |wp, *|
    next if wp.kind != "ville" || wp.name == atlas[:start]
    next if plans[wp.name]&.events&.any? { |e| e.label.start_with?("Habitant") }
    raise MapEvents::Error, "#{wp.name} : ville sans habitant"
  end
  atlas[:maps].each do |name, map|
    next if map[:kind] != "interieur" || !W::HOUSE_BUILDINGS.include?(map[:building]) || !W::HOUSE_SPOTS[map[:template]]
    count = plans[name]&.events&.count { |e| e.label.start_with?("Habitant") } || 0
    raise MapEvents::Error, "#{name} : #{count} habitants (#{W::HOUSE_HABITANTS})" if !W::HOUSE_HABITANTS.include?(count)
  end
end

# The sets of the lieutenants and of the League: one per Pokémon, 1 to 4
# moves it may know (level-up at its level, TM or egg move under the power
# cap of the seals, one seal more for the trainer's type), one of the trainer's type when it learns one by then,
# its hidden ability only if it has one, items that exist.
def check_sets(fights, seals, items)
  fights.each do |fight|
    next if !fight[:sets]
    where = "#{fight[:name]} (#{fight[:role] || "lieutenant #{fight[:gym]}"})"
    raise MapEvents::Error, "#{where} : #{fight[:sets].length} sets pour #{fight[:team].length} Pokémon" if fight[:sets].length != fight[:team].length
    has = fight[:seals] || (fight[:gym] ? fight[:gym] - 1 : seals)
    fight[:team].zip(fight[:sets]).each do |(id, level), set|
      ls = DEX[:species][id]
      raise MapEvents::Error, "#{where} : #{id} sans set" if !set || !ls
      moves = set[:moves]
      raise MapEvents::Error, "#{where} : #{id}, #{moves.length} attaques" if moves.empty? || moves.length > 4 || moves.uniq != moves
      level_moves = ls.level_moves.filter_map { |l, m| m if l <= level }
      moves.each do |move|
        data = DEX[:moves][move]
        taught = (TM_MOVES.include?(move) && ls.tutor_moves.include?(move)) || (has >= W::SET_EGG_SEALS && ls.egg_moves.include?(move))
        ok = data && (level_moves.include?(move) || (taught && data.power <= W.set_cap(has, data.type == fight[:type])))
        raise MapEvents::Error, "#{where} : #{id} niveau #{level} ne peut pas connaître #{move}" if !ok
      end
      type = fight[:type]
      stab = level_moves.any? { |m| (d = DEX[:moves][m]) && d.type == type && d.category != :Status && d.power > 1 }
      if type && stab && moves.none? { |m| DEX[:moves][m].type == type }
        raise MapEvents::Error, "#{where} : #{id} sans attaque #{type}"
      end
      raise MapEvents::Error, "#{where} : #{id} sans talent caché" if set[:ability_index] >= 2 && ls.hidden.empty?
      raise MapEvents::Error, "#{where} : #{id}, AbilityIndex #{set[:ability_index]}" if set[:ability_index] < 2 && set[:ability_index] >= ls.abilities.length
      raise MapEvents::Error, "#{where} : #{id}, objet #{set[:item]} absent" if !set[:item] || !items.include?(set[:item].to_s)
    end
  end
end

# The leaders of the guilds as fights for check_sets.
def guild_fights(guilds)
  return guilds.map do |g|
    { name: g[:leader][:name], role: "chef #{g[:id]}", type: nil, team: g[:leader][:team], sets: g[:leader][:sets], seals: g[:seals] }
  end
end

# WORLD_GUILDS guilds in the world (fewer only when fewer headquarters have
# their place), each with its headquarters on a place of its biomes; its
# leader inside on a cell reached from the door (else by the street), at the
# level of the strongest trainer of the Tronçon (under the cap), with
# GUILD_LEADER_PARTY_SIZES Pokémon of its pool; 2 to 4 members by the street,
# their Pokémon from the pool too.
# The encounters of each guild's dungeon (#336): a zone of its own, drawn
# from the guild's pool with nothing added for the types or the families, at
# the levels of its route, the same with the same seed.
def check_dungeon_encounters(result, zones, lines, generated, seed, roster)
  (result.hqs || {}).each do |kind, name|
    zone = zones.find { |z| z.name == name }
    raise MapEvents::Error, "#{name} : pas de zone de rencontres" if !zone
    raise MapEvents::Error, "#{name} : rencontres hors du pool de la guilde #{kind}" if zone.pool != POOLS[kind]
    tables = generated.tables.select { |t| t.zone.name == name }
    # The dungeon of a guild of the outdoors is in its grass; a room's, on
    # the whole floor behind its door (#337), from the same pool
    if M::HQ_ROOM_KINDS.include?(kind)
      inside = zones.find { |z| z.name == "#{name} - donjon" }
      raise MapEvents::Error, "#{name} : donjon sans rencontres du pool de la guilde" if !inside || inside.pool != POOLS[kind]
      tables += generated.tables.select { |t| t.zone.name == inside.name }
      raise MapEvents::Error, "#{name} : aucune rencontre sur le sol du donjon" if tables.none? { |t| t.type == "Cave" && !t.slots.empty? }
    elsif tables.none? { |t| t.type == "Land" && !t.slots.empty? }
      raise MapEvents::Error, "#{name} : aucune rencontre dans les herbes du donjon"
    end
    tables.each do |table|
      outside = table.slots.reject { |e| zone.pool.include?(e.species.id) }
      raise MapEvents::Error, "#{name} : #{outside.map { |e| e.species.id }.join(', ')} hors du pool" if !outside.empty?
      raise MapEvents::Error, "#{name} : Pokémon ajouté pour les types ou les familles" if table.slots.any? { |e| e.role == :cover }
      raise MapEvents::Error, "#{name} : type dominant tiré" if !table.dominant.empty?
    end
  end
  again, = E.world_encounters(result, roster, E::CAPS, seed, POOLS)
  raise MapEvents::Error, "la même graine donne d'autres rencontres" if again != lines
end

def check_guilds(result, atlas, zones, plans, drawn, bricks)
  available = M::GUILD_HQS.keys.count { |kind| bricks.any? { |b| b.kind == kind } && !M.hq_places(result.places, kind).empty? }
  hqs = atlas[:hqs]
  if hqs.length > M::WORLD_GUILDS.max || hqs.length < [M::WORLD_GUILDS.min, available].min
    raise MapEvents::Error, "#{hqs.length} QG de guildes (#{M::WORLD_GUILDS}, #{available} possibles)"
  end
  missing = hqs.keys - drawn.map { |g| GUILDS.find { |guild| guild.id == g[:id] }.hq }
  raise MapEvents::Error, "QG sans guilde : #{missing.join(', ')}" if !missing.empty?
  drawn.each do |g|
    guild = GUILDS.find { |x| x.id == g[:id] }
    place = result.places.find { |wp, *| wp.name == g[:hq] }
    raise MapEvents::Error, "guilde #{guild.id} : QG sur #{g[:hq]}, ambiance #{place&.last&.ambiance} hors de ses biomes" if !place || !(guild.biomes.empty? || guild.biomes.include?(place[3].ambiance))
    raise MapEvents::Error, "guilde #{guild.id} : QG #{guild.hq} absent de #{g[:hq]}" if place[3].spots[:hqs].none? { |_x, _y, k| k == guild.hq }
    chef = plans[g[:map]]&.events&.find { |e| e.label == g[:leader][:label] }
    raise MapEvents::Error, "#{g[:map]} : pas de chef de guilde #{guild.id}" if !chef
    spots = atlas[:maps][g[:map]]
    if spots[:kind] == "interieur"
      grid = PASSABLE[spots[:template]]
      raise MapEvents::Error, "#{g[:map]} : chef hors d'atteinte" if !reach(grid, spots[:arrival], [])[[chef.x, chef.y + 1]] || !grid[chef.y][chef.x]
    end
    zone = zones[g[:hq]]
    expected = W.guild_level(zones, zone, E::CAPS)
    team = g[:leader][:team]
    raise MapEvents::Error, "chef #{g[:id]} : niveau #{team.map(&:last).max} au lieu de #{expected}" if team.map(&:last).max != expected
    raise MapEvents::Error, "chef #{g[:id]} : niveau #{expected} au-dessus du plafond" if expected > (E::CAPS[zone.seals] || E::CAPS.last)
    size = W::GUILD_LEADER_PARTY_SIZES[[zone.seals, W::GUILD_LEADER_PARTY_SIZES.length - 1].min]
    raise MapEvents::Error, "chef #{g[:id]} : #{team.length} Pokémon au lieu de #{size}" if team.length != size || !(4..6).include?(team.length)
    labels = g[:members].map { |m| m[:label] }
    # In a guild of rooms' dungeon (#337), behind its door
    members = plans[g[:members].first&.[](:map) || g[:hq]]&.events&.select { |e| e.kind == :trainer && labels.include?(e.label) } || []
    raise MapEvents::Error, "guilde #{g[:id]} : #{members.length} membres" if !W::GUILD_MEMBERS.include?(members.length) || members.length != labels.length
    (g[:members].map { |m| m[:team] } + [team]).flatten(1).each do |species, _level|
      raise MapEvents::Error, "guilde #{g[:id]} : #{species} hors de son pool" if !guild.pool.include?(species)
    end
    check_dungeon(g, guild, atlas, plans, members, chef)
  end
end

# What each guild gives once its leader is beaten (#186), with that imposed
# type: an ally, a Pokémon of its pool of that type at the leader's level,
# else the nearest shortcut still closed (its obstacle's events on its
# map), else a field item given ahead; the others, an item that exists and
# money. Each has its own switch.
# Returns the kinds given.
def check_rewards(result, atlas, plans, drawn, type, items)
  switches = drawn.map { |g| g[:switch] }
  raise MapEvents::Error, "interrupteurs de guilde en double ou hors plage (#{switches.join(', ')})" if switches.uniq != switches || switches.any? { |n| !n.between?(W::GUILD_SWITCH + 1, W::GUILD_SWITCH + GUILDS.length) }
  taken = []
  return drawn.map do |g|
    guild = GUILDS.find { |x| x.id == g[:id] }
    where = "guilde #{guild.id} (#{guild.position}, type #{type || 'aucun'})"
    reward = g[:reward]
    chef = plans[g[:map]].events.find { |e| e.label == g[:leader][:label] }
    raise MapEvents::Error, "#{where} : interrupteur #{chef.value('Switch')} au lieu de #{g[:switch]}" if chef.value("Switch").to_i != g[:switch]
    raise MapEvents::Error, "#{where} : chef sans réplique de victoire" if !chef.value("Win")
    # Its field item (#274), on top of its reward
    given = "pbReceiveItem(:#{g[:field_item]})"
    scripts = chef.fields.filter_map { |key, value| value if key == "Reward" && value != given }
    if g[:field_item] && (g[:field_item] != guild.field_item || chef.fields.count { |key, value| key == "Reward" && value == given } != 1)
      raise MapEvents::Error, "#{where} : objet de terrain #{g[:field_item]} mal donné par le chef"
    end
    raise MapEvents::Error, "#{where} : sans récompense" if !reward
    typed = guild.pool.select { |id| type && ROSTER[id].monotype_types.include?(type) }
    shortcuts = W.guild_shortcuts(result, g[:hq]).reject { |wp, _layout| taken.include?(wp.name) }
    fields = W.guild_field_items(result, atlas, g[:hq]) - taken
    expected = "objet"
    if guild.position == W::GUILD_ALLY
      expected = "terrain" if !fields.empty?
      expected = "raccourci" if !shortcuts.empty?
      expected = "pokemon" if !typed.empty?
    end
    raise MapEvents::Error, "#{where} : récompense #{reward[:kind]} au lieu de #{expected}" if reward[:kind] != expected
    case expected
    when "pokemon"
      raise MapEvents::Error, "#{where} : #{reward[:species]} hors du pool ou du type" if !typed.include?(reward[:species])
      raise MapEvents::Error, "#{where} : Pokémon donné au niveau #{reward[:level]} (chef #{g[:level]})" if reward[:level] != g[:level]
      raise MapEvents::Error, "#{where} : don absent du chef" if scripts != ["WorldEvents.guild_pokemon(:#{reward[:species]}, #{reward[:level]})"]
    when "raccourci"
      wp, layout = shortcuts.first
      raise MapEvents::Error, "#{where} : raccourci #{reward[:route]} au lieu du plus proche (#{wp.name})" if reward[:route] != wp.name
      raise MapEvents::Error, "#{where} : obstacle #{wp.lock} sans événement à ouvrir" if !W::GUILD_OPENABLE.include?(wp.lock) || reward[:obstacle] != wp.lock
      cells = layout.spots[:lock].drop(1).each_slice(2).to_a
      raise MapEvents::Error, "#{where} : cases #{reward[:cells].inspect} hors de l'obstacle (#{cells.inspect})" if reward[:cells] != cells || cells.length != ((wp.lock == M::GRAPPLE) ? 2 : 1)
      raise MapEvents::Error, "#{where} : le chef n'annonce pas le raccourci" if chef.fields.count { |key, _v| key == "Win" } < 2
      taken.push(wp.name)
    when "terrain"
      raise MapEvents::Error, "#{where} : objet de terrain #{reward[:item]} inconnu ou déjà obtenu" if !fields.include?(reward[:item]) || !items.include?(reward[:item].to_s)
      raise MapEvents::Error, "#{where} : don absent du chef" if chef.value("Gift") != reward[:item].to_s
      taken.push(reward[:item])
    when "objet"
      raise MapEvents::Error, "#{where} : objet #{reward[:item]} absent" if !items.include?(reward[:item].to_s) || chef.value("Gift") != reward[:item].to_s
      raise MapEvents::Error, "#{where} : argent #{reward[:money]}" if reward[:money].to_i <= 0 || scripts != ["WorldEvents.guild_money(#{reward[:money]})"]
    end
    expected
  end
end

# The zone an affiliated guild frees (#187): the town nearest its
# headquarters (never the first town), whose inhabitants, in the streets
# and the houses, have a page under the guild's switch with a line of
# [habitant_libre] (never a policeman); the Cousins of that town and of
# the routes that touch it vanish under that switch, no other does, and
# the Cousin of the Town Map stays. Returns the number of freed zones.
def check_liberations(result, atlas, plans, drawn)
  towns = result.places.map(&:first).select { |wp| wp.kind == "ville" && wp.name != atlas[:start] && !wp.league && !wp.victory }
  index = result.places.to_h { |wp, *| [wp.name, W.chain_index(wp)] }
  free_lines = DIALOGUES["habitant_libre"].map { |line| line.split(/\s*\|\s*/).first[/\A[^{]+/] }
  vanish = {}
  seen = []
  drawn.each do |g|
    guild = GUILDS.find { |x| x.id == g[:id] }
    where = "guilde #{guild.id} (#{guild.position})"
    if guild.position != W::GUILD_FREEING
      raise MapEvents::Error, "#{where} : zone libérée #{g[:freed].inspect}" if g[:freed]
      next
    end
    left = towns.reject { |wp| seen.include?(wp.name) }
    raise MapEvents::Error, "#{where} : aucune ville libérée" if !g[:freed] && !left.empty?
    next if !g[:freed]
    town = left.find { |wp| wp.name == g[:freed][:town] }
    raise MapEvents::Error, "#{where} : ville libérée #{g[:freed][:town]} inconnue ou déjà libérée" if !town
    nearest = left.map { |wp| (wp.index - index[g[:hq]]).abs }.min
    raise MapEvents::Error, "#{where} : #{town.name} n'est pas la ville la plus proche du QG" if (town.index - index[g[:hq]]).abs != nearest
    seen.push(town.name)
    g[:freed][:maps].each { |map| vanish[map] = g[:switch] }
    homes = [town.name] + atlas[:maps].select { |_name, map| map[:kind] == "interieur" && map[:owner] == town.name }.keys
    habitants = homes.flat_map { |name| plans[name]&.events&.select { |e| e.label.start_with?("Habitant") } || [] }
    raise MapEvents::Error, "#{where} : #{town.name} sans habitant" if habitants.empty?
    habitants.each do |e|
      if e.value("Graphic") == W::POLICE_GRAPHIC
        raise MapEvents::Error, "#{where} : policier de #{town.name} avec une page « zone libérée »" if e.value("When")
        next
      end
      text = e.value("Text").to_s
      if e.value("When") != "S#{g[:switch]}" || !e.value("Wait") || free_lines.none? { |start| text.start_with?(start) }
        raise MapEvents::Error, "#{where} : habitant #{e.label} de #{town.name} sans page « zone libérée »"
      end
    end
  end
  plans.each do |name, plan|
    plan.events.each do |e|
      # The members of the guilds leave the routes for their rivals (check_rivalries)
      next if e.kind != :trainer || e.label.start_with?("Guilde")
      cousin = e.label.start_with?("Cousin") && e.value("Gift") != W::MAP_ITEM.to_s
      expected = cousin ? vanish[name] : nil
      next if e.value("VanishIfSwitch")&.to_i == expected
      raise MapEvents::Error, "#{name} : #{e.label} disparaît sous l'interrupteur #{e.value('VanishIfSwitch').inspect} au lieu de #{expected.inspect}"
    end
    next if seen.any? { |town| name == town || atlas[:maps][name][:owner] == town }
    stray = plan.events.find { |e| e.label.start_with?("Habitant") && e.value("When") }
    raise MapEvents::Error, "#{name} : #{stray.label} a une page « zone libérée » hors d'une ville libérée" if stray
  end
  return seen.length
end

# A guild's dungeon: its place for a guild of the outdoors (#335), the map
# behind its building's door for a guild of rooms (#337, the leader there).
# A member in the corridor of each gate, facing the exit (across the
# corridor in a room), gone once beaten, the first one closing the exit
# (its lock switch); the others and the leader past the gates (the leader
# past the last one); a member of the guild on each cell of the exit's
# inner row (on the exit in a room), seen, there only under the lock and
# gone once the leader is beaten.
def check_dungeon(g, guild, atlas, plans, members, chef)
  room = M::HQ_ROOM_KINDS.include?(guild.hq)
  name = room ? atlas[:maps].find { |_n, m| m[:kind] == "donjon" && m[:building] == guild.hq && m[:owner] == g[:hq] }&.first : g[:hq]
  where = "donjon #{guild.id} (#{name || g[:hq]})"
  raise MapEvents::Error, "#{where} : pas de donjon derrière la porte" if !name
  spots = atlas[:maps][name]
  raise MapEvents::Error, "#{where} : #{spots[:gates]&.length.to_i} barrières" if spots[:gates]&.length != M::HQ_GATES
  raise MapEvents::Error, "#{where} : chef hors du donjon (#{g[:map]})" if room && g[:map] != name
  lock = W.guild_lock(GUILDS, guild)
  raise MapEvents::Error, "#{where} : interrupteur #{lock} hors de GUILD_LOCKS" if lock > W::GUILD_LOCK_SWITCH + W::GUILD_LOCKS
  spots[:gates].each_with_index do |(x, y), i|
    facing = spots[:gate_facing] ? spots[:gate_facing][i] : W::FACE_EXIT[spots[:exits][0][0]]
    m = members.find { |e| e.x == x && e.y == y }
    raise MapEvents::Error, "#{where} : barrière #{i + 1} sans membre" if !m
    raise MapEvents::Error, "#{where} : #{m.label} ne garde pas son goulet" if m.value("Facing") != facing
    raise MapEvents::Error, "#{where} : #{m.label} reste une fois battu" if m.value("Hide") != "A"
    raise MapEvents::Error, "#{where} : #{m.label} ne ferme pas la sortie" if (i == 0) != (m.value("Switch").to_i == lock)
  end
  first = W.past_gate(spots, 0)
  (members.reject { |e| spots[:gates].include?([e.x, e.y]) }).each do |e|
    raise MapEvents::Error, "#{where} : #{e.label} avant la première barrière" if !first[[e.x, e.y]]
  end
  raise MapEvents::Error, "#{where} : chef avant la dernière barrière" if !W.past_gate(spots, -1)[[chef.x, chef.y]]
  exits = plans[name].events.select { |e| e.label.start_with?("Sortie") }
  if exits.map { |e| [e.x, e.y] }.sort != (spots[:locks] || W.gate_cells([spots[:exits][0]])).sort
    raise MapEvents::Error, "#{where} : sortie mal fermée (#{exits.map { |e| [e.x, e.y] }.inspect})"
  end
  exits.each do |e|
    raise MapEvents::Error, "#{where} : #{e.label} invisible (on le traverserait)" if e.value("Graphic") != "trainer_#{guild.member_types.first}"
    raise MapEvents::Error, "#{where} : #{e.label} hors du verrou" if e.value("Show") != "S#{lock}" || e.value("Hide") != "S#{g[:switch]}"
  end
end

# Rivalries (#189): enemies drawn together lie near each other (no place
# where the later one could stand is nearer the other); the members of a
# guild with a rallying enemy (W.guild_rivals) see farther and say a line of
# [guilde_vengeance] under the ally's switch, those of the routes leave under
# their own; no other member does; by an ally's headquarters, a member
# gives an item of the pool's guilde source under each present enemy's switch.
# Returns the enemy pairs of the world.
def check_rivalries(world, result, atlas, plans, drawn, items)
  hqs = atlas[:hqs]
  # A headquarters lies where its place branches off the chain
  index = result.places.to_h { |wp, *| [wp.name, W.chain_index(wp)] }
  pairs = 0
  hqs.each do |kind, place|
    (M::HQ_ENEMIES[kind] || []).each do |enemy|
      next if !hqs[enemy] || kind > enemy
      pairs += 1
      gap = (index[place] - index[hqs[enemy]]).abs
      # The one laid later goes off the nearest route with room left beside
      # it (a free spot now was free when it was laid)
      order = result.places.to_h { |wp, *| [wp.name, wp.index] }
      later, other = (order[place] > order[hqs[enemy]]) ? [kind, hqs[enemy]] : [enemy, place]
      routes = M.hq_places(result.places, later).select { |i| !M.hq_spots(world, result.places, result.places[i][0], M.hq_sizes(later)).empty? }
      nearest = [routes.map { |i| (result.places[i][0].index - index[other]).abs }.min || gap, gap].min
      raise MapEvents::Error, "QG ennemis #{kind} et #{enemy} à #{gap} lieux l'un de l'autre (#{nearest} possible)" if gap > nearest + 1
    end
  end
  rivals = W.guild_rivals(atlas, GUILDS)
  vengeance = DIALOGUES["guilde_vengeance"].map { |line| line.split(/\s*\|\s*/).first[/\A[^{]+/] }
  members = drawn.flat_map { |g| (g[:members].map { |m| [g, m[:map], m, false] }) + g[:routes].map { |m| [g, m[:map], m, true] } }
  members.each do |g, map, member, route|
    entry = plans[map].events.find { |e| e.label == member[:label] }
    where = "#{map} : #{member[:label]} (#{g[:id]})"
    rival = rivals[g[:id]]
    if !rival
      raise MapEvents::Error, "#{where} : vengeance sans ennemi rallié" if entry.value("Rage") || entry.value("VanishIfSwitch")
      next
    end
    switch, sight = entry.value("Rage").to_s.split(",").map(&:to_i)
    raise MapEvents::Error, "#{where} : vengeance sous l'interrupteur #{switch.inspect} au lieu de #{rival[:rage]}" if switch != rival[:rage]
    raise MapEvents::Error, "#{where} : vue de vengeance #{sight} (#{entry.value('Sight')} à #{W::GUILD_RAGE_SIGHT})" if sight < entry.value("Sight").to_i || sight > [W::GUILD_RAGE_SIGHT, entry.value("Sight").to_i].max
    raise MapEvents::Error, "#{where} : réplique de vengeance absente" if vengeance.none? { |start| entry.value("RageBattle").to_s.start_with?(start) }
    expected = route ? rival[:vanish] : nil
    raise MapEvents::Error, "#{where} : quitte la route sous #{entry.value('VanishIfSwitch').inspect} au lieu de #{expected.inspect}" if entry.value("VanishIfSwitch")&.to_i != expected
  end
  drawn.each do |g|
    guild = GUILDS.find { |x| x.id == g[:id] }
    enemies = guild.position == W::GUILD_ALLY ? drawn.select { |e| guild.enemies.include?(e[:id]) } : []
    raise MapEvents::Error, "guilde #{g[:id]} : #{g[:bonuses].length} bonus pour #{enemies.length} ennemis" if g[:bonuses].map { |b| b[:enemy] }.sort != enemies.map { |e| e[:id] }.sort
    g[:bonuses].each do |bonus|
      npc = plans[bonus[:map]].events.find { |e| e.label == bonus[:label] }
      enemy = drawn.find { |e| e[:id] == bonus[:enemy] }
      where = "guilde #{g[:id]} : bonus contre #{bonus[:enemy]}"
      raise MapEvents::Error, "#{where} : absent du QG" if !npc || bonus[:map] != g[:hq]
      raise MapEvents::Error, "#{where} : sous #{npc.value('When')} au lieu de S#{enemy[:switch]}" if npc.value("When") != "S#{enemy[:switch]}"
      raise MapEvents::Error, "#{where} : objet #{npc.value('Gift')}" if !W.guild_bonus_items.include?(npc.value("Gift")&.to_sym) || !items.include?(npc.value("Gift"))
    end
  end
  return pairs
end

# The settling of scores (#190): each guild with a rallying enemy in the
# world has its showdown by its headquarters, shown once the ally rallied
# and gone once the guild's switch is on: the ally's leader as partner, the
# guild's leader and its right hand as foes (its pool, under the cap, a
# section of trainers.txt); the guild's leader counts as beaten once it is
# won. Returns the showdowns of the world.
def check_showdowns(atlas, plans, drawn, sections)
  rivals = W.guild_rivals(atlas, GUILDS)
  count = 0
  drawn.each do |g|
    rival = rivals[g[:id]]
    ally = rival && drawn.find { |a| a[:id] == rival[:ally] }
    show = g[:showdown]
    raise MapEvents::Error, "guilde #{g[:id]} : règlement de comptes sans allié rallié" if show && !ally
    next if !ally
    where = "règlement de comptes #{g[:id]} contre #{ally[:id]}"
    raise MapEvents::Error, "#{where} : absent" if !show
    count += 1
    npc = plans[show[:map]].events.find { |e| e.label == show[:label] }
    raise MapEvents::Error, "#{where} : pas près du QG" if !npc || show[:map] != g[:hq]
    raise MapEvents::Error, "#{where} : là sous #{npc.value('Show')} au lieu de S#{rival[:rage]}" if npc.value("Show") != "S#{rival[:rage]}"
    raise MapEvents::Error, "#{where} : reste sous #{npc.value('Hide')} au lieu de S#{g[:switch]}" if npc.value("Hide") != "S#{g[:switch]}"
    raise MapEvents::Error, "#{where} : partenaire #{show[:partner].inspect}" if show[:partner] != [ally[:leader][:type], ally[:leader][:name]]
    leader, second = show[:foes]
    raise MapEvents::Error, "#{where} : chef #{leader[1]} au lieu de #{g[:leader][:name]}" if leader[0, 2] != [g[:leader][:type], g[:leader][:name]]
    guild = GUILDS.find { |x| x.id == g[:id] }
    raise MapEvents::Error, "#{where} : bras droit #{second[0]} hors des membres" if !guild.member_types.include?(second[0])
    raise MapEvents::Error, "#{where} : bras droit à #{second[2].length} Pokémon" if !W::GUILD_SECOND_SIZES.include?(second[2].length)
    cap = E::CAPS[g[:seals]] || E::CAPS.last
    second[2].each do |species, level|
      raise MapEvents::Error, "#{where} : #{species} hors du pool" if !guild.pool.include?(species)
      raise MapEvents::Error, "#{where} : #{species} niveau #{level} au-dessus du plafond #{cap}" if level > cap
    end
    raise MapEvents::Error, "#{where} : bras droit absent de trainers.txt" if sections.none? { |sec| sec.start_with?("[#{second[0]},#{second[1]},#{W::TRAINER_VERSION}]") }
    args = [show[:partner], *show[:foes].map { |t, n, _team| [t, n] }].flatten.map { |v| v.is_a?(Symbol) ? ":#{v}" : v.inspect }
    raise MapEvents::Error, "#{where} : script #{npc.value('Script')}" if npc.value("Script") != "WorldEvents.showdown(#{args.join(', ')}, #{g[:switch]})"
    chef = plans[g[:map]].events.find { |e| e.label == g[:leader][:label] }
    raise MapEvents::Error, "#{where} : le chef n'est pas battu avec le règlement" if chef.value("EndIfSwitch").to_i != g[:switch]
  end
  return count
end

# Blocking headquarters (#188): at most one per world, of an affiliated or
# rival guild, on a route of the chain reached with GUILD_BLOCK_SEALS seals
# or more; its members stand on the inner row of the exit onward, hidden
# under the guild's switch, and cut the way while its headquarters stays
# reached (checked for every candidate, drawn or not); its leader stays
# under the cap of its Tronçon. Returns [blockades drawn, candidates].
def check_blockades(result, atlas, zones, plans, drawn)
  candidates = W.blockade_candidates(result, atlas, GUILDS, zones.values)
  blocking = drawn.select { |g| g[:blocks] }
  raise MapEvents::Error, "#{blocking.length} QG bloquants" if blocking.length > 1
  candidates.each do |c|
    guild = GUILDS.find { |g| g.id == c[:id] }
    wp, = result.places.find { |w, *| w.name == c[:route] }
    where = "QG bloquant possible #{guild.id} sur #{c[:route]}"
    raise MapEvents::Error, "#{where} : position #{guild.position}" if !W::GUILD_BLOCKING.include?(guild.position)
    raise MapEvents::Error, "#{where} : pas une route de la chaîne" if wp.kind != "route" || wp.extra
    raise MapEvents::Error, "#{where} : #{zones[c[:route]].seals} sceau(x)" if zones[c[:route]].seals < W::GUILD_BLOCK_SEALS
    raise MapEvents::Error, "#{where} : le barrage ne ferme pas la route" if !W.blockade_holds?(atlas[:maps][c[:route]], c[:cells], c[:anchor])
  end
  blocking.each do |g|
    blocks = g[:blocks]
    where = "QG bloquant #{g[:id]} sur #{blocks[:route]}"
    raise MapEvents::Error, "#{where} : pas parmi les QG possibles" if !candidates.include?(blocks)
    barrier = plans[blocks[:route]].events.select { |e| e.label.start_with?("Barrage") }
    raise MapEvents::Error, "#{where} : #{barrier.length} membres pour #{blocks[:cells].length} cases" if barrier.map { |e| [e.x, e.y] }.sort != blocks[:cells].sort
    barrier.each { |e| raise MapEvents::Error, "#{where} : #{e.label} reste après le chef" if e.value("Hide") != "S#{g[:switch]}" }
    cap = E::CAPS[g[:seals]] || E::CAPS.last
    raise MapEvents::Error, "#{where} : chef au niveau #{g[:leader][:team].map(&:last).max}, plafond #{cap}" if g[:leader][:team].map(&:last).max > cap
  end
  stray = plans.select { |name, plan| plan.events.any? { |e| e.label.start_with?("Barrage") } && blocking.none? { |g| g[:blocks][:route] == name } }
  raise MapEvents::Error, "barrage sans QG bloquant sur #{stray.keys.join(', ')}" if !stray.empty?
  return [blocking.length, candidates.empty? ? 0 : 1]
end

# The members of the guilds on the routes (#184): only on a route of their
# guild (W.guild_routes), their Pokémon from its pool. Returns [members,
# trainers of those routes that are no Cousin] for the share over the seeds.
def check_guild_routes(result, atlas, plans, drawn)
  routes = W.guild_routes(result, atlas, GUILDS)
  walkers = drawn.flat_map { |g| g[:routes] }
  walkers.each do |member|
    guild = GUILDS.find { |g| g.id == member[:id] }
    where = "#{member[:map]} : [Trainer #{member[:label]}]"
    raise MapEvents::Error, "#{where} : route hors de la guilde #{guild.id}" if !routes[member[:map]]&.include?(guild)
    raise MapEvents::Error, "#{where} : absent du plan" if plans[member[:map]].events.none? { |e| e.label == member[:label] }
    member[:team].each { |species, _level| raise MapEvents::Error, "#{where} : #{species} hors du pool" if !guild.pool.include?(species) }
  end
  at_hq = drawn.flat_map { |g| g[:members].map { |m| [m[:map], m[:label]] } }
  among = routes.keys.sum do |route|
    (plans[route]&.events || []).count do |e|
      e.kind == :trainer && !e.label.start_with?("Cousin", "Chef") && !at_hq.include?([route, e.label])
    end
  end
  return walkers.length, among
end

# The settings name events and items that exist.
settings = File.join(ROOT, "Plugins", "WorldEvents", "001_Settings.rb")
begin
  DIALOGUES = W.load_dialogues(ROOT)
rescue W::Error => e
  dfile, dline = e.message[/\A(.+?), ligne (\d+)/, 1] ? [$1, $2.to_i] : [W.dialogues_path(ROOT), nil]
  CI.error(dfile, dline, e.message)
  CI.finish("Événements des mondes")
end
roster = E.load_species(ROOT)
begin
  GUILDS = W.load_guilds(ROOT, roster, DIALOGUES)
rescue W::Error => e
  gfile, gline = e.message[/\A(.+?), ligne (\d+)/, 1] ? [$1, $2.to_i] : [W.guilds_path(ROOT), nil]
  CI.error(gfile, gline, e.message)
  CI.finish("Événements des mondes")
end
POOLS = W.guild_pools(GUILDS)
# One guild for each headquarters of MapProc (GUILD_HQS), and its leader
# has a cell in each template of its interior
GUILDS.each do |guild|
  (M::INTERIORS[guild.hq] || []).each do |template, *|
    CI.error(settings, nil, "GUILD_LEADER_SPOTS : gabarit #{template} (QG #{guild.hq}) absent") if !W::GUILD_LEADER_SPOTS[template]
  end
end
# A pool has every intermediate form between two of its species (Combusken
# between Torchic and Blaziken), and whole families
GUILDS.each do |guild|
  guild.pool.each do |id|
    chain = []
    cur = roster[id]&.prevo&.first
    while cur
      chain.push(cur)
      cur = roster[cur]&.prevo&.first
    end
    deepest = chain.rindex { |a| guild.pool.include?(a) }
    gaps = deepest ? chain[0...deepest].reject { |a| guild.pool.include?(a) } : []
    CI.error(W.guilds_path(ROOT), guild.line, "[#{guild.id}] : forme intermédiaire #{gaps.join(', ')} absente du pool (avant #{id})") if !gaps.empty?
  end
  # Whole families: a final form missing would leave the family out of the
  # teams once it is reachable (final_forms)
  families = guild.pool.filter_map { |id| roster[id]&.family }.uniq
  missing = roster.values.select { |sp| families.include?(sp.family) && !guild.pool.include?(sp.id) }.map(&:id)
  CI.error(W.guilds_path(ROOT), guild.line, "[#{guild.id}] : famille incomplète, #{missing.join(', ')} absent(s) du pool") if !missing.empty?
end
GUILDS.group_by(&:hq).each do |hq, list|
  CI.error(W.guilds_path(ROOT), list[1].line, "QG #{hq} de plusieurs guildes (#{list.map(&:id).join(', ')})") if list.length > 1
end
(M::GUILD_HQS.keys - GUILDS.map(&:hq)).each { |kind| CI.error(settings, nil, "GUILD_HQS : QG #{kind} sans guilde dans guildes.txt") }
# HQ_ENEMIES (MapProc) says the « Ennemis » of guildes.txt by headquarters
GUILDS.each do |guild|
  expected = guild.enemies.map { |id| GUILDS.find { |g| g.id == id }.hq }.sort
  next if (M::HQ_ENEMIES[guild.hq] || []).sort == expected
  CI.error(settings, nil, "HQ_ENEMIES[#{guild.hq}] : #{(M::HQ_ENEMIES[guild.hq] || []).sort.join(', ')} au lieu de #{expected.join(', ')} (Ennemis de #{guild.id})")
end
# Enemies are drawn together more often than by chance (#189): over many
# draws with every headquarters possible, how often an enemy of a drawn one
# is there too, against the same draw without HQ_ENEMY_CHANCE
together = [M::HQ_ENEMY_CHANCE, 0].map do |chance|
  hits = 0
  total = 0
  2000.times do |n|
    picks = M.draw_hq_kinds(M::GUILD_HQS.keys, Random.new(n), chance).map(&:first)
    raise "draw_hq_kinds : #{picks.length} QG" if picks.length > M::WORLD_GUILDS.max || picks.uniq != picks
    picks.each do |kind|
      (M::HQ_ENEMIES[kind] || []).each do |enemy|
        total += 1
        hits += 1 if picks.include?(enemy)
      end
    end
  end
  hits * 100.0 / total
end
if together[0] < together[1] + 15
  CI.error(settings, nil, "HQ_ENEMY_CHANCE : ennemis tirés ensemble #{together[0].round} % du temps, #{together[1].round} % au hasard")
end
puts "Ennemis tirés ensemble : #{together[0].round} % (#{together[1].round} % au hasard)"
W::GUILD_LEADER_SPOTS.each do |template, (x, y, _facing)|
  CI.error(settings, nil, "GUILD_LEADER_SPOTS : #{template} #{x},#{y} n'est pas une case libre") if !PASSABLE[template][y]&.[](x)
end
# Every line drawn, by section, to check that none comes back too soon
DRAWN = Hash.new { |hash, section| hash[section] = [] }
W::Lines.prepend(Module.new do
  def draw(section, town = nil)
    super.tap { DRAWN[section].push(@pools[section].length) }
  end
end)
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
guild_types = GUILDS.flat_map { |g| g.member_types + [g.leader] }
(W::TRAINER_TYPES.values.flatten + W::COUSIN_TYPES + W::LEADER_TYPES.values + W::ELDER_TYPES + [W::PARRAIN_TYPE] + guild_types).uniq.each do |type|
  CI.error(settings, nil, "TRAINER_TYPES : type #{type} absent de trainer_types.txt") && next if !ttypes.include?(type.to_s)
  female = W::FEMALE_TYPES.include?(type)
  CI.error(settings, nil, "FEMALE_TYPES : #{type} est #{genders[type.to_s]}") if female != (genders[type.to_s] == "Female")
  %W[Graphics/Trainers/#{type}.png Graphics/Characters/trainer_#{type}.png].each do |file|
    CI.error(settings, nil, "#{type} : #{file} absent") if !File.exist?(File.join(ROOT, file))
  end
end
# The Family's sprites exist only once: never an ordinary trainer, a cousin or an NPC's graphic.
family = CI.read_text(File.join(ROOT, "tools", "art", "family_sprites.rb")).scan(/^\s+\w+:\s+:(\w+)/).flatten
(W::TRAINER_TYPES.values.flatten + W::COUSIN_TYPES + guild_types).each do |type|
  CI.error(settings, nil, "TRAINER_TYPES : #{type} est un sprite de la Famille") if family.include?(type.to_s)
end
W.constants.grep(/GRAPHICS?\z/).flat_map { |c| Array(W.const_get(c)) }.each do |graphic|
  source = graphic.to_s[/\Atrainer_(\w+)\z/, 1]
  CI.error(settings, nil, "#{graphic} : sprite de la Famille") if source && family.include?(source)
end
# [[item, move, type, power, status?]] of every TM, from the PBS files
moves = CI.read_text(File.join(ROOT, "PBS", "moves.txt")).split(/^\[/).drop(1).to_h do |sec|
  [sec[/\A(\w+)/, 1].to_sym, [sec[/^Type\s*=\s*(\w+)/, 1]&.to_sym, sec[/^Power\s*=\s*(\d+)/, 1].to_i, sec[/^Category\s*=\s*Status/] ? true : false]]
end
tms = CI.read_text(File.join(ROOT, "PBS", "items.txt")).split(/^\[/).drop(1).filter_map do |sec|
  move = sec[/^Move\s*=\s*(\w+)/, 1]&.to_sym
  next if !move || !moves[move] || sec !~ /^FieldUse\s*=\s*(TM|HM|TR)\b/
  [sec[/\A(\w+)/, 1].to_sym, move, *moves[move]]
end
DEX = W.load_dex(ROOT)
TM_MOVES = tms.map { |_item, move, *| move }
W::SET_STATUS.each { |move| CI.error(settings, nil, "SET_STATUS : capacité #{move} absente de moves.txt") if !moves[move] }
(W::SET_ITEMS.values.flatten - [:BOOSTER] + W::TYPE_BOOSTERS.values).each do |item|
  CI.error(settings, nil, "SET_ITEMS/TYPE_BOOSTERS : objet #{item} absent de items.txt") if !items.include?(item.to_s)
end
CI.error(settings, nil, "SET_ITEMS : pas de ligne à 0 sceau") if !W::SET_ITEMS[0]
W::TM_STATUS.each { |move| CI.error(settings, nil, "TM_STATUS : capacité #{move} absente de moves.txt") if !moves[move] }
W::TM_POWER_OVERRIDES.each_key { |move| CI.error(settings, nil, "TM_POWER_OVERRIDES : capacité #{move} absente de moves.txt") if !moves[move] }
W::WEATHER_ITEMS.values.flatten.uniq.each do |item|
  CI.error(settings, nil, "WEATHER_ITEMS : objet #{item} absent de items.txt") if !items.include?(item.to_s)
end
W::ARCEUS_BOSS[:moves].each { |move| CI.error(settings, nil, "ARCEUS_BOSS : capacité #{move} absente de moves.txt") if !moves[move] }
ROSTER = roster
# The cells of the houses are walkable, and the people on them cut nobody off
W::HOUSE_SPOTS.each do |template, cells|
  entry = M::INTERIORS.values.flatten(1).find { |t, *| t == template }
  next CI.error(settings, nil, "HOUSE_SPOTS : la carte #{template} n'est pas un gabarit d'intérieur") if !entry
  grid = PASSABLE[template]
  start = [entry[1], entry[2] - 1]
  people = cells.map { |x, y, _facing| [x, y] }
  people.each do |x, y|
    CI.error(settings, nil, "HOUSE_SPOTS : #{template} #{x},#{y} n'est pas une case libre") if !grid[y]&.[](x) || [x, y] == start
  end
  cut = reach(grid, start, []).keys - people - reach(grid, start, people).keys
  CI.error(settings, nil, "HOUSE_SPOTS : #{template}, les habitants coupent #{cut.first(3).inspect}") if !cut.empty?
end
# The pool of items (#331, objets.txt): a format error gives its file and
# line, every table has a line at 0 seals, no shop sells a field item (FIELD_ITEMS,
# Surf, Dive, the Skates...), every weather item is in it with « meteo ».
begin
  W.parse_item_pool("BIDULE commun 0+ sol\n", "objets.txt", items)
  CI.error(settings, nil, "objets.txt : un objet inconnu passe")
rescue W::Error => e
  CI.error(settings, nil, "objets.txt : erreur sans fichier ni ligne (#{e.message})") if !e.message.start_with?("objets.txt, ligne 1 :")
end
begin
  W.item_pool
rescue W::Error => e
  CI.error(W.item_pool_path(ROOT), nil, e.message)
end
field_items = M::FIELD_ITEMS.values.map(&:first) + [M::SURF_ITEM, M::DIVE_ITEM] + M::EXTRA_FIELD_ITEMS.keys + M::NOOKS.values
sold = W.mart_stock(99) & field_items
CI.error(settings, nil, "objets.txt : objets de terrain en boutique (#{sold.join(', ')})") if !sold.empty?
CI.error(settings, nil, "objets.txt : rien en boutique à 0 sceau") if W.mart_stock(0).empty?
{ "sol" => W.item_table, "recoin" => W.nook_table, "revisite" => W.revisit_table }.each do |key, table|
  CI.error(settings, nil, "objets.txt : pas d'objet « #{key} » à 0 sceau") if table[0].nil? || table[0].empty?
end
weather = W.item_pool.select { |item| item.sources.include?("meteo") }.map(&:id)
missing = W::WEATHER_ITEMS.values.flatten.uniq - weather
CI.error(settings, nil, "objets.txt : objets de météo sans « meteo » (#{missing.join(', ')})") if !missing.empty?
# The nurse of each Centre template asks a question (Confirm goes in its first answer)
W::CENTRE_EVENTS.each do |template, events|
  event = load_rxdata(File.join(ROOT, "Data", format("Map%03d.rxdata", template))).instance_variable_get(:@events)[events[0][0]]
  list = event&.instance_variable_get(:@pages)&.first&.instance_variable_get(:@list) || []
  next if list.any? { |c| c.instance_variable_get(:@code) == 402 && c.instance_variable_get(:@parameters)[0] == 0 }
  CI.error(settings, nil, "CENTRE_EVENTS : l'infirmière de la carte #{template} ne pose pas de question")
end
CI.error(settings, nil, "HEART_SCALE : objet #{W::HEART_SCALE} absent de items.txt") if !items.include?(W::HEART_SCALE.to_s)
CI.error(settings, nil, "PACT_INCENSE : objet #{W::PACT_INCENSE} absent de items.txt") if !items.include?(W::PACT_INCENSE.to_s)
CI.error(settings, nil, "MAP_ITEM : objet #{W::MAP_ITEM} absent de items.txt") if !items.include?(W::MAP_ITEM.to_s)
[W::RELEARNER_GRAPHIC, W::FIELD_GRAPHIC, W::ARCEUS_GRAPHIC, W::NURSE_GRAPHIC, *W::GIFT_GRAPHICS].each do |graphic|
  CI.error(settings, nil, "graphisme #{graphic} absent") if !File.exist?(File.join(ROOT, "Graphics", "Characters", "#{graphic}.png"))
end

folder = File.join(ROOT, M::FOLDER)
bricks = Dir.glob(File.join(folder, M::BRICK_FOLDER, "*.txt")).sort.map do |path|
  M.parse_brick(CI.read_text(path), File.basename(path))
end
# For each weather, a world of a type that plays with it: when drawn, its
# items not given by a lieutenant are placed once each, the first ones in
# nooks (up to half of them).
def check_weather(seed, events, worlds)
  # The nooks holding a Heart Scale keep it, so do those to come back to
  # (see W.weather_nooks)
  nooks = events[:items].count { |item| item[:source] == "recoin" && !item[:revisit] && item[:item] != W::HEART_SCALE }
  W::WEATHER_ITEMS.each do |types, list|
    type = types.first
    typed = worlds[type]
    given = typed[:leaders].filter_map { |leader| leader[:tm]&.first }
    expected = W.weather_items(type, Random.new((seed * 1000) + 780)) - given
    placed = typed[:items].select { |item| list.include?(item[:item]) }
    missing = expected - placed.map { |item| item[:item] }
    raise MapEvents::Error, "type #{type} : objets de météo absents (#{missing.join(", ")})" if !missing.empty?
    twice = placed.map { |item| item[:item] }.tally.select { |_item, n| n > 1 }.keys
    raise MapEvents::Error, "type #{type} : objets de météo donnés deux fois (#{twice.join(", ")})" if !twice.empty?
    in_nooks = expected.first((nooks + 1) / 2).reject { |item| placed.any? { |p| p[:item] == item && p[:source] == "recoin" } }
    raise MapEvents::Error, "type #{type} : objets de météo hors des recoins (#{in_nooks.join(", ")})" if !in_nooks.empty?
  end
end

# Pact Incenses: as many as the seed draws (when the world has enough nooks
# and gifts), only in nooks or given by an inhabitant.
def check_pact(seed, events)
  pact = events[:items].select { |item| item[:item] == W::PACT_INCENSE }
  wrong = pact.reject { |item| %w[recoin don].include?(item[:source]) }
  raise MapEvents::Error, "Encens du Pacte hors des recoins et des dons (#{wrong.map { |i| i[:map] }.join(", ")})" if !wrong.empty?
  drawn = Random.new((seed * 1000) + 790).rand(W::PACT_INCENSES)
  raise MapEvents::Error, "#{pact.length} Encens du Pacte au lieu de #{drawn}" if pact.length > drawn
end

count = 0
pact_total = 0
guild_fields = 0
gym_statues = []
guild_walkers = 0
guild_among = 0
rewards = Hash.new(0)
freed = 0
blockades = 0
blockable = 0
enemy_pairs = 0
settled = 0
revisits = [0, 0, 0]
Dir.glob(File.join(folder, "*.txt")).sort.select { |path| M.world_file?(path) }.each do |path|
  world = M.parse_world(CI.read_text(path), File.basename(path))
  town, route = [world.town_file, world.route_file].map do |name|
    M.parse_place(CI.read_text(File.join(folder, name)), name)
  end
  WORLD_SEEDS.each do |seed|
    where = "#{File.basename(path)} (graine #{seed})"
    result = M.generate_world(world, town, route, bricks, seed)
    atlas = M.world_atlas(result)
    zones = E.world_zones(result, E::CAPS, POOLS)
    lines, generated = E.world_encounters(result, roster, E::CAPS, seed, POOLS)
    begin
      check_dungeon_encounters(result, zones, lines, generated, seed, roster)
    rescue MapEvents::Error => e
      CI.error(path, nil, "#{where} : #{e.message}")
    end
    args = { zones: zones, encounters: generated, species: roster, tms: tms, caps: E::CAPS, dialogues: DIALOGUES, dex: DEX,
             guilds: GUILDS }
    DRAWN.clear
    events = W.world_events(result, seed, **args)
    drawn = DRAWN.transform_values(&:dup)
    if W.world_events(result, seed, **args) != events
      CI.error(path, nil, "#{where} : la même graine donne d'autres événements")
    end
    plans = {}
    events[:plans].each do |name, text|
      plans[name] = MapEvents.parse(text, "#{where}, #{name}")
      spots = atlas[:maps][name]
      raise MapEvents::Error, "#{name} : carte absente de l'inventaire" if !spots
      # The gates of the first town, the members of a blocking headquarters
      gates = (name == atlas[:start]) ? W.gate_cells(spots[:exits]) : []
      # The closed exit of a dungeon (its exit itself in a guild of rooms')
      gates += spots[:locks] || W.gate_cells([spots[:exits][0]]) if spots[:gates]
      gates += events[:guilds].filter_map { |g| g[:blocks] && g[:blocks][:route] == name && g[:blocks][:cells] }.flatten(1)
      check_cells(plans[name], spots, gates)
    rescue MapEvents::Error => e
      CI.error(path, nil, "#{where} : #{e.message}")
    end
    begin
      check_start(atlas, plans)
      check_services(atlas, plans)
      check_gyms(atlas, plans, events[:leaders], tms)
      gym_statues.concat(events[:leaders].map { |l| l[:statues] })
      # The right hands of the showdowns fight only there (check_showdowns)
      seconds = events[:guilds].filter_map { |g| g[:showdown] && "[#{g[:showdown][:foes][1][0]},#{g[:showdown][:foes][1][1]}," }
      check_trainers(result, zones.to_h { |z| [z.name, z] }, plans, events[:trainers].reject { |sec| sec.start_with?(*seconds) },
                     species, ttypes)
      check_map_giver(atlas, plans)
      check_league(atlas, plans, events[:league], events[:leaders])
      check_sets(events[:leaders] + events[:league] + guild_fights(events[:guilds]), atlas[:gyms].length, items)
      check_guilds(result, atlas, zones.to_h { |z| [z.name, z] }, plans, events[:guilds], bricks)
      freed += check_liberations(result, atlas, plans, events[:guilds])
      settled += check_showdowns(atlas, plans, events[:guilds], events[:trainers])
      enemy_pairs += check_rivalries(world, result, atlas, plans, events[:guilds], items)
      blocked, possible = check_blockades(result, atlas, zones.to_h { |z| [z.name, z] }, plans, events[:guilds])
      blockades += blocked
      blockable += possible
      walkers, among = check_guild_routes(result, atlas, plans, events[:guilds])
      guild_walkers += walkers
      guild_among += among
      check_lines(drawn)
      check_habitants(result, atlas, plans)
      # The field items of the guilds given at their headquarters (#274)
      sourced = atlas.merge(items: events[:sources])
      guild_fields += check_guild_field_items(atlas, sourced, events[:guilds], plans)
      check_items(sourced, zones.to_h { |z| [z.name, z] }, plans, events[:items])
      # The same world under several imposed types (those of the weathers)
      worlds = W::WEATHER_ITEMS.keys.to_h { |types| [types.first, W.world_events(result, seed, **args, type: types.first)] }
      check_weather(seed, events, worlds)
      worlds.merge(nil => events).each do |type, typed|
        typed_plans = typed[:plans].to_h { |name, text| [name, MapEvents.parse(text, "#{where}, #{name}")] }
        nooks, pokemon, lore = check_revisits(atlas, zones.to_h { |z| [z.name, z] }, typed_plans, type, roster, tms)
        # The nooks once a world: its imposed types draw them again with the same dice
        revisits[0] += nooks if !type
        revisits[1] += pokemon
        revisits[2] += lore
        check_rewards(result, sourced, typed_plans, typed[:guilds], type, items).compact.each { |kind| rewards[kind] += 1 }
      end
      type = worlds.keys.first
      if W.world_events(result, seed, **args, type: type)[:guilds].map { |g| g[:reward] } != worlds[type][:guilds].map { |g| g[:reward] }
        raise MapEvents::Error, "type #{type} : la même graine et le même type donnent d'autres récompenses de guilde"
      end
      check_pact(seed, events)
      pact_total += events[:items].count { |item| item[:item] == W::PACT_INCENSE }
    rescue MapEvents::Error => e
      CI.error(path, nil, "#{where} : #{e.message}")
    end
    count += 1
  rescue M::Error => e
    CI.error(path, nil, "#{where} : #{e.message}")
  end
end

# About one trainer in three on the routes of the guilds is a member
share = guild_among.zero? ? 0 : (guild_walkers * 100.0 / guild_among).round
if guild_among >= 30 && !((W::GUILD_ROUTE_CHANCE - 15)..(W::GUILD_ROUTE_CHANCE + 15)).cover?(share)
  CI.error(settings, nil, "GUILD_ROUTE_CHANCE : #{share} % de membres de guilde sur leurs routes (#{guild_walkers}/#{guild_among})")
end
# A share of the nooks to come back to holds a Pokémon, another a trace: in
# the worlds (once 20 nooks are drawn), and on 40 nooks of one draw
nooks, pokemon, lore = revisits
puts "Recoins à revisiter : #{nooks}, dont #{pokemon} Pokémon et #{lore} traces du Pacte (sous tous les types)"
slots = Array.new(40) { { revisit: true, seals: 0 } }
zone = Struct.new(:seals, :levels).new(0, [10, 20])
W.revisit_loot(slots, { "zone" => zone }, { species: roster, type: :WATER, caps: E::CAPS, rng: Random.new(1) })
if slots.none? { |slot| slot[:pokemon] } || slots.none? { |slot| slot[:lore] }
  CI.error(settings, nil, "REVISIT_POKEMON, REVISIT_LORE : #{slots.count { |slot| slot[:pokemon] }} Pokémon et " \
                          "#{slots.count { |slot| slot[:lore] }} traces du Pacte dans 40 recoins")
end
if nooks >= 20
  CI.error(settings, nil, "REVISIT_POKEMON : aucun Pokémon dans #{nooks} recoins à revisiter") if pokemon.zero?
  CI.error(settings, nil, "REVISIT_LORE : aucune trace du Pacte dans #{nooks} recoins à revisiter") if lore.zero?
end
puts "Récompenses des guildes : #{rewards.sort.map { |kind, n| "#{n} #{kind}" }.join(', ')} ; #{freed} zones libérées"
puts "Paires de guildes ennemies dans les mondes : #{enemy_pairs}, #{settled} règlements de comptes"
puts "QG bloquants : #{blockades} sur #{blockable} mondes qui en permettent un"
puts "Objets de terrain donnés par un chef de guilde : #{guild_fields}"
puts "Arènes à statues : #{gym_statues.count(&:positive?)} sur #{gym_statues.length}, #{gym_statues.sum} statues"
puts "#{count} mondes, graines #{WORLD_SEEDS}, #{pact_total} Encens du Pacte, #{guild_walkers}/#{guild_among} membres de guilde sur leurs routes (#{share} %)"
CI.finish("Événements des mondes")
