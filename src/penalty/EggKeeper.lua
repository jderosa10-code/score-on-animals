--[[
	EggKeeper
	Eggs keep goal. All moves are code (CFrame + Size), so nothing needs uploading.
	Each egg is a single MeshPart from ServerStorage.BaseEggs; its mesh faces local -X.

	local goal = {cf = CFrame (on the goal line, on the ground, LookVector pointing at the kicker),
	              width = inner width, height = inner height}
	local E = EggKeeper.new(eggTemplate, stats, goal, parent)
	E:enter()                 -- hops in from beside the post, facing where it's going
	E:idle()                  -- small bobs on the line, facing the kicker
	E:track(x)                -- hop over to local x (turns to face the way it goes, then back)
	E:dive(Vector2.new(x, y), willSave)   -- x/y are goal-local (x sideways, y height)
	E:bounce()  E:getUp()  E:celebrate()  E:tumble()
	E:hatch(animalTemplate, animalHeight)  -- crack, shell bits, animal pops out
	E:destroy()
	E.onLand = function(egg, strength) end   -- optional: called on every landing (dust puffs etc.)
	EggKeeper.timeScale       -- 1 = normal; set lower for slow motion (every move and run() uses it)

	stats: size (1 = normal), reach (0..1 of half the goal width), react (seconds),
	       diveSpeed (1 = normal), style ("hop" | "roll" | "feint" | "dig"), hop (bob height, studs)
]]
local RunService = game:GetService("RunService")

local EggKeeper = {}
EggKeeper.__index = EggKeeper

EggKeeper.timeScale = 1
EggKeeper.BASE_HEIGHT = 4.2
EggKeeper.Defaults = {size = 1, reach = 0.75, react = 0.18, diveSpeed = 1, style = "hop", hop = 0.5}
EggKeeper.Styles = {
	Chicken  = {style = "feint", reach = 0.8,  react = 0.05, diveSpeed = 1.2, hop = 0.7},
	Giraffe  = {style = "hop",   reach = 0.6,  react = 0.2,  diveSpeed = 0.9, hop = 0.8, size = 1.15},
	Turtle   = {style = "dig",   reach = 0.2,  react = 0.1,  diveSpeed = 0.6, hop = 0.25},
	Elephant = {style = "hop",   reach = 0.55, react = 0.28, diveSpeed = 0.75, hop = 0.3, size = 1.7},
	TRex     = {style = "hop",   reach = 0.75, react = 0.12, diveSpeed = 1.2, hop = 0.6},
	Fish     = {style = "roll",  reach = 0.85, react = 0.15, diveSpeed = 1.05, hop = 0.25},
}

local FACE = CFrame.Angles(0, -math.pi / 2, 0)

local function lerp(a, b, t) return a + (b - a) * t end
local function outQuad(t) return 1 - (1 - t) * (1 - t) end
local function outCubic(t) return 1 - (1 - t) ^ 3 end
local function inQuad(t) return t * t end
local function inOutSine(t) return -(math.cos(math.pi * t) - 1) / 2 end
local function outBack(t) local c = 1.5; t = t - 1; return 1 + (c + 1) * t * t * t + c * t * t end
local function smooth(t) return t * t * (3 - 2 * t) end
local function wrap(a) return (a + math.pi) % (2 * math.pi) - math.pi end

function EggKeeper.new(template, stats, goal, parent)
	local self = setmetatable({}, EggKeeper)
	self.stats = setmetatable(stats or {}, {__index = EggKeeper.Defaults})
	self.goal = goal
	local p = template:Clone()
	p.Anchored, p.CanCollide, p.CanQuery = true, false, false
	local H = EggKeeper.BASE_HEIGHT * self.stats.size
	p.Size = p.Size * (H / p.Size.Y)
	self.base, self.H, self.part = p.Size, H, p
	self.state = {x = 0, z = 0, lift = 0, s = 1, w = 1, roll = 0, pitch = 0, yaw = 0, shake = 0, imp = 0}
	self.token = 0
	self.targetX = 0
	self:apply()
	p.Parent = parent or workspace
	return self
end

