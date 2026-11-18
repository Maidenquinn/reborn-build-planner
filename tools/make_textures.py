"""Original texture generator for the Reborn Build Planner theme (Lot 3.5b).

Every image is DRAWN HERE, from code, for this project: no asset of any game, of ASBuilder or of another addon is read,
copied or traced. Output: 32-bit uncompressed TGA files (the format the 3.3.5a client loads), power-of-two sizes, plus a
PNG contact sheet for review. Deterministic (fixed seeds): the same command always produces the same bytes.

  python -I tools/make_textures.py <out dir> [--preview <png>]

Pure standard library (struct, zlib). Run again to regenerate; tests/lua/test_lot36.lua validates the files.
"""
import os
import struct
import sys
import zlib

# ---------------------------------------------------------------- palette (sRGB bytes)
INK = (8, 15, 29)
SLATE = (25, 39, 66)
SLATE_D = (13, 23, 43)
BRONZE = (89, 137, 171)
BRONZE_D = (43, 75, 115)
GOLD = (175, 220, 239)
IVORY = (231, 243, 255)
BLUE = (58, 118, 202)


class Img:
    def __init__(self, w, h):
        self.w, self.h = w, h
        self.p = [[(0, 0, 0, 0) for _ in range(w)] for _ in range(h)]

    def put(self, x, y, c, a=255):
        """Alpha-blend colour c (r,g,b) with alpha a over the pixel."""
        if 0 <= x < self.w and 0 <= y < self.h:
            r0, g0, b0, a0 = self.p[y][x]
            if a >= 255 or a0 == 0:
                self.p[y][x] = (c[0], c[1], c[2], max(a, a0) if a0 and a < 255 else a)
                return
            fa = a / 255.0
            oa = a + a0 * (1 - fa)
            if oa <= 0:
                return
            k = a / oa
            self.p[y][x] = (int(c[0] * k + r0 * (1 - k)), int(c[1] * k + g0 * (1 - k)), int(c[2] * k + b0 * (1 - k)), int(oa))

    def rect(self, x0, y0, x1, y1, c, a=255):
        for y in range(y0, y1):
            for x in range(x0, x1):
                self.put(x, y, c, a)

    def vgrad(self, x0, y0, x1, y1, top, bottom, a=255):
        n = max(1, y1 - y0 - 1)
        for y in range(y0, y1):
            t = (y - y0) / n
            c = tuple(int(top[i] + (bottom[i] - top[i]) * t) for i in range(3))
            for x in range(x0, x1):
                self.put(x, y, c, a)

    def noise(self, amount, seed):
        s = seed
        for y in range(self.h):
            for x in range(self.w):
                s = (s * 1103515245 + 12345) & 0x7FFFFFFF
                d = ((s >> 16) % (2 * amount + 1)) - amount
                r, g, b, a = self.p[y][x]
                if a:
                    self.p[y][x] = (max(0, min(255, r + d)), max(0, min(255, g + d)), max(0, min(255, b + d)), a)

    def frame(self, x0, y0, x1, y1, c, a=255, t=1):
        for i in range(t):
            self.rect(x0 + i, y0 + i, x1 - i, y0 + i + 1, c, a)
            self.rect(x0 + i, y1 - i - 1, x1 - i, y1 - i, c, a)
            self.rect(x0 + i, y0 + i, x0 + i + 1, y1 - i, c, a)
            self.rect(x1 - i - 1, y0 + i, x1 - i, y1 - i, c, a)

    def diamond(self, cx, cy, r, c, a=255):
        for y in range(cy - r, cy + r + 1):
            for x in range(cx - r, cx + r + 1):
                if abs(x - cx) + abs(y - cy) <= r:
                    self.put(x, y, c, a)

    def clear(self, x, y):
        if 0 <= x < self.w and 0 <= y < self.h:
            self.p[y][x] = (0, 0, 0, 0)

    def tga(self):
        out = bytearray()
        out += struct.pack('<BBBHHBHHHHBB', 0, 0, 2, 0, 0, 0, 0, 0, self.w, self.h, 32, 8)     # bottom-left origin, 8 alpha bits
        for y in range(self.h - 1, -1, -1):
            for x in range(self.w):
                r, g, b, a = self.p[y][x]
                out += bytes((b, g, r, a))
        return bytes(out)

    def png(self, scale=1):
        raw = bytearray()
        for y in range(self.h):
            row = bytearray()
            for x in range(self.w):
                row += bytes(self.p[y][x])
            for _ in range(scale):
                raw += b'\x00' + b''.join(bytes(self.p[y][x]) * scale for x in range(self.w))
        def chunk(t, d):
            c = struct.pack('>I', len(d)) + t + d
            return c + struct.pack('>I', zlib.crc32(t + d) & 0xFFFFFFFF)
        return (b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', struct.pack('>IIBBBBB', self.w * scale, self.h * scale, 8, 6, 0, 0, 0))
                + chunk(b'IDAT', zlib.compress(bytes(raw), 9)) + chunk(b'IEND', b''))


