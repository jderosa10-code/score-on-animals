"""Cut a magenta-screen capture of the Studio icon booth into 256x256 icons with a dark navy stroke.

usage: python3 make_icons.py <capture.jpg> <group> <cols> <rows> <outdir> <Name1,Name2,...>
group: animals | big | eggs   (big = head-and-front crop; animals face right in the booth)
"""
import sys, os, json
import numpy as np
from PIL import Image
from scipy import ndimage

STROKE = (4, 4, 53)        # from Arm_1st_Outline_256px.png
SIZE = 256
SS = 2                     # supersample for smooth edges
STROKE_PX = 12             # at 256
PAD = 6                    # empty space outside the stroke

def key_mask(rgb):
    r, g, b = rgb[..., 0].astype(int), rgb[..., 1].astype(int), rgb[..., 2].astype(int)
    # distance from magenta in a way that tolerates jpeg noise
    if os.environ.get("KEY") == "green":
        bg = (g > 170) & (r < 110) & (b < 110)
    else:
        bg = (r > 150) & (b > 150) & (g < 120) & (np.abs(r - b) < 80)
    fg = ~bg
    fg = ndimage.binary_opening(fg, iterations=1)
    lab, n = ndimage.label(fg)
    if n == 0:
        return fg
    sizes = ndimage.sum(fg, lab, range(1, n + 1))
    keep = np.zeros(n + 1, bool)
    big = sizes.max()
    for i, s in enumerate(sizes, 1):
        if s >= max(25, big * 0.002):
            keep[i] = True
    fg = keep[lab]
    return fg

TALL = {"Brachiosaurus", "Plesiosaur", "Gallimimus", "GiantSquid"}

def icon_from(cell_rgb, group, name=""):
    fg = key_mask(cell_rgb)
    ys, xs = np.nonzero(fg)
    if len(xs) == 0:
        return None, "empty"
    h, w = fg.shape
    touches = xs.min() <= 1 or ys.min() <= 1 or xs.max() >= w - 2 or ys.max() >= h - 2
    x0, x1, y0, y1 = xs.min(), xs.max() + 1, ys.min(), ys.max() + 1
    bleed = False
    if group == "big":
        # head-and-front crop: animals face screen-right in the booth, so keep the right end
        bw, bh = x1 - x0, y1 - y0
        S = int(0.55 * max(bw, bh))
        right = x1 + int(0.06 * S)
        left = right - S
        strip = fg[:, max(left, 0):min(right, w)]
        rys = np.nonzero(strip)[0]
        if not len(rys):
            cyy = (y0 + y1) / 2
        elif name in TALL:   # long necks: the head is at the top
            cyy = (rys.mean() + rys.min()) / 2 + 0.12 * S
        else:
            cyy = rys.mean()
        top = int(cyy - 0.55 * S)
        x0, x1, y0, y1 = left, right, top, top + S
        bleed = True
    # square window around the content
    cw, ch = x1 - x0, y1 - y0
    side = max(cw, ch)
    cx, cy = (x0 + x1) / 2, (y0 + y1) / 2
    X0, Y0 = int(round(cx - side / 2)), int(round(cy - side / 2))
    canvas_rgb = np.zeros((side, side, 3), np.uint8)
    canvas_fg = np.zeros((side, side), bool)
    sx0, sy0 = max(X0, 0), max(Y0, 0)
    sx1, sy1 = min(X0 + side, w), min(Y0 + side, h)
    canvas_rgb[sy0 - Y0:sy1 - Y0, sx0 - X0:sx1 - X0] = cell_rgb[sy0:sy1, sx0:sx1]
    canvas_fg[sy0 - Y0:sy1 - Y0, sx0 - X0:sx1 - X0] = fg[sy0:sy1, sx0:sx1]
    # place into the icon (supersampled)
    S2 = SIZE * SS
    inner = S2 if bleed else S2 - 2 * (STROKE_PX + PAD) * SS
    img = Image.fromarray(canvas_rgb).resize((inner, inner), Image.LANCZOS)
    m = Image.fromarray((canvas_fg * 255).astype(np.uint8)).resize((inner, inner), Image.LANCZOS)
    off = (S2 - inner) // 2
    rgb = np.zeros((S2, S2, 3), np.uint8)
    a = np.zeros((S2, S2), float)
    rgb[off:off + inner, off:off + inner] = np.array(img)
    a[off:off + inner, off:off + inner] = np.array(m) / 255.0
    solid = a > 0.5
    # pull the colour layer in by a pixel so magenta fringe sits under the stroke
    fill = ndimage.binary_erosion(solid, iterations=SS * 1)
    dist = ndimage.distance_transform_edt(~fill)
    stroke_a = np.clip(STROKE_PX * SS + 1 - dist, 0, 1)
    out = np.zeros((S2, S2, 4), float)
    out[..., :3] = STROKE
    out[..., 3] = stroke_a
    fa = ndimage.gaussian_filter(fill.astype(float), 0.6)
    for c in range(3):
        out[..., c] = rgb[..., c] * fa + out[..., c] * (1 - fa)
    out[..., 3] = np.maximum(stroke_a, fa) * 255
    res = Image.fromarray(np.clip(out, 0, 255).astype(np.uint8), "RGBA").resize((SIZE, SIZE), Image.LANCZOS)
    return res, ("clipped" if touches and group != "big" else "ok")

def main():
    path, group, cols, rows, outdir, names = sys.argv[1], sys.argv[2], int(sys.argv[3]), int(sys.argv[4]), sys.argv[5], sys.argv[6].split(",")
    os.makedirs(outdir, exist_ok=True)
    im = np.array(Image.open(path).convert("RGB"))
    H, W = im.shape[:2]
    cw, ch = W / cols, H / rows
    report = {}
    for i, name in enumerate(names):
        if not name:
            continue
        c, r = i % cols, i // cols
        x0, y0 = int(c * cw) + 2, int(r * ch) + 2
        x1, y1 = int((c + 1) * cw) - 2, int((r + 1) * ch) - 2
        icon, status = icon_from(im[y0:y1, x0:x1], group, name)
        report[name] = status
        if icon is not None:
            icon.save(os.path.join(outdir, name + ".png"))
    print(json.dumps(report))

if __name__ == "__main__":
    main()
