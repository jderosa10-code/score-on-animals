# ROUND 2, job rB only (the half of all_originals.blend that was cut off). One Blender, low
# priority, because a game may be running.
$d = "C:\Users\ortho\OneDrive\Desktop\New folder (2)\roblox_pets\variants"
$b = "C:\Program Files\Blender Foundation\Blender 5.2\blender.exe"
$env:SOA_FAST = '1'
$env:SOA_ROUND2 = '1'
New-Item -ItemType Directory -Force "$d\round2\cmp" | Out-Null
$all = ((Get-Content "$d\remaining_map.txt" -Raw).Trim() -split ',') | ForEach-Object { ($_ -split '=')[1] } | Select-Object -Unique
$half = [Math]::Ceiling($all.Count / 2)
$names = ($all[$half..($all.Count-1)] -join ',')
$p = Start-Process -FilePath $b -ArgumentList @('-b',"`"$d\all_originals.blend`"",'-P',"`"$d\restyle.py`"",'--',"`"$d\round2\r2_rB.blend`"","`"$d\round2\cmp\cmp.png`"",$names) -NoNewWindow -PassThru -RedirectStandardOutput "$d\round2\r2_rB.txt" -RedirectStandardError "$d\round2\r2_rB_err.txt"
try { $p.PriorityClass = 'BelowNormal' } catch {}
$p.WaitForExit()
"rB: restyled $((Select-String -Path "$d\round2\r2_rB.txt" -Pattern '^RESTYLE').Count) of $($all.Count - $half), done=$((Select-String -Path "$d\round2\r2_rB.txt" -Pattern '^DONE').Count), blend=$(Test-Path "$d\round2\r2_rB.blend")"
Get-Content "$d\round2\r2_rB_err.txt" | Where-Object { $_ -match 'Error|Traceback|line \d' } | Select-Object -First 6
