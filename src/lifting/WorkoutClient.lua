-- Deadlifts (server: ServerScriptService.Workout).
--  * walk onto your own plot's WeightRack mat -> you start lifting; move or jump to stop
--  * every lifter in the server is animated here, R6 or R15: a stiff-leg deadlift done on the joints in code
--    (legs stay straight, the body hinges at the hips, arms reach for the bar) and the bar rises with them
--  * your own reps are sent to the server at the top of each lift
--  * only your own plot's Upgrade Weights prompt shows
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local player = Players.LocalPlayer
local G = require(RS:WaitForChild("GameConfig"))
local Lift = RS:WaitForChild("GameRemotes"):WaitForChild("Lift")
local plots = workspace:WaitForChild("Plots")

local TILT = math.rad(62)   -- how far the body bends at the bottom
local LIFT = 1.4            -- how high the bar comes up (studs)
local REP = G.RepSeconds
-- one rep: hold at the bottom, pull, hold at the top, lower
local function liftAmount(t)
	t = t % REP
	local a, b, c = 0.35, 1.05, 1.4
	local function ease(x) return x * x * (3 - 2 * x) end
	if t < a then return 0
	elseif t < b then return ease((t - a) / (b - a))
	elseif t < c then return 1
	else return 1 - ease((t - c) / (REP - c)) end
end

local function zoneMat(zone)
	local r = zone and zone:FindFirstChild("WeightRack")
	local best
	for _, p in r and r:GetChildren() or {} do
		if p:IsA("BasePart") and (not best or p.Size.X * p.Size.Z > best.Size.X * best.Size.Z) then best = p end
	end
	return best
end

