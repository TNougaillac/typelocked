#===============================================================================
# WorldEvents - Drawing the events of a world
# Plain Ruby (no game window): from the world drawn by MapProceduralGenerator
# and its seed, the MapEvents plan of each map that has events. The CI
# (tools/ci/check_world_events.rb) checks what it returns.
#===============================================================================
module WorldEvents
  module_function

  # { plans: { map name => MapEvents plan text }, trainers: [sections of
  # PBS/trainers.txt], leaders: [the lieutenants, see gym_events], league:
  # [its fights, see league_events], items: [the items, see item_events] }.
  # zones and encounters: ProceduralEncounters' world_zones and
  # world_encounters (its second value) of that world, for the trainers;
  # species (the roster), tms ([[item, move, type, power, status?]]) and
  # caps (level cap by seals), for the gyms; zones and tms, for the items.
  # Without them, none. dialogues: parse_dialogues of dialogues.txt (read
  # from the game's folder when nil); dex: load_dex (the same), for the
  # sets of the lieutenants and of the League. type: the imposed type, for
  # its weather items (nil: none).
  def world_events(result, seed, zones: nil, encounters: nil, species: nil, tms: nil, caps: nil, dialogues: nil, dex: nil,
                   type: nil)
    atlas = MapProceduralGenerator.world_atlas(result)
    rng = Random.new((seed * 1000) + 700)
    lines = Lines.new(dialogues || load_dialogues, region_name(result), Random.new((seed * 1000) + 750))
    plans = Hash.new { |hash, name| hash[name] = [] }
    start_events(atlas, plans, rng)
    service_events(atlas, seals_at(result), plans)
    trainers = []
    leaders = []
    league = []
    names = Hash.new { |hash, trainer_type| hash[trainer_type] = [] }
    if species && tms && caps
      sets = Sets.new(dex || load_dex, tms, Random.new((seed * 1000) + 770))
      leaders = gym_events(atlas, species, tms, caps, plans, trainers, names, lines, sets, Random.new((seed * 1000) + 720))
      league = league_events(atlas, species, caps, plans, trainers, names, lines, sets, Random.new((seed * 1000) + 740))
    end
    if zones && encounters
      trainer_events(result, atlas, zones, encounters, plans, trainers, names, lines, Random.new((seed * 1000) + 710))
    end
    if zones && tms
      weather = weather_items(type, Random.new((seed * 1000) + 780))
      items = item_events(result, atlas, zones, tms, leaders, weather, plans, lines, Random.new((seed * 1000) + 730))
    end
    habitant_events(result, atlas, plans, lines, Random.new((seed * 1000) + 760))
    return { plans: plans.to_h { |name, events| [name, plan_text(name, events)] }, trainers: trainers, leaders: leaders,
             league: league, items: items || [] }
  end

  def plan_text(name, events)
    return "Map = #{name}\n" + events.map { |_x, _y, text| "\n#{text}" }.join
  end

  # Adds a [Kind label] section on that map: lines are [key, value] pairs.
  def add(plans, name, kind, label, x, y, *lines)
    text = "[#{kind} #{label}]\nPos = #{x},#{y}\n" + lines.map { |key, value| "#{key} = #{value}\n" }.join
    plans[name].push([x, y, text])
  end

  # Seals won on the way to each place, by name: the lieutenants of the
  # chain before it (an island counts as its port).
  def seals_at(result)
    gyms = result.places.filter_map { |wp, *| wp.index if wp.gym } +
           (result.islands || []).filter_map { |wp, *| wp.index if wp.gym }
    seals = result.places.to_h { |wp, *| [wp.name, gyms.count { |i| i < wp.index }] }
    (result.islands || []).each { |wp, port, *| seals[wp.name] = seals[port.name] || gyms.count { |i| i < wp.index } }
    return seals
  end

  # Stock of a shop with that many seals.
  def mart_stock(seals)
    return MART_STOCK.select { |from, _items| from <= seals }.values.flatten
  end

  #-----------------------------------------------------------------------------
  # Pokémon Centres and shops
  #-----------------------------------------------------------------------------
  def service_events(atlas, seals, plans)
    atlas[:maps].each do |name, map|
      next if map[:kind] != "interieur"
      if (events = CENTRE_EVENTS[map[:template]])
        events.each_with_index do |(id, x, y), i|
          add(plans, name, "Copy", CENTRE_LABELS[i], x, y, ["From", "#{map[:template]},#{id}"])
        end
      elsif (clerk = MART_CLERK[map[:template]]) && map[:building] == "boutique"
        add(plans, name, "Npc", "Vendeur", *clerk, ["Graphic", CLERK_GRAPHIC],
            ["Script", "WorldEvents.mart(#{seals[map[:owner]] || 0})"])
      end
    end
  end

  #-----------------------------------------------------------------------------
  # The first town: the professor (in the lab, else outside) and its gate
  #-----------------------------------------------------------------------------
  def start_events(atlas, plans, _rng)
    start = atlas[:start]
    return if !start
    spots = atlas[:maps][start]
    lab = atlas[:lab] && atlas[:maps].find do |_name, map|
      map[:building] == MapProceduralGenerator::LAB && map[:owner] == start
    end&.first
    if lab
      add(plans, lab, "Npc", "Professeur", *LAB_PROFESSOR, ["Graphic", PROFESSOR_GRAPHIC],
          ["Script", "WorldEvents.professor(true)"])
      LAB_BALLS.each_with_index do |(x, y), i|
        add(plans, lab, "Npc", "Ball#{i + 1}", x, y, ["Graphic", BALL_GRAPHIC], ["Hide", "A"],
            ["Script", "pbSetSelfSwitch(@event_id, \"A\", true) if WorldEvents.starter_ball(#{i})"])
      end
    elsif spots[:professor]
      add(plans, start, "Npc", "Professeur", *spots[:professor], ["Graphic", PROFESSOR_GRAPHIC],
          ["Script", "WorldEvents.professor(false)"])
    end
    gate_cells(spots[:exits]).each_with_index do |(x, y), i|
      add(plans, start, "Npc", "Garde#{i + 1}", x, y, ["Trigger", "contact"],
          ["Hide", "V#{STARTER_VARIABLE}>=1"], ["Script", "WorldEvents.gate"])
    end
  end

  # The inner row of each exit (as wide as a street): stepping on it sends
  # the player back.
  def gate_cells(exits)
    width = MapProceduralGenerator::STREET_WIDTH
    return exits.flat_map do |side, x, y|
      case side
      when "nord"  then Array.new(width) { |i| [x + i, y + width - 1] }
      when "sud"   then Array.new(width) { |i| [x + i, y] }
      when "ouest" then Array.new(width) { |i| [x + width - 1, y + i] }
      when "est"   then Array.new(width) { |i| [x, y + i] }
      end
    end
  end

  #-----------------------------------------------------------------------------
  # Inhabitants: by the streets of the towns, in the houses
  #-----------------------------------------------------------------------------
  def habitant_events(result, atlas, plans, lines, rng)
    towns = result.places.filter_map { |wp, *| wp.name if wp.kind == "ville" && wp.name != atlas[:start] } +
            (result.islands || []).map { |wp, *| wp.name }
    towns.each do |town|
      spots = atlas[:maps][town]
      rng.rand(TOWN_HABITANTS).times do |i|
        cell = item_cell(spots, npc_cells(spots, rng), plans[town])
        break if !cell
        police = rng.rand(100) < POLICE_CHANCE
        habitant(plans, town, "Habitant#{i + 1}", cell, spots[:title], lines, rng, police: police)
      end
    end
    atlas[:maps].each do |name, map|
      cells = HOUSE_SPOTS[map[:template]]
      next if map[:kind] != "interieur" || !HOUSE_BUILDINGS.include?(map[:building]) || !cells
      cells.shuffle(random: rng).first(rng.rand(HOUSE_HABITANTS)).each_with_index do |cell, i|
        habitant(plans, name, "Habitant#{i + 1}", cell, map[:title], lines, rng)
      end
    end
  end

  # police: a policeman, with the lines of [policier].
  def habitant(plans, map, label, cell, town, lines, rng, police: false)
    x, y, facing = cell
    graphic = police ? POLICE_GRAPHIC : GIFT_GRAPHICS.sample(random: rng)
    add(plans, map, "Npc", label, x, y, ["Graphic", graphic], ["Facing", facing],
        *lines.boxes(police ? "policier" : "habitant", town).map { |box| ["Text", box] })
  end
end
