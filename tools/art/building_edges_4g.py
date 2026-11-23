"""Makes the buildings of the Outside 4G tileset whole (no tile is ever cut):
- the side edges of their roofs, which SirMalo's Buildings sheet draws one
  tile away from the building (roof_edges in tools/art/outside_4g.py), are
  put back against it, in the tiles already built;
- the drawings that go beyond their frame in the sheet (TALLER: the top of
  the roofs of the Pokémon Centre, the Marts and the teal house, the end of
  the shadow of the stands) are copied whole at the end of the tileset, with
  the row or column they lacked.
It stops if a building is still cut by its frame (cut_drawings).
The [Objects] lines of MapProc/ville.txt and MapProc/route.txt follow (tile,
halo, empty cells).

Run from the repository root, on the tileset built by tools/art/outside_4g.py
and the scripts run after it (run again, it only does what is left to do):
    python3 tools/art/building_edges_4g.py <folder of SirMalo's sheets>
"""
import json
import re
import subprocess
import sys
from PIL import Image

sys.dont_write_bytecode = True
sys.path.insert(0, "tools/art")
from outside_4g import (BUILDINGS, MAGENTA, MORE_BUILDINGS, SHADOW, SHEETS, TALL, TALLER, TARGET, TILE,  # noqa: E402
                        WIDE_SYMBOLS, box, building_frames, cut_drawings, roof_edges)

TILESET_ID = 24
PLANS = ["MapProc/ville.txt", "MapProc/route.txt"]
LINE = re.compile(r"^(\S) = T(\d+) (\d+)x(\d+)(?: halo=(\d+)x(\d+)@(\d+),(\d+)(?:/([\d,]+))?)?(.*)$")


def objects(text):
    """symbol => [[line index, tile, w, h, drawing w, h, block x, y, empty cells, rest of the line]]"""
    found = {}
    for i, line in enumerate(text.split("\n")):
        if (m := LINE.match(line)):
            w, h = int(m[3]), int(m[4])
            found.setdefault(m[1], []).append([i, int(m[2]), w, h, int(m[5] or w), int(m[6] or h), int(m[7] or 0), int(m[8] or 0),
                                               [int(k) for k in (m[9] or "").split(",") if k], m[10]])
    return found


def object_line(sym, tile, w, h, dw, dh, bx, by, empty, rest):
    halo = f" halo={dw}x{dh}@{bx},{by}" + ("/" + ",".join(map(str, sorted(empty))) if empty else "") if (dw, dh) != (w, h) else ""
    return f"{sym} = T{tile} {w}x{h}{halo}{rest}"


def solid(tile):
    return any(c[3] and c != SHADOW for c in tile.get_flattened_data())


def drawing_of(sheet, col, x, y, w, h):
    """Pixels (x, y in the sheet) of the drawing in that frame and joined to
    it beyond."""
    px = sheet.load()
    left = 16 + 144 * col
    clear = {MAGENTA, (255, 245, 104, 255)}
    stack = [(left + a, b) for a in range(x * 16, (x + w) * 16) for b in range(y * 16, (y + h) * 16) if px[left + a, b] not in clear]
    seen = set(stack)
    while stack:
        a, b = stack.pop()
        for q in ((a + 1, b), (a - 1, b), (a, b + 1), (a, b - 1)):
            if q not in seen and left <= q[0] < left + 128 and (y - 1) * 16 <= q[1] < (y + h) * 16 and px[q] not in clear:
                seen.add(q)
                stack.append(q)
    return seen


