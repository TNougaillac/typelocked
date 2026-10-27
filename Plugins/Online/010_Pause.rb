#===============================================================================
# Online - Pause of the room
# In a multiplayer game, the whole room waits while a player is disconnected
# (or this player is cut off from the room). After KICK_AFTER seconds, the
# host can remove the missing player, and a player cut off can leave the
# room; both then play solo. Checked on the map, outside messages.
#===============================================================================
module Online
  module_function

  # Why the room is paused (:bridge, :self, :others), or nil.
  def pause_reason(room)
    return :bridge if room.nil?
    return nil if room["kicked"]
    return :self if room["connected"] == false
    return :others if room["started"] && room["allConnected"] == false
    return nil
  end

  # True when it took the frame: paused, or removed from the room.
  def pause_update
    return false if !polled? || $game_temp.message_window_showing
    if room&.[]("kicked")
      pbMessage(_INTL("L'hôte t'a retiré du salon : ta partie continue en solo."))
      leave_room
      return true
    end
    return false if !pause_reason(room)
    PauseScreen.new.main
    return true
  end

  # The game goes on solo: no room, no panel.
  def leave_room
    clear_ghosts
    $online = nil
    @inbox.clear
    @room = nil
    @polled = false
  end

  # Disconnected players of the room, longest gone first.
  def missing_players(room)
    gone = (room&.[]("players") || []).reject { |p| p["connected"] }
    return gone.sort_by { |p| -(p["goneFor"] || 0) }
  end

  def duration_text(seconds)
    return format("%d:%02d", seconds / 60, seconds % 60)
  end

  class PauseScreen
    def main
      @viewport = Viewport.new(0, 0, Graphics.width, Graphics.height)
      @viewport.z = 99_999
      @window = Window_UnformattedTextPokemon.newWithSize("", 0, Graphics.height - 128, Graphics.width, 128, @viewport)
      @window.setSkin(MessageConfig.pbGetSpeechFrame)
      @start = System.uptime
      refresh
      loop do
        Graphics.update
        Input.update
        @window.update
        if System.uptime >= @next_poll
          Bridge.retry_now
          Online.poll_now
          break if !Online.multi? || !Online.pause_reason(Online.room)
          refresh
        end
        break if Input.trigger?(Input::ACTION) && kick
        break if Input.trigger?(Input::BACK) && leave
      end
    ensure
      @window&.dispose
      @viewport&.dispose
    end

    private

    def refresh
      @next_poll = System.uptime + POLL_INTERVAL
      room = Online.room
      reason = Online.pause_reason(room)
      lines = []
      case reason
      when :bridge
        lines.push(_INTL("Partie en pause : le pont ne répond plus. Relance-le pour reprendre."))
      when :self
        lines.push(_INTL("Partie en pause : connexion au salon perdue, reconnexion…"))
      else
        missing = Online.missing_players(room)
        names = missing.map { |p| p["name"] }.join(", ")
        lines.push(_INTL("Partie en pause : {1} déconnecté depuis {2}.", names,
                         Online.duration_text(missing.first&.[]("goneFor") || 0)))
        if host?
          target = kickable(room)
          lines.push(target ? _INTL("Z : retirer {1} du salon.", target["name"]) :
                              _INTL("Tu pourras retirer un joueur absent depuis {1}.", Online.duration_text(KICK_AFTER)))
        end
      end
      lines.push(_INTL("Retour : quitter le salon et jouer en solo.")) if cut_off_long?(reason)
      @window.text = lines.join("\n")
    end

    def host?
      return Online.data.host == Online.data.you
    end

    def kickable(room)
      return Online.missing_players(room).find { |p| (p["goneFor"] || 0) >= KICK_AFTER }
    end

    # This player is cut off from the room for KICK_AFTER seconds.
    def cut_off_long?(reason)
      return %i[bridge self].include?(reason) && System.uptime - @start >= KICK_AFTER
    end

    def kick
      return false if !host? || Online.pause_reason(Online.room) != :others
      target = kickable(Online.room)
      return false if !target
      return false if !pbConfirmMessage(_INTL("Retirer {1} du salon ? Sa partie continuera en solo.", target["name"]))
      Bridge.kick(target["id"])
      Online.poll_now
      refresh
      return !Online.pause_reason(Online.room)
    end

    def leave
      return false if !cut_off_long?(Online.pause_reason(Online.room))
      return false if !pbConfirmMessage(_INTL("Quitter le salon ? Ta partie continuera en solo, sans retour possible."))
      Online.leave_room
      return true
    end
  end
end
