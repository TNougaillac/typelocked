"""Adds more unique buildings to the Outside 4G tileset (TypeLocked, issue
#299, part 2), from SirMalo's BuildingsRMXP.png (docs/art/inventaire-4g.md):
the futuristic dome (J2 to J5) and the glass tower (P4 to P6), each cut in
halves by the sheet and put back together, like the
buildings of tools/art/unique_4g.py (same format, same checks: a drawing
that its frame cuts stops the script).

Source (docs/CREDITS.md), not in the repository: SirMalo's BuildingsRMXP.png.
Run once from the repository root, after tools/art/bridges_4g.py (Pillow
needed):
    python3 tools/art/unique2_4g.py "<SirMalo folder>"
Prints the MapGen lines of what it adds.
"""
import sys

sys.path.insert(0, "tools/art")
from unique_4g import main  # noqa: E402

# See BUILDINGS in unique_4g.py
BUILDINGS = {
    # (its middle spike stands three rows above its halves)
    "dôme futuriste": ("Ѭѭ", [(9, 0, 9, 8, 13, 0, 3, 100, 200), (9, 0, 20, 8, 16, 8, 0, 40, 416)], (1, 10, 14, 4), (8, 13), [], []),
    # (its left side is drawn apart, above it in the sheet)
    "tour de verre": ("Ѯѯ", [(15, 5, 27, 3, 8, 0, 0, 110, 500), (15, 0, 35, 6, 8, 3, 0, 40, 600)], (1, 3, 8, 4), None,
                      [(1, 6, 41), (1, 6, 42), (1, 7, 41), (1, 7, 42), (1, 5, 43), (1, 6, 43), (1, 7, 43)], [(8, 6), (8, 7)]),
}

if __name__ == "__main__":
    main(BUILDINGS)