def main():
    sheet = Image.open(f"{sys.argv[1]}/{SHEETS['B']}").convert("RGBA")
    if (cut := cut_drawings(sheet)):
        sys.exit("\n".join(f"{sym} : dessin coupé par son cadre ({l} px à gauche, {t} au-dessus, {r} à droite, {b} dessous)" for sym, l, t, r, b in cut))
    tileset = Image.open(TARGET).convert("RGBA")
    texts = {plan: open(plan, encoding="utf-8").read() for plan in PLANS}
    plans = {plan: objects(text) for plan, text in texts.items()}
    copies = {}
    changed = {}   # symbol => its line's new values

    # Each building: its symbol (one per 8 columns of its drawing), the size
    # of its drawing and its block, to tell its lines from another object
    # with the same symbol; then its frames (column, x, y, w, h, x, y in the drawing)
    buildings = [([sym], w, h, (bx, by, bw, bh), [(col, x, y, w, h, 0, 0)]) for sym, (col, x, y, w, h, bx, by, bw, bh, *_door) in BUILDINGS.items()]
    for sym, (parts, block, _door) in MORE_BUILDINGS.items():
        buildings.append(([sym] + WIDE_SYMBOLS.get(sym, []), max(p[5] + p[3] for p in parts), max(p[6] + p[4] for p in parts), block, [p[:7] for p in parts]))
    known = {}
    done = set()   # already copied whole (TALLER)
    for syms, w, h, (bx, by, bw, bh), _frames in buildings:
        for k, sym in enumerate(syms[:(w - 1) // 8 + 1]):
            x0, x1 = k * 8, min(w, k * 8 + 8)
            size = [min(bx + bw, x1) - max(bx, x0), bh, x1 - x0, h, max(bx, x0) - x0, by]
            more_left, more_top, more_right = TALLER.get(sym, (0, 0, 0))
            whole = [size[0], size[1], size[2] + more_left + more_right, size[3] + more_top, size[4] + more_left, size[5] + more_top]
            if sym in TALLER and any(obj[2:8] == whole for found in plans.values() for obj in found.get(sym, [])):
                size = whole
                done.add(sym)
            lines = {tuple(obj[1:8]) for found in plans.values() for obj in found.get(sym, []) if obj[2:8] == size}
            if len(lines) == 1:
                known[sym] = next(obj for found in plans.values() for obj in found.get(sym, []) if obj[2:8] == size)
            else:
                print(f"{sym} : pas de ligne {size} (ou plusieurs tuiles), laissé", file=sys.stderr)
    for syms, _w, _h, _block, frames in buildings:
      for col, x, y, w, h, ox, oy in frames:
        for (tx, ty), edge in roof_edges(sheet, col, x, y, w, h).items():
            dx, dy = tx - x + ox, ty - y + oy
            if not (x <= tx < x + w) or dx // 8 >= len(syms) or syms[dx // 8] not in known:
                continue
            sym, dx = syms[dx // 8], dx % 8
            dx, dy = (dx + TALLER[sym][0], dy + TALLER[sym][1]) if sym in done else (dx, dy)
            _i, tile, bw, bh, dw, dh, bx, by, empty, _rest = obj = changed.setdefault(sym, list(known[sym]))
            dest = tile - by * 8 - bx + dy * 8 + dx
            tileset.alpha_composite(edge.resize((TILE, TILE), Image.NEAREST), box(dest)[:2])
            if not (bx <= dx < bx + bw and by <= dy < by + bh):
                copies[str(dest)] = TALL
                obj[8] = [k for k in empty if k != dy * dw + dx]

    # The drawings that go beyond their frame, whole at the end of the tileset
    first = tileset.height // TILE * 8
    rows = 0
    tiles = {}
    frames = {sym: frame for sym, *frame, _start in building_frames()}
    for sym, (more_x, more_y, more_right) in TALLER.items():
        if sym in done or sym not in known:
            continue
        col, x, y, w, h = frames[sym]
        _i, tile, bw, bh, dw, dh, bx, by, _empty, _rest = obj = changed.setdefault(sym, list(known[sym]))
        keep = drawing_of(sheet, col, x - more_x, y, w + more_x + more_right, h)
        old = tile - by * 8 - bx
        new = first + rows * 8
        width = dw + more_x + more_right
        empty = []
        for ty in range(dh + more_y):
            for tx in range(width):
                dest = new + ty * 8 + tx
                if more_x <= tx < more_x + dw and ty >= more_y:
                    source = old + (ty - more_y) * 8 + tx - more_x
                    tiles[dest] = tileset.crop(box(source))
                    copies[str(dest)] = copies.get(str(source), source)
                else:
                    left, top = 16 + 144 * col + (x - more_x + tx) * 16, (y - more_y + ty) * 16
                    part = Image.new("RGBA", (16, 16))
                    for a in range(16):
                        for b in range(16):
                            pixel = sheet.getpixel((left + a, top + b))
                            # (on the right, only the shadow: the rest is another piece)
                            if (left + a, top + b) in keep and (tx < more_x + dw or pixel == SHADOW):
                                part.putpixel((a, b), pixel)
                    tiles[dest] = part.resize((TILE, TILE), Image.NEAREST)
                    copies[str(dest)] = TALL if solid(tiles[dest]) else "=0"
                inside = bx + more_x <= tx < bx + more_x + bw and by + more_y <= ty < by + more_y + bh
                if not inside and not tiles[dest].getbbox():
                    empty.append(ty * width + tx)
        obj[1:9] = [new + (by + more_y) * 8 + bx + more_x, bw, bh, width, dh + more_y, bx + more_x, by + more_y, empty]
        rows += dh + more_y
    out = Image.new("RGBA", (tileset.width, tileset.height + rows * TILE), (0, 0, 0, 0))
    out.paste(tileset, (0, 0))
    for dest, tile in tiles.items():
        out.paste(tile, box(dest)[:2])
    out.save(TARGET)
    subprocess.run(["ruby", "tools/art/tileset_tables.rb", str(TILESET_ID), str(rows * 8), json.dumps(copies)], check=True)

    for plan, text in texts.items():
        lines = text.split("\n")
        for sym, obj in changed.items():
            for line in plans[plan].get(sym, []):
                if line[1:8] == known[sym][1:8]:
                    lines[line[0]] = object_line(sym, *obj[1:9], line[9])
        open(plan, "w", encoding="utf-8").write("\n".join(lines))
    print("\n".join(object_line(sym, *obj[1:]) for sym, obj in changed.items()))


if __name__ == "__main__":
    main()
