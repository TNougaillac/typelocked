# Builds every French text file in Text_french_core/: data texts (species,
# moves, items, abilities, forms) from the PBS files and the PokeAPI CSV tables,
# then the hand-written texts of tools/translate/manual/.
#
#   ruby tools/translate/build_texts.rb <pokeapi_csv_dir>
#
# The CSV files come from github.com/PokeAPI/pokeapi (data/v2/csv). Matching is
# done on the English names, so it also works for renamed internal IDs.
require "csv"
require_relative "lib"

CSV_DIR = ARGV[0] or abort("usage: build_texts.rb <pokeapi_csv_dir>")
FR = "5"
EN = "9"
PBS = File.join(FrenchTr::ROOT, "PBS")

def table(name)
  CSV.read(File.join(CSV_DIR, "#{name}.csv"), headers: true, encoding: "utf-8")
end

def norm(name)
  name.to_s.downcase.tr("♀♂é’'", "fmé  ").gsub(/[^a-z0-9fm]/, "")
end

# The game fonts lack typographic quotes and narrow spaces.
def plain(text)
  text.tr("’‘  ", "''  ").gsub("…", "...")
end

def clean_flavor(text)
  plain(text.delete("\u00ad").gsub("\\n", " ").tr("\f\n\r", "   ")).gsub(/\s+/, " ").strip
end

# {id => {lang => value}} for a names table.
def names_by_id(rows, id_col, value_col = "name")
  out = Hash.new { |h, k| h[k] = {} }
  rows.each { |r| out[r[id_col]][r["local_language_id"]] = r[value_col] }
  out
end

# English-name index: norm(en name) => id.
def en_index(names)
  names.each_with_object({}) { |(id, l), h| h[norm(l[EN])] ||= id if l[EN] }
end

# French flavor texts per id: {id => [[rank, text], ...]}, newest first.
# order_of maps a version/group id to its rank.
def flavors(rows, id_col, ver_col, order_of)
  out = Hash.new { |h, k| h[k] = [] }
  rows.each do |r|
    next unless r["language_id"] == FR
    out[r[id_col]] << [order_of[r[ver_col]] || 0, clean_flavor(r["flavor_text"])]
  end
  out.each_value { |list| list.sort_by! { |rank, _| -rank }.uniq! { |_, t| t } }
  out
end

# The newest text that fits about as much room as the English one (the game's
# windows are sized for it), else the shortest one.
def pick_flavor(candidates, en)
  return nil if candidates.nil? || candidates.empty?
  limit = (en.length * 1.25).ceil + 8
  fit = candidates.find { |_, text| text.length <= limit }
  (fit || candidates.min_by { |_, text| text.length })[1]
end

group_order = table("version_groups").to_h { |r| [r["id"], r["order"].to_i] }
version_order = table("versions").to_h { |r| [r["id"], group_order[r["version_group_id"]] || 0] }

misses = Hash.new { |h, k| h[k] = [] }
sections = Hash.new { |h, k| h[k] = {} }
add = lambda do |section, en, fr, what = nil|
  next if en.nil? || en.empty?
  if fr.nil? || fr.empty?
    misses[section] << [en, what || en]
  else
    sections[section][en] = plain(fr)
  end
end

#-------------------------------------------------------------------------------
# Species: name, category, Pokédex entry; forms: form name
#-------------------------------------------------------------------------------
sp_names = Hash.new { |h, k| h[k] = {} }
table("pokemon_species_names").each do |r|
  sp_names[r["pokemon_species_id"]][r["local_language_id"]] = [r["name"], r["genus"]]
end
sp_index = sp_names.each_with_object({}) { |(id, l), h| h[norm(l[EN][0])] ||= id if l[EN] }
sp_dex = flavors(table("pokemon_species_flavor_text"), "species_id", "version_id", version_order)

form_names = Hash.new { |h, k| h[k] = {} }
table("pokemon_form_names").each { |r| form_names[r["pokemon_form_id"]][r["local_language_id"]] = r }
form_index = {}
form_names.each_value do |l|
  next unless l[EN] && l[FR]
  form_index[l[EN]["form_name"]] ||= l[FR]["form_name"] if l[EN]["form_name"] && l[FR]["form_name"]
  form_index[l[EN]["pokemon_name"]] ||= l[FR]["pokemon_name"] if l[EN]["pokemon_name"] && l[FR]["pokemon_name"]
end

