-- ShopOfferLabels (pigeon-claude, 2026-11-11). StarterPlayerScripts.
-- The packs that scale with the player show what they'd give YOU right now:
--   the shop's cash packs (Pack10M / Pack100M cards) -> "$X Cash" from your income (GameConfig.packCash)
--   the lifting bar's three Strength buttons (BoostButton1-3) -> "+X" Strength from your barbell and level (GameConfig.packLift)
-- Prices and buying are HUDClient's job; this only writes the amount labels.
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local G = require(RS:WaitForChild("GameConfig"))
local player = Players.LocalPlayer
local gui = player:WaitForChild("PlayerGui")
local content = gui:WaitForChild("Menus"):WaitForChild("ShopMenu"):WaitForChild("ShopPanel"):WaitForChild("Window")
	:WaitForChild("Backdrop"):WaitForChild("List"):WaitForChild("Content")
local energy = gui:WaitForChild("HUD"):WaitForChild("EnergyBarHUD"):WaitForChild("EnergyBarPanel")

local function amountLabel(name)
	local f = content:FindFirstChild(name, true) or energy:FindFirstChild(name, true)
	return f and f:FindFirstChild("AmountLabel")
end

local function render()
	for name, item in G.ShopItems do
		local pr = item.Product and G.Products[item.Product]
		if pr and (pr.CashMinutes or pr.LiftMinutes) then
			local l = amountLabel(name)
			if l then
				if pr.CashMinutes then
					l.Text = "$" .. G.short(G.packCash(pr, player:GetAttribute("CashPerSec") or 0)) .. " Cash"
				else
					local gain = G.packLift(pr, player:GetAttribute("LiftLevel") or 1, player:GetAttribute("LiftXP") or 0, player:GetAttribute("BarbellLevel") or 1, player:GetAttribute("Strength") or 0)
					l.Text = "+" .. G.short(gain)
				end
			end
		end
	end
end

-- egg offers show their egg's picture (ReplicatedStorage.AnimalIcons, the same pictures as the hotbar and backpack)
local okIcons, ICONS = pcall(require, RS:WaitForChild("AnimalIcons", 10))
if okIcons and ICONS then
	for name, item in G.ShopItems do
		local pr = item.Product and G.Products[item.Product]
		local card = pr and pr.Egg and content:FindFirstChild(name, true)
		local icon = card and card:FindFirstChild("IconFrame") and card.IconFrame:FindFirstChild("Icon")
		local image = icon and (ICONS.Eggs[pr.Egg] or ICONS.Eggs[G.AnimalForEgg(pr.Egg)])
		if image then icon.Image = image end
	end
end

local queued = false
local function soon()      -- LiftXP changes every rep: redraw at most twice a second
	if queued then return end
	queued = true
	task.delay(0.5, function() queued = false; render() end)
end
for _, a in {"CashPerSec", "LiftLevel", "LiftXP", "BarbellLevel"} do
	player:GetAttributeChangedSignal(a):Connect(soon)
end
render()
