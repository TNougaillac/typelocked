"""Outside 4G tileset (TypeLocked, issue #177).

Builds Graphics/Tilesets/Outside 4G.png: a copy of Graphics/Tilesets/Outside.png
where each tile used by MapProc gets its 4G equivalent, on the same grid. The
T<n> numbers of MapProc/route.txt and ville.txt stay valid, and so do the
passages and priorities (tileset 24 is a copy of tileset 1, see
tools/art/tileset_clone.rb). Tiles not listed below keep their old drawing:
the next tickets of #177 replace them.

Sources (see docs/CREDITS.md), not in the repository:
- SirMalo, "Tiles - HGSS for RMXP": NatureRMXP.png, UrbanRMXP.png,
  BuildingsRMXP.png. The sheets are at the DS size (16 px tiles), in columns
  of 8 tiles (128 px) every 144 px, from x = 16. Pink is see-through, yellow
  and white are unused. They are scaled x2 (nearest neighbour).

Run from the repository root, after tools/art/tileset_clone.rb (again after
any change of Outside.png or tileset 1), with the folder of the SirMalo sheets (Pillow
needed):
    python3 tools/art/outside_4g.py "<SirMalo folder>"
    python3 tools/art/outside_4g.py "<SirMalo folder>" --preview out.png
The preview draws each replaced object, old and new side by side.
"""
import sys
from PIL import Image

SOURCE = "Graphics/Tilesets/Outside.png"
TARGET = "Graphics/Tilesets/Outside 4G.png"
SHEETS = {"N": "NatureRMXP.png"}
PINK = (240, 91, 161, 255)
UNUSED = {(255, 245, 104, 255), (255, 255, 255, 255)}
# 4G grass and the shadows drawn on it (redrawn on the other grounds)
GRASS = {(112, 216, 168, 255), (112, 208, 168, 255)}
SHADOWS = {(96, 200, 152, 255): 0.9, (80, 176, 144, 255): 0.8, (56, 136, 112, 255): 0.6}
TILE = 32

# Grid tiles: Outside tile => (sheet, column, tile x, tile y) in 16 px tiles.
# A tile with see-through parts is drawn over the 4G grass.
TILES = {
    # Grass (verdoyante ground): plain, blades (3: mirrored, see MIRRORED)
    1: ("N", 0, 0, 0), 2: ("N", 0, 1, 0), 3: ("N", 0, 1, 0),
    # Dirt path on the grass (Rue of the green ambiances; 106 is also the
    # dirt ground): outer edges from the full patch, inner corners from the
    # patch with a hole (its hole shows the grass)
    97: ("N", 0, 0, 6), 98: ("N", 0, 1, 6), 99: ("N", 0, 3, 6),
    105: ("N", 0, 0, 7), 106: ("N", 0, 1, 7), 107: ("N", 0, 3, 7),
    113: ("N", 0, 0, 9), 114: ("N", 0, 1, 9), 115: ("N", 0, 3, 9),
    100: ("N", 0, 5, 7), 102: ("N", 0, 6, 7), 116: ("N", 0, 5, 8), 118: ("N", 0, 6, 8),
    # Sand ground (sand ambiance, desert): the pale sand
    162: ("N", 0, 1, 17),
    # Very tall grass: its foot (opaque) and its top (see-through, drawn over
    # the foot: two rows of grass)
    15: ("N", 3, 0, 9),
}
# Tiles drawn mirrored (left-right), for variety
MIRRORED = {3}
# Tiles drawn from parts: Outside tile => [(sheet, column, x, y, w, h)] in
# pixels of the column, stacked from the top (16 px once joined)
PIECES = {
    # Tall grass: the middle of the patch (it joins its neighbours)
    6: [("N", 3, 0, 128, 16, 16)],
    # Top of the very tall grass: see-through above the tips
    7: [("N", 3, 0, 112, 16, 16)],
}
# Objects: symbol => (first Outside tile, width, height, parts, top tile).
# The parts (as above) are stacked, trimmed to their drawing and placed at the
# bottom centre of the block. top tile: the tile above the middle of the
# block (the crown of the round trees) takes the top row of a drawing one
# tile taller; None: the drawing is cut at the top of the block.
OBJECTS = {
    # Forest trees (route borders, tall pine): the sheet draws them in pairs,
    # one hiding the bottom of the other: the top of the back tree, then the
    # bottom of the front one (same drawing)
    "t": (420, 2, 3, [("N", 2, 16, 8, 32, 29), ("N", 2, 16, 69, 32, 19)], None),
    "é": (440, 3, 3, [("N", 2, 16, 392, 32, 29), ("N", 2, 16, 453, 32, 19)], None),
    "è": (491, 3, 3, [("N", 3, 0, 576, 64, 64)], 484),
    "ü": (539, 3, 3, [("N", 3, 0, 640, 64, 64)], 532),
    "ê": (470, 1, 3, [("N", 3, 0, 240, 16, 48)], None),
    "ë": (502, 1, 2, [("N", 3, 16, 256, 16, 32)], None),
    "à": (475, 1, 1, [("N", 3, 48, 432, 16, 16)], None),
}
# Ground variants (tools/art/ground_variants.py): ground tile, then the first
# tile of each object redrawn on it
VARIANTS = {
    50: {"t": 4016, "é": 4018, "è": 4021, "à": 4045, "ê": 4192, "ë": 4193},
    162: {"t": 4056, "é": 4058, "è": 4061, "à": 4085, "ê": 4194, "ë": 4195},
    106: {"t": 4096, "é": 4098, "è": 4101, "à": 4125, "ê": 4196, "ë": 4197},
    218: {"t": 4136, "é": 4138, "è": 4141, "à": 4165, "ê": 4198, "ë": 4199},
}
# Tall grass on the other grounds: ground => (tall grass, very tall grass foot)
GRASS_VARIANTS = {50: (143, 151), 162: (124, 175), 218: (133, 189), 106: (125, 181)}


