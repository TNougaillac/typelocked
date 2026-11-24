#===============================================================================
# Interface4G - Frames
# The DPPt menu frame comes first among the menu frames (the Options screen
# still offers the others), and the location sign takes the HGSS sign of its
# kind of place (town, route, cave, other).
#===============================================================================
if !Settings::MENU_WINDOWSKINS.include?(Interface4G::MENU_FRAME)
  Settings::MENU_WINDOWSKINS.unshift(Interface4G::MENU_FRAME)
end

class LocationWindow
  alias_method :__interface4g_initialize, :initialize if !private_method_defined?(:__interface4g_initialize)

  def initialize(name)
    __interface4g_initialize(name)
    kind = defined?(MapProceduralGenerator) ? MapProceduralGenerator.spots($game_map.map_id)&.[](:kind) : nil
    @window.setSkin("Graphics/Windowskins/" + Interface4G.sign_frame(kind))
    @window.resizeToFit(name, Graphics.width)
    @window.y = -@window.height
  end
end
