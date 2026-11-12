"""Adds low reliefs to the Outside 4G tileset (TypeLocked, issue #296), from
SirMalo's NatureRMXP.png (docs/art/inventaire-4g.md):
- low terraces (E1 to E4: earth, stone, turquoise grass, moss): a raised bed
  two tiles high, its rim drawn astride the cells (half outside): a left end,
  a middle repeated and a right end, each one tile wide in its brick, its
  rim's outer half a halo;
- banks (I7: earth, rocks): two tiers, the same way (left end, two middles
  that alternate, right end);
- mounds to jump down (J1 earth, J4 stone): a short ledge, its passages the
  ledge's (T6056 to T6058);
- a small dark cave entrance (I7), its passages a cave entrance's;
- cave mouths in the side of a rock (J2 brown, J5 grey, J6 grey under snow),
  walked into from the east or the west: the mouth's cell is only entered
  from that side, the sill in front of it is plain ground.
Each drawing is whole in its frame: the pixels of a piece's frame never go
beyond it (the script stops otherwise).

Source (docs/CREDITS.md), not in the repository: SirMalo's NatureRMXP.png.
Run once from the repository root, after tools/art/unique_4g.py (Pillow
needed):
    python3 tools/art/reliefs_4g.py "<SirMalo folder>"
Prints the MapGen lines of what it adds.
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
TALL = 420   # passages of a halo tile: walkable, drawn over the player
SOLID = 428  # passages of a blocked tile
LEDGE = "T6057"   # the ledge's middle tile (corniche « - »)
CAVE = [["T6016", "T6017", "T6018"], ["T6024", "T6025", "T6026"]]   # a cave entrance's two bottom rows
# Pieces: name => (symbol, Nature column, x, y, width, height of the frame,
# block x, y, w, h in it, passages of the block: SOLID, "ledge", "cave" or
# a side mouth's, "est" or "ouest" (the side it is walked into from),
# the sides where the piece joins the next one: « gauche », « droite »)
PIECES = {}
for name, sym, row in [("terrasse de terre", "ʫʬʭ", 3), ("terrasse de pierre", "ʮʯϢ", 12),
                       ("terrasse herbeuse", "ϣϤϥ", 21), ("terrasse moussue", "ϦϧϨ", 30)]:
    left, middle, right = sym
    PIECES[f"{name} (gauche)"] = (left, 4, 0, row, 2, 4, 1, 1, 1, 2, SOLID, ["droite"])
    PIECES[f"{name} (milieu)"] = (middle, 4, 2, row, 1, 4, 0, 1, 1, 2, SOLID, ["gauche", "droite"])
    PIECES[f"{name} (droite)"] = (right, 4, 3, row, 2, 4, 0, 1, 1, 2, SOLID, ["gauche"])
# (the earth bank of row 51, alone; the rocky one's left end touches the
# earth bank of row 48 in the sheet)
for name, sym, x0, y0, touching in [("talus de terre", "ϩϪϫϬ", 0, 51, []), ("talus rocheux", "ϭϮϯѠ", 4, 48, ["gauche"])]:
    for k, (part, s) in enumerate(zip(["gauche", "milieu 1", "milieu 2", "droite"], sym)):
        joins = [touching + ["droite"], ["gauche", "droite"], ["gauche", "droite"], ["gauche"]][k]
        PIECES[f"{name} ({part})"] = (s, 8, x0 + k, y0, 1, 3, 0, 1, 1, 2, SOLID, joins)
PIECES["bosse de terre"] = ("ѡ", 9, 2, 0, 4, 1, 1, 0, 2, 1, "ledge", [])
PIECES["bosse de pierre"] = ("Ѣ", 9, 2, 24, 4, 1, 1, 0, 2, 1, "ledge", [])
PIECES["entrée de grotte sombre"] = ("ѣ", 8, 0, 54, 3, 2, 0, 0, 3, 2, "cave", [])
# (the snowy one's sill is two tiles wide, under its drift)
for name, sym, row, sill in [("brune", "Ѥѥ", 12, 1), ("grise", "Ѧѧ", 36, 1), ("enneigée", "Ѩѩ", 44, 2)]:
    PIECES[f"entrée latérale {name} (est)"] = (sym[0], 9, 0, row, 2 + sill, 3, 0, 0, 2, 3, "est", [])
    PIECES[f"entrée latérale {name} (ouest)"] = (sym[1], 9, 6 - sill, row, 2 + sill, 3, sill, 0, 2, 3, "ouest", [])
# Passages of a side mouth's cell: closed but towards the side it opens on
# (1 = down, 2 = left, 4 = right, 8 = up)
MOUTHS = {"est": (1, "=11"), "ouest": (0, "=13")}   # side => (column of the mouth in the block, passages)


def check_whole(sheets, name, col, x, y, w, h, joins):
    """Stops on a piece whose frame cuts a drawing: a pixel on the edge of
    the frame that goes on in the tile beyond it."""
    for dy in range(h):
        for dx in range(w):
            tile = sheet_tile(sheets, ("N", col, x + dx, y + dy)).load()
            for side, (nx, ny), edge, facing in [
                    ("gauche", (-1, 0), [(0, j) for j in range(TILE)], [(TILE - 1, j) for j in range(TILE)]),
                    ("droite", (1, 0), [(TILE - 1, j) for j in range(TILE)], [(0, j) for j in range(TILE)]),
                    ("haut", (0, -1), [(i, 0) for i in range(TILE)], [(i, TILE - 1) for i in range(TILE)]),
                    ("bas", (0, 1), [(i, TILE - 1) for i in range(TILE)], [(i, 0) for i in range(TILE)])]:
                tx, ty = dx + nx, dy + ny
                if (0 <= tx < w and 0 <= ty < h) or side in joins:
                    continue
                if not 0 <= x + tx < 8:   # the sheet's gap between columns
                    continue
                beyond = sheet_tile(sheets, ("N", col, x + tx, y + ty)).load()
                if any(tile[p][3] and beyond[q][3] for p, q in zip(edge, facing)):
                    sys.exit(f"{name} : dessin coupé à {side}")


def main():
    sheets = {k: Image.open(f"{sys.argv[1]}/{n}").convert("RGBA") for k, n in SHEETS.items()}
    target = Image.open(TARGET).convert("RGBA")
    first = target.height // TILE * 8
    tiles, copies, lines = {}, {}, []
    at, x, row_h = first, 0, 0
    for name, (sym, col, sx, sy, w, h, bx, by, bw, bh, kind, joins) in PIECES.items():
        check_whole(sheets, name, col, sx, sy, w, h, joins)
        if x + w > 8:
            at, x, row_h = at + 8 * row_h, 0, 0
        row_h = max(row_h, h)
        base, empty = at + x, []
        for dy in range(h):
            for dx in range(w):
                tile = sheet_tile(sheets, ("N", col, sx + dx, sy + dy))
                dest = base + dy * 8 + dx
                tiles[dest] = tile
                inside = bx <= dx < bx + bw and by <= dy < by + bh
                if kind == "ledge" and inside:
                    copies[dest] = LEDGE
                elif kind == "cave":
                    copies[dest] = CAVE[dy][dx]
                elif kind in MOUTHS:
                    mouth, passages = MOUTHS[kind]
                    if (dx, dy) == (bx + mouth, by + 1):
                        copies[dest] = passages
                    else:
                        copies[dest] = SOLID if inside and tile.getbbox() else -1
                elif inside:
                    copies[dest] = SOLID
                else:
                    copies[dest] = TALL if tile.getbbox() else -1
                if not inside and not tile.getbbox():
                    empty.append(dy * w + dx)
        line = f"{sym} = T{base + by * 8 + bx} {bw}x{bh}"
        if (w, h) != (bw, bh):
            line += f" halo={w}x{h}@{bx},{by}" + ("/" + ",".join(map(str, empty)) if empty else "")
        lines.append(f"{line}   # {name}")
        x += w
    at += 8 * row_h
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
