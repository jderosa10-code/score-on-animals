-- LiftTapClient (pigeon-claude, 2026-11-11). Lives in StarterGui.HUD.LiftTapHUD, next to the frames it drives.
-- 1. The tap mini-game: while you lift, a TAP! target pops up somewhere in TapArea. Hit it before its ring
--    closes and your reps run faster for a few seconds (server: Lift "boost", GameConfig.LiftBoost*).
--    Hit several in a row for a combo; miss one and the combo is gone. AFK lifting still works, just slower.
-- 2. Lift effects, for every lifter you can see: a soft sparkle each time the bar is locked out overhead,
--    a puff when it lands, a big burst + confetti on a level up, a burst on a boost.
-- 3. Lift sounds, for your own lifting only: pull, lockout, landing, level up, boost. The Sound objects
--    are in LiftTapHUD.Sounds: swap a SoundId there to change one.
-- Nothing is built here: every frame is a real instance in the ScreenGui, sized by Scale.
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")
local Debris = game:GetService("Debris")

local player = Players.LocalPlayer
local G = require(RS:WaitForChild("GameConfig"))
local Lift = RS:WaitForChild("GameRemotes"):WaitForChild("Lift")
local FX = RS:WaitForChild("Assets"):WaitForChild("VFX"):WaitForChild("Effects")
local plots = workspace:WaitForChild("Plots")

local gui = script.Parent
local area = gui:WaitForChild("TapArea")
local button = area:WaitForChild("TapButton")
local ring = button:WaitForChild("Timer")
local burstRing = area:WaitForChild("Burst")
local popText = area:WaitForChild("PopText")
local boostBar = gui:WaitForChild("BoostBar")
local fill = boostBar:WaitForChild("Track"):WaitForChild("Fill")
local comboLabel = boostBar:WaitForChild("Combo")
local sounds = gui:WaitForChild("Sounds")

local REP = G.RepSeconds
local RING_TIME = 2.4            -- seconds the circle takes to close in on a target
local GRACE = 0.9                -- after the circle has reached the button you can still hit it for this long (it blinks)
local GAP_MIN, GAP_MAX = 1.2, 2.6  -- seconds between targets
local BUTTON_SIZE = button.Size
local RING_BIG, RING_SMALL = ring.Size, UDim2.fromScale(1.04, 1.04)
local ringStroke = ring:FindFirstChildOfClass("UIStroke")
local RING_SHOW = ringStroke and ringStroke.Transparency or 0

---------------------------------------------------------------- helpers
local function sfx(name, volume, pitch)
	local src = sounds:FindFirstChild(name)
	if not src then return end
	local s = src:Clone()
	s.Volume = src.Volume * (volume or 1)
	s.PlaybackSpeed = src.PlaybackSpeed * (pitch or 1)
	s.Parent = sounds
	SoundService:PlayLocalSound(s)
	Debris:AddItem(s, 6)
end

-- emit(effect, worldPosition, scale, countMul): one burst of an effect from ReplicatedStorage.Assets.VFX.Effects
local function emit(name, pos, scale, countMul)
	local src = FX:FindFirstChild(name)
	if not src then return end
	scale, countMul = scale or 1, countMul or 1
	local att = Instance.new("Attachment")
	att.Parent = workspace.Terrain
	att.WorldPosition = pos
	for _, e in src:GetDescendants() do
		if e:IsA("ParticleEmitter") then
			local c = e:Clone()
			c.Enabled = false
			if scale ~= 1 then
				local kps = {}
				for _, k in c.Size.Keypoints do table.insert(kps, NumberSequenceKeypoint.new(k.Time, k.Value * scale, k.Envelope * scale)) end
				c.Size = NumberSequence.new(kps)
				c.Speed = NumberRange.new(c.Speed.Min * scale, c.Speed.Max * scale)
				c.Acceleration *= scale
			end
			c.Parent = att
			local n = math.max(1, math.round((e:GetAttribute("EmitCount") or 8) * countMul))
			task.delay(e:GetAttribute("EmitDelay") or 0, function() if c.Parent then c:Emit(n) end end)
		end
	end
	Debris:AddItem(att, 5)
end

