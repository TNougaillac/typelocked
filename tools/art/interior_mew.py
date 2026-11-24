"""Interior Mew tileset and its house rooms (TypeLocked, issue #322): the
houses of the generated worlds (« maison », « refuge ») lead to rooms drawn
with Mew's Gen 4 Interior Tiles (walls, floors and furniture), in place of
the demo's houses.

The tileset is Mew's sheet as it is (8 tiles of 32 px a row), and one row
more: a black tile (outside the room). Each piece of furniture is taken by
the block of tiles that holds its drawing, whole (the pixels joined to it
must stay in the block, else the script stops). Its foot rows are blocked,
the rows above drawn over the player (priority 1); a piece against the back
wall stands on the first floor row, its top over the wall.

A room is: a black row, the back wall (3 rows of panels), the floor, a black
row; the side walls (Mew's grey strips) on both sides. The exit is on the
last floor row (the player arrives just above it).

Source (docs/CREDITS.md), not in the repository: Mew's Gen 4 Interior Tiles.
Run once from the repository root (Pillow and numpy needed):
    python3 tools/art/interior_mew.py "<Mew's Gen 4 Interior Tiles.png>"
It writes Graphics/Tilesets/Interior Mew.png, then tileset 32 and the room
maps (tools/art/rooms_mew.rb), and prints their lines for INTERIORS.
Add a preview path as a second argument to save a picture of the rooms.
"""
import json
import subprocess
import sys
import numpy as np
from PIL import Image

TARGET = "Graphics/Tilesets/Interior Mew.png"
TILESET_ID = 32
TILE = 32
ROWS = 50          # rows of Mew's sheet
BLACK = ROWS * 8   # the black tile, first of the row added
BLOCKED, OVER = 15, (0, 1)   # passages of a blocked tile; walkable, over the player
# Walls: name => first row of the panels (3 rows); columns 3, 4 are the two
# halves of a panel, 5 a panel alone; the side walls are columns 6 (left)
# and 7 (right), rows 8 to 10
WALLS = {"bois": 8, "pierre": 12, "plâtre": 16}
# Floors: column of the sheet, row 0 shaded by the wall, row 1 plain
FLOORS = {"planches": 0, "briques de bois": 1, "carrés de bois": 2, "pierre sombre": 3,
          "pierre claire": 4, "pierre beige": 5, "damier": 6}
# Furniture: name => (x, y, width, height of its block in the sheet, rows
# blocked at its foot, against the wall: True, on the wall: "mur", free: False)
FURNITURE = {
    "fenêtre": (0, 27, 1, 3, 0, "mur"),
    "double fenêtre": (1, 27, 2, 3, 0, "mur"),
    "petite fenêtre": (0, 30, 1, 2, 0, "mur"),
    "petite double fenêtre": (1, 30, 2, 2, 0, "mur"),
    "tableau": (3, 32, 1, 1, 0, "mur"),
    "calendrier": (3, 33, 1, 1, 0, "mur"),
    "table": (0, 32, 3, 3, 2, False),
    "table à nappe": (0, 35, 3, 3, 2, False),
    "tapis": (3, 36, 3, 3, 0, False),
    "bureau": (0, 38, 2, 2, 1, True),
    "bibliothèque": (2, 39, 3, 4, 1, True),
    "étagère vide": (5, 39, 3, 4, 1, True),
    "armoire": (0, 40, 1, 3, 1, True),
    "armoire étroite": (1, 40, 1, 3, 1, True),
    "petite bibliothèque": (0, 43, 2, 3, 1, True),
    "plante": (2, 43, 1, 2, 1, True),
    "réfrigérateur": (5, 43, 2, 3, 1, True),
}
# Rooms: map ID => (name, wall, floor, floor width, floor height,
# [(furniture, x of its left tile on the floor, y: its foot row from the
# first floor row, for a free piece)], [(x, y, facing) of the inhabitants])
ROOMS = {
    21: ("Maison Mew (bois)", "bois", "planches", 9, 5,
         [("bibliothèque", 0, 0), ("double fenêtre", 4, 0), ("plante", 6, 0), ("réfrigérateur", 7, 0),
          ("table", 3, 3)],
         [(2, 5, "bas"), (8, 6, "gauche")]),
    22: ("Maison Mew (pierre)", "pierre", "pierre beige", 8, 5,
         [("armoire", 0, 0), ("armoire étroite", 1, 0), ("fenêtre", 3, 0), ("tableau", 4, 0),
          ("bureau", 6, 0), ("tapis", 3, 3)],
         [(3, 5, "bas"), (7, 6, "bas")]),
    23: ("Maison Mew (plâtre)", "plâtre", "damier", 11, 6,
         [("réfrigérateur", 0, 0), ("plante", 2, 0), ("double fenêtre", 4, 0), ("calendrier", 6, 0),
          ("étagère vide", 8, 0), ("table à nappe", 1, 4)],
         [(5, 6, "bas"), (8, 7, "gauche")]),
    28: ("Maison Mew (cabane)", "bois", "carrés de bois", 6, 4,
         [("petite bibliothèque", 0, 0), ("petite fenêtre", 3, 0), ("plante", 5, 0)],
         [(4, 5, "bas")]),
}


