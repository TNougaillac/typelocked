"""HGSS autotiles of the Outside 4G tileset (TypeLocked, issues #197, #177).

Builds the autotiles of tileset 24 (see docs/CREDITS.md, sources not in the
repository):
- HGSS Sea (A2): the lone tile of the "HGSS Autotiles" pack's sea, each of
  its 32 frames repeated over the whole frame (the pack crosses out the
  other parts).
- Pond (A1) and sand bank (A4): SirMalo's rounded patches (NatureRMXP.png),
  made into RPG Maker XP autotiles (see blob_autotile): the pond is the
  water of lakes, rivers and the sea, with its bank on all 4 sides, its
  still water replaced by the animated HGSS Sea (32 frames, the bank and
  its light rim kept); the sand bank, laid over the water, is the pale
  sand patch.
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
POND_WATER = (104, 176, 232, 255)   # the still water of SirMalo's pond
FRAME_W, FRAME_H = 96, 128
PINK = (240, 91, 161, 255)
COPIED = ["HGSS Rocks", "HGSS Flowers 01"]
# SirMalo's rounded patches (column 0 of NatureRMXP.png): first row of the
# 4x4 patch; its copy with a hole (the inner corners) is on its right
BLOBS = {"HGSS Pond": 39, "HGSS Sand bank": 21}
# Autotiles of tileset 24, A1 to A7 (Fountain1 is not replaced yet)
NAMES = ["HGSS Pond", "HGSS Sea", "HGSS Pond deep", "HGSS Sand bank",
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
    blobs["HGSS Pond"] = animate(blobs["HGSS Pond"], sea, lambda c: c == POND_WATER)
    for name, image in blobs.items():
        image.save(f"{OUT}/{name}.png")
    animate(blobs["HGSS Sand bank"], sea, lambda c: c[3] > 0, DEEP).save(f"{OUT}/HGSS Pond deep.png")
    subprocess.run(["ruby", "tools/art/tileset_autotiles.rb", str(TILESET_ID), *NAMES], check=True)
    print(f"{OUT} : {len(COPIED) + len(BLOBS) + 2} autotiles HGSS, tileset {TILESET_ID} : {', '.join(NAMES)}")


if __name__ == "__main__":
    main()
