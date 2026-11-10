# Tiny localhost-only file server so Studio can fetch the exported animal JSON.
# Stops by itself after 20 minutes.
param([string]$Dir, [int]$Port = 34873)
$l = New-Object System.Net.HttpListener
$l.Prefixes.Add("http://localhost:$Port/")
$l.Start()
"listening on $Port serving $Dir"
$deadline = (Get-Date).AddMinutes(20)
while ((Get-Date) -lt $deadline) {
    $task = $l.GetContextAsync()
    while (-not $task.Wait(1000)) { if ((Get-Date) -ge $deadline) { break } }
    if (-not $task.IsCompleted) { break }
    $ctx = $task.Result
    $name = [System.IO.Path]::GetFileName($ctx.Request.Url.AbsolutePath)
    $path = Join-Path $Dir $name
    if ($name -and (Test-Path $path)) {
        $bytes = [System.IO.File]::ReadAllBytes($path)
        $ctx.Response.ContentType = "application/json"
        $ctx.Response.ContentLength64 = $bytes.Length
        $ctx.Response.OutputStream.Write($bytes, 0, $bytes.Length)
        "served $name"
    } else {
        $ctx.Response.StatusCode = 404
        "404 $name"
    }
    $ctx.Response.Close()
}
$l.Stop()
"stopped"
