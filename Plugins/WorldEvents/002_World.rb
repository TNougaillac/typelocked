#===============================================================================
# WorldEvents - Drawing the events of a world
# Plain Ruby (no game window): from the world drawn by MapProceduralGenerator
# and its seed, the MapEvents plan of each map that has events. The CI
# (tools/ci/check_world_events.rb) checks what it returns.
#===============================================================================
module WorldEvents
  module_function

  # { plans: { map name => MapEvents plan text } }
  def world_events(result, seed)
    atlas = MapProceduralGenerator.world_atlas(result)
    rng = Random.new((seed * 1000) + 700)
    plans = Hash.new { |hash, name| hash[name] = [] }
    start_events(atlas, plans, rng)
    return { plans: plans.to_h { |name, sections| [name, plan_text(name, sections)] } }
  end

  def plan_text(name, sections)
    return "Map = #{name}\n" + sections.map { |section| "\n#{section}" }.join
  end

  # One [Kind label] section: lines are [key, value] pairs.
  def section(kind, label, x, y, *lines)
    return "[#{kind} #{label}]\nPos = #{x},#{y}\n" + lines.map { |key, value| "#{key} = #{value}\n" }.join
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
      plans[lab].push(section("Npc", "Professeur", *LAB_PROFESSOR, ["Graphic", PROFESSOR_GRAPHIC],
                              ["Script", "WorldEvents.professor(true)"]))
      LAB_BALLS.each_with_index do |(x, y), i|
        plans[lab].push(section("Npc", "Ball#{i + 1}", x, y, ["Graphic", BALL_GRAPHIC], ["Hide", "A"],
                                ["Script", "pbSetSelfSwitch(@event_id, \"A\", true) if WorldEvents.starter_ball(#{i})"]))
      end
    elsif spots[:professor]
      plans[start].push(section("Npc", "Professeur", *spots[:professor], ["Graphic", PROFESSOR_GRAPHIC],
                                ["Script", "WorldEvents.professor(false)"]))
    end
    gate_cells(spots[:exits]).each_with_index do |(x, y), i|
      plans[start].push(section("Npc", "Garde#{i + 1}", x, y, ["Trigger", "contact"],
                                ["Hide", "V#{STARTER_VARIABLE}>=1"], ["Script", "WorldEvents.gate"]))
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
end