function EggKeeper:apply()
	local s = self.state
	local sq = s.s * (1 - s.imp)
	local wid = s.w / math.sqrt(sq)
	self.part.Size = self.base * Vector3.new(wid, sq, wid)
	-- keep the egg on the ground whatever its tilt: centre height = half its extent along world up
	local a = self.H * sq / 2               -- half height along the egg's own up
	local r = self.H * 0.4 * wid            -- egg body radius sideways
	local up = (CFrame.Angles(s.pitch, 0, s.roll)).UpVector
	local ext = math.sqrt((a * up.Y) ^ 2 + (r * up.X) ^ 2 + (r * up.Z) ^ 2)
	local jitter = s.shake > 0 and Vector3.new((math.random() - 0.5) * s.shake, 0, (math.random() - 0.5) * s.shake) or Vector3.zero
	self.part.CFrame = self.goal.cf * CFrame.new(Vector3.new(s.x, s.lift + ext, s.z) + jitter)
		* CFrame.Angles(0, s.yaw, 0) * CFrame.Angles(s.pitch, 0, s.roll) * FACE
end

-- runs fn(alpha) every frame for dur (scaled) seconds; false if a newer move took over
function EggKeeper:run(dur, fn)
	local tok = self.token
	local t = 0
	dur = math.max(dur, 1e-3)
	while true do
		if self.token ~= tok or not self.part.Parent then return false end
		local a = math.min(1, t / dur)
		fn(a)
		self:apply()
		if a >= 1 then return true end
		t += RunService.Heartbeat:Wait() * EggKeeper.timeScale
	end
end
function EggKeeper:wait(d) return self:run(d, function() end) end
function EggKeeper:take() self.token += 1; return self.token end

function EggKeeper:turnTo(yaw, dur)
	local s = self.state
	local y0 = s.yaw
	local d = wrap(yaw - y0)
	if math.abs(d) < 0.02 then return true end
	return self:run(dur or 0.14, function(a) s.yaw = y0 + d * smooth(a) end)
end
function EggKeeper:faceKicker(dur) return self:turnTo(0, dur or 0.16) end

-- one hop. If it travels, it turns to face where it's going and leans into the hop.
function EggKeeper:hop(dx, dz, height, dur, opts)
	opts = opts or {}
	local s = self.state
	dur = dur or 0.32
	local dist = math.sqrt(dx * dx + dz * dz)
	local face = opts.face ~= false and dist > 0.5
	if face and not self:turnTo(math.atan2(-dx, -dz), 0.12) then return false end
	local x0, z0, yaw0, p0, r0 = s.x, s.z, s.yaw, s.pitch, s.roll
	if not self:run(0.08, function(a) s.s = lerp(1, 0.82, outQuad(a)) end) then return false end
	if not self:run(dur, function(a)
		local e = inOutSine(a)
		s.x = x0 + dx * e
		s.z = z0 + dz * e
		s.lift = 4 * height * a * (1 - a)
		s.s = 1.12 - 0.16 * math.sin(math.pi * a)
		if face then s.pitch = p0 - 0.22 * math.sin(math.pi * a) end
		if opts.spin then s.yaw = yaw0 + opts.spin * smooth(a) end
	end) then return false end
	s.lift, s.pitch = 0, p0
	if self.onLand then task.spawn(self.onLand, self, height) end
	if opts.spin then s.yaw = wrap(s.yaw) end
	if not self:run(0.06, function(a) s.s = lerp(1.06, 0.8, a) end) then return false end
	return self:run(0.2, function(a) s.s = lerp(0.8, 1, outBack(a)) end)
end

-- hop to goal-local (x, z) in even steps, facing the way, then turn back to the kicker
function EggKeeper:travel(x, z, stepLen, height, stepDur)
	local s = self.state
	local dx, dz = x - s.x, z - s.z
	local d = math.sqrt(dx * dx + dz * dz)
	local n = math.max(1, math.ceil(d / (stepLen or 2.2)))
	for _ = 1, n do
		if not self:hop(dx / n, dz / n, height or (self.stats.hop + 0.3), stepDur or 0.28) then return false end
	end
	return self:faceKicker()
end

function EggKeeper:enter()
	self:take()
	local s = self.state
	s.x, s.z, s.lift = self.goal.width / 2 + 4, -3, 0
	s.yaw = math.atan2(s.x, s.z)   -- already facing the way in
	self:apply()
	self:travel(0, 0, 2.4, self.stats.hop + 0.5, 0.3)
