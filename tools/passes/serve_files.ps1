# Localhost-only file server with real content types (png/json/lua/txt), for Studio's upload_image and HttpService.
# Stops by itself after $Minutes.
param([string]$Dir, [int]$Port = 34880, [int]$Minutes = 20)
$types = @{ ".png" = "image/png"; ".jpg" = "image/jpeg"; ".json" = "application/json"; ".lua" = "text/plain"; ".txt" = "text/plain" }
$l = New-Object System.Net.HttpListener
$l.Prefixes.Add("http://localhost:$Port/")
$l.Start()
"listening on $Port serving $Dir"
$deadline = (Get-Date).AddMinutes($Minutes)
while ((Get-Date) -lt $deadline) {
    $task = $l.GetContextAsync()
    while (-not $task.Wait(1000)) { if ((Get-Date) -ge $deadline) { break } }
    if (-not $task.IsCompleted) { break }
    $ctx = $task.Result
    $name = [Uri]::UnescapeDataString([System.IO.Path]::GetFileName($ctx.Request.Url.AbsolutePath))
    $path = Join-Path $Dir $name
    if ($name -and (Test-Path $path)) {
        $bytes = [System.IO.File]::ReadAllBytes($path)
        $ext = [System.IO.Path]::GetExtension($name).ToLower()
        $ctx.Response.ContentType = $(if ($types[$ext]) { $types[$ext] } else { "application/octet-stream" })
        $ctx.Response.ContentLength64 = $bytes.Length
        $ctx.Response.OutputStream.Write($bytes, 0, $bytes.Length)
        "served $name"
    } else { $ctx.Response.StatusCode = 404; "404 $name" }
    $ctx.Response.Close()
}
$l.Stop()
"stopped"
