# Compiles Text_french_core/*.txt into Data/messages_french_core.dat, the same
# file that the Debug menu's "Compile translated text" writes in game.
#
#   ruby tools/translate/compile_texts.rb
require_relative "lib"

all_text = FrenchTr.compile
out = File.join(FrenchTr::ROOT, FrenchTr::DAT_FILE)
File.open(out, "wb") { |f| Marshal.dump(all_text, f) }
puts "#{all_text.compact.sum(&:size)} texts -> #{out}"
