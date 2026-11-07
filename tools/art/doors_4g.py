"""Animated doors of the 4G buildings (TypeLocked, issue #199).

Copies SirMalo's door charsets ("Tiles - HGSS for RMXP", Characters folder,
see docs/CREDITS.md) into Graphics/Characters, scaled x2 like the tiles (the
sheets are at the DS size). Each frame is moved 2 px down (at the DS size: its
2 empty bottom rows) so that the door stands on the bottom of its tile, in the
doorway the building's drawing leaves for it. MapProc names them per
building in DOOR_GRAPHICS (Plugins/MapProceduralGenerator/001_Settings.rb).

Run from the repository root (Pillow needed):
    python3 tools/art/doors_4g.py "<SirMalo folder>"
"""
import sys
from PIL import Image

DOORS = ["Door_PC", "Door_Gym01", "Door_Newbark01", "Door_Olivine01", "Door_Violet01", "Door_Goldenrod01"]
SHIFT = 2


def main():
    for name in DOORS:
        sheet = Image.open(f"{sys.argv[1]}/Characters/{name}.png").convert("RGBA")
        fw, fh = sheet.width // 4, sheet.height // 4
        out = Image.new("RGBA", sheet.size)
        for row in range(4):
            for col in range(4):
                frame = sheet.crop((col * fw, row * fh, col * fw + fw, row * fh + fh - SHIFT))
                out.paste(frame, (col * fw, row * fh + SHIFT))
        out.resize((sheet.width * 2, sheet.height * 2), Image.NEAREST).save(f"Graphics/Characters/{name}.png")
    print(f"{len(DOORS)} portes")


if __name__ == "__main__":
    main()
