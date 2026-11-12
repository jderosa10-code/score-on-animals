-- Shared numbers and helpers for hatching eggs on the plot patches and placing animals on the plot Land.
-- Used by ServerScriptService.EggHatching and StarterPlayerScripts.HatchClient.
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local C = {}

C.HATCH_SECONDS = 5     -- every egg for now
C.EGG_HEIGHT = 3.6      -- egg size sitting on a patch
C.HELD_SIZE = 2.6       -- animal size in your hand (longest side)
C.PLACED_MAX = 12       -- in your hand: the animal's real size, but none longer than this
C.FX_POP = 2.0          -- seconds after "Hatch" that the egg bursts (HatchClient's animation)
C.FX_TOTAL = 3.6        -- seconds after "Hatch" that the animal lands in your Backpack

-- Animal models: the server copies ones it needs from ReplicatedStorage.BaseAnimals into ReplicatedStorage.Hatching.Animals.
-- Mutated ones (mut = "Gold" etc.) come from ReplicatedStorage.Assets.Animals.<mut>Animals and are kept as "<mut>_<name>".
function C.animalTemplate(name, mut)
	local f = RS.Hatching.Animals
	local key = mut and (mut .. "_" .. name) or name
	local a = f:FindFirstChild(key)
	if a or not RunService:IsServer() then return a end
	local src
	if mut then
		local mf = RS:FindFirstChild("Assets") and RS.Assets:FindFirstChild("Animals") and RS.Assets.Animals:FindFirstChild(mut .. "Animals")
		src = mf and mf:FindFirstChild(name)
	end
	src = src or (RS:FindFirstChild("BaseAnimals") and RS.BaseAnimals:FindFirstChild(name))
	if not src then return nil end
	a = src:Clone()
	a.Name = key
	a:SetAttribute("BaseName", name)   -- placedScale looks up the rarity by it
	a.Parent = f
	return a
end

function C.mesh(model)
	return model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart", true)
end

-- (pigeon, 11 Nov 2026) placed animals are bigger than their real size, and the rarer the bigger:
-- longest side = real longest side x Grow, but no more than Max (rarer = higher Max). Tiny animals stay tiny.
C.SIZE = {
	Common = {Grow = 1.3, Max = 13}, Uncommon = {Grow = 1.4, Max = 14}, Rare = {Grow = 1.6, Max = 16},
	Epic = {Grow = 1.85, Max = 18}, Legendary = {Grow = 2.2, Max = 21}, Mythic = {Grow = 2.5, Max = 23},
	Exotic = {Grow = 2.8, Max = 25}, Divine = {Grow = 3.1, Max = 27}, Celestial = {Grow = 3.4, Max = 29},
	Secret = {Grow = 3.8, Max = 32}, Admin = {Grow = 2.2, Max = 21},
}
local EggRoll
local function rarityOf(tmpl)
	if EggRoll == nil then
		local ok, m = pcall(function() return require(RS:WaitForChild("DevDemo"):WaitForChild("EggRoll")) end)
		EggRoll = ok and m or false
	end
	if not EggRoll then return "Common" end
	local name = tmpl:GetAttribute("BaseName")
	if not name then   -- older copies: "<mut>_<name>" or just the name
		local base = RS:FindFirstChild("BaseAnimals")
		name = (base and base:FindFirstChild(tmpl.Name)) and tmpl.Name or tmpl.Name:match("^[^_]+_(.+)$") or tmpl.Name
	end
	return EggRoll.rarityOf(name) or "Common"
end

-- scale factor for a placed animal, and the radius it takes up on the Land
function C.placedScale(tmpl)
	local s = C.mesh(tmpl).Size
	local z = C.SIZE[rarityOf(tmpl)] or C.SIZE.Common
	local k = math.min(z.Grow, z.Max / math.max(s.X, s.Y, s.Z))
	return k, 0.5 * math.max(s.X, s.Z) * k
end

-- scale factor for the animal in your hand (its real size, none longer than PLACED_MAX)
function C.heldScale(tmpl)
	local s = C.mesh(tmpl).Size
	return math.min(1, C.PLACED_MAX / math.max(s.X, s.Y, s.Z))
end

function C.land(plot)
	return plot and plot:FindFirstChild("Land")
end

-- inside the Land and not on top of another placed animal
function C.canPlace(plot, pos, radius)
	local land = C.land(plot)
	if not land then return false end
	local lp = land.CFrame:PointToObjectSpace(pos)
	local r = radius * 0.9
	if math.abs(lp.X) + r > land.Size.X / 2 or math.abs(lp.Z) + r > land.Size.Z / 2 then return false end
	local f = plot:FindFirstChild("Animals")
	if f then
		for _, other in f:GetChildren() do
			local p = other:GetPivot().Position
			local d = Vector2.new(p.X - pos.X, p.Z - pos.Z).Magnitude
			if d < ((other:GetAttribute("Radius") or 2) + radius) * 0.75 then return false end
		end
	end
	return true
end

-- where a (scaled) animal model goes so its feet sit on the Land
function C.placedCFrame(land, model, pos, yaw)
	local mesh = C.mesh(model)
	local feet = model:GetPivot().Y - (mesh.Position.Y - mesh.Size.Y / 2)
	return CFrame.new(pos.X, land.Position.Y + land.Size.Y / 2 + feet, pos.Z) * CFrame.Angles(0, yaw, 0)
end

return C
