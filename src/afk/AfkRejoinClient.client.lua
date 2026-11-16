-- AFK REJOIN, client side (pigeon-claude, 15 Nov 2026). Counts how long you've had no input; while you're lifting,
-- at GameConfig.AfkRejoinSeconds (18 min, before Roblox's 20-min idle kick) it asks ServerScriptService.AfkRejoin
-- to rejoin you (which resets Roblox's idle timer). Studio test speed: workspace attribute DebugAfkRejoin = seconds.
-- Live copy: StarterPlayer.StarterPlayerScripts.AfkRejoinClient (this file is a reference copy).
local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local G = require(RS:WaitForChild("GameConfig"))
local ev = RS:WaitForChild("GameRemotes"):WaitForChild("AfkRejoin")
local player = Players.LocalPlayer

local last = os.clock()
local function poke() last = os.clock() end
UIS.InputBegan:Connect(poke)
UIS.InputChanged:Connect(poke)   -- mouse moves, touch drags, sticks
-- Roblox's own idle count (fires after 2 min idle): never let ours be shorter than Roblox's
player.Idled:Connect(function(t) last = math.min(last, os.clock() - t) end)

local asked = -math.huge
while true do
	task.wait(5)
	local limit = (RunService:IsStudio() and workspace:GetAttribute("DebugAfkRejoin")) or G.AfkRejoinSeconds or 1080
	if player:GetAttribute("Lifting") and os.clock() - last >= limit and os.clock() - asked > 60 then
		asked = os.clock()
		ev:FireServer()
	end
end
