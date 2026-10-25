#===============================================================================
# Sprites of the Family (#103): copies an Essentials trainer sprite for each
# lieutenant (one per type), each Ancien and the Parrain, battle sprite
# (Graphics/Trainers/<ID>.png) and overworld sheet
# (Graphics/Characters/trainer_<ID>.png). A sprite drawn for a role later (a
# recoloured one, or one given by Tom) replaces its copy: take its line out.
# Usage: ruby tools/art/family_sprites.rb
#===============================================================================
require "fileutils"

ROOT = File.expand_path("../..", __dir__)

# Trainer type => Essentials sprite it is copied from.
SPRITES = {
  LIEUTENANT_NORMAL:   :COOLTRAINER_M,
  LIEUTENANT_FIRE:     :LEADER_Blaine,
  LIEUTENANT_WATER:    :LEADER_Misty,
  LIEUTENANT_GRASS:    :LEADER_Erika,
  LIEUTENANT_ELECTRIC: :LEADER_Surge,
  LIEUTENANT_ICE:      :ELITEFOUR_Lorelei,
  LIEUTENANT_FIGHTING: :BLACKBELT,
  LIEUTENANT_POISON:   :LEADER_Koga,
  LIEUTENANT_GROUND:   :RUINMANIAC,
  LIEUTENANT_FLYING:   :BIRDKEEPER,
  LIEUTENANT_PSYCHIC:  :LEADER_Sabrina,
  LIEUTENANT_BUG:      :BUGCATCHER,
  LIEUTENANT_ROCK:     :LEADER_Brock,
  LIEUTENANT_GHOST:    :CHANNELER,
  LIEUTENANT_DRAGON:   :ELITEFOUR_Lance,
  LIEUTENANT_DARK:     :BURGLAR,
  LIEUTENANT_STEEL:    :ENGINEER,
  LIEUTENANT_FAIRY:    :BEAUTY,
  ANCIEN_1:            :ELITEFOUR_Agatha,
  ANCIEN_2:            :GENTLEMAN,
  ANCIEN_3:            :GAMBLER,
  ANCIEN_4:            :ELITEFOUR_Bruno,
  PARRAIN:             :ROCKETBOSS
}.freeze

SPRITES.each do |id, source|
  FileUtils.cp(File.join(ROOT, "Graphics/Trainers/#{source}.png"), File.join(ROOT, "Graphics/Trainers/#{id}.png"))
  FileUtils.cp(File.join(ROOT, "Graphics/Characters/trainer_#{source}.png"),
               File.join(ROOT, "Graphics/Characters/trainer_#{id}.png"))
end
puts "#{SPRITES.length} sprites copiés"
