-- Hold-E gifting, client side (pigeon, 14 Nov 2026). Server: ServerScriptService.GiftServer (rules + anti-spam).
-- * Every other player gets a "Gift" ProximityPrompt on their HumanoidRootPart (E / gamepad X / hold on touch).
--   Hidden when they turned Gifts off in Settings (player attribute GiftsOn).
-- * Holding it with an animal in your hands sends that animal as a gift; empty hands = a quick banner.
-- * Incoming gifts open StarterGui.Popups.GiftPopup (a copy of ConfirmPopup): ACCEPT / DECLINE / BLOCK,
--   X = decline, closes itself after the server's time limit (the DECLINE button counts down).
-- Messages use the HUD banner (NotificationsHUD.ShowBanner), always shown: they answer something you just did.
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local player = Players.LocalPlayer
local Remote = RS:WaitForChild("GameRemotes"):WaitForChild("Gift")
local pg = player:WaitForChild("PlayerGui")

local COLORS = {Common = Color3.fromRGB(215, 215, 215), Uncommon = Color3.fromRGB(110, 230, 90), Rare = Color3.fromRGB(90, 175, 255),
	Epic = Color3.fromRGB(190, 110, 255), Legendary = Color3.fromRGB(255, 200, 50), Mythic = Color3.fromRGB(255, 80, 135),
	Exotic = Color3.fromRGB(255, 140, 40), Divine = Color3.fromRGB(255, 250, 215), Celestial = Color3.fromRGB(120, 230, 255),
	Secret = Color3.fromRGB(185, 185, 200)}

local function banner(text)
	local hud = pg:FindFirstChild("HUD")
	local n = hud and hud:FindFirstChild("NotificationsHUD")
	if n and n:FindFirstChild("ShowBanner") then n.ShowBanner:Fire(text) end
end

------------------------------------------------------------ prompts on other players
local function addPrompt(other, char)
	local root = char:WaitForChild("HumanoidRootPart", 10)
	if not root or root:FindFirstChild("GiftPrompt") then return end
	local pp = Instance.new("ProximityPrompt")
	pp.Name = "GiftPrompt"
	pp.ActionText = "Gift"
	pp.ObjectText = other.DisplayName
	pp.HoldDuration = 0.6
	pp.MaxActivationDistance = 10
	pp.RequiresLineOfSight = false
	pp.KeyboardKeyCode = Enum.KeyCode.E
	pp.GamepadKeyCode = Enum.KeyCode.ButtonX
	pp.Exclusivity = Enum.ProximityPromptExclusivity.OnePerButton
	local function refresh() pp.Enabled = other:GetAttribute("GiftsOn") ~= false end
	refresh()
	other:GetAttributeChangedSignal("GiftsOn"):Connect(refresh)
	pp.Triggered:Connect(function()
		local held = player.Character and player.Character:FindFirstChildOfClass("Tool")
		if not (held and held:GetAttribute("AnimalName")) then
			banner("You're not holding any animal!")
			return
		end
		Remote:FireServer("Offer", other)
	end)
	pp.Parent = root
end
local function watch(other)
	if other == player then return end
	if other.Character then task.spawn(addPrompt, other, other.Character) end
	other.CharacterAdded:Connect(function(c) addPrompt(other, c) end)
end
for _, p in Players:GetPlayers() do watch(p) end
Players.PlayerAdded:Connect(watch)

------------------------------------------------------------ the popup
local popup = pg:WaitForChild("Popups"):WaitForChild("GiftPopup")
local panel = popup:WaitForChild("GiftPanel")
local content = panel:WaitForChild("Content")
popup.DisplayOrder = 65   -- above Welcome Back (60), so a gift right after joining isn't hidden
popup.Enabled = false
local current, closeAt

local function hide() popup.Enabled = false; current = nil end
local function answer(how)
	if not current then return end
	Remote:FireServer("Answer", current, how)
	hide()
end
local function clicky(obj, fn)
	if not obj then return end
	if obj:IsA("GuiButton") then obj.Activated:Connect(fn) return end
	obj.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then fn() end
	end)
end
for _, n in {"YesFill", "YesLabel"} do clicky(content:FindFirstChild(n), function() answer("accept") end) end
for _, n in {"NoFill", "NoLabel"} do clicky(content:FindFirstChild(n), function() answer("decline") end) end
for _, n in {"BlockFill", "BlockLabel"} do clicky(content:FindFirstChild(n), function() answer("block") end) end
local x = panel:FindFirstChild("CloseButton", true)
if x then clicky(x, function() answer("decline") end) end
-- gamepad: A accepts, B declines while the popup is up
game:GetService("ContextActionService"):BindAction("GiftPopupPad", function(_, state, input)
	if not current or state ~= Enum.UserInputState.Begin then return Enum.ContextActionResult.Pass end
	if input.KeyCode == Enum.KeyCode.ButtonA then answer("accept") return Enum.ContextActionResult.Sink end
	if input.KeyCode == Enum.KeyCode.ButtonB then answer("decline") return Enum.ContextActionResult.Sink end
	return Enum.ContextActionResult.Pass
end, false, Enum.KeyCode.ButtonA, Enum.KeyCode.ButtonB)

Remote.OnClientEvent:Connect(function(what, a, b, c, d, e)
	if what == "Msg" then
		banner(a)
	elseif what == "Close" then
		if current == a then hide() end
	elseif what == "Incoming" then
		local id, from, label, rarity, secs = a, b, c, d, e
		current = id
		closeAt = os.clock() + (secs or 15)
		content.MessageLabel.Text = string.upper((from and from.DisplayName or "Someone") .. " wants to give you")
		local al = content:FindFirstChild("AnimalLabel")
		if al then
			-- (pigeon, 14 Nov) the rarity sits right after the name: "RAINBOW LION (EPIC)"
			al.Text = string.upper((label or "an animal") .. (rarity and (" (" .. rarity .. ")") or ""))
			al.TextColor3 = COLORS[rarity] or Color3.fromRGB(255, 210, 60)
		end
		panel.Visible = true
		popup.Enabled = true
		task.spawn(function()
			local nl = content:FindFirstChild("NoLabel")
			while current == id do
				local left = math.max(0, math.ceil(closeAt - os.clock()))
				if nl then nl.Text = "DECLINE (" .. left .. ")" end
				if left <= 0 then answer("decline") break end
				task.wait(0.25)
			end
		end)
	end
end)
