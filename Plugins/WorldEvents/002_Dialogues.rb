#===============================================================================
# WorldEvents - Dialogues
# The texts of the events, read from MapProc/Lore/dialogues.txt: one section
# per role, one line per reply (« | » cuts it into several message boxes).
# Each NPC draws a line of its section, never twice in a world while some are
# left. Plain Ruby, except the replies said in game (say, line).
#===============================================================================
module WorldEvents
  class Error < StandardError; end

  # Draws the lines of a world, with its tokens filled.
  class Lines
    def initialize(sections, region, rng)
      @sections = sections
      @region = region
      @rng = rng
      @pools = {}
    end

    # A line of that section (« | » kept), never the same twice while the
    # section has others left. town: the NPC's town (or place).
    def draw(section, town = nil)
      pool = (@pools[section] ||= [])
      pool.concat(@sections[section].shuffle(random: @rng)) if pool.empty?
      return WorldEvents.fill(pool.shift, "ville" => town, "region" => @region)
    end

    # The same in one piece (for a trainer's comments and lose text).
    def text(section, town = nil)
      return draw(section, town).gsub(/\s*\|\s*/, " ")
    end

    # The same, one message box each.
    def boxes(section, town = nil)
      return draw(section, town).split(/\s*\|\s*/)
    end
  end

  module_function

  # { section => [lines] }, raising Error (file, line) on an unknown section,
  # a token unknown or not allowed in its section, a section missing or empty.
  def parse_dialogues(text, file)
    sections = {}
    section = nil
    text.sub(/\A﻿/, "").each_line.with_index(1) do |raw, lineno|
      line = raw.strip
      next if line.empty? || line.start_with?("#")
      fail_at = ->(msg) { raise Error, "#{file}, ligne #{lineno} : #{msg}" }
      if line =~ /\A\[(.+)\]\z/
        section = $1
        fail_at.call("section [#{section}] inconnue (#{DIALOGUE_SECTIONS.keys.join(', ')})") if !DIALOGUE_SECTIONS[section]
        fail_at.call("section [#{section}] en double") if sections[section]
        sections[section] = []
        next
      end
      fail_at.call("réplique hors d'une section") if !section
      line.scan(/\{([^}]*)\}/).flatten.each do |token|
        next if DIALOGUE_SECTIONS[section].include?(token)
        allowed = DIALOGUE_SECTIONS[section].map { |t| "{#{t}}" }.join(", ")
        fail_at.call("jeton {#{token}} inconnu ou interdit dans [#{section}] (#{allowed.empty? ? 'aucun' : allowed})")
      end
      sections[section].push(line)
    end
    missing = DIALOGUE_SECTIONS.keys.select { |key| !sections[key] || sections[key].empty? }
    raise Error, "#{file} : sections absentes ou vides : #{missing.join(', ')}" if !missing.empty?
    return sections
  end

  def dialogues_path(root = ".")
    return File.join(root, MapProceduralGenerator::FOLDER, DIALOGUES_FILE)
  end

  def load_dialogues(root = ".")
    path = dialogues_path(root)
    return parse_dialogues(File.read(path, encoding: "UTF-8"), path)
  end

  # The line with its tokens: {joueur} = the player's name (\PN), the others
  # from values (a missing one left as it is).
  def fill(line, values = {})
    return line.gsub(/\{(\w+)\}/) do
      token = $1
      (token == "joueur") ? "\\PN" : (values[token] || "{#{token}}")
    end
  end

  # The name of the region of a world (its « World » line).
  def region_name(result)
    return result.text[/^World\s*=\s*(.+?)\s*$/, 1]
  end

  #-----------------------------------------------------------------------------
  # In game
  #-----------------------------------------------------------------------------
  # A line of that section drawn at random, {type} = the imposed type.
  def line(section)
    @dialogues ||= load_dialogues
    text = @dialogues[section].sample
    type = defined?(Monotype) ? Monotype.type_name : nil
    return fill(text, "type" => type)
  end

  # Says a line of that section, one message box each « | ».
  def say(section)
    line(section).split(/\s*\|\s*/).each { |box| pbMessage(box) }
  end
end
