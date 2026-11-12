-- Studio-only penalty demo (shared). Runs on the client in Play (F5) and on the server in Run (F8).
-- Test pitch at x = -400. In Play YOU are the kicker: the egg hops in, black bars slide in, you back up to the
-- left of the ball and hold. Click (or tap) to run up and kick. Shot 1 is saved, shot 2 scores and the egg hatches.
-- C toggles the TV camera. In Run there is no player, so a stand-in kicker shoots on its own after a pause.
return function(A, isClient)
local RunService = game:GetService("RunService")
local KSP = game:GetService("KeyframeSequenceProvider")
local UIS = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local RS = game:GetService("ReplicatedStorage")
local EggKeeper = require(RS.Keeper.EggKeeper)
local KA = require(RS.Keeper.KeeperAnimator)
local G = require(RS:WaitForChild("GameConfig"))   -- luck roll, strength per egg, ball speed, aim zones
local gameSpeed, gameSpeedTarget = 1, 1            -- whole-game slow motion while you aim
local function DBG() return workspace:GetAttribute("DebugSpeed") or 1 end   -- dev only: slow motion / pause for checking animations
-- hit-stop: a few frozen frames on a big impact (the strike, a save, the net). Camera shake keeps running.
local freezeUntil = 0
local function hitStop(d) freezeUntil = math.max(freezeUntil, os.clock() + d / math.max(DBG(), 0.05)) end
local function frozen() return os.clock() < freezeUntil end
local function waitFreeze() while frozen() do RunService.Heartbeat:Wait() end end
local function step()
	local dt = isClient and RunService.RenderStepped:Wait() or RunService.Heartbeat:Wait()
	return dt * gameSpeed * DBG() * (frozen() and 0.02 or 1)
end

-- the pitch comes from the map: Workspace.Goal (mouth faces -Z) and Workspace.KickArea (the one nearest the goal)
local GOAL_Z = 33.5                                   -- goal line, measured from ORIGIN
local goalModel = workspace:WaitForChild("Goal")
local gcf, gsize = goalModel:GetBoundingBox()
local GOAL_GROUND = gcf.Position.Y - gsize.Y / 2      -- the pitch the goal stands on
local ORIGIN = Vector3.new(gcf.Position.X, GOAL_GROUND, goalModel:GetPivot().Position.Z - GOAL_Z)
local kickArea
for _, p in ipairs(workspace:GetChildren()) do
	if p.Name == "KickArea" and p:IsA("BasePart") then
		if not kickArea or (p.Position - gcf.Position).Magnitude < (kickArea.Position - gcf.Position).Magnitude then kickArea = p end
	end
end
local KICK_GROUND = A:GetAttribute("KickGround") or (kickArea and (kickArea.Position.Y + kickArea.Size.Y / 2)) or GOAL_GROUND
local KICK_FRONT = A:GetAttribute("KickFront") or (kickArea and (kickArea.Position.Z + kickArea.Size.Z / 2)) or (ORIGIN.Z + 13.5)   -- edge facing the goal
local SLOWMO = 0.3
local goal = {cf = CFrame.lookAt(ORIGIN + Vector3.new(0, 0, GOAL_Z + 0.9), ORIGIN), width = 19.8, height = 10}
local SPOT = Vector3.new(ORIGIN.X, KICK_GROUND + 0.9, KICK_FRONT - 3.5)   -- the ball, near the front of the kick area
local BALL_SPEED = 75                            -- studs per second (before slow motion)
local ballModel = workspace:WaitForChild("SoccerBall")
local ballR = 0.9
local ROSTER = G.EggPool                         -- every egg you can roll
local STYLE = {Blobfish = EggKeeper.Styles.Fish}

local folder = Instance.new("Folder"); folder.Name = "PenaltyDemo"; folder.Parent = workspace
-- sounds (ReplicatedStorage.DevDemo.Sounds, free Toolbox audio): sfx(name, volume, pitch, delay)
local SOUNDS = RS:WaitForChild("DevDemo"):WaitForChild("Sounds")
local MASTER_VOLUME = 0.45
local crowdEvent = RS:WaitForChild("DevDemo"):FindFirstChild("CrowdEvent")   -- the stadium crowd reacts to these
local function crowd(what, extra) if crowdEvent then crowdEvent:Fire(what, extra) end end
local function sfx(name, vol, pitch, delay)
	local src = SOUNDS:FindFirstChild(name)
	if not src then return end
	local function go()
		local snd = src:Clone()
		snd.Volume = (vol or 0.6) * MASTER_VOLUME
		snd.PlaybackSpeed = pitch or 1
		snd.Parent = game:GetService("SoundService")
		snd:Play()
		snd.Ended:Connect(function() snd:Destroy() end)
		game:GetService("Debris"):AddItem(snd, 12)
		return snd
	end
	if delay and delay > 0 then task.delay(delay, go) else return go() end
end
-- fade a playing sound out and remove it
local function fadeOut(snd, dur)
	if not snd or not snd.Parent then return end
	game:GetService("TweenService"):Create(snd, TweenInfo.new(dur or 0.3), {Volume = 0}):Play()
	task.delay((dur or 0.3) + 0.05, function() if snd.Parent then snd:Destroy() end end)
end
local riser   -- PERFECT build-up sound, cut when the ball lands
local ballTrail
local camBase

local function ease(t) return t * t * (3 - 2 * t) end
local function easeInOut(t) return t < 0.5 and 4 * t * t * t or 1 - (-2 * t + 2) ^ 3 / 2 end

----------------------------------------------------------------- slow motion, smoothed every frame
local targetScale = 1
local curScale = 1
local tKick
RunService.Heartbeat:Connect(function(dt)
	gameSpeed += (gameSpeedTarget - gameSpeed) * math.min(1, dt * 10)
	if math.abs(gameSpeed - gameSpeedTarget) < 0.003 then gameSpeed = gameSpeedTarget end
	local want = targetScale * gameSpeed * DBG()
	-- dropping into slow motion snaps in fast (a rocket shot would reach the egg before a slow fade); speeding back up eases
	curScale += (want - curScale) * math.min(1, dt * (want < curScale and 18 or 7))
	if DBG() ~= 1 then curScale = want end
	local cur = frozen() and 0.02 * DBG() or curScale
	EggKeeper.timeScale = cur
	if tKick and tKick.IsPlaying then tKick:AdjustSpeed(cur) end
end)

----------------------------------------------------------------- ball
local ballRot = CFrame.identity
-- squash and stretch: shapeK > 1 stretches the ball along shapeAxis, < 1 flattens it (volume kept)
local ballMesh = ballModel:FindFirstChildWhichIsA("BasePart", true)
local BALL_SIZE = ballMesh.Size
local shapeAxis, shapeK = nil, 1
local function ballTo(pos)
	if shapeAxis and math.abs(shapeK - 1) > 0.02 then
		local w = 1 / math.sqrt(shapeK)
		ballMesh.Size = Vector3.new(BALL_SIZE.X * w, BALL_SIZE.Y * w, BALL_SIZE.Z * shapeK)
		local up = math.abs(shapeAxis.Y) > 0.98 and Vector3.xAxis or Vector3.yAxis
		ballModel:PivotTo(CFrame.lookAt(pos, pos + shapeAxis, up))
	else
		if ballMesh.Size ~= BALL_SIZE then ballMesh.Size = BALL_SIZE end
		ballModel:PivotTo(CFrame.new(pos) * ballRot)
	end
end
local function resetBall() ballRot = CFrame.identity; shapeK = 1; ballTo(SPOT) end
resetBall()

local function fly(from, to, dur, arc, onStep)
	local dir = to - from
	local axis = Vector3.yAxis:Cross(dir.Magnitude > 0 and dir.Unit or Vector3.zAxis)
	if axis.Magnitude < 1e-3 then axis = Vector3.xAxis end
	local spin = dir.Magnitude / ballR / dur
	local t = 0
	while true do
		local a = math.min(1, t / dur)
		local pos = from:Lerp(to, a) + Vector3.new(0, (arc or 0) * 4 * a * (1 - a), 0)
		ballTo(pos)
		if onStep and onStep(pos, a) then return pos, true end
		if a >= 1 then return pos, false end
		local dt = step() * math.min(1, EggKeeper.timeScale / math.max(gameSpeed * DBG(), 1e-4))
		ballRot = CFrame.fromAxisAngle(axis.Unit, spin * dt) * ballRot
		t += dt
	end
end

-- a struck shot: it swerves (o.bend, studs sideways at mid flight), rises and dips (o.arc), comes off
-- the boot stretched along its path and rounds off by mid flight, with side spin
local function flyShot(from, to, dur, o, onStep)
	local d = to - from
	local flat = Vector3.new(d.X, 0, d.Z).Unit
	local bend = o.bend or Vector3.zero
	local ctrl = from:Lerp(to, 0.5) + bend * 2 + Vector3.new(0, (o.arc or 0) * 2, 0)
	local function at(a) local u = 1 - a; return from * (u * u) + ctrl * (2 * u * a) + to * (a * a) end
	local axis = (Vector3.yAxis:Cross(flat) + Vector3.yAxis * (bend.X >= 0 and 0.7 or -0.7)).Unit
	local spin = d.Magnitude / ballR / dur * 0.7
	local t = 0
	shapeAxis = flat
	while true do
		local a = math.min(1, t / dur)
		local pos = at(a)
		local nxt = at(math.min(1, a + 0.03)) - pos
		if nxt.Magnitude > 1e-4 then shapeAxis = nxt.Unit end
		shapeK = 1 + (o.stretch or 0.35) * math.exp(-a * 5)
		ballTo(pos)
		if onStep and onStep(pos, a) then shapeK = 1; ballTo(pos); return pos, true end
		if a >= 1 then shapeK = 1; ballTo(pos); return pos, false end
		local dt = step() * math.min(1, EggKeeper.timeScale / math.max(gameSpeed * DBG(), 1e-4))
		ballRot = CFrame.fromAxisAngle(axis, spin * dt) * ballRot
		t += dt
	end
end

----------------------------------------------------------------- kicker: your own character in Play, a stand-in rig in Run
local player = isClient and game:GetService("Players").LocalPlayer
local rig
local char = player and (player.Character or player.CharacterAdded:Wait())
if char then char:WaitForChild("HumanoidRootPart"); char:WaitForChild("Humanoid") end
if char then
	rig = char   -- you kick yourself (R6 or R15); takeControl() grabs you when you step onto the kick area
else
	-- Run (F8) has no player: an R6 stand-in kicks instead
	rig = A.KickerRigR6:Clone()
	rig.Name = "Kicker"
	for _, p in ipairs(rig:GetDescendants()) do if p:IsA("BasePart") then p.CanCollide = false end end
	rig.Parent = folder
