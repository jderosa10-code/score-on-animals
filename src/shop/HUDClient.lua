-- Hooks Jacob's UI kit (StarterGui.HUD / Menus / Popups) up to the game. Only sets text, images and
-- the kit's own attributes; the layout is untouched. Server side: ServerScriptService.GameServer / GameData.
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local UIS = game:GetService("UserInputService")
local StarterGui = game:GetService("StarterGui")
local MPS = game:GetService("MarketplaceService")
local player = Players.LocalPlayer
local G = require(RS:WaitForChild("GameConfig"))
local EggRoll = require(RS:WaitForChild("DevDemo"):WaitForChild("EggRoll"))
local Remotes = RS:WaitForChild("GameRemotes")
local pg = player:WaitForChild("PlayerGui")
local hud = pg:WaitForChild("HUD")
local menus = pg:WaitForChild("Menus")
local popups = pg:WaitForChild("Popups")
local side = hud:WaitForChild("SideButtonsHUD")
local KIT_FONT = Font.new("rbxasset://fonts/families/LuckiestGuy.json")

local notificationsOn = true
local function banner(text)
	if not notificationsOn then return end
	local n = hud:FindFirstChild("NotificationsHUD")
	if n and n:FindFirstChild("ShowBanner") then n.ShowBanner:Fire(text) end
end
Remotes.Notify.OnClientEvent:Connect(banner)
local function act(...)
	local ok, a, b = pcall(Remotes.Action.InvokeServer, Remotes.Action, ...)
	if ok and b then banner(b) end
	return ok and a
end
local function openMenu(name) side:WaitForChild("OpenMenu"):Fire(name) end

-- our own hotbar replaces Roblox's backpack bar
task.spawn(function()
	for _ = 1, 20 do
		if pcall(StarterGui.SetCoreGuiEnabled, StarterGui, Enum.CoreGuiType.Backpack, false) then break end
		task.wait(0.5)
	end
end)

local data = {Items = {}, Index = {}, IndexClaimed = {}, Daily = {Streak = 0, Ready = false, NextIn = 0}, Rebirths = 0, Placed = 0}
local listeners = {}
local function onData(fn) table.insert(listeners, fn) end
local function refreshAll() for _, fn in listeners do task.spawn(fn) end end
Remotes.Sync.OnClientEvent:Connect(function(d) data = d; refreshAll() end)
-- the penalty asks this to show NEW! on an egg whose animal you haven't found yet
_G.SOA_IndexFound = function(animal) return data.Index ~= nil and data.Index[animal] ~= nil and data.Index[animal] ~= false end
local function onAttr(names, fn)
	for _, n in names do player:GetAttributeChangedSignal(n):Connect(fn) end
	onData(fn)
end

------------------------------------------------------------ currency
do
	local stats = hud:WaitForChild("CurrencyHUD"):WaitForChild("CurrencyPanel"):WaitForChild("Stats")
	local cash, plus = stats.CashLabel, stats.AddCashButton
	-- the + button sits right after the last digit, however long the number gets
	local function placePlus()
		local sw = stats.AbsoluteSize.X
		if sw < 1 or cash.AbsoluteSize.X < 1 then return end
		local k = cash.AbsoluteSize.X / math.max(1, cash.Size.X.Scale * sw)   -- the label's own UIScale, if any
		local textEnd = cash.AbsolutePosition.X + cash.TextBounds.X * k
		local x = textEnd + plus.AbsoluteSize.X * 0.75 - stats.AbsolutePosition.X
		plus.Position = UDim2.new(x / sw, 0, plus.Position.Y.Scale, plus.Position.Y.Offset)
	end
	local function render()
		cash.Text = "$" .. G.commas(player:GetAttribute("Cash") or 0)
		local fb = stats:FindFirstChild("FriendBoostLabel")   -- Jacob swapped this for StrengthLable; kept in case it comes back
		if fb then fb.Text = "Friends: +" .. math.floor((player:GetAttribute("FriendBonus") or 0) * 100 + 0.5) .. "%" end
		task.defer(placePlus)
	end
	onAttr({"Cash", "FriendBonus", "Strength"}, render)
	local str = stats:FindFirstChild("StrengthLable")
	local function renderStrength() if str then str.Text = "Strength: " .. G.short(player:GetAttribute("Strength") or 0) end end
	player:GetAttributeChangedSignal("Strength"):Connect(renderStrength)
	renderStrength()
	cash:GetPropertyChangedSignal("TextBounds"):Connect(placePlus)
	cash:GetPropertyChangedSignal("AbsoluteSize"):Connect(placePlus)
	render()
	-- + opens the shop scrolled down to the cash packs
	stats.AddCashButton.Activated:Connect(function()
		openMenu("ShopMenu")
		task.delay(0.3, function()
			local list = menus.ShopMenu.ShopPanel.Window.Backdrop.List
			local packs = list:FindFirstChild("CashPacks", true)
			if not packs then return end
			local scale, o = 1, list
			while o and o ~= pg do
				local sc = o:FindFirstChildOfClass("UIScale")
				if sc then scale *= sc.Scale end
				o = o.Parent
			end
			local y = list.CanvasPosition.Y + (packs.AbsolutePosition.Y - list.AbsolutePosition.Y) / math.max(scale, 0.01)
			game:GetService("TweenService"):Create(list, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
				{CanvasPosition = Vector2.new(0, math.max(0, y))}):Play()
		end)
	end)
