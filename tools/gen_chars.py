"""Side-view character sprites for Darkspire (soulslike).

Characters face right. Sheets: one row per animation, one column per frame.
A JSON file lists, per character, frame size, animations (row, frames, fps,
loop) and the frame on which an attack connects.

Run from the repo root:  python3 tools/gen_chars.py
"""
import json
import math
import os

from PIL import Image

from pixel import Canvas, Xf, ell, mat, flat, seg, rotate_about

OUT = "game/assets/chars"
DARK = (20, 16, 20)
TAU = math.pi * 2


def darker(c, k=0.72):
    return tuple(int(v * k) for v in c)


# ----------------------------------------------------------------- humanoid rig

def human(cv, root, p, L):
    """Draw a humanoid. root = Xf at the feet. p = pose, L = look."""
    s = root.s
    R = root.child(p.get("x", 0), 0)
    hip_y = -14 + p.get("bob", 0) + p.get("drop", 0)
    T = R.child(0, hip_y, p.get("lean", 0))
    skin = mat(L["skin"])
    legs_m = mat(L["legs"])
    legs_far = mat(darker(L["legs"]))
    torso_m = mat(L["torso"])
    arm_m = mat(L.get("arm", L["torso"]))
    arm_far = mat(darker(L.get("arm", L["torso"])))
    boots = mat(L.get("boots", (70, 48, 34)))

    def leg(a1, a2, m):
        f1 = R.child(0, hip_y, a1)
        cv.poly(f1.pts(seg((0, 0), (0, 7.5), 4.2, 3.6)), m)
        f2 = f1.child(0, 7.5, a2)
        cv.poly(f2.pts(seg((0, 0), (0, 7), 3.4, 3.0)), m)
        cv.poly(f2.pts([(-1.6, 5), (3.6, 5), (3.8, 7.6), (-1.6, 7.6)]), boots)

    def arm(sx, sy, a1, a2, m):
        f1 = T.child(sx, sy, a1)
        cv.poly(f1.pts(seg((0, 0), (0, 5.2), 3.0, 2.6)), m)
        f2 = f1.child(0, 5.2, a2)
        cv.poly(f2.pts(seg((0, 0), (0, 5), 2.6, 2.3)), m)
        return f2((0, 5.4))

    # cloak / robe behind the body
    if L.get("cloak"):
        w = p.get("wave", 0)
        cm = mat(darker(L["cloak"], 0.82))
        top = T((-1, -10))
        knee = R((-6 - w, hip_y + (12 if not L.get("robe") else 15)))
        cv.poly([T((2, -10)), top, T((-4, -6)), (knee[0] - 2 * s, knee[1]), (knee[0] + 5 * s, knee[1] + 1 * s), T((1, 0))], cm)

    # far arm (+ off-hand item)
    hand_far = arm(0.5, -9.5, *p.get("arm_far", (-15, -30)), arm_far)
    if p.get("flask"):
        F = Xf(hand_far[0], hand_far[1], 0, s)
        cv.poly(F.pts([(-1.5, -4), (1.5, -4), (2, 1), (-2, 1)]), mat((230, 140, 50)))
        cv.dot(F((0, -5)), (120, 90, 60))
    wk = L.get("weapon")
    if wk == "staff":
        W = Xf(hand_far[0], hand_far[1], p.get("staff", -100), s)
        cv.poly(W.pts(seg((-6, 0), (19, 0), 2)), mat((86, 64, 48)), shade=False)
        cv.poly(W.pts([(19, -1), (23, -4), (23, -8), (20, -9), (19, -6), (21, -5), (20, -2)]), mat((120, 104, 90)))

    leg(*p.get("leg_far", (0, 0)), legs_far)
    leg(*p.get("leg_near", (0, 0)), legs_m)

    # torso
    cv.poly(T.pts([(-3.6, 1), (3.6, 1), (4, -8), (3, -10.5), (-3, -10.5), (-4, -8)]), torso_m, band=0.7)
    if L.get("belt", True):
        cv.poly(T.pts([(-3.8, -1), (3.8, -1), (3.8, 0.2), (-3.8, 0.2)]), mat((60, 40, 28)), shade=False)
    if L.get("armor"):
        cv.poly(T.pts([(-3.8, -3), (3.8, -3), (4, -8), (3, -10.5), (-3, -10.5), (-4, -8)]), mat(L["armor"]), band=0.75)
        cv.poly(T.pts(ell(1, -9, 3, 2.4, 10)), mat(L["armor"]))
        if L.get("rust"):
            for q in ((-2, -4), (2, -6), (0, -8), (-1, -9), (3, -3)):
                cv.dot(T(q), (168, 86, 40))
    if L.get("robe"):
        w = p.get("wave", 0)
        robe = mat(L["robe"])
        cv.poly([T((-4, -9)), T((4, -9)), T((4.5, 0)), R((7 + w * 0.5, -1)), R((6 + w, 0)), R((-6 + w, 0)), R((-6 + w * 0.5, -1)), T((-4.5, 0))], robe, band=0.8)
        cv.poly([T((-4.5, -1)), T((4.5, -1)), T((4.5, 0.5)), T((-4.5, 0.5))], mat(L.get("sash", (120, 30, 30))), shade=False)

    # head
    H = T.child(0.5, -13.5, p.get("head", 0))
    cv.poly(H.pts(ell(0, 0, 3.3, 3.5, 12)), skin)
    style = L.get("head")
    if style == "hood":
        hood = mat(L["hood"])
        cv.poly(H.pts([(-4.4, 4), (-4.6, -2), (-2, -5), (2.5, -5), (4.4, -2), (2.6, -1.6), (1.4, 1), (-0.5, 3.6)]), hood)
    elif style == "hair":
        hm = mat(L["hair"])
        cv.poly(H.pts([(-3.6, 2), (-4, -2), (-1.5, -4.6), (2.5, -4.4), (3.8, -2), (2.2, -2.5), (-1, -2.2), (-1.8, 1)]), hm)
        if L.get("long_hair"):
            cv.poly(H.pts([(-3.8, 0), (-5.5, 6), (-3.5, 8), (-1.5, 3)]), hm)
    elif style == "helm":
        hm = mat(L["armor"])
        cv.poly(H.pts([(-4, 3.6), (3.8, 3.4), (4.2, -1), (3, -4.6), (-2, -5), (-4.2, -2)]), hm)
        for xx in (1, 2, 3):
            cv.dot(H((xx, -0.6)), DARK)
        if L.get("plume"):
            cv.poly(H.pts([(-1, -5), (-4, -8), (-8, -7), (-5, -5)]), mat(L["plume"]))
    elif style == "skull":
        cv.poly(H.pts([(-4.6, 4), (-5, -2), (-2.5, -5.6), (2, -5.6), (4, -3), (4, 3), (1, 5)]), mat(L["hood"]))
        cv.poly(H.pts([(-1, -3), (3.6, -3), (3.8, 1), (2.6, 3.4), (0, 3.6), (-1, 1)]), mat((214, 204, 180)))
        cv.dot(H((1.4, -1.2)), (255, 120, 40))
        cv.dot(H((3, -1.2)), (255, 120, 40))
    elif style == "ghoul":
        cv.poly(H.pts([(-3, 3), (-3.6, -2), (-1, -4), (3, -3), (4.6, 0), (4.4, 3), (2, 4.6)]), skin)
        cv.dot(H((2.4, -1)), (230, 220, 160))
        cv.poly(H.pts([(2, 2.2), (4.4, 2.2), (4.2, 3.2), (2, 3.2)]), flat((40, 20, 20)))
    if style in ("hood", "hair"):
        eye = L.get("eye", DARK)
        cv.dot(H((1.9, -0.6)), eye)
        if L.get("mark"):
            cv.dot(H((2.6, -0.6)), L["mark"])

    # near arm and main weapon
    hand_near = arm(0, -9.5, *p.get("arm_near", (-20, -40)), arm_m)
    W = Xf(hand_near[0], hand_near[1], p.get("wang", 60), s)
    if wk == "sword":
        cv.poly(W.pts([(-2.5, -1), (0, -1), (0, 1), (-2.5, 1)]), mat((70, 50, 36)))
        cv.poly(W.pts(seg((0.5, -2.6), (0.5, 2.6), 1.4)), mat((150, 140, 120)))
        cv.poly(W.pts([(1, -1.1), (14, -0.9), (16, 0), (14, 0.9), (1, 1.1)]), mat((206, 212, 222)), band=2)
    elif wk == "greatsword":
        cv.poly(W.pts([(-4, -1.2), (0, -1.2), (0, 1.2), (-4, 1.2)]), mat((70, 50, 36)))
        cv.poly(W.pts(seg((0.6, -4), (0.6, 4), 1.8)), mat(L.get("armor", (150, 140, 120))))
        cv.poly(W.pts([(1, -1.7), (23, -1.4), (26, 0), (23, 1.4), (1, 1.7)]), mat(L.get("blade", (190, 196, 206))), band=2)
        if L.get("rust"):
            for t in (5, 9, 14, 18, 21):
                cv.dot(W((t, (t % 3) - 1)), (150, 80, 40))
    elif wk == "staff":
        # censer on a chain, swinging from the near hand
        ca = p.get("censer", 30)
        C = Xf(hand_near[0], hand_near[1], ca, s)
        for i in range(0, 10, 2):
            cv.dot(C((0, i)), (150, 140, 120))
        cv.poly(C.pts(ell(0, 12, 3.2, 3.6, 12)), mat((150, 120, 70)))
        cv.dot(C((-1, 12)), (255, 170, 60))
        cv.dot(C((1, 13)), (255, 120, 40))
    elif wk == "claws":
        for d in (-1, 0, 1):
            cv.line(W((0, d)), W((3.5, d * 1.6)), flat((200, 196, 180)))
    elif wk == "thread":
        if p.get("glow"):
            cv.dot(W((1, 0)), (140, 220, 255))
            cv.dot(W((2, -1)), (200, 240, 255))
            cv.dot(W((2, 1)), (90, 170, 255))


