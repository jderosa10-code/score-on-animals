# Pass icons v2 (pigeon: the glossy 3D ones were awful, match the existing product icons).
# Built from the game's own art: Jacob's Framewisp icon pack (thick #181C32 outline) + the voxel egg/animal renders,
# with flat shapes in the same style and Luckiest Guy "2X"-style labels (#FFDC28, #141032 outline), like cash2x.png.
param([string]$Out = "C:\Users\ortho\OneDrive\Desktop\ROBLOX IMPORT\passes")
Add-Type -AssemblyName System.Drawing
Add-Type -ReferencedAssemblies System.Drawing -TypeDefinition @"
using System; using System.Drawing; using System.Drawing.Drawing2D; using System.Drawing.Imaging; using System.Drawing.Text;
public static class Ico {
  public static Color Navy = Color.FromArgb(24, 28, 50);
  public static Color TextNavy = Color.FromArgb(20, 16, 50);
  public static PrivateFontCollection Fonts = new PrivateFontCollection();
  public static Bitmap Blank() { var b = new Bitmap(512, 512, PixelFormat.Format32bppArgb); using (var g = Graphics.FromImage(b)) g.Clear(Color.Transparent); return b; }
  static Graphics G(Bitmap b) { var g = Graphics.FromImage(b); g.SmoothingMode = SmoothingMode.AntiAlias; g.InterpolationMode = InterpolationMode.HighQualityBicubic; g.PixelOffsetMode = PixelOffsetMode.HighQuality; g.CompositingQuality = CompositingQuality.HighQuality; return g; }
  // draw an image centred at (cx, cy), fitted into size px, rotated deg, optional colour remap (0 none, 1 gold, 2 diamond, 3 rainbow)
  public static void Img(Bitmap dst, string path, float cx, float cy, float size, float deg, int tint) {
    using (var src0 = new Bitmap(path)) {
      Bitmap src = tint == 0 ? new Bitmap(src0) : Tint(src0, tint);
      float k = size / Math.Max(src.Width, src.Height);
      using (var g = G(dst)) {
        g.TranslateTransform(cx, cy); g.RotateTransform(deg);
        g.DrawImage(src, -src.Width * k / 2, -src.Height * k / 2, src.Width * k, src.Height * k);
      }
      src.Dispose();
    }
  }
  static Bitmap Tint(Bitmap s, int mode) {
    var b = new Bitmap(s.Width, s.Height, PixelFormat.Format32bppArgb);
    for (int y = 0; y < s.Height; y++) for (int x = 0; x < s.Width; x++) {
      var c = s.GetPixel(x, y);
      if (c.A == 0) { b.SetPixel(x, y, c); continue; }
      double l = (0.3 * c.R + 0.59 * c.G + 0.11 * c.B) / 255.0;
      bool outline = c.R < 45 && c.G < 45 && c.B < 70;            // keep the navy sticker outline
      if (outline) { b.SetPixel(x, y, c); continue; }
      double r, gg, bb;
      if (mode == 1) { r = 255 * Math.Min(1, 0.55 + l * 0.6); gg = 255 * Math.Min(1, 0.36 + l * 0.6); bb = 255 * Math.Min(1, 0.02 + l * 0.35); }
      else if (mode == 2) { r = 255 * Math.Min(1, 0.35 + l * 0.65); gg = 255 * Math.Min(1, 0.75 + l * 0.3); bb = 255 * Math.Min(1, 0.95 + l * 0.1); }
      else { double h = ((double)y / s.Height) * 300.0; var hc = Hsv(h, 0.55, 0.45 + l * 0.6); r = hc[0]; gg = hc[1]; bb = hc[2]; }
      b.SetPixel(x, y, Color.FromArgb(c.A, (int)Math.Min(255, r), (int)Math.Min(255, gg), (int)Math.Min(255, bb)));
    }
    return b;
  }
  static double[] Hsv(double h, double s, double v) {
    v = Math.Min(1, v); double c = v * s, x = c * (1 - Math.Abs((h / 60) % 2 - 1)), m = v - c; double r = 0, g = 0, b = 0;
    if (h < 60) { r = c; g = x; } else if (h < 120) { r = x; g = c; } else if (h < 180) { g = c; b = x; } else if (h < 240) { g = x; b = c; } else if (h < 300) { r = x; b = c; } else { r = c; b = x; }
    return new double[] { (r + m) * 255, (g + m) * 255, (b + m) * 255 };
  }
  // flat shape with the pack's look: navy outline, fill, a white shine
  public static void Shape(Bitmap dst, GraphicsPath p, Color fill, Color shade, float outline) {
    using (var g = G(dst)) {
      using (var pen = new Pen(Navy, outline * 2) { LineJoin = LineJoin.Round }) g.DrawPath(pen, p);
      using (var br = new SolidBrush(fill)) g.FillPath(br, p);
      var rb = p.GetBounds();
      var clip = new Region(p); g.Clip = clip;
      using (var sh = new SolidBrush(shade)) g.FillRectangle(sh, rb.X, rb.Y + rb.Height * 0.62f, rb.Width, rb.Height);
      using (var hi = new SolidBrush(Color.FromArgb(150, 255, 255, 255))) g.FillEllipse(hi, rb.X + rb.Width * 0.18f, rb.Y + rb.Height * 0.1f, rb.Width * 0.22f, rb.Height * 0.12f);
      g.ResetClip();
    }
  }
  public static GraphicsPath Circle(float cx, float cy, float r) { var p = new GraphicsPath(); p.AddEllipse(cx - r, cy - r, r * 2, r * 2); return p; }
  public static GraphicsPath Moon(float cx, float cy, float r) {
    var a = new GraphicsPath(); a.AddEllipse(cx - r, cy - r, r * 2, r * 2);
    var b = new GraphicsPath(); b.AddEllipse(cx - r * 0.35f, cy - r * 1.15f, r * 1.9f, r * 1.9f);
    var reg = new Region(a); reg.Exclude(b);
    var p = new GraphicsPath();
    // trace the crescent by sampling the region edge
    var pts = new System.Collections.Generic.List<PointF>();
    for (int i = 0; i <= 120; i++) { double t = Math.PI * 0.62 + i / 120.0 * Math.PI * 1.55; pts.Add(new PointF(cx + r * (float)Math.Cos(t), cy + r * (float)Math.Sin(t))); }
    float bx = cx - r * 0.35f + r * 0.95f, by = cy - r * 1.15f + r * 0.95f, br = r * 0.95f;
    var inner = new System.Collections.Generic.List<PointF>();
    for (int i = 0; i <= 120; i++) { double t = Math.PI * 0.62 + i / 120.0 * Math.PI * 1.55; var q = new PointF(cx + r * (float)Math.Cos(t), cy + r * (float)Math.Sin(t)); }
    p.AddEllipse(cx - r, cy - r, r * 2, r * 2);
    return p;
  }
  // a crescent drawn as: full disc, then the "bite" painted back to transparent, then outlined
  public static void Crescent(Bitmap dst, float cx, float cy, float r, Color fill, Color shade, float outline) {
    var layer = Blank();
    Shape(layer, Circle(cx, cy, r), fill, shade, outline);
    using (var g = Graphics.FromImage(layer)) {
      g.SmoothingMode = SmoothingMode.AntiAlias; g.CompositingMode = CompositingMode.SourceCopy;
      using (var clear = new SolidBrush(Color.Transparent)) g.FillEllipse(clear, cx - r * 0.25f, cy - r * 1.25f, r * 1.75f, r * 1.75f);
      g.CompositingMode = CompositingMode.SourceOver;
      g.SetClip(Circle(cx, cy, r + outline)); using (var pen = new Pen(Navy, outline * 2)) g.DrawEllipse(pen, cx - r * 0.25f, cy - r * 1.25f, r * 1.75f, r * 1.75f); g.ResetClip();
    }
    using (var g = G(dst)) g.DrawImage(layer, 0, 0);
    layer.Dispose();
  }
  public static void Star(Bitmap dst, float cx, float cy, float r, float outline) {
    var p = new GraphicsPath(); var pts = new PointF[8];
    for (int i = 0; i < 8; i++) { double a = i * Math.PI / 4 - Math.PI / 2; float rr = i % 2 == 0 ? r : r * 0.38f; pts[i] = new PointF(cx + rr * (float)Math.Cos(a), cy + rr * (float)Math.Sin(a)); }
    p.AddPolygon(pts);
    Shape(dst, p, Color.FromArgb(255, 236, 90), Color.FromArgb(255, 200, 40), outline);
  }
  // "2X" style label: Luckiest Guy, yellow, thick dark outline
  public static void Label(Bitmap dst, string text, float cx, float cy, float size, Color fill) {
    using (var g = G(dst)) {
      var p = new GraphicsPath();
      var fam = Fonts.Families[0];
      var sf = new StringFormat { Alignment = StringAlignment.Center, LineAlignment = StringAlignment.Center };
      p.AddString(text, fam, 0, size, new PointF(cx, cy), sf);
      using (var pen = new Pen(TextNavy, size * 0.32f) { LineJoin = LineJoin.Round }) g.DrawPath(pen, p);
      using (var br = new SolidBrush(fill)) g.FillPath(br, p);
    }
  }
  public static void Save(Bitmap b, string path) { b.Save(path, ImageFormat.Png); b.Dispose(); }
}
"@
[Ico]::Fonts.AddFontFile("$env:LOCALAPPDATA\Roblox\Versions\version-63eb6055af4e4688\content\fonts\LuckiestGuy-Regular.ttf")
$E = "C:\Users\ortho\ScoreOnAnimals\icons\Eggs"; $A = "C:\Users\ortho\ScoreOnAnimals\icons\Animals"
$P = "C:\Users\ortho\AppData\Local\Temp\claude\007600a20c8c370d\d0d3c2f9-f3fd-43df-b93a-c91dd5414ced\scratchpad\cand"   # Jacob's pack icons (thumbnails)
$Y = [System.Drawing.Color]::FromArgb(255, 220, 40)
New-Item -ItemType Directory -Force $Out | Out-Null

