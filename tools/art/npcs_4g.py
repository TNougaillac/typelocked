"""Overworld sheets 4G of the NPCs and trainers (#201): each charset of
Graphics/Characters used by WorldEvents (trainers of the routes, the
professor, the townsfolk « NPC 01 » to « NPC 29 ») and by the Family
(lieutenants, Anciens, Parrain) is copied from a sheet of the Ultimate Gen 4
Overworlds Pack (see docs/CREDITS.md). The pack's sheets are RMXP charsets
(4x4 frames of 64x64), so they are copied as they are. Battle sprites stay.
Each sheet of the pack is used once, so no two characters look the same.
The Cousins and the nurse are recoloured from the pack by
family_henchmen.py and family_nurse.py.

    python3 tools/art/npcs_4g.py "<folder All Official Overworlds of the pack>"
"""
import shutil
import sys
from pathlib import Path

from PIL import Image

TARGET = Path("Graphics/Characters")
# Charset name => sheet of the pack
TRAINERS = {
    "trainer_YOUNGSTER": "NPC_023_Youngster",
    "trainer_LASS": "NPC_025_Lass",
    "trainer_CAMPER": "NPC_015_Camper",
    "trainer_PICNICKER": "NPC_016_Picnicker",
    "trainer_BUGCATCHER": "NPC_013_Bug_Catcher",
    "trainer_BIRDKEEPER": "NPC_109",
    "trainer_POKEMONBREEDER": "NPC_099",
    "trainer_POKEMONRANGER_F": "NPC_002_Ace_Trainer_F",
    "trainer_AROMALADY": "NPC_051_Aroma_Lady",
    "trainer_PAINTER": "NPC_052",
    "trainer_RUINMANIAC": "NPC_081_Ruin_Maniac",
    "trainer_HIKER": "NPC_046_Hiker",
    "trainer_CRUSHGIRL": "NPC_009_Battle_Girl",
    "trainer_POKEMANIAC": "NPC_084_Poke_Maniac",
    "trainer_LADY": "NPC_043_Lady",
    "trainer_PROFESSOR": "NPC_138_Prof_Rowan",
}
# Townsfolk: NPC 01 is the police, NPC 13 the move relearner (an elder).
TOWNSFOLK = {
    "NPC 01": "NPC_088_Policeman", "NPC 02": "NPC_062", "NPC 03": "NPC_089", "NPC 04": "NPC_090",
    "NPC 05": "NPC_091", "NPC 06": "NPC_039_Poke_Fan_M", "NPC 07": "NPC_093", "NPC 08": "NPC_094",
    "NPC 09": "NPC_064_Waiter", "NPC 10": "NPC_074", "NPC 11": "NPC_076", "NPC 12": "NPC_118",
    "NPC 13": "NPC_073_Elder", "NPC 14": "NPC_101", "NPC 15": "NPC_054_Scientist_M",
    "NPC 16": "NPC_065_Waitress", "NPC 17": "NPC_095", "NPC 18": "NPC_100", "NPC 19": "NPC_096",
    "NPC 20": "NPC_080_Worker", "NPC 21": "NPC_053_Super_Nerd", "NPC 22": "NPC_097",
    "NPC 23": "NPC_107", "NPC 24": "NPC_108", "NPC 25": "NPC_092", "NPC 26": "NPC_106",
    "NPC 27": "NPC_075", "NPC 28": "NPC_050", "NPC 29": "NPC_059",
}
# The Family (gym leaders, Elite Four, champions and bosses of the 4G games):
# women for LIEUTENANT_PSYCHIC, _GHOST, _FAIRY and ANCIEN_1 (FEMALE_TYPES).
FAMILY = {
    "trainer_LIEUTENANT_NORMAL": "NPC_139_Silver",
    "trainer_LIEUTENANT_FIRE": "NPC_177_Elite_Four_Flint",
    "trainer_LIEUTENANT_WATER": "NPC_166_Gym_Leader_Crasher_Wake",
    "trainer_LIEUTENANT_GRASS": "NPC_131_Riley",
    "trainer_LIEUTENANT_ELECTRIC": "NPC_170_Gym_Leader_Volkner",
    "trainer_LIEUTENANT_ICE": "NPC_161_Gym_Leader_Pryce",
    "trainer_LIEUTENANT_FIGHTING": "NPC_173_Elite_Four_Bruno",
    "trainer_LIEUTENANT_POISON": "NPC_172_Elite_Four_Koga",
    "trainer_LIEUTENANT_GROUND": "NPC_168_Gym_Leader_Byron",
    "trainer_LIEUTENANT_FLYING": "NPC_155_Gym_Leader_Falkner",
    "trainer_LIEUTENANT_PSYCHIC": "NPC_152_Gym_Leader_Sabrina",
    "trainer_LIEUTENANT_BUG": "NPC_175_Elite_Four_Aaron",
    "trainer_LIEUTENANT_ROCK": "NPC_163_Gym_Leader_Roark",
    "trainer_LIEUTENANT_GHOST": "NPC_167_Gym_Leader_Fantina",
    "trainer_LIEUTENANT_DRAGON": "NPC_181_Champion_Lance",
    "trainer_LIEUTENANT_DARK": "NPC_189_Rocket_Executive_Archer",
    "trainer_LIEUTENANT_STEEL": "NPC_182_Champion_Steven_Stone",
    "trainer_LIEUTENANT_FAIRY": "NPC_146_Caitlin",
    "trainer_ANCIEN_1": "NPC_176_Elite_Four_Bertha",
    "trainer_ANCIEN_2": "NPC_178_Elite_Four_Lucian",
    "trainer_ANCIEN_3": "NPC_197_Galactic_Boss_Cyrus",
    "trainer_ANCIEN_4": "NPC_150_Gym_Leader_Lt_Surge",
    "trainer_PARRAIN": "NPC_190_Rocket_Boss_Giovanni",
}
# Sheets the recolours take (family_henchmen.py, family_nurse.py)
RECOLOURED = ["NPC_184_Rocket_Grunt_M", "NPC_185_Rocket_Grunt_F", "NPC_115_Nurse_1"]


def main():
    folder = Path(sys.argv[1])
    sheets = {**TRAINERS, **TOWNSFOLK, **FAMILY}
    used = list(sheets.values()) + RECOLOURED
    twice = sorted({s for s in used if used.count(s) > 1})
    if twice:
        sys.exit(f"planches utilisées deux fois : {', '.join(twice)}")
    for name, sheet in sheets.items():
        src = folder / f"{sheet}.png"
        size = Image.open(src).size
        if size[0] % 4 or size[1] % 4:
            sys.exit(f"{src} : {size[0]}x{size[1]}, pas une planche de 4x4 images")
        shutil.copyfile(src, TARGET / f"{name}.png")
    print(f"{len(sheets)} planches copiées")


if __name__ == "__main__":
    main()
