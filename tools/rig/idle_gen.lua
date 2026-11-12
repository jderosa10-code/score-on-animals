-- Hand-tuned procedural idles (+ tail follow-through for walks) for the clean-skin animals.
-- (2026-11-12, pigeon: the 4 flagged animals' idles look weird, the Simurgh's tail doesn't follow its body.)
-- Rotations are written in the animal's PART space (X = side, Y = up, -Z = front) about each bone's pivot,
-- then turned into the bone's own frame: r = B^-1 * R * B (B = bone rest rotation relative to the part).
-- Usage (edit context): local G = require(module); G.idle(model, recipeName) -> KeyframeSequence
--                        G.tailWalk(model, walkKS, tailBone, bodyBone) -> new KeyframeSequence
local G = {}
local rad = math.rad

local function restRot(mesh)
	local R = {}
	local function walk(parent, pw)
		for _, b in parent:GetChildren() do
			if b:IsA("Bone") then
				local w = pw * b.CFrame
				R[b.Name] = w.Rotation
				walk(b, w)
			end
		end
	end
	walk(mesh, CFrame.identity)
	return R
end

-- looping smooth curve through (t, v) points; the last point should repeat the first value at t = L
local function curve(pts)
	return function(t)
		for i = 1, #pts - 1 do
			local a, b = pts[i], pts[i + 1]
			if t >= a[1] and t <= b[1] then
				local u = (t - a[1]) / math.max(b[1] - a[1], 1e-6)
				u = u * u * (3 - 2 * u)
				return a[2] + (b[2] - a[2]) * u
			end
		end
		return pts[#pts][2]
	end
end
local function wave(amp, period, phase) return function(t) return amp * math.sin(2 * math.pi * t / period + (phase or 0)) end end
local function add(...) local fs = {...} return function(t) local s = 0 for _, f in fs do s += f(t) end return s end end
local function delay(f, d, L) return function(t) return f((t - d) % L) end end
local function scale(f, k) return function(t) return f(t) * k end end
local zero = function() return 0 end

-- part-space rotation from pitch (about X: + lifts the front), yaw (about Y), roll (about Z), degrees
local function prs(p, y, r) return CFrame.Angles(0, rad(y or 0), 0) * CFrame.Angles(rad(p or 0), 0, 0) * CFrame.Angles(0, 0, rad(r or 0)) end

local function buildKS(mesh, L, dt, rotAt)   -- rotAt(boneName, t) -> part-space rotation or nil
	local B = restRot(mesh)
	local ks = Instance.new("KeyframeSequence"); ks.Loop = true; ks.Priority = Enum.AnimationPriority.Core
	local n = math.floor(L / dt + 0.5)
	for i = 0, n do
		local t = i * dt
		local kf = Instance.new("Keyframe"); kf.Time = t; kf.Parent = ks
		local root = Instance.new("Pose"); root.Name = mesh.Name; root.Weight = 0; root.Parent = kf
		local function walk(parent, pp)
			for _, b in parent:GetChildren() do
				if b:IsA("Bone") then
					local p = Instance.new("Pose"); p.Name = b.Name; p.Weight = 1
					p.EasingStyle = Enum.PoseEasingStyle.Linear
					local R = rotAt(b.Name, i == n and 0 or t)        -- last key = first key: seamless loop
					if R then p.CFrame = B[b.Name]:Inverse() * R * B[b.Name] end
					p.Parent = pp
					walk(b, p)
				end
			end
		end
		walk(mesh, root)
	end
	return ks
end

-- ---------------------------------------------------------------- recipes
G.recipes = {}

-- birds on the shared joint rig: joint7 body, joint15 chest, joint8 head+neck, joint12/13 left wing,
-- joint16/17 right wing, joint10 tail (+ back half), legs joint2../joint19.. stay planted
G.recipes.bird = function(o)
	local L = o.L or 4
	local breath = wave(o.breath or 1.6, L / 2)                                   -- two slow breaths
	local lookY = curve({{0, 0}, {0.5, 0}, {0.95, 16}, {1.7, 16}, {2.25, -13}, {3.05, -13}, {3.5, 0}, {L, 0}})
	local lookP = curve({{0, 0}, {0.5, 0}, {0.95, -4}, {1.7, -2}, {2.25, 3}, {3.05, 3}, {3.5, 0}, {L, 0}})
	local tilt = curve({{0, 0}, {2.3, 0}, {2.55, 9}, {3.0, 9}, {3.35, 0}, {L, 0}})     -- curious head tilt
	local ruffle = curve({{0, 0}, {1.75, 0}, {1.9, 11}, {2.02, 4}, {2.12, 8}, {2.35, 0}, {L, 0}})   -- wing settle
	local wingB = scale(breath, 0.8)
	local tailFollow = delay(breath, 0.25, L)
	local tailSway = wave(o.tailSway or 3, L, 0.6)
	local tailFlick = delay(scale(ruffle, -0.45), 0.08, L)                         -- tail lifts with the ruffle
	return L, function(n, t)
		if n == "joint7" then return prs(breath(t)) end
		if n == "joint8" then return prs(lookP(t), lookY(t), tilt(t)) end
		if n == "joint12" then return prs(0, 0, -(ruffle(t) + wingB(t))) end
		if n == "joint16" then return prs(0, 0, ruffle(t) + wingB(t)) end
		if n == "joint13" then return prs(0, 0, -0.5 * delay(ruffle, 0.06, L)(t)) end
		if n == "joint17" then return prs(0, 0, 0.5 * delay(ruffle, 0.06, L)(t)) end
		if n == o.tail then return prs(tailFollow(t) + tailFlick(t), tailSway(t)) end
		return nil
	end
end

-- tortoise: joint10 neck, joint11 head, joint8 front body, legs planted
G.recipes.tortoise = function(o)
	local L = o.L or 4.8
	local breath = wave(0.9, L / 2)
	local neckY = curve({{0, 0}, {0.6, 0}, {1.2, 14}, {2.0, 14}, {2.6, -12}, {3.5, -12}, {4.1, 0}, {L, 0}})
	local neckP = curve({{0, 0}, {0.6, 0}, {1.2, 5}, {2.0, 5}, {2.6, 3}, {3.5, 3}, {4.1, -6}, {4.4, -2}, {L, 0}})
	local headP = curve({{0, 0}, {1.1, 0}, {1.3, -7}, {1.55, 0}, {1.75, -5}, {2.0, 0}, {L, 0}})  -- a little double nod
	return L, function(n, t)
		if n == "joint8" then return prs(breath(t)) end
		if n == "joint10" then return prs(neckP(t), neckY(t)) end
		if n == "joint11" then return prs(headP(t), 0.4 * neckY(t)) end
		return nil
	end
end

function G.idle(model, recipe, opts)
	local mesh = model.PrimaryPart or model:FindFirstChildWhichIsA("MeshPart", true)
	local L, rot = G.recipes[recipe](opts or {})
	return buildKS(mesh, L, 0.1, rot)
end

-- walk: keep every pose of the old walk, add the tail following the body (delayed) + a stride sway
function G.tailWalk(model, ks, tail, body, opts)
	opts = opts or {}
	local mesh = model.PrimaryPart or model:FindFirstChildWhichIsA("MeshPart", true)
	local B = restRot(mesh)
	local new = ks:Clone()
	local kfs = {}
	for _, kf in new:GetChildren() do if kf:IsA("Keyframe") then table.insert(kfs, kf) end end
	table.sort(kfs, function(a, b) return a.Time < b.Time end)
	local L = kfs[#kfs].Time
	-- body rotation track in part space
	local track = {}
	for _, kf in kfs do
		local p = kf:FindFirstChild(body, true)
		local r = p and p.CFrame.Rotation or CFrame.identity
		table.insert(track, {t = kf.Time, R = B[body] * r * B[body]:Inverse()})
	end
	local function bodyAt(t)
		t = t % L
		for i = 1, #track - 1 do
			local a, b = track[i], track[i + 1]
			if t >= a.t and t <= b.t then return a.R:Lerp(b.R, (t - a.t) / math.max(b.t - a.t, 1e-6)) end
		end
		return track[#track].R
	end
	local sway = wave(opts.sway or 4, L, 0.9)
	local lagD = opts.lag or 0.1
	for _, kf in kfs do
		local t = kf.Time >= L - 1e-4 and 0 or kf.Time
		local R = bodyAt(t - lagD) * prs(0, sway(t))
		local tp = kf:FindFirstChild(tail, true)
		if not tp then
			-- the tail's parent pose must exist (root bone): find the bone's parent name and its pose
			local bone = mesh:FindFirstChild(tail, true)
			local pp = kf:FindFirstChild(bone.Parent.Name, true)
			if not pp then return nil, "no pose for " .. bone.Parent.Name end
			tp = Instance.new("Pose"); tp.Name = tail; tp.Weight = 1; tp.Parent = pp
		end
		tp.Weight = 1
		tp.CFrame = B[tail]:Inverse() * R * B[tail]
	end
	return new
end

return G
