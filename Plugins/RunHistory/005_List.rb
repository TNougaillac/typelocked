#===============================================================================
# RunHistory - The list of every game
# One card per game (region, outcome, score, its team's icons), the
# most recent first, CARDS_SHOWN on screen; Up and Down to choose, Use for the
# details (and playing its seed again), Back to leave. Left and Right switch
# to the BEST_SIZE best scores of all time, the best first.
#===============================================================================
module RunHistory
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
          show(!@best)
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

    # The last games, or the best scores.
    def show(best)
      @best = best
      @list = best ? RunHistory.best(@all) : @all.first(SIZE)
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
      show(false)
      pbFadeInAndShow(@sprites)
    end

    def refresh
      header = @sprites["header"].bitmap
      header.clear
      header.blt(0, 0, @panels.bitmap, Rect.new(0, 444, @panels.width, 46))
      title = @best ? _INTL("Meilleurs scores") : _INTL("Dernières ({1}/{2})", @index + 1, @list.length)
      pbDrawTextPositions(header, [[title, 32, 14, :left, TEXT_COLOR, TEXT_SHADOW_COLOR],
                                   [@best ? _INTL("< Dernières") : _INTL("Meilleurs >"), @panels.width - 32, 14, :right,
                                    TEXT_COLOR, TEXT_SHADOW_COLOR]])
      top = (@index - CARDS_SHOWN + 1).clamp(0, [@list.length - CARDS_SHOWN, 0].max)
      CARDS_SHOWN.times do |k|
        entry = @list[top + k]
        card = @sprites["card#{k}"]
        card.visible = !entry.nil?
        next if !entry
        title = RunHistory.line(entry, false)
        title = "#{top + k + 1}. #{title}" if @best
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
