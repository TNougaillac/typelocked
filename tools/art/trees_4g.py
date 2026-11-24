"""Adds more trees to the Outside 4G tileset (TypeLocked, issue #297):
- a second essence of forest: SirMalo's pair of light green trees (Nature
  column 2, from row 6), its 6x6 drawing and its copy with the passages of a
  halo, like the first essence (FOREST in outside_4g.py), for the forests of
  the grass (MapGen « mix= », drawn in clusters among the first one);
- a remarkable tree (Remastered Johto, JohtoCompactExterior.png), laid once
  per place at most;
- the fruit and flowering trees of the orchards (Remastered Kanto,
  KANTO50S_OUT.png).
Each drawing is whole in its frame.

Sources (docs/CREDITS.md), not in the repository: SirMalo's NatureRMXP.png and
the Remastered Kanto Johto Map Pack (Graphics/Tilesets).
Run once from the repository root, after tools/art/ambiances_4g.py (Pillow
needed):
    python3 tools/art/trees_4g.py "<SirMalo folder>" "<Remastered Tilesets folder>"
Prints the MapGen lines of what it adds.
"""
import json
import subprocess
import sys
from PIL import Image

sys.path.insert(0, "tools/art")
from outside_4g import SHEETS, FOREST_SIZE, box, sheet_tile  # noqa: E402

TARGET = "Graphics/Tilesets/Outside 4G.png"
TILESET_ID = 24
TILE = 32
TALL = 420   # passages of a halo tile: walkable, drawn over the player
SOLID = 428  # passages of a tree tile: blocked
SECOND_ESSENCE = (2, 6)   # Nature column, first row of its 6x6 drawing
REMASTERED = {"J": "JohtoCompactExterior.png", "K": "KANTO50S_OUT.png"}
# Trees: name => (sheet, x, y, width, height in 32 px tiles, block x, y, w, h)
# (whole blocks: the orchard's rows are tight, a halo there would overlap
# the tree above)
TREES = {
    "arbre remarquable": ("J", 5, 137, 3, 3, 0, 0, 3, 3),
    "oranger": ("K", 7, 56, 1, 2, 0, 0, 1, 2),
    "arbre en fleurs": ("K", 0, 64, 1, 2, 0, 0, 1, 2),
    "pommier en fleurs": ("K", 1, 64, 1, 2, 0, 0, 1, 2),
    "jeune arbre": ("K", 2, 64, 1, 2, 0, 0, 1, 2),
    "buisson fruitier": ("K", 3, 65, 1, 1, 0, 0, 1, 1),
}


def main():
    folder, remastered_folder = sys.argv[1], sys.argv[2]
    sheets = {k: Image.open(f"{folder}/{name}").convert("RGBA") for k, name in SHEETS.items()}
    remastered = {k: Image.open(f"{remastered_folder}/{name}").convert("RGBA") for k, name in REMASTERED.items()}
    sheet = Image.open(TARGET).convert("RGBA")
    first = sheet.height // TILE * 8
    tiles, copies, lines = {}, {}, []

    # The second essence: drawing (blocked) then its halo copy, side by side
    col, row = SECOND_ESSENCE
    solid, halo = first, first + FOREST_SIZE * 8
    for dy in range(FOREST_SIZE):
        for dx in range(FOREST_SIZE):
            tile = sheet_tile(sheets, ("N", col, dx, row + dy))
            for start, passages in ((solid, SOLID), (halo, TALL)):
                tiles[start + dy * 8 + dx] = tile
                copies[start + dy * 8 + dx] = passages
    lines.append(f"deuxième essence : mix=T{solid}/T{halo}")
    at = first + 2 * FOREST_SIZE * 8

    # Trees, side by side on rows of 8 tiles
    x, row_h = 0, 0
    for name, (src, sx, sy, w, h, bx, by, bw, bh) in TREES.items():
        if x + w > 8:
            at, x, row_h = at + 8 * row_h, 0, 0
        row_h = max(row_h, h)
        base, empty = at + x, []
        for dy in range(h):
            for dx in range(w):
                c = (sx + dx) * TILE, (sy + dy) * TILE
                tile = remastered[src].crop((c[0], c[1], c[0] + TILE, c[1] + TILE))
                inside = bx <= dx < bx + bw and by <= dy < by + bh
                tiles[base + dy * 8 + dx] = tile
                copies[base + dy * 8 + dx] = SOLID if inside else TALL
                if not inside and not tile.getbbox():
                    empty.append(dy * w + dx)
        line = f"T{base + by * 8 + bx} {bw}x{bh}"
        if (w, h) != (bw, bh):
            line += f" halo={w}x{h}@{bx},{by}" + ("/" + ",".join(map(str, empty)) if empty else "")
        lines.append(f"{name} : {line}")
        x += w
    at += 8 * row_h

    rows = (at - first) // 8
    out = Image.new("RGBA", (sheet.width, sheet.height + rows * TILE), (0, 0, 0, 0))
    out.paste(sheet, (0, 0))
    for t, tile in tiles.items():
        out.paste(tile, box(t)[:2])
    out.save(TARGET)
    filled = {str(t): copies.get(t, -1) for t in range(first, at)}
    subprocess.run(["ruby", "tools/art/tileset_tables.rb", str(TILESET_ID), str(rows * 8), json.dumps(filled)], check=True)
    print("\n".join(lines))


if __name__ == "__main__":
    main()
