-- Player save data + inventory. One profile per player, saved in a DataStore.
-- Inventory items are the source of truth; the Tools in the Backpack are rebuilt from them
-- (so nothing is lost when you respawn).
--   profile = {Cash, Rebirths, LuckLevel, Index = {name = true}, IndexClaimed = {name = true},
--              Daily = {Streak, Last}, Items = {{Id, Type = "Egg"/"Animal", Name}}, NextId,
--              Placed = {{Id, Name, X, Z, Yaw}}, Patches = {[patchName] = {Egg, ReadyAt (unix)}},
--              GiftedPasses = {}, VIPGiven}
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local SS = game:GetService("ServerStorage")
local DSS = game:GetService("DataStoreService")
local C = require(RS:WaitForChild("Hatching"):WaitForChild("HatchConfig"))
local EggRoll = require(RS:WaitForChild("DevDemo"):WaitForChild("EggRoll"))
local G = require(RS:WaitForChild("GameConfig"))
local Remotes = RS:WaitForChild("GameRemotes")

local D = {}
local profiles = {}
local noSave = {}
D.Loaded = Instance.new("BindableEvent")   -- :Fire(player) once the profile is ready

local store
do
	local ok, s = pcall(function() return DSS:GetDataStore("SOA_Player_v1") end)
	if ok then store = s else warn("GameData: DataStore not available (Studio: Game Settings > Security > Enable Studio Access to API Services). Playing without saving.") end
end

local function defaults()
	return {Cash = 0, Rebirths = 0, LuckLevel = 0, Index = {}, IndexClaimed = {}, Daily = {Streak = 0, Last = 0},
		Items = {}, NextId = 1, Placed = {}, Patches = {}, GiftedPasses = {}, VIPGiven = false, Codes = {}, Settings = {}, BaseLevel = 0, Strength = 10, BarbellLevel = 1, LiftLevel = 1, LiftXP = 0}
end

function D.get(player) return profiles[player] end
function D.rarityOf(name) return EggRoll.rarityOf(name) end

------------------------------------------------------------------ tools
-- Held eggs and animals sit out in front of you at their real size (the hand reaches out, see
-- StarterPlayerScripts.ClassicAnimate). The Tool's Handle is a tiny invisible part; the model is welded
-- to your HumanoidRootPart while the tool is equipped.
local EGGS = SS:WaitForChild("BaseEggs")
local function newTool(name)
	local tool = Instance.new("Tool")
	tool.Name = name
	tool.CanBeDropped = false
	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(0.2, 0.2, 0.2)
	handle.Transparency = 1
	handle.CanCollide, handle.CanTouch, handle.CanQuery, handle.Massless = false, false, false, true
	handle.Parent = tool
	return tool
end
local function holdInFront(tool, body, onGround)
	for _, d in body:GetDescendants() do
		if d:IsA("BasePart") then d.Anchored, d.CanCollide, d.CanTouch, d.CanQuery, d.Massless = false, false, false, false, true end
	end
	if body:IsA("BasePart") then body.Anchored, body.CanCollide, body.CanTouch, body.CanQuery, body.Massless = false, false, false, false, true end
	tool.Equipped:Connect(function()
		local char = tool.Parent
		local hrp = char and char:FindFirstChild("HumanoidRootPart")
		if not hrp then return end
		local old = body:FindFirstChild("HoldWeld")
		if old then old:Destroy() end
		local sz = body.Size
		local w = Instance.new("Weld")
		w.Name = "HoldWeld"
		w.Part0 = hrp
		w.Part1 = body
		-- eggs: bottom about hand height; animals: feet on the ground. Just past your reach, facing your way.
		local hum = char:FindFirstChildOfClass("Humanoid")
		local floor = -((hum and hum.HipHeight or 0) + hrp.Size.Y / 2)
		if hum and hum.RigType == Enum.HumanoidRigType.R6 then floor = -(hrp.Size.Y / 2 + 2) end
		w.C0 = CFrame.new(0, (onGround and floor or -0.6) + sz.Y / 2, -(sz.Z / 2 + 1.8))
		w.Parent = body
	end)
	tool.Unequipped:Connect(function()
		local w = body:FindFirstChild("HoldWeld")
		if w then w:Destroy() end
	end)
end

local function eggTool(name, mut)
	local src = (mut and G.mutEggModel(name, mut)) or EGGS:FindFirstChild(name)
	if not (src and src:IsA("BasePart")) then return end
	local tool = newTool(G.mutLabel(mut, name .. " Egg"))
	tool:SetAttribute("EggName", name)
	tool:SetAttribute("Mutation", mut)
	local egg = src:Clone()   -- full size (Jacob)
	egg.Name = "Egg"
	G.addMutationVFX(egg, mut)
	egg.Parent = tool
	holdInFront(tool, egg)
	return tool
end
local function animalTool(name, mut)
	local tmpl = C.animalTemplate(name, mut)
	if not tmpl then warn("GameData: no animal model for " .. name); return end
	local m = tmpl:Clone()
	m:ScaleTo(m:GetScale() * C.heldScale(tmpl))   -- the animal's real size (placed ones grow with rarity, HatchConfig.placedScale)
	local tool = newTool(G.mutLabel(mut, name))
	tool:SetAttribute("AnimalName", name)
	tool:SetAttribute("Mutation", mut)
	local mesh = C.mesh(m)
	mesh.Name = "Body"
	G.addMutationVFX(mesh, mut)
	for _, c in m:GetChildren() do if not c:IsA("AnimationController") then c.Parent = tool end end
	m:Destroy()
	holdInFront(tool, mesh, false)
	return tool
end

