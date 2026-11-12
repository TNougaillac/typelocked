"""Adds street styles to the Outside 4G tileset (TypeLocked, issue #316):
the other paving of SirMalo (UrbanRMXP.png, column B), the paths and city
floors of the DPPt Exterior Ground Tiles and the ground patches of the
Remastered Kanto pack (KANTO50S_OUT.png), as MapProc « Rue » lines.

A style is a full patch (3 or 4 tiles a side: corners and edges), a middle
tile repeated, and a block of 2x2 inner corners; which inner corner a tile is
is read from the drawing (the corner farthest from its centre colour). Tiles
with see-through places are laid on the grass (T18057); the grass of the DPPt
and Kanto drawings (a green brighter or darker than 4G's) is see-through too,
its shadows redrawn in the shadows of the 4G grass. Each patch is whole
in its frame: only its own tiles are taken.

Sources (docs/CREDITS.md), not in the repository: SirMalo's UrbanRMXP.png,
the DPPt Exterior Ground Tiles (folder Platinum) and the Remastered Kanto
Johto Map Pack (Graphics/Tilesets). Run once from the repository root, after
tools/art/snow_patches_4g.py (Pillow and numpy needed):
    python3 tools/art/streets_4g.py "<SirMalo folder>" "<DPPt Platinum folder>" "<Remastered Tilesets folder>"
Prints the « Rue » line of each style.
"""
import json
import subprocess
import sys
import numpy as np
from PIL import Image

sys.path.insert(0, "tools/art")
from outside_4g import SHADOWS, SHEETS, box, sheet_tile  # noqa: E402

TARGET = "Graphics/Tilesets/Outside 4G.png"
TILESET_ID = 24
TILE = 32
GRASS = 18057
KANTO = "KANTO50S_OUT.png"
# Plain grass of the DPPt and Kanto drawings: their greens are read against it
SOURCE_GRASS = {"D": (80, 248, 144), "K": (121, 170, 96)}
# name => (source, full patch x, y, its size, middle x, y, inner corners x, y).
# Source: ("U", column) SirMalo Urban (16 px tiles of the column), ("D", file)
# DPPt (32 px), ("K",) Remastered Kanto (32 px).
STYLES = {
    # Urban B (SirMalo): blue slate, dark stones, ochre
    "ardoise bleue": (("U", 1), 0, 5, 4, 2, 6, 5, 6),
    "pavé sombre": (("U", 1), 4, 28, 4, 1, 33, 1, 29),
    "ocre": (("U", 1), 0, 35, 4, 1, 39, 5, 36),
    # DPPt: paths with round edges, city floors
    "béton": (("D", "Concrete Path"), 0, 0, 4, 1, 1, 4, 0),
    "terre (DPPt)": (("D", "Dirt Path"), 0, 0, 4, 1, 1, 4, 0),
    "sable (DPPt)": (("D", "Path"), 0, 0, 4, 1, 1, 4, 0),
    "parquet (Hearthome)": (("D", "Hearthome City Set"), 0, 0, 3, 1, 1, 3, 0),
    "dalles sombres (Jubilife)": (("D", "Jubilife City Set"), 0, 0, 3, 1, 1, 3, 0),
    "sable des mines (Oreburgh)": (("D", "Oreburgh City Set"), 0, 0, 4, 1, 1, 4, 0),
    "pierre (Eterna)": (("D", "Eterna City Road"), 0, 0, 3, 1, 1, 3, 0),
    # Kanto (Remastered): ground patches 3x3 and their 2x2 holes
    "terre brune": (("K",), 1, 12, 3, 2, 13, 4, 12),
    "terre grise": (("K",), 0, 16, 3, 1, 17, 6, 18),
    "sable clair": (("K",), 3, 15, 3, 4, 16, 6, 20),
    "sable doré": (("K",), 1, 19, 3, 2, 20, 4, 19),
    "dalles ocre": (("K",), 0, 23, 3, 1, 24, 6, 22),
    "pavés violets": (("K",), 0, 45, 3, 1, 46, 3, 45),
}
# Roles of the full patch (offset in a patch of 3 and of 4), then the inner
# corners by the corner of the tile that is outside the street
EDGES = {"N": ((1, 0), (1, 0)), "S": ((1, 2), (1, 3)), "W": ((0, 1), (0, 1)), "E": ((2, 1), (3, 1)),
         "NW": ((0, 0), (0, 0)), "NE": ((2, 0), (3, 0)), "SW": ((0, 2), (0, 3)), "SE": ((2, 2), (3, 3))}
