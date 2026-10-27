#===============================================================================
# Online - Rules of the room
# What the host imposed when creating the room (strings and booleans, as the
# bridge sends them): "nuzlocke" ("required"/"free"), "typeDraw"
# ("required"/"free") and "sameType" (true/false). Monotype always applies
# (ADR 0001).
#===============================================================================
module Online
  module_function

  def nuzlocke_forced?(rules)
    return rules["nuzlocke"] == "required"
  end

  # The type imposed on this player, or nil when they choose as in a solo
  # game. One type for the whole room comes from the room's seed, so every
  # player draws the same; otherwise a required draw is this player's own.
  def forced_type(rules, seed, types, rng = Random)
    return types[Random.new(seed).rand(types.length)] if rules["sameType"]
    return types[rng.rand(types.length)] if rules["typeDraw"] == "required"
    return nil
  end
end
