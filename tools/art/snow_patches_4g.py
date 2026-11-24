"""Adds a patch of snow to the Outside 4G tileset (TypeLocked, issue #301),
from the "DPPt Exterior Ground Tiles" pack (Platinum/Snow Patches.png, 16 px
tiles scaled x2, docs/art/inventaire-4g.md): the drifts of melting snow in
the middle of the sheet's snow field, 4x4 tiles, see-through between them,
drawn over the ground of the place and walked on. The field's own outline
around them is left out (a frame made to be filled, not a drawing), and so
are the drifts that the middle's edge cuts (the middle repeats: they go on
on its other side): every drift kept is whole. A pixel left on the edge of
the frame stops the script.

Source (docs/CREDITS.md), not in the repository: the pack's Platinum folder.
Run once from the repository root, after tools/art/extra_autotiles_4g.py
(Pillow needed):
    python3 tools/art/snow_patches_4g.py "<pack>/Platinum"
Prints the MapGen line of what it adds.
"""
import json
import subprocess
import sys
from PIL import Image

TARGET = "Graphics/Tilesets/Outside 4G.png"
SHEET = "Snow Patches.png"
TILESET_ID = 24
TILE = 32
SOURCE = 16
# The drifts: symbol, x, y, width, height in the sheet (16 px tiles)
SYMBOL, X0, Y0, W, H = "Ѵ", 2, 2, 4, 4


def main():
    sheet = Image.open(f"{sys.argv[1]}/{SHEET}").convert("RGBA")
    patch = sheet.crop((X0 * SOURCE, Y0 * SOURCE, (X0 + W) * SOURCE, (Y0 + H) * SOURCE))
    px = patch.load()
    last_x, last_y = patch.width - 1, patch.height - 1
    # Drifts cut by the edge: cleared from their pixels on the edge inwards
    stack = [(x, y) for x in range(patch.width) for y in (0, last_y)] + [(x, y) for y in range(patch.height) for x in (0, last_x)]
    while stack:
        x, y = stack.pop()
        if not (0 <= x <= last_x and 0 <= y <= last_y) or not px[x, y][3]:
            continue
        px[x, y] = (0, 0, 0, 0)
        stack += [(x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)]
    if not patch.getbbox():
        sys.exit("plaque de neige : aucune congère entière")
    if any(px[x, y][3] for x in range(patch.width) for y in (0, last_y)) or any(px[x, y][3] for y in range(patch.height) for x in (0, last_x)):
        sys.exit("plaque de neige : dessin coupé par son cadre")
    patch = patch.resize((W * TILE, H * TILE), Image.NEAREST)
    target = Image.open(TARGET).convert("RGBA")
    first = target.height // TILE * 8
    out = Image.new("RGBA", (target.width, target.height + H * TILE), (0, 0, 0, 0))
    out.paste(target, (0, 0))
    out.paste(patch, (0, target.height))
    out.save(TARGET)
    filled = {str(t): -1 for t in range(first, first + H * 8)}
    subprocess.run(["ruby", "tools/art/tileset_tables.rb", str(TILESET_ID), str(H * 8), json.dumps(filled)], check=True)
    print(f"{SYMBOL} = T{first} {W}x{H}   # plaque de neige")


if __name__ == "__main__":
    main()
