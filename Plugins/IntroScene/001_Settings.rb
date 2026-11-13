#===============================================================================
# IntroScene - Settings
#===============================================================================
module IntroScene
  # Graphics/Pictures files.
  BACKGROUND = "introbg"
  PROFESSOR  = "introOak"

  # Playable characters (#290): PBS/metadata.txt player ID, menu label, and
  # the charset shown as preview (its front frame, Graphics/Characters).
  CHARACTERS = [
    { id: 1, label: "Ethan",  charset: "hero_boy" },
    { id: 2, label: "Lyra",   charset: "hero_girl" },
    { id: 3, label: "Louka",  charset: "hero_lucas" },
    { id: 4, label: "Aurore", charset: "hero_dawn" }
  ]
  # Zoom of the previews (frames of 64x64, the DS sprites already x2)
  PREVIEW_ZOOM = 2

  # Bottom of the pictures, above the message window.
  PICTURE_BASELINE = 288

  # Fade in and out, in seconds.
  FADE_TIME = 0.4
end
