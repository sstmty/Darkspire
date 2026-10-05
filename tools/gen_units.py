"""Generates animated unit sprite sheets for Darkspire.

Each sheet has one row per animation (idle, walk, attack, hurt, death) and
one column per frame. Units face right; the game mirrors them for the
left-facing side. A JSON file next to the sheets lists frame counts, fps and
the frame on which an attack lands (or a missile is released).

Run from the repo root:  python3 tools/gen_units.py
"""
import json
import math
import os

from PIL import Image

from pixel import Canvas, Xf, ell, mat, flat, seg, rotate_about

OUT = "game/assets/units"
FW = FH = 64
ANIMS = ["idle", "walk", "attack", "hurt", "death"]
DARK = (24, 18, 22)
SKIN = (214, 160, 120)
LEATHER = (96, 62, 38)
WOOD = (120, 84, 50)

TAU = math.pi * 2


def darker(rgb, k=0.7):
    return tuple(int(c * k) for c in rgb)


# ---------------------------------------------------------------- horse rig

def draw_quadruped(cv, root, p, pal, kind="horse"):
    """Horse or hound. root: Xf at ground point. p: pose dict."""
    dog = kind == "hound"
    body_y = -12 if dog else -22
    body = root.child(p.get("x", 0), body_y + p.get("bob", 0) + p.get("drop", 0), p.get("pitch", 0))
    coat = mat(pal["coat"])
    coat_far = mat(darker(pal["coat"], 0.72))
    hair = mat(pal["hair"])
    hoof = flat(DARK)

    if dog:
        hips = {"bf": (-7, 1), "ff": (5, 1), "bn": (-5, 2), "fn": (7, 2)}
        l1, l2, w1, w2 = 5, 6, 3.4, 2.2
    else:
        hips = {"bf": (-10, 3), "ff": (8, 3), "bn": (-8, 4), "fn": (10, 4)}
        l1, l2, w1, w2 = 8, 10, 5, 2.6

    def leg(key, material):
        a1, a2 = p["legs"][key]
        hx, hy = hips[key]
        f1 = body.child(hx, hy, a1 - p.get("pitch", 0) * 0.6)
        cv.poly(f1.pts(seg((0, -1), (0, l1), w1, w1 * 0.7)), material)
        f2 = f1.child(0, l1, a2)
        cv.poly(f2.pts(seg((0, 0), (0, l2), w2, w2)), material)
        if dog:
            cv.poly(f2.pts([(-1, l2 - 1), (2.5, l2 - 1), (2.5, l2 + 1), (-1, l2 + 1)]), material)
        else:
            cv.poly(f2.pts([(-1.6, l2 - 1), (1.6, l2 - 1), (2, l2 + 1.5), (-1.8, l2 + 1.5)]), hoof, shade=False)

    # tail
    if dog:
        t = body.child(-9, -2, p.get("tail", 0))
        cv.poly(t.pts([(0, 0), (-1, 2), (-6, -2), (-8, -7), (-6, -6), (-4, -3)]), coat)
    else:
        t = body.child(-13, -4, p.get("tail", 0))
        cv.poly(t.pts([(0, -1), (2, 2), (0, 8), (-2, 15), (-5, 17), (-5, 10), (-3, 3)]), hair)

    leg("bf", coat_far)
    leg("ff", coat_far)
    cv.poly(body.pts(ell(0, 0, 9 if dog else 13.5, 4.5 if dog else 7.5)), coat, band=0.72)
    leg("bn", coat)
    leg("fn", coat)

    if pal.get("barding"):
        cloth = mat(pal["cloth"])
        trim = mat(pal["trim"])
        outer = [(-15, -2), (-12, -6), (-4, -7), (6, -7), (12, -5), (15, -1), (15, 6), (12, 10),
                 (9, 8), (6, 10), (3, 8), (0, 10), (-3, 8), (-6, 10), (-9, 8), (-12, 10), (-15, 7)]
        inner = [(x * 0.92, (y - 2 if y > 5 else y)) for x, y in outer]
        cv.poly(body.pts(outer), trim)
        cv.poly(body.pts(inner), cloth, band=0.75)
        cx, cy = body((2, 1))
        for dx, dy in ((0, -2), (-1, -1), (0, -1), (1, -1), (-2, 0), (-1, 0), (0, 0), (1, 0), (2, 0), (0, 1), (0, 2)):
            cv.dot((cx + dx, cy + dy), pal["trim"])

    # neck + head
    neck = body.child(9 if not dog else 7, -2 if not dog else -1, p.get("head", 0))
    if dog:
        cv.poly(neck.pts([(-3, 2), (2, 3), (5, -4), (3, -7), (-1, -6)]), coat)
        head = neck.child(4, -5, p.get("head", 0) * 0.3)
        jaw = p.get("jaw", 0)
        cv.poly(head.pts([(-3, -3), (1, -4), (4, -2), (9, -1), (10, 1), (5, 1), (1, 2), (-3, 1)]), coat)
        cv.poly(head.child(1, 1, jaw).pts([(0, 0), (8, 0), (8, 1.5), (1, 2.5)]), mat(darker(pal["coat"], 0.85)))
        cv.poly(head.pts([(-2, -3), (-1, -8), (1, -3)]), coat_far, shade=False)
        cv.dot(head((9.4, -0.5)), DARK)
        cv.dot(head((3, -2)), (230, 60, 40) if pal.get("red_eyes") else DARK)
        if pal.get("collar"):
            c = neck.pts(seg((-3, 0), (3, -2), 2.4))
            cv.poly(c, mat(pal["collar"]), shade=False)
    else:
        cv.poly(neck.pts([(-4, 2), (3, 5), (11, -8), (9, -13), (4, -14), (-2, -6)]), coat)
        head = neck.child(8, -12, p.get("nod", 0))
        cv.poly(head.pts([(-3, -3), (2, -4), (6, -1), (11, 4), (11, 7), (8, 8), (4, 5), (-2, 3)]), coat)
        cv.poly(head.pts([(-1, -3), (0, -8), (2, -4)]), coat)
        if pal.get("barding"):
            cv.poly(head.pts([(-1, -3), (2, -4), (10, 3), (9, 5), (2, 1)]), mat(pal["steel"]))
        cv.dot(head((3, -1)), DARK)
        cv.dot(head((10, 6)), DARK)
        cv.poly(neck.pts([(-6, 0), (-2, -7), (3, -14), (1, -17), (-4, -10), (-8, -1)]), hair)
        if pal.get("red_eyes"):
            cv.dot(head((3, -1)), (230, 50, 40))
    return body


