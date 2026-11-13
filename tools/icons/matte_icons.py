"""Two-background matting (magenta + green) of the DNA tube booth, then 256x256 icons with the navy stroke."""
import sys, os
import numpy as np
from PIL import Image
from scipy import ndimage

STROKE = np.array([4, 4, 53], float)
SIZE, SS, STROKE_PX, PAD = 256, 2, 12, 6
BM, BG = np.array([255, 0, 255], float), np.array([0, 255, 0], float)

def matte(cm, cg):
    D = BM - BG
    k = ((cm - cg) @ D) / (D @ D)          # = 1 - alpha
    a = np.clip(1 - k, 0, 1)
    a[a < 0.06] = 0
    a = ndimage.median_filter(a, 3)
    num = (cm - (1 - a)[..., None] * BM) + (cg - (1 - a)[..., None] * BG)
    f = np.clip(num / np.maximum(2 * a[..., None], 1e-3), 0, 255)
    return f, a

def icon(f, a):
    solid = a > 0.25
    lab, n = ndimage.label(solid)
    if n:
        sizes = ndimage.sum(solid, lab, range(1, n + 1))
        solid = lab == (np.argmax(sizes) + 1)
        solid = ndimage.binary_fill_holes(solid)
    a = a * ndimage.binary_dilation(solid, iterations=2)
    ys, xs = np.nonzero(solid)
    x0, x1, y0, y1 = xs.min(), xs.max() + 1, ys.min(), ys.max() + 1
    side = max(x1 - x0, y1 - y0)
    cx, cy = (x0 + x1) / 2, (y0 + y1) / 2
    X0, Y0 = int(round(cx - side / 2)), int(round(cy - side / 2))
    H, W = a.shape
    cf = np.zeros((side, side, 3)); ca = np.zeros((side, side)); cs = np.zeros((side, side))
    sx0, sy0, sx1, sy1 = max(X0, 0), max(Y0, 0), min(X0 + side, W), min(Y0 + side, H)
    cf[sy0-Y0:sy1-Y0, sx0-X0:sx1-X0] = f[sy0:sy1, sx0:sx1]
    ca[sy0-Y0:sy1-Y0, sx0-X0:sx1-X0] = a[sy0:sy1, sx0:sx1]
    cs[sy0-Y0:sy1-Y0, sx0-X0:sx1-X0] = solid[sy0:sy1, sx0:sx1]
    S2 = SIZE * SS
    inner = S2 - 2 * (STROKE_PX + PAD) * SS
    rs = lambda arr: np.array(Image.fromarray(arr.astype(np.uint8)).resize((inner, inner), Image.LANCZOS)).astype(float)
    F = np.zeros((S2, S2, 3)); A = np.zeros((S2, S2)); SOL = np.zeros((S2, S2))
    off = (S2 - inner) // 2
    F[off:off+inner, off:off+inner] = rs(cf)
    A[off:off+inner, off:off+inner] = rs(ca * 255) / 255
    SOL[off:off+inner, off:off+inner] = rs(cs * 255) / 255
    shape = SOL > 0.5
    dist = ndimage.distance_transform_edt(~shape)
    ring = np.clip(STROKE_PX * SS + 1 - dist, 0, 1) * (dist > 0)
    # inside the silhouette: the object (glass stays see-through); outside: the navy stroke
    A = np.where(shape, np.maximum(A, 0.0), 0)
    out_a = A + ring * (1 - A)
    out_rgb = (F * A[..., None] + STROKE * (ring * (1 - A))[..., None]) / np.maximum(out_a[..., None], 1e-3)
    out = np.dstack([np.clip(out_rgb, 0, 255), np.clip(out_a * 255, 0, 255)]).astype(np.uint8)
    return Image.fromarray(out, "RGBA").resize((SIZE, SIZE), Image.LANCZOS)

def main():
    cm = np.array(Image.open(sys.argv[1]).convert("RGB")).astype(float)
    cg = np.array(Image.open(sys.argv[2]).convert("RGB")).astype(float)
    outdir = sys.argv[3]
    os.makedirs(outdir, exist_ok=True)
    f, a = matte(cm, cg)
    tiers = ["Common", "Rare", "Epic", "Legendary"]
    for r, state in enumerate(["Empty", "Filled"]):
        for c, t in enumerate(tiers):
            x0, x1 = c * 240 + 20, c * 240 + 250
            y0, y1 = (0, 283) if r == 0 else (283, 560)
            im = icon(f[y0:y1, x0:x1], a[y0:y1, x0:x1])
            im.save(os.path.join(outdir, f"DNA_{t}_{state}.png"))
    print("done")

main()
