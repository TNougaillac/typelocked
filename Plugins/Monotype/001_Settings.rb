#===============================================================================
# Monotype - Settings
#===============================================================================
module Monotype
  # Types that can't be drawn or chosen (pseudo-types such as ??? are always excluded).
  EXCLUDED_TYPES = [:SHADOW]

  # Starters: 3 drawn at random for each game among the base forms of ROSTER
  # that respect the Monotype rule and evolve into a Pokémon of ROSTER
  # (006_Roster.rb). Lines whose final evolution
  # has more base stats than STARTER_MAX_FINAL_STATS are left out
  # (pseudo-legendaries: 600).
  STARTER_COUNT           = 3
  STARTER_LEVEL           = 5
  STARTER_MAX_FINAL_STATS = 599

  # true: the starter is chosen right after the type, in the start-of-game
  # dialog. false: an event gives it, Monotype.starter_ball(i) on each of the
  # professor's Poké Balls (map 4) or Monotype.starter_dialog.
  STARTER_AT_SETUP = false

  # Gym and League battles: every trainer on a map whose editor name matches
  # GYM_MAP_PATTERN, and gym leaders, Elite Four and Champion anywhere, the
  # Family's lieutenants, Anciens and Parrain too (trainer type ID matching
  # GYM_LEADER_PATTERN). Only Pokémon of the type can fight them.
  GYM_MAP_PATTERN    = /gym|ar[eè]ne|league|ligue/i
  GYM_LEADER_PATTERN = /\A(LEADER_|ELITEFOUR_|CHAMPION|LIEUTENANT_|ANCIEN_|PARRAIN)/

  # On entering a map with wild encounters, a small window at the top right
  # shows how many species of the type can be caught there (007_ZoneCount.rb).
  SHOW_ZONE_COUNT = true
end
