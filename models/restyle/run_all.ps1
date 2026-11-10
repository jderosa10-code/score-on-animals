# Extract every remaining animal once, then restyle them in 4 chunks (2 at a time, low priority).
$d = "C:\Users\ortho\OneDrive\Desktop\New folder (2)\roblox_pets\variants"
$b = "C:\Program Files\Blender Foundation\Blender 5.2\blender.exe"
$map = (Get-Content "$d\remaining_map.txt" -Raw).Trim() -split ','
$packs = $map | ForEach-Object { ($_ -split '=')[1] } | Select-Object -Unique
"animals: $($packs.Count)"
$p = Start-Process -FilePath $b -ArgumentList @('-b','--factory-startup','-P',"`"$d\extract.py`"",'--','C:\Users\ortho\Downloads\animals.obj',"`"$d\all_originals.blend`"",($packs -join ',')) -NoNewWindow -PassThru -RedirectStandardOutput "$d\all_extract_log.txt" -RedirectStandardError "$d\all_extract_err.txt"
try { $p.PriorityClass = 'BelowNormal' } catch {}
$p.WaitForExit()
"extracted"
New-Item -ItemType Directory -Force "$d\all" | Out-Null
$env:SOA_FAST = '1'
$chunks = @()
$n = [Math]::Ceiling($packs.Count / 4)
for ($i = 0; $i -lt 4; $i++) { $chunks += ,($packs[($i*$n)..([Math]::Min(($i+1)*$n, $packs.Count)-1)] -join ',') }
for ($pair = 0; $pair -lt 4; $pair += 2) {
    $procs = @()
    foreach ($i in $pair, ($pair+1)) {
        $procs += Start-Process -FilePath $b -ArgumentList @('-b',"`"$d\all_originals.blend`"",'-P',"`"$d\restyle.py`"",'--',"`"$d\all_part$i.blend`"","`"$d\all\cmp.png`"",$chunks[$i]) -NoNewWindow -PassThru -RedirectStandardOutput "$d\all_log$i.txt" -RedirectStandardError "$d\all_err$i.txt"
    }
    foreach ($q in $procs) { try { $q.PriorityClass = 'BelowNormal' } catch {} }
    foreach ($q in $procs) { $q.WaitForExit() }
    "chunks $pair,$($pair+1) done"
}
"ALL DONE"