end
local hum = rig.Humanoid
local hrp = rig.HumanoidRootPart
local ownChar = rig == char
if not ownChar then hrp.Anchored = true end
local animator = hum:FindFirstChildOfClass("Animator") or Instance.new("Animator", hum)
if not ownChar then for _, t in ipairs(animator:GetPlayingAnimationTracks()) do t:Stop(0) end end
local function load(id) local a = Instance.new("Animation"); a.AnimationId = id; return animator:LoadAnimation(a) end
-- R15 avatars: Roblox's default R15 idle / walk / cheer, and natural R15 kick moves from
-- ServerStorage.RBX_ANIMSAVES.KickerRigR15, copied here as KickerAnimsR15 by ServerScriptService.PenaltyDemo
local isR15 = hum.RigType == Enum.HumanoidRigType.R15
local KA6 = isR15 and A.KickerAnimsR15 or A.KickerAnimsR6
-- the kick clips are unpublished KeyframeSequences: a real track in Studio, ReplicatedStorage.KSTrack in a live game
local KSTrack = require(RS:WaitForChild("KSTrack"))
local function loadKS(name) return KSTrack.load(animator, rig, KA6[name]) end
local tIdle = isR15 and load("rbxassetid://507766666") or load("rbxassetid://180435571"); tIdle.Looped = true; tIdle.Priority = Enum.AnimationPriority.Idle        -- R6 default idle
local tWalk = isR15 and load("rbxassetid://507777826") or load("rbxassetid://180426354"); tWalk.Looped = true; tWalk.Priority = Enum.AnimationPriority.Movement    -- R6 default walk
local tCheer = isR15 and load("rbxassetid://507770677") or load("rbxassetid://129423030"); tCheer.Priority = Enum.AnimationPriority.Action                         -- R6 default cheer
-- footwork + strikes: KickerAnimKit's set (ServerStorage.KickerAnimKit builds it) when it is there, else the older clips
local function clip(new, old) return KA6:FindFirstChild(new) and new or old end
local N_BACK, N_SET, N_RUN = clip("PenaltyRetreat3", "PenaltyRetreat"), clip("PenaltySet3", "PenaltySet"), clip("PenaltyApproach3", "PenaltyApproach")
local N_KICK, N_PERFECT = clip("PenaltyStrike3", "PenaltyLacesDrive"), clip("PenaltyPerfect3", "PenaltyScissorVolley")
local tBack = loadKS(N_BACK)
tBack.Looped = false
tBack.Priority = Enum.AnimationPriority.Action
local tStance = loadKS(N_SET)
tStance.Looped = true
tStance.Priority = Enum.AnimationPriority.Action
local tRun = loadKS(N_RUN)
tRun.Looped = false
tRun.Priority = Enum.AnimationPriority.Action
local strikes = {}
for _, name in {N_KICK, N_PERFECT} do
	-- The authored contact offset scales with the avatar. This also works on characters
	-- whose animated joints are constraints or have not replicated yet.
	local seq = KA6:WaitForChild(name)
	local track = loadKS(name)
	track.Looped = false
	track.Priority = Enum.AnimationPriority.Action2
	strikes[name] = {
		track = track,
		time = seq:GetAttribute("ContactTime"),
		toeRatio = seq:GetAttribute("ContactOffsetRatio"),
		flickRatio = seq:GetAttribute("FlickOffsetRatio"),
		flickTime = seq:GetAttribute("FlickTime"),
		chargeTime = seq:GetAttribute("ChargeTime"),     -- PERFECT: the wound-up frame that is held for a beat
	}
end
tKick = strikes[N_KICK].track
local tCeleb = loadKS("Celebrate"); tCeleb.Priority = Enum.AnimationPriority.Action3 -- jump, spin, arms out
if not ownChar then tIdle:Play() end
local inRound = not isClient     -- in Run there is no player: the stand-in just keeps going
local ours = {[tIdle] = true, [tWalk] = true, [tRun] = true, [tCheer] = true, [tKick] = true, [tBack] = true, [tStance] = true, [strikes[N_PERFECT].track] = true, [tCeleb] = true}
animator.AnimationPlayed:Connect(function(t) if inRound and ownChar and not ours[t] then t:Stop(0) end end)

local HRP_OFF = isR15 and (hum.HipHeight + hrp.Size.Y / 2) or (rig["Right Leg"].Size.Y + rig.Torso.Size.Y / 2)   -- root height above the floor
local HRP_Y = KICK_GROUND + HRP_OFF
local BALL_POS = Vector3.new(SPOT.X + 0.6, HRP_Y, SPOT.Z - 2.4)
local retreatDir = Vector3.new(0.36, 0, -0.933).Unit
local WAIT_POS = BALL_POS + retreatDir * KA6[N_BACK]:GetAttribute("TravelByHeight") * HRP_OFF

local yawNow = 0
local function setRig(pos, yaw) yawNow = yaw; hrp.CFrame = CFrame.new(pos) * CFrame.Angles(0, math.pi + yaw, 0) end
if not ownChar then setRig(BALL_POS, 0) end

-- stepping on the kick area hands your character to the penalty; walking off gives it back
local controls, saved
local function takeControl()
	if not player then return end
	pcall(function()
		local pm = player.PlayerScripts:FindFirstChild("PlayerModule")
		if pm then controls = require(pm):GetControls(); controls:Disable() end
	end)
	if not ownChar then return end
	local animate = rig:FindFirstChild("Animate")
	if animate then animate.Enabled = false end
	saved = {hum.WalkSpeed, hum.JumpPower, hum.JumpHeight}
	hum.WalkSpeed, hum.JumpPower, hum.JumpHeight = 0, 0, 0
	for _, t in ipairs(animator:GetPlayingAnimationTracks()) do if not ours[t] then t:Stop(0.2) end end
	hrp.Anchored = true
	-- stand up straight, facing the goal, where you are
	setRig(Vector3.new(hrp.Position.X, HRP_Y, hrp.Position.Z), 0)
end
local function releaseControl()
	if not player then return end
	if ownChar then
		for t in pairs(ours) do t:Stop(0.2) end
		hrp.Anchored = false
		if saved then hum.WalkSpeed, hum.JumpPower, hum.JumpHeight = saved[1], saved[2], saved[3] end
		local animate = rig:FindFirstChild("Animate")
		if animate then animate.Enabled = true end
	end
	if controls then controls:Enable() end
