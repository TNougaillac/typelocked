#===============================================================================
# LevelCap - « MAX » next to the level of a Pokémon at the cap
# In battle (the data boxes of the player's side) and on the party screen.
#===============================================================================
module LevelCap
  MAX_BATTLE_COLORS = [Color.new(232, 32, 16), Color.new(248, 168, 184)]
  MAX_PARTY_COLORS  = [Color.new(248, 200, 0), Color.new(96, 64, 0)]

  module_function

  # Draws « MAX » in the small font at x, y if pkmn is at the cap.
  def draw_max(bitmap, pkmn, x, y, colors)
    return if !pkmn || pkmn.egg? || !reached?(pkmn)
    pbSetSmallFont(bitmap)
    pbDrawTextPositions(bitmap, [[_INTL("MAX"), x, y, :left, *colors]])
    pbSetSystemFont(bitmap)
  end
end

class Battle::Scene::PokemonDataBox
  alias __levelcap_draw_level draw_level

  def draw_level
    __levelcap_draw_level
    return if !@battler.pbOwnedByPlayer?
    digits = @battler.level.to_s.length
    LevelCap.draw_max(self.bitmap, @battler.pokemon, @spriteBaseX + 164 + (digits * 16), 14,
                      LevelCap::MAX_BATTLE_COLORS)
  end
end

class PokemonPartyPanel
  alias __levelcap_draw_level draw_level

  def draw_level
    __levelcap_draw_level
    return if @pokemon.egg?
    bitmap = @overlaysprite.bitmap
    pbSetSmallFont(bitmap)
    x = 46 + bitmap.text_size(@pokemon.level.to_s).width
    pbSetSystemFont(bitmap)
    LevelCap.draw_max(bitmap, @pokemon, x, 68, LevelCap::MAX_PARTY_COLORS)
  end
end
