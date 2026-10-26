#===============================================================================
# MapGenerator - Camera held at the edges without a neighbour
# Beyond a map's edge, the screen shows its connected maps; where none is in
# view on that side, it showed black. The camera now stops at that edge, as
# with the SnapEdges metadata, but only on those sides. A map smaller than
# the screen keeps Essentials' camera on that axis.
#===============================================================================
module MapGenerator
  module EdgeCamera
    module_function

    # [x, y, width, height] in tiles of each map connected to map_id, from
    # its top-left corner.
    def neighbours(map_id)
      @neighbours ||= {}
      return @neighbours[map_id] ||= begin
        list = []
        MapFactoryHelper.eachConnectionForMap(map_id) do |conn|
          other, x, y = (conn[0] == map_id) ? [conn[3], conn[1] - conn[4], conn[2] - conn[5]] : [conn[0], conn[4] - conn[1], conn[5] - conn[2]]
          w, h = MapFactoryHelper.getMapDims(other)
          list.push([x, y, w, h])
        end
        list
      end
    end

    def clear
      @neighbours = nil
    end

    # True if a neighbour touches that side of the map within the span
    # (from, to) of tiles along it.
    def neighbour?(map, side, from, to)
      return neighbours(map.map_id).any? do |x, y, w, h|
        case side
        when :left   then x + w == 0 && y < to && from < y + h
        when :right  then x == map.width && y < to && from < y + h
        when :top    then y + h == 0 && x < to && from < x + w
        when :bottom then y == map.height && x < to && from < x + w
        end
      end
    end

    # The display value held within the map on an axis, or nil to keep it:
    # start and along in tiles, size and screen along the axis.
    def hold(map, start, size, screen, along, along_screen, sides)
      return nil if size < screen
      return 0 if start < 0 && !neighbour?(map, sides[0], along, along + along_screen)
      return size - screen if start + screen > size && !neighbour?(map, sides[1], along, along + along_screen)
      return nil
    end
  end
end

class Game_Map
  alias __edge_camera_display_x_set display_x=
  alias __edge_camera_display_y_set display_y=

  def display_x=(value)
    __edge_camera_display_x_set(value)
    hold_camera
  end

  def display_y=(value)
    __edge_camera_display_y_set(value)
    hold_camera
  end

  # Both axes: moving along an edge brings a neighbour into view or out of it.
  def hold_camera
    return if !equal?($game_map)
    sw = Graphics.width.to_f / TILE_WIDTH
    sh = Graphics.height.to_f / TILE_HEIGHT
    x = @display_x.to_f / REAL_RES_X
    y = @display_y.to_f / REAL_RES_Y
    # Each axis looks along the other once that one is held
    held_y = MapGenerator::EdgeCamera.hold(self, y, height, sh, x, sw, %i[top bottom])
    held_x = MapGenerator::EdgeCamera.hold(self, x, width, sw, held_y || y, sh, %i[left right])
    held_y = MapGenerator::EdgeCamera.hold(self, y, height, sh, held_x || x, sw, %i[top bottom])
    __edge_camera_display_x_set((held_x * REAL_RES_X).round) if held_x
    __edge_camera_display_y_set((held_y * REAL_RES_Y).round) if held_y
  end
end

# The connections are read again after a world is written.
module MapFactoryHelper
  class << self
    alias __edge_camera_clear clear

    def clear
      __edge_camera_clear
      MapGenerator::EdgeCamera.clear
    end
  end
end