end

------------------------------------------------------------ items: hotbar + backpack
local function toolFor(id)
	for _, where in {player:FindFirstChildOfClass("Backpack"), player.Character} do
		if where then
			for _, t in where:GetChildren() do
				if t:IsA("Tool") and t:GetAttribute("ItemId") == id then return t end
			end
		end
	end
end
local function itemText(item) return G.mutLabel(item.Mutation, item.Type == "Egg" and item.Name .. " Egg" or item.Name) end
local function toggleItem(item)
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local t = item and toolFor(item.Id)
	if not (hum and t) then return end
	if t.Parent == char then hum:UnequipTools() else hum:EquipTool(t) end
end
-- item icons (Jacob): ReplicatedStorage.AnimalIcons.Eggs / .Animals. Each slot gets an ItemIcon image;
-- the name text only shows for an item that has no icon yet.
local ICON_SETS = require(RS:WaitForChild("AnimalIcons"))
local function itemIcon(item)
	if not item then return nil end
	if item.Type == "Egg" then return ICON_SETS.Eggs[item.Name] or ICON_SETS.Eggs[G.AnimalForEgg(item.Name)] end
	return ICON_SETS.Animals[item.Name]
end
-- mutated items reuse the normal icon, tinted (Jacob: real photos later). Rainbow gets a moving rainbow gradient.
-- light tints (ImageColor3 multiplies, so dark tints made the icons muddy)
local TINT = {Gold = Color3.fromRGB(255, 232, 150), Diamond = Color3.fromRGB(200, 240, 255),
	Inverted = Color3.fromRGB(225, 225, 235), Hacked = Color3.fromRGB(175, 255, 180)}
local RAINBOW = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 170, 170)), ColorSequenceKeypoint.new(0.2, Color3.fromRGB(255, 235, 160)),
	ColorSequenceKeypoint.new(0.4, Color3.fromRGB(190, 255, 180)), ColorSequenceKeypoint.new(0.6, Color3.fromRGB(175, 230, 255)),
	ColorSequenceKeypoint.new(0.8, Color3.fromRGB(215, 185, 255)), ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 170, 170))})
local rainbowGrads = setmetatable({}, {__mode = "k"})
task.spawn(function()
	while true do
		local r = (os.clock() * 60) % 360
		for g in rainbowGrads do if g.Parent then g.Rotation = r end end
		task.wait(1 / 20)
	end
end)
local function tintIcon(img, mut)
	img.ImageColor3 = TINT[mut] or Color3.new(1, 1, 1)
	local g = img:FindFirstChild("RainbowTint")
	if mut == "Rainbow" then
		if not g then
			g = Instance.new("UIGradient"); g.Name = "RainbowTint"; g.Color = RAINBOW; g.Parent = img
			rainbowGrads[g] = true
		end
		g.Enabled = true
	elseif g then
		g.Enabled = false
	end
end
local function setSlotItem(slot, item, cx, cy)
	local img = slot:FindFirstChild("ItemIcon")
	if not img then
		img = Instance.new("ImageLabel")
		img.Name = "ItemIcon"
		img.BackgroundTransparency = 1
		img.AnchorPoint = Vector2.new(0.5, 0.5)
		img.Position = UDim2.fromScale(cx or 0.5, cy or 0.5)
		img.Size = UDim2.fromScale(0.8, 0.8)
		img.ScaleType = Enum.ScaleType.Fit
		-- above the slot's own Backdrop / Outline frames (ZIndex 32-34), which sat on top and darkened it
		img.ZIndex = 40
		img.Parent = slot
		local key = slot:FindFirstChild("KeyLabel")
		if key then key.ZIndex = 42 end
	end
	local id = itemIcon(item)
	img.Image = id or ""
	img.Visible = id ~= nil
	tintIcon(img, item and item.Mutation)
	-- mutated items: a small coloured word along the bottom of the slot (Gold / Diamond / Rainbow)
	local tag = slot:FindFirstChild("MutTag")
	if not tag then
		tag = Instance.new("TextLabel")
		tag.Name = "MutTag"
		tag.BackgroundTransparency = 1
		tag.AnchorPoint = Vector2.new(0.5, 1)
		tag.Position = UDim2.fromScale(cx or 0.5, 0.98)
		tag.Size = UDim2.fromScale(0.9, 0.28)
		tag.FontFace = KIT_FONT
		tag.TextScaled = true
		tag.TextStrokeTransparency = 0
		tag.ZIndex = 41
		tag.Parent = slot
	end
	local mut = item and item.Mutation
	local mi = mut and G.MutationInfo[mut]
	tag.Visible = mi ~= nil
	tag.Text = mut or ""
	tag.TextColor3 = mi and mi.Color or Color3.fromHSV((os.clock() * 0.3) % 1, 0.7, 1)
	slot.Text = (item and not id) and itemText(item) or ""
