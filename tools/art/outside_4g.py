"""Outside 4G tileset (TypeLocked, issue #177).

Since #262, Graphics/Tilesets/Outside.png and tileset 1 are no longer in the
game: this script records how Outside 4G was built from them and cannot be
run again from scratch. New 4G tiles are added to Outside 4G itself.

Builds Graphics/Tilesets/Outside 4G.png from Graphics/Tilesets/Outside.png
and SirMalo's HGSS sheets. The 4G tiles are used as they are drawn: whole
16 px tiles, scaled x2 (nearest neighbour), never cut or redrawn.
- Grounds and plants of MapProc's palette take the place of their old tile
  (same T<n>, same passages).
- The forest tree (route borders) is SirMalo's pair of trees, copied whole
  twice per ground (blocked, and with a halo's passages): MapGen draws each
  cell of a forest from it by its place, so that trees 2 tiles apart overlap
  as the sheet draws them.
- Other trees are bigger than the blocks MapProc gives them: each one is copied
  whole below the old tileset, with the tiles around its block (tips, sides)
  that MapGen draws on layer 3 ("halo", see Plugins/MapGenerator/002_Parser.rb).
  The script prints the new [Objects] lines.
On the other grounds of the ambiances (meadow, sand, dirt, gravel), the 4G
grass under the trees becomes see-through and its shadows the darkened
ground: the only change made to a tile.

Sources (see docs/CREDITS.md), not in the repository:
- SirMalo, "Tiles - HGSS for RMXP": NatureRMXP.png. The sheets are at the DS
  size (16 px tiles), in columns of 8 tiles (128 px) every 144 px from
  x = 16: one column is exactly as wide as a tileset once scaled. Pink is
  see-through, yellow and white are unused.

Run from the repository root, after tools/art/tileset_clone.rb (it resets
tileset 24; again after any change of Outside.png or tileset 1), with the
folder of the SirMalo sheets (Pillow needed):
    ruby tools/art/tileset_clone.rb 1 24 "Outside 4G" "Outside 4G"
    python3 tools/art/outside_4g.py "<SirMalo folder>"
The tiles added below the old tileset get their passages and priorities in
tileset 24 (via tools/art/tileset_tables.rb).
"""
import json
import subprocess
import sys
from PIL import Image

SOURCE = "Graphics/Tilesets/Outside.png"
TARGET = "Graphics/Tilesets/Outside 4G.png"
TILESET_ID = 24
SHEETS = {"N": "NatureRMXP.png", "B": "BuildingsRMXP.png", "U": "UrbanRMXP.png"}
PINK = (240, 91, 161, 255)
MAGENTA = (255, 0, 255, 255)   # see-through of the Buildings sheet
UNUSED = {(255, 245, 104, 255), (255, 255, 255, 255)}
# 4G grass and the shadows drawn on it (redrawn on the other grounds)
GRASS = {(112, 216, 168, 255), (112, 208, 168, 255)}
SHADOWS = {(96, 200, 152, 255): 0.9, (80, 176, 144, 255): 0.8, (56, 136, 112, 255): 0.6}
TILE = 32
TALL = 420   # passages of a halo tile: walkable, drawn over the player
SOLID = 428  # passages of a tree tile: blocked

# Tiles in place: Outside tile => (sheet, column, tile x, tile y) in 16 px
# tiles. Opaque tiles are laid over the 4G grass (the holes of the path's
# inner corners show it); SEE_THROUGH ones are not.
TILES = {
    # Grass (verdoyante ground): plain, blades (3: mirrored, see MIRRORED)
    1: ("N", 0, 0, 0), 2: ("N", 0, 1, 0), 3: ("N", 0, 1, 0),
    # Dirt path on the grass (Rue of the green ambiances; 106 is also the
    # dirt ground): outer edges from the full patch, inner corners from the
    # patch with a hole
    97: ("N", 0, 0, 6), 98: ("N", 0, 1, 6), 99: ("N", 0, 3, 6),
    105: ("N", 0, 0, 7), 106: ("N", 0, 1, 7), 107: ("N", 0, 3, 7),
    113: ("N", 0, 0, 9), 114: ("N", 0, 1, 9), 115: ("N", 0, 3, 9),
    100: ("N", 0, 5, 7), 102: ("N", 0, 6, 7), 116: ("N", 0, 5, 8), 118: ("N", 0, 6, 8),
    # Paved street on the grass (Rue of the verdoyante and autumn ambiances,
    # the square under the fountain): the grey slabs of Urban, same layout
    265: ("U", 0, 0, 11), 266: ("U", 0, 1, 11), 267: ("U", 0, 3, 11),
    273: ("U", 0, 0, 12), 274: ("U", 0, 1, 12), 275: ("U", 0, 3, 12),
    281: ("U", 0, 0, 14), 282: ("U", 0, 1, 14), 283: ("U", 0, 3, 14),
    268: ("U", 0, 5, 12), 270: ("U", 0, 6, 12), 284: ("U", 0, 5, 13), 286: ("U", 0, 6, 13),
    # Rocks and pebbles of the desert and mineral grounds (legend c d j x ,),
    # off their grass, over the ground
    847: ("N", 3, 0, 27), 839: ("N", 3, 2, 34), 927: ("N", 3, 1, 27),
    919: ("N", 3, 5, 34), 895: ("N", 3, 4, 27),
    # Sand ground (sand ambiance, desert): the pale sand
    162: ("N", 0, 1, 17),
    # Tall grass (the middle of a patch: it joins its neighbours); very tall
    # grass: its foot, and its top drawn over it
    6: ("N", 3, 0, 8), 15: ("N", 3, 0, 9), 7: ("N", 3, 0, 7),
    # Bush (legend symbol à, over the ground) and its copies for the grounds
    475: ("N", 3, 3, 27), 4045: ("N", 3, 3, 27), 4085: ("N", 3, 3, 27),
    4125: ("N", 3, 3, 27), 4165: ("N", 3, 3, 27),
}
SEE_THROUGH = {7, 475, 4045, 4085, 4125, 4165, 847, 839, 927, 919, 895}
UNGROUNDED = {847, 839, 927, 919, 895}
MIRRORED = {3}
# Crowns of the old round trees (legend ò, ù above è, ü): the 4G trees draw
# their own top, these become see-through
CLEARED = [484, 532]


def pair_tree(row):
    """A forest tree of SirMalo's pairs of trees (column 2, from `row`): the
    sheet draws 2 trees side by side, 2 rows of them, each hiding a little of
    the one behind. A whole tree is the left half of the left trees and the
    right half of the right trees (the drawings are the same): tips, upper
    canopy of the back row, lower canopy and trunk of the front row; the
    sides it spills over are the front row's."""
    def c(tx, ty):
        return ("N", 2, tx, row + ty)
    return [[None, c(1, 0), c(4, 0), None],
            [c(0, 3), c(1, 1), c(4, 1), c(5, 3)],
            [c(0, 4), c(1, 4), c(4, 4), c(5, 4)],
            [None, c(1, 5), c(4, 5), None]]


def grid_block(col, tx, ty, width, height):
    return [[("N", col, tx + dx, ty + dy) for dx in range(width)] for dy in range(height)]


# Forest tree (t, route borders): SirMalo's 6x6 pair of trees, whole, twice
# per ground: blocked (the trees) and with a halo's passages (the canopy
# drawn around the forest); MapGen picks each cell by its place in the forest
# (Plugins/MapGenerator/003_Builder.rb).
FOREST = ("t", 2, 0)   # symbol, sheet column, first row
FOREST_SIZE = 6
# Trees: symbol => (old first tile, block width, block height, drawing, block
# x, block y in the drawing). The block keeps the passages of the old tiles;
# the rest of the drawing is the halo.
TREES = {
    "é": (440, 3, 3, pair_tree(24), 1, 1),    # tall pine (dark)
    "è": (491, 3, 3, grid_block(3, 0, 36, 4, 4), 0, 1),   # round tree
    "ü": (539, 3, 3, grid_block(3, 0, 40, 4, 4), 0, 1),   # yellow tree (autumn)
    "ê": (470, 1, 3, grid_block(3, 0, 15, 1, 3), 0, 0),   # cypress
    "ë": (502, 1, 2, grid_block(3, 1, 16, 1, 2), 0, 0),   # shrub
}
# Grounds of the ambiances (tools/art/ground_variants.py) and the trees
# drawn on each; None: the 4G grass, as drawn
VARIED = ["é", "è", "ê", "ë"]
GROUNDS = {None: list(TREES), 50: VARIED, 162: VARIED, 106: VARIED, 218: VARIED}
# Tall grass on those grounds: ground => (tall grass, very tall grass foot),
# in place (the grass at the foot becomes the ground)
# The gaps of a patch of tall grass on a ground other than the grass
PATCH_GREEN = (64, 120, 40, 255)
GRASS_VARIANTS = {50: (143, 151), 162: (124, 175), 106: (125, 181), 218: (133, 189)}
GROUND_NAMES = {None: "palette", 50: "prairie", 162: "sable", 106: "terre battue", 218: "minérale"}

# Cliffs (MapProc's relief): SirMalo's plateaux, whole, 5 rows of 8 tiles
# each: row 0 the rim drawn above the north edge, rows 1-3 the plateau (its
# sides, inside and south face), row 4 its inner corners (columns 0-3) and
# the rims where it rises beside them (columns 5-6). A grass top per ground
# (grey rock on the mineral one), then the rock tops of the massifs.
# (ground, sheet column, first row)
CLIFFS = [(None, 5, 20), (50, 5, 20), (162, 5, 20), (106, 5, 20), (218, 6, 20), (None, 5, 0), (218, 6, 0)]
CLIFF_ROWS = 5
# The shades of grass along the rims (any green, its rock is brown or grey)
# become the ground darkened as much as they are darker than the grass
CLIFF_GREEN = 15     # green over red that makes a shade of grass
GRASS_GREEN = 216    # green of the grass
# Cave entrances: 3x3 mouths cut in a cliff face, brown then grey, each in a
# row of 3 tiles of 8 (the legend's 1..9, row by row)
CAVES = [(9, 9), (9, 33)]   # sheet column, first row
CAVE_PASSAGES = [787, 790, 789, 795, 798, 797, 803, 806, 805]
# Ledge (MapProc's corniche, jumped down to the south): left end, middle,
# right end; the old ones give their passages
LEDGE = [(("N", 4, 1, 1), 810), (("N", 4, 2, 1), 828), (("N", 4, 3, 1), 814)]
LEDGE_TILES = [810, 828, 814]

