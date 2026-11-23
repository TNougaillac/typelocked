"""HGSS autotiles of the Outside 4G tileset (TypeLocked, issues #197, #177).

Builds the autotiles of tileset 24 (see docs/CREDITS.md, sources not in the
repository):
- HGSS Sea (A2): the lone tile of the "HGSS Autotiles" pack's sea, each of
  its 32 frames repeated over the whole frame (the pack crosses out the
  other parts).
- HGSS Lake (A1): the water of lakes, rivers and the sea, as in HGSS (Lake
  of Rage): the pack's HGSS Ledge (dirt bank and foam, both animated) over
  the HGSS Sea, the sea only inside the bank. The pack draws no bottom
  edge: its top edge, flipped upside down, is the bottom one, so the bank
  goes all around (see ledge_lake).
- Sand bank (A4): SirMalo's rounded pale sand patch (NatureRMXP.png), made
  into an RPG Maker XP autotile (see blob_autotile), laid over the water.
- Deep water (A3): the animated HGSS Sea, darkened, in the rounded outline
  of the sand bank (no deep water in the sheets).
- HGSS Rocks (A6), HGSS Flowers 01 (A5): copied as they are from the pack,
  with every frame of their animation (a rock is a 2x2 block).
Then sets the autotile names of tileset 24 (tools/art/tileset_autotiles.rb).

Run from the repository root, after tools/art/outside_4g.py, with the
folders of the extracted pack and of the SirMalo sheets (Pillow needed):
    python3 tools/art/autotiles_4g.py "<HGSS Autotiles folder>" "<SirMalo folder>"
"""
import subprocess
import sys
from PIL import Image

OUT = "Graphics/Autotiles"
TILESET_ID = 24
DEEP = 0.75
FRAME_W, FRAME_H = 96, 128
PINK = (240, 91, 161, 255)
COPIED = ["HGSS Rocks", "HGSS Flowers 01"]
# SirMalo's rounded patches (column 0 of NatureRMXP.png): first row of the
# 4x4 patch; its copy with a hole (the inner corners) is on its right
BLOBS = {"HGSS Sand bank": 21}
# Autotiles of tileset 24, A1 to A7 (Fountain1 is not replaced yet)
NAMES = ["HGSS Lake", "HGSS Sea", "HGSS Sea deep", "HGSS Sand bank",
         "HGSS Flowers 01", "HGSS Rocks", "Fountain1"]


def sheet_tile(sheet, tx, ty):
    """One 16 px tile of column 0 of a SirMalo sheet, scaled x2, its pink
    see-through."""
    im = sheet.crop((16 + tx * 16, ty * 16, 32 + tx * 16, ty * 16 + 16))
    im.putdata([(0, 0, 0, 0) if c == PINK else c for c in im.get_flattened_data()])
    return im.resize((32, 32), Image.NEAREST)


def quarter(tile, qx, qy):
    return tile.crop((qx * 16, qy * 16, qx * 16 + 16, qy * 16 + 16))


def blob_autotile(sheet, row):
    """An autotile from a rounded 4x4 patch (columns 0-3) and its copy with
    a hole (columns 4-7): the 3x3 block is the patch's corners and sides
    (its columns 0, 1, 3 and rows 0, 1, 3), the inner corners the quarters
    of the hole, the lone tile the 4 corners. Whole tiles of the patch come
    out of MapGen as they are drawn."""
    out = Image.new("RGBA", (FRAME_W, FRAME_H))
    for by, ty in enumerate((0, 1, 3)):
        for bx, tx in enumerate((0, 1, 3)):
            out.paste(sheet_tile(sheet, tx, row + ty), (bx * 32, 32 + by * 32))
    for qx in (0, 1):
        for qy in (0, 1):
            # The hole is at the meeting point of tiles 5-6 x 1-2 of the copy:
            # the quarter of each tile that touches it
            hole = sheet_tile(sheet, 6 - qx, row + 2 - qy)
            out.paste(quarter(hole, qx, qy), (64 + qx * 16, qy * 16))
            corner = out.crop((qx * 64, 32 + qy * 64, qx * 64 + 32, 64 + qy * 64))
            out.paste(quarter(corner, qx, qy), (qx * 16, qy * 16))
    return out


