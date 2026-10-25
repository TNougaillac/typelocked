#===============================================================================
# RunHistory - Score of a game
# Seals, Anciens, Parrain and Arceus beaten, trainers and gym members beaten
# (counted at each won trainer battle, saved with the game), dead Pokémon, a
# bonus for a fast victory (001_Settings.rb). Shown on the trainer card.
#===============================================================================
module RunHistory
  module_function

  # Trainers and gym members beaten in this game.
  def wins
    return $run_history_wins ||= { trainers: 0, members: 0 }
  end

  # Names of the events fought in the trainer battle about to start: the
  # running one, and the one waiting for a double battle with it ("": a battle
  # started by a script, counted as a trainer).
  def battle_events
    return [""] if !pbMapInterpreterRunning?
    ids = [pbMapInterpreter.get_self&.id, $game_temp.waiting_trainer&.[](1)].compact.uniq
    names = ids.map { |id| $game_map.events[id]&.name.to_s }
    return names.empty? ? [""] : names
  end

  def count_wins(names)
    names.each do |name|
      next if name[BOSS_EVENT]
      wins[name[MEMBER_EVENT] ? :members : :trainers] += 1
    end
  end

  # Pokémon dead in this game: in the graveyard boxes, or not buried yet.
  def deaths
    graveyard = Nuzlocke.data.graveyard_boxes.sum { |box| $PokemonStorage[box].pokemon.count { |pkmn| pkmn } }
    return graveyard + $player.party.count(&:run_history_dead?)
  end

  # The Nuzlocke was played (still on, or lost: its graveyard was made).
  def nuzlocke?
    return Nuzlocke.data.active || !Nuzlocke.data.graveyard_boxes.empty?
  end

  def score(outcome = :playing)
    league = (1..6).map { |n| $game_switches[WorldEvents::LEAGUE_SWITCH + n] }   # Anciens, Parrain, Arceus
    points = ($player.badge_count * SEAL_POINTS) + (league[0, 4].count(true) * ELDER_POINTS)
    points += PARRAIN_POINTS if league[4]
    points += ARCEUS_POINTS if league[5]
    points += (wins[:trainers] * TRAINER_POINTS) + (wins[:members] * MEMBER_POINTS) + (deaths * DEATH_POINTS)
    points += [SPEED_BONUS - (SPEED_BONUS_MINUTE * ($stats.play_time.to_i / 60)), 0].max if outcome == :victory
    points *= TYPE_MULTIPLIERS.fetch(Monotype.data.type, 1.0)
    points *= NO_NUZLOCKE if !nuzlocke?
    return [points.round, 0].max
  end

  def score_text(entry)
    return entry.score ? _INTL("{1} pts", entry.score) : "-"
  end
end

SaveData.register(:run_history_wins) do
  save_value { RunHistory.wins }
  load_value { |value| $run_history_wins = value }
  new_game_value { { trainers: 0, members: 0 } }
end

# Dead in the Nuzlocke, even once the run is lost (nuzlocke_dead? is false
# then).
class Pokemon
  def run_history_dead?
    return @nuzlocke_dead ? true : false
  end
end

# A won trainer battle counts its trainers (Monotype may skip a gym battle:
# not won).
class << TrainerBattle
  alias_method :__run_history_start_core, :start_core

  def start_core(*args)
    names = RunHistory.battle_events
    outcome = __run_history_start_core(*args)
    RunHistory.count_wins(names) if outcome == 1
    return outcome
  end
end

# A Score line under the ID No., right of the start date.
class PokemonTrainerCard_Scene
  alias_method :__run_history_pbDrawTrainerCardFront, :pbDrawTrainerCardFront

  def pbDrawTrainerCardFront
    __run_history_pbDrawTrainerCardFront
    base = Color.new(72, 72, 72)
    shadow = Color.new(160, 160, 160)
    pbDrawTextPositions(@sprites["overlay"].bitmap,
                        [[_INTL("Score"), 332, 262, :left, base, shadow],
                         [RunHistory.score.to_s, 468, 262, :right, base, shadow]])
  end
end