local function hasTool(player, id)
	for _, where in {player:FindFirstChildOfClass("Backpack"), player.Character} do
		if where then
			for _, t in where:GetChildren() do
				if t:IsA("Tool") and t:GetAttribute("ItemId") == id then return t end
			end
		end
	end
end

local function buildTool(player, item)
	if hasTool(player, item.Id) then return end
	local bp = player:FindFirstChildOfClass("Backpack")
	if not bp then return end
	local t = item.Type == "Egg" and eggTool(item.Name, item.Mutation) or animalTool(item.Name, item.Mutation)
	if not t then return end
	t:SetAttribute("ItemId", item.Id)
	t.Parent = bp
end

function D.rebuildTools(player)
	local p = profiles[player]
	if not p then return end
	for _, item in p.Items do buildTool(player, item) end
end

------------------------------------------------------------------ daily rewards
D.DAILY_COOLDOWN, D.DAILY_RESET = 20 * 3600, 48 * 3600
-- streak = days claimed in a row (0 if it broke); the next claim is day (streak % 7) + 1
function D.dailyState(p)
	local since = os.time() - p.Daily.Last
	local streak = since > D.DAILY_RESET and 0 or p.Daily.Streak
	return streak, since >= D.DAILY_COOLDOWN, math.max(0, D.DAILY_COOLDOWN - since)
end

------------------------------------------------------------------ sync to the client
local pending = {}
function D.sync(player)
	if pending[player] then return end
	pending[player] = true
	task.defer(function()
		pending[player] = nil
		local p = profiles[player]
		if not (p and player.Parent) then return end
		local streak, ready, nextIn = D.dailyState(p)
		Remotes.Sync:FireClient(player, {
			Items = p.Items, Index = p.Index, IndexClaimed = p.IndexClaimed,
			Rebirths = p.Rebirths, LuckLevel = p.LuckLevel, Placed = #p.Placed, PlacedList = p.Placed,
			Daily = {Streak = streak, Ready = ready, NextIn = nextIn}, Settings = p.Settings,
		})
		player:SetAttribute("Rebirths", p.Rebirths)
		player:SetAttribute("LuckLevel", p.LuckLevel)
		player:SetAttribute("PlacedCount", #p.Placed)
	end)
end

------------------------------------------------------------------ items
function D.giveItem(player, kind, name, toolDelay, mutation)
	local p = profiles[player]
	if not p then return end
	local item = {Id = p.NextId, Type = kind, Name = name, Mutation = mutation}
	p.NextId += 1
	table.insert(p.Items, item)
	if kind == "Animal" then p.Index[name] = true end
	if toolDelay then task.delay(toolDelay, function() if player.Parent then buildTool(player, item) end end)
	else buildTool(player, item) end
	D.sync(player)
	return item
end

-- remove the item a tool stands for (and the tool). Returns the item or nil.
function D.takeItem(player, tool)
	local p = profiles[player]
	local id = tool and tool:GetAttribute("ItemId")
	if not (p and id) then return end
	for i, item in p.Items do
		if item.Id == id then
			table.remove(p.Items, i)
			tool:Destroy()
			D.sync(player)
			return item
		end
	end
end

------------------------------------------------------------------ cash
function D.addCash(player, n)
	local p = profiles[player]
	if not p then return end
	p.Cash += n
	player:SetAttribute("Cash", p.Cash)
end
function D.spend(player, n)
	local p = profiles[player]
	if not p or p.Cash < n then return false end
	p.Cash -= n
	player:SetAttribute("Cash", p.Cash)
	return true
end

------------------------------------------------------------------ load / save
local function load(player)
	if profiles[player] then return end
	local data, failed
	if store then
		for try = 1, 3 do
			local ok, res = pcall(function() return store:GetAsync("u_" .. player.UserId) end)
			if ok then data = res; failed = false; break end
			failed = true
			warn("GameData: load failed for " .. player.Name .. ": " .. tostring(res))
			if tostring(res):find("Studio access") then break end
			task.wait(2)
		end
	end
	local p = defaults()
	if type(data) == "table" then for k, v in data do p[k] = v end end
	p.Strength = math.max(p.Strength or 0, 10)   -- everyone starts at 10 strength
	profiles[player] = p
	noSave[player] = failed or nil   -- couldn't read their save: play on, but don't overwrite it
	player:SetAttribute("Cash", p.Cash)
	player:SetAttribute("DataLoaded", true)
	D.sync(player)
	D.Loaded:Fire(player)
end

D.beforeSave = {}   -- functions(player, profile) other scripts add to write their state in
function D.save(player)
	local p = profiles[player]
	if not (p and store) or noSave[player] then return end
	for _, fn in D.beforeSave do pcall(fn, player, p) end
	local ok, err = pcall(function() store:SetAsync("u_" .. player.UserId, p) end)
	if not ok then warn("GameData: save failed for " .. player.Name .. ": " .. tostring(err)) end
end

Players.PlayerAdded:Connect(load)
for _, pl in Players:GetPlayers() do task.spawn(load, pl) end
Players.PlayerRemoving:Connect(function(player)
	D.save(player)
	profiles[player] = nil
	noSave[player] = nil
end)
game:BindToClose(function()
	local left = 0
	for _, pl in Players:GetPlayers() do
		left += 1
		task.spawn(function() D.save(pl); left -= 1 end)
	end
	local t = os.clock()
	while left > 0 and os.clock() - t < 25 do task.wait(0.2) end
end)
task.spawn(function()
	while true do
		task.wait(120)
		for _, pl in Players:GetPlayers() do task.spawn(D.save, pl) end
	end
end)

return D
