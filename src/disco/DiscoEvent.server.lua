-- DISCO KICKOFF event (pigeon, 14 Nov 2026): every so often a giant disco ball drops from the sky over the field for
-- DURATION seconds. While it's down, an egg that didn't roll a mutation can come out GROOVY
-- (GameConfig.Mutations "Groovy", chance GROOVY_CHANCE, hooked in ServerScriptService.EggInventory). A Groovy egg hatches
-- a Groovy animal: ReplicatedStorage.Assets.Animals.GroovyAnimals (each base animal with the afro + disco glasses, fitted
-- by ServerStorage.DiscoFit). The show is StarterPlayerScripts.DiscoClient.
-- Workspace attributes: DiscoActive (bool), DiscoEndsAt (server time), DiscoNextAt (server time), DiscoGroovyChance.
-- Never at night or during 2X EGGS. Admin / testing: ServerStorage.DiscoStart:Fire(seconds) starts one now.
-- Studio: workspace attribute TestDisco = true starts one straight away.
local RS = game:GetService("ReplicatedStorage")
local DURATION = 120
local GAP_MIN, GAP_MAX = 12 * 60, 20 * 60
local GROOVY_CHANCE = 0.12   -- about 1 in 8 eggs (pigeon: just some, not every egg)

workspace:SetAttribute("DiscoActive", false)
workspace:SetAttribute("DiscoGroovyChance", GROOVY_CHANCE)
local running = false
local function now() return workspace:GetServerTimeNow() end
local function blocked() return workspace:GetAttribute("IsNight") == true or workspace:GetAttribute("DoubleEggs") == true end

local function run(seconds)
	if running then return end
	running = true
	workspace:SetAttribute("DiscoEndsAt", now() + seconds)
	workspace:SetAttribute("DiscoActive", true)
	task.wait(seconds)
	workspace:SetAttribute("DiscoActive", false)
	running = false
end

local start = game:GetService("ServerStorage"):FindFirstChild("DiscoStart") or Instance.new("BindableEvent")
start.Name = "DiscoStart"
start.Parent = game:GetService("ServerStorage")
start.Event:Connect(function(seconds) task.spawn(run, tonumber(seconds) or DURATION) end)

if game:GetService("RunService"):IsStudio() then
	workspace:GetAttributeChangedSignal("TestDisco"):Connect(function()
		if workspace:GetAttribute("TestDisco") then task.spawn(run, DURATION) end
	end)
end

while true do
	local nextAt = now() + math.random(GAP_MIN, GAP_MAX)
	workspace:SetAttribute("DiscoNextAt", nextAt)
	while now() < nextAt or blocked() or running do task.wait(5) end
	-- only start if the whole show fits before night
	local phaseEnd = workspace:GetAttribute("PhaseEndsAt")
	if type(phaseEnd) == "number" and phaseEnd - now() < DURATION + 5 then
		while workspace:GetAttribute("IsNight") ~= true do task.wait(5) end
		continue
	end
	run(DURATION)
end
