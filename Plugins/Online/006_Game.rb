#===============================================================================
# Online - Multiplayer game
# New Game with the bridge in a room starts a multiplayer game: it waits for
# the host to start it (every player connected), takes the room's seed, and
# the room's rules replace the Nuzlocke and Monotype choices they impose.
# Without the bridge, a new game is a solo game, exactly as before.
#===============================================================================
module Online
  @inbox = []

  module_function

  # Events of the other players not handled yet ({ "n", "from", "data" }).
  def inbox
    @inbox
  end

  # Sends data (a Hash) to the other players; does nothing in a solo game.
  def publish(data)
    Bridge.publish(data) if multi?
  end

  # The room of a new game, nil for a solo game.
  def room_for_new_game
    Bridge.retry_now
    room = Bridge.state
    return nil if !room
    return room if room["started"]
    return wait_for_start
  end

  # Waits for the host to start the room; Back plays solo instead.
  def wait_for_start
    viewport = Viewport.new(0, 0, Graphics.width, Graphics.height)
    viewport.z = 99_999
    window = Window_UnformattedTextPokemon.newWithSize("", 0, Graphics.height - 128, Graphics.width, 128, viewport)
    window.setSkin(MessageConfig.pbGetSpeechFrame)
    next_poll = 0
    loop do
      Graphics.update
      Input.update
      window.update
      return nil if Input.trigger?(Input::BACK)
      next if System.uptime < next_poll
      next_poll = System.uptime + POLL_INTERVAL
      Bridge.retry_now
      room = Bridge.state
      return nil if !room   # Bridge closed: solo game
      return room if room["started"]
      window.text = wait_text(room)
    end
  ensure
    window&.dispose
    viewport&.dispose
  end

  def wait_text(room)
    players = room["players"] || []
    connected = players.count { |p| p["connected"] }
    return _INTL("Salon {1} : en attente du lancement par l'hôte ({2}/{3} joueurs connectés).\nRetour : jouer en solo.",
                 room["code"], connected, players.length)
  end

  # Imposed choices, before the Nuzlocke (10) and Monotype (20) dialogs.
  def apply_rules
    return if !multi? || data.rules_applied
    rules = data.rules
    if nuzlocke_forced?(rules) && !Nuzlocke.data.chosen
      Nuzlocke.data.active = true
      Nuzlocke.data.chosen = true
      Nuzlocke.create_graveyard_box if Nuzlocke.data.graveyard_boxes.empty?
      pbMessage(_INTL("Règle du salon : le mode Nuzlocke est obligatoire."))
    end
    type = forced_type(rules, data.seed, Monotype.available_types)
    if type && !Monotype.data.chosen
      Monotype.activate(type)
      pbMessage(rules["sameType"] ? _INTL("Règle du salon : le même type, tiré au hasard, pour tous les joueurs.") :
                                    _INTL("Règle du salon : le type est tiré au hasard."))
    end
    data.rules_applied = true
  end

  # Reads the other players' events now and then while on the map.
  def poll
    return if !multi? || System.uptime < (@next_poll || 0)
    @next_poll = System.uptime + POLL_INTERVAL
    events, data.last_event = Bridge.events_after(data.last_event)
    @inbox.concat(events)
  end
end

module Game
  class << self
    alias_method :__online_start_new, :start_new

    def start_new
      room = Online.room_for_new_game
      MapProceduralGenerator.next_game_seed = room["seed"] if room
      __online_start_new
      $online = room ? Online::Data.new(room) : nil
    end
  end
end

NewGameSetup.add(:online, 5) { Online.apply_rules }

EventHandlers.add(:on_frame_update, :online_poll,
  proc { Online.poll }
)
