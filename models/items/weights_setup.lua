-- Sets up the imported Weights.fbx (weights_vox.py v6) in Studio. Run in the edit context with
--   ORBITS = <the table from weights_orbits.lua>   passed in as the first argument (see bottom of file
--   for how it's fetched), e.g.  loadstring(src)(orbitTable)
-- What it does:
--   * fixes size + rotation from the three SOA_Axis marker cubes
--   * colours every part from its name (..__<Material>; Hi / Lo = lighter / darker step)
--   * SMOOTH + STUD: SmoothPlastic with the game's Studs textures at a visible strength
--     (Neon / Glass on the special bits)
--   * one Model per tier in Workspace.WeightTiers with an invisible Root (bar centre, PrimaryPart)
--     and HeadA / HeadB anchors at the two weights
--   * effects kept to what looked good in Studio: white 4-point sparkles, soft lights, a few sparks
--   * orbit: every Orb* part gets OrbitSpeed / OrbitCenter / OrbitAxis and a thin trail, and each
--     model with orbiters gets the client script OrbitParts
local ORBITS = ... or {}
local GAP = 9
local ROW_Z, SPACING = 55, 16
local STUD_STRENGTH = 0.5        -- Texture.Transparency for the studs (the animals use 0.85: too faint here)
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
	Diamond = "6FE3FF", Chrome = "D7DCE6",
	TrophyBase = "2A2A30",
	RocketBody = "F2F2F2", RocketRed = "E8262B", RocketWindow = "4DB8FF", Nozzle = "5A5F6B",
	Flame = "FF8A1A", FlameCore = "FFE14D",
	BallBlack = "1E1E24",
	SpaceBar = "2B2F6B", GasA = "7B4DFF", GasC = "FF7EC8", RingA = "FFD27E", RingB = "FF9BD6",
	MoonIce = "8DF4FF", MoonLava = "FF8A3D", Ocean = "2F7BFF", Land = "3FCF5A", Ice = "F4FBFF",
	Moon = "C9CCD6",
	Void = "0B0B14", VoidGrip = "7B4DFF", Disc = "FF8A2A", DiscHot = "FFE9A8", DiscOut = "C24DFF",
	Star = "FFF3B0",
}
local NEON = { RingA = true, RingB = true, RocketWindow = true, MoonLava = true, Flame = true, FlameCore = true,
	Disc = true, DiscHot = true, DiscOut = true, Star = true }
local GLASS = { Diamond = true }
local SHINY = { Gold = 0.18, Chrome = 0.15, Pearl = 0.12, GemRed = 0.3, GemBlue = 0.3 }
local NO_STUDS = { Seed = true, SprinkleY = true, SprinkleB = true, SprinkleG = true, SprinkleW = true, Void = true }
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
	{ h = 1.25, hx = 3.85, hz = 1.25, size = 2.3 }, { h = 1.375, hx = 3.6, hz = 1.375, size = 2.8 },
	{ h = 1.375, hx = 3.6, hz = 1.375, size = 2.8 }, { h = 1.375, hx = 4.0, hz = 1.5, size = 2.8 },
	{ h = 1.75, hx = 4.2, hz = 1.5, size = 2.8 }, { h = 2.0, hx = 4.2, hz = 2.1, size = 2.8 },
	{ h = 2.5, hx = 4.4, hz = 3.0, size = 2.4 }, { h = 1.5, hx = 4.0, hz = 1.5, size = 2.8 },
	{ h = 1.375, hx = 5.2, hz = 1.375, size = 2.6 }, { h = 1.375, hx = 5.2, hz = 1.375, size = 2.0 },
}

