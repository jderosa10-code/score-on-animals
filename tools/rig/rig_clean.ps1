# Re-rig the 11 animals whose skin stretched when they walk, with clean weights (RIG_CLEAN=1):
# each vertex keeps only its main bone + that bone's parent/children. One Rig_<Name>.fbx each in rig\batch3.
$rig = "C:\Users\ortho\OneDrive\Desktop\New folder (2)\roblox_pets\rig"
$v = "C:\Users\ortho\OneDrive\Desktop\New folder (2)\roblox_pets\variants"
$b = "C:\Program Files\Blender Foundation\Blender 5.2\blender.exe"
New-Item -ItemType Directory -Force "$rig\batch3", "$rig\batch3_reports" | Out-Null
$jobs = @(
  @{ blend = "$v\round3\r3_rA.blend"; names = "Cerberus,Griffin,Harpy" },
  @{ blend = "$v\round3\r3_rB.blend"; names = "Tortoise,Simurgh,Tiger,Minotaur" },
  @{ blend = "$v\round3\r3_r3a.blend"; names = "Jackalope" },
  @{ blend = "$v\round3\r3_r2.blend"; names = "Tanuki" },
  @{ blend = "$v\cmp\..\round3\last4.blend"; names = "Microraptor,Archaeopteryx" }
)
$env:RIG_SPLIT = "$rig\batch3"
$env:RIG_CLEAN = "1"
$running = @()
$i = 0
foreach ($jb in $jobs) {
  $i++
  $p = Start-Process -FilePath $b -ArgumentList @('-b',"`"$($jb.blend)`"",'-P',"`"$rig\rig_build.py`"",'--',"`"$rig\studio_dump\bones.json`"",$jb.names,"`"$rig\batch3_reports\x.fbx`"","`"$rig\batch3_reports\job$i.json`"") -NoNewWindow -PassThru -RedirectStandardOutput "$rig\batch3_reports\job$i.txt" -RedirectStandardError "$rig\batch3_reports\job$i`_err.txt"
  try { $p.PriorityClass = 'BelowNormal' } catch {}
  $running += $p
}
foreach ($p in $running) { $p.WaitForExit() }
$env:RIG_SPLIT = $null; $env:RIG_CLEAN = $null
Get-ChildItem "$rig\batch3" -Filter "Rig_*.fbx" | Select-Object Name, Length | Format-Table -AutoSize | Out-String
Get-ChildItem "$rig\batch3_reports" -Filter "job*.txt" | Where-Object { $_.Name -notmatch '_err' } | ForEach-Object { Get-Content $_.FullName } | Where-Object { $_ -match '^RIG |SPLIT DONE|Traceback|Error' }
Get-ChildItem "$rig\batch3_reports" -Filter "*_err.txt" | ForEach-Object { Get-Content $_.FullName } | Where-Object { $_ -match 'Error|Traceback' } | Select-Object -First 6
"ALL DONE"
