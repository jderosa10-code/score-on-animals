-- KickerAnimKit: builds the penalty kicker's KeyframeSequences from code (pigeon-claude, 2026-11-11).
-- Lives in ServerStorage.KickerAnimKit. Run from the command bar:
--   require(game.ServerStorage.KickerAnimKit).install()      -> writes the sequences into RBX_ANIMSAVES.KickerRigR15
--   require(game.ServerStorage.KickerAnimKit).strip("PenaltyStrike3", 10) -> a row of posed dummies in Workspace.KickerAnimPreview
-- Every animation is a function pose(t) that is sampled 30 times a second. Feet are placed by IK, so a
-- planted foot stays planted while the body travels. The runner's contract (PenaltyDemoRunner.playFootwork
-- and the strikes table) is kept: keyframe attributes Travel + Footstep, sequence attributes TravelByHeight,
-- ContactTime, ContactOffsetRatio, FlickTime, FlickOffsetRatio, and a "Contact" marker.
--
-- Angles are the Motor6D Transform angles in degrees. The character faces -Z, +X is its right.
--   limbs (they hang down): rx + swings forward, rz + swings out to the character's right
--   torso / head (they stand up): rx - leans forward, ry + turns left, rz + tips to the left
local Kit = {}
local SS = game:GetService("ServerStorage")
local RIG = SS:WaitForChild("KickerRig")
local SAVES = SS:WaitForChild("RBX_ANIMSAVES"):WaitForChild("KickerRigR15")
local FPS = 30

---------------------------------------------------------------- rig data
local J = {}          -- J[part1] = {parent, C0, C1}
for _, m in RIG:GetDescendants() do
	if m:IsA("Motor6D") then J[m.Part1.Name] = {parent = m.Part0.Name, C0 = m.C0, C1 = m.C1} end
end
local ORDER = {"LowerTorso", "UpperTorso", "Head", "LeftUpperArm", "LeftLowerArm", "LeftHand", "RightUpperArm", "RightLowerArm", "RightHand",
	"LeftUpperLeg", "LeftLowerLeg", "LeftFoot", "RightUpperLeg", "RightLowerLeg", "RightFoot"}
local L1 = math.abs(J.RightUpperLeg.C1.Y) + math.abs(J.RightLowerLeg.C0.Y)       -- hip to knee
local L2 = math.abs(J.RightLowerLeg.C1.Y) + math.abs(J.RightFoot.C0.Y)           -- knee to ankle
local FOOT_H = math.abs(J.RightFoot.C1.Y) + RIG.RightFoot.Size.Y / 2             -- ankle to sole
local FOOT_HALF = RIG.RightFoot.Size.Z / 2 - 0.05
local HRP_OFF = RIG.Humanoid.HipHeight + RIG.HumanoidRootPart.Size.Y / 2         -- root height above the floor
Kit.HRP_OFF = HRP_OFF
local FLOOR = -HRP_OFF

