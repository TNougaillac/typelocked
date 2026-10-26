"""Nurse of the Family (TypeLocked, #114): the Pokémon Centre nurse works for
the Family, like the clerks.

Recolours Essentials' nurse (Graphics/Characters/NPC 16.png): the pinks of
her hair and dress turn dark wine, the blue ribbons gold. The white cap and
apron stay. The source is Essentials' own file, so the result is the same
each time.

Usage: python3 tools/art/family_nurse.py
Writes Graphics/Characters/NPC Famille infirmiere.png.
"""
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "Graphics" / "Characters" / "NPC 16.png"
TARGET = ROOT / "Graphics" / "Characters" / "NPC Famille infirmiere.png"

COLOURS = {
    (136, 64, 80): (26, 20, 28),     # pink, dark -> near black
    (208, 112, 128): (74, 26, 40),   # pink -> dark wine
    (248, 168, 176): (122, 44, 60),  # pink, light -> wine
    (96, 128, 208): (168, 132, 48),  # blue ribbon -> gold
    (144, 192, 240): (220, 188, 92),  # blue ribbon, light -> light gold
}


def main():
    image = Image.open(SOURCE).convert("RGBA")
    pixels = image.load()
    for y in range(image.height):
        for x in range(image.width):
            r, g, b, a = pixels[x, y]
            if a and (r, g, b) in COLOURS:
                pixels[x, y] = (*COLOURS[(r, g, b)], a)
    image.save(TARGET)


if __name__ == "__main__":
    main()
