-- BarbellVFXKit (pigeon-claude, 11 Nov 2026). ServerStorage. Edit-time tool, not used by the running game.
-- Puts the weight effects on the barbell models: emitters copied from the game's own VFX pack
-- (ReplicatedStorage.Assets.VFX), resized and recoloured for each barbell, on invisible host parts at the two
-- plates ("VFX_PlateL" / "VFX_PlateR") and along the bar ("VFX_Bar"). Effects ramp up with the upgrade order.
--   require(game.ServerStorage.BarbellVFXKit:Clone()).apply(game.ServerStorage.Barbells)   -- (re)build all
--   .clear(folder) removes them again and switches the models' original emitters back on.
local K = {}
local VFX = game:GetService("ReplicatedStorage").Assets.VFX

local function c(r, g, b) return Color3.fromRGB(r, g, b) end
local GOLD, ORANGE, PINK, VIOLET, MAGENTA, CYAN, RED = c(255, 200, 40), c(255, 130, 30), c(255, 120, 175), c(190, 120, 255), c(255, 60, 220), c(120, 220, 255), c(255, 70, 50)

-- where: P = both plates, C = along the bar. k = size scale, v = speed scale (default k), rate per host.
-- centre = true: emitted from the middle of the plate (glows, rays); otherwise from the surface of the host box.
K.Spec = {
	["Copper Barbell"] = {},
	["Red Barbell"] = {},
	["Donut Barbell"] = {
		{"P", "TraitAuras/CONFETTI/3D Debris Rotation", k = 0.36, v = 0.1, rate = 3, props = {Acceleration = Vector3.new(0, -7, 0), Brightness = 2,
			Color = ColorSequence.new({ColorSequenceKeypoint.new(0, c(255, 120, 190)), ColorSequenceKeypoint.new(0.5, c(255, 225, 90)), ColorSequenceKeypoint.new(1, c(120, 215, 255))})}},
		{"P", "Traits/Angel/Blurred Spec 19", k = 0.25, rate = 1, color = c(255, 240, 250)},
	},
	["Bone Barbell"] = {
		{"P", "Traits/Angel/Pixelated Smoke Puff", k = 0.28, rate = 1.2, color = c(235, 228, 205), props = {Brightness = 1.5}},
	},
	["Pumpkin Barbell"] = {
		{"P", "Mutations/Gold/Core", k = 0.9, rate = 2, color = ORANGE, centre = true},
		{"P", "Traits/Volcano/Fire5", k = 0.2, rate = 4, color = ORANGE},
		{"P", "Traits/Volcano/OffCentered Spec 9", k = 0.6, v = 0.03, rate = 4, color = c(255, 180, 70), props = {Brightness = 4, LightEmission = 1}},
		light = {ORANGE, 0.8, 7},
	},
	["Rose Barbell"] = {
		{"P", "Mutations/Divine/Glitter", k = 2, rate = 9, color = PINK},
		{"P", "Mutations/Divine/Multiple Specs 2", k = 0.9, rate = 2, color = PINK},
		{"P", "Mutations/Divine/Shrinking Star", k = 1.8, rate = 2.5, color = c(255, 170, 200)},
	},
	["Golden Barbell"] = {
		{"C", "Mutations/Gold/Sparkles", k = 1, rate = 10},
		{"C", "TraitAuras/GOLD/Shrinking Star", k = 0.55, rate = 3},
		{"P", "Mutations/Gold/Core", k = 0.5, rate = 2, centre = true},
		light = {GOLD, 0.5, 6}, replaceOld = true,
	},
	["Ice Barbell"] = {
		{"P", "TraitAuras/ICE/Grey Galaxy Smoke", k = 0.5, rate = 5, color = c(170, 230, 255)},
		{"P", "TraitAuras/ICE/Glowing Snowflake Spinning 4x4", k = 0.5, v = 0.07, rate = 3},
		light = {CYAN, 0.8, 8}, replaceOld = true,
	},
	["Crystal Barbell"] = {
		{"P", "Mutations/Diamond/Rays", k = 1.6, rate = 2, color = VIOLET, centre = true},
		{"P", "Mutations/Divine/Glitter", k = 1.7, rate = 8, color = c(225, 185, 255)},
		{"P", "Mutations/Divine/Abstract Lens Flare", k = 1.4, rate = 2, color = c(225, 185, 255)},
		light = {VIOLET, 0.8, 8},
	},
	["Neon Pulse"] = {
		{"P", "Traits/Electric/Blurry Arc Lightning", k = 0.6, rate = 2, color = MAGENTA},
		{"P", "Traits/Electric/Pixelated Lightning Spark 2 4x4", k = 0.5, rate = 2, color = c(255, 150, 240)},
		{"P", "Traits/Electric/Glow", k = 0.42, rate = 2, color = MAGENTA, centre = true},
		{"C", "Traits/Electric/Stylized Lightning Flash 4x4", k = 0.45, rate = 1, color = c(255, 150, 240)},
		light = {MAGENTA, 1.2, 9},
	},
	["Havenstar Barbell"] = {
		{"P", "TraitAuras/STAR/Stylized Star Flipping4x4", k = 0.5, v = 0.08, rate = 3},
		{"P", "TraitAuras/GOLD/Flare27", k = 0.3, rate = 1, centre = true},
		{"P", "Mutations/Gold/Sparkles", k = 1.1, rate = 6},
		light = {GOLD, 1, 9},
	},
	["Mega Golden Barbell"] = {
		{"P", "Mutations/Gold/Rays", k = 2, rate = 3, centre = true},
		{"P", "Mutations/Gold/Core", k = 1.2, rate = 3, centre = true},
		{"P", "Mutations/Gold/Sparkles", k = 1.3, rate = 12},
		{"P", "TraitAuras/GOLD/Shrinking Star", k = 0.8, rate = 3},
		{"C", "Mutations/Gold/Sparkles", k = 1, rate = 6},
		light = {GOLD, 1.2, 10}, replaceOld = true,
	},
	["Giant Gold Star Barbell"] = {
		{"P", "Traits/Angel/Glowing Star Flipping4x4", k = 0.7, v = 0.08, rate = 3},
		{"P", "Traits/Angel/Rotating Star", k = 0.8, v = 0.1, rate = 5},
		{"P", "Traits/Disco/Rays", k = 0.5, rate = 3, color = c(255, 240, 90), centre = true},
		{"P", "Traits/Angel/Multiple Specs 37", k = 0.5, rate = 2, color = c(255, 220, 60)},
		light = {c(255, 235, 90), 1.3, 10}, replaceOld = true,
	},
	["Red Flyer"] = {
		{"P", "Traits/Volcano/Fire21", k = 0.26, rate = 3, color = c(255, 150, 40)},
		{"P", "Traits/Volcano/Fire728", k = 0.3, rate = 3, color = RED},
		{"P", "Traits/Volcano/OffCentered Spec 9", k = 0.6, v = 0.04, rate = 5, color = c(255, 110, 70), props = {Brightness = 4, LightEmission = 1}},
		light = {RED, 1.5, 10},
	},
	["Starfall Dumbbell"] = {
		{"P", "Traits/UFO/Galaxy Burst", k = 0.6, rate = 4},
		{"P", "Mutations/Celestial/Stars", k = 0.8, rate = 5},
		{"P", "Mutations/Celestial/Zaps", k = 1.2, rate = 4},
		light = {c(160, 90, 255), 1.5, 10},
	},
	["Star Light Dumbbell"] = {
		{"P", "Mutations/Gold/Rays", k = 2.2, rate = 4, color = c(255, 235, 150), centre = true},
		{"P", "Mutations/Secret/Stylized Glow Grey", k = 1.2, rate = 2, color = c(255, 215, 110), centre = true},
		{"P", "TraitAuras/STAR/Stylized Star Flipping4x4", k = 0.6, v = 0.08, rate = 5},
		{"P", "Mutations/Divine/Glitter", k = 1.5, rate = 8, color = c(255, 245, 190)},
		{"P", "Mutations/Divine/Abstract Lens Flare", k = 1.5, rate = 3, color = c(255, 235, 150)},
		{"C", "Mutations/Divine/Shrinking Star", k = 2, rate = 4, color = c(255, 245, 190)},
		{"C", "Mutations/Divine/Pixel Star", k = 3, rate = 3, color = c(255, 245, 190)},
		light = {c(255, 235, 170), 2, 12},
	},
}

