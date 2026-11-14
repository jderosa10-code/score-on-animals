-- DISCO KICKOFF show on your screen (pigeon, 14 Nov 2026). Server: ServerScriptService.DiscoEvent (workspace DiscoActive).
-- A giant mirror disco ball (ReplicatedStorage.Assets.EventCosmetics.Disco.DiscoBall) drops out of the sky on a rope over
-- the field and spins; coloured spotlight beams sweep the field and plots with pools of coloured light; sparkles fly off
-- the ball; the world gets a party tint; the music switches to disco (MusicPlayer fades the normal song while DiscoActive).
-- At the end it all goes back up into the sky.
-- (Repo copy. The live version is StarterPlayerScripts.DiscoClient; patch the live Source, don't paste this over it.)
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")
local SoundService = game:GetService("SoundService")
local player = Players.LocalPlayer

local MUSIC_ID = "rbxassetid://130633590241078"   -- "Disco Funk Groove" (DistroKid, licensed for all experiences)
local HANG = 46          -- studs above the field
local COLORS = {Color3.fromRGB(255, 60, 170), Color3.fromRGB(60, 220, 255), Color3.fromRGB(255, 220, 60),
	Color3.fromRGB(170, 80, 255), Color3.fromRGB(80, 255, 140), Color3.fromRGB(255, 120, 40)}

local function banner(text, style)
	local hud = player:WaitForChild("PlayerGui"):FindFirstChild("HUD")
	local n = hud and hud:FindFirstChild("NotificationsHUD")
	if n and n:FindFirstChild("ShowBanner") then n.ShowBanner:Fire(text, style) end
end
local function fieldCentre()
	local k, g = workspace:FindFirstChild("KickArea"), workspace:FindFirstChild("Goal")
	if k and g then
		local a = k.Position
		local b = g:IsA("Model") and g:GetPivot().Position or g.Position
		return Vector3.new((a.X + b.X) / 2, math.min(a.Y, b.Y) - 2, (a.Z + b.Z) / 2)
	end
	return Vector3.new(-400, 1, -3)
end

local show   -- everything the show made, to clean up
local function stop(instant)
	local s = show
	show = nil
	if not s then return end
	if s.conn then s.conn:Disconnect() end
	if s.music then
		local m = s.music
		TweenService:Create(m, TweenInfo.new(instant and 0 or 2), {Volume = 0}):Play()
		task.delay(instant and 0 or 2.1, function() m:Destroy() end)
	end
	if s.cc then TweenService:Create(s.cc, TweenInfo.new(1.5), {TintColor = Color3.new(1, 1, 1), Saturation = 0, Brightness = 0}):Play(); task.delay(1.6, function() s.cc:Destroy() end) end
	for _, b in s.beams or {} do TweenService:Create(b, TweenInfo.new(0.8), {Width0 = 0, Width1 = 0}):Play() end
	for _, l in s.lights or {} do TweenService:Create(l, TweenInfo.new(0.8), {Brightness = 0}):Play() end
	if s.sparks then s.sparks.Enabled = false end
	local ball = s.ball
	if ball then
		if instant then s.folder:Destroy() return end
		-- back up into the sky
		local v = Instance.new("NumberValue"); v.Value = 0
		v.Changed:Connect(function(t) s.y = s.hangY + t * 420 end)
		local tw = TweenService:Create(v, TweenInfo.new(3.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {Value = 1})
		local spin = 0
		local c2; c2 = RunService.RenderStepped:Connect(function(dt)
			spin += dt * 1.2
			ball:PivotTo(CFrame.new(s.centre.X, s.y, s.centre.Z) * CFrame.Angles(0, spin, 0))
		end)
		tw:Play()
		tw.Completed:Wait()
		c2:Disconnect()
		s.folder:Destroy()
	end
end

local function start(instant)
	if show then return end
	local kit = RS:FindFirstChild("Assets") and RS.Assets:FindFirstChild("EventCosmetics") and RS.Assets.EventCosmetics:FindFirstChild("Disco")
	local src = kit and kit:FindFirstChild("DiscoBall")
	if not src then return end
	local s = {beams = {}, lights = {}, targets = {}}
	show = s
	s.centre = fieldCentre()
	s.hangY = s.centre.Y + HANG
	s.y = instant and s.hangY or s.hangY + 420
	s.folder = Instance.new("Folder"); s.folder.Name = "DiscoShow"; s.folder.Parent = workspace
	local ball = src:Clone()
	ball.Parent = s.folder
	s.ball = ball
	ball:PivotTo(CFrame.new(s.centre.X, s.y, s.centre.Z))
	local core = ball.PrimaryPart
	-- the rope up into the sky
	local a0 = Instance.new("Attachment"); a0.Position = Vector3.new(0, 16, 0); a0.Parent = core
	local a1 = Instance.new("Attachment"); a1.Position = Vector3.new(0, 600, 0); a1.Parent = core
	local rope = Instance.new("Beam"); rope.Attachment0, rope.Attachment1 = a0, a1; rope.Width0, rope.Width1 = 0.5, 0.5
	rope.Color = ColorSequence.new(Color3.fromRGB(60, 62, 70)); rope.LightInfluence = 1; rope.FaceCamera = true; rope.Segments = 1; rope.Parent = core
	-- a light inside the ball and sparkles flying off it
	local glow = Instance.new("PointLight"); glow.Range = 60; glow.Brightness = 3; glow.Color = COLORS[1]; glow.Parent = core
	table.insert(s.lights, glow)
	local sp = Instance.new("ParticleEmitter")
	sp.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	sp.Rate = 35; sp.Lifetime = NumberRange.new(1.2, 2); sp.Speed = NumberRange.new(18, 30); sp.SpreadAngle = Vector2.new(180, 180)
	sp.Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 1.4), NumberSequenceKeypoint.new(1, 0)}); sp.LightEmission = 1
	sp.Color = ColorSequence.new(Color3.new(1, 1, 1)); sp.Drag = 2; sp.Parent = core
	s.sparks = sp
	-- spotlight beams down to moving pools of light
	local centreAtt = Instance.new("Attachment"); centreAtt.Parent = core
	local ground = Instance.new("Part"); ground.Name = "BeamTargets"; ground.Anchored = true; ground.CanCollide = false; ground.CanQuery = false; ground.CanTouch = false
	ground.Transparency = 1; ground.Size = Vector3.one; ground.Position = s.centre; ground.Parent = s.folder
	for i = 1, 8 do
		local t = Instance.new("Attachment"); t.Parent = ground
		local col = COLORS[(i - 1) % #COLORS + 1]
		local b = Instance.new("Beam"); b.Attachment0, b.Attachment1 = centreAtt, t
		b.Width0, b.Width1 = 1.2, 9; b.FaceCamera = true; b.LightEmission = 1; b.LightInfluence = 0; b.Segments = 1
		b.Color = ColorSequence.new(col)
		b.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.25), NumberSequenceKeypoint.new(1, 0.75)})
		b.Parent = core
		local pl = Instance.new("PointLight"); pl.Range = 18; pl.Brightness = 4; pl.Color = col; pl.Parent = t
		table.insert(s.beams, b); table.insert(s.lights, pl)
		table.insert(s.targets, {att = t, r = 14 + (i % 4) * 14, speed = (i % 2 == 0 and 1 or -1) * (0.35 + i * 0.05), phase = i * math.pi / 4})
	end
	-- party tint
	local cc = Instance.new("ColorCorrectionEffect"); cc.Name = "DiscoCC"; cc.Parent = Lighting
	s.cc = cc
	TweenService:Create(cc, TweenInfo.new(2), {TintColor = Color3.fromRGB(255, 225, 255), Saturation = 0.25, Brightness = -0.03}):Play()
	-- disco music (follows the Music setting)
	local m = Instance.new("Sound"); m.Name = "DiscoMusic"; m.SoundId = MUSIC_ID; m.Looped = true; m.Volume = 0
	m.Parent = SoundService
	s.music = m
	m:Play()
	-- every frame: spin the ball, sweep the pools of light, cycle the colours, drop the ball in
	local t0 = os.clock()
	local dropT = instant and 1 or 0
	s.conn = RunService.RenderStepped:Connect(function(dt)
		local t = os.clock() - t0
		if dropT < 1 then
			dropT = math.min(1, t / 4.5)
			local e = 1 - (1 - dropT) ^ 3
			s.y = (s.hangY + 420) + (s.hangY - (s.hangY + 420)) * e
		end
		ball:PivotTo(CFrame.new(s.centre.X, s.y + math.sin(t * 1.3) * 0.6, s.centre.Z) * CFrame.Angles(0, t * 0.9, 0))
		for _, tg in s.targets do
			local a = tg.phase + t * tg.speed
			tg.att.WorldPosition = s.centre + Vector3.new(math.cos(a) * tg.r, 0.5, math.sin(a) * tg.r)
		end
		glow.Color = COLORS[math.floor(t * 2) % #COLORS + 1]
		local musicOn = player:GetAttribute("MusicOn") ~= false
		m.Volume = musicOn and math.min(0.4, t * 0.2) or 0
	end)
	if not instant then
		banner("🪩 DISCO KICKOFF! Score eggs for GROOVY animals!", {text = Color3.fromRGB(255, 120, 220), fill = Color3.fromRGB(70, 20, 120)})
	end
end

local function update(instant)
	if workspace:GetAttribute("DiscoActive") == true then start(instant)
	elseif show then
		banner("🪩 The disco's over!", {text = Color3.fromRGB(255, 120, 220), fill = Color3.fromRGB(70, 20, 120)})
		task.spawn(stop, false)
	end
end
workspace:GetAttributeChangedSignal("DiscoActive"):Connect(function() update(false) end)
task.defer(update, true)   -- joined in the middle of one: straight into it
