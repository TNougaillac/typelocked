"""Adds unique buildings to the Outside 4G tileset (TypeLocked, issue #299),
from SirMalo's BuildingsRMXP.png (docs/art/inventaire-4g.md): the pagoda of
the Pact (F9, F10), a lighthouse (L1, L2), a railway station (Q3 to Q5), the
Family's casino (M7 to M10), a greenhouse (R1 to R3), fair garlands (K5) and
a market stall (H3).

The sheet cuts its biggest drawings in two halves, put back side by side
(like MORE_BUILDINGS in outside_4g.py); a drawing wider than the tileset's
8 tiles becomes one object per 8 columns, side by side in its brick. Each
drawing is whole in its frame: the pixels joined to it beyond its frame
stop the script, but for the neighbours it touches in the sheet (« apart »,
their tiles), and those of a neighbour inside its frame are cleared but for
the shadow (« drop »).

Source (docs/CREDITS.md), not in the repository: SirMalo's BuildingsRMXP.png.
Run once from the repository root, after tools/art/towns_4g.py (Pillow
needed):
    python3 tools/art/unique_4g.py "<SirMalo folder>"
Prints the MapGen lines of what it adds.
"""
import json
import subprocess
import sys
from PIL import Image

sys.path.insert(0, "tools/art")
from outside_4g import SHEETS, SHADOW, box, drawing_image, joined_pixels, building_passages  # noqa: E402

TARGET = "Graphics/Tilesets/Outside 4G.png"
TILESET_ID = 24
TILE = 32
# Buildings: name => (symbols, parts, block x, y, w, h, door x, y in the
# drawing or None, apart, drop). A part is (sheet column, x, y, width,
# height of its frame, x, y of the frame in the drawing, x, y of a pixel of
# it in the column, or -1, -1 for every pixel of the frame). apart: [(part,
# tile x, y in the column)] of neighbours joined to it; drop: [(tile x, y in
# the drawing)] where only the shadow is kept.
BUILDINGS = {
    "pagode du Pacte": ("ʠ", [(5, 0, 64, 8, 13, 0, 0, 64, 1104)], (0, 9, 7, 3), (3, 11), [], []),
    "phare": ("ʡ", [(11, 0, 0, 8, 13, 0, 0, 48, 100)], (0, 6, 7, 5), (3, 10), [], [(7, 2), (7, 3), (7, 4), (7, 5)]),
    "gare": ("ʢʣ", [(16, 4, 19, 4, 9, 0, 0, 88, 344), (16, 0, 28, 5, 9, 4, 0, 24, 488)], (0, 4, 9, 4), (4, 7),
             [(0, x, y) for x in (2, 3) for y in range(19, 28)] + [(1, x, y) for x in (5, 6) for y in range(28, 37)], []),
    "casino de la Famille": ("ʤʥ", [(12, 2, 51, 6, 14, 0, 0, 72, 856), (12, 0, 65, 8, 14, 6, 0, 16, 1080)],
                             (1, 8, 11, 4), (6, 11), [], []),
    "serre": ("ʦʧ", [(17, 1, 0, 7, 11, 0, 0, 104, 56), (17, 0, 10, 4, 11, 7, 0, 16, 216)], (1, 4, 9, 5), (6, 8),
              [(1, 4, 18)], []),
    # The two poles of a garland, each its own object: the player walks
    # under the flags, between them
    "guirlande (gauche)": ("ʨ", [(10, 4, 29, 3, 5, 0, 0, -1, -1)], (0, 3, 1, 1), None, [], []),
    "guirlande (droite)": ("ʩ", [(10, 3, 34, 3, 5, 0, 0, -1, -1)], (1, 3, 1, 1), None, [], []),
    "étal": ("ʪ", [(7, 0, 17, 4, 5, 0, 0, 40, 290)], (0, 1, 4, 3), None,
             [(0, x, y) for x in range(4, 8) for y in range(17, 22)], []),
}


def check_whole(sheet, name, parts, apart):
    """Stops on a drawing that its frame cuts (no tile is ever cut)."""
    for i, (col, x, y, w, h, _ox, _oy, sx, sy) in enumerate(parts):
        if sx < 0:
            continue
        beyond = {(a // 16, b // 16) for a, b in joined_pixels(sheet, col, (sx, sy))
                  if not (x * 16 <= a < (x + w) * 16 and y * 16 <= b < (y + h) * 16)}
        beyond -= {(tx, ty) for p, tx, ty in apart if p == i}
        if beyond:
            sys.exit(f"{name} : dessin coupé par son cadre (tuiles {sorted(beyond)})")


def drop_neighbours(drawing, drop):
    """Only the shadow kept on those tiles (16 px) of the drawing."""
    px = drawing.load()
    for tx, ty in drop:
        for b in range(ty * 16, ty * 16 + 16):
            for a in range(tx * 16, tx * 16 + 16):
                if px[a, b] != SHADOW:
                    px[a, b] = (0, 0, 0, 0)


def main(buildings=None):
    """Adds these buildings (BUILDINGS by default) under the tileset."""
    buildings = buildings or BUILDINGS
    sheet = Image.open(f"{sys.argv[1]}/{SHEETS['B']}").convert("RGBA")
    target = Image.open(TARGET).convert("RGBA")
    first = target.height // TILE * 8
    tiles, copies, lines = {}, {}, []
    at = first
    for name, (symbols, parts, (bx, by, bw, bh), door, apart, drop) in buildings.items():
        check_whole(sheet, name, parts, apart)
        drawing = drawing_image(sheet, parts)
        drop_neighbours(drawing, drop)
        w, h = drawing.width // 16, drawing.height // 16
        if len(symbols) != (w + 7) // 8:
            sys.exit(f"{name} : {(w + 7) // 8} symboles attendus")
        for k, sym in enumerate(symbols):
            x0, x1 = k * 8, min(w, k * 8 + 8)
            empty = []
            for ty in range(h):
                for tx in range(x0, x1):
                    dest = at + ty * 8 + tx - x0
                    tile = drawing.crop((tx * 16, ty * 16, tx * 16 + 16, ty * 16 + 16)).resize((TILE, TILE), Image.NEAREST)
                    inside = bx <= tx < bx + bw and by <= ty < by + bh
                    tiles[dest] = tile
                    copies[dest] = building_passages(tile, inside, (tx, ty) == door)
                    if not inside and not tile.getbbox():
                        empty.append(ty * (x1 - x0) + tx - x0)
            pbx, pbw = max(bx, x0) - x0, min(bx + bw, x1) - max(bx, x0)
            line = f"{sym} = T{at + by * 8 + pbx} {pbw}x{bh}"
            if (x1 - x0, h) != (pbw, bh):
                line += f" halo={x1 - x0}x{h}@{pbx},{by}" + ("/" + ",".join(map(str, empty)) if empty else "")
            part = f", partie {k + 1}" if len(symbols) > 1 else ""
            porte = f" (porte {door[0] - bx},{door[1] - by} de la brique)" if door and k == 0 else ""
            lines.append(f"{line}   # {name}{part}{porte}")
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
