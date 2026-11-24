#===============================================================================
# WorldEvents - Called by the events in game
# Their texts come from dialogues.txt (say, line).
#===============================================================================
module WorldEvents
  module_function

  # The professor: greets the player, then opens the lab's Poké Balls (lab) or
  # offers the three starters in a list.
  # After a seal: the lieutenant's three rewards, the player keeps one (no
  # cancel). tm: an item or nil; held: an item, BOOSTER = the item of the
  # player's type; pack: [[item, quantity]].
  def seal_loot(tm, held, pack)
    held = TYPE_BOOSTERS.fetch(Monotype.data.type, :EXPERTBELT) if held == :BOOSTER
    options = []
    if tm && GameData::Item.exists?(tm)
      item = GameData::Item.get(tm)
      options.push([_INTL("CT : {1}", GameData::Move.get(item.move).name), [[tm, 1]]])
    end
    options.push([_INTL("Objet tenu : {1}", GameData::Item.get(held).name), [[held, 1]]])
    pack_name = pack.map { |id, qty| "#{qty} #{qty > 1 ? GameData::Item.get(id).name_plural : GameData::Item.get(id).name}" }
    options.push([_INTL("Lot : {1}", pack_name.join(", ")), pack])
    loop do
      index = pbMessage(_INTL("Choisis ta récompense."), options.map(&:first), 0)
      next if !pbConfirmMessage(_INTL("Prendre « {1} » ? Les autres seront perdues.", options[index][0]))
      options[index][1].each { |id, qty| pbReceiveItem(id, qty) }
      return
    end
  end

  def professor(lab)
    return say("professeur_apres") if Monotype.data.starter_given
    say("professeur_intro") if !$game_switches[CHOOSING_STARTER_SWITCH]
    if lab
      $game_switches[CHOOSING_STARTER_SWITCH] = true
      $game_map.need_refresh = true
      say("professeur_balls")
      return
    end
    Monotype.starter_dialog
    return if !Monotype.data.starter_given
    pbSet(STARTER_VARIABLE, 1)
    give_pokedex
  end

  # A Poké Ball of the lab: true once its starter is taken.
  def starter_ball(index)
    if !$game_switches[CHOOSING_STARTER_SWITCH]
      say("ball")
      return false
    end
    return false if !Monotype.starter_ball(index)
    $game_switches[CHOOSING_STARTER_SWITCH] = false
    pbSet(STARTER_VARIABLE, index + 1)
    give_pokedex
    return true
  end

  # The professor gives the Pokédex with the starter (#115).
  def give_pokedex
    return if $player.has_pokedex
    say("professeur_pokedex")
    $player.has_pokedex = true
    pbMessage(_INTL("\\me[Key item get]{1} reçoit le Pokédex !\\wtnp[30]", $player.name))
  end

  # The clerk of a shop where that many seals are won on the way.
  # A shop (#176): the Family's margin (MART_PRICE_FACTOR) until the guild
  # switch freed, if any, is on.
  def mart(seals, freed = nil)
    stock = mart_stock(seals)
    margin = (freed && $game_switches[freed]) ? 1 : MART_PRICE_FACTOR
    stock.each { |item| buy_price(item, margin) }
    pbPokemonMart(stock, line(margin == 1 ? "vendeur_libre" : "vendeur"))
  end

  # The travelling merchant (#176): basics a bit cheaper than the shop,
  # rares ([item, price]) dear. He cannot buy.
  def merchant(basics, rares)
    basics.each { |item| buy_price(item, MART_PRICE_FACTOR * MERCHANT_BASIC_FACTOR) }
    rares.each { |item, price| $game_temp.mart_prices[item] = [price, -1] }
    pbPokemonMart(basics + rares.map(&:first), line("marchand"), true)
  end

  # This mart's buy price of item: its PBS price times factor (selling back
  # keeps the PBS sell price). pbPokemonMart clears it.
  def buy_price(item, factor)
    $game_temp.mart_prices[item] = [(GameData::Item.get(item).price * factor).round, -1]
  end

  # An exit of the first town, before the starter.
  def gate
    say("garde")
    pbMoveRoute($game_player, [PBMoveRoute::BACKWARD], true)
  end

  # A Move Relearner: a move remembered for a Heart Scale.
  def relearner
    say("maitre_intro")
    return say("maitre_sans_ecaille") if !$bag.has?(HEART_SCALE)
    return say("maitre_aucun") if $player.party.none?(&:can_relearn_move?)
    pbChoosePokemon(1, 3, proc { |pkmn| pkmn.can_relearn_move? })
    return if pbGet(1) < 0
    return if !pbRelearnMoveScreen($player.party[pbGet(1)])
    $bag.remove(HEART_SCALE)
    say("maitre_fin")
  end

  # The nurse, before healing (#114): FREE_HEALS free heals in each Centre,
  # then HEAL_PRICES by the seals won. false: no heal (refused, or not enough
  # money).
  def nurse_pay
    heals = $PokemonGlobal.centre_heals
    count = heals[$game_map.map_id] || 0
    if count >= FREE_HEALS
      price = HEAL_PRICES[[$player.badge_count, HEAL_PRICES.length - 1].min]
      section = (count == FREE_HEALS) ? "infirmiere_fin_gratuit" : "infirmiere_prix"
      return false if !pbConfirmMessage(line(section, "prix" => price.to_s_formatted))
      if $player.money < price
        say("infirmiere_sans_argent")
        return false
      end
      $player.money -= price
    end
    heals[$game_map.map_id] = count + 1
    return true
  end

  # The door of a room of the League, before its fight is won.
  def league_door
    say("porte_ligue")
    pbMoveRoute($game_player, [PBMoveRoute::BACKWARD], true)
  end

  # A rallied guild gives a Pokémon of the imposed type (#186): a gift, so
  # the Nuzlocke asks its nickname (pbNickname) and it can die like any other.
  def guild_pokemon(species, level)
    pbAddPokemon(species, level)
  end

  # A Pokémon found in a nook to come back to (#269): added like a capture
  # (the Nuzlocke nickname applies). False if the player can't take it (the
  # nook keeps it).
  def nook_pokemon(species, level)
    return pbAddPokemon(species, level)
  end

  # A beaten guild pays the player.
  def guild_money(amount)
    $player.money += amount
    pbMessage(_INTL("{1} reçoit {2} $ !", $player.name, amount.to_s_formatted))
  end

  # The settling of scores (#190): the player and the ally's leader against
  # the enemy's leader and its right hand; won, the enemy's switch is on,
  # as if its leader were beaten (its members leave, the ally's bonus).
  def showdown(partner_type, partner_name, leader_type, leader_name, second_type, second_name, switch)
    pbRegisterPartner(partner_type, partner_name, TRAINER_VERSION)
    setBattleRule("double")
    won = TrainerBattle.start(leader_type, leader_name, TRAINER_VERSION, second_type, second_name, TRAINER_VERSION)
    pbDeregisterPartner
    return if !won
    $game_switches[switch] = true
    $game_map.need_refresh = true
    say("guilde_reglement_fin")
  end

  # Arceus (interpreter: the event's, for OverworldBoss): beaten or caught,
  # the Pact is broken, the door of its room opens and the postgame begins
  # (#106: no level cap, the lieutenants' rematches).
  def arceus(interpreter, level, switch)
    outcome = interpreter.boss_battle(:ARCEUS, level, **ARCEUS_BOSS)
    return if ![1, 4].include?(outcome)
    $game_switches[switch] = true
    $game_switches[POSTGAME_SWITCH] = true
    $game_map.need_refresh = true
    say("arceus_fin")
  end

  # A statue of a generated gym (#121, Statue<rank> of count): lit once
  # touched (its self switch A). Ordered: it says its number, and a statue
  # touched out of turn puts them all out. The last one lit turns on switch,
  # which lifts the barriers around the lieutenant.
  def gym_statue(rank, count, switch, ordered)
    statues = (1..count).map { |k| $game_map.events.values.find { |e| e.name.end_with?(" Statue#{k}") } }
    return if statues.include?(nil)
    key = ->(event) { [$game_map.map_id, event.id, "A"] }
    return say("arene_statue_deja") if $game_self_switches[key.call(statues[rank - 1])]
    say("arene_statue_rang", "rang" => rank.to_s) if ordered
    if ordered && statues.count { |e| $game_self_switches[key.call(e)] } != rank - 1
      statues.each { |e| $game_self_switches[key.call(e)] = false }
      pbSEPlay("GUI party switch")
      return say("arene_statue_erreur")
    end
    $game_self_switches[key.call(statues[rank - 1])] = true
    pbSEPlay("Voltorb Flip tile")
    say("arene_statue")
    return if statues.any? { |e| !$game_self_switches[key.call(e)] }
    $game_switches[switch] = true
    $game_map.need_refresh = true
    pbSEPlay("Door slide")
    say("arene_ouverte")
  end

  # After pushing a boulder of a generated gym (#121, tranche 5, event id
  # pushed): a sound if it lies on one of the plates, the switch on once
  # every plate holds a boulder, and the boulders back in place (the player
  # at the entry) if the push shut the player away from the entry.
  def gym_plates(switch, plates, pushed, entry)
    stones = $game_map.events.values.select { |e| e.name =~ / Rocher\d+\z/ }
    event = $game_map.events[pushed]
    if event && !$game_switches[switch] && plates.include?([event.x, event.y])
      say("arene_dalle")
      if plates.all? { |cell| stones.any? { |e| [e.x, e.y] == cell } }
        $game_switches[switch] = true
        $game_map.need_refresh = true
        pbSEPlay("Door slide")
        say("arene_ouverte")
      end
    end
    return if player_reach[entry]
    say("arene_rochers_coinces")
    pbFadeOutIn do
      stones.each do |e|
        e.moveto(e.instance_variable_get(:@original_x), e.instance_variable_get(:@original_y))
        $PokemonMap&.movedEvents&.delete([$game_map.map_id, e.id])
      end
      $game_player.moveto(*entry)
      $game_map.need_refresh = true
    end
  end

  # { [x, y] => true } of the cells the player can walk to from where he stands.
  def player_reach
    seen = { [$game_player.x, $game_player.y] => true }
    queue = seen.keys
    until queue.empty?
      x, y = queue.shift
      { 2 => [0, 1], 4 => [-1, 0], 6 => [1, 0], 8 => [0, -1] }.each do |dir, (dx, dy)|
        cell = [x + dx, y + dy]
        next if seen[cell] || !$game_player.passable?(x, y, dir)
        seen[cell] = true
        queue.push(cell)
      end
    end
    return seen
  end
end

# Heals done in each Centre (map ID => count), saved with the game.
class PokemonGlobalMetadata
  def centre_heals
    @centre_heals ||= {}
    return @centre_heals
  end
end

# A double battle (DoubleBattle = oui) with fewer than two able Pokémon is
# fought single (#123).
class << TrainerBattle
  alias_method :__world_events_start_core, :start_core

  def start_core(*args)
    setBattleRule("single") if $game_temp.battle_rules["size"] == "double" && !pbCanDoubleBattle?
    return __world_events_start_core(*args)
  end
end

# A defeat opens the guilds' dungeons again (#335): the player wakes at a
# Centre, the exits closed by GUILD_LOCK_SWITCH no longer hold them.
alias __world_events_pbStartOver pbStartOver

def pbStartOver(*args)
  (1..WorldEvents::GUILD_LOCKS).each { |i| $game_switches[WorldEvents::GUILD_LOCK_SWITCH + i] = false }
  return __world_events_pbStartOver(*args)
end