def draw_rider(cv, body, p, pal):
    r = p.get("rider", {})
    pitch = p.get("pitch", 0)
    R = body.child(-1 + r.get("dx", 0), -7 + r.get("dy", 0), r.get("rot", 0) - pitch * 0.6)
    steel = mat(pal["steel"])
    cloth = mat(pal["cloth"])
    trim = mat(pal["trim"])
    weapon = pal.get("weapon", "lance")

    if pal.get("cape"):
        w = p.get("flutter", 0)
        cv.poly(R.pts([(-2, -11), (-11 - w, -5), (-15 - w, 2 + w), (-8, 4), (-3, 1)]), mat(darker(pal["cloth"], 0.85)))

    # far arm + main weapon (behind the torso)
    if weapon in ("lance", "banner"):
        L = R.child(3, -6, p.get("lance", -30))
        push = p.get("push", 0)
        length = 30 if weapon == "lance" else 24
        stripes = pal.get("stripes", [pal["cloth"], pal["trim"]])
        x = -9 + push
        i = 0
        while x < length + push:
            nx = min(x + 4, length + push)
            cv.poly(L.pts(seg((x, 0), (nx, 0), 2.2)), flat(stripes[i % 2]), shade=False)
            x = nx
            i += 1
        if weapon == "lance":
            cv.poly(L.pts([(length + push, -1.6), (length + 5 + push, 0), (length + push, 1.6)]), mat((210, 214, 224)))
            f = p.get("flutter", 0)
            cv.poly(L.pts([(19 + push, -1), (25 + push, -1), (23 + push - f, -5), (17 + push - f, -6 + f * 0.5)]), cloth)
        else:
            f = p.get("flutter", 0)
            flag = [(length - 1, 0), (length - 1, 12), (length - 9 - f, 13 + f), (length - 12 - f, 6 + f), (length - 9 - f, -1)]
            cv.poly(L.pts([(length - 1, 1), (length - 13 - f, 2 + f), (length - 14 - f, 10), (length - 1, 9)]), cloth)
            cc = L((length - 7 - f * 0.5, 5))
            for dx, dy in ((0, -1), (-1, 0), (0, 0), (1, 0), (0, 1), (-1, 1), (1, 1)):
                cv.dot((cc[0] + dx, cc[1] + dy), pal["trim"])
        cv.poly(R.pts(seg((1, -9), (3, -6), 2.5)), steel)
    elif weapon == "sword":
        S = R.child(3, -8, p.get("sword", -20))
        cv.poly(S.pts(seg((0, 2), (0, -1), 2.2)), mat(LEATHER))
        cv.poly(S.pts([(-2.5, -1), (2.5, -1), (2.5, -2), (-2.5, -2)]), mat(pal["trim"]))
        cv.poly(S.pts([(-1.2, -2), (1.2, -2), (1, -17), (0, -19), (-1, -17)]), mat((205, 210, 222)))
        cv.poly(R.pts(seg((1, -9), (3, -8), 2.5)), steel)

    # near leg
    cv.poly(R.pts(seg((0, -1), (5, 5), 4.2, 3.6)), steel)
    cv.poly(R.pts(seg((5, 5), (4, 12), 3.4, 3)), steel)
    cv.poly(R.pts([(2, 11), (6, 11), (8, 13), (2, 14)]), mat(LEATHER))
    # torso
    cv.poly(R.pts([(-4, 0), (4, 0), (4.5, -9), (3, -11), (-3, -11), (-4.5, -8)]), steel)
    cv.poly(R.pts([(-4, 1), (4, 1), (4, -6), (-4, -6)]), cloth, band=0.6)
    # head
    H = R.child(0.5, -12, r.get("head", 0))
    cv.poly(H.pts([(-3.5, 1), (3.5, 1), (4, -3), (3, -6), (-2, -7), (-4, -4)]), steel)
    for xx in (1, 2, 3):
        cv.dot(H((xx, -3)), DARK)
    crest = pal.get("crest")
    if crest == "plume":
        f = p.get("flutter", 0) * 0.5
        cv.poly(H.pts([(-1, -6), (-2, -9), (-7 - f, -10), (-11 - f, -6), (-8 - f, -7), (-4, -6)]), trim)
    elif crest == "horns":
        cv.poly(H.pts([(-3, -5), (-6, -9), (-6, -12), (-1, -6)]), mat((200, 190, 160)))
        cv.poly(H.pts([(2, -6), (4, -10), (6, -12), (4, -5)]), mat((200, 190, 160)))
    elif crest == "spike":
        cv.poly(H.pts([(-1, -6), (0.5, -10), (2, -6)]), steel)
    # shield on near arm
    sh = R.child(1.5, -6, r.get("shield", 0))
    cv.poly(sh.pts([(-4.5, -6), (5, -6), (5, 1), (0.5, 7.5), (-4.5, 1)]), mat(pal["steel"]))
    cv.poly(sh.pts([(-3.5, -5), (4, -5), (4, 1), (0.5, 5.5), (-3.5, 1)]), cloth, band=0.8)
    c = sh((0.3, -0.5))
    for dx, dy in pal.get("emblem", ((0, -3), (0, -2), (-1, -1), (0, -1), (1, -1), (-2, 0), (0, 0), (2, 0), (0, 1), (0, 2))):
        cv.dot((c[0] + dx, c[1] + dy), pal["trim"])
    cv.poly(R.pts(ell(0, -9, 2.6, 2.2, 10)), steel)


