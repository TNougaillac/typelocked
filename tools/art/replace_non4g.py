"""Replaces the last non-4G tiles that MapProc draws (TypeLocked, issue #262).

Outside 4G was built from the old Outside tileset (tools/art/outside_4g.py):
142 of its tiles that MapProc still drew were left as they were (3G or
Essentials). See docs/art/inventaire-4g.md.
- Tiles in place (same T<n>, same passages): grounds, flowers, tall grass of
  the mountains, stairs, rocks, bushes, field, pier.
- Two grounds change (prairie T50, gravel T218): the tiles drawn on them
  (trees, cliffs, tall grass, see GROUNDS in outside_4g.py) took the old
  ground in their see-through places and shadows; those pixels take the new
  ground, by place, darkened the same.
- Drawings of another size, or bigger than their block, are added below the
  tileset, whole (hedges, rock wall, tropical
  tree, boat); the script prints their [Objects] lines.

Sources (docs/CREDITS.md), not in the repository: SirMalo's sheets
(NatureRMXP.png, UrbanRMXP.png, BuildingsRMXP.png) and the Remastered
Kanto Johto Map Pack (Graphics/Tilesets/Caves.png, Johtoshiptile.png).
Run once from the repository root (Pillow and numpy needed):
    python3 tools/art/replace_non4g.py "<SirMalo folder>" "<Remastered Tilesets folder>"
"""
import json
import subprocess
import sys
import numpy as np
from PIL import Image

sys.path.insert(0, "tools/art")
from outside_4g import SHEETS, box, sheet_tile  # noqa: E402

TARGET = "Graphics/Tilesets/Outside 4G.png"
TILESET_ID = 24
TILE = 32
TALL = 420   # passages of a halo tile (see outside_4g.py)
SOLID = 428  # passages of a tree tile
# Tiles of the Remastered pack (32 px): file => short name
REMASTERED = {"C": "Caves.png", "J": "Johtoshiptile.png"}

# In place: tile => SirMalo tile (sheet, column, x, y) or Remastered tile
# ("C"/"J", x, y) in 32 px tiles. A drawing on pink is laid on nothing.
TILES = {
    # Grounds: prairie (light grass), gravel of the mineral grounds
    50: ("N", 0, 0, 5), 218: ("N", 1, 4, 52),
    # Flowers of the prairie (opaque, on grass)
    4046: ("N", 0, 3, 0),
    # Stairs (none at SirMalo): the stone steps of the Remastered caves,
    # top and face of a 2 wide stair
    769: ("C", 6, 12), 770: ("C", 7, 12), 777: ("C", 6, 12), 778: ("C", 7, 12),
    # Pebble, rocks (over the ground)
    815: ("N", 3, 0, 27), 831: ("N", 3, 5, 34), 911: ("J", 0, 44),
    # Yellow bush, tropical bush (over the ground)
    523: ("N", 3, 6, 17), 606: ("N", 3, 1, 17),
    # Ploughed field (2x2): four patches of soil
    617: ("N", 3, 0, 10), 618: ("N", 3, 1, 10), 625: ("N", 3, 2, 10), 626: ("N", 3, 3, 10),
    # Wooden pier over the water and its south lip
    1205: ("U", 2, 4, 10), 1206: ("U", 2, 5, 10), 1207: ("U", 2, 6, 10),
    1213: ("U", 2, 4, 11), 1214: ("U", 2, 5, 11), 1215: ("U", 2, 6, 11),
    1221: ("U", 2, 4, 15), 1222: ("U", 2, 5, 15), 1223: ("U", 2, 6, 15),
}
# Tall grass on the mountains (over a level's ground, and on the grey rock
# top): the tall grass of the other grounds, its gaps dark (T133, outside_4g.py)
TALL_GRASS = 133
MOUNTAIN_GRASS = (147, 148)
# Grounds that change, and the share of a tile's pixels on the old ground
# that make it a tile drawn on it, among the tiles below LAST_ON_GROUND
# (the old tiles and the drawings of outside_4g.py on its grounds)
GROUNDS = (50, 218)
ON_GROUND = 24
LAST_ON_GROUND = 5800
SHADES = (1.0, 0.9, 0.8, 0.6)

# Drawings added below the tileset, whole: name => (tiles: rows of sources,
# block x, y, width, height in the drawing, passages of the block, symbol).
# The halo above the block is drawn over the player, a row below it (only
# shadow) under him.
DRAWINGS = {
    "haie carrée": ([[("N", 3, 0, 24), ("N", 3, 4, 24)], [("N", 3, 0, 25), ("N", 3, 4, 25)]], (0, 0, 2, 2), 669, "î"),
    "haie": ([[("N", 3, 0, 24), ("N", 3, 1, 24), ("N", 3, 4, 24)],
              [("N", 3, 0, 25), ("N", 3, 1, 25), ("N", 3, 4, 25)]], (0, 1, 3, 1), 685, "û"),
    "palmier": ([[("J", x, y) for x in (4, 5, 6)] for y in range(41, 46)], (0, 0, 3, 5), SOLID, "ç"),
    "voilier": ([[("B", 10, x, y) for x in range(6)] for y in range(71, 77)], (0, 3, 6, 3), 1097, "b"),
    "rocher": ([[("N", 3, x, y) for x in (2, 3, 4)] for y in (33, 34)], (0, 0, 3, 2), 784, "R"),
}


