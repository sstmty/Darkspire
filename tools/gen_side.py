"""Side-view world art for Darkspire: tiles, parallax backgrounds with the
Spire, decor props, the Coal of Memory brazier and dialogue portraits.

Run from the repo root:  python3 tools/gen_side.py
"""
import math
import os
import random

from PIL import Image

from pixel import Canvas, ell, mat, flat, seg

OUT = "game/assets"
W, H = 640, 360


def lerp(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3))


def noise(cv, x0, y0, w, h, cols, r):
    for y in range(y0, y0 + h):
        for x in range(x0, x0 + w):
            cv.dot((x, y), cols[r.randrange(len(cols))])


# ------------------------------------------------------------------ tiles
# index: 0 ash-grass top, 1 dirt fill, 2 stone top, 3 stone fill, 4 bridge deck,
#        5 bridge girder, 6 wood platform, 7 burnt top, 8 rust top, 9 dark fill

TILES = ["grass_top", "dirt", "stone_top", "stone", "deck", "girder", "plank", "burnt_top", "rust_top", "deep"]
DIRT = [(66, 52, 46), (60, 48, 42), (72, 58, 50)]
DEEP = [(40, 32, 30), (36, 30, 28), (44, 36, 32)]
STONE = [(86, 86, 94), (78, 78, 86), (92, 92, 100)]


def tile(name, v):
    r = random.Random(hash(name) % 1000 + v * 17)
    cv = Canvas(16, 16)
    if name in ("grass_top", "burnt_top", "rust_top"):
        noise(cv, 0, 0, 16, 16, DIRT, r)
        top = {"grass_top": [(92, 100, 78), (80, 90, 70), (104, 110, 86)],
               "burnt_top": [(52, 44, 40), (40, 34, 32), (62, 50, 44)],
               "rust_top": [(120, 72, 46), (104, 62, 40), (134, 84, 52)]}[name]
        for x in range(16):
            h = 3 + r.randrange(3)
            for y in range(h):
                cv.dot((x, y), top[r.randrange(3)])
            if r.random() < 0.3 and name != "rust_top":
                cv.dot((x, 0), top[2])
        if name == "burnt_top":
            for _ in range(3):
                cv.dot((r.randrange(16), r.randrange(4)), (220, 110, 40))
    elif name == "dirt":
        noise(cv, 0, 0, 16, 16, DIRT, r)
        for _ in range(4):
            cv.dot((r.randrange(16), r.randrange(16)), (90, 76, 66))
    elif name == "deep":
        noise(cv, 0, 0, 16, 16, DEEP, r)
    elif name in ("stone_top", "stone"):
        noise(cv, 0, 0, 16, 16, STONE, r)
        for y in (7, 15):
            for x in range(16):
                cv.dot((x, y), (54, 54, 62))
        for x, y0 in ((4 + v % 2 * 4, 0), (12 - v % 2 * 4, 8)):
            for y in range(y0, y0 + 8):
                cv.dot((x, y), (54, 54, 62))
        if name == "stone_top":
            for x in range(16):
                cv.dot((x, 0), (120, 120, 128))
    elif name == "deck":
        noise(cv, 0, 0, 16, 16, [(110, 70, 50), (100, 64, 46)], r)
        for x in range(16):
            cv.dot((x, 0), (150, 96, 64))
            cv.dot((x, 15), (60, 38, 30))
        for x in (2, 13):
            cv.dot((x, 3), (180, 120, 80))
            cv.dot((x, 12), (180, 120, 80))
        for _ in range(6):
            cv.dot((r.randrange(16), r.randrange(16)), (150, 80, 40))
    elif name == "girder":
        for y in range(16):
            for x in range(16):
                if (x + y) % 8 in (0, 1) or (x - y) % 8 in (0, 1) or y < 2:
                    cv.dot((x, y), (96, 60, 44) if r.random() > 0.2 else (140, 76, 40))
    elif name == "plank":
        for y in range(0, 5):
            for x in range(16):
                cv.dot((x, y), (116, 84, 56) if y < 4 else (70, 50, 34))
        for x in (0, 8):
            cv.dot((x, 1), (60, 42, 30))
            cv.dot((x, 2), (60, 42, 30))
    return cv.img