def cavalry_poses(pal):
    stand = {"bf": (0, 0), "ff": (0, 0), "bn": (0, 0), "fn": (0, 0)}
    sword = pal.get("weapon") == "sword"
    poses = {k: [] for k in ANIMS}
    for i in range(4):
        poses["idle"].append({"legs": dict(stand), "bob": [0, 0, 1, 1][i], "tail": [-4, 0, 4, 1][i],
                              "head": [0, 2, 3, 1][i], "nod": [0, 3, 4, 1][i], "flutter": [0, 1, 2, 1][i],
                              "lance": -32, "sword": -20})
    for i in range(6):
        t = i / 6 * TAU
        legs = {}
        for k, ph in (("fn", 0), ("bf", 0.4), ("ff", math.pi), ("bn", math.pi + 0.4)):
            a1 = -24 * math.sin(t + ph)
            a2 = 50 * max(0.0, math.cos(t + ph))
            if k[0] == "b":
                a2 = -a2 * 0.8
            legs[k] = (a1, a2)
        poses["walk"].append({"legs": legs, "bob": [0, -1, 0, 0, -1, 0][i], "tail": 5 * math.sin(t),
                              "head": 3 * math.sin(2 * t), "flutter": 2 + math.sin(t), "lance": -32,
                              "sword": -20, "pitch": 2 * math.sin(2 * t)})
    rear = {"bf": (8, -10), "ff": (-30, 70), "bn": (6, -8), "fn": (-25, 60)}
    atk = [
        dict(legs=dict(stand), lance=-30, x=0, pitch=-3, sword=-30),
        dict(legs=rear, lance=-48, x=-2, pitch=-9, sword=-75, flutter=2),
        dict(legs={"bf": (-10, 0), "ff": (-20, 40), "bn": (-8, 0), "fn": (-14, 30)}, lance=-10, x=3, pitch=-2, sword=-10, flutter=3),
        dict(legs={"bf": (-14, 0), "ff": (-8, 0), "bn": (-12, 0), "fn": (-6, 0)}, lance=3, x=7, push=7, pitch=4, sword=95, flutter=3),
        dict(legs=dict(stand), lance=0, x=5, push=4, pitch=2, sword=110, flutter=2),
        dict(legs=dict(stand), lance=-20, x=1, pitch=0, sword=40, flutter=1),
    ]
    poses["attack"] = atk
    poses["hurt"] = [
        dict(legs={"bf": (6, 0), "ff": (-15, 30), "bn": (6, 0), "fn": (-10, 25)}, x=-3, pitch=-7, lance=-42, sword=-40, rider={"rot": -12}),
        dict(legs=dict(stand), x=-1, pitch=-2, lance=-34, sword=-25, rider={"rot": -4}),
    ]
    fold_f = lambda k: (-30 - 15 * k, 90 * k)
    fold_b = lambda k: (30 + 15 * k, -100 * k)
    death = []
    spec = [
        (0.0, -8, -2, 0, dict(dx=0, dy=0, rot=-12), -40),
        (0.35, -2, -1, 2, dict(dx=-3, dy=-2, rot=-40), -10),
        (0.6, 2, 0, 6, dict(dx=-9, dy=4, rot=-70), 30),
        (0.85, 4, 0, 10, dict(dx=-15, dy=11, rot=-88), 70),
        (1.0, 4, 0, 12, dict(dx=-17, dy=15, rot=-92), 92),
        (1.0, 5, 0, 13, dict(dx=-17, dy=16, rot=-93, head=10), 93),
    ]
    for k, pitch, x, drop, rider, lance in spec:
        legs = {"ff": fold_f(k), "fn": fold_f(k * 0.95), "bf": fold_b(k), "bn": fold_b(k * 0.95)}
        if k == 0:
            legs = {"bf": (6, 0), "ff": (-20, 40), "bn": (6, 0), "fn": (-18, 40)}
        death.append(dict(legs=legs, pitch=pitch, x=x, drop=drop, rider=rider, lance=lance,
                          sword=lance, head=20 * k, nod=25 * k, tail=-6 * k))
    poses["death"] = death
    return poses


