-- Deadlifts at each plot's WorkoutZone (Workspace.Plots.PlotN.WorkoutZone):
--  * walk onto your own WeightRack mat -> WorkoutClient asks to start; you're put behind the bar and lift
--    (every client animates you and the bar), each rep gives XP = the barbell's Power;
--    each level up (GameConfig.LiftXP) gives GameConfig.StrengthPerLevel Strength
--  * move to stop
--  * UpgradeWeightsBtn has a prompt: buy the next barbell (GameConfig.Barbells); the new one appears on the rack
--  * a tag above UpgradeWeightsBtn shows the next barbell's price and XP per rep
-- Saved: profile.Strength, BarbellLevel, LiftLevel, LiftXP. Player attributes: the same + Lifting, LiftStart.
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local SS = game:GetService("ServerStorage")
local D = require(script.Parent:WaitForChild("GameData"))
local G = require(RS:WaitForChild("GameConfig"))
local Remotes = RS:WaitForChild("GameRemotes")
local TEMPLATES = SS:WaitForChild("Barbells")
local plots = workspace:WaitForChild("Plots")

local function notify(p, t) Remotes.Notify:FireClient(p, t) end
local function ownerOf(plot)
	local id = plot:GetAttribute("Owner") or 0
	return id ~= 0 and Players:GetPlayerByUserId(id) or nil
end
local function rack(zone) return zone:FindFirstChild("WeightRack") end
local function mat(zone)
	local r = rack(zone)
	local best
	for _, p in r and r:GetChildren() or {} do
		if p:IsA("BasePart") and (not best or p.Size.X * p.Size.Z > best.Size.X * best.Size.Z) then best = p end
	end
	return best
end

