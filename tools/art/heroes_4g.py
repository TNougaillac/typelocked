"""Charsets 4G of the playable characters (#195): Ethan (boy) and Lyra (girl)
of the Ultimate Gen 4 Overworlds Pack (PurpleZaffre and others, see
docs/CREDITS.md), copied to Graphics/Characters under the names used by
PBS/metadata.txt. The pack's sheets are already RMXP charsets (4x4 frames
of 64x64, the DS sprites scaled x2), so they are copied as they are.

    python3 tools/art/heroes_4g.py "<folder All Official Overworlds of the pack>"
"""
import shutil
import sys
from pathlib import Path

from PIL import Image

TARGET = Path("Graphics/Characters")
# Charset name => sheet of the pack
SHEETS = {
    "hero_boy": "NPC_203_Ethan",
    "hero_boy_run": "NPC_203_Ethan_run",
    "hero_boy_bike": "NPC_203_Ethan_bike",
    "hero_boy_surf": "NPC_203_Ethan_surf",
    "hero_boy_fish": "NPC_203_Ethan_fishing",
    "hero_girl": "NPC_206_Lyra",
    "hero_girl_run": "NPC_206_Lyra_run",
    "hero_girl_bike": "NPC_206_Lyra_bike",
    "hero_girl_surf": "NPC_206_Lyra_surf",
    "hero_girl_fish": "NPC_206_Lyra_fishing",
}


def main():
    folder = Path(sys.argv[1])
    for name, sheet in SHEETS.items():
        src = folder / f"{sheet}.png"
        size = Image.open(src).size
        if size[0] % 4 or size[1] % 4:
            sys.exit(f"{src} : {size[0]}x{size[1]}, pas une planche de 4x4 images")
        shutil.copyfile(src, TARGET / f"{name}.png")
        print(f"{name}.png : {size[0]}x{size[1]} (images de {size[0] // 4}x{size[1] // 4})")


if __name__ == "__main__":
    main()
