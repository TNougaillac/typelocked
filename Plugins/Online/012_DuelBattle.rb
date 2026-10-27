#===============================================================================
# Online - The battle of a duel
# Each player runs the same battle: both teams rebuilt from what was sent
# (copies: the real teams never change), the random numbers of the duel's
# seed, the challenger's side first wherever the order of the battlers draws
# random numbers. The other player's battler takes the choices they send
# instead of the AI's. No items from the Bag, no experience, no money, no
# Nuzlocke death; a cut connection, a forfeit or a difference between the two
# battles (checked at each choice) ends it for both players.
#===============================================================================
module Online
  module_function

  # The team as sent to the other player (no eggs).
  def pack_team(party)
    return party.reject(&:egg?).map { |pkmn| pack_pokemon(pkmn) }
  end

  def pack_pokemon(pkmn)
    return {
      "species" => pkmn.species.to_s, "form" => pkmn.form, "pid" => pkmn.personalID, "exp" => pkmn.exp,
      "gender" => pkmn.gender, "shiny" => pkmn.shiny?, "abilityIndex" => pkmn.ability_index,
      "ability" => pkmn.ability_id&.to_s, "nature" => pkmn.nature_id&.to_s,
      "statNature" => pkmn.nature_for_stats_id&.to_s, "item" => pkmn.item_id&.to_s,
      "iv" => main_stats.to_h { |id| [id.to_s, pkmn.iv[id]] },
      "ev" => main_stats.to_h { |id| [id.to_s, pkmn.ev[id]] },
      "moves" => pkmn.moves.map { |m| [m.id.to_s, m.pp, m.ppup] },
      "name" => pkmn.name, "happiness" => pkmn.happiness, "ball" => pkmn.poke_ball.to_s,
      "hp" => pkmn.hp, "status" => pkmn.status.to_s, "statusCount" => pkmn.statusCount
    }
  end

  def main_stats
    stats = []
    GameData::Stat.each_main { |s| stats.push(s.id) }
    return stats
  end

  def unpack_team(team)
    return (team || []).filter_map { |info| unpack_pokemon(info) }
  end

  # The Pokémon, or nil when this game does not know its species.
  def unpack_pokemon(info)
    species = info["species"].to_sym
    return nil if !GameData::Species.exists?(species)
    pkmn = Pokemon.new(species, 1, $player, false, false)
    pkmn.personalID = info["pid"]
    pkmn.form_simple = info["form"]
    pkmn.exp = info["exp"]
    pkmn.gender = info["gender"]
    pkmn.shiny = info["shiny"]
    pkmn.ability_index = info["abilityIndex"]
    pkmn.ability = known(:Ability, info["ability"])
    pkmn.nature = known(:Nature, info["nature"])
    pkmn.nature_for_stats = known(:Nature, info["statNature"])
    pkmn.item = known(:Item, info["item"])
    main_stats.each do |id|
      pkmn.iv[id] = info["iv"][id.to_s]
      pkmn.ev[id] = info["ev"][id.to_s]
    end
    pkmn.moves = info["moves"].filter_map do |id, pp, ppup|
      next if !GameData::Move.exists?(id.to_sym)
      move = Pokemon::Move.new(id.to_sym)
      move.ppup = ppup
      move.pp = pp
      move
    end
    pkmn.name = info["name"]
    pkmn.happiness = info["happiness"]
    pkmn.poke_ball = known(:Item, info["ball"]) || :POKEBALL
    pkmn.calc_stats
    pkmn.hp = info["hp"]
    pkmn.status = info["status"].to_sym
    pkmn.statusCount = info["statusCount"]
    return pkmn
  end

  # The id (Symbol) if this game knows it, else nil.
  def known(kind, id)
    return nil if !id || id.empty?
    return GameData.const_get(kind).exists?(id.to_sym) ? id.to_sym : nil
  end

  class DuelBattle < Battle
    def self.start(duel)
      trainer_info = duel.foe_trainer || {}
      type = Online.known(:TrainerType, trainer_info["type"]) || $player.trainer_type
      foe = NPCTrainer.new(trainer_info["name"] || _INTL("Joueur"), type)
      scene = BattleCreationHelperMethods.create_battle_scene
      battle = new(duel, scene, Online.unpack_team(duel.team), Online.unpack_team(duel.foe_team), [$player], [foe])
      outcome = 0
      saved_counts = [$game_temp.party_critical_hits_dealt, $game_temp.party_direct_damage_taken]
      $game_temp.party_critical_hits_dealt = $game_temp.party_direct_damage_taken = nil
      pbBattleAnimation(pbGetTrainerBattleBGM(foe), 1, [foe]) do
        pbSceneStandby { outcome = battle.pbStartBattle }
      end
      $game_temp.party_critical_hits_dealt, $game_temp.party_direct_damage_taken = saved_counts
      Input.update
      return outcome
    end

    def initialize(duel, scene, party, foe_party, player, foe)
      super(scene, party, foe_party, player, foe)
      @duel = duel
      @rng = Random.new(duel.seed)
      @all_owned = false
      self.party1starts = [0]
      self.party2starts = [0]
      self.items = [[]]
      self.internalBattle = false
      self.expGain = false
      self.moneyGain = false
      self.switchStyle = false
      self.canLose = true
      self.showAnims = ($PokemonSystem.battlescene == 0)
      self.environment = :None
      self.backdrop = "indoor1"
      self.time = 0
    end

    def pbRandom(x)
      return @rng.rand(x)
    end

    def pbCanMegaEvolve?(_idxBattler)
      return false
    end

    def pbOwnedByPlayer?(idxBattler)
      return true if @all_owned
      return super
    end

    # Effects that only work for the player's Pokémon work for both sides,
    # as on the other player's screen.
    def as_all_owned
      @all_owned = true
      return yield
    ensure
      @all_owned = false
    end

    # The tie-breakers are drawn in the challenger's order on both screens.
    def pbCalculatePriority(fullCalc = false, indexArray = nil)
      return super if !fullCalc || @duel.host?
      @battlers[0], @battlers[1] = @battlers[1], @battlers[0]
      begin
        return super
      ensure
        @battlers[0], @battlers[1] = @battlers[1], @battlers[0]
      end
    end

    # This player's choice goes to the other player; theirs replaces the AI's.
    def pbCommandPhaseLoop(isPlayer)
      if isPlayer
        choosing = pbCanShowCommands?(0) && @choices[0][0] == :None
        super
        send_input("turn", Online.encode_choice(@choices[0])) if choosing && @decision == 0
        return
      end
      return if @decision != 0 || !pbCanShowCommands?(1) || @choices[1][0] != :None
      input = receive_input("turn")
      apply_choice(input["value"]) if input
    end

    def pbSwitchInBetween(idxBattler, checkLaxOnly = false, canCancel = false)
      if pbOwnedByPlayer?(idxBattler)
        ret = super
        send_input("switch", ret)
        return ret
      end
      input = receive_input("switch")
      return input["value"] if input && pbCanSwitchIn?(idxBattler, input["value"])
      end_duel(:desync) if input
      return @battleAI.pbDefaultChooseNewEnemy(idxBattler)   # The battle is over
    end

    # Forfeiting (Run) ends the duel for the other player too.
    def pbRun(idxBattler, duringBattle = false)
      ret = super
      Online.publish(Online.duel_message(@duel.id, @duel.foe, "forfeit")) if @decision == 3
      return ret
    end

    private

    def check
      host, guest = @party1, @party2
      host, guest = guest, host if !@duel.host?
      return Online.duel_check(@turnCount, host.map(&:hp), guest.map(&:hp))
    end

    def send_input(step, value)
      Online.publish(Online.duel_message(@duel.id, @duel.foe, "input", "step" => step, "value" => value,
                                                                       "check" => check))
    end

    def apply_choice(value)
      what, index, target = value
      ok = case what
           when "switch" then pbRegisterSwitch(1, index)
           when "move"
             if index < 0   # Struggle
               @choices[1][0] = :UseMove
               @choices[1][1] = -1
               @choices[1][2] = @struggle
               @choices[1][3] = -1
               true
             else
               pbRegisterMove(1, index, false) && (pbRegisterTarget(1, Online.flip(target)) || true)
             end
           end
      end_duel(:desync) if !ok
    end

    # The other player's next input of this step, or nil once the duel ends.
    def receive_input(step)
      shown = false
      next_poll = 0
      loop do
        return nil if @decision != 0
        if @duel.ended
          end_duel(@duel.ended)
          return nil
        end
        input = @duel.inputs.shift
        if input
          return input if input["step"] == step && input["check"] == check
          end_duel(:desync)
          return nil
        end
        if !shown
          @scene.pbDisplayMessage(_INTL("En attente de {1}… (Retour : abandonner)", @opponent[0].name), true)
          shown = true
        end
        @scene.pbUpdate
        if Input.trigger?(Input::BACK) && pbDisplayConfirm(_INTL("Abandonner le combat ?"))
          Online.publish(Online.duel_message(@duel.id, @duel.foe, "forfeit"))
          @decision = 3
          return nil
        end
        next if System.uptime < next_poll
        next_poll = System.uptime + POLL_INTERVAL
        @duel.ended ||= :cancel if Online.pause_reason(Online.pump)
      end
    end

    # Ends the battle: won if the other player gave up, a draw otherwise.
    def end_duel(reason)
      @duel.ended = reason
      Online.publish(Online.duel_message(@duel.id, @duel.foe, "cancel")) if reason != :forfeit
      @decision = (reason == :forfeit) ? 1 : 5
    end
  end
end

# Anticipation, Forewarn and Frisk (as the Deluxe Battle Kit left them) only
# work for the player's Pokémon; in a duel they work for both, as Forewarn
# draws a random number.
%i[ANTICIPATION FOREWARN FRISK].each do |ability|
  original = Battle::AbilityEffects::OnSwitchIn[ability]
  next if !original
  Battle::AbilityEffects::OnSwitchIn.add(ability,
    proc { |*args|
      battle = args[2]
      next original.call(*args) if !battle.is_a?(Online::DuelBattle)
      next battle.as_all_owned { original.call(*args) }
    }
  )
end
