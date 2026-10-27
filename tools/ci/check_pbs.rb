#===============================================================================
# Cross-reference check of the PBS files: every move, ability, item, type,
# species, trainer type and map they mention must exist, and no ID may be
# defined twice. Only PBS/*.txt is read (not the "Gen X backup" folders).
#===============================================================================
require_relative "lib/ci"

PBS = File.join(ROOT, "PBS")
ID = /\A[A-Z0-9_]+\z/

Section = Struct.new(:id, :file, :line, :pairs)   # pairs: [key, value, line]

# Essentials also loads extra files named <base>_<anything>.txt.
def pbs_files(base)
  Dir.glob(File.join(PBS, "#{base}*.txt")).sort.select do |path|
    name = File.basename(path, ".txt")
    next true if name == base
    next false unless name.start_with?("#{base}_")
    %w[pokemon_forms pokemon_metrics].none? { |other| other != base && name.start_with?(other) }
  end
end

# Splits a file into [Section] blocks; lines outside "Key = value" form go in
# pairs with a nil key.
def sections(base)
  pbs_files(base).flat_map do |path|
    list = []
    CI.read_text(path).each_line.with_index(1) do |raw, lineno|
      line = raw.sub(/\s*#.*/, "").strip
      next if line.empty?
      if line =~ /\A\[\s*(.+?)\s*\]\z/
        list.push(Section.new($1, path, lineno, []))
      elsif list.empty?
        CI.error(path, lineno, "ligne hors de toute section [...]")
      elsif line =~ /\A(\w+)\s*=\s*(.*)\z/
        list.last.pairs.push([$1, $2, lineno])
      else
        list.last.pairs.push([nil, line, lineno])
      end
    end
    list
  end
end

def ids(base, &key)
  key ||= ->(s) { s.id }
  seen = {}
  sections(base).each do |s|
    id = key.call(s)
    if (first = seen[id])
      CI.error(s.file, s.line, "[#{s.id}] déjà défini ligne #{first.line} de #{File.basename(first.file)}")
    else
      seen[id] = s
    end
  end
  return seen
end

def check(set, kind, value, s, lineno)
  value = value.strip
  return if value.empty? || set.key?(value)
  CI.error(s.file, lineno, "#{kind} « #{value} » inconnu(e) (dans [#{s.id}])")
end

def each_value(s, *keys)
  s.pairs.each do |key, value, lineno|
    next unless keys.include?(key)
    value.split(",").each_with_index { |v, i| yield v.strip, lineno, i }
  end
end

types     = ids("types")
abilities = ids("abilities")
moves     = ids("moves")
items     = ids("items")
species   = ids("pokemon")
ttypes    = ids("trainer_types")
forms     = ids("pokemon_forms") { |s| s.id.gsub(/\s/, "") }
ids("trainers") { |s| s.id.split(",").map(&:strip).then { |a| [a[0], a[1], a[2].to_i] } }
ids("encounters") { |s| s.id.split(",").map(&:to_i).then { |a| [a[0], a[1] || 0] } }

maps = Dir.glob(File.join(ROOT, "Data", "Map[0-9][0-9][0-9].rxdata"))
          .to_h { |p| [File.basename(p)[/\d+/].to_i, true] }
check_map = lambda do |value, s, lineno|
  next if value.to_i == 0 || maps[value.to_i]
  CI.error(s.file, lineno, "carte #{value.to_i} absente de Data/ (Map#{format('%03d', value.to_i)}.rxdata)")
end
# Evolution parameters are an item, move, species or type depending on the method.
evo_params = [items, moves, species, types].reduce({}) { |all, set| all.merge(set) }

# pokemon.txt / pokemon_forms.txt
(species.values + forms.values).each do |s|
  if forms.value?(s)
    base = s.id.split(",")[0].strip
    CI.error(s.file, s.line, "espèce « #{base} » inconnue") unless species[base]
  end
  each_value(s, "Types") { |v, l| check(types, "type", v, s, l) }
  each_value(s, "Abilities", "HiddenAbilities") { |v, l| check(abilities, "talent", v, s, l) }
  each_value(s, "TutorMoves", "EggMoves", "MegaMove") { |v, l| check(moves, "attaque", v, s, l) }
  each_value(s, "Moves") { |v, l, i| check(moves, "attaque", v, s, l) if i.odd? }
  each_value(s, "Offspring") { |v, l| check(species, "espèce", v, s, l) }
  each_value(s, "WildItemCommon", "WildItemUncommon", "WildItemRare", "MegaStone", "Incense") do |v, l|
    check(items, "objet", v, s, l)
  end
  each_value(s, "Evolutions") do |v, l, i|
    case i % 3
    when 0 then check(species, "espèce", v, s, l)
    when 2 then check(evo_params, "paramètre d'évolution", v, s, l) if v =~ ID && v !~ /\A\d+\z/
    end
  end
end

moves.each_value { |s| each_value(s, "Type") { |v, l| check(types, "type", v, s, l) } }
items.each_value { |s| each_value(s, "Move") { |v, l| check(moves, "attaque", v, s, l) } }
types.each_value do |s|
  each_value(s, "Weaknesses", "Resistances", "Immunities") { |v, l| check(types, "type", v, s, l) }
end

sections("trainers").each do |s|
  check(ttypes, "type de dresseur", s.id.split(",")[0], s, s.line)
  each_value(s, "Items", "Item", "Ball") { |v, l| check(items, "objet", v, s, l) }
  each_value(s, "Pokemon") { |v, l, i| check(species, "espèce", v, s, l) if i == 0 }
  each_value(s, "Moves") { |v, l| check(moves, "attaque", v, s, l) }
  each_value(s, "Ability") { |v, l| check(abilities, "talent", v, s, l) }
end

sections("encounters").each do |s|
  check_map.call(s.id.split(",")[0], s, s.line)
  s.pairs.each do |key, value, lineno|
    next if key || value !~ /\A\d+\s*,\s*([^,\s]+)/
    check(species, "espèce", $1.sub(/_\d+\z/, ""), s, lineno)
  end
end

sections("metadata").each do |s|
  each_value(s, "Home") { |v, l, i| check_map.call(v, s, l) if i == 0 }
  each_value(s, "TrainerType") { |v, l| check(ttypes, "type de dresseur", v, s, l) }
  each_value(s, "StartItemStorage") { |v, l| check(items, "objet", v, s, l) }
end

sections("map_metadata").each do |s|
  check_map.call(s.id, s, s.line)
  each_value(s, "HealingSpot") { |v, l, i| check_map.call(v, s, l) if i == 0 }
  each_value(s, "DiveMap") { |v, l| check_map.call(v, s, l) }
end

# map_connections.txt has no [sections]: read its lines directly.
pbs_files("map_connections").each do |path|
  fake = Section.new("connexion", path, 0, [])
  CI.read_text(path).each_line.with_index(1) do |raw, lineno|
    line = raw.sub(/\s*#.*/, "").strip
    next if line.empty?
    fields = line.split(",")
    [fields[0], fields[3]].each { |v| check_map.call(v.to_s, fake, lineno) }
  end
end

sections("town_map").each do |s|
  each_value(s, "Point") { |v, l, i| check_map.call(v, s, l) if i == 4 }
end

sections("regional_dexes").each do |s|
  s.pairs.each do |key, value, lineno|
    value.split(",").each { |v| check(species, "espèce", v, s, lineno) } unless key
  end
end

# Monotype: ROSTER (Plugins/Monotype/006_Roster.rb) is docs/roster/pokedex.csv,
# and each type that can be drawn has enough starters (base forms of the roster
# that have the type or evolve into it, and evolve into a Pokémon of the
# roster, pseudo-legendaries excluded, as Monotype.starter_pool).
%w[001_Settings 006_Roster].each { |f| require File.join(ROOT, "Plugins", "Monotype", "#{f}.rb") }
roster_file = File.join(ROOT, "Plugins", "Monotype", "006_Roster.rb")
csv_ids = CI.read_text(File.join(ROOT, "docs", "roster", "pokedex.csv")).lines.drop(1).map { |l| l.split(",")[0] }
roster = Monotype::ROSTER.map(&:to_s)
CI.error(roster_file, nil, "ROSTER différent de docs/roster/pokedex.csv") if roster != csv_ids
roster.each { |id| CI.error(roster_file, nil, "ROSTER : espèce « #{id} » inconnue") unless species[id] }
value_of = ->(s, key) { s.pairs.find { |k, _, _| k == key }&.at(1).to_s }
evolutions = species.transform_values do |s|
  value_of.call(s, "Evolutions").split(",").each_slice(3).map { |a| a[0].strip }
end
prevo = evolutions.flat_map { |id, evos| evos.map { |evo| [evo, id] } }.to_h
types_of = ->(id) { species[id] ? value_of.call(species[id], "Types").split(",").map(&:strip) : [] }
eligible = ->(id, type) { types_of.call(id).include?(type) || evolutions.fetch(id, []).any? { |e| eligible.call(e, type) } }
final_stats = lambda do |id|
  evos = evolutions.fetch(id, [])
  next value_of.call(species[id], "BaseStats").split(",").sum(&:to_i) if evos.empty?
  evos.map { |e| final_stats.call(e) }.max
end
types.each_value do |t|
  next if value_of.call(t, "IsPseudoType") == "true" || Monotype::EXCLUDED_TYPES.include?(t.id.to_sym)
  pool = roster.select do |id|
    !roster.include?(prevo[id]) && eligible.call(id, t.id) && evolutions.fetch(id, []).any? { |e| roster.include?(e) } &&
      final_stats.call(id) <= Monotype::STARTER_MAX_FINAL_STATS
  end
  next if pool.length >= Monotype::STARTER_COUNT
  CI.error(roster_file, nil, "#{pool.length} starter(s) possible(s) pour #{t.id}, il en faut #{Monotype::STARTER_COUNT}")
end

CI.finish("Références des PBS")
