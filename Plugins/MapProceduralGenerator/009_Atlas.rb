#===============================================================================
# MapProceduralGenerator - Inventory of a world (atlas)
# Each generated world keeps where things can go on each of its maps (exits,
# doors and their building type, free cells beside the streets, tall grass,
# dead ends...) and, for the whole world, its start and the order of its gyms.
# MapEvents and the other plugins place their events from it. Saved with the
# maps (ATLAS_FILE) and exported as text next to the world plan
# (MapProc/Export/<world>_<seed>_inventaire.txt).
# In game: MapProceduralGenerator.spots(map_id), MapProceduralGenerator.atlas.
#===============================================================================
module MapProceduralGenerator
  ATLAS_FILE = "Data/MapProcAtlas.rxdata"

  module_function

  # Inventory of a world by map name:
  #   { start:, lab: (the start if it has the lab), gyms: [names in the order
  #     they are beaten], surf:, dive:, victory: (the Victory Road), league:
  #     [the rooms of the League, in order], items: { field item => town },
  #     maps: { name => { kind:, title:, exits:, doors:, street:, grass:, dead_ends: ... } } }
  def world_atlas(result)
    places = result.places.sort_by { |wp, *| wp.index }
    islands = result.islands || []
    maps = {}
    places.each { |wp, _place, _text, layout| maps[wp.name] = map_spots(wp.kind, wp.title, layout.spots) }
    islands.each { |wp, _port, _place, _text, layout| maps[wp.name] = map_spots("ile", wp.title || wp.name, layout.spots) }
    # Each door of a building names its interior: [x, y, type, interior]. A
    # room of the League names its role and its door to the next room
    # (onward: [x, y, next room]).
    interiors = result.interiors || []
    interiors.each do |it|
      owner = maps[it.owner]
      door = it.door && owner[:doors].find { |x, y, _kind| [x, y] == it.door }
      door[3] = it.name if door
      maps[it.name] = { kind: "interieur", title: owner[:title], building: it.kind, template: it.template,
                        owner: it.owner, exits: it.exit ? [[*it.exit, it.owner]] : [], door: it.door&.dup,
                        arrival: it.arrival.dup, role: it.role, onward: it.onward&.first(3) }
    end
    # A cave floor: exits ([x, y, route]), ladders, floor cells, its far end
    result.caves.each do |wp, name, _text, floor|
      maps[name] = map_spots("grotte", floor.dark ? wp.title : wp.cave_title || name, floor.spots).merge(level: floor.level)
      maps[name][:dark] = true if floor.dark
    end
    gyms = []
    places.each do |wp, *|
      gyms.push(wp.name) if wp.gym
      # An island's gym comes right after its port
      gyms.push(wp.island) if wp.island_gym && islands.any? { |iwp, *| iwp.name == wp.island }
    end
    start = places.find { |wp, *| wp.kind == "ville" }
    # The lab of the first town, else where the professor waits outside: the
    # free cell by a street closest to the Pokémon Centre's door
    lab = start && start[3].doors.find { |_x, _y, brick| brick.kind == LAB }
    if start && !lab
      spots = maps[start[0].name]
      cx, cy = (spots[:doors].find { |_x, _y, kind| kind == "centre" } || spots[:doors].first || spots[:exits].first[1, 2])
      spots[:professor] = spots[:street].min_by { |x, y| [(x - cx).abs + (y - cy - 1).abs, y, x] }
    end
    return { start: start && start[0].name, lab: lab && start[0].name, gyms: gyms,
             victory: places.find { |wp, *| wp.victory }&.first&.name,
             items: field_towns(places),
             league: interiors.select(&:role).map(&:name),
             surf: places.find { |wp, *| wp.surf }&.first&.name,
             dive: places.find { |wp, *| wp.dive }&.first&.name, maps: maps }
  end

  # Town where each field item is obtained: { item => name }
  def field_towns(places)
    towns = {}
    places.each do |wp, *|
      (wp.items || []).each { |item| towns[item] = wp.name }
      towns[SURF_ITEM] = wp.name if wp.surf
      towns[DIVE_ITEM] = wp.name if wp.dive
    end
    return towns
  end

  def map_spots(kind, title, spots)
    # A copy: the world's inventory is completed without touching the layouts
    return { kind: kind, title: title }.merge(Marshal.load(Marshal.dump(spots || {})))
  end

  # The same inventory with map IDs in place of map names (names left out
  # when a map has no ID).
  def atlas_by_id(atlas, map_ids)
    id = ->(name) { map_ids[name] || name }
    return atlas.merge(start: atlas[:start] && id.call(atlas[:start]),
                       lab: atlas[:lab] && id.call(atlas[:lab]),
                       gyms: atlas[:gyms].map(&id),
                       victory: atlas[:victory] && id.call(atlas[:victory]),
                       league: atlas[:league].map(&id),
                       items: atlas[:items].transform_values(&id),
                       surf: atlas[:surf] && id.call(atlas[:surf]),
                       dive: atlas[:dive] && id.call(atlas[:dive]),
                       maps: atlas[:maps].to_h { |name, spots| [id.call(name), spots.merge(name: name)] })
  end

  # Text export, one section per map, to read or check the inventory.
  def atlas_text(atlas, map_ids = {})
    label = ->(name) { map_ids[name] ? sprintf("%03d %s", map_ids[name], name) : name }
    text = +"# Inventaire du monde, écrit par MapProceduralGenerator.\n"
    text << "Depart = #{atlas[:start] && label.call(atlas[:start])}\n"
    text << "Labo   = #{atlas[:lab] ? 'oui' : 'non (professeur dehors)'}\n"
    text << "Arenes = #{atlas[:gyms].map(&label).join(', ')}\n"
    text << "Victoire = #{label.call(atlas[:victory])}\n" if atlas[:victory]
    atlas[:items].each { |item, town| text << "#{item} = #{label.call(town)}\n" }
    text << "Ligue  = #{atlas[:league].map(&label).join(', ')}\n" if !atlas[:league].empty?
    text << "Surf   = #{atlas[:surf]}\n" if atlas[:surf]
    text << "Plongee = #{atlas[:dive]}\n" if atlas[:dive]
    atlas[:maps].each do |name, spots|
      text << "\n[#{label.call(name)}]\n"
      spots.each do |key, value|
        next if value.nil? || (value.respond_to?(:empty?) && value.empty?) || key == :ground
        text << "#{key} = #{atlas_value(value)}\n"
      end
    end
    return text
  end

  def atlas_value(value)
    return value.to_s if !value.is_a?(Array)
    return value.map { |v| v.is_a?(Array) ? v.join(",") : v.to_s }.join(" ")
  end

  #-----------------------------------------------------------------------------
  # In game
  #-----------------------------------------------------------------------------
  # Inventory of the world on disk (by map ID), {} if none.
  def atlas
    @atlas ||= File.exist?(ATLAS_FILE) ? load_data(ATLAS_FILE) : {}
    return @atlas
  end

  # Inventory of that map ({ kind:, title:, name:, exits:, doors:, ... }), nil
  # if it is not a map of the generated world.
  def spots(map_id)
    return atlas[:maps]&.[](map_id)
  end

  # The cells walked on (ground) are only for drawing the world's events.
  def save_atlas(atlas, map_ids)
    atlas = atlas.merge(maps: atlas[:maps].transform_values { |spots| spots.except(:ground) })
    @atlas = atlas_by_id(atlas, map_ids)
    save_data(@atlas, ATLAS_FILE)
  end

  def forget_atlas
    @atlas = nil
    delete_file(ATLAS_FILE)
  end
end
