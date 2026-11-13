"""Adds the Poachers' thatched hut to the Outside 4G tileset (TypeLocked,
issue #338), from the "Remastered Kanto Johto Map Pack"
(JohtoCompactExterior.png, 32 px tiles, docs/art/inventaire-4g.md): a round
hut of thatch on wooden posts, its door drawn (green), its window on the
right. The sheet packs its drawings tight: a bush in the top row of the
hut's frame (only the pixels joined to the rest of the hut are kept there)
and the hair of a walker below poking into its bottom row, over the hut's
shadow (shadow again, STRAY).

The drawing is whole in its frame: a pixel of the hut on the edge of its
frame that goes on in the tile beyond it stops the script.

Source (docs/CREDITS.md), not in the repository: the pack's
Graphics/Tilesets folder.
Run once from the repository root, after tools/art/buildings2_4g.py (Pillow
needed):
    python3 tools/art/poacher_hut_4g.py "<pack>/Graphics/Tilesets"
Prints the MapGen line of what it adds.
"""
import json
import subprocess
import sys
from PIL import Image

sys.path.insert(0, "tools/art")
from outside_4g import box, building_passages  # noqa: E402

TARGET = "Graphics/Tilesets/Outside 4G.png"
SHEET = "JohtoCompactExterior.png"
TILESET_ID = 24
TILE = 32
SHADOW = (2, 3, 31, 76)   # the sheet's shadow
SYMBOL = "Ҩ"
# The hut's frame in the sheet (x, y, width, height), its block in it (x, y,
# w, h) and its door
FRAME = (4, 112, 4, 5)
BLOCK = (0, 3, 4, 2)
DOOR = (1, 4)
# Box of the frame (x0, y0, x1, y1) drawn by the walker below it
STRAY = (100, 158, 110, 160)


def hut(sheet):
    """The frame's drawing, only what is joined to its body (the rows under
    its top one)."""
    x0, y0, w, h = FRAME
    img = sheet.crop((x0 * TILE, y0 * TILE, (x0 + w) * TILE, (y0 + h) * TILE))
    px = img.load()
    todo = [(x, y) for y in range(TILE, img.height) for x in range(img.width) if px[x, y][3]]
    kept = set(todo)
    while todo:
        x, y = todo.pop()
        for n in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
            if n not in kept and 0 <= n[0] < img.width and 0 <= n[1] < img.height and px[n][3]:
                kept.add(n)
                todo.append(n)
    for y in range(TILE):
        for x in range(img.width):
            if (x, y) not in kept:
                px[x, y] = (0, 0, 0, 0)
    sx0, sy0, sx1, sy1 = STRAY
    for y in range(sy0, sy1):
        for x in range(sx0, sx1):
            px[x, y] = SHADOW
    return img


def check_whole(sheet, img):
    """Stops on a hut that goes on beyond its frame (not its shadow): a solid
    pixel on an edge of the frame next to a solid one of the sheet beyond."""
    x0, y0, w, h = FRAME
    solid = lambda c: c[3] and c != SHADOW  # noqa: E731
    sx, sy = x0 * TILE, y0 * TILE
    edges = [("haut", [(x, 0, x, -1) for x in range(img.width)]),
             ("bas", [(x, img.height - 1, x, img.height) for x in range(img.width)]),
             ("gauche", [(0, y, -1, y) for y in range(img.height)]),
             ("droite", [(img.width - 1, y, img.width, y) for y in range(img.height)])]
    for side, pairs in edges:
        for x, y, bx, by in pairs:
            inside = 0 <= sx + bx < sheet.width and 0 <= sy + by < sheet.height
            if inside and solid(img.getpixel((x, y))) and solid(sheet.getpixel((sx + bx, sy + by))):
                sys.exit(f"hutte de chaume : dessin coupé à {side} ({x}, {y})")
    if any(solid(img.getpixel((x, 0))) for x in range(img.width)):
        sys.exit("hutte de chaume : dessin coupé en haut du cadre")


def main():
    sheet = Image.open(f"{sys.argv[1]}/{SHEET}").convert("RGBA")
    img = hut(sheet)
    check_whole(sheet, img)
    target = Image.open(TARGET).convert("RGBA")
    first = target.height // TILE * 8
    _, _, w, h = FRAME
    bx, by, bw, bh = BLOCK
    out = Image.new("RGBA", (target.width, target.height + h * TILE), (0, 0, 0, 0))
    out.paste(target, (0, 0))
    filled, empty = {}, []
    for dy in range(h):
        for dx in range(w):
            tile = img.crop((dx * TILE, dy * TILE, dx * TILE + TILE, dy * TILE + TILE))
            dest = first + dy * 8 + dx
            inside = bx <= dx < bx + bw and by <= dy < by + bh
            out.paste(tile, box(dest)[:2])
            filled[str(dest)] = building_passages(tile, inside, (dx, dy) == DOOR)
            if not inside and not tile.getbbox():
                empty.append(dy * w + dx)
    for t in range(first, first + h * 8):
        filled.setdefault(str(t), -1)
    out.save(TARGET)
    subprocess.run(["ruby", "tools/art/tileset_tables.rb", str(TILESET_ID), str(h * 8), json.dumps(filled)], check=True)
    halo = f" halo={w}x{h}@{bx},{by}" + ("/" + ",".join(map(str, empty)) if empty else "")
    print(f"{SYMBOL} = T{first + by * 8 + bx} {bw}x{bh}{halo}   # hutte de chaume (camp des braconniers ; porte "
          f"{DOOR[0] - bx},{DOOR[1] - by} de la brique)")


if __name__ == "__main__":
    main()
