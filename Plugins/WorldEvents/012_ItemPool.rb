#===============================================================================
# WorldEvents - Pool of the game's items (#331)
# Every item a game draws at random, read from MapProc/Lore/objets.txt: its
# rarity (the weight of its draw), the seals it drops at, its sources. The
# tables of the draws (ground, nooks, nooks to come back to, shops, guild
# gifts) are made from it. Plain Ruby.
#===============================================================================
module WorldEvents
  ITEM_POOL_FILE = "Lore/objets.txt"
  RARITIES = { "commun" => 8, "peu_commun" => 4, "rare" => 2, "tres_rare" => 1 }.freeze
  # sol: on the ground, hidden or given (ITEM_SOURCES); casino: at the prize
  # counter of the Family's casino (FamilyCasino, #330); boutique=N: sold from
  # N seals on
  POOL_SOURCES = %w[sol recoin revisite guilde meteo casino].freeze
  # The draw of a random TM, not an item of items.txt
  POOL_TM = :TM
  # seals: a Range (endless = to the end); shop: seals from which it is sold
  PoolItem = Struct.new(:id, :weight, :seals, :sources, :shop, :line)

  module_function

  def item_pool_path(root = ".")
    return File.join(root, MapProceduralGenerator::FOLDER, ITEM_POOL_FILE)
  end

  # The pool (PoolItem, in the file's order), checked against PBS/items.txt.
  def load_item_pool(root = ".")
    path = item_pool_path(root)
    known = File.read(File.join(root, "PBS", "items.txt"), encoding: "UTF-8").scan(/^\[(\w+)\]/).flatten
    return parse_item_pool(File.read(path, encoding: "UTF-8"), path, known)
  end

  def parse_item_pool(text, file, known)
    pool = []
    text.each_line.with_index(1) do |raw, lineno|
      line = raw.sub(/\A﻿/, "").sub(/#.*/, "").strip
      next if line.empty?
      fail_at = ->(msg) { raise Error, "#{file}, ligne #{lineno} : #{msg}" }
      id, rarity, seals, *sources = line.split
      fail_at.call("attendu « Objet Rareté Sceaux Sources »") if sources.empty?
      fail_at.call("objet #{id} absent de PBS/items.txt") if id != POOL_TM.to_s && !known.include?(id)
      fail_at.call("objet #{id} en double") if pool.any? { |item| item.id == id.to_sym }
      fail_at.call("rareté « #{rarity} » inconnue (#{RARITIES.keys.join(', ')})") if !RARITIES[rarity]
      range = case seals
              when /\A(\d+)\.\.(\d+)\z/ then ($1.to_i..$2.to_i)
              when /\A(\d+)\+\z/        then ($1.to_i..)
              end
      fail_at.call("Sceaux « #{seals} » : attendu « 0..1 » ou « 4+ »") if !range || (range.end && range.end < range.begin)
      shop = nil
      sources = sources.reject do |source|
        next false if source !~ /\Aboutique=(\d+)\z/
        shop = $1.to_i
      end
      sources.each { |source| fail_at.call("source « #{source} » inconnue (#{POOL_SOURCES.join(', ')}, boutique=N)") if !POOL_SOURCES.include?(source) }
      fail_at.call("#{id} : une CT au hasard ne se vend pas") if shop && id == POOL_TM.to_s
      pool.push(PoolItem.new(id.to_sym, RARITIES[rarity], range, sources, shop, lineno))
    end
    raise Error, "#{file} : aucun objet" if pool.empty?
    return pool
  end

  def item_pool
    return @item_pool ||= load_item_pool
  end

  # The draw table of a source: { seals => { item => weight } }, a line at
  # each number of seals where the items change (draw_item takes the last
  # line at most the seals won).
  def pool_table(source)
    items = item_pool.select { |item| item.sources.include?(source) }
    steps = (items.map { |item| item.seals.begin } + items.filter_map { |item| item.seals.end&.+(1) }).uniq.sort
    return steps.to_h do |seals|
      [seals, items.select { |item| item.seals.cover?(seals) }.to_h { |item| [item.id, item.weight] }]
    end
  end

  # Ground (sol, cache, don), nooks, nooks to come back to: their tables.
  def item_table
    return @item_table ||= pool_table("sol")
  end

  def nook_table
    return @nook_table ||= pool_table("recoin")
  end

  def revisit_table
    return @revisit_table ||= pool_table("revisite")
  end

  # The items a guild ally gives once an enemy's leader is beaten (#189).
  def guild_bonus_items
    return item_pool.select { |item| item.sources.include?("guilde") }.map(&:id)
  end

  # Stock of a shop with that many seals, in the pool's order.
  def mart_stock(seals)
    return item_pool.select { |item| item.shop && item.shop <= seals }.sort_by.with_index { |item, i| [item.shop, i] }.map(&:id)
  end
end
