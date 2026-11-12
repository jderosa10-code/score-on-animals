-- Rainbow eggs (ReplicatedStorage.Assets.Eggs.RainbowEggs, tag "RainbowEgg") are plain white models, so the
-- colour is done here: every rainbow egg in the world (in the goal, on a patch, in your hand) cycles
-- through the rainbow. Clones keep the tag, so nothing else needs to know about it.
-- Lives in StarterPlayer.StarterPlayerScripts.RainbowEggClient.
local CS = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local SPEED = 0.35   -- rainbow loops per second

RunService.RenderStepped:Connect(function()
	local t = os.clock() * SPEED
	for _, p in CS:GetTagged("RainbowEgg") do
		if p:IsA("BasePart") and p:IsDescendantOf(workspace) then
			local pos = p.Position
			p.Color = Color3.fromHSV((t + (pos.X + pos.Y + pos.Z) * 0.01) % 1, 0.75, 1)
		end
	end
end)
