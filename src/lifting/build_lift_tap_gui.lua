-- Builds StarterGui.HUD.LiftTapHUD once, in edit mode (pigeon-claude, 2026-11-11). Run from the command bar /
-- edit context:  loadstring(src)()(clientSource)
-- The result is plain instances in StarterGui (a ScreenGui, Frames, a TextButton, labels, Sounds, one
-- LocalScript). Everything is sized and placed by Scale with aspect-ratio constraints and TextScaled
-- labels, so it keeps its shape on phones, tablets and wide monitors. No runtime scaling scripts.
return function(clientSource)
	local SG = game:GetService("StarterGui")
	local hud = SG:FindFirstChild("HUD") or SG
	local old = hud:FindFirstChild("LiftTapHUD")
	if old then old:Destroy() end
	local FONT = Font.new("rbxasset://fonts/families/LuckiestGuy.json")
	local function make(class, props, parent)
		local i = Instance.new(class)
		for k, v in pairs(props) do i[k] = v end
		i.Parent = parent
		return i
	end
	local function round(parent) return make("UICorner", {CornerRadius = UDim.new(0.5, 0)}, parent) end
	local function square(parent) return make("UIAspectRatioConstraint", {AspectRatio = 1, AspectType = Enum.AspectType.ScaleWithParentSize, DominantAxis = Enum.DominantAxis.Height}, parent) end
	local function outline(parent, thickness, color)
		return make("UIStroke", {Thickness = thickness, Color = color or Color3.new(0, 0, 0), ApplyStrokeMode = parent:IsA("TextLabel") and Enum.ApplyStrokeMode.Contextual or Enum.ApplyStrokeMode.Border}, parent)
	end
	local function label(name, text, props, parent)
		local l = make("TextLabel", {Name = name, Text = text, BackgroundTransparency = 1, TextScaled = true, TextWrapped = false, FontFace = FONT, TextColor3 = Color3.new(1, 1, 1)}, parent)
		for k, v in pairs(props) do l[k] = v end
		make("UITextSizeConstraint", {MaxTextSize = 72, MinTextSize = 8}, l)
		return l
	end

	local gui = Instance.new("ScreenGui")
	gui.Name = "LiftTapHUD"; gui.ResetOnSpawn = false; gui.IgnoreGuiInset = true; gui.DisplayOrder = 30
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

	-- the part of the screen where targets may pop up (clear of the side buttons and the level bar)
	local area = make("Frame", {Name = "TapArea", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.43),
		Size = UDim2.fromScale(0.6, 0.46), BackgroundTransparency = 1}, gui)

	-- the target
	local btn = make("TextButton", {Name = "TapButton", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.36, 0.36), BackgroundColor3 = Color3.new(1, 1, 1), Text = "", AutoButtonColor = false, Visible = false, ZIndex = 3}, area)
	square(btn); round(btn)
	-- never smaller than a fingertip on a small phone, never huge on a big monitor
	make("UISizeConstraint", {MinSize = Vector2.new(76, 76), MaxSize = Vector2.new(210, 210)}, btn)
	make("UIGradient", {Rotation = 90, Color = ColorSequence.new(Color3.fromRGB(255, 226, 64), Color3.fromRGB(255, 122, 24))}, btn)
	outline(btn, 4, Color3.new(1, 1, 1))
	local shine = make("Frame", {Name = "Shine", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0.08), Size = UDim2.fromScale(0.62, 0.3),
		BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.65, BorderSizePixel = 0, ZIndex = 3}, btn)
	round(shine)
	local tap = label("Label", "TAP!", {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.56), Size = UDim2.fromScale(0.8, 0.44), ZIndex = 4}, btn)
	outline(tap, 3)
	-- the ring that closes in on the target: when it reaches the edge, the target is gone
	local ring = make("Frame", {Name = "Timer", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(1.75, 1.75),
		BackgroundTransparency = 1, ZIndex = 2}, btn)
	round(ring)
	local rs = outline(ring, 5, Color3.new(1, 1, 1)); rs.Transparency = 0.15

	-- templates the script copies when you hit a target
	local burst = make("Frame", {Name = "Burst", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.36, 0.36),
		BackgroundTransparency = 1, Visible = false, ZIndex = 2}, area)
	square(burst); round(burst)
	outline(burst, 6, Color3.fromRGB(255, 232, 90))
	local pop = label("PopText", "SPEED UP!", {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.5, 0.17),
		TextColor3 = Color3.fromRGB(255, 232, 90), Visible = false, ZIndex = 5}, area)
	outline(pop, 3)

	-- the boost bar: shows while your reps are sped up, and empties as the boost runs out
	local bar = make("Frame", {Name = "BoostBar", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0.265), Size = UDim2.fromScale(0.34, 0.085),
		BackgroundTransparency = 1, Visible = false}, gui)
	make("UIAspectRatioConstraint", {AspectRatio = 5.6}, bar)      -- keeps its shape on tall (portrait) screens too
	local title = label("Title", "SPEED BOOST!", {Position = UDim2.fromScale(0, 0), Size = UDim2.fromScale(1, 0.58), TextColor3 = Color3.fromRGB(255, 232, 90)}, bar)
	outline(title, 3)
	local track = make("Frame", {Name = "Track", Position = UDim2.fromScale(0.1, 0.64), Size = UDim2.fromScale(0.8, 0.3), BackgroundColor3 = Color3.fromRGB(22, 28, 46),
		BackgroundTransparency = 0.2, BorderSizePixel = 0}, bar)
	round(track); outline(track, 2)
	local fill = make("Frame", {Name = "Fill", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0}, track)
	round(fill)
	make("UIGradient", {Color = ColorSequence.new(Color3.fromRGB(255, 232, 90), Color3.fromRGB(255, 122, 24))}, fill)
	local combo = label("Combo", "x2", {AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.fromScale(1.02, 0.5), Size = UDim2.fromScale(0.3, 0.9), TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = Color3.fromRGB(255, 255, 255), Visible = false}, bar)
	outline(combo, 3)

	-- sounds (swap a SoundId here to change one)
	local sounds = make("Folder", {Name = "Sounds"}, gui)
	local function sound(name, id, volume, speed)
		make("Sound", {Name = name, SoundId = "rbxassetid://" .. id, Volume = volume, PlaybackSpeed = speed or 1}, sounds)
	end
	sound("Pull", "9113269991", 0.35)          -- Barbell Weights 7 (Roblox's licensed library): a short rattle as the bar comes up
	sound("Lockout", "109359226723492", 0.45, 1.5)   -- the game's own pop, pitched up
	sound("Land", "9113269783", 0.5)           -- Barbell Weights 3: the bar back on the rack
	sound("LevelUp", "112485797063762", 0.8)   -- "UI - Level Up"
	sound("Boost", "8208591201", 0.7)          -- "Speed Boost Start"
	sound("TargetPop", "6586979979", 0.5)      -- the game's UI hover blip
	sound("Miss", "109359226723492", 0.3, 0.6)

	local ls = Instance.new("LocalScript")
	ls.Name = "LiftTapClient"
	ls.Source = clientSource
	ls.Parent = gui

	gui.Parent = hud
	return gui
end