end

function EggKeeper:idle()
	local tok = self:take()
	task.spawn(function()
		if not self:faceKicker(0.25) then return end
		local s = self.state
		local t = 0
		local y0 = s.yaw
		while self.token == tok and self.part.Parent do
			s.s = 1 + 0.025 * math.sin(t * math.pi * 2 / 1.7)          -- breathing
			s.roll = 0.045 * math.sin(t * math.pi * 2 / 2.6)            -- weight shift
			s.yaw = y0 + 0.07 * math.sin(t * math.pi * 2 / 4.1 + 1)     -- glancing
			s.pitch = -0.03 - 0.02 * math.sin(t * math.pi * 2 / 1.7)    -- leaning in, ready
			self:apply()
			t += RunService.Heartbeat:Wait() * EggKeeper.timeScale
		end
	end)
end

function EggKeeper:track(x)
	self.targetX = math.clamp(x, -self.goal.width / 2 + self.H * 0.4, self.goal.width / 2 - self.H * 0.4)
end

-- dive toward goal-local (x, y). Fast takeoff, slow controlled finish.
-- arriveIn (optional): seconds until the ball gets there; the dive is timed to meet it
function EggKeeper:dive(target, willSave, arriveIn)
	self:take()
	local st, s = self.stats, self.state
	local half = self.goal.width / 2
	local tx = math.clamp(target.X, -half + self.H * 0.3, half - self.H * 0.3)
	local ty = target.Y
	if willSave then
		local reachX = st.reach * half + self.H
		tx = math.clamp(tx, s.x - reachX, s.x + reachX)
	else
		tx = s.x + (tx - s.x) * 0.45   -- falls short
		ty = ty * 0.45
	end
	local sp = st.diveSpeed
	local react = st.react
	if arriveIn then react = math.min(react, arriveIn * 0.25) end
	-- time left for the actual leap once reacting and crouching are done
	local function leap(base, used)
		if not arriveIn then return base / sp end
		return math.clamp(arriveIn - react - used, 0.1, base / sp * 1.3)
	end
	self:faceKicker(0.05)
	s.pitch = 0
	self:wait(react)
	local x0 = s.x
	local dir = (tx - x0) >= 0 and 1 or -1

	if st.style == "dig" then
		self:run(0.22, function(a) s.s = lerp(1, 0.68, outQuad(a)) end)
		self:run(0.5, function(a) s.roll = math.sin(a * math.pi * 3) * 0.08 * (1 - a) end)
		s.roll = 0
		return
	end

	if st.style == "feint" then
		-- a quick fake step the wrong way, then the real dive
		local fd = arriveIn and math.min(0.16, arriveIn * 0.2) or 0.16
		self:run(fd, function(a)
			s.x = x0 - dir * 0.9 * math.sin(math.pi * a)
			s.lift = 0.5 * math.sin(math.pi * a)
			s.roll = dir * 0.15 * math.sin(math.pi * a)
		end)
		s.lift, s.roll = 0, 0
	end

	if st.style == "roll" then
		local r = self.H * 0.35
		local lift = math.clamp(ty - self.H * 0.6, 0, 1.5)
		self:run(0.1, function(a) s.s = lerp(1, 0.8, outQuad(a)) end)
		self:run(leap(0.55, 0.1), function(a)
			local e = outCubic(a)
			s.x = lerp(x0, tx, e)
			s.roll = -(s.x - x0) / r
			s.lift = 4 * lift * a * (1 - a)
			s.s = lerp(0.8, 1, math.min(1, a * 4))
		end)
		s.lift = 0
		local r1 = s.roll
		self:run(0.35, function(a) s.roll = lerp(r1, r1 - dir * 0.25, outQuad(a)) end)
		return
	end

	-- Load up, explode off the line, and reach FULL STRETCH exactly as the ball arrives (2026-11-11:
	-- the old dive launched at once and was already coming down when the ball got there, so it read
	-- as a flop, not a save). A beaten egg stretches out with its tip a whisker short of the ball.
	local H = self.H
	local reachX = st.reach * half + H
	local aimX, aimY = math.clamp(target.X, -half + H * 0.3, half - H * 0.3), target.Y   -- where the ball really goes
	local endX, peak
	if willSave then
		endX = aimX - dir * H * 0.22
		peak = math.max(0.15, aimY - H * 0.5)
	else
		endX = aimX - dir * (H * 0.5 + 1.5)
		peak = math.max(0.15, aimY - H * 0.5 - 0.5)
	end
	endX = math.clamp(endX, x0 - reachX, x0 + reachX)
	endX = math.clamp(endX, -half + H * 0.3, half - H * 0.3)
	local feintUsed = (st.style == "feint" and arriveIn) and math.min(0.16, arriveIn * 0.2) or (st.style == "feint" and 0.16 or 0)
	local crouch = arriveIn and math.min(0.2, arriveIn * 0.22) or 0.14
	local leapT = arriveIn and math.max(0.16, arriveIn - react - feintUsed - crouch) or (0.42 / sp)
	self:run(crouch, function(a)
		local e = outQuad(a)
		s.s = lerp(1, 0.66, e)
		s.x = x0 - dir * 0.35 * e          -- winds up the other way
		s.roll = dir * 0.12 * e
		s.pitch = -0.1 * e
	end)
	local xs, r0, p0 = s.x, s.roll, s.pitch
	self:run(leapT, function(a)
		local e = 1 - (1 - a) ^ 1.7        -- fast off the line, still travelling when it gets there
		s.x = lerp(xs, endX, e)
		s.lift = peak * (1 - (1 - a) ^ 2)
		s.roll = lerp(r0, -dir * 1.3, smooth(math.min(1, a / 0.7)))
		s.pitch = lerp(p0, 0, math.min(1, a * 3))
		s.s = a < 0.25 and lerp(0.66, 1.3, a / 0.25) or lerp(1.3, 1.2, (a - 0.25) / 0.75)
	end)
	self.atBall = true                     -- full stretch: the runner reads this
	if self.holdAtBall then return end     -- blasted: the runner takes it from here
	-- follow through, then down onto its side and a skid
	local hx = s.x
	self:run(0.14, function(a)
		s.x = hx + dir * 0.5 * a
		s.lift = peak + 0.12 * math.sin(math.pi * a)
		s.s = lerp(1.2, 1.1, a)
	end)
	local lx, lt, rt = s.x, s.lift, s.roll
	self:run(0.3, function(a)
		s.lift = lt * (1 - inQuad(a))
		s.roll = lerp(rt, -dir * math.pi / 2, smooth(a))
		s.x = lx + dir * 0.6 * a
		s.s = lerp(1.1, 1, a)
	end)
	s.lift = 0
	if self.onLand then task.spawn(self.onLand, self, 3) end
	local sx = s.x
	self:run(0.06, function(a) s.s = lerp(1, 0.8, a) end)
	self:run(0.45, function(a)
		s.s = lerp(0.8, 1, outBack(a))
		s.x = math.clamp(sx + dir * 1.4 * outQuad(a), -half + H * 0.3, half - H * 0.3)
		s.roll = -dir * (math.pi / 2 + 0.14 * math.sin(a * math.pi * 2) * (1 - a))
	end)