end
local function styleSlot(slot)
	slot.FontFace = KIT_FONT
	slot.TextScaled = true
	slot.TextWrapped = true
	slot.TextColor3 = Color3.new(1, 1, 1)
	slot.TextStrokeTransparency = 0.2
end

do
	local slots = hud:WaitForChild("HotbarHUD"):WaitForChild("HotbarPanel"):WaitForChild("Slots")
	for i = 1, 9 do
		local slot = slots:WaitForChild("Slot" .. i)
		styleSlot(slot)
		slot.Activated:Connect(function() toggleItem(data.Items[i]) end)
	end
	local function render()
		for i = 1, 9 do
			local item = data.Items[i]
			setSlotItem(slots["Slot" .. i], item, 0.55, 0.55)
			slots["Slot" .. i].Visible = item ~= nil   -- only the backpack slot shows when you have nothing
		end
	end
	onData(render)
	local KEYS = {Enum.KeyCode.One, Enum.KeyCode.Two, Enum.KeyCode.Three, Enum.KeyCode.Four, Enum.KeyCode.Five,
		Enum.KeyCode.Six, Enum.KeyCode.Seven, Enum.KeyCode.Eight, Enum.KeyCode.Nine}
	UIS.InputBegan:Connect(function(input, processed)
		if processed then return end
		local i = table.find(KEYS, input.KeyCode)
		if i then toggleItem(data.Items[i]) end
	end)
end

do
	local panel = menus:WaitForChild("BackpackMenu"):WaitForChild("BackpackPanel")
	local slots = panel:WaitForChild("Slots")
	local filter = "All"
	local shown = {}
	local function render()
		shown = {}
		for _, item in data.Items do
			if filter == "All" or (filter == "Pets" and item.Type == "Animal") or (filter == "Tools" and item.Type == "Egg") then
				table.insert(shown, item)
			end
		end
		for i = 1, 24 do
			local slot = slots:FindFirstChild("Slot" .. i)
			if slot then setSlotItem(slot, shown[i]) end
		end
	end
	for i = 1, 24 do
		local slot = slots:FindFirstChild("Slot" .. i)
		if slot then
			styleSlot(slot)
			slot.Activated:Connect(function() toggleItem(shown[i]) end)
		end
	end
	for _, tab in {"All", "Pets", "Tools"} do
		local b = panel:FindFirstChild(tab .. "Tab")
		if b then b.Activated:Connect(function() filter = tab; render() end) end
	end
	onData(render)
end

------------------------------------------------------------ Index
do
	local panel = menus:WaitForChild("IndexMenu"):WaitForChild("IndexPanel")
	local list = panel:WaitForChild("Backdrop"):WaitForChild("List")
	local info = panel:WaitForChild("InfoCard")
	local claimSpot = info:WaitForChild("RewardBox"):WaitForChild("ClaimButtons")
	local cards = {}   -- {card, animal}
	for _, sec in G.IndexSections do
		local frame = list:FindFirstChild(sec.frame)
		if frame then
			local n = 0
			for _, name in G.IndexAnimals do
				if table.find(sec.rarities, EggRoll.rarityOf(name)) then
					n += 1
					local card = frame:FindFirstChild("Card" .. n)
					if card then table.insert(cards, {card = card, name = name}) end
				end
			end
		end
	end
	local selected = G.IndexAnimals[1]
	-- icons: ReplicatedStorage.AnimalIcons.Animals[name] = "rbxassetid://..." (not found yet = black silhouette)
	local ICONS = require(RS:WaitForChild("AnimalIcons")).Animals
	local function setIcon(img, name, found)
		local id = ICONS[name]
		img.Visible = id ~= nil
		if id then
			img.Image = id
			img.ImageColor3 = found and Color3.new(1, 1, 1) or Color3.new(0, 0, 0)
		end
	end
	local function income(name) return G.Income[EggRoll.rarityOf(name)] or 0 end
	local function renderInfo()
		local found = data.Index[selected]
		info.PetBox.IncomeLabel.Text = found and ("$" .. G.short(income(selected)) .. "/s") or "???"
		setIcon(info.PetBox.PetImage, selected, found)
		info.RewardBox.Title.Text = "Reward: $" .. G.short(income(selected) * G.IndexRewardSeconds)
		claimSpot:SetAttribute("CanClaim", found == true and not data.IndexClaimed[selected])
	end
	local function render()
		for _, c in cards do
			c.card.NameLabel.Text = data.Index[c.name] and c.name or "???"
			setIcon(c.card.Icon, c.name, data.Index[c.name])
		end
		renderInfo()
	end
	for _, c in cards do
		c.card.Activated:Connect(function() selected = c.name; renderInfo() end)
	end
	claimSpot:WaitForChild("ClaimButton").Activated:Connect(function() act("ClaimIndex", selected) end)
	-- tabs: All = everything, Pets = the normal tiers, Event = only seasonal (event) animals
	local tabs = panel:WaitForChild("CategoryTabs")
	local function tabChanged()
		local t = tabs:GetAttribute("SelectedTab")
		for _, sec in G.IndexSections do
			local f = list:FindFirstChild(sec.frame)
			if f then
				local isEvent = sec.frame == "EventSection"
				f.Visible = (t == "Event" and isEvent) or (t == "Pets" and not isEvent) or (t ~= "Event" and t ~= "Pets" and t ~= "Tools")
			end
		end
		list.CanvasPosition = Vector2.zero
	end
	tabs:GetAttributeChangedSignal("SelectedTab"):Connect(tabChanged)
	onData(render)
	render()
