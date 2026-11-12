"""Cave tilesets by biome (TypeLocked, issue #300): the same layout as Cave 4G
(tools/art/caves_4g.py: walls where Essentials' dungeon painter looks for
them, rock top, floor, ladder), drawn from the other caves of the "Remastered
Kanto Johto Map Pack" (Caves.png, see docs/CREDITS.md, sources not in the
repository). The pack draws each cave's rock mound the same way, a few rows
apart: a style is the brown cave's layout moved down that many rows, with
its own floor and its own patch on the floor (an autotile like HGSS Cave
sand).
- ice (snow): the blue ice mound, the blue rock floor, patches of snow;
- lava (volcano): the brown mound, the red floor, patches of brown earth;
- moss (dark forest, marsh, tropical forest): the mossy mound, the green
  floor, patches of pale earth.
Each tileset is a copy of tileset 25 (passages kept: the tiles are at the
same places), with its own graphic and autotile.

Run from the repository root with the extracted pack's folder (Pillow needed):
    python3 tools/art/cave_styles_4g.py "<Remastered Kanto Johto Map Pack folder>"
"""
import subprocess
import sys
from PIL import Image

sys.path.insert(0, "tools/art")
from caves_4g import LAYOUT, TILES, tile  # noqa: E402

SOURCE_ID = 25
LADDER = 47
# Styles: name => (tileset ID, rows below the brown cave's mound, floor,
# patch on the floor (3x3), its copy with a hole (2x2), tiles drawn from
# elsewhere: tile => (column, row))
# (the pack has no rounded ends of the south wall for the mossy mound: its
# middle is drawn there)
STYLES = {
    "glace": (28, 48, (3, 93), (0, 104), (3, 104), {}),
    "lave": (29, 0, (6, 34), (0, 36), (3, 36), {}),
    "mousse": (30, 96, (1, 34), (1, 27), (4, 27), {16: (1, 145), 18: (1, 145)}),
}
FLOOR_TILE = 42


def patch_autotile(sheet, blob, hole, floor):
    """RPG Maker XP autotile (96x128) of a patch on the floor: the 3x3 patch,
    the inner corners from the quarters of its copy with a hole that touch
    the hole, the lone tile from the patch's 4 corners (like blob_autotile
    of caves_4g.py)."""
    out = Image.new("RGBA", (96, 128))
    bx, by = blob
    hx, hy = hole
    for y in range(3):
        for x in range(3):
            out.paste(tile(sheet, bx + x, by + y), (x * 32, 32 + y * 32))
    for qx in (0, 1):
        for qy in (0, 1):
            piece = tile(sheet, hx + 1 - qx, hy + 1 - qy)
            out.paste(piece.crop((qx * 16, qy * 16, qx * 16 + 16, qy * 16 + 16)), (64 + qx * 16, qy * 16))
            corner = out.crop((qx * 64, 32 + qy * 64, qx * 64 + 32, 64 + qy * 64))
            out.paste(corner.crop((qx * 16, qy * 16, qx * 16 + 16, qy * 16 + 16)), (qx * 16, qy * 16))
    for y in range(0, 128, 32):
        for x in range(0, 96, 32):
            under = floor.copy()
            under.alpha_composite(out.crop((x, y, x + 32, y + 32)))
            out.paste(under, (x, y))
    return out


def main():
    sheet = Image.open(f"{sys.argv[1]}/Graphics/Tilesets/Caves.png").convert("RGBA")
    for style, (tileset_id, down, floor_at, blob, hole, others) in STYLES.items():
        name = f"Cave 4G {style}"
        patch = f"HGSS Cave {style}"
        floor = tile(sheet, *floor_at)
        if floor.getextrema()[3][0] < 255:
            sys.exit(f"{style} : sol {floor_at} troué")
        out = Image.new("RGBA", (256, TILES // 8 * 32))
        for n, (tx, ty) in LAYOUT.items():
            if n == FLOOR_TILE:
                drawn = floor
            elif n == LADDER:
                # The brown cave's hole with its ladder, on this floor
                drawn = floor.copy()
                drawn.alpha_composite(tile(sheet, tx, ty))
            else:
                drawn = tile(sheet, *others[n]) if n in others else tile(sheet, tx, ty + down)
                if not drawn.getbbox() or any(0 < a < 255 for a in drawn.getchannel("A").get_flattened_data()):
                    sys.exit(f"{style} : tuile {n} vide ou translucide en {(tx, ty + down)}")
            out.paste(drawn, ((n % 8) * 32, (n // 8) * 32))
        out.save(f"Graphics/Tilesets/{name}.png")
        patch_autotile(sheet, blob, hole, floor).save(f"Graphics/Autotiles/{patch}.png")
        subprocess.run(["ruby", "tools/art/tileset_clone.rb", str(SOURCE_ID), str(tileset_id), name, name], check=True)
        subprocess.run(["ruby", "tools/art/tileset_autotiles.rb", str(tileset_id), patch, "", "", "", "", "", ""], check=True)
        print(f"{name} : tileset {tileset_id}, autotile {patch}")


if __name__ == "__main__":
    main()
