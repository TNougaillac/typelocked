#===============================================================================
# FastPace - Choice of the next Repel
# When a Repel wears off, the Repels in the Bag open in the same carousel as the
# Poké Ball shortcut of wild battles (Enhanced Battle UI), to pick one or none.
#===============================================================================
module FastPace
  class RepelSelection
    PATH         = "Graphics/Plugins/Enhanced Battle UI/"
    BASE_LIGHT   = Color.new(248, 248, 248)
    SHADOW_LIGHT = Color.new(32, 32, 32)
    BASE_DARK    = Color.new(56, 56, 56)
    SHADOW_DARK  = Color.new(184, 184, 184)
    BALL_X       = [64, 146, 256, 366, 448]

    # items: [[item, quantity], ...]. Returns the chosen item, or nil.
    def initialize(items)
      @items = [[nil], *items, [nil]]
      @index = 1
      @show_desc = false
    end

    def main
      start
      chosen = nil
      loop do
        Graphics.update
        Input.update
        @sprites["leftarrow"].update
        @sprites["rightarrow"].update
        @sprites["prompt"].update
        old = [@index, @show_desc]
        if Input.trigger?(Input::USE)
          item = @items[@index][0]
          item ? pbPlayDecisionSE : pbPlayCloseMenuSE
          chosen = item
          break
        elsif Input.trigger?(Input::BACK)
          pbPlayCloseMenuSE
          break
        elsif Input.trigger?(Input::ACTION)
          @show_desc = !@show_desc
          pbPlayDecisionSE
        elsif Input.repeat?(Input::LEFT)
          @index = (@index - 1) % @items.length
        elsif Input.repeat?(Input::RIGHT)
          @index = (@index + 1) % @items.length
        elsif Input.trigger?(Input::JUMPUP)
          @index = 0
        elsif Input.trigger?(Input::JUMPDOWN)
          @index = @items.length - 1
        end
        next if old == [@index, @show_desc]
        pbPlayCursorSE if old[0] != @index
        refresh
      end
      pbDisposeSpriteHash(@sprites)
      @viewport.dispose
      return chosen
    end

    private

    def start
      @viewport = Viewport.new(0, 0, Graphics.width, Graphics.height)
      @viewport.z = 99_999
      @sprites = {}
      @box_y = Graphics.height - 96
      @sprites["prompt"] = Window_UnformattedTextPokemon.newWithSize(
        _INTL("L'effet du Repousse est terminé ! En utiliser un autre ?"),
        0, @box_y, Graphics.width, 96, @viewport
      )
      @sprites["prompt"].setSkin(MessageConfig.pbGetSpeechFrame)
      @sprites["overlay"] = BitmapSprite.new(Graphics.width, Graphics.height, @viewport)
      pbSetSmallFont(@sprites["overlay"].bitmap)
      %w[left right].each do |side|
        arrow = AnimatedSprite.new("Graphics/UI/#{side}_arrow", 8, 40, 28, 2, @viewport)
        arrow.x = (side == "left") ? 174 : 298
        arrow.y = @box_y - 56
        arrow.z = 2
        arrow.play
        @sprites["#{side}arrow"] = arrow
      end
      BALL_X.each_with_index do |x, i|
        @sprites["ball_icon#{i}"] = ItemIconSprite.new(x, @box_y - 56, nil, @viewport)
        @sprites["ball_icon#{i}"].z = 1
        pbAddSpriteOutline(["ball_icon#{i}", @viewport, nil, PictureOrigin::CENTER])
      end
      refresh
    end

    # Same drawing as Battle::Scene#pbUpdateBallSelection.
    def refresh
      overlay = @sprites["overlay"].bitmap
      overlay.clear
      ypos = @box_y - 128
      images = [[PATH + "pokeball_bg", 0, ypos]]
      images.push([PATH + "pokeball_desc", 0, ypos - 69]) if @show_desc
      text_y = @show_desc ? ypos - 55 : ypos + 14
      item = GameData::Item.try_get(@items[@index][0])
      name = item ? item.name : _INTL("Retour")
      desc = item ? item.description : _INTL("Ne pas utiliser d'autre Repousse.")
      texts = [
        [_INTL("C : Utiliser"), 46, text_y, :center, BASE_LIGHT],
        [@show_desc ? _INTL("Z : Cacher") : _INTL("Z : Détails"), Graphics.width - 46, text_y, :center, BASE_LIGHT],
        [name, Graphics.width / 2, text_y, :center, BASE_LIGHT, SHADOW_LIGHT, :outline]
      ]
      ((@index - 2)..(@index + 2)).each_with_index do |pos, i|
        entry = (pos >= 0) ? @items[pos] : nil
        update_icon(i, entry && entry[0], entry.nil?)
        next if !entry || !entry[0]
        colors = (pos == @index) ? [BASE_LIGHT, SHADOW_LIGHT, :outline] : [BASE_DARK, SHADOW_DARK]
        texts.push([entry[1].to_s, @sprites["ball_icon#{i}"].x + ((pos == @index) ? 2 : 0), @box_y - 25, :center, *colors])
      end
      @sprites["leftarrow"].visible = @index > 0
      @sprites["rightarrow"].visible = @index < @items.length - 1
      pbDrawImagePositions(overlay, images)
      pbDrawTextPositions(overlay, texts)
      drawTextEx(overlay, 10, ypos - 21, Graphics.width - 10, 2, desc, BASE_DARK, SHADOW_DARK) if @show_desc
    end

    def update_icon(index, item, blank)
      key = "ball_icon#{index}"
      @sprites[key].item = item
      @sprites[key].blankzero = blank
      pbUpdateOutline(key, item) if !blank
      pbShowOutline(key, !blank)
    end
  end
end

EventHandlers.remove(:on_player_step_taken, :repel_counter)
EventHandlers.add(:on_player_step_taken, :repel_counter,
  proc {
    next if $PokemonGlobal.repel <= 0 || $game_player.terrain_tag.ice   # Shouldn't count down if on ice
    $PokemonGlobal.repel -= 1
    next if $PokemonGlobal.repel > 0
    repels = []
    GameData::Item.each { |itm| repels.push([itm.id, $bag.quantity(itm.id)]) if itm.has_flag?("Repel") && $bag.has?(itm.id) }
    if repels.empty?
      pbMessage(_INTL("L'effet du Repousse est terminé !"))
      next
    end
    item = FastPace::RepelSelection.new(repels).main
    pbUseItem($bag, item) if item
  }
)
