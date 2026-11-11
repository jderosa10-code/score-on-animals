# ROUND 3 on every animal: warp.py (one smooth warp, no part guessing) on the ORIGINAL meshes,
# then one FBX for Studio. Same animal lists as round 2. Low priority, 3 Blenders at a time.
$d = "C:\Users\ortho\OneDrive\Desktop\New folder (2)\roblox_pets\variants"
$b = "C:\Program Files\Blender Foundation\Blender 5.2\blender.exe"
New-Item -ItemType Directory -Force "$d\round3\cmp" | Out-Null
$all = ((Get-Content "$d\remaining_map.txt" -Raw).Trim() -split ',') | ForEach-Object { ($_ -split '=')[1] } | Select-Object -Unique
$half = [Math]::Ceiling($all.Count / 2)
$jobs = @(
  @{ src = "five_originals.blend";    names = "Corgi1,Toad1,Hedgehog1,Giraffe1,Polarbear1"; tag = "r5" },
  @{ src = "batch2_originals.blend";  names = (Get-Content "$d\batch2_keep.txt").Trim(); tag = "r2" },
  @{ src = "batch3_originals.blend";  names = "Tapirv21,Porcupine1,Platypus1,Binturong1,Jackalope1,Raiju1,Chupacabra1,Australiancattledog11,Bichonfrise11,Cavalierkingcharlesspaniel1,Iguana1,Komododragon1,Kappa1,Toucan1,Muscovyduck1,Kookaburra1,Shoebill1"; tag = "r3a" },
  @{ src = "batch3b_originals.blend"; names = "Gecko1,Newt1,Chameleon1,Raven1,Ladybug1,Beetle1,Giantisopod1,Qilin1,Yiqi1"; tag = "r3b" },
  @{ src = "all_originals.blend";     names = ($all[0..($half-1)] -join ','); tag = "rA" },
  @{ src = "all_originals.blend";     names = ($all[$half..($all.Count-1)] -join ','); tag = "rB" }
)
function RunSet($set) {
  $procs = foreach ($j in $set) {
    Start-Process -FilePath $b -ArgumentList @('-b',"`"$d\$($j.src)`"",'-P',"`"$d\warp.py`"",'--',"`"$d\round3\r3_$($j.tag).blend`"","`"$d\round3\cmp`"",$j.names) -NoNewWindow -PassThru -RedirectStandardOutput "$d\round3\r3_$($j.tag).txt" -RedirectStandardError "$d\round3\r3_$($j.tag)_err.txt"
  }
  foreach ($q in $procs) { try { $q.PriorityClass = 'BelowNormal' } catch {} }
  foreach ($q in $procs) { $q.WaitForExit() }
}
RunSet $jobs[0..2]
RunSet $jobs[3..5]
$total = 0
foreach ($j in $jobs) {
  $n = (Select-String -Path "$d\round3\r3_$($j.tag).txt" -Pattern '^WARP').Count; $total += $n
  "{0}: warped {1}, skipped {2}, done {3}" -f $j.tag, $n, (Select-String -Path "$d\round3\r3_$($j.tag).txt" -Pattern '^SKIP').Count, ((Select-String -Path "$d\round3\r3_$($j.tag).txt" -Pattern '^DONE').Count -gt 0)
  Get-Content "$d\round3\r3_$($j.tag)_err.txt" | Where-Object { $_ -match 'Error|Traceback|line \d' } | Select-Object -First 3
}
"total warped: $total"
# merge everything into one file, then export one FBX (same names as before: <Pack>_NEW_Body)
$cur = "$d\round3\r3_rA.blend"
$names = $jobs[4].names
foreach ($j in $jobs | Where-Object { $_.tag -ne 'rA' }) {
  $out = "$d\round3\merge_$($j.tag).blend"
  $p = Start-Process -FilePath $b -ArgumentList @('-b',"`"$cur`"",'-P',"`"$d\merge_into.py`"",'--',"`"$d\round3\r3_$($j.tag).blend`"",$j.names,"`"$out`"") -NoNewWindow -PassThru -RedirectStandardOutput "$d\round3\merge_$($j.tag).txt" -RedirectStandardError "$d\round3\merge_$($j.tag)_err.txt"
  try { $p.PriorityClass = 'BelowNormal' } catch {}; $p.WaitForExit()
  $cur = $out; $names = $names + ',' + $j.names
}
$p = Start-Process -FilePath $b -ArgumentList @('-b',"`"$cur`"",'-P',"`"$d\export_fbx.py`"",'--',"`"$d\fbx`"",$names,'Restyle_R3.fbx') -NoNewWindow -PassThru -RedirectStandardOutput "$d\round3\export.txt" -RedirectStandardError "$d\round3\export_err.txt"
try { $p.PriorityClass = 'BelowNormal' } catch {}; $p.WaitForExit()
"exported animals: $((Select-String -Path "$d\round3\export.txt" -Pattern '^ANIMAL').Count)"
Get-Content "$d\round3\export_err.txt" | Where-Object { $_ -match 'Error|Traceback|line \d' } | Select-Object -First 3
Copy-Item "$d\fbx\Restyle_R3.fbx" "$d\Restyle_R3.fbx" -Force
"{0:N1} MB" -f ((Get-Item "$d\Restyle_R3.fbx").Length / 1MB)
"ALL DONE"
