"""Side stairs of the Outside tileset (TypeLocked, MapProc towns in terraces).

Essentials' Outside tileset only has stairs climbing north (T769 T770 over
T777 T778). This script appends, below the tileset, one row of stairs
climbing east or west: those four tiles turned a quarter (the steps run north
to south, the shadow stays at the bottom), 2 tiles wide, for a street that
crosses the cut side of a terrace. The new tiles get the passages,
priorities and terrain tags of their source in Data/Tilesets.rxdata (via
tools/art/tileset_tables.rb).

Run once from the repository root (Pillow needed):
    python3 tools/art/side_stairs.py
It prints the new tile numbers, used by « EscalierLateral » in
MapProc/ville.txt. Running it again appends again: restore the two files
from git first.
"""
import json
import subprocess
from PIL import Image

TILESET = "Graphics/Tilesets/Outside.png"
# The stairs climbing north: top row, bottom row (left column shaded)
NORTH = [[769, 770], [777, 778]]


def box(i):
    return ((i % 8) * 32, (i // 8) * 32, (i % 8) * 32 + 32, (i // 8) * 32 + 32)


def main():
    im = Image.open(TILESET).convert("RGBA")
    first = (im.height // 32) * 8
    block = Image.new("RGBA", (64, 64))
    for y, row in enumerate(NORTH):
        for x, tile in enumerate(row):
            block.paste(im.crop(box(tile)), (x * 32, y * 32))
    # Climbing west (the high side west): the top steps go to the west column
    west = block.rotate(90)
    east = west.transpose(Image.FLIP_LEFT_RIGHT)
    out = Image.new("RGBA", (im.width, im.height + 64))
    out.paste(im, (0, 0))
    copies = {}
    result = {}
    # Each: high column, low column, top then bottom row
    for k, (name, stairs, high) in enumerate([("est", east, 1), ("ouest", west, 0)]):
        result[name] = []
        for col in (high, 1 - high):
            for row in range(2):
                d = first + row * 8 + k * 2 + (0 if col == high else 1)
                out.paste(stairs.crop((col * 32, row * 32, col * 32 + 32, row * 32 + 32)), box(d)[:2])
                copies[d] = NORTH[1][0] if row == 1 else NORTH[0][1]
                result[name].append(d)
    out.save(TILESET)
    subprocess.run(["ruby", "tools/art/tileset_tables.rb", str(1), str(16),
                    json.dumps({str(k): v for k, v in copies.items()})], check=True)
    print(json.dumps(result, ensure_ascii=False))


if __name__ == "__main__":
    main()
