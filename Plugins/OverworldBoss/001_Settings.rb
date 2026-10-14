#===============================================================================
# OverworldBoss - Settings
#===============================================================================
module OverworldBoss
  # IVs of every stat, unless the event gives others (ivs: 20).
  DEFAULT_IVS = 31

  # Immunities from the Deluxe Battle Kit: :FLINCH, :OHKO, :SELFKO, :ESCAPE.
  DEFAULT_IMMUNITIES = [:FLINCH, :OHKO, :ESCAPE]

  # A caught boss keeps the ability it had as a boss (true) or gets its
  # natural ability back (false). Stat multipliers and immunities always go.
  KEEP_ABILITY_ON_CAPTURE = true

  # Self switch set on the event when the boss is defeated or caught.
  SELF_SWITCH = "A"
end
