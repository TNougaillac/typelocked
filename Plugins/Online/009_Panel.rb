#===============================================================================
# Online - Room panel
# Pause menu > Salon, in a multiplayer game only: for each player of the
# room, their seals, place, team, deaths and score, who is connected, who
# lost their run (spectator) and who won the race. Choosing another connected
# player challenges them to a duel (011), once back on the map.
#===============================================================================
module Online
  class RoomPanel
    ROW_HEIGHT = 44
    TOP        = 34
    BASE       = Color.new(248, 248, 248)
    SHADOW     = Color.new(48, 48, 48)
    DIM        = Color.new(168, 168, 176)
    BACKGROUND = Color.new(28, 30, 40)
    ROW_COLOR  = Color.new(44, 47, 62)
    CURSOR     = Color.new(240, 200, 80)
    ICON_X     = 280
    ICON_STEP  = 36

    # The player to challenge to a duel, or nil.
    def main
      start
      chosen = nil
      loop do
        Graphics.update
        Input.update
        @sprites.each_value { |sprite| sprite.update if sprite.respond_to?(:update) }
        move_cursor(-1) if Input.repeat?(Input::UP)
        move_cursor(1) if Input.repeat?(Input::DOWN)
        break if Input.trigger?(Input::BACK)
        next if !Input.trigger?(Input::USE)
        chosen = @rows[@cursor]&.first if @cursor
        break
      end
      pbPlayCloseMenuSE
      pbDisposeSpriteHash(@sprites)
      @viewport.dispose
      return chosen
    end

    private

    # [id, name, status, connected] of each player, this one first.
    def rows
      room = Online.refresh_names || {}
      players = room["players"] || Online.data.players.keys.map { |id| { "id" => id, "connected" => false } }
      players = players.sort_by { |p| (p["id"] == Online.data.you) ? 0 : 1 }
      return players.first(8).map do |p|
        id = p["id"]
        status = (id == Online.data.you) ? Online.status : Online.data.players[id]
        [id, Online.player_name(id), status, p["connected"] || id == Online.data.you]
      end
    end

    def start
      @viewport = Viewport.new(0, 0, Graphics.width, Graphics.height)
      @viewport.z = 99_999
      @sprites = {}
      @sprites["overlay"] = BitmapSprite.new(Graphics.width, Graphics.height, @viewport)
      overlay = @sprites["overlay"].bitmap
      overlay.fill_rect(0, 0, Graphics.width, Graphics.height, BACKGROUND)
      pbSetSystemFont(overlay)
      texts = [[_INTL("Salon {1}", Online.data.code), 12, 8, :left, BASE, SHADOW]]
      winner = Online.data.winner
      texts.push([_INTL("Vainqueur : {1}", Online.player_name(winner)), Graphics.width - 12, 8, :right, BASE, SHADOW]) if winner
      pbDrawTextPositions(overlay, texts)
      pbSetSmallFont(overlay)
      @rows = rows
      @rows.each_with_index { |row, i| draw_row(overlay, i, *row) }
      # Other connected players can be challenged to a duel.
      @choices = @rows.each_index.select { |i| @rows[i][0] != Online.data.you && @rows[i][3] }
      @cursor = @choices.first
      @sprites["cursor"] = BitmapSprite.new(Graphics.width - 8, ROW_HEIGHT - 4, @viewport)
      @sprites["cursor"].x = 4
      draw_cursor
      footer = @cursor ? _INTL("C : défier ce joueur · Retour : fermer") : _INTL("Retour : fermer")
      return if TOP + (@rows.length * ROW_HEIGHT) > Graphics.height - 24   # No room left
      pbDrawTextPositions(overlay, [[footer, Graphics.width / 2, Graphics.height - 24, :center, DIM, SHADOW]])
    end

    def move_cursor(step)
      return if !@cursor || @choices.length < 2
      @cursor = @choices[(@choices.index(@cursor) + step) % @choices.length]
      pbPlayCursorSE
      draw_cursor
    end

    def draw_cursor
      sprite = @sprites["cursor"]
      sprite.visible = !@cursor.nil?
      return if !@cursor
      bitmap = sprite.bitmap
      bitmap.clear
      w = bitmap.width
      h = bitmap.height
      [[0, 0, w, 2], [0, h - 2, w, 2], [0, 0, 2, h], [w - 2, 0, 2, h]].each { |r| bitmap.fill_rect(*r, CURSOR) }
      sprite.y = TOP + (@cursor * ROW_HEIGHT)
    end

    def draw_row(overlay, index, id, name, status, connected)
      y = TOP + (index * ROW_HEIGHT)
      overlay.fill_rect(4, y, Graphics.width - 8, ROW_HEIGHT - 4, ROW_COLOR)
      tags = []
      tags.push(_INTL("hôte")) if id == Online.data.host
      tags.push(_INTL("absent")) if !connected
      tags.push(_INTL("spectateur")) if status&.[]("eliminated")
      tags.push(_INTL("vainqueur")) if id == Online.data.winner
      title = tags.empty? ? name : "#{name} (#{tags.join(', ')})"
      texts = [[title, 12, y + 2, :left, BASE, SHADOW]]
      if status
        texts.push([_INTL("Sceaux {1} · Morts {2} · {3} pts", status["seals"], status["deaths"], status["score"]),
                    12, y + 20, :left, DIM, SHADOW])
        texts.push([status["place"].to_s, ICON_X - 12, y + 2, :right, DIM, SHADOW])
        draw_team(index, y, status["team"] || [])
      else
        texts.push([_INTL("En attente de sa progression…"), 12, y + 20, :left, DIM, SHADOW])
      end
      pbDrawTextPositions(overlay, texts)
    end

    def draw_team(index, y, team)
      team.first(Settings::MAX_PARTY_SIZE).each_with_index do |member, slot|
        species = GameData::Species.try_get(member["species"].to_s.to_sym)
        next if !species
        icon = PokemonSpeciesIconSprite.new(species.species, @viewport)
        icon.pbSetParams(species.species, 0, member["form"] || 0, member["shiny"])
        icon.zoom_x = icon.zoom_y = 0.5
        icon.x = ICON_X + (slot * ICON_STEP)
        icon.y = y + 4
        icon.tone = Tone.new(0, 0, 0, 255) if member["dead"]   # Grey: dead
        @sprites["icon_#{index}_#{slot}"] = icon
      end
    end
  end
end

MenuHandlers.add(:pause_menu, :online_room, {
  "name"      => _INTL("Salon"),
  "order"     => 15,
  "condition" => proc { next Online.multi? },
  "effect"    => proc { |menu|
    pbPlayDecisionSE
    foe = nil
    pbFadeOutIn do
      foe = Online::RoomPanel.new.main
      menu.pbRefresh
    end
    next false if !foe || !pbConfirmMessage(_INTL("Défier {1} en combat ?", Online.player_name(foe)))
    Online.request_duel(foe)
    menu.pbEndScene
    $game_temp.in_menu = false
    next true
  }
})
