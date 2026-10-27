"""Decor objects of the MapProc ambiances (TypeLocked, issue #110).

Each object is drawn here at 16 px a tile (shapes, then a dark outline of
its own colours and a soft shadow on the ground), scaled x2 to the 32 px
tiles of RPG Maker XP, on a transparent background so that it fits on every
ground. They are appended below Graphics/Tilesets/Outside.png and get their
passages and priorities in Data/Tilesets.rxdata (tools/art/tileset_tables.rb):
blocking like the bush T475, walkable, or for the top of a tall object
drawn above the player like the top of the tree T420.

Run once from the repository root (Pillow needed):
    python3 tools/art/ambiance_props.py            # appends, prints tile numbers
    python3 tools/art/ambiance_props.py --preview out.png   # only draws them
The tile numbers are used by [Legend] and [Objects] of MapProc/route.txt and
MapProc/ville.txt. Running it again appends again: restore the two files
from git first.
"""
import json
import math
import subprocess
import sys
from PIL import Image

TILESET = "Graphics/Tilesets/Outside.png"
T = 16                      # pixels a tile before scaling
BLOCK, WALK, TALL = 475, -1, 420   # source tiles of the passages/priorities
SHADOW = (24, 32, 24, 70)


def mix(c, k):
    """c darkened (k < 1) or lightened (k > 1)."""
    if k <= 1:
        return tuple(int(v * k) for v in c[:3]) + (255,)
    return tuple(int(v + (255 - v) * (k - 1)) for v in c[:3]) + (255,)


def ramp(c):
    """Highlight, light, mid, dark of a colour."""
    return [mix(c, 1.45), mix(c, 1.18), c[:3] + (255,), mix(c, 0.72)]


class Canvas:
    def __init__(self, w, h):
        self.w, self.h = w * T, h * T
        self.px = [[None] * self.w for _ in range(self.h)]
        self.shadows = []

    def put(self, x, y, c):
        x, y = int(x), int(y)
        if 0 <= x < self.w and 0 <= y < self.h:
            self.px[y][x] = c

    def rect(self, x0, y0, x1, y1, c):
        for y in range(y0, y1 + 1):
            for x in range(x0, x1 + 1):
                self.put(x, y, c)

    def ball(self, cx, cy, rx, ry, color, light=(-0.55, -0.7), bands=None):
        """Filled ellipse shaded from the top left (4 tones)."""
        r = ramp(color)
        for y in range(int(cy - ry) - 1, int(cy + ry) + 2):
            for x in range(int(cx - rx) - 1, int(cx + rx) + 2):
                nx, ny = (x + 0.5 - cx) / rx, (y + 0.5 - cy) / ry
                d = nx * nx + ny * ny
                if d > 1:
                    continue
                lum = -(nx * light[0] + ny * light[1]) * 0.9 + (1 - d) * 0.35
                k = 0 if lum > 0.75 else 1 if lum > 0.25 else 2 if lum > -0.35 else 3
                if bands and (y - int(cy - ry)) % bands == bands - 1:
                    k = min(3, k + 1)
                self.put(x, y, r[k])

    def poly(self, pts, c):
        ys = [p[1] for p in pts]
        for y in range(int(min(ys)), int(max(ys)) + 1):
            for x in range(self.w):
                if inside(x + 0.5, y + 0.5, pts):
                    self.put(x, y, c)

    def shadow(self, cx, cy, rx, ry):
        self.shadows.append((cx, cy, rx, ry))

    def finish(self):
        """Outline in a dark tone of the neighbour, then the ground shadow."""
        out = [row[:] for row in self.px]
        for y in range(self.h):
            for x in range(self.w):
                if self.px[y][x]:
                    continue
                near = [self.px[y + dy][x + dx] for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))
                        if 0 <= x + dx < self.w and 0 <= y + dy < self.h and self.px[y + dy][x + dx]]
                if near:
                    c = min(near, key=sum)
                    out[y][x] = mix(c, 0.42)
        for cx, cy, rx, ry in self.shadows:
            for y in range(self.h):
                for x in range(self.w):
                    nx, ny = (x + 0.5 - cx) / rx, (y + 0.5 - cy) / ry
                    if nx * nx + ny * ny <= 1 and not out[y][x]:
                        out[y][x] = SHADOW
        im = Image.new("RGBA", (self.w, self.h), (0, 0, 0, 0))
        for y in range(self.h):
            for x in range(self.w):
                if out[y][x]:
                    im.putpixel((x, y), out[y][x])
        return im.resize((self.w * 2, self.h * 2), Image.NEAREST)