end

-- on its toes while the kicker runs up: a quick side-to-side shuffle
function EggKeeper:ready()
	local tok = self:take()
	task.spawn(function()
		if not self:faceKicker(0.1) then return end
		local s = self.state
		local x0, t = s.x, 0
		while self.token == tok and self.part.Parent do
			local ph = t * math.pi * 2 / 0.52
			s.x = x0 + 0.32 * math.sin(ph)
			s.lift = 0.24 * math.abs(math.cos(ph))
			s.roll = -0.1 * math.sin(ph)
			s.s = 1 + 0.07 * math.cos(ph * 2)
			s.pitch = -0.07
			self:apply()
			t += RunService.Heartbeat:Wait() * EggKeeper.timeScale
		end
	end)
end

-- stand up from wherever it is lying
function EggKeeper:standUp(dur)
	local s = self.state
	local r0, p0, l0 = wrap(s.roll), wrap(s.pitch), s.lift
	return self:run(dur or 0.4, function(a)
		s.roll = lerp(r0, 0, outBack(a))
		s.pitch = lerp(p0, 0, outBack(a))
		s.lift = l0 * (1 - a) + 0.5 * math.sin(math.pi * a)
		s.s = lerp(s.s, 1, a)
	end)
end

-- beaten: lies there a moment, pushes itself up, turns to look at the ball in its net, and sags
function EggKeeper:defeated()
	local tok = self:take()
	local s = self.state
	if not self:wait(0.15) then return end
	if not self:standUp(0.45) then return end
	s.roll, s.pitch, s.lift = 0, 0, 0
	if not self:turnTo(math.pi, 0.4) then return end
	if not self:run(0.4, function(a) s.s = lerp(1, 0.86, outQuad(a)); s.pitch = lerp(0, -0.24, outQuad(a)) end) then return end
	task.spawn(function()
		local t = 0
		while self.token == tok and self.part.Parent do
			s.s = 0.86 + 0.02 * math.sin(t * 2.2)
			self:apply()
			t += RunService.Heartbeat:Wait() * EggKeeper.timeScale
		end
	end)