def shade(c, k):
    return tuple(max(0, min(255, int(v * k))) for v in c)


def notch(img, n=2):
    """Cut the four corner pixels (n x n staircase): a clipped, chiselled corner instead of a square one."""
    w, h = img.w, img.h
    for i in range(n):
        for j in range(n - i):
            for (x, y) in ((i, j), (w - 1 - i, j), (i, h - 1 - j), (w - 1 - i, h - 1 - j)):
                img.clear(x, y)


# ---------------------------------------------------------------- textures
def panel_nine():            # 64 x 64, corner 16: dark slate panel, bronze rule, gold corner studs
    g = Img(64, 64)
    g.vgrad(0, 0, 64, 64, (27, 32, 48), (16, 19, 31))
    g.noise(3, 11)
    g.frame(0, 0, 64, 64, INK)
    g.frame(1, 1, 63, 63, BRONZE_D)
    g.frame(2, 2, 62, 62, (12, 14, 24))
    g.rect(3, 3, 61, 4, (255, 255, 255), 18)           # light line under the top rule
    for (x, y) in ((6, 6), (57, 6), (6, 57), (57, 57)):
        g.diamond(x, y, 2, GOLD)
    notch(g, 2)
    return g


def window_nine():
    """Quiet outer shell: dark satin steel, 2px edge, beveled internal lip."""
    g = Img(128, 128)
    g.vgrad(0, 0, 128, 128, (22, 38, 62), (8, 17, 34))
    g.noise(2, 23)
    g.frame(0, 0, 128, 128, (3, 9, 21))
    g.frame(1, 1, 127, 127, (59, 112, 151))
    g.frame(2, 2, 126, 126, (16, 44, 77))
    g.frame(4, 4, 124, 124, (34, 69, 103))
    g.rect(5, 5, 123, 6, (183, 223, 245), 40)
    g.rect(5, 121, 123, 122, (3, 8, 18), 135)
    return g

def inset_nine():            # 32 x 32, corner 6: sunken field / list well
    g = Img(32, 32)
    g.rect(0, 0, 32, 32, (8, 10, 17))
    g.vgrad(1, 1, 31, 31, (16, 19, 31), (12, 14, 24))
    g.noise(2, 5)
    g.rect(0, 0, 32, 1, (0, 0, 0))                  # dark top / left edge (it is sunken)
    g.rect(0, 0, 1, 32, (0, 0, 0))
    g.rect(0, 31, 32, 32, (104, 84, 50))            # light bottom / right edge
    g.rect(31, 0, 32, 32, (104, 84, 50))
    g.rect(1, 1, 31, 2, (0, 0, 0), 120)
    notch(g, 1)
    return g


ROLES = {
    'primary': ((62, 111, 175), (24, 56, 106), (145, 210, 243)),
    'secondary': ((42, 61, 93), (19, 31, 54), (81, 126, 168)),
    'danger': ((116, 40, 36), (60, 19, 19), (176, 74, 62)),
    'selected': ((72, 127, 203), (27, 68, 131), GOLD),
    'disabled': ((31, 34, 45), (22, 25, 34), (54, 56, 68)),
}


