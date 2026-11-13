"""Charsets 4G of the gym mechanics (#121): the statues the player touches
and the barriers around the lieutenant, cut from the object sheets of the
Ultimate Gen 4 Overworlds Pack (PurpleZaffre and others, see
docs/CREDITS.md). Each charset repeats one frame of its sheet on the 4x4
grid of RMXP, so the event shows it whatever its facing or step.

    python3 tools/art/gym_props_4g.py "<folder All Official Overworlds of the pack>"
"""
import sys
from pathlib import Path

from PIL import Image

TARGET = Path("Graphics/Characters")
# Charset name => (sheet of the pack, column, row of the frame)
FRAMES = {
    "Gym statue": ("Object_Various2", 0, 0),
    "Gym barrier": ("Object_Various2", 3, 1),
    "Gym boulder": ("Object_Strength", 0, 0),
    "Gym ice": ("Object_Ice1", 0, 0),
    "Gym tree": ("Object_Cut", 0, 0),
}


def main():
    folder = Path(sys.argv[1])
    for name, (sheet, col, row) in FRAMES.items():
        src = Image.open(folder / f"{sheet}.png").convert("RGBA")
        w, h = src.size[0] // 4, src.size[1] // 4
        frame = src.crop((col * w, row * h, (col + 1) * w, (row + 1) * h))
        if not frame.getbbox():
            sys.exit(f"{sheet} ({col}, {row}) : image vide")
        out = Image.new("RGBA", src.size, (0, 0, 0, 0))
        for y in range(4):
            for x in range(4):
                out.paste(frame, (x * w, y * h))
        out.save(TARGET / f"{name}.png")
        print(f"{name}.png : {sheet} ({col}, {row}), images de {w}x{h}")


if __name__ == "__main__":
    main()