local function source(path)
	local folder, item, name = path:match("^([^/]+)/([^/]+)/(.+)$")
	for _, it in VFX[folder]:GetChildren() do
		if it.Name == item then
			local e = it:FindFirstChild(name, true)
			if e and e:IsA("ParticleEmitter") then return e end
		end
	end
	error("BarbellVFXKit: no emitter " .. path)
end
local function scaleNS(ns, k)
	local kp = {}
	for _, p in ns.Keypoints do table.insert(kp, NumberSequenceKeypoint.new(p.Time, p.Value * k, p.Envelope * k)) end
	return NumberSequence.new(kp)
end

function K.clear(root)
	for _, d in root:GetDescendants() do
		if d:GetAttribute("BarbellVFX") then d:Destroy()
		elseif d:GetAttribute("OffForBarbellVFX") then d.Enabled = true; d:SetAttribute("OffForBarbellVFX", nil) end
	end
end

local function host(model, name, offset, size)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Transparency = 1
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow, p.Massless = true, false, false, false, false, true
	p.CFrame = model:GetPivot() * CFrame.new(offset)
	p:SetAttribute("BarbellVFX", true)
	p.Parent = model
	return p
end

function K.applyOne(model, name)
	local spec = K.Spec[name]
	if not spec then return false end
	K.clear(model)
	if #spec == 0 then return true end
	local _, size = model:GetBoundingBox()
	local grip = model:GetAttribute("GripHeight") or size.Y / 2
	local d = math.clamp(size.Y + 0.7, 1.6, 5)      -- a little bigger than the plate, so small bits float just off it
	local dz = math.clamp(size.Z + 0.7, 1.6, 5)
	local x = size.X / 2 - 0.85
	local hosts = {
		P = {host(model, "VFX_PlateL", Vector3.new(-x, grip, 0), Vector3.new(2, d, dz)), host(model, "VFX_PlateR", Vector3.new(x, grip, 0), Vector3.new(2, d, dz))},
		C = {host(model, "VFX_Bar", Vector3.new(0, grip, 0), Vector3.new(size.X - 3.2, 0.9, 0.9))},
	}
	if spec.replaceOld then
		for _, e in model:GetDescendants() do
			if e:IsA("ParticleEmitter") and e.Enabled and not e.Parent:GetAttribute("BarbellVFX") then e.Enabled = false; e:SetAttribute("OffForBarbellVFX", true) end
		end
	end
	for _, s in ipairs(spec) do
		local from = source(s[2])
		for _, h in hosts[s[1]] do
			local e = from:Clone()
			e.Name = "VFX_" .. s[2]:match("[^/]+$")
			e.Size = scaleNS(e.Size, s.k or 1)
			local v = s.v or s.k or 1
			e.Speed = NumberRange.new(e.Speed.Min * v, e.Speed.Max * v)
			e.Acceleration = e.Acceleration * v
			e.Rate = s.rate or e.Rate
			e.Enabled = true
			if s.color then e.Color = ColorSequence.new(s.color) end
			for prop, val in s.props or {} do e[prop] = val end
			if s.centre then   -- big glows and rays: from the middle of the plate
				local a = h:FindFirstChild("VFX_Centre") or Instance.new("Attachment")
				a.Name = "VFX_Centre"; a.Parent = h
				e.Parent = a
			else               -- small bits: all over a rounded shell around the plate (a Box only emits from one face)
				e.Shape, e.ShapeStyle, e.ShapePartial = Enum.ParticleEmitterShape.Sphere, Enum.ParticleEmitterShapeStyle.Surface, 1
				e.ShapeInOut = Enum.ParticleEmitterShapeInOut.Outward
				e.Parent = h
			end
		end
	end
	if spec.light then
		for _, h in hosts.P do
			local l = Instance.new("PointLight")
			l.Name = "VFX_Light"
			l.Color, l.Brightness, l.Range, l.Shadows = spec.light[1], spec.light[2], spec.light[3], false
			l.Parent = h
		end
	end
	return true
end

-- every model in the folder (previews may be named "<n> <name>")
function K.apply(root)
	local done = {}
	for _, m in root:GetChildren() do
		if m:IsA("Model") then
			local name = m.Name:gsub("^%d+ ", "")
			if K.applyOne(m, name) then table.insert(done, name) end
		end
	end
	return done
end

return K