end

------------------------------------------------------------ confirm popup (Yes / No are labels in the kit)
local confirmCb
do
	local popup = popups:WaitForChild("ConfirmPopup")
	local panel = popup:WaitForChild("ConfirmPanel")
	local content = panel:WaitForChild("Content")
	local function close() popup.Enabled = false; confirmCb = nil end
	local function clicky(obj, fn)
		obj.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then fn() end
		end)
	end
	for _, n in {"YesLabel", "YesFill"} do
		local o = content:FindFirstChild(n)
		if o then clicky(o, function() local cb = confirmCb; close(); if cb then cb() end end) end
	end
	for _, n in {"NoLabel", "NoFill"} do
		local o = content:FindFirstChild(n)
		if o then clicky(o, close) end
	end
	-- while the confirm is up, every other open menu hides (they come back when it closes)
	popup.DisplayOrder = 50
	local hiddenForConfirm = {}
	popup:GetPropertyChangedSignal("Enabled"):Connect(function()
		if popup.Enabled then return end
		for g in hiddenForConfirm do if g.Parent then g.Enabled = true end end
		table.clear(hiddenForConfirm)
	end)
	function _G.SOA_Confirm(text, cb)
		content.MessageLabel.Text = text
		confirmCb = cb
		panel.Visible = true
		for _, g in menus:GetChildren() do
			if g:IsA("ScreenGui") and g.Enabled then hiddenForConfirm[g] = true; g.Enabled = false end
		end
		popup.Enabled = true
	end
end

------------------------------------------------------------ blur the world a little while any menu or popup is open
do
	local blur = game:GetService("Lighting"):FindFirstChild("UIBlur") or Instance.new("BlurEffect", game:GetService("Lighting"))
	blur.Name = "UIBlur"; blur.Size = 0; blur.Enabled = true
	local TS = game:GetService("TweenService")
	local on
	-- open = the ScreenGui is on AND its panel is showing (MenuButtons closes a menu by hiding the panel,
	-- the ScreenGui stays enabled)
	local function rootOf(g) for _, c in g:GetChildren() do if c:IsA("GuiObject") then return c end end end
	local function update()
		local any = false
		for _, folder in {menus, popups} do
			for _, g in folder:GetChildren() do
				local r = g:IsA("ScreenGui") and rootOf(g)
				if r and g.Enabled and r.Visible then any = true end
			end
		end
		if any == on then return end
		on = any
		TS:Create(blur, TweenInfo.new(0.25, Enum.EasingStyle.Quad), {Size = any and 10 or 0}):Play()
	end
	for _, folder in {menus, popups} do
		for _, g in folder:GetChildren() do
			if g:IsA("ScreenGui") then
				g:GetPropertyChangedSignal("Enabled"):Connect(function() task.defer(update) end)
				local r = rootOf(g)
				if r then r:GetPropertyChangedSignal("Visible"):Connect(function() task.defer(update) end) end
			end
		end
	end
	update()
end

------------------------------------------------------------ Robux prompts
local function prompt(itemName)
	local item = G.ShopItems[itemName]
	if not item then return end
	if item.Pass then
		local pass = G.Passes[item.Pass]
		if player:GetAttribute("Pass_" .. item.Pass) then banner("You already own this!") return end
		if pass.Id == 0 then banner("Coming soon!") return end
		MPS:PromptGamePassPurchase(player, pass.Id)
	else
		local pr = G.Products[item.Product]
		if pr.Id == 0 then banner("Coming soon!") return end
		MPS:PromptProductPurchase(player, pr.Id)
	end