local function barOf(pl)
	local plot = plots:FindFirstChild(pl:GetAttribute("Lifting") or "")
	local zone = plot and plot:FindFirstChild("WorkoutZone")
	local bar = zone and zone:FindFirstChild("Barbell")
	if not bar then return end
	return bar:GetPivot().Position + Vector3.new(0, bar:GetAttribute("GripHeight") or (bar:GetAttribute("Height") or 3) / 2, 0)
end
local function rootOf(pl)
	local c = pl.Character
	return c and c:FindFirstChild("HumanoidRootPart")
end

---------------------------------------------------------------- the tap target
local active, shownAt, combo = false, 0, 0
local nextSpawn = math.huge
local wasLifting = false

local function hideTarget(hit)
	active = false
	local t = TweenService:Create(button, TweenInfo.new(hit and 0.12 or 0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
		{Size = UDim2.fromScale(0, 0)})
	t.Completed:Once(function() if not active then button.Visible = false end end)
	t:Play()
end

local function showTarget()
	active = true
	shownAt = os.clock()
	button.Position = UDim2.fromScale(0.1 + math.random() * 0.8, 0.14 + math.random() * 0.72)
	button.Size = UDim2.fromScale(0, 0)
	button.Rotation = 0
	ring.Size = RING_BIG
	if ringStroke then ringStroke.Transparency = RING_SHOW end
	button.Visible = true
	TweenService:Create(button, TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Size = BUTTON_SIZE}):Play()
	sfx("TargetPop", 1, 0.95 + math.random() * 0.15)
end

