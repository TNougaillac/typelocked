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

# Message texts of the game, outside it
def _INTL(text, *args)
  text.gsub(/\{(\d)\}/) { args[Regexp.last_match(1).to_i - 1].to_s }
end
%w[001_Settings 007_News 010_Pause].each { |f| require File.join(ROOT, "Plugins", "Online", f) }
PAUSE = File.join(ROOT, "Plugins", "Online", "010_Pause.rb")
NEWS = File.join(ROOT, "Plugins", "Online", "007_News.rb")

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

# Announcements of the race: what changed between two statuses of a player
start = { "seals" => 0, "deaths" => 0, "elders" => 0, "godfather" => false, "won" => false, "eliminated" => false }
CI.error(NEWS, nil, "annonce au premier envoi") if !Online.news(nil, start).empty?
CI.error(NEWS, nil, "annonce sans changement") if !Online.news(start, start.dup).empty?
later = start.merge("seals" => 3, "deaths" => 2, "elders" => 4, "godfather" => true, "won" => true, "eliminated" => true)
whats = Online.news(start, later).map { |n| n["what"] }
expected = %w[seal death elder godfather arceus eliminated]
CI.error(NEWS, nil, "annonces #{whats} au lieu de #{expected}") if whats != expected
Online.news(start, later).each do |item|
  text = Online.news_text("Léo", item)
  CI.error(NEWS, nil, "annonce « #{item['what']} » sans texte") if !text&.include?("Léo")
end
CI.error(NEWS, nil, "3e sceau mal écrit") if Online.news_text("Léo", { "what" => "seal", "count" => 3 }) != "Léo a gagné son 3e sceau !"

# Pause of the room
here = { "id" => "a", "name" => "Tom", "connected" => true, "goneFor" => nil }
gone = { "id" => "b", "name" => "Léo", "connected" => false, "goneFor" => 400 }
playing = { "started" => true, "connected" => true, "allConnected" => true, "players" => [here] }
{
  nil => :bridge,
  playing => nil,
  playing.merge("connected" => false) => :self,
  playing.merge("allConnected" => false, "players" => [here, gone]) => :others,
  playing.merge("kicked" => true, "connected" => false) => nil
}.each do |room, wanted|
  reason = Online.pause_reason(room)
  CI.error(PAUSE, nil, "pause : #{reason.inspect} au lieu de #{wanted.inspect} pour #{room.inspect}") if reason != wanted
end
late = gone.merge("id" => "c", "goneFor" => 30)
CI.error(PAUSE, nil, "absent depuis le plus longtemps pas en premier") if Online.missing_players({ "players" => [here, late, gone] }).map { |p| p["id"] } != %w[b c]
CI.error(PAUSE, nil, "durée mal écrite") if Online.duration_text(Online::KICK_AFTER) != "5:00"

# Duels: messages of a duel between Tom (a, challenger) and Léo (b), as Léo's game
require File.join(ROOT, "Plugins", "Online", "011_Duel")
DUEL = File.join(ROOT, "Plugins", "Online", "011_Duel.rb")
module Online
  Me = Struct.new(:you)
  def self.data = Me.new("b")
  def self.sent = (@sent ||= [])
  def self.publish(message) = sent.push(message)
  def self.reset_duels(duel = nil)
    @duel = duel
    @challenge = nil
    sent.clear
  end
end
challenge = Online.duel_message("d1", "b", "challenge", "seed" => 42, "team" => [], "trainer" => {})
Online.reset_duels
Online.duel_event("a", challenge.merge("to" => "c"))
CI.error(DUEL, nil, "défi pour un autre joueur reçu") if Online.challenge
Online.duel_event("a", challenge)
CI.error(DUEL, nil, "défi non reçu") if Online.challenge&.dig("info", "seed") != 42
Online.duel_event("c", Online.duel_message("d2", "b", "challenge"))
refused = Online.sent.last
CI.error(DUEL, nil, "second défi pas refusé (occupé)") if refused&.values_at("what", "to", "busy") != ["refuse", "c", true]
Online.duel_event("a", Online.duel_message("d1", "b", "withdraw"))
CI.error(DUEL, nil, "défi retiré encore proposé") if !Online.challenge["withdrawn"]
duel = Online::Duel.new("d1", "a", 42, false, [])
Online.reset_duels(duel)
duel.started = true
inputs = [Online.duel_message("d1", "b", "input", "step" => "turn", "value" => ["move", 0, 1], "check" => "1:5|6"),
          Online.duel_message("d1", "b", "input", "step" => "switch", "value" => 2, "check" => "1:0|6")]
inputs.each { |input| Online.duel_event("a", input) }
Online.duel_event("c", inputs[0])   # Same duel id, another player
CI.error(DUEL, nil, "choix du combat mal gardés") if duel.inputs.map { |i| i["step"] } != %w[turn switch]
Online.duel_event("a", Online.duel_message("d9", "b", "forfeit"))
CI.error(DUEL, nil, "abandon d'un autre combat pris en compte") if duel.ended
Online.duel_event("a", Online.duel_message("d1", "b", "forfeit"))
Online.duel_event("a", Online.duel_message("d1", "b", "cancel"))
CI.error(DUEL, nil, "abandon : #{duel.ended.inspect}") if duel.ended != :forfeit
Online.reset_duels
Online.duel_event("a", Online.duel_message("d1", "b", "accept"))
CI.error(DUEL, nil, "acceptation d'un défi abandonné sans annulation") if Online.sent.last&.[]("what") != "cancel"
CI.error(DUEL, nil, "choix d'attaque mal envoyé") if Online.encode_choice([:UseMove, 2, nil, 1, 0]) != ["move", 2, 1]
CI.error(DUEL, nil, "changement mal envoyé") if Online.encode_choice([:SwitchOut, 3, nil, -1, 0]) != ["switch", 3, -1]
CI.error(DUEL, nil, "cibles mal retournées") if [0, 1, -1].map { |i| Online.flip(i) } != [1, 0, -1]
CI.error(DUEL, nil, "contrôle des deux combats") if Online.duel_check(3, [10, 0], [25]) != "3:10,0|25"

CI.finish("Mode multijoueur")
