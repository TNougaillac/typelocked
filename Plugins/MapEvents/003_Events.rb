#===============================================================================
# MapEvents - Builds RMXP events from plan entries
# Trainers and items are written the short way Essentials understands (event
# name + comments), then turned into full events by Essentials' own compiler
# functions, exactly as if they had been placed by hand in the editor.
#===============================================================================
module MapEvents
  module_function

  def build_event(entry, id, checker)
    event = RPG::Event.new(entry.x, entry.y)
    event.id = id
    page = event.pages[0]
    page.list = []
    page.graphic.character_name = entry.value("Graphic") || ""
    page.graphic.direction = FACINGS[entry.value("Facing")] || 2
    set_movement(page, entry)
    case entry.kind
    when :npc     then build_npc(event, entry)
    when :trainer then event = build_trainer(event, entry, checker)
    when :item    then event = build_item(event, entry)
    when :copy    then event = build_copy(entry, id)
    end
    return event
  end

  # Talks (or runs its script lines, gives its items) when the player presses
  # the action key, or steps on it (Trigger = contact). With When, a page
  # before it says the Wait texts until its condition holds; with Once, a
  # page after it says the Once texts ever after; with Hide, an empty page
  # that goes through takes over once its condition holds.
  def build_npc(event, entry)
    event.name = "#{TAG} #{entry.label}"
    page = event.pages[0]
    page.trigger = TRIGGERS[entry.value("Trigger") || "action"]
    blank = Marshal.load(Marshal.dump(page))
    entry.fields.each do |key, value|
      page.list.push(message(value)) if key == "Text"
      Compiler.push_script(page.list, value) if key == "Script"
      Compiler.push_script(page.list, "pbReceiveItem(:#{value})") if key == "Gift"
    end
    page.list.push(RPG::EventCommand.new(123, 0, ["A", 0])) if entry.value("Once")   # Self switch A ON
    Compiler.push_end(page.list)
    if entry.value("When")
      set_condition(page.condition, entry.value("When"))
      event.pages.unshift(texts_page(blank, entry, "Wait"))
    end
    if entry.value("Once")
      once = texts_page(blank, entry, "Once")
      set_condition(once.condition, "A")
      event.pages.push(once)
    end
    event.pages.push(hidden_page(entry.value("Hide"))) if entry.value("Hide")
  end

  # A copy of the NPC's blank page saying the texts of that key.
  def texts_page(blank, entry, key)
    page = Marshal.load(Marshal.dump(blank))
    entry.fields.each { |k, value| page.list.push(message(value)) if k == key }
    Compiler.push_end(page.list)
    return page
  end

  def hidden_page(hide)
    page = RPG::Event::Page.new
    page.through = true
    set_condition(page.condition, hide)
    return page
  end

  # A to D = self switch on, S25 = game switch on, V7>=1 = game variable.
  def set_condition(condition, text)
    case text
    when /\A[A-D]\z/
      condition.self_switch_valid = true
      condition.self_switch_ch = text
    when /\AS(\d+)\z/
      condition.switch1_valid = true
      condition.switch1_id = $1.to_i
    when /\AV(\d+)>=(\d+)\z/
      condition.variable_valid = true
      condition.variable_id = $1.to_i
      condition.variable_value = $2.to_i
    end
  end

  # Movement type, speed and loop route; trainers keep them through
  # Compiler.convert_to_trainer_event, which copies the first page.
  def set_movement(page, entry)
    route = entry.value("Route")
    page.move_type = MOVES[entry.value("Move") || (route ? "ronde" : "fixe")]
    page.move_speed = entry.value("Speed").to_i if entry.value("Speed")
    page.move_frequency = entry.value("Frequency").to_i if entry.value("Frequency")
    page.through = yes?(entry.value("Through"))
    return if !route
    page.move_route = RPG::MoveRoute.new
    page.move_route.repeat = true
    page.move_route.list = parse_route(route).map { |code, params, _, _| RPG::MoveCommand.new(code, params) }
    page.move_route.list.push(RPG::MoveCommand.new)   # End of route
  end

  # One message box. Not Compiler.push_text, which cuts the text at each "\m"
  # and would break message codes such as \me[Badge get].
  def message(text, indent = 0)
    return RPG::EventCommand.new(101, indent, [text])
  end

  # "Trainer(n)" keeps the sight range; the tag after it keeps the name apart
  # from hand-made trainers (Essentials only looks for "trainer(n)" in it).
  def build_trainer(event, entry, checker)
    event.name = "Trainer(#{entry.value('Sight') || 3}) #{TAG} #{entry.label}"
    list = event.pages[0].list
    entry.fields.each do |key, value|
      next if !TRAINER_COMMENTS.include?(key)
      if YES_NO_KEYS.include?(key)
        next if !yes?(value)
        value = "true"
      end
      Compiler.push_comment(list, "#{key}: #{value}")
    end
    Compiler.push_end(list)
    trainer = Compiler.convert_to_trainer_event(event, checker)
    add_rewards(trainer, entry)
    return trainer
  end

  # Gym leader rewards, run on a win before the event's self switch A is set.
  def add_rewards(trainer, entry)
    rewards = []
    entry.fields.each { |key, value| rewards.push(message(value, 1)) if key == "Win" }
    badge = entry.value("Badge")
    Compiler.push_script(rewards, "$player.badges[#{badge.to_i - 1}] = true", 1) if badge
    gift = entry.value("Gift")
    Compiler.push_script(rewards, "pbReceiveItem(:#{gift})", 1) if gift
    if (switch = entry.value("Switch"))
      rewards.push(RPG::EventCommand.new(121, 1, [switch.to_i, switch.to_i, 0]))   # Switch ON
    end
    return if rewards.empty?
    list = trainer.pages[0].list
    index = list.index { |command| command.code == 123 && command.indent == 1 }   # Self switch A
    list.insert(index, *rewards)
  end

  # The event as it is on its map, moved to Pos ("Nurse MapEvents N").
  def build_copy(entry, id)
    map_id, event_id = copy_source(entry)
    template = load_data(sprintf("Data/Map%03d.rxdata", map_id)).events[event_id]
    raise Error, "[Copy #{entry.label}] : pas d'événement #{event_id} sur la carte #{map_id}" if !template
    event = Marshal.load(Marshal.dump(template))
    event.id = id
    event.x, event.y = entry.x, entry.y
    event.name = "#{template.name} #{TAG} #{entry.label}"
    replace_graphic(event, entry.value("Graphic")) if entry.value("Graphic")
    add_confirm(event, entry) if entry.value("Confirm")
    return event
  end

  # The copy's graphic (that of its first page) replaced on every page and in
  # its move routes (Change Graphic).
  def replace_graphic(event, graphic)
    old = event.pages[0].graphic.character_name
    event.pages.each do |page|
      page.graphic.character_name = graphic if page.graphic.character_name == old
      page.list.each do |command|
        next if command.code != 209 && command.code != 509
        route = (command.code == 209) ? command.parameters[1].list : [command.parameters[0]]
        route.each { |move| move.parameters[0] = graphic if move.code == 41 && move.parameters[0] == old }
      end
    end
  end

  # The first answer of the first choice (When [0]) of page 1 starts with:
  # unless Confirm's script holds, exit event processing.
  def add_confirm(event, entry)
    list = event.pages[0].list
    index = list.index { |command| command.code == 402 && command.parameters[0] == 0 }
    raise Error, "[Copy #{entry.label}] : pas de choix pour Confirm" if !index
    indent = list[index].indent + 1
    list.insert(index + 1,
                RPG::EventCommand.new(111, indent, [12, "!(#{entry.value('Confirm')})"]),
                RPG::EventCommand.new(115, indent + 1, []),
                RPG::EventCommand.new(0, indent + 1, []),
                RPG::EventCommand.new(412, indent, []))
  end

  def build_item(event, entry)
    hidden = yes?(entry.value("Hidden"))
    event.name = "#{hidden ? 'HiddenItem' : 'Item'}:#{entry.value('Item')}"
    item = Compiler.convert_to_item_event(event)
    raise Error, "[Item #{entry.label}] : objet « #{entry.value('Item')} » inconnu" if !item
    item.name += " #{TAG} #{entry.label}"   # "Item MapEvents C"
    return item
  end
end
