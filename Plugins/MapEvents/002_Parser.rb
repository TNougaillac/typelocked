#===============================================================================
# MapEvents - Plan file parser
# File format (one file per map, keys in English, # starts a comment):
#   Map = Route 1              (required: map name in the map tree, or its ID)
#   BGM = Route 1              (optional: map music, name[,volume[,pitch]])
#   [Npc A]                    (a person or a sign: one event per section,
#   Pos = 4,7                   A = its label, unique in the file;
#   Graphic = NPC 01            Pos = x,y cell from 0; no Graphic = sign;
#   Facing = bas                Facing = haut|bas|gauche|droite;
#   Text = Bonjour !            each Text = one message box, each Script =
#   Script = pbPokemonMart([:POKEBALL])   one script line, run in file order)
#   Move = ronde               (movement, also for trainers: Move = fixe |
#   Route = droite*3, attendre 60, gauche*3   vers_joueur | ronde; Route =
#   Speed = 3                   steps repeated in a loop (haut, bas, gauche,
#   Frequency = 3               droite, *n to repeat, regard_<direction>,
#   Through = oui               attendre <frames>), it implies Move = ronde and
#                               must come back to Pos; Speed and Frequency =
#                               1-6; Through = oui walks through the others)
#   Trigger = contact          (NPC: action (default) or contact, run when the
#                               player steps on it or bumps into it)
#   Show = S71                 (NPC: there only once S71 or V7>=1 holds)
#   Hide = V7>=1               (NPC: gone once the condition holds: A to D =
#                               its self switch, S25 = game switch 25 on,
#                               V7>=1 = game variable 7 at least 1)
#   When = S4                  (NPC: Text, Script and Gift only once S4 or
#   Wait = Reviens plus tard.   V7>=1 holds, Wait = what it says before;
#   Gift = MACHETE              Gift = item given, in file order with the
#   Once = Bonne route !        texts; Once = what it says ever after, the
#                               NPC talks only once, required with a Gift)
#   [Trainer B]                (Essentials trainer: Type, Name and Battle are
#   Pos = 10,3                  required; Sight = how far it sees, 3 by
#   Sight = 4                   default; Graphic is taken from the trainer
#   Type = YOUNGSTER            type when omitted; the other keys are the
#   Name = Ben                  Essentials trainer comments: BattleID,
#   Battle = Tu es nouveau ?    DoubleBattle, Continue (oui|non), Backdrop,
#   EndBattle = Bien joué.      EndBattle, EndIfSwitch, VanishIfSwitch,
#   Badge = 1                   Outcome, RegSpeech; several Battle = rematches.
#   Win = \me[Badge get]Badge !  Gym leader: Badge = n gives badge n (1-8),
#   Gift = TM39                 Win = text after a win, Gift = item given,
#   Switch = 25                 Switch = game switch turned on, each Reward
#   Reward = pbAddPokemon(:EEVEE, 5)   = one script line run on a win;
#   Rage = 71,6                 Rage = once game switch 71 is on, it sees 6
#   RageBattle = Traître !      cells ahead and says the RageBattle texts
#                               instead of Battle)
#   [Copy N]                   (a copy of event 2 of map 24, as it is there:
#   Pos = 7,2                   pages, graphics, commands; it keeps its ID when
#   From = 24,2                 free, for the events that name it, such as a
#   Graphic = NPC 16            nurse and her healing machine; Graphic = in
#   Confirm = pbPay             place of its own, in its move routes too;
#                               Confirm = script run at the start of the first
#                               choice's first answer: false stops the event)
#   [Item C]                   (Poké Ball on the ground, Hidden = oui for a
#   Pos = 2,2                   hidden item)
#   Item = POTION
#   [Metadata]                 (lines merged into the map's section of
#   HealingSpot = 3,10,8        PBS/map_metadata.txt, other keys kept)
#   [Encounters]               (replaces the map's section of
#   Land,21                     PBS/encounters.txt, same lines as there)
#   40,PIDGEY,2,4
#===============================================================================
module MapEvents
  class Error < StandardError; end

  Plan = Struct.new(:file, :target, :bgm, :events, :metadata, :encounters)
  # fields: [key, value] in file order, a key can repeat (Text, Battle...)
  Entry = Struct.new(:kind, :label, :x, :y, :fields, :lineno) do
    def value(key)
      pair = fields.find { |k, _| k == key }
      return pair && pair[1]
    end
  end

  FACINGS = { "bas" => 2, "gauche" => 4, "droite" => 6, "haut" => 8 }
  MOVES   = { "fixe" => 0, "vers_joueur" => 2, "ronde" => 3 }   # RMXP move types
  # Route steps: RMXP move command code and [dx, dy]
  ROUTE_STEPS = {
    "bas" => [1, [0, 1]], "gauche" => [2, [-1, 0]], "droite" => [3, [1, 0]], "haut" => [4, [0, -1]],
    "regard_bas" => [16, [0, 0]], "regard_gauche" => [17, [0, 0]],
    "regard_droite" => [18, [0, 0]], "regard_haut" => [19, [0, 0]]
  }
  MOVE_KEYS = %w[Move Route Speed Frequency Through]
  TRIGGERS = { "action" => 0, "contact" => 1 }   # RMXP triggers
  # Hide conditions: self switch, game switch, game variable at least n
  HIDE_PATTERN = /\A(?:[A-D]|S\d+|V\d+>=\d+)\z/
  # When conditions: game switch, game variable at least n
  WHEN_PATTERN = /\A(?:S\d+|V\d+>=\d+)\z/
  # Keys written as comments for Compiler.convert_to_trainer_event
  TRAINER_COMMENTS = %w[Battle Type Name BattleID DoubleBattle Backdrop Continue EndBattle
                        EndIfSwitch VanishIfSwitch Outcome RegSpeech]
  KEYS = {
    npc:     %w[Pos Graphic Facing Text Script Gift When Wait Once Trigger Hide Show] + MOVE_KEYS,
    trainer: %w[Pos Graphic Facing Sight Badge Win Reward Gift Switch Rage RageBattle] + MOVE_KEYS + TRAINER_COMMENTS,
    item:    %w[Pos Item Hidden],
    copy:    %w[Pos From Graphic Confirm]
  }
  REQUIRED = { npc: %w[Pos], trainer: %w[Pos Type Name Battle], item: %w[Pos Item], copy: %w[Pos From] }
  NUMBER_KEYS = %w[Sight Badge Switch BattleID EndIfSwitch VanishIfSwitch Outcome]
  YES_NO_KEYS = %w[DoubleBattle Continue Hidden Through]
  ID_KEYS     = %w[Type Item Gift]

  module_function

  # [map ID, event ID] of a [Copy]'s From
  def copy_source(entry)
    return entry.value("From").split(",").map(&:to_i)
  end

  def yes?(value)
    return %w[oui true].include?(value.to_s.downcase)
  end

  def parse_file(path)
    text = File.read(path, encoding: "UTF-8").sub(/\A﻿/, "")
    return parse(text, File.basename(path))
  end

  def parse(text, file = "plan")
    plan = Plan.new(file, nil, nil, [], [], [])
    section = :header
    entry = nil
    text.each_line.with_index(1) do |raw, lineno|
      line = raw.chomp.sub(/(\A|\s)#.*\z/, "").strip
      next if line.empty?
      fail_at = proc { |msg| raise Error, "#{file}, ligne #{lineno} : #{msg}" }
      if line =~ /\A\[(\w+)(?:\s+(\S+))?\]\z/
        section = $1.downcase.to_sym
        label = $2
        if KEYS[section]
          fail_at.call("nom attendu, par exemple [#{$1} A]") if !label
          fail_at.call("« #{label} » est déjà utilisé") if plan.events.any? { |e| e.label == label }
          entry = Entry.new(section, label, nil, nil, [], lineno)
          plan.events.push(entry)
        elsif ![:metadata, :encounters].include?(section) || label
          fail_at.call("section inconnue [#{$1}] (Npc, Trainer, Item, Copy, Metadata, Encounters)")
        end
        next
      end
      if section == :encounters
        plan.encounters.push(line)
        next
      end
      fail_at.call("attendu « Clé = valeur »") unless line =~ /\A(\w+)\s*=\s*(.+)\z/
      key, value = $1, $2.strip
      case section
      when :header
        case key.downcase
        when "map" then plan.target = (value =~ /\A\d+\z/) ? value.to_i : value
        when "bgm" then plan.bgm = value
        else fail_at.call("clé « #{key} » inconnue (Map, BGM)")
        end
      when :metadata
        plan.metadata.push("#{key} = #{value}")
      else
        known = KEYS[section].find { |k| k.casecmp?(key) }
        fail_at.call("clé « #{key} » inconnue dans [#{section.capitalize}] (#{KEYS[section].join(', ')})") if !known
        check_value(entry, known, value, fail_at)
        entry.fields.push([known, value])
      end
    end
    validate(plan)
    return plan
  end

  def check_value(entry, key, value, fail_at)
    if key == "Pos"
      fail_at.call("attendu « Pos = x,y »") unless value =~ /\A(\d+)\s*,\s*(\d+)\z/
      fail_at.call("« Pos » donné deux fois") if entry.x
      entry.x, entry.y = $1.to_i, $2.to_i
    elsif key == "Facing" && !FACINGS[value]
      fail_at.call("direction « #{value} » inconnue (#{FACINGS.keys.join(', ')})")
    elsif key == "Move" && !MOVES[value]
      fail_at.call("déplacement « #{value} » inconnu (#{MOVES.keys.join(', ')})")
    elsif key == "Rage" && value !~ /\A\d+\s*,\s*\d+\z/
      fail_at.call("attendu « Rage = interrupteur,vue », par exemple 71,6")
    elsif key == "From" && value !~ /\A\d+\s*,\s*\d+\z/
      fail_at.call("attendu « From = carte,événement », par exemple 24,2")
    elsif key == "Trigger" && !TRIGGERS[value]
      fail_at.call("déclenchement « #{value} » inconnu (#{TRIGGERS.keys.join(', ')})")
    elsif key == "Hide" && value !~ HIDE_PATTERN
      fail_at.call("condition « #{value} » inconnue (A à D, S25, V7>=1)")
    elsif %w[Show When].include?(key) && value !~ WHEN_PATTERN
      fail_at.call("condition « #{value} » inconnue (S25, V7>=1)")
    elsif NUMBER_KEYS.include?(key) && value !~ /\A\d+\z/
      fail_at.call("nombre attendu pour « #{key} », trouvé « #{value} »")
    elsif YES_NO_KEYS.include?(key) && !%w[oui non true false].include?(value.downcase)
      fail_at.call("« #{key} » vaut oui ou non")
    elsif ID_KEYS.include?(key) && value !~ /\A\w+\z/
      fail_at.call("identifiant attendu pour « #{key} » (ex. POTION), trouvé « #{value} »")
    elsif key == "Badge" && !value.to_i.between?(1, 8)
      fail_at.call("« Badge » va de 1 à 8")
    elsif %w[Speed Frequency].include?(key) && !value.to_i.between?(1, 6)
      fail_at.call("« #{key} » va de 1 à 6")
    elsif key == "Route"
      begin
        parse_route(value)
      rescue Error => e
        fail_at.call(e.message)
      end
    end
  end

  # Returns the route as [[code, params, dx, dy], ...], one entry per step.
  def parse_route(value)
    value.split(",").flat_map do |step|
      step = step.strip
      if step =~ /\Aattendre\s+(\d+)\z/
        next [[15, [$1.to_i], 0, 0]]
      end
      raise Error, "pas « #{step} » inconnu (#{ROUTE_STEPS.keys.join(', ')}, attendre n)" unless step =~ /\A(\w+)(?:\*(\d+))?\z/
      code, (dx, dy) = ROUTE_STEPS[$1]
      raise Error, "pas « #{step} » inconnu (#{ROUTE_STEPS.keys.join(', ')}, attendre n)" if !code
      Array.new(($2 || 1).to_i) { [code, [], dx, dy] }
    end
  end

  # Cells a route walks through from its entry's Pos, raising if the loop
  # does not end where it started (the event would drift away).
  def route_cells(entry)
    x, y = entry.x, entry.y
    cells = parse_route(entry.value("Route")).map { |_, _, dx, dy| [x += dx, y += dy] }
    return cells if [x, y] == [entry.x, entry.y]
    raise Error, "[#{entry.kind.capitalize} #{entry.label}] : la ronde finit en #{x},#{y} au lieu de revenir en #{entry.x},#{entry.y}"
  end

  def validate(plan)
    raise Error, "#{plan.file} : « Map » manquant" if !plan.target
    cells = {}
    plan.events.each do |entry|
      where = "#{plan.file}, ligne #{entry.lineno} : [#{entry.kind.capitalize} #{entry.label}]"
      REQUIRED[entry.kind].each do |key|
        raise Error, "#{where} : « #{key} » manquant" if !entry.value(key)
      end
      raise Error, "#{where} : « RageBattle » demande « Rage »" if entry.value("RageBattle") && !entry.value("Rage")
      raise Error, "#{where} : « Rage » demande « RageBattle »" if entry.value("Rage") && !entry.value("RageBattle")
      if entry.kind == :npc
        raise Error, "#{where} : « Text », « Script » ou « Gift » manquant" if !%w[Text Script Gift].any? { |k| entry.value(k) }
        raise Error, "#{where} : « Wait » demande « When »" if entry.value("Wait") && !entry.value("When")
        raise Error, "#{where} : « Show » et « When » ensemble" if entry.value("Show") && entry.value("When")
        raise Error, "#{where} : « Gift » demande « Once » (sinon il redonne)" if entry.value("Gift") && !entry.value("Once")
        raise Error, "#{where} : « Once » utilise déjà l'interrupteur local A de « Hide »" if entry.value("Once") && entry.value("Hide") == "A"
      end
      if entry.value("Move") == "ronde" && !entry.value("Route")
        raise Error, "#{where} : « Move = ronde » demande une « Route »"
      elsif entry.value("Route")
        raise Error, "#{where} : « Route » demande « Move = ronde »" if (entry.value("Move") || "ronde") != "ronde"
        begin
          route_cells(entry)
        rescue Error => e
          raise Error, "#{plan.file}, ligne #{entry.lineno} : #{e.message}"
        end
      end
      if (other = cells[[entry.x, entry.y]])
        raise Error, "#{where} : case #{entry.x},#{entry.y} déjà prise par [#{other.kind.capitalize} #{other.label}]"
      end
      cells[[entry.x, entry.y]] = entry
    end
  end
end
