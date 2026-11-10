-- Sets up the imported Weights.fbx (weights_vox.py, v5 stepped style) in Studio. Run in the edit context.
--   * fixes size + rotation from the three SOA_Axis marker cubes
--   * colours every part from its name (..__<Material>, Hi/Lo = lighter/darker step)
--   * SMOOTH + STUD: SmoothPlastic with the game's Studs textures (Neon / Glass on the special bits)
--   * one Model per tier in Workspace.WeightTiers, with an invisible Root (bar centre, PrimaryPart)
--     and HeadA / HeadB anchors at the two weights (effects hang off these)
--   * light effects that ramp up by tier, and the orbit script on 10 Planets
local GAP = 8
local ROW_Z, SPACING = 55, 13
local V = game.ReplicatedStorage.Assets.VFX

local imp
for _, c in ipairs(workspace:GetChildren()) do if c:IsA("Model") and c.Name:find("^Weights") then imp = c end end
assert(imp, "import the FBX first (Home > Import 3D > Weights.fbx)")

local function axis(v)
	local a = Vector3.new(math.abs(v.X), math.abs(v.Y), math.abs(v.Z))
	if a.X >= a.Y and a.X >= a.Z then return Vector3.new(math.sign(v.X), 0, 0) end
	if a.Y >= a.Z then return Vector3.new(0, math.sign(v.Y), 0) end
	return Vector3.new(0, 0, math.sign(v.Z))
end
-- size: the Up marker is 3 studs above the origin marker. Then Blender X -> X, Z -> Y (up), Y -> -Z.
local d = (imp.SOA_AxisUp.Position - imp.SOA_AxisO.Position).Magnitude
imp:ScaleTo(imp:GetScale() * 3 / d)
local O, Up, Fw = imp.SOA_AxisO, imp.SOA_AxisUp, imp.SOA_AxisFwd
local U, F = axis(Up.Position - O.Position), axis(Fw.Position - O.Position)
local C = CFrame.fromMatrix(Vector3.zero, U:Cross(-F), U, -F)
imp.PrimaryPart = O
imp:SetPrimaryPartCFrame(CFrame.new(O.Position) * C:Inverse() * O.CFrame.Rotation)
local origin = O.Position
for _, mk in ipairs({O, Up, Fw}) do mk:Destroy() end

local BASE = {
	Bar = "8C8F99", Grip = "2E2E36", Wood = "B5793C",
	Marshmallow = "FFF4EA", MarshPink = "FFB7D5", Toast = "C98A3E",
	Dough = "E3A35A", Icing = "FF7EB6",
	SprinkleY = "FFE14D", SprinkleB = "4DB8FF", SprinkleG = "6BE36B", SprinkleW = "FFFFFF",
	Rind = "2E9B35", RindIn = "E4F7C8", Flesh = "FF4D5E", Seed = "1A1A1A",
	Gold = "F7C440", Pearl = "FFF6E0", GemRed = "E8262B", GemBlue = "2F7BFF",
	Anvil = "4A4E5A", HotMetal = "FF7A1A",
	Diamond = "6FE3FF", Chrome = "D7DCE6",
	TrophyBase = "2A2A30",
	RocketBody = "F2F2F2", RocketRed = "E8262B", RocketWindow = "4DB8FF", Nozzle = "5A5F6B",
	BallBlack = "1E1E24",
	SpaceBar = "2B2F6B", GasA = "7B4DFF", GasC = "FF7EC8", RingA = "FFD27E", RingB = "FF9BD6",
	MoonIce = "8DF4FF", MoonLava = "FF8A3D", Ocean = "2F7BFF", Land = "3FCF5A", Ice = "F4FBFF",
	Moon = "C9CCD6",
}
local NEON = { HotMetal = true, RingA = true, RingB = true, RocketWindow = true, MoonLava = true }
local GLASS = { Diamond = true }
local SHINY = { Gold = 0.18, Chrome = 0.15, Pearl = 0.12, GemRed = 0.3, GemBlue = 0.3 }
local function look(matn)
	local base, mode = matn, nil
	if not BASE[matn] and (matn:sub(-2) == "Hi" or matn:sub(-2) == "Lo") then base, mode = matn:sub(1, -3), matn:sub(-2) end
	local c = Color3.fromHex(BASE[base] or "FF00FF")
	if mode == "Hi" then c = c:Lerp(Color3.new(1, 1, 1), 0.28) elseif mode == "Lo" then c = Color3.new(c.R * 0.74, c.G * 0.74, c.B * 0.74) end
	return c, base
