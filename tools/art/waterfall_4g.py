"""Adds waterfall tiles to the Outside 4G tileset (MapProc's cascades, the
rivers going down the levels): one row of 8 tiles at its end, the first
frame of Essentials' waterfall autotiles (Graphics/Autotiles: Waterfall
crest, Waterfall, Waterfall bottom), still, as no autotile slot is left.
Passages: water (impassable, crossed with Surf/Waterfall); terrain tags:
Waterfall (8) for the fall, WaterfallCrest (9) for its crest, Water (7)
for its foot.

Run from the repository root, after tools/art/outside_4g.py:
    python3 tools/art/waterfall_4g.py
Prints the tile numbers (MapGen T<n>) of the crest, the fall and the foot.
"""
import json
import subprocess
from PIL import Image

TARGET = "Graphics/Tilesets/Outside 4G.png"
TILESET_ID = 24
PARTS = [("Waterfall crest", 9), ("Waterfall", 8), ("Waterfall bottom", 7)]


def main():
    sheet = Image.open(TARGET).convert("RGBA")
    first = sheet.height // 32 * 8
    out = Image.new("RGBA", (sheet.width, sheet.height + 32), (0, 0, 0, 0))
    out.paste(sheet, (0, 0))
    copies = {}
    for i, (name, tag) in enumerate(PARTS):
        frame = Image.open(f"Graphics/Autotiles/{name}.png").convert("RGBA").crop((0, 0, 32, 32))
        out.paste(frame, (i * 32, sheet.height))
        copies[str(first + i)] = f"=15/{tag}"
    out.save(TARGET)
    subprocess.run(["ruby", "tools/art/tileset_tables.rb", str(TILESET_ID), "8", json.dumps(copies)], check=True)
    print("cascade : " + " ".join(f"{name}=T{first + i}" for i, (name, _tag) in enumerate(PARTS)))


if __name__ == "__main__":
    main()