def inside(x, y, pts):
    hit = False
    j = len(pts) - 1
    for i, (xi, yi) in enumerate(pts):
        xj, yj = pts[j]
        if (yi > y) != (yj > y) and x < (xj - xi) * (y - yi) / (yj - yi) + xi:
            hit = not hit
        j = i
    return hit


# ---------------------------------------------------------------- sable
def cactus():
    c = Canvas(1, 2)
    c.shadow(8, 29.5, 6, 2)
    g = ramp((72, 152, 64))

    def stalk(x0, x1, y0, y1):
        c.rect(x0, y0, x1, y1, g[2])
        c.rect(x0, y0, x0, y1, g[1])
        c.rect(x1, y0, x1, y1, g[3])
        c.rect(x0 + 1, y0 - 1, x1 - 1, y0 - 1, g[1])

    stalk(6, 9, 6, 29)
    stalk(2, 4, 10, 17)
    c.rect(3, 16, 6, 18, g[2])
    c.rect(3, 18, 6, 18, g[3])
    stalk(11, 13, 13, 20)
    c.rect(9, 19, 12, 21, g[2])
    c.rect(9, 21, 12, 21, g[3])
    for x, y in ((7, 9), (8, 14), (7, 19), (8, 24), (3, 12), (12, 15), (7, 27)):
        c.put(x, y, (232, 240, 184, 255))
    c.rect(7, 3, 8, 4, (240, 96, 120, 255))
    c.put(6, 4, (200, 64, 96, 255))
    c.put(9, 4, (200, 64, 96, 255))
    c.put(7, 3, (255, 176, 192, 255))
    return c


def jars():
    c = Canvas(1, 1)
    c.shadow(8, 14, 7, 1.6)
    clay = (200, 112, 64)
    c.ball(6, 9.5, 4.5, 4.5, clay)
    c.rect(4, 3, 7, 5, ramp(clay)[2])
    c.rect(3, 3, 8, 3, ramp(clay)[1])
    c.rect(4, 4, 4, 5, ramp(clay)[1])
    c.rect(2, 8, 10, 8, (120, 56, 32, 255))
    c.ball(12, 11.5, 2.8, 2.8, (216, 168, 96))
    c.rect(11, 7, 13, 8, ramp((216, 168, 96))[1])
    return c


def well():
    c = Canvas(2, 2)
    c.shadow(16, 29.5, 14, 2.2)
    roof = ramp((192, 72, 56))
    for y in range(2, 8):
        half = 4 + (y - 2) * 2.2
        c.rect(int(16 - half), y, int(15 + half), y, roof[1] if y < 5 else roof[2])
    c.rect(3, 8, 28, 9, roof[3])
    for x in range(5, 27, 4):
        c.put(x, 5, roof[2])
        c.put(x + 2, 7, roof[3])
    wood = ramp((168, 112, 64))
    for x0 in (6, 24):
        c.rect(x0, 10, x0 + 1, 19, wood[2])
        c.rect(x0, 10, x0, 19, wood[1])
    c.rect(8, 12, 23, 12, wood[1])
    c.rect(8, 13, 23, 13, wood[3])
    c.rect(15, 14, 16, 17, (224, 200, 120, 255))
    c.rect(14, 17, 17, 19, wood[2])
    stone = ramp((176, 168, 152))
    c.ball(16, 20, 13, 3, (176, 168, 152))
    c.ball(16, 20, 10, 1.8, (40, 48, 72))
    c.rect(3, 21, 28, 28, stone[2])
    for row, y in enumerate(range(21, 29, 2)):
        for x in range(3 + (row % 2) * 3, 29, 6):
            c.rect(x, y, min(x + 4, 28), y, stone[1 if x < 16 else 2])
            c.put(min(x + 5, 28), y, stone[3])
        c.rect(3, y + 1, 28, y + 1, stone[3])
    c.rect(3, 21, 3, 28, stone[1])
    c.rect(28, 21, 28, 28, stone[3])
    return c