# ----------------------------------------------------------------- pose sets

def walk_pose(i, n, speed=1.0, lean=4, arms=True):
    t = i / n * TAU
    d = dict(leg_far=(30 * speed * math.sin(t + math.pi), 50 * speed * max(0.0, math.cos(t + math.pi))),
             leg_near=(30 * speed * math.sin(t), 50 * speed * max(0.0, math.cos(t))),
             bob=-1 if (i % (n // 2)) == 1 else 0, lean=lean, wave=2 + 2 * math.sin(t))
    if arms:
        d["arm_far"] = (25 * speed * math.sin(t) - 10, -30)
        d["arm_near"] = (-25 * speed * math.sin(t) - 15, -40)
    return d


def merge(base, **kw):
    d = dict(base)
    d.update(kw)
    return d


def said_anims():
    A = {}
    idle_arm = dict(arm_near=(-25, -50), wang=55, arm_far=(-5, -25))
    A["idle"] = [merge(idle_arm, bob=b, wave=w, head=h) for b, w, h in ((0, 0, 0), (0, 1, 0), (1, 2, 3), (1, 1, 2))]
    A["run"] = []
    for i in range(8):
        d = walk_pose(i, 8, 1.3, 10)
        d.update(arm_near=(-50 - 20 * math.sin(i / 8 * TAU), -40), wang=20)
        A["run"].append(d)
    A["jump"] = [dict(leg_far=(-30, 80), leg_near=(-50, 90), arm_near=(-60, -40), arm_far=(-70, -20), wang=-20, wave=4, drop=-2)]
    A["fall"] = [dict(leg_far=(10, 20), leg_near=(-15, 30), arm_near=(-120, -20), arm_far=(-140, -10), wang=-60, wave=-3)]
    curl = dict(leg_far=(-80, 130), leg_near=(-95, 140), arm_near=(-60, -80), arm_far=(-60, -80), wang=150, lean=40, drop=6, wave=0)
    A["roll"] = [curl] * 6
    A["attack1"] = [
        dict(arm_near=(-160, -10), arm_far=(-120, -40), wang=-120, lean=-6, leg_near=(-15, 15), wave=1),
        dict(arm_near=(-120, 0), arm_far=(-90, -40), wang=-50, lean=6, leg_near=(-30, 20), leg_far=(20, 10), x=2, wave=3),
        dict(arm_near=(-80, 0), arm_far=(-60, -40), wang=10, lean=12, leg_near=(-35, 20), leg_far=(25, 10), x=4, wave=4),
        dict(arm_near=(-50, -10), arm_far=(-40, -40), wang=50, lean=12, leg_near=(-35, 20), leg_far=(25, 10), x=4, wave=3),
        dict(arm_near=(-30, -40), arm_far=(-20, -30), wang=60, lean=4, x=2, wave=1),
    ]
    A["attack2"] = [
        dict(arm_near=(-20, -10), arm_far=(-10, -30), wang=80, lean=10, leg_near=(-20, 10), x=1, drop=1),
        dict(arm_near=(-60, 0), arm_far=(-40, -30), wang=30, lean=8, leg_near=(-30, 20), leg_far=(20, 10), x=3),
        dict(arm_near=(-110, 0), arm_far=(-80, -30), wang=-40, lean=-2, leg_near=(-35, 20), leg_far=(25, 10), x=5, bob=-1),
        dict(arm_near=(-150, 0), arm_far=(-110, -30), wang=-100, lean=-8, leg_near=(-35, 20), leg_far=(25, 10), x=5, bob=-1),
        dict(arm_near=(-60, -40), arm_far=(-30, -30), wang=20, lean=2, x=2),
    ]
    A["heal"] = [
        merge(idle_arm, arm_far=(-60, -90), flask=1),
        merge(idle_arm, arm_far=(-110, -110), head=-15, flask=1),
        merge(idle_arm, arm_far=(-115, -115), head=-20, flask=1),
        merge(idle_arm, arm_far=(-40, -60)),
    ]
    A["hurt"] = [merge(idle_arm, lean=-16, x=-2, head=-15, wave=-2), merge(idle_arm, lean=-6, x=-1)]
    death = []
    for k in (0, 0.3, 0.6, 1, 1, 1):
        death.append(merge(idle_arm, lean=10 * k, drop=5 * k, leg_far=(-60 * k, 120 * k), leg_near=(-70 * k, 130 * k),
                           head=20 * k, arm_near=(-20 + 40 * k, -40), wang=80))
    A["death"] = death
    return A


def nayra_anims():
    A = {}
    A["idle"] = [dict(bob=b, wave=w, arm_near=(-15, -30), arm_far=(-5, -20), head=h) for b, w, h in ((0, 0, 0), (0, 1, 0), (1, 2, 3), (1, 1, 2))]
    A["run"] = [walk_pose(i, 8, 1.2, 8) for i in range(8)]
    A["cast"] = [
        dict(arm_near=(-60, -20), arm_far=(-30, -40), lean=-2, glow=1),
        dict(arm_near=(-90, 0), arm_far=(-60, -30), lean=4, glow=1, wave=2),
        dict(arm_near=(-95, 0), arm_far=(-80, -10), lean=6, glow=1, wave=3),
        dict(arm_near=(-90, 0), arm_far=(-70, -20), lean=6, glow=1, wave=2),
        dict(arm_near=(-40, -30), arm_far=(-20, -30), lean=2),
    ]
    A["hurt"] = [dict(lean=-14, x=-2, head=-12, arm_near=(-15, -30)), dict(lean=-5, arm_near=(-15, -30))]
    return A


def ghoul_anims():
    A = {}
    base = dict(lean=28, head=-20, arm_near=(-30, -10), arm_far=(-20, -10), wang=40)
    A["idle"] = [merge(base, bob=b, head=-20 + h, arm_near=(-30 + a, -10)) for b, h, a in ((0, 0, 0), (0, 4, 5), (1, 6, 8), (1, 2, 3))]
    A["walk"] = [merge(base, **{k: v for k, v in walk_pose(i, 6, 1.1, 28, arms=False).items()}) for i in range(6)]
    A["attack"] = [
        merge(base, lean=10, arm_near=(-150, -20), arm_far=(-140, -20), x=-2, drop=2),
        merge(base, lean=0, arm_near=(-170, -10), arm_far=(-160, -10), x=-3, drop=3, head=-30),
        merge(base, lean=40, arm_near=(-80, 0), arm_far=(-70, 0), x=6, leg_near=(-40, 20), leg_far=(30, 10)),
        merge(base, lean=45, arm_near=(-30, -10), arm_far=(-20, -10), x=8, leg_near=(-40, 20), leg_far=(30, 10)),
        merge(base, lean=30, x=3),
    ]
    A["hurt"] = [merge(base, lean=0, x=-3, head=-40), merge(base, lean=15, x=-1)]
    A["death"] = [merge(base, lean=28 + 10 * k, drop=6 * k, leg_far=(-50 * k, 110 * k), leg_near=(-60 * k, 120 * k)) for k in (0, 0.4, 0.8, 1, 1)]
    return A


def heavy_anims(kind):
    """Rust guard / Draven: big sword overhead slam; Draven also a thrust."""
    A = {}
    base = dict(arm_near=(-30, -50), arm_far=(-20, -50), wang=50, lean=2)
    A["idle"] = [merge(base, bob=b, wang=50 + w, wave=w) for b, w in ((0, 0), (0, 1), (1, 2), (1, 1))]
    A["walk"] = []
    for i in range(6):
        d = walk_pose(i, 6, 0.8, 6, arms=False)
        d.update(arm_near=(-30, -50), arm_far=(-20, -50), wang=50)
        A["walk"].append(d)
    A["attack"] = [
        merge(base, arm_near=(-120, -20), arm_far=(-110, -20), wang=-60, lean=-4),
        merge(base, arm_near=(-170, -10), arm_far=(-160, -10), wang=-120, lean=-10, x=-1),
        merge(base, arm_near=(-185, -5), arm_far=(-175, -5), wang=-140, lean=-12, x=-2),
        merge(base, arm_near=(-110, 0), arm_far=(-100, 0), wang=-20, lean=10, x=3, leg_near=(-30, 20), leg_far=(20, 0)),
        merge(base, arm_near=(-60, 0), arm_far=(-50, 0), wang=50, lean=20, x=5, leg_near=(-35, 25), leg_far=(25, 0), drop=2),
        merge(base, arm_near=(-50, -10), arm_far=(-40, -10), wang=70, lean=18, x=5, leg_near=(-35, 25), leg_far=(25, 0), drop=2),
        merge(base, lean=6, x=2),
    ]
    if kind == "draven":
        A["thrust"] = [
            merge(base, arm_near=(-60, -60), arm_far=(-50, -60), wang=-10, lean=-6, x=-2),
            merge(base, arm_near=(-40, -90), arm_far=(-30, -90), wang=-5, lean=-10, x=-4, leg_near=(10, 30)),
            merge(base, arm_near=(-95, 0), arm_far=(-85, 0), wang=0, lean=18, x=6, leg_near=(-45, 25), leg_far=(30, 0)),
            merge(base, arm_near=(-95, 0), arm_far=(-85, 0), wang=0, lean=20, x=8, leg_near=(-45, 25), leg_far=(30, 0)),
            merge(base, arm_near=(-70, -20), arm_far=(-60, -20), wang=20, lean=10, x=4),
            merge(base, lean=4, x=1),
        ]
    A["hurt"] = [merge(base, lean=-12, x=-2, head=-10), merge(base, lean=-4, x=-1)]
    A["death"] = [merge(base, lean=10 * k, drop=5 * k, leg_far=(-60 * k, 120 * k), leg_near=(-70 * k, 130 * k), wang=50 + 60 * k, head=25 * k)
                  for k in (0, 0.3, 0.6, 1, 1, 1, 1)]
    return A


def shepherd_anims():
    A = {}
    base = dict(arm_near=(-40, -30), arm_far=(-60, -40), staff=-95, censer=20, lean=6, head=-8)
    A["idle"] = [merge(base, bob=b, censer=c, wave=w) for b, c, w in ((0, 10, 0), (0, 25, 1), (1, 35, 2), (1, 20, 1))]
    A["walk"] = []
    for i in range(6):
        d = walk_pose(i, 6, 0.6, 8, arms=False)
        d.update(arm_near=(-40, -30), arm_far=(-60, -40), staff=-95 + 6 * math.sin(i / 6 * TAU), censer=20 + 20 * math.sin(i / 6 * TAU), head=-8)
        A["walk"].append(d)
    A["attack"] = [
        merge(base, arm_near=(-10, -20), censer=-40, lean=0),
        merge(base, arm_near=(20, -10), censer=-80, lean=-6, x=-2),
        merge(base, arm_near=(-60, 0), censer=-150, lean=4),
        merge(base, arm_near=(-110, 0), censer=-250, lean=14, x=4, leg_near=(-30, 20)),
        merge(base, arm_near=(-100, 0), censer=-300, lean=16, x=5, leg_near=(-30, 20)),
        merge(base, arm_near=(-60, -10), censer=-340, lean=8, x=3),
        merge(base, censer=10, lean=6),
    ]
    A["cast"] = [
        merge(base, arm_far=(-100, -30), staff=-120, lean=0),
        merge(base, arm_far=(-160, -20), staff=-95, lean=-8, head=-20),
        merge(base, arm_far=(-170, -10), staff=-90, lean=-10, head=-25),
        merge(base, arm_far=(-80, -10), staff=-45, lean=12, x=2),
        merge(base, arm_far=(-70, -20), staff=-40, lean=12, x=2),
        merge(base, lean=6),
    ]
    A["hurt"] = [merge(base, lean=-10, x=-2, head=-25), merge(base, lean=0, x=-1)]
    A["death"] = [merge(base, lean=6 + 12 * k, drop=6 * k, leg_far=(-60 * k, 120 * k), leg_near=(-70 * k, 130 * k), head=20 * k, censer=60 * k, staff=-95 + 60 * k)
                  for k in (0, 0.25, 0.5, 0.8, 1, 1, 1)]
    return A


# ----------------------------------------------------------------- roster

SAID = dict(skin=(206, 170, 146), torso=(70, 58, 52), arm=(78, 70, 70), legs=(52, 48, 54), boots=(62, 44, 34),
            cloak=(104, 104, 114), head="hood", hood=(112, 112, 122), weapon="sword", eye=(30, 24, 26), mark=(255, 140, 60))
NAYRA = dict(skin=(222, 182, 156), torso=(46, 88, 86), arm=(222, 182, 156), legs=(54, 60, 66), boots=(70, 52, 40),
             cloak=(60, 104, 100), head="hair", hair=(150, 56, 40), long_hair=True, weapon="thread", eye=(60, 120, 140))
GHOUL = dict(skin=(150, 146, 140), torso=(110, 104, 100), arm=(150, 146, 140), legs=(96, 92, 90), boots=(90, 86, 84),
             head="ghoul", weapon="claws", belt=False)
GUARD = dict(skin=(150, 120, 100), torso=(76, 60, 52), arm=(112, 96, 88), legs=(70, 56, 50), boots=(60, 44, 34),
             head="helm", armor=(120, 100, 88), weapon="greatsword", rust=True, blade=(150, 120, 100))
SHEPHERD = dict(skin=(200, 190, 170), torso=(60, 54, 56), arm=(70, 62, 64), legs=(50, 46, 50), boots=(40, 36, 40),
                head="skull", hood=(66, 58, 60), robe=(74, 64, 66), sash=(150, 60, 30), cloak=(56, 50, 52), robe_cloak=True,
                weapon="staff", robe_long=True)
DRAVEN = dict(skin=(150, 120, 100), torso=(64, 50, 46), arm=(126, 110, 100), legs=(76, 62, 56), boots=(56, 40, 32),
              head="helm", armor=(138, 118, 104), plume=(120, 40, 30), weapon="greatsword", rust=True, cloak=(96, 36, 30),
              blade=(170, 150, 130))

CHARS = {
    # name: (look, anims fn, frame size, scale, hit frames, fps overrides)
    "said": (SAID, said_anims, 48, 1.0, {"attack1": 2, "attack2": 2}),
    "nayra": (NAYRA, nayra_anims, 48, 1.0, {"cast": 2}),
    "ashghoul": (GHOUL, ghoul_anims, 48, 1.0, {"attack": 3}),
    "rustguard": (GUARD, lambda: heavy_anims("guard"), 64, 1.25, {"attack": 4}),
    "shepherd": (SHEPHERD, shepherd_anims, (112, 96), 2.0, {"attack": 4, "cast": 3}),
    "draven": (DRAVEN, lambda: heavy_anims("draven"), (144, 96), 1.8, {"attack": 4, "thrust": 3}),
}
FPS = {"idle": 5, "run": 12, "walk": 8, "jump": 1, "fall": 1, "roll": 14, "attack1": 14, "attack2": 14, "attack": 10,
       "thrust": 10, "cast": 9, "heal": 6, "hurt": 8, "death": 8}
LOOP = {"idle", "run", "walk", "jump", "fall", "roll"}


def render(name):
    look, fn, size, scale, hits = CHARS[name]
    anims = fn()
    rows = []
    fw, fh = size if isinstance(size, tuple) else (size, size)
    meta = {"w": fw, "h": fh, "anims": {}}
    for row, (anim, poses) in enumerate(anims.items()):
        frames = []
        for i, p in enumerate(poses):
            cv = Canvas(fw, fh)
            ox, oy = fw / 2, fh - 4
            human(cv, Xf(ox, oy, 0, scale), p, look)
            cv.outline()
            img = cv.img
            if anim == "roll":
                img = rotate_about(img, i * 60, ox, oy - 12 * scale)
            elif anim == "death" and i >= len(poses) - 3:
                k = i - (len(poses) - 3)
                img = rotate_about(img, [50, 80, 90][k], ox + 3 * scale, oy)
            frames.append(img)
        rows.append(frames)
        meta["anims"][anim] = {"row": row, "frames": len(frames), "fps": FPS[anim], "loop": anim in LOOP,
                               "hit": hits.get(anim, -1)}
    cols = max(len(r) for r in rows)
    sheet = Image.new("RGBA", (cols * fw, len(rows) * fh))
    for y, r in enumerate(rows):
        for x, f in enumerate(r):
            sheet.paste(f, (x * fw, y * fh))
    sheet.save(f"{OUT}/{name}.png")
    return meta


def main():
    os.makedirs(OUT, exist_ok=True)
    meta = {n: render(n) for n in CHARS}
    with open(f"{OUT}/chars.json", "w") as f:
        json.dump(meta, f, indent=1)
    print("ok", list(meta))


if __name__ == "__main__":
    main()
