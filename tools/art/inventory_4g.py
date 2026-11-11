"""Inventory of the 4G tiles not used yet (TypeLocked, issue #262).

Cuts every sheet of the 4G packs into 16 px tiles (the 32 px sheets are
halved first) and looks for each tile in the game's 4G graphics (tilesets,
autotiles, characters): it is used if a game tile has the same colours on
MATCH of its drawn pixels (see-through colours left out). A tile tinted when
it was copied is not found: check the chunks by eye before calling them new.

Writes, for each sheet, a map of the sheet (used tiles greyed, chunks of
8x8 tiles named « C4 », those mostly unused framed in red) and a JSON of its
chunks, to OUT:
    python3 tools/art/inventory_4g.py "<packs folder>" OUT
where the packs folder holds SirMalo/, the unpacked DPPt Exterior Ground
Tiles v1/, HGSS Autotiles/, Remastered Kanto Johto Map Pack/ and the two
PNG sheets (Mew's Gen 4 Interior Tiles, alchemybats). Pillow needed.
"""
import glob
import json
import os
import sys
import numpy as np
from PIL import Image, ImageDraw

GAME = [
    "Graphics/Tilesets/Outside 4G.png", "Graphics/Tilesets/Cave 4G.png",
    "Graphics/Tilesets/Interior 4G.png", "Graphics/Tilesets/Underwater 4G.png",
]
GAME_GLOBS = ["Graphics/Autotiles/HGSS *.png", "Graphics/Autotiles/*4G.png", "Graphics/Characters/*.png"]
# See-through and unused colours of the packs
CLEAR = {(240, 91, 161), (255, 0, 255), (255, 245, 104), (255, 255, 255)}
# Sheets: name => (glob under the packs folder, tile size of the file)
SHEETS = {
    "SirMalo Nature": ("SirMalo/NatureRMXP.png", 16),
    "SirMalo Buildings": ("SirMalo/BuildingsRMXP.png", 16),
    "SirMalo Urban": ("SirMalo/UrbanRMXP.png", 16),
    "Mew Interior": ("Mew's Gen 4 Interior Tiles.png", 16),
    "alchemybats DPP": ("alchemybats DPP Sinnoh Overworld V2.png", 16),
    "Remastered Caves": ("Remastered Kanto Johto Map Pack/Graphics/Tilesets/Caves.png", 32),
    "Remastered Johto": ("Remastered Kanto Johto Map Pack/Graphics/Tilesets/JohtoCompactExterior.png", 32),
    "Remastered Johto ship": ("Remastered Kanto Johto Map Pack/Graphics/Tilesets/Johtoshiptile.png", 32),
    "Remastered Kanto": ("Remastered Kanto Johto Map Pack/Graphics/Tilesets/KANTO50S_OUT.png", 32),
}
DPPT = "DPPt Exterior Ground Tiles v1/Platinum/*.png"
BACK = (40, 40, 48, 255)
# Share of a tile's drawn pixels that must be the same as a game tile's
MATCH = 0.75
# Sheets are read in chunks of CHUNK x CHUNK tiles, named by column letter
# and band number (« C4 »); SirMalo's columns start 1 tile in, every 9 tiles
CHUNK = 8
SIRMALO_GRID = (1, 9)
# A chunk is « unused » (framed in red) with this share of unused tiles
UNUSED_SHARE = 0.5
AUTOTILES = ["HGSS Autotiles/HGSS *.png", "Remastered Kanto Johto Map Pack/Graphics/Autotiles/*.png"]


