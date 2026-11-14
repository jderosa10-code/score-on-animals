-- All the game's numbers in one place (economy, rebirth, daily rewards, Robux products).
-- Used by ServerScriptService.GameServer / GameData and StarterPlayerScripts.HUDClient.
local G = {}

-- OLD flat cash per second by rarity. Not used for income any more: every animal now has its own income,
-- G.AnimalIncome(name) further down ($5/s Hamster .. $100T/s Dragon, Jacob 11 Nov 2026).
G.Income = {Common = 5, Uncommon = 12, Rare = 30, Epic = 75, Legendary = 200, Mythic = 600, Secret = 2000, Admin = 8000}
G.Income.Exotic, G.Income.Divine, G.Income.Celestial = 900, 1300, 1700   -- the new tiers between Mythic and Secret

-- Luck (bought at the Egg Luck shop outside your base)
-- (Jacob, 11 Nov 2026) Luck multiplies each level, so the maxed shop reaches the best animals:
-- level 0 = x1 (Commons) .. level 40 = x150 (rolls centred on the Dragon). Each level is about x1.13.
-- Strength still decides whether you can score on the egg you roll.
G.LuckMaxLevel = 40
function G.luckAt(level) return G.LuckTop ^ (math.clamp(level, 0, G.LuckMaxLevel) / G.LuckMaxLevel) end
-- price of the next level: the income of the animals your luck is rolling now (the centre rank) times
-- 100 s at the start, growing to 20,000 s for the last level
local LUCK_COST = {}
function G.luckCost(level)
	if level == 0 then return 0 end   -- (Jacob, 11 Nov 2026) the first Egg Luck level is free
	if LUCK_COST[level] then return LUCK_COST[level] end
	local inc = G.IncomeAtRank(G.rollCentre(G.luckAt(level)))
	local n = inc * 100 * 200 ^ (math.clamp(level, 0, G.LuckMaxLevel - 1) / (G.LuckMaxLevel - 1))
	local mag = n >= 100 and 10 ^ (math.floor(math.log10(n)) - 1) or 1
	LUCK_COST[level] = math.floor(n / mag + 0.5) * mag
	return LUCK_COST[level]
end

-- Rebirth: needs cash AND placed animals; only cash resets
function G.rebirthCash(r) return 25000 * 3 ^ r end
function G.rebirthAnimals(r) return 3 + 2 * r end
G.RebirthCashBonus = 0.5     -- +50% cash per rebirth
G.BaseWalkSpeed = 24         -- (pigeon, 11 Nov 2026) everyone walks faster than Roblox's 16
G.RebirthSpeed = 2           -- +2 walk speed per rebirth
G.RebirthLuck = 0.5          -- +0.5 luck per rebirth

-- Base upgrades (the sign behind each plot): land depth per level, and the price to reach the next one
G.BaseDepths = {42, 58, 74}   -- land depth for levels 0, 1, 2 (the lobby's back wall stops it there)
-- (Jacob, 11 Nov 2026) how many animals your base holds: 10, then +2 per upgrade (10, 12, 14).
-- An upgrade only exists if it makes the plot bigger, so there are 2.
G.BaseMaxLevel = #G.BaseDepths - 1
function G.BaseSlots(level) return 10 + 2 * math.clamp(level or 0, 0, G.BaseMaxLevel) end
-- price to go from level k-1 to k: ~3,000 s of income of the animal 1/4 and 1/2 of the way up the ranks
G.BaseUpgradeCost = {32e6, 67e9}

-- Deadlift barbells, in upgrade order (models in ServerStorage.Barbells). Power = XP per rep.
-- Order (pigeon, 11 Nov 2026): plain -> silly (Donut, Bone, Pumpkin, Rose) -> precious (Golden, Ice, Crystal) -> glowing -> legendary.
-- Only the names moved: every slot kept its Cost and Power. Effects: ServerStorage.BarbellVFXKit.
-- Costs scaled with the per-animal income (Jacob, 11 Nov 2026): barbell k is bought with the animals
-- about k/16 of the way up the ranks, and costs about as many seconds of their income as before.
G.Barbells = {
	{Name = "Copper Barbell", Cost = 0, Power = 1},
	{Name = "Red Barbell", Cost = 1700, Power = 2},
	{Name = "Donut Barbell", Cost = 21e3, Power = 4},
	{Name = "Bone Barbell", Cost = 470e3, Power = 7},
	{Name = "Pumpkin Barbell", Cost = 9.2e6, Power = 12},
	{Name = "Rose Barbell", Cost = 170e6, Power = 20},
	{Name = "Golden Barbell", Cost = 1.4e9, Power = 35},
	{Name = "Ice Barbell", Cost = 23e9, Power = 60},
	{Name = "Crystal Barbell", Cost = 370e9, Power = 100},
	{Name = "Neon Pulse", Cost = 6e12, Power = 160},
	{Name = "Havenstar Barbell", Cost = 44e12, Power = 250},
	{Name = "Mega Golden Barbell", Cost = 720e12, Power = 400},
	{Name = "Giant Gold Star Barbell", Cost = 4.2e15, Power = 650},
	{Name = "Red Flyer", Cost = 70e15, Power = 1000},
	{Name = "Starfall Dumbbell", Cost = 280e15, Power = 1600},
	{Name = "Star Light Dumbbell", Cost = 3.1e18, Power = 2500},
}
G.RepSeconds = 2.1   -- one deadlift rep (at LiftSpeed 1)
G.LiftSpeed = 1.35   -- (Jacob, 11 Nov 2026) lifting runs this much faster: a rep every ~1.55 s; the animation speeds up with it
-- Lift boost (the tap mini-game, StarterGui.HUD.LiftTapHUD): hitting a tap target makes your reps run this
-- much faster for a few seconds. The server takes one boost per LiftBoostMinGap at most.
G.LiftBoostSpeed, G.LiftBoostSeconds, G.LiftBoostMinGap = 1.75, 3.2, 1.0
-- Seconds of lifting done so far = real time since LiftStart + the extra banked by boosts.
-- Player attribute LiftBoost = Vector3(extra banked, boost start, boost end), times counted from LiftStart.
function G.LiftClock(player, now)
	local t = now - (player:GetAttribute("LiftStart") or now)
	local b = player:GetAttribute("LiftBoost")
	if typeof(b) == "Vector3" then t += b.X + (G.LiftBoostSpeed - 1) * math.clamp(t - b.Y, 0, math.max(0, b.Z - b.Y)) end
	return t * G.LiftSpeed
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
	-- (Jacob, 11 Nov 2026) the two in the game description
	FREEEGG = {Egg = "Axolotl"},                 -- a Rare egg
	STRONG = {Cash = 25000, Strength = 100},     -- $25K and +100 Strength
}

