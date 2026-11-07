"""Outside 4G tileset (TypeLocked, issue #177).

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
SHEETS = {"N": "NatureRMXP.png", "B": "BuildingsRMXP.png"}
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
    # Sand ground (sand ambiance, desert): the pale sand
    162: ("N", 0, 1, 17),
    # Tall grass (the middle of a patch: it joins its neighbours); very tall
    # grass: its foot, and its top drawn over it
    6: ("N", 3, 0, 8), 15: ("N", 3, 0, 9), 7: ("N", 3, 0, 7),
    # Bush (legend symbol à, over the ground) and its copies for the grounds
    475: ("N", 3, 3, 27), 4045: ("N", 3, 3, 27), 4085: ("N", 3, 3, 27),
    4125: ("N", 3, 3, 27), 4165: ("N", 3, 3, 27),
}
SEE_THROUGH = {7, 475, 4045, 4085, 4125, 4165}
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
}
SHADOW = (2, 3, 31, 76)   # the Buildings sheet's shadow
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


def building_passages(tile, inside, door):
    """Passages of a building tile ("=<n>" or a tile to copy, see
    tools/art/tileset_tables.rb)."""
    if inside:
        return "=0" if door else "=15"
    if all(c[3] == 0 or c == SHADOW for c in tile.get_flattened_data()):
        return "=0"
    return TALL


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


def build(folder):
    sheets = {k: Image.open(f"{folder}/{name}").convert("RGBA") for k, name in SHEETS.items()}
    old = Image.open(SOURCE).convert("RGBA")
    grass = sheet_tile(sheets, TILES[1])
    tiles = {}
    for dest, src in TILES.items():
        drawing = sheet_tile(sheets, src)
        if dest in MIRRORED:
            drawing = drawing.transpose(Image.FLIP_LEFT_RIGHT)
        tile = Image.new("RGBA", (TILE, TILE))
        if dest not in SEE_THROUGH:
            tile.paste(grass)
        tile.alpha_composite(drawing)
        tiles[dest] = tile
    for dest in CLEARED:
        tiles[dest] = Image.new("RGBA", (TILE, TILE))
    for ground_id, (tall, foot) in GRASS_VARIANTS.items():
        ground = tiles[ground_id] if ground_id in tiles else old.crop(box(ground_id))
        tiles[tall] = on_ground(tiles[6], ground, True)
        tiles[foot] = on_ground(tiles[15], ground, True)
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
    for sym, (col, x, y, w, h, bx, by, bw, bh, dx, dy) in BUILDINGS.items():
        empty = []
        for ty in range(h):
            for tx in range(w):
                dest = first + ty * 8 + tx
                tile = sheet_tile(sheets, ("B", col, x + tx, y + ty))
                inside = bx <= tx < bx + bw and by <= ty < by + bh
                tiles[dest] = tile
                copies[dest] = building_passages(tile, inside, (tx, ty) == (bx + dx, by + dy))
                if not inside and not tile.getbbox():
                    empty.append(ty * w + tx)
        buildings.append((sym, first, empty))
        first += h * 8
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
    count = first - first_new
    out = Image.new("RGBA", (old.width, old.height + (count // 8) * TILE), (0, 0, 0, 0))
    out.paste(old, (0, 0))
    for dest, tile in tiles.items():
        out.paste((0, 0, 0, 0), box(dest))
        out.paste(tile, box(dest)[:2])
    return out, placed, forests, copies, count, (cliffs, caves, extra, blocker, buildings, gyms)


def cliff_line(first):
    """The roles of a cliff block (MapGen [Terrains], see 003_Builder.rb):
    the inside, then the edges, the inner corners and the rims above."""
    def t(dx, dy):
        return f"T{first + dy * 8 + dx}"
    return (f"inside={t(1, 2)} W={t(0, 2)} E={t(3, 2)} NW={t(0, 1)} NE={t(3, 1)} SW={t(0, 3)} S={t(1, 3)} "
            f"SE={t(3, 3)} iSE={t(0, 4)} iSW={t(1, 4)} oN={t(1, 0)} oNW={t(0, 0)} oNE={t(3, 0)} "
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
    out, placed, forests, copies, count, (cliffs, caves, ledge, blocker, buildings, gyms) = build(sys.argv[1])
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
    print(f"corniche : < = T{ledge} - = T{ledge + 1} > = T{ledge + 2} ; bord nord sous le rebord : T{blocker}")


if __name__ == "__main__":
    main()
