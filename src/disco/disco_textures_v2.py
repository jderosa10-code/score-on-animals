# Groovy textures v2 (pigeon-claude 14 Nov 2026): cleaner mirror tiles, thin grout, strong facet contrast; fewer, brighter spots
import random, sys
from PIL import Image, ImageDraw, ImageFilter
out = sys.argv[1]
N, C, G = 256, 32, 2
random.seed(11)
m = Image.new("RGBA", (N, N), (30, 32, 44, 210))
d = ImageDraw.Draw(m)
for i in range(8):
    for j in range(8):
        x0, y0 = i * C + G, j * C + G
        x1, y1 = x0 + C - 2 * G - 1, y0 + C - 2 * G - 1
        r = random.random()
        if r < 0.12:   v, a = 255, 210      # a tile catching the light
        elif r < 0.35: v, a = 120, 120      # a darker facet
        else:          v, a = random.randint(185, 235), random.randint(60, 110)
        d.rectangle([x0, y0, x1, y1], fill=(v, v, v, a))
        d.line([x0, y0, x1, y0], fill=(255, 255, 255, 230), width=2)   # bevel top
        d.line([x0, y0, x0, y1], fill=(255, 255, 255, 190), width=2)   # bevel left
        if r < 0.12:   # star glint on the bright tiles
            cx, cy = x0 + 9, y0 + 9
            d.line([cx - 6, cy, cx + 6, cy], fill=(255, 255, 255, 255), width=2)
            d.line([cx, cy - 6, cx, cy + 6], fill=(255, 255, 255, 255), width=2)
m.save(out + "/DiscoMirror2.png")
COLS = [(255, 40, 160), (40, 210, 255), (255, 215, 30), (160, 60, 255), (60, 255, 120), (255, 110, 20)]
s = Image.new("RGBA", (N, N), (0, 0, 0, 0))
glow = Image.new("RGBA", (N, N), (0, 0, 0, 0))
d, dg = ImageDraw.Draw(s), ImageDraw.Draw(glow)
cells = [(i, j) for i in range(8) for j in range(8)]
random.shuffle(cells)
for k, (i, j) in enumerate(cells[:9]):
    x0, y0 = i * C + G, j * C + G
    x1, y1 = x0 + C - 2 * G - 1, y0 + C - 2 * G - 1
    c = COLS[k % len(COLS)]
    dg.rectangle([x0 - 3, y0 - 3, x1 + 3, y1 + 3], fill=c + (120,))
    d.rectangle([x0, y0, x1, y1], fill=c + (235,))
    d.rectangle([x0 + 7, y0 + 7, x1 - 7, y1 - 7], fill=tuple(min(255, v + 110) for v in c) + (255,))
glow = glow.filter(ImageFilter.GaussianBlur(3))
glow.alpha_composite(s)
glow.save(out + "/DiscoSpots2.png")
p = Image.new("RGBA", (N * 2, N), (150, 150, 155, 255))
p.alpha_composite(m, (0, 0)); p.alpha_composite(m, (N, 0)); p.alpha_composite(glow, (N, 0))
p.save(out + "/../disco_preview2.png")
print("ok")
