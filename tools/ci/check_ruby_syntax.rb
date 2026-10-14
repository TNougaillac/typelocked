#===============================================================================
# Compiles every plugin script without running it, to catch syntax errors
# (missing "end", unclosed brackets...) before the game crashes on launch.
#===============================================================================
require_relative "lib/ci"

files = Dir.glob(File.join(ROOT, "Plugins", "**", "*.rb")).sort
files.each do |path|
  RubyVM::InstructionSequence.compile(CI.read_text(path), path)
rescue SyntaxError => e
  e.message.each_line do |line|
    next unless line =~ /\A#{Regexp.escape(path)}:(\d+): (.+)/
    CI.error(path, $1.to_i, $2.strip)
  end
  CI.error(path, nil, "erreur de syntaxe") if CI.errors.none? { |f, _, _| path.end_with?(f) }
end
puts "#{files.length} scripts compilés"
CI.finish("Syntaxe Ruby des plugins")