# Fast Hatch: an egg with Jacob's speed sneaker
$b = [Ico]::Blank(); [Ico]::Img($b, "$E\Corgi.png", 230, 236, 420, -8, 0); [Ico]::Img($b, "$P\85304749865231.png", 370, 360, 250, 0, 0); [Ico]::Save($b, "$Out\FastHatch.png")
# +5 Pen Slots: an animal and +5
$b = [Ico]::Blank(); [Ico]::Img($b, "$A\Corgi.png", 236, 230, 440, 0, 0); [Ico]::Label($b, "+5", 372, 392, 170, $Y); [Ico]::Save($b, "$Out\PenSlots.png")
# +3 Hatcheries: three eggs and +3
$b = [Ico]::Blank(); [Ico]::Img($b, "$E\Bunny.png", 105, 250, 300, -16, 0); [Ico]::Img($b, "$E\Chicken.png", 405, 240, 300, 14, 0); [Ico]::Img($b, "$E\Corgi.png", 250, 200, 310, 0, 0); [Ico]::Label($b, "+3", 372, 400, 170, $Y); [Ico]::Save($b, "$Out\Hatcheries3.png")
# 2x Strength: Jacob's bicep and 2X (like 2x Cash)
$b = [Ico]::Blank(); [Ico]::Img($b, "$P\115227323980377.png", 236, 220, 420, 0, 0); [Ico]::Label($b, "2X", 370, 400, 170, $Y); [Ico]::Save($b, "$Out\Strength2x.png")
# Super Luck: the unicorn egg, sparkles and 3X
$b = [Ico]::Blank(); [Ico]::Img($b, "$E\Unicorn.png", 236, 236, 430, 0, 0); [Ico]::Star($b, 90, 110, 52, 9); [Ico]::Star($b, 420, 140, 40, 8); [Ico]::Star($b, 110, 380, 34, 7); [Ico]::Label($b, "3X", 372, 400, 170, $Y); [Ico]::Save($b, "$Out\SuperLuck.png")
# Mutation Hunter: gold, diamond and rainbow eggs and 2X
$b = [Ico]::Blank(); [Ico]::Img($b, "$E\Bunny.png", 130, 225, 290, -14, 2); [Ico]::Img($b, "$E\Chicken.png", 382, 222, 290, 12, 3); [Ico]::Img($b, "$E\Corgi.png", 252, 210, 330, 0, 1); [Ico]::Star($b, 440, 80, 36, 7); [Ico]::Label($b, "2X", 372, 400, 170, $Y); [Ico]::Save($b, "$Out\MutationHunter.png")
# Bigger Green Zone: a flat target in the pack style
$b = [Ico]::Blank()
[Ico]::Shape($b, [Ico]::Circle(256, 250, 205), [System.Drawing.Color]::FromArgb(70, 214, 92), [System.Drawing.Color]::FromArgb(40, 170, 70), 9)
[Ico]::Shape($b, [Ico]::Circle(256, 250, 145), [System.Drawing.Color]::FromArgb(245, 248, 255), [System.Drawing.Color]::FromArgb(205, 214, 235), 7)
[Ico]::Shape($b, [Ico]::Circle(256, 250, 92), [System.Drawing.Color]::FromArgb(70, 214, 92), [System.Drawing.Color]::FromArgb(40, 170, 70), 7)
[Ico]::Shape($b, [Ico]::Circle(256, 250, 40), [System.Drawing.Color]::FromArgb(245, 248, 255), [System.Drawing.Color]::FromArgb(205, 214, 235), 6)
[Ico]::Label($b, "BIG", 380, 420, 120, $Y); [Ico]::Save($b, "$Out\GreenZone.png")
# Long Offline: a moon over Jacob's cash and 24H
$b = [Ico]::Blank(); [Ico]::Crescent($b, 180, 175, 135, [System.Drawing.Color]::FromArgb(255, 222, 70), [System.Drawing.Color]::FromArgb(245, 185, 30), 9)
[Ico]::Img($b, "$P\76394155120975.png", 285, 315, 360, -8, 0); [Ico]::Label($b, "24H", 372, 420, 140, $Y); [Ico]::Save($b, "$Out\LongOffline.png")
"done"
