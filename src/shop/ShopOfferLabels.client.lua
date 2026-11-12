-- ShopOfferLabels (pigeon-claude, 2026-11-11). StarterPlayerScripts.
-- Shows what each offer would give YOU right now:
--   the shop's cash packs (Pack10M / Pack100M cards) -> "$X Cash" from your income (GameConfig.packCash)
--   the lifting bar's three Strength buttons (BoostButton1-3) -> "+X" Strength from your barbell and level (GameConfig.packLift)
--   pack cards (the Starter Pack in the old VIPPack frame): one picture tile per thing inside
--   (ItemEgg / ItemStrength / ItemCash, each with a Caption), and "OWNED" once a one-time pack is bought
-- Egg offers show their egg's picture (ReplicatedStorage.AnimalIcons, the same pictures as the hotbar).
-- Prices and buying are HUDClient's job; this only writes labels and pictures.
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local G = require(RS:WaitForChild("GameConfig"))
local player = Players.LocalPlayer
local gui = player:WaitForChild("PlayerGui")
local content = gui:WaitForChild("Menus"):WaitForChild("ShopMenu"):WaitForChild("ShopPanel"):WaitForChild("Window")
	:WaitForChild("Backdrop"):WaitForChild("List"):WaitForChild("Content")
local energy = gui:WaitForChild("HUD"):WaitForChild("EnergyBarHUD"):WaitForChild("EnergyBarPanel")
local okIcons, ICONS = pcall(require, RS:WaitForChild("AnimalIcons", 10))
if not okIcons then ICONS = nil end

local function cardOf(name) return content:FindFirstChild(name, true) or energy:FindFirstChild(name, true) end
local function eggImage(egg) return ICONS and (ICONS.Eggs[egg] or ICONS.Eggs[G.AnimalForEgg(egg)]) end
local function caption(card, tile, text)
	local t = card:FindFirstChild(tile)
	local c = t and t:FindFirstChild("Caption")
	if c then c.Text = text end
end

local function render()
	local cps = player:GetAttribute("CashPerSec") or 0
	local function lift(pr)
		return G.packLift(pr, player:GetAttribute("LiftLevel") or 1, player:GetAttribute("LiftXP") or 0, player:GetAttribute("BarbellLevel") or 1, player:GetAttribute("Strength") or 0)
	end
	for name, item in G.ShopItems do
		local pr = item.Product and G.Products[item.Product]
		local card = pr and cardOf(name)
		if card then
			local amount = card:FindFirstChild("AmountLabel")
			if amount and pr.CashMinutes then amount.Text = "$" .. G.short(G.packCash(pr, cps)) .. " Cash"
			elseif amount and pr.LiftMinutes then amount.Text = "+" .. G.short(lift(pr)) end
			-- a pack card: one tile per thing inside
			if card:FindFirstChild("ItemEgg") or card:FindFirstChild("ItemStrength") or card:FindFirstChild("ItemCash") then
				if pr.Egg then caption(card, "ItemEgg", pr.EggLabel or "EGG") end
				if pr.LiftMinutes then caption(card, "ItemStrength", "+" .. G.short(lift(pr))) end
				if pr.CashMinutes then caption(card, "ItemCash", "$" .. G.short(G.packCash(pr, cps))) end
			end
			-- a bought one-time pack: the buy button's own OwnedLabel (made in StarterGui) replaces the price
			local buy = pr.OnePer and card:FindFirstChild("BuyButton")
			local ownedLabel = buy and buy:FindFirstChild("OwnedLabel")
			if ownedLabel then
				local owned = player:GetAttribute("Bought_" .. item.Product) == true
				ownedLabel.Visible = owned
				for _, n in {"PriceLabel", "RobuxIcon"} do
					local c = buy:FindFirstChild(n)
					if c then c.Visible = not owned end
				end
			end
		end
	end
end

-- pictures: egg offers and pack tiles
for name, item in G.ShopItems do
	local pr = item.Product and G.Products[item.Product]
	local card = pr and pr.Egg and content:FindFirstChild(name, true)
	if card then
		local frame = card:FindFirstChild("ItemEgg") or card:FindFirstChild("IconFrame")
		local icon = frame and frame:FindFirstChild("Icon")
		local image = icon and eggImage(pr.Egg)
		if image then icon.Image = image end
	end
	local perks = pr and pr.Perks and content:FindFirstChild(name, true)
	perks = perks and perks:FindFirstChild("PerksLabel")
	if perks then perks.Text = pr.Perks end
end

-- labels tagged SelfSized in StarterGui (prices and texts the scripts rewrite) fill their box. A Studio tool resets
-- TextScaled on Framewisp menus in edit, so it's switched on here; the kit's TextScaler leaves untagged labels alone.
-- Their outlines follow the text too (pigeon: in the real game the text got "a big stroke around it", worse on a
-- small window). These labels left the kit's stroke scaling, so a fixed pixel outline swallowed small text.
-- Now the outline is a share of the drawn text's height, the same share the kit's own labels use.
local STROKE = 0.09
local function fitStroke(l)
	local h = l.TextBounds.Y
	if h <= 0 then return end
	for _, st in l:GetChildren() do
		if st:IsA("UIStroke") and st.ApplyStrokeMode == Enum.ApplyStrokeMode.Contextual then
			-- pixels, not "ScaledSize" (there a Thickness of 1 = the label's whole size: the black pills)
			st.StrokeSizingMode = Enum.StrokeSizingMode.FixedSize
			st.Thickness = math.max(1, h * STROKE)
		end
	end
end
local function selfSize(l)
	if l:IsA("TextLabel") and l:GetAttribute("StrokeFit") and not l:GetAttribute("SelfSized") then   -- outline only
		l:GetPropertyChangedSignal("TextBounds"):Connect(function() fitStroke(l) end)
		fitStroke(l)
		return
	end
	if not (l:IsA("TextLabel") and l:GetAttribute("SelfSized")) then return end
	l.TextScaled = true
	l:GetPropertyChangedSignal("TextScaled"):Connect(function() if not l.TextScaled then l.TextScaled = true end end)
	l:GetPropertyChangedSignal("TextBounds"):Connect(function() fitStroke(l) end)
	l.ChildAdded:Connect(function() task.defer(fitStroke, l) end)
	fitStroke(l)
end
for _, d in gui:GetDescendants() do selfSize(d) end
gui.DescendantAdded:Connect(selfSize)

local queued = false
local function soon()      -- LiftXP changes every rep: redraw at most twice a second
	if queued then return end
	queued = true
	task.delay(0.5, function() queued = false; render() end)
end
for _, a in {"CashPerSec", "LiftLevel", "LiftXP", "BarbellLevel", "Strength"} do
	player:GetAttributeChangedSignal(a):Connect(soon)
end
for key, pr in G.Products do
	if pr.OnePer then player:GetAttributeChangedSignal("Bought_" .. key):Connect(soon) end
end
render()
task.delay(3, render)   -- after HUDClient has written the prices
