"""Adds a pond to the Outside 4G tileset (TypeLocked, issue #301), from
SirMalo's NatureRMXP.png (docs/art/inventaire-4g.md, A6): a blue pond with
its earth bank, 4x4 tiles, drawn over the ground of the place and blocked
(still water: no Surf, no fishing).
The drawing is whole in its frame: a pixel on the edge of the frame that
goes on in the tile beyond it stops the script.

Source (docs/CREDITS.md), not in the repository: SirMalo's NatureRMXP.png.
Run once from the repository root, after tools/art/kanto_houses_4g.py
(Pillow needed):
    python3 tools/art/ponds_4g.py "<SirMalo folder>"
Prints the MapGen line of what it adds.
"""
import json
import subprocess
import sys
from PIL import Image

sys.path.insert(0, "tools/art")
from outside_4g import SHEETS, box, sheet_tile  # noqa: E402

TARGET = "Graphics/Tilesets/Outside 4G.png"
TILESET_ID = 24
TILE = 32
SOLID = 428  # passages of a blocked tile
# Ponds: name => (symbol, Nature column, x, y, width, height in the sheet)
PONDS = {"mare": ("ѳ", 0, 0, 39, 4, 4)}


def check_whole(sheets, name, col, x0, y0, w, h):
    """Stops on a pond whose frame cuts its drawing."""
    last = TILE - 1
    for y in range(y0, y0 + h):
        for x in range(x0, x0 + w):
            tile = sheet_tile(sheets, ("N", col, x, y)).load()
            sides = [("gauche", x == x0, (x - 1, y), [(0, j) for j in range(TILE)], [(last, j) for j in range(TILE)]),
                     ("droite", x == x0 + w - 1, (x + 1, y), [(last, j) for j in range(TILE)], [(0, j) for j in range(TILE)]),
                     ("haut", y == y0, (x, y - 1), [(i, 0) for i in range(TILE)], [(i, last) for i in range(TILE)]),
                     ("bas", y == y0 + h - 1, (x, y + 1), [(i, last) for i in range(TILE)], [(i, 0) for i in range(TILE)])]
            for side, edge_of_frame, (nx, ny), edge, facing in sides:
                if not edge_of_frame or not 0 <= nx < 8 or ny < 0:
                    continue
                beyond = sheet_tile(sheets, ("N", col, nx, ny)).load()
                if any(tile[p][3] and beyond[q][3] for p, q in zip(edge, facing)):
                    sys.exit(f"{name} : dessin coupé à {side}")


def main():
    sheets = {"N": Image.open(f"{sys.argv[1]}/{SHEETS['N']}").convert("RGBA")}
    target = Image.open(TARGET).convert("RGBA")
    first = target.height // TILE * 8
    tiles, lines = {}, []
    at = first
    for name, (sym, col, x0, y0, w, h) in PONDS.items():
        check_whole(sheets, name, col, x0, y0, w, h)
        for dy in range(h):
            for dx in range(w):
                tiles[at + dy * 8 + dx] = sheet_tile(sheets, ("N", col, x0 + dx, y0 + dy))
        lines.append(f"{sym} = T{at} {w}x{h}   # {name}")
        at += 8 * h
    rows = (at - first) // 8
    out = Image.new("RGBA", (target.width, target.height + rows * TILE), (0, 0, 0, 0))
    out.paste(target, (0, 0))
    for t, tile in tiles.items():
        out.paste(tile, box(t)[:2])
    out.save(TARGET)
    filled = {str(t): SOLID if t in tiles else -1 for t in range(first, at)}
    subprocess.run(["ruby", "tools/art/tileset_tables.rb", str(TILESET_ID), str(rows * 8), json.dumps(filled)], check=True)
    print("\n".join(lines))


if __name__ == "__main__":
    main()