def button_nine(role):
    """Clean raised controls: soft vertical gradient, slim rim, no clipped corners."""
    top, bottom, border = ROLES[role]
    g = Img(32, 32)
    g.vgrad(0, 0, 32, 32, top, bottom)
    g.noise(1, 41)
    g.frame(0, 0, 32, 32, (5, 15, 31))
    g.frame(1, 1, 31, 31, border)
    g.frame(2, 2, 30, 30, shade(border, 0.47))
    if role != 'disabled':
        g.rect(3, 3, 29, 4, (210, 232, 250), 58)
        g.rect(3, 27, 29, 28, (2, 9, 19), 115)
        g.rect(3, 5, 4, 27, (150, 187, 229), 21)
    return g

def veil_hover():            # 32 x 32: warm light veil over a hovered control (clearly visible)
    g = Img(32, 32)
    g.vgrad(0, 0, 32, 32, (255, 232, 160), (255, 205, 110))
    for y in range(32):
        a = int(78 - 58 * y / 31)
        for x in range(32):
            r, gg, b, _ = g.p[y][x]
            g.p[y][x] = (r, gg, b, a)
    return g


def veil_pressed():          # 32 x 32: dark veil with an inner top shadow for the pressed look
    g = Img(32, 32)
    g.rect(0, 0, 32, 32, (0, 0, 0), 96)
    g.rect(0, 0, 32, 3, (0, 0, 0), 90)
    return g


def titlebar_nine():         # 64 x 32, corner 12: title bar, lighter bronze-slate band
    g = Img(64, 32)
    g.vgrad(0, 0, 64, 32, (46, 40, 34), (24, 22, 24))
    g.noise(2, 77)
    g.frame(0, 0, 64, 32, INK)
    g.frame(1, 1, 63, 31, BRONZE_D)
    g.rect(2, 2, 62, 3, (255, 236, 190), 56)
    g.rect(2, 28, 62, 29, (0, 0, 0), 80)
    notch(g, 3)
    return g


def separator():
    """One soft horizontal division, no diamond ornaments at every section."""
    g = Img(128, 8)
    for x in range(128):
        d = abs(x-63.5)/63.5
        alpha = int(150*(1-d)**0.8)
        g.put(x, 3, (81, 153, 202), alpha)
        g.put(x, 4, (31, 88, 138), int(alpha*0.55))
    return g

def icon_frame():            # 64 x 64: light bronze frame with a transparent centre; tinted by rarity in the UI
    g = Img(64, 64)
    light = (236, 226, 200)
    g.frame(0, 0, 64, 64, (0, 0, 0), t=2)
    g.frame(2, 2, 62, 62, light, t=3)
    g.frame(5, 5, 59, 59, (0, 0, 0), a=150, t=1)
    for (x, y) in ((3, 3), (60, 3), (3, 60), (60, 60)):
        g.diamond(x, y, 3, (255, 250, 230))
    return g


def slot_nine(kind):         # 32 x 32, corner 8: equipment cell background
    g = Img(32, 32)
    if kind == 'empty':
        g.rect(0, 0, 32, 32, (13, 15, 25))
        g.noise(2, 9)
        for i in range(2, 30, 4):                       # dashed border
            for (x, y) in ((i, 1), (i, 30), (1, i), (30, i)):
                g.put(x, y, BRONZE_D)
                g.put(x + 1 if y in (1, 30) else x, y + 1 if x in (1, 30) else y, BRONZE_D)
    else:
        g.vgrad(0, 0, 32, 32, (35, 41, 62), (22, 26, 40))
        g.noise(2, 13)
        g.frame(0, 0, 32, 32, INK)
        if kind == 'selected':
            g.vgrad(1, 1, 31, 31, (43, 70, 128), (26, 42, 84))
            g.frame(1, 1, 31, 31, GOLD, t=2)
            g.frame(3, 3, 29, 29, (255, 240, 190), a=60, t=1)
        else:
            g.frame(1, 1, 31, 31, BRONZE)
            g.rect(2, 2, 30, 3, (255, 255, 255), 30)
    notch(g, 2)
    return g


