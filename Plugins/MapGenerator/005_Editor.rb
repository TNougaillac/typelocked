#===============================================================================
# MapGenerator - Restarts RPG Maker XP so it loads the generated maps
# RPG Maker XP keeps the project in memory: it only sees new map files after
# reopening the project. Windows only (tasklist, taskkill, start).
#===============================================================================
module MapGenerator
  EDITOR_EXE = "RPGXP.exe"

  module_function

  def windows?
    return RUBY_PLATFORM =~ /mingw|mswin/i
  end

  def editor_running?
    return false if !windows?
    return `tasklist /FI "IMAGENAME eq #{EDITOR_EXE}" /NH 2>NUL`.include?(EDITOR_EXE)
  end

  # Force-closes RPG Maker XP (no save prompt, so it can't overwrite the new
  # maps) and reopens the project. Returns false if it could not be done.
  def restart_editor
    return false if !windows?
    project = File.expand_path("Game.rxproj").tr("/", "\\")
    return false if !File.exist?(project)
    system("taskkill /IM #{EDITOR_EXE} /F >NUL 2>&1")
    10.times do
      break if !editor_running?
      sleep(0.2)
    end
    Process.detach(Process.spawn("cmd /c start \"\" \"#{project}\""))
    return true
  end

  # Called after generating: offers the restart, or explains the manual step.
  def offer_editor_restart
    if !editor_running?
      pbMessage(_INTL("RPG Maker XP n'est pas ouvert : les cartes y seront à l'ouverture du projet."))
      return
    end
    msg = _INTL("Rouvrir RPG Maker XP pour voir les cartes ? Il sera fermé sans enregistrer : les modifications faites dans l'éditeur depuis le lancement du test seront perdues.")
    return if !pbConfirmMessage(msg)
    return if restart_editor
    pbMessage(_INTL("Impossible de relancer RPG Maker XP. Ferme-le sans enregistrer, puis rouvre le projet."))
  end
end