def gen_tiles():
    sheet = Image.new("RGBA", (16 * len(TILES), 16 * 3))
    for i, n in enumerate(TILES):
        for v in range(3):
            sheet.paste(tile(n, v), (i * 16, v * 16))
    sheet.save(f"{OUT}/side/tiles.png")


# ------------------------------------------------------------------ parallax

THEMES = {
    "hollowd": dict(sky=((26, 14, 20), (150, 60, 36)), far=(64, 34, 34), mid=(40, 24, 24), glow=(255, 120, 50)),
    "border": dict(sky=((20, 24, 36), (96, 100, 112)), far=(58, 62, 74), mid=(38, 40, 48), glow=(120, 170, 230)),
}


def spire(cv, cx, base, height, col, glow):
    for y in range(base - height, base):
        t = (y - (base - height)) / height
        w = int(1 + t * t * 26 + t * 6)
        for x in range(cx - w, cx + w + 1):
            cv.dot((x, y), col)
    for i in range(6):
        y = base - height + 20 + i * (height - 40) // 6
        cv.dot((cx, y), glow)
        cv.dot((cx + 1, y), glow)
    for y in range(base - height - 6, base - height + 6):
        cv.dot((cx, y), lerp(glow, col, abs(y - (base - height)) / 6))


def background(theme, layer, seed):
    th = THEMES[theme]
    r = random.Random(seed)
    cv = Canvas(W, H)
    if layer == "sky":
        top, bot = th["sky"]
        for y in range(H):
            c = lerp(top, bot, min(1.0, y / (H * 0.75)))
            for x in range(W):
                cv.px[x, y] = c + (255,)
        for _ in range(60):
            cv.dot((r.randrange(W), r.randrange(H // 3)), lerp(top, (220, 220, 230), r.random() * 0.6))
        spire(cv, 420, 300, 250, lerp(top, (10, 8, 12), 0.5), th["glow"])
    elif layer == "far":
        ph = r.random() * 10
        for x in range(W):
            h = 210 + int(30 * math.sin(x * TAU_W(2) + ph) + 14 * math.sin(x * TAU_W(5) + ph * 3))
            for y in range(h, H):
                cv.px[x, y] = th["far"] + (255,)
    elif layer == "mid":
        for x in range(W):
            h = 260 + int(12 * math.sin(x * TAU_W(3)) + 6 * math.sin(x * TAU_W(11)))
            for y in range(h, H):
                cv.px[x, y] = th["mid"] + (255,)
        # silhouettes of dead trees / ruined houses
        for i in range(9):
            x0 = i * 72 + r.randrange(30)
            if theme == "hollowd" and i % 2 == 0:
                hw, hh = r.randrange(26, 40), r.randrange(24, 36)
                for y in range(270 - hh, 280):
                    for x in range(x0, x0 + hw):
                        cv.dot((x, y), th["mid"])
                for k in range(hw // 2 + 4):
                    for x in range(x0 - 4 + k, x0 + hw + 4 - k):
                        if r.random() > 0.15:
                            cv.dot((x, 270 - hh - k), th["mid"])
            else:
                for y in range(220, 275):
                    cv.dot((x0, y), th["mid"])
                    cv.dot((x0 + 1, y), th["mid"])
                for b in range(4):
                    by = 225 + b * 10
                    for k in range(10):
                        cv.dot((x0 + (k if b % 2 else -k), by - k // 2), th["mid"])
    return cv.img


def TAU_W(n):
    return math.pi * 2 * n / W


def gen_backgrounds():
    for theme in THEMES:
        for i, layer in enumerate(("sky", "far", "mid")):
            background(theme, layer, i * 13 + len(theme)).save(f"{OUT}/side/bg_{theme}_{layer}.png")


# ------------------------------------------------------------------ props

def house(burnt, seed):
    r = random.Random(seed)
    cv = Canvas(72, 60)
    wall = (64, 52, 48) if burnt else (130, 112, 92)
    cv.poly([(6, 59), (6, 26), (66, 26), (66, 59)], mat(wall), band=0.95)
    for y in range(28, 59, 6):
        for x in range(6, 66):
            cv.dot((x, y), (44, 36, 34) if burnt else (100, 84, 70))
    cv.poly([(28, 59), (28, 40), (40, 40), (40, 59)], flat((24, 18, 18)))
    cv.poly([(48, 44), (58, 44), (58, 34), (48, 34)], flat((240, 140, 50) if burnt else (40, 34, 30)))
    if burnt:
        cv.poly([(2, 27), (20, 10), (28, 18), (36, 6), (50, 18), (70, 27)], mat((36, 30, 30)))
        for _ in range(30):
            cv.dot((r.randrange(6, 66), r.randrange(26, 59)), (30, 24, 24))
    else:
        cv.poly([(1, 27), (36, 4), (71, 27)], mat((90, 60, 44)), band=0.9)
    cv.outline()
    return cv.img


def dead_tree(seed):
    r = random.Random(seed)
    cv = Canvas(40, 64)
    cv.poly(seg((20, 63), (21, 20), 5, 3), mat((58, 46, 40)))
    for _ in range(5):
        y = r.randrange(18, 44)
        d = r.choice((-1, 1))
        cv.poly(seg((21, y), (21 + d * r.randrange(8, 16), y - r.randrange(6, 14)), 2.4, 1), mat((58, 46, 40)))
    cv.outline()
    return cv.img


def fence():
    cv = Canvas(48, 20)
    for x in (2, 16, 30, 44):
        cv.poly([(x, 19), (x, 3), (x + 2, 1), (x + 3, 3), (x + 3, 19)], mat((92, 70, 50)))
    cv.poly([(0, 7), (48, 6), (48, 9), (0, 10)], mat((92, 70, 50)))
    cv.poly([(0, 13), (48, 13), (48, 16), (0, 16)], mat((92, 70, 50)))
    cv.outline()
    return cv.img


def cart():
    cv = Canvas(44, 26)
    cv.poly([(2, 16), (36, 16), (40, 6), (4, 6)], mat((96, 70, 48)))
    for cx in (10, 30):
        cv.poly(ell(cx, 19, 6, 6, 14), mat((70, 52, 38)))
        cv.dot((cx, 19), (30, 24, 22))
    cv.poly(seg((36, 14), (44, 18), 2), mat((96, 70, 48)))
    cv.outline()
    return cv.img


def rail():
    cv = Canvas(32, 16)
    for x in (1, 15, 29):
        cv.poly([(x, 15), (x, 2), (x + 2, 2), (x + 2, 15)], mat((110, 66, 44)))
    cv.poly([(0, 3), (32, 3), (32, 5), (0, 5)], mat((128, 78, 48)))
    cv.outline()
    return cv.img


def brazier():
    """Coal of Memory: a stone bowl; the blue flame is particles in game."""
    cv = Canvas(24, 22)
    cv.poly([(6, 21), (8, 12), (16, 12), (18, 21)], mat((84, 82, 92)))
    cv.poly([(2, 12), (22, 12), (19, 7), (5, 7)], mat((100, 98, 108)))
    for x in range(6, 19):
        cv.dot((x, 7), (60, 120, 200))
    cv.dot((10, 6), (140, 200, 255))
    cv.dot((14, 6), (140, 200, 255))
    cv.outline()
    return cv.img


def banner():
    cv = Canvas(16, 48)
    cv.poly(seg((3, 47), (3, 1), 2), mat((80, 60, 44)))
    cv.poly([(4, 3), (15, 3), (15, 26), (10, 22), (4, 26)], mat((60, 60, 66)))
    for y in range(8, 18):
        cv.dot((9, y), (160, 160, 170))
    cv.outline()
    return cv.img


def grave():
    cv = Canvas(16, 18)
    cv.poly([(2, 17), (2, 6), (5, 2), (11, 2), (14, 6), (14, 17)], mat((96, 96, 104)))
    cv.poly([(7, 6), (9, 6), (9, 13), (7, 13)], flat((60, 60, 66)))
    cv.poly([(5, 8), (11, 8), (11, 10), (5, 10)], flat((60, 60, 66)))
    cv.outline()
    return cv.img


def gen_props():
    props = {"house": house(False, 1), "house_burnt": house(True, 2), "house_burnt2": house(True, 3),
             "dead_tree": dead_tree(4), "dead_tree2": dead_tree(5), "fence": fence(), "cart": cart(),
             "rail": rail(), "coal": brazier(), "banner": banner(), "grave": grave()}
    for n, im in props.items():
        im.save(f"{OUT}/side/{n}.png")


# ------------------------------------------------------------------ portraits

PORTRAITS = {
    "said": dict(bg=(50, 52, 64), skin=(206, 170, 146), hair=(40, 34, 32), hairstyle="hood", hood=(108, 108, 118),
                 body=(70, 58, 52), eyes=(40, 34, 30), ember=True, scar=True, stubble=(70, 56, 50)),
    "nayra": dict(bg=(40, 72, 70), skin=(224, 186, 160), hair=(150, 56, 40), hairstyle="long", body=(46, 88, 86),
                  eyes=(60, 140, 160), thread=True),
    "kassian": dict(bg=(56, 56, 66), skin=(196, 160, 136), hair=(196, 196, 200), hairstyle="bald", beard=(200, 200, 204),
                    body=(92, 92, 100), hood=(84, 84, 92), eyes=(70, 70, 70), scar=False),
    "draven": dict(bg=(80, 46, 34), skin=(150, 120, 100), hair=(30, 24, 22), hairstyle="helm", body=(110, 70, 50),
                   armor=(138, 118, 104), eyes=(200, 120, 60), rust=True),
    "shepherd": dict(bg=(70, 30, 24), skin=(214, 204, 180), hair=(40, 34, 34), hairstyle="skull", hood=(66, 58, 60),
                     body=(74, 64, 66), eyes=(255, 120, 40)),
    "echo": dict(bg=(20, 26, 44), skin=(110, 150, 200), hair=(80, 110, 160), hairstyle="long", body=(60, 90, 140),
                 eyes=(200, 230, 255), ghost=True),
}


def portrait(p):
    cv = Canvas(48, 48)
    for y in range(48):
        c = lerp(p["bg"], tuple(int(v * 0.35) for v in p["bg"]), y / 47)
        for x in range(48):
            cv.px[x, y] = c + (255,)
    skin = mat(p["skin"])
    cv.poly([(4, 48), (8, 36), (18, 32), (30, 32), (40, 36), (44, 48)], mat(p["body"]), band=0.85)
    if p.get("armor"):
        cv.poly(ell(10, 38, 6, 4, 12), mat(p["armor"]))
        cv.poly(ell(38, 38, 6, 4, 12), mat(p["armor"]))
    if p.get("hood"):
        cv.poly([(9, 44), (10, 16), (17, 6), (31, 6), (38, 16), (39, 44)], mat(p["hood"]), band=0.9)
    hs = p["hairstyle"]
    if hs == "long":
        cv.poly([(12, 40), (13, 12), (20, 5), (29, 5), (35, 12), (36, 40), (31, 34), (17, 34)], mat(p["hair"]), band=0.9)
    cv.poly([(20, 34), (20, 28), (28, 28), (28, 34)], skin, band=2)
    cv.poly([(15, 20), (16, 12), (20, 8), (28, 8), (32, 12), (33, 20), (31, 27), (27, 31), (21, 31), (17, 27)], skin, band=0.8)
    hair = mat(p["hair"])
    if hs == "long":
        cv.poly([(14, 16), (15, 9), (21, 5), (29, 6), (34, 11), (34, 18), (30, 11), (22, 10), (17, 12)], hair)
    elif hs == "bald":
        cv.poly([(14, 20), (15, 14), (17, 14), (17, 20)], hair)
        cv.poly([(31, 20), (31, 14), (33, 14), (34, 20)], hair)
    elif hs == "hood":
        cv.poly([(13, 30), (13, 12), (19, 4), (29, 4), (35, 12), (35, 30), (32, 18), (32, 12), (24, 9), (16, 12), (16, 18)], mat(p["hood"]))
    eyes_y = 17
    for ex in (19, 26):
        cv.rect(ex, eyes_y, 3, 2, (240, 236, 230))
        cv.rect(ex + 1, eyes_y, 2, 2, p["eyes"])
        cv.rect(ex - 1, eyes_y - 2, 5, 1, tuple(int(v * 0.7) for v in p["hair"]))
    if p.get("ember"):
        cv.rect(27, eyes_y, 2, 2, (255, 140, 60))
        cv.dot((29, eyes_y - 1), (255, 200, 120))
        for i in range(4):
            cv.dot((27 + i % 2, eyes_y + 3 + i), (90, 70, 66))
    cv.rect(23, 19, 2, 5, tuple(int(v * 0.82) for v in p["skin"]))
    cv.rect(21, 26, 6, 1, (140, 80, 70))
    if p.get("stubble"):
        for x in range(18, 31):
            for y in range(25, 31):
                if (x + y) % 2 == 0 and not (21 <= x <= 26 and y == 26):
                    cv.dot((x, y), p["stubble"])
    if p.get("beard"):
        cv.poly([(16, 22), (18, 32), (22, 37), (26, 37), (30, 32), (32, 22), (28, 27), (20, 27)], mat(p["beard"]))
        cv.rect(21, 26, 6, 1, (90, 50, 46))
    if p.get("scar") and not p.get("ember"):
        for i in range(5):
            cv.dot((28 + i // 2, 14 + i), (170, 90, 80))
    if hs == "helm":
        a = mat(p["armor"])
        cv.poly([(13, 32), (13, 12), (18, 5), (30, 5), (35, 12), (35, 32), (30, 34), (18, 34)], a, band=0.9)
        cv.rect(16, 17, 16, 3, (20, 14, 14))
        cv.rect(20, 18, 2, 1, p["eyes"])
        cv.rect(27, 18, 2, 1, p["eyes"])
        for x in range(20, 29, 2):
            for y in range(24, 31, 3):
                cv.dot((x, y), (40, 30, 28))
        cv.poly([(22, 5), (26, 5), (25, 0), (23, 0)], mat((120, 40, 30)))
    if p.get("rust"):
        r = random.Random(9)
        for _ in range(40):
            x, y = r.randrange(10, 38), r.randrange(4, 46)
            if cv.px[x, y][3]:
                cv.dot((x, y), (160, 84, 42))
    if hs == "skull":
        cv.poly([(10, 44), (11, 14), (17, 4), (31, 4), (37, 14), (38, 44)], mat(p["hood"]), band=0.95)
        cv.poly([(16, 12), (32, 12), (33, 24), (29, 32), (19, 32), (15, 24)], mat(p["skin"]))
        cv.rect(18, 17, 5, 4, (20, 12, 12))
        cv.rect(26, 17, 5, 4, (20, 12, 12))
        cv.rect(20, 18, 2, 2, p["eyes"])
        cv.rect(28, 18, 2, 2, p["eyes"])
        cv.rect(23, 23, 2, 3, (40, 30, 30))
        for x in range(19, 30, 2):
            cv.rect(x, 28, 1, 3, (60, 50, 46))
    if p.get("thread"):
        for i in range(40):
            x = 4 + i
            y = int(44 - 3 * math.sin(i / 6))
            cv.dot((x, y), (130, 210, 255))
    if p.get("ghost"):
        r = random.Random(3)
        for y in range(2, 46):
            for x in range(2, 46):
                c = cv.px[x, y]
                if r.random() < 0.25:
                    cv.px[x, y] = (int(c[0] * 0.6), int(c[1] * 0.6), int(c[2] * 0.7), 255)
    for i in range(48):
        for c in ((i, 0), (i, 47), (0, i), (47, i)):
            cv.dot(c, (150, 150, 160))
        for c in ((i, 1), (i, 46), (1, i), (46, i)):
            cv.dot(c, (50, 50, 58))
    return cv.img


def gen_portraits():
    os.makedirs(f"{OUT}/portraits", exist_ok=True)
    for n, p in PORTRAITS.items():
        portrait(p).save(f"{OUT}/portraits/{n}.png")


def main():
    os.makedirs(f"{OUT}/side", exist_ok=True)
    gen_tiles()
    gen_backgrounds()
    gen_props()
    gen_portraits()
    print("ok")


if __name__ == "__main__":
    main()
