-- Economy and menus on the server: cash per second from placed animals, Luck shop, rebirth,
-- daily rewards, Index rewards, Robux purchases and gifts. Data lives in ServerScriptService.GameData.
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local MPS = game:GetService("MarketplaceService")
local D = require(script.Parent:WaitForChild("GameData"))
local G = require(RS:WaitForChild("GameConfig"))
local EggRoll = require(RS:WaitForChild("DevDemo"):WaitForChild("EggRoll"))
local Remotes = RS:WaitForChild("GameRemotes")
local plots = workspace:WaitForChild("Plots")

local function notify(player, text) Remotes.Notify:FireClient(player, text) end

------------------------------------------------------------------ game passes
local owned = {}   -- [player][passKey] = true
local function refreshPasses(player)
	local p = D.get(player)
	local t = {}
	for key, pass in G.Passes do
		local yes = p and p.GiftedPasses[key] == true
		if not yes and pass.Id ~= 0 then
			local ok, res = pcall(MPS.UserOwnsGamePassAsync, MPS, player.UserId, pass.Id)
			yes = ok and res
		end
		t[key] = yes or nil
		player:SetAttribute("Pass_" .. key, yes == true)
	end
	owned[player] = t
	if t.VIP and p and not p.VIPGiven then   -- VIP one-time bonus
		p.VIPGiven = true
		local vipCash = math.max(G.VIPCashMin, math.floor((player:GetAttribute("CashPerSec") or 0) * 60 * G.VIPCashMinutes))
		D.addCash(player, vipCash)
		D.giveItem(player, "Egg", G.VIPEgg)
		notify(player, "VIP: +$" .. G.short(vipCash) .. " and a free " .. G.VIPEgg .. " egg!")
	end
end
local function has(player, key) return owned[player] and owned[player][key] == true end

