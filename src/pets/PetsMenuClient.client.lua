-- Pets menu (Jacob's StarterGui.Menus.PetsMenu): one card per animal on your plot, best first.
-- PICK UP = back to your backpack, SELL = asks YES / NO first, EQUIP BEST = your best animals fill the plot.
-- Open it with any button that has the attribute OpensMenu = "PetsMenu" (HUD.SideButtonsHUD.MenuButtons).
-- Server: ServerScriptService.EggHatching (Hatching.PetAction). Lives in StarterPlayer.StarterPlayerScripts.
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local player = Players.LocalPlayer
local G = require(RS:WaitForChild("GameConfig"))
local ICONS = require(RS:WaitForChild("AnimalIcons")).Animals
local PetAction = RS:WaitForChild("Hatching"):WaitForChild("PetAction")
local Remotes = RS:WaitForChild("GameRemotes")
local pg = player:WaitForChild("PlayerGui")
local menu = pg:WaitForChild("Menus"):WaitForChild("PetsMenu")
local panel = menu:WaitForChild("PetsPanel")
local list = panel:WaitForChild("List")
local template = list:WaitForChild("PetCardTemplate")
local empty = panel:FindFirstChild("EmptyLabel")
template.Visible = false
for _, c in list:GetChildren() do if c:GetAttribute("Preview") then c:Destroy() end end   -- the editor's sample cards

local function banner(text)
	local n = pg:FindFirstChild("HUD") and pg.HUD:FindFirstChild("NotificationsHUD")
	if text and n and n:FindFirstChild("ShowBanner") then n.ShowBanner:Fire(text) end
end
local busy = false
local function act(action, id)
	if busy then return end
	busy = true
	local ok, _, msg = pcall(PetAction.InvokeServer, PetAction, action, id)
	busy = false
	if ok then banner(msg) end
end

local placed = {}
local cards = {}
-- "9/10" next to the title: animals on your plot / how many your base holds (GameConfig.BaseSlots)
local countLabel = panel:FindFirstChild("TopBar") and panel.TopBar:FindFirstChild("CountLabel")
local function myPlot() return workspace:FindFirstChild("Plots") and workspace.Plots:FindFirstChild(player:GetAttribute("Plot") or "") end
local function updateCount()
	if not countLabel then return end
	local plot = myPlot()
	countLabel.Text = #placed .. "/" .. G.BaseSlots(plot and plot:GetAttribute("Level") or 0)
end
local hooked
local function hookPlot()
	local plot = myPlot()
	if plot and plot ~= hooked then
		hooked = plot
		plot:GetAttributeChangedSignal("Level"):Connect(updateCount)
	end
	updateCount()
end
player:GetAttributeChangedSignal("Plot"):Connect(hookPlot)
task.defer(hookPlot)
local function render()
	for _, c in cards do c:Destroy() end
	table.clear(cards)
	local sorted = table.clone(placed)
	table.sort(sorted, function(a, b)
		return G.AnimalIncome(a.Name) * G.mutIncome(a.Mutation) > G.AnimalIncome(b.Name) * G.mutIncome(b.Mutation)
	end)
	for i, a in sorted do
		local card = template:Clone()
		card.Name = "Pet_" .. a.Id
		card.LayoutOrder = i
		card.Visible = true
		local title = G.mutLabel(a.Mutation, a.Name)
		card.PetNameLabel.Text = title
		local icon = ICONS[a.Name]
		if icon then card.PetIcon.Image = icon end
		local pick, sell, yes, no = card.PickUpButton, card.SellButton, card.YesButton, card.NoButton
		local function confirm(on)
			pick.Visible, sell.Visible = not on, not on
			yes.Visible, no.Visible = on, on
			card.PetNameLabel.Text = on and ("SELL FOR $" .. G.short(G.SellValue(a.Name, a.Mutation)) .. "?") or title
		end
		confirm(false)
		yes.Position, no.Position = pick.Position, sell.Position
		pick.Activated:Connect(function() act("PickUp", a.Id) end)
		sell.Activated:Connect(function() confirm(true) end)
		no.Activated:Connect(function() confirm(false) end)
		yes.Activated:Connect(function() act("Sell", a.Id) end)
		card.Parent = list
		table.insert(cards, card)
	end
	if empty then empty.Visible = #sorted == 0 end
	updateCount()
end

Remotes.Sync.OnClientEvent:Connect(function(d)
	if type(d) == "table" and type(d.PlacedList) == "table" then
		placed = d.PlacedList
		render()
	end
end)
local eb = panel:FindFirstChild("EquipBestButton")
if eb then eb.Activated:Connect(function() act("EquipBest") end) end
render()
-- the first Sync may have gone out before this script started: ask for the list once
task.spawn(function()
	for _ = 1, 10 do
		local ok, got, _, list0 = pcall(PetAction.InvokeServer, PetAction, "List")
		if ok and got and type(list0) == "table" then
			if #placed == 0 then placed = list0; render() end
			return
		end
		task.wait(1)
	end
end)
