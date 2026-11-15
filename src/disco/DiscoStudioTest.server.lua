-- DISCO STUDIO TEST (pigeon-claude, 14 Nov 2026). STUDIO ONLY, does nothing in a live server.
-- For pigeon's account (TEST_USERS) only, so other people's Studio play tests are left alone.
-- When you join a Studio play test:
--  * a few Groovy (disco-skin) animals appear in your pen. They are display copies only: not in your save, no income,
--    gone when the test stops (attribute DiscoTestOnly).
--  * the Disco Kickoff show starts (workspace DiscoActive) for SHOW_SECONDS. ServerScriptService.DiscoEvent stays
--    disabled; this only flips the attribute the show listens to. While it's on, eggs can roll Groovy (EggInventory),
--    and those DO save, like any other test hatch.
-- To stop it: disable this script (Enabled = false) or delete it.
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
if not RunService:IsStudio() then return end

local TEST_USERS = {[89199750] = true}   -- bmasterdevil (the account pigeon tests with)
local SHOW_SECONDS = 180
local ANIMALS = {"Lion", "Corgi", "Wolf", "Elephant", "Toucan", "Shark", "Dragon"}

local C = require(RS:WaitForChild("Hatching"):WaitForChild("HatchConfig"))
local G = require(RS:WaitForChild("GameConfig"))

local function fillPen(player)
	local plot
	for _ = 1, 60 do
		plot = workspace.Plots:FindFirstChild(player:GetAttribute("Plot") or "")
		if plot and C.land(plot) then break end
		task.wait(0.5)
	end
	if not plot then return end
	task.wait(2)   -- let the saved animals load in first, so the copies go in the free spots
	local land = C.land(plot)
	local f = plot:FindFirstChild("Animals")
	if not f then f = Instance.new("Folder"); f.Name = "Animals"; f.Parent = plot end
	for _, m in f:GetChildren() do if m:GetAttribute("DiscoTestOnly") then m:Destroy() end end
	local sx, sz = land.Size.X, land.Size.Z
	for _, name in ANIMALS do
		local tmpl = C.animalTemplate(name, "Groovy")
		if tmpl then
			local k, radius = C.placedScale(tmpl)
			local spot
			for gx = -0.42, 0.42, 0.12 do
				for gz = -0.42, 0.42, 0.12 do
					local pos = land.CFrame:PointToWorldSpace(Vector3.new(gx * sx, land.Size.Y / 2, gz * sz))
					if not spot and C.canPlace(plot, pos, radius) then spot = pos end
				end
			end
			if spot then
				local m = tmpl:Clone()
				m:ScaleTo(m:GetScale() * k)
				for _, d in m:GetDescendants() do if d:IsA("BasePart") then d.Anchored, d.CanCollide = true, false end end
				m:PivotTo(C.placedCFrame(land, m, spot, math.pi))
				m:SetAttribute("AnimalName", name); m:SetAttribute("Mutation", "Groovy"); m:SetAttribute("Radius", radius)
				m:SetAttribute("DiscoTestOnly", true)
				G.addMutationVFX(C.mesh(m), "Groovy")
				m.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
				m.Parent = f
			end
		end
	end
end

local running = false
local function startShow()
	if running or workspace:GetAttribute("DiscoActive") then return end
	running = true
	workspace:SetAttribute("DiscoEndsAt", workspace:GetServerTimeNow() + SHOW_SECONDS)
	workspace:SetAttribute("DiscoActive", true)
	task.delay(SHOW_SECONDS, function()
		workspace:SetAttribute("DiscoActive", false)
		running = false
	end)
end

local function onJoin(player)
	if not TEST_USERS[player.UserId] then return end
	task.spawn(fillPen, player)
	task.delay(6, startShow)   -- after the loading screen
end
Players.PlayerAdded:Connect(onJoin)
for _, p in Players:GetPlayers() do onJoin(p) end
