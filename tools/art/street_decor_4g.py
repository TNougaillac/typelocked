"""Adds street and market decor to the Outside 4G tileset (TypeLocked, issue
#320): the street furniture of SirMalo's UrbanRMXP.png (column F: windmill,
logs, rocks, signs, bell, table, market stall, vending machines,
statue). The bird bath, the bike rack and the festival gates (Buildings L7,
L8) go on past their column of the sheet: left out.

Each drawing is cut out whole by its pixels: every drawn pixel inside its
rectangle and every pixel joined to them (drawn pixels that touch). A
drawing that goes on beyond its rectangle stops the script (it would be cut).
It is laid at the foot of a frame of 32 px tiles, centred, blocked at its
foot, its top drawn over the player (halo).

Source (docs/CREDITS.md), not in the repository: SirMalo's UrbanRMXP.png.
Run once from the repository root, after tools/art/snow_cliffs_4g.py (Pillow
and numpy needed):
    python3 tools/art/street_decor_4g.py "<SirMalo folder>"
Prints the MapGen lines of what it adds.
"""
import json
import math
import subprocess
import sys
import numpy as np
from PIL import Image

sys.path.insert(0, "tools/art")
from outside_4g import SHEETS, MAGENTA, PINK, UNUSED, box  # noqa: E402

TARGET = "Graphics/Tilesets/Outside 4G.png"
TILESET_ID = 24
TILE = 32
TALL = 420   # passages of a halo tile: walkable, drawn over the player
SOLID = 428  # passages of a blocked tile
# name => (symbol, sheet, column, rectangle x0, y0, x1, y1 in 16 px tiles of
# the column, blocked rows at the foot)
DRAWINGS = {
    "éolienne": ("Ґ", "U", 5, (0.6, 1.4, 3.75, 7.0), 1),
    "bûches": ("ґ", "U", 5, (1.3, 7.7, 2.8, 9.2), 1),
    "tas de rochers": ("Ғ", "U", 5, (5.9, 7.2, 8.0, 9.3), 1),
    "panneau Pokémon": ("ғ", "U", 5, (1.8, 10.3, 3.5, 13.1), 1),
    "cloche": ("Ҕ", "U", 5, (4.75, 10.0, 7.25, 12.45), 1),
    "table": ("Җ", "U", 5, (1.05, 17.05, 3.2, 18.5), 1),
    "panneau d'affichage": ("җ", "U", 5, (3.9, 17.4, 5.05, 19.05), 1),
    "étal bleu": ("Ҙ", "U", 5, (0.95, 19.05, 4.6, 22.5), 2),
    "distributeurs": ("ҙ", "U", 5, (4.95, 19.95, 8.0, 22.05), 1),
    "statue à la sphère": ("қ", "U", 5, (1.25, 30.3, 2.95, 33.25), 1),
}


def extract(sheet, kind, col, rect, name):
    """The drawing in the rectangle, cut out on a clear image, scaled x2."""
    left = 16 + 144 * col
    a = np.asarray(sheet).astype(int)
    rgb = a[:, :, :3]
    clear = [MAGENTA, (255, 245, 104)] if kind == "B" else [PINK] + list(UNUSED)
    full = ~(np.any([(rgb == c[:3]).all(2) for c in clear], axis=0) | (a[:, :, 3] == 0))
    x0, y0, x1, y1 = (round(v * 16) for v in rect)
    seen = np.zeros(full.shape, bool)
    seen[y0:y1, left + x0:left + x1] = full[y0:y1, left + x0:left + x1]
    stack = list(zip(*np.nonzero(seen)))
    while stack:
        y, x = stack.pop()
        for ny, nx in ((y + 1, x), (y - 1, x), (y, x + 1), (y, x - 1)):
            if full[ny, nx] and not seen[ny, nx]:
                seen[ny, nx] = True
                stack.append((ny, nx))
    ys, xs = np.nonzero(seen)
    if ys.min() < y0 or ys.max() >= y1 or xs.min() < left + x0 or xs.max() >= left + x1:
        sys.exit(f"{name} : le dessin dépasse de son rectangle")
    out = np.zeros(a.shape, np.uint8)
    out[seen] = a[seen]
    cut = Image.fromarray(out).crop((xs.min(), ys.min(), xs.max() + 1, ys.max() + 1))
    return cut.resize((cut.width * 2, cut.height * 2), Image.NEAREST)


def main():
    sheets = {k: Image.open(f"{sys.argv[1]}/{name}").convert("RGBA") for k, name in SHEETS.items()}
    target = Image.open(TARGET).convert("RGBA")
    first = target.height // TILE * 8
    tiles, tables, lines = {}, {}, []
    at, x, row_h = first, 0, 0
    for name, (sym, kind, col, rect, foot) in DRAWINGS.items():
        cut = extract(sheets[kind], kind, col, rect, name)
        w, h = math.ceil(cut.width / TILE), math.ceil(cut.height / TILE)
        if w > 8:
            sys.exit(f"{name} : plus large que le tileset")
        frame = Image.new("RGBA", (w * TILE, h * TILE), (0, 0, 0, 0))
        frame.paste(cut, ((w * TILE - cut.width) // 2, h * TILE - cut.height))
        foot = min(foot, h)
        by = h - foot
        if x + w > 8:
            at, x, row_h = at + 8 * row_h, 0, 0
        row_h = max(row_h, h)
        base, empty = at + x, []
        for dy in range(h):
            for dx in range(w):
                tile = frame.crop((dx * TILE, dy * TILE, dx * TILE + TILE, dy * TILE + TILE))
                tiles[base + dy * 8 + dx] = tile
                tables[str(base + dy * 8 + dx)] = SOLID if dy >= by else TALL
                if dy < by and not tile.getbbox():
                    empty.append(dy * w + dx)
        line = f"{sym} = T{base + by * 8} {w}x{foot}"
        if foot != h:
            line += f" halo={w}x{h}@0,{by}" + ("/" + ",".join(map(str, empty)) if empty else "")
        lines.append(f"{line}   # {name}")
        x += w
    at += 8 * row_h
    rows = (at - first) // 8
    out = Image.new("RGBA", (target.width, target.height + rows * TILE), (0, 0, 0, 0))
    out.paste(target, (0, 0))
    for t, tile in tiles.items():
        out.paste(tile, box(t)[:2])
    out.save(TARGET)
    for t in range(first, at):
        tables.setdefault(str(t), -1)
    subprocess.run(["ruby", "tools/art/tileset_tables.rb", str(TILESET_ID), str(rows * 8), json.dumps(tables)], check=True)
    print("\n".join(lines))


if __name__ == "__main__":
    main()
