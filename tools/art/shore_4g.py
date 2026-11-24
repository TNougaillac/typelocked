"""Animated sandy shore of the Outside 4G tileset (TypeLocked, issue #301):
the autotile « HGSS Shore », the sea with waves breaking on pale sand all
around it, in the last free autotile slot of tileset 24 (A7).
The "HGSS Autotiles" pack draws the opposite, a sand bank in the sea (HGSS
Beach, and its inner corners in HGSS Beach Corner, 32 frames each): the
shore is the same drawing read from the water's side.
- an edge of the sea is the opposite edge of the bank (the north shore is
  the bank's south edge...);
- a corner of the sea is a whole inner corner tile of the bank;
- a point of sand in the sea (the autotile's inner corners) is the quarter
  of the bank's corner that holds its tip;
- the middle is the plain sea (HGSS Sea), drawn under every tile; a lone
  tile of sea is the pack's pool (the first tile of HGSS Beach Corner).
A7 takes the passages, priorities and terrain tags of A1 (the water).

Run from the repository root, after tools/art/autotiles_4g.py, with the
folder of the extracted pack (Pillow needed):
    python3 tools/art/shore_4g.py "<HGSS Autotiles folder>"
"""
import json
import subprocess
import sys
from PIL import Image

OUT = "Graphics/Autotiles"
NAME = "HGSS Shore"
TILESET_ID = 24
FRAME_W, FRAME_H, TILE = 96, 128, 32
# Autotiles of tileset 24, A1 to A7 (tools/art/autotiles_4g.py, then A7)
NAMES = ["HGSS Lake", "HGSS Sea", "HGSS Sea deep", "HGSS Sand bank", "HGSS Flowers 01", "HGSS Rocks", NAME]
# Tile of the shore's frame (column, row) => (sheet, column, row) in the
# pack's frame: B the bank (HGSS Beach), C its inner corners
TILES = {
    (0, 0): ("C", 0, 0),
    (0, 1): ("C", 2, 3), (1, 1): ("B", 1, 3), (2, 1): ("C", 0, 3),
    (0, 2): ("B", 2, 2), (2, 2): ("B", 0, 2),
    (0, 3): ("C", 2, 1), (1, 3): ("B", 1, 1), (2, 3): ("C", 0, 1),
}
# Quarter (x, y) of the inner corners tile => the bank's corner with its tip
POINTS = {(0, 0): (2, 3), (1, 0): (0, 3), (0, 1): (2, 1), (1, 1): (0, 1)}


def main():
    pack = sys.argv[1]
    sheets = {"B": Image.open(f"{pack}/HGSS Beach.png").convert("RGBA"),
              "C": Image.open(f"{pack}/HGSS Beach Corner.png").convert("RGBA")}
    sea = Image.open(f"{OUT}/HGSS Sea.png").convert("RGBA")
    frames = sea.width // FRAME_W
    if any(sheet.width != sea.width for sheet in sheets.values()):
        sys.exit("HGSS Beach : pas le même nombre d'images que HGSS Sea")
    out = Image.new("RGBA", (sea.width, FRAME_H))
    for i in range(frames):
        left = i * FRAME_W
        out.paste(sea.crop((left, 0, left + FRAME_W, FRAME_H)), (left, 0))

        def tile(sheet, tx, ty):
            return sheets[sheet].crop((left + tx * TILE, ty * TILE, left + (tx + 1) * TILE, (ty + 1) * TILE))
        for (x, y), src in TILES.items():
            out.alpha_composite(tile(*src), (left + x * TILE, y * TILE))
        for (qx, qy), (tx, ty) in POINTS.items():
            box = (qx * 16, qy * 16, qx * 16 + 16, qy * 16 + 16)
            out.alpha_composite(tile("B", tx, ty).crop(box), (left + 2 * TILE + qx * 16, qy * 16))
    if out.getextrema()[3][0] < 255:
        sys.exit(f"{NAME} : image trouée")
    out.save(f"{OUT}/{NAME}.png")
    subprocess.run(["ruby", "tools/art/tileset_autotiles.rb", str(TILESET_ID), *NAMES], check=True)
    subprocess.run(["ruby", "tools/art/tileset_tables.rb", str(TILESET_ID), "0", json.dumps({"A7": "A1"})], check=True)
    print(f"{OUT}/{NAME}.png : {frames} images, A7 du tileset {TILESET_ID}")


if __name__ == "__main__":
    main()