------------------------------------------------------------ start / stop for you
local armed = true
local lastTry = 0
local function moving(hum) return hum.MoveDirection.Magnitude > 0.1 end
local lastTop = nil
task.spawn(function()
	while true do
		task.wait(0.1)
		local char = player.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart")
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		local plot = plots:FindFirstChild(player:GetAttribute("Plot") or "")
		local m = plot and zoneMat(plot:FindFirstChild("WorkoutZone"))
		-- only your own plot's upgrade prompt
		for _, p in plots:GetChildren() do
			local z = p:FindFirstChild("WorkoutZone")
			local pp = z and z:FindFirstChild("UpgradePrompt", true)
			if pp then pp.Enabled = p == plot end
		end
		if not (hrp and hum and m) then continue end
		local lp = m.CFrame:PointToObjectSpace(hrp.Position)
		local on = math.abs(lp.X) <= m.Size.X / 2 + 0.3 and math.abs(lp.Z) <= m.Size.Z / 2 + 0.3 and lp.Y > -1 and lp.Y < 8
		if player:GetAttribute("Lifting") then
			if moving(hum) or not on then Lift:FireServer("stop") end
		elseif on and (armed or os.clock() - lastTry > 1.5) and not player:GetAttribute("InPenalty") then
			-- (retried while you stay on the mat, in case the server hadn't seen you arrive yet)
			armed = false
			lastTry = os.clock()
			lastTop = nil
			Lift:FireServer("start")
		elseif not on then
			armed = true
		end
	end
end)
UIS.JumpRequest:Connect(function() if player:GetAttribute("Lifting") then Lift:FireServer("stop") end end)

------------------------------------------------------------ animate every lifter
local barRest = {}   -- [barbell model] = resting pivot
local rigs = {}      -- [character] = joints

-- LiftPose = the clean and jerk (pigeon-claude); DeadliftPose is the older move and the fallback
local Pose = require(RS:WaitForChild("LiftPose", 5) or RS:WaitForChild("DeadliftPose"))
local joints, clearPose = Pose.joints, Pose.clear
local function pose(j, f, rest, t) return Pose.apply(j, f, rest, t, REP) end

RunService.Stepped:Connect(function()
	local now = workspace:GetServerTimeNow()
	local active = {}
	for _, pl in Players:GetPlayers() do
		local plotName = pl:GetAttribute("Lifting")
		local char = pl.Character
		local plot = plotName and plots:FindFirstChild(plotName)
		local bar = plot and plot:FindFirstChild("WorkoutZone") and plot.WorkoutZone:FindFirstChild("Barbell")
		if char and bar then
			if not rigs[char] then rigs[char] = joints(char) end
			local j = rigs[char]
			if not barRest[bar] then barRest[bar] = bar:GetPivot() end
			local t = now - (pl:GetAttribute("LiftStart") or now)
			local f = liftAmount(t)
			local rest = barRest[bar]
			-- (GripHeight = where the model's grip bar is; on some barbells it is not the middle of the model)
			local restCentre = rest.Position + Vector3.new(0, bar:GetAttribute("GripHeight") or (bar:GetAttribute("Height") or 4) / 2, 0)
			local y, shift = restCentre.Y, nil
			if j then y, shift = pose(j, f, restCentre, t % REP) end
			bar:PivotTo(rest + Vector3.new(0, y - restCentre.Y, 0) + (shift or Vector3.zero))   -- the bar rides in the hands
			active[char] = true
			active[bar] = true
			-- your own rep: counted once each time you reach the top
			if pl == player then
				local repN = math.floor((t % 1e9 - 1.05) / REP)
				if t % REP >= 1.05 and repN ~= lastTop then
					lastTop = repN
					Lift:FireServer("rep")
				end
			end
		end
	end
	for char, j in rigs do
		if not active[char] then clearPose(j); rigs[char] = nil end
	end
	for bar, rest in barRest do
		if not active[bar] then
			if bar.Parent then bar:PivotTo(rest) end
			barRest[bar] = nil
		end
	end
end)

-- pause Roblox's default Animate while you lift (it would fight the pose), resume after
local function onLifting()
	local char = player.Character
	local animate = char and char:FindFirstChild("Animate")
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local animator = hum and hum:FindFirstChildOfClass("Animator")
	local lifting = player:GetAttribute("Lifting") ~= nil
	if animate then animate.Enabled = not lifting end
	if lifting and animator then for _, t in animator:GetPlayingAnimationTracks() do t:Stop(0.1) end end
end
player:GetAttributeChangedSignal("Lifting"):Connect(onLifting)

------------------------------------------------------------ level bar (HUD.EnergyBarHUD) replaces the hotbar while you lift
local hud = player:WaitForChild("PlayerGui"):WaitForChild("HUD")
local barGui = hud:WaitForChild("EnergyBarHUD")
local hotbar = hud:WaitForChild("HotbarHUD")
local panel = barGui:WaitForChild("EnergyBarPanel")
local bar = panel:WaitForChild("EnergyBar")
local fill = bar:WaitForChild("Fill")
local levelLabel = bar:WaitForChild("LevelLabel")
local progress = bar:WaitForChild("ProgressLabel")
-- the + next to the bar sells nothing yet, so it stays hidden; the 3 boost buttons stay
local add = panel:FindFirstChild("AddButton")
if add then add.Visible = false end
fill.AnchorPoint = Vector2.new(0, 0.5)   -- fill grows from the left
fill.Position = UDim2.fromScale(0, 0.5)
-- these labels change text a lot, so they size themselves (the kit's TextScaler skips FW_TextOwn labels)
for _, l in {levelLabel, progress} do
	l:SetAttribute("FW_TextOwn", true)
	l.TextScaled = true
	local sc = l:FindFirstChild("FW_Scale")
	if sc then sc.Scale = 1 end
end
-- the progress label was sized for "MAX": widen it to the left, same right edge, so "2,519/3,162" fits
local right = progress.Position.X.Scale + progress.Size.X.Scale * (1 - progress.AnchorPoint.X)
progress.AnchorPoint = Vector2.new(1, progress.AnchorPoint.Y)
progress.Position = UDim2.new(right, 0, progress.Position.Y.Scale, 0)
progress.Size = UDim2.fromScale(0.3, progress.Size.Y.Scale)
progress.TextXAlignment = Enum.TextXAlignment.Right
local function refreshBar()
	local lvl = player:GetAttribute("LiftLevel") or 1
	local xp = player:GetAttribute("LiftXP") or 0
	local need = G.LiftXP(lvl)
	levelLabel.Text = "LEVEL " .. lvl
	progress.Text = G.commas(xp) .. "/" .. G.commas(need)
	fill.Size = UDim2.fromScale(math.clamp(xp / need, 0, 1), 1)
end
local wasHotbar
local function showBar()
	local lifting = player:GetAttribute("Lifting") ~= nil and not player:GetAttribute("InPenalty")
	if lifting and not barGui.Enabled then
		wasHotbar = hotbar.Enabled
		hotbar.Enabled = false
		barGui.Enabled = true
	elseif not lifting and barGui.Enabled then
		barGui.Enabled = false
		if wasHotbar ~= false then hotbar.Enabled = true end
	end
	refreshBar()
end
player:GetAttributeChangedSignal("Lifting"):Connect(showBar)
player:GetAttributeChangedSignal("LiftLevel"):Connect(refreshBar)
player:GetAttributeChangedSignal("LiftXP"):Connect(refreshBar)
barGui.Enabled = false
showBar()