local function screenBurst(at)
	-- a ring that opens out from where you tapped, and a word that floats up
	local r = burstRing:Clone()
	r.Position = at
	r.Size = UDim2.fromScale(BUTTON_SIZE.X.Scale * 0.6, BUTTON_SIZE.Y.Scale * 0.6)
	r.Visible = true
	r.Parent = area
	local stroke = r:FindFirstChildOfClass("UIStroke")
	TweenService:Create(r, TweenInfo.new(0.45, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
		{Size = UDim2.fromScale(BUTTON_SIZE.X.Scale * 2.6, BUTTON_SIZE.Y.Scale * 2.6)}):Play()
	if stroke then TweenService:Create(stroke, TweenInfo.new(0.45), {Transparency = 1}):Play() end
	Debris:AddItem(r, 0.6)
	local p = popText:Clone()
	p.Text = combo >= 2 and ("COMBO x" .. combo .. "!") or "SPEED UP!"
	p.Position = at
	p.Rotation = math.random(-8, 8)
	p.Visible = true
	p.Parent = area
	local ps = p:FindFirstChildOfClass("UIStroke")
	TweenService:Create(p, TweenInfo.new(0.7, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{Position = at - UDim2.fromScale(0, 0.22), TextTransparency = 1}):Play()
	if ps then TweenService:Create(ps, TweenInfo.new(0.7), {Transparency = 1}):Play() end
	Debris:AddItem(p, 0.8)
end

button.MouseButton1Down:Connect(function()
	if not active or not player:GetAttribute("Lifting") then return end
	combo += 1
	local at = button.Position
	hideTarget(true)
	nextSpawn = os.clock() + GAP_MIN + math.random() * (GAP_MAX - GAP_MIN)
	Lift:FireServer("boost")
	screenBurst(at)
	sfx("Boost", 1, math.min(1.5, 1 + (combo - 1) * 0.06))
	local root = rootOf(player)
	if root then emit("Diamond", root.Position + Vector3.new(0, 0.5, 0), 0.8) end
end)

---------------------------------------------------------------- level ups (every player)
local function flash(char)
	local h = Instance.new("Highlight")
	h.FillColor = Color3.fromRGB(255, 240, 150); h.OutlineColor = Color3.new(1, 1, 1)
	h.FillTransparency = 0.25; h.OutlineTransparency = 0; h.DepthMode = Enum.HighlightDepthMode.Occluded
	h.Parent = char
	TweenService:Create(h, TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {FillTransparency = 1, OutlineTransparency = 1}):Play()
	Debris:AddItem(h, 0.7)
end
local function watchLevel(pl)
	local known = pl:GetAttribute("LiftLevel")
	pl:GetAttributeChangedSignal("LiftLevel"):Connect(function()
		local lvl = pl:GetAttribute("LiftLevel")
		local up = known and lvl and lvl > known
		known = lvl
		if not up then return end
		local root = rootOf(pl)
		if not root then return end
		emit("LevelUp2", root.Position, 1)
		emit("Confetti", root.Position + Vector3.new(0, 3, 0), 1)
		flash(pl.Character)
		if pl == player then
			sfx("LevelUp")
			local cam = workspace.CurrentCamera
			local fov = cam.FieldOfView
			cam.FieldOfView = fov + 7       -- a quick punch out, eased back
			TweenService:Create(cam, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {FieldOfView = fov}):Play()
		end
	end)
end
for _, pl in Players:GetPlayers() do watchLevel(pl) end
Players.PlayerAdded:Connect(watchLevel)

---------------------------------------------------------------- every frame
local lastClock = {}     -- [player] = lift clock last frame
local function passed(prev, cur, mark)      -- did the rep pass this moment since last frame?
	return cur > prev and math.floor((cur - mark) / REP) > math.floor((prev - mark) / REP)
end
local auraAt = 0

RunService.Heartbeat:Connect(function()
	local now = workspace:GetServerTimeNow()
	-- rep moments, for every lifter
	for _, pl in Players:GetPlayers() do
		if pl:GetAttribute("Lifting") then
			local cur = G.LiftClock(pl, now)
			local prev = lastClock[pl]
			lastClock[pl] = cur
			if prev and cur - prev < 1 then
				local mine = pl == player
				local fast = G.LiftBoosted(pl, now)
				if mine and passed(prev, cur, 0.18) then sfx("Pull", 1, (fast and 1.15 or 1) * (0.94 + math.random() * 0.12)) end
				if passed(prev, cur, 1.05) then
					local at = barOf(pl)
					if at then emit("Sparkles", at, fast and 0.45 or 0.35, fast and 0.8 or 0.5) end      -- calm: a few small sparks close to the bar
					if mine then sfx("Lockout", 1, (fast and 1.2 or 1) * (0.96 + math.random() * 0.08)) end
				end
				if passed(prev, cur, REP - 0.12) then
					local at = barOf(pl)
					if at then emit("Poof", at - Vector3.new(0, 0.6, 0), 0.3, 0.4) end
					if mine then sfx("Land", 1, 0.94 + math.random() * 0.12) end
				end
			end
		else
			lastClock[pl] = nil
		end
	end

	-- your tap game
	local lifting = player:GetAttribute("Lifting") ~= nil and not player:GetAttribute("InPenalty")
	if lifting and not wasLifting then
		combo = 0
		nextSpawn = os.clock() + 2.2          -- let the first rep start before the first target
	elseif not lifting and wasLifting then
		if active then hideTarget(false) end
		nextSpawn = math.huge
		combo = 0
	end
	wasLifting = lifting
	if lifting then
		local t = os.clock()
		if active then
			local age = t - shownAt
			ring.Size = RING_BIG:Lerp(RING_SMALL, math.clamp(age / RING_TIME, 0, 1))
			if ringStroke then
				-- last chance: the circle sits on the button and blinks until the grace time is up
				ringStroke.Transparency = age > RING_TIME and (math.sin((age - RING_TIME) * 22) > 0 and RING_SHOW or 0.75) or RING_SHOW
			end
			if age >= RING_TIME + GRACE then          -- missed
				hideTarget(false)
				combo = 0
				nextSpawn = t + GAP_MIN + math.random() * (GAP_MAX - GAP_MIN)
				sfx("Miss", 1, 1)
			end
		elseif t >= nextSpawn then
			showTarget()
		end
	end

	-- the boost bar
	local boosted, left = G.LiftBoosted(player, now)
	boosted = boosted and lifting
	boostBar.Visible = boosted
	if boosted then
		fill.Size = UDim2.fromScale(math.clamp(left / G.LiftBoostSeconds, 0, 1), 1)
		comboLabel.Visible = combo >= 2
		comboLabel.Text = "x" .. combo
		-- a little trail of sparkles on the bar while it lasts
		if os.clock() >= auraAt then
			auraAt = os.clock() + 0.35
			local at = barOf(player)
			if at then emit("Sparkles", at, 0.3, 0.3) end
		end
	end
end)
