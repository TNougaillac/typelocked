#===============================================================================
# Interface4G - Settings
# Gen 4 frames already shipped with Essentials (Graphics/Windowskins). Plain
# Ruby: the CI checks that each file exists.
#===============================================================================
module Interface4G
  # Default menu frame (choices, Pause menu, options): the DPPt frame, put
  # first in Settings::MENU_WINDOWSKINS so a new game starts with it.
  MENU_FRAME = "choice dp"

  # Frame of the location sign by kind of generated map (the atlas kinds of
  # MapProceduralGenerator); any other map takes SIGN_DEFAULT.
  SIGN_FRAMES = {
    "ville"   => "sign hgss town",
    "village" => "sign hgss town",
    "ile"     => "sign hgss town",
    "route"   => "sign hgss dir",
    "grotte"  => "sign hgss loc"
  }.freeze
  SIGN_DEFAULT = "sign hgss tt"

  module_function

  # Frame (file name in Graphics/Windowskins) of the sign of that map kind.
  def sign_frame(kind)
    return SIGN_FRAMES[kind] || SIGN_DEFAULT
  end
end
