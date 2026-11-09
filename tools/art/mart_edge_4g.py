"""Puts back the right edge of the Marts' roof in the Outside 4G tileset:
SirMalo's Buildings sheet draws it (3 px) one tile too far to the right, so
the roofs were square on that side (ROOF_EDGES in tools/art/outside_4g.py,
which now builds them whole). Patches the tileset already built.

Run once from the repository root:
    python3 tools/art/mart_edge_4g.py <folder of SirMalo's sheets>
"""
import json
import subprocess
import sys
from PIL import Image

sys.path.insert(0, "tools/art")
from outside_4g import BUILDINGS, ROOF_EDGES, SHEETS, TALL, TILE, TARGET, box, sheet_tile  # noqa: E402

TILESET_ID = 24
FIRST = {"M": 6112, "N": 6152}   # first tile of each drawing (MapProc/ville.txt)


def main():
    folder = sys.argv[1]
    sheets = {k: Image.open(f"{folder}/{name}").convert("RGBA") for k, name in SHEETS.items()}
    sheet = Image.open(TARGET).convert("RGBA")
    copies = {}
    for sym, first in FIRST.items():
        col, x, y = BUILDINGS[sym][:3]
        tx, rows = ROOF_EDGES[sym]
        for ty in rows:
            tile = first + ty * 8 + tx
            current = sheet.crop(box(tile))
            edge = sheet_tile(sheets, ("B", col, x + tx + 1, y + ty))
            sheet.paste(Image.alpha_composite(current, edge), box(tile)[:2])
            copies[str(tile)] = TALL
    sheet.save(TARGET)
    subprocess.run(["ruby", "tools/art/tileset_tables.rb", str(TILESET_ID), "0", json.dumps(copies)], check=True)


if __name__ == "__main__":
    main()
