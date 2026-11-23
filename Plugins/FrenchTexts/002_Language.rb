#===============================================================================
# FrenchTexts - Language
#===============================================================================
# French is the only language of the game: Data/messages_french_core.dat holds
# the translations of the data (species, moves, items...) and of the script
# texts. With a single language, Essentials loads it at boot without asking.
# The file is built by tools/translate/ from Text_french_core/.
module Settings
  remove_const(:LANGUAGES)
  LANGUAGES = [
    ["Français", "french"]
  ].freeze
end