def render_cavalry(pal, s=1.0, fw=FW, fh=FH, anims=ANIMS):
    poses = cavalry_poses(pal)
    rows = []
    for a in anims:
        frames = []
        for p in poses[a]:
            cv = Canvas(fw, fh)
            root = Xf(fw / 2 - 2 * s, fh - 6 * s, 0, s * pal.get("scale", 1.0))
            body = draw_quadruped(cv, root, p, pal, "horse")
            draw_rider(cv, body, p, pal)
            cv.outline()
            frames.append(cv.img)
        rows.append(frames)
    return rows


# ---------------------------------------------------------------- hound

def hound_poses():
    st = {"bf": (0, 0), "ff": (0, 0), "bn": (0, 0), "fn": (0, 0)}
    P = {k: [] for k in ANIMS}
    for i in range(4):
        P["idle"].append(dict(legs=dict(st), bob=[0, 0, 1, 0][i], tail=[-10, 5, -10, 5][i], head=[0, -3, 0, 3][i], jaw=[0, 10, 0, 0][i]))
    for i in range(6):
        t = i / 6 * TAU
        legs = {}
        for k, ph in (("fn", 0), ("ff", 0.5), ("bn", math.pi), ("bf", math.pi + 0.5)):
            a1 = -35 * math.sin(t + ph)
            a2 = 40 * max(0.0, math.cos(t + ph))
            if k[0] == "b":
                a2 = -a2
            legs[k] = (a1, a2)
        P["walk"].append(dict(legs=legs, bob=[0, -1, -2, 0, -1, -2][i], tail=-10 + 8 * math.sin(t), pitch=6 * math.sin(t), jaw=8))
    P["attack"] = [
        dict(legs={"bf": (20, -30), "ff": (25, -30), "bn": (20, -30), "fn": (25, -30)}, drop=2, x=-2, pitch=4, jaw=0, tail=-15),
        dict(legs={"bf": (30, -50), "ff": (35, -50), "bn": (30, -50), "fn": (35, -50)}, drop=3, x=-4, pitch=6, jaw=10, tail=-20),
        dict(legs={"bf": (40, 0), "ff": (-50, 30), "bn": (40, 0), "fn": (-45, 30)}, drop=-4, x=5, pitch=-14, jaw=35, tail=-5),
        dict(legs={"bf": (30, 0), "ff": (-40, 20), "bn": (30, 0), "fn": (-35, 20)}, drop=-2, x=10, pitch=-6, jaw=-5, tail=0),
        dict(legs={"bf": (10, 0), "ff": (-10, 0), "bn": (10, 0), "fn": (-10, 0)}, x=7, pitch=0, jaw=20, head=10),
        dict(legs=dict(st), x=2, jaw=5),
    ]
    P["hurt"] = [dict(legs=dict(st), x=-3, pitch=-10, jaw=30, head=-15), dict(legs=dict(st), x=-1, pitch=-3, jaw=10)]
    P["death"] = []
    for k in (0, 0.3, 0.6, 0.85, 1, 1):
        P["death"].append(dict(legs={"bf": (40 * k, -60 * k), "ff": (-50 * k, 80 * k), "bn": (60 * k, -40 * k), "fn": (-70 * k, 60 * k)},
                               drop=7 * k, pitch=-8 * k, jaw=25 * k, head=25 * k, tail=20 * k, x=-2 * k))
    return P


