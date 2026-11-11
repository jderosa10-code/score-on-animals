# Run the feature redesign on eggs and tile old/new check sheets.
#   .\run_features.ps1 -Names ALL            (or "Eggcow1,Eggcat1")
param([string]$Names = "ALL", [string]$Tag = "all")
$e = "C:\Users\ortho\OneDrive\Desktop\New folder (2)\roblox_pets\eggs"; $b = "C:\Program Files\Blender Foundation\Blender 5.2\blender.exe"
$j = "C:\Users\ortho\OneDrive\Desktop\New folder (2)\roblox_pets\variants\studio_json"
$rd = "$e\renders\feat_$Tag"
New-Item -ItemType Directory -Force $rd | Out-Null; Remove-Item "$rd\*.png" -ErrorAction SilentlyContinue
$env:EGG_OVERRIDES = "$e\feature_overrides.json"
$p = Start-Process -FilePath $b -ArgumentList @('-b',"`"$e\eggs2_originals.blend`"",'-P',"`"$e\egg_features2.py`"",'--',"`"$e\egg_features_$Tag.blend`"","`"$rd`"",$Names,"`"$j\eggfeat_$Tag.json`"") -NoNewWindow -PassThru -RedirectStandardOutput "$e\feat_$Tag.txt" -RedirectStandardError "$e\feat_${Tag}_err.txt"
try { $p.PriorityClass = 'BelowNormal' } catch {}; $p.WaitForExit()
Get-Content "$e\feat_$Tag.txt" | Where-Object { $_ -match '^CHANGED|^DONE|^MISSING|Traceback' }
Get-Content "$e\feat_${Tag}_err.txt" | Where-Object { $_ -match 'Error|Traceback|line \d' } | Select-Object -First 8
Add-Type -AssemblyName System.Drawing
foreach ($view in "a","b") {
  $files = Get-ChildItem $rd -Filter "*_$view.png" | Sort-Object Name
  $cols = 5; $rows = 6; $tw = 400; $th = 250; $per = $cols * $rows; $sheet = 0
  $f = New-Object System.Drawing.Font "Segoe UI", 11, ([System.Drawing.FontStyle]::Bold)
  for ($s = 0; $s -lt $files.Count; $s += $per) {
    $bmp = New-Object System.Drawing.Bitmap ($cols*$tw), ($rows*$th); $g = [System.Drawing.Graphics]::FromImage($bmp); $g.InterpolationMode = 'HighQualityBicubic'; $g.Clear([System.Drawing.Color]::White)
    for ($i = 0; $i -lt $per -and ($s+$i) -lt $files.Count; $i++) { $im = [System.Drawing.Image]::FromFile($files[$s+$i].FullName); $x = ($i % $cols) * $tw; $y = [math]::Floor($i / $cols) * $th; $g.DrawImage($im, $x, $y, $tw, $th); $im.Dispose(); $g.DrawString($files[$s+$i].BaseName.Substring(3).Replace("1_$view",''), $f, [System.Drawing.Brushes]::Black, $x + 2, $y + 1) }
    $g.Dispose(); $sheet++; $bmp.Save(("$e\renders\feat_${Tag}_${view}_{0:d2}.png" -f $sheet), [System.Drawing.Imaging.ImageFormat]::Png); $bmp.Dispose()
  }
  "view $view : $($files.Count) eggs, $sheet sheets"
}
