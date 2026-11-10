# Re-run the restyle on EVERY animal (all source blends) into rerun\ so the results can be
# compared with the previous logs. 3 at a time, low priority.
$d = "C:\Users\ortho\OneDrive\Desktop\New folder (2)\roblox_pets\variants"
$b = "C:\Program Files\Blender Foundation\Blender 5.2\blender.exe"
$env:SOA_FAST = '1'
New-Item -ItemType Directory -Force "$d\rerun" | Out-Null
$all = ((Get-Content "$d\remaining_map.txt" -Raw).Trim() -split ',') | ForEach-Object { ($_ -split '=')[1] } | Select-Object -Unique
$half = [Math]::Ceiling($all.Count / 2)
$jobs = @(
  @{ src = "five_originals.blend";   names = "Corgi1,Toad1,Hedgehog1,Giraffe1,Polarbear1"; tag = "r5" },
  @{ src = "batch2_originals.blend"; names = (Get-Content "$d\batch2_keep.txt").Trim(); tag = "r2" },
  @{ src = "batch3_originals.blend"; names = "Tapirv21,Porcupine1,Platypus1,Binturong1,Jackalope1,Raiju1,Chupacabra1,Australiancattledog11,Bichonfrise11,Cavalierkingcharlesspaniel1,Iguana1,Komododragon1,Kappa1,Toucan1,Muscovyduck1,Kookaburra1,Shoebill1"; tag = "r3a" },
  @{ src = "batch3b_originals.blend"; names = "Gecko1,Newt1,Chameleon1,Raven1,Ladybug1,Beetle1,Giantisopod1,Qilin1,Yiqi1"; tag = "r3b" },
  @{ src = "all_originals.blend";    names = ($all[0..($half-1)] -join ','); tag = "rA" },
  @{ src = "all_originals.blend";    names = ($all[$half..($all.Count-1)] -join ','); tag = "rB" }
)
for ($i = 0; $i -lt $jobs.Count; $i += 3) {
  $procs = @()
  foreach ($j in $jobs[$i..([Math]::Min($i+2, $jobs.Count-1))]) {
    $procs += Start-Process -FilePath $b -ArgumentList @('-b',"`"$d\$($j.src)`"",'-P',"`"$d\restyle.py`"",'--',"`"$d\rerun_$($j.tag).blend`"","`"$d\rerun\cmp.png`"",$j.names) -NoNewWindow -PassThru -RedirectStandardOutput "$d\rerun_$($j.tag).txt" -RedirectStandardError "$d\rerun_$($j.tag)_err.txt"
  }
  foreach ($q in $procs) { try { $q.PriorityClass = 'BelowNormal' } catch {} }
  foreach ($q in $procs) { $q.WaitForExit() }
  "jobs from $i done"
}
"ALL DONE"