---------------------------------------------------------------- small maths
local rad = math.rad
local function A(rx, ry, rz) return CFrame.Angles(rad(rx or 0), rad(ry or 0), rad(rz or 0)) end
local EASE = {
	lin = function(a) return a end,
	io = function(a) return a * a * (3 - 2 * a) end,
	["in"] = function(a) return a * a end,
	out = function(a) return 1 - (1 - a) * (1 - a) end,
	in3 = function(a) return a * a * a end,
	out3 = function(a) return 1 - (1 - a) ^ 3 end,
	back = function(a) local c = 1.9; a -= 1; return 1 + (c + 1) * a * a * a + c * a * a end,     -- overshoots, then settles
	snap = function(a) return 1 - (1 - a) ^ 5 end,
}
-- ch{{t, value, ease}, ...}: a keyed channel. ease = how it arrives at that key.
local function ch(keys)
	return function(t)
		if t <= keys[1][1] then return keys[1][2] end
		for i = 2, #keys do
			local k = keys[i]
			if t <= k[1] then
				local p = keys[i - 1]
				local a = (t - p[1]) / math.max(1e-6, k[1] - p[1])
				return p[2] + (k[2] - p[2]) * EASE[k[3] or "io"](a)
			end
		end
		return keys[#keys][2]
	end
end
Kit.ch = ch

---------------------------------------------------------------- pose -> Motor transforms
-- A pose is:
--   root = {x, y, z, rx, ry, rz}        pelvis offset from standing (x right, y up, z BACK; so forward is -z) + turn
--   chest = {rx, ry, rz}, head = {rx, ry, rz}
--   armL / armR = {rx, ry, rz, elbow, wrist}
--   legL / legR = {ik = true, x, y, f, pitch, yaw, knee}   foot centre: x right of the body line, y above the floor,
--                                                    f forward of the root (HRP), pitch + = toes up, knee = knee turn out (deg)
--              or {rx, ry, rz, knee, ankle}                 plain angles (knee is a positive bend)
local function solveLeg(side, spec, rootCF)
	local hipName, kneeName, footName = side .. "UpperLeg", side .. "LowerLeg", side .. "Foot"
	if spec.T then return spec.T[1], spec.T[2], spec.T[3] end
	if not spec.ik then
		return A(spec.rx, spec.ry, spec.rz), A(-(spec.knee or 0), 0, 0), A(spec.ankle or 0, 0, 0)
	end
	local pitch, yaw = spec.pitch or 0, spec.yaw or 0
	local F = A(0, yaw, 0) * A(pitch, 0, 0)                                -- the foot's orientation in root space
	local k = (pitch < 0) and 1 or -1                                      -- toes down pivots on the toe, toes up on the heel
	local centre = Vector3.new(spec.x, FLOOR + spec.y, -spec.f)
	local fwd = A(0, yaw, 0):VectorToWorldSpace(Vector3.new(0, 0, -1))
	local ankle = centre + fwd * (k * FOOT_HALF) + F:VectorToWorldSpace(Vector3.new(0, FOOT_H, k * FOOT_HALF))
	-- hip joint frame in root space
	local lt = CFrame.new(0, 0, 0) * J.LowerTorso.C0 * rootCF * J.LowerTorso.C1:Inverse()
	local hipFrame = lt * J[hipName].C0
	local a = hipFrame:PointToObjectSpace(ankle)
	local d = math.clamp(a.Magnitude, math.abs(L1 - L2) + 0.02, L1 + L2 - 0.004)
	local dir = a.Unit
	local cosK = math.clamp((L1 * L1 + L2 * L2 - d * d) / (2 * L1 * L2), -1, 1)
	local bend = math.pi - math.acos(cosK)
	local alpha = math.acos(math.clamp((L1 * L1 + d * d - L2 * L2) / (2 * L1 * d), -1, 1))
	-- frame whose -Y runs down the hip->ankle line and whose knee points forward (turned by yaw and knee-out)
	local kneeFwd = (hipFrame:Inverse() * A(0, yaw * 0.6 + (spec.knee or 0) * (side == "Right" and -1 or 1), 0)):VectorToWorldSpace(Vector3.new(0, 0, -1))
	local Y = -dir
	local X = Y:Cross(-kneeFwd)
	if X.Magnitude < 1e-3 then X = Vector3.new(1, 0, 0) end
	X = X.Unit
	local Z = X:Cross(Y)
	local hipT = CFrame.fromMatrix(Vector3.zero, X, Y, Z) * CFrame.Angles(alpha, 0, 0)
	local kneeT = CFrame.Angles(-bend, 0, 0)
	local shinRot = (hipFrame * hipT * kneeT).Rotation
	local ankleT = shinRot:Inverse() * F
	return hipT, kneeT, ankleT
end

Kit.solveLeg = solveLeg
function Kit.rootOf(p)
	local r = p.root or {}
	return CFrame.new(r[1] or 0, r[2] or 0, r[3] or 0) * A(r[4], r[5], r[6])
end
-- two legs of different kinds (IK / angles) are blended as joint rotations
local function mixLegs(side, x, rootX, y, rootY, u)
	local h0, k0, a0 = solveLeg(side, x, rootX)
	local h1, k1, a1 = solveLeg(side, y, rootY)
	return {T = {h0:Lerp(h1, u), k0:Lerp(k1, u), a0:Lerp(a1, u)}}
end
local function transforms(p)
	local rootCF = Kit.rootOf(p)
	local T = {LowerTorso = rootCF}
	local c, h = p.chest or {}, p.head or {}
	T.UpperTorso = A(c[1], c[2], c[3])
	T.Head = A(h[1], h[2], h[3])
	for _, side in {"Left", "Right"} do
		local arm = p["arm" .. side:sub(1, 1)] or {}
		T[side .. "UpperArm"] = A(arm[1], arm[2], arm[3])
		T[side .. "LowerArm"] = A(arm[4], 0, 0)
		T[side .. "Hand"] = A(arm[5], 0, 0)
		local hipT, kneeT, ankleT = solveLeg(side, p["leg" .. side:sub(1, 1)] or {}, rootCF)
		T[side .. "UpperLeg"], T[side .. "LowerLeg"], T[side .. "Foot"] = hipT, kneeT, ankleT
	end
	return T
end

-- part CFrames in root (HRP) space
local function fk(T)
	local W = {HumanoidRootPart = CFrame.identity}
	for _, name in ORDER do
		local j = J[name]
		W[name] = W[j.parent] * j.C0 * T[name] * j.C1:Inverse()
	end
	return W
end

---------------------------------------------------------------- gait helper
-- plants = {{down, up, f, x}, ...} in time order: the foot is on the ground at path distance f from `down` to `up`.
-- opts: lift (swing height), strike (landing pitch), push (lift-off pitch), tuck
-- returns the foot's {f (path), x, y, pitch} at time t
local function footAt(plants, t, o)
	o = o or {}
	local lift, strike, push = o.lift or 0.5, o.strike or 18, o.push or -38
	local first, last = plants[1], plants[#plants]
	if t <= first[1] then return {f = first[3], x = first[4], y = 0, pitch = 0} end
	for i, pl in ipairs(plants) do
		if t >= pl[1] and t <= pl[2] then
			local a = (t - pl[1]) / math.max(1e-6, pl[2] - pl[1])
			local pitch = 0
			local inT, outT = math.min(0.07, (pl[2] - pl[1]) * 0.3), math.min(0.11, (pl[2] - pl[1]) * 0.4)
			if i > 1 and t - pl[1] < inT then pitch = strike * (1 - (t - pl[1]) / inT) end
			if i < #plants and pl[2] - t < outT then local u = 1 - (pl[2] - t) / outT; pitch = push * u * u end
			return {f = pl[3], x = pl[4], y = 0, pitch = pitch}
		end
		local nx = plants[i + 1]
		if nx and t > pl[2] and t < nx[1] then
			local u = (t - pl[2]) / (nx[1] - pl[2])
			local e = u * u * (3 - 2 * u)
			return {f = pl[3] + (nx[3] - pl[3]) * e, x = pl[4] + (nx[4] - pl[4]) * e,
				y = lift * math.sin(math.pi * u) ^ 0.9, pitch = push + (strike - push) * (u ^ 0.8)}
		end
	end
	return {f = last[3], x = last[4], y = 0, pitch = 0}
end
Kit.footAt = footAt

---------------------------------------------------------------- the animations
local ANIMS = {}
Kit.ANIMS = ANIMS
local STANCE_F = 0            -- feet under the root when standing

-- the ready stance both footwork clips end / start in: knees bent, weight forward, arms loose
local function setPose(t)
	local breathe = math.sin(t * math.pi * 2 / 1.6)
	local bounce = math.abs(math.sin(t * math.pi * 2 / 0.8))
	return {
		root = {0, -0.26 + 0.05 * bounce, 0.05, -4, -14, 0},
		chest = {-13 - 1.5 * breathe, 6, 0}, head = {8, 8, 0},
		armL = {22 + 3 * breathe, 0, -16, 38, 0}, armR = {-12 - 3 * breathe, 0, 18, 30, 0},
		legL = {ik = true, x = -0.62, y = 0, f = 0.55, pitch = 0, yaw = 6, knee = 4},
		legR = {ik = true, x = 0.66, y = 0, f = -0.6, pitch = -16 - 6 * bounce, yaw = -12, knee = 8},
	}
end

ANIMS.PenaltySet3 = {dur = 1.6, loop = true, pose = setPose}

-- WALK BACK: eyes on the ball, three quick backward steps that get shorter, then a little hop into the stance.
do
	local D = 7.45                                    -- studs travelled (same as the old retreat, so the spot is unchanged)
	local dur = 1.5
	local travel = ch{{0, 0}, {0.16, 0.03, "in"}, {1.05, 0.9, "lin"}, {1.28, 1, "out"}, {dur, 1}}
	-- path distance is measured FORWARD, the body goes backward: root is at -D * travel
	local function rootF(t) return -D * travel(t) end
	local R = {  -- right foot plants {down, up, f, x}
		{0, 0.10, 0, 0.5}, {0.34, 0.58, -2.2, 0.55}, {0.84, 1.06, -5.85, 0.6}, {1.28, 9, -D - 0.6, 0.66}}
	local L = {
		{0, 0.30, 0, -0.5}, {0.60, 0.82, -4.1, -0.55}, {1.08, 9, -D + 0.55, -0.62}}
	local bob = ch{{0, 0}, {0.10, -0.3, "out"}, {0.22, -0.18}, {0.34, -0.38}, {0.47, -0.2}, {0.60, -0.38}, {0.72, -0.2}, {0.84, -0.38},
		{0.96, -0.2}, {1.08, -0.38}, {1.18, -0.2}, {1.30, -0.46}, {1.42, -0.18, "out"}, {dur, -0.26}}
	local lean = ch{{0, 0}, {0.2, 9, "out"}, {1.0, 7}, {1.2, -3}, {1.32, -9, "out"}, {dur, -4}}
	local twist = ch{{0, 0}, {0.34, -12}, {0.60, 12}, {0.84, -12}, {1.08, 10}, {1.3, -16}, {dur, -14}}
	local armSwing = ch{{0, 0}, {0.34, -30}, {0.60, 30}, {0.84, -30}, {1.08, 28}, {1.3, -14}, {dur, 0}}
	local settle = ch{{0, 0}, {1.2, 0}, {dur, 1}}
	ANIMS.PenaltyRetreat3 = {
		dur = dur, D = D, travel = travel,
		steps = {{0.34, "Step1"}, {0.60, "Step2"}, {0.84, "Step1"}, {1.08, "Step2"}, {1.28, "Step1"}},
		pose = function(t)
			local rf = rootF(t)
			local r, l = footAt(R, t, {lift = 0.55, strike = -22, push = 16}), footAt(L, t, {lift = 0.55, strike = -22, push = 16})
			local s = settle(t)
			local set = setPose(0)
			local sw = armSwing(t)
			local function mix(a, b) return a + (b - a) * s end
			return {
				root = {0, bob(t), mix(0, 0.05), -lean(t), mix(twist(t), -14), 0},
				chest = {mix(-6 - lean(t) * 0.6, -13), mix(-twist(t) * 0.8, 6), 0},
				head = {mix(10, 8), mix(0, 8), 0},
				armL = {mix(sw, 22), 0, mix(-10, -16), mix(34, 38), 0},
				armR = {mix(-sw, -12), 0, mix(10, 18), mix(34, 30), 0},
				legL = {ik = true, x = l.x, y = l.y, f = l.f - rf, pitch = l.pitch, yaw = mix(0, 6), knee = 4},
				legR = {ik = true, x = r.x, y = r.y, f = r.f - rf, pitch = mix(r.pitch, -16), yaw = mix(0, -12), knee = mix(4, 8)},
			}
		end,
	}
end

-- RUN-UP: drops into a sprinter's lean, three strides that get longer and faster, then a long last leap
-- onto the standing foot with the kicking leg already pulled back and the arms thrown wide.
local RUN_END                                     -- the pose the run-up ends in = the pose every strike starts from
do
	local D = 7.17
	local dur = 1.0
	local travel = ch{{0, 0}, {0.12, -0.012, "out"}, {0.3, 0.07, "in"}, {0.80, 0.80, "lin"}, {0.93, 0.97, "out"}, {dur, 1, "out"}}
	local function rootF(t) return D * travel(t) end
	-- starts in the set stance: left foot forward (+0.55), right foot back (-0.6)
	local R = {{0, 0.20, -0.6, 0.66}, {0.42, 0.54, 2.05, 0.5}, {0.73, 9, 5.3, 0.5}}
	local L = {{0, 0.34, 0.55, -0.62}, {0.58, 0.69, 3.75, -0.5}, {0.905, 9, D + 0.42, -0.5}}
	local bob = ch{{0, -0.26}, {0.13, -0.5, "out"}, {0.3, -0.2}, {0.42, -0.32}, {0.5, -0.12}, {0.57, -0.3}, {0.64, -0.1}, {0.72, -0.3},
		{0.82, 0.18, "out"}, {0.905, -0.2, "in"}, {dur, -0.36, "out"}}
	local lean = ch{{0, 4}, {0.13, 16, "out"}, {0.3, 24}, {0.72, 20}, {0.84, 4}, {dur, -16, "out"}}                  -- + = forward
	local twist = ch{{0, -14}, {0.13, -20}, {0.34, 14}, {0.49, -14}, {0.64, 14}, {0.78, -10}, {dur, -34, "out"}}
	local armSwing = ch{{0, 0}, {0.13, -30, "out"}, {0.34, 52}, {0.49, -52}, {0.64, 56}, {0.76, -40}, {dur, 0}}
	local wind = ch{{0, 0}, {0.74, 0}, {dur, 1, "out"}}
	RUN_END = {
		root = {-0.08, -0.36, 0.1, 16, -34, 6},
		chest = {6, -18, -6}, head = {-12, 34, 0},
		armL = {-20, 0, -96, 22, 0}, armR = {-62, 0, 44, 28, 0},
		legL = {ik = true, x = -0.5, y = 0, f = 0.42, pitch = 0, yaw = 14, knee = 6},
		legR = {rx = -58, ry = 0, rz = 10, knee = 112, ankle = -30},
	}
	ANIMS.PenaltyApproach3 = {
		dur = dur, D = D, travel = travel,
		steps = {{0.42, "Step1"}, {0.58, "Step2"}, {0.73, "Step1"}, {0.905, "Step2"}},
		pose = function(t)
			local rf = rootF(t)
			local r, l = footAt(R, t, {lift = 0.85, strike = 10, push = -46}), footAt(L, t, {lift = 0.8, strike = 14, push = -46})
			local w = wind(t)
			local sw = armSwing(t)
			local e = RUN_END
			local function mix(a, b) return a + (b - a) * w end
			-- the right leg: runs by IK until its last push-off, then it is thrown back by plain angles
			local LIFT = 0.80
			local legR = {ik = true, x = r.x, y = r.y, f = r.f - rootF(math.min(t, LIFT)), pitch = t < LIFT and r.pitch or -40, yaw = 0, knee = 4}
			local pose = {
				root = {mix(0, e.root[1]), bob(t), mix(0.05, e.root[3]), mix(-lean(t), e.root[4]), twist(t), mix(0, e.root[6])},
				chest = {mix(-8 - lean(t) * 0.5, e.chest[1]), mix(-twist(t) * 0.9, e.chest[2]), mix(0, e.chest[3])},
				head = {mix(12 + lean(t) * 0.5, e.head[1]), mix(0, e.head[2]), 0},
				armL = {mix(sw, e.armL[1]), 0, mix(-12, e.armL[3]), mix(70, e.armL[4]), 0},
				armR = {mix(-sw, e.armR[1]), 0, mix(12, e.armR[3]), mix(70, e.armR[4]), 0},
				legL = {ik = true, x = l.x, y = l.y, f = l.f - rf, pitch = l.pitch, yaw = mix(0, 14), knee = mix(4, 6)},
				legR = legR,
			}
			if t > LIFT then
				-- off the ground: the leg trails the body and folds up behind into the wind-up
				local root = Kit.rootOf(pose)
				pose.legR = mixLegs("Right", legR, root, e.legR, root, EASE.out((t - LIFT) / (dur - LIFT)))
			end
			return pose
		end,
	}
end

-- helper for the strikes: blend between whole poses given as keyed lists
local function lerpNum(a, b, u) return a + (b - a) * u end
local function blendPose(a, b, u)
	local out = {}
	for _, key in {"root", "chest", "head", "armL", "armR"} do
		out[key] = {}
		for i = 1, 6 do out[key][i] = lerpNum(a[key][i] or 0, b[key][i] or 0, u) end
	end
	for _, key in {"legL", "legR"} do
		local x, y = a[key], b[key]
		local side = key == "legL" and "Left" or "Right"
		if x.T or y.T then
			out[key] = mixLegs(side, x, Kit.rootOf(a), y, Kit.rootOf(b), u)
		elseif x.ik and y.ik then
			out[key] = {ik = true, x = lerpNum(x.x, y.x, u), y = lerpNum(x.y, y.y, u), f = lerpNum(x.f, y.f, u),
				pitch = lerpNum(x.pitch or 0, y.pitch or 0, u), yaw = lerpNum(x.yaw or 0, y.yaw or 0, u), knee = lerpNum(x.knee or 0, y.knee or 0, u)}
		elseif not x.ik and not y.ik then
			out[key] = {rx = lerpNum(x.rx or 0, y.rx or 0, u), ry = lerpNum(x.ry or 0, y.ry or 0, u), rz = lerpNum(x.rz or 0, y.rz or 0, u),
				knee = lerpNum(x.knee or 0, y.knee or 0, u), ankle = lerpNum(x.ankle or 0, y.ankle or 0, u)}
		else
			out[key] = mixLegs(side, x, Kit.rootOf(a), y, Kit.rootOf(b), u)
		end
	end
	return out
end
-- keys = {{t, pose, ease}, ...}
local function poseTrack(keys)
	return function(t)
		if t <= keys[1][1] then return keys[1][2] end
		for i = 2, #keys do
			if t <= keys[i][1] then
				local p, k = keys[i - 1], keys[i]
				return blendPose(p[2], k[2], EASE[k[3] or "io"]((t - p[1]) / (k[1] - p[1])))
			end
		end
		return keys[#keys][2]
	end
end

-- THE KICK: from the wound-up pose the hips fire first, the leg whips through late, and the
-- follow-through lifts the kicker off the ground and lands them on the kicking foot.
do
	local plantL = {ik = true, x = -0.5, y = 0, f = 0.42, pitch = 0, yaw = 14, knee = 6}
	local wind = RUN_END
	local load = {                                             -- one last coil: hips open, leg at full stretch behind
		root = {-0.1, -0.44, -0.12, 10, -42, 9}, chest = {10, -24, -4}, head = {-14, 40, 0},
		armL = {10, 0, -112, 14, 0}, armR = {-78, 0, 50, 20, 0},
		legL = plantL, legR = {rx = -66, ry = 0, rz = 12, knee = 124, ankle = -34}}
	local whip = {                                             -- hips through, knee leading, shin still folded
		root = {-0.12, -0.34, -0.5, 2, -6, 13}, chest = {-4, 14, 0}, head = {-2, 4, 0},
		armL = {-30, 0, -84, 24, 0}, armR = {-30, 0, 62, 26, 0},
		legL = plantL, legR = {rx = 22, ry = 0, rz = 4, knee = 100, ankle = -12}}
	local contact = {                                          -- laces through the ball, body over it
		root = {-0.14, -0.2, -0.7, -4, 16, 13}, chest = {-8, 26, 2}, head = {6, -14, 0},
		armL = {-58, 0, -62, 30, 0}, armR = {34, 0, 70, 30, 0},
		legL = plantL, legR = {rx = 58, ry = 0, rz = -2, knee = 10, ankle = -30}}
	local through = {                                          -- leg way up, lifted onto the toe
		root = {-0.14, 0.2, -1.05, -10, 34, 8}, chest = {-8, 30, 4}, head = {10, -30, 0},
		armL = {-80, 0, -50, 34, 0}, armR = {66, 0, 60, 40, 0},
		legL = {ik = true, x = -0.5, y = 0.1, f = 0.42, pitch = -34, yaw = 14, knee = 6},
		legR = {rx = 104, ry = 0, rz = -14, knee = 22, ankle = -30}}
	local hop = {                                              -- both feet off the ground
		root = {-0.1, 0.5, -1.3, -6, 30, 0}, chest = {-6, 22, 2}, head = {8, -22, 0},
		armL = {-60, 0, -58, 40, 0}, armR = {40, 0, 62, 44, 0},
		legL = {ik = true, x = -0.52, y = 0.7, f = 0.3, pitch = -30, yaw = 10, knee = 4},
		legR = {rx = 70, ry = 0, rz = -8, knee = 44, ankle = -10}}
	local land = {                                             -- down on the kicking foot, knee soaks it up
		root = {0.1, -0.5, -1.25, 4, 16, 2}, chest = {-18, 8, 0}, head = {14, -10, 0},
		armL = {30, 0, -50, 30, 0}, armR = {-34, 0, 44, 36, 0},
		legL = {ik = true, x = -0.56, y = 0.9, f = 0.0, pitch = -50, yaw = 6, knee = 2},
		legR = {ik = true, x = 0.42, y = 0, f = 1.72, pitch = 0, yaw = -6, knee = 6}}
	local settle = {
		root = {0, -0.14, -1.2, 0, 4, 0}, chest = {-6, 2, 0}, head = {4, -2, 0},
		armL = {6, 0, -12, 20, 0}, armR = {-6, 0, 12, 20, 0},
		legL = {ik = true, x = -0.52, y = 0, f = 0.72, pitch = 0, yaw = 4, knee = 2},
		legR = {ik = true, x = 0.46, y = 0, f = 1.72, pitch = 0, yaw = -4, knee = 4}}
	local CONTACT = 0.26
	ANIMS.PenaltyStrike3 = {
		dur = 1.05, contact = CONTACT,
		pose = poseTrack{{0, wind}, {0.10, load, "out"}, {0.20, whip, "in"}, {CONTACT, contact, "lin"}, {0.36, through, "out"},
			{0.50, hop, "out"}, {0.66, land, "in"}, {0.80, land, "out"}, {1.05, settle, "io"}},
	}
end

-- PERFECT: the toe pops the ball up, the kicker leaps into a full spin and smashes it out of the air
-- with a flying volley, then lands low on one knee.
do
	local plantL = {ik = true, x = -0.5, y = 0, f = 0.42, pitch = 0, yaw = 14, knee = 6}
	local wind = RUN_END
	local scoop = {                                            -- short jab: the toe slides under the ball
		root = {-0.1, -0.52, -0.3, 6, -10, -3}, chest = {-4, 6, -2}, head = {10, 0, 0},
		armL = {-30, 0, -70, 30, 0}, armR = {-20, 0, 60, 30, 0},
		legL = plantL, legR = {ik = true, x = 0.45, y = 0.04, f = 1.15, pitch = 20, yaw = 0, knee = 4}}
	local flick = {                                            -- and lifts it
		root = {-0.1, -0.4, -0.4, 8, -4, -2}, chest = {-4, 2, 0}, head = {2, 0, 0},
		armL = {-10, 0, -60, 40, 0}, armR = {-10, 0, 56, 40, 0},
		legL = plantL, legR = {ik = true, x = 0.45, y = 0.9, f = 1.45, pitch = 38, yaw = 0, knee = 4}}
	local crouch = {                                           -- both feet down, coiled to jump, arms loaded to the right
		root = {0.05, -0.95, -0.25, -6, -40, 0}, chest = {-8, -30, 0}, head = {-4, 40, 0},
		armL = {40, 0, -30, 60, 0}, armR = {-50, 0, 40, 50, 0},
		legL = {ik = true, x = -0.55, y = 0, f = 0.42, pitch = 0, yaw = 14, knee = 10},
		legR = {ik = true, x = 0.6, y = 0, f = 0.5, pitch = 0, yaw = -20, knee = 12}}
	-- the spin: the whole pelvis turns left through 360 degrees while it rises. Legs are plain angles in the air.
	local function air(y, f, yaw, tilt, legRrx, legRknee, legLrx, legLknee, chestTwist, armsOut)
		return {
			root = {-0.05, y, f, tilt, yaw, 0}, chest = {-6, chestTwist, 0}, head = {0, chestTwist * 0.6, 0},
			armL = {-10, 0, -armsOut, 30, 0}, armR = {-10, 0, armsOut, 30, 0},
			legL = {rx = legLrx, ry = 0, rz = -8, knee = legLknee, ankle = -30},
			legR = {rx = legRrx, ry = 0, rz = 8, knee = legRknee, ankle = -30}}
	end
	local up1 = air(0.5, -0.7, 60, -4, 20, 70, 10, 60, 50, 40)          -- tucked, already turning
	local up2 = air(1.5, -0.9, 180, -2, 40, 100, 30, 100, 40, 24)       -- back to the goal, tight tuck (spins fast)
	local up3 = air(2.1, -1.1, 290, 6, -40, 120, 50, 80, 30, 70)        -- coming round: kicking leg cocked behind
	local cock = air(2.25, -1.2, 338, 12, -64, 128, 60, 70, 20, 96)     -- the held frame: fully cocked, arms wide
	local smash = {                                             -- the volley: leg straight out through the ball, body laid back
		root = {-0.05, 2.15, -1.45, 26, 384, -6}, chest = {4, 22, 4}, head = {12, -20, 0},
		armL = {-70, 0, -70, 20, 0}, armR = {50, 0, 80, 20, 0},
		legL = {rx = -30, ry = 0, rz = -10, knee = 96, ankle = -30},
		legR = {rx = 72, ry = 0, rz = -4, knee = 4, ankle = -40}}
	local after = {
		root = {-0.05, 1.7, -1.75, 14, 400, -4}, chest = {-4, 26, 2}, head = {8, -26, 0},
		armL = {-50, 0, -64, 30, 0}, armR = {60, 0, 70, 30, 0},
		legL = {rx = -10, ry = 0, rz = -10, knee = 80, ankle = -30},
		legR = {rx = 108, ry = 0, rz = -12, knee = 30, ankle = -30}}
	local landLow = {                                           -- superhero landing: deep, one hand down
		root = {0, -1.5, -2.1, -8, 372, 0}, chest = {-34, 8, 0}, head = {26, -4, 0},
		armL = {56, 0, -10, 10, 0}, armR = {-40, 0, 70, 30, 0},
		legL = {ik = true, x = -0.6, y = 0, f = 2.75, pitch = 0, yaw = 12, knee = 14},
		legR = {ik = true, x = 0.62, y = 0, f = 1.25, pitch = -42, yaw = -10, knee = 6}}
	local rise = {
		root = {0, -0.2, -2.05, 0, 364, 0}, chest = {-6, 2, 0}, head = {4, 0, 0},
		armL = {8, 0, -14, 22, 0}, armR = {-8, 0, 14, 22, 0},
		legL = {ik = true, x = -0.52, y = 0, f = 2.6, pitch = 0, yaw = 4, knee = 3},
		legR = {ik = true, x = 0.5, y = 0, f = 1.6, pitch = 0, yaw = -4, knee = 3}}
	local FLICK, CONTACT = 0.13, 0.80
	ANIMS.PenaltyPerfect3 = {
		dur = 1.75, contact = CONTACT, flick = FLICK, charge = 0.71,
		marks = {{0.71, "Charge"}},
		pose = poseTrack{{0, wind}, {0.08, scoop, "out"}, {FLICK, scoop, "lin"}, {0.2, flick, "out"}, {0.31, crouch, "io"},
			{0.40, up1, "in"}, {0.52, up2, "lin"}, {0.64, up3, "lin"}, {0.72, cock, "out"}, {CONTACT, smash, "in3"}, {0.90, after, "out"},
			{1.12, landLow, "in"}, {1.36, landLow, "out"}, {1.75, rise, "io"}},
	}
end

---------------------------------------------------------------- sampling
local function sampleTimes(def)
	local times, seen = {}, {}
	local function add(t) t = math.round(t * 1000) / 1000; if not seen[t] then seen[t] = true; table.insert(times, t) end end
	local n = math.ceil(def.dur * FPS)
	for i = 0, n do add(math.min(def.dur, i / FPS)) end
	add(def.dur)
	if def.contact then add(def.contact) end
	if def.flick then add(def.flick) end
	if def.charge then add(def.charge) end
	for _, s in def.steps or {} do add(s[1]) end
	for _, s in def.marks or {} do add(s[1]) end
	table.sort(times)
	return times
end

-- the striking point of the boot (front of the right foot), in root space
local function toeAt(def, t)
	local W = fk(transforms(def.pose(t)))
	return (W.RightFoot * CFrame.new(0, 0.04, -0.36)).Position
end
Kit.toeAt = function(name, t) return toeAt(ANIMS[name], t) end

function Kit.sequence(name)
	local def = ANIMS[name]
	local seq = Instance.new("KeyframeSequence")
	seq.Name = name
	seq.Loop = def.loop or false
	seq.Priority = Enum.AnimationPriority.Action2
	seq.AuthoredHipHeight = RIG.Humanoid.HipHeight       -- so the pelvis moves scale to each avatar's leg length
	for _, t in sampleTimes(def) do
		local kf = Instance.new("Keyframe")
		kf.Time = t
		local T = transforms(def.pose(t))
		local made = {}
		local rootPose = Instance.new("Pose"); rootPose.Name = "HumanoidRootPart"; rootPose.Weight = 1; rootPose.Parent = kf
		made.HumanoidRootPart = rootPose
		for _, part in ORDER do
			local p = Instance.new("Pose")
			p.Name = part; p.Weight = 1; p.CFrame = T[part]
			p.EasingStyle = Enum.PoseEasingStyle.Linear; p.EasingDirection = Enum.PoseEasingDirection.In
			p.Parent = made[J[part].parent]
			made[part] = p
		end
		if def.travel then kf:SetAttribute("Travel", math.clamp(def.travel(t), -0.05, 1)) end
		for _, s in def.steps or {} do if math.abs(s[1] - t) < 0.0006 then kf:SetAttribute("Footstep", s[2]) end end
		local function mark(n) local m = Instance.new("KeyframeMarker"); m.Name = n; m.Parent = kf; kf.Name = n end
		if def.contact and math.abs(def.contact - t) < 0.0006 then mark("Contact") end
		if def.flick and math.abs(def.flick - t) < 0.0006 then mark("Flick") end
		for _, s in def.marks or {} do if math.abs(s[1] - t) < 0.0006 then mark(s[2]) end end
		kf.Parent = seq
	end
	seq:SetAttribute("KickerAnimKit", 3)
	seq:SetAttribute("Duration", def.dur)
	if def.D then
		seq:SetAttribute("TravelDistance", def.D)
		seq:SetAttribute("TravelByHeight", def.D / HRP_OFF)
	end
	local size = Vector3.new(RIG.HumanoidRootPart.Size.X, HRP_OFF, HRP_OFF)
	if def.contact then
		seq:SetAttribute("ContactTime", def.contact)
		seq:SetAttribute("ContactOffsetRatio", toeAt(def, def.contact) / size)
	end
	if def.flick then
		seq:SetAttribute("FlickTime", def.flick)
		seq:SetAttribute("FlickOffsetRatio", toeAt(def, def.flick) / size)
	end
	if def.charge then
		seq:SetAttribute("ChargeTime", def.charge)
	end
	return seq
end

-- writes every animation into ServerStorage.RBX_ANIMSAVES.KickerRigR15 (replacing its own older output only)
function Kit.install()
	local done = {}
	for name in ANIMS do
		local old = SAVES:FindFirstChild(name)
		if old then old:Destroy() end
		Kit.sequence(name).Parent = SAVES
		table.insert(done, name)
	end
	table.sort(done)
	return table.concat(done, ", ")
end

---------------------------------------------------------------- preview: a film strip of posed dummies
function Kit.strip(name, count, origin, spacing, t0, t1)
	local def = ANIMS[name]
	local folder = workspace:FindFirstChild("KickerAnimPreview") or Instance.new("Folder")
	folder.Name = "KickerAnimPreview"; folder.Parent = workspace
	local row = folder:FindFirstChild(name)
	if row then row:Destroy() end
	row = Instance.new("Model"); row.Name = name; row.Parent = folder
	origin = origin or CFrame.new(0, 60, 0)
	spacing = spacing or 4.2
	t0, t1 = t0 or 0, t1 or def.dur
	local floor = Instance.new("Part")
	floor.Anchored = true; floor.Size = Vector3.new(spacing * count + 6, 0.2, 16); floor.Color = Color3.fromRGB(70, 150, 80)
	floor.Size = Vector3.new(16, 0.2, spacing * count + 6)
	floor.CFrame = origin * CFrame.new(0, FLOOR - 0.1, -spacing * (count - 1) / 2); floor.Parent = row
	-- the dummies stand in a line along the way they face, so a camera on their right sees a film strip
	for i = 1, count do
		local t = t0 + (t1 - t0) * (i - 1) / math.max(1, count - 1)
		local W = fk(transforms(def.pose(t)))
		local base = origin * CFrame.new(0, 0, -spacing * (i - 1))
		local dummy = Instance.new("Model"); dummy.Name = string.format("t%.2f", t)
		for _, part in RIG:GetChildren() do
			if part:IsA("BasePart") and W[part.Name] then
				local c = part:Clone()
				for _, d in c:GetDescendants() do if d:IsA("JointInstance") or d:IsA("Motor6D") or d:IsA("Attachment") then d:Destroy() end end
				c.Anchored = true; c.CanCollide = false
				-- colour-coded so a pose reads at a glance: right side warm, left side cool
				local n = part.Name
				c.Material = Enum.Material.SmoothPlastic
				c.Color = n == "Head" and Color3.fromRGB(255, 220, 90)
					or n:find("Torso") and Color3.fromRGB(235, 235, 240)
					or n:find("Right") and (n:find("Arm") or n:find("Hand")) and Color3.fromRGB(255, 150, 60)
					or n:find("Right") and Color3.fromRGB(230, 60, 60)
					or (n:find("Arm") or n:find("Hand")) and Color3.fromRGB(90, 200, 255)
					or Color3.fromRGB(60, 90, 230)
				if c:IsA("MeshPart") then c.TextureID = "" end
				c.Transparency = n == "HumanoidRootPart" and 1 or 0
				c.CFrame = base * W[part.Name]
				c.Parent = dummy
			end
		end
		dummy.Parent = row
	end
	return row
end

return Kit
