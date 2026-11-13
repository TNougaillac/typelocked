#===============================================================================
# Sprites of the Family (#103): copies an Essentials trainer sprite for each
# lieutenant (one per type), each Ancien and the Parrain, as its battle sprite
# (Graphics/Trainers/<ID>.png). Their overworld sheets are 4G ones
# (tools/art/npcs_4g.py, #201). A sprite drawn for a role later (a recoloured
# one, or one given by Tom) replaces its copy: take its line out.
# Usage: ruby tools/art/family_sprites.rb
#===============================================================================
require "fileutils"

ROOT = File.expand_path("../..", __dir__)

# Trainer type => Essentials sprite it is copied from: only characters that
# look threatening or shifty (gym leaders and Elite Four included).
SPRITES = {
  LIEUTENANT_NORMAL:   :RIVAL1,
  LIEUTENANT_FIRE:     :LEADER_Blaine,
  LIEUTENANT_WATER:    :ROCKER,
  LIEUTENANT_GRASS:    :POKEMONRANGER_M,
  LIEUTENANT_ELECTRIC: :ENGINEER,
  LIEUTENANT_ICE:      :SUPERNERD,
  LIEUTENANT_FIGHTING: :BLACKBELT,
  LIEUTENANT_POISON:   :SCIENTIST,
  LIEUTENANT_GROUND:   :BIKER,
  LIEUTENANT_FLYING:   :TAMER,
  LIEUTENANT_PSYCHIC:  :LEADER_Sabrina,
  LIEUTENANT_BUG:      :LEADER_Koga,
  LIEUTENANT_ROCK:     :ELITEFOUR_Bruno,
  LIEUTENANT_GHOST:    :CHANNELER,
  LIEUTENANT_DRAGON:   :ELITEFOUR_Lance,
  LIEUTENANT_DARK:     :BURGLAR,
  LIEUTENANT_STEEL:    :CUEBALL,
  LIEUTENANT_FAIRY:    :PSYCHIC_F,
  ANCIEN_1:            :ELITEFOUR_Agatha,
  ANCIEN_2:            :GENTLEMAN,
  ANCIEN_3:            :GAMBLER,
  ANCIEN_4:            :LEADER_Surge,
  PARRAIN:             :ROCKETBOSS
}.freeze

SPRITES.each do |id, source|
  FileUtils.cp(File.join(ROOT, "Graphics/Trainers/#{source}.png"), File.join(ROOT, "Graphics/Trainers/#{id}.png"))
end
puts "#{SPRITES.length} sprites copiés"
