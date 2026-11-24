"""Draw the Family casino's deck of cards (#330).

52 cards and a back, 80x112 each, in Graphics/UI/Casino/cards.png: one row per
suit (Fire, Water, Grass, Electric), ranks 2..10, J, Q, K, A from left to
right; the back is the first cell of a fifth row. The four suits are four
types with their symbol; the faces show a Pokemon of their type, stronger
from J to K, and the Ace a legendary one. The Pokemon are the game's own
icons (Graphics/Pokemon/Icons). The back has the Family's colours.

Usage: python3 tools/art/casino_cards.py [--preview out.png]
--preview also draws a board (the sheet and a mock-up of the poker screen at
512x384), both at 2x, to check the cards are readable.
"""
import sys
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "Graphics" / "UI" / "Casino" / "cards.png"
W, H = 80, 112
RANKS = ["2", "3", "4", "5", "6", "7", "8", "9", "10", "V", "D", "R", "A"]

# Suit: (type, main colour, dark colour, faces J/Q/K/A)
SUITS = [
    ("FIRE", (240, 128, 48), (156, 60, 16), ["CHARMANDER", "CHARMELEON", "CHARIZARD", "MOLTRES"]),
    ("WATER", (104, 144, 240), (40, 72, 160), ["SQUIRTLE", "WARTORTLE", "BLASTOISE", "KYOGRE"]),
    ("GRASS", (120, 200, 80), (48, 116, 32), ["BULBASAUR", "IVYSAUR", "VENUSAUR", "CELEBI"]),
    ("ELECTRIC", (248, 208, 48), (152, 112, 8), ["PICHU", "PIKACHU", "RAICHU", "ZAPDOS"]),
]

# 9x9 symbols of the four types
SYMBOLS = {
    "FIRE": [
        "....#....",
        "....##...",
        "...###...",
        "..####.#.",
        "..######.",
        ".########",
        ".###.####",
        ".##...##.",
        "..#####..",
    ],
    "WATER": [
        "....#....",
        "....#....",
        "...###...",
        "..#####..",
        ".#######.",
        ".##.####.",
        ".##.####.",
        "..#####..",
        "...###...",
    ],
    "GRASS": [
        ".....####",
        "...######",
        "..#####.#",
        ".#####.##",
        ".####.###",
        ".##.####.",
        "..#####..",
        ".#.......",
        "#........",
    ],
    "ELECTRIC": [
        "....####.",
        "...####..",
        "..####...",
        ".#######.",
        "...####..",
        "..###....",
        ".###.....",
        ".##......",
        "#........",
    ],
}

# Pip centres of the number cards, in a 32x60 box (x 0..32, y 0..60),
# stretched to the card (pip_at)
PIPS = {
    2: [(16, 0), (16, 60)],
    3: [(16, 0), (16, 30), (16, 60)],
    4: [(0, 0), (32, 0), (0, 60), (32, 60)],
    5: [(0, 0), (32, 0), (16, 30), (0, 60), (32, 60)],
    6: [(0, 0), (32, 0), (0, 30), (32, 30), (0, 60), (32, 60)],
    7: [(0, 0), (32, 0), (16, 15), (0, 30), (32, 30), (0, 60), (32, 60)],
    8: [(0, 0), (32, 0), (16, 15), (0, 30), (32, 30), (16, 45), (0, 60), (32, 60)],
    9: [(0, 0), (32, 0), (0, 20), (32, 20), (16, 30), (0, 40), (32, 40), (0, 60), (32, 60)],
    10: [(0, 0), (32, 0), (16, 10), (0, 20), (32, 20), (0, 40), (32, 40), (16, 50), (0, 60), (32, 60)],
}

PAPER = (248, 244, 232)
EDGE = (40, 36, 40)
WINE, DARK_WINE, GOLD = (122, 44, 60), (56, 20, 30), (168, 132, 48)


def symbol(kind, colour, dark):
    """The symbol of a type, 11x11 with a dark outline."""
    rows = SYMBOLS[kind]
    image = Image.new("RGBA", (11, 11), (0, 0, 0, 0))
    filled = {(x + 1, y + 1) for y, row in enumerate(rows) for x, c in enumerate(row) if c == "#"}
    for x in range(11):
        for y in range(11):
            if (x, y) in filled:
                image.putpixel((x, y), colour + (255,))
            elif any((x + dx, y + dy) in filled for dx in (-1, 0, 1) for dy in (-1, 0, 1)):
                image.putpixel((x, y), dark + (255,))
    return image


def icon(species):
    """First frame of a Pokemon's icon, cropped to its pixels."""
    image = Image.open(ROOT / "Graphics" / "Pokemon" / "Icons" / f"{species}.png").convert("RGBA")
    frame = image.crop((0, 0, image.height, image.height))
    return frame.crop(frame.getbbox())


def blank():
    card = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    draw = ImageDraw.Draw(card)
    draw.rounded_rectangle((0, 0, W - 1, H - 1), radius=5, fill=PAPER, outline=EDGE)
    return card, draw


# 5x7 rank glyphs, drawn bold (each pixel doubled to the right): the game's
# pixel fonts draw R and A alike
GLYPHS = {
    "0": ["01110", "10001", "10011", "10101", "11001", "10001", "01110"],
    "1": ["00100", "01100", "00100", "00100", "00100", "00100", "01110"],
    "2": ["01110", "10001", "00001", "00110", "01000", "10000", "11111"],
    "3": ["11110", "00001", "00001", "01110", "00001", "00001", "11110"],
    "4": ["00010", "00110", "01010", "10010", "11111", "00010", "00010"],
    "5": ["11111", "10000", "11110", "00001", "00001", "10001", "01110"],
    "6": ["00110", "01000", "10000", "11110", "10001", "10001", "01110"],
    "7": ["11111", "00001", "00010", "00100", "01000", "01000", "01000"],
    "8": ["01110", "10001", "10001", "01110", "10001", "10001", "01110"],
    "9": ["01110", "10001", "10001", "01111", "00001", "00010", "01100"],
    "V": ["10001", "10001", "10001", "10001", "01010", "01010", "00100"],
    "D": ["11110", "10001", "10001", "10001", "10001", "10001", "11110"],
    "R": ["11110", "10001", "10001", "11110", "10100", "10010", "10001"],
    "A": ["00100", "01010", "10001", "10001", "11111", "10001", "10001"],
}


