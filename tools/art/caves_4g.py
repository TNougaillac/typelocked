"""HGSS cave tileset of the generated caves (TypeLocked, issues #198, #177).

Builds Graphics/Tilesets/Cave 4G.png and its sand autotile from the brown
cave of the "Remastered Kanto Johto Map Pack" (Caves.png, see
docs/CREDITS.md, sources not in the repository). The tileset is laid out like
Dungeon cave (tileset 7), so that Essentials' dungeon painter finds every wall
where PBS/dungeon_tilesets.txt says ([25], DoubleWalls):
- the walls are the edges of the pack's rock (its brown mound and the ring
  around a hollow), whole tiles: the 2 rows of rock face on the north side of
  a gallery, the rim of the rock on its other sides, the mound's corners
  where the rock juts out;
- the rock top (void) is the pack's rock texture; where an edge tile shows
  floor on its outer side (the ring is drawn to lie over rock), that side is
  filled with the rock texture (the only touch-up: no tile is cropped);
- floor: the brown floor (the middle of its patch); ladder: the pack's hole with its ladder.
- HGSS Cave sand (autotile, floor patches): the pack's pale sand patch (3x3)
  and its copy with a hole, made into an RPG Maker XP autotile, over the
  brown floor.
Then copies tileset 7 (passages kept: same layout) to ID 25 and names its
autotile (tools/art/tileset_clone.rb, tools/art/tileset_autotiles.rb).

Run from the repository root with the extracted pack's folder (Pillow needed):
    python3 tools/art/caves_4g.py "<Remastered Kanto Johto Map Pack folder>"
"""
import subprocess
import sys
from PIL import Image

TILESET_ID = 25
SOURCE_ID = 7
NAME = "Cave 4G"
SAND = "HGSS Cave sand"
TILES = 64
FLOOR = (1, 37)
VOID = (1, 50)   # the mound's middle: the one rock tile that repeats without seams
# Tile of Cave 4G => (column, row) in Caves.png, and the sides whose
# see-through pixels are rock (filled with VOID): t(op) b(ottom) l(eft) r(ight)
LAYOUT = {
    # Upper walls (DoubleWalls): the top row of the north face, rock elsewhere
    0: ((2, 52), "t"), 2: ((0, 52), ""), 4: ((6, 52), "t"),
    5: (VOID, ""), 6: (VOID, ""), 13: ((0, 52), ""), 14: ((1, 52), ""),
    16: (VOID, ""), 20: (VOID, ""), 32: (VOID, ""), 34: (VOID, ""), 36: (VOID, ""),
    # Walls next to the floor
    9: ((2, 53), "l"), 10: ((0, 53), ""), 11: ((6, 53), "r"),
    17: ((3, 53), "l"), 19: ((5, 53), "r"),
    25: ((3, 54), "lb"), 26: ((4, 54), "b"), 27: ((5, 54), "rb"),
    21: ((0, 49), ""), 22: ((2, 49), ""), 29: ((0, 51), ""), 30: ((2, 51), ""),
    # Rock top, its variant, floor, ladder
    40: (VOID, ""), 41: ((4, 50), ""), 42: (FLOOR, ""), 47: ((4, 53), ""),
}
# The sand patch (3x3) and its copy with a hole (2x2)
SAND_BLOB = (3, 38)
SAND_HOLE = (6, 38)


def tile(sheet, tx, ty):
    return sheet.crop((tx * 32, ty * 32, tx * 32 + 32, ty * 32 + 32))


def fill_sides(im, rock, sides):
    """See-through pixels reached from the given sides become rock."""
    px, rk = im.load(), rock.load()
    stack = []
    for x in range(32):
        if "t" in sides:
            stack.append((x, 0))
        if "b" in sides:
            stack.append((x, 31))
    for y in range(32):
        if "l" in sides:
            stack.append((0, y))
        if "r" in sides:
            stack.append((31, y))
    seen = set()
    while stack:
        x, y = stack.pop()
        if (x, y) in seen or not (0 <= x < 32 and 0 <= y < 32) or px[x, y][3] != 0:
            continue
        seen.add((x, y))
        px[x, y] = rk[x, y]
        stack += [(x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)]
    return im


def blob_autotile(sheet):
    """RPG Maker XP autotile (96x128): the 3x3 patch, the inner corners from
    the quarters of the copy with a hole that touch the hole, the lone tile
    from the patch's 4 corners. Drawn over the floor (it replaces it)."""
    out = Image.new("RGBA", (96, 128))
    bx, by = SAND_BLOB
    hx, hy = SAND_HOLE
    for y in range(3):
        for x in range(3):
            out.paste(tile(sheet, bx + x, by + y), (x * 32, 32 + y * 32))
    for qx in (0, 1):
        for qy in (0, 1):
            hole = tile(sheet, hx + 1 - qx, hy + 1 - qy)
            out.paste(hole.crop((qx * 16, qy * 16, qx * 16 + 16, qy * 16 + 16)), (64 + qx * 16, qy * 16))
            corner = out.crop((qx * 64, 32 + qy * 64, qx * 64 + 32, 64 + qy * 64))
            out.paste(corner.crop((qx * 16, qy * 16, qx * 16 + 16, qy * 16 + 16)), (qx * 16, qy * 16))
    floor = tile(sheet, *FLOOR)
    for y in range(0, 128, 32):
        for x in range(0, 96, 32):
            under = floor.copy()
            under.alpha_composite(out.crop((x, y, x + 32, y + 32)))
            out.paste(under, (x, y))
    return out


def main():
    sheet = Image.open(f"{sys.argv[1]}/Graphics/Tilesets/Caves.png").convert("RGBA")
    rock = tile(sheet, *VOID)
    out = Image.new("RGBA", (256, TILES // 8 * 32))
    for n, ((tx, ty), sides) in LAYOUT.items():
        out.paste(fill_sides(tile(sheet, tx, ty), rock, sides), ((n % 8) * 32, (n // 8) * 32))
    out.save(f"Graphics/Tilesets/{NAME}.png")
    blob_autotile(sheet).save(f"Graphics/Autotiles/{SAND}.png")
    subprocess.run(["ruby", "tools/art/tileset_clone.rb", str(SOURCE_ID), str(TILESET_ID), NAME, NAME], check=True)
    subprocess.run(["ruby", "tools/art/tileset_autotiles.rb", str(TILESET_ID), SAND, "", "", "", "", "", ""], check=True)
    print(f"{NAME} : {len(LAYOUT)} tuiles, autotile {SAND}")


if __name__ == "__main__":
    main()