end
local animSpeedApplied = 1
RunService.Heartbeat:Connect(function()
	local sp = gameSpeed * DBG() * (frozen() and 0.02 or 1)
	if sp == animSpeedApplied then return end
	animSpeedApplied = sp
	for t in pairs(ours) do if t.IsPlaying and t ~= tKick and t ~= tRun and t ~= tBack then t:AdjustSpeed(sp) end end
end)
-- The sequence stores the distance traveled at each pose. Use the same clock for both
-- so the support boot stays planted as the character crosses the pitch.
local function playFootwork(track, sequence, destination, heading)
	local frames = sequence:GetKeyframes()
	table.sort(frames, function(a,b) return a.Time < b.Time end)
	local origin, initialYaw = hrp.Position, yawNow
	local deltaYaw = (heading-initialYaw+math.pi) % (2*math.pi)-math.pi
	local duration = frames[#frames].Time
	local elapsed, index = 0, 1
	track:Play(0.09, 1, 0)
	while true do
		while index < #frames and elapsed >= frames[index+1].Time do
			index += 1
			local sound = frames[index]:GetAttribute("Footstep")
			if sound then sfx(sound, track == tBack and 0.14 or 0.23, 1) end
		end
		local current = frames[index]
		local travel = current:GetAttribute("Travel")
		local following = frames[index+1]
		if following then
			local alpha = (elapsed-current.Time)/(following.Time-current.Time)
			travel += (following:GetAttribute("Travel")-travel)*alpha
		end
		setRig(origin:Lerp(destination, travel), initialYaw + deltaYaw*ease(math.min(1,elapsed/0.22)))
		if track.Length > 0 then track.TimePosition = math.min(elapsed, track.Length-.0001) end
		if elapsed >= duration then break end
		elapsed = math.min(duration, elapsed+step())
	end
end

local function onKickArea()
	local kcf, ksz = A:GetAttribute("KickCF"), A:GetAttribute("KickSize")
	local c = player and player.Character
	local r = c and c:FindFirstChild("HumanoidRootPart")
	if not (kcf and ksz and r) then return false end
	local lp = kcf:PointToObjectSpace(r.Position)
	return math.abs(lp.X) <= ksz.X / 2 and math.abs(lp.Z) <= ksz.Z / 2 and lp.Y > -ksz.Y / 2 and lp.Y < ksz.Y / 2 + 8
end

local function moveRig(to, dur, track, baseSpeed, easeFn, faceYaw)
	local from, y0 = hrp.Position, yawNow
	local dist = (to - from).Magnitude
	local t = 0
	easeFn = easeFn or easeInOut
	track:Play(0.25)
	while t < dur do
		local a = easeFn(t / dur)
		local a2 = easeFn(math.min(1, (t + 1 / 60) / dur))
		local speed = (a2 - a) * dist * 60
		track:AdjustSpeed(math.sign(baseSpeed) * math.clamp(speed / math.abs(baseSpeed), 0.2, 1.6))
		setRig(from:Lerp(to, a), y0 + ((faceYaw or y0) - y0) * ease(math.min(1, t / dur * 1.5)))
		t += step()
	end
	setRig(to, faceYaw or y0)
end

----------------------------------------------------------------- camera + black bars (Play only)
local camShot = "wide"
local camSide = 1        -- which post the "save" shot sits beside (+1 = +X)
local showResult = function() end
local shakeAmp, shakeT = 0, 0
local function shake(amount, dur) shakeAmp = math.max(shakeAmp, amount); shakeT = math.max(shakeT, dur or 0.3) end
local camFov = 55       -- the camera eases toward this; each moment of the penalty sets it
local setBars = function() end
local setTvCam = function() end
local fovPunch = function() end
local camEgg, camEggDist = nil, 11                    -- the "egg" shot follows this part from this far away                       -- a quick zoom in that eases back out
local nameLbl
local showOdds = function() end                       -- "1/28" at the bottom, in the timing-result style
local aimShot = function() return nil end             -- slow motion + click the goal; returns the spot (goal space) or nil
local clearAim = function() end
-- this round: the egg (the server rolls it), the aim-zone seed, which try, and the shot that scored
local roundEgg, roundSeed, tryNo, scoreShot = nil, 0, 1, nil
local roundMut = nil          -- this round's mutation (Gold / Diamond / Rainbow) or nil, rolled by the server
local aimZones = nil          -- this shot's green/red zones (GameConfig.AimZones), shown while aiming
local hideZones = function() end   -- removes the zones at the strike; your aim marker stays
local showCaption = function() end -- big text in the TimingResult style: showCaption(key, text, colour, y, height)
local hideCaption = function() end -- hideCaption(key, fadeSeconds)
-- full-screen fade: black when you step onto the kick area, a white flash when you teleport home
local fadeFrame
local function screenFade(color, alpha, t)
	if not (isClient and player) then return end
	if not fadeFrame then
		local g = Instance.new("ScreenGui")
		g.Name = "ScreenFade"; g.IgnoreGuiInset = true; g.ResetOnSpawn = false; g.DisplayOrder = 100
		g.Parent = player:WaitForChild("PlayerGui")
		fadeFrame = Instance.new("Frame")
		fadeFrame.Size = UDim2.fromScale(1, 1); fadeFrame.BorderSizePixel = 0; fadeFrame.BackgroundTransparency = 1
		fadeFrame.Parent = g
	end
	if color then fadeFrame.BackgroundColor3 = color end
	TweenService:Create(fadeFrame, TweenInfo.new(t, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {BackgroundTransparency = 1 - alpha}):Play()
end
local function luckText(l)
	local s = string.format("%.2f", l):gsub("0+$", ""):gsub("%.$", "")
	return s .. "X LUCK"
end
local function myLuck() return (player and player:GetAttribute("Luck")) or folder:GetAttribute("Luck") or 1 end
local function myStrength() return (player and player:GetAttribute("Strength")) or G.StartStrength end
-- returns the timing zone the player stopped on: 1 Perfect, 2 Great, 3 Good, 4 Weak, 5 Miss
local waitForClick = function() task.wait(1.8); return math.random(1, 5) end
if isClient then
	local cam = workspace.CurrentCamera
	local tvCam = false
	-- shots that cut in hard; the rest (wide, ball) glide like before
	local CUT_SHOTS = {walk = true, hold = true, aim = true, kicker = true, powerKick = true, celebrate = true, egg = true, save = true, net = true, claim = true}
	local lastShot
	local inShow = false
	UIS.InputBegan:Connect(function(i, gp)
		if gp or i.KeyCode ~= Enum.KeyCode.C or not inShow then return end
		tvCam = not tvCam
		cam.CameraType = tvCam and Enum.CameraType.Scriptable or Enum.CameraType.Custom
	end)
	fovPunch = function(amount) if tvCam then cam.FieldOfView -= amount end end
	setTvCam = function(on)
		inShow, tvCam = on, on
		camBase = nil
		if not on then cam.CameraType = Enum.CameraType.Custom; cam.FieldOfView = 70 end
	end
	-- cinematic letterbox
	local gui = Instance.new("ScreenGui")
	gui.Name = "PenaltyBars"; gui.IgnoreGuiInset = true; gui.ResetOnSpawn = false; gui.DisplayOrder = 50
	local function bar(top)
		local f = Instance.new("Frame")
		f.BackgroundColor3 = Color3.new(0, 0, 0); f.BorderSizePixel = 0
		f.AnchorPoint = Vector2.new(0, top and 0 or 1)
		f.Position = UDim2.fromScale(0, top and 0 or 1)
		f.Size = UDim2.fromScale(1, 0)
		f.Parent = gui
		return f
	end
	local topBar, botBar = bar(true), bar(false)
	gui.Parent = player:WaitForChild("PlayerGui")
	setBars = function(size)
		local info = TweenInfo.new(0.5, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
		for _, f in ipairs({topBar, botBar}) do TweenService:Create(f, info, {Size = UDim2.fromScale(1, size)}):Play() end
	end
	-- the word that pops up when you stop the bar (StarterGui.TimingResult)
	local WORDS = {
		{"PERFECT!", nil},                                  -- rainbow
		{"GREAT!", Color3.fromRGB(170, 255, 40)},
		{"GOOD", Color3.fromRGB(255, 225, 40)},
		{"BAD", Color3.fromRGB(255, 150, 30)},
		{"MISS", Color3.fromRGB(255, 50, 50)},
	}
	local resultTok = 0
	showResult = function(zone)
		local rg = player.PlayerGui:FindFirstChild("TimingResult")
		local lbl = rg and rg:FindFirstChild("Result")
		if not lbl then return end
		resultTok += 1
		local tok = resultTok
		local w = WORDS[zone]
		local rainbow = lbl:FindFirstChild("Rainbow")
		local shadow = lbl:FindFirstChild("Shadow")
		lbl.Text = w[1]; if shadow then shadow.Text = w[1] end
		lbl.TextColor3 = w[2] or Color3.new(1, 1, 1)
		if rainbow then rainbow.Enabled = (w[2] == nil) end
		lbl.TextTransparency = 0
		lbl:FindFirstChildOfClass("UIStroke").Transparency = 0
		if shadow then shadow.TextTransparency = 0.55 end
		lbl.Rotation = math.random(-6, 6)
		lbl.Visible = true
		local sc = lbl:FindFirstChildOfClass("UIScale")
		task.spawn(function()
			local t = 0
			while resultTok == tok and t < 1.5 do
				local dt = RunService.RenderStepped:Wait()
				t += dt
				-- pop: 0 -> 1.25 -> 1, then a little pulse; perfect scrolls its rainbow
				local pop = t < 0.12 and (t / 0.12) * 1.25 or (t < 0.25 and 1.25 - (t - 0.12) / 0.13 * 0.25 or 1 + 0.03 * math.sin(t * 12))
				if sc then sc.Scale = pop end
				if rainbow and rainbow.Enabled then rainbow.Offset = Vector2.new(((t * 0.8) % 2) - 1, 0) end
				if t > 1.1 then
					local f = (t - 1.1) / 0.4
					lbl.TextTransparency = f
					lbl:FindFirstChildOfClass("UIStroke").Transparency = f
					if shadow then shadow.TextTransparency = 0.55 + 0.45 * f end
				end
			end
			if resultTok == tok then lbl.Visible = false end
		end)
	end
	local RARITY_TEXT = {
		Common = Color3.fromRGB(150, 255, 110), Uncommon = Color3.fromRGB(60, 240, 210), Rare = Color3.fromRGB(70, 160, 255),
		Epic = Color3.fromRGB(205, 80, 255), Legendary = Color3.fromRGB(255, 205, 30), Mythic = Color3.fromRGB(255, 70, 130),
	}   -- Secret / Admin (and anything rarer) get the rainbow, like PERFECT
	-- captions (TAP TO KICK!, your luck, the egg you won): clones of the TimingResult label, one per key
	local caps = {}
	showCaption = function(key, text, color, y, h)
		local l = caps[key]
		if not (l and l.Parent) then
			local src = player.PlayerGui:FindFirstChild("TimingResult")
			local res = src and src:FindFirstChild("Result")
			if not res then return end
			local g = Instance.new("ScreenGui")
			g.Name = "Caption_" .. key; g.ResetOnSpawn = false; g.DisplayOrder = 41
			g.Parent = player.PlayerGui
			l = res:Clone(); l.Name = "Text"
			local sh = l:FindFirstChild("Shadow"); if sh then sh:Destroy() end
			l.Parent = g
			caps[key] = l
		end
		l.Position = UDim2.fromScale(0.5, y or 0.5); l.Size = UDim2.fromScale(0.5, h or 0.07)
		local rb = l:FindFirstChild("Rainbow"); if rb then rb.Enabled = color == nil end
		l.Text = text; l.TextColor3 = color or Color3.new(1, 1, 1); l.TextTransparency = 0; l.Rotation = 0
		local st = l:FindFirstChildOfClass("UIStroke"); if st then st.Transparency = 0 end
		l.Visible = true
		local sc = l:FindFirstChildOfClass("UIScale")
		if sc then sc.Scale = 0.6; TweenService:Create(sc, TweenInfo.new(0.25, Enum.EasingStyle.Back), {Scale = 1}):Play() end
	end
	hideCaption = function(key, fade)
		local l = caps[key]
		if not (l and l.Parent and l.Visible) then return end
		if not fade then l.Visible = false; return end
		local st = l:FindFirstChildOfClass("UIStroke")
		TweenService:Create(l, TweenInfo.new(fade), {TextTransparency = 1}):Play()
		if st then TweenService:Create(st, TweenInfo.new(fade), {Transparency = 1}):Play() end
		task.delay(fade, function() if l.TextTransparency > 0.95 then l.Visible = false end end)
	end
	local oddsTok = 0
	local oddsLbl
	showOdds = function(text, rarity, final, eggName, mutation)
		if not oddsLbl then
			local src = player.PlayerGui:FindFirstChild("TimingResult")
			if not src then return end
			local g = src:Clone()
			g.Name = "EggOdds"
			g.DisplayOrder = 40
			g.Parent = player.PlayerGui
			oddsLbl = g:FindFirstChild("Result")
			if not oddsLbl then return end
			local sh = oddsLbl:FindFirstChild("Shadow")   -- one layer only: the shadow faded out after the text
			if sh then sh:Destroy() end
			-- the egg's name (and mutation) just above the odds, shown on the reveal
			nameLbl = oddsLbl:Clone()
			nameLbl.Name = "EggName"
			nameLbl.Position = UDim2.fromScale(0.5, 0.805)
			nameLbl.Size = UDim2.fromScale(0.34, 0.06)
			nameLbl.Visible = false
			local rb = nameLbl:FindFirstChild("Rainbow")
			if rb then rb.Enabled = false end
			nameLbl.TextColor3 = Color3.new(1, 1, 1)
			nameLbl.Parent = g
			oddsLbl.Position = UDim2.fromScale(0.5, 0.87)
			oddsLbl.Size = UDim2.fromScale(0.22, 0.065)
		end
		local lbl = oddsLbl
		oddsTok += 1
		local tok = oddsTok
		if nameLbl then nameLbl.Visible = false end
		if text == nil then lbl.Visible = false; return end
		local rainbow, shadow = lbl:FindFirstChild("Rainbow"), lbl:FindFirstChild("Shadow")
		local stroke, sc = lbl:FindFirstChildOfClass("UIStroke"), lbl:FindFirstChildOfClass("UIScale")
		local col = RARITY_TEXT[rarity]
		lbl.Text = text; if shadow then shadow.Text = text end
		lbl.TextColor3 = col or Color3.new(1, 1, 1)
		if rainbow then rainbow.Enabled = col == nil end
		lbl.TextTransparency = 0
		if stroke then stroke.Transparency = 0 end
		if shadow then shadow.TextTransparency = 0.55 end
		lbl.Rotation = 0
		lbl.Visible = true
		local nStroke, nScale
		if nameLbl and final and eggName then
			nameLbl.Text = (mutation and (mutation .. " ") or "") .. eggName .. " Egg"
			nameLbl.TextTransparency = 0
			nStroke = nameLbl:FindFirstChildOfClass("UIStroke")
			nScale = nameLbl:FindFirstChildOfClass("UIScale")
			if nStroke then nStroke.Transparency = 0 end
			nameLbl.Visible = true
		end
		local peak, rest = final and 1.35 or 1.15, final and 1.12 or 1
		task.spawn(function()
			local t = 0
			while oddsTok == tok do
				local dt = RunService.RenderStepped:Wait()
				t += dt
				local pop = t < 0.1 and (t / 0.1) * peak or (t < 0.22 and peak - (t - 0.1) / 0.12 * (peak - rest) or rest)
				if sc then sc.Scale = pop end
				if nScale then nScale.Scale = pop end
				if rainbow and rainbow.Enabled then rainbow.Offset = Vector2.new(((t * 0.8) % 2) - 1, 0) end
				if final and t > 2.2 then
					local f = math.min(1, (t - 2.2) / 0.4)
					lbl.TextTransparency = f
					if stroke then stroke.Transparency = f end
					if nameLbl then nameLbl.TextTransparency = f end
					if nStroke then nStroke.Transparency = f end
					if shadow then shadow.TextTransparency = 0.55 + 0.45 * f end
					if f >= 1 then lbl.Visible = false; if nameLbl then nameLbl.Visible = false end; break end
				end
			end
		end)
	end
	-- AIM: after the timing bar the whole game goes slow; hover the goal to see the target, click to lock it
	local TARGET_IMG = "rbxassetid://132576202596882"
	local AIM_TOP = 8.5                     -- highest aimable point (under the crossbar)
	local aimPart
	-- AIM ZONES: Jacob's aim UI reads folder attribute "AimZones" (JSON list of {kind, x, y, r} in goal studs,
	-- x from the goal's centre, y from the ground) while it is set. Until that UI exists, flat green/red discs
	-- on the goal stand in for it (turn them off with the workspace attribute AimZonePlaceholder = false).
	local zoneParts = {}
	local function clearZones()
		for _, z in zoneParts do z:Destroy() end
		table.clear(zoneParts)
		folder:SetAttribute("AimZones", nil)
	end
	local function showZones(zones)
		clearZones()
		if not zones then return end
		folder:SetAttribute("AimZones", game:GetService("HttpService"):JSONEncode(zones))
		if workspace:GetAttribute("AimZonePlaceholder") == false then return end
		for _, z in zones do
			local d = Instance.new("Part")
			d.Name = "AimZonePlaceholder"; d.Shape = Enum.PartType.Cylinder
			d.Anchored = true; d.CanCollide = false; d.CanQuery = false; d.CanTouch = false; d.CastShadow = false
			d.Material = Enum.Material.Neon; d.Transparency = 0.55
			d.Color = z.kind == "green" and Color3.fromRGB(60, 230, 90) or Color3.fromRGB(235, 60, 60)
			d.Size = Vector3.new(0.05, z.r * 2, z.r * 2)
			d.CFrame = goal.cf * CFrame.new(z.x, z.y, z.kind == "green" and -0.5 or -0.45) * CFrame.Angles(0, math.rad(90), 0)
			d.Parent = folder
			table.insert(zoneParts, d)
		end
	end
	clearAim = function() if aimPart then aimPart:Destroy(); aimPart = nil end; clearZones() end
	hideZones = clearZones
	local function goalPoint(pos, isViewport)
		local ray = isViewport and cam:ViewportPointToRay(pos.X, pos.Y) or cam:ScreenPointToRay(pos.X, pos.Y)
		local n = goal.cf.LookVector
		local planeP = (goal.cf * CFrame.new(0, 0, -0.4)).Position
		local d = ray.Direction:Dot(n)
		if math.abs(d) < 1e-4 then return end
		local tt = (planeP - ray.Origin):Dot(n) / d
		if tt <= 0 then return end
		local w = ray.Origin + ray.Direction * tt
		local l = goal.cf:PointToObjectSpace(w)
		if math.abs(l.X) > goal.width / 2 - 0.7 or l.Y < 0.7 or l.Y > AIM_TOP then return end
		return Vector2.new(l.X, l.Y), w
	end
	aimShot = function()
		clearAim()
		local p = Instance.new("Part")
		p.Name = "AimTarget"; p.Anchored = true; p.CanCollide = false; p.CanQuery = false; p.CanTouch = false
		p.Transparency = 1; p.Size = Vector3.new(0.2, 0.2, 0.2); p.Parent = folder
		local bb = Instance.new("BillboardGui")
		bb.Size = UDim2.new(2.8, 0, 2.8, 0); bb.AlwaysOnTop = true; bb.LightInfluence = 0; bb.Enabled = false
		bb.Adornee = p; bb.Parent = p
		local img = Instance.new("ImageLabel")
		img.Size = UDim2.fromScale(1, 1); img.BackgroundTransparency = 1; img.Image = TARGET_IMG; img.ImageTransparency = 0.55
		img.Parent = bb
		aimPart = p
		showZones(aimZones)
		gameSpeedTarget = 0.12
		camShot = "aim"; camFov = 30
		crowd("aim")
		setBars(0)
		sfx("WhooshBig", 0.35, 0.6)
		local chosen
		local con = UIS.InputBegan:Connect(function(i, gp)
			if gp or chosen then return end
			local touch = i.UserInputType == Enum.UserInputType.Touch
			if i.UserInputType == Enum.UserInputType.MouseButton1 or touch then
				local v, w
				if touch then v, w = goalPoint(Vector2.new(i.Position.X, i.Position.Y), false)
				else v, w = goalPoint(UIS:GetMouseLocation(), true) end
				if v then chosen = v; p.Position = w end
			end
		end)
		while not chosen do
			local auto = folder:GetAttribute("AutoAim")
			if typeof(auto) == "Vector2" then
				chosen = auto
				p.Position = (goal.cf * CFrame.new(auto.X, auto.Y, -0.4)).Position
				break
			end
			-- PC: the faded target follows the mouse while it is over the goal
			local v, w = goalPoint(UIS:GetMouseLocation(), true)
			if v then p.Position = w; bb.Enabled = true else bb.Enabled = false end
			RunService.RenderStepped:Wait()
		end
		con:Disconnect()
		-- locked: the target goes solid and stays; the game speeds back up
		bb.Enabled = true
		img.ImageTransparency = 0
		bb.Size = UDim2.new(3.6, 0, 3.6, 0)
		TweenService:Create(bb, TweenInfo.new(0.25, Enum.EasingStyle.Back), {Size = UDim2.new(2.8, 0, 2.8, 0)}):Play()
		sfx("BarPop", 0.7, 1.3)
		sfx("Whoosh", 0.5, 1.2)
		gameSpeedTarget = 1
		camShot = "kicker"; camFov = 60
		setBars(0.09)
		return chosen
	end
	-- zone edges in the Figma bar (px from the top of an 855 px bar)
	local EDGES = {0, 87, 208, 393, 610, 855}
	local BAR_H = 855
	local function zoneAt(y) for i = 1, 5 do if y < EDGES[i + 1] then return i end end return 5 end
	waitForClick = function()
		local tg = player.PlayerGui:FindFirstChild("TimingBar")
		local line = tg and tg:FindFirstChild("Line", true)
		if tg then tg.Enabled = true end
		local clicked = false
		local con = UIS.InputBegan:Connect(function(i, gp)
			if gp then return end
			if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then clicked = true end
		end)
		-- the marker sweeps up and down at a constant speed (no slowing at the ends)
		local t, y = 0, BAR_H - 13
		local PERIOD = 1.1                                                -- seconds for bottom -> top -> bottom
		showCaption("tap", "TAP TO KICK!", Color3.new(1, 1, 1), 0.86, 0.075)
		while not clicked and not folder:GetAttribute("Go") do
			t += step()
			local ph = (t / PERIOD) % 1
			local p = ph < 0.5 and ph * 2 or 2 - ph * 2                      -- 0 -> 1 -> 0, straight lines
			y = (BAR_H - 13) - p * (BAR_H - 26)       -- the marker's centre goes from the very bottom to the very top
			if line then line.Position = UDim2.fromScale(0, y / BAR_H) end
		end
		hideCaption("tap")
		local forced = folder:GetAttribute("Go")
		folder:SetAttribute("Go", nil)
		con:Disconnect()
		local zone = typeof(forced) == "number" and forced or zoneAt(y)
		showResult(zone)
		local popPitch = ({1.35, 1.15, 1.0, 0.8, 0.65})[zone]
		sfx("BarPop", 0.8, popPitch)
		if zone == 1 then sfx("BarPop", 0.7, 1.6, 0.08); sfx("WhooshBig", 0.5, 1.1) end
		-- flash the zone it stopped on, then hide the bar
		if tg then
			for _, f in ipairs(tg:GetDescendants()) do
				if f:IsA("Frame") and f:GetAttribute("Zone") == zone then
					local inner = f:FindFirstChild("Inner")
					local st = inner and inner:FindFirstChildOfClass("UIStroke")
					if st then
						st.Transparency = 0; st.Thickness = 4
						task.delay(0.5, function() st.Thickness = 2; st.Transparency = 0.35 end)
					end
				end
			end
			task.delay(0.6, function() tg.Enabled = false end)
		end
		return zone
	end
	-- camera shots: "wide" (egg coming in), "kicker" (over the shoulder, follows you), "ball" (follows the shot)
	local goalMid = ORIGIN + Vector3.new(0, 4, GOAL_Z)
	RunService:BindToRenderStep("PenaltyCam", Enum.RenderPriority.Camera.Value + 1, function(dt)
		if not tvCam then return end
		cam.CameraType = Enum.CameraType.Scriptable
		local want, fov
		local k = hrp.Position
		if camShot == "egg" and camEgg and camEgg.Parent then
			-- low, in front of the egg and a little to the side, creeping in as it gets close
			local p = camEgg.Position
			want = CFrame.lookAt(p + Vector3.new(-3, 1.2, -camEggDist), p + Vector3.new(0, 0.4, 0))
		elseif camShot == "aim" then
			want = CFrame.lookAt(Vector3.new(k.X - 9, k.Y + 1, k.Z - 9), goalMid:Lerp(k, 0.06) + Vector3.new(0, 1.2, 0))
		elseif camShot == "walk" then
			-- low and back, looking up at the player so you see the feet
			want = CFrame.lookAt(k + Vector3.new(-7.5, 0.35, -8.5), k:Lerp(SPOT, 0.2))
		elseif camShot == "celebrate" then
			-- low and in front of him (he has spun round to face this way), so you see the celebration
			want = CFrame.lookAt(Vector3.new(k.X - 2.5, k.Y + 0.6, k.Z - 8.5), k + Vector3.new(0, 0.6, 0))
		elseif camShot == "save" then
			-- goal-side: low, just outside the post the shot is going to, so the egg dives TOWARD the
			-- camera and the ball comes into the same frame (the old chase cam left the egg a far-off dot)
			-- (it leans toward the ball as it arrives, so a top-corner shot stays in frame)
			local b = ballModel:GetPivot().Position
			local w = math.clamp((b.Z - (goalMid.Z - 24)) / 24, 0, 1) * 0.45
			want = CFrame.lookAt(goalMid + Vector3.new(camSide * 12.5, -1.8, -9), (goalMid + Vector3.new(camSide * 2.5, -0.6, 0.5)):Lerp(b, w))
		elseif camShot == "claim" then
			-- behind you, looking up the pitch: the egg flies in from the goal and lands in your hands
			want = CFrame.lookAt(Vector3.new(k.X - 3.5, k.Y + 1.0, k.Z - 11), k + Vector3.new(0, 3.2, 0))
		elseif camShot == "net" then
			-- the goal itself: low in front of goal, from the other side, looking across the fallen egg
			-- at the ball in the net (from the "save" spot the near post hides the ball)
			local b = ballModel:GetPivot().Position
			want = CFrame.lookAt(goalMid + Vector3.new(-camSide * 3.5, -1.7, -9), b:Lerp(goalMid, 0.4))
		elseif camShot == "hold" then
			want = CFrame.lookAt(Vector3.new(k.X - 5.2, k.Y + 3, k.Z - 12.5), goalMid)
		elseif camShot == "powerKick" then
			-- On the kicking-foot side, keep the ball and the planted leg in the same shot.
			local ball = ballModel:GetPivot().Position
			-- (when the ball is flicked up for the PERFECT volley the shot tilts up with it, so the leap stays in frame)
			local focus = k:Lerp(ball, 0.32) + Vector3.yAxis*(0.5 + math.max(0, ball.Y - SPOT.Y)*0.5)
			want = CFrame.lookAt(k + Vector3.new(-9, 0.8, -6), focus)
		elseif camShot == "kicker" or camShot == "ball" then
			-- behind and over the right shoulder (your right is -X here), kept low for drama
			local eye, look
			if camShot == "ball" then
				-- moved right and turned left onto the ball as it's struck
				local b = ballModel:GetPivot().Position
				local away = math.clamp(((b - SPOT) * Vector3.new(1, 0, 1)).Magnitude / 20, 0, 1)
				eye = Vector3.new(k.X - 6.5, k.Y + 2.2, k.Z - 7):Lerp(Vector3.new(b.X - 4, b.Y + 2.5, b.Z - 10), away)
				look = b:Lerp(goalMid, 0.15)
			else
				eye = k + Vector3.new(-6.5, 1.15, -8.5)
				look = k:Lerp(SPOT, 0.5) + Vector3.new(0, 0.45, 0)
			end
			want = CFrame.lookAt(eye, look)
		else
			want = CFrame.lookAt(ORIGIN + Vector3.new(-14, 9, 8), ORIGIN + Vector3.new(0, 3.5, 30))
		end
		local a = math.min(1, dt * (camShot == "ball" and 9 or 4))
		-- snap cuts (Jacob): changing to one of these shots jumps straight there instead of gliding
		if camShot ~= lastShot then
			if CUT_SHOTS[camShot] and lastShot ~= nil then a = 1; cam.FieldOfView = camFov end
			lastShot = camShot
		end
		camBase = (camBase or cam.CFrame):Lerp(want, a)
		local off = CFrame.identity
		if shakeT > 0 then
			shakeT -= dt
			local k = shakeAmp * math.clamp(shakeT / 0.3, 0, 1)
			off = CFrame.new((math.random() - 0.5) * k, (math.random() - 0.5) * k, 0)
				* CFrame.Angles(0, 0, (math.random() - 0.5) * k * 0.05)
			if shakeT <= 0 then shakeAmp = 0 end
		end
		cam.CFrame = camBase * off
		cam.FieldOfView += (camFov - cam.FieldOfView) * math.min(1, dt * 2.5)
	end)
end

----------------------------------------------------------------- VFX (uses the effects already in ReplicatedStorage.Assets.VFX.Effects)
local Debris = game:GetService("Debris")
local FX = RS:WaitForChild("Assets"):WaitForChild("VFX"):WaitForChild("Effects")
-- burst(effectName, part, worldPos?, scale?, countMul?): the effect sits on that part (at worldPos on it, or its centre)
local function burst(name, part, pos, scale, countMul)
	local src = FX:FindFirstChild(name)
	if not src or not part then return end
	scale = scale or 1
	local att = Instance.new("Attachment")
	att.Parent = part
	att.WorldPosition = pos or part.Position
	for _, e in ipairs(src:GetDescendants()) do
		if e:IsA("ParticleEmitter") then
			local c = e:Clone()
			c.Enabled = false
			if scale ~= 1 then
				local kps = {}
				for _, k in ipairs(c.Size.Keypoints) do table.insert(kps, NumberSequenceKeypoint.new(k.Time, k.Value * scale, k.Envelope * scale)) end
				c.Size = NumberSequence.new(kps)
				c.Speed = NumberRange.new(c.Speed.Min * scale, c.Speed.Max * scale)
				c.Acceleration *= scale
			end
			c.Parent = att
			local n = math.max(1, math.floor((c:GetAttribute("EmitCount") or 8) * (countMul or 1) + 0.5))
			local d = c:GetAttribute("EmitDelay")
			if d and d > 0 then task.delay(d, function() if c.Parent then c:Emit(n) end end) else c:Emit(n) end
		end
	end
	Debris:AddItem(att, 4)
end
-- dust only for the egg: puffs at the bottom of the egg part
local function eggDust(egg, scale)
	local p = egg.part
	if not p or not p.Parent then return end
	burst("Poof", p, Vector3.new(p.Position.X, ORIGIN.Y + 0.3, p.Position.Z), scale or 0.4, 0.6)
end

-- a glowing streak behind the ball
do
	local bp = ballModel:FindFirstChildWhichIsA("BasePart", true)
	local a0 = Instance.new("Attachment"); a0.Position = Vector3.new(0, 0.45, 0); a0.Parent = bp
	local a1 = Instance.new("Attachment"); a1.Position = Vector3.new(0, -0.45, 0); a1.Parent = bp
	local tr = Instance.new("Trail")
	tr.Attachment0, tr.Attachment1 = a0, a1
	tr.Lifetime = 0.22
	tr.LightEmission, tr.LightInfluence = 1, 0
	tr.FaceCamera = true
	tr.Color = ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(150, 210, 255))
	tr.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.15), NumberSequenceKeypoint.new(1, 1)})
	tr.WidthScale = NumberSequence.new({NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 0.1)})
	tr.Enabled = false
	tr.Parent = bp
	ballTrail = tr
