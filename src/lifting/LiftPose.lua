-- LiftPose: the weight-lifting rep as a clean and jerk (pigeon-claude, 2026-11-11). Lives in ReplicatedStorage.
-- Same job and calls as ReplicatedStorage.DeadliftPose (kept as the fallback): the pose is set on
-- Motor6D.Transform, nothing to upload, R6 and R15, any body shape.
--   one rep:  grip low -> rip the bar up to the hips -> flip it to the shoulders -> dip -> jump and punch it
--             overhead (locked out at P.TOP, where WorkoutClient counts the rep) -> hold it, shaking ->
--             drop it; it lands on the rack with a bounce while the lifter follows it down
-- P.joints(char) -> j
-- P.apply(j, f, rest, t, rep) -> bar centre height, bar shift (Vector3, along world Z)
--     t = seconds into this rep, rep = rep length; rest = bar centre when it sits on the rack (world)
-- P.clear(j)
-- Dev: workspace:SetAttribute("LiftDebugT", seconds) freezes every lifter at that moment of the rep.
local P = {}
P.TILT, P.KNEE = math.rad(45), math.rad(60)   -- at full depth (scaled down to just reach the bar)
P.R6_TILT = math.rad(75)
P.STANCE = math.rad(11)                       -- legs spread outward
P.TOP = 1.05                                  -- lockout time

local function find(char, partName, joint)
	local part = char:FindFirstChild(partName)
	return part and part:FindFirstChild(joint)
end
local function yz(v) return math.sqrt(v.Y * v.Y + v.Z * v.Z) end

function P.joints(char)
	local hum = char:FindFirstChildOfClass("Humanoid")
	local hrp = char:FindFirstChild("HumanoidRootPart")
	if not (hum and hrp) then return end
	local j = {hrp = hrp, r15 = hum.RigType == Enum.HumanoidRigType.R15}
	if j.r15 then
		j.root = find(char, "LowerTorso", "Root")
		j.waist = find(char, "UpperTorso", "Waist")
		j.neck = find(char, "Head", "Neck")
		j.legs = {}
		for _, s in {"Right", "Left"} do
			table.insert(j.legs, {side = s == "Right" and 1 or -1, hip = find(char, s .. "UpperLeg", s .. "Hip"),
				knee = find(char, s .. "LowerLeg", s .. "Knee"), ankle = find(char, s .. "Foot", s .. "Ankle")})
		end
		j.arms = {}
		for _, s in {"Right", "Left"} do
			local sh, el, wr = find(char, s .. "UpperArm", s .. "Shoulder"), find(char, s .. "LowerArm", s .. "Elbow"), find(char, s .. "Hand", s .. "Wrist")
			if sh then
				local upper = el and yz(el.C0.Position - sh.C1.Position) or 1
				local fore = (el and wr and yz(wr.C0.Position - el.C1.Position) or 0.9) + (wr and math.abs(wr.C1.Position.Y) or 0.2)
				table.insert(j.arms, {sh = sh, el = el, upper = upper, fore = el and fore or 0})
			end
		end
		local L = j.legs[1]
		if not (j.root and L.hip and L.knee and j.arms[1]) then return end
		j.thigh = (L.hip.C1.Position - L.knee.C0.Position).Magnitude
		j.shin = L.ankle and (L.knee.C1.Position - L.ankle.C0.Position).Magnitude or j.thigh
		local R0 = j.root.C0 * j.root.C1:Inverse()
		local mid = Vector3.zero
		for _, l in j.legs do if l.hip then mid += (R0 * l.hip.C0).Position / #j.legs end end
		j.pivot = mid
		local chest = char:FindFirstChild("UpperTorso")
		j.chest = chest and chest.Size.Z / 2 or 0.5
	else
		local torso = char:FindFirstChild("Torso")
		if not torso then return end
		j.root = hrp:FindFirstChild("RootJoint")
		j.neck = torso:FindFirstChild("Neck")
		j.legs = {{side = 1, hip = torso:FindFirstChild("Right Hip")}, {side = -1, hip = torso:FindFirstChild("Left Hip")}}
		j.arms = {}
		for _, n in {"Right", "Left"} do
			local sh = torso:FindFirstChild(n .. " Shoulder")
			local arm = char:FindFirstChild(n .. " Arm")
			if sh and arm then table.insert(j.arms, {sh = sh, upper = (arm.Size.Y / 2 + sh.C1.Position.Y) - 0.15, fore = 0}) end
		end
		j.pivot = Vector3.new(0, -torso.Size.Y / 2, 0)
		j.thigh, j.shin = 1, 1
		j.chest = torso.Size.Z / 2
		if not (j.root and j.arms[1]) then return end
	end
	j.arm = j.arms[1].upper + j.arms[1].fore          -- straight arm, shoulder to grip
	return j
end

