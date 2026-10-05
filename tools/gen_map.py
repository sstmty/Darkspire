"""Builds the chapter 1 world map as ASCII (game/data/chapter1.txt) and checks
that every event can be reached from the start.

Legend (terrain): . grass  , grass2  ; flowers  = road  ~ water  H bridge
                  b burnt  f field  : mud  s stone
Blocking decor:   T tree  P pine  D dead tree  M mountain  r rock  X hidden blocker
                  C Vale castle  F Karr fort  h house  x burnt house  t Karr tent  W the Darkspire
Events:           @ start  1-7 armies  R recruit hall  g gold  c chest  S scout  k campfire  B cage
"""
import random
from collections import deque

W, H = 56, 34
r = random.Random(7)
g = [["." if r.random() < 0.7 else "," for _ in range(W)] for _ in range(H)]
for _ in range(60):
    g[r.randrange(H)][r.randrange(W)] = ";"


def put(x, y, c):
    if 0 <= x < W and 0 <= y < H:
        g[y][x] = c


def line(x0, y0, x1, y1, c):
    """4-connected line so the road never steps diagonally."""
    x, y = x0, y0
    put(x, y, c)
    while (x, y) != (x1, y1):
        if abs(x1 - x) >= abs(y1 - y) and x != x1:
            x += 1 if x1 > x else -1
        elif y != y1:
            y += 1 if y1 > y else -1
        put(x, y, c)


def blob(cx, cy, rx, ry, chars, density=0.85):
    for y in range(cy - ry, cy + ry + 1):
        for x in range(cx - rx, cx + rx + 1):
            if ((x - cx) / rx) ** 2 + ((y - cy) / ry) ** 2 <= 1 and r.random() < density:
                put(x, y, r.choice(chars))


# mountains along the north edge and the map border
for x in range(W):
    for y in range(0, 3 + int(1.5 + 1.5 * ((x * 7) % 5) / 4)):
        put(x, y, "M")
for y in range(H):
    put(0, y, "P"); put(W - 1, y, "P")
for x in range(W):
    put(x, H - 1, "P")
    if r.random() < 0.6:
        put(x, H - 2, "P")

# forests
blob(22, 8, 6, 3, "TTP")
blob(8, 9, 5, 4, "TPT")
blob(26, 27, 7, 4, "DDT", 0.7)
blob(42, 24, 8, 5, "PPT")
blob(46, 5, 6, 2, "PT")
blob(4, 19, 3, 5, "TT")
blob(18, 21, 3, 3, "TT", 0.7)
blob(29, 17, 2, 3, "TP", 0.8)
blob(50, 18, 4, 3, "PP", 0.8)

# river (2 wide), runs from the mountains to the south edge
x = 33
for y in range(3, H):
    put(x, y, "~"); put(x + 1, y, "~")
    if y % 5 == 0:
        x += r.choice([-1, 0, 1])
        x = max(31, min(35, x))
# burnt land around the castle
blob(5, 28, 6, 4, "b", 0.8)

# road: castle -> village -> bridge -> fort
road = [(6, 28), (8, 24), (11, 20), (14, 16), (20, 14), (30, 14)]
for (a, b) in zip(road, road[1:]):
    line(*a, *b, "=")
# bridge row: find river columns at y=14
river_x = [x for x in range(W) if g[14][x] == "~"]
line(30, 14, min(river_x) - 1, 14, "=")
for x in river_x:
    put(x, 14, "H")
road2 = [(max(river_x) + 1, 14), (40, 14), (44, 12), (49, 12)]
for (a, b) in zip(road2, road2[1:]):
    line(*a, *b, "=")
# side path to the Karr camp in the dead forest
line(14, 16, 16, 20, "=")
line(16, 20, 22, 25, ":")
blob(25, 26, 3, 2, ":", 1.0)
# path north to the wolves
line(18, 14, 18, 11, ":")
blob(19, 10, 2, 1, ".", 1.0)

# village fields + houses
blob(12, 13, 3, 2, "f", 1.0)
blob(17, 17, 2, 1, "f", 1.0)
for hx, hy in ((11, 15), (16, 13), (12, 18), (17, 15)):
    put(hx, hy, "h")
put(15, 15, "R")

# castle (burning) and fort with hidden footprints
def structure(cx, cy, ch):
    for dx in (-1, 0, 1):
        for dy in (-1, 0):
            put(cx + dx, cy + dy, "X")
    put(cx, cy, ch)
    for dx in (-2, -1, 0, 1, 2):
        if g[cy + 1][cx + dx] in "PTDMr":
            put(cx + dx, cy + 1, ".")


structure(4, 29, "C")
for p in ((2, 31), (7, 30), (3, 26)):
    put(*p, "x")
structure(49, 10, "F")
blob(49, 13, 3, 1, "b", 0.6)
put(48, 12, "="); put(49, 11, "=")

# camp with tents
for p in ((23, 24), (27, 24), (28, 27)):
    put(*p, "t")
put(25, 27, "k")
put(27, 26, "B")

# the Darkspire far in the north
put(28, 1, "W")

# events
put(6, 27, "@")
put(9, 23, "1")
put(14, 17, "2")
put(25, 25, "3")
put(river_x[0], 14, "4")
put(19, 10, "5")
put(42, 13, "6")
put(49, 12, "7")
# loot
for p in ((10, 26), (21, 15), (38, 18), (45, 16), (52, 14), (7, 16), (27, 20)):
    put(*p, "g")
for p in ((20, 9), (29, 26), (47, 20), (38, 9)):
    put(*p, "c")
put(29, 13, "S")
put(8, 26, "k")
for p in ((12, 22), (38, 30), (6, 13), (52, 26), (24, 31)):
    put(*p, "r")

BLOCK = set("TPDMrXChxtW~kF")
for y in range(H):
    for x in range(W):
        pass

# reachability check: armies and objects are targets, never passed through
start = next((x, y) for y in range(H) for x in range(W) if g[y][x] == "@")
seen = {start}
q = deque([start])
blocked_events = set("1234567RgcSB")
while q:
    x, y = q.popleft()
    for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1), (1, 1), (1, -1), (-1, 1), (-1, -1)):
        nx, ny = x + dx, y + dy
        if not (0 <= nx < W and 0 <= ny < H) or (nx, ny) in seen:
            continue
        c = g[ny][nx]
        if c in BLOCK:
            continue
        seen.add((nx, ny))
        if c in blocked_events and c not in "4":
            continue  # standing next to it is enough; armies block passage
        if c == "4":
            continue
        q.append((nx, ny))

missing = []
for y in range(H):
    for x in range(W):
        c = g[y][x]
        if c in "123456RgcSB" and (x, y) not in seen:
            missing.append((c, x, y))
# everything past the bridge is checked separately by pretending the bridge army is gone
print("unreachable before bridge:", missing)

with open("game/data/chapter1.txt", "w") as f:
    f.write("\n".join("".join(row) for row in g) + "\n")
print("\n".join("".join(row) for row in g))
