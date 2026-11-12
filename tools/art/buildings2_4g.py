"""Adds more buildings to the Outside 4G tileset (TypeLocked, issue #321),
from SirMalo's BuildingsRMXP.png (docs/art/inventaire-4g.md): the theatre (I6),
the dojo (J9) and the manor (K1), in the format and with the checks of
tools/art/unique_4g.py (a drawing that its frame cuts stops the script). The
swimmers' pavilion (A6) touches the drawing beside it in the sheet: left out.

Source (docs/CREDITS.md), not in the repository: SirMalo's BuildingsRMXP.png.
Run once from the repository root, after tools/art/street_decor_4g.py (Pillow
needed):
    python3 tools/art/buildings2_4g.py "<SirMalo folder>"
Prints the MapGen lines of what it adds.
"""
import sys

sys.path.insert(0, "tools/art")
from unique_4g import main  # noqa: E402

# See BUILDINGS in unique_4g.py
BUILDINGS = {
    "théâtre": ("ҟ", [(8, 1, 39, 7, 8, 0, 0, 64, 688)], (0, 4, 7, 3), (2, 6), [], []),
    # (the porch of the dojo below it in the sheet stands in its frame)
    "dojo": ("Ҡ", [(9, 0, 63, 8, 8, 0, 0, 64, 1056)], (0, 3, 7, 3), (3, 5), [], [(2, 7), (3, 7), (4, 7)]),
    "manoir": ("ҡ", [(10, 0, 0, 8, 9, 0, 0, 64, 64)], (0, 4, 7, 3), (3, 6), [], []),
}

if __name__ == "__main__":
    main(BUILDINGS)