------------------------------------------------------------------ stats (luck, multipliers, speed)
local friends = {}   -- [player] = friends in this server
local function refreshStats(player)
	local p = D.get(player)
	if not p then return end
	local luck = (1 + p.LuckLevel * G.LuckPerLevel + p.Rebirths * G.RebirthLuck) * (has(player, "Luck2x") and 2 or 1)
	player:SetAttribute("Luck", luck)
	local fb = math.min(G.FriendBonusMax, (friends[player] or 0) * G.FriendBonus)
	player:SetAttribute("FriendBonus", fb)
	local mult = (1 + p.Rebirths * G.RebirthCashBonus) * (has(player, "Cash2x") and 2 or 1) * (has(player, "VIP") and G.VIPCashMulti or 1) * (1 + fb)
	player:SetAttribute("CashMulti", mult)
	local income = 0
	for _, a in p.Placed do income += (G.Income[D.rarityOf(a.Name)] or 0) * G.mutIncome(a.Mutation) end
	player:SetAttribute("CashPerSec", income * mult)
	player:SetAttribute("PlacedCount", #p.Placed)
	local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if hum and not player:GetAttribute("InPenalty") and not player:GetAttribute("Lifting") then hum.WalkSpeed = 16 + p.Rebirths * G.RebirthSpeed end
	player:SetAttribute("LuckCost", p.LuckLevel < G.LuckMaxLevel and G.luckCost(p.LuckLevel) or -1)
	player:SetAttribute("RebirthCash", G.rebirthCash(p.Rebirths))
	player:SetAttribute("RebirthAnimals", G.rebirthAnimals(p.Rebirths))
end
_G.SOA_RefreshStats = refreshStats   -- EggHatching calls this after placing an animal

local function onCharacter(player)
	task.wait()
	D.rebuildTools(player)
	refreshStats(player)
end
local function setup(player)
	refreshPasses(player)
	local prof = D.get(player)
	for key in prof and prof.Bought or {} do player:SetAttribute("Bought_" .. key, true) end
	refreshStats(player)
	if player.Character then onCharacter(player) end
end
local function hook(player)
	player.CharacterAdded:Connect(function() if D.get(player) then onCharacter(player) end end)
end
Players.PlayerAdded:Connect(hook)
for _, pl in Players:GetPlayers() do hook(pl) end
D.Loaded.Event:Connect(setup)
for _, pl in Players:GetPlayers() do if D.get(pl) then task.spawn(setup, pl) end end
Players.PlayerRemoving:Connect(function(p) owned[p] = nil; friends[p] = nil end)

-- friends online together
task.spawn(function()
	while true do
		local list = Players:GetPlayers()
		for _, a in list do
			local n = 0
			for _, b in list do
				if a ~= b then
					local ok, f = pcall(a.IsFriendsWith, a, b.UserId)
					if ok and f then n += 1 end
				end
			end
			friends[a] = n
			refreshStats(a)
		end
		task.wait(15)
	end
end)

-- cash every second
task.spawn(function()
	while true do
		task.wait(1)
		for _, pl in Players:GetPlayers() do
			local cps = pl:GetAttribute("CashPerSec")
			if cps and cps > 0 then D.addCash(pl, cps) end
		end
	end
end)

------------------------------------------------------------------ actions
local function buyLuck(player, count)
	local p = D.get(player)
	if not p then return false, "Loading" end
	count = math.clamp(math.floor(tonumber(count) or 1), 1, 10)
	if p.LuckLevel >= G.LuckMaxLevel then return false, "Luck is maxed!" end
	count = math.min(count, G.LuckMaxLevel - p.LuckLevel)
	local cost = 0
	for l = p.LuckLevel, p.LuckLevel + count - 1 do cost += G.luckCost(l) end
	if not D.spend(player, cost) then return false, "Need $" .. G.short(cost) end
	p.LuckLevel += count
	refreshStats(player)
	D.sync(player)
	return true, "Luck x" .. string.format("%.2f", player:GetAttribute("Luck"))
end

local function doRebirth(player, skip)
	local p = D.get(player)
	if not p then return false end
	if not skip and (p.Cash < G.rebirthCash(p.Rebirths) or #p.Placed < G.rebirthAnimals(p.Rebirths)) then
		return false, "Not ready yet"
	end
	p.Cash = 0
	player:SetAttribute("Cash", 0)
	p.Rebirths += 1
	refreshStats(player)
	D.sync(player)
	return true, "Rebirth " .. p.Rebirths .. "!"
end

local function claimDaily(player)
	local p = D.get(player)
	if not p then return false end
	local streak, ready = D.dailyState(p)
	if not ready then return false, "Come back later" end
	local day = streak % 7 + 1
	local r = G.Daily[day]
	p.Daily.Streak = streak + 1
	p.Daily.Last = os.time()
	if r.Cash then D.addCash(player, r.Cash) end
	if r.Egg then D.giveItem(player, "Egg", r.Egg) end
	D.sync(player)
	return true, "Day " .. day .. " claimed!"
end

local function claimIndex(player, name)
	local p = D.get(player)
	if not (p and type(name) == "string" and p.Index[name] and not p.IndexClaimed[name]) then return false end
	p.IndexClaimed[name] = true
	local cash = (G.Income[D.rarityOf(name)] or 0) * G.IndexRewardSeconds
	D.addCash(player, cash)
	D.sync(player)
	return true, "+$" .. G.short(cash)
end

------------------------------------------------------------------ Robux
local productById = {}   -- [id] = {key, gift, pass}
for key, pr in G.Products do
	if pr.Id ~= 0 then productById[pr.Id] = {key = key} end
	if pr.GiftId and pr.GiftId ~= 0 then productById[pr.GiftId] = {key = key, gift = true} end
end
for key, pass in G.Passes do
	if pass.GiftId ~= 0 then productById[pass.GiftId] = {key = key, gift = true, pass = true} end
end

local function grantProduct(player, key)
	local pr = G.Products[key]
	if pr.OnePer then   -- one-per-player packs (the Starter Pack): remembered in the save, the shop shows OWNED
		local p = D.get(player)
		p.Bought = p.Bought or {}
		p.Bought[key] = true
		player:SetAttribute("Bought_" .. key, true)
	end
	if pr.Cash then D.addCash(player, pr.Cash); notify(player, "+$" .. G.short(pr.Cash)) end
	if pr.CashMinutes then   -- scales with your income (GameConfig.packCash)
		local cash = G.packCash(pr, player:GetAttribute("CashPerSec") or 0)
		D.addCash(player, cash)
		notify(player, "+$" .. G.short(cash))
	end
	if pr.LiftMinutes then   -- that many minutes of lifting with your barbell (GameConfig.packLift)
		local p = D.get(player)
		local gain, level, xp = G.packLift(pr, p.LiftLevel, p.LiftXP, p.BarbellLevel, p.Strength)
		p.LiftLevel, p.LiftXP = level, xp
		p.Strength += gain
		player:SetAttribute("Strength", p.Strength)
		player:SetAttribute("LiftLevel", p.LiftLevel)
		player:SetAttribute("LiftXP", p.LiftXP)
		notify(player, "+" .. G.commas(gain) .. " Strength!")
	end
	if pr.Egg then D.giveItem(player, "Egg", pr.Egg); notify(player, pr.Egg .. " Egg added to your backpack!") end
	if pr.LuckyEgg then
		local name = EggRoll.pick(G.EggPool, (player:GetAttribute("Luck") or 1) * 10)
		D.giveItem(player, "Egg", name)
		notify(player, "Lucky Pack: " .. name .. " Egg!")
	end
	if pr.Skip then doRebirth(player, true) end
end

local giftFor = {}   -- [buyer] = {key, target}
MPS.ProcessReceipt = function(info)
	local buyer = Players:GetPlayerByUserId(info.PlayerId)
	local what = productById[info.ProductId]
	if not (buyer and what and D.get(buyer)) then return Enum.ProductPurchaseDecision.NotProcessedYet end
	local to = buyer
	if what.gift then
		local g = giftFor[buyer]
		to = g and Players:GetPlayerByUserId(g.target) or buyer
		if not D.get(to) then to = buyer end
	end
	if what.pass then
		D.get(to).GiftedPasses[what.key] = true
		refreshPasses(to)
		refreshStats(to)
	else
		grantProduct(to, what.key)
	end
	if to ~= buyer then
		notify(to, buyer.DisplayName .. " gifted you " .. what.key .. "!")
		notify(buyer, "Gift sent to " .. to.DisplayName .. "!")
	end
	task.spawn(D.save, to)
	return Enum.ProductPurchaseDecision.PurchaseGranted
end
MPS.PromptGamePassPurchaseFinished:Connect(function(player, _, bought)
	if bought then refreshPasses(player); refreshStats(player) end
end)

-- Sell (Workspace.SellShop -> Menus.SellMenu): animals in your inventory (not placed ones) for
-- GameConfig.SellValue. id = the item's Id, or "all".
local function sellAnimals(player, id)
	local p = D.get(player)
	if not p then return false, "Try again in a second" end
	local total, n = 0, 0
	for i = #p.Items, 1, -1 do
		local item = p.Items[i]
		if item.Type == "Animal" and (id == "all" or item.Id == id) then
			table.remove(p.Items, i)
			for _, where in {player:FindFirstChildOfClass("Backpack"), player.Character} do
				for _, t in where and where:GetChildren() or {} do
					if t:IsA("Tool") and t:GetAttribute("ItemId") == item.Id then t:Destroy() end
				end
			end
			total += G.SellValue(item.Name, item.Mutation)
			n += 1
			if id ~= "all" then break end
		end
	end
	if n == 0 then return false, "Nothing to sell" end
	D.addCash(player, total)
	D.sync(player)
	return true, "Sold " .. (n == 1 and "1 animal" or (n .. " animals")) .. " for $" .. G.short(total)
end

Remotes.Action.OnServerInvoke = function(player, action, a, b)
	if action == "BuyLuck" then return buyLuck(player, a)
	elseif action == "Rebirth" then return doRebirth(player, false)
	elseif action == "ClaimDaily" then return claimDaily(player)
	elseif action == "ClaimIndex" then return claimIndex(player, a)
	elseif action == "SellAnimal" then return sellAnimals(player, typeof(a) == "number" and a or nil)
	elseif action == "SellAll" then return sellAnimals(player, "all")
	elseif action == "Redeem" then
		local p = D.get(player)
		local code = type(a) == "string" and a:upper():gsub("%s", "") or ""
		local r = G.Codes[code]
		if not (p and r) then return false, "That code doesn't exist" end
		if p.Codes[code] then return false, "You already used that code" end
		p.Codes[code] = true
		if r.Cash then D.addCash(player, r.Cash) end
		if r.Egg then D.giveItem(player, "Egg", r.Egg) end
		return true, "Code redeemed!" .. (r.Cash and (" +$" .. G.short(r.Cash)) or "") .. (r.Egg and (" " .. r.Egg .. " Egg") or "")
	elseif action == "Setting" then
		local p = D.get(player)
		if p and type(a) == "string" and #a < 20 and type(b) == "boolean" then p.Settings[a] = b end
		return true
	elseif action == "GiftTarget" then
		-- a = shop item frame name, b = target UserId; returns the gift product id to prompt
		local item = G.ShopItems[a]
		if not item or typeof(b) ~= "number" or not Players:GetPlayerByUserId(b) then return 0 end
		local cfg = item.Pass and G.Passes[item.Pass] or G.Products[item.Product]
		giftFor[player] = {key = item.Pass or item.Product, target = b}
		return cfg and cfg.GiftId or 0
	end
end

------------------------------------------------------------------ Studio test hook
if game:GetService("RunService"):IsStudio() then
	local dev = game:GetService("ServerStorage"):FindFirstChild("DevCommand") or Instance.new("BindableFunction")
	dev.Name = "DevCommand"
	dev.Parent = game:GetService("ServerStorage")
	dev.OnInvoke = function(cmd, player, a, b, c)
		player = player or Players:GetPlayers()[1]
		if cmd == "give" then return D.giveItem(player, a, b, nil, c) ~= nil   -- c = mutation
		elseif cmd == "cash" then D.addCash(player, a); return true
		elseif cmd == "grant" then grantProduct(player, a); return true   -- test a Robux product without buying it
		elseif cmd == "profile" then return D.get(player)
		end
	end
end

------------------------------------------------------------------ Egg Luck shops
-- Walking onto your own shop's spot (LuckShops.LuckShopN["Meshes/spot"]) opens the UpgradesMenu (HUDClient),
-- which buys through the BuyLuck action above.
