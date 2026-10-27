#===============================================================================
# Online - The other players in the world
# In a multiplayer game, this player's map, tiles walked, direction, sprite
# and speed are sent every POLL_INTERVAL while they change (and every
# POS_REFRESH anyway). A player on the same map appears there with their
# sprite and name, and walks the same tiles a moment later; talking to them
# proposes a duel or a trade, as from the room panel. They are not obstacles.
# The players' worlds come from the same seed, so their map ids are the same.
#===============================================================================
module Online
  @positions = {}   # Player id => their last "pos" message
  @ghosts = {}      # Player id => Ghost on this player's map
  @ghost_sprites = {}

  module_function

  # The direction (2, 4, 6, 8) from tile from to the next tile to, or nil when
  # it is not next to it.
  def step_dir(from, to)
    dx = to[0] - from[0]
    dy = to[1] - from[1]
    return nil if dx.abs + dy.abs != 1
    return { [0, 1] => 2, [-1, 0] => 4, [1, 0] => 6, [0, -1] => 8 }[[dx, dy]]
  end

  # Tiles of path to walk after last (the tile already walked to), without
  # repeating it; the newest MAX_STEPS at most.
  def new_steps(last, path)
    steps = []
    path.each do |tile|
      next if tile == (steps.last || last)
      steps.push(tile)
    end
    return steps.last(MAX_STEPS)
  end

  # Sends this player's position when it changed.
  def send_position
    map = $game_map.map_id
    tile = [$game_player.x, $game_player.y]
    look = [$game_player.direction, $game_player.character_name, $game_player.move_speed]
    if map != @pos_map
      @pos_map = map
      @path = [tile]
    elsif tile != (@path.last || @sent_tile)
      @path.push(tile)
      @path.shift if @path.length > MAX_STEPS
    end
    changed = !@path.empty? || look != @sent_look
    now = System.uptime
    return if now < (@next_pos || 0) || (!changed && now < (@pos_refresh || 0))
    path = @path.empty? ? [tile] : @path
    publish({ "kind" => "pos", "map" => map, "path" => path, "dir" => look[0], "sprite" => look[1],
              "speed" => look[2] })
    @sent_tile = path.last
    @sent_look = look
    @path = []
    @next_pos = now + POLL_INTERVAL
    @pos_refresh = now + POS_REFRESH
  end

  # Keeps another player's position, and moves or shows their Ghost.
  def position_event(from, info)
    return if from == data.you || !info["path"].is_a?(Array) || info["path"].empty?
    @positions[from] = info
    ghost = @ghosts[from]
    if ghost && info["map"] == $game_map.map_id
      ghost.follow(info)
    else
      remove_ghost(from)
      add_ghost(from, info) if info["map"] == $game_map.map_id
    end
  end

  # A player who left the room disappears.
  def forget_player(id)
    @positions.delete(id)
    remove_ghost(id)
  end

  def add_ghost(id, info)
    spriteset = $scene.is_a?(Scene_Map) ? $scene.spriteset : nil
    return if !spriteset
    ghost = Ghost.new($game_map, info)
    @ghosts[id] = ghost
    sprite = GhostSprite.new(Spriteset_Map.viewport, ghost, player_name(id))
    @ghost_sprites[id] = sprite
    spriteset.addUserSprite(sprite)
  end

  def remove_ghost(id)
    @ghosts.delete(id)
    @ghost_sprites.delete(id)&.dispose
  end

  # Out of the room: nobody else on the map any more.
  def clear_ghosts
    @ghost_sprites.each_value(&:dispose)
    @ghost_sprites.clear
    @ghosts.clear
    @positions.clear
  end

  # Ghosts of the players on this player's map, made again for each new map
  # sprites (new map, after a battle or a menu that hid the map).
  def rebuild_ghosts(spriteset)
    @ghost_spriteset = spriteset
    @ghost_map = $game_map.map_id
    @ghost_sprites.each_value(&:dispose)
    @ghost_sprites.clear
    @ghosts.clear
    @positions.each { |id, info| add_ghost(id, info) if info["map"] == @ghost_map }
  end

  def ghost_update
    return if !$scene.is_a?(Scene_Map)
    spriteset = $scene.spriteset
    rebuild_ghosts(spriteset) if spriteset != @ghost_spriteset || $game_map.map_id != @ghost_map
    @ghosts.each_value(&:update)
    send_position
    talk_to_ghost if Input.trigger?(Input::USE) && map_free?
  end

  # USE facing another player: duel, trade or nothing.
  def talk_to_ghost
    dir = $game_player.direction
    x = $game_player.x + { 4 => -1, 6 => 1 }.fetch(dir, 0)
    y = $game_player.y + { 8 => -1, 2 => 1 }.fetch(dir, 0)
    id, = @ghosts.find { |_id, ghost| ghost.x == x && ghost.y == y }
    return if !id
    choice = pbMessage(_INTL("{1}", player_name(id)), [_INTL("Défier"), _INTL("Échanger"), _INTL("Retour")], 3)
    request_meeting((choice == 0) ? :duel : :trade, id) if choice < 2
  end

  # Another player on this map, walking the tiles they send.
  class Ghost < Game_Character
    def initialize(map, info)
      super(map)
      @through = true
      @steps = []
      moveto(*info["path"].last)
      follow(info)
      @steps.clear
    end

    def follow(info)
      @character_name = info["sprite"].to_s
      @speed = info["speed"] || 3
      @facing = info["dir"]
      @steps.concat(Online.new_steps(@steps.last || [@x, @y], info["path"]))
      moveto(*@steps.shift) while @steps.length > MAX_STEPS   # Far behind: jumps
    end

    def update
      if !moving?
        if (tile = @steps.shift)
          self.move_speed = @speed + ((@steps.length >= CATCH_UP_STEPS) ? 1 : 0)
          dir = Online.step_dir([@x, @y], tile)
          dir ? move_generic(dir) : moveto(*tile)
        elsif @facing
          @direction = @facing
        end
      end
      super
    end
  end

  # The Ghost's sprite and their nickname above it.
  class GhostSprite
    def initialize(viewport, ghost, name)
      @sprite = Sprite_Character.new(viewport, ghost)
      @label = Sprite.new(viewport)
      @label.bitmap = Bitmap.new(128, 24)
      pbSetSmallFont(@label.bitmap)
      pbDrawTextPositions(@label.bitmap, [[name, 64, 2, :center, Color.new(248, 248, 248), Color.new(48, 48, 48)]])
      @label.ox = 64
    end

    def disposed?
      return @sprite.disposed?
    end

    def dispose
      return if disposed?
      @sprite.dispose
      @label.bitmap.dispose
      @label.dispose
    end

    def update
      return if disposed?
      @sprite.update
      @label.x = @sprite.x
      @label.y = @sprite.y - @sprite.oy - 20
      @label.z = @sprite.z + 1
    end
  end
end
