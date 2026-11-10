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
for _, p in ipairs(parts(top9, "BarGold$")) do   -- glowing bar on the top tier
	p.Material = Enum.Material.Neon; p.Color = C3(255, 190, 60)
	for _, t in ipairs(p:GetChildren()) do if t:IsA("Texture") then t:Destroy() end end
end
