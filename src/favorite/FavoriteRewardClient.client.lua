-- Favorite reward, client side (pigeon, 14 Nov 2026). Server: ServerScriptService.FavoriteReward.
-- * Workspace.GroupSign's FavoritePrompt (F / gamepad Y) opens Roblox's favorite prompt.
-- * Any confirmed favorite prompt (also Jacob's idle one in FavoritePromptClient) claims the reward once.
-- * The sign prompt hides once you've had the reward (player attribute FavRewarded).
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local AES = game:GetService("AvatarEditorService")
local PPS = game:GetService("ProximityPromptService")
local player = Players.LocalPlayer
local Remote = RS:WaitForChild("GameRemotes"):WaitForChild("FavoriteReward")

local function banner(text)
	local hud = player:WaitForChild("PlayerGui"):FindFirstChild("HUD")
	local n = hud and hud:FindFirstChild("NotificationsHUD")
	if n and n:FindFirstChild("ShowBanner") then n.ShowBanner:Fire(text) end
end
Remote.OnClientEvent:Connect(function(what, text) if what == "Msg" then banner(text) end end)

AES.PromptSetFavoriteCompleted:Connect(function(result)
	if result == Enum.AvatarPromptResult.Success and not player:GetAttribute("FavRewarded") then
		Remote:FireServer("Favorited")
	end
end)

local function isFav(pp)
	local sign = workspace:FindFirstChild("GroupSign")
	return pp.Name == "FavoritePrompt" and sign ~= nil and pp:IsDescendantOf(sign)
end
PPS.PromptShown:Connect(function(pp)
	if isFav(pp) and player:GetAttribute("FavRewarded") then pp.Enabled = false end
end)
player:GetAttributeChangedSignal("FavRewarded"):Connect(function()
	if not player:GetAttribute("FavRewarded") then return end
	local sign = workspace:FindFirstChild("GroupSign")
	local pp = sign and sign:FindFirstChild("FavoritePrompt", true)
	if pp then pp.Enabled = false end
end)
PPS.PromptTriggered:Connect(function(pp)
	if not isFav(pp) then return end
	pcall(function() AES:PromptSetFavorite(game.PlaceId, Enum.AvatarItemType.Asset, true) end)
end)
