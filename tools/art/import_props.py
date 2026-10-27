"""Decor objects taken from free fan tilesets (TypeLocked, issue #110).

Copies objects of two packs (see docs/CREDITS.md) below
Graphics/Tilesets/Outside.png and gives them their passages and priorities in Data/Tilesets.rxdata (via
tools/art/tileset_tables.rb):
- Emerald Outdoor (glassbetelgeuse, from Heartlessdragoon's rips):
  Graphics/Tilesets/Outside E.png
- KingTapir Tilesets (KingTapir, NocTurn): KingTapirSandstreamDesert.png,
  KingTapirAlolaMisc.png (their opaque grey shadows become see-through)

The packs are not in the repository. Run once from the repository root, with
the folder of each unpacked pack (Pillow needed):
    python3 tools/art/import_props.py "<Emerald Outdoor>" "<KingTapirTilesets>"
    python3 tools/art/import_props.py ... --preview out.png   # only draws them
It prints the tile number of each object, used by [Legend] and [Objects] of
MapProc/route.txt and MapProc/ville.txt. Running it again appends again:
restore the two files from git first.
"""
import json
import os
import subprocess
import sys
from PIL import Image

TILESET = "Graphics/Tilesets/Outside.png"
BLOCK, WALK, TALL = 475, -1, 420   # source tiles of the passages/priorities
KT_SHADOW = (120, 120, 120, 255)
SHADOW = (24, 32, 24, 70)
TRIM_TOP = {"aiguille rouge": 1}   # pixel rows of another tile above the object

# name, pack, first tile, width, height, passages:
#   block: every tile blocks; walk: none; tall: the bottom row blocks, the
#   rows above are passable and drawn over the player; tree: tall, but only
#   the middle column of the bottom row blocks (trunk, pole)
PROPS = [
    ("poterie brune", "E", 798, 1, 1, "block"),
    ("poterie orange", "E", 799, 1, 1, "block"),
    ("poterie verte", "E", 806, 1, 1, "block"),
    ("poterie rouge", "E", 807, 1, 1, "block"),
    ("caisses", "E", 811, 1, 1, "block"),
    ("caisse", "E", 812, 1, 1, "block"),
    ("jardinière de légumes", "E", 810, 1, 1, "block"),
    ("pot de fleurs blanches", "E", 813, 1, 1, "block"),
    ("pot de fleurs rouges", "E", 821, 1, 1, "block"),
    ("pot de fleurs jaunes", "E", 822, 1, 1, "block"),
    ("bac de fleurs", "E", 815, 1, 1, "block"),
    ("rocher moussu", "E", 646, 1, 1, "block"),
    ("rocher moussu rond", "E", 647, 1, 1, "block"),
    ("rocher blanc", "E", 702, 1, 1, "block"),
    ("rocher rouge", "E", 727, 1, 1, "block"),
    ("rocher rose", "E", 623, 1, 1, "block"),
    ("touffe sèche", "KS", 9, 1, 1, "walk"),
    ("buisson tropical", "KA", 51, 1, 1, "block"),
    ("buisson tropical fleuri", "KA", 52, 1, 1, "block"),
    ("buisson bleu", "KA", 115, 1, 1, "block"),
    ("caisses empilées", "E", 796, 1, 2, "tall"),
    ("long bac de fleurs", "E", 823, 1, 2, "block"),
    ("tas de bûches", "E", 996, 3, 1, "block"),
    ("rondins", "E", 999, 1, 3, "block"),
    ("arbre en fleurs", "E", 440, 2, 2, "tall"),
    ("arbre en fleurs étroit", "E", 434, 1, 3, "tall"),
    ("petit arbre en fleurs", "E", 464, 2, 2, "tall"),
    ("acacia", "E", 460, 2, 2, "tall"),
    ("parasol bleu", "E", 2214, 2, 2, "tall"),
    ("parasol orange", "E", 2238, 2, 2, "tall"),
    ("parasol vert", "E", 2262, 2, 2, "tall"),
    ("cactus tonneau", "KS", 16, 1, 2, "tall"),
    ("cactus fleuri", "KS", 17, 1, 2, "tall"),
    ("touffe sèche large", "KS", 11, 2, 1, "walk"),
    ("aiguille de grès", "KS", 5, 1, 2, "tall"),
    ("aiguille de grès fine", "KS", 6, 1, 2, "tall"),
    ("grand palmier", "KA", 0, 3, 5, "tree"),
    ("palmier", "KA", 3, 3, 4, "tree"),
    ("petit palmier", "KA", 36, 2, 2, "tall"),
    ("palmier bas", "KA", 40, 3, 3, "tree"),
    ("grand palmier bleu", "KA", 64, 3, 5, "tree"),
    ("petit palmier bleu", "KA", 100, 2, 2, "tall"),
    ("gros rocher brun", "KA", 131, 2, 2, "block"),
    ("gros rocher brun bas", "KA", 155, 2, 2, "block"),
    ("tiki", "KA", 382, 1, 2, "tall"),
    ("tiki sombre", "KA", 398, 1, 2, "tall"),
    ("parasol de plage", "KA", 413, 3, 3, "tree"),
    ("brouette", "KA", 453, 3, 1, "block"),
    ("caisse en bois", "KA", 110, 2, 2, "block"),
    # Trees and mounds for the ambiances (#162)
    ("grand arbre rond", "E", 408, 3, 3, "tree"),
    ("sapin", "E", 419, 2, 2, "tall"),
    ("arbre touffu", "E", 435, 2, 3, "tall"),
    ("aiguille rouge", "E", 725, 2, 3, "tall"),
]


