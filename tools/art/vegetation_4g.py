"""Adds vegetation to the Outside 4G tileset (TypeLocked, issue #317):
- the flowers of the DPPt Exterior Ground Tiles: the four animated flower
  autotiles (blue, pink, purple, yellow) as extra autotiles T4 to T7 (left
  free by tools/art/extra_autotiles_4g.py, see EXTRA_AUTOTILES of the
  plugin), and the three still flowers; their DPPt grass made see-through
  (tools/art/streets_4g.py regreen), walked on;
- bushes, a flower pot, planters, hedges and rocks of SirMalo's
  NatureRMXP.png (column D), cut out whole by their pixels (DRAWINGS), and
  the berry soil of DPPt, whole in its frame (a pixel on the edge of the
  frame that goes on in the tile beyond it stops the script). Blocked at
  their foot, their top drawn over the player (halo).

Sources (docs/CREDITS.md), not in the repository: SirMalo's NatureRMXP.png and
the DPPt Exterior Ground Tiles (folder Platinum). Run once from the repository
root, after tools/art/streets_4g.py (Pillow and numpy needed):
    python3 tools/art/vegetation_4g.py "<SirMalo folder>" "<DPPt Platinum folder>"
Prints the MapGen lines of what it adds.
"""
import json
import math
import subprocess
import sys
import numpy as np
from PIL import Image

sys.path.insert(0, "tools/art")
from outside_4g import SHEETS, box  # noqa: E402
from streets_4g import SOURCE_GRASS, regreen  # noqa: E402

TARGET = "Graphics/Tilesets/Outside 4G.png"
AUTOTILES = "Graphics/Autotiles"
TILESET_ID = 24
TILE = 32
TALL = 420   # passages of a halo tile: walkable, drawn over the player
SOLID = 428  # passages of a blocked tile
# DPPt flower autotiles (4 frames of 32 px) => their name in Graphics/Autotiles,
# extra autotiles T4 to T7 in this order
FLOWERS = {"Flower (Blue - Autotile)": "DPPt Flowers Blue", "Flower (Pink - Autotile)": "DPPt Flowers Pink",
           "Flower (Purple - Autotile)": "DPPt Flowers Purple", "Flower (Yellow - Autotile)": "DPPt Flowers Yellow"}
FIRST_FLOWER = 4
STILL_FLOWERS = "Flowers (Static)"
# Drawings of SirMalo's Nature column D: name => (symbol, column, points
# (x, y in 16 px tiles) inside the drawing, blocked rows at its foot). The
# drawing is every pixel joined to these points (drawn pixels that touch),
# cut out whole whatever the 16 px grid and laid at the foot of a frame of
# 32 px tiles, centred: SirMalo draws most of them across the grid.
DRAWINGS = {
    "buisson sombre": ("Ѷ", 3, [(1.5, 1.5)], 1),
    "buisson enneigé": ("ѷ", 3, [(1.5, 4.5)], 1),
    "arbrisseau": ("Ѹ", 3, [(6.5, 8.0)], 1),
    "pot de fleurs": ("ѹ", 3, [(1.5, 13.0)], 1),
    "topiaire": ("Ѻ", 3, [(0.5, 16.8)], 1),
    "petit buisson": ("ѻ", 3, [(1.5, 17.2)], 1),
    "buisson rond": ("Ѽ", 3, [(3.5, 17.1)], 1),
    "buisson en fleurs": ("ѽ", 3, [(3.5, 19.1)], 1),
    "jardinière": ("Ѿ", 3, [(2.5, 20.6)], 1),
    "jardinière longue": ("ѿ", 3, [(5.5, 20.6)], 1),
    "haie basse": ("Ҁ", 3, [(2.0, 23.1)], 1),
    "haie haute": ("ҁ", 3, [(6.5, 24.3)], 3),
    "rocher enneigé": ("Ҋ", 3, [(2.0, 30.0)], 2),
    "rocher": ("ҋ", 3, [(4.0, 34.0)], 2),
    "caillou enneigé": ("Ҍ", 3, [(0.5, 30.5)], 1),
}
# DPPt drawings in 32 px tiles, whole in their frame: name => (symbol, file,
# x, y, width, height, blocked rows at the foot)
DPPT_DRAWINGS = {"terre à baies": ("ҍ", "Berry Soil", 0, 0, 3, 1, 1)}
PINK = (240, 91, 161)
UNUSED = ((255, 245, 104), (255, 255, 255))


def drawing(sheet, col, points):
    """The pixels joined to the points (16 px sheet), cut out on a clear
    image, scaled x2."""
    left = 16 + 144 * col
    a = np.asarray(sheet).astype(int)
    rgb = a[:, :, :3]
    full = ~((rgb == PINK).all(2) | (a[:, :, 3] == 0) | np.any([(rgb == c).all(2) for c in UNUSED], axis=0))
    full[:, :left] = False
    full[:, left + 128:] = False
    seen = np.zeros(full.shape, bool)
    stack = [(int(y * 16), left + int(x * 16)) for x, y in points]
    for y, x in stack:
        if not full[y, x]:
            sys.exit(f"point {x},{y} hors du dessin")
        seen[y, x] = True
    while stack:
        y, x = stack.pop()
        for ny, nx in ((y + 1, x), (y - 1, x), (y, x + 1), (y, x - 1)):
            if full[ny, nx] and not seen[ny, nx]:
                seen[ny, nx] = True
                stack.append((ny, nx))
    ys, xs = np.nonzero(seen)
    out = np.zeros(a.shape, np.uint8)
    out[seen] = a[seen]
    cut = Image.fromarray(out).crop((xs.min(), ys.min(), xs.max() + 1, ys.max() + 1))
    return cut.resize((cut.width * 2, cut.height * 2), Image.NEAREST)