# ---------------------------------------------------------------- minérale
def crystals():
    c = Canvas(1, 1)
    c.shadow(8, 14, 7, 1.6)
    rock = ramp((128, 120, 128))
    c.ball(8, 12, 6.5, 2.6, (128, 120, 128))
    for (x0, x1, top, base, col) in ((2, 4, 5, 11, (120, 168, 232)), (6, 9, 1, 11, (168, 128, 232)),
                                      (11, 13, 6, 11, (120, 200, 216))):
        r = ramp(col)
        mid = (x0 + x1) / 2
        c.poly([(x0, base), (x0, top + 2), (mid, top), (x1 + 1, top + 2), (x1 + 1, base)], r[2])
        c.poly([(x0, base), (x0, top + 2), (mid, top), (mid, base)], r[1])
        c.put(int(mid) - 1, top + 2, r[0])
        c.put(int(mid) - 1, top + 3, r[0])
    c.rect(2, 12, 13, 12, rock[2])
    c.rect(3, 13, 12, 13, rock[3])
    return c


def mine_cart():
    c = Canvas(1, 1)
    c.shadow(8, 14.5, 7, 1.4)
    ore = (160, 152, 160)
    c.ball(5, 6, 3, 2.4, ore)
    c.ball(10.5, 5.5, 3.2, 2.6, ore)
    c.ball(8, 4.5, 1.8, 1.6, (248, 200, 64))
    iron = ramp((120, 104, 96))
    c.poly([(1, 7), (15, 7), (13.5, 13), (2.5, 13)], iron[2])
    c.rect(1, 7, 14, 7, iron[1])
    c.rect(3, 10, 12, 10, iron[3])
    for x in (3, 12):
        c.rect(x, 8, x, 12, iron[1])
    for x in (4, 11):
        c.rect(x - 1, 13, x + 1, 14, (56, 48, 48, 255))
        c.put(x, 13, (152, 144, 136, 255))
    return c


def cut_stones():
    c = Canvas(1, 1)
    c.shadow(8, 14, 7.5, 1.6)
    s = ramp((168, 160, 168))
    for x0, y0, x1, y1 in ((1, 8, 7, 13), (8, 8, 14, 13), (4, 2, 11, 7)):
        c.rect(x0, y0, x1, y1, s[2])
        c.rect(x0, y0, x1, y0 + 1, s[0])
        c.rect(x0, y0 + 2, x0, y1, s[1])
        c.rect(x1, y0 + 2, x1, y1, s[3])
    c.put(10, 11, s[3])
    c.put(3, 11, s[3])
    return c


# ---------------------------------------------------------------- verdoyante, prairie
def beehive():
    c = Canvas(1, 1)
    c.shadow(8, 14, 6.5, 1.6)
    wood = ramp((136, 96, 56))
    c.rect(3, 11, 12, 12, wood[2])
    c.rect(4, 13, 4, 14, wood[3])
    c.rect(11, 13, 11, 14, wood[3])
    c.ball(8, 7, 5.5, 5, (216, 168, 72), bands=2)
    c.rect(7, 9, 8, 10, (72, 48, 24, 255))
    for x, y in ((2, 3), (13, 2), (12, 6)):
        c.put(x, y, (248, 216, 48, 255))
        c.put(x + 1, y, (40, 32, 24, 255))
    return c


def vegetable_patch():
    c = Canvas(2, 1)
    c.shadow(16, 14.5, 15, 1.4)
    wood = ramp((152, 104, 56))
    c.rect(1, 4, 30, 13, wood[2])
    c.rect(1, 4, 30, 4, wood[0])
    c.rect(1, 13, 30, 13, wood[3])
    c.rect(3, 6, 28, 11, (96, 64, 40, 255))
    for x in range(5, 28, 6):
        c.ball(x + 0.5, 7.5, 2.4, 2, (88, 176, 72))
        c.put(x, 11, (232, 120, 40, 255))
        c.put(x + 2, 11, (232, 120, 40, 255))
        c.put(x + 1, 10, (96, 176, 64, 255))
    return c


# ---------------------------------------------------------------- automne
def pumpkins():
    c = Canvas(1, 1)
    c.shadow(8, 14, 7.5, 1.6)
    orange = (232, 128, 32)
    c.ball(6, 9.5, 5, 4, orange)
    for x in (4, 8):
        c.rect(x, 7, x, 12, ramp(orange)[3])
    c.rect(6, 4, 6, 5, (96, 112, 40, 255))
    c.ball(12, 11.5, 3, 2.5, (240, 168, 48))
    c.rect(12, 8, 12, 8, (96, 112, 40, 255))
    return c


