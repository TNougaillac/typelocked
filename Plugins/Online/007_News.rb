#===============================================================================
# Online - Announcements of the race
# A player's progress ("status") is compared with the one sent before: what
# changed becomes announcements for the other players. Plain Ruby.
#===============================================================================
module Online
  module_function

  # Announcements between two statuses of the same player (old nil: the
  # first status of the game, nothing to announce).
  def news(old, new)
    return [] if !old
    list = []
    list.push({ "what" => "seal", "count" => new["seals"] }) if new["seals"] > old["seals"]
    list.push({ "what" => "death", "count" => new["deaths"] - old["deaths"] }) if new["deaths"] > old["deaths"]
    list.push({ "what" => "elder", "count" => new["elders"] }) if new["elders"] > old["elders"]
    list.push({ "what" => "godfather" }) if new["godfather"] && !old["godfather"]
    list.push({ "what" => "arceus" }) if new["won"] && !old["won"]
    list.push({ "what" => "eliminated" }) if new["eliminated"] && !old["eliminated"]
    return list
  end

  def news_text(name, news)
    case news["what"]
    when "seal"
      return _INTL("{1} a gagné son 1er sceau !", name) if news["count"] == 1
      return _INTL("{1} a gagné son {2}e sceau !", name, news["count"])
    when "death"
      return _INTL("{1} a perdu un Pokémon.", name) if news["count"] == 1
      return _INTL("{1} a perdu {2} Pokémon.", name, news["count"])
    when "elder"     then return _INTL("{1} a battu un Ancien ({2}/4).", name, news["count"])
    when "godfather" then return _INTL("{1} a battu le Parrain !", name)
    when "arceus"    then return _INTL("{1} a battu Arceus !", name)
    when "eliminated" then return _INTL("{1} a perdu son run Nuzlocke : spectateur.", name)
    end
    return nil
  end
end
