#===============================================================================
# IntroScene - The professor's intro
# Professor Castellane tells the Pact, the player picks a character and a name,
# then the game modes (NewGameSetup), and he announces the imposed type. Shown
# on a background, before the first town of the generated world appears.
#===============================================================================
module IntroScene
  module_function

  def run
    create_sprites
    fade(255, 0)
    pbMessage(_INTL("Ah, enfin ! Approche, petit. Professeur Castellane, enchanté."))
    pbMessage(_INTL("Ici, pas d'État, pas de Ligue. Il y a la Famille. Elle tient la région, et crois-moi, personne ne s'en plaint."))
    pbMessage(_INTL("Il y a des siècles, la Famille a topé là avec Arceus en personne. Un Pacte. Et un Pacte, ça s'honore."))
    pbMessage(_INTL("À chaque génération, il désigne quelqu'un. Cette fois, c'est tombé sur toi. Un seul type, et tu montes jusqu'au Parrain. Quel honneur, hein ?"))
    choose_character
    choose_name
    pbMessage(_INTL("{1}… C'est bien le nom qu'on m'avait donné.", $player.name))
    Monotype.quiet_draw { NewGameSetup.run }
    pbMessage(_INTL("Le Pacte a parlé : type {1}. Me fais pas honte. On se revoit en ville.", Monotype.type_name))
    fade(0, 255)
  ensure
    dispose
  end

  def create_sprites
    @viewport = Viewport.new(0, 0, Graphics.width, Graphics.height)
    @viewport.z = 99_990   # Under the message windows (99999)
    @viewport.color = Color.new(0, 0, 0, 255)
    @sprites = {}
    @sprites[:bg] = picture(BACKGROUND, 0, 0)
    @sprites[:professor] = picture(PROFESSOR, Graphics.width / 2)
    CHARACTERS.each_with_index do |char, i|
      x = Graphics.width * (i + 1) / (CHARACTERS.length + 1)
      @sprites[char[:id]] = preview(char[:charset], x)
      @sprites[char[:id]].visible = false
    end
  end

  # Picture anchored at its bottom center (x), or at the top left with y.
  def picture(name, x, y = nil)
    sprite = IconSprite.new(x, y || PICTURE_BASELINE, @viewport)
    sprite.setBitmap("Graphics/Pictures/" + name)
    if !y && sprite.bitmap
      sprite.ox = sprite.bitmap.width / 2
      sprite.oy = sprite.bitmap.height
    end
    sprite
  end

  # Front frame of a charset (4x4 frames), zoomed, anchored at its bottom
  # center (x).
  def preview(charset, x)
    sprite = IconSprite.new(x, PICTURE_BASELINE, @viewport)
    sprite.setBitmap("Graphics/Characters/" + charset)
    if sprite.bitmap
      w = sprite.bitmap.width / 4
      h = sprite.bitmap.height / 4
      sprite.src_rect = Rect.new(0, 0, w, h)
      sprite.ox = w / 2
      sprite.oy = h
      sprite.zoom_x = sprite.zoom_y = PREVIEW_ZOOM
    end
    sprite
  end

  def fade(from, to)
    timer_start = System.uptime
    loop do
      alpha = lerp(from, to, FADE_TIME, timer_start, System.uptime)
      @viewport.color = Color.new(0, 0, 0, alpha)
      Graphics.update
      Input.update
      break if alpha == to
    end
  end

  def choose_character
    @sprites[:professor].visible = false
    CHARACTERS.each { |char| @sprites[char[:id]].visible = true }
    labels = CHARACTERS.map { |char| _INTL(char[:label]) }
    index = pbMessage(_INTL("Fais voir un peu ta bobine."), labels, 0)   # 0: no cancel
    pbChangePlayer(CHARACTERS[index][:id])
    CHARACTERS.each { |char| @sprites[char[:id]].visible = false }
    @sprites[:professor].visible = true
  end

  # Same as pbTrainerName, with a French prompt.
  def choose_name
    name = pbEnterPlayerName(_INTL("Ton nom ?"), 0, Settings::MAX_PLAYER_NAME_SIZE)
    if name.nil? || name.empty?
      meta = GameData::PlayerMetadata.get($player.character_ID)
      name = pbSuggestTrainerName(pbGetTrainerTypeGender(meta.trainer_type))
    end
    $player.name   = name
    $player.outfit = 0
  end

  def dispose
    @sprites&.each_value(&:dispose)
    @viewport&.dispose
    @sprites = nil
    @viewport = nil
  end
end

#===============================================================================
# A new game in a generated world plays the intro instead of MapProc's bare
# name entry, before the map scene starts.
#===============================================================================
module Game
  class << self
    alias_method :__introscene_start_new, :start_new

    def start_new
      __introscene_start_new
      return if !$game_temp.mapproc_name_entry
      $game_temp.mapproc_name_entry = false
      # The map scene has no sprites yet: messages must not update it.
      scene = $scene
      $scene = nil
      begin
        IntroScene.run
      ensure
        $scene = scene
      end
    end
  end
end