def tooltip_nine():
    g = Img(64,64)
    g.vgrad(0,0,64,64,(25,42,67),(9,18,35))
    g.noise(2,31)
    g.frame(0,0,64,64,(4,13,27))
    g.frame(1,1,63,63,(84,145,184))
    g.frame(2,2,62,62,(25,63,102))
    g.rect(3,3,61,4,(211,231,252),45)
    return g

def row_sel():               # 16 x 32: selected list row, deep blue to blue-gold, gold bar on the left (stretched)
    g = Img(16, 32)
    for x in range(16):
        t = x / 15.0
        c = (int(36 + 30 * t), int(66 + 26 * t), int(128 - 20 * t))
        for y in range(32):
            g.put(x, y, c, 235)
    g.rect(0, 0, 16, 1, (255, 255, 255), 40)          # (the gold bar is a separate solid texture: stretching would fatten it)
    return g


def thumb():
    g = Img(16,32)
    g.vgrad(0,0,16,32,(89,146,189),(35,76,121))
    g.frame(0,0,16,32,(6,18,35))
    g.frame(1,1,15,31,(102,174,220),a=200)
    g.rect(2,2,14,3,(231,244,255),70)
    for y in (14,17,20): g.rect(5,y,11,y+1,(11,39,66),150)
    return g

def catalogue():
    out = {
        'panel_nine': panel_nine(), 'window_nine': window_nine(), 'inset_nine': inset_nine(),
        'veil_hover': veil_hover(), 'veil_pressed': veil_pressed(), 'titlebar_nine': titlebar_nine(),
        'separator': separator(), 'icon_frame': icon_frame(), 'tooltip_nine': tooltip_nine(),
        'slot_normal_nine': slot_nine('normal'), 'slot_selected_nine': slot_nine('selected'), 'slot_empty_nine': slot_nine('empty'),
        'row_sel': row_sel(), 'thumb': thumb(),
    }
    for role in ROLES:
        out['button_%s_nine' % role] = button_nine(role)
    return out


def main(argv):
    out = argv[0]
    if '--check' in argv:      # byte-for-byte comparison with the committed files (used by tools/run_all.py)
        cat = catalogue()
        bad = []
        for name, img in sorted(cat.items()):
            path = os.path.join(out, name + '.tga')
            if not os.path.exists(path) or open(path, 'rb').read() != img.tga():
                bad.append(name)
        extra = sorted(set(f[:-4] for f in os.listdir(out) if f.endswith('.tga') and not f.startswith('ultimate_')) - set(cat))
        print('textures up to date' if not bad and not extra else 'textures DIFFER: %s extra: %s' % (bad, extra))
        return 0 if not bad and not extra else 1
    preview = argv[argv.index('--preview') + 1] if '--preview' in argv else None
    os.makedirs(out, exist_ok=True)
    cat = catalogue()
    for name, img in sorted(cat.items()):
        with open(os.path.join(out, name + '.tga'), 'wb') as fh:
            fh.write(img.tga())
    if preview:
        names = sorted(cat)
        cell = 140
        cols = 5
        rows = (len(names) + cols - 1) // cols
        sheet = Img(cols * cell, rows * cell)
        sheet.rect(0, 0, sheet.w, sheet.h, (70, 74, 86))
        for i, n in enumerate(names):
            im = cat[n]
            ox, oy = (i % cols) * cell + 6, (i // cols) * cell + 6
            k = max(1, min(2, 128 // max(im.w, im.h)))
            for y in range(im.h):
                for x in range(im.w):
                    r, g, b, a = im.p[y][x]
                    if a:
                        for dy in range(k):
                            for dx in range(k):
                                sheet.put(ox + x * k + dx, oy + y * k + dy, (r, g, b), a)
        with open(preview, 'wb') as fh:
            fh.write(sheet.png(1))
    print('wrote %d textures to %s' % (len(cat), out))
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
