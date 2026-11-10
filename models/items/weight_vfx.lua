-- Weight tier VFX for Workspace.WeightTiers (run in Studio's edit context / command bar).
-- Rule: effects are SIZED TO THE ITEM and ramp up by tier. Never paste a whole animal aura on a
-- weight (those are built for 4-9 stud animals: an 8-stud fire sprite swallows a 2.7-stud ball).
--   1-3 Marshmallow / Donut / Watermelon : nothing (light and easy)
--   4 Golden Egg : a rare glint            5 Anvil  : a few forge sparks
--   6 Diamond    : twinkles + soft halo    7 Trophy : shimmer + stars rising from the cup
--   8 Rocket     : engine flame + sparks   9 Golden Soccer Ball : flame halo, embers, glowing bar
-- Everything it creates is tagged with the attribute WeightVFX, so re-running replaces it cleanly.
local V = game.ReplicatedStorage.Assets.VFX
local F = workspace.WeightTiers

-- library emitters to clone (keeps their textures + flipbook setup); everything else is set here
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
local function extents(part)
	local mn, mx = Vector3.new(math.huge, math.huge, math.huge), Vector3.new(-math.huge, -math.huge, -math.huge)
	local h = part.Size / 2
	for _, sx in ipairs({-1, 1}) do for _, sy in ipairs({-1, 1}) do for _, sz in ipairs({-1, 1}) do
		local w = part.CFrame:PointToWorldSpace(Vector3.new(h.X * sx, h.Y * sy, h.Z * sz))
		mn = mn:Min(w); mx = mx:Max(w)
	end end end
	return mn, mx
end
local function sizeTo(e, target)   -- rescale the size curve so its peak = target (studs)
	local mx = 0
	for _, k in ipairs(e.Size.Keypoints) do mx = math.max(mx, k.Value) end
	local ks = {}
	for _, k in ipairs(e.Size.Keypoints) do ks[#ks + 1] = NumberSequenceKeypoint.new(k.Time, k.Value / mx * target) end
	e.Size = NumberSequence.new(ks)
end
local function emit(kind, parent, props)
	local e = LIB[kind]:Clone()
	e.Name = "VFX_" .. kind
	e:SetAttribute("WeightVFX", true)
	e.Speed = NumberRange.new(0); e.Acceleration = Vector3.zero; e.SpreadAngle = Vector2.zero
	e.Enabled = true
	local size = props.Size; props.Size = nil
	for k, v in pairs(props) do e[k] = v end
	if size then sizeTo(e, size) end
	e.Parent = parent
	return e
end
local function point(part, worldPos)   -- world-aligned attachment (so "Top" = straight up)
	local a = Instance.new("Attachment")
	a.Name = "VFX_Point"; a:SetAttribute("WeightVFX", true)
	a.Parent = part
	a.WorldCFrame = CFrame.new(worldPos)
	return a
end
local function light(part, color, range, brightness)
	local l = Instance.new("PointLight")
	l.Name = "VFX_Light"; l:SetAttribute("WeightVFX", true)
	l.Color = color; l.Range = range; l.Brightness = brightness; l.Shadows = false
	l.Parent = part
end
local function onSurface(e)   -- spread over the item's round surface, not inside it
	e.Shape = Enum.ParticleEmitterShape.Sphere
	e.ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface
end
local function parts(model, pattern)
	local out = {}
	for _, p in ipairs(model:GetChildren()) do
		if p:IsA("BasePart") and p.Name:find(pattern) then out[#out + 1] = p end
	end
	return out
end
local C3, CS, NS = Color3.fromRGB, ColorSequence.new, NumberSequence.new
local SOFT = NS({NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0.8), NumberSequenceKeypoint.new(1, 1)})

for _, d in ipairs(F:GetDescendants()) do
	if d:GetAttribute("WeightVFX") then d:Destroy() end
end

-- 4 Golden Egg
for _, p in ipairs(parts(F["4 GoldenEgg"], "^Egg")) do
	onSurface(emit("twinkle", p, {Size = 0.55, Rate = 1.5, Lifetime = NumberRange.new(0.7), Color = CS(C3(255, 240, 190)), ZOffset = 0.3, LockedToPart = true}))
end

-- 5 Anvil
for _, p in ipairs(parts(F["5 Anvil"], "^Top")) do
	local _, mx = extents(p)
	local a = point(p, Vector3.new(p.Position.X, mx.Y, p.Position.Z))
	emit("spark", a, {Size = 0.22, Rate = 2, Lifetime = NumberRange.new(0.35, 0.6), Speed = NumberRange.new(4, 7), SpreadAngle = Vector2.new(55, 55),
		Acceleration = Vector3.new(0, -18, 0), Color = CS(C3(255, 170, 60)), LightEmission = 1, EmissionDirection = Enum.NormalId.Top, LockedToPart = false})
end

-- 6 Diamond
for _, p in ipairs(parts(F["6 Diamond"], "^Gem")) do
	onSurface(emit("twinkle", p, {Size = 0.6, Rate = 4, Lifetime = NumberRange.new(0.8), Color = CS(C3(255, 255, 255)), ZOffset = 0.3, LockedToPart = true}))
	onSurface(emit("glint", p, {Size = 1.1, Rate = 0.8, Lifetime = NumberRange.new(0.6, 0.9), Color = CS(C3(150, 235, 255)), ZOffset = 0.5, LockedToPart = true}))
	emit("glow", point(p, p.Position), {Size = 3.4, Rate = 2, Lifetime = NumberRange.new(1.5), Color = CS(C3(120, 225, 255)), Transparency = SOFT, ZOffset = -1.5, LockedToPart = true})
	light(p, C3(120, 225, 255), 7, 0.8)
end

-- 7 Trophy
for _, p in ipairs(parts(F["7 Trophy"], "^Cup")) do
	local _, mx = extents(p)
	onSurface(emit("twinkle", p, {Size = 0.6, Rate = 4, Lifetime = NumberRange.new(0.7), Color = CS(C3(255, 245, 200)), ZOffset = 0.3, LockedToPart = true}))
	emit("glow", point(p, p.Position), {Size = 3.8, Rate = 2, Lifetime = NumberRange.new(1.5), Color = CS(C3(255, 200, 60)), Transparency = SOFT, ZOffset = -1.5, LockedToPart = true})
	local top = point(p, Vector3.new(p.Position.X, mx.Y, p.Position.Z))
	emit("star", top, {Size = 0.55, Rate = 2.5, Lifetime = NumberRange.new(0.9, 1.3), Speed = NumberRange.new(1.5, 2.5), SpreadAngle = Vector2.new(25, 25),
		Color = CS(C3(255, 215, 70)), EmissionDirection = Enum.NormalId.Top, LockedToPart = false})
	light(p, C3(255, 205, 90), 8, 0.9)
end

-- 8 Rocket (flame sprites flipped upside down so the fire points out of the engine)
for _, p in ipairs(parts(F["8 Rocket"], "^Nozzle")) do
	local mn = extents(p)
	local a = point(p, Vector3.new(p.Position.X, mn.Y + 0.35, p.Position.Z))
	emit("fireA", a, {Size = 1.9, Rate = 10, Lifetime = NumberRange.new(0.25, 0.4), Rotation = NumberRange.new(180), RotSpeed = NumberRange.new(0), ZOffset = 0.8, LockedToPart = true})
	emit("fireB", a, {Size = 1.6, Rate = 10, Lifetime = NumberRange.new(0.25, 0.4), Rotation = NumberRange.new(180), RotSpeed = NumberRange.new(0), ZOffset = 0.8, LockedToPart = true})
	emit("spark", a, {Size = 0.2, Rate = 12, Lifetime = NumberRange.new(0.3, 0.5), Speed = NumberRange.new(4, 8), SpreadAngle = Vector2.new(80, 80),
		Acceleration = Vector3.new(0, 4, 0), Color = CS(C3(255, 190, 70)), LightEmission = 1, EmissionDirection = Enum.NormalId.Bottom, LockedToPart = false})
	light(p, C3(255, 150, 60), 7, 1.2)
end

-- 9 Golden Soccer Ball: flame halo BEHIND the ball (negative ZOffset keeps the ball readable)
local top9 = F["9 SoccerBall"]
for _, p in ipairs(parts(top9, "^Ball.*BallGold$")) do
	local a = point(p, p.Position + Vector3.new(0, 0.55, 0))
	for i, k in ipairs({"fireA", "fireB", "fireC"}) do
		emit(k, a, {Size = 4.3 - i * 0.2, Rate = 7, Lifetime = NumberRange.new(0.45, 0.65), ZOffset = -1.7, LockedToPart = true})
	end
	local up = point(p, p.Position + Vector3.new(0, 1.0, 0))
	emit("spark", up, {Size = 0.28, Rate = 9, Lifetime = NumberRange.new(0.8, 1.3), Speed = NumberRange.new(2.5, 5), SpreadAngle = Vector2.new(35, 35),
		Acceleration = Vector3.new(0, 2, 0), Color = CS(C3(255, 200, 60), C3(255, 80, 20)), LightEmission = 1, EmissionDirection = Enum.NormalId.Top, LockedToPart = false})
	onSurface(emit("twinkle", p, {Size = 0.65, Rate = 5, Lifetime = NumberRange.new(0.7), Color = CS(C3(255, 250, 215)), ZOffset = 0.3, LockedToPart = true}))
	light(p, C3(255, 170, 60), 12, 1.6)
end
for _, p in ipairs(parts(top9, "BarGold$")) do   -- glowing bar
	p.Material = Enum.Material.Neon; p.Color = C3(255, 190, 60)
	for _, t in ipairs(p:GetChildren()) do if t:IsA("Texture") then t:Destroy() end end
end

-- 10 Planets: the cool part is the MODEL (ringed giant, Earth, moons + a tiny rocket that orbit).
-- Effects stay light: a soft atmosphere glow, a few stars, thin trails behind the orbiters.
local P = F["10 Planets"]
local barX = P.PrimaryPart.Position.X
local function side(p) return p.Position.X > barX and 1 or -1 end
for _, s in ipairs({1, -1}) do
	local globes, orbs = {}, {}
	for _, p in ipairs(P:GetChildren()) do
		if p:IsA("BasePart") and side(p) == s then
			if p.Name:find("^Globe") then globes[#globes + 1] = p elseif p.Name:find("^Orb") then orbs[#orbs + 1] = p end
		end
	end
	-- planet centre = middle of all its pieces; reference part = its biggest piece
	local mn, mx = Vector3.new(math.huge, math.huge, math.huge), Vector3.new(-math.huge, -math.huge, -math.huge)
	local ref
	for _, g in ipairs(globes) do
		local a, b = extents(g); mn = mn:Min(a); mx = mx:Max(b)
		if not ref or g.Size.Magnitude > ref.Size.Magnitude then ref = g end
	end
	local centre = (mn + mx) / 2
	local isGas = ref.Name:find("Gas") ~= nil
	local tint = isGas and C3(170, 130, 255) or C3(110, 180, 255)
	emit("glow", point(ref, centre), {Size = 4.2, Rate = 2, Lifetime = NumberRange.new(1.5), Color = CS(tint), Transparency = SOFT, ZOffset = -1.6, LockedToPart = true})
	onSurface(emit("twinkle", ref, {Size = 0.5, Rate = 2.5, Lifetime = NumberRange.new(0.8), Color = CS(C3(255, 255, 255)), ZOffset = 0.4, LockedToPart = true}))
	light(ref, tint, 9, 0.9)
	-- orbit data: axis = perpendicular to the orbiter's offset, in the plane of (up, bar direction)
	local axisOf = {}
	for _, o in ipairs(orbs) do
		local key = o.Name:find("^OrbSat") and "OrbSat" or o.Name   -- the rocket's body + nose share one orbit
		if not axisOf[key] then
			local body = o
			if key == "OrbSat" then
				for _, q in ipairs(orbs) do if q.Name:find("^OrbSatBody") then body = q end end
			end
			local r0 = body.Position - centre
			local n = r0:Cross(Vector3.new(0, 0, 1)).Unit
			if n.Y < 0 then n = -n end
			axisOf[key] = n
		end
		local speed = (o.Name:find("^OrbIce") and 1.1) or (o.Name:find("^OrbLava") and -0.8) or (o.Name:find("^OrbMoon") and 0.9) or 1.7
		local cf = ref.CFrame
		o:SetAttribute("OrbitSpeed", speed)
		o:SetAttribute("OrbitCenter", cf:PointToObjectSpace(centre))
		o:SetAttribute("OrbitAxis", cf:VectorToObjectSpace(axisOf[key]))
		local ov = o:FindFirstChild("OrbitRef") or Instance.new("ObjectValue")
		ov.Name = "OrbitRef"; ov.Value = ref; ov.Parent = o
		if not o.Name:find("Nose") then   -- thin fading trail (shows while it moves)
			local w = math.min(o.Size.X, o.Size.Y, o.Size.Z) * 0.35
			local a0, a1 = Instance.new("Attachment"), Instance.new("Attachment")
			a0.Name, a1.Name = "VFX_T0", "VFX_T1"
			a0.Position, a1.Position = Vector3.new(0, w, 0), Vector3.new(0, -w, 0)
			local tr = Instance.new("Trail")
			tr.Name = "VFX_Trail"; tr.Attachment0 = a0; tr.Attachment1 = a1; tr.FaceCamera = true
			tr.Lifetime = 0.55; tr.LightEmission = 0.8
			tr.Color = CS(o.Name:find("Sat") and C3(255, 170, 70) or o.Color)
			tr.Transparency = NS(0.35, 1); tr.WidthScale = NS(1, 0)
			for _, x in ipairs({a0, a1, tr}) do x:SetAttribute("WeightVFX", true); x.Parent = o end
		end
	end
end

-- the script that makes the Orb* parts circle their planet (runs on each player's client)
local old = P:FindFirstChild("PlanetOrbit"); if old then old:Destroy() end
local sc = Instance.new("Script")
sc.Name = "PlanetOrbit"
sc.RunContext = Enum.RunContext.Client
sc.Source = [[
-- Moves every part that has an OrbitSpeed attribute around its planet.
-- OrbitRef = the planet part, OrbitCenter / OrbitAxis are in that part's local space,
-- so the orbits follow the barbell when it is lifted or carried.
local RunService = game:GetService("RunService")
local model = script.Parent
task.wait(1)
local orbs = {}
for _, p in ipairs(model:GetDescendants()) do
	if p:IsA("BasePart") and p:GetAttribute("OrbitSpeed") then
		local ov = p:FindFirstChild("OrbitRef")
		local ref = ov and ov.Value
		if ref then
			local c = p:GetAttribute("OrbitCenter")
			local frame = ref.CFrame * CFrame.new(c)
			table.insert(orbs, {part = p, ref = ref, c = c, axis = p:GetAttribute("OrbitAxis"),
				speed = p:GetAttribute("OrbitSpeed"), rel = frame:ToObjectSpace(p.CFrame)})
		end
	end
end
local t0 = os.clock()
RunService.RenderStepped:Connect(function()
	local t = os.clock() - t0
	for _, o in ipairs(orbs) do
		if o.part.Parent and o.ref.Parent then
			o.part.CFrame = o.ref.CFrame * CFrame.new(o.c) * CFrame.fromAxisAngle(o.axis, o.speed * t) * o.rel
		end
	end
end)
]]
sc.Parent = P
