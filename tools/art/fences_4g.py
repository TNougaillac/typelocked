"""Adds wooden pens to the Outside 4G tileset (MapProc's enclosures,
« enclos » bricks): SirMalo's wooden fence (UrbanRMXP.png, see
docs/CREDITS.md, sources not in the repository) around a patch of ground,
drawn whole as objects, one per size. Its 16 px pieces (strip 3): the
left and right ends of its small pen (tips, top rail, tips and rail of the
bottom side), the farm's fence (« barriere ») in between, and its columns of
posts for the sides. Each pen: one row of tips above its block (drawn over what stands
there, see-through elsewhere, as the farm's fence), then its block, all of
it fenced (passages and priorities of the farm's fence).

Run from the repository root, after tools/art/outside_4g.py and
tools/art/waterfall_4g.py:
    python3 tools/art/fences_4g.py <folder of SirMalo's sheets>
Prints the MapGen object lines of the pens.
"""
import json
import subprocess
import sys
from PIL import Image

sys.path.insert(0, "tools/art")
from outside_4g import SHEETS, sheet_tile  # noqa: E402

TARGET = "Graphics/Tilesets/Outside 4G.png"
TILESET_ID = 24
TILE = 32
STRIP = 3
# Source columns of the pen's left and right ends, rows of its tips, top
# rail, tips of its bottom side, bottom rail; the fence in between (tips,
# rail); the posts of the left and right sides
LEFT, RIGHT = 0, 1
TIPS, TOP, BOTTOM_TIPS, BOTTOM = 7, 8, 9, 10
MIDDLE = {TIPS: (1, 11), TOP: (1, 12), BOTTOM_TIPS: (1, 11), BOTTOM: (1, 12)}
LEFT_POSTS, RIGHT_POSTS = (3, 8), (2, 8)
# The farm's fence: its tips (passable, drawn over) and its rail (fenced)
FARM_TIPS, FARM_RAIL = 15283, 15291
# Pens: width in tiles, rows of sides between the top and the bottom rail
PENS = [("enclos", 4, 1), ("grand enclos", 6, 2)]


def pen(sheets, width, sides):
    """The drawing of a pen (tiles, row after row) and the source of each
    tile's passages."""
    piece = lambda col, row: sheet_tile(sheets, ("U", STRIP, col, row))
    empty = Image.new("RGBA", (TILE, TILE), (0, 0, 0, 0))
    rows = []
    for row in [TIPS, TOP] + [None] * sides + [BOTTOM_TIPS, BOTTOM]:
        if row is None:
            tiles = [piece(*LEFT_POSTS)] + [empty] * (width - 2) + [piece(*RIGHT_POSTS)]
        else:
            tiles = [piece(LEFT, row)] + [piece(*MIDDLE[row])] * (width - 2) + [piece(RIGHT, row)]
        rows.append([(t, FARM_TIPS if row == TIPS else FARM_RAIL) for t in tiles])
    return rows


def main():
    folder = sys.argv[1]
    sheets = {k: Image.open(f"{folder}/{name}").convert("RGBA") for k, name in SHEETS.items()}
    sheet = Image.open(TARGET).convert("RGBA")
    first = sheet.height // TILE * 8
    drawings = [(name, pen(sheets, width, sides)) for name, width, sides in PENS]
    height = sum(len(rows) for _name, rows in drawings)
    out = Image.new("RGBA", (sheet.width, sheet.height + height * TILE), (0, 0, 0, 0))
    out.paste(sheet, (0, 0))
    copies, lines, row0 = {}, [], 0
    for name, rows in drawings:
        for dy, row in enumerate(rows):
            for dx, (tile, source) in enumerate(row):
                out.paste(tile, (dx * TILE, sheet.height + (row0 + dy) * TILE))
                copies[str(first + (row0 + dy) * 8 + dx)] = source
        width, tall = len(rows[0]), len(rows)
        lines.append(f"T{first + (row0 + 1) * 8} {width}x{tall - 1} halo={width}x{tall}@0,1   # {name}")
        row0 += tall
    out.save(TARGET)
    subprocess.run(["ruby", "tools/art/tileset_tables.rb", str(TILESET_ID), str(height * 8), json.dumps(copies)], check=True)
    print("\n".join(lines))


if __name__ == "__main__":
    main()
