"""Builds the ASCII level maps in game/data/*.txt.

Legend (one char = one 16 px tile, 23 rows per level):
  #  ground          =  bridge deck      -  one-way plank     |  girder (decor)
  p  start           U  Угль Памяти      E  exit
  g  ash ghoul       G  rust guard       B  boss spawn        [ ]  arena bounds
  1-9 dialog triggers (see TRIGGERS in level.gd)
  props: h house, b/c burnt houses, t/T dead trees, f fence, k cart, r rail, n banner, x grave
Actors and props stand on the row they are drawn in; the ground is the row below.
"""
import os

H = 23
OUT = os.path.join(os.path.dirname(__file__), "..", "game", "data")


class Level:
    def __init__(self, w):
        self.w = w
        self.g = [[" "] * w for _ in range(H)]
        self.top = [H] * w  # first solid row per column

    def ground(self, x0, x1, h, ch="#"):
        for x in range(x0, x1 + 1):
            for y in range(H - h, H):
                self.g[y][x] = ch
            self.top[x] = H - h

    def deck(self, x0, x1, row, girders=8):
        for x in range(x0, x1 + 1):
            self.g[row][x] = "="
            self.top[x] = row
            if (x - x0) % girders == 0:
                for y in range(row + 1, H):
                    self.g[y][x] = "|"

    def plank(self, x0, x1, row):
        for x in range(x0, x1 + 1):
            self.g[row][x] = "-"

    def put(self, x, ch, row=None):
        self.g[(self.top[x] if row is None else row) - 1][x] = ch

    def save(self, name):
        with open(os.path.join(OUT, name + ".txt"), "w") as f:
            f.write("\n".join("".join(r) for r in self.g) + "\n")


def hollowd():
    L = Level(200)
    L.ground(0, 1, H)
    L.ground(2, 40, 5)
    L.put(4, "p")
    for x, c in [(9, "b"), (17, "t"), (23, "f"), (35, "x")]:
        L.put(x, c)
    L.put(26, "2")
    L.put(31, "g")
    L.put(38, "g")
    # first gap, then a step up to the burnt square with the first coal
    L.ground(44, 72, 6)
    L.put(47, "h")
    L.put(54, "3")
    L.put(57, "U")
    L.put(62, "k")
    L.put(68, "g")
    L.ground(76, 112, 5)
    L.put(78, "t")
    L.put(84, "g")
    L.put(89, "g")
    L.put(93, "c")
    L.ground(98, 104, 7)
    L.put(101, "g")
    L.plank(106, 110, H - 8)
    L.put(108, "x")
    # a wide breach crossed on planks
    L.plank(113, 117, H - 5)
    L.ground(118, 146, 5)
    L.put(120, "T")
    L.put(124, "g")
    L.put(129, "f")
    L.put(132, "g")
    L.put(136, "b")
    L.put(140, "g")
    L.put(144, "U")
    L.ground(147, 196, 5)
    L.put(149, "4")
    for x in [153, 160, 181, 188]:
        L.put(x, "x")
    L.put(152, "[")
    L.put(176, "B")
    L.put(190, "]")
    L.put(193, "E")
    L.ground(197, 199, H)
    L.save("hollowd")


def border():
    L = Level(220)
    L.ground(0, 1, H)
    L.ground(2, 34, 5)
    L.put(4, "p")
    for x, c in [(10, "t"), (16, "x"), (27, "f")]:
        L.put(x, c)
    L.put(22, "5")
    L.put(31, "G")
    L.ground(35, 44, 6)
    L.put(40, "g")
    L.ground(48, 66, 6)
    L.put(52, "g")
    L.put(57, "T")
    L.put(62, "6")
    L.ground(67, 90, 5)
    L.put(69, "U")
    L.put(74, "n")
    L.put(80, "G")
    L.put(86, "k")
    L.ground(91, 96, 7)
    L.plank(97, 101, H - 7)
    L.ground(102, 124, 5)
    L.put(104, "g")
    L.put(108, "g")
    L.put(113, "t")
    L.put(118, "G")
    L.ground(128, 140, 5)
    L.put(130, "x")
    L.put(134, "U")
    L.put(137, "7")
    L.put(140, "n")
    # the Rust Bridge over the chasm
    L.deck(141, 204, H - 5)
    for x in range(144, 204, 6):
        L.put(x, "r")
    L.put(150, "G")
    L.put(162, "[")
    L.put(184, "B")
    L.put(200, "]")
    L.ground(205, 216, 5)
    L.put(206, "n")
    L.put(210, "E")
    L.ground(217, 219, H)
    L.save("border")


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    hollowd()
    border()
    print("levels written")
