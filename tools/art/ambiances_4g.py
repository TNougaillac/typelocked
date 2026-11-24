"""Adds the grounds, reliefs and props of the ambiances to the Outside 4G
tileset (TypeLocked, issue #295): 4G tiles that MapProc did not draw yet
(docs/art/inventaire-4g.md), each reserved to its ambiance by its bricks.

- Patches (MapGen [Terrains], the 13 roles of STREET_ROLES: edges from the
  full patch, inner corners from the patch with a hole), laid on their
  ambiance's ground: dark dirt (the path of the autumn), dead leaves and
  ochre earth (autumn), undergrowth (tall grass) and moss (dark forest), red
  earth and dried mud (volcano).
- A mossy bank around a patch of grass (marsh), its 8 edges only.
- Plateaux (5 rows of 8, like CLIFFS in outside_4g.py), on their ambiance's
  ground: red earth over brown rock (the volcano's massifs), sand over brown
  rock (the beach's levels), sand over grey rock (the beach's massifs).
- Props, whole: red autumn tree, dead stumps, driftwood, beach plants, and a
  fern of the DPPt Eterna Forest (its DS grass see-through).

Sources (docs/CREDITS.md), not in the repository: SirMalo's NatureRMXP.png
and the DPPt Exterior Ground Tiles (Platinum/Eterna Forest Set.png).
Run once from the repository root, after tools/art/replace_non4g.py (Pillow
needed):
    python3 tools/art/ambiances_4g.py "<SirMalo folder>" "<Eterna Forest Set.png>"
Prints the MapGen lines of what it adds.
"""
import json
import subprocess
import sys
from PIL import Image

sys.path.insert(0, "tools/art")
from outside_4g import (SHEETS, STREET_ROLES, CLIFF_ROWS, box, sheet_tile, on_ground,  # noqa: E402
                        cliff_passages, cliff_line)

TARGET = "Graphics/Tilesets/Outside 4G.png"
TILESET_ID = 24
TILE = 32
TALL = 420   # passages of a halo tile: walkable, drawn over the player
SOLID = 428  # passages of a tree tile: blocked
WALK = "=0"
TALL_GRASS = "=64/2"   # bush flag, Grass terrain tag (the marsh grass's)
GRASS, ASH, SAND = 1, 14968, 162   # the grounds they are laid on

# Patches: name => (Nature column, full patch x, y, middle x, y, patch with a
# hole x, y, ground, passages)
PATCHES = {
    "terre sombre": (0, 0, 48, 1, 49, 4, 48, GRASS, WALK),
    "feuilles mortes": (0, 0, 53, 1, 54, 4, 53, GRASS, WALK),
    "terre ocre": (1, 0, 1, 1, 3, 4, 1, GRASS, WALK),
    "sous-bois": (1, 0, 6, 1, 7, 4, 6, GRASS, TALL_GRASS),
    "mousse": (1, 0, 16, 1, 17, 4, 16, GRASS, WALK),
    "terre rouge": (1, 0, 28, 1, 29, 4, 28, ASH, WALK),
    # Dried mud on red clay: its hole is in the full patch; the clay around
    # it takes the red earth's colour (it is laid inside a patch of it)
    "boue séchée": (1, 0, 54, 1, 55, 0, 54, None, WALK),
}
CLAY = {(176, 136, 120, 255): (168, 120, 112, 255)}
# The mossy bank (Nature column 7): role => x, y; its middle is the grass
BANK = {"N": (1, 41), "S": (1, 43), "W": (0, 42), "E": (3, 42),
        "NW": (0, 41), "NE": (3, 41), "SW": (0, 43), "SE": (3, 43)}
# Plateaux: name => (Nature column, first row, ground, top retextured)
# (the beach's levels and massifs: their sand top is darker than the beach's
# sand; its colours take the beach's, by place, so that a level's top, the
# ground itself, joins its rims)
PLATEAUX = {"volcan (massifs)": (5, 40, ASH, False), "plage (niveaux)": (7, 0, SAND, True),
            "plage (massifs)": (8, 0, SAND, True)}
# Props: name => (source, x, y, width, height in tiles, block x, y, w, h)
# (source: Nature column, or "E" the Eterna Forest set; 16 px tiles)
PROPS = {
    "arbre rouge": (3, 4, 40, 4, 4, 0, 1, 3, 3),
    "souche": (3, 4, 45, 2, 3, 0, 1, 2, 2),
    "souche boueuse": (3, 6, 44, 2, 2, 0, 1, 2, 1),
    "souche aux feuilles": (3, 6, 46, 2, 2, 0, 1, 2, 1),
    "bois flotté": (4, 1, 56, 2, 1, 0, 0, 2, 1),
    "bois flotté long": (4, 3, 56, 2, 1, 0, 0, 2, 1),
    "plante de plage": (4, 1, 57, 2, 2, 0, 0, 2, 2),
    "fougère": ("E", 10, 8, 2, 2, 0, 0, 2, 2),
}
# Small beach plants, one tile each (MapGen [Legend], over the ground)
PLANTS = [(4, 3, 57), (4, 4, 57), (4, 5, 57), (4, 6, 57)]
ETERNA_GRASS = (64, 216, 80, 255)


def water_to_sand(tile, sand):
    """The blue water of a beach drawing (driftwood, plants floating) the
    sand darkened, so that it lies on the beach."""
    tile = tile.copy()
    px, s = tile.load(), sand.load()
    for y in range(TILE):
        for x in range(TILE):
            r, g, b, a = px[x, y]
            if a and b > r + 60 and b > g + 40:
                k = 0.85
                px[x, y] = tuple(int(v * k) for v in s[x, y][:3]) + (255,)
    return tile


