-- Favorite reward (pigeon, 14 Nov 2026): favorite the game once -> a random RARE animal + cash.
-- Cash scales like the cash packs (GameConfig.packCash): at least CASH_MIN, or CASH_MINUTES of your income if that's more.
-- Once per account (profile FavoriteRewarded, player attribute FavRewarded).
-- Roblox lets a game see that its favorite prompt was confirmed (AvatarEditorService.PromptSetFavoriteCompleted),
-- but there's no way at all to see likes, so "like the game" is only asked for, never checked.
-- Client: StarterPlayerScripts.FavoriteRewardClient fires GameRemotes.FavoriteReward("Favorited") after a confirmed
-- favorite (from the sign's FavoritePrompt or Jacob's idle FavoritePromptClient). The server can't double-check a
-- favorite, so the most anyone can cheat is this one reward, once.
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local D = require(script.Parent:WaitForChild("GameData"))
local G = require(RS:WaitForChild("GameConfig"))
local EggRoll = require(RS:WaitForChild("DevDemo"):WaitForChild("EggRoll"))
local C = require(RS:WaitForChild("Hatching"):WaitForChild("HatchConfig"))
local Remote = RS:WaitForChild("GameRemotes"):WaitForChild("FavoriteReward")

local RARITY = "Rare"
local CASH_MIN, CASH_MINUTES = 5000, 10

local function pickAnimal()
	local list = {}
	for _, n in G.AnimalOrder do
		if EggRoll.rarityOf(n) == RARITY and C.animalTemplate(n) then table.insert(list, n) end
	end
	return list[math.random(1, math.max(1, #list))]
end

local busy = {}
Remote.OnServerEvent:Connect(function(pl, what)
	if what ~= "Favorited" or busy[pl] then return end
	local p = D.get(pl)
	if not p or p.FavoriteRewarded then return end
	busy[pl] = true
	p.FavoriteRewarded = true
	pl:SetAttribute("FavRewarded", true)
	local name = pickAnimal()
	if name then D.giveItem(pl, "Animal", name, nil, nil, true) end
	local cash = G.packCash({CashMin = CASH_MIN, CashMinutes = CASH_MINUTES}, pl:GetAttribute("CashPerSec") or 0)
	D.addCash(pl, cash)
	Remote:FireClient(pl, "Msg", "Thanks for the favorite! You got a Rare " .. (name and (G.nice and G.nice(name) or name) or "animal") .. " + $" .. G.short(cash) .. "!")
	task.spawn(D.save, pl)
	busy[pl] = nil
end)

local function mark(pl)
	local p = D.get(pl)
	if p then pl:SetAttribute("FavRewarded", p.FavoriteRewarded == true) end
end
D.Loaded.Event:Connect(mark)
for _, pl in Players:GetPlayers() do mark(pl) end
