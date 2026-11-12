-- Animals menu (Jacob's StarterGui.Menus.PetsMenu): one card per animal on your plot, best first.
-- PICK UP = back to your backpack, SELL = asks YES / NO first, EQUIP BEST = your best animals fill the plot.
-- Opened by HUD.AnimalsButtonHUD.AnimalsButtonPanel.PetsButton (attribute OpensMenu = "PetsMenu"), which hides while the menu is open.
-- Server: ServerScriptService.EggHatching (Hatching.PetAction). Lives in StarterPlayer.StarterPlayerScripts.
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local TS = game:GetService("TweenService")
local RunService = game:GetService("RunService")
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

-- scrolling: the cards are sized by their aspect ratio, so the canvas height is set here: from the cards'
-- real on-screen top and bottom, nudging the canvas each frame until it matches (this way the kit's
-- UIScales don't matter). Checked every frame while open, because the pop-in tween and the card
-- animations change sizes over several frames.
list.AutomaticCanvasSize = Enum.AutomaticSize.None
local function fitCanvas()
	local top, bottom
	for _, c in list:GetChildren() do
		if c:IsA("GuiObject") and c.Visible then
			local y0, y1 = c.AbsolutePosition.Y, c.AbsolutePosition.Y + c.AbsoluteSize.Y
			top = top and math.min(top, y0) or y0
			bottom = bottom and math.max(bottom, y1) or y1
		end
	end
	local have = list.AbsoluteCanvasSize.Y
	if have < 1 then return end
	local need = top and (bottom - top + 12) or 0   -- the cards plus the list's top and bottom padding
	need = math.max(need, list.AbsoluteWindowSize.Y)   -- never smaller than the window
	if math.abs(need - have) > 1 then
		local cur = list.CanvasSize
		local scale = (cur.Y.Scale > 0 and cur.Y.Scale or 1) * need / have
		list.CanvasSize = UDim2.new(0, 0, scale, 0)
	end
end
RunService.Heartbeat:Connect(function()
	if menu.Enabled and panel.Visible then fitCanvas() end
end)

-- the Animals button hides while this menu is open
-- (HUD.AnimalsButtonHUD: its own copy of the side buttons' kit, so it gets the same hover effects)
local openBtn = pg:WaitForChild("HUD"):WaitForChild("AnimalsButtonHUD"):WaitForChild("AnimalsButtonPanel"):WaitForChild("PetsButton")
local function syncButton()
	if openBtn then openBtn.Visible = not (menu.Enabled and panel.Visible) end
end
menu:GetPropertyChangedSignal("Enabled"):Connect(syncButton)
panel:GetPropertyChangedSignal("Visible"):Connect(syncButton)
syncButton()

local function banner(text)
	local n = pg:FindFirstChild("HUD") and pg.HUD:FindFirstChild("NotificationsHUD")
	if text and n and n:FindFirstChild("ShowBanner") then n.ShowBanner:Fire(text) end
end

local placed = {}
local cards = {}
local animating, pending = 0, false
local render

-- "9/10" under the title: animals on your plot / how many your base holds (GameConfig.BaseSlots)
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

------------------------------------------------------------ transitions
local OUT = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
local POP = TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local CLOSE = TweenInfo.new(0.28, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
-- a card leaving: it shrinks (its height follows its width), and the cards below slide up into its place
local function removeCard(card, done)
	animating += 1
	local tw = TS:Create(card, CLOSE, {Size = UDim2.new(0, 0, card.Size.Y.Scale, card.Size.Y.Offset)})
	tw.Completed:Once(function()
		card:Destroy()
		animating -= 1
		if done then done() end
		if animating == 0 and pending then pending = false; render() end
	end)
	tw:Play()
end
-- swap two buttons for two others: the old ones squeeze shut, the new ones pop open in the same spots
local function swapButtons(old, new, full)
	for _, b in old do
		TS:Create(b, OUT, {Size = UDim2.new(0, 0, full.Y.Scale, full.Y.Offset)}):Play()
	end
	task.delay(OUT.Time, function()
		for _, b in old do b.Visible = false; b.Size = full end
		for _, b in new do
			b.Size = UDim2.new(0, 0, full.Y.Scale, full.Y.Offset)
			b.Visible = true
			TS:Create(b, POP, {Size = full}):Play()
		end
	end)
end

------------------------------------------------------------ cards
local busy = false
local function act(action, id)
	if busy then return false end
	busy = true
	local ok, good, msg = pcall(PetAction.InvokeServer, PetAction, action, id)
	busy = false
	if ok then banner(msg) end
	return ok and good
end

render = function()
	if animating > 0 then pending = true; return end
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
		local full = pick.Size
		yes.Position, no.Position = pick.Position, sell.Position
		yes.Visible, no.Visible = false, false
		local asking = false
		local function confirm(on)
			if asking == on then return end
			asking = on
			card.PetNameLabel.Text = on and ("SELL FOR $" .. G.short(G.SellValue(a.Name, a.Mutation)) .. "?") or title
			if on then swapButtons({pick, sell}, {yes, no}, full) else swapButtons({yes, no}, {pick, sell}, full) end
		end
		local gone = false
		local function leave(action)
			if gone or busy then return end
			gone = true
			task.spawn(function()
				if not act(action, a.Id) then gone = false; render() end   -- refused: put the card back as it was
			end)
			removeCard(card)
		end
		pick.Activated:Connect(function() leave("PickUp") end)
		sell.Activated:Connect(function() confirm(true) end)
		no.Activated:Connect(function() confirm(false) end)
		yes.Activated:Connect(function() leave("Sell") end)
		card.Parent = list
		table.insert(cards, card)
	end
	if empty then empty.Visible = #sorted == 0 end
	updateCount()
end

Remotes.Sync.OnClientEvent:Connect(function(d)
	if type(d) == "table" and type(d.PlacedList) == "table" then
		placed = d.PlacedList
		updateCount()
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