-- put barbell level n on a plot's rack
local function showBarbell(plot, n)
	local zone = plot:FindFirstChild("WorkoutZone")
	if not zone then return end
	local old = zone:FindFirstChild("Barbell")
	if old then old:Destroy() end
	local info = G.Barbells[math.clamp(n, 1, #G.Barbells)]
	local t = TEMPLATES:FindFirstChild(info.Name)
	local m = mat(zone)
	if not (t and m) then return end
	local b = t:Clone()
	b.Name = "Barbell"
	b:SetAttribute("BarbellName", info.Name)
	local top = m.Position.Y + m.Size.Y / 2
	b:PivotTo(CFrame.new(m.Position.X, top, m.Position.Z))
	b.Parent = zone
end

local function updatePrompt(plot)
	local owner = ownerOf(plot)
	local zone = plot:FindFirstChild("WorkoutZone")
	local pp = zone and zone:FindFirstChild("UpgradePrompt", true)
	if not pp then return end
	local p = owner and D.get(owner)
	local n = p and p.BarbellLevel or 1
	local nxt = G.Barbells[n + 1]
	pp.ActionText = nxt and "Upgrade Weights" or "Weights Maxed"
	pp.ObjectText = nxt and (nxt.Name .. "  ·  $" .. G.short(nxt.Cost)) or ""
	local tag = zone:FindFirstChild("UpgradeTag", true)
	if tag then
		tag.Price.Text = nxt and ("$" .. G.short(nxt.Cost)) or "MAXED"
		tag.XP.Text = nxt and ("+" .. G.short(nxt.Power) .. " XP / rep") or ("+" .. G.short(G.Barbells[n].Power) .. " XP / rep")
	end
end

local function setLevel(player, plot)
	local p = D.get(player)
	if not p then return end
	player:SetAttribute("BarbellLevel", p.BarbellLevel)
	player:SetAttribute("Strength", p.Strength)
	player:SetAttribute("LiftLevel", p.LiftLevel)
	player:SetAttribute("LiftXP", p.LiftXP)
	showBarbell(plot, p.BarbellLevel)
	updatePrompt(plot)
end

local function upgrade(plot, player)
	if ownerOf(plot) ~= player then return end
	local p = D.get(player)
	if not p then return end
	local nxt = G.Barbells[p.BarbellLevel + 1]
	if not nxt then notify(player, "Your weights are maxed!") return end
	if not D.spend(player, nxt.Cost) then notify(player, "Need $" .. G.short(nxt.Cost)) return end
	p.BarbellLevel += 1
	setLevel(player, plot)
	notify(player, nxt.Name .. " unlocked! +" .. G.short(nxt.Power) .. " XP per rep")
end

-- lifting
local lastRep = {}
local lastClock = {}   -- [player] = lift clock (GameConfig.LiftClock) at the last counted rep
local function liftSpot(zone, char)
	local b = zone:FindFirstChild("Barbell")
	local m = mat(zone)
	local hum = char:FindFirstChildOfClass("Humanoid")
	local hrp = char:FindFirstChild("HumanoidRootPart")
	if not (m and hum and hrp) then return end
	local top = m.Position.Y + m.Size.Y / 2
	local up = hum.RigType == Enum.HumanoidRigType.R15 and (hum.HipHeight + hrp.Size.Y / 2) or 3
	local bz = b and b:GetPivot().Z or m.Position.Z
	local pos = Vector3.new(m.Position.X, top + up, bz + 1.9)        -- behind the bar, facing it (-Z)
	return CFrame.lookAt(pos, pos - Vector3.new(0, 0, 1))
end
local function stop(player)
	if not player:GetAttribute("Lifting") then return end
	local plot = plots:FindFirstChild(player:GetAttribute("Lifting"))
	player:SetAttribute("Lifting", nil)
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if hrp then
		local hum = char:FindFirstChildOfClass("Humanoid")
		if hum then
			local p = D.get(player)
			hum.WalkSpeed = G.BaseWalkSpeed + (p and p.Rebirths or 0) * G.RebirthSpeed
			hum.JumpPower, hum.AutoRotate = 50, true
		end
		local zone = plot and plot:FindFirstChild("WorkoutZone")
		local m = zone and mat(zone)
		if m then   -- step off the mat toward the walkway so it doesn't start again
			local p = Vector3.new(hrp.Position.X, hrp.Position.Y, m.Position.Z + m.Size.Z / 2 + 2.5)
			char:PivotTo(CFrame.lookAt(p, p + Vector3.new(0, 0, 1)))
		end
	end
end
Remotes.Lift.OnServerEvent:Connect(function(player, what)
	local plot = plots:FindFirstChild(player:GetAttribute("Plot") or "")
	local zone = plot and plot:FindFirstChild("WorkoutZone")
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if what == "start" then
		if player:GetAttribute("Lifting") or player:GetAttribute("InPenalty") then return end
		if not (zone and hrp and ownerOf(plot) == player) then return end
		local m = mat(zone)
		if not m or (Vector3.new(hrp.Position.X - m.Position.X, 0, hrp.Position.Z - m.Position.Z)).Magnitude > 12 then return end
		local hum = char:FindFirstChildOfClass("Humanoid")
		if hum then hum:UnequipTools() end
		local cf = liftSpot(zone, char)
		if not cf then return end
		-- held in place by WalkSpeed 0 (not anchoring, so the client still sees your movement input to stop)
		hum.WalkSpeed, hum.JumpPower, hum.AutoRotate = 0, 0, false
		hrp.AssemblyLinearVelocity = Vector3.zero
		char:PivotTo(cf)
		lastRep[player] = os.clock()
		lastClock[player] = 0
		player:SetAttribute("LiftBoost", nil)
		player:SetAttribute("LiftStart", workspace:GetServerTimeNow())
		player:SetAttribute("Lifting", plot.Name)
	elseif what == "stop" then
		if workspace:GetServerTimeNow() - (player:GetAttribute("LiftStart") or 0) < 0.6 then return end
		stop(player)
	elseif what == "rep" then
		local p = D.get(player)
		if not (p and player:GetAttribute("Lifting")) then return end
		local now = os.clock()
		-- no faster than the animation: one rep of lift time (a boost from the tap game makes that time run faster)
		local clock = G.LiftClock(player, workspace:GetServerTimeNow())
		if clock - (lastClock[player] or 0) < G.RepSeconds * 0.85 then return end
		lastClock[player] = clock
		lastRep[player] = now
		p.LiftXP += G.Barbells[p.BarbellLevel].Power * (player:GetAttribute("Pass_VIP") and G.VIPLiftMulti or 1)   -- VIP lifts faster
		local ups = 0
		while p.LiftXP >= G.LiftXP(p.LiftLevel) do
			p.LiftXP -= G.LiftXP(p.LiftLevel)
			p.LiftLevel += 1
			ups += 1
		end
		if ups > 0 then
			p.Strength += ups * G.StrengthPerLevel
			player:SetAttribute("Strength", p.Strength)
			player:SetAttribute("LiftLevel", p.LiftLevel)
			notify(player, "Level " .. p.LiftLevel .. "! +" .. ups * G.StrengthPerLevel .. " Strength")
		end
		player:SetAttribute("LiftXP", p.LiftXP)
	elseif what == "boost" then
		-- the tap mini-game (StarterGui.HUD.LiftTapHUD): reps run G.LiftBoostSpeed times faster for G.LiftBoostSeconds
		if not player:GetAttribute("Lifting") then return end
		local nowS = workspace:GetServerTimeNow()
		local t = nowS - (player:GetAttribute("LiftStart") or nowS)
		local b = player:GetAttribute("LiftBoost")
		local extra, last = 0, -math.huge
		if typeof(b) == "Vector3" then
			extra = b.X + (G.LiftBoostSpeed - 1) * math.clamp(t - b.Y, 0, math.max(0, b.Z - b.Y))   -- bank what the old boost gave
			last = b.Y
		end
		if t - last < G.LiftBoostMinGap then return end
		player:SetAttribute("LiftBoost", Vector3.new(extra, t, t + G.LiftBoostSeconds))
	end
end)
Players.PlayerRemoving:Connect(function(p) lastRep[p] = nil end)

-- set up every plot: prompt on the button, starter barbell, follow owners
for _, plot in plots:GetChildren() do
	local zone = plot:FindFirstChild("WorkoutZone")
	if zone then
		local btn = zone:FindFirstChild("UpgradeWeightsBtn")
		local part = btn and btn:FindFirstChildWhichIsA("BasePart")
		if part then
			local att = Instance.new("Attachment")
			att.Name = "PromptAtt"
			att.Parent = part
			att.WorldPosition = part.Position + Vector3.new(0, 0.3, 0)   -- right on the button
			local pp = Instance.new("ProximityPrompt")
			pp.Name = "UpgradePrompt"
			pp.HoldDuration = 0
			pp.MaxActivationDistance = 8
			pp.RequiresLineOfSight = false
			pp.Parent = att
			pp.Triggered:Connect(function(player) upgrade(plot, player) end)
		end
		showBarbell(plot, 1)
		updatePrompt(plot)
		plot:GetAttributeChangedSignal("Owner"):Connect(function()
			local owner = ownerOf(plot)
			if owner and D.get(owner) then setLevel(owner, plot) else showBarbell(plot, 1); updatePrompt(plot) end
		end)
	end
end
local function ready(player)
	local plot = plots:FindFirstChild(player:GetAttribute("Plot") or "")
	if plot and D.get(player) and ownerOf(plot) == player then setLevel(player, plot) end
end
D.Loaded.Event:Connect(ready)
local function hook(player)
	player:GetAttributeChangedSignal("Plot"):Connect(function() ready(player) end)
	player.CharacterAdded:Connect(function() player:SetAttribute("Lifting", nil) end)
	ready(player)
end
Players.PlayerAdded:Connect(hook)
for _, pl in Players:GetPlayers() do hook(pl) end
