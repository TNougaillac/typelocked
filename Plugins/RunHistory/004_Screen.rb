#===============================================================================
# RunHistory - « Dernières parties » on the title screen
# A panel under New Game shows the last game before the saved one (region,
# type, outcome, its team's icons); choosing it opens the list of every game
# (005_List.rb). The details of a game, then playing its seed again.
# Each card shows the game's score on its first line, on the right.
#===============================================================================
module RunHistory
  TEXT_COLOR        = Color.new(232, 232, 232)
  TEXT_SHADOW_COLOR = Color.new(136, 136, 136)

  module_function

  # Region · type · outcome; without the type on a card of the list (its
  # score is on the same line, the team shows the type).
  def line(entry, with_type = true)
    type = (with_type && entry.type) ? GameData::Type.try_get(entry.type)&.name : nil
    return [entry.region || _INTL("Région inconnue"), type, OUTCOMES[entry.outcome]].compact.join(" · ")
  end

  # The game shown on the title screen: the last one but the saved one.
  def highlighted
    saved = saved_id
    return entries.find { |e| e.id != saved }
  end

  # Draws a card of panels.png on bitmap (the Continue panel cut to its
  # height): title and score, then line and the team's icons, or line only.
  def draw_card(bitmap, panels, selected, title, score, line, team, icon_y)
    w = panels.width
    h = bitmap.height
    top = selected ? 222 : 0
    bitmap.clear
    bitmap.blt(0, 0, panels.bitmap, Rect.new(0, top, w, h - 24))
    bitmap.blt(0, h - 24, panels.bitmap, Rect.new(0, top + 198, w, 24))
    textpos = [[title, 32, 14, :left, TEXT_COLOR, TEXT_SHADOW_COLOR]]
    textpos.push([score, w - 32, 14, :right, TEXT_COLOR, TEXT_SHADOW_COLOR]) if score
    textpos.push([line, 32, 56, :left, TEXT_COLOR, TEXT_SHADOW_COLOR]) if line
    pbDrawTextPositions(bitmap, textpos)
    (team || []).each_with_index do |member, k|
      file = GameData::Species.icon_filename(member.species)
      next if !file
      icon = AnimatedBitmap.new(file)
      size = icon.height
      bitmap.blt(24 + (k * 60), icon_y, icon.bitmap, Rect.new(0, 0, size, size), member.dead ? DEAD_OPACITY : 255)
      icon.dispose
    end
  end

  # The details of a game; returns its seed if the player plays it again.
  def details(entry)
    hours, minutes = (entry.play_time / 60).divmod(60)
    pbMessage(_INTL("{1}\nGraine {2} · {3} · {4} h {5}", line(entry), entry.seed || "?",
                    entry.updated.strftime("%d/%m/%Y"), hours, format("%02d", minutes)))
    pbMessage(_INTL("Dernier lieu : {1}", entry.place || "?"))
    pbMessage(_INTL("Score : {1}", score_text(entry)) + (entry.nuzlocke == false ? _INTL(" (sans Nuzlocke)") : ""))
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

  # The panel of the title screen (selected and refreshed by the scene like
  # the others).
  class LoadPanel < Sprite
    attr_reader :selected

    def initialize(entry, viewport = nil)
      super(viewport)
      @entry = entry
      @panels = AnimatedBitmap.new("Graphics/UI/Load/panels")
      self.bitmap = Bitmap.new(@panels.width, PANEL_HEIGHT)
      pbSetSystemFont(self.bitmap)
      @selected = false
      refresh
    end

    def selected=(value)
      @selected = value
    end

    def pbRefresh
      refresh
    end

    def refresh
      line = @entry ? RunHistory.line(@entry) : _INTL("Aucune partie terminée.")
      score = @entry ? RunHistory.score_text(@entry) : nil
      RunHistory.draw_card(self.bitmap, @panels, @selected, _INTL("Dernières parties"), score, line, @entry&.team, 80)
    end

    def dispose
      @panels.dispose
      self.bitmap.dispose
      super
    end
  end
end

# The title screen's commands are local to pbStartLoadScreen: the command is
# put after New Game when the scene starts, and the scene's answers after it
# are moved back by one. Playing a seed again answers New Game, its seed set
# for the new world. The panels are laid out again (ours is taller), and
# scroll up to show the one chosen.
class PokemonLoad_Scene
  alias_method :__run_history_pbStartScene, :pbStartScene
  alias_method :__run_history_pbChoose, :pbChoose
  alias_method :__run_history_pbUpdate, :pbUpdate

  def pbStartScene(commands, *args)
    @run_history_new_game = commands.index(_INTL("New Game"))
    @run_history_command = @run_history_new_game + 1
    commands.insert(@run_history_command, _INTL("Dernières parties"))
    __run_history_pbStartScene(commands, *args)
    old = @sprites["panel#{@run_history_command}"]
    panel = RunHistory::LoadPanel.new(RunHistory.highlighted, old.viewport)
    panel.x = old.x
    old.dispose
    @sprites["panel#{@run_history_command}"] = panel
    y = 32
    @run_history_panels = commands.length.times.map do |i|
      sprite = @sprites["panel#{i}"]
      sprite.y = y
      y += sprite.bitmap.height + 2
      [sprite, sprite.y]
    end
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
      seed = RunHistory::ListScene.new.main
      next if !seed
      MapProceduralGenerator.next_game_seed = seed
      return @run_history_new_game
    end
  end
end