end
local function priceOf(item)
	local id, kind
	if item.Pass then id, kind = G.Passes[item.Pass].Id, Enum.InfoType.GamePass
	else id, kind = G.Products[item.Product].Id, Enum.InfoType.Product end
	if id == 0 then return (item.Pass and G.Passes[item.Pass] or G.Products[item.Product]).Price end   -- not on the dashboard yet: the planned price
	local ok, info = pcall(MPS.GetProductInfo, MPS, id, kind)
	return ok and info and info.PriceInRobux
end

------------------------------------------------------------ Rebirth
local function wireRebirth(menuName)
	local menu = menus:FindFirstChild(menuName)
	local rp = menu and menu:FindFirstChild("RebirthPanel")
	if not rp then return end
	local bar = rp.CashGoal:FindFirstChild("BarFill")
	local barSize = bar and bar.Size
	local done = 0
	local function render()
		local r = player:GetAttribute("Rebirths") or 0
		local cash, need = player:GetAttribute("Cash") or 0, player:GetAttribute("RebirthCash") or G.rebirthCash(r)
		local placed, needA = player:GetAttribute("PlacedCount") or 0, player:GetAttribute("RebirthAnimals") or G.rebirthAnimals(r)
		rp.CashGoal.Title.Text = "1. Cash"
		rp.CashGoal.ProgressLabel.Text = G.short(math.min(cash, need)) .. "/" .. G.short(need)
		if bar then bar.Size = UDim2.new(barSize.X.Scale * math.clamp(cash / need, 0.02, 1), barSize.X.Offset, barSize.Y.Scale, barSize.Y.Offset) end
		rp.GoalCard.Title.Text = "2. Place animals"
		rp.GoalCard.ProgressLabel.Text = math.min(placed, needA) .. "/" .. needA
		done = (cash >= need and 1 or 0) + (placed >= needA and 1 or 0)
		local pl = rp.ProgressBar:FindFirstChild("ProgressLabel", true)
		if pl then pl.Text = done .. "/2 Completed" end
		rp.CashReward.RewardLabel.Text = "x" .. (1 + (r + 1) * G.RebirthCashBonus) .. " cash"
		rp.SpeedReward.RewardLabel.Text = "+" .. G.RebirthSpeed .. " speed"
		rp.StrengthReward.RewardLabel.Text = "+" .. G.RebirthLuck .. " luck"
		local skip = rp.SkipButton
		skip.Label.Text = done == 2 and "REBIRTH" or "SKIP"
		skip.PriceLabel.Visible = done < 2
		skip.RobuxIcon.Visible = done < 2
	end
	rp.SkipButton.Activated:Connect(function()
		if done == 2 then
			_G.SOA_Confirm("Rebirth? Your cash resets.", function() act("Rebirth") end)
		else
			local pr = G.Products.SkipRebirth
			if pr.Id == 0 then banner("Coming soon!") else MPS:PromptProductPurchase(player, pr.Id) end
		end
	end)
	task.spawn(function()
		local price = priceOf({Product = "SkipRebirth"})
		if price then rp.SkipButton.PriceLabel.Text = tostring(price) end
	end)
	onAttr({"Cash", "Rebirths", "PlacedCount", "RebirthCash", "RebirthAnimals"}, render)
	render()
end
wireRebirth("RebirthMenu")
wireRebirth("RebirthMenu_Alt")

