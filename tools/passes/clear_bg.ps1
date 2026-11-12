# Make an icon's white background transparent (ChatGPT icons come on white).
# Flood-fills from the edges through anything that isn't the dark outline, and turns that area's whiteness into
# transparency ("colour to alpha"), so soft glows stay as see-through glows. Insides of outlined shapes keep their whites.
param([string]$In, [string]$Out, [int]$Size = 1024)
Add-Type -AssemblyName System.Drawing
Add-Type -ReferencedAssemblies System.Drawing -TypeDefinition @"
using System; using System.Drawing; using System.Drawing.Imaging; using System.Runtime.InteropServices; using System.Collections.Generic;
public static class ClearBg {
  public static Bitmap Run(string path) {
    var src = new Bitmap(path); var b = new Bitmap(src.Width, src.Height, PixelFormat.Format32bppArgb);
    using (var g = Graphics.FromImage(b)) g.DrawImage(src, 0, 0, src.Width, src.Height); src.Dispose();
    var d = b.LockBits(new Rectangle(0, 0, b.Width, b.Height), ImageLockMode.ReadWrite, PixelFormat.Format32bppArgb);
    var a = new byte[d.Stride * b.Height]; Marshal.Copy(d.Scan0, a, 0, a.Length);
    int W = b.Width, H = b.Height; var seen = new bool[W * H]; var q = new Queue<int>();
    Func<int, bool> open = k => { int i = (k / W) * d.Stride + (k % W) * 4; return Math.Min(a[i + 2], Math.Min(a[i + 1], a[i])) > 140; };   /* near-white / pale glow only: bright yellow or green parts are a wall */
    for (int x = 0; x < W; x++) { q.Enqueue(x); q.Enqueue((H - 1) * W + x); }
    for (int y = 0; y < H; y++) { q.Enqueue(y * W); q.Enqueue(y * W + W - 1); }
    while (q.Count > 0) {
      int k = q.Dequeue(); if (seen[k] || !open(k)) continue; seen[k] = true;
      int x = k % W, y = k / W;
      if (x > 0) q.Enqueue(k - 1); if (x < W - 1) q.Enqueue(k + 1); if (y > 0) q.Enqueue(k - W); if (y < H - 1) q.Enqueue(k + W);
    }
    for (int k = 0; k < W * H; k++) {
      if (!seen[k]) continue; int i = (k / W) * d.Stride + (k % W) * 4;
      double r = a[i + 2] / 255.0, g = a[i + 1] / 255.0, bl = a[i] / 255.0;
      double al = 1 - Math.Min(r, Math.Min(g, bl));
      if (al < 0.04) { a[i + 3] = 0; continue; }
      a[i + 2] = (byte)Math.Max(0, Math.Min(255, 255 * (r - (1 - al)) / al));
      a[i + 1] = (byte)Math.Max(0, Math.Min(255, 255 * (g - (1 - al)) / al));
      a[i] = (byte)Math.Max(0, Math.Min(255, 255 * (bl - (1 - al)) / al));
      a[i + 3] = (byte)(255 * al);
    }
    Marshal.Copy(a, 0, d.Scan0, a.Length); b.UnlockBits(d); return b;
  }
}
"@
$b = [ClearBg]::Run($In)
$o = New-Object System.Drawing.Bitmap $Size, $Size, ([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
$g = [System.Drawing.Graphics]::FromImage($o); $g.InterpolationMode = "HighQualityBicubic"; $g.PixelOffsetMode = "HighQuality"; $g.Clear([System.Drawing.Color]::Transparent)
$g.DrawImage($b, 0, 0, $Size, $Size); $g.Dispose(); $b.Dispose()
$o.Save($Out, [System.Drawing.Imaging.ImageFormat]::Png); $o.Dispose()
"saved $Out"
