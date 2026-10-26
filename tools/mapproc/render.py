"""Draws the JSON of tools/mapproc/dump_place.rb as a PNG (tileset Outside and
its autotiles, as RMXP draws them; animated autotiles show their 1st frame).
Usage: python3 tools/mapproc/render.py place.json out.png [scale]"""
import json
import sys
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
# Autotiles of tileset 1 (Data/Tilesets.rxdata), in order
AUTOTILES = ["Sea", "Sea without shore", "Sea deep", "Sand shore", "Flowers1", "Water rock", "Fountain1"]
# RMXP: the four 16x16 quarters (1-based, 6 per row of the autotile image)
# of each of the 48 patterns
PATTERNS = [
    [27, 28, 33, 34], [5, 28, 33, 34], [27, 6, 33, 34], [5, 6, 33, 34],
    [27, 28, 33, 12], [5, 28, 33, 12], [27, 6, 33, 12], [5, 6, 33, 12],
    [27, 28, 11, 34], [5, 28, 11, 34], [27, 6, 11, 34], [5, 6, 11, 34],
    [27, 28, 11, 12], [5, 28, 11, 12], [27, 6, 11, 12], [5, 6, 11, 12],
    [25, 26, 31, 32], [25, 6, 31, 32], [25, 26, 31, 12], [25, 6, 31, 12],
    [15, 16, 21, 22], [15, 16, 21, 12], [15, 16, 11, 22], [15, 16, 11, 12],
    [29, 30, 35, 36], [29, 30, 11, 36], [5, 30, 35, 36], [5, 30, 11, 36],
    [39, 40, 45, 46], [5, 40, 45, 46], [39, 6, 45, 46], [5, 6, 45, 46],
    [25, 30, 31, 36], [15, 16, 45, 46], [13, 14, 19, 20], [13, 14, 19, 12],
    [17, 18, 23, 24], [17, 18, 11, 24], [41, 42, 47, 48], [5, 42, 47, 48],
    [37, 38, 43, 44], [37, 6, 43, 44], [13, 18, 19, 24], [13, 14, 43, 44],
    [37, 42, 43, 48], [17, 18, 47, 48], [13, 18, 43, 48], [1, 2, 7, 8],
]


def main():
    place = json.loads(Path(sys.argv[1]).read_text())
    scale = float(sys.argv[3]) if len(sys.argv) > 3 else 1
    tileset = Image.open(ROOT / "Graphics/Tilesets/Outside.png").convert("RGBA")
    autotiles = [Image.open(ROOT / f"Graphics/Autotiles/{n}.png").convert("RGBA") for n in AUTOTILES]
    cache = {}

    def tile(tid):
        if tid not in cache:
            if tid >= 384:
                n = tid - 384
                cache[tid] = tileset.crop(((n % 8) * 32, (n // 8) * 32, (n % 8) * 32 + 32, (n // 8) * 32 + 32))
            else:
                image = autotiles[(tid // 48) - 1]
                out = Image.new("RGBA", (32, 32))
                if image.height == 32:
                    out = image.crop((0, 0, 32, 32))
                else:
                    for i, q in enumerate(PATTERNS[tid % 48]):
                        q -= 1
                        part = image.crop(((q % 6) * 16, (q // 6) * 16, (q % 6) * 16 + 16, (q // 6) * 16 + 16))
                        out.paste(part, ((i % 2) * 16, (i // 2) * 16))
                cache[tid] = out
        return cache[tid]

    layers = place["layers"]
    h, w = len(layers[0]), len(layers[0][0])
    out = Image.new("RGBA", (w * 32, h * 32), (0, 0, 0, 255))
    for layer in layers:
        for y, row in enumerate(layer):
            for x, tid in enumerate(row):
                if tid >= 48:
                    t = tile(tid)
                    out.alpha_composite(t, (x * 32, y * 32))
    if scale != 1:
        out = out.resize((int(w * 32 * scale), int(h * 32 * scale)), Image.LANCZOS)
    out.convert("RGB").save(sys.argv[2])


main()
