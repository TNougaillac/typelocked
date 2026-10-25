"""Henchmen of the Family (TypeLocked, #103): the Cousins in mafia style.

Redraws Essentials' Team Rocket grunts (battle sprites and overworld sheets)
as Family henchmen, all in brown: a pinstripe suit of brown tweed, a flat
cap (coppola) one shade darker, a white shirt with a dark red tie instead of
the R, dark brown leather gloves and shoes, a gold belt buckle; her hair is
black. The sources are Essentials' own files, so the
result is the same each time.

Usage: python3 tools/art/family_henchmen.py
Writes Graphics/Trainers/COUSIN_M.png, COUSIN_F.png and
Graphics/Characters/trainer_COUSIN_M.png, trainer_COUSIN_F.png.
"""
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]

# Grunt colours -> henchman colours
SUIT = {(56, 56, 72): (72, 52, 38), (80, 80, 104): (106, 80, 56), (120, 120, 144): (142, 112, 82)}
CAP = {(56, 56, 72): (52, 36, 26), (80, 80, 104): (80, 58, 40), (120, 120, 144): (110, 84, 60)}
LEATHER = {(152, 152, 168): (52, 36, 26), (176, 176, 192): (70, 50, 36), (200, 200, 216): (92, 68, 50)}
RED = {(160, 72, 64), (208, 96, 88), (240, 104, 96)}
SHIRT = (236, 236, 240)
TIE = (128, 20, 32)
TIE_LIGHT = (176, 40, 48)
GOLD = (208, 172, 72)
# Her red hair turns black
HAIR = {(160, 72, 64): (22, 20, 26), (208, 96, 88): (42, 38, 48), (240, 104, 96): (68, 62, 76)}
OW_HAIR = {(80, 16, 0): (22, 20, 26), (144, 64, 40): (42, 38, 48), (120, 64, 64): (42, 38, 48),
           (224, 112, 80): (68, 62, 76)}
STRIPE = 16             # lighter added to every pinstripe pixel
STRIPE_EVERY = 8        # pixels between pinstripes (4 pixels of art, drawn x2)

# Battle sprites (128x128, art drawn x2): cap bottom, R box (x0, y0, x1, y1),
# shirt (x0, x1, top, bottom) with the tie in its middle, belt buckle box.
BATTLE = {
    "M": {"cap": 30, "logo": (54, 48, 71, 63), "shirt": (58, 66, 40, 64), "tie": (62, 64), "buckle": (70, 70, 73, 75)},
    "F": {"cap": 30, "logo": (62, 48, 75, 61), "shirt": (66, 72, 42, 62), "tie": (68, 70), "buckle": (68, 66, 71, 73)},
}


def box(point, rect):
    x, y = point
    return rect[0] <= x <= rect[2] and rect[1] <= y <= rect[3]


def battle(gender):
    spec = BATTLE[gender]
    im = Image.open(ROOT / f"Graphics/Trainers/TEAMROCKET_{gender}.png").convert("RGBA")
    px = im.load()
    for y in range(im.height):
        for x in range(im.width):
            r, g, b, a = px[x, y]
            if a == 0:
                continue
            c = (r, g, b)
            if c in RED:
                if box((x, y), spec["logo"]):
                    c = SUIT[(80, 80, 104)]
                elif box((x, y), spec["buckle"]):
                    c = GOLD
                elif gender == "F" and y < 45:
                    c = HAIR[c]
                else:
                    c = (60, 34, 28)              # soles, glove seams
            elif c in SUIT:
                if y < spec["cap"]:
                    c = CAP[c]
                else:
                    c = SUIT[c]
                    if x % STRIPE_EVERY in (0, 1):
                        c = tuple(min(255, v + STRIPE) for v in c)
            elif c in LEATHER:
                c = LEATHER[c]
            px[x, y] = (*c, a)
    x0, x1, top, bottom = spec["shirt"]
    t0, t1 = spec["tie"]
    for y in range(top, bottom):
        # Shirt as a V narrowing down to the tie, then the tie alone
        half = max(0, (x1 - x0) // 2 - (y - top) // 3)
        for x in range(x0, x1):
            if px[x, y][3] == 0 or px[x, y][:3] == (0, 0, 0):
                continue
            mid = (x0 + x1) // 2
            if t0 <= x < t1:
                px[x, y] = (*(TIE_LIGHT if x == t0 and y > top + 2 else TIE), 255)
            elif abs(x - mid) <= half and px[x, y][:3] != (0, 0, 0):
                px[x, y] = (*SHIRT, 255)
    return im


# Overworld sheets (4x4 frames of 32x48, art drawn x2): the cap is above
# CAP_ROWS in a frame; the R on the chest (TORSO box of a frame) becomes a
# plain shirt with a straight tie down its middle; other red is her hair, or
# his uniform's trim, which turns to suit.
OW_SUIT = {(72, 72, 88): (82, 60, 42), (136, 144, 144): (132, 104, 76)}
OW_CAP = {(72, 72, 88): (60, 42, 30), (136, 144, 144): (100, 76, 54), (56, 56, 24): (42, 30, 20)}
OW_LEATHER = {(192, 200, 216): (70, 50, 36)}
OW_RED = {(224, 112, 80), (120, 64, 64), (144, 64, 40), (80, 16, 0)}
CAP_ROWS = 18
TORSO = (10, 28, 21, 39)


def overworld(gender):
    im = Image.open(ROOT / f"Graphics/Characters/trainer_TEAMROCKET_{gender}.png").convert("RGBA")
    px = im.load()
    fw, fh = im.width // 4, im.height // 4
    for y in range(im.height):
        for x in range(im.width):
            r, g, b, a = px[x, y]
            if a == 0:
                continue
            c = (r, g, b)
            fy = y % fh
            if fy < CAP_ROWS and c in OW_CAP:
                c = OW_CAP[c]
            elif c in OW_SUIT:
                c = OW_SUIT[c]
            elif c in OW_LEATHER:
                c = OW_LEATHER[c]
            elif c in OW_RED:
                if box((x % fw, fy), TORSO) and y < fh:      # front frames only
                    c = SHIRT
                elif gender == "F":
                    c = OW_HAIR[c]
                else:
                    c = OW_SUIT[(72, 72, 88)]
            px[x, y] = (*c, a)
    for frame in range(4):
        tie(px, frame * fw)
    return im


# Tie: the middle art pixel (2 px wide) of the shirt, below its top row.
def tie(px, left):
    x0, y0, x1, y1 = TORSO
    cells = [(x, y) for y in range(y0, y1 + 1) for x in range(left + x0, left + x1 + 1) if px[x, y][:3] == SHIRT]
    xs = sorted({x for x, _ in cells})
    top = min(y for _, y in cells)
    mid = xs[len(xs) // 2] & ~1
    for x, y in cells:
        if x in (mid, mid + 1) and y >= top + 2:
            px[x, y] = (*TIE, 255)


def main():
    for gender in ("M", "F"):
        battle(gender).save(ROOT / f"Graphics/Trainers/COUSIN_{gender}.png")
        overworld(gender).save(ROOT / f"Graphics/Characters/trainer_COUSIN_{gender}.png")
    print("Cousins redessinés")


if __name__ == "__main__":
    main()
