-- All the game's numbers in one place (economy, rebirth, daily rewards, Robux products).
-- Used by ServerScriptService.GameServer / GameData and StarterPlayerScripts.HUDClient.
local G = {}

-- cash per second for each placed animal, by rarity (ReplicatedStorage.DevDemo.EggRoll.EggRarity)
G.Income = {Common = 5, Uncommon = 12, Rare = 30, Epic = 75, Legendary = 200, Mythic = 600, Secret = 2000, Admin = 8000}
G.Income.Exotic, G.Income.Divine, G.Income.Celestial = 900, 1300, 1700   -- the new tiers between Mythic and Secret

-- Luck (bought at the Egg Luck shop outside your base)
G.LuckPerLevel = 0.25
G.LuckMaxLevel = 20
function G.luckCost(level) return math.floor(500 * 1.8 ^ level) end

-- Rebirth: needs cash AND placed animals; only cash resets
function G.rebirthCash(r) return 25000 * 3 ^ r end
function G.rebirthAnimals(r) return 3 + 2 * r end
G.RebirthCashBonus = 0.5     -- +50% cash per rebirth
G.RebirthSpeed = 2           -- +2 walk speed per rebirth
G.RebirthLuck = 0.5          -- +0.5 luck per rebirth

-- Base upgrades (the sign behind each plot): land depth per level, and the price to reach the next one
G.BaseDepths = {42, 58, 74}
G.BaseUpgradeCost = {25000, 150000}   -- level 1 -> 2, level 2 -> 3

-- Deadlift barbells, in upgrade order (models in ServerStorage.Barbells). Power = XP per rep.
G.Barbells = {
	{Name = "Copper Barbell", Cost = 0, Power = 1},
	{Name = "Red Barbell", Cost = 250, Power = 2},
	{Name = "Crystal Barbell", Cost = 1000, Power = 4},
	{Name = "Rose Barbell", Cost = 3500, Power = 7},
	{Name = "Pumpkin Barbell", Cost = 10000, Power = 12},
	{Name = "Havenstar Barbell", Cost = 30000, Power = 20},
	{Name = "Neon Pulse", Cost = 80000, Power = 35},
	{Name = "Bone Barbell", Cost = 200000, Power = 60},
	{Name = "Donut Barbell", Cost = 500000, Power = 100},
	{Name = "Golden Barbell", Cost = 1.2e6, Power = 160},
	{Name = "Ice Barbell", Cost = 3e6, Power = 250},
	{Name = "Mega Golden Barbell", Cost = 7.5e6, Power = 400},
	{Name = "Giant Gold Star Barbell", Cost = 18e6, Power = 650},
	{Name = "Red Flyer", Cost = 45e6, Power = 1000},
	{Name = "Starfall Dumbbell", Cost = 110e6, Power = 1600},
	{Name = "Star Light Dumbbell", Cost = 270e6, Power = 2500},
}
G.RepSeconds = 2.1   -- one deadlift rep
-- Lift boost (the tap mini-game, StarterGui.HUD.LiftTapHUD): hitting a tap target makes your reps run this
-- much faster for a few seconds. The server takes one boost per LiftBoostMinGap at most.
G.LiftBoostSpeed, G.LiftBoostSeconds, G.LiftBoostMinGap = 1.75, 3.2, 1.0
-- Seconds of lifting done so far = real time since LiftStart + the extra banked by boosts.
-- Player attribute LiftBoost = Vector3(extra banked, boost start, boost end), times counted from LiftStart.
function G.LiftClock(player, now)
	local t = now - (player:GetAttribute("LiftStart") or now)
	local b = player:GetAttribute("LiftBoost")
	if typeof(b) == "Vector3" then t += b.X + (G.LiftBoostSpeed - 1) * math.clamp(t - b.Y, 0, math.max(0, b.Z - b.Y)) end
	return t
end
-- is this player's boost running now, and how many seconds are left
function G.LiftBoosted(player, now)
	local b = player:GetAttribute("LiftBoost")
	if typeof(b) ~= "Vector3" then return false, 0 end
	local t = now - (player:GetAttribute("LiftStart") or now)
	return t >= b.Y and t < b.Z, math.max(0, b.Z - t)
end

