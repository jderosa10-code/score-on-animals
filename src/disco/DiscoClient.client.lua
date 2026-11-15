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

-- music: APM Music tracks (Roblox's own licensed library, free for every experience), one picked per show
local MUSIC_IDS = {"rbxassetid://1840082311", "rbxassetid://9038367768"}   -- "Feel The Energy", "Funky Disco Beats"
local WASH = {Color3.fromRGB(255, 215, 245), Color3.fromRGB(215, 228, 255), Color3.fromRGB(238, 212, 255)}
local CONFETTI = "rbxassetid://87631052434865"     -- plain white square
local BPM = 120
local HANG = 46           -- studs above the field
local INTRO, FALL = 1.4, 2.4   -- the lights cut out, then the ball falls out of the sky for FALL seconds
local WHOOSH_ID = "rbxassetid://9114631265"   -- Pro Sound Effects "Gong Whoosh 4" (Roblox licensed SFX)
local BOOM_ID = "rbxassetid://9125484526"     -- Pro Sound Effects "Deep Hits Big Reverberant Booms 1"
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
local function sfx(id, vol)
	local snd = Instance.new("Sound"); snd.SoundId = id; snd.Volume = vol
	local g = SoundService:FindFirstChild("SFX")
	if g and g:IsA("SoundGroup") then snd.SoundGroup = g end   -- follows the SFX setting
	snd.Parent = SoundService
	snd:Play()
	task.delay(8, function() snd:Destroy() end)
end
-- a short camera shake that fades out
local function shake(power, time)
	local t0 = os.clock()
	pcall(function() RunService:UnbindFromRenderStep("DiscoShake") end)
	RunService:BindToRenderStep("DiscoShake", Enum.RenderPriority.Camera.Value + 1, function()
		local k = 1 - (os.clock() - t0) / time
		if k <= 0 then RunService:UnbindFromRenderStep("DiscoShake") return end
		local a = power * k * k
		local cam = workspace.CurrentCamera
		cam.CFrame = cam.CFrame * CFrame.new((math.random() - 0.5) * a, (math.random() - 0.5) * a, 0)
	end)
end
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
	s.fog.Enabled = true
	for _, x in s.streaks do tw(x.b, t, {Width0 = 0.15, Width1 = 1.4}) end
	if not instant then
		for _, e in s.fountains do e.Enabled = true end
		task.delay(2.5, function() for _, e in s.fountains do e.Enabled = false end end)
	end
	for _, tl in s.tiles do
		local ring = math.max(math.abs(tl.x), math.abs(tl.z))
		if instant then tl.on = true else task.delay(ring * 0.07, function() tl.on = true end) end
	end
	if not instant then
		-- the catch: BOOM, a shockwave dome + a flash across the field, the camera shakes
		sfx(BOOM_ID, 0.9)
		shake(1.3, 0.8)
		s.sparks:Emit(120)
		s.glow.Brightness = 12; tw(s.glow, 1.2, {Brightness = 1.5})
		task.delay(0.35, function() for _, tr in s.trails do tr.Enabled = false end end)
		if s.skyBeam then tw(s.skyBeam, 0.5, {Width0 = 0, Width1 = 0}) end
		if s.landGlow then tw(s.landGlow, 0.6, {Transparency = 1}) end
		local wave = part("Shockwave", Vector3.new(6, 6, 6), s.folder)
		wave.Shape = Enum.PartType.Ball; wave.Material = Enum.Material.ForceField; wave.Color = COLORS[1]; wave.Transparency = 0
		wave.Position = Vector3.new(s.centre.X, s.hangY, s.centre.Z)
		tw(wave, 1.4, {Size = Vector3.new(320, 320, 320), Transparency = 1}, Enum.EasingStyle.Quart)
		local disc = part("ShockDisc", Vector3.new(0.4, 6, 6), s.folder)
		disc.Shape = Enum.PartType.Cylinder; disc.Material = Enum.Material.Neon; disc.Color = Color3.new(1, 1, 1); disc.Transparency = 0.45
		disc.CFrame = CFrame.new(s.centre.X, s.floorY + 0.5, s.centre.Z) * CFrame.Angles(0, 0, math.pi / 2)
		tw(disc, 1.1, {Size = Vector3.new(0.4, 240, 240), Transparency = 1}, Enum.EasingStyle.Quart)
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
	s.fog.Enabled = false
	for _, e in s.fountains do e.Enabled = false end
	for _, x in s.streaks do tw(x.b, 0.6, {Width0 = 0, Width1 = 0}) end
	for _, b in s.bars do tw(b.p, 0.6, {Transparency = 1}) end
	for _, f in s.fans do   -- the crowd back to how it was
		if f.root.Parent then f.root.CFrame = f.base end
		f.rs.C0, f.ls.C0 = f.rc0, f.lc0
	end
	local ball = s.ball
	if instant then s.folder:Destroy() return end
	-- back up into the sky (run off the clock, and the folder is always cleaned up)
	local r0, spin = os.clock(), 0
	local c2
	c2 = RunService.RenderStepped:Connect(function(dt)
		local u = math.min(1, (os.clock() - r0) / 3.2)
		spin += dt * 1.2
		ball:PivotTo(CFrame.new(s.centre.X, s.hangY + 420 * u * u, s.centre.Z) * CFrame.Angles(0, spin, 0))
		if u >= 1 then c2:Disconnect(); s.folder:Destroy() end
	end)
	task.delay(5, function()
		if c2.Connected then c2:Disconnect() end
		s.folder:Destroy()
	end)
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
	table.insert(s.lights, glow); s.glow = glow
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
	-- rainbow streaks for the fall (a trail across the ball both ways, twisted into a spiral by the spin)
	s.trails = {}
	for k, off in {Vector3.new(11, 0, 0), Vector3.new(0, 0, 11)} do
		local a0 = Instance.new("Attachment"); a0.Position = off; a0.Parent = core
		local a1 = Instance.new("Attachment"); a1.Position = -off; a1.Parent = core
		local tr = Instance.new("Trail"); tr.Attachment0, tr.Attachment1 = a0, a1
		tr.Lifetime = 0.5; tr.LightEmission = 1; tr.LightInfluence = 0
		tr.Color = ColorSequence.new({ColorSequenceKeypoint.new(0, COLORS[k]), ColorSequenceKeypoint.new(0.5, COLORS[k + 2]), ColorSequenceKeypoint.new(1, COLORS[k + 3])})
		tr.Transparency = NumberSequence.new({kp(0, 0.1), kp(1, 1)}); tr.Enabled = false; tr.Parent = core
		table.insert(s.trails, tr)
	end
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
	if not instant then
		-- a beam of light from the sky marks where the ball is coming down
		local top = Instance.new("Attachment"); top.Parent = ground; top.WorldPosition = Vector3.new(cx, fy + 500, cz)
		local bot = Instance.new("Attachment"); bot.Parent = ground; bot.WorldPosition = Vector3.new(cx, fy + 0.3, cz)
		local sb = Instance.new("Beam"); sb.Attachment0, sb.Attachment1 = top, bot
		sb.Width0, sb.Width1 = 0, 0; sb.FaceCamera = true; sb.LightEmission = 1; sb.LightInfluence = 0; sb.Segments = 1
		sb.Color = ColorSequence.new(Color3.fromRGB(255, 190, 255), Color3.new(1, 1, 1))
		sb.Transparency = NumberSequence.new({kp(0, 0.85), kp(1, 0.3)}); sb.Parent = ground
		s.skyBeam = sb
		task.delay(0.7, function() if showIs(s) then tw(sb, 0.5, {Width0 = 34, Width1 = 14}) end end)
		local lg = part("LandingGlow", Vector3.new(0.3, 2, 2), s.folder)
		lg.Shape = Enum.PartType.Cylinder; lg.Material = Enum.Material.Neon; lg.Color = Color3.fromRGB(255, 150, 255)
		lg.CFrame = CFrame.new(cx, fy + 0.2, cz) * CFrame.Angles(0, 0, math.pi / 2); lg.Transparency = 0.35
		task.delay(0.7, function() if showIs(s) then tw(lg, 0.6, {Size = Vector3.new(0.3, 22, 22)}) end end)
		s.landGlow = lg
	end
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

	-- equalizer bars in a ring round the dance floor, jumping to the beat
	s.bars = {}
	for i = 1, 28 do
		local a = i / 28 * math.pi * 2
		local b = part("EQBar", Vector3.new(1.6, 1, 1.6), s.folder)
		b.Material = Enum.Material.Neon
		table.insert(s.bars, {p = b, base = Vector3.new(cx + math.cos(a) * 40, fy, cz + math.sin(a) * 40), i = i})
	end
	-- white mirror-ball reflections sweeping round the stadium, turning with the ball
	s.streaks = {}
	for i = 1, 12 do
		local t = Instance.new("Attachment"); t.Parent = ground
		local b = Instance.new("Beam"); b.Attachment0, b.Attachment1 = centreAtt, t
		b.Width0, b.Width1 = 0, 0; b.FaceCamera = true; b.LightEmission = 1; b.LightInfluence = 0; b.Segments = 1
		b.Color = ColorSequence.new(Color3.new(1, 1, 1)); b.Transparency = NumberSequence.new({kp(0, 0.35), kp(1, 1)})
		b.Parent = core
		table.insert(s.streaks, {b = b, att = t, a = i / 12 * math.pi * 2, h = (i % 3) * 9})
	end
	-- low purple fog over the field
	local fogBox = part("DiscoFog", Vector3.new(80, 1, 80), s.folder)
	fogBox.Position = Vector3.new(cx, fy + 0.5, cz)
	local fog = Instance.new("ParticleEmitter")
	fog.Shape = Enum.ParticleEmitterShape.Box; fog.Texture = "rbxasset://textures/particles/smoke_main.dds"
	fog.Rate = 14; fog.Lifetime = NumberRange.new(5, 8); fog.Speed = NumberRange.new(0.4, 1.2)
	fog.Size = NumberSequence.new({kp(0, 7), kp(1, 15)}); fog.Rotation = NumberRange.new(0, 360); fog.RotSpeed = NumberRange.new(-10, 10)
	fog.Transparency = NumberSequence.new({kp(0, 1), kp(0.25, 0.72), kp(1, 1)}); fog.LightEmission = 0.25
	fog.Color = ColorSequence.new(Color3.fromRGB(190, 130, 255), Color3.fromRGB(255, 140, 220)); fog.Enabled = false; fog.Parent = fogBox
	s.fog = fog
	-- pyro fountains at the corners of the dance floor (on the landing and on every 16th beat)
	s.fountains = {}
	for i = 1, 4 do
		local sx, sz = (i <= 2) and -1 or 1, (i % 2 == 0) and -1 or 1
		local p = part("Pyro", Vector3.one, s.folder)
		p.Position = Vector3.new(cx + sx * 31, fy + 0.5, cz + sz * 31)
		local e = Instance.new("ParticleEmitter")
		e.Texture = "rbxasset://textures/particles/sparkles_main.dds"; e.Rate = 140; e.Lifetime = NumberRange.new(0.8, 1.3)
		e.Speed = NumberRange.new(32, 44); e.SpreadAngle = Vector2.new(7, 7); e.Acceleration = Vector3.new(0, -45, 0)
		e.EmissionDirection = Enum.NormalId.Top; e.Size = NumberSequence.new({kp(0, 0.9), kp(1, 0)}); e.LightEmission = 1
		e.Color = ColorSequence.new(Color3.fromRGB(255, 240, 200), Color3.fromRGB(255, 150, 60)); e.Enabled = false; e.Parent = p
		table.insert(s.fountains, e)
	end
	-- fireworks over the stadium (2 bursts every 8 beats)
	s.fireworks = {}
	for _ = 1, 4 do
		local p = part("Firework", Vector3.one, s.folder)
		local e = Instance.new("ParticleEmitter")
		e.Texture = "rbxasset://textures/particles/sparkles_main.dds"; e.Rate = 0; e.Lifetime = NumberRange.new(1.2, 1.9)
		e.Speed = NumberRange.new(35, 55); e.SpreadAngle = Vector2.new(180, 180); e.Drag = 2.5; e.Acceleration = Vector3.new(0, -12, 0)
		e.Size = NumberSequence.new({kp(0, 3), kp(1, 0)}); e.LightEmission = 1; e.Parent = p
		local l = Instance.new("PointLight"); l.Range = 60; l.Brightness = 0; l.Parent = p
		table.insert(s.fireworks, {p = p, e = e, l = l})
	end
	-- the crowd in the stands dances: hops on the beat, arms up and waving (on your screen only)
	s.fans = {}
	local crowd = workspace:FindFirstChild("Crowd")
	for i, fan in crowd and crowd:GetChildren() or {} do
		local root, torso = fan:FindFirstChild("HumanoidRootPart"), fan:FindFirstChild("Torso")
		local rs, ls = torso and torso:FindFirstChild("Right Shoulder"), torso and torso:FindFirstChild("Left Shoulder")
		if root and root.Anchored and rs and ls then
			table.insert(s.fans, {root = root, base = root.CFrame, rs = rs, ls = ls, rc0 = rs.C0, lc0 = ls.C0, ph = (i % 4) * 0.25, k = i % 3})
		end
	end

	if not instant then
		-- power cut: the lights flicker and die before the ball comes
		local fl = Instance.new("ColorCorrectionEffect"); fl.Name = "DiscoFlicker"; fl.Parent = Lighting
		task.spawn(function()
			for _, b in {-0.55, 0, -0.65, 0.05, -0.75, -0.2} do fl.Brightness = b; task.wait(0.07) end
			tw(fl, 0.5, {Brightness = 0}).Completed:Wait()
			fl:Destroy()
		end)
	end
	lightsOut(s, instant and 0.6 or 1.6)
	-- disco music (follows the Music setting)
	local m = Instance.new("Sound"); m.Name = "DiscoMusic"; m.SoundId = MUSIC_IDS[math.random(#MUSIC_IDS)]; m.Looped = true; m.Volume = 0
	m.Parent = SoundService
	s.music = m
	m:Play()
	if instant then land(s, true) end

	-- every frame: drop + spin the ball, sweep the lights, the floor and colours on the beat
	local t0 = os.clock()
	local lastBeat = -1
	local spin = 0
	s.conn = RunService.RenderStepped:Connect(function(dt)
		local t = os.clock() - t0
		if not s.landed then
			-- the ball falls out of the sky like a meteor: faster and faster, spinning, trailing rainbow streaks
			local ft = t - INTRO
			if ft >= 0 then
				if not s.falling then
					s.falling = true
					sfx(WHOOSH_ID, 0.7)
					s.sparks.Enabled = true
					for _, tr in s.trails do tr.Enabled = true end
				end
				local u = math.min(1, ft / FALL)
				s.y = s.hangY + 420 * (1 - u * u)
				if u >= 1 then s.landedAt = t; land(s, false) end
			end
		end
		spin += dt * ((s.falling and not s.landed) and 8 or 0.9)
		-- caught by the chain: a springy bounce
		local bounce = 0
		if s.landedAt and t - s.landedAt < 3 then
			local u = t - s.landedAt
			bounce = -7 * math.exp(-3 * u) * math.sin(8 * u)
		end
		ball:PivotTo(CFrame.new(cx, s.y + bounce + math.sin(t * 1.3) * 0.6, cz) * CFrame.Angles(0, spin, 0))
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
			for _, b in s.bars do b.p.Color = COLORS[(b.i // 4 + beat // 2) % #COLORS + 1] end
			if s.landed then
				-- crowd arms: hands up for 4 beats, then waving for 4
				local up = beat % 8 >= 4
				for _, f in s.fans do
					local a = up and 2.8 or (((beat + f.k) % 2 == 0) and 2.2 or 0.7)
					f.rs.C0 = f.rc0 * CFrame.Angles(0, 0, a)
					f.ls.C0 = f.lc0 * CFrame.Angles(0, 0, -a)
				end
				if beat % 8 == 0 then
					tw(s.cc, 1, {TintColor = WASH[(beat // 8) % #WASH + 1]})
					for k = 1, 2 do   -- fireworks
						local fw = s.fireworks[(beat // 8 * 2 + k) % #s.fireworks + 1]
						fw.p.Position = Vector3.new(cx + math.random(-70, 70), fy + math.random(55, 85), cz + math.random(-70, 70))
						local col = COLORS[math.random(#COLORS)]
						fw.e.Color = ColorSequence.new(Color3.new(1, 1, 1), col); fw.l.Color = col
						fw.e:Emit(140)
						fw.l.Brightness = 8; tw(fw.l, 0.7, {Brightness = 0})
					end
				end
				if beat % 16 == 0 then   -- pyro on the big beat
					for _, e in s.fountains do e.Enabled = true end
					task.delay(1.5, function() for _, e in s.fountains do e.Enabled = false end end)
				end
			end
		end
		local frac = bt - beat
		local pulse = 0.2 + 0.35 * frac
		for _, tl in s.tiles do tl.p.Transparency = tl.on and pulse or 1 end
		if s.landed then
			s.bloom.Intensity = 0.4 + 0.35 * (1 - frac) ^ 2
			local kick = (1 - frac) ^ 1.5
			for _, b in s.bars do
				local h = 1 + 9 * kick * (0.45 + math.clamp(math.noise(b.i * 0.37, t * 1.7) + 0.5, 0, 1) * 0.55)
				b.p.Size = Vector3.new(1.6, h, 1.6)
				b.p.CFrame = CFrame.lookAt(b.base + Vector3.new(0, h / 2, 0), Vector3.new(cx, fy + h / 2, cz))
				b.p.Transparency = 0.1
			end
			local spin = t * 0.9
			for _, x in s.streaks do
				local a = x.a + spin
				x.att.WorldPosition = Vector3.new(cx + math.cos(a) * 120, fy + 8 + x.h, cz + math.sin(a) * 120)
			end
			for _, f in s.fans do
				if f.root.Parent then f.root.CFrame = f.base + Vector3.new(0, math.sin(((bt + f.ph) % 1) * math.pi) * 0.9, 0) end
			end
		end
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
