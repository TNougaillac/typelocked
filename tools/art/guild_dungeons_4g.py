"""Tilesets of the guilds' dungeons (TypeLocked, issue #337): the dungeon of a
guild of rooms is grown like a cave (006_Caves.rb, guild_dungeon_floor) and
its walls are drawn by Essentials' dungeon painter with double walls
([33] to [36] in PBS/dungeon_tilesets.txt, DoubleWalls = true). Each tileset
is laid out where that painter looks for its tiles (Tile = 0,walls):
- the back wall: two rows of a wall panel of Mew's Gen 4 Interior Tiles
  (the top row, its frame, above the bottom row, its skirting), on the
  north side of the floor (upper_wall_8 over wall_8, and the inner corners
  of its top row);
- the side and front walls: Mew's grey strip (its pixel profile, 12 px
  wide) along the floor on black, bent around the corners (outer corners
  square, inner corners joined); the outer ring of the double walls is
  black;
- rock (void): black; floor: a floor of Mew (for the swimmers, its light
  stone tinted pool blue); exit: Mew's rug shrunk into one tile, on that
  floor.
Every tile is drawn whole in its 32x32 frame.
Each tileset is a copy of tileset 25 (Cave 4G) with its own graphic, its
walls and rock blocked, its floor and exit walkable.

Source: Graphics/Tilesets/Interior Mew.png (tools/art/interior_mew.py), in
the game. Run from the repository root (Pillow needed):
    python3 tools/art/guild_dungeons_4g.py [preview.png]
"""
import json
import subprocess
import sys
from PIL import Image

MEW = "Graphics/Tilesets/Interior Mew.png"
SOURCE_ID = 25
TILES = 64
# Mew's walls (first row of their 3 rows of panels; column 5 is a panel
# alone) and floors (column, plain on row 1)
WALLS = {"bois": 8, "pierre": 12, "plâtre": 16}
PANEL_COLUMN = 5
MEW_FLOORS = {"planches": 0, "damier": 6, "pierre sombre": 3, "pierre claire": 4}
# The swimmers' floor: the light stone, its grey turned pool blue (times
# its lightness)
POOL_BLUE = (0.62, 0.86, 1.08)
RUG = (3, 36)    # Mew's rug, 3x3 tiles
RUG_SIZE = 26
# Guild headquarters => (tileset ID, name, wall, floor)
STYLES = {
    "contrebande": (33, "Donjon 4G entrepot", "bois", "planches"),
    "chromes": (34, "Donjon 4G repaire", "plâtre", "damier"),
    "nageurs": (35, "Donjon 4G club", "plâtre", "bleu"),
    "temple": (36, "Donjon 4G temple", "pierre", "pierre sombre"),
}
# The painter's tiles (double walls, single tiles: DungeonTileset of
# Essentials, offsets from Tile = 0,walls)
UPPER = {"7": 0, "8": 2, "9": 4, "in_3": 5, "in_1": 6, "in_9": 13, "in_7": 14, "4": 16, "6": 20, "1": 32, "2": 34, "3": 36}
LOWER = {"7": 9, "8": 10, "9": 11, "4": 17, "6": 19, "in_3": 21, "in_1": 22, "1": 25, "2": 26, "3": 27, "in_9": 29,
         "in_7": 30}
VOID, FLOOR, EXIT = 40, 42, 47
BLACK = (0, 0, 0, 255)


def tile(sheet, tx, ty):
    return sheet.crop((tx * 32, ty * 32, tx * 32 + 32, ty * 32 + 32))


def strip_profile(mew):
    """Grey of Mew's left side wall, from the black side to the floor side
    (12 px, on the right of its tile)."""
    left = tile(mew, 6, WALLS["bois"] + 2)
    profile = [left.getpixel((x, 16)) for x in range(20, 32)]
    if any(p[3] < 255 for p in profile) or profile[0] == BLACK:
        sys.exit(f"bande de Mew inattendue : {profile}")
    return profile


def frame(profile, depth):
    """A black tile with the strip drawn where depth(x, y) (pixels from the
    floor side) is under its width."""
    out = Image.new("RGBA", (32, 32), BLACK)
    width = len(profile)
    for y in range(32):
        for x in range(32):
            d = depth(x, y)
            if d is not None and 0 <= d < width:
                out.putpixel((x, y), profile[width - 1 - d])
    return out