def plain_sea(sea):
    parts = []
    for i in range(sea.width // FRAME_W):
        tile = sea.crop((i * FRAME_W, 0, i * FRAME_W + 32, 32))
        for x in range(0, FRAME_W, 32):
            for y in range(0, FRAME_H, 32):
                parts.append((tile, (i * FRAME_W + x, y)))
    out = Image.new("RGBA", (sea.width, FRAME_H))
    for tile, at in parts:
        out.paste(tile, at)
    return out


def animate(still, sea, where, dark=1.0):
    """One frame per frame of the sea: the pixels of `still` chosen by
    where(pixel) take the sea's (darkened by `dark`), the others stay."""
    base = still.get_flattened_data()
    out = Image.new("RGBA", (sea.width, FRAME_H))
    for i in range(sea.width // FRAME_W):
        water = sea.crop((i * FRAME_W, 0, i * FRAME_W + FRAME_W, FRAME_H)).get_flattened_data()
        frame = Image.new("RGBA", (FRAME_W, FRAME_H))
        frame.putdata([(int(water[k][0] * dark), int(water[k][1] * dark), int(water[k][2] * dark), 255)
                       if where(c) else c for k, c in enumerate(base)])
        out.paste(frame, (i * FRAME_W, 0))
    return out


def flood(frame, seeds):
    """See-through pixels of a frame reached from seeds, each fill kept in
    its box: [(points, (x0, y0, x1, y1)), ...]."""
    px = frame.load()
    seen = set()
    for points, (x0, y0, x1, y1) in seeds:
        stack = list(points)
        while stack:
            x, y = stack.pop()
            if (x, y) in seen or not (x0 <= x < x1 and y0 <= y < y1) or px[x, y][3] != 0:
                continue
            seen.add((x, y))
            stack += [(x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)]
    return seen


def border(x0, y0, x1, y1):
    return [(x, y) for x in range(x0, x1) for y in (y0, y1 - 1)] + [(x, y) for y in range(y0, y1) for x in (x0, x1 - 1)]


def ledge_lake(ledge, sea):
    """Each frame: the ledge with a bottom edge (its top edge flipped: the
    top halves of the lone tile, of the 3x3 block's top row and of the top
    inner corners, flipped into the bottom halves), over the sea where the
    bank closes (see-through pixels not reached from the outer sides)."""
    out = Image.new("RGBA", (ledge.width, FRAME_H))
    for i in range(ledge.width // FRAME_W):
        frame = ledge.crop((i * FRAME_W, 0, i * FRAME_W + FRAME_W, FRAME_H))
        flip = frame.transpose(Image.FLIP_TOP_BOTTOM)
        frame.paste(flip.crop((0, 112, 32, 128)), (0, 16))       # lone tile
        frame.paste(flip.crop((64, 112, 96, 128)), (64, 16))     # inner corners
        frame.paste(flip.crop((0, 64, 96, 96)), (0, 96))         # bottom row
        lake = sea.crop((i * FRAME_W, 0, i * FRAME_W + FRAME_W, FRAME_H))
        lake.alpha_composite(frame)
        px = lake.load()
        beyond = flood(frame, [(border(0, 0, 32, 32), (0, 0, 32, 32)), (border(0, 32, 96, 128), (0, 32, 96, 128)),
                               ([(64, 0)], (64, 0, 80, 16)), ([(95, 0)], (80, 0, 96, 16)),
                               ([(64, 31)], (64, 16, 80, 32)), ([(95, 31)], (80, 16, 96, 32))])
        for x, y in beyond:
            px[x, y] = (0, 0, 0, 0)
        out.paste(lake, (i * FRAME_W, 0))
    return out


def main():
    pack, sirmalo = sys.argv[1], sys.argv[2]

    def load(name):
        return Image.open(f"{pack}/{name}.png").convert("RGBA")
    for name in COPIED:
        load(name).save(f"{OUT}/{name}.png")
    sea = plain_sea(load("HGSS Sea"))
    sea.save(f"{OUT}/HGSS Sea.png")
    nature = Image.open(f"{sirmalo}/NatureRMXP.png").convert("RGBA")
    blobs = {name: blob_autotile(nature, row) for name, row in BLOBS.items()}
    for name, image in blobs.items():
        image.save(f"{OUT}/{name}.png")
    ledge_lake(load("HGSS Ledge"), sea).save(f"{OUT}/HGSS Lake.png")
    animate(blobs["HGSS Sand bank"], sea, lambda c: c[3] > 0, DEEP).save(f"{OUT}/HGSS Sea deep.png")
    subprocess.run(["ruby", "tools/art/tileset_autotiles.rb", str(TILESET_ID), *NAMES], check=True)
    print(f"{OUT} : {len(COPIED) + len(BLOBS) + 3} autotiles HGSS, tileset {TILESET_ID} : {', '.join(NAMES)}")


if __name__ == "__main__":
    main()
