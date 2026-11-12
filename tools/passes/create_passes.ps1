# Create the new Score for Animals game passes + their gift developer products via Open Cloud (through the
# Studio MCP bridge). Writes passes_ids.json. Usage: create_passes.ps1 [-Only FastHatch]
param([string]$Only)
$br = "C:\Users\ortho\OneDrive\Desktop\New folder (2)\roblox_pets\rig\studio_mcp.ps1"
$U = 10775616643
$img = "C:/Users/ortho/OneDrive/Desktop/ROBLOX IMPORT/passes"
$tmp = "$env:TEMP\create_pass_req.json"
$idsFile = "C:\Users\ortho\OneDrive\Desktop\New folder (2)\roblox_pets\passes\passes_ids.json"
$passes = @(
  @{ Key = "FastHatch";      Name = "Fast Hatch";        Price = 199; Sale = $true;  Desc = "Your eggs hatch 2x faster, forever." },
  @{ Key = "PenSlots";       Name = "+5 Pen Slots";      Price = 199; Sale = $true;  Desc = "Place 5 more animals in your pen, forever." },
  @{ Key = "Hatcheries3";    Name = "+3 Hatcheries";     Price = 149; Sale = $false; Desc = "3 more hatcheries on your plot, so you can hatch more eggs at once." },
  @{ Key = "Strength2x";     Name = "2x Strength";       Price = 249; Sale = $true;  Desc = "Double the Strength you get from lifting, forever." },
  @{ Key = "SuperLuck";      Name = "Super Luck";        Price = 499; Sale = $true;  Desc = "3x egg luck, forever. Stacks with 2x Luck." },
  @{ Key = "MutationHunter"; Name = "Mutation Hunter";   Price = 299; Sale = $true;  Desc = "Double the chance of Gold, Diamond, Rainbow and Hacked eggs." },
  @{ Key = "GreenZone";      Name = "Bigger Green Zone"; Price = 149; Sale = $true;  Desc = "A bigger green aim zone on every penalty kick, for easier perfect kicks." },
  @{ Key = "LongOffline";    Name = "Long Offline";      Price = 149; Sale = $true;  Desc = "Your animals keep earning for 24 hours while you're away, at full rate." }
)
$ids = @{}
if (Test-Path $idsFile) { (Get-Content $idsFile -Raw | ConvertFrom-Json).PSObject.Properties | ForEach-Object { $ids[$_.Name] = $_.Value } }
function Call($endpoint, $scope, $fields, $file) {
  $req = @{ method = "POST"; endpoint = $endpoint; scopes = @($scope); body = ($fields | ConvertTo-Json -Compress)
    files = @(@{ name = "imageFile"; path = $file; contentType = "image/png" }) } | ConvertTo-Json -Depth 5
  [IO.File]::WriteAllText($tmp, $req)
  return (& $br -Tool open_cloud_invoke -ArgsFile $tmp 2>&1 | Out-String)
}
foreach ($p in $passes) {
  if ($Only -and $p.Key -ne $Only) { continue }
  $k = $p.Key
  if (-not $ids[$k]) { $ids[$k] = @{} } elseif ($ids[$k] -isnot [hashtable]) { $h = @{}; $ids[$k].PSObject.Properties | ForEach-Object { $h[$_.Name] = $_.Value }; $ids[$k] = $h }
  $file = "$img/$k.png"
  if (-not $ids[$k].Id) {
    $r = Call "/game-passes/v1/universes/$U/game-passes" "game-pass:write" @{ name = $p.Name; description = $p.Desc; price = "$($p.Price)"; isForSale = "$($p.Sale)".ToLower() } $file
    $id = [regex]::Match($r, '"gamePassId"\s*:\s*"?(\d+)').Groups[1].Value
    if (-not $id) { $id = [regex]::Match($r, '"id"\s*:\s*"?(\d+)').Groups[1].Value }
    if ($id) { $ids[$k].Id = [int64]$id; "$k pass $id" } else { "$k PASS FAILED: " + $r.Substring(0, [Math]::Min(500, $r.Length)) }
  }
  if (-not $ids[$k].GiftId) {
    $r = Call "/developer-products/v2/universes/$U/developer-products" "developer-product:write" @{ name = "Gift: " + $p.Name; description = "Gift " + $p.Name + " to another player."; price = "$($p.Price)"; isForSale = "true" } $file
    $id = [regex]::Match($r, '"productId"\s*:\s*"?(\d+)').Groups[1].Value
    if (-not $id) { $id = [regex]::Match($r, '"id"\s*:\s*"?(\d+)').Groups[1].Value }
    if ($id) { $ids[$k].GiftId = [int64]$id; "$k gift $id" } else { "$k GIFT FAILED: " + $r.Substring(0, [Math]::Min(500, $r.Length)) }
  }
  $ids[$k].Price = $p.Price
  $ids | ConvertTo-Json -Depth 4 | Set-Content $idsFile -Encoding utf8
}
