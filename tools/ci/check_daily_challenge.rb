#===============================================================================
# Checks the daily challenge's seed and draw (DailyChallenge, 002_Seed.rb):
# a day always gives the same seed in range, the days of a year give different
# worlds, and a seed always draws the same type and starters.
#===============================================================================
require_relative "lib/ci"

%w[001_Settings 002_Seed].each { |f| require File.join(ROOT, "Plugins", "DailyChallenge", f) }
D = DailyChallenge
file = File.join(ROOT, "Plugins", "DailyChallenge", "002_Seed.rb")

CI.error(file, nil, "today : #{D.today(Time.new(2026, 11, 2, 23, 59))} au lieu de 2026-11-02") if D.today(Time.new(2026, 11, 2, 23, 59)) != "2026-11-02"
CI.error(file, nil, "short_date : #{D.short_date('2026-11-02')} au lieu de 02/11") if D.short_date("2026-11-02") != "02/11"
days = (0...366).map { |n| D.today(Time.new(2026, 1, 1, 12) + (n * 86_400)) }.uniq
seeds = days.map { |date| D.seed_for(date) }
CI.error(file, nil, "graine hors de 0...#{D::SEED_RANGE}") if seeds.any? { |s| !(0...D::SEED_RANGE).cover?(s) }
CI.error(file, nil, "graine du 02/11/2026 changée : #{D.seed_for('2026-11-02')}") if D.seed_for("2026-11-02") != D.seed_for("2026-11-02".dup)
CI.error(file, nil, "#{seeds.length - seeds.uniq.length} jours de l'année avec la graine d'un autre jour") if seeds.uniq.length < seeds.length - 1
types = %i[NORMAL FIRE WATER GRASS]
pool = ->(type) { (1..10).map { |n| :"#{type}_#{n}" } }
draws = seeds.first(30).map { |s| D.draw(s, types, pool, 3) }
CI.error(file, nil, "tirage différent pour une même graine") if draws != seeds.first(30).map { |s| D.draw(s, types, pool, 3) }
CI.error(file, nil, "starters hors du type ou en double") if draws.any? { |type, starters| starters.uniq.length != 3 || starters.any? { |s| !s.to_s.start_with?("#{type}_") } }
CI.error(file, nil, "toujours le même type sur 30 jours") if draws.map(&:first).uniq.length < 2

puts "#{days.length} jours, #{seeds.uniq.length} graines différentes"
CI.finish("Défi du jour")
