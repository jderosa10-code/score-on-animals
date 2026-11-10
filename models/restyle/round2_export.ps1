# ROUND 2 export: merge the small job files into the rA file, then write two FBX files for Studio
# (same layout and part names as round 1: <Pack>_NEW_Body / _Eyes, 30 studs apart, axis markers).
#   Restyle_R2_A.fbx = jobs r5 + r2 + r3a + r3b + rA      Restyle_R2_B.fbx = job rB
# One Blender at a time, low priority.
$d = "C:\Users\ortho\OneDrive\Desktop\New folder (2)\roblox_pets\variants"
$b = "C:\Program Files\Blender Foundation\Blender 5.2\blender.exe"
function Run($argList, $log) {
  $p = Start-Process -FilePath $b -ArgumentList $argList -NoNewWindow -PassThru -RedirectStandardOutput "$d\round2\$log.txt" -RedirectStandardError "$d\round2\${log}_err.txt"
  try { $p.PriorityClass = 'BelowNormal' } catch {}
  $p.WaitForExit()
  Get-Content "$d\round2\${log}_err.txt" | Where-Object { $_ -match 'Error|Traceback|line \d' } | Select-Object -First 4
}
$all = ((Get-Content "$d\remaining_map.txt" -Raw).Trim() -split ',') | ForEach-Object { ($_ -split '=')[1] } | Select-Object -Unique
$half = [Math]::Ceiling($all.Count / 2)
$sets = [ordered]@{
  r5  = "Corgi1,Toad1,Hedgehog1,Giraffe1,Polarbear1"
  r2  = (Get-Content "$d\batch2_keep.txt").Trim()
  r3a = "Tapirv21,Porcupine1,Platypus1,Binturong1,Jackalope1,Raiju1,Chupacabra1,Australiancattledog11,Bichonfrise11,Cavalierkingcharlesspaniel1,Iguana1,Komododragon1,Kappa1,Toucan1,Muscovyduck1,Kookaburra1,Shoebill1"
  r3b = "Gecko1,Newt1,Chameleon1,Raven1,Ladybug1,Beetle1,Giantisopod1,Qilin1,Yiqi1"
}
$namesA = ($all[0..($half-1)] -join ',')
$namesB = ($all[$half..($all.Count-1)] -join ',')
$cur = "$d\round2\r2_rA.blend"
foreach ($k in $sets.Keys) {
  $out = "$d\round2\merge_$k.blend"
  Run @('-b',"`"$cur`"",'-P',"`"$d\merge_into.py`"",'--',"`"$d\round2\r2_$k.blend`"",$sets[$k],"`"$out`"") "merge_$k"
  "merged $k : $((Select-String -Path "$d\round2\merge_$k.txt" -Pattern '^APPENDED').Count) objects"
  $cur = $out
  $namesA = $namesA + ',' + $sets[$k]
}
Run @('-b',"`"$cur`"",'-P',"`"$d\export_fbx.py`"",'--',"`"$d\fbx`"",$namesA,'Restyle_R2_A.fbx') "export_A"
Run @('-b',"`"$d\round2\r2_rB.blend`"",'-P',"`"$d\export_fbx.py`"",'--',"`"$d\fbx`"",$namesB,'Restyle_R2_B.fbx') "export_B"
foreach ($x in "A","B") { "{0}: {1} animals | {2}" -f $x, (Select-String -Path "$d\round2\export_$x.txt" -Pattern '^ANIMAL').Count, ((Select-String -Path "$d\round2\export_$x.txt" -Pattern '^FBX').Line) }
Get-ChildItem "$d\fbx" -Filter "Restyle_R2_*.fbx" | ForEach-Object { Copy-Item $_.FullName "$d\$($_.Name)" -Force; "{0}  {1:N1} MB" -f $_.Name, ($_.Length / 1MB) }
"EXPORT DONE"
