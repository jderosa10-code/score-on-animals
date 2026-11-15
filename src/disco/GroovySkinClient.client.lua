-- Groovy (Disco Kickoff) mutation skin (pigeon-claude, 14 Nov 2026). Groovy animals and eggs are silver mirror tiles
-- (Texture "DiscoMirror") with a layer of coloured light spots (Texture "DiscoSpots", tag DiscoSpots), 8x8 tiles per texture.
-- Every beat the spots jump one tile, and the direction changes every 4 beats, so the animal looks like a disco ball
-- catching the lights. Different from Rainbow on purpose: Rainbow is smooth colour bands, Groovy is tiles that flash.
local CS = game:GetService("CollectionService")
local BEAT = 0.5
local DIRS = {{1, 0}, {0, 1}, {-1, 0}, {0, -1}, {1, 1}, {-1, 1}}
local step = 0
while true do
	task.wait(BEAT)
	step += 1
	local d = DIRS[(step // 4) % #DIRS + 1]
	for _, t in CS:GetTagged("DiscoSpots") do
		if t:IsA("Texture") and t:IsDescendantOf(workspace) then
			local cu, cv = t.StudsPerTileU / 8, t.StudsPerTileV / 8   -- one tile (works after a model is scaled)
			t.OffsetStudsU = (t.OffsetStudsU + d[1] * cu) % t.StudsPerTileU
			t.OffsetStudsV = (t.OffsetStudsV + d[2] * cv) % t.StudsPerTileV
		end
	end
end
