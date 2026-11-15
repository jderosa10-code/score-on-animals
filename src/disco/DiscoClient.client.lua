-- DISCO KICKOFF show on your screen (pigeon, 14 Nov 2026). Server: ServerScriptService.DiscoEvent (workspace DiscoActive).
-- LIGHTS OUT: the sun sets in a few seconds, the night sky comes in with a purple haze and glow, while a giant mirror disco
-- ball (ReplicatedStorage.Assets.EventCosmetics.Disco.DiscoBall) drops out of the sky on a rope over the field.
-- When it lands: a flash + a confetti burst, then the party: a light-up dance floor under the ball that changes pattern on
-- the beat, mirror-ball light specks sweeping round, coloured spotlight beams + pools of light, lasers, searchlights in the
-- sky, floating sparkles and disco music (MusicPlayer fades the normal song while DiscoActive; follows the Music setting).
-- At the end the ball goes back up and the sun comes back up. The server never runs it at night.
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")
local SoundService = game:GetService("SoundService")
local player = Players.LocalPlayer

local MUSIC_ID = "rbxassetid://130633590241078"   -- "Disco Funk Groove" (DistroKid, licensed for all experiences)
local CONFETTI = "rbxassetid://87631052434865"     -- plain white square
local BPM = 120
local HANG = 46           -- studs above the field
local DROP_TIME = 4.5
local FLOOR_N, FLOOR_TILE = 9, 6
local COLORS = {Color3.fromRGB(255, 60, 170), Color3.fromRGB(60, 220, 255), Color3.fromRGB(255, 220, 60),
	Color3.fromRGB(170, 80, 255), Color3.fromRGB(80, 255, 140), Color3.fromRGB(255, 120, 40)}
-- the dark look: night, but still easy to play in
local DARK = {ClockTime = 23.9, Brightness = 1.6, Ambient = Color3.fromRGB(95, 75, 140),
	OutdoorAmbient = Color3.fromRGB(125, 95, 175), ExposureCompensation = 0}
-- dance floor patterns: colour index from tile (x, z) and the beat
local PATTERNS = {
	function(x, z, b) return x + z + b end,                                          -- diagonal stripes
	function(x, z, b) return math.max(math.abs(x), math.abs(z)) - b end,             -- rings rolling out
	function(x, z, b) return ((x + z) % 2 == 0) and b or b + 3 end,                  -- checkerboard flip
	function(x, z, b) return math.floor((math.atan2(z, x) + math.pi) / (math.pi / 3)) + b end,   -- pinwheel
}

local show   -- everything the current show made, to clean up
local function showIs(s) return show == s end
local function kp(t, v) return NumberSequenceKeypoint.new(t, v) end
local function tw(o, t, props, style, dir)
	local x = TweenService:Create(o, TweenInfo.new(t, style or Enum.EasingStyle.Sine, dir or Enum.EasingDirection.Out), props)
	x:Play()
	return x
end
local function part(name, size, parent)
	local p = Instance.new("Part")
	p.Name = name; p.Anchored = true; p.CanCollide = false; p.CanQuery = false; p.CanTouch = false; p.CastShadow = false
	p.Size = size; p.Transparency = 1; p.Parent = parent
	return p
end
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
local function groundY(c, ignore)
	local p = RaycastParams.new()
	p.FilterType = Enum.RaycastFilterType.Exclude
	p.FilterDescendantsInstances = ignore
	local r = workspace:Raycast(c + Vector3.new(0, 60, 0), Vector3.new(0, -140, 0), p)
	return r and r.Position.Y or c.Y + 2
end

