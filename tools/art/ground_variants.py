"""Ground variants of the Outside tileset (TypeLocked, MapProc ambiances).

The tiles of Essentials' Outside tileset are drawn for the plain grass: grass
background (112,200,160) and teal grass shadows (64,176,136), (24,160,104).
On another ground (meadow, sand, dirt, gravel) they show as green squares or
green rings. This script appends, below the tileset, a copy of each object
redrawn on each ground (background -> ground, shadows -> darkened ground),
and gives the new tiles the passages, priorities and terrain tags of their
source in Data/Tilesets.rxdata (via tools/art/tileset_tables.rb).

Run once from the repository root (Pillow needed):
    python3 tools/art/ground_variants.py
It prints the new tile number of each object, used by the [Ambiance] sections
of MapProc/route.txt and MapProc/ville.txt. Running it again appends again:
restore the two files from git first.
"""
import json
import subprocess
from PIL import Image

TILESET = "Graphics/Tilesets/Outside.png"
GRASS = (112, 200, 160, 255)
SHADOWS = {(64, 176, 136, 255): 0.85, (24, 160, 104, 255): 0.7}
GROUNDS = {"prairie": 50, "sable": 162, "terre battue": 106, "minérale": 218}
# Blocks of 8 tiles wide, each placed at (column, row) in its group:
# group A (3 rows): tree, tall pine, round tree; group B (2 rows): square
# hedge, hedge, bush, flowers, bank under the water.
OBJECTS = [
    ("t", 420, 2, 3, "A", 0, 0),
    ("é", 440, 3, 3, "A", 2, 0),
    ("è", 491, 3, 3, "A", 5, 0),
    ("î", 669, 2, 2, "B", 0, 0),
    ("û", 685, 3, 1, "B", 2, 0),
    ("à", 475, 1, 1, "B", 5, 0),
    ("!", 849, 1, 1, "B", 7, 0),
]
# After the street: cypress and shrub, 2 columns per ground (3 rows)
EXTRA = [("ê", 470, 1, 3, 0), ("ë", 502, 1, 2, 1)]
# Prairie only: the street (its edges show grass) and the flowers (first frame
# of the Flowers1 autotile, which can't be redrawn: the 7 slots are taken)
STREET = [274, 266, 282, 273, 275, 265, 267, 281, 283, 286, 284, 270, 268]
FLOWERS = "Graphics/Autotiles/Flowers1.png"


def box(i):
    return ((i % 8) * 32, (i // 8) * 32, (i % 8) * 32 + 32, (i // 8) * 32 + 32)


def redraw(tile, ground):
    tile = tile.copy()
    px, g = tile.load(), ground.load()
    for y in range(32):
        for x in range(32):
            c = px[x, y]
            if c == GRASS:
                px[x, y] = g[x, y]
            elif c in SHADOWS:
                k = SHADOWS[c]
                r, gg, b, _a = g[x, y]
                px[x, y] = (int(r * k), int(gg * k), int(b * k), 255)
    return tile


def main():
    im = Image.open(TILESET).convert("RGBA")
    first = (im.height // 32) * 8
    rows = 5 * len(GROUNDS) + 2 + 3
    out = Image.new("RGBA", (256, im.height + rows * 32), (0, 0, 0, 0))
    out.paste(im, (0, 0))
    copies = {}   # new tile => source tile (tables)
    result = {}
    row = im.height // 32
    for name, ground_id in GROUNDS.items():
        ground = im.crop(box(ground_id))
        result[name] = {}
        for sym, src, w, h, group, col, r0 in OBJECTS:
            top = row + (0 if group == "A" else 3) + r0
            result[name][sym] = (top * 8) + col
            for dy in range(h):
                for dx in range(w):
                    s = src + dy * 8 + dx
                    d = (top + dy) * 8 + col + dx
                    out.paste(redraw(im.crop(box(s)), ground), box(d)[:2])
                    copies[d] = s
        if name == "prairie":
            flowers = Image.open(FLOWERS).convert("RGBA").crop((0, 0, 32, 32))
            d = (row + 3) * 8 + 6
            out.paste(redraw(flowers, ground), box(d)[:2])
            copies[d] = -1   # passages of the autotile: walkable
            result[name]["*"] = d
        row += 5
    ground = im.crop(box(GROUNDS["prairie"]))
    result["prairie street"] = []
    for k, s in enumerate(STREET):
        d = row * 8 + k
        out.paste(redraw(im.crop(box(s)), ground), box(d)[:2])
        copies[d] = s
        result["prairie street"].append(d)
    row += 2   # 13 street tiles: two rows
    for k, (name, ground_id) in enumerate(GROUNDS.items()):
        ground = im.crop(box(ground_id))
        for sym, src, w, h, col in EXTRA:
            result[name][sym] = row * 8 + k * 2 + col
            for dy in range(h):
                s = src + dy * 8
                d = (row + dy) * 8 + k * 2 + col
                out.paste(redraw(im.crop(box(s)), ground), box(d)[:2])
                copies[d] = s
    out.save(TILESET)
    subprocess.run(["ruby", "tools/art/tileset_tables.rb", str(1), str(first + rows * 8 - first),
                    json.dumps({str(k): v for k, v in copies.items()})], check=True)
    print(json.dumps(result, ensure_ascii=False, indent=1))


if __name__ == "__main__":
    main()
