#===============================================================================
# Checks the French texts: every translation keeps the placeholders and control
# codes of its English line, and Data/messages_french_core.dat matches the
# files of Text_french_core/ (run tools/translate/compile_texts.rb if not).
#===============================================================================
require_relative "lib/ci"
require_relative "../translate/lib"

compiled = FrenchTr.compile { |file, message| CI.error(file, nil, message) }
dat = File.join(ROOT, FrenchTr::DAT_FILE)
if !File.exist?(dat)
  CI.error(dat, nil, "fichier absent : lancer ruby tools/translate/compile_texts.rb")
elsif Marshal.load(File.binread(dat)) != compiled
  CI.error(dat, nil, "pas à jour avec Text_french_core/ : lancer ruby tools/translate/compile_texts.rb")
end
CI.finish("Textes français")
