-- Client side of hatching (server: ServerScriptService.EggHatching):
--  * shows the patch prompts only on your own plot ("Place Egg" while holding an egg, "Hatch" when ready)
--  * plays the hatch animation (wobbles, white flash, burst with ReplicatedStorage.Assets.VFX, animal pops out)
--  * placing: hold an animal, hover your plot's Land to see a see-through copy, click to place, R to turn it
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local player = Players.LocalPlayer
local H = RS:WaitForChild("Hatching")
local C = require(H:WaitForChild("HatchConfig"))
local VFX = RS:WaitForChild("Assets"):WaitForChild("VFX")
local FXROOTS = {VFX:WaitForChild("Effects"), VFX:WaitForChild("ScreenParticles")}
local Sounds = RS:WaitForChild("DevDemo"):FindFirstChild("Sounds")
local plots = workspace:WaitForChild("Plots")
local CAM = RS:WaitForChild("CamParticles")
local EggRoll = require(RS:WaitForChild("DevDemo"):WaitForChild("EggRoll"))

local function myPlot()
	local n = player:GetAttribute("Plot")
	return n and plots:FindFirstChild(n)
end
local function held(attr)
	local c = player.Character
	local t = c and c:FindFirstChildOfClass("Tool")
	return t and t:GetAttribute(attr) and t or nil
end

local function sfx(name, vol, pitch)
	local s = Sounds and Sounds:FindFirstChild(name)
	if not s then return end
	s = s:Clone()
	s.Volume = vol or 0.5
	s.PlaybackSpeed = pitch or 1
	s.Parent = workspace.CurrentCamera
	s:Play()
	Debris:AddItem(s, 6)
	return s
end

-- burst(effectName, part, worldPos?, scale?, countMul?)
local function burst(name, part, pos, scale, countMul)
	local src
	for _, root in FXROOTS do src = src or root:FindFirstChild(name) end
	if not (src and part) then return end
	scale = scale or 1
	local att = Instance.new("Attachment")
	att.Parent = part
	att.WorldPosition = pos or part.Position
	for _, e in src:GetDescendants() do
		if e:IsA("ParticleEmitter") then
			local c = e:Clone()
			c.Enabled = false
			if scale ~= 1 then
				local kps = {}
				for _, k in c.Size.Keypoints do table.insert(kps, NumberSequenceKeypoint.new(k.Time, k.Value * scale, k.Envelope * scale)) end
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

-- camBurst(name): plays ReplicatedStorage.CamParticles[name] on your screen (an invisible part rides in front of the camera)
local CAM_DIST = 5
local function camBurst(name)
	local src = CAM:FindFirstChild(name)
	local cam = workspace.CurrentCamera
	if not (src and CAM:FindFirstChild("Part")) then return end
	local host = CAM.Part:Clone()
	host.Name = "CamFX"
	host.CFrame = cam.CFrame * CFrame.new(0, 0, -CAM_DIST)
	host.Parent = cam
	local att = host:FindFirstChildOfClass("Attachment")
	for _, e in src:GetChildren() do
		if e:IsA("ParticleEmitter") then
			local c = e:Clone()
			c.Enabled = false
			c.Parent = att
			-- big still sprites (flare, sunburst, wave) fire once (stacking them whites out the screen), rays a few;
			-- moving sparkles fire their Rate, very high-rate ones ~0.1 s worth
			local n
			if e.Speed.Max == 0 then n = e.Name == "Rays" and 3 or 1
			elseif e.Rate <= 12 then n = math.max(1, math.round(e.Rate))
			else n = math.round(e.Rate * 0.1) end
			c:Emit(n)
		end
	end
	local con = RunService.RenderStepped:Connect(function()
		host.CFrame = cam.CFrame * CFrame.new(0, 0, -CAM_DIST)
	end)
	task.delay(3, function() con:Disconnect(); host:Destroy() end)
end

------------------------------------------------------------ prompts
task.spawn(function()
	while true do
		local mine = myPlot()
		local egg = held("EggName")
		for _, plot in plots:GetChildren() do
			local patches = plot:FindFirstChild("Patches")
			for _, patch in patches and patches:GetChildren() or {} do
				local pp = patch:FindFirstChild("HatchPrompt", true)
				if pp then
					local state = patch:GetAttribute("State")
					if plot == mine and state == "Empty" and egg then
						pp.ActionText = "Place Egg"
						pp.ObjectText = egg:GetAttribute("EggName") .. " Egg"
						pp.Enabled = true
					elseif plot == mine and state == "Ready" then
						pp.ActionText = "Hatch"
						pp.ObjectText = (patch:GetAttribute("Egg") or "") .. " Egg"
						pp.Enabled = true
					else
						pp.Enabled = false
					end
				end
			end
		end
		task.wait(0.15)
	end
end)

