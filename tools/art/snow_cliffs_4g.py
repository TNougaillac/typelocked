"""Snow cliffs of the Outside 4G tileset (TypeLocked, issue #318): SirMalo's
own snowy plateaux (NatureRMXP.png H3 to H5, I3 to I5) in place of the brown
and grey cliffs tinted white for the snow biome (#204). Snow over brown rock
for the levels (terraces, mountains), over grey rock for the massifs; laid
like the other plateaux (5 rows of 8, CLIFF_ROWS in outside_4g.py, see
tools/art/ambiances_4g.py), their snow top taking the snow ground's colours by
place, so that a level's top joins the ground. New tiles: the palettes of
MapProc swap the tinted cliffs for them (the script prints the offsets).

Source (docs/CREDITS.md), not in the repository: SirMalo's NatureRMXP.png.
Run once from the repository root, after tools/art/vegetation_4g.py (Pillow
needed):
    python3 tools/art/snow_cliffs_4g.py "<SirMalo folder>"
"""
import json
import subprocess
import sys
from PIL import Image

sys.path.insert(0, "tools/art")
from outside_4g import SHEETS, CLIFF_ROWS, box, sheet_tile, on_ground, cliff_passages  # noqa: E402
from ambiances_4g import retexture  # noqa: E402

TARGET = "Graphics/Tilesets/Outside 4G.png"
TILESET_ID = 24
TILE = 32
SNOW = 14632
# Plateaux: name => (Nature column, first row, first tile of the tinted cliff
# it replaces)
PLATEAUX = {"neige (niveaux)": (7, 20, 14808), "neige (massifs)": (8, 20, 14848)}


def main():
    sheets = {k: Image.open(f"{sys.argv[1]}/{name}").convert("RGBA") for k, name in SHEETS.items()}
    sheet = Image.open(TARGET).convert("RGBA")
    snow = sheet.crop(box(SNOW))
    first = sheet.height // TILE * 8
    tiles, copies, lines, at = {}, {}, [], first
    for name, (col, row, old) in PLATEAUX.items():
        # The colours of the top: its middle row (the row above holds the rim)
        top = {c for x in (1, 2) for c in sheet_tile(sheets, ("N", col, x, row + 2)).get_flattened_data()}
        for dy in range(CLIFF_ROWS):
            for dx in range(8):
                tile = on_ground(sheet_tile(sheets, ("N", col, dx, row + dy)), snow, cliff=True)
                tile = retexture(tile, top, snow)
                tiles[at + dy * 8 + dx] = tile
                copies[str(at + dy * 8 + dx)] = cliff_passages(dy, dx, tile)
        lines.append(f"falaise {name} : T{old} à T{old + CLIFF_ROWS * 8 - 1} => +{at - old}")
        at += CLIFF_ROWS * 8
    rows = (at - first) // 8
    out = Image.new("RGBA", (sheet.width, sheet.height + rows * TILE), (0, 0, 0, 0))
    out.paste(sheet, (0, 0))
    for t, tile in tiles.items():
        out.paste(tile, box(t)[:2])
    out.save(TARGET)
    subprocess.run(["ruby", "tools/art/tileset_tables.rb", str(TILESET_ID), str(rows * 8), json.dumps(copies)], check=True)
    print("\n".join(lines))


if __name__ == "__main__":
    main()
