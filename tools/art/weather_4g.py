#!/usr/bin/env python3
"""Redraw Graphics/Weather in a Gen 4 (DS) style.

No ready-made Gen 4 weather sheets exist, so every sprite is drawn here at
half resolution and scaled x2 (nearest), like the rest of Essentials' art.
File names, sizes and fall directions stay those of Essentials, so the
weather code (RPG::Weather) uses them unchanged.

Usage: python3 tools/art/weather_4g.py [Graphics/Weather]
"""
import math
import random
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

OUT = Path(sys.argv[1] if len(sys.argv) > 1 else "Graphics/Weather")
SEED = 0x4E7  # fixed: the script always gives the same images

RAIN_TOP = (176, 208, 240)
RAIN_TIP = (248, 252, 255)
SNOW = (248, 252, 255)
SNOW_EDGE = (200, 220, 240)
SAND = (224, 176, 104)
SAND_DARK = (168, 112, 48)
SAND_LIGHT = (248, 216, 152)


def canvas(w, h):
    return Image.new("RGBA", (w // 2, h // 2), (0, 0, 0, 0))


def save(img, name):
    img.resize((img.width * 2, img.height * 2), Image.NEAREST).save(OUT / f"{name}.png")


def mix(a, b, t):
    return tuple(round(x + (y - x) * t) for x, y in zip(a, b))


def streak(img, length, alpha, side=0):
    """Drop falling from the top right to the bottom left corner. Only the
    lower `length` part is drawn, fading in from the tail to a bright tip."""
    w, h = img.size
    px = img.load()
    for y in range(h):
        t = 0.35 + 0.65 * (y - (h - length)) / length
        if y < h - length:
            continue
        x = round((w - 1) * (1 - y / (h - 1)))
        px[x, y] = (*mix(RAIN_TOP, RAIN_TIP, t), round(alpha * t))
        if side and 0 <= x + 1 < w:
            px[x + 1, y] = (*RAIN_TOP, round(side * t))


def splash(w, h, arcs):
    img = canvas(w, h)
    d = ImageDraw.Draw(img)
    for box, alpha in arcs:
        d.arc(box, 180, 360, fill=(*RAIN_TIP, alpha))
    return img


def flake(size, shape):
    img = canvas(size, size)
    px = img.load()
    c = size // 4
    for (dx, dy), colour, alpha in shape:
        px[c + dx, c + dy] = (*colour, alpha)
    return img


def ring(core, edge):
    return [((dx, dy), SNOW, 255) for dx, dy in core] + [((dx, dy), SNOW_EDGE, 140) for dx, dy in edge]


def tile(size, count, draw):
    """Tileable sprinkle: every mark is drawn on a 3x3 grid then cropped."""
    rng = random.Random(SEED + size + count)
    big = Image.new("RGBA", (size * 3 // 2, size * 3 // 2), (0, 0, 0, 0))
    d = ImageDraw.Draw(big)
    half = size // 2
    for _ in range(count):
        x, y = rng.randrange(half), rng.randrange(half)
        for ox in (0, half, 2 * half):
            for oy in (0, half, 2 * half):
                draw(d, x + ox - half // 2, y + oy - half // 2, rng)
    return big.crop((half, half, 2 * half, 2 * half))


def fog(size, seed, cells):
    """Soft tileable clouds: periodic value noise, blurred, alpha 144..248
    like the Essentials fog tiles (the game sets the overall opacity)."""
    rng = random.Random(seed)
    n = size // 2
    grid = [[rng.random() for _ in range(cells)] for _ in range(cells)]
    img = Image.new("L", (n, n))
    px = img.load()
    for y in range(n):
        for x in range(n):
            fx, fy = x * cells / n, y * cells / n
            ix, iy = int(fx), int(fy)
            tx, ty = fx - ix, fy - iy
            tx, ty = tx * tx * (3 - 2 * tx), ty * ty * (3 - 2 * ty)
            g = lambda i, j: grid[(iy + j) % cells][(ix + i) % cells]
            top = g(0, 0) + (g(1, 0) - g(0, 0)) * tx
            bot = g(0, 1) + (g(1, 1) - g(0, 1)) * tx
            px[x, y] = round(255 * (top + (bot - top) * ty))
    wrap = Image.new("L", (n * 3, n * 3))
    for ox in range(3):
        for oy in range(3):
            wrap.paste(img, (ox * n, oy * n))
    img = wrap.filter(ImageFilter.GaussianBlur(2)).crop((n, n, 2 * n, 2 * n))
    out = Image.new("RGBA", (n, n))
    out.putdata([(255, 255, 255, 144 + (v * 104 // 255) // 8 * 8) for v in img.tobytes()])
    return out


def main():
    OUT.mkdir(parents=True, exist_ok=True)

    # Rain: thin bright streaks, fading towards the tail (DS rain).
    for name, (w, h), length in (("rain_1", (16, 64), 24), ("rain_2", (32, 96), 36), ("rain_3", (32, 128), 48)):
        img = canvas(w, h)
        streak(img, length, 255, side=90)
        save(img, name)
    save(splash(16, 16, [((1, 4, 6, 8), 220), ((2, 6, 5, 8), 140)]), "rain_4")

    # Storm: longer, heavier streaks with a faint second pixel.
    for name, size, length in (("storm_1", 128, 44), ("storm_2", 192, 64), ("storm_3", 192, 80)):
        img = canvas(size, size)
        streak(img, length, 255, side=110)
        save(img, name)
    save(splash(32, 16, [((2, 3, 13, 8), 230), ((4, 5, 11, 8), 150), ((0, 6, 3, 8), 120)]), "storm_4")

    # Snow (hail_*): round soft flakes, small to large.
    save(flake(16, ring([(0, 0)], [(-1, 0), (1, 0), (0, -1), (0, 1)])), "hail_1")
    save(flake(16, ring([(0, 0), (1, 0), (0, 1), (1, 1)],
                        [(-1, 0), (-1, 1), (2, 0), (2, 1), (0, -1), (1, -1), (0, 2), (1, 2)])), "hail_2")
    save(flake(16, ring([(0, 0), (-1, 0), (1, 0), (0, -1), (0, 1)],
                        [(-1, -1), (1, -1), (-1, 1), (1, 1), (-2, 0), (2, 0), (0, -2), (0, 2)])), "hail_3")

    # Blizzard: six-armed crystals and wind-blown specks.
    star = [(0, 0), (-1, 0), (1, 0), (-2, 0), (2, 0), (-1, -2), (1, 2), (1, -2), (-1, 2)]
    save(flake(16, ring(star, [(0, -1), (0, 1), (-3, 0), (3, 0)])), "blizzard_1")
    save(flake(16, ring([(0, 0), (-1, -1), (1, 1), (-1, 1), (1, -1)], [(0, -1), (0, 1), (-1, 0), (1, 0)])), "blizzard_2")
    save(flake(16, ring([(0, 0), (1, 0)], [(-1, 0), (2, 0)])), "blizzard_3")
    save(flake(16, ring([(0, 0)], [(1, 0), (-1, 0)])), "blizzard_4")
    save(tile(256, 300, lambda d, x, y, r: d.line((x, y, x + r.randint(4, 9), y + r.randint(1, 3)),
                                                    fill=(*SNOW, r.choice((150, 200, 255))))), "blizzard_tile")

    # Sandstorm: two-tone grains and drifting streaks.
    def grain(cells):
        img = canvas(16, 16)
        px = img.load()
        for (dx, dy), colour in cells:
            px[4 + dx, 4 + dy] = (*colour, 255)
        return img
    save(grain([((0, 0), SAND), ((1, 0), SAND_DARK), ((0, -1), SAND_LIGHT)]), "sandstorm_1")
    save(grain([((0, 0), SAND), ((1, 1), SAND_DARK)]), "sandstorm_2")
    save(grain([((0, 0), SAND_LIGHT), ((1, 0), SAND), ((0, 1), SAND), ((1, 1), SAND_DARK)]), "sandstorm_3")
    save(grain([((0, 0), SAND_DARK)]), "sandstorm_4")
    save(tile(256, 360, lambda d, x, y, r: d.line((x, y, x + r.randint(3, 8), y + r.randint(0, 2)),
                                                    fill=(*r.choice((SAND, SAND_DARK, SAND_LIGHT)), r.choice((140, 200, 255))))),
         "sandstorm_tile")

    # Fog: soft clouds, two variants.
    save(fog(128, SEED, 4), "fog_tile")
    save(fog(128, SEED + 1, 4), "fog_tile_2")


if __name__ == "__main__":
    main()