end

-- BLASTED: the shot goes straight through it. Carried back into the net tumbling, flattens against
-- it (onNet fires there), is thrown back out, bounces, balances on its head and topples over.
function EggKeeper:blasted(depth, onNet)
	self:take()
	local s = self.state
	depth = depth or 3.2
	local z0, l0 = s.z, s.lift
	if not self:run(0.14 + depth * 0.014, function(a)
		s.z = z0 + depth * a
		s.lift = l0 + 0.7 * math.sin(math.pi * a * 0.5)
		s.pitch = a * math.pi * 2.5
		s.roll = s.roll * (1 - a)
		s.s = lerp(1.2, 0.95, a)
	end) then return end
	if onNet then task.spawn(onNet, self) end
	self:bounce(0.42)
	local z1, l1, p1 = s.z, s.lift, s.pitch
	if not self:run(0.16, function(a) s.z = z1 + 0.5 * math.sin(math.pi * a * 0.5) end) then return end
	local z2 = s.z
	-- thrown back out and down, ending upside down
	if not self:run(0.5, function(a)
		s.z = z2 - math.max(2.4, depth * 0.45) * outQuad(a)
		s.lift = l1 * (1 - inQuad(a))
		s.pitch = lerp(p1, math.pi * 3, a)
	end) then return end
	s.lift, s.pitch = 0, math.pi
	if self.onLand then task.spawn(self.onLand, self, 3) end
	local z3 = s.z
	self:run(0.07, function(a) s.s = lerp(1, 0.78, a) end)
	if not self:run(0.34, function(a)                 -- one more bounce, still on its head
		s.s = lerp(0.78, 1, math.min(1, a * 3))
		s.lift = 0.9 * math.sin(math.pi * a)
		s.z = z3 - 0.7 * a
	end) then return end
	s.lift = 0
	if self.onLand then task.spawn(self.onLand, self, 1.5) end
	if not self:run(0.7, function(a) s.roll = 0.3 * math.sin(a * math.pi * 5) * (1 - a) end) then return end   -- wobbles on its head
	if not self:run(0.4, function(a) s.pitch = lerp(math.pi, math.pi * 1.5, inQuad(a)) end) then return end     -- and over it goes
	s.pitch, s.roll = -math.pi / 2, 0
	if self.onLand then task.spawn(self.onLand, self, 2) end
	self:run(0.25, function(a) s.s = lerp(0.85, 1, outBack(a)) end)
end

-- seeing stars: lies there rocking and slowly turning
function EggKeeper:dazed()
	local tok = self:take()
	task.spawn(function()
		local s = self.state
		local t, y0 = 0, s.yaw
		while self.token == tok and self.part.Parent do
			s.roll = 0.13 * math.sin(t * 5)
			s.yaw = y0 + 0.5 * t
			self:apply()
			t += RunService.Heartbeat:Wait() * EggKeeper.timeScale
		end
	end)
end

-- the ball hits it: quick squash and recover
function EggKeeper:bounce(strength)
	local s = self.state
	local k = strength or 0.22
	task.spawn(function()
		local t, dur = 0, 0.32
		while t < dur and self.part.Parent do
			local a = t / dur
			s.imp = k * math.sin(math.pi * math.min(1, a * 2.2)) * (1 - a) ^ 1.5
			t += RunService.Heartbeat:Wait() * EggKeeper.timeScale
		end
		s.imp = 0
	end)