def render_hound(pal, s=1.0, fw=FW, fh=FH, anims=ANIMS):
    P = hound_poses()
    rows = []
    for a in anims:
        frames = []
        for p in P[a]:
            cv = Canvas(fw, fh)
            draw_quadruped(cv, Xf(fw / 2, fh - 6 * s, 0, s * pal.get("scale", 1.25)), p, pal, "hound")
            cv.outline()
            frames.append(cv.img)
        rows.append(frames)
    return rows


# ---------------------------------------------------------------- footman rig

def draw_foot(cv, root, p, pal):
    kind = pal["kind"]
    steel = mat(pal["steel"])
    cloth = mat(pal["cloth"])
    trim = mat(pal["trim"])
    skin = mat(SKIN)
    legm = mat(pal.get("legs", darker(pal["cloth"], 0.6)))
    legm_far = mat(darker(pal.get("legs", darker(pal["cloth"], 0.6)), 0.75))
    R = root.child(p.get("x", 0), 0)
    hip_y = -15 + p.get("bob", 0) + p.get("drop", 0)
    T = R.child(0, hip_y, p.get("lean", 0))

    def leg(a1, a2, material):
        f1 = R.child(0, hip_y, a1)
        cv.poly(f1.pts(seg((0, 0), (0, 7.5), 4, 3.4)), material)
        f2 = f1.child(0, 7.5, a2)
        cv.poly(f2.pts(seg((0, 0), (0, 7), 3.2, 3)), material)
        cv.poly(f2.pts([(-1.5, 5.5), (3.5, 5.5), (3.8, 8), (-1.5, 8)]), mat(LEATHER))

    def arm(sx, sy, a1, a2, material):
        f1 = T.child(sx, sy, a1)
        cv.poly(f1.pts(seg((0, 0), (0, 5), 2.8, 2.4)), material)
        f2 = f1.child(0, 5, a2)
        cv.poly(f2.pts(seg((0, 0), (0, 5), 2.4, 2.2)), material)
        hand = f2((0, 5.5))
        return hand

    far_arm_mat = mat(darker(pal["arm"], 0.75)) if pal.get("arm") else mat(darker(pal["steel"], 0.75))
    near_arm_mat = mat(pal["arm"]) if pal.get("arm") else steel
    s = root.s

    # quiver / cape behind
    if kind == "archer":
        q = T.child(-3, -8, -25)
        cv.poly(q.pts([(-1.5, 0), (1.5, 0), (1.5, 9), (-1.5, 9)]), mat(LEATHER))
        for xx in (-1, 0, 1):
            cv.dot(q((xx, -1)), (230, 225, 210))
    if pal.get("cape"):
        w = p.get("flutter", 0)
        cv.poly(T.pts([(-2, -11), (-7 - w, -4), (-8 - w, 3), (-2, 1)]), mat(darker(pal["cloth"], 0.8)))

    # far arm and the weapon it carries
    hand_far = arm(0.5, -10, *p.get("arm_far", (-30, -40)), far_arm_mat)
    if kind == "spear":
        W = Xf(hand_far[0], hand_far[1], p.get("weapon", -15), s)
        cv.poly(W.pts(seg((-10, 0), (20, 0), 1.8)), mat(WOOD), shade=False)
        cv.poly(W.pts([(20, -1.8), (26, 0), (20, 1.8)]), mat((210, 214, 224)))
    if kind == "axe":
        W = Xf(hand_far[0], hand_far[1], p.get("weapon", -20), s)
        cv.poly(W.pts(seg((0, 4), (0, -15), 2)), mat(WOOD), shade=False)
        cv.poly(W.pts([(0, -15), (6, -18), (7, -11), (5, -9), (0, -11)]), mat((190, 194, 204)))
        cv.poly(W.pts([(0, -14), (-3, -13), (0, -11)]), mat((150, 154, 164)))

    leg(*p.get("leg_far", (0, 0)), legm_far)
    leg(*p.get("leg_near", (0, 0)), legm)

    # torso
    cv.poly(T.pts([(-3.5, 1), (3.5, 1), (4, -8), (3, -11), (-3, -11), (-4, -8)]), steel)
    cv.poly(T.pts([(-3.8, 3), (3.8, 3), (3.6, -8), (-3.6, -8)]), cloth, band=0.65)
    cv.poly(T.pts([(-3.8, -1), (3.8, -1), (3.8, 0), (-3.8, 0)]), mat(LEATHER), shade=False)
    if pal.get("tabard_mark", True):
        c = T((0, -4))
        for dx, dy in ((0, -2), (-1, -1), (1, -1), (0, -1), (0, 0)):
            cv.dot((c[0] + dx, c[1] + dy), pal["trim"])

    # head
    H = T.child(0.5, -14, p.get("head", 0))
    cv.poly(H.pts(ell(0, 0, 3.2, 3.4, 12)), skin)
    cv.dot(H((1.8, -0.5)), DARK)
    helm = pal["helm"]
    if helm == "kettle":
        cv.poly(H.pts([(-3.4, -0.5), (3.4, -0.5), (3, -3.5), (1, -5), (-2, -5), (-3.4, -3)]), steel)
        cv.poly(H.pts(seg((-5.5, -0.5), (5.5, -0.5), 1.4)), steel, shade=False)
    elif helm == "hood":
        cv.poly(H.pts([(-4, 4), (-4.5, -2), (-2, -5), (2, -5), (4, -2), (2, -1), (1.5, 1), (-1, 3)]), cloth)
    elif helm == "cap":
        cv.poly(H.pts([(-3.6, -0.5), (3.6, -1), (3, -4), (-2, -4.5), (-3.8, -2)]), mat(LEATHER))
        cv.poly(H.pts([(-1, 1), (3.6, 1), (3.4, 4), (1, 5), (-1, 3)]), mat(pal.get("beard", (70, 46, 32))))
    elif helm == "sallet":
        cv.poly(H.pts([(-4, 1), (3.6, 0), (3.6, -3), (1, -5), (-2, -5), (-4.5, -2), (-6, 1)]), steel)
        for xx in (1, 2, 3):
            cv.dot(H((xx, -1)), DARK)

    # near arm and what it holds
    hand_near = arm(0, -10, *p.get("arm_near", (-50, -40)), near_arm_mat)
    if kind == "spear":
        sh = Xf(hand_near[0] - 1 * s, hand_near[1] - 1 * s, 0, s)
        cv.poly(sh.pts(ell(0, 0, 5.5, 6.5, 16)), steel)
        cv.poly(sh.pts(ell(0, 0, 4.4, 5.4, 16)), cloth)
        c = sh((0, 0))
        for dx, dy in pal.get("emblem", ((0, -3), (0, -2), (-1, -1), (0, -1), (1, -1), (-2, 0), (0, 0), (2, 0), (0, 1), (0, 2))):
            cv.dot((c[0] + dx, c[1] + dy), pal["trim"])
    elif kind == "archer":
        B = Xf(hand_near[0], hand_near[1], 0, s)
        draw = p.get("draw", 0)
        tips = [B((-1, -9)), B((-1, 9))]
        arc = [B((-1 + 3.5 * math.cos(math.pi * (i / 8 - 0.5)), -9 + 18 * i / 8)) for i in range(9)]
        for a, b in zip(arc, arc[1:]):
            cv.line(a, b, flat(WOOD), 1)
        string_pt = hand_far if draw > 0 else B((-2, 0))
        cv.line(tips[0], string_pt, flat((225, 220, 205)), 1)
        cv.line(tips[1], string_pt, flat((225, 220, 205)), 1)
        if p.get("arrow", True):
            cv.line(string_pt, B((5, 0)) if draw > 0 else B((5, -0.5)), flat((235, 230, 215)), 1)
            cv.dot(B((5, 0)) if draw > 0 else B((5, -0.5)), (200, 205, 215))
    elif kind == "crossbow":
        C = Xf(hand_near[0], hand_near[1], p.get("weapon", 0), s)
        cv.poly(C.pts(seg((-7, 0), (6, 0), 2.2)), mat(WOOD))
        cv.poly(C.pts(seg((4, -6), (4, 6), 1.6)), mat((150, 150, 160)))
        if p.get("arrow", True):
            cv.line(C((-1, -1)), C((7, -1)), flat((235, 230, 215)), 1)
    elif kind == "axe":
        pass


