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
    end
    return event
  end

  # Talks (or runs its script lines) when the player presses the action key.
  def build_npc(event, entry)
    event.name = "#{TAG} #{entry.label}"
    page = event.pages[0]
    entry.fields.each do |key, value|
      page.list.push(message(value)) if key == "Text"
      Compiler.push_script(page.list, value) if key == "Script"
    end
    Compiler.push_end(page.list)
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

  def build_item(event, entry)
    hidden = yes?(entry.value("Hidden"))
    event.name = "#{hidden ? 'HiddenItem' : 'Item'}:#{entry.value('Item')}"
    item = Compiler.convert_to_item_event(event)
    raise Error, "[Item #{entry.label}] : objet « #{entry.value('Item')} » inconnu" if !item
    item.name += " #{TAG} #{entry.label}"   # "Item MapEvents C"
    return item
  end
end
