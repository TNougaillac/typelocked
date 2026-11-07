"""Interior 4G tileset (#194): « Interior general » (tileset 3, the houses,
flats, warehouses and lab of the generated worlds) with its floors redrawn
with the floors of Mew's Gen 4 Interior Tiles (see docs/CREDITS.md).

Each floor of Essentials is a block of tiles: the plain floor and its
variants shaded by the walls and furniture. Every tile of the block becomes
the plain Mew floor (its row 1), darkened where the Essentials tile is
darker than the plain one at the same pixel: the shadows stay where they
were. Walls and furniture are kept (Mew's pack has few of them).

    python3 tools/art/interiors_4g.py "<Mew's Gen 4 Interior Tiles.png>"

Then: ruby tools/art/tileset_clone.rb 3 26 "Interior 4G" "Interior 4G"
"""
import sys
from pathlib import Path

from PIL import Image

T = 32
SOURCE = Path("Graphics/Tilesets/Interior general.png")
TARGET = Path("Graphics/Tilesets/Interior 4G.png")
# Floor block of Essentials (first row, last row, first column, last column)
# => column of Mew's floor (row 1 is plain): 0 wood planks, 1 wood bricks,
# 2 wood squares, 3 dark stone, 4 light stone, 5 beige stone, 6 checker,
# 7 carpet.
FLOORS = {
    (25, 29, 0, 7): 4,   # grey squares -> light stone
    (30, 34, 0, 7): 5,   # white diagonal tiles -> beige stone
    (35, 38, 0, 7): 6,   # blue tiles -> checker
    (39, 42, 0, 7): 2,   # orange -> wood squares
    (43, 46, 0, 7): 7,   # pink -> carpet
    (47, 49, 0, 7): 0,   # parquet -> wood planks
    (80, 82, 0, 3): 4,   # white and blue tiles -> light stone
    (83, 86, 0, 3): 1,   # wood -> wood bricks
    (83, 86, 4, 7): 5,   # yellow tiles -> beige stone
}
SHADE_MIN = 0.45


def lum(p):
    return 0.299 * p[0] + 0.587 * p[1] + 0.114 * p[2]


def main():
    mew = Image.open(sys.argv[1]).convert("RGBA")
    out = Image.open(SOURCE).convert("RGBA")
    src = out.copy().load()
    dst = out.load()
    for (r0, r1, c0, c1), col in FLOORS.items():
        plain = mew.crop((col * T, T, col * T + T, 2 * T)).load()
        tiles = [(r, c) for r in range(r0, r1 + 1) for c in range(c0, c1 + 1)
                 if src[c * T, r * T][3] or src[c * T + T - 1, r * T + T - 1][3]]
        # The brightest value of each pixel among the tiles of the same
        # parity: the floor without shadow (patterns of 1 or 2 tiles)
        top = {}
        for r, c in tiles:
            key = (r % 2, c % 2)
            for y in range(T):
                for x in range(T):
                    v = lum(src[c * T + x, r * T + y])
                    if v > top.get((key, x, y), 0):
                        top[(key, x, y)] = v
        for r, c in tiles:
            key = (r % 2, c % 2)
            for y in range(T):
                for x in range(T):
                    a = src[c * T + x, r * T + y]
                    if not a[3]:
                        continue
                    shade = max(SHADE_MIN, min(1.0, lum(a) / max(1, top[(key, x, y)])))
                    p = plain[x, y]
                    dst[c * T + x, r * T + y] = (int(p[0] * shade), int(p[1] * shade), int(p[2] * shade), 255)
    out.save(TARGET)
    print(f"{TARGET} : {len(FLOORS)} sols")


if __name__ == "__main__":
    main()