def hay_bale():
    c = Canvas(1, 1)
    c.shadow(8, 14, 7.5, 1.6)
    h = ramp((224, 184, 88))
    c.rect(1, 3, 14, 13, h[2])
    c.rect(1, 3, 14, 5, h[1])
    c.rect(1, 3, 14, 3, h[0])
    for x, y in ((3, 7), (6, 9), (10, 8), (12, 11), (4, 11), (8, 12), (11, 4), (5, 4)):
        c.put(x, y, h[3])
        c.put(x + 1, y, h[0] if y < 6 else h[1])
    c.rect(4, 3, 4, 13, (136, 80, 40, 255))
    c.rect(11, 3, 11, 13, (136, 80, 40, 255))
    c.rect(14, 6, 14, 13, h[3])
    return c


def leaf_pile():
    c = Canvas(1, 1)
    c.ball(8, 11, 6.5, 3.4, (208, 104, 40))
    for x, y, col in ((4, 10, (232, 176, 48)), (9, 9, (184, 56, 40)), (11, 12, (232, 176, 48)),
                      (6, 12, (152, 72, 32)), (12, 10, (232, 136, 48)), (7, 9, (240, 200, 88))):
        c.put(x, y, col + (255,))
        c.put(x + 1, y, mix(col + (255,), 0.8))
    c.put(2, 14, (232, 176, 48, 255))
    c.put(14, 6, (208, 104, 40, 255))
    return c


# ---------------------------------------------------------------- forêt tropicale
def giant_fern():
    c = Canvas(1, 1)
    c.shadow(8, 14, 7, 1.6)
    g = ramp((56, 152, 64))
    for ang in (200, 235, 270, 305, 340):
        a = math.radians(ang)
        for t in range(1, 8):
            x, y = 8 + math.cos(a) * t, 12 + math.sin(a) * t * 1.15
            c.put(x, y, g[2] if t < 6 else g[1])
            nx, ny = -math.sin(a), math.cos(a)
            if 2 <= t <= 6:
                c.put(x + nx, y + ny, g[1])
                c.put(x - nx, y - ny, g[3])
    c.rect(7, 11, 9, 13, g[3])
    return c