end

-- a ball that comes down keeps bouncing a couple of times, with a thud on each bounce
local function settleBall(from, dir)
	local p = from
	local horiz = Vector3.new(dir.X, 0, dir.Z)
	for i, hgt in ipairs({1.2, 0.45}) do
		sfx("BallLand", 0.55 / i, 1 + 0.1 * i)
		local to = p + horiz * (2.2 / i)
		fly(p, to, 0.32 / i, hgt)
		p = to
	end
	sfx("BallLand", 0.2, 1.3)
end

-- the net: real vertex flex through EditableMesh, so the strands bulge around the ball
local AS = game:GetService("AssetService")
local NETS = {}
for _, p in ipairs(workspace.Goal:GetDescendants()) do if p:IsA("MeshPart") and p:GetAttribute("Net") then table.insert(NETS, p) end end
local netData = {}
local warnedNet = false
local function prepNet(part)
	if netData[part] ~= nil then return netData[part] end
	netData[part] = false
	local mp
	local ok, res = pcall(function()
		local em = AS:CreateEditableMeshAsync(Content.fromUri(part.MeshId))
		local ids = em:GetVertices()     -- errors if Mesh/Image APIs are off in Game Settings > Security
		local orig, mn, mx = {}, Vector3.one * math.huge, -Vector3.one * math.huge
		for _, id in ipairs(ids) do local v = em:GetPosition(id); orig[id] = v; mn = mn:Min(v); mx = mx:Max(v) end
		mp = AS:CreateMeshPartAsync(Content.fromObject(em))
		local ms = mx - mn
		local sc = Vector3.new(part.Size.X / math.max(ms.X, 1e-4), part.Size.Y / math.max(ms.Y, 1e-4), part.Size.Z / math.max(ms.Z, 1e-4))
		return {em = em, ids = ids, orig = orig, center = (mn + mx) / 2, sc = sc, part = part}
	end)
	if not ok then
		if mp then mp:Destroy() end
		if not warnedNet then warnedNet = true; warn("Net flex is using the simple version. For the real bulge turn on Game Settings > Security > Allow Mesh / Image APIs.", res) end
		return false
	end
	mp.Name = part.Name .. "_Flex"
	mp.Anchored, mp.CanCollide, mp.CanQuery, mp.CanTouch = true, false, false, false
	mp.Size, mp.CFrame = part.Size, part.CFrame
	mp.TextureID, mp.Material, mp.Color = part.TextureID, part.Material, part.Color
	mp.Parent = folder
	part.Transparency = 1
	netData[part] = res
	return res
