$o = "C:\Users\ortho\ScoreOnAnimals\models\items\barbells_v2"
$p = Start-Process -FilePath "C:\Program Files\Blender Foundation\Blender 5.2\blender.exe" -ArgumentList @('-b','--factory-startup','-P',"`"$o\barbells_v2.py`"",'--',"`"$o\barbells_v2.blend`"","`"$o\unused.fbx`"","`"$o\bb.png`"") -NoNewWindow -PassThru -RedirectStandardOutput "$env:TEMP\bb_log.txt" -RedirectStandardError "$env:TEMP\bb_err.txt"
try { $p.PriorityClass = 'BelowNormal' } catch {}
$p.WaitForExit()
Get-Content "$env:TEMP\bb_log.txt" | Where-Object { $_ -match '^TIER|DONE|Traceback|Error' }
Get-Content "$env:TEMP\bb_err.txt" | Select-Object -Last 12