end
local studs = {}
for _, t in ipairs(workspace.BaseAnimals.Corgi:FindFirstChildWhichIsA("MeshPart"):GetChildren()) do
	if t:IsA("Texture") then studs[#studs + 1] = t end
end

-- per tier: bar height, distance of each weight from the middle, height of the weight's centre, its size
local T = {
	{ h = 1.2, hx = 2.6, hz = 1.2, size = 2.3 }, { h = 1.4, hx = 2.4, hz = 1.4, size = 2.8 },
	{ h = 1.4, hx = 2.4, hz = 1.4, size = 2.8 }, { h = 1.4, hx = 2.8, hz = 1.5, size = 2.8 },
	{ h = 1.6, hx = 2.4, hz = 1.1, size = 2.2 }, { h = 1.8, hx = 2.9, hz = 1.5, size = 2.8 },
	{ h = 2.0, hx = 2.9, hz = 2.1, size = 2.8 }, { h = 1.6, hx = 2.9, hz = 2.0, size = 2.2 },
	{ h = 1.4, hx = 2.8, hz = 1.4, size = 2.8 }, { h = 1.4, hx = 3.2, hz = 1.4, size = 2.6 },
}

local old = workspace:FindFirstChild("WeightTiers"); if old then old:Destroy() end
local folder = Instance.new("Folder"); folder.Name = "WeightTiers"; folder.Parent = workspace
local tiers, missing = {}, {}
for _, p in ipairs(imp:GetChildren()) do
	local n, tier, group, matn = p.Name:match("^Weight(%d+)_(%a+)_(%a+)__(%a+)")
	if n then
		n = tonumber(n)
		tiers[n] = tiers[n] or { name = tier, parts = {} }
		local col, base = look(matn)
		if not BASE[base] then missing[matn] = true end
		p.Anchored = true; p.CanCollide = false
		p.Color = col
		p.Material = Enum.Material.SmoothPlastic
		p.Reflectance = SHINY[base] or 0
		local plain = true
		if NEON[base] then p.Material = Enum.Material.Neon; plain = false end
		if GLASS[base] then p.Material = Enum.Material.Glass; p.Transparency = 0.15; p.Reflectance = 0.1; plain = false end
		if plain and not group:find("^Orb") and not base:find("^Sprinkle") and base ~= "Seed" then
			for _, s in ipairs(studs) do s:Clone().Parent = p end
		end
		p.Name = group .. "_" .. matn
		table.insert(tiers[n].parts, p)
	end
end

local function hidden(name, pos, size, shape)
	local a = Instance.new("Part")
	a.Name = name; a.Anchored = true; a.CanCollide = false; a.CanQuery = false; a.CanTouch = false
	a.Transparency = 1; a.Size = Vector3.one * size; a.Position = pos
	if shape then a.Shape = shape end
	return a
end
for n = 1, 10 do
	local t, P = tiers[n], T[n]
	if t then
		local m = Instance.new("Model"); m.Name = string.format("%d %s", n, t.name)
		for _, p in ipairs(t.parts) do p.Parent = m end
		local o = origin + Vector3.new(0, 0, (n - 1) * GAP)      -- this tier's ground origin
		local root = hidden("Root", o + Vector3.new(0, P.h, 0), 0.4)
		root.Parent = m; m.PrimaryPart = root
		hidden("HeadA", o + Vector3.new(P.hx, P.hz, 0), P.size, Enum.PartType.Ball).Parent = m
		hidden("HeadB", o + Vector3.new(-P.hx, P.hz, 0), P.size, Enum.PartType.Ball).Parent = m
		m:SetAttribute("HeadOffset", P.hx)
		m.Parent = folder
		m:PivotTo(CFrame.new((n - 5.5) * SPACING, P.h, ROW_Z))
	end
end
if #imp:GetChildren() == 0 then imp:Destroy() end

-- ------------------------------------------------------------------ effects (light, ramping up)
local LIB = {
	twinkle = V.Mutations.Gold:FindFirstChild("Sparkles"),
	glint = V.TraitAuras.GOLD:FindFirstChild("Star20", true),
	glow = V.Mutations.Gold:FindFirstChild("Core", true),
	fireA = V.TraitAuras.FIRE:FindFirstChild("Fire21", true),
	fireB = V.TraitAuras.FIRE:FindFirstChild("Fire728", true),
	fireC = V.TraitAuras.FIRE:FindFirstChild("Fire5", true),
	spark = V.TraitAuras.FIRE:FindFirstChild("OffCentered Spec 9", true),
	star = V.TraitAuras.STAR:FindFirstChild("Rotating Star", true),
}
local function sizeTo(e, target)
	local mx = 0
	for _, k in ipairs(e.Size.Keypoints) do mx = math.max(mx, k.Value) end
	local ks = {}
	for _, k in ipairs(e.Size.Keypoints) do ks[#ks + 1] = NumberSequenceKeypoint.new(k.Time, k.Value / mx * target) end
	e.Size = NumberSequence.new(ks)
end
local function emit(kind, parent, props)
	local e = LIB[kind]:Clone()
	e.Name = "VFX_" .. kind
	e.Speed = NumberRange.new(0); e.Acceleration = Vector3.zero; e.SpreadAngle = Vector2.zero
	e.Enabled = true
	local size = props.Size; props.Size = nil
	for k, v in pairs(props) do e[k] = v end
	if size then sizeTo(e, size) end
	e.Parent = parent
	return e
end
local function point(part, offset)
	local a = Instance.new("Attachment"); a.Name = "VFX_Point"; a.Parent = part
	a.WorldCFrame = CFrame.new(part.Position + offset)
	return a
end
local function light(part, color, range, brightness)
	local l = Instance.new("PointLight"); l.Name = "VFX_Light"
	l.Color = color; l.Range = range; l.Brightness = brightness; l.Shadows = false; l.Parent = part
end
local function onSurface(e)
	e.Shape = Enum.ParticleEmitterShape.Sphere; e.ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface
end
local C3, CS, NS = Color3.fromRGB, ColorSequence.new, NumberSequence.new
local SOFT = NS({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0.82), NumberSequenceKeypoint.new(1, 1) })
local WHITE = CS(C3(255, 255, 255))
local function heads(n)
	local m = folder:FindFirstChild(string.format("%d %s", n, tiers[n].name))
	return { m.HeadA, m.HeadB }, m
end
local function sparkle(p, rate, size)      -- the white 4-point glints
	onSurface(emit("twinkle", p, { Size = size or 0.7, Rate = rate, Lifetime = NumberRange.new(0.8), Color = WHITE, ZOffset = 0.5, LockedToPart = true }))
end

-- 1-3: nothing. They're the light and easy ones.
for _, p in ipairs(heads(4)) do sparkle(p, 2) end                                     -- 4 Golden Egg
for _, p in ipairs(heads(5)) do                                                       -- 5 Anvil: forge sparks
	emit("spark", point(p, Vector3.new(0, 1.2, 0)), { Size = 0.25, Rate = 3, Lifetime = NumberRange.new(0.35, 0.6), Speed = NumberRange.new(4, 7),
		SpreadAngle = Vector2.new(55, 55), Acceleration = Vector3.new(0, -18, 0), Color = CS(C3(255, 170, 60)), LightEmission = 1,
		EmissionDirection = Enum.NormalId.Top, LockedToPart = false })
	light(p, C3(255, 140, 50), 6, 0.7)
end
for _, p in ipairs(heads(6)) do                                                       -- 6 Diamond
	sparkle(p, 4, 0.8)
	emit("glow", point(p, Vector3.zero), { Size = 4, Rate = 2, Lifetime = NumberRange.new(1.5), Color = CS(C3(120, 225, 255)), Transparency = SOFT, ZOffset = -1.8, LockedToPart = true })
	light(p, C3(120, 225, 255), 8, 0.9)
end
for _, p in ipairs(heads(7)) do                                                       -- 7 Trophy
	sparkle(p, 4, 0.8)
	emit("glow", point(p, Vector3.zero), { Size = 4.2, Rate = 2, Lifetime = NumberRange.new(1.5), Color = CS(C3(255, 200, 60)), Transparency = SOFT, ZOffset = -1.8, LockedToPart = true })
	emit("star", point(p, Vector3.new(0, 0.9, 0)), { Size = 0.6, Rate = 2.5, Lifetime = NumberRange.new(0.9, 1.3), Speed = NumberRange.new(1.5, 2.5), SpreadAngle = Vector2.new(25, 25),
		Color = CS(C3(255, 215, 70)), EmissionDirection = Enum.NormalId.Top, LockedToPart = false })
	light(p, C3(255, 205, 90), 8, 0.9)
end
for _, p in ipairs(heads(8)) do                                                       -- 8 Rocket: engine flame
	local a = point(p, Vector3.new(0, -1.5, 0))
	emit("fireA", a, { Size = 1.9, Rate = 10, Lifetime = NumberRange.new(0.25, 0.4), Rotation = NumberRange.new(180), RotSpeed = NumberRange.new(0), ZOffset = 0.8, LockedToPart = true })
	emit("fireB", a, { Size = 1.6, Rate = 10, Lifetime = NumberRange.new(0.25, 0.4), Rotation = NumberRange.new(180), RotSpeed = NumberRange.new(0), ZOffset = 0.8, LockedToPart = true })
	emit("spark", a, { Size = 0.22, Rate = 12, Lifetime = NumberRange.new(0.3, 0.5), Speed = NumberRange.new(4, 8), SpreadAngle = Vector2.new(80, 80),
		Acceleration = Vector3.new(0, 4, 0), Color = CS(C3(255, 190, 70)), LightEmission = 1, EmissionDirection = Enum.NormalId.Bottom, LockedToPart = false })
	light(p, C3(255, 150, 60), 7, 1.2)
end
for _, p in ipairs(heads(9)) do                                                       -- 9 Golden Soccer Ball
	local a = point(p, Vector3.new(0, 0.55, 0))
	for i, k in ipairs({ "fireA", "fireB", "fireC" }) do
		emit(k, a, { Size = 4.4 - i * 0.2, Rate = 7, Lifetime = NumberRange.new(0.45, 0.65), ZOffset = -1.9, LockedToPart = true })
	end
	emit("spark", point(p, Vector3.new(0, 1, 0)), { Size = 0.28, Rate = 9, Lifetime = NumberRange.new(0.8, 1.3), Speed = NumberRange.new(2.5, 5), SpreadAngle = Vector2.new(35, 35),
		Acceleration = Vector3.new(0, 2, 0), Color = CS(C3(255, 200, 60), C3(255, 80, 20)), LightEmission = 1, EmissionDirection = Enum.NormalId.Top, LockedToPart = false })
	sparkle(p, 5, 0.85)
	light(p, C3(255, 170, 60), 12, 1.5)
end

-- 10 Planets: glow + stars, and everything named Orb* circles its planet
local hs, P = heads(10)
local root = P.Root
for i, p in ipairs(hs) do
	local tint = i == 1 and C3(170, 130, 255) or C3(110, 180, 255)
	sparkle(p, 3, 0.7)
	emit("glow", point(p, Vector3.zero), { Size = 4.4, Rate = 2, Lifetime = NumberRange.new(1.5), Color = CS(tint), Transparency = SOFT, ZOffset = -1.8, LockedToPart = true })
	light(p, tint, 9, 0.9)
end
local SPEED = { OrbIce = 1.1, OrbLava = -0.8, OrbMoon = 0.9, OrbSat = 1.7 }
local axisOf = {}
for _, o in ipairs(P:GetChildren()) do
	if o:IsA("BasePart") and o.Name:find("^Orb") then
		local key = o.Name:match("^(Orb%a-)_") or o.Name
		if key:find("^OrbSat") then key = "OrbSat" end
		local sideX = o.Position.X > root.Position.X and 1 or -1
		local centre = root.Position + Vector3.new(sideX * T[10].hx, 0, 0)
		if not axisOf[key] then
			local nrm = (o.Position - centre):Cross(Vector3.new(0, 0, 1)).Unit
			if nrm.Y < 0 then nrm = -nrm end
			axisOf[key] = nrm
		end
		o:SetAttribute("OrbitSpeed", SPEED[key] or 1)
		o:SetAttribute("OrbitCenter", root.CFrame:PointToObjectSpace(centre))
		o:SetAttribute("OrbitAxis", root.CFrame:VectorToObjectSpace(axisOf[key]))
		if not o.Name:find("Nose") and not o.Name:find("Hi$") then      -- one thin trail per orbiter
			local w = math.min(o.Size.X, o.Size.Y, o.Size.Z) * 0.35
			local a0, a1 = Instance.new("Attachment"), Instance.new("Attachment")
			a0.Position, a1.Position = Vector3.new(0, w, 0), Vector3.new(0, -w, 0)
			local tr = Instance.new("Trail")
			tr.Attachment0 = a0; tr.Attachment1 = a1; tr.FaceCamera = true; tr.Lifetime = 0.55; tr.LightEmission = 0.8
			tr.Color = CS(key == "OrbSat" and C3(255, 170, 70) or o.Color)
			tr.Transparency = NS(0.35, 1); tr.WidthScale = NS(1, 0)
			a0.Parent = o; a1.Parent = o; tr.Parent = o
		end
	end
end
local sc = Instance.new("Script")
sc.Name = "PlanetOrbit"
sc.RunContext = Enum.RunContext.Client
sc.Source = [[
-- Moves every part that has an OrbitSpeed attribute around its planet. OrbitCenter / OrbitAxis
-- are in the Root part's space, so the orbits follow the barbell when it is lifted or carried.
local RunService = game:GetService("RunService")
local model = script.Parent
local root = model:WaitForChild("Root")
task.wait(1)
local orbs = {}
for _, p in ipairs(model:GetChildren()) do
	if p:IsA("BasePart") and p:GetAttribute("OrbitSpeed") then
		local c = p:GetAttribute("OrbitCenter")
		table.insert(orbs, { part = p, c = c, axis = p:GetAttribute("OrbitAxis"), speed = p:GetAttribute("OrbitSpeed"),
			rel = (root.CFrame * CFrame.new(c)):ToObjectSpace(p.CFrame) })
	end
end
local t0 = os.clock()
RunService.RenderStepped:Connect(function()
	local t = os.clock() - t0
	for _, o in ipairs(orbs) do
		if o.part.Parent then
			o.part.CFrame = root.CFrame * CFrame.new(o.c) * CFrame.fromAxisAngle(o.axis, o.speed * t) * o.rel
		end
	end
end)
]]
sc.Parent = P

local miss = {}
for k in pairs(missing) do miss[#miss + 1] = k end
local counts = {}
for n = 1, 10 do if tiers[n] then counts[#counts + 1] = n .. ":" .. #tiers[n].parts end end
return "tiers " .. table.concat(counts, " ") .. " | missing colours: " .. table.concat(miss, ",")
