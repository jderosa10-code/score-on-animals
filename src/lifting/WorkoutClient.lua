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
			local t = G.LiftClock(pl, now)      -- real time + what boosts from the tap game added
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

-- white flash when you get on and off the weights (Jacob, 11 Nov 2026): holds white a moment, then fades
local wasLifting = player:GetAttribute("Lifting") ~= nil
local function flashWhite()
	local gui = Instance.new("ScreenGui")
	gui.Name = "LiftFlash"; gui.IgnoreGuiInset = true; gui.DisplayOrder = 100; gui.ResetOnSpawn = false
	local f = Instance.new("Frame")
	f.Size = UDim2.fromScale(1, 1); f.BackgroundColor3 = Color3.new(1, 1, 1); f.BorderSizePixel = 0
	f.BackgroundTransparency = 0.55; f.Parent = gui   -- soft (Jacob: toned down)
	gui.Parent = player:WaitForChild("PlayerGui")
	local tw = game:GetService("TweenService"):Create(f, TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {BackgroundTransparency = 1})
	tw:Play()
	game:GetService("Debris"):AddItem(gui, 0.6)
end

-- pause Roblox's default Animate while you lift (it would fight the pose), resume after
local function onLifting()
	local now = player:GetAttribute("Lifting") ~= nil
	if now ~= wasLifting then flashWhite() end
	wasLifting = now
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
-- STOP button at the top while you lift (HUD.StopLiftHUD, a copy of the Shop button)
local stopGui = hud:WaitForChild("StopLiftHUD", 5)
local stopBtn = stopGui and stopGui:FindFirstChild("StopButton")
if stopBtn then stopBtn.Activated:Connect(function() Lift:FireServer("stop") end) end
local wasHotbar
local function showBar()
	local lifting = player:GetAttribute("Lifting") ~= nil and not player:GetAttribute("InPenalty")
	if stopGui then stopGui.Enabled = lifting end
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

-- keep your own body on the lift spot (pigeon-claude, 11 Nov 2026): you're held by WalkSpeed 0, not anchored,
-- and the lift pose moving the hips made the body slide back a little every rep
do
	local pin
	RunService.Stepped:Connect(function()
		local char = player.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart")
		local started = player:GetAttribute("LiftStart") or 0
		-- wait a moment after starting, so the server's move onto the mat has arrived first
		if not (hrp and player:GetAttribute("Lifting")) or workspace:GetServerTimeNow() - started < 0.35 then pin = nil; return end
		pin = pin or hrp.CFrame
		local p = hrp.Position
		if Vector3.new(p.X - pin.X, 0, p.Z - pin.Z).Magnitude > 0.01 then
			hrp.CFrame = CFrame.new(pin.X, p.Y, pin.Z) * pin.Rotation
			local v = hrp.AssemblyLinearVelocity
			hrp.AssemblyLinearVelocity = Vector3.new(0, v.Y, 0)
		end
	end)
end

------------------------------------------------------------ a new barbell drops in from the sky (Jacob, 11 Nov 2026)
-- Workout sets "DropAt" on the barbell it places after an upgrade: it falls in, lands with a burst and a small shake.
local Debris = game:GetService("Debris")
local VFX = RS:WaitForChild("Assets"):WaitForChild("VFX"):WaitForChild("Effects")
local function burst(name, pos, scale)
	local src = VFX:FindFirstChild(name)
	if not src then return end
	local host = Instance.new("Part")
	host.Anchored, host.CanCollide, host.CanQuery, host.CanTouch, host.Transparency = true, false, false, false, 1
	host.Size = Vector3.one; host.CFrame = CFrame.new(pos); host.Parent = workspace
	local att = Instance.new("Attachment"); att.Parent = host
	for _, e in src:GetDescendants() do
		if e:IsA("ParticleEmitter") then
			local c = e:Clone(); c.Enabled = false
			local kps = {}
			for _, k in c.Size.Keypoints do table.insert(kps, NumberSequenceKeypoint.new(k.Time, k.Value * scale, k.Envelope * scale)) end
			c.Size = NumberSequence.new(kps)
			c.Speed = NumberRange.new(c.Speed.Min * scale, c.Speed.Max * scale)
			c.Parent = att
			c:Emit(math.max(1, math.floor((c:GetAttribute("EmitCount") or 8) + 0.5)))
		end
	end
	Debris:AddItem(host, 4)
end
local function shake(dur, mag)
	local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if not hum then return end
	local t0 = os.clock()
	while os.clock() - t0 < dur do
		local k = 1 - (os.clock() - t0) / dur
		hum.CameraOffset = Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5) * mag * k
		RunService.RenderStepped:Wait()
	end
	hum.CameraOffset = Vector3.zero
end
local function dropIn(bar, plot)
	local at = bar:GetAttribute("DropAt")
	if not at or workspace:GetServerTimeNow() - at > 2 then return end
	local rest = bar:GetPivot()
	local H, T = 45, 0.55
	bar:PivotTo(rest + Vector3.new(0, H, 0))
	local t0 = os.clock()
	while bar.Parent and os.clock() - t0 < T do
		local a = (os.clock() - t0) / T
		bar:PivotTo(rest + Vector3.new(0, H * (1 - a * a), 0))   -- falls faster and faster
		RunService.RenderStepped:Wait()
	end
	if not bar.Parent then return end
	bar:PivotTo(rest)
	local mine = plot.Name == player:GetAttribute("Plot")
	local snd = mine and RS:FindFirstChild("BallLand", true)   -- only your own new weight makes the crash sound
	if snd and snd:IsA("Sound") then
		local c = snd:Clone(); c.Volume = 0.8; c.PlaybackSpeed = 0.7; c.Parent = bar.PrimaryPart or bar:FindFirstChildWhichIsA("BasePart", true)
		if c.Parent then c:Play(); Debris:AddItem(c, 3) end
	end
	burst("Poof", rest.Position + Vector3.new(0, 0.5, 0), 1.6)
	burst("LevelUp", rest.Position + Vector3.new(0, 1.5, 0), 1.2)
	if mine then shake(0.3, 0.35) end
end
plots.DescendantAdded:Connect(function(d)
	if d.Name == "Barbell" and d:IsA("Model") and d.Parent and d.Parent.Name == "WorkoutZone" then
		local plot = d.Parent.Parent
		task.defer(dropIn, d, plot)   -- (DropAt is set before the server parents it, so it arrives with the model)
	end
end)