def foot_poses(kind):
    P = {k: [] for k in ANIMS}
    base_arms = {
        "spear": dict(arm_far=(-70, -30), arm_near=(-35, -60), weapon=-12),
        "archer": dict(arm_far=(-20, -50), arm_near=(-85, 0), draw=0),
        "axe": dict(arm_far=(-40, -70), arm_near=(-40, -70), weapon=-25),
        "crossbow": dict(arm_far=(-40, -60), arm_near=(-70, -20), weapon=0),
    }[kind]
    for i in range(4):
        d = dict(base_arms)
        d.update(bob=[0, 0, 1, 1][i], head=[0, 0, 4, 2][i], flutter=[0, 1, 2, 1][i])
        if kind == "axe":
            d["weapon"] = -25 + [0, 2, 4, 2][i]
        P["idle"].append(d)
    for i in range(6):
        t = i / 6 * TAU
        d = dict(base_arms)
        d.update(leg_far=(28 * math.sin(t + math.pi), 45 * max(0.0, math.cos(t + math.pi))),
                 leg_near=(28 * math.sin(t), 45 * max(0.0, math.cos(t))),
                 bob=[0, -1, 0, 0, -1, 0][i], flutter=2 + math.sin(t), lean=3)
        if kind in ("axe",):
            d["arm_far"] = (-40 + 10 * math.sin(t), -70)
        P["walk"].append(d)
    if kind == "spear":
        P["attack"] = [
            dict(arm_far=(-80, -10), arm_near=(-35, -60), weapon=-10, x=-1, lean=-4),
            dict(arm_far=(-60, 0), arm_near=(-30, -60), weapon=-6, x=-2, lean=-8, leg_near=(-15, 10)),
            dict(arm_far=(-95, -5), arm_near=(-50, -60), weapon=-2, x=3, lean=10, leg_near=(-30, 20), leg_far=(20, 10)),
            dict(arm_far=(-100, 0), arm_near=(-55, -60), weapon=0, x=5, lean=14, leg_near=(-35, 20), leg_far=(25, 10)),
            dict(arm_far=(-85, -10), arm_near=(-45, -60), weapon=-4, x=3, lean=8, leg_near=(-20, 10), leg_far=(15, 0)),
            dict(arm_far=(-70, -30), arm_near=(-35, -60), weapon=-10, x=1, lean=2),
        ]
        hit = 3
    elif kind == "archer":
        P["attack"] = [
            dict(arm_far=(-40, -60), arm_near=(-80, 0), draw=0, head=2),
            dict(arm_far=(-80, -20), arm_near=(-95, 0), draw=1, head=4, lean=-2),
            dict(arm_far=(-85, 80), arm_near=(-95, 0), draw=1, head=4, lean=-4),
            dict(arm_far=(-85, 110), arm_near=(-95, 0), draw=1, head=4, lean=-5),
            dict(arm_far=(-60, 60), arm_near=(-95, 0), draw=0, arrow=False, head=4, lean=-2),
            dict(arm_far=(-20, -50), arm_near=(-85, 0), draw=0, arrow=False),
        ]
        hit = 4
    elif kind == "crossbow":
        P["attack"] = [
            dict(arm_far=(-60, -40), arm_near=(-80, -10), weapon=-4),
            dict(arm_far=(-70, -40), arm_near=(-90, -10), weapon=-2, lean=-2),
            dict(arm_far=(-70, -40), arm_near=(-90, -10), weapon=0, lean=-2),
            dict(arm_far=(-60, -40), arm_near=(-80, -20), weapon=-14, lean=-8, x=-2, arrow=False),
            dict(arm_far=(-50, -50), arm_near=(-75, -20), weapon=-6, lean=-4, x=-1, arrow=False),
            dict(arm_far=(-40, -60), arm_near=(-70, -20), weapon=0, arrow=False),
        ]
        hit = 3
    else:
        P["attack"] = [
            dict(arm_far=(-130, -30), arm_near=(-120, -30), weapon=-60, lean=-6),
            dict(arm_far=(-160, -20), arm_near=(-150, -20), weapon=-100, lean=-10, x=-1),
            dict(arm_far=(-170, -10), arm_near=(-160, -10), weapon=-130, lean=-12, x=-1, leg_near=(-20, 10)),
            dict(arm_far=(-90, -10), arm_near=(-85, -10), weapon=40, lean=10, x=4, leg_near=(-30, 20), leg_far=(20, 0)),
            dict(arm_far=(-40, -20), arm_near=(-35, -20), weapon=110, lean=16, x=5, leg_near=(-30, 20), leg_far=(25, 0)),
            dict(arm_far=(-40, -60), arm_near=(-40, -60), weapon=-10, lean=4, x=2),
        ]
        hit = 4
    hurt_base = dict(base_arms)
    hurt_base.update(lean=-14, x=-2, head=-15)
    hurt2 = dict(base_arms)
    hurt2.update(lean=-5, x=-1)
    P["hurt"] = [hurt_base, hurt2]
    for k in (0, 0.25, 0.5, 0.75, 1, 1):
        d = dict(base_arms)
        d.update(lean=-15 * k, leg_far=(-40 * k, 90 * k), leg_near=(-50 * k, 100 * k), head=-20 * k, drop=4 * k)
        P["death"].append(d)
    return P, hit