-- the world goes dark: sunset, night sky, purple haze, glow on everything neon
local function lightsOut(s, time)
	s.saved = {}
	for k in DARK do s.saved[k] = Lighting[k] end
	s.daySky = Lighting:FindFirstChildOfClass("Sky")
	local night = RS:FindFirstChild("Night")
	if night and s.daySky then
		s.sky = night:Clone(); s.sky.Name = "DiscoSky"
		task.delay(time * 0.5, function()
			if showIs(s) then s.daySky.Parent = nil; s.sky.Parent = Lighting end
		end)
	end
	s.oldAtmo = Lighting:FindFirstChildOfClass("Atmosphere")
	if s.oldAtmo then s.oldAtmo.Parent = nil end
	local atmo = Instance.new("Atmosphere")
	atmo.Name = "DiscoHaze"; atmo.Density = 0; atmo.Offset = 0.1; atmo.Glare = 0.6; atmo.Haze = 1.6
	atmo.Color = Color3.fromRGB(120, 60, 190); atmo.Decay = Color3.fromRGB(45, 20, 90)
	atmo.Parent = Lighting
	s.atmo = atmo
	tw(atmo, time, {Density = 0.3})
	local bloom = Instance.new("BloomEffect")
	bloom.Name = "DiscoBloom"; bloom.Intensity = 0; bloom.Size = 28; bloom.Threshold = 0.95; bloom.Parent = Lighting
	s.bloom = bloom
	tw(bloom, time, {Intensity = 0.5})
	local cc = Instance.new("ColorCorrectionEffect"); cc.Name = "DiscoCC"; cc.Parent = Lighting
	s.cc = cc
	tw(cc, time, {TintColor = Color3.fromRGB(235, 215, 255), Saturation = 0.3, Contrast = 0.12})
	tw(Lighting, time, DARK)
end

-- and back: the sun comes up again (unless night has started, then the night look takes over)
local function lightsOn(s, time)
	if workspace:GetAttribute("IsNight") ~= true and s.saved then
		Lighting.ClockTime = 0
		tw(Lighting, time, s.saved)
	end
	task.delay(time * 0.4, function()
		if s.sky then s.sky:Destroy() end
		if s.daySky and not s.daySky.Parent and workspace:GetAttribute("IsNight") ~= true then s.daySky.Parent = Lighting end
	end)
	if s.atmo then tw(s.atmo, time, {Density = 0}) end
	if s.bloom then tw(s.bloom, time, {Intensity = 0}) end
	if s.cc then tw(s.cc, time, {TintColor = Color3.new(1, 1, 1), Saturation = 0, Contrast = 0, Brightness = 0}) end
	task.delay(time + 0.1, function()
		for _, e in {s.atmo, s.bloom, s.cc} do e:Destroy() end
		if s.oldAtmo and workspace:GetAttribute("IsNight") ~= true and not Lighting:FindFirstChildOfClass("Atmosphere") then
			s.oldAtmo.Parent = Lighting
		end
	end)
end

-- the ball has landed: flash, confetti, and everything switches on
local function land(s, instant)
	if s.landed then return end
	s.landed = true
	local t = instant and 0 or 0.6
	for _, b in s.beams do tw(b, t, {Width0 = 1.2, Width1 = 9}) end
	for _, l in s.pools do tw(l, t, {Brightness = 4}) end
	for _, l in s.specks do tw(l, t, {Brightness = 10}) end
	for _, x in s.lasers do tw(x.b, t, {Width0 = 0.25, Width1 = 0.6}) end
	for _, x in s.searches do tw(x.b, instant and 0 or 1.2, {Width0 = 2.5, Width1 = 14}) end
	s.sparks.Enabled = true
	s.motes.Enabled = true
	s.twinkle.Enabled = true
	for _, tl in s.tiles do
		local ring = math.max(math.abs(tl.x), math.abs(tl.z))
		if instant then tl.on = true else task.delay(ring * 0.07, function() tl.on = true end) end
	end
	if not instant then
		for _, e in s.confetti do e:Emit(45) end
		tw(s.cc, 0.08, {Brightness = 0.35}).Completed:Connect(function()
			if s.cc.Parent and showIs(s) then tw(s.cc, 0.7, {Brightness = 0}) end
		end)
	end
end