# Snow ambiance (#204), after everything else so that the tiles before keep
# their numbers. Ground: the snow of SirMalo's snowy plateaux (4 variants);
# deep snow and ice: that snow tinted (no 4G drawing of them), with their
# terrain tags (DeepSnow from Plugins/MapProceduralGenerator, Ice of
# Essentials). Trees: the snowy pair of trees (forest, tall pine, round tree),
# the cypress and shrub on the snow; cliffs: the snowy plateaux, brown for
# the levels, grey for the rock massifs; the snowy cave mouth.
SNOW_GROUND = [(7, 1, 22), (7, 2, 22), (7, 1, 21), (7, 2, 21)]   # sheet column, tile x, y
DEEP_SNOW_TAG = 18
ICE_TAG = 12
SNOW_FOREST_ROW = 48
# Cells of the snowy forest's 6x6 frame that hold the sheet's colour samples
# (dirt, snow), not the trees: left empty
SNOW_FOREST_SAMPLES = {(5, 0), (5, 5)}
SNOW_TREES = {   # symbol => drawing, block x, y (the block of TREES[symbol])
    "é": (pair_tree(SNOW_FOREST_ROW), 1, 1),
    "è": (pair_tree(SNOW_FOREST_ROW), 1, 1),
    "ê": (grid_block(3, 0, 15, 1, 3), 0, 0),
    "ë": (grid_block(3, 1, 16, 1, 2), 0, 0),
}
SNOW_CLIFFS = [(7, 20), (8, 20)]   # sheet column, first row: levels, massifs
SNOW_CAVE = (9, 40)
# The straight rims of the snowy plateaux (drawn above their north edge,
# between the rounded corners) are a line of rock that floats on the snow
# ground, away from the plateau (its snowy top is as white as the ground):
# they keep their passages but are not drawn. (column, row) in the block
SNOW_HIDDEN_RIMS = {(1, 0), (2, 0), (5, 0), (6, 0), (5, 4), (6, 4)}


def tint(tile, colours):
    """The snow tile recoloured: each colour by its brightness (white,
    then the pale blue of its wind lines) to the matching one of `colours`."""
    tile = tile.copy()
    tile.putdata([colours[0] if c[3] and min(c[:3]) >= 244 else colours[1] if c[3] else c
                  for c in tile.get_flattened_data()])
    return tile
# Buildings (BuildingsRMXP.png): symbol => (sheet column, x, y, width,
# height of the drawing in tiles, block x, y, width, height in the drawing,
# door x, y in the block). The block is the building (blocked, its door
# walked into); the rest of the drawing (eaves, chimney, the shadow) is its
# halo (Plugins/MapGenerator/002_Parser.rb): drawn over the player where it
# holds some of the building, under him where it is only shadow.
BUILDINGS = {
    "C": (0, 1, 1, 6, 6, 0, 0, 5, 5, 2, 4),     # Pokémon Centre
    "M": (0, 0, 17, 5, 5, 0, 0, 4, 4, 2, 3),    # Mart (blue)
    "N": (0, 0, 24, 5, 5, 0, 0, 4, 4, 2, 3),    # Mart (purple)
    "V": (15, 0, 20, 6, 6, 1, 1, 5, 4, 2, 3),   # orange house
    "U": (5, 0, 1, 6, 5, 1, 0, 4, 4, 1, 3),     # teal house
    "E": (13, 0, 20, 6, 6, 1, 1, 4, 4, 1, 3),   # dark green house
    "K": (15, 0, 28, 5, 6, 1, 1, 4, 4, 1, 3),   # grey-green house
    "D": (5, 0, 44, 6, 6, 1, 1, 4, 4, 2, 3),    # purple house with a turret
    "O": (5, 0, 37, 6, 6, 1, 1, 4, 4, 1, 3),    # brown house
    "h": (14, 0, 0, 6, 6, 1, 1, 4, 4, 1, 3),    # green house
    "W": (12, 0, 0, 6, 6, 1, 1, 4, 4, 1, 3),    # red wooden house
    "u": (5, 0, 30, 6, 6, 1, 1, 4, 4, 1, 3),    # red gabled house
    "r": (5, 0, 23, 6, 6, 1, 1, 4, 4, 1, 3),    # pink house
    "Q": (13, 0, 9, 8, 7, 0, 2, 7, 4, 3, 3),    # grey building with round windows (immeuble gris)
    "X": (14, 0, 0, 6, 6, 1, 2, 4, 3, 1, 2),    # small green house (Card vert)
    "Y": (13, 0, 21, 6, 5, 1, 1, 4, 3, 1, 2),   # dark green house (Card vert, miroir)
    "Z": (15, 0, 20, 6, 6, 1, 2, 5, 3, 1, 2),   # orange house (Card orange)
    "A": (13, 0, 0, 7, 8, 1, 4, 6, 3, 1, 2),    # pink gabled house (Card orange, miroir)
    "B": (14, 0, 17, 5, 6, 0, 2, 4, 3, 1, 2),   # big green house (immeuble)
}
# Buildings added after the streets (#199, second part): below them, so that
# the tiles before keep their numbers. Their sheet packs drawings close
# together: only the drawing itself is kept (what touches its door's wall),
# the bits of its neighbours in its frame become see-through.
LATE_BUILDINGS = ["Q", "X", "Y", "Z", "A", "B"]
# The sheet draws the side edges of a roof (its overhang, up to EDGE_WIDTH px)
# apart, one tile away from the building, over a tile that only holds
# shadow: they are put back against it (roof_edges). Shorter runs than
# EDGE_ROWS px are something else.
EDGE_WIDTH = 8
EDGE_ROWS = 10
# Drawings that go beyond their frame in the sheet (a few pixels of roof, the
# end of a shadow): symbol => (columns more on the left, rows more above,
# columns more on the right, of which only the shadow is taken). The built
# tileset gets them from tools/art/building_edges_4g.py.
TALLER = {"C": (1, 1, 0), "M": (0, 1, 0), "N": (0, 1, 0), "U": (0, 1, 0), "s": (0, 0, 1), "y": (0, 0, 1)}
# Drawn against another piece of the sheet (the awning that lengthens a
# stand): only their shadow is checked beyond their frame (cut_drawings).
JOINED = {"s", "y"}
SHADOW = (2, 3, 31, 76)   # the Buildings sheet's shadow
# More buildings (#199, third part), after everything else: symbol =>
# (parts, block x, y, width, height, door x, y in the drawing or None for a
# building with no door). A part is (sheet column, x, y, width, height of its
# frame, x, y of the frame in the drawing, x, y of a pixel of it in the
# column): only the pixels joined to that one are kept (all those of the
# frame with -1, -1). The sheet cuts the biggest buildings in two halves, put
# back side by side.
# The symbols of the right part of the buildings wider than 8 tiles
WIDE_SYMBOLS = {"μ": ["Ђ"], "ν": ["Є"], "ξ": ["Ѕ"], "ο": ["Ј"], "L": ["Ї"]}
MORE_BUILDINGS = {
    "R": ([(14, 0, 40, 7, 7, 0, 0, 55, 643)], (1, 3, 5, 3), (3, 5)),   # Dôme crème
    "I": ([(11, 0, 69, 8, 10, 0, 0, 9, 1107)], (0, 4, 8, 5), (3, 8)),   # Bâtiment de la Ligue
    "Α": ([(0, 0, 8, 7, 7, 0, 0, 19, 142)], (1, 3, 5, 3), (3, 5)),   # Centre Pokémon (toit rouge)
    "Β": ([(5, 0, 7, 7, 8, 0, 0, 55, 121)], (1, 4, 5, 3), (2, 6)),   # Haute maison turquoise
    "Γ": ([(5, 0, 15, 8, 7, 0, 0, 18, 245)], (1, 3, 6, 3), (2, 5)),   # Maison turquoise à annexe
    "Δ": ([(5, 0, 51, 8, 7, 0, 0, 67, 816)], (1, 3, 7, 3), (4, 5)),   # Grande maison aux tuiles violettes
    "Ε": ([(6, 0, 25, 7, 8, 0, 0, 42, 401)], (1, 3, 5, 4), (3, 6)),   # Maison en rondins
    "Ζ": ([(6, 0, 59, 6, 6, 0, 0, 44, 947)], (1, 2, 4, 3), (2, 4)),   # Chaumière
    "Η": ([(6, 0, 66, 6, 6, 0, 0, 68, 1060)], (1, 2, 4, 3), (2, 4)),   # Chaumière à cheminée
    "Θ": ([(7, 3, 0, 5, 7, 0, 0, 84, 5)], (1, 3, 3, 3), (2, 5)),   # Maison au toit rouge
    "Ι": ([(9, 0, 45, 6, 5, 0, 0, 27, 722)], (1, 1, 4, 3), (2, 3)),   # Maison orange à balustrade
    "Κ": ([(10, 4, 10, 4, 5, 0, 0, 70, 167)], (0, 1, 4, 3), (1, 3)),   # Maison aux bardeaux
    "Λ": ([(10, 0, 15, 6, 7, 0, 0, 32, 241)], (0, 2, 5, 3), (2, 4)),   # Chalet rouge
    "Μ": ([(10, 1, 39, 6, 6, 0, 0, 70, 634)], (1, 2, 4, 3), (2, 4)),   # Maison bordeaux à cheminée
    "Ν": ([(10, 1, 46, 6, 6, 0, 0, 60, 737)], (1, 2, 4, 3), (2, 4)),   # Maison au toit de mousse
    "Ξ": ([(11, 0, 30, 6, 6, 0, 0, 45, 488)], (1, 2, 4, 3), (2, 4)),   # Maison au toit vitré
    "Ο": ([(11, 0, 36, 6, 6, 0, 0, 44, 582)], (1, 2, 4, 3), (2, 4)),   # Maison au toit vitré bleu
    "Π": ([(11, 0, 43, 5, 5, 0, 0, 27, 692)], (0, 1, 4, 3), (1, 3)),   # Maison au pignon bleu
    "Ρ": ([(12, 0, 12, 6, 6, 0, 0, 45, 204)], (1, 2, 4, 3), (2, 4)),   # Case en paille
    "Σ": ([(14, 0, 7, 5, 5, 0, 0, 5, 113)], (0, 1, 4, 3), (1, 3)),   # Maison orange à escalier
    "Τ": ([(15, 0, 66, 5, 6, 0, 0, 17, 1067)], (0, 2, 4, 3), (1, 4)),   # Maison rouge à auvent
    "Υ": ([(16, 1, 0, 6, 6, 0, 0, 38, 9)], (1, 2, 4, 3), (2, 4)),   # Maison crème
    "Φ": ([(16, 0, 49, 5, 5, 0, 0, 10, 790)], (0, 1, 4, 3), (1, 3)),   # Maison ocre
    "Χ": ([(16, 0, 55, 5, 6, 0, 0, 10, 893)], (0, 2, 4, 3), (1, 4)),   # Maison mauve
    "Ψ": ([(6, 0, 44, 5, 5, 0, 0, 0, 708)], (0, 1, 4, 3), (1, 3)),   # Boutique au store bleu
    "Ω": ([(7, 0, 36, 5, 5, 0, 0, 3, 582)], (0, 1, 4, 3), (1, 3)),   # Boutique fleurie
    "α": ([(7, 0, 42, 8, 12, 0, 0, 55, 683)], (0, 6, 7, 5), (3, 10)),   # Tour à éolienne
    "β": ([(7, 0, 55, 7, 9, 0, 0, 21, 890)], (1, 4, 5, 4), (3, 7)),   # Immeuble orange
    "γ": ([(7, 0, 64, 6, 6, 0, 0, 28, 1031)], (0, 2, 5, 3), (2, 4)),   # Galerie au store rayé
    "δ": ([(7, 0, 71, 8, 6, 0, 0, 46, 1141)], (0, 2, 7, 3), (3, 4)),   # Salle de jeux violette
    "ε": ([(13, 0, 71, 6, 6, 0, 0, 6, 1146)], (0, 2, 5, 3), (2, 4)),   # Bâtiment à bassin
    "ζ": ([(14, 0, 47, 4, 5, 0, 0, 0, 758)], (0, 1, 4, 3), (1, 3)),   # Boutique mauve
    "η": ([(14, 0, 53, 8, 17, 0, 0, 43, 858)], (0, 9, 7, 6), (3, 14)),   # Tour dorée
    "θ": ([(14, 0, 70, 7, 9, 0, 0, 4, 1135)], (0, 4, 6, 4), (4, 7)),   # Immeuble vert
    "ι": ([(15, 0, 46, 8, 6, 0, 0, 19, 736)], (1, 2, 7, 3), (4, 4)),   # Salle aux néons
    "κ": ([(15, 0, 52, 6, 5, 0, 0, 23, 832)], (1, 1, 4, 3), (2, 3)),   # Boutique aux néons
    "λ": ([(16, 0, 69, 8, 7, 0, 0, 33, 1112)], (0, 2, 7, 3), (3, 4)),   # Club de combat
    "μ": ([(17, 2, 22, 6, 14, 0, 0, 124, 364), (17, 0, 35, 6, 14, 6, 0, 0, 572)], (1, 7, 10, 6), (5, 12)),   # Gratte-ciel
    "ν": ([(10, 3, 52, 5, 9, 0, 0, 118, 846), (10, 0, 61, 5, 9, 5, 0, 0, 990)], (1, 4, 9, 4), (5, 7)),   # Grand magasin bleu
    "ξ": ([(8, 3, 10, 5, 15, 0, 2, 127, 164), (8, 0, 21, 6, 17, 5, 0, 5, 336)], (1, 10, 9, 6), (5, 15)),   # Tour radio
    "ο": ([(14, 4, 22, 4, 10, 0, 0, 126, 367), (14, 0, 30, 5, 10, 4, 0, 0, 495)], (1, 4, 8, 4), (4, 7)),   # Pavillon rouge
    "π": ([(6, 0, 0, 7, 8, 0, 0, 14, 11)], (1, 4, 5, 3), None),   # Maison de pierre
    "ρ": ([(6, 0, 8, 7, 8, 0, 0, 14, 139)], (1, 3, 5, 3), None),   # Cabane en rondins
    "σ": ([(6, 0, 16, 7, 8, 0, 0, 47, 270)], (1, 4, 5, 3), None),   # Maison voûtée
    "τ": ([(6, 0, 34, 8, 7, 0, 0, 35, 552)], (1, 3, 6, 3), None),   # Abri au toit fleuri
    "υ": ([(6, 0, 73, 3, 5, 0, 0, 20, 1173)], (1, 1, 1, 3), None),   # Cabanon
    "φ": ([(7, 0, 23, 6, 7, 0, 0, 4, 369)], (0, 3, 5, 3), None),   # Immeuble de bureaux
    "χ": ([(7, 0, 30, 5, 6, 0, 0, 8, 485)], (0, 2, 4, 3), None),   # Petit immeuble beige
    "ψ": ([(9, 2, 36, 6, 6, 0, 0, 44, 587)], (1, 1, 4, 2), None),   # Abri en bois
    "ω": ([(9, 0, 51, 6, 5, 0, 0, 27, 818)], (1, 1, 4, 3), None),   # Maison à balustrade
    "Б": ([(9, 0, 56, 8, 7, 0, 0, 31, 906)], (1, 3, 7, 3), None),   # Demeure aux tuiles bleues
    "Г": ([(9, 0, 71, 8, 5, 0, 0, 0, 1136)], (0, 1, 7, 3), None),   # Longère
    "Д": ([(10, 0, 22, 5, 7, 0, 0, 36, 354)], (1, 2, 3, 3), None),   # Tourelle
    "Ж": ([(12, 1, 7, 4, 5, 0, 0, 29, 125)], (1, 1, 2, 3), None),   # Château d’eau
    "З": ([(13, 0, 16, 6, 5, 0, 0, 22, 256)], (1, 1, 4, 3), None),   # Maison verte à volets
    "И": ([(13, 1, 60, 5, 5, 0, 0, 26, 960)], (0, 1, 4, 3), None),   # Kiosque turquoise
    "Л": ([(15, 0, 0, 6, 6, 0, 0, 41, 1)], (1, 2, 4, 3), None),   # Tourelle verte
    "П": ([(15, 0, 6, 6, 8, 0, 0, 9, 97)], (0, 3, 5, 4), None),   # Immeuble à terrasses
    "Ф": ([(15, 1, 14, 6, 6, 0, 0, 56, 230)], (0, 2, 5, 3), None),   # Jardinerie
    "Ц": ([(15, 0, 73, 5, 6, 0, 0, 29, 1178)], (0, 2, 4, 3), None),   # Maison rose
    "Ч": ([(16, 0, 9, 7, 9, 0, 0, 43, 145)], (0, 4, 6, 4), None),   # Dôme orange
    "Ш": ([(16, 0, 38, 5, 5, 0, 0, 10, 614)], (0, 1, 4, 3), None),   # Maison verte au toit plat
    "Щ": ([(16, 0, 43, 5, 6, 0, 0, 10, 703)], (0, 2, 4, 3), None),   # Maison vert et jaune
    "Э": ([(16, 0, 62, 6, 7, 0, 0, 6, 994)], (0, 3, 5, 3), None),   # Immeuble jaune
    "L": ([(8, 0, 0, 8, 10, 0, 0, 75, 13), (8, 0, 10, 1, 9, 8, 1, -1, -1)], (1, 5, 8, 4), (3, 8)),   # Labo (dôme blanc)
    "J": ([(15, 0, 58, 7, 7, 0, 0, 12, 942)], (1, 3, 5, 3), (3, 5)),   # Entrepôt du port (toit bordeaux)
    "s": ([(11, 0, 61, 5, 4, 0, 0, 0, 982)], (0, 2, 5, 1), None),   # Stand au store bleu
    "y": ([(11, 0, 65, 5, 4, 0, 0, 0, 1046)], (0, 2, 5, 1), None),   # Stand au store rose
    "F": ([(0, 0, 29, 8, 9, 0, 0, 56, 504)], (1, 4, 5, 5), (3, 8)),   # Gare maritime (turquoise, escalier)
}
# Gyms, one per type in two styles (round, square), each type's the same
# drawing (8x7 tiles, the block 7x5 from its row 1, the door 3,4): style =>
# (symbol, [(sheet column, first row)] for the two columns of types, every
# 8 rows). The town draws the Normal one; WorldEvents paints the
# lieutenant's type over it (Plugins/WorldEvents/010_GymExteriors.rb).
GYM_TYPES = [["BUG", "DARK", "DRAGON", "ELECTRIC", "FAIRY", "FIGHTING", "FIRE", "FLYING", "GHOST"],
             ["GRASS", "GROUND", "ICE", "NORMAL", "POISON", "PSYCHIC", "ROCK", "STEEL", "WATER"]]
