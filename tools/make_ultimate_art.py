"""Generate Reborn UI textures (development-only Pillow dependency).
Ornaments are original; the two class icons reproduce user-provided WoW art.
Private-project assets only: rights/provenance must be reviewed before release.
Outputs uncompressed 32-bit TGA files; no runtime network dependency.
"""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFilter
import random, math, struct, sys, base64, io, hashlib

G=(128,190,226,255); L=(210,241,255,255); B=(40,93,151,255)

def motif(d,cx,cy,k=1,flip=1):
    def pt(x,y): return (int(cx+flip*x*k),int(cy+y*k))
    for i in range(3):
        a,b=pt(i*2,i*2),pt(60-i*2,60-i*2)
        d.arc((min(a[0],b[0]),min(a[1],b[1]),max(a[0],b[0]),max(a[1],b[1])),185,350,fill=(61+i*19,113+i*20,161+i*22,255),width=max(1,int(3*k)))
    for j in range(4):
        a=pt(0,0); b=pt(12+14*j*math.cos(j*.35),18+14*j*math.sin(j*.35));c=pt(55+j*2,18+j*4)
        d.line([a,b,c],fill=G if j%2==0 else B,width=max(1,int(2*k)))
    p=pt(17,10)
    d.polygon([pt(10,10),pt(17,0),pt(24,10),pt(17,22)],fill=G,outline=L)
    q,r=pt(31,22),pt(38,29)
    d.ellipse((min(q[0],r[0]),min(q[1],r[1]),max(q[0],r[0]),max(q[1],r[1])),fill=L)

def corner():
    """Low-key metal end-cap, not a huge ornamental window bracket."""
    im = Image.new("RGBA", (128, 128))
    d = ImageDraw.Draw(im)
    # A thin L-piece and tiny tapered glow; the source is mostly transparent.
    d.line([(2, 82), (2, 12), (12, 2), (82, 2)], fill=(83, 151, 194, 180), width=2)
    d.line([(6, 58), (6, 15), (15, 6), (58, 6)], fill=(171, 220, 247, 105), width=1)
    d.line([(11, 35), (11, 18), (18, 11), (35, 11)], fill=(66, 120, 162, 100), width=1)
    d.ellipse((10, 10, 15, 15), fill=(198, 232, 253, 170))
    return im

def crest():
    """A small original arcane interface glyph, designed for a 30px header."""
    im = Image.new("RGBA", (128, 128))
    d = ImageDraw.Draw(im)
    d.ellipse((17, 17, 111, 111), fill=(12, 34, 61, 255),
              outline=(88, 151, 196, 255), width=4)
    d.ellipse((25, 25, 103, 103), outline=(173, 216, 240, 210), width=2)
    d.arc((36, 36, 92, 92), 215, 335, fill=(120, 212, 249, 255), width=5)
    d.arc((36, 36, 92, 92), 35, 155, fill=(67, 114, 172, 255), width=5)
    d.polygon([(64, 37), (87, 64), (64, 91), (41, 64)], fill=(35, 91, 146, 255),
              outline=(168, 223, 251, 255))
    d.line([(64, 49), (76, 64), (64, 79)], fill=(216, 244, 255, 255), width=3)
    return im

def title():
    """Continuous satin-metal header, without the old RPG banner cutouts."""
    w, h = 512, 128
    im = Image.new("RGBA", (w, h))
    p = im.load()
    rng = random.Random(117)
    for y in range(h):
        t = y / (h - 1)
        for x in range(w):
            wave = 1.2 * math.sin(x * .022 + y * .014)
            grain = rng.randint(-2, 2)
            halo = 6 * (1 - abs(x - w / 2) / (w / 2)) * (1 - t)
            v = halo + wave + grain
            p[x, y] = (int(16 + 7 * (1 - t) + v),
                       int(33 + 12 * (1 - t) + v),
                       int(57 + 18 * (1 - t) + v), 255)
    d = ImageDraw.Draw(im)
    d.line((0, 0, w-1, 0), fill=(72, 139, 190, 255), width=2)
    d.line((0, 3, w-1, 3), fill=(170, 220, 245, 120), width=1)
    d.line((0, h-3, w-1, h-3), fill=(30, 76, 117, 255), width=2)
    d.line((0, h-1, w-1, h-1), fill=(5, 16, 33, 255), width=1)
    return im

