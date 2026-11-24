#===============================================================================
# FamilyDebt - The usurer
# FamilyDebt.usurer, from his event: borrow (no debt), or pay back.
#===============================================================================
module FamilyDebt
  module_function

  def usurer
    debt ? pay_back_dialog : borrow_dialog
  end

  def borrow_dialog
    pbMessage(_INTL("Besoin d'argent ? La Famille prête à ses amis. Remboursement avant ton prochain sceau."))
    seals = $player.badge_count
    amounts = LOANS.map { |base| base * (1 + seals) }
    rate = rand(INTEREST)
    commands = amounts.map { |amount| _INTL("${1}", amount.to_s_formatted) } + [_INTL("Non merci")]
    index = pbMessage(_INTL("Combien ? Intérêts : {1} % à chaque dresseur que tu bats.", rate), commands, commands.length)
    if index >= amounts.length
      pbMessage(_INTL("Comme tu veux. La porte reste ouverte."))
      return
    end
    return if !pbConfirmMessage(_INTL("${1} à {2} % par dresseur battu, à rendre avant ton prochain sceau. Marché conclu ?",
                                      amounts[index].to_s_formatted, rate))
    borrow(amounts[index], rate)
    pbSEPlay("Mart buy item")
    pbMessage(_INTL("Tu reçois ${1}. La Famille n'oublie jamais une dette.", amounts[index].to_s_formatted))
  end

  def pay_back_dialog
    late = late?
    pbMessage(late ? _INTL("Tu es en retard. La Famille n'aime pas attendre.") : _INTL("Ah, notre débiteur préféré."))
    pbMessage(_INTL("Tu nous dois ${1} ({2} % par dresseur battu).", debt.amount.to_s_formatted, debt.rate))
    if $player.money == 0
      pbMessage(_INTL("Reviens quand tu auras de quoi payer."))
      return
    end
    paid = [$player.money, debt.amount].min
    return if !pbConfirmMessage(_INTL("Rembourser ${1} ?", paid.to_s_formatted))
    $player.money -= paid
    left = pay_off(paid)
    pbSEPlay("Mart buy item")
    pbMessage(left == 0 ? _INTL("Dette réglée. Un plaisir de faire affaire avec toi.") :
                          _INTL("Il reste ${1}. On se reverra.", left.to_s_formatted))
  end
end