GYMS = {"round": ("G", [(1, 3), (2, 1)]), "square": ("H", [(3, 1), (4, 1)])}
GYM_SIZE = (8, 7)
GYM_BLOCK = (0, 1, 7, 5)
GYM_DOOR = (3, 4)


# Decor objects (#200), in place of the Emerald and KingTapir ones (MapProc's
# symbols and blocks kept): symbol => (sheet, column, x, y, width, height of
# the drawing, block x, y, width, height in it, passages). Passages: block
# (every tile of the block), tall (its bottom row; the rows above are walked
# under), tree (the middle of its bottom row), walk (none). The rest of the
# drawing is its halo, as for the buildings. Grass under a Nature drawing
# becomes see-through and its shades the sheets' translucent shadow.
# Single tiles of the decor laid on the ground ([Legend], blocked): symbol =>
# the variants drawn at random, [(sheet, column, x, y)]
LEGEND_PROPS = {
    "ā": [("U", 5, 5, 29), ("U", 5, 7, 29)],                     # pots (poteries)
    "ē": [("U", 5, 2, 29)],                                      # basket of greens (caisses)
    "ī": [("U", 5, 6, 29)],                                      # basket of flowers (jardinière)
    "ū": [("U", 5, 1, 29), ("U", 5, 4, 29)],                     # baskets of flowers (pots de fleurs)
    "ő": [("N", 3, 4, 27), ("N", 3, 1, 27)],                     # grey rocks (rochers moussus)
    "ű": [("N", 3, 5, 34)],                                      # white rock
    "ŵ": [("N", 3, 0, 27), ("N", 3, 2, 34)],                     # brown rocks (rochers rouges)
}
PROPS = {
    "ļ": ("N", 3, 1, 16, 1, 2, 0, 1, 1, 1, "block"),     # bush
    "ń": ("U", 5, 7, 26, 1, 2, 0, 0, 1, 2, "tall"),      # notice board (caisses empilées)
    "ď": ("N", 3, 0, 12, 3, 3, 1, 0, 1, 2, "block"),     # flower box
    "ž": ("N", 3, 0, 10, 4, 1, 0, 0, 3, 1, "block"),     # logs
    "ą": ("N", 3, 0, 36, 4, 4, 2, 2, 2, 2, "tall"),      # round tree
    "ð": ("N", 3, 0, 44, 4, 4, 2, 2, 2, 2, "tall"),      # bushy tree
    "œ": ("U", 5, 1, 23, 5, 5, 2, 3, 2, 2, "tall"),      # parasol and table
    "ß": ("U", 5, 1, 23, 5, 5, 2, 3, 2, 2, "tall"),
    "ÿ": ("U", 5, 1, 23, 5, 5, 2, 3, 2, 2, "tall"),
    "ă": ("N", 3, 3, 29, 2, 2, 0, 0, 2, 2, "block"),     # big brown rock
    "ĕ": ("N", 3, 6, 33, 2, 2, 0, 0, 2, 2, "block"),     # big red rock
    "ņ": ("U", 5, 1, 23, 5, 5, 1, 2, 3, 3, "tree"),      # parasol and table (parasol de plage)
    "ǚ": ("N", 3, 0, 36, 4, 4, 1, 1, 3, 3, "tree"),      # round tree
    "ǜ": ("U", 4, 1, 35, 4, 5, 2, 3, 2, 2, "tall"),      # fir
    "ȁ": ("N", 3, 0, 44, 4, 4, 2, 1, 2, 3, "tall"),      # bushy tree
    "Ā": ("U", 4, 2, 11, 2, 4, 0, 1, 1, 2, "tall"),      # stone pillar (statue)
    "Ă": ("U", 4, 4, 16, 1, 3, 0, 1, 1, 2, "tall"),      # street lamp
    "Ć": ("U", 5, 1, 13, 5, 4, 1, 1, 3, 3, "block"),     # sandpit (parterre)
    "ć": ("U", 4, 0, 32, 2, 3, 0, 0, 2, 3, "block"),     # fountain
    "Ĉ": ("U", 4, 0, 23, 2, 3, 0, 0, 1, 3, "tall"),      # red lamp (poteau)
    "Ċ": ("U", 4, 3, 26, 4, 3, 0, 0, 3, 2, "block"),     # hedge in its box (haie basse)
    "ċ": ("U", 4, 0, 15, 2, 4, 0, 1, 2, 3, "tall"),      # lantern
    "ĵ": ("U", 4, 0, 15, 2, 4, 0, 1, 2, 3, "tall"),
    "Č": ("U", 4, 1, 35, 4, 5, 1, 0, 3, 5, "tree"),      # fir (arbre de Galar)
    "č": ("N", 3, 0, 44, 4, 4, 2, 1, 2, 3, "tall"),      # bushy tree
    "Đ": ("U", 4, 3, 3, 4, 5, 1, 2, 3, 3, "tall"),       # billboard
    "İ": ("U", 4, 3, 3, 4, 5, 1, 2, 3, 3, "tall"),
    "đ": ("U", 4, 4, 9, 1, 2, 0, 0, 1, 2, "tall"),       # post box
    "Ē": ("U", 4, 0, 6, 3, 5, 1, 1, 1, 3, "tall"),       # pole with a sign (distributeur)
    "Ĕ": ("U", 4, 7, 8, 1, 3, 0, 1, 1, 2, "tall"),       # orange machine (gachas)
    "Ė": ("U", 5, 6, 17, 1, 3, 0, 1, 1, 2, "tall"),      # drinks machines
    "ė": ("U", 5, 7, 17, 1, 3, 0, 1, 1, 2, "tall"),
    "Ę": ("U", 4, 5, 1, 2, 2, 0, 0, 2, 2, "tall"),       # machine and screen (panneaux)
    "ĝ": ("U", 4, 5, 1, 2, 2, 0, 0, 2, 2, "tall"),
    "Ğ": ("U", 5, 6, 17, 2, 3, 0, 1, 2, 2, "tall"),
    "ę": ("U", 5, 1, 7, 2, 3, 0, 0, 2, 2, "block"),      # logs
    "Ě": ("U", 5, 3, 7, 3, 3, 1, 0, 2, 2, "block"),
    "ğ": ("U", 3, 4, 29, 1, 2, 0, 1, 1, 1, "block"),     # orange bollard (cône)
    "Ġ": ("U", 3, 5, 29, 1, 2, 0, 1, 1, 1, "block"),     # white bollard (caisse plate)
    "ġ": ("U", 5, 7, 26, 1, 2, 0, 0, 1, 2, "tall"),      # notice board (caisse haute)
    "Ĥ": ("U", 5, 1, 17, 3, 2, 0, 1, 2, 1, "block"),     # bench
    "ĥ": ("U", 5, 1, 17, 3, 2, 0, 1, 3, 1, "block"),     # bench (and its shadow)
    "Ĵ": ("U", 4, 0, 3, 3, 2, 1, 0, 1, 2, "tall"),       # bus stop sign
    "Ņ": ("U", 5, 1, 17, 3, 2, 0, 0, 2, 2, "block"),     # bench
    "a": ("N", 3, 0, 33, 2, 2, 0, 0, 2, 2, "block"),     # brown rock pile (flèche brune, désert)
    "i": ("N", 3, 5, 28, 3, 4, 0, 1, 3, 2, "block"),     # grey rock spire (flèche grise, minéral)
    "v": ("U", 5, 1, 30, 2, 4, 0, 0, 2, 4, "block"),     # statue on its pedestal (statue de la Famille)
}