------------------------------------------------------------ Daily rewards
do
	local dp = menus:WaitForChild("DailyRewardsMenu"):WaitForChild("DailyPanel")
	for d = 1, 7 do
		local f = dp:FindFirstChild("Day" .. d .. "Reward")
		local r = G.Daily[d]
		if f and r then
			f.RewardNameLabel.Text = r.Cash and ("$" .. G.short(r.Cash)) or (r.Egg .. " Egg")
			f.ClaimButton.Activated:Connect(function() act("ClaimDaily") end)
		end
	end
	local function clock(s) return string.format("%02d:%02d", s // 3600, (s % 3600) // 60) end
	local stamp = os.clock()
	onData(function() stamp = os.clock() end)
	local function render()
		local streak = data.Daily.Streak or 0
		local nextDay = streak % 7 + 1
		local claimedThisLoop = streak % 7   -- days already claimed in this 7-day loop
		local left = math.max(0, (data.Daily.NextIn or 0) - (os.clock() - stamp))
		for d = 1, 7 do
			local f = dp:FindFirstChild("Day" .. d .. "Reward")
			if f then
				local can = d == nextDay and (data.Daily.Ready or left <= 0)
				f:SetAttribute("CanClaim", can)
				local lockLabel = f.ClaimButtonLocked:FindFirstChild("Label")
				if lockLabel then
					lockLabel.Text = d <= claimedThisLoop and "Claimed" or (d == nextDay and clock(left)) or "Claim"
				end
			end
		end
	end
	onData(render)
	task.spawn(function() while true do render(); task.wait(1) end end)
end

------------------------------------------------------------ Shop + boosts
do
	local content = menus:WaitForChild("ShopMenu"):WaitForChild("ShopPanel"):WaitForChild("Window"):WaitForChild("Backdrop"):WaitForChild("List"):WaitForChild("Content")
	local boosts = hud:WaitForChild("BoostsHUD"):WaitForChild("BoostsPanel")
	local energy = hud:WaitForChild("EnergyBarHUD"):WaitForChild("EnergyBarPanel")   -- the lifting bar's Strength buttons
	local function find(name) return content:FindFirstChild(name, true) or boosts:FindFirstChild(name, true) or energy:FindFirstChild(name, true) end
	for name, item in G.ShopItems do
		local f = find(name)
		if f then
			if item.Title then
				local lbl = f:FindFirstChild("NameLabel") or f:FindFirstChild("Title")
				if lbl then lbl.Text = item.Title end
			end
			local button = f:FindFirstChild("BuyButton") or f:FindFirstChild("PackButton") or (f:IsA("GuiButton") and f)
			if button then button.Activated:Connect(function() prompt(name) end) end
			task.spawn(function()
				local price = priceOf(item)
				local lbl = f:FindFirstChild("PriceLabel", true)
				if price and lbl then lbl.Text = tostring(price) end
			end)
		end
	end
	-- owned passes say so
	local function owned()
		for name, item in G.ShopItems do
			if item.Pass and player:GetAttribute("Pass_" .. item.Pass) then
				local f = find(name)
				local lbl = f and f:FindFirstChild("PriceLabel", true)
				if lbl then lbl.Text = "Owned" end
			end
		end
	end
	for key in G.Passes do player:GetAttributeChangedSignal("Pass_" .. key):Connect(owned) end
	owned()
end

------------------------------------------------------------ Gift menu
do
	local gm = menus:WaitForChild("GiftMenu")
	local panel = gm:WaitForChild("GiftPanel")
	local targets = {}
	local function fill()
		targets = {}
		for _, pl in Players:GetPlayers() do if pl ~= player then table.insert(targets, pl) end end
		for i = 1, 4 do
			local card = panel:FindFirstChild("PlayerCard" .. i)
			local pl = targets[i]
			if card then
				card.Visible = pl ~= nil
				if pl then
					card.PlayerNameLabel.Text = pl.DisplayName
					task.spawn(function()
						local ok, img = pcall(Players.GetUserThumbnailAsync, Players, pl.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size150x150)
						if ok then card.Avatar.Image = img end
					end)
				end
			end
		end
		if #targets == 0 and gm.Enabled then banner("Nobody else is here to gift to") end
	end
	for i = 1, 4 do
		local card = panel:FindFirstChild("PlayerCard" .. i)
		if card then
			card.GiftButton.Activated:Connect(function()
				local pl = targets[i]
				if not pl then return end
				local id = act("GiftTarget", gm:GetAttribute("OpenedFrom"), pl.UserId)
				if not id or id == 0 then banner("Gifting coming soon!") return end
				MPS:PromptProductPurchase(player, id)
			end)
		end
	end
	gm:GetPropertyChangedSignal("Enabled"):Connect(fill)
	gm:GetAttributeChangedSignal("OpenedFrom"):Connect(fill)
	Players.PlayerAdded:Connect(fill)
	Players.PlayerRemoving:Connect(function() task.defer(fill) end)
	fill()
end

------------------------------------------------------------ Egg Luck shop prompt + luck for the egg roll
do
	local plots = workspace:WaitForChild("Plots")
	task.spawn(function()
		while true do
			for _, plot in plots:GetChildren() do
				local pp = plot:FindFirstChild("UpgradePrompt", true)
				if pp then pp.Enabled = plot.Name == player:GetAttribute("Plot") end
			end
			local demo = workspace:FindFirstChild("PenaltyDemo")
			if demo then demo:SetAttribute("Luck", player:GetAttribute("Luck") or 1) end
			task.wait(0.3)
		end
	end)
end

------------------------------------------------------------ Codes + Settings (opened from the top-left topbar icons)
do
	local cp = menus:WaitForChild("CodesMenu"):WaitForChild("CodesPanel")
	cp:WaitForChild("RedeemButton").Activated:Connect(function()
		local code = cp.CodeInput.Text
		if code == "" then return end
		local wasOn = notificationsOn
		notificationsOn = true   -- always say what happened to a code
		act("Redeem", code)
		notificationsOn = wasOn
		cp.CodeInput.Text = ""
	end)
end

do
	local SoundService = game:GetService("SoundService")
	local Lighting = game:GetService("Lighting")
	local options = menus:WaitForChild("SettingsMenu"):WaitForChild("SettingsPanel"):WaitForChild("Window")
		:WaitForChild("Backdrop"):WaitForChild("List"):WaitForChild("Options")
	local DEFAULT = {Music = true, SFX = true, Shadows = true, Notifications = true, Trading = true}
	local function apply(name, on)
		if name == "Music" then local g = SoundService:FindFirstChild("Music"); if g then g.Volume = on and 1 or 0 end
		elseif name == "SFX" then local g = SoundService:FindFirstChild("SFX"); if g then g.Volume = on and 1 or 0 end
		elseif name == "Shadows" then Lighting.GlobalShadows = on
		elseif name == "Notifications" then notificationsOn = on
		end   -- Trading: saved for when trading exists
	end
	local loaded = false
	onData(function()
		if loaded then return end
		loaded = true
		local saved = data.Settings or {}
		for name, def in DEFAULT do
			local row = options:FindFirstChild(name)
			local on = saved[name]
			if on == nil then on = def end
			if row then row:SetAttribute("On", on) end
			apply(name, on)
		end
	end)
	for name in DEFAULT do
		local row = options:FindFirstChild(name)
		if row then
			row:GetAttributeChangedSignal("On"):Connect(function()
				local on = row:GetAttribute("On") == true
				apply(name, on)
				if loaded then task.spawn(act, "Setting", name, on) end
			end)
		end
	end
end

task.spawn(function()
	local ok, Icon = pcall(function() return require(RS:WaitForChild("TopbarPlus"):WaitForChild("Icon")) end)
	if not ok then warn("HUDClient: TopbarPlus didn't load: " .. tostring(Icon)) return end
	local sideBtns = side:WaitForChild("SideButtonsPanel")
	local function make(button, caption, menuName)
		local img = sideBtns:FindFirstChild(button) and sideBtns[button]:FindFirstChild("Icon") and sideBtns[button].Icon.Image
		local icon = Icon.new()
		if img then icon:setImage(img) end
		pcall(function() icon:setCaption(caption) end)
		pcall(function() icon:oneClick() end)
		icon.selected:Connect(function() side.ToggleMenu:Fire(menuName) end)
		return icon
	end
	make("CodesButton", "Codes", "CodesMenu")
	make("SettingsButton", "Settings", "SettingsMenu")
end)

------------------------------------------------------------ Egg Luck: stand on your shop's spot -> UpgradesMenu
do
	local panel = menus:WaitForChild("UpgradesMenu"):WaitForChild("UpgradesPanel")
	local row = panel:WaitForChild("SpeedUpgrade")   -- Jacob's luck row
	local BUYS = {{button = row:WaitForChild("BuyButton1"), count = 1}, {button = row:WaitForChild("BuyButton2"), count = 3}}
	local function luckAt(level)
		local r = player:GetAttribute("Rebirths") or 0
		return (1 + level * G.LuckPerLevel + r * G.RebirthLuck) * (player:GetAttribute("Pass_Luck2x") and 2 or 1)
	end
	local function fmt(x) return (string.format("%.2f", x):gsub("0$", ""):gsub("%.0$", "")) end
	local function render()
		local level = player:GetAttribute("LuckLevel") or 0
		local maxed = level >= G.LuckMaxLevel
		row.ValueLabel.Text = maxed and ("x" .. fmt(luckAt(level)) .. " MAX") or ("x" .. fmt(luckAt(level)) .. " > x" .. fmt(luckAt(level + 1)))
		for _, b in BUYS do
			local n = math.min(b.count, G.LuckMaxLevel - level)
			local cost = 0
			for l = level, level + n - 1 do cost += G.luckCost(l) end
			local cap = b.button:FindFirstChild("Caption")
			if cap then
				cap.AmountLabel.Text = "BUY " .. b.count
				cap.PriceLabel.Text = n <= 0 and "MAX" or ("$" .. G.short(cost))
			end
		end
	end
	for _, b in BUYS do
		b.button.Activated:Connect(function() act("BuyLuck", b.count) end)
	end
	for _, n in {"LuckLevel", "Rebirths", "Pass_Luck2x", "Cash"} do player:GetAttributeChangedSignal(n):Connect(render) end
	render()

	-- open while standing on your own shop's spot, close when you step off
	local onSpot = false
	task.spawn(function()
		while true do
			task.wait(0.15)
			local char = player.Character
			local root = char and char:FindFirstChild("HumanoidRootPart")
			local shops = workspace:FindFirstChild("LuckShops")
			local mine = (player:GetAttribute("Plot") or ""):match("%d+$")
			local shop = shops and mine and shops:FindFirstChild("LuckShop" .. mine)
			local spot = shop and shop:FindFirstChild("Meshes/spot")
			local now = false
			if root and spot and not player:GetAttribute("InPenalty") then
				local lp = spot.CFrame:PointToObjectSpace(root.Position)
				now = math.abs(lp.X) <= spot.Size.X / 2 + 0.5 and math.abs(lp.Z) <= spot.Size.Z / 2 + 0.5 and lp.Y > -1 and lp.Y < 7
			end
			if now ~= onSpot then
				onSpot = now
				if now then render(); openMenu("UpgradesMenu") else side.CloseMenu:Fire("UpgradesMenu") end
			end
		end
	end)
end

------------------------------------------------------------ Sell: Workspace.SellShop opens Menus.SellMenu
-- Lists the animals in your inventory (placed ones stay on your plot). One row each (Row1-5 are the
-- kit's rows; more are cloned from Row1), SELL sells that one, SELL ALL sells them all after a confirm.
-- Price: GameConfig.SellValue (server: GameServer action SellAnimal / SellAll).
do
	local menu = menus:WaitForChild("SellMenu")
	local panel = menu:WaitForChild("SellPanel")
	local list = panel:WaitForChild("Backdrop"):WaitForChild("List")
	local rowsFrame = list:WaitForChild("Rows")
	local template = rowsFrame:WaitForChild("Row1"):Clone()
	local baseCanvas = list.CanvasSize
	local rows, shownItems = {}, {}
	local function hook(i, r)
		for _, n in {"NameLabel", "ValueLabel"} do
			local l = r.ItemSlot:FindFirstChild(n)
			if l then l:SetAttribute("FW_TextOwn", true); l.TextScaled = true end
		end
		r.SellButton.Activated:Connect(function()
			local it = shownItems[i]
			if it then act("SellAnimal", it.Id) end
		end)
	end
	for i = 1, 5 do
		rows[i] = rowsFrame:FindFirstChild("Row" .. i)
		if rows[i] then hook(i, rows[i]) end
	end
	local function rowFor(i)
		if not rows[i] then
			local r = template:Clone()
			r.Name = "Row" .. i
			r.Parent = rowsFrame
			rows[i] = r
			hook(i, r)
		end
		return rows[i]
	end
	local function render()
		shownItems = {}
		for _, item in data.Items do if item.Type == "Animal" then table.insert(shownItems, item) end end
		local n = math.max(5, #shownItems)
		for i = 1, n do
			local r = rowFor(i)
			r.Position = UDim2.fromScale(r.Position.X.Scale, (i - 0.5) / n)
			r.Size = UDim2.fromScale(r.Size.X.Scale, 0.95 / n)
			local it = shownItems[i]
			r.Visible = it ~= nil
			if it then
				local slot = r.ItemSlot
				slot.Icon.Image = ICON_SETS.Animals[it.Name] or ""
				tintIcon(slot.Icon, it.Mutation)
				slot.NameLabel.Text = G.mutLabel(it.Mutation, it.Name)
				slot.ValueLabel.Text = "$" .. G.commas(G.SellValue(it.Name, it.Mutation))
			end
		end
		for i = n + 1, #rows do if rows[i] then rows[i].Visible = false end end
		list.CanvasSize = UDim2.new(baseCanvas.X.Scale, baseCanvas.X.Offset, baseCanvas.Y.Scale * n / 5, baseCanvas.Y.Offset)
	end
	onData(render)
	render()
	panel:WaitForChild("SellAllButton").Activated:Connect(function()
		local total, count = 0, 0
		for _, it in shownItems do total += G.SellValue(it.Name, it.Mutation); count += 1 end
		if count == 0 then banner("Nothing to sell") return end
		local text = "Sell " .. count .. (count == 1 and " animal" or " animals") .. " for $" .. G.short(total) .. "?"
		if _G.SOA_Confirm then _G.SOA_Confirm(text, function() act("SellAll") end) else act("SellAll") end
	end)

	-- open while standing on the sell stand's spot, close when you step off
	local onSpot = false
	task.spawn(function()
		while true do
			task.wait(0.15)
			local char = player.Character
			local root = char and char:FindFirstChild("HumanoidRootPart")
			local shop = workspace:FindFirstChild("SellShop")
			local spot = shop and shop:FindFirstChild("Meshes/spot")
			local now = false
			if root and spot and not player:GetAttribute("InPenalty") then
				local lp = spot.CFrame:PointToObjectSpace(root.Position)
				now = math.abs(lp.X) <= spot.Size.X / 2 + 0.5 and math.abs(lp.Z) <= spot.Size.Z / 2 + 0.5 and lp.Y > -1 and lp.Y < 7
			end
			if now ~= onSpot then
				onSpot = now
				if now then render(); openMenu("SellMenu") else side.CloseMenu:Fire("SellMenu") end
			end
		end
	end)
end
