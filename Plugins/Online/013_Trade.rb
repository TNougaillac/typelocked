#===============================================================================
# Online - Trades between players
# A player proposes a trade from the room panel; once the other one accepts,
# the proposer picks a Pokémon, then the other one sees it and picks theirs,
# and the proposer confirms: both games then trade (Essentials' trade scene,
# trade evolutions). Only a Pokémon of the receiver's type can be given, never
# a dead one, an egg or the last one able to fight. A received Pokémon is a
# trade, not a capture: the Nuzlocke zone is not used. A cut connection
# before the confirmation cancels the trade: nobody gives anything.
# Messages of a trade are events of the room with kind "trade".
#===============================================================================
module Online
  # One trade, from the proposal to the exchange.
  class Trade
    attr_reader :id, :foe
    # The answer to this player's proposal, the other player's Pokémon
    # ("pick" message), their confirmation, why it ended early (:cancel).
    attr_accessor :answer, :foe_pick, :confirmed, :ended, :started

    def initialize(id, foe)
      @id = id
      @foe = foe
    end
  end

  @trade = nil
  @trade_offer = nil

  module_function

  # The trade this player is in or proposed (nil: none).
  def trade
    @trade
  end

  # A proposal received and not answered yet ({ "from", "info" }).
  def trade_offer
    @trade_offer
  end

  def trade_message(id, to, what, extra = {})
    return { "kind" => "trade", "what" => what, "trade" => id, "to" => to }.merge(extra)
  end

  # Why a Pokémon can't be given (:egg, :dead, :type, :last, :locked), or nil.
  # types: its types; receiver_type: the receiver's Monotype type (nil: any);
  # others_able: the giver keeps another Pokémon able to fight.
  def trade_refusal(types, dead, egg, receiver_type, others_able = true, locked = false)
    return :egg if egg
    return :dead if dead
    return :locked if locked
    return :type if receiver_type && !types.include?(receiver_type)
    return :last if !others_able
    return nil
  end

  def trade_refusal_text(reason, type_name = "")
    return {
      egg: _INTL("Un Œuf ne s'échange pas."), dead: _INTL("Un Pokémon mort ne s'échange pas."),
      locked: _INTL("Ce Pokémon ne peut pas être échangé."),
      type: _INTL("Ce Pokémon n'est pas du type {1}.", type_name),
      last: _INTL("Tu dois garder un Pokémon capable de combattre."),
      unknown: _INTL("Ce Pokémon n'existe pas dans ce jeu.")
    }[reason]
  end

  # Handles a message of a trade (from: the player who sent it).
  def trade_event(from, info)
    return if info["to"] != data.you
    id = info["trade"]
    current = (@trade && @trade.id == id && @trade.foe == from) ? @trade : nil
    case info["what"]
    when "offer"
      if busy?
        publish(trade_message(id, from, "refuse", "busy" => true))
      else
        @trade_offer = { "from" => from, "info" => info }
      end
    when "withdraw"
      @trade_offer["withdrawn"] = true if @trade_offer && @trade_offer["info"]["trade"] == id
      current.ended ||= :cancel if current
    when "accept", "refuse"
      if current && !current.started
        current.answer = info
      elsif info["what"] == "accept" && !current
        publish(trade_message(id, from, "cancel"))   # Accepted too late
      end
    when "pick"
      current.foe_pick = info if current
    when "confirm"
      current.confirmed = true if current
    when "cancel"
      current.ended ||= :cancel if current
    end
  end

  # This player's Monotype type (nil: no type rule).
  def own_type
    return Monotype.data.active ? Monotype.data.type : nil
  end

  def type_name(type)
    data = type && GameData::Type.try_get(type)
    return data ? data.name : ""
  end

  # Why this player can't give pkmn to someone of receiver_type, or nil.
  def give_refusal(pkmn, receiver_type)
    others_able = $player.party.any? { |other| !other.equal?(pkmn) && other.able? }
    return trade_refusal(pkmn.types, pkmn.run_history_dead?, pkmn.egg?, receiver_type, others_able,
                         pkmn.cannot_trade)
  end

  def can_give_any?(receiver_type)
    return $player.party.any? { |pkmn| give_refusal(pkmn, receiver_type).nil? }
  end

  # Party slot of the Pokémon to give (party screen), or nil.
  def choose_gift(receiver_type)
    slot = -1
    pbFadeOutIn do
      scene = PokemonParty_Scene.new
      screen = PokemonPartyScreen.new(scene, $player.party)
      slot = screen.pbChooseAblePokemon(proc { |pkmn| give_refusal(pkmn, receiver_type).nil? }, false)
    end
    return (slot >= 0) ? slot : nil
  end

  # The other player's Pokémon from their "pick" message, or nil (said why).
  def received_pokemon(pick)
    pkmn = begin
      unpack_pokemon(pick["pokemon"])
    rescue StandardError
      nil
    end
    reason = pkmn ? trade_refusal(pkmn.types, pick["dead"], false, own_type) : :unknown
    return pkmn if !reason
    pbMessage(trade_refusal_text(reason, type_name(own_type)) + "\n" + _INTL("Échange annulé."))
    return nil
  end

  def pick_message(slot)
    pkmn = $player.party[slot]
    return trade_message(@trade.id, @trade.foe, "pick", "pokemon" => pack_pokemon(pkmn),
                                                        "dead" => pkmn.run_history_dead?)
  end

  def pokemon_text(pkmn)
    return _INTL("{1} (Nv. {2})", pkmn.name, pkmn.level)
  end

  # Ends the trade with nothing given; tells the other player unless they ended it.
  def cancel_trade(name)
    if @trade.ended
      pbMessage(_INTL("{1} a annulé l'échange.", name))
    else
      publish(trade_message(@trade.id, @trade.foe, "cancel"))
    end
  end

  # Gives the Pokémon of slot for theirs, with the trade scene.
  def exchange(slot, theirs, name, gender)
    pbStartTrade(slot, theirs, theirs.name, name, gender)
  end

  # Proposer: the other player accepts, this player picks, the other player
  # picks, this player confirms.
  def send_trade_offer(foe)
    return pbMessage(_INTL("Aucun de tes Pokémon ne peut être échangé.")) if !can_give_any?(nil)
    name = player_name(foe)
    @trade = Trade.new(format("%08x", rand(2**32)), foe)
    publish(trade_message(@trade.id, foe, "offer", "type" => own_type&.to_s, "gender" => $player.gender))
    answer = wait_for(_INTL("Échange proposé à {1}. En attente de sa réponse…", name),
                      time: CHALLENGE_TIME, late_text: _INTL("{1} n'a pas répondu.", name)) { @trade.answer }
    if !answer
      publish(trade_message(@trade.id, foe, "withdraw"))
      return
    end
    if answer["what"] != "accept"
      pbMessage(answer["busy"] ? _INTL("{1} est déjà occupé.", name) :
                answer["none"] ? _INTL("{1} n'a aucun Pokémon à échanger.", name) :
                                 _INTL("{1} a refusé l'échange.", name))
      return
    end
    @trade.started = true
    foe_type = answer["type"]&.to_sym
    if !can_give_any?(foe_type)
      pbMessage(_INTL("Aucun de tes Pokémon n'est du type {1}.", type_name(foe_type)))
      return cancel_trade(name)
    end
    pbMessage(_INTL("Choisis le Pokémon à donner à {1} (type {2}).", name, type_name(foe_type)))
    slot = choose_gift(foe_type)
    return cancel_trade(name) if !slot
    publish(pick_message(slot))
    pick = wait_for(_INTL("{1} choisit son Pokémon…", name)) { @trade.foe_pick || @trade.ended }
    return cancel_trade(name) if !pick.is_a?(Hash)
    theirs = received_pokemon(pick)
    return cancel_trade(name) if !theirs
    if !pbConfirmMessage(_INTL("Échanger ton {1} contre {2} de {3} ?", $player.party[slot].name,
                               pokemon_text(theirs), name))
      return cancel_trade(name)
    end
    pump
    return cancel_trade(name) if @trade.ended
    publish(trade_message(@trade.id, foe, "confirm"))
    exchange(slot, theirs, name, answer["gender"] || 0)
  ensure
    @trade = nil
  end

  # Receiver: accepts, waits for the proposer's Pokémon, picks theirs, waits
  # for the proposer's confirmation.
  def answer_trade_offer
    @trade_offer["asked"] = true
    from = @trade_offer["from"]
    info = @trade_offer["info"]
    name = player_name(from)
    foe_type = info["type"]&.to_sym
    accepted = pbConfirmMessage(_INTL("{1} te propose un échange. Accepter ?", name))
    pump
    if @trade_offer["withdrawn"]
      pbMessage(_INTL("{1} a retiré sa proposition.", name)) if accepted
      return
    end
    return publish(trade_message(info["trade"], from, "refuse")) if !accepted
    if !can_give_any?(foe_type)
      publish(trade_message(info["trade"], from, "refuse", "none" => true))
      return pbMessage(_INTL("Aucun de tes Pokémon n'est du type {1} : échange impossible.", type_name(foe_type)))
    end
    @trade = Trade.new(info["trade"], from)
    @trade.started = true
    publish(trade_message(@trade.id, from, "accept", "type" => own_type&.to_s, "gender" => $player.gender))
    pick = wait_for(_INTL("{1} choisit son Pokémon…", name)) { @trade.foe_pick || @trade.ended }
    return cancel_trade(name) if !pick.is_a?(Hash)
    theirs = received_pokemon(pick)
    return cancel_trade(name) if !theirs
    pbMessage(_INTL("{1} propose {2}. Choisis le Pokémon à lui donner (type {3}).", name, pokemon_text(theirs),
                    type_name(foe_type)))
    slot = choose_gift(foe_type)
    return cancel_trade(name) if !slot
    if !pbConfirmMessage(_INTL("Échanger ton {1} contre {2} ?", $player.party[slot].name, pokemon_text(theirs)))
      return cancel_trade(name)
    end
    publish(pick_message(slot))
    # No Back here: the other player may already be trading.
    done = wait_for(_INTL("En attente de la confirmation de {1}…", name), cancel: false) do
      @trade.confirmed || @trade.ended
    end
    return cancel_trade(name) if done != true
    exchange(slot, theirs, name, info["gender"] || 0)
  ensure
    @trade_offer = nil
    @trade = nil
  end
end