-- friends in the same server: +10% cash each, up to +50%
G.FriendBonus, G.FriendBonusMax = 0.1, 0.5

-- Index: claiming a found animal pays this many seconds of its income
G.IndexRewardSeconds = 100
-- Index sections (Jacob's IndexMenu has 4) and which rarities go in each
-- Every animal's rarity (Jacob, 11 Nov 2026): everyday animals Common, wild ones up the middle,
-- dinosaurs Legendary, myths Mythic and up. Admin = the Event tier. Overrides the pack's VFX_ tags.
G.AnimalRarity = {}
for tier, names in {
	Common = "Bunny Cat Chicken Cow Dog Duck Frog Goat Goldfish GuineaPig Hamster Horse Pigeon Pony Corgi Bull Beetle Snail Ladybug Toad Caterpillar",
	Uncommon = "Akita Angelfish Archerfish Badger Bat Beaver BichonFrise BostonTerrier Boxfish Butterflyfish Capybara CattleDog CavalierKingCharlesSpaniel ChowChow CoralGoby Cowfish Crab Dragonfly EnglishBulldog Gecko GreatDane Hawkfish Hedgehog Jellyfish Lizard Llama Maltese Meerkat Millipede MoorishIdol Moth Newt Owl Papillon Parrot Porcupine Pufferfish Puffin Quokka Raven2 Seahorse Seal ShibaInu Snake Surgeonfish Tortoise Toucan Trumpetfish Turtle Wrasse Centipede PrayingMantis Salamander",
	Rare = "Aardvark Albatross Anteater Armadillo Barracuda Binturong Caracal Cassowary Chameleon Cuttlefish Dingo Emu FennecFox Flamingo Fossa Giraffe Giraffe2 HoneyBadger Hyena Iguana Isopod Jackal Kangaroo Koala Kookaburra Lemur Lionfish Mandarinfish MantisShrimp Nautilus Octopus Ostrich Peafowl Platypus Sailfish SeaTurtle Secretary Serval Shoebill Sloth Stingray Swordfish Tapir_V1 Tapir_V2 Tuna Wobbegong Zebra Axolotl RedPanda Blobfish",
	Epic = "AmericanBison Anglerfish Bear Cobra Crocodile Elephant Fangtooth GiantSquid GoblinShark Gorilla GreatWhite GreenAnaconda Hippopotamus KomodoDragon Lion Moose Okapi PolarBear PolarBear2 SaltwaterCroc Shark Tiger Whale WhiteRhino Wolf Yak",
	Legendary = "Ankylosaurus Archaeopteryx Argentavis Azhdarchid BlueWhale Brachiosaurus Dimetrodon Gallimimus Mammoth Megalodon Microraptor Mosasaurus Plesiosaur Pteranodon Pterodactyl Quetzalcoatlus Sabertooth Spinosaurus Stegosaurus TRex Triceratops Velociraptor WoollyMammoth",
	Mythic = "Imp Gargoyle Jackalope Kappa Tanuki Harpy Stymphalian YiQi Bunyip Unicorn Pegasus Griffin",
	Exotic = "Kitsune Minotaur Manticore Chimera Hydra TripleCobra Lindworm Wyvern Roc Chupacabra Mothman Amphiptere",
	Divine = "Cerberus Fenrir Sphinx Phoenix SeaDragon GreenDragon",
	Celestial = "Caladrius Simurgh Raiju Thunderbird Qilin Garuda",
	Secret = "Dragon Kraken Leviathan KrakenKing",
	Admin = "",   -- Event: seasonal animals only (Christmas, Thanksgiving...); none yet
} do for _, n in string.split(names, " ") do if n ~= "" then G.AnimalRarity[n] = tier end end end
G.IndexSections = {
	{frame = "CommonSection", rarities = {"Common"}},
	{frame = "UncommonSection", rarities = {"Uncommon"}},
	{frame = "RareSection", rarities = {"Rare"}},
	{frame = "EpicSection", rarities = {"Epic"}},
	{frame = "LegendarySection", rarities = {"Legendary"}},
	{frame = "MythicSection", rarities = {"Mythic"}},
	{frame = "ExoticSection", rarities = {"Exotic"}},
	{frame = "DivineSection", rarities = {"Divine"}},
	{frame = "CelestialSection", rarities = {"Celestial"}},
	{frame = "SecretSection", rarities = {"Secret"}},
	{frame = "EventSection", rarities = {"Admin"}},
}
-- every animal goes in the index (A to Z inside each section), not just the ones eggs can roll yet
G.IndexAnimals = {}
do
	local base = script.Parent:FindFirstChild("BaseAnimals")
	for _, m in base and base:GetChildren() or {} do table.insert(G.IndexAnimals, m.Name) end
	table.sort(G.IndexAnimals)
end
-- the animals in the game right now (same as the penalty egg pool)
G.Animals = {"Chicken", "Giraffe", "Elephant", "Turtle", "TRex", "Blobfish"}

-- Daily rewards: day 1-7, then it loops. Miss more than 48 h and the streak resets.
G.Daily = {
	{Cash = 1000},
	{Cash = 2500},
	{Egg = "Giraffe"},
	{Cash = 10000},
	{Egg = "Elephant"},
	{Cash = 50000},
	{Egg = "Turtle"},
}

-- Codes (type them in the Codes menu). Each player can use each code once.
G.Codes = {
	RELEASE = {Cash = 5000},
	EGGS = {Egg = "Giraffe"},
}

-- Animal animations once they're published (Animation ids). Empty = use the KeyframeSequences in
-- Studio (ServerStorage.RBX_ANIMSAVES, copied by the penalty demo); in a live game they need real ids.
G.AnimalAnims = {
	-- Chicken = {Idle = "rbxassetid://...", Walk = "rbxassetid://..."},
}

-- Rare hatches announced to the whole server
G.AnnounceFrom = "Legendary"

-- ROBUX: put the real ids in once they're made on the Creator Dashboard (0 = not set up yet).
-- Passes are game passes; everything else is a developer product.
-- Gift = a second developer product, bought for another player.
G.Passes = {
	VIP = {Id = 0, GiftId = 0},          -- $1M cash once, 2x cash, a free egg
	Cash2x = {Id = 0, GiftId = 0},
	Luck2x = {Id = 0, GiftId = 0},
}
G.Products = {
	Pack10M = {Id = 0, GiftId = 0, Cash = 10e6},
	Pack100M = {Id = 0, GiftId = 0, Cash = 100e6},
	EggTRex = {Id = 0, GiftId = 0, Egg = "TRex"},
	EggElephant = {Id = 0, GiftId = 0, Egg = "Elephant"},
	EggTurtle = {Id = 0, GiftId = 0, Egg = "Turtle"},
	LuckyPack = {Id = 0, LuckyEgg = true},   -- a random egg rolled with x10 luck
	SkipRebirth = {Id = 0, Skip = true},
}
G.VIPCash, G.VIPEgg = 1e6, "Turtle"

-- which shop / HUD frame sells what (frame name in Jacob's UI -> pass or product)
G.ShopItems = {
	VIPPack = {Pass = "VIP"},
	Boost2xCash = {Pass = "Cash2x"},
	Boost2xStrength = {Pass = "Luck2x", Title = "2x Luck"},
	Pack10M = {Product = "Pack10M"},
	Pack100M = {Product = "Pack100M"},
	EasterEgg = {Product = "EggTRex", Title = "T-Rex Egg"},
	ChickenEgg = {Product = "EggElephant", Title = "Elephant Egg"},
	BabyEgg = {Product = "EggTurtle", Title = "Turtle Egg"},
	Boost2xCashButton = {Pass = "Cash2x"},
	Boost2xLuckButton = {Pass = "Luck2x"},
	LuckyPack = {Product = "LuckyPack"},
}

-- $1,234 / $12.5K / $3.2M ...
local SUFFIX = {"", "K", "M", "B", "T", "Qa", "Qi"}
function G.short(n)
	n = math.floor(n)
	if n < 1000 then return tostring(n) end
	local i = 1
	while n >= 1000 and i < #SUFFIX do n /= 1000; i += 1 end
	local s = n >= 100 and string.format("%d", n) or string.format("%.1f", n):gsub("%.0$", "")
	return s .. SUFFIX[i]
end
function G.commas(n)
	local s = tostring(math.floor(n))
	local out = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return (out:gsub("^,", ""))
end

-- Lifting levels: each rep gives XP = the barbell's Power; every level up gives StrengthPerLevel Strength.
G.StrengthPerLevel = 5
function G.LiftXP(level)   -- XP needed to go from this level to the next
	return math.floor(10 * level ^ 1.25)
end

------------------------------------------------------------------ the backbone: luck, strength, ball speed (Jacob, 11 Nov 2026)
-- Every animal from most common to rarest: by tier, then smallest to biggest inside a tier.
G.AnimalOrder = string.split("Hamster Frog Duck Beetle Toad Ladybug Goldfish Chicken Pigeon Snail Bunny Cat GuineaPig Goat Horse Dog Pony Cow Bull Corgi Caterpillar Seahorse Trumpetfish Puffin Toucan Raven2 Crab Owl BichonFrise Cowfish CoralGoby Boxfish Angelfish Lizard GreatDane Pufferfish Turtle MoorishIdol EnglishBulldog CattleDog Archerfish Akita BostonTerrier Bat Hawkfish CavalierKingCharlesSpaniel Jellyfish Maltese Parrot Badger ChowChow Wrasse Capybara Surgeonfish Quokka Butterflyfish Papillon Beaver Hedgehog Tortoise Moth Llama Millipede Newt Dragonfly Gecko Snake Seal ShibaInu Porcupine Meerkat Centipede Salamander PrayingMantis Flamingo Isopod Octopus Kookaburra Albatross Nautilus Barracuda Emu Cassowary Cuttlefish Blobfish Koala Jackal Shoebill Dingo Serval Hyena Stingray HoneyBadger Lionfish Secretary Tuna Fossa Caracal Ostrich Aardvark Binturong Armadillo Mandarinfish Sloth Anteater Wobbegong Iguana Sailfish Platypus Kangaroo Zebra Tapir_V2 Tapir_V1 FennecFox MantisShrimp Peafowl Lemur SeaTurtle Giraffe Swordfish Chameleon Giraffe2 RedPanda Axolotl Fangtooth GoblinShark Anglerfish Okapi Wolf Yak GreenAnaconda KomodoDragon PolarBear2 Tiger Hippopotamus WhiteRhino Crocodile Shark SaltwaterCroc Gorilla Lion PolarBear Bear Cobra AmericanBison Whale Elephant Moose GreatWhite GiantSquid WoollyMammoth Sabertooth Archaeopteryx Argentavis Stegosaurus Mammoth Dimetrodon Ankylosaurus Megalodon Triceratops Mosasaurus Gallimimus TRex Spinosaurus Brachiosaurus Pteranodon Quetzalcoatlus Microraptor BlueWhale Velociraptor Azhdarchid Pterodactyl Plesiosaur Tanuki Jackalope Kappa Unicorn Bunyip YiQi Gargoyle Imp Stymphalian Harpy Pegasus Griffin Minotaur Lindworm Chupacabra Mothman Kitsune Roc Chimera TripleCobra Manticore Hydra Amphiptere Wyvern SeaDragon Fenrir Sphinx Cerberus Phoenix GreenDragon Raiju Garuda Thunderbird Caladrius Simurgh Qilin Leviathan KrakenKing Kraken Dragon", " ")
-- egg models whose name differs from their animal
G.EggAlias = {Bichon = "BichonFrise", Bulldog = "EnglishBulldog", Cavalier = "CavalierKingCharlesSpaniel", GreatWhiteShark = "GreatWhite",
	SaltwaterCrocodile = "SaltwaterCroc", Seadragon = "SeaDragon", Tapir = "Tapir_V1", Terrier = "BostonTerrier"}
function G.AnimalForEgg(egg) return G.EggAlias[egg] or egg end
-- the eggs you can roll (ServerStorage.BaseEggs that have an animal)
G.EggPool = string.split("Aardvark Akita Albatross AmericanBison Amphiptere Anglerfish Ankylosaurus Anteater Archaeopteryx Argentavis Armadillo Axolotl Azhdarchid Badger Bat Bear Beaver Beetle Bichon Binturong Blobfish BlueWhale Brachiosaurus Bull Bulldog Bunny Bunyip Caladrius Capybara Caracal Cassowary Cat Caterpillar CattleDog Cavalier Centipede Cerberus Chameleon Chicken Chimera ChowChow Chupacabra Cobra Corgi Cow Crab Crocodile Cuttlefish Dimetrodon Dingo Dog Dragon Dragonfly Duck Elephant Emu Fangtooth FennecFox Fenrir Flamingo Fossa Frog Gallimimus Gargoyle Garuda Gecko GiantSquid Giraffe Goat GoblinShark Goldfish Gorilla GreatDane GreatWhiteShark GreenAnaconda GreenDragon Griffin GuineaPig Hamster Hedgehog Hippopotamus HoneyBadger Horse Hydra Hyena Iguana Imp Isopod Jackal Jackalope Jellyfish Kangaroo Kappa Kitsune Koala KomodoDragon Kookaburra Kraken KrakenKing Ladybug Lemur Leviathan Lindworm Lion Lizard Llama Maltese Mammoth Manticore MantisShrimp Meerkat Megalodon Microraptor Millipede Minotaur Moose Mosasaurus Moth Mothman Nautilus Newt Octopus Okapi Ostrich Owl Papillon Parrot Peafowl Pegasus Phoenix Pigeon Platypus Plesiosaur PolarBear Pony Porcupine PrayingMantis Pteranodon Pterodactyl Puffin Qilin Quetzalcoatlus Quokka Raiju RedPanda Roc Sabertooth Salamander SaltwaterCrocodile SeaTurtle Seadragon Seal Secretary Serval Shark ShibaInu Shoebill Simurgh Sloth Snail Snake Sphinx Spinosaurus Stegosaurus Stymphalian Swordfish TRex Tanuki Tapir Terrier Thunderbird Tiger Toad Tortoise Toucan Triceratops TripleCobra Turtle Unicorn Velociraptor Whale WhiteRhino Wolf WoollyMammoth Wyvern Yak YiQi Zebra", " ")
local RANK = {}
for i, n in G.AnimalOrder do RANK[n] = i end
function G.rankOf(name) return RANK[G.AnimalForEgg(name)] or 1 end

-- Strength: you start at 10. Each animal's egg needs StrengthFor(name) to score on it,
-- from 10 for the most common to 18,700 for the rarest Secret (exponential along the ranks).
-- Kick strength = Strength x timing (ZoneStrength) x aim (AimZones). The top egg needs 18,700:
-- ~15K Strength with a Perfect kick, or 10K with a Perfect kick into the green zone.
G.StartStrength = 10
G.TopStrength = 18700
function G.StrengthFor(name)
	local p = (G.rankOf(name) - 1) / math.max(1, #G.AnimalOrder - 1)
	local s = G.StartStrength * (G.TopStrength / G.StartStrength) ^ p
	if s < 100 then return math.floor(s + 0.5) end
	local step = s < 1000 and 5 or s < 10000 and 50 or 100
	return math.floor(s / step + 0.5) * step
end
-- the timing bar scales your strength for that kick: Perfect, Great, Good, Weak, Miss
G.ZoneStrength = {1.25, 1.1, 1, 0.7, 0.4}

-- Aim zones (Jacob, 11 Nov 2026): every shot the goal gets one green zone (your strength counts x1.5)
-- and red zones (x0.5). Each animal has a habit: its green spot is always near the same place but
-- shifts a little every shot. Rarer eggs: smaller green, bigger and more red, bigger shifts.
-- Zones are in goal studs, the same space as the aim: x = -9.2 (left) .. 9.2 (right), y = 0.7 (ground) .. 8.5 (bar).
-- AimZones(egg, seed) -> { {kind = "green"|"red", x, y, r}, ... }. The server sends the seed (RollEgg).
G.AimGreen, G.AimRed = 1.5, 0.5
G.AimX, G.AimYLow, G.AimYHigh = 9.2, 0.7, 8.5
local TIER_N = {Common = 1, Uncommon = 2, Rare = 3, Epic = 4, Legendary = 5, Mythic = 6, Exotic = 7, Divine = 8, Celestial = 9, Secret = 10, Admin = 5}
local function hash(s) local h = 5381 for i = 1, #s do h = (h * 33 + s:byte(i)) % 2147483647 end return h end
function G.AimZones(egg, seed)
	local a = G.AnimalForEgg(egg)
	local t = TIER_N[G.AnimalRarity[a]] or 1
	local habit = Random.new(hash(a))                  -- same every time for this animal
	local rng = Random.new(seed or 0)                  -- different every shot
	local X, Y0, Y1 = G.AimX, G.AimYLow, G.AimYHigh
	local shift = 1.5 + 0.5 * t
	local function place(hx, hy, r)
		return math.clamp(hx + rng:NextNumber(-shift, shift), -X + r * 0.5, X - r * 0.5),
			math.clamp(hy + rng:NextNumber(-shift, shift) * 0.6, Y0 + r * 0.4, Y1 - r * 0.4)
	end
	local gr = 3 - 0.19 * (t - 1)                     -- Common 3 studs .. Secret 1.3
	local gx, gy = place(habit:NextNumber(-7, 7), habit:NextNumber(2, 7.5), gr)
	local zones = {{kind = "green", x = gx, y = gy, r = gr}}
	local rr = 2.2 + 0.2 * (t - 1)                    -- Common 2.2 .. Secret 4
	local reds = t <= 3 and 1 or t <= 6 and 2 or 3
	for i = 1, reds do
		local hx, hy = habit:NextNumber(-7, 7), habit:NextNumber(2, 7.5)
		for _ = 1, 40 do
			local x, y = place(hx, hy, rr)
			local ok = math.sqrt((x - gx) ^ 2 + (y - gy) ^ 2) >= gr + rr + 0.5
			for _, z in zones do if z.kind == "red" and math.sqrt((x - z.x) ^ 2 + (y - z.y) ^ 2) < rr then ok = false end end
			if ok then table.insert(zones, {kind = "red", x = x, y = y, r = rr}); break end
			hx, hy = rng:NextNumber(-X, X), rng:NextNumber(Y0, Y1)   -- no room near its habit: anywhere
		end
	end
	return zones
end
-- how much the aim spot counts: green 1.5, red 0.5, anywhere else 1
function G.aimMult(zones, x, y)
	local m = 1
	for _, z in zones do
		if (x - z.x) ^ 2 + (y - z.y) ^ 2 <= z.r ^ 2 then
			if z.kind == "green" then return G.AimGreen end
			m = G.AimRed
		end
	end
	return m
end
-- Ball: little lob at 10 strength, a bullet at the top. t = 0..1 along the strength scale.
G.BallSlow, G.BallFast = 22, 230          -- studs per second
G.BallArcSlow, G.BallArcFast = 7, 0.3     -- studs of arc
function G.strengthT(s) return math.clamp(math.log(math.max(s, 1) / G.StartStrength) / math.log(G.TopStrength / G.StartStrength), 0, 1) end
function G.ballSpeed(s) return G.BallSlow * (G.BallFast / G.BallSlow) ^ G.strengthT(s) end
function G.ballArc(s) local t = G.strengthT(s) return G.BallArcSlow + (G.BallArcFast - G.BallArcSlow) * t end

-- Mutations (Jacob, 11 Nov 2026): any rolled egg can come out mutated. A Gold egg hatches a Gold animal
-- (models: ReplicatedStorage.Assets.Eggs.<M>Eggs / Assets.Animals.<M>Animals, same names as the base ones).
-- Chance = 1 in N per roll. Income = cash/s and sell price multiplier. Need = how much more Strength the egg takes.
-- Inverted is event-only (Chance 0) until an event turns it on (Jacob: every other mutation rolls).
G.Mutations = {
	{Name = "Gold", Chance = 20, Income = 2, Need = 1.25, Color = Color3.fromRGB(255, 205, 40)},
	{Name = "Diamond", Chance = 100, Income = 3, Need = 1.5, Color = Color3.fromRGB(110, 220, 255)},
	{Name = "Rainbow", Chance = 500, Income = 5, Need = 2, Color = nil},   -- nil = rainbow text
	{Name = "Inverted", Chance = 0, Income = 4, Need = 1.75, Color = Color3.fromRGB(200, 200, 200)},
	{Name = "Hacked", Chance = 2000, Income = 8, Need = 2.5, Color = Color3.fromRGB(80, 255, 80)},
}
G.MutationInfo = {}
for _, m in G.Mutations do G.MutationInfo[m.Name] = m end
-- the server rolls this once per egg (rarest first); returns a mutation name or nil
function G.rollMutation(rng)
	local r = rng and rng:NextNumber() or math.random()
	local acc = 0
	for i = #G.Mutations, 1, -1 do
		local m = G.Mutations[i]
		if m.Chance > 0 then
			acc += 1 / m.Chance
			if r < acc then return m.Name end
		end
	end
	return nil
end
function G.mutIncome(mut) local m = mut and G.MutationInfo[mut] return m and m.Income or 1 end
function G.mutNeed(mut) local m = mut and G.MutationInfo[mut] return m and m.Need or 1 end
function G.mutChance(mut) local m = mut and G.MutationInfo[mut] return m and m.Chance or 1 end
function G.mutLabel(mut, text) return mut and (mut .. " " .. text) or text end
-- the egg / animal model for a mutation (nil = the base one)
function G.mutEggModel(name, mut)
	local f = mut and game:GetService("ReplicatedStorage"):FindFirstChild("Assets")
	f = f and f:FindFirstChild("Eggs") and f.Eggs:FindFirstChild(mut .. "Eggs")
	return f and f:FindFirstChild(name)
end
-- the mutation's aura (ReplicatedStorage.Assets.VFX.Mutations.<mut>) on a part: its emitters fill the part,
-- its Attachment sits in the middle. Safe to call twice.
function G.addMutationVFX(part, mut)
	if not (mut and part and part:IsA("BasePart")) or part:GetAttribute("MutVFX") == mut then return end
	local v = game:GetService("ReplicatedStorage"):FindFirstChild("Assets")
	v = v and v:FindFirstChild("VFX") and v.VFX:FindFirstChild("Mutations") and v.VFX.Mutations:FindFirstChild(mut)
	if not v then return end
	for _, c in v:GetChildren() do
		local k = c:Clone()
		k:SetAttribute("MutVFXPart", true)
		k.Parent = part
	end
	part:SetAttribute("MutVFX", mut)
end
function G.mutAnimalModel(name, mut)
	local f = mut and game:GetService("ReplicatedStorage"):FindFirstChild("Assets")
	f = f and f:FindFirstChild("Animals") and f.Animals:FindFirstChild(mut .. "Animals")
	return f and f:FindFirstChild(name)
end

-- Selling an animal from your inventory at Workspace.SellShop pays this many seconds of its income
-- (Common $5/s -> $300 ... Secret $2,000/s -> $120K), times its mutation.
G.SellSeconds = 60
function G.SellValue(name, mut) return (G.Income[G.AnimalRarity[name] or "Common"] or 0) * G.SellSeconds * G.mutIncome(mut) end

-- The "1/N" shown for each egg is a set number per animal (Jacob, 11 Nov 2026): it never changes with luck.
-- 1/2 for the most common, up to 1/10,000,000 for the rarest, rounded to 2 digits.
G.OddsTop = 10000000
function G.EggOdds(name)
	local p = (G.rankOf(name) - 1) / math.max(1, #G.AnimalOrder - 1)
	local n = 2 * (G.OddsTop / 2) ^ p
	if n < 10 then return math.floor(n + 0.5) end
	local mag = 10 ^ (math.floor(math.log10(n)) - 1)
	return math.floor(n / mag + 0.5) * mag
end

-- Luck slides the egg roll up the ranks: at luck 1 you get the most common animals; as luck grows
-- the window moves to rarer commons, then uncommons, rares and so on. LuckTop = the luck that centres
-- the roll on the rarest animal.
G.LuckTop = 150     -- luck 1.25 (first shop level) ~ rank 10, luck 6 (shop maxed) ~ rank 77, 150 = the rarest
G.LuckBelow, G.LuckAbove = 14, 3.5        -- how far the roll spreads below / above the centre (in ranks)
function G.rollCentre(luck) return 1 + (#G.AnimalOrder - 1) * math.clamp(math.log(math.max(luck, 1)) / math.log(G.LuckTop), 0, 1) end
function G.rollWeight(name, luck)
	local d = G.rankOf(name) - G.rollCentre(luck)
	return d <= 0 and math.exp(d / G.LuckBelow) or math.exp(-d / G.LuckAbove)
end

return G
