#===============================================================================
# WorldEvents - Sets of the lieutenants and of the League
# Each of their Pokémon gets real moves (its trainer's type first, then its
# other type, a coverage move, a status move) taken among its level-up moves,
# the TMs of the game and its egg moves, a held item, its hidden ability late
# in the game, a nature for its better attack stat and higher IVs. Learnsets
# read from the PBS files. Plain Ruby.
#===============================================================================
module WorldEvents
  Learnset = Struct.new(:types, :stats, :abilities, :hidden, :level_moves, :tutor_moves, :egg_moves)
  MoveData = Struct.new(:id, :type, :category, :power, :accuracy)

  # Draws the sets of the teams of a world.
  class Sets
    # dex: WorldEvents.load_dex; tms: [[item, move, type, power, status?]]
    def initialize(dex, tms, rng)
      @dex = dex
      @tm_moves = tms.map { |_item, move, *| move }
      @rng = rng
    end

    # [{ moves:, ability_index:, item:, nature:, iv: }] for [[species, level]]:
    # type: the trainer's (nil: each Pokémon's own first type); seals: the
    # player's when fought.
    def draw(team, type, seals, iv)
      items = []
      return team.map do |id, level|
        ls = @dex[:species][id]
        next nil if !ls
        physical = ls.stats[1] >= ls.stats[4]
        moves = choose_moves(learnable(ls, level, seals, type), [type, *ls.types].compact.uniq, physical, seals)
        items = SET_ITEMS.select { |from, _list| from <= seals }.max[1].shuffle(random: @rng) if items.empty?
        item = items.shift
        item = TYPE_BOOSTERS[@dex[:moves][moves.first]&.type] if item == :BOOSTER
        hidden = seals >= SET_HIDDEN_SEALS && !ls.hidden.empty?
        { moves: moves, ability_index: hidden ? 2 : @rng.rand(ls.abilities.length), item: item,
          nature: SET_NATURES[physical ? :physical : :special], iv: iv }
      end
    end

    # MoveData it may know at that level with that many seals (those of the
    # trainer's type: the power cap of one seal more).
    def learnable(ls, level, seals, type)
      taught = (ls.tutor_moves & @tm_moves) + ((seals >= SET_EGG_SEALS) ? ls.egg_moves : [])
      taught = taught.select { |m| @dex[:moves][m] && @dex[:moves][m].power <= WorldEvents.set_cap(seals, @dex[:moves][m].type == type) }
      ids = ls.level_moves.filter_map { |l, m| m if l <= level } + taught
      return ids.uniq.filter_map { |m| @dex[:moves][m] }
    end

    # Up to 4 move ids: the best of each STAB type (the trainer's first), a
    # coverage move, a status move, then the best left.
    def choose_moves(moves, stabs, physical, seals)
      score = lambda do |m|
        m.power * (m.accuracy.zero? ? 100 : m.accuracy) * (stabs.include?(m.type) ? 1.5 : 1) *
          (((m.category == :Physical) == physical) ? 1 : 0.6)
      end
      damaging = moves.select { |m| m.category != :Status && m.power > 1 }
      ranked = damaging.map { |m| [m, score.call(m) * (0.85 + (@rng.rand * 0.15))] }
                       .sort_by { |m, s| [-s, m.id.to_s] }.map(&:first)
      picks = []
      take = ->(m) { picks.push(m) if m && picks.length < 4 && !picks.include?(m) }
      new_type = ->(m) { picks.none? { |p| p.type == m.type } }
      stabs.each { |type| take.call(ranked.find { |m| m.type == type }) }
      take.call(ranked.find(&new_type))
      take.call(moves.select { |m| SET_STATUS.include?(m.id) }.sample(random: @rng)) if seals >= SET_STATUS_SEALS
      ranked.select(&new_type).each(&take)
      ranked.each(&take)
      return picks.map(&:id)
    end
  end

  module_function

  # { species: { id => Learnset }, moves: { id => MoveData } } from the PBS
  # files of root; egg moves those of the first form of the family too.
  def load_dex(root = ".")
    sections = ->(file) { ProceduralEncounters.read_text(File.join(root, file)).split(/^\[/).drop(1) }
    moves = sections.call(MOVES_PBS).to_h do |sec|
      id = sec[/\A(\w+)/, 1].to_sym
      [id, MoveData.new(id, sec[/^Type\s*=\s*(\w+)/, 1]&.to_sym, sec[/^Category\s*=\s*(\w+)/, 1]&.to_sym,
                        sec[/^Power\s*=\s*(\d+)/, 1].to_i, sec[/^Accuracy\s*=\s*(\d+)/, 1].to_i)]
    end
    prevos = {}
    species = sections.call(ProceduralEncounters::POKEMON_PBS).to_h do |sec|
      field = ->(key) { sec[/^#{key}\s*=\s*(.*?)\s*$/, 1].to_s.split(",").map(&:strip) }
      ids = ->(key) { field.call(key).map(&:to_sym) }
      id = sec[/\A(\w+)\]/, 1].to_sym
      field.call("Evolutions").each_slice(3) { |to, *| prevos[to.to_sym] ||= id }
      [id, Learnset.new(ids.call("Types"), field.call("BaseStats").map(&:to_i), ids.call("Abilities"),
                        ids.call("HiddenAbilities"), field.call("Moves").each_slice(2).map { |l, m| [l.to_i, m.to_sym] },
                        ids.call("TutorMoves"), ids.call("EggMoves"))]
    end
    species.each do |id, ls|
      base = id
      base = prevos[base] while prevos[base] && species[prevos[base]]
      ls.egg_moves = (ls.egg_moves | species[base].egg_moves) if base != id
    end
    return { species: species, moves: moves }
  end

  # Highest power of a TM or egg move with that many seals (one more for the
  # trainer's type).
  def set_cap(seals, trainer_type = false)
    return SET_MAX_POWER[[seals + (trainer_type ? 1 : 0), SET_MAX_POWER.length - 1].min]
  end

  # The sub-lines of a Pokémon of PBS/trainers.txt for its set.
  def set_lines(set)
    return "" if !set
    values = { "Moves" => set[:moves].join(","), "AbilityIndex" => set[:ability_index], "Item" => set[:item],
               "Nature" => set[:nature], "IV" => set[:iv] && ([set[:iv]] * 6).join(",") }
    return values.filter_map { |key, value| "    #{key} = #{value}\n" if value && value != "" }.join
  end
end
