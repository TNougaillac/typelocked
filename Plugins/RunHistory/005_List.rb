#===============================================================================
# RunHistory - The list of every game
# One card per game (region, outcome, score, its team's icons), the
# most recent first, CARDS_SHOWN on screen; Up and Down to choose, Use for the
# details (and playing its seed again), Back to leave. Left and Right switch
# to the BEST_SIZE best scores of all time, the best first, then to the views
# other plugins add (RunHistory.extra_views).
#===============================================================================
module RunHistory
  # A list of games shown in the list: name (in the header's « Next > »),
  # title (header, given the index and the length), games, ranked (numbered
  # cards), label (card title of an entry, nil: RunHistory.line).
  View = Struct.new(:name, :title, :games, :ranked, :label)

  module_function

  # Views added after the last games and the best scores (aliased by other
  # plugins).
  def extra_views
    return []
  end

  class ListScene
    # Returns the seed to play again, nil if none.
    def main
      @all = RunHistory.entries
      if @all.empty?
        pbMessage(_INTL("Aucune partie enregistrée pour l'instant."))
        return nil
      end
      start
      seed = nil
      loop do
        Graphics.update
        Input.update
        if Input.repeat?(Input::UP) && @index > 0
          pbPlayCursorSE
          @index -= 1
          refresh
        elsif Input.repeat?(Input::DOWN) && @index < @list.length - 1
          pbPlayCursorSE
          @index += 1
          refresh
        elsif Input.trigger?(Input::LEFT) || Input.trigger?(Input::RIGHT)
          pbPlayCursorSE
          show((@view + (Input.trigger?(Input::RIGHT) ? 1 : -1)) % @views.length)
        elsif Input.trigger?(Input::USE) && @list[@index]
          pbPlayDecisionSE
          seed = RunHistory.details(@list[@index])
          break if seed
        elsif Input.trigger?(Input::BACK)
          pbPlayCloseMenuSE
          break
        end
      end
      finish
      return seed
    end

    def views
      return [View.new(_INTL("Dernières"), ->(i, n) { _INTL("Dernières ({1}/{2})", i + 1, n) }, @all.first(SIZE), false),
              View.new(_INTL("Meilleurs"), ->(_i, _n) { _INTL("Meilleurs scores") }, RunHistory.best(@all), true)] +
             RunHistory.extra_views
    end

    # The view of that index.
    def show(view)
      @view = view
      @list = @views[view].games
      @index = 0
      refresh
    end

    def start
      @viewport = Viewport.new(0, 0, Graphics.width, Graphics.height)
      @viewport.z = 99_998
      @panels = AnimatedBitmap.new("Graphics/UI/Load/panels")
      @sprites = {}
      addBackgroundOrColoredPlane(@sprites, "background", "Load/bg", Color.new(248, 248, 248), @viewport)
      @sprites["header"] = BitmapSprite.new(@panels.width, 46, @viewport)
      @sprites["header"].x = 48
      @sprites["header"].y = 8
      pbSetSystemFont(@sprites["header"].bitmap)
      CARDS_SHOWN.times do |k|
        card = BitmapSprite.new(@panels.width, CARD_HEIGHT, @viewport)
        card.x = 48
        card.y = 60 + (k * (CARD_HEIGHT + 2))
        pbSetSystemFont(card.bitmap)
        @sprites["card#{k}"] = card
      end
      @views = views
      show(0)
      pbFadeInAndShow(@sprites)
    end

    def refresh
      header = @sprites["header"].bitmap
      header.clear
      header.blt(0, 0, @panels.bitmap, Rect.new(0, 444, @panels.width, 46))
      view = @views[@view]
      following = @views[(@view + 1) % @views.length]
      pbDrawTextPositions(header, [[view.title.call(@index, @list.length), 32, 14, :left, TEXT_COLOR, TEXT_SHADOW_COLOR],
                                   ["#{following.name} >", @panels.width - 32, 14, :right, TEXT_COLOR, TEXT_SHADOW_COLOR]])
      top = (@index - CARDS_SHOWN + 1).clamp(0, [@list.length - CARDS_SHOWN, 0].max)
      CARDS_SHOWN.times do |k|
        entry = @list[top + k]
        card = @sprites["card#{k}"]
        card.visible = !entry.nil?
        next if !entry
        title = view.label ? view.label.call(entry) : RunHistory.line(entry, false)
        title = "#{top + k + 1}. #{title}" if view.ranked
        RunHistory.draw_card(card.bitmap, @panels, top + k == @index, title, RunHistory.score_text(entry), nil,
                             entry.team, 36)
      end
    end

    def finish
      pbFadeOutAndHide(@sprites)
      pbDisposeSpriteHash(@sprites)
      @panels.dispose
      @viewport.dispose
    end
  end
end
