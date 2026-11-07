"""HGSS autotiles of the Outside 4G tileset (TypeLocked, issue #197).

Builds the autotiles of tileset 24 from the "HGSS Autotiles" pack (see
docs/CREDITS.md, not in the repository), each frame of its animation kept:
- HGSS Rocks (A6), HGSS Flowers 01 (A5): copied as they are (a rock is a
  2x2 block: the middle of the 3x3 block is unused, crossed out in red).
- HGSS Sea (A2): its lone tile repeated over the whole frame (the pack
  crosses out the other parts: its sea is always the same tile, the edges
  are other autotiles drawn over it).
- HGSS Sea Ledge (A1): the sea under the ledge (bank and foam), only inside
  the bank: outside stays see-through, over the ground as before. Like the
  old Sea, it draws no bottom edge (the Rive tiles below do).
- HGSS Sea deep (A3): the sea, darkened (the pack has no deep water).
- HGSS Sand bank (A4): HGSS Beach, its inner corners and its middle (left
  out in the pack) taken from HGSS Beach Corner: the quarters of its 4
  corner tiles, the water side for the inner corners, the sand side for the
  middle.
Then sets the autotile names of tileset 24 (tools/art/tileset_autotiles.rb).

RMXP autotiles are 96x128 per frame: the top-left tile is the lone tile,
the top-right one the 4 inner corners, the 3x3 block below the edges.

Run from the repository root, after tools/art/outside_4g.py, with the
folder of the extracted pack (Pillow needed):
    python3 tools/art/autotiles_4g.py "<HGSS Autotiles folder>"
"""
import subprocess
import sys
from PIL import Image

OUT = "Graphics/Autotiles"
TILESET_ID = 24
DEEP = 0.75
FRAME_W, FRAME_H = 96, 128
COPIED = ["HGSS Rocks", "HGSS Flowers 01"]
# Autotiles of tileset 24, A1 to A7 (Fountain1 is not replaced yet)
NAMES = ["HGSS Sea Ledge", "HGSS Sea", "HGSS Sea deep", "HGSS Sand bank",
         "HGSS Flowers 01", "HGSS Rocks", "Fountain1"]


def flood(frame, parts):
    """See-through pixels of a frame reached from seeds, each part a (seeds,
    box) pair: the fill stays in its box."""
    px = frame.load()
    seen = set()
    for seeds, (x0, y0, x1, y1) in parts:
        stack = list(seeds)
        while stack:
            x, y = stack.pop()
            if (x, y) in seen or not (x0 <= x < x1 and y0 <= y < y1) or px[x, y][3] != 0:
                continue
            seen.add((x, y))
            stack += [(x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)]
    return seen


def sides(x0, y0, x1, y1, bottom=False):
    seeds = [(x, y0) for x in range(x0, x1)] + [(x0, y) for y in range(y0, y1)] + [(x1 - 1, y) for y in range(y0, y1)]
    return seeds + ([(x, y1 - 1) for x in range(x0, x1)] if bottom else [])


def outside(frame):
    """Pixels of a ledge frame beyond the bank: see-through pixels reached
    from the outer sides of each part (top, left and right of the lone tile
    and of the edge block, the outer corner of the top inner corners; the
    bottom inner corners have no bank, like the bottom edge)."""
    return flood(frame, [(sides(0, 0, 32, 32), (0, 0, 32, 32)), (sides(0, 32, 96, 128), (0, 32, 96, 128)),
                         ([(64, 0)], (64, 0, 80, 16)), ([(95, 0)], (80, 0, 96, 16))])


def frames(image):
    return [image.crop((i * FRAME_W, 0, i * FRAME_W + FRAME_W, FRAME_H)) for i in range(image.width // FRAME_W)]


def join(parts):
    out = Image.new("RGBA", (FRAME_W * len(parts), FRAME_H))
    for i, part in enumerate(parts):
        out.paste(part, (i * FRAME_W, 0))
    return out


def ledge_sea(sea, ledge):
    parts = []
    for water, bank in zip(frames(sea), frames(ledge)):
        frame = water.copy()
        frame.alpha_composite(bank)
        px = frame.load()
        for x, y in outside(bank):
            px[x, y] = (0, 0, 0, 0)
        parts.append(frame)
    return join(parts)


def plain_sea(sea):
    parts = []
    for frame in frames(sea):
        tile = frame.crop((0, 0, 32, 32))
        part = Image.new("RGBA", (FRAME_W, FRAME_H))
        for x in range(0, FRAME_W, 32):
            for y in range(0, FRAME_H, 32):
                part.paste(tile, (x, y))
        parts.append(part)
    return join(parts)


def deep_sea(sea):
    out = sea.copy()
    out.putdata([(int(r * DEEP), int(g * DEEP), int(b * DEEP), a) for r, g, b, a in sea.getdata()])
    return out


def quarters(frame, corner):
    """The 4 quarters of a tile built from the corner tiles of the 3x3 block
    of a frame: corner=True, each from the outer quarter of its tile (top
    left of the top-left tile...); False, from the inner one."""
    tile = Image.new("RGBA", (32, 32))
    for qx in (0, 1):
        for qy in (0, 1):
            dx, dy = (qx, qy) if corner else (1 - qx, 1 - qy)
            x, y = qx * 64 + dx * 16, 32 + qy * 64 + dy * 16
            tile.paste(frame.crop((x, y, x + 16, y + 16)), (qx * 16, qy * 16))
    return tile


def sand_bank(beach, corners):
    """The sand fills the inside of the beach only: what is see-through
    beyond its water (reached from the sides) stays see-through."""
    parts = []
    for frame, corner in zip(frames(beach), frames(corners)):
        part = Image.new("RGBA", (FRAME_W, FRAME_H))
        sand = quarters(corner, False)
        for x in range(0, FRAME_W, 32):
            for y in range(0, FRAME_H, 32):
                part.paste(sand, (x, y))
        beyond = flood(frame, [(sides(0, 0, 32, 32, True), (0, 0, 32, 32)),
                               (sides(0, 32, 96, 128, True), (0, 32, 96, 128))])
        px = part.load()
        for x, y in beyond:
            px[x, y] = (0, 0, 0, 0)
        part.alpha_composite(frame)
        part.paste(quarters(corner, True), (64, 0))
        parts.append(part)
    return join(parts)


def main():
    folder = sys.argv[1]

    def load(name):
        return Image.open(f"{folder}/{name}.png").convert("RGBA")
    for name in COPIED:
        load(name).save(f"{OUT}/{name}.png")
    sea = plain_sea(load("HGSS Sea"))
    sea.save(f"{OUT}/HGSS Sea.png")
    ledge_sea(sea, load("HGSS Ledge")).save(f"{OUT}/HGSS Sea Ledge.png")
    deep_sea(sea).save(f"{OUT}/HGSS Sea deep.png")
    sand_bank(load("HGSS Beach"), load("HGSS Beach Corner")).save(f"{OUT}/HGSS Sand bank.png")
    subprocess.run(["ruby", "tools/art/tileset_autotiles.rb", str(TILESET_ID), *NAMES], check=True)
    print(f"{OUT} : {len(COPIED) + 3} autotiles HGSS, tileset {TILESET_ID} : {', '.join(NAMES)}")


if __name__ == "__main__":
    main()
