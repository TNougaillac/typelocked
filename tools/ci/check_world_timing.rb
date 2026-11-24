#===============================================================================
# WorldTiming (#344): on stub generation steps, each step counts its own time,
# the lines add up to the total, a world drawn beforehand stays out of it, and
# the report reaches the log file.
#===============================================================================
require "tmpdir"
require_relative "lib/ci"

DIR = Dir.mktmpdir
def _INTL(text, *args) = text.gsub(/\{(\d+)\}/) { args[$1.to_i - 1].to_s }
module Console
  def self.lines = (@lines ||= [])
  def self.echoln_li(line) = lines.push(line)
end
def nap(seconds) = sleep(seconds)

module MapGenerator
  module_function
  def parse(_text) = nap(0.02)
  def generate(_plan)   # a timed step inside another
    parse(nil)
    nap(0.03)
  end
  def relink_warps(*) = nil
  def generate_world(*) = nil
  def compile_world_pbs = nil
end
module MapEvents
  module_function
  def parse(*) = nil
  def generate(*) = nil
end
module ProceduralEncounters
  module_function
  def write_world(*) = nap(0.01)
end
module WorldEvents
  module_function
  def write_world(*) = nil
end
module MapProceduralGenerator
  FOLDER = DIR
  EXPORT_FOLDER = "."
  module_function
  def generate_world(*) = nap(0.05)
  def compute_world(*) = generate_world
  %i[write_interior paint_cave write_nook_events write_extra_metadata remove_maps save_atlas].each { |m| define_method(m) { |*| nil } }
  def generate_world_maps(_path, _seed, quiet: false, prune: false, computed: nil) # rubocop:disable Lint/UnusedMethodArgument
    compute_world if !computed
    MapGenerator.generate(nil)
    paint_cave
    ProceduralEncounters.write_world
    nap(0.01)   # untimed: "Autres"
  end
end

load File.join(ROOT, "Plugins", "WorldTiming", "001_WorldTiming.rb")
M = MapProceduralGenerator
T = WorldTiming

def row(name) = Console.lines.find { |l| l.include?(name) }.to_s[/(\d+\.\d+) s/, 1].to_f

M.generate_world_maps("monde.txt", 7)
total = Console.lines.first[/(\d+\.\d+) s/, 1].to_f
CI.error(__FILE__, nil, "pas de rapport en console") if !Console.lines.first.to_s.include?("graine 7")
{ T::PLANS => 0.05, "MapGenerator.parse" => 0.02, "MapGenerator.generate" => 0.03, "ProceduralEncounters" => 0.01, "Autres" => 0.01 }.each do |step, want|
  got = row(step)
  CI.error(__FILE__, nil, "« #{step} » : #{got} s au lieu d'environ #{want} s") if (got - want).abs > 0.015
end
sum = T::STEPS.map(&:last).uniq.sum { |s| row(s) } + row("Autres")
CI.error(__FILE__, nil, "les lignes font #{sum} s pour un total de #{total} s") if (sum - total).abs > 0.02
CI.error(__FILE__, nil, "temps pas remis à zéro") if !T.times.empty?
CI.error(__FILE__, nil, "rapport absent du log") if !File.read(T::LOG_FILE).include?("graine 7")

# A world drawn in a thread during the intro: shown apart, not in the total
Console.lines.clear
Thread.new { M.compute_world }.join
M.generate_world_maps("monde.txt", 8, computed: [])
CI.error(__FILE__, nil, "monde dessiné pendant l'intro absent") if !Console.lines[1].to_s.include?("pendant l'intro")
CI.error(__FILE__, nil, "monde dessiné pendant l'intro compté dans le total") if Console.lines.any? { |l| l.include?(T::PLANS) }

CI.finish("WorldTiming")
