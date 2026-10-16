#===============================================================================
# Monotype - Start-of-game dialog
# Shown automatically at the start of a new game (NewGameSetup plugin), after
# the Nuzlocke choice. Can also be called from an event: Monotype.setup_dialog
#===============================================================================
module Monotype
  module_function

  def rules_text
    [
      _INTL("Tu joues avec un seul type. Normal : le type est tiré au hasard. Facile : tu le choisis."),
      _INTL("Capture : seulement les Pokémon du type, ou qui l'obtiennent en évoluant."),
      _INTL("Un Pokémon qui perd le type en évoluant devient inutilisable et part au PC."),
      _INTL("Dons et échanges hors du type : envoyés au PC, inutilisables."),
      _INTL("Le starter reste utilisable jusqu'à ta première capture, et jamais dans une arène ni à la Ligue.")
    ]
  end

  def activate(type)
    data.type   = type
    data.active = true
    data.chosen = true
    claim_starter($player.party[0])
  end

  # Returns the chosen type, or nil if cancelled.
  def choose_type
    types = available_types
    names = types.map { |t| GameData::Type.get(t).name }
    index = pbMessage(_INTL("Quel type veux-tu ?"), names + [_INTL("Retour")], names.length + 1)
    types[index]
  end

  def setup_dialog
    return if data.chosen
    commands = [_INTL("Normal (type au hasard)"), _INTL("Facile (type au choix)"), _INTL("Voir les règles")]
    loop do
      case pbMessage(_INTL("Mode Monotype : choisis ta difficulté."), commands, -1)
      when 0
        next if !pbConfirmMessage(_INTL("Laisser le hasard choisir ton type ? Ce choix est définitif."))
        activate(available_types.sample)
        pbMessage(_INTL("Le hasard a choisi : type {1} !", type_name))
        return
      when 1
        type = choose_type
        next if !type
        next if !pbConfirmMessage(_INTL("Jouer avec le type {1} ? Ce choix est définitif.",
                                        GameData::Type.get(type).name))
        activate(type)
        return
      when 2
        rules_text.each { |line| pbMessage(line) }
      end
    end
  end
end

NewGameSetup.add(:monotype, 20) { Monotype.setup_dialog }
