-- AFK REJOIN (pigeon-claude, 15 Nov 2026; pigeon: "if you're lifting weights and go AFK for 20 minutes, will it kick you
-- out? ... work a way around it")
-- Roblox kicks anyone with no input for 20 minutes. While you LIFT, StarterPlayerScripts.AfkRejoinClient asks for a
-- rejoin at GameConfig.AfkRejoinSeconds (18 min) of no input: your save is written first, then you're teleported back
-- into THIS server (any server if that fails), which resets Roblox's idle timer. On arrival you're put on your own
-- weight mat and WorkoutClient starts lifting again by itself. Only while lifting: idle anywhere else = the normal kick.
-- Teleports don't work in Studio (they end the play test): there it skips the teleport and only tests the arrival
-- (back to your spawn, then onto the mat). Studio test speed: workspace attribute DebugAfkRejoin = seconds (Studio only).
-- Live copy: ServerScriptService.AfkRejoin (this file is a reference copy; patch the live Source, don't paste over it).
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local TeleportService = game:GetService("TeleportService")
local RunService = game:GetService("RunService")
local D = require(script.Parent:WaitForChild("GameData"))
local Remotes = RS:WaitForChild("GameRemotes")
local ev = Remotes:WaitForChild("AfkRejoin")

local busy = {}

-- put them on their own weight mat (the rack's biggest part, like ServerScriptService.Workout); WorkoutClient starts
-- the lift as soon as it sees them standing on it
local function toMat(player)
	for _ = 1, 80 do
		local plot = workspace.Plots:FindFirstChild(player:GetAttribute("Plot") or "")
		local zone = plot and plot:FindFirstChild("WorkoutZone")
		local rack = zone and zone:FindFirstChild("WeightRack")
		local char = player.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart")
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if rack and hrp and hum and player:GetAttribute("DataLoaded") then
			local mat
			for _, p in rack:GetChildren() do
				if p:IsA("BasePart") and (not mat or p.Size.X * p.Size.Z > mat.Size.X * mat.Size.Z) then mat = p end
			end
			if not mat then return false end
			task.wait(2)   -- after the join's own spawn moves
			if not (player.Parent and char.Parent) then return false end
			local y = mat.Position.Y + mat.Size.Y / 2 + hum.HipHeight + hrp.Size.Y / 2 + 0.2
			char:PivotTo(CFrame.new(mat.Position.X, y, mat.Position.Z) * (hrp.CFrame - hrp.Position))
			return true
		end
		task.wait(0.5)
	end
	return false
end

local function teleport(player, sameServer)
	local opts = Instance.new("TeleportOptions")
	if sameServer then opts.ServerInstanceId = game.JobId end
	opts:SetTeleportData({afkLift = true})
	return pcall(function() TeleportService:TeleportAsync(game.PlaceId, {player}, opts) end)
end

ev.OnServerEvent:Connect(function(player)
	if busy[player] or not player:GetAttribute("Lifting") or player:GetAttribute("InDuel") then return end
	busy[player] = true
	pcall(Remotes.Notify.FireClient, Remotes.Notify, player, "Still lifting! Rejoining so you don't get kicked for being AFK...")
	D.save(player)   -- written before you leave, so the rejoin loads it
	if RunService:IsStudio() then
		-- Studio can't teleport (it just ends the play test): test the arrival instead (to your spawn, then onto the mat)
		busy[player] = nil
		local plot = workspace.Plots:FindFirstChild(player:GetAttribute("Plot") or "")
		local spawn = plot and plot:FindFirstChild("Spawn")
		if spawn and player.Character then player.Character:PivotTo(CFrame.new(spawn.Position + Vector3.new(0, 5, 0))) end
		print("AfkRejoin: Studio, would rejoin " .. player.Name .. " now; testing the arrival:", toMat(player))
		return
	end
	local ok, err = teleport(player, true)
	if not ok then ok, err = teleport(player, false) end
	if not ok then
		warn("AfkRejoin: couldn't rejoin " .. player.Name .. ": " .. tostring(err))
		busy[player] = nil
	end
end)

-- the same-server rejoin failed after it started (server full, etc.): try any server
TeleportService.TeleportInitFailed:Connect(function(player, result, msg, placeId, opts)
	if not busy[player] then return end
	warn("AfkRejoin: teleport failed for " .. player.Name .. " (" .. tostring(result) .. ") " .. tostring(msg))
	if opts and opts.ServerInstanceId ~= "" then
		local ok = teleport(player, false)
		if ok then return end
	end
	busy[player] = nil
end)

local function joined(player)
	local ok, jd = pcall(player.GetJoinData, player)
	local td = ok and jd and jd.TeleportData
	if type(td) == "table" and td.afkLift then
		print("AfkRejoin: " .. player.Name .. " is back from an AFK rejoin, back to lifting")
		task.spawn(toMat, player)
	end
end
Players.PlayerAdded:Connect(joined)
for _, p in Players:GetPlayers() do task.spawn(joined, p) end
Players.PlayerRemoving:Connect(function(p) busy[p] = nil end)