def strips(profile):
    """Side and front walls, by the painter's name: the floor east (4), west
    (6), north (2); outer corners (1: floor north-east, 3: north-west);
    inner corners (in_1: floor east and north, in_3: west and north)."""
    w = len(profile)
    return {
        "4": frame(profile, lambda x, y: 31 - x),
        "6": frame(profile, lambda x, y: x),
        "2": frame(profile, lambda x, y: y),
        "1": frame(profile, lambda x, y: max(y, 31 - x) if x >= 32 - w and y < w else None),
        "3": frame(profile, lambda x, y: max(y, x) if x < w and y < w else None),
        "in_1": frame(profile, lambda x, y: min(y, 31 - x)),
        "in_3": frame(profile, lambda x, y: min(y, x)),
    }


def floor_tile(mew, name):
    drawn = tile(mew, MEW_FLOORS["pierre claire" if name == "bleu" else name], 1)
    if drawn.getextrema()[3][0] < 255:
        sys.exit(f"sol {name} troué")
    if name == "bleu":
        pixels = [(min(255, int(l * POOL_BLUE[0])), min(255, int(l * POOL_BLUE[1])), min(255, int(l * POOL_BLUE[2])), 255)
                  for l in drawn.convert("L").get_flattened_data()]
        drawn = Image.new("RGBA", (32, 32))
        drawn.putdata(pixels)
    return drawn


def small_rug(mew):
    """Mew's rug (3x3 tiles) shrunk to a mat inside one tile (RUG_SIZE px)."""
    rx, ry = RUG
    rug = mew.crop((rx * 32, ry * 32, rx * 32 + 96, ry * 32 + 96))
    if not rug.getbbox():
        sys.exit("tapis de Mew vide")
    rug = rug.crop(rug.getbbox()).resize((RUG_SIZE, RUG_SIZE), Image.NEAREST)
    out = Image.new("RGBA", (32, 32))
    out.paste(rug, ((32 - RUG_SIZE) // 2, (32 - RUG_SIZE) // 2))
    return out


def sheet_for(mew, profile, wall, floor_name):
    out = Image.new("RGBA", (256, TILES // 8 * 32))
    put = lambda n, img: out.paste(img, ((n % 8) * 32, (n // 8) * 32))
    black = Image.new("RGBA", (32, 32), BLACK)
    for n in list(UPPER.values()) + list(LOWER.values()) + [VOID]:
        put(n, black)
    top, bottom = tile(mew, PANEL_COLUMN, WALLS[wall]), tile(mew, PANEL_COLUMN, WALLS[wall] + 2)
    for img in (top, bottom):
        if img.getextrema()[3][0] < 255:
            sys.exit(f"mur {wall} troué")
    # The back wall: its top over its bottom, along the floor (its outer
    # corners stay black: the top would start a tile before the bottom)
    for key in ("8", "in_7", "in_9"):
        put(UPPER[key], top)
    for key in ("7", "8", "9"):
        put(LOWER[key], bottom)
    side = strips(profile)
    for key, img in side.items():
        put(LOWER[key], img)
    # Where a side wall meets the back wall of a hall below, it goes on
    # down to the floor (the back wall starts after it)
    put(LOWER["in_7"], side["4"])
    put(LOWER["in_9"], side["6"])
    floor = floor_tile(mew, floor_name)
    put(FLOOR, floor)
    mat = floor.copy()
    mat.alpha_composite(small_rug(mew))
    put(EXIT, mat)
    return out


def main():
    mew = Image.open(MEW).convert("RGBA")
    profile = strip_profile(mew)
    sheets = []
    for kind, (tileset_id, name, wall, floor_name) in STYLES.items():
        out = sheet_for(mew, profile, wall, floor_name)
        out.save(f"Graphics/Tilesets/{name}.png")
        sheets.append(out)
        subprocess.run(["ruby", "tools/art/tileset_clone.rb", str(SOURCE_ID), str(tileset_id), name, name], check=True)
        # Walls and rock blocked, floor and exit walkable, no priority
        passages = {str(n): "=15" for n in list(UPPER.values()) + list(LOWER.values()) + [VOID]}
        passages.update({str(FLOOR): "=0", str(EXIT): "=0"})
        subprocess.run(["ruby", "tools/art/tileset_tables.rb", str(tileset_id), "0", json.dumps(passages)], check=True)
        print(f"{name} ({kind}) : tileset {tileset_id}")
    if len(sys.argv) > 1:
        preview = Image.new("RGBA", (len(sheets) * 266, sheets[0].height), (255, 0, 255, 255))
        for i, s in enumerate(sheets):
            preview.paste(s, (i * 266, 0))
        preview.save(sys.argv[1])


if __name__ == "__main__":
    main()
