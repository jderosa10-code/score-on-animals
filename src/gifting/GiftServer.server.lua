-- Hold-E gifting (pigeon, 14 Nov 2026). Walk up to someone holding an animal, hold their "Gift" prompt
-- (StarterPlayerScripts.GiftClient makes it), and they get StarterGui.Popups.GiftPopup: ACCEPT / DECLINE / BLOCK.
-- The animal in your hands is the gift. Remote: GameRemotes.Gift
--   client -> server: ("Offer", targetPlayer)   ("Answer", offerId, "accept" | "decline" | "block")
--   server -> client: ("Incoming", offerId, fromPlayer, animalLabel, rarity, seconds)   ("Close", offerId)   ("Msg", text)
-- Anti-spam (all checked here, the client can't skip them):
--   * one gift waiting at a time per sender and per receiver ("busy")
--   * the popup auto-declines after OFFER_SECONDS
--   * after a decline / no answer: that sender waits PAIR_WAIT[n] before gifting that person again
--     (1, 5, 15 min, growing with each decline in a row) and SENDER_WAIT before gifting anyone
--   * AUTO_BLOCK declines in a row = blocked for the rest of the server; BLOCK on the popup blocks right away
--   * an ACCEPTED gift adds no wait at all and resets the decline count
--   * Settings "Gifts" OFF (profile Settings.Gifts == false) = nobody can gift you; shown as player attribute GiftsOn
--   * you must be close (MAX_DIST) and really own the held animal; it's checked again when they accept
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local D = require(script.Parent:WaitForChild("GameData"))
local G = require(RS:WaitForChild("GameConfig"))
local EggRoll = require(RS:WaitForChild("DevDemo"):WaitForChild("EggRoll"))
local Remote = RS:WaitForChild("GameRemotes"):WaitForChild("Gift")

local OFFER_SECONDS = 15
local SENDER_WAIT = 10
local PAIR_WAIT = {60, 300, 900}
local AUTO_BLOCK = 3
local MAX_DIST = 16

local byFrom, byTo, offers = {}, {}, {}   -- player -> offer, player -> offer, id -> offer
local pairState = {}                       -- [from][to] = {declines, untilT}
local blocked = {}                         -- [to][from] = true
local senderUntil = {}
local lastFire = {}
local nextId = 0

local function msg(pl, text) if pl and pl.Parent then Remote:FireClient(pl, "Msg", text) end end
local function pair(from, to)
	pairState[from] = pairState[from] or {}
	pairState[from][to] = pairState[from][to] or {declines = 0, untilT = 0}
	return pairState[from][to]
end
local function hrp(pl) local c = pl.Character; return c and c:FindFirstChild("HumanoidRootPart") end
local function giftsOn(pl) local p = D.get(pl); return not (p and p.Settings and p.Settings.Gifts == false) end
local function heldAnimal(pl)
	local p = D.get(pl)
	local tool = pl.Character and pl.Character:FindFirstChildOfClass("Tool")
	local id = tool and tool:GetAttribute("ItemId")
	if not (p and id and tool:GetAttribute("AnimalName")) then return end
	for _, it in p.Items do
		if it.Id == id and not it.Pending and (it.Type == nil or it.Type == "Animal") then return tool, it end
	end
end
local function findTool(pl, id)
	for _, where in {pl.Character, pl:FindFirstChildOfClass("Backpack")} do
		if where then for _, t in where:GetChildren() do if t:IsA("Tool") and t:GetAttribute("ItemId") == id then return t end end end
	end
end
local function waitText(s) return s >= 60 and (math.ceil(s / 60) .. " min") or (math.ceil(s) .. "s") end

local function finish(o, how)
	if offers[o.id] ~= o then return end
	offers[o.id] = nil
	if byFrom[o.from] == o then byFrom[o.from] = nil end
	if byTo[o.to] == o then byTo[o.to] = nil end
	if o.to.Parent then Remote:FireClient(o.to, "Close", o.id) end
	if how == "accept" then return end
	if how == "gone" then return end
	-- decline / no answer / block: the waits start now
	local ps = pair(o.from, o.to)
	ps.declines += 1
	ps.untilT = os.clock() + PAIR_WAIT[math.min(ps.declines, #PAIR_WAIT)]
	senderUntil[o.from] = os.clock() + SENDER_WAIT
	if how == "block" or ps.declines >= AUTO_BLOCK then
		blocked[o.to] = blocked[o.to] or {}
		blocked[o.to][o.from] = true
	end
	if how == "timeout" then
		msg(o.from, o.to.DisplayName .. " didn't answer your gift")
	else
		msg(o.from, o.to.DisplayName .. " declined your gift")
	end
end

local function accept(o)
	local from, to = o.from, o.to
	if not (from.Parent and to.Parent and D.get(from) and D.get(to)) then finish(o, "gone"); msg(to, "That gift isn't available anymore"); return end
	local tool = findTool(from, o.itemId)
	local still = false
	for _, it in D.get(from).Items do if it.Id == o.itemId and not it.Pending then still = true end end
	if not (tool and still) then
		finish(o, "gone")
		msg(to, "That gift isn't available anymore")
		msg(from, "Your gift to " .. to.DisplayName .. " didn't go through (you don't have that animal anymore)")
		return
	end
	finish(o, "accept")
	local item = D.takeItem(from, tool)
	if not item then msg(to, "That gift isn't available anymore") return end
	local new = D.giveItem(to, item.Type or "Animal", item.Name, nil, item.Mutation, true)
	if new then
		for k, v in item do if new[k] == nil and k ~= "Id" and k ~= "Pending" then new[k] = v end end
	end
	local ps = pair(from, to)
	ps.declines, ps.untilT = 0, 0
	msg(from, to.DisplayName .. " accepted your " .. o.label .. "!")
	msg(to, "You got a " .. o.label .. " from " .. from.DisplayName .. "!")
	task.spawn(D.save, from)
	task.spawn(D.save, to)
end

local function offer(from, to)
	if typeof(to) ~= "Instance" or not to:IsA("Player") or not to.Parent then return end
	-- Studio only: workspace attribute GiftSelfTest lets you gift yourself, to test the popup with one player
	if to == from and not (game:GetService("RunService"):IsStudio() and workspace:GetAttribute("GiftSelfTest")) then return end
	if not (D.get(from) and D.get(to)) then msg(from, "Try again in a second") return end
	local tool, item = heldAnimal(from)
	if not tool then msg(from, "You're not holding any animal!") return end
	if not giftsOn(to) then msg(from, to.DisplayName .. " has gifts turned off") return end
	if blocked[to] and blocked[to][from] then msg(from, to.DisplayName .. " isn't taking gifts from you") return end
	if byFrom[from] then msg(from, "Wait for " .. byFrom[from].to.DisplayName .. " to answer your gift first") return end
	if byTo[to] then msg(from, to.DisplayName .. " is busy with another gift") return end
	local now = os.clock()
	local ps = pair(from, to)
	if ps.untilT > now then msg(from, to.DisplayName .. " declined your last gift. Try again in " .. waitText(ps.untilT - now)) return end
	if (senderUntil[from] or 0) > now then msg(from, "Wait " .. waitText(senderUntil[from] - now) .. " before gifting again") return end
	local a, b = hrp(from), hrp(to)
	if not (a and b) or (a.Position - b.Position).Magnitude > MAX_DIST then msg(from, "Get closer to " .. to.DisplayName) return end
	nextId += 1
	local label = G.mutLabel(item.Mutation, G.nice and G.nice(item.Name) or item.Name)
	local o = {id = nextId, from = from, to = to, itemId = item.Id, label = label}
	offers[o.id], byFrom[from], byTo[to] = o, o, o
	Remote:FireClient(to, "Incoming", o.id, from, label, EggRoll.rarityOf(item.Name), OFFER_SECONDS)
	msg(from, "Gift sent to " .. to.DisplayName .. "! Waiting for them to accept...")
	task.delay(OFFER_SECONDS + 0.5, function() if offers[o.id] == o then finish(o, "timeout") end end)
end

Remote.OnServerEvent:Connect(function(pl, what, a, b)
	local now = os.clock()
	if (lastFire[pl] or 0) > now - 0.25 then return end   -- ignore remote spam
	lastFire[pl] = now
	if what == "Offer" then
		offer(pl, a)
	elseif what == "Answer" then
		local o = offers[a]
		if not o or o.to ~= pl then return end
		if b == "accept" then accept(o)
		elseif b == "block" then finish(o, "block")
		else finish(o, "decline") end
	end
end)

Players.PlayerRemoving:Connect(function(pl)
	for _, o in offers do
		if o.from == pl or o.to == pl then
			finish(o, "gone")
			if o.from == pl then msg(o.to, "The gift was cancelled") end
		end
	end
	pairState[pl], blocked[pl], senderUntil[pl], lastFire[pl] = nil, nil, nil, nil
	for _, t in pairState do t[pl] = nil end
	for _, t in blocked do t[pl] = nil end
end)

-- show who has gifts switched off, so their prompt hides (GiftClient)
task.spawn(function()
	while true do
		for _, pl in Players:GetPlayers() do
			local on = giftsOn(pl)
			if pl:GetAttribute("GiftsOn") ~= on then pl:SetAttribute("GiftsOn", on) end
		end
		task.wait(1)
	end
end)
