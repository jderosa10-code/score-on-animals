# Serves files from a folder over http://localhost:<Port>/<name> for a few minutes (Studio pulls scripts with HttpService).
param([string]$Dir, [int]$Port = 35111, [int]$Minutes = 5)
$l = New-Object System.Net.HttpListener
$l.Prefixes.Add("http://localhost:$Port/")
$l.Start()
"serving $Dir on $Port"
$end = (Get-Date).AddMinutes($Minutes)
while ((Get-Date) -lt $end) {
  $t = $l.GetContextAsync()
  while (-not $t.Wait(500)) { if ((Get-Date) -ge $end) { break } }
  if (-not $t.IsCompleted) { break }
  $c = $t.Result
  $f = Join-Path $Dir ([IO.Path]::GetFileName($c.Request.Url.AbsolutePath))
  if (Test-Path $f) { $b = [IO.File]::ReadAllBytes($f); $c.Response.StatusCode = 200 } else { $b = [Text.Encoding]::UTF8.GetBytes("missing"); $c.Response.StatusCode = 404 }
  $c.Response.OutputStream.Write($b, 0, $b.Length); $c.Response.Close()
}
$l.Stop()
