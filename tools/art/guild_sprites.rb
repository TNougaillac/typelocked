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
  CHEF_ELEVEURS: ["COOLTRAINER_M", "NPC 18"]   # an old farmer in green
}.freeze

SPRITES.each do |id, (battle, overworld)|
  FileUtils.cp(File.join(ROOT, "Graphics/Trainers/#{battle}.png"), File.join(ROOT, "Graphics/Trainers/#{id}.png"))
  FileUtils.cp(File.join(ROOT, "Graphics/Characters/#{overworld}.png"), File.join(ROOT, "Graphics/Characters/trainer_#{id}.png"))
end
puts "#{SPRITES.length} sprites copiés"