def render_foot(pal, s=1.0, fw=FW, fh=FH, anims=ANIMS):
    P, hit = foot_poses(pal["kind"])
    rows = []
    for a in anims:
        frames = []
        for i, p in enumerate(P[a]):
            cv = Canvas(fw, fh)
            ox, oy = fw / 2, fh - 6 * s
            draw_foot(cv, Xf(ox, oy, 0, s * pal.get("scale", 1.3)), p, pal)
            cv.outline()
            img = cv.img
            if a == "death":
                ang = [0, -12, -35, -62, -86, -90][i]
                img = rotate_about(img, ang, ox - 4 * s, oy, 0, 0)
            frames.append(img)
        rows.append(frames)
    return rows, hit


# ---------------------------------------------------------------- roster

VALE = dict(steel=(172, 180, 196), cloth=(40, 74, 162), trim=(232, 232, 238))
KARR = dict(steel=(84, 82, 94), cloth=(128, 26, 30), trim=(196, 160, 82))
# Falcon emblem for Vale, boar tusks for Karr
FALCON = ((0, -3), (-1, -2), (0, -2), (1, -2), (-3, -1), (-2, -1), (-1, -1), (0, -1), (1, -1), (2, -1), (3, -1), (-1, 0), (0, 0), (1, 0), (0, 1), (-1, 2), (1, 2))
BOAR = ((-2, -2), (2, -2), (-2, -1), (-1, -1), (0, -1), (1, -1), (2, -1), (-1, 0), (0, 0), (1, 0), (-1, 1), (1, 1), (0, 2))

