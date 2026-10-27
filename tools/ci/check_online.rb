#===============================================================================
# Checks the pure parts of the Online plugin: the JSON spoken with the bridge
# and the room rules (imposed Nuzlocke, imposed or shared type).
#===============================================================================
require_relative "lib/ci"

module Online; end
%w[002_Json 003_Rules].each { |f| require File.join(ROOT, "Plugins", "Online", f) }
J = Online::Json
SOURCE = File.join(ROOT, "Plugins", "Online", "002_Json.rb")
RULES = File.join(ROOT, "Plugins", "Online", "003_Rules.rb")

# JSON: what the bridge sends comes back the same
samples = [
  { "room" => { "code" => "ABC234", "seed" => 793_175, "started" => true, "rules" => { "nuzlocke" => "required", "sameType" => false } } },
  { "events" => [{ "n" => 2, "from" => "e1367f9e08fa", "data" => { "kind" => "seal", "name" => "Léo \"le Feu\"\n", "x" => -1.5 } }], "last" => 2 },
  { "room" => nil },
  []
]
samples.each do |sample|
  back = J.parse(J.dump(sample))
  CI.error(SOURCE, nil, "JSON : #{sample.inspect} revient en #{back.inspect}") if back != sample
end
{ '{"a":"é😀"}' => { "a" => "é😀" }, ' { "a" : [ 1 , 2 ] } ' => { "a" => [1, 2] } }.each do |text, expected|
  CI.error(SOURCE, nil, "JSON : #{text} lu #{J.parse(text).inspect}") if J.parse(text) != expected
end
["", "{", '{"a":}', "[1,]", "nope", '{"a":1} x'].each do |text|
  CI.error(SOURCE, nil, "JSON invalide accepté : #{text.inspect}") if !J.parse(text).nil?
end

# Rules of the room
types = %i[NORMAL FIRE WATER GRASS ELECTRIC]
free = { "nuzlocke" => "free", "typeDraw" => "free", "sameType" => false }
CI.error(RULES, nil, "Nuzlocke libre vu comme obligatoire") if Online.nuzlocke_forced?(free)
CI.error(RULES, nil, "Nuzlocke obligatoire non imposé") if !Online.nuzlocke_forced?(free.merge("nuzlocke" => "required"))
CI.error(RULES, nil, "type libre imposé quand même") if Online.forced_type(free, 1, types)
drawn = Online.forced_type(free.merge("typeDraw" => "required"), 1, types)
CI.error(RULES, nil, "tirage obligatoire sans type") if !types.include?(drawn)
same = free.merge("sameType" => true)
(1..50).each do |seed|
  # Two players of the room: same seed, their own random generators
  a = Online.forced_type(same, seed, types, Random.new(1))
  b = Online.forced_type(same, seed, types, Random.new(2))
  CI.error(RULES, nil, "même type pour tous : graine #{seed}, #{a} et #{b}") if a != b || !types.include?(a)
end
seen = (1..50).map { |seed| Online.forced_type(same, seed, types) }.uniq
CI.error(RULES, nil, "même type pour tous : toujours le même type quelle que soit la graine") if seen.length < 2

CI.finish("Mode multijoueur")