# Paved streets of other styles (MapProc's « Rue » variants, drawn per town
# and per district): name => (sheet, column, full patch x, y (4x4 tiles), its
# middle tile x, y, patch with a hole x, y). Edges and corners from the full
# patch, inner corners from the quarters of the hole, laid over the grass.
STREETS = {
    "bleue": ("U", 1, 0, 5, 1, 6, 4, 5),
    "violette": ("U", 1, 4, 28, 5, 29, 0, 28),
}
# Role => (from the full patch, x, y) or (from the hole, x, y), in the order
# of a MapGen [Terrains] line
STREET_ROLES = [("", 0, 0, None), ("N", 1, 0, "o"), ("S", 1, 3, "o"), ("W", 0, 1, "o"), ("E", 3, 1, "o"),
                ("NW", 0, 0, "o"), ("NE", 3, 0, "o"), ("SW", 0, 3, "o"), ("SE", 3, 3, "o"),
                ("iNW", 2, 2, "h"), ("iNE", 1, 2, "h"), ("iSW", 2, 1, "h"), ("iSE", 1, 1, "h")]


def drawing_pixels(sheet, col, door_x, door_y):
    """Pixels (x, y in the sheet) of the Buildings drawing whose door is at
    that tile: all those that touch the wall above it."""
    px = sheet.load()
    left = 16 + 144 * col
    clear = {MAGENTA, (255, 245, 104, 255)}
    start = (left + door_x * 16 + 8, door_y * 16 - 8)
    seen = {start}
    stack = [start]
    while stack:
        a, b = stack.pop()
        for q in ((a + 1, b), (a - 1, b), (a, b + 1), (a, b - 1)):
            if q not in seen and left <= q[0] < left + 128 and 0 <= q[1] < sheet.height and px[q] not in clear:
                seen.add(q)
                stack.append(q)
    return seen


def joined_pixels(sheet, col, start):
    """Pixels (x, y in the column) joined to that one, in the Buildings sheet."""
    px = sheet.load()
    left = 16 + 144 * col
    clear = {MAGENTA, (255, 245, 104, 255)}
    start = (left + start[0], start[1])
    seen = {start}
    stack = [start]
    while stack:
        a, b = stack.pop()
        for q in ((a + 1, b), (a - 1, b), (a, b + 1), (a, b - 1)):
            if q not in seen and left <= q[0] < left + 128 and 0 <= q[1] < sheet.height and px[q] not in clear:
                seen.add(q)
                stack.append(q)
    return {(a - left, b) for a, b in seen}


def roof_edge_pixels(sheet, col, x, y, w, h):
    """The side edges of the roof of a Buildings drawing (its frame in 16 px
    tiles), which the sheet draws one tile away from it: [(x, y in the
    column, x where it belongs)]."""
    px = sheet.load()
    left = 16 + 144 * col
    solid = lambda a, b: 0 <= a < 128 and px[left + a, b] not in (MAGENTA, (255, 245, 104, 255), SHADOW)
    found = {}   # (boundary, side) => [(x, y, x where it belongs)]
    for b in range(y * 16, (y + h) * 16):
        for bx in range(x * 16 - 16, (x + w) * 16 + 17, 16):
            # After the building: the edge starts the next tile
            k = next((i for i in range(EDGE_WIDTH + 1) if not solid(bx + i, b)), EDGE_WIDTH + 1)
            if 0 < k <= EDGE_WIDTH and solid(bx - 17, b) and not any(solid(bx - 16 + i, b) for i in range(k)):
                found.setdefault((bx, 1), []).extend((bx + i, b, bx + i - 16) for i in range(k))
            # Before it: the edge ends the tile before
            k = next((i for i in range(EDGE_WIDTH + 1) if not solid(bx - 1 - i, b)), EDGE_WIDTH + 1)
            if 0 < k <= EDGE_WIDTH and solid(bx + 16, b) and not any(solid(bx + 15 - i, b) for i in range(k)):
                found.setdefault((bx, -1), []).extend((bx - 1 - i, b, bx + 15 - i) for i in range(k))
    out = []
    for (bx, side), pixels in found.items():
        rows = {b for _a, b, _to in pixels}
        if len(rows) < EDGE_ROWS:
            continue
        out += pixels
        # The edge goes on above and below, over the building where it is
        # wider (its roof covers the top of the wall)
        for step, b in ((-1, min(rows) - 1), (1, max(rows) + 1)):
            while b not in rows and y * 16 <= b < (y + h) * 16:
                run = [bx + i if side == 1 else bx - 1 - i for i in range(EDGE_WIDTH + 1)]
                k = next((i for i, a in enumerate(run) if not solid(a, b)), EDGE_WIDTH + 1)
                if not 0 < k <= EDGE_WIDTH:
                    break
                out += [(a, b, a - 16 * side) for a in run[:k]]
                b += step
    return out


