# Talk to Roblox's StudioMCP.exe directly over stdio (JSON-RPC), for sessions where its tools didn't load.
#   studio_mcp.ps1 -List                      -> tool names
#   studio_mcp.ps1 -Tool <name> -ArgsJson '{...}'   -> calls the tool (after picking the Studio with the place open)
param([switch]$List, [string]$Tool, [string]$ArgsJson = "{}", [string]$ArgsFile, [int]$WaitSec = 120)
if ($ArgsFile) { $ArgsJson = Get-Content $ArgsFile -Raw }
$ErrorActionPreference = "Stop"
$exe = Get-ChildItem "$env:LOCALAPPDATA\Roblox\Versions\*\StudioMCP.exe" | Sort-Object LastWriteTime -Descending | Select-Object -First 1
$psi = New-Object System.Diagnostics.ProcessStartInfo
$psi.FileName = $exe.FullName
$psi.UseShellExecute = $false
$psi.RedirectStandardInput = $true; $psi.RedirectStandardOutput = $true; $psi.RedirectStandardError = $true
$psi.StandardOutputEncoding = [Text.Encoding]::UTF8
$p = [System.Diagnostics.Process]::Start($psi)
$script:id = 0
function Send($method, $params, [switch]$Note) {
  $msg = @{ jsonrpc = "2.0"; method = $method }
  if ($params) { $msg.params = $params }
  if (-not $Note) { $script:id++; $msg.id = $script:id }
  $p.StandardInput.WriteLine(($msg | ConvertTo-Json -Depth 20 -Compress)); $p.StandardInput.Flush()
  if ($Note) { return $null }
  $want = $script:id
  $deadline = (Get-Date).AddSeconds($WaitSec)
  while ((Get-Date) -lt $deadline) {
    $t = $p.StandardOutput.ReadLineAsync()
    if (-not $t.Wait(([int]($deadline - (Get-Date)).TotalMilliseconds) + 1)) { break }
    $line = $t.Result
    if (-not $line) { continue }
    try { $r = $line | ConvertFrom-Json } catch { continue }
    if ($r.id -eq $want) { return $r }
  }
  throw "no reply to $method"
}
try {
  $null = Send "initialize" @{ protocolVersion = "2025-06-18"; capabilities = @{}; clientInfo = @{ name = "claude-code-bridge"; version = "1.0" } }
  $null = Send "notifications/initialized" $null -Note
  Start-Sleep -Seconds 3                                  # let it find the running Studio
  $tools = (Send "tools/list" @{}).result.tools
  if ($List) { "tools: " + $tools.Count; $tools | ForEach-Object { $_.name }; return }
  if ($env:MCP_SCHEMA) { $tools | Where-Object { $env:MCP_SCHEMA -split "," -contains $_.name } | ForEach-Object { $_.name; $_.description.Substring(0,[Math]::Min(300,$_.description.Length)); ($_.inputSchema | ConvertTo-Json -Depth 8 -Compress) }; return }
  # pick the Studio that has a place open
  $studios = (Send "tools/call" @{ name = "list_roblox_studios"; arguments = @{} }).result.content[0].text
  "studios: $studios"
  $sid = (($studios | ConvertFrom-Json).studios | Select-Object -First 1).id
  if ($Tool) {
    $a = $ArgsJson | ConvertFrom-Json
    $h = @{}; $a.PSObject.Properties | ForEach-Object { $h[$_.Name] = $_.Value }
    if (-not $h.ContainsKey("studio_id")) { $h.studio_id = $sid }
    $res = Send "tools/call" @{ name = $Tool; arguments = $h }
    $res.result.content | ForEach-Object { $_.text }
    if ($res.error) { "ERROR: " + ($res.error | ConvertTo-Json -Compress) }
  }
} finally {
  try { $p.StandardInput.Close(); if (-not $p.WaitForExit(2000)) { $p.Kill() } } catch {}
}