def check_whole(sheet, name, x0, y0, w, h):
    """Stops on a DPPt drawing whose frame cuts it."""
    last = TILE - 1

    def tile_at(x, y):
        return sheet.crop((x * TILE, y * TILE, x * TILE + TILE, y * TILE + TILE)).load()

    for y in range(y0, y0 + h):
        for x in range(x0, x0 + w):
            tile = tile_at(x, y)
            sides = [("gauche", x == x0, (x - 1, y), [(0, j) for j in range(TILE)], [(last, j) for j in range(TILE)]),
                     ("droite", x == x0 + w - 1, (x + 1, y), [(last, j) for j in range(TILE)], [(0, j) for j in range(TILE)]),
                     ("haut", y == y0, (x, y - 1), [(i, 0) for i in range(TILE)], [(i, last) for i in range(TILE)]),
                     ("bas", y == y0 + h - 1, (x, y + 1), [(i, last) for i in range(TILE)], [(i, 0) for i in range(TILE)])]
            for side, edge_of_frame, (nx, ny), edge, facing in sides:
                if not edge_of_frame or not 0 <= nx < sheet.width // TILE or not 0 <= ny < sheet.height // TILE:
                    continue
                beyond = tile_at(nx, ny)
                if any(tile[p][3] and beyond[q][3] for p, q in zip(edge, facing)):
                    sys.exit(f"{name} : dessin coupé à {side}")


def main():
    sirmalo, dppt = sys.argv[1], sys.argv[2]
    nature = Image.open(f"{sirmalo}/{SHEETS['N']}").convert("RGBA")
    target = Image.open(TARGET).convert("RGBA")
    tables, lines = {}, []

    # Animated flowers: extra autotiles T4 to T7, first frame in the tileset
    for n, (file, name) in enumerate(FLOWERS.items()):
        strip = Image.open(f"{dppt}/{file}.png").convert("RGBA")
        frames = [regreen(strip.crop((f * TILE, 0, f * TILE + TILE, TILE)), SOURCE_GRASS["D"])
                  for f in range(strip.width // TILE)]
        out = Image.new("RGBA", strip.size, (0, 0, 0, 0))
        for f, frame in enumerate(frames):
            out.paste(frame, (f * TILE, 0))
        out.save(f"{AUTOTILES}/{name}.png")
        target.paste(frames[0], box(FIRST_FLOWER + n)[:2])
        tables[str(FIRST_FLOWER + n)] = "=0"
        lines.append(f"T{FIRST_FLOWER + n} = {name} (autotile supplémentaire)")

    first = target.height // TILE * 8
    tiles, at = {}, first
    # Still flowers: one row
    still = Image.open(f"{dppt}/{STILL_FLOWERS}.png").convert("RGBA")
    for i in range(still.width // TILE):
        tiles[at + i] = regreen(still.crop((i * TILE, 0, i * TILE + TILE, TILE)), SOURCE_GRASS["D"])
        tables[str(at + i)] = -1
    lines.append("fleurs DPPt : " + " ".join(f"T{at + i}" for i in range(still.width // TILE)))
    at += 8

    pieces = []
    for name, (sym, col, points, foot) in DRAWINGS.items():
        cut = drawing(nature, col, points)
        w, h = math.ceil(cut.width / TILE), math.ceil(cut.height / TILE)
        frame = Image.new("RGBA", (w * TILE, h * TILE), (0, 0, 0, 0))
        frame.paste(cut, ((w * TILE - cut.width) // 2, h * TILE - cut.height))
        pieces.append((name, sym, [[frame.crop((x * TILE, y * TILE, x * TILE + TILE, y * TILE + TILE))
                                    for x in range(w)] for y in range(h)], min(foot, h)))
    for name, (sym, file, sx, sy, w, h, foot) in DPPT_DRAWINGS.items():
        sheet = Image.open(f"{dppt}/{file}.png").convert("RGBA")
        check_whole(sheet, name, sx, sy, w, h)
        pieces.append((name, sym, [[sheet.crop(((sx + x) * TILE, (sy + y) * TILE, (sx + x + 1) * TILE, (sy + y + 1) * TILE))
                                    for x in range(w)] for y in range(h)], foot))

    x, row_h = 0, 0
    for name, sym, grid, foot in pieces:
        h, w = len(grid), len(grid[0])
        by = h - foot
        if x + w > 8:
            at, x, row_h = at + 8 * row_h, 0, 0
        row_h = max(row_h, h)
        base, empty = at + x, []
        for dy in range(h):
            for dx in range(w):
                tile = grid[dy][dx]
                inside = dy >= by
                tiles[base + dy * 8 + dx] = tile
                tables[str(base + dy * 8 + dx)] = SOLID if inside else TALL
                if not inside and not tile.getbbox():
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
