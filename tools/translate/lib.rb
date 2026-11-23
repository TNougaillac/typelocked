# Shared helpers for the French translation tools.
# Text files follow the Essentials "Text_<lang>_core" layout read by
# Translator.compile_text: a [SECTION] header, then pairs of lines
# (English key, then French text).
module FrenchTr
  ROOT = File.expand_path("../..", __dir__)
  TEXT_DIR = File.join(ROOT, "Text_french_core")

  module_function

  # Same escaping as Translator#normalize_value.
  def normalize(value)
    return value unless value[/[\r\n\t\x01]|^[\[\]]/]
    value.gsub("\r", "<<r>>").gsub("\n", "<<n>>").gsub("\t", "<<t>>")
         .gsub("[", "<<[>>").gsub("]", "<<]>>").gsub("\x01", "<<1>>")
  end

  def denormalize(value)
    return value unless value[/<<[rnt1\[\]]>>/]
    value.gsub("<<1>>", "\x01").gsub("<<r>>", "\r").gsub("<<n>>", "\n")
         .gsub("<<[>>", "[").gsub("<<]>>", "]").gsub("<<t>>", "\t")
  end

  # Same as Translation.stringToKey.
  def string_to_key(str)
    return str unless str && str[/[\r\n\t\x01]|^\s+|\s+$|\s{2,}/]
    str.strip.gsub(/\s{2,}/, " ")
  end

  # Lines that pbEachSection would drop or misread cannot be stored.
  def storable?(text)
    !text.nil? && !text.strip.empty? && !text.start_with?("#") && text.strip == text
  end

  def write_section(name, pairs)
    path = File.join(TEXT_DIR, "#{name}.txt")
    File.open(path, "wb") do |f|
      f.write("# French texts (#{name}). Each English line is followed by its translation.\r\n")
      f.write("[#{name}]\r\n")
      pairs.each do |en, fr|
        en_n = normalize(en)
        fr_n = normalize(fr)
        next unless storable?(en_n) && storable?(fr_n)
        f.write("#{en_n}\r\n#{fr_n}\r\n")
      end
    end
    path
  end

  # Minimal PBS reader: yields [section_id, {key => value}].
  def each_pbs_section(file)
    section = nil
    data = {}
    File.foreach(file, encoding: "bom|utf-8") do |line|
      line = line.chomp
      next if line.start_with?("#") || line.strip.empty?
      if line =~ /^\[(.+)\]\s*$/
        yield section, data if section
        section = $1
        data = {}
      elsif line =~ /^\s*(\w+)\s*=\s*(.*?)\s*$/
        data[$1] = $2
      end
    end
    yield section, data if section
  end
end

module FrenchTr
  module_function

  # Reads a text file in the Text_<lang> layout: {section => [[en, fr], ...]}.
  # Raises on an odd line count, which means a translation line is missing.
  def read_pairs(file)
    out = {}
    section = nil
    lines = []
    flush = lambda do
      next unless section
      raise "#{file} [#{section}]: odd number of lines" if lines.length.odd?
      (out[section] ||= []).concat(lines.each_slice(2).map { |en, fr| [denormalize(en), denormalize(fr)] })
    end
    File.foreach(file, encoding: "bom|utf-8") do |line|
      next if line.start_with?("#") || line.strip.empty?
      if line =~ /^\s*\[\s*(.+?)\s*\]\s*$/
        flush.call
        section = $1
        lines = []
      else
        lines << line.strip
      end
    end
    flush.call
    out
  end
end

module FrenchTr
  DAT_FILE = "Data/messages_french_core.dat"

  # MessageTypes constants of Essentials v21.1 (Intl_Messages).
  SECTION_IDS = %w[
    EVENT_TEXTS SPECIES_NAMES SPECIES_CATEGORIES POKEDEX_ENTRIES SPECIES_FORM_NAMES
    MOVE_NAMES MOVE_DESCRIPTIONS ITEM_NAMES ITEM_NAME_PLURALS ITEM_DESCRIPTIONS
    ABILITY_NAMES ABILITY_DESCRIPTIONS TYPE_NAMES TRAINER_TYPE_NAMES TRAINER_NAMES
    FRONTIER_INTRO_SPEECHES FRONTIER_END_SPEECHES_WIN FRONTIER_END_SPEECHES_LOSE
    REGION_NAMES REGION_LOCATION_NAMES REGION_LOCATION_DESCRIPTIONS MAP_NAMES
    PHONE_MESSAGES TRAINER_SPEECHES_LOSE SCRIPT_TEXTS RIBBON_NAMES RIBBON_DESCRIPTIONS
    STORAGE_CREATOR_NAME ITEM_PORTION_NAMES ITEM_PORTION_NAME_PLURALS POKEMON_NICKNAMES
  ].each_with_index.to_h.freeze

  # Placeholders and control codes that a translation must keep: {1}, \c[1],
  # <<n>>, <r>...
  CODES = /\{\d+(?::[^}]*)?\}|<<[rnt1\[\]]>>|\\[a-zA-Z]+(?:\[[^\]]*\])?|<\/?\w+[^>]*>/

  module_function

  def codes(text)
    normalize(text).scan(CODES).sort
  end

  # Array indexed by MessageTypes, each entry a {English key => French} hash:
  # the content of a messages_<lang>_core.dat file. Yields problems if a block
  # is given.
  def compile
    all_text = []
    Dir[File.join(TEXT_DIR, "*.txt")].sort.each do |file|
      read_pairs(file).each do |section, pairs|
        id = SECTION_IDS[section]
        next yield(file, "section inconnue [#{section}]") if !id && block_given?
        raise "#{file}: unknown section [#{section}]" unless id
        hash = (all_text[id] ||= {})
        pairs.each do |en, fr|
          if block_given? && codes(en) != codes(fr)
            yield(file, "codes différents : « #{en} » / « #{fr} »")
          end
          hash[string_to_key(en)] = fr
        end
      end
    end
    all_text
  end
end
