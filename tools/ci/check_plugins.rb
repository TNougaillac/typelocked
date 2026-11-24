#===============================================================================
# Checks each plugin's meta.txt (required fields, Requires that point to an
# installed plugin) and that every text file the game reads is valid UTF-8.
#===============================================================================
require_relative "lib/ci"

ESSENTIALS_VERSION = "21.1"

# --- Encoding ---------------------------------------------------------------
text_files = Dir.glob(File.join(ROOT, "PBS", "*.txt")) +
             Dir.glob(File.join(ROOT, "MapGen", "*.txt")) +
             Dir.glob(File.join(ROOT, "MapEvents", "*.txt")) +
             Dir.glob(File.join(ROOT, "MapProc", "**", "*.txt")) +
             Dir.glob(File.join(ROOT, "Plugins", "**", "*.{rb,txt}"))
text_files.sort.each do |path|
  bytes = File.binread(path).force_encoding("UTF-8")
  next if bytes.valid_encoding?
  bad = bytes.each_line.find_index { |line| !line.valid_encoding? }
  CI.error(path, bad && bad + 1, "texte non UTF-8 (accents abîmés ? réenregistrer en UTF-8)")
end

# --- meta.txt ---------------------------------------------------------------
metas = Dir.glob(File.join(ROOT, "Plugins", "*", "meta.txt")).sort.to_h do |path|
  fields = []
  CI.read_text(path).each_line.with_index(1) do |raw, lineno|
    line = raw.strip
    next if line.empty? || line.start_with?("#")
    next CI.error(path, lineno, "attendu « Clé = valeur »") unless line =~ /\A(\w+)\s*=\s*(.*)\z/
    fields.push([$1, $2.strip, lineno])
  end
  [path, fields]
end
Dir.glob(File.join(ROOT, "Plugins", "*/")).sort.each do |dir|
  path = File.join(dir, "meta.txt")
  CI.error(path, nil, "meta.txt manquant") unless metas[path]
end

installed = {}
metas.each do |path, fields|
  value = ->(key) { fields.find { |k, _, _| k == key }&.at(1) }
  %w[Name Version Essentials].each do |key|
    CI.error(path, nil, "champ « #{key} » manquant") if value.call(key).to_s.empty?
  end
  if (name = value.call("Name"))
    CI.error(path, nil, "plugin « #{name} » déjà défini") if installed[name]
    installed[name] = value.call("Version")
  end
  version = value.call("Version")
  CI.error(path, nil, "Version « #{version} » invalide (ex. 1.2.0)") if version && version !~ /\A\d+(\.\d+)*\z/
  essentials = value.call("Essentials")
  if essentials && !essentials.split(",").map(&:strip).include?(ESSENTIALS_VERSION)
    CI.error(path, nil, "Essentials = #{essentials} : le projet est en v#{ESSENTIALS_VERSION}")
  end
end

# Requires = Name[,min version]; Essentials refuses to start without it.
metas.each do |path, fields|
  fields.each do |key, value, lineno|
    next unless key == "Requires"
    name, min = value.split(",").map(&:strip)
    if !installed.key?(name)
      CI.error(path, lineno, "plugin requis « #{name} » absent de Plugins/")
    elsif min && Gem::Version.new(installed[name]) < Gem::Version.new(min)
      CI.error(path, lineno, "« #{name} » #{installed[name]} installé, #{min} minimum requis")
    end
  end
end

# Interface4G: each frame it picks is a file of Graphics/Windowskins.
settings = File.join(ROOT, "Plugins", "Interface4G", "001_Settings.rb")
if File.exist?(settings)
  load settings
  frames = [Interface4G::MENU_FRAME, Interface4G::SIGN_DEFAULT, *Interface4G::SIGN_FRAMES.values].uniq
  frames.each do |frame|
    next if File.exist?(File.join(ROOT, "Graphics", "Windowskins", "#{frame}.png"))
    CI.error(settings, nil, "cadre « #{frame} » absent de Graphics/Windowskins")
  end
end

puts "#{metas.length} plugins, #{text_files.length} fichiers texte"
CI.finish("Plugins et encodage")
