#===============================================================================
# Essentials v21.1 iterates over hash[:autotile] and hash[:tile] without a nil
# check (DungeonTileset#set_tile_type_ids), so a PBS/dungeon_tilesets.txt
# section with no "Autotile =" line (the double-walled dungeons and gym
# interiors, [33] onwards) crashes the PBS compiler. Treat a missing list as
# empty.
#===============================================================================
module GameData
  class DungeonTileset
    alias __typelocked_set_tile_type_ids set_tile_type_ids unless method_defined?(:__typelocked_set_tile_type_ids)

    def set_tile_type_ids(hash)
      __typelocked_set_tile_type_ids({ autotile: [], tile: [] }.merge(hash.compact))
    end
  end
end
