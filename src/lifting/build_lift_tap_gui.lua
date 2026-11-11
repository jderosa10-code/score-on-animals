-- Builds StarterGui.HUD.LiftTapHUD once, in edit mode (pigeon-claude, 2026-11-11). Run from the edit context:
--   loadstring(src)()(clientSource)
-- The result is plain instances in StarterGui (a ScreenGui, Frames, a TextButton, labels, Sounds, one
-- LocalScript), sized by Scale with aspect-ratio constraints, so it keeps its shape on any screen.
-- LOOK: it is made from the game's own UI kit so it matches the rest of the HUD. The button skin (gradient
-- Fill + diamond Pattern + black outline) is copied from HUD.StopLiftHUD.StopButton, the bar from
-- HUD.EnergyBarHUD's EnergyBar, the yellow text from the Strength label, the arm icon from the boost buttons.
return function(clientSource)
	local SG = game:GetService("StarterGui")
	local hud = SG:FindFirstChild("HUD") or SG
	local old = hud:FindFirstChild("LiftTapHUD")
	if old then old:Destroy() end
	local kitButton = hud.StopLiftHUD.StopButton
	local kitBar = hud.EnergyBarHUD.EnergyBarPanel.EnergyBar
	local kitIcon = hud.EnergyBarHUD.EnergyBarPanel.BoostButton1.Icon
	local FONT = kitButton.Label.FontFace
	local ORANGE = ColorSequence.new(Color3.fromRGB(255, 138, 0), Color3.fromRGB(255, 216, 84))    -- dark on top, light below, like the kit's buttons
	local YELLOW = ColorSequence.new(Color3.fromRGB(255, 193, 7), Color3.fromRGB(255, 255, 0))     -- the Strength label's text gradient

	local function make(class, props, parent)
		local i = Instance.new(class)
		for k, v in pairs(props) do i[k] = v end
		i.Parent = parent
		return i
	end
	-- a copy of a kit piece without the kit's own scaling helpers and bookkeeping
	local function kitCopy(src, parent)
		local c = src:Clone()
		for _, d in ipairs(c:GetDescendants()) do
			if d.Name == "FW_Scale" or d:IsA("LuaSourceContainer") then d:Destroy() end
		end
		for _, d in ipairs({c, table.unpack(c:GetDescendants())}) do
			for k in pairs(d:GetAttributes()) do d:SetAttribute(k, nil) end
		end
		c.Parent = parent
		return c
	end
	local function textStroke(l)
		make("UIStroke", {Color = Color3.new(0, 0, 0), Thickness = 0.085, StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual, LineJoinMode = Enum.LineJoinMode.Round}, l)
	end
	local function label(name, text, props, parent, yellow)
		local l = make("TextLabel", {Name = name, Text = text, BackgroundTransparency = 1, TextScaled = true, TextWrapped = false, FontFace = FONT, TextColor3 = Color3.new(1, 1, 1)}, parent)
		for k, v in pairs(props) do l[k] = v end
		textStroke(l)
		if yellow then make("UIGradient", {Color = YELLOW, Rotation = -63}, l) end
		return l
	end
	local function recolor(fill, colors)
		local g = fill:FindFirstChildOfClass("UIGradient")
		if g then g.Color = colors end
	end

	local gui = Instance.new("ScreenGui")
	gui.Name = "LiftTapHUD"; gui.ResetOnSpawn = false; gui.IgnoreGuiInset = true; gui.DisplayOrder = 5
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

	-- the part of the screen where targets may pop up (clear of the side buttons, STOP and the level bar)
	local area = make("Frame", {Name = "TapArea", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.47),
		Size = UDim2.fromScale(0.6, 0.42), BackgroundTransparency = 1}, gui)

	-- the target: a ROUND kit button in orange (the kit's gradient Fill + diamond Pattern + black outline, as a circle)
	local RATIO = 1
	local btn = make("TextButton", {Name = "TapButton", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.4, 0.4), BackgroundTransparency = 1, Text = "", AutoButtonColor = false, Visible = false, ZIndex = 3}, area)
	make("UIAspectRatioConstraint", {AspectRatio = RATIO, AspectType = Enum.AspectType.ScaleWithParentSize, DominantAxis = Enum.DominantAxis.Height}, btn)
	-- never smaller than a fingertip on a small phone, never huge on a big monitor
	make("UISizeConstraint", {MinSize = Vector2.new(84, 84), MaxSize = Vector2.new(210, 210)}, btn)
	local function circle(piece)
		piece.AnchorPoint = Vector2.new(0.5, 0.5); piece.Position = UDim2.fromScale(0.5, 0.5); piece.Size = UDim2.fromScale(1, 1)
		for _, d in ipairs(piece:GetDescendants()) do
			if d:IsA("UICorner") then d.CornerRadius = UDim.new(0.5, 0) end
		end
	end
	local fill = kitCopy(kitButton.Fill, btn)
	recolor(fill, ORANGE)
	circle(fill)
	local pattern = kitCopy(kitButton.Pattern, btn)
	circle(pattern)
	-- the diamonds are the same size on screen as on the STOP button and the level bar: there a tile is about
	-- 0.04 of the screen's height, and this button is about 0.17 of it, so one tile is 0.24 of the button
	pattern.Texture.TileSize = UDim2.fromScale(0.24, 0.24)
	local icon = kitCopy(kitIcon, btn)
	icon.Name = "Icon"; icon.AnchorPoint = Vector2.new(0.5, 0.5); icon.Position = UDim2.fromScale(0.5, 0.33); icon.Size = UDim2.fromScale(0.46, 0.42); icon.ZIndex = 12
	label("Label", "TAP!", {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.69), Size = UDim2.fromScale(0.74, 0.3), ZIndex = 14}, btn)
	-- the circle that closes in on the target. When it reaches the button you still have a moment to hit it.
	local ring = make("Frame", {Name = "Timer", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(1.9, 1.9),
		BackgroundTransparency = 1, ZIndex = 2}, btn)
	make("UICorner", {CornerRadius = UDim.new(0.5, 0)}, ring)
	make("UIStroke", {Color = Color3.new(1, 1, 1), Thickness = 0.035, StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize, Transparency = 0.1,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border, LineJoinMode = Enum.LineJoinMode.Round}, ring)

	-- templates the script copies when you hit a target
	local burst = make("Frame", {Name = "Burst", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.4, 0.4),
		BackgroundTransparency = 1, Visible = false, ZIndex = 2}, area)
	make("UIAspectRatioConstraint", {AspectRatio = RATIO, AspectType = Enum.AspectType.ScaleWithParentSize, DominantAxis = Enum.DominantAxis.Height}, burst)
	make("UICorner", {CornerRadius = UDim.new(0.5, 0)}, burst)
	make("UIStroke", {Color = Color3.fromRGB(255, 220, 40), Thickness = 0.05, StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border, LineJoinMode = Enum.LineJoinMode.Round}, burst)
	label("PopText", "SPEED UP!", {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.5, 0.2), Visible = false, ZIndex = 16}, area, true)

	-- the boost bar: the kit's level bar in orange, with a title in the Strength label's yellow
	local bar = make("Frame", {Name = "BoostBar", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0.2), Size = UDim2.fromScale(0.3, 0.1),
		BackgroundTransparency = 1, Visible = false}, gui)
	make("UIAspectRatioConstraint", {AspectRatio = 4.6}, bar)      -- keeps its shape on tall (portrait) screens too
	label("Title", "SPEED BOOST!", {AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0), Size = UDim2.fromScale(1, 0.52), ZIndex = 20}, bar, true)
	local track = kitCopy(kitBar, bar)
	track.Name = "Track"; track.AnchorPoint = Vector2.new(0.5, 0.5); track.Position = UDim2.fromScale(0.5, 0.76); track.Size = UDim2.fromScale(0.9, 0.36)
	for _, c in ipairs(track:GetChildren()) do
		if c:IsA("TextLabel") then c:Destroy() end
	end
	recolor(track.Fill, ORANGE)
	track.Fill.AnchorPoint = Vector2.new(0, 0.5); track.Fill.Position = UDim2.fromScale(0, 0.5)     -- empties from the right
	make("Frame", {Name = "Back", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(20, 24, 40), BackgroundTransparency = 0.35, BorderSizePixel = 0, ZIndex = 1}, track)
	make("UICorner", {CornerRadius = UDim.new(0.04, 0)}, track.Back)
	label("Combo", "x2", {AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.fromScale(0.98, 0.72), Size = UDim2.fromScale(0.24, 0.62), TextXAlignment = Enum.TextXAlignment.Left, Visible = false, ZIndex = 20}, bar)

	-- sounds (swap a SoundId here to change one)
	local sounds = make("Folder", {Name = "Sounds"}, gui)
	local function sound(name, id, volume, speed)
		make("Sound", {Name = name, SoundId = "rbxassetid://" .. id, Volume = volume, PlaybackSpeed = speed or 1}, sounds)
	end
	sound("Pull", "9113269991", 0.35)          -- Barbell Weights 7 (Roblox's licensed library): a short rattle as the bar comes up
	sound("Lockout", "109359226723492", 0.45, 1.5)   -- the game's own pop, pitched up
	sound("Land", "9113269783", 0.5)           -- Barbell Weights 3: the plates rattle as the bar lands
	sound("Drop", "9120265201", 0.8)           -- "Tricycle Impact Slammed On Wood Floor Big 5": the heavy bang on the floor
	sound("Thud", "9116488438", 0.6, 0.7)      -- "Meaty Thud 2", pitched down: the weight behind it
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
