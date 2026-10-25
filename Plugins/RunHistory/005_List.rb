#===============================================================================
# RunHistory - The list of every game
# One card per game (region, type, outcome, its team's icons), the most
# recent first, CARDS_SHOWN on screen; Up and Down to choose, Use for the
# details (and playing its seed again), Back to leave.
#===============================================================================
module RunHistory
  class ListScene
    # Returns the seed to play again, nil if none.
    def main
      @list = RunHistory.entries
      if @list.empty?
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
        elsif Input.trigger?(Input::USE)
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

    def start
      @index = 0
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
      refresh
      pbFadeInAndShow(@sprites)
    end

    def refresh
      header = @sprites["header"].bitmap
      header.clear
      header.blt(0, 0, @panels.bitmap, Rect.new(0, 444, @panels.width, 46))
      pbDrawTextPositions(header, [[_INTL("Dernières parties ({1}/{2})", @index + 1, @list.length), 32, 14, :left,
                                    TEXT_COLOR, TEXT_SHADOW_COLOR]])
      top = (@index - CARDS_SHOWN + 1).clamp(0, [@list.length - CARDS_SHOWN, 0].max)
      CARDS_SHOWN.times do |k|
        entry = @list[top + k]
        card = @sprites["card#{k}"]
        card.visible = !entry.nil?
        next if !entry
        RunHistory.draw_card(card.bitmap, @panels, top + k == @index, RunHistory.line(entry), nil, entry.team, 36)
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
