"""Generates world-map tiles, map objects, battle backgrounds, portraits and icons.

Run from the repo root:  python3 tools/gen_world.py
"""
import math
import os
import random

from PIL import Image

from pixel import Canvas, Xf, ell, mat, flat, seg

OUT = "game/assets"
DARK = (24, 18, 22)


def rng(seed):
    return random.Random(seed)


def noise_fill(cv, x0, y0, w, h, cols, r, density=1.0):
    for y in range(y0, y0 + h):
        for x in range(x0, x0 + w):
            if r.random() < density:
                cv.dot((x, y), cols[r.randrange(len(cols))])


# ------------------------------------------------------------------ tiles
GRASS = [(66, 98, 52), (72, 106, 56), (60, 90, 48)]
GRASS_DARK = [(46, 70, 40), (52, 76, 44)]
ROAD = [(132, 104, 72), (122, 96, 66), (140, 112, 78)]
WATER = [(40, 74, 110), (46, 82, 120)]
BURNT = [(52, 48, 42), (60, 54, 46), (44, 40, 36)]
SAND = [(176, 152, 108), (168, 144, 100)]
STONE = [(110, 108, 112), (100, 98, 104), (120, 118, 122)]
FIELD = [(150, 130, 62), (140, 120, 56)]
SNOW = [(220, 226, 234), (208, 214, 226)]

TILE_NAMES = ["grass", "grass2", "flowers", "road", "water0", "water1", "bridge_h", "bridge_v",
              "burnt", "sand", "stone", "field", "snow", "mud"]


