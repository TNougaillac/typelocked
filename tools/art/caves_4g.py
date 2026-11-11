"""HGSS cave tileset of the generated caves (TypeLocked, issues #198, #177).

Builds Graphics/Tilesets/Cave 4G.png and its sand autotile from the brown
cave of the "Remastered Kanto Johto Map Pack" (Caves.png, see
docs/CREDITS.md, sources not in the repository). The tileset is laid out like
the walls of Essentials' dungeon painter ([25] in PBS/dungeon_tilesets.txt,
single walls), with the pack's tiles where its own brown cave puts them:
- the walls are the edges of its rock mound, whole tiles: the dark face on
  the north side of a gallery, the rounded top on its south side, the sides,
  the mound's corners where the rock juts out, and the 4 corner tiles the
  pack uses where the rock goes round a corner of the floor;
- the rock top (void): the mound's middle; floor: the brown floor (the
  middle of its patch); ladder: the pack's hole with its ladder;
- HGSS Cave sand (autotile, floor patches): the pack's pale sand patch (3x3)
  and its copy with a hole, made into an RPG Maker XP autotile, over the
  brown floor.
Then copies tileset 7 (passages kept: walls, rock, floor and ladder are at the
same places) to ID 25 and names its autotile (tools/art/tileset_clone.rb,
tools/art/tileset_autotiles.rb).

Since #262, tileset 7 (Dungeon cave) is no longer in the game: this script
records how Cave 4G was built and cannot be run again from scratch.

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
# Tile of Cave 4G => (column, row) in Caves.png. Walls (single, the painter's
# numbers): 0-2 north (7 8 9), 3 4 jutting top corners (in_3 in_1), 8 10
# sides (4 6), 11 12 jutting bottom corners (in_9 in_7), 16-18 south (1 2 3)
LAYOUT = {
    0: (0, 52), 1: (1, 51), 2: (1, 52),
    3: (0, 49), 4: (2, 49),
    8: (2, 50), 10: (0, 50), 11: (0, 51), 12: (2, 51),
    16: (6, 49), 17: (1, 49), 18: (7, 49),
    # Rock top, its variant, floor, ladder
    40: VOID, 41: (4, 50), 42: FLOOR, 47: (4, 53),
}
# The sand patch (3x3) and its copy with a hole (2x2)
SAND_BLOB = (3, 38)
SAND_HOLE = (6, 38)


def tile(sheet, tx, ty):
    return sheet.crop((tx * 32, ty * 32, tx * 32 + 32, ty * 32 + 32))


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
    out = Image.new("RGBA", (256, TILES // 8 * 32))
    for n, (tx, ty) in LAYOUT.items():
        out.paste(tile(sheet, tx, ty), ((n % 8) * 32, (n // 8) * 32))
    out.save(f"Graphics/Tilesets/{NAME}.png")
    blob_autotile(sheet).save(f"Graphics/Autotiles/{SAND}.png")
    subprocess.run(["ruby", "tools/art/tileset_clone.rb", str(SOURCE_ID), str(TILESET_ID), NAME, NAME], check=True)
    subprocess.run(["ruby", "tools/art/tileset_autotiles.rb", str(TILESET_ID), SAND, "", "", "", "", "", ""], check=True)
    print(f"{NAME} : {len(LAYOUT)} tuiles, autotile {SAND}")


if __name__ == "__main__":
    main()