def rank_text(rank, colour):
    """A rank in GLYPHS, 7 pixels high."""
    image = Image.new("RGBA", (7 * len(rank), 7), (0, 0, 0, 0))
    for i, char in enumerate(rank):
        for y, row in enumerate(GLYPHS[char]):
            for x, bit in enumerate(row):
                if bit == "1":
                    image.putpixel((i * 7 + x, y), colour + (255,))
                    image.putpixel((i * 7 + x + 1, y), colour + (255,))
    return image


def corners(card, rank, mark, dark):
    """Rank and symbol side by side at the top left, and upside down at the
    bottom right."""
    corner = Image.new("RGBA", (30, 11), (0, 0, 0, 0))
    text = rank_text(rank, dark)
    corner.alpha_composite(text, (0, 2))
    corner.alpha_composite(mark, (text.width + 1, 0))
    card.alpha_composite(corner, (4, 4))
    card.alpha_composite(corner.rotate(180), (W - 34, H - 15))


def face_card(suit, rank, species):
    kind, colour, dark, _ = suit
    card, draw = blank()
    mark = symbol(kind, colour, dark)
    corners(card, rank, mark, dark)
    # A panel of the type's colour with the Pokemon on it
    light = tuple((c + 255 * 2) // 3 for c in colour)
    draw.rounded_rectangle((5, 17, W - 6, H - 18), radius=3, fill=light, outline=dark)
    pokemon = icon(species)
    if rank == "A":
        big = mark.resize((44, 44), Image.NEAREST)
        card.alpha_composite(big, ((W - 44) // 2, (H - 44) // 2))
    x = (W - pokemon.width) // 2
    y = (H - pokemon.height) // 2
    card.alpha_composite(pokemon, (x, y))
    return card


def number_card(suit, value):
    kind, colour, dark, _ = suit
    card, _ = blank()
    mark = symbol(kind, colour, dark)
    corners(card, str(value), mark, dark)
    for px, py in PIPS[value]:
        card.alpha_composite(mark, (20 + (px * 40 // 32) - 5, 24 + (py * 64 // 60) - 5))
    return card


def back():
    card = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    draw = ImageDraw.Draw(card)
    draw.rounded_rectangle((0, 0, W - 1, H - 1), radius=5, fill=WINE, outline=EDGE)
    draw.rounded_rectangle((4, 4, W - 5, H - 5), radius=3, outline=GOLD)
    # A diamond lattice in dark wine, a gold lozenge in the middle
    for y in range(6, H - 6):
        for x in range(6, W - 6):
            if (x + y) % 8 == 0 or (x - y) % 8 == 0:
                card.putpixel((x, y), DARK_WINE + (255,))
    cx, cy = W // 2, H // 2
    draw.polygon([(cx, cy - 16), (cx + 12, cy), (cx, cy + 16), (cx - 12, cy)], fill=DARK_WINE, outline=GOLD)
    draw.polygon([(cx, cy - 8), (cx + 6, cy), (cx, cy + 8), (cx - 6, cy)], fill=GOLD)
    return card


def sheet():
    image = Image.new("RGBA", (W * 13, H * 5), (0, 0, 0, 0))
    for row, suit in enumerate(SUITS):
        for col, rank in enumerate(RANKS):
            if col < 9:
                card = number_card(suit, col + 2)
            else:
                card = face_card(suit, rank, suit[3][col - 9])
            image.alpha_composite(card, (col * W, row * H))
    image.alpha_composite(back(), (0, 4 * H))
    return image


def preview(cards, path):
    """The sheet and a 512x384 mock-up of the poker screen, at 2x."""
    felt = (24, 92, 60)
    screen = Image.new("RGBA", (512, 384), felt + (255,))
    hand = [(0, 8), (1, 8), (2, 10), (3, 11), (0, 12)]
    for i, (row, col) in enumerate(hand):
        card = cards.crop((col * W, row * H, (col + 1) * W, (row + 1) * H))
        screen.alpha_composite(card, (44 + i * 86, 160))
    dealer = [(4, 0), (1, 4)]
    for i, (row, col) in enumerate(dealer):
        card = cards.crop((col * W, row * H, (col + 1) * W, (row + 1) * H))
        screen.alpha_composite(card, (170 + i * 86, 24))
    board = Image.new("RGBA", (cards.width * 2, cards.height * 2 + 384 * 2 + 16), (64, 64, 64, 255))
    board.alpha_composite(cards.resize((cards.width * 2, cards.height * 2), Image.NEAREST), (0, 0))
    board.alpha_composite(screen.resize((1024, 768), Image.NEAREST), (0, cards.height * 2 + 16))
    board.save(path)


def main():
    cards = sheet()
    OUT.parent.mkdir(parents=True, exist_ok=True)
    cards.save(OUT)
    print(f"{OUT.relative_to(ROOT)} : {cards.width}x{cards.height}")
    if "--preview" in sys.argv:
        path = sys.argv[sys.argv.index("--preview") + 1]
        preview(cards, path)
        print(path)


if __name__ == "__main__":
    main()