INNER = {"TL": "iNW", "TR": "iNE", "BL": "iSW", "BR": "iSE"}
ROLES = ["", "N", "S", "W", "E", "NW", "NE", "SW", "SE", "iNW", "iNE", "iSW", "iSE"]


def source_tile(sources, src, x, y):
    if src[0] == "U":
        return sheet_tile(sources, ("U", src[1], x, y))
    im = sources[src]
    return regreen(im.crop((x * TILE, y * TILE, x * TILE + TILE, y * TILE + TILE)), SOURCE_GRASS[src[0]])


def regreen(tile, base):
    """The tile with its greens on 4G's: plain grass see-through, darker
    greens the nearest 4G grass shadow (by their share of the plain green)."""
    a = np.array(tile.convert("RGBA")).astype(int)
    r, g, b = a[:, :, 0], a[:, :, 1], a[:, :, 2]
    green = (g > r + 30) & (g > b + 20) & (a[:, :, 3] > 0)
    share = g / base[1]
    shades = sorted([(1.0, None)] + [(k, c) for c, k in SHADOWS.items()], reverse=True)
    for k, colour in shades:
        near = green & (np.abs(share - k) == np.min([np.abs(share - s) for s, _ in shades], axis=0))
        if colour is None:
            a[near, 3] = 0
        else:
            a[near, :3] = colour[:3]
    return Image.fromarray(a.astype(np.uint8))


def outer_corner(tile):
    """The corner of an inner-corner tile that is off the street: the one
    farthest from the centre colour."""
    a = np.asarray(tile).astype(int)
    centre = a[16, 16]
    spots = {"TL": (2, 2), "TR": (29, 2), "BL": (2, 29), "BR": (29, 29)}
    return max(spots, key=lambda k: np.abs(a[spots[k][1], spots[k][0]] - centre).sum())


def main():
    sirmalo, dppt, remastered = sys.argv[1], sys.argv[2], sys.argv[3]
    sources = {k: Image.open(f"{sirmalo}/{name}").convert("RGBA") for k, name in SHEETS.items()}
    for src, *_ in STYLES.values():
        if src[0] == "D":
            sources[src] = Image.open(f"{dppt}/{src[1]}.png").convert("RGBA")
        elif src[0] == "K":
            sources[src] = Image.open(f"{remastered}/{KANTO}").convert("RGBA")
    sheet = Image.open(TARGET).convert("RGBA")
    grass = sheet.crop(box(GRASS))
    first = sheet.height // TILE * 8
    tiles, lines, at = {}, [], first

    for name, (src, fx, fy, size, mx, my, ix, iy) in STYLES.items():
        picked = {"": (mx, my)}
        for role, offsets in EDGES.items():
            dx, dy = offsets[size == 4]
            picked[role] = (fx + dx, fy + dy)
        for dy in (0, 1):
            for dx in (0, 1):
                role = INNER[outer_corner(source_tile(sources, src, ix + dx, iy + dy).convert("RGBA"))]
                if role in picked:
                    sys.exit(f"{name} : deux coins rentrants {role}")
                picked[role] = (ix + dx, iy + dy)
        ids = []
        for i, role in enumerate(ROLES):
            tile = grass.copy()
            tile.alpha_composite(source_tile(sources, src, *picked[role]).convert("RGBA"))
            tiles[at + i] = tile
            ids.append(f"{role}=T{at + i}" if role else f"T{at + i}")
        lines.append(f"Rue   = {' '.join(ids)} with=fŀĿĳĲ   # {name}")
        at += 16

    rows = (at - first) // 8
    out = Image.new("RGBA", (sheet.width, sheet.height + rows * TILE), (0, 0, 0, 0))
    out.paste(sheet, (0, 0))
    for t, tile in tiles.items():
        out.paste(tile, box(t)[:2])
    out.save(TARGET)
    filled = {str(t): -1 for t in range(first, at)}
    subprocess.run(["ruby", "tools/art/tileset_tables.rb", str(TILESET_ID), str(rows * 8), json.dumps(filled)], check=True)
    print("\n".join(lines))


if __name__ == "__main__":
    main()
