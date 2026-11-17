"""Composes a PREVIEW of the theme from the generated textures, in software (nine-slice stretch + alpha blend).

This is NOT a screenshot of the client: it shows what the texture files look like when stretched to typical component sizes
(nearest-neighbour, the way a pixel-art texture is stretched), so the art can be reviewed before it goes anywhere near the game.

  python -I tools/preview_theme.py <png> [--scale 2]
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import make_textures as mt

CAT = mt.catalogue()
SIZES = {'panel_nine': (64, 16, 64), 'window_nine': (128, 28, 128), 'inset_nine': (32, 6, 32), 'titlebar_nine': (64, 12, 32),
         'tooltip_nine': (64, 14, 64), 'slot_normal_nine': (32, 8, 32), 'slot_selected_nine': (32, 8, 32), 'slot_empty_nine': (32, 8, 32)}
for r in mt.ROLES:
    SIZES['button_%s_nine' % r] = (32, 8, 32)


def blit_nine(dst, name, x, y, w, h):
    src = CAT[name]
    sw, c, sh = SIZES[name]
    def sample(u, v):
        return src.p[min(sh - 1, int(v))][min(sw - 1, int(u))]
    for j in range(h):
        for i in range(w):
            # map destination pixel to source pixel with 9-slice rules
            if i < c: u = i
            elif i >= w - c: u = sw - (w - i)
            else: u = c + (i - c) * (sw - 2 * c) / max(1, (w - 2 * c))
            if j < c: v = j
            elif j >= h - c: v = sh - (h - j)
            else: v = c + (j - c) * (sh - 2 * c) / max(1, (h - 2 * c))
            r, g, b, a = sample(u, v)
            if a:
                dst.put(x + i, y + j, (r, g, b), a)


def blit(dst, name, x, y, w, h, tint=None):
    src = CAT[name]
    for j in range(h):
        for i in range(w):
            r, g, b, a = src.p[min(src.h - 1, int(j * src.h / h))][min(src.w - 1, int(i * src.w / w))]
            if a:
                if tint:
                    r, g, b = int(r * tint[0] / 255), int(g * tint[1] / 255), int(b * tint[2] / 255)
                dst.put(x + i, y + j, (r, g, b), a)


def text(dst, s, x, y, col, k=1):
    """Tiny 3x5 pixel font: just enough to label the preview (digits and capitals)."""
    F = {'A': '010101111101101', 'B': '110101110101110', 'C': '011100100100011', 'E': '111100110100111', 'I': '111010010010111',
         'L': '100100100100111', 'N': '110101101101101', 'O': '010101101101010', 'P': '110101110100100', 'R': '110101110110101',
         'S': '011100010001110', 'T': '111010010010010', 'U': '101101101101111', ' ': '000000000000000', 'V': '101101101101010',
         'D': '110101101101110', 'F': '111100110100100', 'G': '011100101101011', 'H': '101101111101101', 'M': '101111111101101',
         'K': '101101110101101', 'X': '101101010101101', 'Y': '101101010010010', 'Z': '111001010100111', 'J': '001001001101010',
         'W': '101101111111101', 'Q': '010101101110011', '.': '000000000000010', '1': '010110010010111', '2': '110001010100111'}
    cx = x
    for ch in s.upper():
        g = F.get(ch, F[' '])
        for r in range(5):
            for c in range(3):
                if g[r * 3 + c] == '1':
                    dst.rect(cx + c * k, y + r * k, cx + (c + 1) * k, y + (r + 1) * k, col)
        cx += 4 * k


def main(argv):
    out = argv[0]
    scale = int(argv[argv.index('--scale') + 1]) if '--scale' in argv else 2
    W, H = 760, 560
    img = mt.Img(W, H)
    img.rect(0, 0, W, H, (40, 52, 70))                      # a stand-in for the game behind the window
    # window with title bar, panels, buttons, cells, tooltip
    blit_nine(img, 'window_nine', 10, 10, 740, 540)
    blit_nine(img, 'titlebar_nine', 30, 26, 700, 34)
    text(img, 'REBORN BUILD PLANNER', 300, 38, mt.IVORY, 2)
    blit_nine(img, 'panel_nine', 30, 74, 220, 300)
    blit_nine(img, 'panel_nine', 262, 74, 300, 300)
    blit_nine(img, 'panel_nine', 574, 74, 156, 300)
    for i in range(5):
        blit_nine(img, 'panel_nine' if False else 'inset_nine', 42, 112 + i * 40, 196, 32) if i % 2 else blit_nine(img, 'inset_nine', 42, 112 + i * 40, 196, 32)
    text(img, 'PANNEAU', 100, 88, mt.GOLD, 2)
    blit(img, 'separator', 42, 100, 196, 8)
    x = 276
    for i, role in enumerate(['primary', 'secondary', 'danger', 'selected', 'disabled']):
        blit_nine(img, 'button_%s_nine' % role, x, 90 + i * 0, 120 if i < 2 else 78, 30)
        x += (128 if i < 2 else 86)
        if x > 520:
            break
    # states row: hover / pressed overlays on a secondary button
    for k, (nm, tint) in enumerate((('veil_hover', None), ('veil_pressed', None))):
        blit_nine(img, 'button_secondary_nine', 276 + k * 130, 140, 120, 30)
        blit(img, nm, 276 + k * 130, 140, 120, 30)
    blit_nine(img, 'button_secondary_nine', 276, 180, 60, 24)
    blit_nine(img, 'button_secondary_nine', 344, 180, 150, 24)
    # field, rows
    blit_nine(img, 'inset_nine', 276, 220, 280, 30)
    blit_nine(img, 'slot_normal_nine', 276, 264, 168, 58)
    blit(img, 'icon_frame', 284, 286, 30, 30, tint=(255, 148, 36))
    blit_nine(img, 'slot_selected_nine', 452, 264, 100, 58)
    blit_nine(img, 'slot_empty_nine', 276, 330, 168, 36)
    blit(img, 'row_sel', 590, 100, 130, 34)
    blit(img, 'icon_frame', 596, 104, 26, 26, tint=(180, 90, 240))
    blit_nine(img, 'tooltip_nine', 574, 150, 156, 110)
    blit_nine(img, 'inset_nine', 46, 392, 160, 100)
    blit_nine(img, 'panel_nine', 230, 392, 40, 34)
    blit_nine(img, 'panel_nine', 280, 392, 120, 100)
    blit(img, 'thumb', 410, 400, 12, 30)
    with open(out, 'wb') as fh:
        fh.write(img.png(scale))
    print('preview written: %s (%dx%d)' % (out, W * scale, H * scale))
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
