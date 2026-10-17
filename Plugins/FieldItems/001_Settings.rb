#===============================================================================
# FieldItems - Settings
# Field moves (Cut, Surf...) are replaced by key items given by NPCs: the
# player uses the item, no seal is needed and Pokémon no longer use these
# moves outside battle.
#===============================================================================
module FieldItems
  # Field move => key item that unlocks it (PBS/items.txt, pocket 8).
  ITEMS = {
    CUT:       :MACHETE,
    ROCKSMASH: :PICKAXE,
    STRENGTH:  :HARNESS,
    SURF:      :SURFSADDLE,
    WATERFALL: :GRAPPLINGHOOK,
    DIVE:      :DIVINGSUIT,
    FLY:       :FLYINGSADDLE,
    FLASH:     :LANTERN
  }
end
