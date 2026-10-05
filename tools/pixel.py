"""Small pixel-art toolkit used by the asset generators.

Shapes are rasterised without anti-aliasing, then shaded with a simple
bevel (light top/left edge, dark bottom/right edge and lower band) and the
whole silhouette gets a dark outline. This gives the chunky look of classic
90s strategy sprites while keeping every asset reproducible from code.
"""
import math
from PIL import Image, ImageDraw

OUTLINE = (22, 17, 26, 255)


def clamp(v):
    return max(0, min(255, int(round(v))))


def mat(rgb, light=1.28, dark=0.62):
    """Material = (base, highlight, shadow) colour triple."""
    r, g, b = rgb
    hi = (clamp(r * light + 10), clamp(g * light + 8), clamp(b * light + 4))
    lo = (clamp(r * dark), clamp(g * dark), clamp(b * dark + 6))
    return (tuple(rgb), hi, lo)


def flat(rgb):
    return (tuple(rgb), tuple(rgb), tuple(rgb))


def rot(p, a):
    r = math.radians(a)
    c, s = math.cos(r), math.sin(r)
    return (p[0] * c - p[1] * s, p[0] * s + p[1] * c)


def add(a, b):
    return (a[0] + b[0], a[1] + b[1])


def ell(cx, cy, rx, ry, n=18):
    return [(cx + rx * math.cos(2 * math.pi * i / n), cy + ry * math.sin(2 * math.pi * i / n)) for i in range(n)]


def seg(a, b, wa, wb=None):
    """Quad polygon for a limb from a to b with widths wa -> wb."""
    if wb is None:
        wb = wa
    dx, dy = b[0] - a[0], b[1] - a[1]
    ln = math.hypot(dx, dy) or 1.0
    nx, ny = -dy / ln, dx / ln
    return [
        (a[0] + nx * wa / 2, a[1] + ny * wa / 2),
        (b[0] + nx * wb / 2, b[1] + ny * wb / 2),
        (b[0] - nx * wb / 2, b[1] - ny * wb / 2),
        (a[0] - nx * wa / 2, a[1] - ny * wa / 2),
    ]


class Xf:
    """2D transform: scale, rotate (deg), translate. Maps local -> canvas."""

    def __init__(self, ox=0.0, oy=0.0, ang=0.0, s=1.0):
        self.ox, self.oy, self.ang, self.s = ox, oy, ang, s

    def __call__(self, p):
        q = rot((p[0] * self.s, p[1] * self.s), self.ang)
        return (self.ox + q[0], self.oy + q[1])

    def pts(self, ps):
        return [self(p) for p in ps]

    def child(self, px, py, ang=0.0):
        """Child frame whose origin sits at local (px,py), rotated by ang."""
        o = self((px, py))
        return Xf(o[0], o[1], self.ang + ang, self.s)


class Canvas:
    def __init__(self, w, h):
        self.w, self.h = w, h
        self.img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
        self.px = self.img.load()

    def _mask(self, draw_fn):
        m = Image.new("L", (self.w, self.h), 0)
        draw_fn(ImageDraw.Draw(m))
        return m

    def poly(self, pts, material, shade=True, band=0.7):
        pts = [(round(x), round(y)) for x, y in pts]
        m = self._mask(lambda d: d.polygon(pts, fill=255))
        self._blit(m, material, shade, band)

    def line(self, a, b, material, width=1, shade=False):
        m = self._mask(lambda d: d.line([(round(a[0]), round(a[1])), (round(b[0]), round(b[1]))], fill=255, width=width))
        self._blit(m, material, shade, 2.0)

    def dot(self, p, rgb):
        x, y = int(round(p[0])), int(round(p[1]))
        if 0 <= x < self.w and 0 <= y < self.h:
            self.px[x, y] = tuple(rgb) + (255,)

    def rect(self, x, y, w, h, rgb):
        for yy in range(int(y), int(y + h)):
            for xx in range(int(x), int(x + w)):
                self.dot((xx, yy), rgb)

    def _blit(self, m, material, shade, band):
        bbox = m.getbbox()
        if not bbox:
            return
        base, hi, lo = material
        mp = m.load()
        x0, y0, x1, y1 = bbox
        cut = y0 + (y1 - y0) * band
        W, H = self.w, self.h
        for y in range(y0, y1):
            for x in range(x0, x1):
                if not mp[x, y]:
                    continue
                c = base
                if shade:
                    up = y == 0 or not mp[x, y - 1]
                    lf = x == 0 or not mp[x - 1, y]
                    dn = y == H - 1 or not mp[x, y + 1]
                    rt = x == W - 1 or not mp[x + 1, y]
                    if dn or rt or y >= cut:
                        c = lo
                    elif up or lf:
                        c = hi
                self.px[x, y] = c + (255,)

    def outline(self, color=OUTLINE):
        src = self.img.copy().load()
        for y in range(self.h):
            for x in range(self.w):
                if src[x, y][3]:
                    continue
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    xx, yy = x + dx, y + dy
                    if 0 <= xx < self.w and 0 <= yy < self.h and src[xx, yy][3]:
                        self.px[x, y] = color
                        break


def rotate_about(img, ang, cx, cy, dx=0, dy=0):
    """Rotate an RGBA image around (cx,cy) with nearest sampling, then shift."""
    out = img.rotate(-ang, resample=Image.NEAREST, center=(cx, cy), translate=(dx, dy))
    return out
