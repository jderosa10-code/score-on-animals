import sys, glob
from PIL import Image
fs = sorted(glob.glob(sys.argv[1] + "/*.png"))
cols = 8
rows = (len(fs) + cols - 1) // cols
sheet = Image.new("RGBA", (256 * cols, 256 * rows), (190, 205, 225, 255))
for i, f in enumerate(fs):
    sheet.alpha_composite(Image.open(f), ((i % cols) * 256, (i // cols) * 256))
sheet.convert("RGB").resize((sheet.width // 2, sheet.height // 2)).save(sys.argv[2], quality=88)