-- Animal animations once they're published (Animation ids). Empty = use the KeyframeSequences in
-- Studio (ServerStorage.RBX_ANIMSAVES, copied by the penalty demo); in a live game they need real ids.
-- Published 2026-11-11 (pigeon-claude): group-owned Idle/Walk for every animal (fish and snakes have no Walk).
G.AnimalAnims = {
	Aardvark = {Idle = "rbxassetid://128877123107924", Walk = "rbxassetid://94996569738697"},
	Akita = {Idle = "rbxassetid://100941280509253", Walk = "rbxassetid://73320849097468"},
	Albatross = {Idle = "rbxassetid://111427098497820", Walk = "rbxassetid://101126722435903"},
	AmericanBison = {Idle = "rbxassetid://123404494713796", Walk = "rbxassetid://72850218241356"},
	Amphiptere = {Idle = "rbxassetid://102070591745309"},
	Angelfish = {Idle = "rbxassetid://130149619739091"},
	Anglerfish = {Idle = "rbxassetid://107366080303712"},
	Ankylosaurus = {Idle = "rbxassetid://89899218152531", Walk = "rbxassetid://136962326742479"},
	Anteater = {Idle = "rbxassetid://91259023160425", Walk = "rbxassetid://87241113211709"},
	Archaeopteryx = {Idle = "rbxassetid://133684152667412", Walk = "rbxassetid://129932106033614"},
	Archerfish = {Idle = "rbxassetid://74698149209343"},
	Argentavis = {Idle = "rbxassetid://130567696814057", Walk = "rbxassetid://107278801369504"},
	Armadillo = {Idle = "rbxassetid://74251511405514", Walk = "rbxassetid://109884030435576"},
	Axolotl = {Idle = "rbxassetid://88161477590263", Walk = "rbxassetid://112089589259953"},
	Azhdarchid = {Idle = "rbxassetid://79050571362367", Walk = "rbxassetid://72808349767196"},
	Badger = {Idle = "rbxassetid://127128722544453", Walk = "rbxassetid://103450031259832"},
	Barracuda = {Idle = "rbxassetid://111675553355451"},
	Bat = {Idle = "rbxassetid://106771512976382", Walk = "rbxassetid://138892736935225"},
	Bear = {Idle = "rbxassetid://124995358577131", Walk = "rbxassetid://128670828196524"},
	Beaver = {Idle = "rbxassetid://109909801736317", Walk = "rbxassetid://133271424992773"},
	Beetle = {Idle = "rbxassetid://126258629807379", Walk = "rbxassetid://115899022968660"},
	BichonFrise = {Idle = "rbxassetid://96525032443368", Walk = "rbxassetid://80921155603815"},
	Binturong = {Idle = "rbxassetid://131436444592681", Walk = "rbxassetid://117779294007933"},
	Blobfish = {Idle = "rbxassetid://104021390381521"},
	BlueWhale = {Idle = "rbxassetid://80206407591123"},
	BostonTerrier = {Idle = "rbxassetid://90826456851760", Walk = "rbxassetid://90919117354477"},
	Boxfish = {Idle = "rbxassetid://131247213558041"},
	Brachiosaurus = {Idle = "rbxassetid://71375093536105", Walk = "rbxassetid://79723712710375"},
	Bull = {Idle = "rbxassetid://104287722123812", Walk = "rbxassetid://83323694776830"},
	Bunny = {Idle = "rbxassetid://97282842076877", Walk = "rbxassetid://101405257457064"},
	Bunyip = {Idle = "rbxassetid://126348012224702", Walk = "rbxassetid://76203064867983"},
	Butterflyfish = {Idle = "rbxassetid://76027481209004"},
	Caladrius = {Idle = "rbxassetid://129732131316208", Walk = "rbxassetid://131023197927285"},
	Capybara = {Idle = "rbxassetid://112003669613245", Walk = "rbxassetid://131464170087392"},
	Caracal = {Idle = "rbxassetid://115003362548224", Walk = "rbxassetid://75009087792511"},
	Cassowary = {Idle = "rbxassetid://123144346513679", Walk = "rbxassetid://108679577568795"},
	Cat = {Idle = "rbxassetid://129192160111271", Walk = "rbxassetid://93434902822266"},
	Caterpillar = {Idle = "rbxassetid://78064435864908", Walk = "rbxassetid://96698909649737"},
	CattleDog = {Idle = "rbxassetid://85206534218996", Walk = "rbxassetid://122516576610276"},
	CavalierKingCharlesSpaniel = {Idle = "rbxassetid://135122603401427", Walk = "rbxassetid://123170746601975"},
	Centipede = {Idle = "rbxassetid://93544940958094", Walk = "rbxassetid://111914892208951"},
	Cerberus = {Idle = "rbxassetid://132914701298951", Walk = "rbxassetid://95462720005723"},
	Chameleon = {Idle = "rbxassetid://106168685976902", Walk = "rbxassetid://90178071786856"},
	Chicken = {Idle = "rbxassetid://76199447126062", Walk = "rbxassetid://133945020843745"},
	Chimera = {Idle = "rbxassetid://130741323247048", Walk = "rbxassetid://106966504906833"},
	ChowChow = {Idle = "rbxassetid://132435288567550", Walk = "rbxassetid://105740877201694"},
	Chupacabra = {Idle = "rbxassetid://89964240022590", Walk = "rbxassetid://126409363363901"},
	Cobra = {Idle = "rbxassetid://90555346602215"},
	CoralGoby = {Idle = "rbxassetid://87699080485333"},
	Corgi = {Idle = "rbxassetid://95980200561059", Walk = "rbxassetid://116261223115683"},
	Cow = {Idle = "rbxassetid://121175134448738", Walk = "rbxassetid://108236947859941"},
	Cowfish = {Idle = "rbxassetid://99624504845668"},
	Crab = {Idle = "rbxassetid://74528208195574", Walk = "rbxassetid://90657627171376"},
	Crocodile = {Idle = "rbxassetid://89466449517376", Walk = "rbxassetid://139765228406565"},
	Cuttlefish = {Idle = "rbxassetid://100648137117321"},
	Dimetrodon = {Idle = "rbxassetid://71560671920739", Walk = "rbxassetid://131864461311102"},
	Dingo = {Idle = "rbxassetid://119885947633189", Walk = "rbxassetid://84324537056538"},
	Dog = {Idle = "rbxassetid://81801156475422", Walk = "rbxassetid://123598021496887"},
	Dragon = {Idle = "rbxassetid://75548764615582", Walk = "rbxassetid://99730056951391"},
	Dragonfly = {Idle = "rbxassetid://83619494085872"},
	Duck = {Idle = "rbxassetid://110988405940282", Walk = "rbxassetid://126580145315047"},
	Elephant = {Idle = "rbxassetid://116696364185602", Walk = "rbxassetid://103634194706251"},
	Emu = {Idle = "rbxassetid://101105594233929", Walk = "rbxassetid://108887578052395"},
	EnglishBulldog = {Idle = "rbxassetid://102013734544735", Walk = "rbxassetid://102861256206086"},
	Fangtooth = {Idle = "rbxassetid://114186977379105"},
	FennecFox = {Idle = "rbxassetid://85692170726056", Walk = "rbxassetid://132450772348241"},
	Fenrir = {Idle = "rbxassetid://99063142192402", Walk = "rbxassetid://110810367410487"},
	Flamingo = {Idle = "rbxassetid://117927893279871", Walk = "rbxassetid://85843771104304"},
	Fossa = {Idle = "rbxassetid://99294128850536", Walk = "rbxassetid://84737614684438"},
	Frog = {Idle = "rbxassetid://111172415253671", Walk = "rbxassetid://120447579733187"},
	Gallimimus = {Idle = "rbxassetid://91927810885351", Walk = "rbxassetid://127773324433220"},
	Gargoyle = {Idle = "rbxassetid://76815485888305", Walk = "rbxassetid://137110871667716"},
	Garuda = {Idle = "rbxassetid://122621830147500", Walk = "rbxassetid://100441225769165"},
	Gecko = {Idle = "rbxassetid://140528767877342", Walk = "rbxassetid://119747917221675"},
	GiantSquid = {Idle = "rbxassetid://91376939615640"},
	Giraffe = {Idle = "rbxassetid://113660118618802", Walk = "rbxassetid://81139792642924"},   -- v3: head turns on the top of the neck (pose positions stored x100: the Animator scales them by the model's 0.01 scale)
	Giraffe2 = {Idle = "rbxassetid://102240811978890", Walk = "rbxassetid://75890265327644"},
	Goat = {Idle = "rbxassetid://83396649946181", Walk = "rbxassetid://90926853125842"},
	GoblinShark = {Idle = "rbxassetid://120821664904125"},
	Goldfish = {Idle = "rbxassetid://97346712717411"},
	Gorilla = {Idle = "rbxassetid://107489904372089", Walk = "rbxassetid://138055474899811"},
	GreatDane = {Idle = "rbxassetid://118265180650207", Walk = "rbxassetid://137886917359834"},
	GreatWhite = {Idle = "rbxassetid://108297213243722"},
	GreenAnaconda = {Idle = "rbxassetid://106604401392554"},
	GreenDragon = {Idle = "rbxassetid://84708278947627", Walk = "rbxassetid://82408577415250"},
	Griffin = {Idle = "rbxassetid://74812051358980", Walk = "rbxassetid://81613208972350"},
	GuineaPig = {Idle = "rbxassetid://137808982145899", Walk = "rbxassetid://88607202504109"},
	Hamster = {Idle = "rbxassetid://104448805747512", Walk = "rbxassetid://137979185179319"},
	Harpy = {Idle = "rbxassetid://77694978053326", Walk = "rbxassetid://136466414963036"},
	Hawkfish = {Idle = "rbxassetid://137444771258096"},
	Hedgehog = {Idle = "rbxassetid://111519577040265", Walk = "rbxassetid://92949826394934"},
	Hippopotamus = {Idle = "rbxassetid://127737151311103", Walk = "rbxassetid://139750676554067"},
	HoneyBadger = {Idle = "rbxassetid://130797922979165", Walk = "rbxassetid://137231900166783"},
	Horse = {Idle = "rbxassetid://107311090419863", Walk = "rbxassetid://91043855467189"},
	Hydra = {Idle = "rbxassetid://116561239758338"},
	Hyena = {Idle = "rbxassetid://97678098488785", Walk = "rbxassetid://137194881067702"},
	Iguana = {Idle = "rbxassetid://102114975502549", Walk = "rbxassetid://129415738667754"},
	Imp = {Idle = "rbxassetid://139509829842775", Walk = "rbxassetid://123981772335461"},
	Isopod = {Idle = "rbxassetid://105153199224637", Walk = "rbxassetid://78803818232521"},
	Jackal = {Idle = "rbxassetid://102643717204914", Walk = "rbxassetid://96931862842939"},
	Jackalope = {Idle = "rbxassetid://76152932873530", Walk = "rbxassetid://130874930887173"},
	Jellyfish = {Idle = "rbxassetid://137085207965856"},
	Kangaroo = {Idle = "rbxassetid://95719834594883", Walk = "rbxassetid://88799151847518"},
	Kappa = {Idle = "rbxassetid://78169688030385", Walk = "rbxassetid://122311922141160"},
	KickerRigR15Classic = {Idle = "rbxassetid://103738372998074", Walk = "rbxassetid://72038616092085"},
	Kitsune = {Idle = "rbxassetid://126598627409687", Walk = "rbxassetid://100720699370971"},
	Koala = {Idle = "rbxassetid://100027202026085", Walk = "rbxassetid://104630343710448"},
	KomodoDragon = {Idle = "rbxassetid://72278805515777", Walk = "rbxassetid://129351012892718"},
	Kookaburra = {Idle = "rbxassetid://107187484567926", Walk = "rbxassetid://85877786735363"},
	Kraken = {Idle = "rbxassetid://112728140473659"},
	KrakenKing = {Idle = "rbxassetid://75720798970714"},
	Ladybug = {Idle = "rbxassetid://103026412105808", Walk = "rbxassetid://115055092455743"},
	Lemur = {Idle = "rbxassetid://80572242373795", Walk = "rbxassetid://126206445877805"},
	Leviathan = {Idle = "rbxassetid://94474408315764", Walk = "rbxassetid://114403564395564"},
	Lindworm = {Idle = "rbxassetid://128552523446278"},
	Lion = {Idle = "rbxassetid://118853203890204", Walk = "rbxassetid://121248456232536"},
	Lionfish = {Idle = "rbxassetid://89424748521053"},
	Lizard = {Idle = "rbxassetid://84828472862064", Walk = "rbxassetid://112239080159353"},
	Llama = {Idle = "rbxassetid://84857041468157", Walk = "rbxassetid://77042967879476"},
	Maltese = {Idle = "rbxassetid://118917292934167", Walk = "rbxassetid://79249122628496"},
	Mammoth = {Idle = "rbxassetid://139655882772004", Walk = "rbxassetid://123602654365704"},
	Mandarinfish = {Idle = "rbxassetid://134160877578485"},
	Manticore = {Idle = "rbxassetid://125822949708839", Walk = "rbxassetid://70633326336724"},
	MantisShrimp = {Idle = "rbxassetid://92760565410733"},
	Meerkat = {Idle = "rbxassetid://76558405651098", Walk = "rbxassetid://113308448255911"},
	Megalodon = {Idle = "rbxassetid://132581420249719"},
	Microraptor = {Idle = "rbxassetid://85233935911902", Walk = "rbxassetid://95723082113282"},
	Millipede = {Idle = "rbxassetid://110168690467452", Walk = "rbxassetid://80024312619997"},
	Minotaur = {Idle = "rbxassetid://88734215263091", Walk = "rbxassetid://83472965593858"},
	MoorishIdol = {Idle = "rbxassetid://127671899881250"},
	Moose = {Idle = "rbxassetid://73117696472520", Walk = "rbxassetid://98204679501112"},
	Mosasaurus = {Idle = "rbxassetid://137237903476108"},
	Moth = {Idle = "rbxassetid://137120868684877"},
	Mothman = {Idle = "rbxassetid://93058969022470", Walk = "rbxassetid://71104038236794"},
	Nautilus = {Idle = "rbxassetid://116200148495322"},
	Newt = {Idle = "rbxassetid://96042157675185", Walk = "rbxassetid://100937588541529"},
	Octopus = {Idle = "rbxassetid://117677894539447"},
	Okapi = {Idle = "rbxassetid://88926607980546", Walk = "rbxassetid://139494489974999"},
	Ostrich = {Idle = "rbxassetid://137325370987443", Walk = "rbxassetid://85953681137421"},
	Owl = {Idle = "rbxassetid://91895929253217", Walk = "rbxassetid://123979358607960"},
	Papillon = {Idle = "rbxassetid://82131763531717", Walk = "rbxassetid://115007530296986"},
	Parrot = {Idle = "rbxassetid://84178118471984", Walk = "rbxassetid://95467797358516"},
	Peafowl = {Idle = "rbxassetid://94982252053911", Walk = "rbxassetid://102259971326267"},
	Pegasus = {Idle = "rbxassetid://116478315085139", Walk = "rbxassetid://87731229326128"},
	Phoenix = {Idle = "rbxassetid://134699892129640", Walk = "rbxassetid://79495655007205"},
	Pigeon = {Idle = "rbxassetid://126961055311238", Walk = "rbxassetid://94963289850618"},
	Platypus = {Idle = "rbxassetid://108057578494108", Walk = "rbxassetid://132291473629919"},
	Plesiosaur = {Idle = "rbxassetid://73182595885964"},
	PolarBear = {Idle = "rbxassetid://119316288871250", Walk = "rbxassetid://85051889357042"},
	PolarBear2 = {Idle = "rbxassetid://83803150067184", Walk = "rbxassetid://104879417978734"},
	Pony = {Idle = "rbxassetid://118015391984237", Walk = "rbxassetid://118178084385309"},
	Porcupine = {Idle = "rbxassetid://120190120050598", Walk = "rbxassetid://132416756005697"},
	PrayingMantis = {Idle = "rbxassetid://120874579437753", Walk = "rbxassetid://72522362100787"},
	Pteranodon = {Idle = "rbxassetid://116427204936127", Walk = "rbxassetid://102335947338333"},
	Pterodactyl = {Idle = "rbxassetid://136955306848880", Walk = "rbxassetid://70975010759505"},
	Pufferfish = {Idle = "rbxassetid://72889092953679"},
	Puffin = {Idle = "rbxassetid://77086219450381", Walk = "rbxassetid://96850907612662"},
	Qilin = {Idle = "rbxassetid://107416419017620", Walk = "rbxassetid://134187926226270"},
	Quetzalcoatlus = {Idle = "rbxassetid://126271752675247", Walk = "rbxassetid://110050600855054"},
	Quokka = {Idle = "rbxassetid://123263974557996", Walk = "rbxassetid://102902407332288"},
	Raiju = {Idle = "rbxassetid://131391741171618", Walk = "rbxassetid://97783015133347"},
	Raven2 = {Idle = "rbxassetid://74694248184251", Walk = "rbxassetid://83954660211598"},
	RedPanda = {Idle = "rbxassetid://110124002875149", Walk = "rbxassetid://110035018472494"},
	Roc = {Idle = "rbxassetid://103078426078092", Walk = "rbxassetid://72343016774530"},
	Sabertooth = {Idle = "rbxassetid://102087298124792", Walk = "rbxassetid://119812256681775"},
	Sailfish = {Idle = "rbxassetid://89452869742501"},
	Salamander = {Idle = "rbxassetid://85936981707184", Walk = "rbxassetid://134798842440032"},
	SaltwaterCroc = {Idle = "rbxassetid://125321574980464", Walk = "rbxassetid://102692521449013"},
	SeaDragon = {Idle = "rbxassetid://113494015616773"},
	SeaTurtle = {Idle = "rbxassetid://88530987167700"},
	Seahorse = {Idle = "rbxassetid://85249783434924"},
	Seal = {Idle = "rbxassetid://124234177631389", Walk = "rbxassetid://95464164737205"},
	Secretary = {Idle = "rbxassetid://120007063964355", Walk = "rbxassetid://125532188670426"},
	Serval = {Idle = "rbxassetid://110794196265829", Walk = "rbxassetid://107435856666900"},
	Shark = {Idle = "rbxassetid://109448885589611"},
	ShibaInu = {Idle = "rbxassetid://108737809612206", Walk = "rbxassetid://74236280012854"},
	Shoebill = {Idle = "rbxassetid://95607882159660", Walk = "rbxassetid://120351399095221"},
	Simurgh = {Idle = "rbxassetid://139326067323132", Walk = "rbxassetid://94542523350516"},
	Sloth = {Idle = "rbxassetid://90933532249331", Walk = "rbxassetid://107438706970997"},
	Snail = {Idle = "rbxassetid://73158519666382", Walk = "rbxassetid://108730516799227"},
	Snake = {Idle = "rbxassetid://86563018387009"},
	Sphinx = {Idle = "rbxassetid://94980789727643", Walk = "rbxassetid://101118952932842"},
	Spinosaurus = {Idle = "rbxassetid://94334633841302", Walk = "rbxassetid://108582993101333"},
	Stegosaurus = {Idle = "rbxassetid://100808832589067", Walk = "rbxassetid://127168267947030"},
	Stingray = {Idle = "rbxassetid://104900967584577"},
	Stymphalian = {Idle = "rbxassetid://128646903203487", Walk = "rbxassetid://82681377677863"},
	Surgeonfish = {Idle = "rbxassetid://139965982801858"},
	Swordfish = {Idle = "rbxassetid://92518750541335"},
	TRex = {Idle = "rbxassetid://98537498323742", Walk = "rbxassetid://129057457224640"},
	Tanuki = {Idle = "rbxassetid://109982922036166", Walk = "rbxassetid://81752838856725"},
	Tapir_V1 = {Idle = "rbxassetid://118335132528775", Walk = "rbxassetid://122200402165419"},
	Tapir_V2 = {Idle = "rbxassetid://96240840166786", Walk = "rbxassetid://110074827192958"},
	Thunderbird = {Idle = "rbxassetid://88815539440883", Walk = "rbxassetid://119339803623994"},
	Tiger = {Idle = "rbxassetid://99719481665890", Walk = "rbxassetid://100740355367396"},
	Toad = {Idle = "rbxassetid://118689556028392", Walk = "rbxassetid://127205788634722"},
	Tortoise = {Idle = "rbxassetid://106949045648498", Walk = "rbxassetid://84521013687568"},
	Toucan = {Idle = "rbxassetid://109496761817503", Walk = "rbxassetid://73084728647312"},
	Triceratops = {Idle = "rbxassetid://70391110234774", Walk = "rbxassetid://102116200426577"},
	TripleCobra = {Idle = "rbxassetid://97572522653091"},
	Trumpetfish = {Idle = "rbxassetid://131172015249598"},
	Tuna = {Idle = "rbxassetid://134520887328346"},
	Turtle = {Idle = "rbxassetid://116163554763191", Walk = "rbxassetid://119241459684919"},
	Unicorn = {Idle = "rbxassetid://84650127063961", Walk = "rbxassetid://114726268169975"},
	Velociraptor = {Idle = "rbxassetid://92729201837418", Walk = "rbxassetid://81025099439557"},
	Whale = {Idle = "rbxassetid://130970561654207"},
	WhiteRhino = {Idle = "rbxassetid://131800013288612", Walk = "rbxassetid://98794412141350"},
	Wobbegong = {Idle = "rbxassetid://114133498121819"},
	Wolf = {Idle = "rbxassetid://117731818443943", Walk = "rbxassetid://113927203364120"},
	WoollyMammoth = {Idle = "rbxassetid://74441967782958", Walk = "rbxassetid://100262708813464"},
	Wrasse = {Idle = "rbxassetid://102918840722230"},
	Wyvern = {Idle = "rbxassetid://103946029444287", Walk = "rbxassetid://75677961972521"},
	Yak = {Idle = "rbxassetid://129212839043841", Walk = "rbxassetid://91650578443713"},
	YiQi = {Idle = "rbxassetid://116001779104314", Walk = "rbxassetid://103126857340546"},
	Zebra = {Idle = "rbxassetid://99242088879500", Walk = "rbxassetid://117995636262452"},
}

-- Rare hatches announced to the whole server
G.AnnounceFrom = "Legendary"

-- ROBUX: put the real ids in once they're made on the Creator Dashboard (0 = not set up yet).
-- Passes are game passes; everything else is a developer product.
-- Gift = a second developer product, bought for another player.
-- Prices are in Robux: set the same price on the Creator Dashboard. Once an id is in, the shop shows the
-- dashboard's price; until then it shows Price. Balance rule (pigeon-claude, 11 Nov 2026): a pack is worth
-- "minutes of your own progress", and the more Robux, the more minutes per Robux (bigger = better value):
--   Strength packs: 19 R = 30 min of lifting (1.6 min/R), 79 R = 150 min (1.9), 249 R = 600 min (2.4),
--                   or a share of the Strength you have (3% / 14% / 50%: 0.16 / 0.18 / 0.20 % per Robux), whichever is more
--                   (lifting is slow for now, so mid and late game the share is what you get)
--   Cash packs:     49 R = 60 min of your income (1.2 min/R), 199 R = 360 min (1.8)
-- Packs scale with the player (your income, your barbell, your lift level), so they stay fair at every stage
-- and never hand out a fixed 100M that skips the game. The floors make them worth it for brand-new players.
-- Eggs: never sell the top tiers (Secret, Celestial...). Gift products cost the same as the item.
G.Passes = {
	VIP = {Id = 0, GiftId = 0, Price = 299},          -- 1.5x cash, 1.25x lifting XP, a free Giraffe egg + 2 h of income once
	Cash2x = {Id = 2082212310, GiftId = 3730520744, Price = 199},
	Luck2x = {Id = 2081720308, GiftId = 3730520756, Price = 249},
}
G.Products = {
	Pack10M = {Id = 3730520464, GiftId = 3730520818, Price = 49, CashMinutes = 60, CashMin = 10000},      -- shop card Pack10M: the small cash pack
	Pack100M = {Id = 3730520528, GiftId = 3730520834, Price = 199, CashMinutes = 360, CashMin = 75000},   -- shop card Pack100M: the big cash pack
	StrengthSmall = {Id = 3730520534, Price = 19, LiftMinutes = 30, StrengthMin = 25, StrengthPct = 0.03},           -- lifting bar BoostButton1
	StrengthMedium = {Id = 3730520542, Price = 79, LiftMinutes = 150, StrengthMin = 100, StrengthPct = 0.14},        -- BoostButton2
	StrengthLarge = {Id = 3730520584, Price = 249, LiftMinutes = 600, StrengthMin = 350, StrengthPct = 0.5},        -- BoostButton3
	EggTRex = {Id = 3730520594, GiftId = 3730520844, Price = 299, Egg = "TRex"},          -- Legendary, $200/s (0.67/s per Robux)
	EggElephant = {Id = 3730520603, GiftId = 3730520903, Price = 129, Egg = "Elephant"},  -- Epic, $75/s (0.58/s per Robux)
	EggTurtle = {Id = 3730520650, GiftId = 3730520918, Price = 25, Egg = "Turtle"},       -- Uncommon, $12/s: the cheap first buy
	LuckyPack = {Id = 3730520659, Price = 99, LuckyEgg = true},   -- a random egg rolled with x10 luck
	-- Starter Pack (in the shop's top card, the old VIPPack frame): one per player, about 2x the value of buying
	-- the same things one by one (a Rare egg ~60 R + 150 min of lifting = the 79 R pack + 2 h of income ~85 R)
	StarterPack = {Id = 3730520668, Price = 99, OnePer = true, Perks = "ONE TIME ONLY * 2X VALUE",
		Egg = "Giraffe", EggLabel = "RARE EGG",
		LiftMinutes = 150, StrengthMin = 100, StrengthPct = 0.14,
		CashMinutes = 120, CashMin = 25000},
	SkipRebirth = {Id = 3730520734, Price = 149, Skip = true},
}
-- What a scaling pack gives this player right now (the shop labels and the server use the same maths).
function G.packCash(pr, cashPerSec)
	return math.max(pr.CashMin or 0, math.floor((cashPerSec or 0) * 60 * pr.CashMinutes))
end
-- returns Strength gained, new lift level, new lift XP
function G.packLift(pr, level, xp, barbellLevel, strength)
	local b = G.Barbells[math.clamp(barbellLevel or 1, 1, #G.Barbells)]
	level = level or 1
	xp = (xp or 0) + pr.LiftMinutes * 60 * G.LiftSpeed / G.RepSeconds * b.Power
	local ups, gained = 0, 0
	while xp >= G.LiftXP(level) and ups < 100000 do
		xp -= G.LiftXP(level); level += 1; ups += 1
		gained += G.StrengthGain(level)
	end
	local least = math.max(pr.StrengthMin or 0, (pr.StrengthPct or 0) * (strength or 0))
	while gained < least and ups < 100000 do level += 1; ups += 1; gained += G.StrengthGain(level) end
	return gained, level, xp
end
-- VIP (pigeon-claude, 11 Nov 2026): its own perks, so it isn't just the 2x Cash pass again (the two stack: 3x).
-- The old one-time $1M skipped most of the barbells for a new player; now it's 2 h of your income (at least $25K).
G.VIPCashMulti, G.VIPLiftMulti = 1.5, 1.25
G.VIPCashMinutes, G.VIPCashMin = 120, 25000
G.VIPEgg = "Giraffe"   -- Rare, $30/s
G.VIPPerks = "1.5x CASH * 1.25x LIFT * EGG"   -- keep it about as long as the card's old text, or it runs into the VIP title

-- which shop / HUD frame sells what (frame name in Jacob's UI -> pass or product)
G.ShopItems = {
	VIPPack = {Product = "StarterPack", Title = "STARTER PACK"},   -- was the VIP pass (pigeon: an offer, not a VIP bundle). VIP stays defined but isn't sold.
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
	BoostButton1 = {Product = "StrengthSmall"},     -- the three Robux buttons on the lifting bar (HUD.EnergyBarHUD)
	BoostButton2 = {Product = "StrengthMedium"},
	BoostButton3 = {Product = "StrengthLarge"},
}

-- $1,234 / $12.5K / $3.2M ...
local SUFFIX = {"", "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No", "Dc"}
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

-- Lifting levels: each rep gives XP = the barbell's Power; every level up gives G.StrengthGain(new level) Strength.
-- Jacob (11 Nov 2026): more per level as you go: 5 early, ~15 at level 100, ~26 at 150, ~45 at 200, ~130 at 300.
G.StrengthPerLevel = 5        -- the starting gain
G.StrengthGrowth = 1.011      -- x per level
function G.StrengthGain(level)
	return math.max(G.StrengthPerLevel, math.floor(G.StrengthPerLevel * G.StrengthGrowth ^ (level or 1) + 0.5))
end
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

-- Income (Jacob, 11 Nov 2026): every animal has its own cash per second, climbing along the ranks from
-- $5/s (Hamster) to $100T/s (Dragon), rounded to 2 digits. Mutations multiply it (Hacked Dragon $800T/s).
G.IncomeBottom, G.IncomeTop = 5, 1e14
local function round2(n)
	if n < 100 then return math.floor(n + 0.5) end
	local mag = 10 ^ (math.floor(math.log10(n)) - 1)
	return math.floor(n / mag + 0.5) * mag
end
local INCOME = {}
function G.AnimalIncome(name)
	name = G.AnimalForEgg(name)
	if INCOME[name] then return INCOME[name] end
	local p = (G.rankOf(name) - 1) / math.max(1, #G.AnimalOrder - 1)
	INCOME[name] = round2(G.IncomeBottom * (G.IncomeTop / G.IncomeBottom) ^ p)
	return INCOME[name]
end
function G.IncomeAtRank(r)
	local p = (math.clamp(r, 1, #G.AnimalOrder) - 1) / math.max(1, #G.AnimalOrder - 1)
	return G.IncomeBottom * (G.IncomeTop / G.IncomeBottom) ^ p
end

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
G.AimGreen, G.AimRed = 1.25, 0.5   -- (pigeon, 14 Nov) green was 1.5
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
-- (Jacob, 11 Nov 2026) Strength 10 = a slow high lob (~3.4 s over the 74-stud penalty), the top = a rocket (~0.2 s).
G.BallSlow, G.BallFast = 22, 420          -- studs per second
G.BallArcSlow, G.BallArcFast = 9, 0.2     -- studs of arc
function G.strengthT(s) return math.clamp(math.log(math.max(s, 1) / G.StartStrength) / math.log(G.TopStrength / G.StartStrength), 0, 1) end
function G.ballSpeed(s) return G.BallSlow * (G.BallFast / G.BallSlow) ^ G.strengthT(s) end
function G.ballArc(s) local t = G.strengthT(s) return G.BallArcSlow + (G.BallArcFast - G.BallArcSlow) * t end

-- Mutations (Jacob, 11 Nov 2026): any rolled egg can come out mutated. A Gold egg hatches a Gold animal
-- (models: ReplicatedStorage.Assets.Eggs.<M>Eggs / Assets.Animals.<M>Animals, same names as the base ones).
-- Chance = 1 in N per roll. Income = cash/s and sell price multiplier. Need = how much more Strength the egg takes.
-- Inverted is event-only (Chance 0) until an event turns it on (Jacob: every other mutation rolls).
G.Mutations = {
	-- a bit more common (Jacob, 11 Nov 2026): was 1 in 20 / 100 / 500 / 2000
	{Name = "Gold", Chance = 12, Income = 2, Need = 1.25, Color = Color3.fromRGB(255, 205, 40)},
	{Name = "Diamond", Chance = 60, Income = 3, Need = 1.5, Color = Color3.fromRGB(110, 220, 255)},
	{Name = "Rainbow", Chance = 300, Income = 5, Need = 2, Color = nil},   -- nil = rainbow text
	{Name = "Inverted", Chance = 0, Income = 4, Need = 1.75, Color = Color3.fromRGB(200, 200, 200)},
	{Name = "Hacked", Chance = 1200, Income = 8, Need = 2.5, Color = Color3.fromRGB(80, 255, 80)},
}
G.MutationInfo = {}
for _, m in G.Mutations do G.MutationInfo[m.Name] = m end
-- (Jacob, 11 Nov 2026) much more common on the low-end animals: x MutLowBoost on the most common animal,
-- easing down to x1 by the rarest (so a Hamster egg is Gold about 1 in 3, a Dragon egg still 1 in 12).
G.MutLowBoost = 4
function G.mutBoost(name)
	if not name then return 1 end
	local p = (G.rankOf(G.AnimalForEgg(name)) - 1) / math.max(1, #G.AnimalOrder - 1)
	return 1 + (G.MutLowBoost - 1) * (1 - p) ^ 2
end
-- 1 in N for this mutation on this egg / animal
function G.mutChanceFor(mut, name)
	local m = mut and G.MutationInfo[mut]
	if not m then return 1 end
	return m.Chance / G.mutBoost(name)
end
-- the server rolls this once per egg (rarest first); returns a mutation name or nil. name = the egg (optional)
function G.rollMutation(rng, name)
	local r = rng and rng:NextNumber() or math.random()
	local boost = G.mutBoost(name)
	local acc = 0
	for i = #G.Mutations, 1, -1 do
		local m = G.Mutations[i]
		if m.Chance > 0 then
			acc += boost / m.Chance
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
-- The auras are made for a ~G.VFXRefSize-stud thing; on anything bigger (huge placed Dragons etc.) the particles,
-- their speed and rate grow with it (G.scaleVFX), so a big animal gets a big aura.
G.VFXRefSize = 5
local function scaleSeq(seq, f)
	local kp = {}
	for _, k in seq.Keypoints do table.insert(kp, NumberSequenceKeypoint.new(k.Time, math.min(k.Value * f, 100), math.min(k.Envelope * f, 100))) end
	return NumberSequence.new(kp)
end
function G.scaleVFX(root, f)
	if f == 1 then return end
	local list = root:GetDescendants()
	table.insert(list, root)
	for _, d in list do
		if d:IsA("ParticleEmitter") then
			d.Size = scaleSeq(d.Size, f)
			d.Speed = NumberRange.new(d.Speed.Min * f, d.Speed.Max * f)
			d.Acceleration *= f
			d.Rate *= math.min(f, 3)
		elseif d:IsA("Attachment") then
			d.Position *= f
		elseif d:IsA("Light") then
			d.Range = math.min(d.Range * f, 60)
		elseif d:IsA("Beam") then
			d.Width0 *= f; d.Width1 *= f
		end
	end
end
function G.addMutationVFX(part, mut)
	if not (mut and part and part:IsA("BasePart")) or part:GetAttribute("MutVFX") == mut then return end
	local v = game:GetService("ReplicatedStorage"):FindFirstChild("Assets")
	v = v and v:FindFirstChild("VFX") and v.VFX:FindFirstChild("Mutations") and v.VFX.Mutations:FindFirstChild(mut)
	if not v then return end
	local s = part.Size
	local f = math.max(1, (s.X * s.Y * s.Z) ^ (1 / 3) / G.VFXRefSize)
	-- animals: the mesh box includes wings and tails, so centre the aura on the body (the root Bone) in an
	-- invisible VFXShell welded to the mesh, 65% of the mesh's size. Eggs (no bones) keep it on the part itself.
	local host = part
	local root = part:FindFirstChildWhichIsA("Bone")
	if root then
		local old = part:FindFirstChild("VFXShell")
		if old then old:Destroy() end
		host = Instance.new("Part")
		host.Name = "VFXShell"
		host.Transparency = 1
		host.CanCollide, host.CanQuery, host.CanTouch, host.Massless = false, false, false, true
		host.Anchored = false   -- rides on the weld, so it follows the mesh when held or moved
		host.Size = Vector3.new(math.max(1, s.X * 0.65), math.max(1, s.Y * 0.65), math.max(1, s.Z * 0.65))
		host.CFrame = part.CFrame.Rotation + root.WorldPosition
		local w = Instance.new("WeldConstraint")
		w.Part0, w.Part1 = part, host
		w.Parent = host
		host:SetAttribute("MutVFXPart", true)
		host.Parent = part
	else
		for _, c in part:GetChildren() do if c:GetAttribute("MutVFXPart") then c:Destroy() end end
	end
	for _, c in v:GetChildren() do
		local k = c:Clone()
		k:SetAttribute("MutVFXPart", true)
		G.scaleVFX(k, f)
		k.Parent = host
	end
	part:SetAttribute("MutVFX", mut)
end
function G.mutAnimalModel(name, mut)
	local f = mut and game:GetService("ReplicatedStorage"):FindFirstChild("Assets")
	f = f and f:FindFirstChild("Animals") and f.Animals:FindFirstChild(mut .. "Animals")
	return f and f:FindFirstChild(name)
end

-- Selling an animal from your inventory at Workspace.SellShop pays this many seconds of its income
-- (Hamster $5/s -> $300 ... Dragon $100T/s -> $6Qa), times its mutation.
G.SellSeconds = 60
function G.SellValue(name, mut) return G.AnimalIncome(name) * G.SellSeconds * G.mutIncome(mut) end
-- Offline earnings (Jacob, 11 Nov 2026): while you're away your placed animals earn OfflineRate of your cash/s
-- (at the moment you left), for up to OfflineMaxHours. Shown on the Welcome Back popup from your 2nd join.
G.OfflineRate, G.OfflineMaxHours, G.OfflineMinSeconds = 0.5, 12, 60

-- eggs sell too (Jacob, 11 Nov 2026): half of what the animal inside would sell for
G.EggSellShare = 0.5
function G.EggSellValue(egg, mut) return G.SellValue(G.AnimalForEgg(egg), mut) * G.EggSellShare end
function G.ItemSellValue(item) return item.Type == "Egg" and G.EggSellValue(item.Name, item.Mutation) or G.SellValue(item.Name, item.Mutation) end

-- sea animals float a little above the ground when placed (Jacob): HatchConfig.placedCFrame lifts these
G.Swimmers = {}
for _, n in string.split("Angelfish Anglerfish Archerfish Barracuda Blobfish BlueWhale Boxfish Butterflyfish CoralGoby Cowfish Cuttlefish Fangtooth GiantSquid GoblinShark Goldfish GreatWhite Hawkfish Jellyfish Kraken KrakenKing Leviathan Lionfish Mandarinfish MantisShrimp Megalodon MoorishIdol Mosasaurus Nautilus Octopus Plesiosaur Pufferfish Sailfish SeaDragon SeaTurtle Seahorse Shark Stingray Surgeonfish Swordfish Trumpetfish Tuna Whale Wobbegong Wrasse", " ") do G.Swimmers[n] = true end

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

-- Hatch time on a patch, by rank (Jacob, 11 Nov 2026): 5 s for the most common, up to 30 min for the rarest (Dragon).
-- Roughly: Commons 5-10 s, Rares ~30 s, Epics ~1-2 min, Legendary ~3-5 min, Mythic+ 6-30 min.
G.HatchMin, G.HatchMax = 5, 6 * 3600   -- Jacob: the rarest (Secret) takes 6 hours
function G.HatchSeconds(egg)
	local p = (G.rankOf(G.AnimalForEgg(egg)) - 1) / math.max(1, #G.AnimalOrder - 1)
	local s = G.HatchMin * (G.HatchMax / G.HatchMin) ^ p
	local step = s < 60 and 1 or s < 300 and 5 or s < 3600 and 30 or 60
	return math.max(G.HatchMin, math.floor(s / step + 0.5) * step)
end

-- Luck slides the egg roll up the ranks: at luck 1 you get the most common animals; as luck grows
-- the window moves to rarer commons, then uncommons, rares and so on. LuckTop = the luck that centres
-- the roll on the rarest animal.
G.LuckTop = 150     -- x150 (luck shop maxed) = rolls centred on the rarest animal
G.LuckBelow, G.LuckAbove = 14, 3.5        -- how far the roll spreads below / above the centre (in ranks)
function G.rollCentre(luck) return 1 + (#G.AnimalOrder - 1) * math.clamp(math.log(math.max(luck, 1)) / math.log(G.LuckTop), 0, 1) end
function G.rollWeight(name, luck)
	local d = G.rankOf(name) - G.rollCentre(luck)
	return d <= 0 and math.exp(d / G.LuckBelow) or math.exp(-d / G.LuckAbove)
end

return G