def panel():
    """Opaque layered smoke-glass with tiny cold rim and no boxed-in corner art."""
    w = h = 256
    im = Image.new("RGBA", (w, h))
    p = im.load()
    rng = random.Random(42)
    for y in range(h):
        t = y / (h - 1)
        for x in range(w):
            noise = rng.randint(-2, 2)
            wave = 2.0 * math.sin(x * .03 + y * .018)
            glow = 4.0 * (1 - abs(x - w/2) / (w/2)) * (1 - t)
            v = noise + wave + glow
            p[x, y] = (max(0, int(12 + (1-t)*3 + v)),
                       max(0, int(24 + (1-t)*6 + v)),
                       max(0, int(42 + (1-t)*10 + v)), 255)
    d = ImageDraw.Draw(im)
    # Hairline separators are deliberately lower contrast than item quality.
    d.rectangle((0, 0, w-1, h-1), outline=(7, 19, 37, 255), width=2)
    d.line((2, 2, w-3, 2), fill=(74, 133, 171, 255), width=1)
    d.line((3, 4, w-4, 4), fill=(44, 87, 127, 255), width=1)
    d.line((2, 3, 2, h-3), fill=(52, 97, 134, 255), width=1)
    d.line((w-3, 3, w-3, h-3), fill=(27, 60, 99, 255), width=1)
    d.line((3, h-3, w-3, h-3), fill=(25, 54, 85, 255), width=1)
    return im

def favorite(filled):
    """Small original transparent heart. Consistent silhouette at 20px UI size."""
    im = Image.new("RGBA", (64, 64), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    path = [(32, 53), (10, 33), (7, 27), (7, 19), (11, 12), (18, 9),
            (24, 10), (32, 17), (40, 10), (46, 9), (53, 12),
            (57, 19), (57, 27), (54, 33)]
    # Dark stroke improves readability against selected blue rows.
    d.line(path + [path[0]], fill=(8, 19, 36, 255), width=7, joint="curve")
    if filled:
        d.polygon(path, fill=(233, 93, 126, 255))
        d.line([(11, 19), (17, 13), (23, 13), (30, 20)],
               fill=(255, 196, 208, 240), width=3)
    else:
        d.polygon(path, fill=(20, 35, 58, 120))
        d.line(path + [path[0]], fill=(174, 199, 221, 240), width=3, joint="curve")
    return im

def supplied_class_icon(kind):
    """Reproduce the two reference images provided by the user, not a redraw.

    Payloads are private reference JPEGs transformed with a reversible XOR
    to avoid corruption when sending their base64 as text through the connector.
    SHA-256 verification prevents silently packaging broken or wrong artwork.
    """
    name = "monk" if kind == "monk" else "dh"
    checksums = {
        "monk": "1236bf1b491a06834b2a9d29dec4b72f8a87ee62f3292684706bb25948a34b87",
        "dh": "c290f4bbc2a2798dbf5a65ad3592684449387a147e073b0d2cbe50d265406e68",
    }
    path = Path(__file__).with_name("official_icons_" + name + ".b64")
    encoded = "".join(path.read_text(encoding="ascii").split())
    raw = base64.b64decode(encoded, validate=True)
    data = bytes((b ^ 0xA5) for b in raw)
    digest = hashlib.sha256(data).hexdigest()
    if digest != checksums[name]:
        raise ValueError("User-supplied official class artwork hash mismatch: " + name + " (" + digest + ")")
    im = Image.open(io.BytesIO(data)).convert("RGBA")
    if im.size != (48, 48):
        raise ValueError("Unexpected source class art size: " + str(im.size))
    return im.resize((64, 64), Image.Resampling.LANCZOS)


def tga_bytes(im):
    """WoW-compatible 18-byte header, uncompressed bottom-left BGRA rows."""
    w, h = im.size
    result = bytearray(struct.pack("<BBBHHBHHHHBB", 0, 0, 2, 0, 0, 0, 0, 0, w, h, 32, 8))
    px = im.load()
    for y in range(h - 1, -1, -1):
        for x in range(w):
            r, g, b, a = px[x, y]
            result.extend((b, g, r, a))
    return bytes(result)


def main(out):
    out=Path(out);out.mkdir(parents=True,exist_ok=True)
    textures={"ultimate_corner":corner(),"ultimate_crest":crest(),"ultimate_titlebar":title(),"ultimate_panel":panel(),
              "ultimate_fav_on":favorite(True),"ultimate_fav_off":favorite(False),
              "ultimate_class_monk":supplied_class_icon("monk"),"ultimate_class_dh":supplied_class_icon("demonhunter")}
    for name,im in textures.items():(out/(name+".tga")).write_bytes(tga_bytes(im))
    print("Generated",len(textures),"textures (6 original + 2 supplied game-class artworks) in",out)

if __name__=="__main__":
    if len(sys.argv)!=2:raise SystemExit("Usage: python tools/make_ultimate_art.py <Media directory>")
    main(sys.argv[1])
