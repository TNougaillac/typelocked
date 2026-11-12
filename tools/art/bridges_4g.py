"""Adds a stone bridge and a round paved square to the Outside 4G tileset
(TypeLocked, issue #298, part 2), from SirMalo's UrbanRMXP.png
(docs/art/inventaire-4g.md):
- the stone bridge (C5, C6), walked from north to south over a canal that
  runs from west to east: the sheet's deck is three tiles wide, a street two
  (STREET_WIDTH), so its middle column is left out (the planks run across);
  its posts stand on the banks (the first two rows and the last), its parapets on
  the water;
- the round square (A4): a ring of bricks around a bed, walked on.
Each drawing is whole in its frame: a pixel on the edge of a frame that goes
on in the tile beyond it stops the script.

Source (docs/CREDITS.md), not in the repository: SirMalo's UrbanRMXP.png.
Run once from the repository root, after tools/art/cave_styles_4g.py (Pillow
needed):
    python3 tools/art/bridges_4g.py "<SirMalo folder>"
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
PIER = "T1214"   # the planks of a wooden pier: walked on, over the water
FLAT = -1    # walkable, under the player


def bridge_passages(x, y):
    """The deck (the two middle columns) is walked on; the parapets block;
    the posts of the north bank hide the player behind them, those of the
    south bank block."""
    if x in (1, 2):
        return PIER if 2 <= y <= 7 else FLAT
    return TALL if y <= 1 else SOLID


# Pieces: name => (symbol, Urban column, columns of the frame, first row,
# height, block x, y, w, h, passages(x, y) of a drawn tile, options of the
# MapGen line, tiles of the frame that belong to a neighbour: left empty)
PIECES = {
    "pont de pierre": ("Ѫ", 2, [2, 3, 5, 6], 36, 9, 0, 2, 4, 6, bridge_passages, " L3 @~", []),
    "placette ronde": ("ѫ", 0, [0, 1, 2, 3, 4], 24, 5, 0, 0, 5, 5, lambda x, y: FLAT, "", [(4, 28)]),
}


def piece_tile(sheets, col, x, y, drop):
    tile = sheet_tile(sheets, ("U", col, x, y))
    return Image.new("RGBA", tile.size, (0, 0, 0, 0)) if (x, y) in drop else tile


def check_whole(sheets, name, col, columns, y0, h, drop):
    """Stops on a piece whose frame cuts a drawing (the columns left out
    inside the frame are not its edge)."""
    left, right = columns[0], columns[-1]
    for y in range(y0, y0 + h):
        for x in columns:
            tile = piece_tile(sheets, col, x, y, drop).load()
            sides = [("gauche", x == left, (x - 1, y), [(0, j) for j in range(TILE)], [(TILE - 1, j) for j in range(TILE)]),
                     ("droite", x == right, (x + 1, y), [(TILE - 1, j) for j in range(TILE)], [(0, j) for j in range(TILE)]),
                     ("haut", y == y0, (x, y - 1), [(i, 0) for i in range(TILE)], [(i, TILE - 1) for i in range(TILE)]),
                     ("bas", y == y0 + h - 1, (x, y + 1), [(i, TILE - 1) for i in range(TILE)], [(i, 0) for i in range(TILE)])]
            for side, edge_of_frame, (nx, ny), edge, facing in sides:
                if not edge_of_frame or not 0 <= nx < 8:
                    continue
                beyond = sheet_tile(sheets, ("U", col, nx, ny)).load()
                if any(tile[p][3] and beyond[q][3] for p, q in zip(edge, facing)):
                    sys.exit(f"{name} : dessin coupé à {side}")


def main():
    sheets = {"U": Image.open(f"{sys.argv[1]}/{SHEETS['U']}").convert("RGBA")}
    target = Image.open(TARGET).convert("RGBA")
    first = target.height // TILE * 8
    tiles, copies, lines = {}, {}, []
    at = first
    for name, (sym, col, columns, y0, h, bx, by, bw, bh, passages, options, drop) in PIECES.items():
        check_whole(sheets, name, col, columns, y0, h, drop)
        w, empty = len(columns), []
        for dy in range(h):
            for dx, x in enumerate(columns):
                tile = piece_tile(sheets, col, x, y0 + dy, drop)
                dest = at + dy * 8 + dx
                tiles[dest] = tile
                copies[dest] = passages(dx, dy) if tile.getbbox() else FLAT
                inside = bx <= dx < bx + bw and by <= dy < by + bh
                if not inside and not tile.getbbox():
                    empty.append(dy * w + dx)
        line = f"{sym} = T{at + by * 8 + bx} {bw}x{bh}"
        if (w, h) != (bw, bh):
            line += f" halo={w}x{h}@{bx},{by}" + ("/" + ",".join(map(str, empty)) if empty else "")
        lines.append(f"{line}{options}   # {name}")
        at += 8 * h
    rows = (at - first) // 8
    out = Image.new("RGBA", (target.width, target.height + rows * TILE), (0, 0, 0, 0))
    out.paste(target, (0, 0))
    for t, tile in tiles.items():
        out.paste(tile, box(t)[:2])
    out.save(TARGET)
    filled = {str(t): copies.get(t, FLAT) for t in range(first, at)}
    subprocess.run(["ruby", "tools/art/tileset_tables.rb", str(TILESET_ID), str(rows * 8), json.dumps(filled)], check=True)
    print("\n".join(lines))


if __name__ == "__main__":
    main()
