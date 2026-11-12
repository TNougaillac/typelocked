"""Adds town styles to the Outside 4G tileset (TypeLocked, issue #298):
SirMalo's paving (UrbanRMXP.png, column A) as MapProc street styles (« Rue »
lines of the ambiances: edges from the full patch, inner corners from the
patch with a hole, like STREETS in outside_4g.py), and the fences and street
furniture of each town style (HOUSE_STYLES of the plugin): a fence of
pickets (warm), a white fence (cold), lamps and a fire hydrant (SirMalo's
grey railing is drawn to repeat, its pieces cut by any frame: left out). Each drawing is whole in its frame.

Sources (docs/CREDITS.md), not in the repository: SirMalo's UrbanRMXP.png.
Run once from the repository root, after tools/art/trees_4g.py (Pillow
needed):
    python3 tools/art/towns_4g.py "<SirMalo folder>"
Prints the MapGen lines of what it adds.
"""
import json
import subprocess
import sys
from PIL import Image

sys.path.insert(0, "tools/art")
from outside_4g import SHEETS, STREET_ROLES, box, sheet_tile  # noqa: E402

TARGET = "Graphics/Tilesets/Outside 4G.png"
TILESET_ID = 24
TILE = 32
TALL = 420   # passages of a halo tile: walkable, drawn over the player
SOLID = 428  # passages of a blocked tile
GRASS = 1
# Paving: name => (Urban column, full patch x, y, middle x, y, patch with a
# hole x, y)
PAVING = {
    "pierre grise": (0, 0, 11, 1, 12, 4, 11),
    "dalles dorées": (0, 4, 15, 5, 16, 0, 15),
    "terre tassée": (0, 0, 1, 1, 2, 4, 1),
}
# Props: name => (Urban column, x, y, width, height, block x, y, w, h)
PROPS = {
    "palissade": (3, 0, 11, 3, 2, 0, 1, 3, 1),
    "barrière blanche": (3, 4, 17, 2, 2, 0, 1, 2, 1),
    "lanternes en bois": (4, 4, 15, 2, 4, 0, 3, 2, 1),
    "réverbère rouge": (4, 0, 23, 2, 3, 0, 2, 2, 1),
    "réverbère turquoise": (4, 4, 11, 2, 3, 0, 2, 2, 1),
    "bouche d'incendie": (5, 6, 26, 1, 2, 0, 1, 1, 1),
}


def main():
    folder = sys.argv[1]
    sheets = {k: Image.open(f"{folder}/{name}").convert("RGBA") for k, name in SHEETS.items()}
    sheet = Image.open(TARGET).convert("RGBA")
    grass = sheet.crop(box(GRASS))
    first = sheet.height // TILE * 8
    tiles, copies, lines = {}, {}, []
    at = first

    for name, (col, ox, oy, cx, cy, hx, hy) in PAVING.items():
        ids = []
        for i, (role, dx, dy, part) in enumerate(STREET_ROLES):
            src = (cx, cy) if part is None else (ox + dx, oy + dy) if part == "o" else (hx + dx, hy + dy)
            tile = grass.copy()
            tile.alpha_composite(sheet_tile(sheets, ("U", col) + src))
            tiles[at + i] = tile
            copies[at + i] = -1
            ids.append(f"{role}=T{at + i}" if role else f"T{at + i}")
        lines.append(f"rue ({name}) : Rue = " + " ".join(ids))
        at += 16

    x, row_h = 0, 0
    for name, (col, sx, sy, w, h, bx, by, bw, bh) in PROPS.items():
        if x + w > 8:
            at, x, row_h = at + 8 * row_h, 0, 0
        row_h = max(row_h, h)
        base, empty = at + x, []
        for dy in range(h):
            for dx in range(w):
                tile = sheet_tile(sheets, ("U", col, sx + dx, sy + dy))
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
