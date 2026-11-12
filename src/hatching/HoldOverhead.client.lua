-- HoldOverhead (pigeon-claude, 11 Nov 2026). StarterPlayerScripts.
-- Anyone holding an egg or an animal (a Tool with an EggName or AnimalName attribute) holds it up over their
-- head in both hands. GameData welds the item above the head; this raises the arms on every client, R15 and R6.
-- It writes the shoulder/elbow joint Transforms (Motor6D or AnimationConstraint) each frame after Roblox's own animation step (like KSTrack),
-- so it wins over the default one-armed tool pose, and stops as soon as the item is put away.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local UP = math.rad(172)     -- shoulder: from hanging down to almost straight up (a touch forward)
local IN = math.rad(16)      -- arms lean in toward the item
local BEND = math.rad(14)    -- a little give at the elbows

local function holding(char)
	local t = char:FindFirstChildOfClass("Tool")
	return t and (t:GetAttribute("EggName") or t:GetAttribute("AnimalName")) and t
end

local R15 = {
	RightShoulder = CFrame.Angles(0, 0, IN) * CFrame.Angles(UP, 0, 0),
	LeftShoulder = CFrame.Angles(0, 0, -IN) * CFrame.Angles(UP, 0, 0),
	RightElbow = CFrame.Angles(BEND, 0, 0),
	LeftElbow = CFrame.Angles(BEND, 0, 0),
	RightWrist = CFrame.identity,
	LeftWrist = CFrame.identity,
}
-- R6 shoulders turn about their own Z axis (the old "DesiredAngle"); left and right are mirrored
local R6 = {
	["Right Shoulder"] = CFrame.Angles(0, 0, UP) * CFrame.Angles(-IN, 0, 0),
	["Left Shoulder"] = CFrame.Angles(0, 0, -UP) * CFrame.Angles(-IN, 0, 0),
}

local cache = {}   -- [character] = {motor = pose}
local function motorsOf(char)
	local c = cache[char]
	if c then return c end
	c = {}
	for _, m in char:GetDescendants() do
		if m:IsA("Motor6D") or m:IsA("AnimationConstraint") then   -- newer avatars use AnimationConstraint joints
			local pose = R15[m.Name] or R6[m.Name]
			if pose then c[m] = pose end
		end
	end
	cache[char] = c
	char.AncestryChanged:Connect(function(_, parent) if not parent then cache[char] = nil end end)
	return c
end

RunService.Stepped:Connect(function()
	for _, plr in Players:GetPlayers() do
		local char = plr.Character
		if char and holding(char) then
			for m, pose in motorsOf(char) do
				if m.Parent then m.Transform = pose end
			end
		end
	end
end)
