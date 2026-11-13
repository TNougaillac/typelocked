"""Tilesets of the gyms' interiors (TypeLocked, issue #121): one per type of
lieutenant, laid out like the guilds' dungeons (tools/art/guild_dungeons_4g.py:
double walls drawn by Essentials' dungeon painter, Tile = 0,walls), so that a
gym's floor drawn once can wear any type's tileset (WorldEvents swaps its
tileset for its lieutenant's type).
- the back wall: Mew's plaster panel, tinted with the type's colour;
- the side and front walls: Mew's grey strip on black;
- floor: Mew's light stone, tinted with the type's colour; exit: Mew's rug
  shrunk into one tile, on that floor.
Every tile is drawn whole in its 32x32 frame.
Each tileset is a copy of tileset 25 (Cave 4G) with its own graphic, its
walls and rock blocked, its floor and exit walkable.

Source: Graphics/Tilesets/Interior Mew.png (tools/art/interior_mew.py), in
the game. Run from the repository root, after
tools/art/guild_dungeons_4g.py (Pillow needed):
    python3 tools/art/gym_interiors_4g.py [preview.png]
Prints the [dungeon_tilesets.txt] sections.
"""
import json
import subprocess
import sys
from PIL import Image

sys.path.insert(0, "tools/art")
from guild_dungeons_4g import (EXIT, FLOOR, LOWER, MEW, MEW_FLOORS, PANEL_COLUMN, SOURCE_ID, UPPER, VOID,  # noqa: E402
                               WALLS, sheet_for, small_rug, strip_profile, tile)

FIRST_ID = 37
# Colour of each type (the classic ones), by the plugin's type ID
TYPES = {
    "NORMAL": (168, 168, 120), "FIRE": (240, 128, 48), "WATER": (104, 144, 240), "GRASS": (120, 200, 80),
    "ELECTRIC": (248, 208, 48), "ICE": (152, 216, 216), "FIGHTING": (192, 48, 40), "POISON": (160, 64, 160),
    "GROUND": (224, 192, 104), "FLYING": (168, 144, 240), "PSYCHIC": (248, 88, 136), "BUG": (168, 184, 32),
    "ROCK": (184, 160, 56), "GHOST": (112, 88, 152), "DRAGON": (112, 56, 248), "DARK": (112, 88, 72),
    "STEEL": (184, 184, 208), "FAIRY": (238, 153, 172),
}
# Share of the type's colour in the floor and in the back wall
FLOOR_TINT, WALL_TINT = 0.55, 0.5


def tinted(img, colour, share):
    """img with its lightness carried by the colour (share of it, the rest
    its own colours), alpha kept."""
    out = img.copy()
    px = out.load()
    for y in range(out.height):
        for x in range(out.width):
            r, g, b, a = px[x, y]
            light = (r * 299 + g * 587 + b * 114) / 1000 / 160
            px[x, y] = tuple(min(255, int(c * (1 - share) + k * light * share)) for c, k in zip((r, g, b), colour)) + (a,)
    return out


def sheet(mew, profile, colour):
    """A dungeon sheet of the plaster wall and the light stone, both tinted."""
    out = sheet_for(mew, profile, "plâtre", "pierre claire")
    put = lambda n, img: out.paste(img, ((n % 8) * 32, (n // 8) * 32))  # noqa: E731
    top = tinted(tile(mew, PANEL_COLUMN, WALLS["plâtre"]), colour, WALL_TINT)
    bottom = tinted(tile(mew, PANEL_COLUMN, WALLS["plâtre"] + 2), colour, WALL_TINT)
    for key in ("8", "in_7", "in_9"):
        put(UPPER[key], top)
    for key in ("7", "8", "9"):
        put(LOWER[key], bottom)
    floor = tinted(tile(mew, MEW_FLOORS["pierre claire"], 1), colour, FLOOR_TINT)
    put(FLOOR, floor)
    mat = floor.copy()
    mat.alpha_composite(small_rug(mew))
    put(EXIT, mat)
    return out


def main():
    mew = Image.open(MEW).convert("RGBA")
    profile = strip_profile(mew)
    sheets, sections = [], []
    for i, (kind, colour) in enumerate(TYPES.items()):
        tileset_id = FIRST_ID + i
        name = f"Arene 4G {kind.lower()}"
        out = sheet(mew, profile, colour)
        out.save(f"Graphics/Tilesets/{name}.png")
        sheets.append(out)
        subprocess.run(["ruby", "tools/art/tileset_clone.rb", str(SOURCE_ID), str(tileset_id), name, name], check=True)
        passages = {str(n): "=15" for n in list(UPPER.values()) + list(LOWER.values()) + [VOID]}
        passages.update({str(FLOOR): "=0", str(EXIT): "=0"})
        subprocess.run(["ruby", "tools/art/tileset_tables.rb", str(tileset_id), "0", json.dumps(passages)], check=True)
        sections.append(f"[{tileset_id}]   # {name}\nTile = {VOID},void\nTile = {FLOOR},floor\nTile = 0,walls\nDoubleWalls = true")
    print("#-------------------------------\n".join(s + "\n" for s in sections))
    if len(sys.argv) > 1:
        preview = Image.new("RGBA", (6 * 266, 3 * 170), (255, 0, 255, 255))
        for i, s in enumerate(sheets):
            preview.paste(s.crop((0, 0, 256, 160)), ((i % 6) * 266, (i // 6) * 170))
        preview.save(sys.argv[1])


if __name__ == "__main__":
    main()
