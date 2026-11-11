# Rig every animal: one Rig_<Name>.fbx per animal in rig\batch, reports in rig\batch2_reports.
# Animals are grouped by the round-3 blend that holds their original + warped meshes (pack_source.txt).
$rig = "C:\Users\ortho\OneDrive\Desktop\New folder (2)\roblox_pets\rig"
$v = "C:\Users\ortho\OneDrive\Desktop\New folder (2)\roblox_pets\variants"
$b = "C:\Program Files\Blender Foundation\Blender 5.2\blender.exe"
New-Item -ItemType Directory -Force "$rig\batch2", "$rig\batch2_reports" | Out-Null
$src = @{}; Get-Content "$rig\pack_source.txt" | ForEach-Object { $k, $x = $_ -split '='; $src[$k] = $x }
$j = Get-Content "$rig\studio_dump\bones.json" -Raw | ConvertFrom-Json
$byFile = @{}
foreach ($e in $j) { $pk = $e.new.part -replace '_NEW_.*$',''; $fl = $src[$pk]; if ($fl) { if (-not $byFile[$fl]) { $byFile[$fl] = @() }; $byFile[$fl] += $e.name } }
$jobs = @()
foreach ($fl in $byFile.Keys) {
  $names = $byFile[$fl]
  for ($i = 0; $i -lt $names.Count; $i += 25) {       # 25 animals per Blender run
    $jobs += [pscustomobject]@{ file = $fl; names = ($names[$i..([Math]::Min($i + 24, $names.Count - 1))] -join ','); tag = "$fl`_$i" }
  }
}
$env:RIG_SPLIT = "$rig\batch2"
$running = @()
foreach ($jb in $jobs) {
  while (($running | Where-Object { -not $_.HasExited }).Count -ge 3) { Start-Sleep -Seconds 3 }
  $p = Start-Process -FilePath $b -ArgumentList @('-b',"`"$v\round3\$($jb.file).blend`"",'-P',"`"$rig\rig_build.py`"",'--',"`"$rig\studio_dump\bones.json`"",$jb.names,"`"$rig\batch2_reports\x.fbx`"","`"$rig\batch2_reports\$($jb.tag).json`"") -NoNewWindow -PassThru -RedirectStandardOutput "$rig\batch2_reports\$($jb.tag).txt" -RedirectStandardError "$rig\batch2_reports\$($jb.tag)_err.txt"
  try { $p.PriorityClass = 'BelowNormal' } catch {}
  $running += $p
}
foreach ($p in $running) { $p.WaitForExit() }
$env:RIG_SPLIT = $null
$files = (Get-ChildItem "$rig\batch2" -Filter "Rig_*.fbx").Count
"jobs $($jobs.Count), files $files of $($j.Count)"
Get-ChildItem "$rig\batch2_reports" -Filter "*_err.txt" | ForEach-Object { Get-Content $_.FullName } | Where-Object { $_ -match 'Error|Traceback' } | Select-Object -First 6
"ALL DONE"