------------------------------------------------------------ effect helpers
local RAR_COL = {}
for r, t in EggRoll.Colors do RAR_COL[r] = Color3.fromHex(r == "Secret" and t[3] or t[1]) end
local function rarityInfo(name)
	local r = EggRoll.rarityOf(name)
	return table.find(EggRoll.Order, r) or 1, RAR_COL[r] or Color3.new(1, 1, 1)
end

local function fxPart(size, color, cf, shape)
	local p = Instance.new("Part")
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
	p.Material = Enum.Material.Neon
	p.Color = color
	if shape then p.Shape = shape end
	p.Size = size
	p.CFrame = cf
	p.Parent = workspace
	return p
end

-- run(dur, fn(a, dt)): calls fn every frame with a going 0 -> 1
local function run(dur, fn)
	local t = 0
	while t < dur do
		local dt = RunService.RenderStepped:Wait()
		t += dt
		fn(math.min(t / dur, 1), dt)
	end
end

-- a ring of glowing blocks spreading out flat on the ground
local function ring(pos, color, r0, r1, dur, n)
	n = n or 20
	local bits = {}
	for k = 1, n do bits[k] = fxPart(Vector3.new(0.5, 0.25, 0.5), color, CFrame.new(pos)) end
	task.spawn(function()
		run(dur, function(a)
			local r = r0 + (r1 - r0) * (1 - (1 - a) ^ 3)
			for k, b in bits do
				local ang = k / n * math.pi * 2
				b.Size = Vector3.new(0.45, 0.25, math.max(0.3, r * 2 * math.pi / n * 0.55))
				b.CFrame = CFrame.new(pos + Vector3.new(math.cos(ang) * r, 0, math.sin(ang) * r)) * CFrame.Angles(0, -ang, 0)
				b.Transparency = a ^ 1.5
			end
		end)
		for _, b in bits do b:Destroy() end
	end)
end

