-- StarterPlayer.StarterPlayerScripts.RestyleShowcaseClient
-- Rebuilds the restyled NEW test animals next to the originals every time you Play.
-- (Editable meshes can't be saved in the place, so they're built on the client at runtime.)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Builder = require(ReplicatedStorage:WaitForChild("RestyleBuilder"))

local show = workspace:WaitForChild("RestyleShowcase", 30)
if not show then return end
print("[Restyle] building the NEW animals...")
local ok, res = pcall(Builder.buildAllSlots)
local n = 0
if ok and res then
	for _, d in ipairs(res:GetDescendants()) do
		if d:IsA("MeshPart") then n += 1 end
	end
end
if ok and n > 0 then
	print("[Restyle] done: " .. n .. " parts built")
else
	warn("[Restyle] the NEW animals didn't build (" .. tostring(ok and "0 parts" or res) .. "). "
		.. "If it mentions Editable or permission: Game Settings > Security > turn on 'Allow Mesh / Image APIs'.")
end