local function conj(joint, rotation)
	local r = joint.C0.Rotation
	return r:Inverse() * rotation * r
end

-- body pose: s = how far into the solved squat (0 standing .. 1 hands on the racked bar), dip = extra
-- knee bend, hop = lift off the floor, arch = lean back
local function body(j, s, dip, hop, arch)
	local a = (j.r15 and P.TILT or P.R6_TILT) * s - (arch or 0)
	local th = j.r15 and (P.KNEE * s + (dip or 0)) or 0
	local drop = j.r15 and ((j.thigh + j.shin) * (1 - math.cos(th) * math.cos(P.STANCE))) or 0
	local pv = j.pivot
	local M = CFrame.new(0, (hop or 0) - drop, 0) * CFrame.new(pv) * CFrame.Angles(-a, 0, 0) * CFrame.new(-pv)
	local R0 = j.root.C0 * j.root.C1:Inverse()
	local base = j.hrp.CFrame * M * R0
	if j.r15 and j.waist then base = base * j.waist.C0 * j.waist.C1:Inverse() end
	return M, R0, base, th, a
end

-- where straight arms reach a bar at the rack's Z: grip height (the lower of the two shoulders)
local function gripHeight(j, base, barZ)
	local y = math.huge
	for _, arm in j.arms do
		local sw = (base * arm.sh.C0).Position
		local dz = math.min(math.abs(barZ - sw.Z), j.arm * 0.95)
		y = math.min(y, sw.Y - math.sqrt(j.arm * j.arm - dz * dz))
	end
	return y
end

-- how deep to squat so the hands just reach the bar on the rack (cached per lifter + bar spot)
local function depthFor(j, rest)
	local key = math.floor(rest.Y * 100) .. ":" .. math.floor(rest.Z * 100)
	if j.depthKey == key then return j.depth end
	local lo, hi = 0, 1.3
	for _ = 1, 16 do
		local mid = (lo + hi) / 2
		local _, _, base = body(j, mid)
		if gripHeight(j, base, rest.Z) > rest.Y then lo = mid else hi = mid end
	end
	j.depthKey, j.depth = key, (lo + hi) / 2
	return j.depth
end

local function clamp01(x) return math.clamp(x, 0, 1) end
local function smooth(x) x = clamp01(x); return x * x * (3 - 2 * x) end
local function out3(x) x = clamp01(x); return 1 - (1 - x) ^ 3 end
local function ramp(t, a, b) return clamp01((t - a) / (b - a)) end

-- bends one arm so the hand goes to a point given in the chest's space (from the shoulder joint, y up, z back).
-- Returns where the hand really ends up (same space): the target if it is in reach.
local function reach(arm, y, z)
	local u, f = arm.upper, arm.fore
	local D = math.sqrt(y * y + z * z)
	local dir = math.atan2(-z, -y)                       -- 0 = straight down, + = forward / up
	local phi, bend = dir, 0
	if f > 0.05 then
		D = math.clamp(D, math.abs(u - f) + 0.02, u + f - 0.002)
		bend = math.pi - math.acos(math.clamp((u * u + f * f - D * D) / (2 * u * f), -1, 1))
		phi = dir - math.acos(math.clamp((u * u + D * D - f * f) / (2 * u * D), -1, 1))
	else
		D = u
	end
	arm.sh.Transform = conj(arm.sh, CFrame.Angles(phi, 0, 0))
	if arm.el then arm.el.Transform = conj(arm.el, CFrame.Angles(bend, 0, 0)) end
	return -D * math.cos(dir), -D * math.sin(dir)
end