def roof_edges(sheet, col, x, y, w, h):
    """Those edges where they belong: {(tile x, y in the column): 16 px
    image}."""
    px = sheet.load()
    left = 16 + 144 * col
    out = {}
    for a, b, to in roof_edge_pixels(sheet, col, x, y, w, h):
        tile = out.setdefault((to // 16, b // 16), Image.new("RGBA", (16, 16)))
        tile.putpixel((to % 16, b % 16), px[left + a, b])
    return out


def building_frames():
    """Each building drawn from one frame of the sheet: (symbol, column, x,
    y, w, h of its frame in tiles, a pixel of it in the column)."""
    frames = [(sym, col, x, y, w, h, ((x + bx) * 16 + bw * 8, (y + by) * 16 + bh * 8))
              for sym, (col, x, y, w, h, bx, by, bw, bh, *_door) in BUILDINGS.items()]
    for sym, (parts, _block, _door) in MORE_BUILDINGS.items():
        col, x, y, w, h, _ox, _oy, sx, sy = parts[0]
        frames.append((sym, col, x, y, w, h, (sx, sy))) if len(parts) == 1 and sx >= 0 else None
    return frames


def cut_drawings(sheet):
    """The buildings that their frame cuts (no tile is ever cut): [(symbol,
    pixels beyond its frame on the left, above, on the right, below)]. A
    drawing is every pixel joined to it, shadow included; its frame is the
    one of its table and TALLER; the roof edges drawn apart (roof_edges)
    are not beyond it."""
    px = sheet.load()
    clear = {MAGENTA, (255, 245, 104, 255)}
    cut = []
    for sym, col, x, y, w, h, start in building_frames():
        left = 16 + 144 * col
        more_left, more_top, more_right = TALLER.get(sym, (0, 0, 0))
        x0, y0, x1, y1 = (x - more_left) * 16, (y - more_top) * 16, (x + w + more_right) * 16, (y + h) * 16
        apart = {(a, b) for a, b, _to in roof_edge_pixels(sheet, col, x, y, w, h)}
        seen = {start}
        stack = [start]
        while stack:
            a, b = stack.pop()
            for q in ((a + 1, b), (a - 1, b), (a, b + 1), (a, b - 1)):
                if q not in seen and q not in apart and 0 <= q[0] < 128 and 0 <= q[1] < sheet.height and px[left + q[0], q[1]] not in clear:
                    seen.add(q)
                    stack.append(q)
        seen = {q for q in seen if px[left + q[0], q[1]] == SHADOW} if sym in JOINED else seen
        beyond = (sum(a < x0 for a, _b in seen), sum(b < y0 for _a, b in seen), sum(a >= x1 for a, _b in seen), sum(b >= y1 for _a, b in seen))
        if any(beyond):
            cut.append((sym, *beyond))
    return cut


def drawing_image(sheet, parts):
    """A MORE_BUILDINGS drawing, its parts put together (16 px tiles)."""
    width = max(p[5] + p[3] for p in parts)
    height = max(p[6] + p[4] for p in parts)
    out = Image.new("RGBA", (width * 16, height * 16))
    src = sheet.load()
    dst = out.load()
    for col, x, y, w, h, ox, oy, sx, sy in parts:
        left = 16 + 144 * col
        clear = {MAGENTA, (255, 245, 104, 255)}
        # No pixel given: the whole frame
        pixels = joined_pixels(sheet, col, (sx, sy)) if sx >= 0 else \
            {(a, b) for a in range(x * 16, (x + w) * 16) for b in range(y * 16, (y + h) * 16) if src[left + a, b] not in clear}
        for a, b in pixels:
            if x * 16 <= a < (x + w) * 16 and y * 16 <= b < (y + h) * 16:
                dst[a - x * 16 + ox * 16, b - y * 16 + oy * 16] = src[left + a, b]
        for (tx, ty), edge in roof_edges(sheet, col, x, y, w, h).items():
            if x <= tx < x + w:
                out.alpha_composite(edge, ((tx - x + ox) * 16, (ty - y + oy) * 16))
    return out


def only_drawing(tile, keep, col, tx, ty):
    """That tile (scaled x2) with only the pixels of the drawing kept."""
    tile = tile.copy()
    out = tile.load()
    left = 16 + 144 * col
    for y in range(TILE):
        for x in range(TILE):
            if (left + tx * 16 + x // 2, ty * 16 + y // 2) not in keep:
                out[x, y] = (0, 0, 0, 0)
    return tile


def building_passages(tile, inside, door):
    """Passages of a building tile ("=<n>" or a tile to copy, see
    tools/art/tileset_tables.rb)."""
    if inside:
        return "=0" if door else "=15"
    if all(c[3] == 0 or c == SHADOW for c in tile.get_flattened_data()):
        return "=0"
    return TALL


def prop_passages(tile, kind, tx, ty, bx, by, bw, bh):
    """Passages of a decor object's tile (see PROPS)."""
    if not (bx <= tx < bx + bw and by <= ty < by + bh):
        return building_passages(tile, False, False)
    bottom = ty == by + bh - 1
    if kind == "block" or (kind == "tall" and bottom) or (kind == "tree" and bottom and tx == bx + bw // 2):
        return "=15"
    return -1 if kind == "walk" or not tile.getbbox() else TALL


def unground(tile):
    """A Nature drawing off its grass: the grass see-through, its shades the
    translucent shadow."""
    tile = tile.copy()
    tile.putdata([(0, 0, 0, 0) if c in GRASS else SHADOW if c in SHADOWS else c for c in tile.get_flattened_data()])
    return tile


def cliff_passages(row, col, tile):
    """Passages of a cliff tile ("=<n>", see tools/art/tileset_tables.rb):
    a rim can't be crossed to the south (nor climbed from it), the sides and
    the south face are blocked, the top is walked on."""
    if not tile.getbbox():
        return -1
    if row == 0 or (row == 4 and col in (5, 6)):
        return "=1"
    if row == 4 or col in (0, 3, 4, 7) or row == 3:
        return "=15"
    return -1


def box(tile):
    return ((tile % 8) * TILE, (tile // 8) * TILE, (tile % 8) * TILE + TILE, (tile // 8) * TILE + TILE)


def sheet_tile(sheets, src):
    """One 16 px tile of a sheet, scaled x2, its pink and unused colours
    see-through (the Buildings sheet: magenta and yellow; its white is
    drawn)."""
    sheet, col, tx, ty = src
    left = 16 + 144 * col
    im = sheets[sheet].crop((left + tx * 16, ty * 16, left + tx * 16 + 16, ty * 16 + 16))
    clear = {MAGENTA, (255, 245, 104, 255)} if sheet == "B" else {PINK} | UNUSED
    im.putdata([(0, 0, 0, 0) if c in clear else c for c in im.get_flattened_data()])
    return im.resize((TILE, TILE), Image.NEAREST)


def on_ground(tile, ground, opaque=False, cliff=False):
    """A tile on another ground: its grass see-through (or the ground), its
    shadows the darkened ground (on a cliff, every shade of grass)."""
    tile = tile.copy()
    px, g = tile.load(), ground.load()
    for y in range(TILE):
        for x in range(TILE):
            c = px[x, y]
            shade = SHADOWS.get(c)
            if cliff and c[3] and c[1] > c[0] + CLIFF_GREEN:
                shade = min(1.0, c[1] / GRASS_GREEN)
            if c in GRASS:
                px[x, y] = g[x, y] if opaque else (0, 0, 0, 0)
            elif shade:
                k = shade
                r, gg, b, _a = g[x, y]
                px[x, y] = (int(r * k), int(gg * k), int(b * k), 255)
    return tile


def patch_grass(tile):
    """The tall grass in the middle of a patch on another ground: the gaps
    between its blades the dark green of the blades, not that ground (its
    light dots repeated tile after tile looked cut)."""
    return dark_gaps(tile, TILE)


def dark_gaps(tile, rows):
    """The tile with the ground's teal (bluer than red) of its first rows
    the dark green of the blades, each shade by its brightness (a foot keeps
    the ground below its blades)."""
    tile = tile.copy()
    px = tile.load()
    for y in range(rows):
        for x in range(TILE):
            c = px[x, y]
            if c[3] and c[2] > c[0] + 20:
                k = min(1.0, c[1] / 216)
                px[x, y] = tuple(int(v * k) for v in PATCH_GREEN[:3]) + (255,)
    return tile


def build(folder):
    sheets = {k: Image.open(f"{folder}/{name}").convert("RGBA") for k, name in SHEETS.items()}
    old = Image.open(SOURCE).convert("RGBA")
    grass = sheet_tile(sheets, TILES[1])
    tiles = {}
    for dest, src in TILES.items():
        drawing = sheet_tile(sheets, src)
        if dest in UNGROUNDED:
            drawing = unground(drawing)
        if dest in MIRRORED:
            drawing = drawing.transpose(Image.FLIP_LEFT_RIGHT)
        tile = Image.new("RGBA", (TILE, TILE))
        if dest not in SEE_THROUGH:
            tile.paste(grass)
        tile.alpha_composite(drawing)
        tiles[dest] = tile
    for dest in CLEARED:
        tiles[dest] = Image.new("RGBA", (TILE, TILE))
    # The very tall grass's top: the ground's teal between its blades dark,
    # like the tall grass of the other grounds (it stands on all of them)
    # (and the notch left of its tips, in its lower half: the ground would
    # show through, between two rows of it)
    tiles[7] = dark_gaps(tiles[7], TILE)
    notch = tiles[7].load()
    for y in range(TILE // 2, TILE):
        for x in range(TILE):
            if not notch[x, y][3]:
                notch[x, y] = PATCH_GREEN
    for ground_id, (tall, foot) in GRASS_VARIANTS.items():
        ground = tiles[ground_id] if ground_id in tiles else old.crop(box(ground_id))
        tiles[tall] = patch_grass(tiles[6])
        tiles[foot] = on_ground(dark_gaps(tiles[15], TILE // 2), ground, True)
    # Trees: whole drawings below the old tileset, in slots of 4x4 tiles (two
    # per row of slots)
    first_new = (old.height // TILE) * 8
    placed = []   # (ground, symbol, first tile of the drawing)
    copies = {}   # new tile => tile whose passages it takes
    for slot, (ground_id, sym) in enumerate((g, s) for g, syms in GROUNDS.items() for s in syms):
        # The ground as the new tileset draws it (sand and dirt are 4G)
        ground = None
        if ground_id is not None:
            ground = tiles[ground_id] if ground_id in tiles else old.crop(box(ground_id))
        old_first, width, height, drawing, bx, by = TREES[sym]
        first = first_new + (slot // 2) * 4 * 8 + (slot % 2) * 4
        for dy, row in enumerate(drawing):
            for dx, src in enumerate(row):
                dest = first + dy * 8 + dx
                tile = sheet_tile(sheets, src) if src else Image.new("RGBA", (TILE, TILE))
                tiles[dest] = on_ground(tile, ground) if ground else tile
                inside = bx <= dx < bx + width and by <= dy < by + height
                copies[dest] = old_first + (dy - by) * 8 + (dx - bx) if inside else TALL
        # Cells of the halo with nothing drawn: MapGen leaves them out, so
        # that they never hide a neighbour's drawing
        empty = [dy * len(row) + dx for dy, row in enumerate(drawing) for dx in range(len(row))
                 if not (bx <= dx < bx + width and by <= dy < by + height)
                 and not tiles[first + dy * 8 + dx].getbbox()]
        placed.append((ground_id, sym, first, empty))
    # Forests: below the trees, a blocked and a halo copy per ground, side
    # by side on 6 rows (the last 2 columns stay empty)
    forest_first = first_new + ((len(placed) + 1) // 2) * 4 * 8
    sym, col, row = FOREST
    forests = []   # (ground, first blocked tile, first halo tile)
    for k, ground_id in enumerate(GROUNDS):
        ground = None
        if ground_id is not None:
            ground = tiles[ground_id] if ground_id in tiles else old.crop(box(ground_id))
        solid = forest_first + k * 2 * FOREST_SIZE * 8
        halo = solid + FOREST_SIZE * 8
        for dy in range(FOREST_SIZE):
            for dx in range(FOREST_SIZE):
                tile = sheet_tile(sheets, ("N", col, dx, row + dy))
                tile = on_ground(tile, ground) if ground else tile
                for first, passages in ((solid, SOLID), (halo, TALL)):
                    tiles[first + dy * 8 + dx] = tile
                    copies[first + dy * 8 + dx] = passages
        forests.append((ground_id, solid, halo))
    # Cliffs, cave entrances, the ledge, then a see-through tile that can't
    # be left to the north (the north edge of a plateau under its rim)
    cliff_first = forest_first + len(GROUNDS) * 2 * FOREST_SIZE * 8
    cliffs = []   # (ground, column, first tile)
    for k, (ground_id, col, row) in enumerate(CLIFFS):
        ground = None
        if ground_id is not None and row:
            ground = tiles[ground_id] if ground_id in tiles else old.crop(box(ground_id))
        first = cliff_first + k * CLIFF_ROWS * 8
        for dy in range(CLIFF_ROWS):
            for dx in range(8):
                tile = sheet_tile(sheets, ("N", col, dx, row + dy))
                tile = on_ground(tile, ground, cliff=True) if ground else tile
                tiles[first + dy * 8 + dx] = tile
                copies[first + dy * 8 + dx] = cliff_passages(dy, dx, tile)
        cliffs.append((ground_id, col, row, first))
    cave_first = cliff_first + len(CLIFFS) * CLIFF_ROWS * 8
    caves = []
    for k, (col, row) in enumerate(CAVES):
        first = cave_first + k * 3 * 8
        for i, src in enumerate(CAVE_PASSAGES):
            dest = first + (i // 3) * 8 + i % 3
            tiles[dest] = sheet_tile(sheets, ("N", col, 1 + i % 3, row + i // 3))
            copies[dest] = src
        caves.append(first)
    extra = cave_first + len(CAVES) * 3 * 8
    for i, (src, passages) in enumerate(LEDGE):
        tiles[extra + i] = sheet_tile(sheets, src)
        copies[extra + i] = passages
    blocker = extra + len(LEDGE)
    tiles[blocker] = Image.new("RGBA", (TILE, TILE))
    copies[blocker] = "=8"
    # Buildings, each from a new row of the tileset
    buildings = []   # (symbol, first tile of the drawing, empty cells)
    first = extra + 8
    def add_buildings(symbols, first):
        for sym in symbols:
            col, x, y, w, h, bx, by, bw, bh, dx, dy = BUILDINGS[sym]
            keep = drawing_pixels(sheets["B"], col, x + bx + dx, y + by + dy) if sym in LATE_BUILDINGS else None
            edges = roof_edges(sheets["B"], col, x, y, w, h)
            empty = []
            for ty in range(h):
                for tx in range(w):
                    dest = first + ty * 8 + tx
                    tile = sheet_tile(sheets, ("B", col, x + tx, y + ty))
                    if keep is not None:
                        tile = only_drawing(tile, keep, col, x + tx, y + ty)
                    if (x + tx, y + ty) in edges:
                        tile = Image.alpha_composite(tile, edges[(x + tx, y + ty)].resize((TILE, TILE), Image.NEAREST))
                    inside = bx <= tx < bx + bw and by <= ty < by + bh
                    tiles[dest] = tile
                    copies[dest] = building_passages(tile, inside, (tx, ty) == (bx + dx, by + dy))
                    if not inside and not tile.getbbox():
                        empty.append(ty * w + tx)
            buildings.append((sym, first, empty))
            first += h * 8
        return first
    first = add_buildings([sym for sym in BUILDINGS if sym not in LATE_BUILDINGS], first)
    gyms = {}   # style => {type: first tile of its drawing}, and its empty cells
    w, h = GYM_SIZE
    bx, by, bw, bh = GYM_BLOCK
    for style, (sym, columns) in GYMS.items():
        gyms[style] = {}
        for (col, row), types in zip(columns, GYM_TYPES):
            for k, gym_type in enumerate(types):
                empty = []
                for ty in range(h):
                    for tx in range(w):
                        dest = first + ty * 8 + tx
                        tile = sheet_tile(sheets, ("B", col, tx, row + k * 8 + ty))
                        inside = bx <= tx < bx + bw and by <= ty < by + bh
                        tiles[dest] = tile
                        copies[dest] = building_passages(tile, inside, (tx, ty) == (bx + GYM_DOOR[0], by + GYM_DOOR[1]))
                        if not inside and not tile.getbbox():
                            empty.append(ty * w + tx)
                gyms[style][gym_type] = (first, empty)
                first += h * 8
    props = []   # (symbol, first tile of the drawing, empty cells)
    legend = {}   # symbol => its tiles
    for sym, variants in LEGEND_PROPS.items():
        legend[sym] = []
        for i, (sheet, col, x, y) in enumerate(variants):
            tile = sheet_tile(sheets, (sheet, col, x, y))
            tiles[first + i] = unground(tile) if sheet == "N" else tile
            copies[first + i] = "=15"
            legend[sym].append(first + i)
        first += 8
    for sym, (sheet, col, x, y, w, h, bx, by, bw, bh, kind) in PROPS.items():
        empty = []
        for ty in range(h):
            for tx in range(w):
                dest = first + ty * 8 + tx
                tile = sheet_tile(sheets, (sheet, col, x + tx, y + ty))
                tile = unground(tile) if sheet == "N" else tile
                tiles[dest] = tile
                copies[dest] = prop_passages(tile, kind, tx, ty, bx, by, bw, bh)
                inside = bx <= tx < bx + bw and by <= ty < by + bh
                if not inside and not tile.getbbox():
                    empty.append(ty * w + tx)
        props.append((sym, first, empty))
        first += h * 8
    streets = {}   # name => the tile of each role
    for name, (sheet, col, ox, oy, cx, cy, hx, hy) in STREETS.items():
        streets[name] = []
        for i, (_role, dx, dy, part) in enumerate(STREET_ROLES):
            src = (cx, cy) if part is None else (ox + dx, oy + dy) if part == "o" else (hx + dx, hy + dy)
            tile = Image.new("RGBA", (TILE, TILE))
            tile.paste(grass)
            tile.alpha_composite(sheet_tile(sheets, (sheet, col) + src))
            tiles[first + i] = tile
            copies[first + i] = -1
            streets[name].append(first + i)
        first += 16
    first = add_buildings(LATE_BUILDINGS, first)
    more = []   # (symbol, first tile, empty cells, its part of the drawing, block)
    for sym, (parts, (bx, by, bw, bh), door) in MORE_BUILDINGS.items():
        drawing = drawing_image(sheets["B"], parts)
        w, h = drawing.width // 16, drawing.height // 16
        # Wider than the tileset's 8 tiles: one object per 8 columns, side by
        # side in the brick (WIDE_SYMBOLS)
        for k, part_sym in enumerate([sym] + WIDE_SYMBOLS.get(sym, [])[:(w - 1) // 8]):
            x0, x1 = k * 8, min(w, k * 8 + 8)
            empty = []
            for ty in range(h):
                for tx in range(x0, x1):
                    dest = first + ty * 8 + tx - x0
                    tile = drawing.crop((tx * 16, ty * 16, tx * 16 + 16, ty * 16 + 16)).resize((TILE, TILE), Image.NEAREST)
                    inside = bx <= tx < bx + bw and by <= ty < by + bh
                    tiles[dest] = tile
                    copies[dest] = building_passages(tile, inside, (tx, ty) == door)
                    if not inside and not tile.getbbox():
                        empty.append(ty * (x1 - x0) + tx - x0)
            part_block = (max(bx, x0) - x0, by, min(bx + bw, x1) - max(bx, x0), bh)
            more.append((part_sym, first, empty, (x1 - x0, h), part_block))
            first += h * 8
    snow = build_snow(sheets, tiles, copies, first)
    first = snow["end"]
    snow["edges"] = build_grass_edges(sheets, tiles, copies, first)
    first += 8
    snow["marsh"] = build_marsh(sheets, tiles, copies, first, grass)
    first += 6 * 8
    snow["volcano"] = build_volcano(sheets, tiles, copies, first, snow["edges"])
    first = snow["volcano"]["end"]
    snow["farm"] = build_farm(sheets, tiles, copies, first)
    first = snow["farm"]["end"]
    count = first - first_new
    out = Image.new("RGBA", (old.width, old.height + (count // 8) * TILE), (0, 0, 0, 0))
    out.paste(old, (0, 0))
    for dest, tile in tiles.items():
        out.paste((0, 0, 0, 0), box(dest))
        out.paste(tile, box(dest)[:2])
    return out, placed, forests, copies, count, (cliffs, caves, extra, blocker, buildings, gyms, props, legend, streets, more, snow)


def build_snow(sheets, tiles, copies, first):
    """The tiles of the snow ambiance from `first`, one block of 8 per row.
    Returns their numbers by role, and "end" (the next free tile)."""
    snow = {}
    grounds = [sheet_tile(sheets, ("N",) + src) for src in SNOW_GROUND]
    ground = grounds[0]
    # Row 1: the 4 snow tiles, then the very tall grass's foot and the tall
    # grass on the snow, then a deep snow and an ice tile
    for i, tile in enumerate(grounds):
        tiles[first + i] = tile
        copies[first + i] = -1
    snow["ground"] = [first + i for i in range(len(grounds))]
    tiles[first + 4] = patch_grass(tiles[6])
    copies[first + 4] = 6
    tiles[first + 5] = on_ground(dark_gaps(tiles[15], TILE // 2), ground, True)
    copies[first + 5] = 15
    snow["grass"] = (first + 4, first + 5)
    first += 8
    # Row 2: deep snow (4 variants), then ice (4 variants)
    for i, tile in enumerate(grounds):
        tiles[first + i] = tint(tile, [(224, 232, 248, 255), (184, 204, 236, 255)])
        copies[first + i] = f"=0/{DEEP_SNOW_TAG}"
        tiles[first + 4 + i] = tint(tile, [(176, 220, 248, 255), (232, 248, 255, 255)])
        copies[first + 4 + i] = f"=0/{ICE_TAG}"
    snow["deep"] = [first + i for i in range(4)]
    snow["ice"] = [first + 4 + i for i in range(4)]
    first += 8
    # Trees on the snow, in slots of 4x4 tiles, two per row of slots
    snow["trees"] = []
    for slot, (sym, (drawing, bx, by)) in enumerate(SNOW_TREES.items()):
        old_first, width, height = TREES[sym][:3]
        top = first + (slot // 2) * 4 * 8 + (slot % 2) * 4
        for dy, row in enumerate(drawing):
            for dx, src in enumerate(row):
                tile = sheet_tile(sheets, src) if src else Image.new("RGBA", (TILE, TILE))
                tiles[top + dy * 8 + dx] = on_ground(tile, ground)
                inside = bx <= dx < bx + width and by <= dy < by + height
                copies[top + dy * 8 + dx] = old_first + (dy - by) * 8 + (dx - bx) if inside else TALL
        empty = [dy * len(row) + dx for dy, row in enumerate(drawing) for dx in range(len(row))
                 if not (bx <= dx < bx + width and by <= dy < by + height)
                 and not tiles[top + dy * 8 + dx].getbbox()]
        snow["trees"].append((sym, top, (len(drawing[0]), len(drawing)), (bx, by, width, height), empty))
    first += ((len(SNOW_TREES) + 1) // 2) * 4 * 8
    # The snowy forest: blocked, then with a halo's passages
    solid, halo = first, first + FOREST_SIZE * 8
    for dy in range(FOREST_SIZE):
        for dx in range(FOREST_SIZE):
            tile = Image.new("RGBA", (TILE, TILE)) if (dx, dy) in SNOW_FOREST_SAMPLES \
                else sheet_tile(sheets, ("N", FOREST[1], dx, SNOW_FOREST_ROW + dy))
            for top, passages in ((solid, SOLID), (halo, TALL)):
                tiles[top + dy * 8 + dx] = tile
                copies[top + dy * 8 + dx] = passages
    snow["forest"] = (solid, halo)
    first += 2 * FOREST_SIZE * 8
    # Snowy cliffs (levels, massifs) and the cave mouth
    snow["cliffs"] = []
    for col, row in SNOW_CLIFFS:
        for dy in range(CLIFF_ROWS):
            for dx in range(8):
                tile = sheet_tile(sheets, ("N", col, dx, row + dy))
                copies[first + dy * 8 + dx] = cliff_passages(dy, dx, tile)
                if (dx, dy) in SNOW_HIDDEN_RIMS:
                    tile = Image.new("RGBA", (TILE, TILE))
                tiles[first + dy * 8 + dx] = tile
        snow["cliffs"].append(first)
        first += CLIFF_ROWS * 8
    col, row = SNOW_CAVE
    for i, src in enumerate(CAVE_PASSAGES):
        dest = first + (i // 3) * 8 + i % 3
        tiles[dest] = sheet_tile(sheets, ("N", col, 1 + i % 3, row + i // 3))
        copies[dest] = src
    snow["cave"] = first
    snow["end"] = first + 3 * 8
    return snow


def cliff_line(first):
    """The roles of a cliff block (MapGen [Terrains], see 003_Builder.rb):
    the inside, then the edges, the inner corners and the rims above."""
    def t(dx, dy):
        return f"T{first + dy * 8 + dx}"
    return (f"inside={t(1, 2)} W={t(0, 2)} E={t(3, 2)} NW={t(0, 1)} NE={t(3, 1)} SW={t(0, 3)} S={t(1, 3)} "
            f"SE={t(3, 3)} iSE={t(0, 4)} iSW={t(1, 4)} iNW={t(3, 4)} iNE={t(2, 4)} oN={t(1, 0)} oNW={t(0, 0)} oNE={t(3, 0)} "
            f"oiNW={t(5, 4)} oiNE={t(6, 4)}")


def object_line(sym, first, empty):
    _old, width, height, drawing, bx, by = TREES[sym]
    text = f"{sym} = T{first + by * 8 + bx} {width}x{height}"
    if len(drawing[0]) != width or len(drawing) != height:
        text += f" halo={len(drawing[0])}x{len(drawing)}@{bx},{by}"
        if empty:
            text += "/" + ",".join(str(k) for k in empty)
    return text


def main():
    # No tile is ever cut: a building that its frame cuts stops the build
    sheet = Image.open(f"{sys.argv[1]}/{SHEETS['B']}").convert("RGBA")
    if (cut := cut_drawings(sheet)):
        sys.exit("\n".join(f"{sym} : dessin coupé par son cadre ({l} px à gauche, {t} au-dessus, {r} à droite, {b} dessous)" for sym, l, t, r, b in cut))
    out, placed, forests, copies, count, (cliffs, caves, ledge, blocker, buildings, gyms, props, legend, streets, more, snow) = build(sys.argv[1])
    out.save(TARGET)
    subprocess.run(["ruby", "tools/art/tileset_tables.rb", str(TILESET_ID), str(count),
                    json.dumps({str(k): v for k, v in copies.items()})], check=True)
    print(f"{TARGET} : {len(TILES) + len(CLEARED) + 2 * len(GRASS_VARIANTS)} tuiles remplacées, "
          f"{len(placed)} arbres et {len(forests)} forêts ajoutés")
    for ground_id, solid, halo in forests:
        print(f"[{GROUND_NAMES[ground_id]}] {FOREST[0]} = T{solid} 2x2 forest=T{halo}")
    for ground_id, sym, first, empty in placed:
        print(f"[{GROUND_NAMES[ground_id]}] {object_line(sym, first, empty)}")
    for ground_id, col, row, first in cliffs:
        top = "roche" if row == 0 else "herbe"
        print(f"[{GROUND_NAMES[ground_id]}] falaise ({top}, {'grise' if col == 6 else 'brune'}) : {cliff_line(first)}")
    for first in caves:
        print("grotte : " + " ".join(f"{i + 1} = T{first + (i // 3) * 8 + i % 3}" for i in range(9)))
    for sym, first, empty in buildings:
        _col, _x, _y, w, h, bx, by, bw, bh, dx, dy = BUILDINGS[sym]
        line = f"{sym} = T{first + by * 8 + bx} {bw}x{bh} halo={w}x{h}@{bx},{by}"
        print(f"bâtiment : {line}{'/' + ','.join(map(str, empty)) if empty else ''}   (porte {dx},{dy})")
    w, h = GYM_SIZE
    bx, by, bw, bh = GYM_BLOCK
    for style, (sym, _columns) in GYMS.items():
        first, empty = gyms[style]["NORMAL"]
        print(f"arène ({style}) : {sym} = T{first + by * 8 + bx} {bw}x{bh} halo={w}x{h}@{bx},{by}"
              f"{'/' + ','.join(map(str, empty)) if empty else ''}   (porte {GYM_DOOR[0]},{GYM_DOOR[1]})")
        print(f"  {style}: {{ " + ", ".join(f"{t}: {f}" for t, (f, _e) in gyms[style].items()) + " }")
    for sym, ids in legend.items():
        print(f"objet : {sym} = {{sol}} " + "|".join(f"T{i}" for i in ids))
    for sym, first, empty in props:
        _sheet, _col, _x, _y, w, h, bx, by, bw, bh, _kind = PROPS[sym]
        line = f"{sym} = T{first + by * 8 + bx} {bw}x{bh}"
        if (w, h) != (bw, bh):
            line += f" halo={w}x{h}@{bx},{by}" + ("/" + ",".join(map(str, empty)) if empty else "")
        print(f"objet : {line}")
    for name, ids in streets.items():
        roles = " ".join(f"{role}=T{i}" if role else f"T{i}" for (role, *_r), i in zip(STREET_ROLES, ids))
        print(f"rue ({name}) : Rue = {roles}")
    for sym, first, empty, (w, h), (bx, by, bw, bh) in more:
        line = f"{sym} = T{first + by * 8 + bx} {bw}x{bh}"
        if (w, h) != (bw, bh):
            line += f" halo={w}x{h}@{bx},{by}" + ("/" + ",".join(map(str, empty)) if empty else "")
        door = MORE_BUILDINGS.get(sym, (None, None, None))[2]
        print(f"bâtiment : {line}" + (f"   (porte {door[0] - bx},{door[1] - by})" if door else ""))
    print(f"corniche : < = T{ledge} - = T{ledge + 1} > = T{ledge + 2} ; bord nord sous le rebord : T{blocker}")
    print_snow(snow)
    print(f"Bords des hautes herbes : haut T{snow['edges'][0]}, bas T{snow['edges'][1]}, seule T{snow['edges'][2]}, "
          f"herbes très hautes sous leur rangée du haut T{snow['edges'][3]}")
    for name, ids in snow["marsh"].items():
        roles = MARSH_GRASS_ROLES if name == "herbe" else STREET_ROLES
        print(f"[marais] {name} = " + " ".join(f"{role}=T{i}" if role else f"T{i}" for (role, *_r), i in zip(roles, ids)))
    print_volcano(snow["volcano"])
    print_farm(snow["farm"])


# Marsh (#205): SirMalo's patches of the Nature sheet, column 1: mud
# (blocked), marsh water (shallow: walked, Puddle terrain tag) as full patch
# + patch with a hole (like STREETS: full patch x, y, middle x, y, hole x,
# y); marsh grass (tall grass, its own edges) as a 3x3 block, middle in it.
PUDDLE_TAG = 16   # Essentials' Puddle (splashes, reflections)
MARSH_PATCHES = {"boue": ((0, 34, 1, 35, 4, 34), "=15"), "eau": ((0, 43, 1, 44, 4, 43), f"=0/{PUDDLE_TAG}")}
MARSH_GRASS = (2, 47)   # top left of its 3x3 block
MARSH_GRASS_ROLES = [("", 1, 1), ("N", 1, 0), ("S", 1, 2), ("W", 0, 1), ("E", 2, 1),
                     ("NW", 0, 0), ("NE", 2, 0), ("SW", 0, 2), ("SE", 2, 2)]


def build_marsh(sheets, tiles, copies, first, grass):
    """The marsh tiles from `first` (16 per patch, then the marsh grass),
    over the grass. Returns name => [tile of each role] (STREET_ROLES, or
    MARSH_GRASS_ROLES for "herbe")."""
    marsh = {}
    for name, ((ox, oy, cx, cy, hx, hy), passages) in MARSH_PATCHES.items():
        marsh[name] = []
        for i, (_role, dx, dy, part) in enumerate(STREET_ROLES):
            src = (cx, cy) if part is None else (ox + dx, oy + dy) if part == "o" else (hx + dx, hy + dy)
            tile = Image.new("RGBA", (TILE, TILE))
            tile.paste(grass)
            tile.alpha_composite(sheet_tile(sheets, ("N", 1) + src))
            tiles[first + i] = tile
            copies[first + i] = passages
            marsh[name].append(first + i)
        first += 16
    marsh["herbe"] = []
    gx, gy = MARSH_GRASS
    for i, (_role, dx, dy) in enumerate(MARSH_GRASS_ROLES):
        tile = Image.new("RGBA", (TILE, TILE))
        tile.paste(grass)
        tile.alpha_composite(sheet_tile(sheets, ("N", 1, gx + dx, gy + dy)))
        tiles[first + i] = tile
        copies[first + i] = "=64/2"
        marsh["herbe"].append(first + i)
    return marsh


def build_grass_edges(sheets, tiles, copies, first):
    """The edges of a patch of tall grass, see-through over any ground (one
    row of 8 from `first`): its top row (the blades' tips, from the sheet's
    row above the patch), its bottom row (their foot, the ground below it
    see-through, its shade a darker veil) and a lone row (tips, then foot).
    Tall grass (terrain tag 2, a bush), like T6; then the very tall grass
    below its top row. Returns [top, bottom, lone, very tall middle]."""
    top = patch_grass(sheet_tile(sheets, TILES[7]))
    foot = dark_gaps(sheet_tile(sheets, TILES[15]), TILE // 2)
    px = foot.load()
    for y in range(TILE // 2, TILE):
        for x in range(TILE):
            c = px[x, y]
            if c[3] and c[2] > c[0] + 20:
                px[x, y] = (0, 0, 0, 0) if c in GRASS else (0, 0, 0, int(255 * (1 - SHADOWS.get(c, 0.8)) * 1.5))
    lone = Image.new("RGBA", (TILE, TILE))
    lone.paste(top.crop((0, 4, TILE, 4 + TILE // 2)), (0, 0))
    lone.paste(foot.crop((0, 0, TILE, TILE // 2)), (0, TILE // 2))
    for i, tile in enumerate([top, foot, lone]):
        tiles[first + i] = tile
        copies[first + i] = "=64/2"
    # The very tall grass below its top row: the middle of a patch, drawn
    # over the player like its top (T7: its passages, priority and tag)
    tiles[first + 3] = patch_grass(sheet_tile(sheets, TILES[6]))
    copies[first + 3] = 7
    return [first, first + 1, first + 2, first + 3]


# Volcano (#206): no 4G drawing of ash or lava, SirMalo's tiles recoloured.
# Ash ground: the grass greyed (a hint of green left); tall grass dusted with
# ash; black ground: the dirt path's patch in basalt (walked: the street and
# the patches of the bricks); lava: the marsh mud's patch glowing (blocked);
# lava rocks: the desert's rocks in basalt, their cracks glowing. Trees,
# forest, cliffs (brown rock) and the cave on the ash.
ASH_GROUND = 0.85    # share of ash in the ground (the rest stays grass)
ASH_BLADES = 0.55    # share of ash on the blades of tall grass
LAVA_RAMP = [(96, 16, 8), (176, 40, 8), (232, 96, 16), (255, 176, 48), (255, 232, 120)]
BLACK_PATH = [106, 98, 114, 105, 107, 97, 99, 113, 115, 118, 116, 102, 100]   # STREET_ROLES order


def luma(c):
    return 0.3 * c[0] + 0.59 * c[1] + 0.11 * c[2]


def greenish(c):
    return c[1] > c[0] + 15 and c[1] >= c[2]


def recolour(tile, fn, keep=()):
    """The tile with each opaque colour (but those of `keep`) through fn."""
    tile = tile.copy()
    tile.putdata([fn(c) if c[3] and c not in keep else c for c in tile.get_flattened_data()])
    return tile


def ash(c, share):
    """A colour under ash: blended towards a warm grey of its brightness."""
    lum = luma(c)
    grey = (lum * 0.80, lum * 0.78, lum * 0.75)
    return tuple(int(v * (1 - share) + g * share) for v, g in zip(c[:3], grey)) + (c[3],)


def basalt(c):
    lum = luma(c)
    return (int(lum * 0.30 + 16), int(lum * 0.28 + 16), int(lum * 0.28 + 20), c[3])


def lava(c):
    t = max(0.0, min(0.999, (luma(c) - 60) / 120)) * (len(LAVA_RAMP) - 1)
    a, b = LAVA_RAMP[int(t)], LAVA_RAMP[int(t) + 1]
    k = t - int(t)
    return tuple(int(x + (y - x) * k) for x, y in zip(a, b)) + (c[3],)


def glowing_rock(tile):
    """A rock in basalt, its outline's colour inside it (its cracks, away
    from the edge) glowing."""
    px = tile.load()
    darkest = min((c for c in tile.get_flattened_data() if c[3]), key=luma)
    out = recolour(tile, basalt)
    po = out.load()
    for y in range(2, TILE - 2):
        for x in range(2, TILE - 2):
            near = [px[x + dx, y + dy][3] for dx in (-2, 0, 2) for dy in (-2, 0, 2)]
            if px[x, y] == darkest and all(near):
                po[x, y] = (232, 88, 16, 255)
    return out


def build_volcano(sheets, tiles, copies, first, edges):
    """The tiles of the volcano ambiance from `first`. Returns their numbers
    by role, and "end" (the next free tile)."""
    v = {}
    grounds = [recolour(tiles[i], lambda c: ash(c, ASH_GROUND)) for i in (1, 2, 3)]
    ground = grounds[0]
    def dusted(tile):
        return recolour(tile, lambda c: ash(c, ASH_BLADES), keep=GRASS | set(SHADOWS))
    # Row 1: ash ground (3), tall grass, the very tall grass's foot and top,
    # the edges of a patch (top, bottom); row 2: lone row, very tall middle,
    # bush, lava rock, lava pebbles
    row = grounds + [recolour(patch_grass(tiles[6]), lambda c: ash(c, ASH_BLADES)),
                     on_ground(dusted(dark_gaps(tiles[15], TILE // 2)), ground, True),
                     dusted(tiles[7]), dusted(tiles[edges[0]]), dusted(tiles[edges[1]]),
                     dusted(tiles[edges[2]]), dusted(tiles[edges[3]]),
                     dusted(on_ground(sheet_tile(sheets, TILES[475]), ground)),
                     glowing_rock(unground(sheet_tile(sheets, TILES[847]))),
                     glowing_rock(unground(sheet_tile(sheets, TILES[839])))]
    passages = [-1, -1, -1, 6, 15, 7, "=64/2", "=64/2", "=64/2", 7, 475, 847, 839]
    for i, (tile, p) in enumerate(zip(row, passages)):
        tiles[first + i] = tile
        copies[first + i] = p
    v["ground"] = [first, first + 1, first + 2]
    v["grass"] = [first + i for i in range(3, 10)]   # " ; : ˈ ˌ ˑ ˸
    v["bush"], v["rock"], v["pebbles"] = first + 10, first + 11, first + 12
    first += 16
    # Black ground (the path's patch) and lava (the mud's patch), on the ash
    def patch(drawing, fn, p, first):
        tile = ground.copy()
        tile.alpha_composite(recolour(drawing, lambda c: ash(c, ASH_GROUND) if greenish(c) else fn(c)))
        tiles[first] = tile
        copies[first] = p
    v["black"] = []
    for i, src in enumerate(BLACK_PATH):
        patch(sheet_tile(sheets, TILES[src]), basalt, -1, first + i)
        v["black"].append(first + i)
    first += 16
    (ox, oy, cx, cy, hx, hy), _p = MARSH_PATCHES["boue"]
    v["lava"] = []
    for i, (_role, dx, dy, part) in enumerate(STREET_ROLES):
        src = (cx, cy) if part is None else (ox + dx, oy + dy) if part == "o" else (hx + dx, hy + dy)
        patch(sheet_tile(sheets, ("N", 1) + src), lava, "=15", first + i)
        v["lava"].append(first + i)
    first += 16
    # Trees on the ash (their leaves dusted), in slots of 4x4 tiles, two per row of slots
    v["trees"] = []
    for slot, sym in enumerate(VARIED):
        old_first, width, height, drawing, bx, by = TREES[sym]
        top = first + (slot // 2) * 4 * 8 + (slot % 2) * 4
        for dy, line in enumerate(drawing):
            for dx, src in enumerate(line):
                tile = sheet_tile(sheets, src) if src else Image.new("RGBA", (TILE, TILE))
                tiles[top + dy * 8 + dx] = on_ground(dusted(tile), ground)
                inside = bx <= dx < bx + width and by <= dy < by + height
                copies[top + dy * 8 + dx] = old_first + (dy - by) * 8 + (dx - bx) if inside else TALL
        empty = [dy * len(line) + dx for dy, line in enumerate(drawing) for dx in range(len(line))
                 if not (bx <= dx < bx + width and by <= dy < by + height)
                 and not tiles[top + dy * 8 + dx].getbbox()]
        v["trees"].append((sym, top, empty))
    first += ((len(VARIED) + 1) // 2) * 4 * 8
    # The forest: blocked, then with a halo's passages
    _sym, col, frow = FOREST
    solid, halo = first, first + FOREST_SIZE * 8
    for dy in range(FOREST_SIZE):
        for dx in range(FOREST_SIZE):
            tile = on_ground(dusted(sheet_tile(sheets, ("N", col, dx, frow + dy))), ground)
            for top, p in ((solid, SOLID), (halo, TALL)):
                tiles[top + dy * 8 + dx] = tile
                copies[top + dy * 8 + dx] = p
    v["forest"] = (solid, halo)
    first += 2 * FOREST_SIZE * 8
    # Cliffs on the ash (levels: grass top; massifs: rock top) and the cave
    v["cliffs"] = []
    for col, crow in ((5, 20), (5, 0)):
        for dy in range(CLIFF_ROWS):
            for dx in range(8):
                tile = on_ground(sheet_tile(sheets, ("N", col, dx, crow + dy)), ground, cliff=True)
                tiles[first + dy * 8 + dx] = tile
                copies[first + dy * 8 + dx] = cliff_passages(dy, dx, tile)
        v["cliffs"].append(first)
        first += CLIFF_ROWS * 8
    col, crow = CAVES[0]
    for i, src in enumerate(CAVE_PASSAGES):
        dest = first + (i // 3) * 8 + i % 3
        tiles[dest] = on_ground(sheet_tile(sheets, ("N", col, 1 + i % 3, crow + i // 3)), ground, cliff=True)
        copies[dest] = src
    v["cave"] = first
    v["end"] = first + 3 * 8
    return v


# The farm of the Breeders' HQ (#212): drawing (sheet, column, x, y, width,
# height), block x, y, width, height in it, passages (see PROPS). A
# vegetable patch (SirMalo's crops), a wooden fence, a trough.
FARM = {
    "potager": (("N", 1, 2, 47, 3, 3), (0, 0, 3, 3), "block"),
    "barriere": (("U", 3, 0, 11, 3, 2), (0, 1, 3, 1), "tall"),
    "abreuvoir": (("N", 3, 0, 10, 2, 1), (0, 0, 2, 1), "block"),
}


def build_farm(sheets, tiles, copies, first):
    """The farm's objects from `first`, one row of 8 per 3 rows of drawings
    side by side. Returns symbol => (first tile, size, block), and "end"."""
    farm = {}
    x = 0
    for name, ((sheet, col, sx, sy, w, h), (bx, by, bw, bh), kind) in FARM.items():
        for ty in range(h):
            for tx in range(w):
                dest = first + ty * 8 + x + tx
                tile = sheet_tile(sheets, (sheet, col, sx + tx, sy + ty))
                tile = unground(tile) if sheet == "N" else tile
                tiles[dest] = tile
                copies[dest] = prop_passages(tile, kind, tx, ty, bx, by, bw, bh)
        farm[name] = (first + x, (w, h), (bx, by, bw, bh))
        x += w
    farm["end"] = first + 3 * 8
    return farm


def print_farm(farm):
    """The palette lines of the farm (route.txt)."""
    for name in FARM:
        top, (w, h), (bx, by, bw, bh) = farm[name]
        line = f"T{top + by * 8 + bx} {bw}x{bh}"
        if (w, h) != (bw, bh):
            line += f" halo={w}x{h}@{bx},{by}"
        print(f"[ferme] {name} = {line}")


def print_volcano(v):
    """The palette lines of the volcano ambiance (route.txt, ville.txt)."""
    def roles(ids):
        return " ".join(f"{role}=T{i}" if role else f"T{i}" for (role, *_r), i in zip(STREET_ROLES, ids))
    tall, foot, top, e_top, e_bottom, e_lone, middle = v["grass"]
    print(f"[volcan] Sol = {'|'.join(f'T{t}' for t in [v['ground'][0]] * 3 + v['ground'][1:])}")
    print(f"[volcan] \" = T{tall}  ; = T{foot}  : = {{sol}} T{top}  ˈ ˌ ˑ = T{e_top} T{e_bottom} T{e_lone}  ˸ = T{middle}")
    print(f"[volcan] à = T{v['bush']}  roche de lave = T{v['rock']}  cailloux = T{v['pebbles']}")
    print(f"[volcan] sol noir : {roles(v['black'])}")
    print(f"[volcan] lave : {roles(v['lava'])}")
    for sym, top, empty in v["trees"]:
        print(f"[volcan] {object_line(sym, top, empty)}")
    print(f"[volcan] t = T{v['forest'][0]} 2x2 forest=T{v['forest'][1]}")
    for name, first in zip(("niveaux", "massifs"), v["cliffs"]):
        print(f"[volcan] falaise ({name}) : {cliff_line(first)}")
    cave = v["cave"]
    print(f"[volcan] grotte : " + " ".join(f"{k + 1} = T{cave + (k // 3) * 8 + k % 3}" for k in range(9)))


def print_snow(snow):
    """The palette lines of the snow ambiance (route.txt, ville.txt)."""
    tall, foot = snow["grass"]
    print(f"[neige] Sol = {'|'.join(f'T{t}' for t in [snow['ground'][0]] * 3 + snow['ground'][1:])}")
    print(f"[neige] \" = T{tall}   : = T{foot} T7   ; = T{foot}")
    print(f"[neige] neige profonde : {'|'.join(f'T{t}' for t in snow['deep'])} ; glace : {'|'.join(f'T{t}' for t in snow['ice'])}")
    for sym, top, (w, h), (bx, by, bw, bh), empty in snow["trees"]:
        line = f"{sym} = T{top + by * 8 + bx} {bw}x{bh}"
        if (w, h) != (bw, bh):
            line += f" halo={w}x{h}@{bx},{by}" + ("/" + ",".join(map(str, empty)) if empty else "")
        print(f"[neige] {line}")
    print(f"[neige] t = T{snow['forest'][0]} 2x2 forest=T{snow['forest'][1]}")
    for name, first in zip(("niveaux", "massifs"), snow["cliffs"]):
        print(f"[neige] falaise ({name}) : {cliff_line(first)}")
    cave = snow["cave"]
    print(f"[neige] grotte : " + " ".join(f"{k + 1} = T{cave + (k // 3) * 8 + k % 3}" for k in range(9)))


if __name__ == "__main__":
    main()