local old = workspace:FindFirstChild("WeightTiers"); if old then old:Destroy() end
local folder = Instance.new("Folder"); folder.Name = "WeightTiers"; folder.Parent = workspace
local tiers, missing = {}, {}
for _, p in ipairs(imp:GetChildren()) do
	local n, tier, group, matn = p.Name:match("^Weight(%d+)_(%a+)_(%w+)__(%a+)")
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
		if plain and not NO_STUDS[base] and not group:find("^Orb") then
			for _, s in ipairs(studs) do
				local t = s:Clone(); t.Transparency = STUD_STRENGTH; t.Parent = p
			end
		end
		p:SetAttribute("Group", group)
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
		m.Parent = folder
		m:PivotTo(CFrame.new((n - 5.5) * SPACING, P.h, ROW_Z))
	end
end
if #imp:GetChildren() == 0 then imp:Destroy() end

-- ------------------------------------------------------------------ effects
local C3, CS, NS = Color3.fromRGB, ColorSequence.new, NumberSequence.new
local function seq(pts)
	local ks = {}
	for _, p in ipairs(pts) do ks[#ks + 1] = NumberSequenceKeypoint.new(p[1], p[2]) end
	return NS(ks)
end
local function heads(n)
	local m = folder:FindFirstChild(string.format("%d %s", n, tiers[n].name))
	return { m.HeadA, m.HeadB }, m
end
local function sparkle(p, rate, size, color)      -- the white 4-point glints, on the item's surface
	local e = V.Mutations.Gold.Sparkles:Clone()
	e.Name = "VFX_sparkle"; e.Rate = rate; e.Lifetime = NumberRange.new(0.7, 1); e.Color = CS(color or C3(255, 255, 255))
	e.Size = seq({ { 0, 0 }, { 0.5, size or 0.9 }, { 1, 0 } }); e.ZOffset = 0.6; e.LockedToPart = true
	e.Shape = Enum.ParticleEmitterShape.Sphere; e.ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface
	e.Speed = NumberRange.new(0); e.Enabled = true; e.Parent = p
end
local function specks(p, props)                   -- tiny glowing dots
	local e = V.TraitAuras.FIRE:FindFirstChild("OffCentered Spec 9", true):Clone()
	e.Name = "VFX_speck"; e.LightEmission = 1; e.Acceleration = Vector3.zero; e.Enabled = true
	e.Size = seq({ { 0, props.Size or 0.28 }, { 1, 0 } }); props.Size = nil
	for k, v in pairs(props) do e[k] = v end
	e.Parent = p
	return e
end
local function light(p, color, range, brightness)
	local l = Instance.new("PointLight"); l.Name = "VFX_Light"
	l.Color = color; l.Range = range; l.Brightness = brightness; l.Shadows = false; l.Parent = p
end
local function point(part, offset)
	local a = Instance.new("Attachment"); a.Name = "VFX_Point"; a.Parent = part
	a.WorldCFrame = CFrame.new(part.Position + offset)
	return a
end

-- 1-3 (Marshmallow, Donut, Watermelon): nothing, they're the plain ones.
for _, p in ipairs(heads(4)) do sparkle(p, 3, 0.9); light(p, C3(255, 215, 110), 6, 0.5) end                    -- Golden Egg
for _, p in ipairs(heads(5)) do sparkle(p, 5, 1.0); light(p, C3(120, 225, 255), 9, 1.0) end                    -- Diamond
for _, p in ipairs(heads(6)) do sparkle(p, 5, 1.0); light(p, C3(255, 205, 90), 9, 1.0) end                     -- Trophy
for _, p in ipairs(heads(7)) do                                                                               -- Rocket: the flame is a model
	local a = point(p, Vector3.new(0, -2.75, 0))      -- where the flame meets the ground
	specks(a, { Rate = 14, Lifetime = NumberRange.new(0.35, 0.6), Speed = NumberRange.new(5, 9), SpreadAngle = Vector2.new(80, 80),
		Acceleration = Vector3.new(0, -14, 0), Color = CS(C3(255, 200, 80), C3(255, 110, 30)), EmissionDirection = Enum.NormalId.Top,
		LockedToPart = false, Size = 0.3 })
	local l = Instance.new("PointLight"); l.Name = "VFX_Light"; l.Color = C3(255, 150, 60); l.Range = 9; l.Brightness = 2; l.Shadows = false; l.Parent = a
end
for _, p in ipairs(heads(8)) do                                                                               -- Golden Soccer Ball
	sparkle(p, 6, 1.0)
	specks(p, { Rate = 7, Lifetime = NumberRange.new(0.9, 1.4), Speed = NumberRange.new(1.5, 3), SpreadAngle = Vector2.new(40, 40),
		Color = CS(C3(255, 235, 150)), EmissionDirection = Enum.NormalId.Top, Shape = Enum.ParticleEmitterShape.Sphere, LockedToPart = false })
	light(p, C3(255, 200, 90), 11, 1.3)
end
for i, p in ipairs(heads(9)) do                                                                               -- Planets
	sparkle(p, 3, 0.8); light(p, i == 1 and C3(170, 130, 255) or C3(110, 180, 255), 10, 1.0)
end
for _, p in ipairs(heads(10)) do                                                                              -- Black Hole: dust falls IN
	p.Size = Vector3.one * 5
	specks(p, { Rate = 22, Lifetime = NumberRange.new(0.7, 1.0), Speed = NumberRange.new(2.2, 2.8), Color = CS(C3(255, 190, 110), C3(200, 90, 255)),
		Shape = Enum.ParticleEmitterShape.Sphere, ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface, ShapeInOut = Enum.ParticleEmitterShapeInOut.Inward,
		LockedToPart = true, Size = 0.3 })
	light(p, C3(200, 110, 255), 11, 1.2)
end

-- ------------------------------------------------------------------ orbits
local ORBIT_SRC = [[
-- Moves every part that has an OrbitSpeed attribute around its orbit. OrbitCenter / OrbitAxis are
-- in the Root part's space, so the orbits follow the barbell when it is lifted or carried.
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
local orbitCount = 0
for n, groups in pairs(ORBITS) do
	local _, m = heads(n)
	local trailed = {}
	for _, o in ipairs(m:GetChildren()) do
		local g = o:IsA("BasePart") and groups[o:GetAttribute("Group")]
		if g then
			o:SetAttribute("OrbitCenter", Vector3.new(g[1], g[2], g[3]))
			o:SetAttribute("OrbitAxis", Vector3.new(g[4], g[5], g[6]).Unit)
			o:SetAttribute("OrbitSpeed", g[7])
			orbitCount += 1
			local key = o:GetAttribute("Group"):gsub("Nose$", ""):gsub("Flame$", ""):gsub("Body$", "")
			if not trailed[key] then                                 -- one thin trail per orbiter
				trailed[key] = true
				local w = math.min(o.Size.X, o.Size.Y, o.Size.Z) * 0.4
				local a0, a1 = Instance.new("Attachment"), Instance.new("Attachment")
				a0.Position, a1.Position = Vector3.new(0, w, 0), Vector3.new(0, -w, 0)
				local tr = Instance.new("Trail")
				tr.Attachment0 = a0; tr.Attachment1 = a1; tr.FaceCamera = true; tr.Lifetime = 0.6; tr.LightEmission = 0.9
				tr.Color = CS(o.Color:Lerp(Color3.new(1, 1, 1), 0.3))
				tr.Transparency = NS(0.3, 1); tr.WidthScale = NS(1, 0)
				a0.Parent = o; a1.Parent = o; tr.Parent = o
			end
		end
	end
	local sc = Instance.new("Script")
	sc.Name = "OrbitParts"; sc.RunContext = Enum.RunContext.Client; sc.Source = ORBIT_SRC; sc.Parent = m
end

local miss = {}
for k in pairs(missing) do miss[#miss + 1] = k end
local counts = {}
for n = 1, 10 do if tiers[n] then counts[#counts + 1] = n .. ":" .. #tiers[n].parts end end
return "tiers " .. table.concat(counts, " ") .. " | orbiting parts " .. orbitCount .. " | missing colours: " .. table.concat(miss, ",")
