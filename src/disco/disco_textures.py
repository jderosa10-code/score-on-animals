# Groovy (disco) mutation textures, 8x8 mirror-tile grid, 256 px (pigeon-claude 14 Nov 2026)
#  DiscoMirror.png : silver mirror tiles, each a slightly different brightness + a corner glint, dark grout
#  DiscoSpots.png  : the same grid with ~1 in 5 tiles lit pink/cyan/yellow/purple/green/orange, rest clear
import random, sys
from PIL import Image, ImageDraw
out = sys.argv[1]
N, C, G = 256, 32, 3          # size, cell, grout
random.seed(4)
m = Image.new("RGBA", (N, N), (38, 40, 52, 235))
d = ImageDraw.Draw(m)
for i in range(8):
    for j in range(8):
        x0, y0 = i * C + G // 2 + 1, j * C + G // 2 + 1
        x1, y1 = x0 + C - G - 1, y0 + C - G - 1
        v = random.randint(170, 255)
        a = random.randint(70, 150)
        d.rectangle([x0, y0, x1, y1], fill=(v, v, min(255, v + 12), a))
        # bevel: lighter top-left edge, darker bottom-right edge
        d.line([x0, y0, x1, y0], fill=(255, 255, 255, 200), width=2)
        d.line([x0, y0, x0, y1], fill=(255, 255, 255, 170), width=2)
        d.line([x0, y1, x1, y1], fill=(90, 95, 115, 200), width=2)
        d.line([x1, y0, x1, y1], fill=(90, 95, 115, 200), width=2)
        if random.random() < 0.3:   # a glint on some tiles
            d.polygon([(x0 + 3, y0 + 3), (x0 + 13, y0 + 3), (x0 + 3, y0 + 13)], fill=(255, 255, 255, 235))
m.save(out + "/DiscoMirror.png")
COLS = [(255, 60, 170), (60, 220, 255), (255, 220, 60), (170, 80, 255), (80, 255, 140), (255, 120, 40)]
s = Image.new("RGBA", (N, N), (0, 0, 0, 0))
d = ImageDraw.Draw(s)
cells = [(i, j) for i in range(8) for j in range(8)]
random.shuffle(cells)
for k, (i, j) in enumerate(cells[:13]):
    x0, y0 = i * C + G // 2 + 1, j * C + G // 2 + 1
    x1, y1 = x0 + C - G - 1, y0 + C - G - 1
    c = COLS[k % len(COLS)]
    d.rectangle([x0, y0, x1, y1], fill=c + (215,))
    d.rectangle([x0 + 6, y0 + 6, x1 - 6, y1 - 6], fill=tuple(min(255, v + 70) for v in c) + (240,))
s.save(out + "/DiscoSpots.png")
# preview: both over grey
p = Image.new("RGBA", (N * 2, N), (150, 150, 155, 255))
p.alpha_composite(m, (0, 0)); p.alpha_composite(m, (N, 0)); p.alpha_composite(s, (N, 0))
p.save(out + "/disco_preview.png")
print("ok")
