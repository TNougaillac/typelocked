#===============================================================================
# MapProceduralGenerator - Terrain tags of the generated places
# Deep snow (snow ambiance, #204): walked only, never run nor cycled on, like
# tall grass; no wild Pokémon. Its tiles in the Outside 4G tileset get this
# tag from tools/art/outside_4g.py.
#===============================================================================
GameData::TerrainTag.register({
  :id                 => :DeepSnow,
  :id_number          => 18,
  :must_walk          => true,
  :battle_environment => :Snow
})
