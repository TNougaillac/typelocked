#===============================================================================
# Online - Room panel
# Pause menu > Salon, in a multiplayer game only: for each player of the
# room, their seals, place, team, deaths and score, who is connected, who
# lost their run (spectator) and who won the race.
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
    ICON_X     = 280
    ICON_STEP  = 36

    def main
      start
      loop do
        Graphics.update
        Input.update
        @sprites.each_value { |sprite| sprite.update if sprite.respond_to?(:update) }
        break if Input.trigger?(Input::BACK) || Input.trigger?(Input::USE)
      end
      pbPlayCloseMenuSE
      pbDisposeSpriteHash(@sprites)
      @viewport.dispose
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
      rows.each_with_index { |row, i| draw_row(overlay, i, *row) }
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
    pbFadeOutIn do
      Online::RoomPanel.new.main
      menu.pbRefresh
    end
    next false
  }
})
