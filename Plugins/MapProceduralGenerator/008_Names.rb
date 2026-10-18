#===============================================================================
# MapProceduralGenerator - Place names
# The names shown in game (map metadata, Town Map) are drawn with the world's
# seed from the names file of the world (key « Toponymie », see
# MapProc/Lore/noms.txt). The maps keep their generated names in the map tree
# (« Ville générée 1 »...), so a world drawn again with another seed reuses the
# same maps.
#===============================================================================
module MapProceduralGenerator
  # forms: form => ["Bourg {nom}", ...]; regions: region names; bases: the
  # base names, one list per language
  NameTable = Struct.new(:forms, :regions, :bases)
  NAME_FORMS = %w[Village Port Ville Grotte]
  NAME_SLOT = "{nom}"

  module_function

  def load_names(path)
    return parse_names(File.read(path, encoding: "UTF-8").sub(/\A﻿/, ""), File.basename(path))
  end

  def parse_names(text, file = "noms")
    table = NameTable.new({}, [], [])
    languages = {}
    section = nil
    text.each_line.with_index(1) do |raw, lineno|
      fail_at = proc { |msg| raise Error, "#{file}, ligne #{lineno} : #{msg}" }
      content = raw.chomp.sub(/#.*\z/, "").strip
      next if content.empty?
      if content =~ /\A\[(.+)\]\z/
        section = $1.strip
        next
      end
      fail_at.call("attendu une section, ex. [Formes]") if !section
      case section.downcase
      when "formes"
        fail_at.call("attendu « Forme = modèle | modèle »") unless content =~ /\A(\w+)\s*=\s*(.+)\z/
        form = NAME_FORMS.find { |f| f.casecmp?($1) }
        fail_at.call("forme « #{$1} » inconnue (#{NAME_FORMS.join(', ')})") if !form
        patterns = $2.split("|").map(&:strip)
        fail_at.call("chaque modèle doit contenir #{NAME_SLOT}") if !patterns.all? { |p| p.include?(NAME_SLOT) }
        table.forms[form] = patterns
      when "region"
        table.regions.concat(content.split(",").map(&:strip).reject(&:empty?))
      else
        (languages[section] ||= []).concat(content.split(",").map(&:strip).reject(&:empty?))
      end
    end
    missing = NAME_FORMS.reject { |f| table.forms[f] }
    raise Error, "#{file} : forme(s) manquante(s) dans [Formes] : #{missing.join(', ')}" if !missing.empty?
    raise Error, "#{file} : [Region] est vide" if table.regions.empty?
    table.bases = languages.values.map(&:uniq).reject(&:empty?)
    raise Error, "#{file} : aucun nom de base (sections comme [Italien])" if table.bases.empty?
    return table
  end

  # Sets the name shown in game of each place (title) and of each route's cave
  # (cave_title). The language of each base name is drawn first, at equal
  # shares, and no base name comes twice (until they have all been used).
  # Returns the region's name.
  def name_world(world, places, names, rng)
    # The islands already took their base names (« Île Lucca »)
    used = places.filter_map { |p| p.island&.sub(/\AÎle /, "") }
    draw_base = lambda do
      lists = names.bases.map { |list| list - used }.reject(&:empty?)
      if lists.empty?
        used.clear
        lists = names.bases
      end
      base = lists.sample(random: rng).sample(random: rng)
      used.push(base)
      next base
    end
    form = ->(kind) { names.forms[kind].sample(random: rng).sub(NAME_SLOT, draw_base.call) }
    first = places.select { |p| p.kind == "ville" }.min_by(&:index)
    route_number = 0
    places.sort_by(&:index).each do |wp|
      if wp.kind == "route"
        route_number += 1
        wp.title = "Route #{route_number}"
        wp.cave_title = form.call("Grotte") if wp.crossing == "grotte" || wp.cave
      elsif world.names.include?(wp.name)
        wp.title = wp.name   # named by the world plan (« Noms »)
      elsif wp == first
        wp.title = form.call("Village")
      elsif wp.port || wp.excess == "cité lacustre"
        wp.title = form.call("Port")
      else
        wp.title = form.call(wp.gym ? "Ville" : "Village")
      end
    end
    return names.regions.sample(random: rng)
  end
end