def retexture(tile, colours, ground):
    """The pixels of the tile in `colours` the ground's, by place."""
    tile = tile.copy()
    px, g = tile.load(), ground.load()
    for y in range(TILE):
        for x in range(TILE):
            if px[x, y] in colours:
                px[x, y] = g[x, y]
    return tile


def eterna_tile(eterna, tx, ty):
    im = eterna.crop((tx * 16, ty * 16, tx * 16 + 16, ty * 16 + 16))
    im.putdata([(0, 0, 0, 0) if c == ETERNA_GRASS else c for c in im.get_flattened_data()])
    return im.resize((TILE, TILE), Image.NEAREST)


def laid(drawing, ground):
    """A drawing of the Nature sheet on a ground: its grass the ground."""
    tile = ground.copy()
    tile.alpha_composite(on_ground(drawing, ground, True) if ground is not None else drawing)
    return tile


def main():
    folder, eterna_path = sys.argv[1], sys.argv[2]
    sheets = {k: Image.open(f"{folder}/{name}").convert("RGBA") for k, name in SHEETS.items()}
    eterna = Image.open(eterna_path).convert("RGBA")
    sheet = Image.open(TARGET).convert("RGBA")
    grounds = {g: sheet.crop(box(g)) for g in (GRASS, ASH, SAND)}
    first = sheet.height // TILE * 8
    tiles, copies, lines = {}, {}, []
    at = first

    # Patches, 16 tiles each (13 roles)
    for name, (col, ox, oy, cx, cy, hx, hy, ground, passages) in PATCHES.items():
        ids = []
        for i, (role, dx, dy, part) in enumerate(STREET_ROLES):
            src = (cx, cy) if part is None else (ox + dx, oy + dy) if part == "o" else (hx + dx, hy + dy)
            drawing = sheet_tile(sheets, ("N", col) + src)
            if ground is None:
                drawing.putdata([CLAY.get(c, c) for c in drawing.get_flattened_data()])
                tiles[at + i] = drawing
            else:
                tiles[at + i] = laid(drawing, grounds[ground])
            copies[at + i] = passages
            ids.append(f"{role}=T{at + i}" if role else f"T{at + i}")
        lines.append(f"{name} : " + " ".join(ids))
        at += 16

    # Mossy bank, 8 tiles
    ids = [f"T{GRASS}"]
    for i, (role, (x, y)) in enumerate(BANK.items()):
        tiles[at + i] = laid(sheet_tile(sheets, ("N", 7, x, y)), grounds[GRASS])
        copies[at + i] = WALK
        ids.append(f"{role}=T{at + i}")
    lines.append("berge moussue : " + " ".join(ids))
    at += 8

    # Plateaux
    for name, (col, row, ground, retextured) in PLATEAUX.items():
        # The colours of the top: its middle row (the row above holds the rim)
        top = {c for x in (1, 2) for c in sheet_tile(sheets, ("N", col, x, row + 2)).get_flattened_data()}
        for dy in range(CLIFF_ROWS):
            for dx in range(8):
                tile = on_ground(sheet_tile(sheets, ("N", col, dx, row + dy)), grounds[ground], cliff=True)
                if retextured:
                    tile = retexture(tile, top, grounds[ground])
                tiles[at + dy * 8 + dx] = tile
                copies[at + dy * 8 + dx] = cliff_passages(dy, dx, tile)
        lines.append(f"falaise {name} : {cliff_line(at)}")
        at += CLIFF_ROWS * 8

    # Props, each from the start of a row (drawings side by side while they fit)
    x = 0
    for name, (src, sx, sy, w, h, bx, by, bw, bh) in PROPS.items():
        if x + w > 8:
            at += 8 * max_h
            x = 0
        if x == 0:
            max_h = 0
        max_h = max(max_h, h)
        base = at + x
        empty = []
        for dy in range(h):
            for dx in range(w):
                if src == "E":
                    tile = eterna_tile(eterna, sx + dx, sy + dy)
                else:
                    tile = sheet_tile(sheets, ("N", src, sx + dx, sy + dy))
                    if src == 4:
                        tile = water_to_sand(tile, grounds[SAND])
                dest = base + dy * 8 + dx
                tiles[dest] = tile
                inside = bx <= dx < bx + bw and by <= dy < by + bh
                copies[dest] = SOLID if inside else TALL
                if not inside and not tile.getbbox():
                    empty.append(dy * w + dx)
        line = f"T{base + by * 8 + bx} {bw}x{bh}"
        if (w, h) != (bw, bh):
            line += f" halo={w}x{h}@{bx},{by}" + ("/" + ",".join(map(str, empty)) if empty else "")
        lines.append(f"{name} : {line}")
        x += w
    at += 8 * max_h

    # Small plants, one row
    ids = []
    for i, (col, px, py) in enumerate(PLANTS):
        tiles[at + i] = water_to_sand(sheet_tile(sheets, ("N", col, px, py)), grounds[SAND])
        copies[at + i] = -1
        ids.append(f"T{at + i}")
    lines.append("plantes de plage : {sol} " + "|".join(ids))
    at += 8

    rows = (at - first) // 8
    out = Image.new("RGBA", (sheet.width, sheet.height + rows * TILE), (0, 0, 0, 0))
    out.paste(sheet, (0, 0))
    for t, tile in tiles.items():
        out.paste(tile, box(t)[:2])
    out.save(TARGET)
    filled = {str(t): copies.get(t, -1) for t in range(first, at)}
    subprocess.run(["ruby", "tools/art/tileset_tables.rb", str(TILESET_ID), str(rows * 8), json.dumps(filled)], check=True)
    print("\n".join(lines))


if __name__ == "__main__":
    main()
