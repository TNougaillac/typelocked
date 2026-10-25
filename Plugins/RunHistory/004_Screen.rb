#===============================================================================
# RunHistory - « Dernières parties »
# From the title screen (before « Quit Game »): the list of the last games,
# then the details of the one chosen.
#===============================================================================
module RunHistory
  module_function

  # Returns the seed of the game to play again, nil if none.
  def show
    list = entries
    if list.empty?
      pbMessage(_INTL("Aucune partie enregistrée pour l'instant."))
      return nil
    end
    loop do
      choice = pbMessage(_INTL("Dernières parties"), list.map { |e| line(e) } + [_INTL("Retour")], -1)
      return nil if choice < 0 || choice >= list.length
      seed = details(list[choice])
      return seed if seed
    end
  end

  def line(entry)
    type = entry.type ? GameData::Type.try_get(entry.type)&.name : nil
    return [entry.region || _INTL("Région inconnue"), type, OUTCOMES[entry.outcome]].compact.join(" · ")
  end

  def details(entry)
    hours, minutes = (entry.play_time / 60).divmod(60)
    pbMessage(_INTL("{1}\nGraine {2} · {3} · {4} h {5}", line(entry), entry.seed || "?",
                    entry.updated.strftime("%d/%m/%Y"), hours, format("%02d", minutes)))
    pbMessage(_INTL("Dernier lieu : {1}", entry.place || "?"))
    team = entry.team.map do |m|
      species = GameData::Species.try_get(m.species)&.name || m.species.to_s
      name = (m.name == species) ? species : "#{m.name} (#{species})"
      _INTL("{1} N.{2}", name, m.level) + (m.dead ? _INTL(" (mort)") : "")
    end
    pbMessage(team.empty? ? _INTL("Aucun Pokémon.") : team.join(", "))
    return nil if !entry.seed
    return entry.seed if pbConfirmMessage(_INTL("Rejouer cette graine ? Une nouvelle partie commence dans la même région."))
    return nil
  end
end

# The title screen's commands are local to pbStartLoadScreen: the command is
# put before the last one (Quit Game) when the scene starts, and the scene's
# answers after it are moved back by one. Playing a seed again answers New
# Game, its seed set for the new world. One more panel goes below the
# screen: the panels scroll up to show the one chosen.
class PokemonLoad_Scene
  alias_method :__run_history_pbStartScene, :pbStartScene
  alias_method :__run_history_pbChoose, :pbChoose
  alias_method :__run_history_pbUpdate, :pbUpdate

  def pbStartScene(commands, *args)
    @run_history_command = commands.length - 1
    @run_history_new_game = commands.index(_INTL("New Game"))
    commands.insert(@run_history_command, _INTL("Dernières parties"))
    __run_history_pbStartScene(commands, *args)
    @run_history_panels = commands.length.times.map { |i| [@sprites["panel#{i}"], @sprites["panel#{i}"].y] }
  end

  def pbUpdate
    __run_history_pbUpdate
    return if !@run_history_panels || !@sprites["cmdwindow"] || @run_history_panels.any? { |sprite, _y| sprite.disposed? }
    panel, y = @run_history_panels[@sprites["cmdwindow"].index] || @run_history_panels.first
    shift = [y + panel.bitmap.height + 16 - Graphics.height, 0].max
    @run_history_panels.each { |sprite, base| sprite.y = base - shift }
  end

  def pbChoose(commands)
    loop do
      choice = __run_history_pbChoose(commands)
      return choice if !@run_history_command || choice < @run_history_command
      return choice - 1 if choice > @run_history_command
      pbPlayDecisionSE
      seed = RunHistory.show
      next if !seed || !@run_history_new_game
      MapProceduralGenerator.next_game_seed = seed
      return @run_history_new_game
    end
  end
end
