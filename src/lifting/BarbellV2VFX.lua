-- BarbellV2VFX (pigeon-claude, 11 Nov 2026). ServerStorage. Edit-time tool for the barbell v2 concepts
-- (Workspace.BarbellShowcase, not the game's real weights yet). Emitters are copied from the game's own VFX pack
-- (ReplicatedStorage.Assets.VFX), resized and recoloured per weight, on invisible hosts around each head
-- ("VFX_HeadL" / "VFX_HeadR", a shell just outside the head) and along the bar ("VFX_Bar"). All locked to the model.
-- Effects ramp up with the order: none on the first two, a light touch on the food ones, big on the top tiers.
--   require(game.ServerStorage.BarbellV2VFX:Clone()).apply(workspace.BarbellShowcase)
local K = {}
local VFX = game:GetService("ReplicatedStorage").Assets.VFX
local function c(r, g, b) return Color3.fromRGB(r, g, b) end
local function seq(...) local t = {} for i, col in {...} do t[i] = ColorSequenceKeypoint.new((i - 1) / math.max(1, select("#", ...) - 1), col) end return ColorSequence.new(t) end
local GOLD = c(255, 205, 50)

-- {where, "Folder/Item/Emitter", k = size scale, v = speed scale, rate = per host, centre = from the middle, color, props}
-- where: H = both heads, B = along the bar
K.Spec = {
	Copper = {}, Red = {},
	Donut = {
		{"H", "TraitAuras/CONFETTI/3D Debris Rotation", k = 0.32, v = 0.05, rate = 4, color = seq(c(255, 110, 180), c(255, 230, 80), c(110, 210, 255), c(140, 235, 120)),
			props = {Acceleration = Vector3.new(0, -6, 0)}},
	},
	Bone = {
		{"H", "Traits/Angel/Pixelated Smoke Puff", k = 0.22, rate = 1.5, color = c(240, 232, 210), props = {Brightness = 1.2}},
	},
	Pumpkin = {
		{"H", "Mutations/Gold/Core", k = 1.0, rate = 2, color = c(255, 130, 20), centre = true},
		{"H", "Traits/Volcano/OffCentered Spec 9", k = 0.6, v = 0.03, rate = 5, color = c(255, 170, 60), props = {Brightness = 4, LightEmission = 1}},
		{"H", "Traits/Volcano/Fire5", k = 0.16, rate = 3, color = c(255, 120, 20)},
		light = {c(255, 140, 30), 1.2, 8},
	},
	Rose = {
		{"H", "TraitAuras/CONFETTI/3D Debris Rotation", k = 0.3, v = 0.04, rate = 3, color = seq(c(255, 70, 110), c(255, 150, 180)), props = {Acceleration = Vector3.new(0, -3, 0)}},
		{"H", "Mutations/Divine/Glitter", k = 2, rate = 8, color = c(255, 150, 190)},
		light = {c(255, 90, 130), 0.8, 7},
	},
	Golden = {
		{"H", "Mutations/Gold/Sparkles", k = 1.4, rate = 14},
		{"H", "TraitAuras/GOLD/Shrinking Star", k = 0.7, rate = 4},
		{"B", "Mutations/Gold/Sparkles", k = 1, rate = 6},
		light = {GOLD, 1, 8},
	},
	Ice = {
		{"H", "TraitAuras/ICE/Grey Galaxy Smoke", k = 0.45, rate = 6, color = c(185, 235, 255)},
		{"H", "TraitAuras/ICE/Glowing Snowflake Spinning 4x4", k = 0.55, v = 0.05, rate = 4},
		{"H", "Mutations/Gold/Sparkles", k = 1.2, rate = 8, color = c(220, 245, 255)},
		light = {c(120, 220, 255), 1, 9},
	},
	Crystal = {
		{"H", "Mutations/Diamond/Rays", k = 1.8, rate = 2, color = c(190, 120, 255), centre = true},
		{"H", "Mutations/Divine/Glitter", k = 2, rate = 10, color = c(220, 180, 255)},
		{"H", "Mutations/Divine/Abstract Lens Flare", k = 1.5, rate = 2.5, color = c(225, 190, 255)},
		light = {c(170, 90, 255), 1.3, 9},
	},
	NeonPulse = {
		{"H", "Traits/Electric/Glow", k = 0.5, rate = 2, color = c(255, 50, 210), centre = true},
		{"H", "Traits/Electric/Blurry Arc Lightning", k = 0.6, rate = 2.5, color = c(255, 60, 220)},
		{"H", "Traits/Electric/Pixelated Lightning Spark 2 4x4", k = 0.5, rate = 2.5, color = c(255, 160, 240)},
		{"B", "Traits/Electric/Stylized Lightning Flash 4x4", k = 0.45, rate = 1.2, color = c(255, 160, 240)},
		light = {c(255, 40, 200), 1.8, 10},
	},
	Havenstar = {
		{"H", "Traits/Angel/Glowing Star Flipping4x4", k = 0.6, v = 0.06, rate = 4, color = c(255, 255, 255)},
		{"H", "Mutations/Secret/Stylized Glow Grey", k = 1.1, rate = 2, color = c(140, 240, 255), centre = true},
		{"H", "Mutations/Gold/Sparkles", k = 1.4, rate = 12, color = c(200, 250, 255)},
		light = {c(140, 235, 255), 1.5, 10},
	},
	MegaGolden = {
		{"H", "Mutations/Gold/Rays", k = 2.4, rate = 3, centre = true},
		{"H", "Mutations/Gold/Core", k = 1.4, rate = 3, centre = true},
		{"H", "Mutations/Gold/Sparkles", k = 1.6, rate = 16},
		{"H", "TraitAuras/GOLD/Shrinking Star", k = 0.9, rate = 4},
		{"B", "Mutations/Gold/Sparkles", k = 1.1, rate = 8},
		light = {GOLD, 1.8, 11},
	},
	GiantGoldStar = {
		{"H", "Traits/Angel/Glowing Star Flipping4x4", k = 0.8, v = 0.07, rate = 4},
		{"H", "Traits/Angel/Rotating Star", k = 0.9, v = 0.08, rate = 6},
		{"H", "Traits/Disco/Rays", k = 0.6, rate = 3, color = c(255, 240, 90), centre = true},
		{"H", "Traits/Angel/Multiple Specs 37", k = 0.55, rate = 2.5, color = c(255, 220, 60)},
		light = {c(255, 230, 80), 2, 11},
	},
	RedFlyer = {
		{"H", "Traits/Volcano/Fire21", k = 0.22, rate = 4, color = c(255, 170, 50)},
		{"H", "Traits/Volcano/OffCentered Spec 9", k = 0.7, v = 0.05, rate = 7, color = c(255, 120, 60), props = {Brightness = 4, LightEmission = 1}},
		{"H", "Traits/Meteor/Line Spec 26", k = 1, v = 1, rate = 12, color = c(255, 210, 160)},
		light = {c(255, 80, 40), 1.8, 11},
	},
	Starfall = {
		{"H", "Traits/UFO/Galaxy Burst", k = 0.55, rate = 5, centre = true},
		{"H", "Mutations/Celestial/Stars", k = 1, rate = 7},
		{"H", "Mutations/Celestial/Zaps", k = 1.4, rate = 5},
		{"H", "Mutations/Divine/Glitter", k = 2, rate = 10, color = c(255, 235, 150)},
		light = {c(160, 90, 255), 2, 12},
	},
	StarLight = {
		{"H", "Mutations/Gold/Rays", k = 2.8, rate = 4, color = c(255, 235, 150), centre = true},
		{"H", "Mutations/Secret/Stylized Glow Grey", k = 1.5, rate = 2.5, color = c(255, 215, 110), centre = true},
		{"H", "TraitAuras/STAR/Stylized Star Flipping4x4", k = 0.7, v = 0.07, rate = 6},
		{"H", "Mutations/Divine/Glitter", k = 2.2, rate = 12, color = c(255, 245, 190)},
		{"H", "Mutations/Divine/Abstract Lens Flare", k = 1.8, rate = 3, color = c(255, 235, 150)},
		{"B", "Mutations/Divine/Shrinking Star", k = 2.2, rate = 5, color = c(255, 245, 190)},
		light = {c(255, 225, 140), 2.5, 14},
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
	error("BarbellV2VFX: no emitter " .. path)
end
local function scaleNS(ns, k)
	local kp = {}
	for _, p in ns.Keypoints do table.insert(kp, NumberSequenceKeypoint.new(p.Time, p.Value * k, p.Envelope * k)) end
	return NumberSequence.new(kp)
end

function K.clear(model)
	for _, d in model:GetDescendants() do if d:GetAttribute("BarbellVFX") then d:Destroy() end end
end

local function host(model, name, cf, size)
	local p = Instance.new("Part")
	p.Name = name; p.Size = size; p.Transparency = 1; p.CFrame = cf
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow, p.Massless = true, false, false, false, false, true
	p:SetAttribute("BarbellVFX", true)
	p.Parent = model
	return p
end

function K.applyOne(model, key)
	local spec = K.Spec[key]
	if not spec then return false end
	K.clear(model)
	if #spec == 0 then return true end
	-- bounding box of the weight itself (not its sign)
	local lo, hi = Vector3.one * 1e9, -Vector3.one * 1e9
	for _, p in model:GetDescendants() do
		if p:IsA("BasePart") and p.Name ~= "Sign" and not p:GetAttribute("BarbellVFX") then
			lo = lo:Min(p.Position - p.Size / 2); hi = hi:Max(p.Position + p.Size / 2)
		end
	end
	local centre, size = (lo + hi) / 2, hi - lo
	local half = size.X / 2
	local inner = 2.2                                   -- the grip zone ends here; heads are outside it
	local headLen = math.max(1, half - inner)
	local hx = inner + headLen / 2
	local hostSize = Vector3.new(headLen + 0.6, size.Y + 0.4, size.Z + 0.4)
	local hosts = {
		H = {host(model, "VFX_HeadL", CFrame.new(centre + Vector3.new(-hx, 0, 0)), hostSize), host(model, "VFX_HeadR", CFrame.new(centre + Vector3.new(hx, 0, 0)), hostSize)},
		B = {host(model, "VFX_Bar", CFrame.new(centre), Vector3.new(inner * 2 - 0.6, 0.9, 0.9))},
	}
	for _, s in ipairs(spec) do
		local from = source(s[2])
		for _, h in hosts[s[1]] do
			local e = from:Clone()
			e.Name = "VFX_" .. s[2]:match("[^/]+$")
			e.Size = scaleNS(e.Size, s.k or 1)
			local v = s.v or s.k or 1
			e.Speed = NumberRange.new(e.Speed.Min * v, e.Speed.Max * v)
			e.Rate = s.rate or e.Rate
			e.Enabled = true
			e.LockedToPart = true
			if s.color then e.Color = typeof(s.color) == "ColorSequence" and s.color or ColorSequence.new(s.color) end
			for prop, val in s.props or {} do e[prop] = val end
			if s.centre then
				local a = h:FindFirstChild("VFX_Centre") or Instance.new("Attachment")
				a.Name = "VFX_Centre"; a.Parent = h
				e.Parent = a
			else
				e.Shape, e.ShapeStyle, e.ShapePartial = Enum.ParticleEmitterShape.Sphere, Enum.ParticleEmitterShapeStyle.Surface, 1
				e.ShapeInOut = Enum.ParticleEmitterShapeInOut.Outward
				e.Parent = h
			end
		end
	end
	if spec.light then
		for _, h in hosts.H do
			local l = Instance.new("PointLight")
			l.Name = "VFX_Light"; l.Color, l.Brightness, l.Range, l.Shadows = spec.light[1], spec.light[2], spec.light[3], false
			l.Parent = h
		end
	end
	return true
end

function K.apply(folder)
	local done = {}
	for _, m in folder:GetChildren() do
		local key = m:IsA("Model") and m.Name:match("^Barbell_(.+)$")
		if key and K.applyOne(m, key) then table.insert(done, key) end
	end
	return done
end

return K
