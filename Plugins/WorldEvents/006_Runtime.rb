#===============================================================================
# WorldEvents - Called by the events in game
#===============================================================================
module WorldEvents
  module_function

  # The professor: tells the Pact, then opens the lab's Poké Balls (lab) or
  # offers the three starters in a list.
  def professor(lab)
    return pbMessage(_INTL(PROFESSOR_AFTER)) if Monotype.data.starter_given
    if !$game_switches[CHOOSING_STARTER_SWITCH]
      PROFESSOR_INTRO.each { |line| pbMessage(_INTL(line, Monotype.type_name)) }
    end
    if lab
      $game_switches[CHOOSING_STARTER_SWITCH] = true
      $game_map.need_refresh = true
      pbMessage(_INTL(PROFESSOR_BALLS))
      return
    end
    Monotype.starter_dialog
    pbSet(STARTER_VARIABLE, 1) if Monotype.data.starter_given
  end

  # A Poké Ball of the lab: true once its starter is taken.
  def starter_ball(index)
    if !$game_switches[CHOOSING_STARTER_SWITCH]
      pbMessage(_INTL(BALL_TEXT))
      return false
    end
    return false if !Monotype.starter_ball(index)
    $game_switches[CHOOSING_STARTER_SWITCH] = false
    pbSet(STARTER_VARIABLE, index + 1)
    return true
  end

  # The clerk of a shop where that many seals are won on the way.
  def mart(seals)
    pbPokemonMart(mart_stock(seals), _INTL(MART_SPEECH))
  end

  # An exit of the first town, before the starter.
  def gate
    pbMessage(_INTL(GATE_TEXT))
    pbMoveRoute($game_player, [PBMoveRoute::BACKWARD], true)
  end

  # A Move Relearner: a move remembered for a Heart Scale.
  def relearner
    pbMessage(_INTL(RELEARNER_INTRO))
    return pbMessage(_INTL(RELEARNER_NO_SCALE)) if !$bag.has?(HEART_SCALE)
    return pbMessage(_INTL(RELEARNER_NONE)) if $player.party.none?(&:can_relearn_move?)
    pbChoosePokemon(1, 3, proc { |pkmn| pkmn.can_relearn_move? })
    return if pbGet(1) < 0
    return if !pbRelearnMoveScreen($player.party[pbGet(1)])
    $bag.remove(HEART_SCALE)
    pbMessage(_INTL(RELEARNER_DONE))
  end

  # The door of a room of the League, before its fight is won.
  def league_door
    pbMessage(_INTL(LEAGUE_DOOR_TEXT))
    pbMoveRoute($game_player, [PBMoveRoute::BACKWARD], true)
  end

  # Arceus (interpreter: the event's, for OverworldBoss): beaten or caught,
  # the Pact is broken and the door of its room opens.
  def arceus(interpreter, level, switch)
    outcome = interpreter.boss_battle(:ARCEUS, level, **ARCEUS_BOSS)
    return if ![1, 4].include?(outcome)
    $game_switches[switch] = true
    $game_map.need_refresh = true
    ARCEUS_END.each { |line| pbMessage(_INTL(line)) }
  end
end