end

function EggKeeper:getUp()
	self:take()
	local s = self.state
	local r0, p0 = s.roll, s.pitch
	self:run(0.35, function(a)
		s.roll = lerp(r0, 0, outBack(a))
		s.pitch = lerp(p0, 0, outBack(a))
		s.lift = 0.7 * math.sin(math.pi * a)
	end)
	s.roll, s.pitch, s.lift, s.s = 0, 0, 0, 1
	self:travel(0, 0, 2.2, 0.6, 0.26)
end

function EggKeeper:celebrate()
	self:take()
	self:faceKicker(0.1)
	self:hop(0, 0, 1.5, 0.42, {face = false, spin = math.pi * 2})
	self:hop(0, 0, 0.7, 0.3, {face = false})
end

-- blasted: knocked back into the net
function EggKeeper:tumble()
	self:take()
	local s = self.state
	local z0, p0 = s.z, s.pitch
	self:run(0.5, function(a)
		s.z = z0 + 3 * outCubic(a)
		s.pitch = p0 + 2.4 * outCubic(a)
		s.lift = 1.4 * math.sin(math.pi * a)
	end)
	s.lift = 0
	self:run(0.4, function(a) s.pitch = lerp(p0 + 2.4, math.pi / 2, outBack(a)) end)
end

local function emitEffect(name, at, count)
	local vfx = game:GetService("ReplicatedStorage"):FindFirstChild("Assets")
	vfx = vfx and vfx:FindFirstChild("VFX") and vfx.VFX:FindFirstChild("Effects")
	local src = vfx and vfx:FindFirstChild(name)
	if not src then return end
	local holder = Instance.new("Part")
	holder.Anchored, holder.CanCollide, holder.CanQuery, holder.Transparency = true, false, false, 1
	holder.Size = Vector3.one * 0.2
	holder.CFrame = CFrame.new(at)
	local att = Instance.new("Attachment", holder)
	holder.Parent = workspace
	for _, e in ipairs(src:GetDescendants()) do
		if e:IsA("ParticleEmitter") then
			local c = e:Clone()
			c.Enabled = false
			c.Parent = att
			c:Emit(count or 25)
		end
	end
	game:GetService("Debris"):AddItem(holder, 4)
end
EggKeeper.emitEffect = emitEffect