def sources(emerald, kingtapir):
    return {
        "E": os.path.join(emerald, "Graphics", "Tilesets", "Outside E.png"),
        "KS": os.path.join(kingtapir, "KingTapirSandstreamDesert.png"),
        "KA": os.path.join(kingtapir, "KingTapirAlolaMisc.png"),
    }


def crop(im, tile, w, h, pack):
    x, y = (tile % 8) * 32, (tile // 8) * 32
    part = im.crop((x, y, x + w * 32, y + h * 32))
    if pack.startswith("K"):
        px = part.load()
        for j in range(part.height):
            for i in range(part.width):
                if px[i, j] == KT_SHADOW:
                    px[i, j] = SHADOW
    return part


def passage(kind, dx, dy, w, h):
    if kind == "walk":
        return WALK
    if kind == "block" or dy == h - 1 and (kind == "tall" or dx == w // 2):
        return BLOCK
    return TALL if dy < h - 1 else WALK


def layout():
    """First free spot of each object on a grid 8 tiles wide (rows from 0)."""
    taken = set()
    spots = []
    for _name, _pack, _tile, w, h, _kind in PROPS:
        i = 0
        while True:
            col, row = i % 8, i // 8
            cells = {(col + dx, row + dy) for dx in range(w) for dy in range(h)}
            if col + w <= 8 and not cells & taken:
                taken |= cells
                spots.append((col, row))
                break
            i += 1
    return spots, max(r for _c, r in taken) + 1


def main():
    args = [a for a in sys.argv[1:] if a != "--preview"]
    preview = args[2] if "--preview" in sys.argv else None
    images = {k: Image.open(v).convert("RGBA") for k, v in sources(args[0], args[1]).items()}
    spots, rows = layout()
    sheet = Image.new("RGBA", (256, rows * 32), (0, 0, 0, 0))
    for (name, pack, tile, w, h, _kind), (col, row) in zip(PROPS, spots):
        part = crop(images[pack], tile, w, h, pack)
        part.paste((0, 0, 0, 0), (0, 0, w * 32, TRIM_TOP.get(name, 0)))
        sheet.alpha_composite(part, (col * 32, row * 32))
    if preview:
        sheet.save(preview)
        return
    im = Image.open(TILESET).convert("RGBA")
    first = (im.height // 32) * 8
    out = Image.new("RGBA", (256, im.height + rows * 32), (0, 0, 0, 0))
    out.paste(im, (0, 0))
    out.paste(sheet, (0, im.height))
    copies, result = {}, {}
    for (name, _pack, _tile, w, h, kind), (col, row) in zip(PROPS, spots):
        result[name] = first + row * 8 + col
        for dy in range(h):
            for dx in range(w):
                copies[first + (row + dy) * 8 + col + dx] = passage(kind, dx, dy, w, h)
    out.save(TILESET)
    subprocess.run(["ruby", "tools/art/tileset_tables.rb", "1", str(rows * 8),
                    json.dumps({str(k): v for k, v in copies.items()})], check=True)
    print(json.dumps(result, ensure_ascii=False, indent=1))


if __name__ == "__main__":
    main()