local function stop(instant)
	local s = show
	show = nil
	if not s then return end
	if s.conn then s.conn:Disconnect() end
	if s.music then
		local m = s.music
		tw(m, instant and 0 or 2, {Volume = 0})
		task.delay(instant and 0 or 2.1, function() m:Destroy() end)
	end
	lightsOn(s, instant and 0 or 3)
	for _, b in s.beams do tw(b, 0.8, {Width0 = 0, Width1 = 0}) end
	for _, x in s.lasers do tw(x.b, 0.5, {Width0 = 0, Width1 = 0}) end
	for _, x in s.searches do tw(x.b, 1, {Width0 = 0, Width1 = 0}) end
	for _, l in s.lights do tw(l, 0.8, {Brightness = 0}) end
	for _, tl in s.tiles do tw(tl.p, 0.8, {Transparency = 1}) end
	s.sparks.Enabled = false
	s.motes.Enabled = false
	s.twinkle.Enabled = false
	local ball = s.ball
	if instant then s.folder:Destroy() return end
	-- back up into the sky
	local v = Instance.new("NumberValue"); v.Value = 0
	v.Changed:Connect(function(t) s.y = s.hangY + t * 420 end)
	local up = tw(v, 3.2, {Value = 1}, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	local spin = 0
	local c2 = RunService.RenderStepped:Connect(function(dt)
		spin += dt * 1.2
		ball:PivotTo(CFrame.new(s.centre.X, s.y, s.centre.Z) * CFrame.Angles(0, spin, 0))
	end)
	up.Completed:Wait()
	c2:Disconnect()
	s.folder:Destroy()
end

local function start(instant)
	if show then return end
	local kit = RS:FindFirstChild("Assets") and RS.Assets:FindFirstChild("EventCosmetics") and RS.Assets.EventCosmetics:FindFirstChild("Disco")
	local src = kit and kit:FindFirstChild("DiscoBall")
	if not src then return end
	local s = {beams = {}, pools = {}, lights = {}, targets = {}, specks = {}, lasers = {}, searches = {}, tiles = {}, confetti = {}}
	show = s
	s.centre = fieldCentre()
	s.hangY = s.centre.Y + HANG
	s.y = instant and s.hangY or s.hangY + 420
	s.folder = Instance.new("Folder"); s.folder.Name = "DiscoShow"; s.folder.Parent = workspace
	local ignore = {s.folder}
	for _, p in Players:GetPlayers() do if p.Character then table.insert(ignore, p.Character) end end
	s.floorY = groundY(s.centre, ignore)
	local cx, cz, fy = s.centre.X, s.centre.Z, s.floorY

	local ball = src:Clone()
	ball.Parent = s.folder
	s.ball = ball
	ball:PivotTo(CFrame.new(cx, s.y, cz))
	local core = ball.PrimaryPart
	-- the rope up into the sky
	local a0 = Instance.new("Attachment"); a0.Position = Vector3.new(0, 16, 0); a0.Parent = core
	local a1 = Instance.new("Attachment"); a1.Position = Vector3.new(0, 600, 0); a1.Parent = core
	local rope = Instance.new("Beam"); rope.Attachment0, rope.Attachment1 = a0, a1; rope.Width0, rope.Width1 = 0.5, 0.5
	rope.Color = ColorSequence.new(Color3.fromRGB(60, 62, 70)); rope.LightInfluence = 1; rope.FaceCamera = true; rope.Segments = 1; rope.Parent = core
	-- a light inside the ball, sparkles flying off it, and a confetti cannon for the landing
	-- (the coloured glow hangs under the ball, so the ball itself stays a silver mirror)
	local under = Instance.new("Attachment"); under.Position = Vector3.new(0, -16, 0); under.Parent = core
	local glow = Instance.new("PointLight"); glow.Range = 40; glow.Brightness = 1.5; glow.Color = COLORS[1]; glow.Parent = under
	table.insert(s.lights, glow)
	local sp = Instance.new("ParticleEmitter")
	sp.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	sp.Rate = 35; sp.Lifetime = NumberRange.new(1.2, 2); sp.Speed = NumberRange.new(18, 30); sp.SpreadAngle = Vector2.new(180, 180)
	sp.Size = NumberSequence.new({kp(0, 1.4), kp(1, 0)}); sp.LightEmission = 1
	sp.Color = ColorSequence.new(Color3.new(1, 1, 1)); sp.Drag = 2; sp.Enabled = false; sp.Parent = core
	s.sparks = sp
	-- mirror glints twinkling all over the ball's surface
	local shell = part("Twinkle", Vector3.new(23, 23, 23), ball)
	shell.Shape = Enum.PartType.Ball; shell.CFrame = core.CFrame
	local tk = Instance.new("ParticleEmitter")
	tk.Texture = "rbxasset://textures/particles/sparkles_main.dds"; tk.Rate = 45; tk.Lifetime = NumberRange.new(0.25, 0.5)
	tk.Speed = NumberRange.new(0); tk.Shape = Enum.ParticleEmitterShape.Sphere; tk.ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface
	tk.Size = NumberSequence.new({kp(0, 0), kp(0.5, 3), kp(1, 0)}); tk.LightEmission = 1; tk.LockedToPart = true
	tk.Enabled = false; tk.Parent = shell
	s.twinkle = tk
	for i = 1, 4 do
		local c = Instance.new("ParticleEmitter")
		c.Texture = CONFETTI; c.Rate = 0; c.Lifetime = NumberRange.new(4, 6); c.Speed = NumberRange.new(35, 70)
		c.SpreadAngle = Vector2.new(180, 180); c.Acceleration = Vector3.new(0, -22, 0); c.Drag = 1.2
		c.Size = NumberSequence.new(0.5); c.Squash = NumberSequence.new(0.4)
		c.Rotation = NumberRange.new(0, 360); c.RotSpeed = NumberRange.new(-400, 400)
		c.Color = ColorSequence.new(COLORS[({1, 2, 3, 5})[i]]); c.LightEmission = 0.4; c.Parent = core
		table.insert(s.confetti, c)
	end
	-- mirror-ball light specks: narrow spotlights pointing out of the ball, turning with it
	for i = 1, 14 do
		local yv = -0.8 - 0.18 * (i - 0.5) / 14
		local r = math.sqrt(1 - yv * yv)
		local th = i * 2.39996
		local a = Instance.new("Attachment")
		a.CFrame = CFrame.lookAt(Vector3.zero, Vector3.new(math.cos(th) * r, yv, math.sin(th) * r))
		a.Parent = core
		local sl = Instance.new("SpotLight")
		sl.Face = Enum.NormalId.Front; sl.Angle = 7; sl.Range = 60; sl.Brightness = 0; sl.Shadows = false
		sl.Color = (i % 3 == 0) and COLORS[(i // 3 - 1) % #COLORS + 1] or Color3.new(1, 1, 1)
		sl.Parent = a
		table.insert(s.specks, sl); table.insert(s.lights, sl)
	end
	-- spotlight beams down to moving pools of light, lasers, searchlights
	local centreAtt = Instance.new("Attachment"); centreAtt.Parent = core
	local ground = part("BeamTargets", Vector3.one, s.folder)
	ground.Position = Vector3.new(cx, fy, cz)
	for i = 1, 8 do
		local t = Instance.new("Attachment"); t.Parent = ground
		local col = COLORS[(i - 1) % #COLORS + 1]
		local b = Instance.new("Beam"); b.Attachment0, b.Attachment1 = centreAtt, t
		b.Width0, b.Width1 = 0, 0; b.FaceCamera = true; b.LightEmission = 1; b.LightInfluence = 0; b.Segments = 1
		b.Color = ColorSequence.new(col)
		b.Transparency = NumberSequence.new({kp(0, 0.25), kp(1, 0.75)})
		b.Parent = core
		local pl = Instance.new("PointLight"); pl.Range = 18; pl.Brightness = 0; pl.Color = col; pl.Parent = t
		table.insert(s.beams, b); table.insert(s.pools, pl); table.insert(s.lights, pl)
		table.insert(s.targets, {att = t, r = 14 + (i % 4) * 14, speed = (i % 2 == 0 and 1 or -1) * (0.35 + i * 0.05), phase = i * math.pi / 4})
	end
	for i = 1, 6 do
		local t = Instance.new("Attachment"); t.Parent = ground
		local b = Instance.new("Beam"); b.Attachment0, b.Attachment1 = centreAtt, t
		b.Width0, b.Width1 = 0, 0; b.FaceCamera = true; b.LightEmission = 1; b.LightInfluence = 0; b.Segments = 1
		b.Color = ColorSequence.new(COLORS[(i % 2 == 0) and 2 or 1]); b.Transparency = NumberSequence.new(0.05)
		b.Parent = core
		table.insert(s.lasers, {b = b, att = t, phase = i * math.pi / 3})
	end
	for i = 1, 4 do
		local sx, sz = (i <= 2) and -1 or 1, (i % 2 == 0) and -1 or 1
		local base = Vector3.new(cx + sx * 55, fy + 22, cz + sz * 48)   -- starts above head height
		local b0 = Instance.new("Attachment"); b0.Parent = ground; b0.WorldPosition = base
		local b1 = Instance.new("Attachment"); b1.Parent = ground
		local b = Instance.new("Beam"); b.Attachment0, b.Attachment1 = b0, b1
		b.Width0, b.Width1 = 0, 0; b.FaceCamera = true; b.LightEmission = 1; b.LightInfluence = 0; b.Segments = 1
		b.Color = ColorSequence.new(COLORS[i + 1]); b.Transparency = NumberSequence.new({kp(0, 0.5), kp(1, 1)})
		b.Parent = ground
		table.insert(s.searches, {b = b, top = b1, base = base, phase = i * math.pi / 2})
	end
	-- floating sparkles over the field
	local box = part("DiscoMotes", Vector3.new(120, 36, 120), s.folder)
	box.Position = Vector3.new(cx, fy + 20, cz)
	local mo = Instance.new("ParticleEmitter")
	mo.Shape = Enum.ParticleEmitterShape.Box; mo.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	mo.Texture = "rbxasset://textures/particles/sparkles_main.dds"; mo.Rate = 60
	mo.Lifetime = NumberRange.new(2.5, 4); mo.Speed = NumberRange.new(0.5, 2); mo.SpreadAngle = Vector2.new(180, 180)
	mo.Size = NumberSequence.new({kp(0, 0), kp(0.3, 0.8), kp(1, 0)}); mo.LightEmission = 1
	mo.Color = ColorSequence.new({ColorSequenceKeypoint.new(0, COLORS[1]), ColorSequenceKeypoint.new(0.5, COLORS[2]), ColorSequenceKeypoint.new(1, COLORS[4])})
	mo.Enabled = false; mo.Parent = box
	s.motes = mo
	-- the light-up dance floor under the ball
	local floor = Instance.new("Model"); floor.Name = "DanceFloor"
	local h = (FLOOR_N - 1) // 2
	for x = -h, h do
		for z = -h, h do
			local t = part("Tile", Vector3.new(FLOOR_TILE - 0.4, 0.2, FLOOR_TILE - 0.4), floor)
			t.Material = Enum.Material.Neon
			t.Position = Vector3.new(cx + x * FLOOR_TILE, fy + 0.1, cz + z * FLOOR_TILE)
			table.insert(s.tiles, {p = t, x = x, z = z})
		end
	end
	floor.Parent = s.folder

	lightsOut(s, instant and 0.6 or 3.5)
	-- disco music (follows the Music setting)
	local m = Instance.new("Sound"); m.Name = "DiscoMusic"; m.SoundId = MUSIC_ID; m.Looped = true; m.Volume = 0
	m.Parent = SoundService
	s.music = m
	m:Play()
	if instant then land(s, true) end

	-- every frame: drop + spin the ball, sweep the lights, the floor and colours on the beat
	local t0 = os.clock()
	local dropT = instant and 1 or 0
	local lastBeat = -1
	s.conn = RunService.RenderStepped:Connect(function()
		local t = os.clock() - t0
		if dropT < 1 then
			dropT = math.min(1, t / DROP_TIME)
			s.y = s.hangY + 420 * (1 - dropT) ^ 3
			if dropT >= 1 then land(s, false) end
		end
		ball:PivotTo(CFrame.new(cx, s.y + math.sin(t * 1.3) * 0.6, cz) * CFrame.Angles(0, t * 0.9, 0))
		for _, tg in s.targets do
			local a = tg.phase + t * tg.speed
			tg.att.WorldPosition = Vector3.new(cx + math.cos(a) * tg.r, fy + 0.5, cz + math.sin(a) * tg.r)
		end
		for i, L in s.lasers do
			local a = L.phase + t * 0.45 + math.sin(t * 0.8 + i) * 0.9
			local r = 70 + math.sin(t * 0.6 + i * 1.7) * 40
			L.att.WorldPosition = Vector3.new(cx + math.cos(a) * r, fy, cz + math.sin(a) * r)
		end
		for _, S in s.searches do
			local a = S.phase + t * 0.35
			S.top.WorldPosition = S.base + Vector3.new(math.cos(a) * 90, 320, math.sin(a) * 90)
		end
		local bt = t * BPM / 60
		local beat = math.floor(bt)
		if beat ~= lastBeat then
			lastBeat = beat
			glow.Color = COLORS[beat % #COLORS + 1]
			if beat % 4 == 0 then
				for i, L in s.lasers do L.b.Color = ColorSequence.new(COLORS[(beat // 4 + i) % #COLORS + 1]) end
			end
			local pat = PATTERNS[(beat // 8) % #PATTERNS + 1]
			for _, tl in s.tiles do tl.p.Color = COLORS[pat(tl.x, tl.z, beat) % #COLORS + 1] end
		end
		local pulse = 0.2 + 0.35 * (bt - beat)
		for _, tl in s.tiles do tl.p.Transparency = tl.on and pulse or 1 end
		m.Volume = (player:GetAttribute("MusicOn") ~= false) and math.min(0.4, t * 0.2) or 0
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
-- joined in the middle of one: straight into it, once the day/night script has read the normal daylight
task.spawn(function()
	if not game:IsLoaded() then game.Loaded:Wait() end
	task.wait(2)
	update(true)
end)
