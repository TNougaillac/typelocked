"""Nurse of the Family (TypeLocked, #114): the Pokémon Centre nurse works for
the Family, like the clerks.

Recolours the 4G nurse of the Ultimate Gen 4 Overworlds Pack (#201, see
docs/CREDITS.md): her pink hair turns near black, her blue dress dark wine.
The white of her cap and apron stays. The result is the same each time.

Usage: python3 tools/art/family_nurse.py "<folder All Official Overworlds of the pack>"
Writes Graphics/Characters/NPC Famille infirmiere.png.
"""
import sys
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
SOURCE = "NPC_115_Nurse_1.png"
TARGET = ROOT / "Graphics" / "Characters" / "NPC Famille infirmiere.png"

COLOURS = {
    (224, 128, 152): (74, 62, 72),   # pink hair -> near black
    (152, 88, 104): (44, 36, 44),    # pink hair, dark
    (88, 64, 80): (22, 18, 24),      # pink hair, darkest
    (168, 168, 216): (150, 56, 74),  # blue dress, light -> wine
    (136, 168, 232): (168, 132, 48),  # blue trim -> gold
    (112, 120, 184): (122, 44, 60),  # blue dress -> wine
    (120, 120, 160): (122, 44, 60),
    (96, 96, 144): (90, 30, 44),     # blue dress, dark -> dark wine
    (72, 72, 104): (56, 20, 30),
}


def main():
    image = Image.open(Path(sys.argv[1]) / SOURCE).convert("RGBA")
    pixels = image.load()
    for y in range(image.height):
        for x in range(image.width):
            r, g, b, a = pixels[x, y]
            if a and (r, g, b) in COLOURS:
                pixels[x, y] = (*COLOURS[(r, g, b)], a)
    image.save(TARGET)


if __name__ == "__main__":
    main()