def box(tile):
    return ((tile % 8) * TILE, (tile // 8) * TILE, (tile % 8) * TILE + TILE, (tile // 8) * TILE + TILE)


def piece(sheets, sheet, col, x, y, w, h):
    """A part of a sheet column at the DS size, its pink and unused colours
    see-through."""
    left = 16 + 144 * col
    im = sheets[sheet].crop((left + x, y, left + x + w, y + h))
    im.putdata([(0, 0, 0, 0) if c == PINK or c in UNUSED else c for c in im.getdata()])
    return im


def stack(parts):
    width = max(p.width for p in parts)
    out = Image.new("RGBA", (width, sum(p.height for p in parts)), (0, 0, 0, 0))
    y = 0
    for p in parts:
        out.alpha_composite(p, ((width - p.width) // 2, y))
        y += p.height
    return out


def x2(im):
    return im.resize((im.width * 2, im.height * 2), Image.NEAREST)


def see_through_grass(im):
    """The 4G grass of an object becomes see-through: the ground of its map
    shows under it."""
    im = im.copy()
    im.putdata([(0, 0, 0, 0) if c in GRASS else c for c in im.getdata()])
    return im


def redraw(tile, ground, opaque):
    """A 4G tile on another ground: the grass becomes the ground (or
    see-through), its shadows the darkened ground."""
    tile = tile.copy()
    px, g = tile.load(), ground.load()
    for y in range(tile.height):
        for x in range(tile.width):
            c = px[x, y]
            if c in GRASS:
                px[x, y] = g[x, y] if opaque else (0, 0, 0, 0)
            elif c in SHADOWS:
                k = SHADOWS[c]
                r, gg, b, _a = g[x, y]
                px[x, y] = (int(r * k), int(gg * k), int(b * k), 255)
    return tile


def object_image(sheets, width, height, parts, top):
    """The drawing of an object on its block (one row taller with a top
    tile), at the tileset size."""
    drawing = stack([piece(sheets, *p) for p in parts])
    bbox = drawing.getbbox()
    drawing = x2(drawing.crop(bbox)) if bbox else x2(drawing)
    rows = height + (1 if top else 0)
    canvas = Image.new("RGBA", (width * TILE, rows * TILE), (0, 0, 0, 0))
    x = (canvas.width - drawing.width) // 2
    y = canvas.height - drawing.height
    canvas.alpha_composite(drawing.crop((max(0, -x), max(0, -y), drawing.width, drawing.height)),
                           (max(0, x), max(0, y)))
    return see_through_grass(canvas)


def paste_block(out, image, first, width, height, top, ground=None):
    """Writes an object's drawing on its tiles (and its top tile)."""
    rows = height + (1 if top else 0)
    for dy in range(rows):
        for dx in range(width):
            if top and dy == 0:
                if dx != width // 2:
                    continue
                dest = top
            else:
                dest = first + (dy - (1 if top else 0)) * 8 + dx
            tile = image.crop((dx * TILE, dy * TILE, dx * TILE + TILE, dy * TILE + TILE))
            if ground is not None:
                tile = redraw(tile, ground, False)
            out.paste((0, 0, 0, 0), box(dest))
            out.paste(tile, box(dest)[:2])


def build(folder):
    sheets = {k: Image.open(f"{folder}/{name}").convert("RGBA") for k, name in SHEETS.items()}
    out = Image.open(SOURCE).convert("RGBA")
    grass = x2(grid(sheets, TILES[1]))
    for dest, src in TILES.items():
        tile = Image.new("RGBA", (TILE, TILE))
        tile.paste(grass)
        drawing = x2(grid(sheets, src))
        if dest in MIRRORED:
            drawing = drawing.transpose(Image.FLIP_LEFT_RIGHT)
        tile.alpha_composite(drawing)
        out.paste(tile, box(dest)[:2])
    for dest, parts in PIECES.items():
        tile = x2(stack([piece(sheets, *p) for p in parts]))
        if dest != 7:
            under = grass.copy()
            under.alpha_composite(tile)
            tile = under
        out.paste((0, 0, 0, 0), box(dest))
        out.paste(tile, box(dest)[:2])
    images = {}
    for sym, (first, width, height, parts, top) in OBJECTS.items():
        images[sym] = object_image(sheets, width, height, parts, top)
        paste_block(out, images[sym], first, width, height, top)
    # Other grounds: the objects and the tall grass redrawn on them (the
    # grounds are taken from the new tileset: sand and dirt are 4G)
    for ground_id, firsts in VARIANTS.items():
        ground = out.crop(box(ground_id))
        big = Image.new("RGBA", (3 * TILE, 4 * TILE))
        for gx in range(3):
            for gy in range(4):
                big.paste(ground, (gx * TILE, gy * TILE))
        for sym, first in firsts.items():
            _f, width, height, _parts, top = OBJECTS[sym]
            image = images[sym].crop((0, TILE if top else 0, width * TILE, (height + (1 if top else 0)) * TILE))
            paste_block(out, image, first, width, height, None, big)
        tall, foot = GRASS_VARIANTS[ground_id]
        for dest, src in ((tall, 6), (foot, 15)):
            out.paste(redraw(out.crop(box(src)), ground, True), box(dest)[:2])
    return out, images


def grid(sheets, src):
    sheet, col, tx, ty = src
    return piece(sheets, sheet, col, tx * 16, ty * 16, 16, 16)


def preview(out, path):
    old = Image.open(SOURCE).convert("RGBA")
    blocks = [(first, w, h + (1 if top else 0), top) for first, w, h, _p, top in OBJECTS.values()]
    width = sum(w for _f, w, _h, _t in blocks) * TILE * 2 + len(blocks) * 16
    sheet = Image.new("RGBA", (width, 5 * TILE), (112, 216, 168, 255))
    x = 0
    for first, w, h, top in blocks:
        for k, src in enumerate((old, out)):
            for dy in range(h):
                for dx in range(w):
                    tile_y = dy - (1 if top else 0)
                    if tile_y < 0 and dx != w // 2:
                        continue
                    dest = top if tile_y < 0 else first + tile_y * 8 + dx
                    sheet.alpha_composite(src.crop(box(dest)), (x + k * w * TILE + dx * TILE, (5 - h + dy) * TILE))
        x += w * TILE * 2 + 16
    sheet.save(path)


def main():
    out, _images = build(sys.argv[1])
    if "--preview" in sys.argv:
        preview(out, sys.argv[sys.argv.index("--preview") + 1])
        return
    out.save(TARGET)
    print(f"{TARGET} : {len(TILES) + len(PIECES)} tuiles et {len(OBJECTS)} objets remplacés")


if __name__ == "__main__":
    main()