function P.apply(j, f, rest, t, rep)
	rep = rep or 2
	t = workspace:GetAttribute("LiftDebugT") or t or f * P.TOP
	local TOP = P.TOP
	local tA, tB, tC, tD = 0.16, 0.46, 0.68, 0.82          -- sink, bar at the hips, bar on the shoulders, bottom of the dip
	local tH, tL = rep - 0.52, rep - 0.12                 -- let go, bar lands
	local depth = depthFor(j, rest)

	-- the body
	local s
	if t < tA then s = 1 + 0.07 * math.sin(math.pi * t / tA)
	elseif t < tB then s = 1 - out3(ramp(t, tA, tB))
	elseif t < tH then s = 0
	else s = smooth(ramp(t, tH, tL) ^ 0.85) end
	local dip = 0
	if t >= tB and t < tC then dip = 0.2 * smooth(ramp(t, tB, tC))
	elseif t >= tC and t < tD then dip = 0.2 + 0.16 * smooth(ramp(t, tC, tD))
	elseif t >= tD and t < tD + 0.12 then dip = 0.36 * (1 - out3(ramp(t, tD, tD + 0.12)))
	elseif t >= TOP and t < TOP + 0.3 then dip = 0.16 * math.sin(math.pi * ramp(t, TOP, TOP + 0.3)) end      -- soaks up the landing
	local hop = 0
	if t > tD + 0.08 and t < TOP then local x = ramp(t, tD + 0.08, TOP); hop = 0.32 * j.thigh * 4 * x * (1 - x) end
	local over = t < tH and out3(ramp(t, tD + 0.05, TOP - 0.02)) or 1 - smooth(ramp(t, tH, tH + 0.2))   -- arms overhead
	local hold = (t > TOP and t < tH) and 1 or 0
	local arch = 0.07 * over
	local M, R0, base, th, lean = body(j, depth * s, dip, hop, arch)

	local c0 = j.root.C0
	j.root.Transform = c0:Inverse() * M * c0
	for _, l in j.legs do
		if l.hip then
			local H = (R0 * l.hip.C0).Position
			local X = CFrame.new((M * CFrame.new(H)).Position) * CFrame.Angles(th, 0, 0) * CFrame.Angles(0, 0, l.side * P.STANCE) * CFrame.new(-H)
			l.hip.Transform = l.hip.C0:Inverse() * R0:Inverse() * M:Inverse() * X * R0 * l.hip.C0
		end
		if l.knee then l.knee.Transform = conj(l.knee, CFrame.Angles(-2 * th, 0, 0)) end
		if l.ankle then l.ankle.Transform = conj(l.ankle, CFrame.Angles(th, 0, -l.side * P.STANCE)) end
	end
	-- eyes forward while bent over, up at the bar overhead
	if j.neck then j.neck.Transform = conj(j.neck, CFrame.Angles(math.max(0, lean) * 0.7 + 0.32 * over, 0, 0)) end

	-- the hands. Three places, given from the shoulder in the chest's space (y up, z back):
	local Lr = j.arm
	local gy = math.max(gripHeight(j, base, rest.Z), rest.Y)                 -- hanging: straight arms to the bar at the rack's Z
	local rackZ = -math.max(0.4 * Lr, j.chest + 0.35)                       -- on the shoulders: just in front of the chest
	local toRack = smooth(ramp(t, tB - 0.05, tC))
	local shake = hold * math.sin(t * 55) * 0.012 * Lr
	local barY, barZ, n = 0, 0, 0
	local dropping = t >= tH
	local dropY, dropZ
	if dropping then
		-- the bar is let go: it comes forward off the head and falls to the rack, the hands chase it
		local _, _, base0 = body(j, 0, 0, 0, 0.07)
		local top = base0 * j.arms[1].sh.C0 * CFrame.new(0, 0.985 * Lr, 0.05 * Lr)
		local u = ramp(t, tH, tL)
		dropY = top.Position.Y + (rest.Y - top.Position.Y) * u * u
		dropZ = top.Position.Z + (rest.Z - top.Position.Z) * smooth(u * 1.7)
		if t > tL then
			local v = ramp(t, tL, rep)
			dropY = rest.Y + 0.16 * math.sin(math.pi * v) * (1 - v) ^ 1.5      -- one small bounce on the rack
			dropZ = rest.Z
		end
	end
	for _, arm in j.arms do
		local sw = base * arm.sh.C0
		local y, z
		if dropping then
			local d = base:VectorToObjectSpace(Vector3.new(sw.X, dropY, dropZ) - sw.Position)
			y, z = d.Y, d.Z
		else
			local hang = base:VectorToObjectSpace(Vector3.new(sw.X, gy, rest.Z) - sw.Position)
			-- hang -> rack swings out in front of the body, rack -> overhead goes straight up
			y = hang.Y + (0.06 * Lr - hang.Y) * toRack
			z = hang.Z + (rackZ - hang.Z) * toRack - 0.22 * Lr * math.sin(math.pi * toRack)
			y += (0.985 * Lr - y) * over + shake
			z += (0.05 * Lr - z) * over
		end
		local hy, hz = reach(arm, y, z)
		local hand = (sw * CFrame.new(0, hy, hz)).Position
		barY += hand.Y; barZ += hand.Z; n += 1
	end
	if dropping then return math.max(dropY, rest.Y), Vector3.new(0, 0, dropZ - rest.Z) end
	barY /= n; barZ /= n
	-- on the way up from the rack the bar stays on the rack's line until the hands leave it
	local free = smooth(ramp(t, tB - 0.05, tB + 0.06))
	return math.max(barY, rest.Y), Vector3.new(0, 0, (barZ - rest.Z) * free)
end

function P.clear(j)
	if not j then return end
	j.root.Transform = CFrame.identity
	for _, l in j.legs do for _, k in {"hip", "knee", "ankle"} do if l[k] then l[k].Transform = CFrame.identity end end end
	for _, arm in j.arms do
		arm.sh.Transform = CFrame.identity
		if arm.el then arm.el.Transform = CFrame.identity end
	end
	if j.neck then j.neck.Transform = CFrame.identity end
end

return P
