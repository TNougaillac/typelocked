#===============================================================================
# Nuzlocke - Start-of-game dialog
# Shown automatically by the Monotype plugin; also usable as an event script.
#===============================================================================
module Nuzlocke
  module_function

  def rules_text
    [
      _INTL("Mort définitive : un Pokémon K.O. meurt et part dans une boîte Cimetière du PC."),
      _INTL("Surnoms obligatoires pour chaque Pokémon obtenu."),
      _INTL("Une seule capture possible par zone : la première rencontre."),
      _INTL("Clause des doublons : une espèce déjà capturée ne compte pas, la zone reste libre."),
      _INTL("Clause du shiny : un shiny est toujours capturable.")
    ]
  end

  def setup_dialog
    return if data.chosen
    commands = [_INTL("Nuzlocke"), _INTL("Normal"), _INTL("Voir les règles")]
    loop do
      index = pbMessage(_INTL("Quel mode de jeu veux-tu ?"), commands, -1)
      next if index < 0
      choice = commands[index]
      case choice
      when _INTL("Voir les règles")
        rules_text.each { |line| pbMessage(line) }
      when _INTL("Normal")
        next if !pbConfirmMessage(_INTL("Jouer en mode normal ? Ce choix est définitif."))
        data.chosen = true
        return
      else
        next if !pbConfirmMessage(_INTL("Activer le mode Nuzlocke ? Ce choix est définitif."))
        data.active = true
        data.chosen = true
        create_graveyard_box if data.graveyard_boxes.empty?
        return
      end
    end
  end
end
