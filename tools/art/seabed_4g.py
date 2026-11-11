"""Seabed 4G tileset (#203): « Underwater » (tileset 22) with its floor and
its rock redrawn from the HGSS cave of the Remastered Kanto Johto Map Pack
(Caves.png, see docs/CREDITS.md), tinted blue under the water: the 4G games
have no diving, so no pack draws a seabed.

Since #262, Graphics/Tilesets/Underwater.png and tileset 22 are no longer in
the game: this script records how Underwater 4G was built and cannot be run
again from scratch.

- floor (T0-T3, T8, T9): the pack's pale sand, its plain middle tile;
- rock (terrain R, T35-T53): the 3x3 rock mound (its corners, sides and
  middle) over the sand; the inner corners take the middle.
The seaweed autotiles get the 4G sand behind them (« Seaweed dark 4G »,
« Seaweed light 4G »): their purple floor, and its shadow, become the 4G
floor, and its shadow.

    python3 tools/art/seabed_4g.py "<Remastered Kanto Johto Map Pack folder>"

Then: ruby tools/art/tileset_clone.rb 22 27 "Underwater 4G" "Underwater 4G"
      ruby tools/art/tileset_autotiles.rb 27 "Underwater dark" "" "Seaweed dark 4G" "Seaweed light 4G" "" "" ""
"""
import sys
from pathlib import Path

from PIL import Image

T = 32
SOURCE = Path("Graphics/Tilesets/Underwater.png")
TARGET = Path("Graphics/Tilesets/Underwater 4G.png")
SAND = (4, 39)   # the middle of the pale sand patch
MOUND = {"NW": (0, 49), "N": (1, 49), "NE": (2, 49), "W": (0, 50), "C": (1, 50), "E": (2, 50),
         "SW": (0, 51), "S": (1, 51), "SE": (2, 51)}
# Tile of Underwater => tile of Caves.png
LAYOUT = {
    0: SAND, 1: SAND, 2: SAND, 3: SAND, 8: SAND, 9: SAND,
    44: MOUND["C"], 36: MOUND["N"], 52: MOUND["S"], 43: MOUND["W"], 45: MOUND["E"],
    35: MOUND["NW"], 37: MOUND["NE"], 51: MOUND["SW"], 53: MOUND["SE"],
    47: MOUND["C"], 46: MOUND["C"], 39: MOUND["C"], 38: MOUND["C"],
}


MAGENTA = (255, 0, 255)


def cut(caves, cx, cy):
    """A tile of Caves.png, its magenta background transparent."""
    tile = caves.crop((cx * T, cy * T, cx * T + T, cy * T + T))
    px = tile.load()
    for y in range(T):
        for x in range(T):
            if px[x, y][:3] == MAGENTA:
                px[x, y] = (0, 0, 0, 0)
    return tile


def underwater(tile):
    """The tile seen under the sea: darker, bluer."""
    out = tile.copy()
    px = out.load()
    for y in range(T):
        for x in range(T):
            r, g, b, a = px[x, y]
            if a:
                px[x, y] = (int(r * 0.35), int(g * 0.5 + 10), min(255, int(b * 0.6 + 90)), a)
    return out


# Seaweed autotile => its floor colours and their shadows (3G purples)
SEAWEEDS = {
    "Seaweed dark": ({(88, 48, 176)}, {(72, 32, 152), (40, 8, 136)}),
    "Seaweed light": ({(112, 72, 200)}, {(80, 40, 184), (56, 16, 160)}),
}
SHADOW = 0.75


def seaweed(name, floor):
    image = Image.open(Path("Graphics/Autotiles") / f"{name}.png").convert("RGBA")
    px = image.load()
    fl = floor.load()
    plain, shade = SEAWEEDS[name]
    for y in range(image.height):
        for x in range(image.width):
            c = px[x, y][:3]
            if c in plain or c in shade:
                r, g, b, a = fl[x % T, y % T]
                k = SHADOW if c in shade else 1
                px[x, y] = (int(r * k), int(g * k), int(b * k), 255)
    image.save(Path("Graphics/Autotiles") / f"{name} 4G.png")


def main():
    caves = Image.open(Path(sys.argv[1]) / "Graphics/Tilesets/Caves.png").convert("RGBA")
    out = Image.open(SOURCE).convert("RGBA")
    sand = cut(caves, *SAND)
    for index, (cx, cy) in LAYOUT.items():
        # Over the sand, so that the rock's corners show the floor
        tile = sand.copy()
        rock = cut(caves, cx, cy)
        tile.paste(rock, (0, 0), rock)
        tile = underwater(tile)
        x, y = (index % 8) * T, (index // 8) * T
        out.paste((0, 0, 0, 0), (x, y, x + T, y + T))
        out.paste(tile, (x, y), tile)
    out.save(TARGET)
    floor = underwater(sand)
    for name in SEAWEEDS:
        seaweed(name, floor)
    print(f"{TARGET} : {len(LAYOUT)} tuiles, {len(SEAWEEDS)} autotiles d'algues")


if __name__ == "__main__":
    main()
