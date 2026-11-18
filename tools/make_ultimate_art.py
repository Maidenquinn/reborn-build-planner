"""Original ornamental UI textures for Reborn (development-only Pillow dependency).
No game assets, fonts, external catalogues or player data are consumed.
Outputs uncompressed 32-bit TGA files; no runtime network dependency.
"""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFilter
import random, math, struct, sys

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
    im=Image.new("RGBA",(128,128));d=ImageDraw.Draw(im)
    d.polygon([(0,0),(121,0),(96,13),(27,13),(13,30),(13,101),(0,122)],fill=(18,49,85,245),outline=G)
    d.line([(3,109),(3,6),(112,6)],fill=L,width=3)
    d.line([(16,98),(16,26),(28,16),(90,16)],fill=B,width=4)
    motif(d,23,20,.9)
    for x,y in [(10,10),(105,10),(10,105)]:
        d.ellipse((x-4,y-4,x+4,y+4),fill=G,outline=L)
    return im.filter(ImageFilter.GaussianBlur(.25))

def crest():
    im=Image.new("RGBA",(128,128));d=ImageDraw.Draw(im)
    d.polygon([(64,4),(105,22),(110,66),(91,104),(64,124),(37,104),(18,66),(23,22)],fill=(20,42,76,255),outline=L,width=4)
    d.polygon([(64,14),(96,29),(99,65),(83,95),(64,111),(45,95),(29,65),(32,29)],fill=(9,31,65,255),outline=G,width=3)
    d.polygon([(64,27),(72,50),(96,48),(76,64),(82,91),(64,76),(46,91),(52,64),(32,48),(56,50)],fill=G,outline=L)
    d.ellipse((58,58,70,70),fill=L)
    return im

def title():
    w,h=512,128;im=Image.new("RGBA",(w,h));p=im.load();rng=random.Random(117)
    for y in range(h):
        for x in range(w):
            n=rng.randrange(-5,6);t=y/(h-1)
            p[x,y]=(max(0,int(18-6*t+n)),max(0,int(40-13*t+n)),max(0,int(72-25*t+n)),255)
    d=ImageDraw.Draw(im)
    d.polygon([(0,18),(88,18),(104,2),(408,2),(424,18),(511,18),(511,111),(423,111),(406,125),(106,125),(89,111),(0,111)],outline=G,width=4)
    d.line((22,28,490,28),fill=(210,240,254,255),width=2)
    d.line((24,32,488,32),fill=B,width=2)
    d.line((24,99,488,99),fill=G,width=2)
    d.line((26,105,486,105),fill=(6,15,35,255),width=4)
    d.line((34,47,476,47),fill=(67,119,170,255),width=1)
    d.line((34,84,476,84),fill=(30,78,132,255),width=1)
    for flip,cx in ((1,20),(-1,492)):motif(d,cx,40,.7,flip)
    return im

def panel():
    w=h=256;im=Image.new("RGBA",(w,h));p=im.load();rng=random.Random(42)
    for y in range(h):
        for x in range(w):
            # Subtle forged-steel texture: three low-frequency waves, a
            # soft halo, restrained micrograin, and darkened perimeter.
            n=rng.randint(-3,3)
            wave=2.5*math.sin(x*.034+y*.019)+1.8*math.cos(y*.057)
            halo=3.2*(1-abs(x-w/2)/(w/2))*(1-abs(y-h/2)/(h/2))
            edge=5.0*(min(x,y,w-1-x,h-1-y)<16)
            v=wave+halo-edge+n
            p[x,y]=(max(0,int(13+v)),max(0,int(28+v*1.1)),max(0,int(51+v*1.35)),255)
    d=ImageDraw.Draw(im)
    # Hand-drawn three-stage bevel: dark silhouette, cool-steel lip and a
    # softer inner highlight. No rivets near short labels.
    d.rectangle((0,0,w-1,h-1),outline=(4,12,27,255),width=2)
    d.rectangle((2,2,w-3,h-3),outline=(65,132,184,255),width=2)
    d.line([(5,5),(w-6,5)],fill=(151,209,236,255),width=1)
    d.line([(5,6),(5,h-8)],fill=(100,170,214,255),width=1)
    d.line([(6,h-6),(w-6,h-6)],fill=(24,65,103,255),width=2)
    d.line([(w-6,6),(w-6,h-7)],fill=(20,59,105,255),width=2)
    # Fine engraved corner tracery, constrained to a 12px peripheral strip.
    for mirror_x in (False, True):
        for mirror_y in (False, True):
            def reflect(x,y):
                return (w-1-x if mirror_x else x, h-1-y if mirror_y else y)
            d.line([reflect(8,22),reflect(8,13),reflect(13,8),reflect(22,8)],
                   fill=(89,160,205,235),width=1)
            d.line([reflect(9,21),reflect(9,13),reflect(13,9),reflect(21,9)],
                   fill=(29,86,140,255),width=1)
    return im

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
    textures={"ultimate_corner":corner(),"ultimate_crest":crest(),"ultimate_titlebar":title(),"ultimate_panel":panel()}
    for name,im in textures.items():(out/(name+".tga")).write_bytes(tga_bytes(im))
    print("Generated",len(textures),"original textures in",out)

if __name__=="__main__":
    if len(sys.argv)!=2:raise SystemExit("Usage: python tools/make_ultimate_art.py <Media directory>")
    main(sys.argv[1])