def tiles(image, size):
    """{(x, y): 16x16x4 array} of an image cut in size px tiles."""
    a = np.asarray(image.convert("RGBA"))
    if size != 16:
        a = a[::size // 16, ::size // 16]
    out = {}
    for y in range(a.shape[0] // 16):
        for x in range(a.shape[1] // 16):
            out[(x, y)] = a[y * 16:(y + 1) * 16, x * 16:(x + 1) * 16]
    return out


def opaque(tile):
    """Mask of the drawn pixels of a pack tile (see-through colours out)."""
    rgb = tile[:, :, :3]
    mask = tile[:, :, 3] >= 128
    for colour in CLEAR:
        mask &= ~(rgb == colour).all(axis=2)
    return mask


class Game:
    """The game's 4G tiles, indexed by their 4x4 blocks. A pack tile is in
    the game if a game tile has the same colours on MATCH of its drawn
    pixels: the game may have drawn a ground under it, or trimmed it."""

    def __init__(self):
        files = GAME + [f for pattern in GAME_GLOBS for f in sorted(glob.glob(pattern))]
        found = {}
        for path in files:
            image = Image.open(path).convert("RGBA")
            # Characters and autotiles: 32 px frames are not always on the
            # grid of 32, so both halvings are tried at each 16 px step
            for oy in (0, 16):
                for ox in (0, 16):
                    shifted = image.crop((ox, oy, image.width, image.height))
                    for tile in tiles(shifted, 32).values():
                        if tile[:, :, 3].any():
                            for rgb in (tile[:, :, :3], tile[:, ::-1, :3]):
                                found.setdefault(rgb.tobytes(), np.ascontiguousarray(rgb))
        self.tiles = np.stack(list(found.values()))
        self.index = {}
        for i, tile in enumerate(self.tiles):
            for by in range(4):
                for bx in range(4):
                    k = (bx, by, tile[by * 4:by * 4 + 4, bx * 4:bx * 4 + 4].tobytes())
                    self.index.setdefault(k, set()).add(i)

    def has(self, tile):
        """None if the tile is empty (or a speck), else whether it is in the game."""
        mask = opaque(tile)
        if mask.sum() < 16:
            return None
        rgb = tile[:, :, :3]
        candidates = set()
        blocks = 0
        for by in range(4):
            for bx in range(4):
                if not mask[by * 4:by * 4 + 4, bx * 4:bx * 4 + 4].all():
                    continue
                blocks += 1
                candidates |= self.index.get((bx, by, rgb[by * 4:by * 4 + 4, bx * 4:bx * 4 + 4].tobytes()), set())
        if blocks and not candidates:
            return False
        pool = self.tiles[sorted(candidates)] if blocks else self.tiles
        same = (pool[:, mask] == rgb[mask]).all(axis=-1).mean(axis=1)
        return bool(same.max() >= MATCH)


def chunk_of(cell, grid):
    """Name of the chunk (column letter, band number) holding a cell, or None
    on the gap between two columns."""
    origin, pitch = grid
    cx, rest = divmod(cell[0] - origin, pitch)
    if cell[0] < origin or rest >= CHUNK:
        return None
    return f"{chr(ord('A') + cx)}{cell[1] // CHUNK + 1}"


def inventory(name, image, size, grid, game, out):
    cut = tiles(image, size)
    state = {cell: game.has(tile) for cell, tile in cut.items()}
    full = {cell for cell, has in state.items() if has is not None}
    found = {cell for cell in full if state[cell]}
    chunks = {}
    for cell in full:
        label = chunk_of(cell, grid)
        if label:
            entry = chunks.setdefault(label, {"tiles": 0, "used": 0})
            entry["tiles"] += 1
            entry["used"] += cell in found
    # Map: used tiles greyed, a grid of chunks with their names; a chunk
    # with at least UNUSED_SHARE of its tiles unused is framed in red
    sheet = Image.new("RGBA", (image.width * 16 // size, image.height * 16 // size), BACK)
    for cell, tile in cut.items():
        tile = Image.fromarray(tile)
        if cell in found:
            tile = Image.blend(tile.convert("L").convert("RGBA"), Image.new("RGBA", (16, 16), BACK), 0.6)
        sheet.alpha_composite(tile, (cell[0] * 16, cell[1] * 16))
    draw = ImageDraw.Draw(sheet)
    origin, pitch = grid
    for label, entry in sorted(chunks.items()):
        cx = ord(label[0]) - ord("A")
        cy = int(label[1:]) - 1
        x0, y0 = (origin + cx * pitch) * 16, cy * CHUNK * 16
        unused = entry["tiles"] - entry["used"]
        colour = (255, 40, 40, 255) if unused >= entry["tiles"] * UNUSED_SHARE else (120, 120, 140, 255)
        draw.rectangle((x0, y0, x0 + CHUNK * 16 - 1, y0 + CHUNK * 16 - 1), outline=colour, width=1)
        draw.text((x0 + 2, y0 + 1), label, fill=(255, 255, 0, 255), stroke_width=1, stroke_fill=(0, 0, 0, 255))
    slug = name.lower().replace(" ", "-")
    sheet.convert("RGB").save(os.path.join(out, f"{slug}.png"), optimize=True)
    with open(os.path.join(out, f"{slug}.json"), "w") as f:
        json.dump({"sheet": name, "tiles": len(full), "used": len(found), "chunks": chunks}, f, indent=1, sort_keys=True)
    framed = sum(1 for e in chunks.values() if e["tiles"] - e["used"] >= e["tiles"] * UNUSED_SHARE)
    print(f"{name} : {len(full)} tuiles, {len(found)} dans le jeu, {framed} planches sur {len(chunks)} surtout inutilisées")


def main():
    packs, out = sys.argv[1], sys.argv[2]
    os.makedirs(out, exist_ok=True)
    game = Game()
    for name, (pattern, size) in SHEETS.items():
        grid = SIRMALO_GRID if name.startswith("SirMalo") else (0, CHUNK)
        for path in glob.glob(os.path.join(packs, pattern)):
            inventory(name, Image.open(path), size, grid, game, out)
    # Small sheets and autotiles: how many of their tiles are in the game
    report = []
    for pattern in [DPPT] + AUTOTILES:
        for path in sorted(glob.glob(os.path.join(packs, pattern))):
            size = 32 if "Remastered" in path or "HGSS" in path else 16
            states = [game.has(t) for t in tiles(Image.open(path), size).values()]
            full = [has for has in states if has is not None]
            report.append({"file": os.path.relpath(path, packs), "tiles": len(full), "used": sum(full)})
            print(f"{os.path.relpath(path, packs)} : {sum(full)}/{len(full)}")
    with open(os.path.join(out, "petites-planches.json"), "w") as f:
        json.dump(report, f, indent=1)


if __name__ == "__main__":
    main()