def bamboo():
    c = Canvas(1, 2)
    c.shadow(8, 29.5, 6.5, 2)
    g = ramp((136, 184, 72))
    for x0, top in ((3, 3), (7, 0), (11, 5)):
        c.rect(x0, top, x0 + 1, 29, g[2])
        c.rect(x0, top, x0, 29, g[1])
        for y in range(top + 4, 29, 6):
            c.rect(x0, y, x0 + 1, y, g[3])
    leaf = ramp((72, 152, 56))
    for x, y, d in ((5, 4, 1), (2, 9, -1), (9, 3, 1), (13, 10, 1), (6, 14, -1), (10, 17, 1)):
        for k in range(3):
            c.put(x + k * d, y + (k // 2), leaf[1 if k == 0 else 2])
    return c


def tropical_flowers():
    c = Canvas(1, 1)
    leaf = (56, 136, 56)
    for x, y in ((4, 11), (11, 9), (8, 13)):
        c.ball(x, y, 2.6, 1.6, leaf)
    for x, y, col in ((4, 9, (232, 56, 88)), (11, 7, (248, 136, 40)), (8, 11, (232, 56, 88))):
        r = ramp(col)
        c.rect(x - 1, y - 1, x + 1, y + 1, r[2])
        c.put(x - 1, y - 1, r[1])
        c.put(x, y, (248, 232, 96, 255))
    return c


# ---------------------------------------------------------------- terre battue, chemins de terre
def barrel():
    c = Canvas(1, 1)
    c.shadow(8, 14.5, 6.5, 1.4)
    wood = ramp((168, 104, 56))
    for x in range(3, 13):
        bulge = 0 if 5 <= x <= 10 else 1
        tone = 1 if x < 6 else 2 if x < 10 else 3
        c.rect(x, 4 + bulge, x, 13 - bulge, wood[tone])
    c.ball(8, 4, 4.5, 1.6, (136, 88, 48))
    c.rect(6, 4, 9, 4, wood[3])
    for y in (6, 11):
        c.rect(3, y, 12, y, (96, 96, 112, 255))
        c.rect(3, y, 5, y, (144, 144, 160, 255))
    return c


def wagon():
    c = Canvas(2, 2)
    c.shadow(16, 29.5, 14.5, 2)
    c.ball(15, 9, 12, 7, (224, 184, 88))
    for x, y in ((8, 7), (13, 4), (19, 8), (22, 6), (11, 11), (17, 12)):
        c.put(x, y, ramp((224, 184, 88))[3])
    wood = ramp((152, 96, 48))
    c.rect(2, 13, 29, 22, wood[2])
    c.rect(2, 13, 29, 13, wood[0])
    for y in (16, 19):
        c.rect(2, y, 29, y, wood[3])
    c.rect(2, 13, 2, 22, wood[1])
    c.rect(29, 14, 29, 22, wood[3])
    c.rect(29, 18, 31, 19, wood[3])
    for cx in (8, 23):
        c.ball(cx, 25, 4.5, 4.5, (80, 64, 48))
        c.ball(cx, 25, 3, 3, (168, 120, 72))
        c.ball(cx, 25, 1.2, 1.2, (80, 64, 48))
    return c


# name, drawing, width, height, kind (block, walk, tall: top rows above the
# player, the bottom row blocking)
PROPS = [
    ("cactus", cactus, 1, 2, "tall"),
    ("bambous", bamboo, 1, 2, "tall"),
    ("puits", well, 2, 2, "tall"),
    ("charrette", wagon, 2, 2, "tall"),
    ("potager", vegetable_patch, 2, 1, "block"),
    ("jarres", jars, 1, 1, "block"),
    ("cristaux", crystals, 1, 1, "block"),
    ("wagonnet", mine_cart, 1, 1, "block"),
    ("pierres taillées", cut_stones, 1, 1, "block"),
    ("ruche", beehive, 1, 1, "block"),
    ("citrouilles", pumpkins, 1, 1, "block"),
    ("botte de foin", hay_bale, 1, 1, "block"),
    ("tas de feuilles", leaf_pile, 1, 1, "walk"),
    ("fougère géante", giant_fern, 1, 1, "block"),
    ("fleurs exotiques", tropical_flowers, 1, 1, "walk"),
    ("tonneau", barrel, 1, 1, "block"),
]


def layout():
    """First free spot of each object on a grid 8 tiles wide (rows from 0)."""
    taken = set()
    spots = []
    for _name, _draw, w, h, _kind in PROPS:
        i = 0
        while True:
            col, row = i % 8, i // 8
            cells = {(col + dx, row + dy) for dx in range(w) for dy in range(h)}
            if col + w <= 8 and not cells & taken:
                taken |= cells
                spots.append((col, row))
                break
            i += 1
    rows = max(r for _c, r in taken) + 1
    return spots, rows


def main():
    spots, rows = layout()
    sheet = Image.new("RGBA", (256, rows * 32), (0, 0, 0, 0))
    for (_name, draw, _w, _h, _kind), (col, row) in zip(PROPS, spots):
        sheet.alpha_composite(draw().finish(), (col * 32, row * 32))
    if len(sys.argv) > 2 and sys.argv[1] == "--preview":
        sheet.save(sys.argv[2])
        return
    im = Image.open(TILESET).convert("RGBA")
    first = (im.height // 32) * 8
    out = Image.new("RGBA", (256, im.height + rows * 32), (0, 0, 0, 0))
    out.paste(im, (0, 0))
    out.paste(sheet, (0, im.height))
    copies, result = {}, {}
    for (name, _draw, w, h, kind), (col, row) in zip(PROPS, spots):
        result[name] = first + row * 8 + col
        for dy in range(h):
            for dx in range(w):
                src = WALK if kind == "walk" else TALL if kind == "tall" and dy < h - 1 else BLOCK
                copies[first + (row + dy) * 8 + col + dx] = src
    out.save(TILESET)
    subprocess.run(["ruby", "tools/art/tileset_tables.rb", "1", str(rows * 8),
                    json.dumps({str(k): v for k, v in copies.items()})], check=True)
    print(json.dumps(result, ensure_ascii=False, indent=1))


if __name__ == "__main__":
    main()
