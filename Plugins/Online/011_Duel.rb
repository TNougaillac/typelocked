#===============================================================================
# Online - Duels between players
# A player challenges another one from the room panel; the challenge is shown
# to them once they are free on the map, and they accept or refuse. Both then
# play the same battle (012): same teams, same random numbers, and each sends
# their choices to the other. A duel changes nothing in either game.
# Messages of a duel are events of the room with kind "duel", addressed to
# one player ("to"); the others ignore them.
#===============================================================================
module Online
  # One duel, from the challenge to the end of the battle.
  class Duel
    attr_reader :id, :foe, :seed, :team
    # The answer to this player's challenge ("accept"/"refuse" message), the
    # other player's team and trainer (from their challenge or answer), why
    # the duel ended early (:forfeit, :cancel), whether the battle started.
    attr_accessor :answer, :foe_team, :foe_trainer, :ended, :started

    def initialize(id, foe, seed, host, team)
      @id = id
      @foe = foe
      @seed = seed
      @host = host
      @team = team
      @inputs = []
    end

    # The challenger: their side comes first wherever both sides must agree.
    def host?
      @host
    end

    # Choices of the other player not used yet, oldest first.
    def inputs
      @inputs
    end
  end

  @duel = nil
  @challenge = nil

  module_function

  # The duel this player is in or waiting for (nil: none).
  def duel
    @duel
  end

  # A challenge received and not answered yet ({ "from", "info" }).
  def challenge
    @challenge
  end

  # A message of the duel to the other player.
  def duel_message(id, to, what, extra = {})
    return { "kind" => "duel", "what" => what, "duel" => id, "to" => to }.merge(extra)
  end

  # This player's trainer, as the other player shows it.
  def duel_trainer
    return { "name" => $player.name, "type" => $player.trainer_type.to_s }
  end

  # Handles a message of a duel (from: the player who sent it).
  def duel_event(from, info)
    return if info["to"] != data.you
    id = info["duel"]
    current = (@duel && @duel.id == id && @duel.foe == from) ? @duel : nil
    case info["what"]
    when "challenge"
      if @duel || @challenge
        publish(duel_message(id, from, "refuse", "busy" => true))
      else
        @challenge = { "from" => from, "info" => info }
      end
    when "withdraw"
      @challenge["withdrawn"] = true if @challenge && @challenge["info"]["duel"] == id
      current.ended ||= :cancel if current
    when "accept", "refuse"
      if current && !current.started
        current.answer = info
      elsif info["what"] == "accept" && !current
        # Accepted too late: this player gave up on that challenge.
        publish(duel_message(id, from, "cancel"))
      end
    when "input"
      current&.inputs&.push(info)
    when "forfeit"
      current.ended ||= :forfeit if current
    when "cancel"
      current.ended ||= :cancel if current
    end
  end

  # A choice of the round as sent: [what, index, target].
  def encode_choice(choice)
    return ["switch", choice[1], -1] if choice[0] == :SwitchOut
    return ["move", choice[1], choice[3]]
  end

  # The other player's battler is 1 here and 0 there (single battles).
  def flip(index)
    return (index >= 0) ? index ^ 1 : index
  end

  # What both battles must agree on: the round and every HP, the
  # challenger's team first.
  def duel_check(turn, host_hps, guest_hps)
    return "#{turn}:#{host_hps.join(',')}|#{guest_hps.join(',')}"
  end

  # Reads the bridge now and handles every event; returns the room.
  def pump
    poll_now
    @inbox.shift(@inbox.length).each { |event| handle(event) }
    return room
  end

  # Pause menu > Salon > a player: challenged once back on the map.
  def request_duel(foe)
    @duel_request = foe
  end

  # On the map, with nothing else going on.
  def map_free?
    return false if !$scene.is_a?(Scene_Map) || $game_temp.message_window_showing || $game_temp.in_menu
    return false if pbMapInterpreterRunning? || $game_temp.player_transferring || $game_player.moving?
    return !$game_player.move_route_forcing
  end

  # Called on the map: sends the challenge asked for, or shows the one received.
  def duel_update
    return if !map_free?
    if @duel_request
      foe = @duel_request
      @duel_request = nil
      send_challenge(foe)
    elsif @challenge && !@challenge["asked"]
      @challenge["withdrawn"] ? (@challenge = nil) : answer_challenge
    end
  end

  def able_to_duel?
    return $player.able_pokemon_count > 0
  end

  def send_challenge(foe)
    return pbMessage(_INTL("Aucun de tes Pokémon ne peut combattre.")) if !able_to_duel?
    name = player_name(foe)
    @duel = Duel.new(format("%08x", rand(2**32)), foe, rand(1_000_000_000), true, pack_team($player.party))
    publish(duel_message(@duel.id, foe, "challenge", "seed" => @duel.seed, "team" => @duel.team,
                                                      "trainer" => duel_trainer))
    answer = wait_answer(name)
    if !answer
      publish(duel_message(@duel.id, foe, "withdraw"))
      return
    end
    if answer["what"] != "accept"
      pbMessage(answer["busy"] ? _INTL("{1} est déjà occupé.", name) : _INTL("{1} a refusé le combat.", name))
      return
    end
    @duel.foe_team = answer["team"]
    @duel.foe_trainer = answer["trainer"]
    fight_duel(name)
  ensure
    @duel = nil
  end

  # The answer to this player's challenge, or nil (gave up, no answer, cut off).
  def wait_answer(name)
    viewport = Viewport.new(0, 0, Graphics.width, Graphics.height)
    viewport.z = 99_999
    window = Window_UnformattedTextPokemon.newWithSize("", 0, Graphics.height - 96, Graphics.width, 96, viewport)
    window.setSkin(MessageConfig.pbGetSpeechFrame)
    window.text = _INTL("Défi envoyé à {1}. En attente de sa réponse…\nRetour : annuler.", name)
    give_up = System.uptime + CHALLENGE_TIME
    next_poll = 0
    loop do
      Graphics.update
      Input.update
      window.update
      return nil if Input.trigger?(Input::BACK)
      next if System.uptime < next_poll
      next_poll = System.uptime + POLL_INTERVAL
      cut = pause_reason(pump)
      return @duel.answer if @duel.answer
      if cut || System.uptime >= give_up
        window.visible = false
        pbMessage(cut ? _INTL("Défi annulé : la connexion au salon est coupée.") :
                        _INTL("{1} n'a pas répondu.", name))
        return nil
      end
    end
  ensure
    window&.dispose
    viewport&.dispose
  end

  def answer_challenge
    @challenge["asked"] = true
    from = @challenge["from"]
    info = @challenge["info"]
    name = player_name(from)
    if !able_to_duel?
      publish(duel_message(info["duel"], from, "refuse"))
      pbMessage(_INTL("{1} te défie en combat, mais aucun de tes Pokémon ne peut combattre.", name))
      return
    end
    accepted = pbConfirmMessage(_INTL("{1} te défie en combat ! Accepter ?", name))
    pump
    if @challenge["withdrawn"]
      pbMessage(_INTL("{1} a retiré son défi.", name)) if accepted
      return
    end
    if !accepted
      publish(duel_message(info["duel"], from, "refuse"))
      return
    end
    @duel = Duel.new(info["duel"], from, info["seed"], false, pack_team($player.party))
    @duel.foe_team = info["team"]
    @duel.foe_trainer = info["trainer"]
    publish(duel_message(@duel.id, from, "accept", "team" => @duel.team, "trainer" => duel_trainer))
    fight_duel(name)
  ensure
    @challenge = nil
    @duel = nil
  end

  # Plays the battle, then says how it ended; the teams are as before.
  def fight_duel(name)
    @duel.started = true
    outcome = DuelBattle.start(@duel)
    text = case @duel.ended
           when :forfeit then _INTL("{1} a abandonné le combat.", name)
           when :cancel  then _INTL("Combat annulé : la connexion avec {1} est coupée.", name)
           when :desync  then _INTL("Combat annulé : les deux parties ne voient plus le même combat.")
           else
             { 1 => _INTL("Tu as battu {1} !", name), 2 => _INTL("{1} t'a battu.", name),
               3 => _INTL("Tu as abandonné le combat.") }[outcome] || _INTL("Combat nul.")
           end
    pbMessage(text + "\n" + _INTL("Ton équipe est revenue à son état d'avant le combat."))
  end
end