def tile(name, seed):
    r = rng(seed)
    cv = Canvas(16, 16)
    if name in ("grass", "grass2", "flowers"):
        noise_fill(cv, 0, 0, 16, 16, GRASS, r)
        for _ in range(6 if name != "grass2" else 10):
            x, y = r.randrange(16), r.randrange(1, 16)
            cv.dot((x, y), (96, 136, 70))
            cv.dot((x, y - 1), (110, 150, 80))
        if name == "flowers":
            for _ in range(4):
                x, y = r.randrange(1, 15), r.randrange(1, 15)
                cv.dot((x, y), r.choice([(220, 210, 120), (210, 120, 150), (230, 230, 240)]))
    elif name == "road":
        noise_fill(cv, 0, 0, 16, 16, ROAD, r)
        for _ in range(5):
            cv.dot((r.randrange(16), r.randrange(16)), (100, 80, 56))
            cv.dot((r.randrange(16), r.randrange(16)), (160, 132, 96))
    elif name.startswith("water"):
        f = int(name[-1])
        noise_fill(cv, 0, 0, 16, 16, WATER, rng(77))
        for i in range(4):
            y = (i * 4 + f * 2) % 16
            x = (i * 5 + f * 3) % 12
            for dx in range(4):
                cv.dot((x + dx, y), (110, 150, 190))
    elif name in ("bridge_h", "bridge_v"):
        noise_fill(cv, 0, 0, 16, 16, WATER, rng(77))
        for i in range(16):
            for j in range(2, 14):
                x, y = (i, j) if name == "bridge_h" else (j, i)
                c = (128, 92, 58) if (i // 4) % 2 == 0 else (116, 82, 52)
                if i % 4 == 3:
                    c = (84, 58, 36)
                cv.dot((x, y), c)
        for i in range(16):
            for j in (2, 13):
                x, y = (i, j) if name == "bridge_h" else (j, i)
                cv.dot((x, y), (70, 48, 30))
    elif name == "burnt":
        noise_fill(cv, 0, 0, 16, 16, BURNT, r)
        for _ in range(3):
            cv.dot((r.randrange(16), r.randrange(16)), (180, 80, 40))
    elif name == "sand":
        noise_fill(cv, 0, 0, 16, 16, SAND, r)
    elif name == "stone":
        noise_fill(cv, 0, 0, 16, 16, STONE, r)
        for y in (0, 8):
            for x in range(16):
                cv.dot((x, y), (80, 78, 84))
        for x, y0 in ((0, 0), (8, 8)):
            for y in range(y0, y0 + 8):
                cv.dot((x, y), (80, 78, 84))
    elif name == "field":
        noise_fill(cv, 0, 0, 16, 16, FIELD, r)
        for y in range(1, 16, 3):
            for x in range(16):
                cv.dot((x, y), (118, 100, 46))
    elif name == "snow":
        noise_fill(cv, 0, 0, 16, 16, SNOW, r)
    elif name == "mud":
        noise_fill(cv, 0, 0, 16, 16, [(92, 76, 56), (84, 70, 50)], r)
    return cv.img


def gen_tiles():
    sheet = Image.new("RGBA", (16 * len(TILE_NAMES), 16 * 4))
    for i, n in enumerate(TILE_NAMES):
        for v in range(4):
            sheet.paste(tile(n, i * 31 + v * 7 + 1), (i * 16, v * 16))
    sheet.save(f"{OUT}/world/tiles.png")


# ------------------------------------------------------------------ objects

def obj_tree(seed, pine=False, dead=False):
    r = rng(seed)
    cv = Canvas(20, 28)
    cv.poly(seg((10, 27), (10, 17), 3), mat((88, 60, 38)))
    if dead:
        cv.poly(seg((10, 18), (5, 10), 2), mat((70, 56, 44)))
        cv.poly(seg((10, 20), (15, 12), 2), mat((70, 56, 44)))
        cv.poly(seg((10, 18), (10, 6), 2), mat((70, 56, 44)))
    elif pine:
        for i, (w, y) in enumerate(((9, 20), (8, 15), (6, 10), (4, 5))):
            cv.poly([(10 - w, y), (10 + w, y), (10, y - 9)], mat((38, 74, 52)), band=0.8)
        cv.dot((10, 1), (60, 100, 70))
    else:
        for cx, cy, rr in ((10, 12, 8), (6, 15, 5), (14, 15, 5), (10, 8, 6)):
            cv.poly(ell(cx, cy, rr, rr * 0.85, 14), mat((58, 102, 50)), band=0.75)
        for _ in range(8):
            cv.dot((r.randrange(4, 16), r.randrange(4, 14)), (96, 140, 70))
    cv.outline()
    return cv.img


def obj_mountain(seed, snow=True):
    r = rng(seed)
    cv = Canvas(36, 30)
    cv.poly([(1, 29), (12, 6), (17, 11), (22, 3), (35, 29)], mat((112, 104, 100)), band=0.85)
    cv.poly([(22, 3), (35, 29), (24, 29), (21, 16)], flat((84, 78, 78)))
    cv.poly([(12, 6), (17, 11), (14, 29), (8, 29), (10, 16)], flat((92, 86, 84)))
    if snow:
        cv.poly([(22, 3), (19, 8), (21, 7), (23, 10), (25, 8)], flat((228, 232, 240)))
        cv.poly([(12, 6), (10, 10), (12, 9), (14, 10)], flat((228, 232, 240)))
    for _ in range(10):
        cv.dot((r.randrange(6, 30), r.randrange(14, 28)), (70, 64, 64))
    cv.outline()
    return cv.img


def obj_rock(seed):
    cv = Canvas(16, 12)
    cv.poly([(1, 11), (3, 5), (8, 2), (13, 4), (15, 11)], mat((118, 112, 108)))
    cv.outline()
    return cv.img


def obj_house(burnt=False, seed=0):
    cv = Canvas(26, 26)
    wall = (90, 80, 72) if burnt else (182, 162, 128)
    cv.poly([(3, 25), (3, 12), (23, 12), (23, 25)], mat(wall), band=0.9)
    for x in range(3, 24):
        cv.dot((x, 16), (120, 96, 70) if not burnt else (50, 44, 40))
    cv.poly([(7, 25), (7, 18), (11, 18), (11, 25)], flat((70, 46, 30)))
    cv.poly([(15, 20), (19, 20), (19, 17), (15, 17)], flat((240, 200, 110) if not burnt else (30, 26, 26)))
    if burnt:
        cv.poly([(1, 13), (8, 5), (12, 9), (14, 4), (25, 13)], mat((40, 36, 34)))
    else:
        cv.poly([(1, 13), (13, 3), (25, 13)], mat((130, 90, 54)), band=0.9)
        for y in range(6, 13, 2):
            for x in range(13 - (y - 3), 13 + (y - 3)):
                if 1 <= x <= 25 and (x + y) % 3 == 0:
                    cv.dot((x, y), (100, 66, 40))
    cv.outline()
    return cv.img


def castle(pal, burning=False, fort=False):
    cv = Canvas(56, 52)
    stone = mat(pal["stone"])
    roof = mat(pal["roof"])
    # back keep
    cv.poly([(18, 50), (18, 14), (38, 14), (38, 50)], stone, band=0.95)
    for x in range(18, 38, 4):
        cv.poly([(x, 14), (x + 2, 14), (x + 2, 11), (x, 11)], stone, shade=False)
    if not fort:
        cv.poly([(16, 14), (28, 2), (40, 14)], roof)
    # towers
    for tx in (4, 42):
        cv.poly([(tx, 51), (tx, 20), (tx + 10, 20), (tx + 10, 51)], stone, band=0.95)
        if fort:
            for x in range(tx, tx + 10, 3):
                cv.poly([(x, 20), (x + 1, 20), (x + 1, 17), (x, 17)], stone, shade=False)
        else:
            cv.poly([(tx - 2, 20), (tx + 5, 10), (tx + 12, 20)], roof)
        cv.poly([(tx + 4, 30), (tx + 6, 30), (tx + 6, 26), (tx + 4, 26)], flat((30, 24, 30)))
    # walls + gate
    cv.poly([(10, 51), (10, 32), (46, 32), (46, 51)], stone, band=0.95)
    for x in range(10, 46, 4):
        cv.poly([(x, 32), (x + 2, 32), (x + 2, 29), (x, 29)], stone, shade=False)
    cv.poly([(23, 51), (23, 41), (28, 37), (33, 41), (33, 51)], flat((40, 28, 22)))
    for x in range(24, 33, 2):
        for y in range(41, 51):
            cv.dot((x, y), (90, 80, 70))
    # banners
    for bx in (20, 35):
        cv.poly([(bx, 34), (bx + 3, 34), (bx + 3, 40), (bx + 1.5, 42), (bx, 40)], mat(pal["banner"]), shade=False)
    if burning:
        for x in range(0, 56):
            for y in range(0, 52):
                p = cv.px[x, y]
                if p[3]:
                    cv.px[x, y] = (int(p[0] * 0.55 + 20), int(p[1] * 0.5), int(p[2] * 0.5), 255)
    cv.outline()
    return cv.img


def obj_tent(cloth):
    cv = Canvas(24, 20)
    cv.poly([(1, 19), (12, 3), (23, 19)], mat(cloth), band=0.8)
    cv.poly([(10, 19), (12, 10), (14, 19)], flat((30, 22, 22)))
    cv.line((12, 3), (12, 0), flat((90, 70, 50)))
    cv.outline()
    return cv.img


def obj_chest():
    cv = Canvas(14, 12)
    cv.poly([(1, 11), (1, 5), (13, 5), (13, 11)], mat((130, 84, 44)))
    cv.poly([(1, 5), (2, 2), (12, 2), (13, 5)], mat((150, 100, 52)))
    cv.rect(1, 5, 12, 1, (200, 170, 60))
    cv.rect(6, 5, 2, 3, (230, 200, 80))
    cv.outline()
    return cv.img


def obj_gold():
    cv = Canvas(14, 10)
    for cx, cy in ((4, 7), (9, 7), (7, 5), (6, 8), (10, 5)):
        cv.poly(ell(cx, cy, 3, 2, 10), mat((222, 184, 64)))
    cv.dot((7, 4), (255, 240, 160))
    cv.outline()
    return cv.img


def obj_cage():
    cv = Canvas(18, 22)
    cv.poly([(1, 21), (1, 5), (17, 5), (17, 21)], flat((40, 36, 40)))
    # prisoner silhouette
    cv.poly(ell(9, 10, 2.5, 2.5, 10), mat((214, 160, 120)))
    cv.poly([(6, 21), (6, 13), (12, 13), (12, 21)], mat((150, 156, 170)))
    cv.poly([(6, 9), (7, 7), (11, 7), (12, 9), (9, 8)], flat((220, 190, 90)))
    for x in range(1, 18, 3):
        cv.line((x, 4), (x, 21), flat((110, 100, 96)))
    cv.rect(0, 3, 18, 2, (90, 80, 76))
    cv.rect(0, 20, 18, 2, (90, 80, 76))
    cv.outline()
    return cv.img


def obj_sign():
    cv = Canvas(12, 14)
    cv.poly(seg((6, 13), (6, 4), 2), mat((100, 70, 44)))
    cv.poly([(1, 2), (11, 2), (11, 7), (1, 7)], mat((150, 110, 66)))
    cv.outline()
    return cv.img


def obj_flag(cloth, trim, frame):
    cv = Canvas(14, 20)
    cv.line((2, 19), (2, 1), flat((90, 70, 50)))
    w = [0, 1, 0, -1][frame]
    cv.poly([(3, 1), (12, 2 + w), (12, 9 + w), (3, 8)], mat(cloth), shade=False)
    cv.dot((7, 5 + w // 2), trim)
    cv.outline()
    return cv.img


def obj_campfire(frame):
    cv = Canvas(14, 14)
    cv.poly(seg((2, 12), (12, 10), 2), mat((90, 60, 40)))
    cv.poly(seg((2, 10), (12, 12), 2), mat((80, 54, 36)))
    h = [0, 2, 1][frame]
    cv.poly([(4, 11), (7, 2 - h), (10, 11)], flat((230, 120, 40)))
    cv.poly([(5.5, 11), (7, 5 - h), (8.5, 11)], flat((255, 220, 110)))
    return cv.img


def obj_ruin():
    cv = Canvas(20, 30)
    cv.poly([(3, 29), (3, 6), (7, 4), (9, 8), (12, 3), (16, 7), (16, 29)], mat((96, 92, 96)), band=0.9)
    cv.poly([(8, 29), (8, 22), (11, 20), (11, 29)], flat((30, 26, 30)))
    cv.poly([(9, 13), (10, 13), (10, 10), (9, 10)], flat((30, 26, 30)))
    cv.outline()
    return cv.img


def obj_spire():
    """The Darkspire itself, seen far away in the north."""
    cv = Canvas(24, 56)
    cv.poly([(4, 55), (9, 20), (11, 2), (13, 20), (19, 55)], mat((36, 32, 44)), band=0.95)
    cv.poly([(1, 55), (5, 40), (8, 55)], mat((44, 40, 52)))
    cv.poly([(16, 55), (18, 42), (22, 55)], mat((44, 40, 52)))
    for y in (14, 24, 34):
        cv.dot((11, y), (190, 80, 230))
        cv.dot((12, y), (190, 80, 230))
    cv.outline()
    return cv.img


def gen_objects():
    d = f"{OUT}/world"
    VALE = dict(stone=(150, 150, 158), roof=(46, 76, 150), banner=(46, 76, 160))
    KARR = dict(stone=(84, 78, 80), roof=(110, 30, 30), banner=(130, 26, 30))
    items = {
        "tree": obj_tree(1), "tree2": obj_tree(2), "pine": obj_tree(3, pine=True), "dead_tree": obj_tree(4, dead=True),
        "mountain": obj_mountain(5), "mountain2": obj_mountain(6, snow=False), "rock": obj_rock(7),
        "house": obj_house(), "house_burnt": obj_house(True), "castle_vale": castle(VALE, burning=True),
        "fort_karr": castle(KARR, fort=True), "tent_karr": obj_tent((130, 30, 34)), "tent_vale": obj_tent((46, 76, 160)),
        "chest": obj_chest(), "gold": obj_gold(), "cage": obj_cage(), "sign": obj_sign(), "ruin": obj_ruin(),
        "spire": obj_spire(),
    }
    for n, im in items.items():
        im.save(f"{d}/{n}.png")
    for f in range(4):
        obj_flag((130, 26, 30), (200, 160, 80), f).save(f"{d}/flag_karr_{f}.png")
        obj_flag((46, 76, 160), (230, 230, 236), f).save(f"{d}/flag_vale_{f}.png")
    for f in range(3):
        obj_campfire(f).save(f"{d}/campfire_{f}.png")


# ------------------------------------------------------------------ battle backgrounds
W, H = 640, 360
GRID_TOP = 112


def lerp(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3))


def battle_bg(kind, seed):
    r = rng(seed)
    cv = Canvas(W, H)
    sky_top, sky_bot = {"field": ((40, 46, 78), (196, 120, 90)), "river": ((60, 80, 110), (170, 170, 170)),
                        "fort": ((30, 20, 34), (150, 60, 50)), "ash": ((30, 26, 30), (120, 70, 50))}[kind]
    for y in range(0, 96):
        c = lerp(sky_top, sky_bot, y / 95)
        for x in range(W):
            cv.px[x, y] = c + (255,)
    # stars / embers
    for _ in range(40):
        cv.dot((r.randrange(W), r.randrange(40)), (220, 210, 200))
    # far hills
    for layer, (base_y, amp, col) in enumerate(((70, 18, (70, 60, 80)), (84, 12, (50, 52, 60)))):
        ph = r.random() * 10
        for x in range(W):
            h = base_y + int(amp * math.sin(x / (60 + layer * 30) + ph) + amp * 0.5 * math.sin(x / 23 + ph * 2))
            for y in range(h, 100):
                cv.px[x, y] = col + (255,)
    if kind == "fort":
        # palisade and towers across the back
        for x in range(0, W, 6):
            h = 78 + (x * 7 % 5)
            for y in range(h, 104):
                for dx in range(5):
                    cv.dot((x + dx, y), (70, 50, 36) if dx else (44, 30, 22))
            cv.dot((x + 2, h - 1), (70, 50, 36))
        for tx in (120, 470):
            for y in range(44, 104):
                for x in range(tx, tx + 40):
                    cv.dot((x, y), (78, 72, 76) if (x // 6 + y // 5) % 7 else (60, 56, 60))
            for x in range(tx - 2, tx + 42, 6):
                for y in range(38, 44):
                    for dx in range(3):
                        cv.dot((x + dx, y), (78, 72, 76))
    if kind == "river":
        for y in range(92, 108):
            for x in range(W):
                cv.px[x, y] = ((44, 80, 116) if (x + y * 3) % 17 else (110, 150, 190)) + (255,)
    # tree line
    if kind in ("field", "river", "ash"):
        for x in range(-8, W, 7):
            h = r.randrange(10, 22)
            base = 100
            col = (32, 52, 38) if kind != "ash" else (40, 34, 32)
            for i in range(h):
                w = int((h - i) * 0.45) + 1
                for dx in range(-w, w + 1):
                    cv.dot((x + dx, base - i), col)
    # ground
    ground = {"field": GRASS, "river": GRASS, "fort": [(96, 82, 60), (88, 76, 56), (104, 88, 64)],
              "ash": BURNT}[kind]
    for y in range(100, H):
        shade = 0.82 + 0.18 * min(1, (y - 100) / 120)
        for x in range(W):
            c = ground[r.randrange(len(ground))]
            cv.px[x, y] = tuple(int(v * shade) for v in c) + (255,)
    for _ in range(900):
        x, y = r.randrange(W), r.randrange(104, H)
        c = cv.px[x, y]
        cv.dot((x, y), tuple(min(255, int(v * 1.25)) for v in c[:3]))
    # dirt patches
    for _ in range(14):
        cx, cy = r.randrange(W), r.randrange(130, H - 20)
        rx, ry = r.randrange(10, 30), r.randrange(4, 10)
        for y in range(cy - ry, cy + ry):
            for x in range(cx - rx, cx + rx):
                if ((x - cx) / rx) ** 2 + ((y - cy) / ry) ** 2 < 1 - r.random() * 0.25:
                    cv.dot((x, y), ROAD[r.randrange(3)] if kind != "ash" else (70, 62, 54))
    # vignette
    for y in range(H):
        for x in range(W):
            dx, dy = (x - W / 2) / (W / 2), (y - H / 2) / (H / 2)
            v = max(0.0, (dx * dx + dy * dy) - 0.55)
            if v > 0:
                c = cv.px[x, y]
                k = max(0.45, 1 - v * 0.6)
                cv.px[x, y] = (int(c[0] * k), int(c[1] * k), int(c[2] * k), 255)
    return cv.img


def gen_battle_bgs():
    os.makedirs(f"{OUT}/battle", exist_ok=True)
    for i, k in enumerate(("field", "river", "fort", "ash")):
        battle_bg(k, 100 + i).save(f"{OUT}/battle/bg_{k}.png")
    # obstacles
    for i in range(3):
        obj_rock(20 + i).save(f"{OUT}/battle/rock_{i}.png")
    stump = Canvas(16, 12)
    stump.poly([(2, 11), (3, 4), (13, 4), (14, 11)], mat((110, 76, 46)))
    stump.poly(ell(8, 4, 5, 2, 12), mat((170, 130, 84)))
    stump.outline()
    stump.img.save(f"{OUT}/battle/stump.png")
    obj_tree(31, dead=True).save(f"{OUT}/battle/deadtree.png")
    # arrow + bolt
    a = Canvas(14, 5)
    a.line((0, 2), (11, 2), flat((150, 110, 70)))
    a.poly([(10, 0), (13, 2), (10, 4)], flat((200, 204, 214)))
    a.dot((0, 1), (230, 230, 230))
    a.dot((1, 1), (230, 230, 230))
    a.dot((0, 3), (230, 230, 230))
    a.dot((1, 3), (230, 230, 230))
    a.img.save(f"{OUT}/battle/arrow.png")


# ------------------------------------------------------------------ portraits

PORTRAITS = {
    "kairen": dict(bg=(40, 60, 110), skin=(214, 164, 126), hair=(46, 32, 26), hairstyle="short", beard=None,
                   body=(40, 74, 162), armor=(172, 180, 196), circlet=(220, 220, 230), eyes=(60, 90, 140)),
    "brenna": dict(bg=(70, 70, 90), skin=(226, 180, 146), hair=(222, 190, 100), hairstyle="crop", beard=None,
                   body=(150, 156, 170), armor=(172, 180, 196), scar=True, eyes=(70, 110, 150)),
    "orrin": dict(bg=(60, 54, 70), skin=(200, 150, 120), hair=(200, 200, 204), hairstyle="bald", beard=(210, 210, 214),
                  body=(90, 80, 100), hood=(70, 62, 80), eyes=(40, 40, 40)),
    "garrot": dict(bg=(80, 24, 24), skin=(180, 130, 100), hair=(20, 18, 20), hairstyle="long", beard=(28, 24, 24),
                   body=(84, 82, 94), armor=(70, 68, 80), scar=True, eyes=(160, 40, 30), horns=True),
    "elder": dict(bg=(70, 80, 50), skin=(200, 150, 112), hair=(150, 140, 130), hairstyle="short", beard=(160, 150, 140),
                  body=(110, 90, 60), eyes=(40, 40, 40)),
    "raider": dict(bg=(90, 40, 30), skin=(196, 140, 104), hair=(60, 40, 26), hairstyle="cap", beard=(60, 40, 26),
                   body=(110, 40, 34), eyes=(40, 30, 30)),
    "scout": dict(bg=(50, 80, 70), skin=(210, 160, 120), hair=(110, 70, 40), hairstyle="hood", beard=None,
                  body=(52, 92, 70), hood=(52, 92, 70), eyes=(60, 80, 50)),
}


def portrait(p):
    cv = Canvas(48, 48)
    for y in range(48):
        c = lerp(p["bg"], tuple(int(v * 0.4) for v in p["bg"]), y / 47)
        for x in range(48):
            cv.px[x, y] = c + (255,)
    skin = mat(p["skin"])
    # shoulders
    cv.poly([(4, 48), (8, 36), (18, 32), (30, 32), (40, 36), (44, 48)], mat(p["body"]), band=0.85)
    if p.get("armor"):
        cv.poly(ell(10, 38, 6, 4, 12), mat(p["armor"]))
        cv.poly(ell(38, 38, 6, 4, 12), mat(p["armor"]))
        cv.poly([(18, 48), (19, 36), (29, 36), (30, 48)], mat(p["armor"]), band=0.9)
    if p.get("hood"):
        cv.poly([(10, 40), (11, 16), (17, 8), (31, 8), (37, 16), (38, 40)], mat(p["hood"]), band=0.9)
    # neck + face
    cv.poly([(20, 34), (20, 28), (28, 28), (28, 34)], skin, band=2)
    cv.poly([(15, 20), (16, 12), (20, 8), (28, 8), (32, 12), (33, 20), (31, 27), (27, 31), (21, 31), (17, 27)], skin, band=0.8)
    hair = mat(p["hair"])
    hs = p["hairstyle"]
    if hs == "short":
        cv.poly([(14, 17), (15, 10), (20, 6), (29, 6), (33, 10), (34, 17), (31, 12), (24, 10), (18, 12)], hair)
    elif hs == "crop":
        cv.poly([(14, 15), (15, 9), (21, 5), (29, 6), (34, 11), (34, 15), (30, 10), (22, 9), (17, 11)], hair)
    elif hs == "long":
        cv.poly([(13, 30), (14, 10), (20, 5), (29, 5), (34, 10), (35, 30), (31, 20), (31, 12), (24, 9), (17, 12), (17, 22)], hair)
    elif hs == "bald":
        cv.poly([(14, 20), (15, 14), (17, 14), (17, 20)], hair)
        cv.poly([(31, 20), (31, 14), (33, 14), (34, 20)], hair)
    elif hs == "cap":
        cv.poly([(14, 14), (15, 8), (21, 5), (28, 5), (33, 8), (34, 14)], mat((96, 62, 38)))
    elif hs == "hood":
        cv.poly([(13, 30), (13, 12), (19, 5), (29, 5), (35, 12), (35, 30), (32, 18), (32, 12), (24, 9), (16, 12), (16, 18)], mat(p["hood"]))
    if p.get("circlet"):
        for x in range(16, 33):
            cv.dot((x, 12), p["circlet"])
        cv.dot((24, 11), (120, 170, 230))
    if p.get("horns"):
        cv.poly([(15, 10), (8, 4), (9, 0), (17, 7)], mat((200, 190, 160)))
        cv.poly([(33, 10), (40, 4), (39, 0), (31, 7)], mat((200, 190, 160)))
    # eyes, brows, nose, mouth
    for ex in (19, 26):
        cv.rect(ex, 17, 3, 2, (240, 236, 230))
        cv.rect(ex + 1, 17, 2, 2, p["eyes"])
        cv.rect(ex - 1, 15, 5, 1, tuple(int(v * 0.7) for v in p["hair"]))
    cv.rect(23, 19, 2, 5, tuple(int(v * 0.82) for v in p["skin"]))
    cv.rect(21, 26, 6, 1, (140, 80, 70))
    if p.get("beard"):
        cv.poly([(16, 22), (18, 30), (22, 35), (26, 35), (30, 30), (32, 22), (28, 27), (20, 27)], mat(p["beard"]))
        cv.rect(21, 26, 6, 1, (90, 50, 46))
    if p.get("scar"):
        for i in range(5):
            cv.dot((28 + i // 2, 14 + i), (170, 90, 80))
    # frame
    for i in range(48):
        for c in ((i, 0), (i, 47), (0, i), (47, i)):
            cv.dot(c, (200, 170, 90))
        for c in ((i, 1), (i, 46), (1, i), (46, i)):
            cv.dot(c, (90, 70, 40))
    return cv.img


def gen_portraits():
    os.makedirs(f"{OUT}/portraits", exist_ok=True)
    for n, p in PORTRAITS.items():
        portrait(p).save(f"{OUT}/portraits/{n}.png")


# ------------------------------------------------------------------ icons
ICONS = {
    "gold": ["..####..", ".#yyyy#.", "#yyYyyy#", "#yYYYyy#", "#yyYyyy#", "#yyyyyy#", ".#yyyy#.", "..####.."],
    "attack": ["......#s", ".....#s#", "....#s#.", ".#.#s#..", "..#s#...", "..b#....", ".b.b....", "b......."],
    "defense": ["########", "#sssssS#", "#sbbbsS#", "#sbbbsS#", ".#sbbS#.", ".#ssS#..", "..#S#...", "...#...."],
    "hp": [".##..##.", "#rr##rr#", "#rRrrrr#", "#rrrrrr#", ".#rrrr#.", "..#rr#..", "...##...", "........"],
    "speed": ["..####..", ".#wwww#.", "#ww#.ww#", "#w.#..w#", "#w..##w#", "#w....w#", ".#wwww#.", "..####.."],
    "shots": [".......#", "......#w", ".....#w.", "....#w..", "b..#w...", ".b#w....", "..bb....", ".b..b..."],
    "army": ["..#..#..", ".#s##s#.", ".#ssss#.", "..#bb#..", ".#bbbb#.", "#b#bb#b#", "..#..#..", ".##..##."],
    "xp": ["...#....", "..#y#...", "###y####", "#yyyyyy#", ".#yyyy#.", ".#y##y#.", "#y#..#y#", "##....##"],
}
ICOL = {"#": (24, 18, 22), "y": (222, 184, 64), "Y": (255, 236, 150), "s": (200, 206, 220), "S": (120, 126, 140),
        "b": (110, 74, 44), "r": (200, 40, 50), "R": (255, 150, 150), "w": (220, 220, 220)}


def gen_icons():
    os.makedirs(f"{OUT}/ui", exist_ok=True)
    for n, rows in ICONS.items():
        im = Image.new("RGBA", (8, 8))
        for y, row in enumerate(rows):
            for x, ch in enumerate(row):
                if ch in ICOL:
                    im.putpixel((x, y), ICOL[ch] + (255,))
        im.save(f"{OUT}/ui/{n}.png")


def main():
    os.makedirs(f"{OUT}/world", exist_ok=True)
    gen_tiles()
    gen_objects()
    gen_battle_bgs()
    gen_portraits()
    gen_icons()
    print("ok")


if __name__ == "__main__":
    main()