-- shake, crack, burst into shell bits, the animal pops out
-- returns the hatched animal model
function EggKeeper:hatch(animalTemplate, animalHeight, onAnimal)
	self:take()
	local s = self.state
	local p = self.part
	-- stand back up first if lying down
	if math.abs(s.roll) > 0.05 or math.abs(s.pitch) > 0.05 then
		local r0, p0 = s.roll, s.pitch
		self:run(0.25, function(a) s.roll = lerp(r0, 0, outBack(a)); s.pitch = lerp(p0, 0, outBack(a)) end)
	end
	-- build-up: wobble faster and faster
	self:run(1.1, function(a)
		s.roll = math.sin(a * a * 38) * 0.16 * a
		s.s = 1 + math.sin(a * a * 50) * 0.04 * a
	end)
	-- big stretch then burst
	local hl = Instance.new("Highlight")
	hl.FillColor = Color3.new(1, 1, 1)
	hl.OutlineTransparency = 1
	hl.FillTransparency = 1
	hl.DepthMode = Enum.HighlightDepthMode.Occluded
	hl.Parent = p
	s.roll = 0
	self:run(0.16, function(a) s.s = lerp(1, 1.25, a); hl.FillTransparency = 1 - a * 0.9 end)
	local center = p.Position
	local base = p.CFrame.Position - Vector3.new(0, p.Size.Y / 2, 0)
	-- shell bits: chunky voxel pieces that fly out and fade
	local bits = {}
	local n = 18
	for i = 1, n do
		local b = Instance.new("Part")
		b.Anchored, b.CanCollide, b.CanQuery = true, false, false
		local sz = self.H * (0.12 + math.random() * 0.1)
		b.Size = Vector3.new(sz, sz * 0.5, sz)
		b.Material = Enum.Material.SmoothPlastic
		b.Color = (i % 3 == 0) and Color3.fromRGB(255, 244, 222) or Color3.fromRGB(245, 235, 210)
		local dir = Vector3.new(math.random() - 0.5, math.random() * 0.8 + 0.2, math.random() - 0.5).Unit
		b.CFrame = CFrame.new(center + dir * self.H * 0.35) * CFrame.Angles(math.random() * 6, math.random() * 6, 0)
		b.Parent = workspace
		bits[i] = {part = b, v = dir * (10 + math.random() * 10) + Vector3.new(0, 8, 0), spin = CFrame.Angles(math.random() * 0.3, math.random() * 0.3, 0)}
	end
	emitEffect("Poof", center, 30)
	emitEffect("Confetti", center + Vector3.new(0, self.H * 0.3, 0), 40)
	p.Transparency = 1
	for _, d in ipairs(p:GetDescendants()) do if d:IsA("Texture") or d:IsA("Decal") then d.Transparency = 1 end end
	task.spawn(function()
		local t0, last = os.clock(), os.clock()
		while os.clock() - t0 < 1.1 do
			local now = os.clock(); local dt = now - last; last = now
			for _, b in ipairs(bits) do
				b.v += Vector3.new(0, -60 * dt, 0)
				local pos = b.part.Position + b.v * dt
				if pos.Y < base.Y + b.part.Size.Y / 2 then pos = Vector3.new(pos.X, base.Y + b.part.Size.Y / 2, pos.Z); b.v = Vector3.new(b.v.X * 0.5, -b.v.Y * 0.3, b.v.Z * 0.5) end
				b.part.CFrame = CFrame.new(pos) * b.part.CFrame.Rotation * b.spin
				local f = math.clamp((now - t0 - 0.6) / 0.5, 0, 1)
				b.part.Transparency = f
			end
			RunService.Heartbeat:Wait()
		end
		for _, b in ipairs(bits) do b.part:Destroy() end
	end)
	-- the animal pops out
	local animal
	if animalTemplate then
		animal = animalTemplate:Clone()
		for _, d in ipairs(animal:GetDescendants()) do if d:IsA("BasePart") then d.Anchored = true; d.CanCollide = false end end
		-- measure by mesh parts only (GetBoundingBox is thrown off by tiny helper parts)
		local function box()
			local mn, mx = Vector3.one * math.huge, -Vector3.one * math.huge
			for _, q in ipairs(animal:GetDescendants()) do
				if q:IsA("MeshPart") then
					local c, h = q.CFrame, q.Size / 2
					local e = Vector3.new(
						math.abs(c.XVector.X) * h.X + math.abs(c.YVector.X) * h.Y + math.abs(c.ZVector.X) * h.Z,
						math.abs(c.XVector.Y) * h.X + math.abs(c.YVector.Y) * h.Y + math.abs(c.ZVector.Y) * h.Z,
						math.abs(c.XVector.Z) * h.X + math.abs(c.YVector.Z) * h.Y + math.abs(c.ZVector.Z) * h.Z)
					mn = mn:Min(c.Position - e); mx = mx:Max(c.Position + e)
				end
			end
			return mn, mx
		end
		local mn, mx = box()
		local full = animal:GetScale() * (animalHeight or self.H * 1.1) / math.max(mx.Y - mn.Y, 1e-3)
		animal.Parent = p.Parent
		local function place(scale)
			animal:ScaleTo(scale)
			local a1, b1 = box()
			local bottom = Vector3.new((a1.X + b1.X) / 2, a1.Y, (a1.Z + b1.Z) / 2)
			animal:PivotTo(animal:GetPivot() + (base - bottom))
		end
		place(full * 0.15)
		if onAnimal then onAnimal(animal) end
		local t0 = os.clock()
		while true do
			local a = math.min(1, (os.clock() - t0) / 0.45)
			place(full * lerp(0.15, 1, outBack(a)))
			if a >= 1 then break end
			RunService.Heartbeat:Wait()
		end
		place(full)
	end
	p:Destroy()
	return animal
end

function EggKeeper:destroy()
	self:take()
	if self.part then self.part:Destroy() end
end

return EggKeeper
