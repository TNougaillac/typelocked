#===============================================================================
# FieldItems - Key items unlock field moves
# Essentials' field move code asks $player.get_pokemon_with_move(move) and
# checks the seal count; both are redirected to the key items here.
#===============================================================================
module FieldItems
  # Stands in for a Pokémon when the player uses the item himself: Essentials
  # then shows "<player> used <move>!" and no Pokémon animation.
  class User
    def name
      return $player.name
    end
  end

  module_function

  def unlocked?(move)
    return $DEBUG || $bag.has?(ITEMS[move])
  end

  def user
    return User.new
  end
end

class Player
  alias __fielditems_get_pokemon_with_move get_pokemon_with_move

  def get_pokemon_with_move(move)
    return __fielditems_get_pokemon_with_move(move) if !FieldItems::ITEMS.key?(move)
    return nil if !FieldItems.unlocked?(move)
    return __fielditems_get_pokemon_with_move(move) || FieldItems.user
  end
end

# The key items replace the seals.
def pbCheckHiddenMoveBadge(_badge = -1, _showmsg = true)
  return true
end

alias __fielditems_pbHiddenMoveAnimation pbHiddenMoveAnimation
def pbHiddenMoveAnimation(pokemon)
  return false if pokemon.is_a?(FieldItems::User)
  return __fielditems_pbHiddenMoveAnimation(pokemon)
end

# Party menu: a Pokémon knowing the move can't use it without the item.
module HiddenMoveHandlers
  class << self
    alias_method :__fielditems_triggerCanUseMove, :triggerCanUseMove

    def triggerCanUseMove(move, pkmn, showmsg)
      if FieldItems::ITEMS.key?(move) && !FieldItems.unlocked?(move)
        if showmsg
          pbMessage(_INTL("Il faut d'abord obtenir l'objet {1}.",
                          GameData::Item.get(FieldItems::ITEMS[move]).name))
        end
        return false
      end
      return __fielditems_triggerCanUseMove(move, pkmn, showmsg)
    end
  end
end

#===============================================================================
# Items used from the Bag: Fly and Flash have no event to interact with.
#===============================================================================
ItemHandlers::UseFromBag.add(:FLYINGSADDLE, proc { |_item|
  next (pbCanFly?(nil, true)) ? 2 : 0
})

ItemHandlers::UseInField.add(:FLYINGSADDLE, proc { |_item|
  next false if !pbCanFly?(nil, true)
  if $game_temp.fly_destination.nil?
    pbFadeOutIn do
      scene = PokemonRegionMap_Scene.new(-1, false)
      screen = PokemonRegionMapScreen.new(scene)
      $game_temp.fly_destination = screen.pbStartFlyScreen
    end
  end
  next false if $game_temp.fly_destination.nil?
  next pbFlyToNewLocation
})

ItemHandlers::UseFromBag.add(:LANTERN, proc { |_item|
  next (pbCanUseHiddenMove?(FieldItems.user, :FLASH)) ? 2 : 0
})

ItemHandlers::UseInField.add(:LANTERN, proc { |_item|
  next false if !pbCanUseHiddenMove?(FieldItems.user, :FLASH)
  next pbUseHiddenMove(FieldItems.user, :FLASH)
})
