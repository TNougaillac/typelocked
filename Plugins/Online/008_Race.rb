#===============================================================================
# Online - Live race
# In a multiplayer game, this player's progress is sent when it changes, with
# announcements; the other players' progress and announcements are kept and
# shown (008: announcements, 009: room panel in the Pause menu). The first
# player to beat Arceus wins the race.
#===============================================================================
module Online
  @news = []

  module_function

  # This player's progress, as sent to the room.
  def status
    league = (1..6).map { |n| $game_switches[WorldEvents::LEAGUE_SWITCH + n] }   # Anciens, Parrain, Arceus
    team = $player.party.map do |pkmn|
      { "species" => pkmn.species.to_s, "form" => pkmn.form, "level" => pkmn.level, "shiny" => pkmn.shiny?,
        "dead" => pkmn.run_history_dead? }
    end
    return {
      "kind" => "status", "seals" => $player.badge_count, "place" => $game_map.name, "team" => team,
      "deaths" => RunHistory.deaths, "elders" => league[0, 4].count(true), "godfather" => league[4],
      "won" => league[5], "eliminated" => eliminated?, "score" => RunHistory.score
    }
  end

  # Lost the Nuzlocke run: the player goes on as a spectator of the room.
  def eliminated?
    return !Nuzlocke.data.active && !Nuzlocke.data.graveyard_boxes.empty?
  end

  # Sends this player's progress when it changed, with its announcements.
  def send_status
    current = status
    return if current == data.last_status
    list = news(data.last_status, current)
    publish(current)
    list.each { |item| publish(item.merge("kind" => "news")) }
    if current["won"] && !data.winner
      data.winner = data.you
      @news.push(_INTL("Tu es le premier à battre Arceus : tu gagnes la course !"))
    end
    data.last_status = current
  end

  # Keeps what the other players sent.
  def handle(event)
    from = event["from"]
    info = event["data"] || {}
    case info["kind"]
    when "status"
      data.players[from] = info
    when "news"
      text = news_text(player_name(from), info)
      @news.push(text) if text
      if info["what"] == "arceus" && !data.winner
        data.winner = from
        @news.push(_INTL("{1} gagne la course !", player_name(from)))
      end
    end
  end

  # Nickname of a player of the room (asked to the bridge when unknown).
  def player_name(id)
    @names ||= {}
    refresh_names if !@names[id]
    return @names[id] || _INTL("Un joueur")
  end

  def refresh_names
    room = Bridge.state
    (room&.[]("players") || []).each { |p| @names[p["id"]] = p["name"] }
    return room
  end

  # The next announcement, once the player is free (no message, no event).
  def show_news
    return if @news.empty? || (@toast && !@toast.disposed?)
    return if $game_temp.message_window_showing || pbMapInterpreterRunning? || !$scene.is_a?(Scene_Map)
    @toast = NewsWindow.new(@news.shift)
    $scene.spriteset.addUserSprite(@toast)
  end

  def race_update
    return if !multi?
    @inbox.shift(@inbox.length).each { |event| handle(event) }
    if System.uptime >= (@next_status || 0)
      @next_status = System.uptime + STATUS_INTERVAL
      send_status
    end
    show_news
  end

  # An announcement in the top right corner, like the map name's sign.
  class NewsWindow
    APPEAR_TIME = 0.3

    def initialize(text)
      @window = Window_AdvancedTextPokemon.new(text)
      @window.resizeToFit(text, Graphics.width)
      @window.x = Graphics.width - @window.width
      @window.y = -@window.height
      @window.viewport = Viewport.new(0, 0, Graphics.width, Graphics.height)
      @window.viewport.z = 99_999
      @start = System.uptime
    end

    def disposed?
      return @window.disposed?
    end

    def dispose
      viewport = @window.viewport
      @window.dispose
      viewport&.dispose
    end

    def update
      return if disposed?
      @window.update
      return dispose if $game_temp.message_window_showing
      hide_at = @start + APPEAR_TIME + NEWS_TIME
      if System.uptime < hide_at
        @window.y = lerp(-@window.height, 0, APPEAR_TIME, @start, System.uptime)
      else
        @window.y = lerp(0, -@window.height, APPEAR_TIME, hide_at, System.uptime)
        dispose if @window.y + @window.height <= 0
      end
    end
  end
end

EventHandlers.add(:on_frame_update, :online_race,
  proc { Online.race_update }
)