def load_tile(sheets, remastered, src):
    if src[0] in remastered:
        _, x, y = src
        return remastered[src[0]].crop((x * TILE, y * TILE, x * TILE + TILE, y * TILE + TILE))
    return sheet_tile(sheets, src)


def regrounded(old, new, ground_old, ground_new):
    """The tile with its pixels on the old ground (by place, plain or
    darkened by a shade of SHADES) on the new one; None if it has fewer
    than ON_GROUND of them."""
    out = old.copy()
    hits = np.zeros(old.shape[:2], bool)
    for k in SHADES:
        dark = (ground_old[:, :, :3] * k).astype(int) if k < 1 else ground_old[:, :, :3].astype(int)
        same = (old[:, :, :3].astype(int) == dark).all(axis=2) & (old[:, :, 3] == 255) & ~hits
        out[same, :3] = (ground_new[same, :3] * k).astype(np.uint8)
        hits |= same
    return out if hits.sum() >= ON_GROUND else None


def main():
    folder, remastered_folder = sys.argv[1], sys.argv[2]
    sheets = {k: Image.open(f"{folder}/{name}").convert("RGBA") for k, name in SHEETS.items()}
    remastered = {k: Image.open(f"{remastered_folder}/{name}").convert("RGBA") for k, name in REMASTERED.items()}
    sheet = Image.open(TARGET).convert("RGBA")
    grass = sheet.crop(box(1))
    # The grounds: their old and new looks
    olds = {g: np.asarray(sheet.crop(box(g))) for g in GROUNDS}
    for dest, src in TILES.items():
        drawing = load_tile(sheets, remastered, src)
        tile = Image.new("RGBA", (TILE, TILE))
        if dest in (50, 4046):
            tile.paste(grass)
        tile.alpha_composite(drawing)
        sheet.paste(tile, box(dest)[:2])
    for dest in MOUNTAIN_GRASS:
        sheet.paste(sheet.crop(box(TALL_GRASS)), box(dest)[:2])
    # Tiles drawn on a ground that changes
    pixels = np.array(sheet)
    regrounded_tiles = {}
    for g in GROUNDS:
        new = pixels[g // 8 * TILE:(g // 8 + 1) * TILE, g % 8 * TILE:(g % 8 + 1) * TILE].copy()
        for t in range(LAST_ON_GROUND):
            if t in GROUNDS or t in TILES or t in MOUNTAIN_GRASS:
                continue
            y, x = t // 8 * TILE, t % 8 * TILE
            done = regrounded(pixels[y:y + TILE, x:x + TILE], None, olds[g], new)
            if done is not None:
                pixels[y:y + TILE, x:x + TILE] = done
                regrounded_tiles.setdefault(g, []).append(t)
    sheet = Image.fromarray(pixels)
    # Drawings added below
    first = sheet.height // TILE * 8
    rows = sum(len(tiles) for tiles, *_ in DRAWINGS.values())
    out = Image.new("RGBA", (sheet.width, sheet.height + rows * TILE), (0, 0, 0, 0))
    out.paste(sheet, (0, 0))
    copies, lines, row0 = {}, [], 0
    for name, (tiles, (bx, by, bw, bh), passages, sym) in DRAWINGS.items():
        empty = []
        for dy, row in enumerate(tiles):
            for dx, src in enumerate(row):
                tile = load_tile(sheets, remastered, src)
                out.paste(tile, (dx * TILE, sheet.height + (row0 + dy) * TILE))
                inside = bx <= dx < bx + bw and by <= dy < by + bh
                if not inside and not tile.getbbox():
                    empty.append(dy * len(row) + dx)
                copies[str(first + (row0 + dy) * 8 + dx)] = passages if inside else -1 if dy >= by + bh else TALL
        w, h = len(tiles[0]), len(tiles)
        block = first + (row0 + by) * 8 + bx
        halo = "" if (w, h) == (bw, bh) else f" halo={w}x{h}@{bx},{by}" + (f"/{','.join(map(str, empty))}" if empty else "")
        lines.append(f"{sym} = T{block} {bw}x{bh}{halo}   # {name}")
        row0 += h
    out.save(TARGET)
    subprocess.run(["ruby", "tools/art/tileset_tables.rb", str(TILESET_ID), str(rows * 8), json.dumps(copies)], check=True)
    for g, tiles in regrounded_tiles.items():
        print(f"Sol T{g} : {len(tiles)} tuiles redessinées sur le nouveau sol ({tiles[0]} à {tiles[-1]})")
    print("\n".join(lines))


if __name__ == "__main__":
    main()