end
task.spawn(function() for _, p in ipairs(NETS) do prepNet(p) end end)

-- bulge the net at worldPos along dir; returns how far the net is pushed at time t (for the ball to ride it)
local function netAmp(t, A)
	if t < 0.1 then return A * (t / 0.1) * (2 - t / 0.1) end
	local u = t - 0.1
	return A * math.exp(-4.5 * u) * math.cos(11 * u)
end
local function flexNet(part, worldPos, dir, A, radius, onStep)
	local d = prepNet(part)
	local t, DUR = 0, 1.4
	if not d then
		local base = part.CFrame
		while t < DUR do
			local a = netAmp(t, A)
			part.CFrame = base + dir * (a * 0.45)
			if onStep then onStep(a) end
			t += step()
		end
		part.CFrame = base
		return
	end
	local lp = part.CFrame:PointToObjectSpace(worldPos)
	local ldir = part.CFrame:VectorToObjectSpace(dir)
	local hit = {}
	for _, id in ipairs(d.ids) do
		local v = (d.orig[id] - d.center) * d.sc
		local dist = (Vector3.new(v.X, v.Y, v.Z) - lp).Magnitude
		if dist < radius then
			local w = 1 - (dist / radius) ^ 2
			table.insert(hit, {id, w * w})
		end
	end
	local off = ldir / d.sc        -- local studs -> mesh units
	while t < DUR do
		local a = netAmp(t, A)
		for _, h in ipairs(hit) do d.em:SetPosition(h[1], d.orig[h[1]] + off * (a * h[2])) end
		if onStep then onStep(a) end
		t += step() * math.max(EggKeeper.timeScale, 0.5)
	end
	for _, h in ipairs(hit) do d.em:SetPosition(h[1], d.orig[h[1]]) end
end

-- where a shot through the mouth meets the net
local netParams = RaycastParams.new()
netParams.FilterType = Enum.RaycastFilterType.Include
netParams.FilterDescendantsInstances = NETS
local function netHit(from, through)
	local d0 = (through - from).Unit
	local dir = Vector3.new(d0.X * 0.3, d0.Y * 0.35, d0.Z).Unit
	local r = workspace:Raycast(through, dir * 30, netParams)
	if r then return r.Position, r.Instance, dir end
	return through + dir * 4, nil, dir
end

