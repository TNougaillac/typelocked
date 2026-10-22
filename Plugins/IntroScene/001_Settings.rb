#===============================================================================
# IntroScene - Settings
#===============================================================================
module IntroScene
  # Graphics/Pictures files.
  BACKGROUND = "introbg"
  PROFESSOR  = "introOak"

  # Playable characters: PBS/metadata.txt player ID, menu label, picture.
  CHARACTERS = [
    { id: 1, label: "Garçon", picture: "introBoy" },
    { id: 2, label: "Fille",  picture: "introGirl" }
  ]

  # Bottom of the pictures, above the message window.
  PICTURE_BASELINE = 288

  # Fade in and out, in seconds.
  FADE_TIME = 0.4
end
