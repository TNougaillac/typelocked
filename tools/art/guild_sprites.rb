#===============================================================================
# Sprites of the guilds' leaders (#182): copies an Essentials battle sprite
# (Graphics/Trainers/<ID>.png) and a 4G overworld sheet already in the game
# (Graphics/Characters/trainer_<ID>.png) for each leader's trainer type, until
# the guilds get their own 4G sprites (#201). A sprite drawn for a leader
# later replaces its copy: take its line out.
# Usage: ruby tools/art/guild_sprites.rb
#===============================================================================
require "fileutils"

ROOT = File.expand_path("../..", __dir__)

# Trainer type => [battle sprite, overworld sheet] it is copied from
SPRITES = {
  CHEF_ELEVEURS:       ["COOLTRAINER_M", "NPC 18"],  # an old farmer in green
  CHEF_NAGEURS:        ["SWIMMER2_M", "NPC 21"],     # a pale man in blue, the sect's guru
  CHEF_DUNDEES:        ["FISHERMAN", "NPC 03"],      # a man in a green cap
  CHEF_PONTES:         ["SWIMMER2_F", "NPC 26"],     # a woman in a green cap
  CHEF_BRACONNIERS:    ["TEAMROCKET_F", "NPC 25"],   # a woman in purple
  CHEF_FORESTIERS:     ["POKEMONRANGER_F", "NPC 04"], # a woman in an orange hat
  CHEF_OUVRIERS:       ["HIKER", "NPC 20"],          # a worker in a yellow helmet
  CHEF_CONTREBANDIERS: ["SAILOR", "NPC 12"],         # a captain in his cap
  CHEF_FORAINS:        ["JUGGLER", "NPC 05"],        # a stout man in purple
  CHEF_MINEURS:        ["RUINMANIAC", "NPC 27"],     # an old man in green
  CHEF_ORDRE:          ["PSYCHIC_M", "NPC 10"],      # a bald old man with a beard
  CHEF_ENDEUILLES:     ["BEAUTY", "NPC 14"],         # an old woman in grey
  CHEF_CHROMES:        ["TEAMROCKET_M", "NPC 07"],   # a dark-haired young man
}.freeze

SPRITES.each do |id, (battle, overworld)|
  FileUtils.cp(File.join(ROOT, "Graphics/Trainers/#{battle}.png"), File.join(ROOT, "Graphics/Trainers/#{id}.png"))
  FileUtils.cp(File.join(ROOT, "Graphics/Characters/#{overworld}.png"), File.join(ROOT, "Graphics/Characters/trainer_#{id}.png"))
end
puts "#{SPRITES.length} sprites copiés"
