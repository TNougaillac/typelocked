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
%w[001_Settings 002_Parser 003_Builder 004_World 006_Caves 008_Names 009_Atlas 010_CavePainter 011_Interiors 013_Fillers].each { |f| require File.join(ROOT, "Plugins", "MapProceduralGenerator", f) }
%w[001_Settings 002_Parser].each { |f| require File.join(ROOT, "Plugins", "MapEvents", f) }
%w[001_Settings 002_Species 003_Tables 004_World].each { |f| require File.join(ROOT, "Plugins", "ProceduralEncounters", f) }
%w[001_Settings 002_Dialogues 003_World 004_Trainers 005_Gyms 006_Sets 007_Items].each { |f| require File.join(ROOT, "Plugins", "WorldEvents", f) }
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
    if !tm || !W.useful_tms(tms, drawn[:type], drawn[:gym] - 1).include?(tm)
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

# Every nook has its loot, every field item is given in its town once its
# lieutenant is beaten, the Heart Scales reach their number, a Move
# Relearner stands in a town reached before the 2nd seal, gifts are given
# once and reach their share.
def check_items(atlas, zones, plans, items)
  loot = Hash.new(0)
  plans.each { |name, plan| loot[name] = plan.events.count { |e| e.kind == :item && e.label.start_with?("Recoin") } }
  atlas[:maps].each do |name, spots|
    nooks = (spots[:nooks] || []).count { |_x, _y, kind, *| kind != "sombre" }
    nooks = 1 if spots[:dark] && spots[:loot]
    raise MapEvents::Error, "#{name} : #{loot[name]} butins pour #{nooks} recoins" if loot[name] != nooks
  end
  atlas[:items].each do |item, town|
    npc = plans[town]&.events&.find { |e| e.kind == :npc && e.value("Gift") == item.to_s }
    raise MapEvents::Error, "#{town} : personne ne donne #{item}" if !npc
    gym = atlas[:gyms].index(town)
    if gym && npc.value("When") != "S#{W::GYM_SWITCH + gym + 1}"
      raise MapEvents::Error, "#{town} : #{item} donné sans attendre le sceau de la ville (#{npc.value('When')})"
    end
  end
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
    has = fight[:gym] ? fight[:gym] - 1 : seals
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

# The settings name events and items that exist.
settings = File.join(ROOT, "Plugins", "WorldEvents", "001_Settings.rb")
begin
  DIALOGUES = W.load_dialogues(ROOT)
rescue W::Error => e
  dfile, dline = e.message[/\A(.+?), ligne (\d+)/, 1] ? [$1, $2.to_i] : [W.dialogues_path(ROOT), nil]
  CI.error(dfile, dline, e.message)
  CI.finish("Événements des mondes")
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
(W::TRAINER_TYPES.values.flatten + W::COUSIN_TYPES + W::LEADER_TYPES.values + W::ELDER_TYPES + [W::PARRAIN_TYPE]).uniq.each do |type|
  CI.error(settings, nil, "TRAINER_TYPES : type #{type} absent de trainer_types.txt") && next if !ttypes.include?(type.to_s)
  female = W::FEMALE_TYPES.include?(type)
  CI.error(settings, nil, "FEMALE_TYPES : #{type} est #{genders[type.to_s]}") if female != (genders[type.to_s] == "Female")
  %W[Graphics/Trainers/#{type}.png Graphics/Characters/trainer_#{type}.png].each do |file|
    CI.error(settings, nil, "#{type} : #{file} absent") if !File.exist?(File.join(ROOT, file))
  end
end
# The Family's sprites exist only once: never an ordinary trainer, a cousin or an NPC's graphic.
family = CI.read_text(File.join(ROOT, "tools", "art", "family_sprites.rb")).scan(/^\s+\w+:\s+:(\w+)/).flatten
(W::TRAINER_TYPES.values.flatten + W::COUSIN_TYPES).each do |type|
  CI.error(settings, nil, "TRAINER_TYPES : #{type} est un sprite de la Famille") if family.include?(type.to_s)
end
W.constants.grep(/GRAPHICS?\z/).flat_map { |c| Array(W.const_get(c)) }.each do |graphic|
  source = graphic.to_s[/\Atrainer_(\w+)\z/, 1]
  CI.error(settings, nil, "#{graphic} : sprite de la Famille") if source && family.include?(source)
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
W::MART_STOCK.values.flatten.each { |item| CI.error(settings, nil, "MART_STOCK : objet #{item} absent de items.txt") if !items.include?(item.to_s) }
{ "ITEM_TABLE" => W::ITEM_TABLE, "NOOK_TABLE" => W::NOOK_TABLE }.each do |key, table|
  CI.error(settings, nil, "#{key} : pas de ligne à 0 sceau") if !table[0]
  table.values.flat_map(&:keys).uniq.each do |item|
    CI.error(settings, nil, "#{key} : objet #{item} absent de items.txt") if item != :TM && !items.include?(item.to_s)
  end
end
# The nurse of each Centre template asks a question (Confirm goes in its first answer)
W::CENTRE_EVENTS.each do |template, events|
  event = load_rxdata(File.join(ROOT, "Data", format("Map%03d.rxdata", template))).instance_variable_get(:@events)[events[0][0]]
  list = event&.instance_variable_get(:@pages)&.first&.instance_variable_get(:@list) || []
  next if list.any? { |c| c.instance_variable_get(:@code) == 402 && c.instance_variable_get(:@parameters)[0] == 0 }
  CI.error(settings, nil, "CENTRE_EVENTS : l'infirmière de la carte #{template} ne pose pas de question")
end
CI.error(settings, nil, "HEART_SCALE : objet #{W::HEART_SCALE} absent de items.txt") if !items.include?(W::HEART_SCALE.to_s)
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
def check_weather(result, seed, args, events)
  nooks = events[:items].count { |item| item[:source] == "recoin" }
  W::WEATHER_ITEMS.each do |types, list|
    type = types.first
    typed = W.world_events(result, seed, **args, type: type)
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
    args = { zones: zones, encounters: generated, species: roster, tms: tms, caps: E::CAPS, dialogues: DIALOGUES, dex: DEX }
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
      check_map_giver(atlas, plans)
      check_league(atlas, plans, events[:league], events[:leaders])
      check_sets(events[:leaders] + events[:league], atlas[:gyms].length, items)
      check_lines(drawn)
      check_habitants(result, atlas, plans)
      check_items(atlas, zones.to_h { |z| [z.name, z] }, plans, events[:items])
      check_weather(result, seed, args, events)
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