UNITS = {
    "vale_knight": ("cavalry", dict(VALE, coat=(152, 112, 74), hair=(54, 38, 30), barding=True, crest="plume",
                                    stripes=[(232, 232, 238), (40, 74, 162)], emblem=FALCON)),
    "vale_hero": ("cavalry", dict(VALE, coat=(214, 214, 220), hair=(150, 150, 160), barding=True, crest="plume",
                                  weapon="banner", stripes=[(120, 84, 50), (120, 84, 50)], cape=True, emblem=FALCON)),
    "vale_spearman": ("foot", dict(VALE, kind="spear", helm="kettle", emblem=FALCON, legs=(70, 64, 60))),
    "vale_archer": ("foot", dict(VALE, kind="archer", helm="hood", cloth=(52, 92, 70), trim=(220, 210, 170),
                                 steel=(130, 110, 80), arm=(110, 84, 60), legs=(76, 60, 46))),
    "karr_raider": ("foot", dict(KARR, kind="axe", helm="cap", steel=(100, 80, 60), arm=SKIN, legs=(60, 46, 40),
                                 cloth=(110, 40, 34), beard=(60, 40, 26))),
    "karr_crossbow": ("foot", dict(KARR, kind="crossbow", helm="sallet", legs=(54, 46, 50))),
    "karr_rider": ("cavalry", dict(KARR, coat=(52, 46, 52), hair=(26, 22, 28), barding=False, crest="spike", cape=True,
                                   stripes=[(128, 26, 30), (30, 26, 30)], emblem=BOAR)),
    "karr_lord": ("cavalry", dict(KARR, coat=(40, 36, 42), hair=(20, 18, 22), barding=True, crest="horns", cape=True,
                                  weapon="sword", steel=(70, 68, 80), red_eyes=True, emblem=BOAR)),
    "karr_hound": ("hound", dict(coat=(92, 78, 68), hair=(60, 50, 44), collar=(150, 30, 30))),
    "wolf": ("hound", dict(coat=(150, 150, 158), hair=(110, 110, 120), red_eyes=False)),
}

FPS = {"idle": 5, "walk": 10, "attack": 10, "hurt": 8, "death": 9}


def build_sheet(rows, fw, fh):
    cols = max(len(r) for r in rows)
    sheet = Image.new("RGBA", (cols * fw, len(rows) * fh), (0, 0, 0, 0))
    for y, r in enumerate(rows):
        for x, f in enumerate(r):
            sheet.paste(f, (x * fw, y * fh))
    return sheet


def main():
    os.makedirs(OUT, exist_ok=True)
    meta = {}
    for name, (rig, pal) in UNITS.items():
        if rig == "cavalry":
            rows, hit = render_cavalry(pal), 3
        elif rig == "hound":
            rows, hit = render_hound(pal), 2
        else:
            rows, hit = render_foot(pal)
        build_sheet(rows, FW, FH).save(f"{OUT}/{name}.png")
        meta[name] = {"fw": FW, "fh": FH, "hit": hit,
                      "anims": {a: {"row": i, "frames": len(rows[i]), "fps": FPS[a]} for i, a in enumerate(ANIMS)}}
        # small version for the world map (idle + walk only)
        if rig == "cavalry":
            mrows = render_cavalry(pal, 0.5, 32, 32, ["idle", "walk"])
        elif rig == "hound":
            mrows = render_hound(pal, 0.45, 32, 32, ["idle", "walk"])
        else:
            mrows = render_foot(pal, 0.42, 32, 32, ["idle", "walk"])[0]
        build_sheet(mrows, 32, 32).save(f"{OUT}/{name}_mini.png")
        print("built", name)
    with open(f"{OUT}/units.json", "w") as f:
        json.dump(meta, f, indent=1)


if __name__ == "__main__":
    main()
