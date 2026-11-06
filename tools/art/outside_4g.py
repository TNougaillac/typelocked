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
SHEETS = {"N": "NatureRMXP.png"}
PINK = (240, 91, 161, 255)
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


def box(tile):
    return ((tile % 8) * TILE, (tile // 8) * TILE, (tile % 8) * TILE + TILE, (tile // 8) * TILE + TILE)


def sheet_tile(sheets, src):
    """One 16 px tile of a sheet, scaled x2, its pink and unused colours
    see-through."""
    sheet, col, tx, ty = src
    left = 16 + 144 * col
    im = sheets[sheet].crop((left + tx * 16, ty * 16, left + tx * 16 + 16, ty * 16 + 16))
    im.putdata([(0, 0, 0, 0) if c == PINK or c in UNUSED else c for c in im.getdata()])
    return im.resize((TILE, TILE), Image.NEAREST)


def on_ground(tile, ground, opaque=False):
    """A tile on another ground: its grass see-through (or the ground), its
    shadows the darkened ground."""
    tile = tile.copy()
    px, g = tile.load(), ground.load()
    for y in range(TILE):
        for x in range(TILE):
            c = px[x, y]
            if c in GRASS:
                px[x, y] = g[x, y] if opaque else (0, 0, 0, 0)
            elif c in SHADOWS:
                k = SHADOWS[c]
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
    count = forest_first - first_new + len(GROUNDS) * 2 * FOREST_SIZE * 8
    out = Image.new("RGBA", (old.width, old.height + (count // 8) * TILE), (0, 0, 0, 0))
    out.paste(old, (0, 0))
    for dest, tile in tiles.items():
        out.paste((0, 0, 0, 0), box(dest))
        out.paste(tile, box(dest)[:2])
    return out, placed, forests, copies, count


def object_line(sym, first, empty):
    _old, width, height, drawing, bx, by = TREES[sym]
    text = f"{sym} = T{first + by * 8 + bx} {width}x{height}"
    if len(drawing[0]) != width or len(drawing) != height:
        text += f" halo={len(drawing[0])}x{len(drawing)}@{bx},{by}"
        if empty:
            text += "/" + ",".join(str(k) for k in empty)
    return text


def main():
    out, placed, forests, copies, count = build(sys.argv[1])
    out.save(TARGET)
    subprocess.run(["ruby", "tools/art/tileset_tables.rb", str(TILESET_ID), str(count),
                    json.dumps({str(k): v for k, v in copies.items()})], check=True)
    print(f"{TARGET} : {len(TILES) + len(CLEARED) + 2 * len(GRASS_VARIANTS)} tuiles remplacées, "
          f"{len(placed)} arbres et {len(forests)} forêts ajoutés")
    for ground_id, solid, halo in forests:
        print(f"[{GROUND_NAMES[ground_id]}] {FOREST[0]} = T{solid} 2x2 forest=T{halo}")
    for ground_id, sym, first, empty in placed:
        print(f"[{GROUND_NAMES[ground_id]}] {object_line(sym, first, empty)}")


if __name__ == "__main__":
    main()
