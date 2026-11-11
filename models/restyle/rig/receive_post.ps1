# Tiny local receiver: Studio POSTs text to http://localhost:<Port>/<name> and it is saved as <Dir>\<name>.
# Stops by itself after $Minutes. Only listens on localhost.
param([string]$Dir, [int]$Port = 35041, [int]$Minutes = 20)
New-Item -ItemType Directory -Force $Dir | Out-Null
$l = New-Object System.Net.HttpListener
$l.Prefixes.Add("http://localhost:$Port/")
$l.Start()
"listening on $Port, saving to $Dir"
$end = (Get-Date).AddMinutes($Minutes)
while ((Get-Date) -lt $end) {
  $t = $l.GetContextAsync()
  while (-not $t.Wait(500)) { if ((Get-Date) -ge $end) { break } }
  if (-not $t.IsCompleted) { break }
  $c = $t.Result
  $name = [IO.Path]::GetFileName($c.Request.Url.AbsolutePath)
  if (-not $name) { $name = "post.txt" }
  $r = New-Object IO.StreamReader($c.Request.InputStream, [Text.Encoding]::UTF8)
  $body = $r.ReadToEnd(); $r.Close()
  [IO.File]::WriteAllText((Join-Path $Dir $name), $body, (New-Object System.Text.UTF8Encoding $false))
  "saved $name ($($body.Length) chars)"
  $b = [Text.Encoding]::UTF8.GetBytes("ok")
  $c.Response.OutputStream.Write($b, 0, $b.Length); $c.Response.Close()
}
$l.Stop()
"stopped"
