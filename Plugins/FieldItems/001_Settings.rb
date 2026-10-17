#===============================================================================
# FieldItems - Settings
# Field moves (Cut, Surf...) are unlocked by key items given by NPCs, not by
# seals or by a Pokémon knowing the move. With the item, a party Pokémon that
# knows the move uses it; otherwise the player uses the item.
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
