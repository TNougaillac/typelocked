"""Frees the first row of the Outside 4G tileset for Essentials' extra
autotiles (TypeLocked, issue #301). A RPG Maker XP tileset has 7 autotiles;
TilemapRenderer::EXTRA_AUTOTILES draws more of them in place of the first
tiles of the tileset (here: single tile autotiles, one tile each).
- Moves the 8 tiles of the first row (T0 to T7: grass, tall grass) to a new
  row at the end of the tileset, with their passages, priorities and terrain
  tags. The palettes of MapProc use the new numbers.
- T0 to T3 become the animated autotiles of EXTRA (the plugin's
  EXTRA_AUTOTILES, in the same order): the three parts of a waterfall
  (Essentials' Waterfall crest, Waterfall, Waterfall bottom, whose first
  frames were the still tiles of tools/art/waterfall_4g.py) and the white
  flowers of the HGSS autotiles (HGSS Flowers 02, copied from the pack).
  Their first frame is drawn in the tileset (what an editor shows); T4 to T7
  are left empty.

Run once from the repository root, after tools/art/ponds_4g.py, with the
folder of the extracted HGSS autotiles (Pillow needed):
    python3 tools/art/extra_autotiles_4g.py "<HGSS Autotiles folder>"
Prints the new numbers of the moved tiles.
"""
import json
import shutil
import subprocess
import sys
from PIL import Image

TARGET = "Graphics/Tilesets/Outside 4G.png"
AUTOTILES = "Graphics/Autotiles"
TILESET_ID = 24
TILE = 32
# Extra autotiles, T0 onwards => passages and terrain tag (waterfall_4g.py's:
# water, WaterfallCrest 9, Waterfall 8, Water 7; the flowers are walked on)
EXTRA = [("Waterfall crest", "=15/9"), ("Waterfall", "=15/8"), ("Waterfall bottom", "=15/7"),
         ("HGSS Flowers 02", "=0")]
COPIED = ["HGSS Flowers 02"]


def main():
    for name in COPIED:
        shutil.copyfile(f"{sys.argv[1]}/{name}.png", f"{AUTOTILES}/{name}.png")
    target = Image.open(TARGET).convert("RGBA")
    first = target.height // TILE * 8
    out = Image.new("RGBA", (target.width, target.height + TILE), (0, 0, 0, 0))
    out.paste(target, (0, 0))
    out.paste(target.crop((0, 0, 8 * TILE, TILE)), (0, target.height))
    out.paste(Image.new("RGBA", (8 * TILE, TILE), (0, 0, 0, 0)), (0, 0))
    tables = {str(first + n): n for n in range(8)}
    for n, (name, passages) in enumerate(EXTRA):
        frame = Image.open(f"{AUTOTILES}/{name}.png").convert("RGBA").crop((0, 0, TILE, TILE))
        out.paste(frame, (n * TILE, 0))
        tables[str(n)] = passages
    for n in range(len(EXTRA), 8):
        tables[str(n)] = "=15"
    out.save(TARGET)
    subprocess.run(["ruby", "tools/art/tileset_tables.rb", str(TILESET_ID), "8", json.dumps(tables)], check=True)
    print("déplacées : " + " ".join(f"T{n}=T{first + n}" for n in range(8)))
    print("autotiles : " + " ".join(f"T{n}={name}" for n, (name, _p) in enumerate(EXTRA)))


if __name__ == "__main__":
    main()
