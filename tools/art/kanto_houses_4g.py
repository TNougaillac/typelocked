"""Adds Kanto's houses to the Outside 4G tileset (TypeLocked, issue #299),
from the "Remastered Kanto Johto Map Pack" (KANTO50S_OUT.png, 32 px tiles,
docs/art/inventaire-4g.md, A22 and A23): a house with a glass roof, a green
house with an orange roof and a house with a purple roof. The sheet leaves a
hole where the door goes: the door is an event, drawn by a charset
(DOOR_GRAPHICS of the plugin), like the other 4G buildings.

Each drawing is whole in its frame: a pixel of a house on the edge of its
frame that goes on in the tile beyond it stops the script.

Source (docs/CREDITS.md), not in the repository: the pack's
Graphics/Tilesets folder.
Run once from the repository root, after tools/art/unique2_4g.py (Pillow
needed):
    python3 tools/art/kanto_houses_4g.py "<pack>/Graphics/Tilesets"
Prints the MapGen lines of what it adds.
"""
import json
import subprocess
import sys
from PIL import Image

sys.path.insert(0, "tools/art")
from outside_4g import box, building_passages  # noqa: E402

TARGET = "Graphics/Tilesets/Outside 4G.png"
SHEET = "KANTO50S_OUT.png"
TILESET_ID = 24
TILE = 32
MARKER = (229, 77, 253, 255)   # the sheet's filling of a door's hole
SHADOW = (2, 3, 31, 76)   # the sheet's shadow
# Houses: name => (symbol, x, y, width, height of the frame in the sheet,
# block x, y, w, h in it, door x, y in it, sides where a neighbour of the
# sheet touches it: « haut », « bas », « gauche », « droite »)
# (the sheet packs its drawings tight: a house's shadow may go on under its
# neighbour, where it is left; the green house's eave ends in its fifth column)
HOUSES = {
    "maison au toit de verre": ("Ѱ", 1, 171, 4, 4, 0, 2, 4, 2, 1, 3, ["haut"]),
    "maison verte au toit orange": ("ѱ", 0, 175, 5, 4, 0, 2, 4, 2, 1, 3, []),
    "maison au toit violet": ("Ѳ", 4, 179, 4, 4, 0, 2, 4, 2, 1, 3, ["bas"]),
}


def sheet_tile(sheet, x, y):
    tile = sheet.crop((x * TILE, y * TILE, x * TILE + TILE, y * TILE + TILE))
    tile.putdata([(0, 0, 0, 0) if c == MARKER else c for c in tile.get_flattened_data()])
    return tile


def check_whole(sheet, name, x0, y0, w, h, touching):
    """Stops on a house whose frame cuts its drawing (not its shadow)."""
    solid = lambda c: c[3] and c != SHADOW  # noqa: E731
    last = TILE - 1
    for y in range(y0, y0 + h):
        for x in range(x0, x0 + w):
            tile = sheet_tile(sheet, x, y).load()
            sides = [("gauche", x == x0, (x - 1, y), [(0, j) for j in range(TILE)], [(last, j) for j in range(TILE)]),
                     ("droite", x == x0 + w - 1, (x + 1, y), [(last, j) for j in range(TILE)], [(0, j) for j in range(TILE)]),
                     ("haut", y == y0, (x, y - 1), [(i, 0) for i in range(TILE)], [(i, last) for i in range(TILE)]),
                     ("bas", y == y0 + h - 1, (x, y + 1), [(i, last) for i in range(TILE)], [(i, 0) for i in range(TILE)])]
            for side, edge_of_frame, (nx, ny), edge, facing in sides:
                if not edge_of_frame or side in touching or not 0 <= nx < 8:
                    continue
                beyond = sheet_tile(sheet, nx, ny).load()
                if any(solid(tile[p]) and solid(beyond[q]) for p, q in zip(edge, facing)):
                    sys.exit(f"{name} : dessin coupé à {side} (tuile {x},{y})")


def main():
    sheet = Image.open(f"{sys.argv[1]}/{SHEET}").convert("RGBA")
    target = Image.open(TARGET).convert("RGBA")
    first = target.height // TILE * 8
    tiles, copies, lines = {}, {}, []
    at = first
    for name, (sym, x0, y0, w, h, bx, by, bw, bh, door_x, door_y, touching) in HOUSES.items():
        check_whole(sheet, name, x0, y0, w, h, touching)
        empty = []
        for dy in range(h):
            for dx in range(w):
                tile = sheet_tile(sheet, x0 + dx, y0 + dy)
                dest = at + dy * 8 + dx
                inside = bx <= dx < bx + bw and by <= dy < by + bh
                tiles[dest] = tile
                copies[dest] = building_passages(tile, inside, (dx, dy) == (door_x, door_y))
                if not inside and not tile.getbbox():
                    empty.append(dy * w + dx)
        line = f"{sym} = T{at + by * 8 + bx} {bw}x{bh}"
        if (w, h) != (bw, bh):
            line += f" halo={w}x{h}@{bx},{by}" + ("/" + ",".join(map(str, empty)) if empty else "")
        lines.append(f"{line}   # {name} (porte {door_x - bx},{door_y - by} de la brique)")
        at += h * 8
    rows = (at - first) // 8
    out = Image.new("RGBA", (target.width, target.height + rows * TILE), (0, 0, 0, 0))
    out.paste(target, (0, 0))
    for t, tile in tiles.items():
        out.paste(tile, box(t)[:2])
    out.save(TARGET)
    filled = {str(t): copies.get(t, -1) for t in range(first, at)}
    subprocess.run(["ruby", "tools/art/tileset_tables.rb", str(TILESET_ID), str(rows * 8), json.dumps(filled)], check=True)
    print("\n".join(lines))


if __name__ == "__main__":
    main()