def check_whole(sheet, name, x, y, w, h):
    """Stops on a piece whose drawing goes on beyond its block."""
    a = np.asarray(sheet)[:, :, 3] > 0
    inside = np.zeros(a.shape, bool)
    inside[y * TILE:(y + h) * TILE, x * TILE:(x + w) * TILE] = True
    seen = a & inside
    stack = list(zip(*np.nonzero(seen)))
    while stack:
        py, px = stack.pop()
        for ny in (py - 1, py, py + 1):
            for nx in (px - 1, px, px + 1):
                if 0 <= ny < a.shape[0] and 0 <= nx < a.shape[1] and a[ny, nx] and not seen[ny, nx]:
                    if not inside[ny, nx]:
                        sys.exit(f"{name} : dessin coupé par son bloc ({nx // TILE},{ny // TILE})")
                    seen[ny, nx] = True
                    stack.append((ny, nx))


def tile(x, y):
    return 384 + y * 8 + x


def passages(sheet):
    """Passages and priorities of every tile: floors walkable, walls and
    black blocked, furniture blocked at its foot and over the player above."""
    table = {t: (BLOCKED, 0) for t in range(384, 384 + BLACK + 8)}
    for col in FLOORS.values():
        for row in range(7):
            table[tile(col, row)] = (0, 0)
    for name, (x, y, w, h, foot, place) in FURNITURE.items():
        check_whole(sheet, name, x, y, w, h)
        for dy in range(h):
            for dx in range(w):
                if place == "mur":
                    value = (BLOCKED, 0)
                elif dy >= h - foot:
                    value = (BLOCKED, 0)
                elif foot == 0:
                    value = (0, 0)
                else:
                    value = OVER
                table[tile(x + dx, y + dy)] = value
    return table


def room_layers(wall, floor, w, h, furniture):
    """The 3 layers of a room (lists of rows of tile IDs) and its exit."""
    width, height = w + 2, h + 5
    layers = [[[tile(0, ROWS)] * width for _ in range(height)]] + [[[0] * width for _ in range(height)] for _ in (1, 2)]
    ground = layers[0]
    first = WALLS[wall]
    col = FLOORS[floor]
    for x in range(1, w + 1):
        part = 3 + (x - 1) % 2
        if x == w and part == 3:
            part = 5
        for k in range(3):
            ground[1 + k][x] = tile(part, first + k)
        for y in range(4, 4 + h):
            ground[y][x] = tile(col, 0 if y == 4 else 1)
    for y in range(1, 4 + h):
        ground[y][0] = tile(6, min(7 + y, 9) + first - 8)
        ground[y][width - 1] = tile(7, min(7 + y, 9) + first - 8)
    for name, fx, fy in furniture:
        x0, y0, fw, fh, _foot, place = FURNITURE[name]
        if place == "mur":
            top = 1 + (3 - fh) // 2
        elif place:
            top = 4 - fh + 1
        else:
            top = 4 + fy - fh + 1
        z = 2 if any(layers[1][top + dy][1 + fx + dx] for dy in range(fh) for dx in range(fw)) else 1
        for dy in range(fh):
            for dx in range(fw):
                layers[z][top + dy][1 + fx + dx] = tile(x0 + dx, y0 + dy)
    return layers, (1 + w // 2, 3 + h)


def main():
    sheet = Image.open(sys.argv[1]).convert("RGBA")
    if sheet.size != (8 * TILE, ROWS * TILE):
        sys.exit(f"planche de {sheet.size} au lieu de {(8 * TILE, ROWS * TILE)}")
    out = Image.new("RGBA", (8 * TILE, (ROWS + 1) * TILE), (0, 0, 0, 0))
    out.paste(sheet, (0, 0))
    out.paste(Image.new("RGBA", (TILE, TILE), (0, 0, 0, 255)), (0, ROWS * TILE))
    table = passages(sheet)
    rooms = {}
    for map_id, (name, wall, floor, w, h, furniture, people) in ROOMS.items():
        layers, (ex, ey) = room_layers(wall, floor, w, h, furniture)
        rooms[map_id] = {"name": name, "layers": layers, "exit": [ex, ey]}
        print(f"[{map_id}, {ex}, {ey}],   # {name}, habitants {people}")
    if len(sys.argv) > 2:
        preview(out, rooms, sys.argv[2])
        return
    out.save(TARGET)
    data = {"tileset": TILESET_ID, "graphic": "Interior Mew", "count": len(table),
            "passages": [table[t][0] for t in sorted(table)], "priorities": [table[t][1] for t in sorted(table)],
            "rooms": rooms}
    subprocess.run(["ruby", "tools/art/rooms_mew.rb"], input=json.dumps(data), text=True, check=True)


def preview(sheet, rooms, path):
    pics = []
    for room in rooms.values():
        layers = room["layers"]
        pic = Image.new("RGBA", (len(layers[0][0]) * TILE, len(layers[0]) * TILE), (255, 0, 255, 255))
        for layer in layers:
            for y, row in enumerate(layer):
                for x, t in enumerate(row):
                    if t:
                        n = t - 384
                        pic.alpha_composite(sheet.crop(((n % 8) * TILE, (n // 8) * TILE, (n % 8 + 1) * TILE, (n // 8 + 1) * TILE)), (x * TILE, y * TILE))
        ex, ey = room["exit"]
        pic.paste((255, 0, 0, 255), (ex * TILE + 12, ey * TILE + 12, ex * TILE + 20, ey * TILE + 20))
        pics.append(pic)
    out = Image.new("RGBA", (sum(p.width for p in pics) + 16 * len(pics), max(p.height for p in pics)), (255, 255, 255, 255))
    x = 0
    for p in pics:
        out.paste(p, (x, 0))
        x += p.width + 16
    out.save(path)


if __name__ == "__main__":
    main()
