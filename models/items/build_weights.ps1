# Build the weight tiers in background Blender (low priority) and write renders + FBX.
$o = "C:\Users\ortho\ScoreOnAnimals\models\items"
$p = Start-Process -FilePath "C:\Program Files\Blender Foundation\Blender 5.2\blender.exe" -ArgumentList @('-b','--factory-startup','-P',"`"$o\weights_vox.py`"",'--',"`"$o\weights_vox.blend`"","`"$o\Weights.fbx`"","`"$o\wv.png`"") -NoNewWindow -PassThru -RedirectStandardOutput "$env:TEMP\w_log.txt" -RedirectStandardError "$env:TEMP\w_err.txt"
try { $p.PriorityClass = 'BelowNormal' } catch {}
$p.WaitForExit()
Get-Content "$env:TEMP\w_log.txt" | Where-Object { $_ -match '^TIER|DONE|Traceback' }
Get-Content "$env:TEMP\w_err.txt" | Where-Object { $_ -match 'Error|Traceback|line \d' } | Select-Object -First 8
