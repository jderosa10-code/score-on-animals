-- Shared numbers and helpers for hatching eggs on the plot patches and placing animals on the plot Land.
-- Used by ServerScriptService.EggHatching and StarterPlayerScripts.HatchClient.
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local C = {}

C.HATCH_SECONDS = 5     -- every egg for now
C.EGG_HEIGHT = 3.6      -- egg size sitting on a patch
C.HELD_SIZE = 2.6       -- animal size in your hand (longest side)
-- (pigeon, 11 Nov 2026) held over your head in both hands.
-- (Jacob, 11 Nov 2026) at their normal size: animals at real size (only the giant ones capped), eggs full size.
C.HELD_MAX = 14         -- animals: real size, none longer than this (Dragon is 45 studs real)
C.HELD_EGG_MAX = 3.5    -- eggs held over your head: none longer than this (pigeon, 11 Nov: full size was "too big")
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
	local name = tmpl:GetAttribute("BaseName")
	if not name then   -- older copies: "<mut>_<name>" or just the name
		local base = RS:FindFirstChild("BaseAnimals")
		name = (base and base:FindFirstChild(tmpl.Name)) and tmpl.Name or tmpl.Name:match("^[^_]+_(.+)$") or tmpl.Name
	end
	-- GameConfig.AnimalRarity is the real tier list (EggRoll's older table didn't know most animals, so
	-- nearly everything came out "Common" and a Dragon was corgi-sized)
	local ok, G = pcall(require, RS:WaitForChild("GameConfig"))
	local r = ok and G.AnimalRarity and G.AnimalRarity[name]
	if r then return r end
	return EggRoll and EggRoll.rarityOf(name) or "Common"
end

-- (Jacob, 11 Nov 2026: "the Dragon should be huge", like Throw Food for Animals) Placed size comes from the
-- rarity, not the model: each tier has a target size (cube root of the model's box volume, so a winged
-- dragon isn't judged by its wingspan), stepping up ~1.25x a tier: Common ~hamster to corgi, Secret 40-70
-- studs long. Inside a tier, bigger animals stay a bit bigger (x0.5 .. x1.6 around the tier's median).
-- Nothing gets longer than PLACED_CAP. Big ones can stick out past the fences, like in Throw Food.
C.TIER_SIZE = {Common = 4.5, Uncommon = 5.2, Rare = 6.5, Epic = 9, Legendary = 13, Mythic = 17, Exotic = 22,
	Divine = 27, Celestial = 33, Secret = 40, Admin = 13}
C.TIER_MEDIAN = {Common = 2.72, Uncommon = 2.85, Rare = 2.99, Epic = 5.36, Legendary = 11.19, Mythic = 5.47,
	Exotic = 8.28, Divine = 5.82, Celestial = 8.28, Secret = 13.03, Admin = 11.19}   -- the models' own sizes per tier
C.PLACED_CAP = 60

-- scale factor for a placed animal, and the radius it takes up on the Land
function C.placedScale(tmpl)
	local s = C.mesh(tmpl).Size
	local tier = rarityOf(tmpl)
	local gm = (s.X * s.Y * s.Z) ^ (1 / 3)
	local target = (C.TIER_SIZE[tier] or 4.5) * math.clamp((gm / (C.TIER_MEDIAN[tier] or gm)) ^ 0.6, 0.5, 1.6)
	local k = math.min(target / gm, C.PLACED_CAP / math.max(s.X, s.Y, s.Z))
	return k, 0.5 * math.max(s.X, s.Z) * k
end

-- scale factor for the animal held over your head
function C.heldScale(tmpl)
	local s = C.mesh(tmpl).Size
	return math.min(1, C.HELD_MAX / math.max(s.X, s.Y, s.Z))
end

-- scale factor for an egg (a single part) held over your head
function C.heldEggScale(part)
	local s = part.Size
	return math.min(1, C.HELD_EGG_MAX / math.max(s.X, s.Y, s.Z))
end

function C.land(plot)
	return plot and plot:FindFirstChild("Land")
end

-- (Jacob, 11 Nov 2026) you can place anywhere on your Land: animals may stand close together or overlap;
-- the only limit is how many your base holds (GameConfig.BaseSlots, checked by the callers).
-- spread = true (Equip Best's auto-placing) also keeps it fully on the Land and off other animals.
function C.canPlace(plot, pos, radius, spread)
	local land = C.land(plot)
	if not land then return false end
	local lp = land.CFrame:PointToObjectSpace(pos)
	local r = spread and radius * 0.9 or 0
	if math.abs(lp.X) + r > land.Size.X / 2 or math.abs(lp.Z) + r > land.Size.Z / 2 then return false end
	local f = spread and plot:FindFirstChild("Animals")
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