----------------------------------------------------------------- one penalty
-- is the ball touching the egg? (uses the egg's real size, an ellipsoid)
local function touchingEgg(egg, p)
	local e = egg.part
	local lp = e.CFrame:PointToObjectSpace(p)
	local h = e.Size / 2 + Vector3.one * ballR * 0.8
	return (lp.X / h.X) ^ 2 + (lp.Y / h.Y) ^ 2 + (lp.Z / h.Z) ^ 2 <= 1
end

-- perfect = true: the timing bar hit PERFECT -> the kicker coils and whips the strike across their body
local function shoot(egg, target, willSave, perfect, zone)
	setBars(0.07)
	camShot = "walk"; camFov = 49
	tIdle:Stop(0.12)
	local toBall = hrp.Position - WAIT_POS
	playFootwork(tBack, KA6[N_BACK], WAIT_POS, math.atan2(toBall.X, toBall.Z))
	tStance:Play(0.09)
	tBack:Stop(0.09)
	camShot = "hold"
	setBars(0.025); camFov = 40
	zone = waitForClick()
	aimZones = roundEgg and G.AimZones(roundEgg, roundSeed + tryNo) or nil   -- new zones every shot
	if perfect == nil then perfect = zone == 1 end
	if willSave == nil then willSave = zone >= 4 end
	if perfect then
		-- build-up: a riser that climbs from the click until the ball hits the net
		riser = sfx("Riser", 0.15, 0.9)
		if riser then
			game:GetService("TweenService"):Create(riser, TweenInfo.new(2.4, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
				{Volume = 0.95 * MASTER_VOLUME, PlaybackSpeed = 1.15}):Play()
		end
	end
	if target == nil then
		local side = math.random() < 0.5 and -1 or 1
		if willSave then
			target = Vector2.new(egg.state.x + side * math.random(1, 3), 2)       -- weak: straight at the egg
		elseif perfect then
			target = Vector2.new(side * 8.5, 7.5)                                 -- top corner
		else
			target = Vector2.new(side * math.random(6, 8), math.random(3, 6))
		end
	end
	setBars(0.09); camFov = 60
	camShot = "kicker"
	egg:ready()
	local aimed = aimShot()
	if aimed then target = aimed end
	local world = (goal.cf * CFrame.new(target.X, target.Y, -0.4)).Position
	local direction = (world - SPOT) * Vector3.new(1, 0, 1)
	direction = direction.Unit
	local strike = perfect and strikes[N_PERFECT] or strikes[N_KICK]
	tKick = strike.track
	local avatarSize = Vector3.new(hrp.Size.X, HRP_OFF, HRP_OFF)
	local localToe = (strike.flickRatio or strike.toeRatio) * avatarSize
	local height = HRP_Y + localToe.Y - SPOT.Y
	local depth = math.sqrt(math.max(0, ballR*ballR-height*height))*0.94
	-- wide-bodied avatars: keep the ball clear of the belly (the boot then stops a little short of it)
	local chest = rig:FindFirstChild("UpperTorso")
	local belly = chest and math.max(0, chest.Size.Z/2 - 0.5) or 0
	local contactPoint = SPOT-direction*(depth + (strike.flickTime and 0 or belly*0.6))
	-- Approach at an angle. Align the swinging instep with the ball along that line.
	local heading, plant = yawNow, hrp.Position
	for _ = 1, 4 do
		local toe = CFrame.Angles(0, math.pi+heading, 0):VectorToWorldSpace(localToe)
		plant = Vector3.new(contactPoint.X-toe.X, HRP_Y, contactPoint.Z-toe.Z)
		local path = plant-hrp.Position
		heading = math.atan2(path.X,path.Z)
	end
	camShot = perfect and "powerKick" or "kicker"
	camFov = perfect and 49 or 54
	tStance:Stop(0.10)
	playFootwork(tRun, KA6[N_RUN], plant, heading)
	local releaseSpot = SPOT
	if strike.flickTime then
		local boot = CFrame.Angles(0, math.pi+heading, 0):VectorToWorldSpace(strike.toeRatio*avatarSize)
		releaseSpot = plant + boot + direction*(ballR*0.92 + belly)
	end
	local contact = false
	local marker = tKick:GetMarkerReachedSignal("Contact"):Connect(function() contact = true end)
	tKick:Play(0.055, 1, curScale)
	tRun:Stop(0.065)
	local elapsed, flicked, charged = 0, false, false
	while not contact and tKick.TimePosition < strike.time and elapsed < strike.time + 0.25 do
		elapsed += step()
		local clock = tKick.Length > 0 and tKick.TimePosition or elapsed
		if strike.chargeTime and not charged and clock >= strike.chargeTime then
			-- PERFECT: fully wound up in the air, held for a beat before the smash
			charged = true
			camFov = 45
			burst("Gold", ballMesh, nil, 0.7)
			sfx("WhooshBig", 0.7, 1.45)
			sfx("BarPop", 0.6, 1.8)
			shake(0.3, 0.3)
			hitStop(0.3)
		end
		if strike.flickTime then
			local u = math.clamp((clock-strike.flickTime)/(strike.time-strike.flickTime), 0, 1)
			if u > 0 then
				if not flicked then
					flicked = true
					sfx("Bounce", 0.30, 1.26)
					sfx("Whoosh", 0.40, 1.12)
				end
				local rise = math.max(0,releaseSpot.Y-SPOT.Y)
				if strike.chargeTime then
					-- popped up fast, hangs while the kicker spins under it, drops onto the boot
					local flat = SPOT:Lerp(releaseSpot, 1 - (1 - u) ^ 4)
					ballTo(Vector3.new(flat.X, SPOT.Y + rise*((1 - (1 - u) ^ 2.4) + 0.2*math.sin(math.pi*u)), flat.Z))
				else
					ballTo(SPOT:Lerp(releaseSpot,u) + Vector3.yAxis*(rise*u*(1-u)))
				end
			end
		end
	end
	marker:Disconnect()
	-- the kick's strength = your Strength x timing x aim zone. Below what this egg needs, it saves the ball.
	local kickStrength = 100
	if isClient and roundEgg then
		kickStrength = myStrength() * (G.ZoneStrength[zone] or 1) * (aimZones and G.aimMult(aimZones, target.X, target.Y) or 1)
		willSave = kickStrength < G.StrengthFor(roundEgg) * G.mutNeed(roundMut)
		scoreShot = {zone = zone, x = target.X, y = target.Y, try = tryNo}
	end
	local hitPos, hitNet, dir = netHit(releaseSpot, world)
	local ballPart = ballMesh
	local blast = perfect and not willSave      -- far more power than the egg can handle: the ball takes the egg with it
	-- more strength = faster, flatter ball: a little lob at 10, a bullet at the top (GameConfig.ballSpeed / ballArc)
	local speed = isClient and roundEgg and G.ballSpeed(kickStrength) or (perfect and BALL_SPEED * 1.3 or BALL_SPEED)
	local shotDir = (world - releaseSpot).Unit
	-- THE STRIKE: the ball flattens on the boot for a few frozen frames, then it is gone
	hideZones()                      -- the aim zones go at the kick; the aim marker stays
	burst("Diamond", ballPart, nil, perfect and 0.8 or 0.5)
	sfx("Kick", perfect and 1 or 0.85, perfect and 0.85 or 1)
	crowd("kick", perfect)
	if perfect then
		burst("Rainbow", ballPart, nil, 0.6)
		sfx("CrowdGasp", 0.9, 1.05, 0.05)
	end
	shake(perfect and 1 or 0.5, 0.25)
	shapeAxis = shotDir; shapeK = perfect and 0.55 or 0.68
	ballTo(releaseSpot + shotDir * 0.2)
	hitStop(perfect and 0.12 or 0.075)
	waitFreeze()
	sfx(perfect and "WhooshBig" or "Whoosh", perfect and 0.8 or 0.55, perfect and 0.9 or 1.15)
	ballTrail.Enabled = true
	local flight = (world - releaseSpot).Magnitude / speed
	egg.atBall, egg.holdAtBall = false, blast
	-- a save is decided by strength, so the egg always gets there (however far the shot is from it)
	local reach0 = egg.stats.reach
	if willSave then egg.stats.reach = 99 end
	task.spawn(function() egg:dive(target, willSave or blast, flight) end)
	egg.stats.reach = reach0
	camSide = target.X >= 0 and 1 or -1
	local cut = false
	local pos = flyShot(releaseSpot, world, flight, {bend = Vector3.new(camSide * (perfect and 0.5 or 2.2), 0, 0),
		arc = isClient and roundEgg and G.ballArc(kickStrength) or (perfect and 0.5 or 1.7), stretch = perfect and 0.55 or 0.35}, function(p, a)
		if a >= 0.24 and not cut and camShot ~= "ball" then
			camShot = "ball"; camFov = perfect and 36 or 42
		end
		-- slow motion as the ball reaches the egg, for every kick (pigeon: "I like seeing it go slo mo when the egg gets hit").
		-- Strength still sets how fast the ball leaves the boot; the window is ~0.3 s of flight so rockets slow down in time too.
		if targetScale == 1 and (world - p).Magnitude < math.max(18, speed * 0.3) then
			targetScale = perfect and SLOWMO * 0.73 or SLOWMO
		end
		if not cut and a > 0.5 then cut = true; camShot = "save"; camFov = 44 end      -- cut to the goal-side camera for the dive
		return (willSave or blast) and a > 0.6 and touchingEgg(egg, p)
	end)
	if willSave then
		-- SAVED: a frozen beat with the ball flattened on the egg, then it spins away
		egg:bounce(0.36)
		shapeAxis = shotDir; shapeK = 0.7; ballTo(pos)
		hitStop(0.09)
		fadeOut(riser, 0.15); riser = nil
		sfx("EggHit", 0.9, 1.05)
		sfx("Bounce", 0.8, 0.9)
		sfx("CrowdAww", 0.55, 1, 0.15)
		crowd("save")
		burst("Gold", egg.part, pos:Lerp(egg.part.Position, 0.3), 0.6)
		shake(0.8, 0.35)
		waitFreeze()
		shapeK = 1
		local away = (pos - egg.part.Position) * Vector3.new(1, 0, 0)
		local side = away.Magnitude > 0.1 and away.Unit or Vector3.new(math.random() < 0.5 and -1 or 1, 0, 0)
		local land = Vector3.new(pos.X, GOAL_GROUND + ballR, pos.Z) + side * 8 + Vector3.new(0, 0, -7)
		targetScale = 1; camFov = 58
		fly(pos, land, 0.75, 3)
		ballTrail.Enabled = false
		settleBall(land, land - pos)
		tKick:Stop(0.4); tIdle:Play(0.4)
		task.wait(0.6)
		setBars(0)
		camShot = "wide"; camFov = 55
		return false
	end
	local eggDown = false
	if blast then
		-- BLAST: far too much power. The ball goes straight through the egg and carries it into the net.
		shapeAxis = shotDir; shapeK = 0.6; ballTo(pos)
		egg:bounce(0.45)
		hitStop(0.14)
		sfx("EggHit", 1, 0.8); sfx("Kick", 0.9, 0.6); sfx("CrowdGasp", 0.8, 1.1)
		burst("Complete", egg.part, pos, 1.3); burst("Rainbow", egg.part, pos, 0.9); burst("Diamond", ballPart, nil, 0.9)
		shake(1.3, 0.5)
		camFov = 36
		waitFreeze()
		shapeK = 1
		task.spawn(function()
			-- all the way back to the net (the goal is deep), minus the egg's own half width
			local depth = math.max(3, (hitPos - egg.part.Position):Dot(goal.cf.LookVector * -1) - egg.H * 0.45)
			egg:blasted(depth, function(e)
				-- the egg slams into the net beside the ball
				if hitNet then task.spawn(flexNet, hitNet, e.part.Position + dir * 1.5, dir, 2.6, 6) end
				burst("Poof", e.part, nil, 0.8); sfx("NetHit", 0.8, 0.55); shake(0.9, 0.35)
			end)
			egg:dazed()
			eggDown = true
			for i = 1, 4 do      -- seeing stars
				if not (egg.part and egg.part.Parent) then break end
				burst("Sparkles", egg.part, egg.part.Position + Vector3.new(0, egg.H * 0.6, 0), 0.8)
				task.wait(0.5)
			end
		end)
	else
		-- BEATEN: it finishes its dive and skid, then gets up, looks back at the ball in its net and sags
		task.spawn(function()
			task.wait(1.05)
			if egg.part and egg.part.Parent then egg:defeated() end
		end)
	end
	-- GOAL: the ball carries on into the net, which bulges around it
	local endPos = hitPos - dir * ballR
	pos = fly(pos, endPos, (endPos - pos).Magnitude / speed, 0)
	hitStop(0.05)
	camShot = "net"                          -- cut to the goal as the net takes it
	targetScale = 1; camFov = blast and 42 or 46
	burst("Confetti", ballPart, nil, perfect and 1.2 or 0.9)
	sfx("ConfettiPop", 0.7, 1, 0.02)
	sfx("NetHit", 0.9, 0.7)
	if riser then fadeOut(riser, 0.12); riser = nil end
	if perfect then sfx("PerfectSting", 0.8, 1) end
	sfx("CrowdGoal", perfect and 0.9 or 0.75)
	crowd("goal", perfect)
	burst("Complete", ballPart, nil, perfect and 1.4 or 1)
	burst("Sparkles", ballPart, nil, 1.2)
	shake(perfect and 1 or 0.7, 0.4)
	local start = ballModel:GetPivot().Position
	task.spawn(function()
		if hitNet then flexNet(hitNet, hitPos, dir, blast and 3 or 2.3, blast and 5.5 or 4.5, function(a) ballTo(start + dir * math.max(a, -0.3)) end) end
		ballTrail.Enabled = false
		local p0 = ballModel:GetPivot().Position
		local floor = Vector3.new(p0.X, ORIGIN.Y + ballR, p0.Z - 1)
		fly(p0, floor, 0.35, 0.2)
		settleBall(floor, Vector3.new(0, 0, -1))
	end)
	if not perfect then
		-- normal goal: stay on the goal for the ball in the net and the beaten egg getting up, looking
		-- back at it and sagging. The egg flying into your hands (claimEgg) is the celebration.
		task.wait(0.6)
		tKick:Stop(0.3); tIdle:Play(0.3)
		task.wait(2.2)
		return true
	end
	if blast then
		-- hold on the goal until the egg has finished tumbling out of the net
		local t0 = os.clock()
		while not eggDown and os.clock() - t0 < 5 do task.wait() end
		task.wait(0.5)
	end
	-- PERFECT celebration: recover from the strike, then jump, spin to face the camera and fling the arms out
	task.wait(0.5)
	tKick:Stop(0.25)
	task.wait(0.35)
	camShot = "celebrate"; camFov = 45
	tCeleb:Play(0.15)
	sfx("Whoosh", 0.45, 1.3, 0.25)
	local y0, t = yawNow, 0
	local torso = rig:FindFirstChild("Torso") or rig:FindFirstChild("UpperTorso") or hrp
	local head = rig:FindFirstChild("Head") or hrp
	local popped = false
	burst("Sparkles", hrp, hrp.Position - Vector3.new(0, HRP_OFF - 0.3, 0), 1)       -- sparkle at his feet as he jumps
	while t < 0.8 do
		local a = math.clamp((t - 0.25) / 0.5, 0, 1)
		setRig(hrp.Position, y0 + math.pi * (a * a * (3 - 2 * a)))
		if not popped and a > 0.35 then
			-- confetti showers out of him mid-turn
			popped = true
			burst("Confetti", head, head.Position + Vector3.new(0, 1.5, 0), 1.1, 1.5)
			sfx("ConfettiPop", 0.8, 1.05)
		end
		t += step()
	end
	setRig(hrp.Position, y0 + math.pi)
	-- facing the camera: confetti cannons on both sides, his own burst and a sparkle ring
	local right = hrp.CFrame.RightVector
	burst("Confetti", torso, torso.Position + right * 2.5, 1.2, 1.6)
	burst("Confetti", torso, torso.Position - right * 2.5, 1.2, 1.6)
	burst("Confetti", torso, nil, 1, 1.2)
	burst("Complete", torso, nil, 0.9)
	burst("Sparkles", head, head.Position + Vector3.new(0, 1, 0), 1.3)
	if perfect then burst("Rainbow", torso, nil, 0.8) end
	sfx("ConfettiPop2", 0.8, 1)
	sfx("ConfettiPop2", 0.65, 1.12, 0.07)
	shake(0.35, 0.25)
	task.wait(1.8)
	setBars(0)
	-- turn back round for the next one
	t = 0
	while t < 0.4 do setRig(hrp.Position, y0 + math.pi * (1 - (t / 0.4))); t += step() end
	setRig(hrp.Position, y0)
	camShot = "wide"; camFov = 55
	tIdle:Play(0.3)
	return true
end

do  -- the locked target stays up until the shot is over
	local shootInner = shoot
	shoot = function(...)
		local r = shootInner(...)
		clearAim()
		return r
	end
end

-- YOU WON IT: the beaten egg gets up, launches itself across the pitch in one big spinning arc and
-- lands in your hands above your head. Then it is yours (Backpack) and you take it home to hatch.
local function claimEgg(egg)
	local p = egg.part
	if not (p and p.Parent) then return end
	-- first: which egg you won, and NEW! if that animal isn't in your Index yet (HUDClient: _G.SOA_IndexFound)
	if isClient and roundEgg then
		local ER = require(RS.DevDemo.EggRoll)
		local r = ER.rarityOf(roundEgg, A.Eggs)
		local hex = ER.Colors and ER.Colors[r] and ER.Colors[r][1]
		showCaption("got", G.mutLabel(roundMut, roundEgg .. " Egg"), hex and Color3.fromHex(hex) or Color3.new(1, 1, 1), 0.17, 0.085)
		local found = _G.SOA_IndexFound and _G.SOA_IndexFound(G.AnimalForEgg(roundEgg))
		if not found then showCaption("new", "NEW!", Color3.fromRGB(255, 225, 50), 0.245, 0.06) end
		task.wait(0.8)
		task.delay(1.6, function() hideCaption("got", 0.35); hideCaption("new", 0.35) end)
	end
	egg:take()
	egg:standUp(0.3)
	egg:take()
	local head = rig:FindFirstChild("Head") or hrp
	setRig(hrp.Position, 0)
	camShot = "claim"; camFov = 52
	setBars(0.07)
	tCheer:Stop(0.1); tIdle:Play(0.2)
	sfx("Whoosh", 0.55, 0.8)
	burst("Sparkles", p, nil, 1)
	burst("Poof", p, Vector3.new(p.Position.X, ORIGIN.Y + 0.3, p.Position.Z), 0.5)
	local from, size0 = p.Position, p.Size
	local faceMe = goal.cf.Rotation * CFrame.Angles(0, -math.pi / 2, 0)
	local function above() return head.Position + Vector3.new(0, 1.0 + p.Size.Y / 2, 0) end
	-- both arms go up to catch it (set on the shoulder joints after the animation each frame)
	local armsUp, armCon = 0, nil
	if isClient then
		local shoulders = {}
		for _, m in ipairs(rig:GetDescendants()) do
			if m:IsA("Motor6D") and (m.Name == "RightShoulder" or m.Name == "LeftShoulder" or m.Name == "Right Shoulder" or m.Name == "Left Shoulder") then
				local r6 = m.Name:find(" ") ~= nil
				local right = m.Name:find("Right") ~= nil
				-- R15: turn about X raises the arm forward and up. R6 shoulders are turned sideways: about Z.
				local pose = r6 and CFrame.Angles(0, 0, math.rad(right and 170 or -170)) or CFrame.Angles(math.rad(168), 0, math.rad(right and -8 or 8))
				table.insert(shoulders, {m, pose})
			end
		end
		armCon = RunService.Stepped:Connect(function()      -- Stepped runs after the animation update, so this pose wins
			for _, s in ipairs(shoulders) do s[1].Transform = s[1].Transform:Lerp(s[2], armsUp) end
		end)
	end
	local t, DUR = 0, 1.05
	while t < DUR do
		local a = t / DUR
		local e = ease(a)
		armsUp = ease(math.clamp((a - 0.35) / 0.4, 0, 1))
		p.Size = size0 * (1 - 0.3 * e)
		local pos = from:Lerp(above(), e) + Vector3.new(0, 7 * 4 * a * (1 - a), 0)
		p.CFrame = CFrame.new(pos) * faceMe * CFrame.Angles(0, 0, (1 - e) * math.pi * 4)
		t += step()
	end
	-- caught: a squash that settles, confetti, the crowd
	sfx("BarPop", 0.85, 1.2); sfx("ConfettiPop", 0.6, 1.1)
	burst("Confetti", p, nil, 0.9, 1.3); burst("Sparkles", p, nil, 1.2)
	crowd("goal", false)
	shake(0.35, 0.2)
	local s1 = p.Size
	t = 0
	while t < 1.0 do
		local a = t / 1.0
		local sq = 1 + 0.22 * math.exp(-a * 5) * math.cos(a * 24)
		local w = 1 / math.sqrt(sq)
		p.Size = s1 * Vector3.new(w, sq, w)
		p.CFrame = CFrame.new(above()) * faceMe * CFrame.Angles(0, 0, 0.08 * math.sin(a * 9) * (1 - a))
		t += step()
	end
	if armCon then armCon:Disconnect() end
	tCheer:Stop(0.3)
	setBars(0)
end

----------------------------------------------------------------- eggs come out of Workspace.Tunnel
local function enterEgg(egg)
	local mouth, out = A:GetAttribute("TunnelMouth"), A:GetAttribute("TunnelOut")
	if typeof(mouth) ~= "Vector3" or typeof(out) ~= "Vector3" then return egg:enter() end
	egg:take()
	local s = egg.state
	local a = goal.cf:PointToObjectSpace(mouth - out * 1.5)       -- just inside the doorway
	local b = goal.cf:PointToObjectSpace(mouth + out * 7)         -- out onto the pitch
	s.x, s.z, s.lift = a.X, a.Z, 0
	s.yaw = math.atan2(-(b.X - a.X), -(b.Z - a.Z))                 -- already facing out of the tunnel
	egg:apply()
	local hop = egg.stats.hop + 0.5
	-- round the outside of the net: aim for a spot just in front of the post on the tunnel's side
	local side = (a.X >= 0) and 1 or -1
	local c = Vector2.new(side * (goal.width / 2 + 4), -3)
	local function hopTo(x, z)
		local dx, dz = x - egg.state.x, z - egg.state.z
		local n = math.max(1, math.ceil(math.sqrt(dx * dx + dz * dz) / 5))
		for _ = 1, n do if not egg:hop(dx / n, dz / n, hop + 0.4, 0.24) then return false end end
		return true
	end
	-- out of the tunnel without stopping to look round, past the post, then along to the middle of the goal
	if not hopTo(b.X, b.Z) then return end
	if not hopTo(c.X, c.Y) then return end
	egg:travel(0, 0, 5, hop + 0.4, 0.24)
end

----------------------------------------------------------------- the egg walks out as a mystery
-- Until it reaches the goal the egg is a black silhouette with a glowing white outline, and it keeps
-- changing: each one shrinks to nothing and the next bursts out at full size in white VFX. It lands
-- on the rolled egg, then the real egg is revealed.
local EggRoll = require(RS.DevDemo.EggRoll)
local function outBack(t) local c = 1.7; t -= 1; return 1 + (c + 1) * t * t * t + c * t * t end
local followSignal = isClient and RunService.RenderStepped or RunService.Heartbeat

local function mysteryEnter(egg, winner)
	local keeper = egg.part
	-- hide the real egg until it is in goal
	local was = {}
	for _, d in ipairs(keeper:GetDescendants()) do
		if d:IsA("Texture") or d:IsA("Decal") then was[d] = d.Transparency; d.Transparency = 1 end
	end
	local keeperT = keeper.Transparency
	keeper.Transparency = 1

	local MIN = 0.22                         -- smallest it squeezes down to (still visible)
	local disp, dispBase, pop, current = nil, nil, MIN, nil
	local function place()
		if not disp or not keeper.Parent then return end
		disp.Size = dispBase * (keeper.Size / egg.base) * pop
		disp.CFrame = keeper.CFrame - Vector3.new(0, (1 - pop) * keeper.Size.Y / 2, 0)   -- shrinks down to the ground
	end
	local function setEgg(name)
		local old = disp
		local t = A.Eggs:FindFirstChild(name) or A.Eggs:FindFirstChild(winner)
		disp = t:Clone()
		disp.Name = "MysteryEgg"
		disp.Anchored, disp.CanCollide, disp.CanQuery, disp.CanTouch = true, false, false, false
		dispBase = disp.Size * (egg.H / disp.Size.Y)
		local hl = Instance.new("Highlight")
		hl.FillColor, hl.FillTransparency = Color3.new(0, 0, 0), 0
		hl.OutlineColor, hl.OutlineTransparency = Color3.new(1, 1, 1), 0
		hl.DepthMode = Enum.HighlightDepthMode.Occluded
		hl.Parent = disp
		local glow = Instance.new("PointLight")
		glow.Color, glow.Brightness, glow.Range, glow.Shadows = Color3.new(1, 1, 1), 2, 9, false
		glow.Parent = disp
		place()                              -- in position before it appears
		disp.Parent = folder
		current = name
		if old then
			-- keep the old one one more frame so the swap never shows an empty spot
			task.delay(0.05, function() old:Destroy() end)
		end
	end
	local follow = followSignal:Connect(place)
	-- it only flicks through eggs of YOUR rarity: the tier your Luck rolls most (GameConfig.rollCentre).
	-- A lucky roll from a higher tier still lands at the end, as a surprise.
	local yourTier = EggRoll.rarityOf(G.AnimalOrder[math.floor(G.rollCentre(myLuck()) + 0.5)] or winner, A.Eggs)
	local shown = {}
	for _, n in ROSTER do if EggRoll.rarityOf(n, A.Eggs) == yourTier then table.insert(shown, n) end end
	if #shown < 2 then shown = ROSTER end
	local function pick(notThis)
		if #shown < 2 then return shown[1] end
		local n
		repeat n = shown[math.random(#shown)] until n ~= notThis
		return n
	end
	local busy = false
	local function swapTo(name)
		busy = true
		sfx("RollTick", 0.6, 0.95 + math.random() * 0.2)                           -- on the beat of the landing
		sfx("BarPop", 0.25, 1.5 + math.random() * 0.2)
		fovPunch(2.5)
		local t = 0
		while t < 0.045 do pop = 1 - (1 - MIN) * (t / 0.045) ^ 2; t += step() end    -- squeeze down small
		pop = MIN
		setEgg(name)
		burst("Mystery", keeper, keeper.Position, 0.45, 0.45)                     -- white puff + rings
		burst("Poof", keeper, keeper.Position, 0.55, 0.6)
		showOdds(EggRoll.oddsText(EggRoll.chance(name, ROSTER, folder:GetAttribute("Luck") or 1, A.Eggs)), EggRoll.rarityOf(name, A.Eggs))
		t = 0
		while t < 0.18 do pop = MIN + (1 - MIN) * outBack(t / 0.18); t += step() end   -- bursts out to full size
		pop = 1
		busy = false
	end

	-- cinematic: bars in, the camera goes down to the egg, a drum roll under it all
	setBars(0.055)
	camEgg, camEggDist = keeper, 15
	camShot = "egg"; camFov = 50
	local drum = sfx("DrumRoll", 0.25, 1)
	if drum then
		drum.Looped = true
		TweenService:Create(drum, TweenInfo.new(4, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {Volume = 0.75 * MASTER_VOLUME, PlaybackSpeed = 1.12}):Play()
	end
	task.spawn(function()   -- creep closer the whole way out
		local t0 = os.clock()
		while camShot == "egg" and camEgg == keeper do
			camEggDist = math.max(11, 15 - (os.clock() - t0) * 1.0)
			step()
		end
	end)
	-- first egg pops out as it starts walking, then it keeps swapping, slowing down as it gets close
	local arrived = false
	task.spawn(function()
		setEgg(pick(nil))
		fovPunch(2.5)
		showOdds(EggRoll.oddsText(EggRoll.chance(current, ROSTER, folder:GetAttribute("Luck") or 1, A.Eggs)), EggRoll.rarityOf(current, A.Eggs))
		local t = 0
		while t < 0.2 do pop = MIN + (1 - MIN) * outBack(t / 0.2); t += step() end
		pop = 1
	end)
	-- every time the egg lands from a hop it changes; the last hop lands on the rolled egg
	local prevLand = egg.onLand
	egg.onLand = function(e, strength)
		if prevLand then prevLand(e, strength) end
		if arrived or busy then return end
		local s = egg.state
		local last = math.sqrt(s.x * s.x + s.z * s.z) < 0.6
		task.spawn(swapTo, last and winner or pick(current))
	end
	enterEgg(egg)
	egg.onLand = prevLand
	arrived = true
	while busy do step() end
	if current ~= winner then swapTo(winner) end
	camFov = 46                                                                    -- push in a little for the reveal
	task.wait(0.55)                                                                -- a beat of suspense

	-- reveal: the silhouette lets go, the real egg flashes white and bursts in
	follow:Disconnect()
	if disp then disp:Destroy() end
	keeper.Transparency = keeperT
	for d, tr in pairs(was) do d.Transparency = tr end
	local flash = Instance.new("Highlight")
	flash.FillColor, flash.FillTransparency = Color3.new(1, 1, 1), 0
	flash.OutlineColor, flash.OutlineTransparency = Color3.new(1, 1, 1), 0
	flash.DepthMode = Enum.HighlightDepthMode.Occluded
	flash.Parent = keeper
	TweenService:Create(flash, TweenInfo.new(0.6, Enum.EasingStyle.Quad), {FillTransparency = 1, OutlineTransparency = 1}):Play()
	game:GetService("Debris"):AddItem(flash, 0.7)
	fadeOut(drum, 0.08)
	sfx("Cymbal", 0.55, 1)
	sfx("WhooshBig", 0.4, 1.3)
	fovPunch(6)
	local winEgg = A.Eggs:FindFirstChild(winner)
	showOdds(EggRoll.oddsText(EggRoll.chance(winner, ROSTER, myLuck(), A.Eggs) * G.mutChance(roundMut)), EggRoll.rarityOf(winner, A.Eggs), true,
		winner, roundMut or (winEgg and winEgg:GetAttribute("Mutation")))
	burst("Mystery", keeper, nil, 0.8, 0.8)
	burst("Diamond", keeper, nil, 0.6)
	burst("Poof", keeper, nil, 0.9)
	shake(0.35, 0.2)
	local rank = table.find(EggRoll.Order, EggRoll.rarityOf(winner, A.Eggs)) or 1
	sfx("BarPop", 0.7, 1.15)
	sfx("ConfettiPop", 0.5, 1.1)
	if rank >= 4 then sfx("PerfectSting", 0.7); sfx("CrowdGasp", 0.55, 1, 0.05) end
	crowd("reveal", rank)
	task.wait(1.3)
	camEgg = nil
	camShot = "wide"; camFov = 55
	setBars(0)
end

----------------------------------------------------------------- one egg: roll it, up to 3 tries
local rollGui = isClient and player and player:WaitForChild("PlayerGui"):FindFirstChild("EggRollVS")   -- Jacob's VS screen, once it exists
local function playEgg()
	-- the server rolls the egg with your Luck (ServerScriptService.EggInventory) and sends this round's aim-zone seed
	local name, seed
	local rollRF = isClient and RS.DevDemo:FindFirstChild("RollEgg")
	if rollRF then
		local ok, n, s, mu = pcall(function() return rollRF:InvokeServer() end)
		if ok and n and A.Eggs:FindFirstChild(n) then name, seed, roundMut = n, s, mu else roundMut = nil end
	end
	name = name or EggRoll.pick(ROSTER, myLuck(), A.Eggs)
	roundEgg, roundSeed, scoreShot = name, tonumber(seed) or math.random(1, 1e8), nil
	folder:SetAttribute("RolledEgg", name)
	if rollGui then
		setBars(0)
		name = EggRoll.play{gui = rollGui, eggs = A.Eggs, pool = ROSTER, force = name,
			kickPower = myStrength(), character = rig, playerName = player and player.DisplayName, sfx = sfx}
	end
	local tmpl = (roundMut and G.mutEggModel(name, roundMut)) or A.Eggs:FindFirstChild(name)   -- a Gold egg looks gold
	if not tmpl then return end
	targetScale = 1
	resetBall()
	camShot = "wide"
	tCheer:Stop(0.2); tIdle:Play(0.3)
	setRig(BALL_POS, 0)
	local stats = table.clone(STYLE[name] or EggKeeper.Styles[name] or {})
	local egg = EggKeeper.new(tmpl, stats, goal, folder)
	egg.onLand = function(e, strength)
		strength = strength or 0.5
		eggDust(e, math.clamp(0.25 + strength * 0.15, 0.25, 0.75))
		if strength >= 2 then
			sfx("BallLand", 0.5, 0.75 + math.random() * 0.1)
		else
			sfx(math.random() < 0.5 and "Step1" or "Step2", 0.18, 0.7 + math.random() * 0.15)
		end
		if strength >= 2 then shake(0.4, 0.2) end      -- the egg crashing down after a dive
	end
	-- your luck at the top while the egg walks out
	if isClient then showCaption("luck", luckText(myLuck()), Color3.fromRGB(255, 215, 60), 0.09, 0.075) end
	if rollGui then enterEgg(egg) else mysteryEnter(egg, name) end
	hideCaption("luck", 0.4)
	G.addMutationVFX(egg.part, roundMut)   -- once it's revealed, a mutated egg wears its aura
	egg:idle()
	sfx("Whistle", 0.5)
	task.wait(0.3)
	-- up to 3 tries; the timing bar decides each shot (Perfect whips across the ball, Weak/Miss get saved)
	local scored = false
	for try = 1, 3 do
		tryNo = try
		scored = shoot(egg, nil, nil, nil)
		if scored then break end
		egg:celebrate()
		egg:getUp()
		egg:idle()
		if try < 3 then
			-- the ball comes back to the spot while the kicker walks up to it
			local from = ballModel:GetPivot().Position
			task.spawn(function() fly(from, SPOT, 1.4, 9) end)
			tIdle:Stop(0.3)
			local shotWas = camShot; camShot = "walk"
			moveRig(BALL_POS, 1.4, tWalk, 6, easeInOut, 0)
			camShot = shotWas
			tWalk:Stop(0.3); tIdle:Play(0.3)
			ballTo(SPOT)
			task.wait(0.4)
		end
	end
	if not scored then
		-- the egg wins: it hops off happy
		egg:travel(goal.width / 2 + 5, -2, 2.4, 0.9, 0.3)
		egg:destroy()
		local from = ballModel:GetPivot().Position
		task.spawn(function() fly(from, SPOT, 1.4, 9) end)
		moveRig(BALL_POS, 1.4, tWalk, 6, easeInOut, 0)
		tWalk:Stop(0.3); tIdle:Play(0.3)
		task.wait(0.4)
		return false
	end
	-- scored: the egg flies into your hands, then it goes to your Backpack and you go straight back to your base
	claimEgg(egg)
	egg:destroy()
	tCheer:Stop(0.3); tIdle:Play(0.3)
	resetBall()
	return true, name
end

----------------------------------------------------------------- main loop
if not isClient then
	while true do playEgg() end   -- Run (F8): the stand-in keeps kicking
end
resetBall()
while true do
	-- walk onto the kick area to start
	while not onKickArea() do task.wait(0.1) end
	-- a smooth fade to black, then we're at the ball
	screenFade(Color3.new(0, 0, 0), 1, 0.45)
	task.wait(0.5)
	inRound = true
	local stateRE = RS.DevDemo:FindFirstChild("PenaltyState")
	if stateRE then stateRE:FireServer(true) end
	takeControl()
	setTvCam(true)
	camShot = "wide"; camFov = 55
	if ownChar then
		setRig(BALL_POS, 0)   -- straight onto the kicking spot, no walk-up
		tIdle:Play(0.3)
	end
	task.delay(0.2, function() screenFade(nil, 0, 0.6) end)
	local scored, eggName = playEgg()
	-- hand you back. Scored: the server puts the egg in your Backpack and sends you to your base
	-- (ServerScriptService.EggInventory). Missed: walk off the kick area and back on for the next egg.
	setBars(0)
	setTvCam(false)
	inRound = false
	releaseControl()
	local scoredRE = RS.DevDemo:FindFirstChild("EggScored")
	-- the server re-checks the kick: timing zone, aim spot, which try (for the zones)
	if scored and scoredRE and scoreShot then
		-- teleport home: flash white, the server moves you while the screen is white, then it fades
		screenFade(Color3.new(1, 1, 1), 1, 0.1)
		task.wait(0.12)
		scoredRE:FireServer(scoreShot.zone, scoreShot.x, scoreShot.y, scoreShot.try)
		task.delay(0.25, function() screenFade(nil, 0, 0.7) end)
	end
	if stateRE then stateRE:FireServer(false) end
	while onKickArea() do task.wait(0.2) end
end
end