-- little blocky shell pieces that fly out, bounce on the ground and fade
local function shards(pos, n, colors, speed, groundY)
	local list = {}
	for k = 1, n do
		local sz = 0.3 + math.random() * 0.35
		local p = fxPart(Vector3.new(sz, sz, sz), colors[math.random(#colors)], CFrame.new(pos))
		p.Material = Enum.Material.SmoothPlastic
		local ang = math.random() * math.pi * 2
		local v = Vector3.new(math.cos(ang), 0, math.sin(ang)) * speed * (0.4 + math.random() * 0.6) + Vector3.new(0, speed * (0.8 + math.random() * 0.7), 0)
		list[k] = {p = p, v = v, spin = Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5) * 18}
	end
	task.spawn(function()
		run(1.3, function(a, dt)
			for _, sh in list do
				sh.v += Vector3.new(0, -70 * dt, 0)
				local np = sh.p.Position + sh.v * dt
				local floor = groundY + sh.p.Size.Y / 2
				if np.Y < floor then
					np = Vector3.new(np.X, floor, np.Z)
					sh.v = Vector3.new(sh.v.X * 0.5, -sh.v.Y * 0.3, sh.v.Z * 0.5)
				end
				sh.p.CFrame = CFrame.new(np) * sh.p.CFrame.Rotation * CFrame.Angles(sh.spin.X * dt, sh.spin.Y * dt, sh.spin.Z * dt)
				sh.p.Transparency = a > 0.7 and (a - 0.7) / 0.3 or 0
			end
		end)
		for _, sh in list do sh.p:Destroy() end
	end)
end

local function flashBall(pos, color, size, dur, t0)
	t0 = t0 or 0
	local p = fxPart(Vector3.one, color, CFrame.new(pos), Enum.PartType.Ball)
	task.spawn(function()
		run(dur, function(a)
			p.Size = Vector3.one * (0.5 + size * (1 - (1 - a) ^ 2))
			p.Transparency = t0 + (1 - t0) * a
		end)
		p:Destroy()
	end)
end

-- a beam of light shooting up out of the egg (rarer eggs)
local function pillar(pos, color, height, dur)
	local p = fxPart(Vector3.new(height, 0.1, 0.1), color, CFrame.new(pos + Vector3.new(0, height / 2, 0)) * CFrame.Angles(0, 0, math.pi / 2), Enum.PartType.Cylinder)
	task.spawn(function()
		run(dur, function(a)
			local w = a < 0.12 and a / 0.12 * 2.2 or 2.2 * (1 - (a - 0.12) / 0.88)
			p.Size = Vector3.new(height, math.max(w, 0.05), math.max(w, 0.05))
			p.Transparency = 0.4 + 0.6 * a ^ 2
		end)
		p:Destroy()
	end)
end

local function fovTo(f, dur)
	local cam = workspace.CurrentCamera
	if cam.CameraType ~= Enum.CameraType.Custom then return end
	TweenService:Create(cam, TweenInfo.new(dur, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {FieldOfView = f}):Play()
end

local function fresh(inst)
	local at = inst:GetAttribute("PlacedAt")
	return at and workspace:GetServerTimeNow() - at < 1.5
end

------------------------------------------------------------ hatch animation
-- Kept simple (Jacob): light cracks out of the egg as it wobbles (ReplicatedStorage.Assets.VFX.Ray),
-- then the egg breaks away and the animal pops out and goes into your inventory.
local RAY = VFX:WaitForChild("Ray")
H.HatchFX.OnClientEvent:Connect(function(egg, name, who, mut)
	if not (egg and egg.Parent) then return end
	local mine = who == player
	local rank, col = rarityInfo(name)
	if rank == 1 then col = Color3.new(1, 1, 1) end   -- Commons hatch in plain white light (their rarity colour is green)
	local h = egg.Size.Y
	local size0 = egg.Size
	local bottom = egg.CFrame * CFrame.new(0, -h / 2, 0)
	local center = bottom.Position + Vector3.new(0, h / 2, 0)
	local groundY = bottom.Position.Y
	local function pose(angle, sx, sy)
		if not egg.Parent then return end
		egg.Size = Vector3.new(size0.X * sx, size0.Y * sy, size0.Z * sx)
		egg.CFrame = bottom * CFrame.Angles(0, 0, angle) * CFrame.new(0, egg.Size.Y / 2, 0)
	end
	-- the light cracks: Jacob's Ray emitter, sized to the egg
	local host = Instance.new("Part")
	host.Anchored, host.CanCollide, host.CanQuery, host.CanTouch = true, false, false, false
	host.Transparency = 1
	host.Size = Vector3.one
	host.CFrame = CFrame.new(center)
	host.Parent = workspace
	Debris:AddItem(host, 8)
	local att = Instance.new("Attachment")
	att.Parent = host
	local ray = RAY:Clone()
	ray.Enabled = false
	local k = h * 1.1 / 8
	local kps = {}
	for _, kp in ray.Size.Keypoints do table.insert(kps, NumberSequenceKeypoint.new(kp.Time, kp.Value * k, kp.Envelope * k)) end
	ray.Size = NumberSequence.new(kps)
	ray.Color = ColorSequence.new(Color3.new(1, 1, 1):Lerp(col, 0.35))
	ray.ZOffset = 2
	ray.Brightness = ray.Brightness * 0.45     -- toned down (Jacob: the white glow was too much)
	ray.Parent = att
	local glow = Instance.new("PointLight")
	glow.Color, glow.Range, glow.Brightness, glow.Shadows = col, 10, 0, false
	glow.Parent = host

	-- the build-up starts with the first wobble and is timed to peak as the egg breaks (Riser is 4 s;
	-- at x2.4 it lasts the ~1.7 s of wobbles + shake), then it's cut on the break
	local riser = mine and sfx("Riser", 0.3, 2.4)
	-- 1. three wobbles; each one cracks more light out
	for n, amp in {0.14, 0.24, 0.36} do
		run(0.44 - n * 0.06, function(a) pose(math.sin(a * math.pi * 2) * amp, 1, 1) end)
		pose(0, 1, 1)
		ray:Emit(n == 3 and 2 or 1)
		glow.Brightness = n * 0.35
		if mine then sfx("RollTick", 0.7, 0.85 + n * 0.15) end
		task.wait(0.1)
	end
	-- 2. a quick shake while the light pours out
	ray.Rate = 6
	ray.Enabled = true
	run(0.4, function(a) pose(math.sin(a * 48) * 0.05, 1, 1); glow.Brightness = 1.1 + 0.7 * a end)
	ray.Enabled = false
	-- 3. it breaks away
	egg.LocalTransparencyModifier = 1
	for _, d in egg:GetDescendants() do if d:IsA("Decal") then pcall(function() d.LocalTransparencyModifier = 1 end) end end
	if riser then TweenService:Create(riser, TweenInfo.new(0.12), {Volume = 0}):Play(); Debris:AddItem(riser, 0.2) end
	ray:Emit(2)
	burst("Poof", host, Vector3.new(center.X, groundY + 0.3, center.Z), 0.6, 0.7)
	TweenService:Create(glow, TweenInfo.new(0.6), {Brightness = 0}):Play()
	if mine then sfx("BarPop", 0.7, 1.1); sfx("ConfettiPop", 0.45, 1) end

	-- 4. the animal pops out, spins once, then flies into you
	local tmpl = C.animalTemplate(name, mut)
	if not tmpl then return end
	local m = tmpl:Clone()
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") then d.Anchored, d.CanCollide, d.CanQuery, d.CanTouch = true, false, false, false end
	end
	local sz = C.mesh(m).Size
	local full = m:GetScale() * 5 / math.max(sz.X, sz.Y, sz.Z)
	m:ScaleTo(full * 0.05)
	m.Parent = workspace
	local function pose2(kk, yaw, at)
		m:ScaleTo(full * math.max(kk, 0.05))
		local mesh = C.mesh(m)
		local feet = m:GetPivot().Y - (mesh.Position.Y - mesh.Size.Y / 2)
		m:PivotTo(CFrame.new(at.X, at.Y + feet, at.Z) * CFrame.Angles(0, yaw, 0))
	end
	local spot = Vector3.new(center.X, groundY, center.Z)
	run(1.05, function(a)
		local t = a * 1.05
		local kk = TweenService:GetValue(math.min(t / 0.35, 1), Enum.EasingStyle.Back, Enum.EasingDirection.Out)
		pose2(kk, math.pi + a * math.pi * 2, spot + Vector3.new(0, math.min(t / 0.35, 1) * 1.5, 0))
	end)
	local from = spot + Vector3.new(0, 1.5, 0)
	local char = who and who.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	local to = root and root.Position or from + Vector3.new(0, 6, 0)
	run(0.35, function(a)
		local e = a * a
		pose2(1 - e * 0.9, math.pi, from:Lerp(to, e) + Vector3.new(0, math.sin(a * math.pi) * 3, 0))
	end)
	m:Destroy()
	if mine then sfx("BarPop", 0.6, 1.5) end
end)

------------------------------------------------------------ placing effects (egg on a patch, animal on the Land)
local function onEggPlaced(egg)
	task.wait()
	if not (egg.Parent and fresh(egg)) then return end
	local plot = egg.Parent.Parent and egg.Parent.Parent.Parent
	local mine = plot == myPlot()
	local cf, size = egg.CFrame, egg.Size
	local bottom = cf.Position - Vector3.new(0, size.Y / 2, 0)
	-- drops in from above
	run(0.22, function(a) egg.CFrame = cf + Vector3.new(0, 5 * (1 - a * a), 0) end)
	burst("Poof", egg, bottom + Vector3.new(0, 0.2, 0), 0.6)
	burst("Sparkles", egg, cf.Position, 0.5, 0.6)
	if mine then sfx("BallLand", 0.5, 1.1); sfx("BarPop", 0.5, 1.3) end
	-- squash on landing, then spring back
	run(0.3, function(a)
		local b = TweenService:GetValue(a, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
		local sy, sx = 0.7 + 0.3 * b, 1.2 - 0.2 * b
		egg.Size = Vector3.new(size.X * sx, size.Y * sy, size.Z * sx)
		egg.CFrame = CFrame.new(bottom + Vector3.new(0, egg.Size.Y / 2, 0)) * cf.Rotation
	end)
	egg.Size, egg.CFrame = size, cf
end

local function onAnimalPlaced(m)
	task.wait()
	if not (m.Parent and fresh(m)) then return end
	local mesh = C.mesh(m)
	if not mesh then return end
	local plot = m.Parent.Parent
	local mine = plot == myPlot()
	local cf0, s0 = m:GetPivot(), m:GetScale()
	local base = Vector3.new(cf0.X, mesh.Position.Y - mesh.Size.Y / 2, cf0.Z)
	local _, col = rarityInfo(m:GetAttribute("AnimalName") or m.Name)
	-- pops up from nothing and drops onto the Land
	run(0.32, function(a)
		m:ScaleTo(s0 * math.max(TweenService:GetValue(a, Enum.EasingStyle.Back, Enum.EasingDirection.Out), 0.05))
		m:PivotTo(cf0 + Vector3.new(0, 3 * (1 - a) ^ 2, 0))
	end)
	m:ScaleTo(s0)
	m:PivotTo(cf0)
	local reach = math.max(mesh.Size.X, mesh.Size.Z) * 0.5
	burst("Poof", workspace.Terrain, base + Vector3.new(0, 0.3, 0), 0.6 + reach * 0.08)
	burst("Sparkles", workspace.Terrain, base + Vector3.new(0, mesh.Size.Y * 0.5, 0), 0.7)
	if mine then sfx("PlaceAnimal", 0.6, 1) end
end

plots.DescendantAdded:Connect(function(d)
	local p = d.Parent
	if d.Name == "HatchEgg" and d:IsA("BasePart") and p and p.Parent and p.Parent.Name == "Patches" then
		task.spawn(onEggPlaced, d)
	elseif d:IsA("Model") and p and p.Name == "Animals" then
		task.spawn(onAnimalPlaced, d)
	end
end)

------------------------------------------------------------ placing animals
local ghost, ghostFor, ghostRadius, ghostHl
local target, targetOk = nil, false
local yaw = math.pi
local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Include

local function clearGhost()
	if ghost then ghost:Destroy() end
	ghost, ghostFor, target = nil, nil, nil
end

local function makeGhost(name, mut)
	local tmpl = C.animalTemplate(name, mut)
	if not tmpl then return end
	local k, r = C.placedScale(tmpl)
	local m = tmpl:Clone()
	m:ScaleTo(m:GetScale() * k)
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored, d.CanCollide, d.CanQuery, d.CanTouch, d.CastShadow = true, false, false, false, false
			d.Transparency = 0.5
		elseif d:IsA("Texture") or d:IsA("Decal") then
			d.Transparency = 0.6
		end
	end
	local hl = Instance.new("Highlight")
	hl.FillTransparency, hl.OutlineTransparency = 0.65, 0.2
	hl.DepthMode = Enum.HighlightDepthMode.Occluded
	hl.Parent = m
	ghost, ghostFor, ghostRadius, ghostHl = m, name, r, hl
end

RunService.RenderStepped:Connect(function()
	local tool = held("AnimalName")
	local plot = myPlot()
	local land = C.land(plot)
	if not (tool and land) then clearGhost(); return end
	local mut = tool:GetAttribute("Mutation")
	local name = tool:GetAttribute("AnimalName")
	local key = (mut or "") .. name
	if ghostFor ~= key then clearGhost(); makeGhost(name, mut); ghostFor = ghost and key end
	if not ghost then return end
	params.FilterDescendantsInstances = {land}
	local mp = UIS:GetMouseLocation()
	local ray = workspace.CurrentCamera:ViewportPointToRay(mp.X, mp.Y)
	local hit = workspace:Raycast(ray.Origin, ray.Direction * 600, params)
	if not hit then ghost.Parent = nil; target = nil; return end
	target = hit.Position
	targetOk = C.canPlace(plot, target, ghostRadius)
	ghost:PivotTo(C.placedCFrame(land, ghost, target, yaw))
	local col = targetOk and Color3.fromRGB(120, 255, 120) or Color3.fromRGB(255, 80, 80)
	ghostHl.FillColor, ghostHl.OutlineColor = col, col
	ghost.Parent = workspace
end)

UIS.InputBegan:Connect(function(input, processed)
	if processed then return end
	if input.KeyCode == Enum.KeyCode.R and ghost then
		yaw += math.pi / 2
	elseif input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		local tool = held("AnimalName")
		if tool and target and targetOk then
			H.PlaceAnimal:FireServer(tool, target, yaw)
		end
	end
end)

------------------------------------------------------------ placed animals: name tag + walking around
-- Only on your screen (the server keeps each animal where it was placed).
local G = require(RS:WaitForChild("GameConfig"))
local KSP = game:GetService("KeyframeSequenceProvider")
local animIds = {}
local function animId(name, kind)
	animIds[name] = animIds[name] or {}
	local cached = animIds[name][kind]
	if cached ~= nil then return cached or nil end
	local id = G.AnimalAnims[name] and G.AnimalAnims[name][kind]
	if not id then   -- Studio only: the unpublished KeyframeSequences the penalty demo copies over
		local A = RS:FindFirstChild("PenaltyDemoAssets")
		local set = A and A:FindFirstChild("AnimSets") and A.AnimSets:FindFirstChild(name)
		local ks = set and set:FindFirstChild(kind)
		if ks then
			local ok, res = pcall(KSP.RegisterKeyframeSequence, KSP, ks)
			if ok then id = res end
		end
	end
	animIds[name][kind] = id or false
	return id
end

local walkers = {}
local function playOnly(w, kind)
	for k, t in w.tracks do
		if k == kind then if not t.IsPlaying then t:Play(0.25) end else t:Stop(0.25) end
	end
end

local function setupAnimal(m)
	if walkers[m] then return end
	task.wait(0.5)   -- let the placing pop finish first
	-- with streaming (live servers, and when you rejoin) the model, its mesh or the plot's Land can arrive
	-- a moment later: keep checking for up to 15 s instead of giving up (that left saved animals with
	-- no outline, no tag and not walking)
	local mesh, plot, land
	for _ = 1, 150 do
		if not m.Parent or walkers[m] then return end
		mesh = C.mesh(m)
		plot = m.Parent and m.Parent.Parent
		land = plot and C.land(plot)
		if mesh and land then break end
		task.wait(0.1)
	end
	if not (mesh and land) or walkers[m] then return end
	local name = m:GetAttribute("AnimalName") or m.Name
	local rarity = EggRoll.rarityOf(name)
	local tag = H.AnimalInfo:Clone()
	tag.Adornee = mesh
	tag.StudsOffsetWorldSpace = Vector3.new(0, mesh.Size.Y / 2 + 1.4, 0)
	tag.NameLabel.Text = name
	tag.Rarity.Text = rarity
	tag.Rarity.TextColor3 = RAR_COL[rarity] or Color3.new(1, 1, 1)
	-- cash per second straight away (the template's placeholder says "Income"); the loop below keeps it current
	local owner = Players:GetPlayerByUserId(plot:GetAttribute("Owner") or 0)
	tag.Income.Text = "$" .. G.short(G.AnimalIncome(name) * G.mutIncome(m:GetAttribute("Mutation")) * (owner and owner:GetAttribute("CashMulti") or 1)) .. "/s"
	local mutation = m:GetAttribute("Mutation")
	tag.Mutation.Text = mutation or ""
	local mi = mutation and G.MutationInfo[mutation]
	if mi and mi.Color then tag.Mutation.TextColor3 = mi.Color end
	tag.Mutation.Visible = mutation ~= nil
	tag.Parent = m
	local outline = Instance.new("Highlight")   -- black outline (Jacob)
	outline.FillTransparency = 1
	outline.OutlineColor = Color3.new(0, 0, 0)
	outline.OutlineTransparency = 0
	outline.DepthMode = Enum.HighlightDepthMode.Occluded
	outline.Parent = m
	local tracks = {}
	local ac = m:FindFirstChildOfClass("AnimationController")
	local animator = ac and ac:FindFirstChildOfClass("Animator")
	if animator then
		for _, kind in {"Idle", "Walk"} do
			local id = animId(name, kind)
			-- live game: unpublished clips play through ReplicatedStorage.KSTrack instead
			local A = RS:FindFirstChild("PenaltyDemoAssets")
			local set = A and A:FindFirstChild("AnimSets") and A.AnimSets:FindFirstChild(name)
			local ks = set and set:FindFirstChild(kind)
			if ks and not (G.AnimalAnims[name] and G.AnimalAnims[name][kind]) and (not game:GetService("RunService"):IsStudio() or workspace:GetAttribute("ForceKSTrack")) then
				local t = require(RS:WaitForChild("KSTrack")).new(m, ks)
				t.Looped = true
				tracks[kind] = t
			elseif id then
				local a = Instance.new("Animation")
				a.AnimationId = id
				local ok, t = pcall(animator.LoadAnimation, animator, a)
				if ok then t.Looped = true; tracks[kind] = t end
			end
		end
		tracks.Walk = tracks.Walk or tracks.Idle   -- e.g. the Blobfish only has Idle
	end
	local cf = m:GetPivot()
	local look = cf.LookVector
	local w = {
		tracks = tracks, land = land, plot = plot, name = name, tag = tag,
		pos = cf.Position, yaw = math.atan2(-look.X, -look.Z),
		radius = m:GetAttribute("Radius") or 2, mut = m:GetAttribute("Mutation"),
		state = "idle", timer = 1 + math.random() * 4,
	}
	w.speed = math.clamp(2 + w.radius * 0.4, 2, 6)
	-- (pigeon, 11 Nov 2026) loading in: start each animal at a random free spot on the land, not the saved rows
	-- ("Equip best" saves them side by side). Only on your screen, like the walking; one you just placed stays put.
	local placedAt = m:GetAttribute("PlacedAt")
	if not (placedAt and workspace:GetServerTimeNow() - placedAt < 10) then
		local mx = math.max(0, land.Size.X / 2 - w.radius)
		local mz = math.max(0, land.Size.Z / 2 - w.radius)
		local best, bestGap = nil, -math.huge
		for _ = 1, 24 do   -- the try furthest from the animals already out
			local p = land.CFrame:PointToWorldSpace(Vector3.new((math.random() * 2 - 1) * mx, 0, (math.random() * 2 - 1) * mz))
			local gap = math.huge
			for _, o in walkers do
				if o.land == land then gap = math.min(gap, Vector2.new(o.pos.X - p.X, o.pos.Z - p.Z).Magnitude - o.radius - w.radius) end
			end
			if gap > bestGap then best, bestGap = p, gap end
		end
		w.pos = Vector3.new(best.X, w.pos.Y, best.Z)
		w.yaw = math.random() * 2 * math.pi
		m:PivotTo(CFrame.new(w.pos) * CFrame.Angles(0, w.yaw, 0))
	end
	walkers[m] = w
	playOnly(w, "Idle")
end

local function pickTarget(w)
	local land = w.land
	local mx = math.max(0, land.Size.X / 2 - w.radius)
	local mz = math.max(0, land.Size.Z / 2 - w.radius)
	local here = land.CFrame:PointToObjectSpace(w.pos)
	local x = math.clamp(here.X + (math.random() * 2 - 1) * 12, -mx, mx)
	local z = math.clamp(here.Z + (math.random() * 2 - 1) * 12, -mz, mz)
	local p = land.CFrame:PointToWorldSpace(Vector3.new(x, 0, z))
	return Vector3.new(p.X, w.pos.Y, p.Z)
end

RunService.Heartbeat:Connect(function(dt)
	for m, w in walkers do
		if not m.Parent then
			walkers[m] = nil
			continue
		end
		if w.state == "idle" then
			w.timer -= dt
			if w.timer <= 0 then
				w.target = pickTarget(w)
				w.state = "walk"
				playOnly(w, "Walk")
			end
		else
			local flat = Vector3.new(w.target.X - w.pos.X, 0, w.target.Z - w.pos.Z)
			local d = flat.Magnitude
			if d < 0.3 then
				w.state = "idle"
				w.timer = 2 + math.random() * 5
				playOnly(w, "Idle")
			else
				local dir = flat.Unit
				local want = math.atan2(-dir.X, -dir.Z)
				local diff = (want - w.yaw + math.pi) % (2 * math.pi) - math.pi
				w.yaw += diff * math.min(1, dt * 6)
				if math.abs(diff) < 0.8 then w.pos += dir * math.min(d, w.speed * dt) end   -- turn first, then walk
				m:PivotTo(CFrame.new(w.pos) * CFrame.Angles(0, w.yaw, 0))
			end
		end
	end
end)

-- cash per second on each tag: base income x the owner's multipliers
task.spawn(function()
	while true do
		for m, w in walkers do
			local owner = Players:GetPlayerByUserId(w.plot:GetAttribute("Owner") or 0)
			local mult = owner and owner:GetAttribute("CashMulti") or 1
			w.tag.Income.Text = "$" .. G.short(G.AnimalIncome(w.name) * G.mutIncome(w.mut) * mult) .. "/s"
		end
		task.wait(1)
	end
end)

plots.DescendantAdded:Connect(function(d)
	if d:IsA("Model") and d.Parent and d.Parent.Name == "Animals" then task.spawn(setupAnimal, d) end
end)
for _, d in plots:GetDescendants() do
	if d:IsA("Model") and d.Parent and d.Parent.Name == "Animals" then task.spawn(setupAnimal, d) end
end