%w[pokemon.txt pokemon_forms.txt].each do |file|
  FrenchTr.each_pbs_section(File.join(PBS, file)) do |id, d|
    species = id.split(",")[0]
    if d["Name"]
      sid = sp_index[norm(d["Name"])]
      fr = sid && sp_names[sid][FR]
      add.call("SPECIES_NAMES", d["Name"], fr && fr[0], "#{species} #{d["Name"]}")
      genus = fr && fr[1]&.sub(/^Pokémon\s+/, "")
      add.call("SPECIES_CATEGORIES", d["Category"], genus, "#{species} #{d["Category"]}") if d["Category"]
      # Alternate forms have their own entry, which PokeAPI does not split out
      add.call("POKEDEX_ENTRIES", d["Pokedex"], sid && pick_flavor(sp_dex[sid], d["Pokedex"]), "#{species} dex") if d["Pokedex"] && file == "pokemon.txt"
    end
    add.call("SPECIES_FORM_NAMES", d["FormName"], form_index[d["FormName"]], "#{id} #{d["FormName"]}") if d["FormName"]
  end
end

#-------------------------------------------------------------------------------
# Moves, abilities: name and description
#-------------------------------------------------------------------------------
[["moves", "move", "MOVE"], ["abilities", "ability", "ABILITY"]].each do |pbs, api, sec|
  names = names_by_id(table("#{api}_names"), "#{api}_id")
  index = en_index(names)
  flavor = flavors(table("#{api}_flavor_text"), "#{api}_id", "version_group_id", group_order)
  FrenchTr.each_pbs_section(File.join(PBS, "#{pbs}.txt")) do |id, d|
    aid = index[norm(d["Name"])] || index[norm(id)]
    add.call("#{sec}_NAMES", d["Name"], aid && names[aid][FR], id)
    add.call("#{sec}_DESCRIPTIONS", d["Description"], aid && d["Description"] && pick_flavor(flavor[aid], d["Description"]), "#{id} desc")
  end
end

#-------------------------------------------------------------------------------
# Items: name, plural, description (TMs/TRs/HMs use the French CT/DT/CS codes)
#-------------------------------------------------------------------------------
item_names = names_by_id(table("item_names"), "item_id")
item_index = en_index(item_names)
table("items").each { |r| item_index[norm(r["identifier"])] ||= r["id"] }
item_flavor = flavors(table("item_flavor_text"), "item_id", "version_group_id", group_order)
TM_CODES = { "TM" => "CT", "TR" => "DT", "HM" => "CS" }

def fr_plural(name)
  return name if name.include?(" ") || name =~ /[sxz]$/i || name !~ /[a-zé]$/i
  name + "s"
end

FrenchTr.each_pbs_section(File.join(PBS, "items.txt")) do |id, d|
  if d["Name"] =~ /^(TM|TR|HM)(\d+)$/
    code = TM_CODES[$1] + $2
    add.call("ITEM_NAMES", d["Name"], code)
    add.call("ITEM_NAME_PLURALS", d["NamePlural"], code) if d["NamePlural"]
    next # TM descriptions come from the move description
  end
  iid = item_index[norm(d["Name"])] || item_index[norm(id)]
  fr = iid && item_names[iid][FR]
  add.call("ITEM_NAMES", d["Name"], fr, id)
  add.call("ITEM_NAME_PLURALS", d["NamePlural"], fr && fr_plural(fr), id) if d["NamePlural"]
  add.call("ITEM_DESCRIPTIONS", d["Description"], iid && pick_flavor(item_flavor[iid], d["Description"]), "#{id} desc") if d["Description"]
  # French texts name the item itself rather than "a jar of ..."
  add.call("ITEM_PORTION_NAMES", d["PortionName"], fr, id) if d["PortionName"]
  add.call("ITEM_PORTION_NAME_PLURALS", d["PortionNamePlural"], fr && fr_plural(fr), id) if d["PortionNamePlural"]
end

#-------------------------------------------------------------------------------
# Hand-written texts (tools/translate/manual/<SECTION>.txt) override PokeAPI
#-------------------------------------------------------------------------------
Dir[File.join(__dir__, "manual", "*.txt")].sort.each do |file|
  FrenchTr.read_pairs(file).each do |section, pairs|
    pairs.each do |en, fr|
      sections[section][en] = fr
      misses[section].reject! { |m| m[0] == en }
    end
  end
end

#-------------------------------------------------------------------------------
Dir.mkdir(FrenchTr::TEXT_DIR) unless Dir.exist?(FrenchTr::TEXT_DIR)
sections.each do |name, pairs|
  FrenchTr.write_section(name, pairs.sort_by { |en, _| en })
  puts format("%-22s %4d translated, %3d missing", name, pairs.size, misses[name].uniq.size)
end
File.open(File.join(FrenchTr::TEXT_DIR, "_missing_data.log"), "w") do |f|
  misses.each { |sec, list| f.puts("[#{sec}]", list.map(&:last).uniq) }
end
