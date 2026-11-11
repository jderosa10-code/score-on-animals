-- EggHatchOffer: the Chicken Egg offer shows a real 3D egg that hatches (pigeon-claude, 2026-11).
-- The egg wobbles, shakes, its top shell pops off along the crack, the chicken jumps out, spins,
-- lands in the offer's box and stays there. It plays when the shop opens, when you click the box,
-- and when you click Buy on that offer.
-- Needs ReplicatedStorage.ShopModels (ChickenEgg: Top + Bottom, Chicken). Safe to delete: the
-- offer just shows its flat icon again.
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")
local RS = game:GetService("ReplicatedStorage")

local gui = script.Parent
local panelRoot = gui:WaitForChild("ShopPanel")
local models = RS:WaitForChild("ShopModels", 5)
if not models then return end
local card = gui:WaitForChild("ShopPanel").Window.Backdrop.List.Content.ExclusiveSection.EggPacks:WaitForChild("ChickenEgg")
local iconFrame = card:WaitForChild("IconFrame")
local icon = iconFrame:WaitForChild("Icon")

local CHICKEN_YAW = math.rad(models:GetAttribute("ChickenYaw") or 0)    -- which way the chicken faces
local CHICKEN_HEIGHT = models:GetAttribute("ChickenHeight") or 4.3      -- studs, next to a 5.5 stud egg
local VIEW = 1.75                                                       -- the 3D view is this much bigger than the box, so the jump is not cut off
local EGG_FLOOR = -2.75                                                 -- bottom of the egg (it rocks about this point)
local LAND_Y = -0.55                                                    -- where the chicken's middle rests

-- ---------------------------------------------------------------- the stage: a 3D view over the box
local vp = Instance.new("ViewportFrame")
vp.Name = "Hatch3D"; vp.BackgroundTransparency = 1; vp.AnchorPoint = Vector2.new(0.5, 0.5)
local fp, fs, fa = iconFrame.Position, iconFrame.Size, iconFrame.AnchorPoint
vp.Position = UDim2.new(fp.X.Scale + fs.X.Scale * (0.5 - fa.X), fp.X.Offset + fs.X.Offset * (0.5 - fa.X),
	fp.Y.Scale + fs.Y.Scale * (0.5 - fa.Y), fp.Y.Offset + fs.Y.Offset * (0.5 - fa.Y))
vp.Size = UDim2.new(fs.X.Scale * VIEW, fs.X.Offset * VIEW, fs.Y.Scale * VIEW, fs.Y.Offset * VIEW)
vp.ZIndex = iconFrame.ZIndex
vp.Ambient = Color3.fromRGB(185, 185, 200); vp.LightColor = Color3.fromRGB(255, 250, 240); vp.LightDirection = Vector3.new(0.7, -1, -0.5)
local sq = Instance.new("UIAspectRatioConstraint"); sq.AspectRatio = 1; sq.Parent = vp
local cam = Instance.new("Camera"); cam.FieldOfView = 30
cam.CFrame = CFrame.lookAt(Vector3.new(-19, 6, 7.5), Vector3.new(0, 0.5, 0))        -- the egg's face looks down -X
cam.Parent = vp; vp.CurrentCamera = cam

local egg = models:WaitForChild("ChickenEgg"):Clone()
local top, bottom = egg:WaitForChild("Top"), egg:WaitForChild("Bottom")
local topHome, botHome = top.CFrame, bottom.CFrame                      -- built around the egg's centre at the origin
egg.Parent = vp
local chick = models:WaitForChild("Chicken"):Clone()
local body = chick.PrimaryPart or chick:FindFirstChildWhichIsA("BasePart", true)
local bodyRot = body.CFrame.Rotation
local _, bbox = chick:GetBoundingBox()
local bodySize = body.Size * (CHICKEN_HEIGHT / math.max(0.1, bbox.Y))
chick.Parent = vp
vp.Parent = card
icon.Visible = false

-- ---------------------------------------------------------------- flash + sparks (flat, on top of the 3D view)
local function sfx(file, vol, pitch)
	local s = Instance.new("Sound"); s.SoundId = "rbxasset://sounds/" .. file; s.Volume = vol; s.PlaybackSpeed = pitch or 1; s.Parent = script
	SoundService:PlayLocalSound(s)
	task.delay(2, function() s:Destroy() end)
end
local function popFX()
	local flash = Instance.new("Frame")
	flash.AnchorPoint = Vector2.new(0.5, 0.5); flash.Position = UDim2.fromScale(0.5, 0.5); flash.Size = UDim2.fromScale(0.25, 0.25)
	flash.BackgroundColor3 = Color3.new(1, 1, 1); flash.BackgroundTransparency = 0.15; flash.BorderSizePixel = 0; flash.ZIndex = 5
	local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0.5, 0); c.Parent = flash
	flash.Parent = vp
	local t = TweenService:Create(flash, TweenInfo.new(0.32, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), { Size = UDim2.fromScale(1.1, 1.1), BackgroundTransparency = 1 })
	t.Completed:Connect(function() flash:Destroy() end); t:Play()
	for i = 1, 12 do
		local s = Instance.new("Frame")
		local a = (i / 12) * math.pi * 2 + math.random() * 0.4
		local far = 0.36 + math.random() * 0.14
		s.AnchorPoint = Vector2.new(0.5, 0.5); s.Position = UDim2.fromScale(0.5, 0.5); s.Size = UDim2.fromScale(0.07, 0.07)
		s.BackgroundColor3 = (i % 2 == 0) and Color3.fromRGB(255, 240, 150) or Color3.new(1, 1, 1); s.BorderSizePixel = 0
		s.Rotation = math.random(0, 90); s.ZIndex = 6; s.Parent = vp
		local tw = TweenService:Create(s, TweenInfo.new(0.55 + math.random() * 0.2, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
			{ Position = UDim2.fromScale(0.5 + math.cos(a) * far, 0.5 + math.sin(a) * far), Size = UDim2.fromScale(0, 0), Rotation = s.Rotation + 220 })
		tw.Completed:Connect(function() s:Destroy() end); tw:Play()
	end
end

-- ---------------------------------------------------------------- the act
local state, t0, lastTick = "egg", os.clock(), 0
local function rock(angle, lift)        -- rocks the whole egg about the point it stands on
	local cf = CFrame.new(0, EGG_FLOOR + (lift or 0), 0) * CFrame.Angles(0, 0, angle) * CFrame.new(0, -EGG_FLOOR, 0)
	top.CFrame = cf * topHome; bottom.CFrame = cf * botHome
end
local function placeChick(y, yaw, scale, squash)
	local q = squash or 0
	body.Size = bodySize * scale * Vector3.new(1 + q * 0.5, 1 - q, 1 + q * 0.5)
	body.CFrame = CFrame.new(0, y - q * bodySize.Y * 0.5 * scale, 0) * CFrame.Angles(0, CHICKEN_YAW + yaw, 0) * bodyRot
end
local function setEgg()
	state = "egg"; t0 = os.clock()
	top.Transparency = 0; bottom.Transparency = 0; body.Transparency = 1
	rock(0)
end
local function hatch()
	if state == "shake" or state == "pop" then return end
	if state == "chicken" then setEgg() end
	state = "shake"; t0 = os.clock(); lastTick = 0
end

RunService.RenderStepped:Connect(function()
	if not (gui.Enabled and panelRoot and panelRoot.Visible) then return end
	local t = os.clock() - t0
	if state == "egg" then
		local p = t % 2.6                                              -- a little wobble now and then
		rock(math.rad(7) * math.sin(p * 18) * math.exp(-p * 3.2))
	elseif state == "shake" then
		local u = math.min(t / 1.05, 1)
		rock(math.rad(3 + 13 * u) * math.sin(t * (40 + 45 * u)), 0.3 * u * math.abs(math.sin(t * 19)))
		if t - lastTick > 0.13 - 0.06 * u then lastTick = t; sfx("switch.wav", 0.25, 1 + u * 1.2) end
		if u >= 1 then
			state = "pop"; t0 = os.clock()
			body.Transparency = 0
			popFX(); sfx("electronicpingshort.wav", 0.45, 1.35); sfx("clickfast.wav", 0.5, 0.8)
		end
	elseif state == "pop" then
		-- the lid flies up and back, tumbling, and fades
		top.CFrame = CFrame.new(Vector3.new(2.2 * t, 10 * t - 13 * t * t, 3 * t)) * topHome * CFrame.Angles(t * 7, t * 3, t * 5)
		top.Transparency = math.clamp((t - 0.4) / 0.35, 0, 1)
		-- the bottom shell kicks down, then sinks away
		local kick = -0.4 * math.exp(-t * 9) * math.cos(t * 30)
		local sink = math.max(0, t - 0.5)
		bottom.CFrame = CFrame.new(0, kick - sink * sink * 14, 0) * botHome
		bottom.Transparency = math.clamp((t - 0.55) / 0.35, 0, 1)
		-- the chicken: out of the shell, one spin in the air, lands in the box with a squash
		local y = -0.9 + 13 * t - 15.5 * t * t
		local grow = 1 - 0.8 * math.exp(-t * 7) * math.cos(t * 13)
		local tl = 0.86                                                  -- when it lands
		local spin = math.pi * 2 * (1 - (1 - math.min(t / 0.8, 1)) ^ 3)
		if t < tl and y > LAND_Y - 0.4 or t < 0.3 then
			placeChick(y, spin, grow)
		else
			local k = t - tl
			placeChick(LAND_Y + 0.45 * math.exp(-k * 7) * math.abs(math.sin(k * 13)), spin, 1, 0.22 * math.exp(-k * 11))
		end
		if t > 1.7 then state = "chicken"; t0 = os.clock() end
	elseif state == "chicken" then
		-- at home in the box: breathing, looking around, a hop now and then
		local p = t % 3.4
		local hop = (p > 2.9) and 0.55 * math.sin((p - 2.9) / 0.5 * math.pi) or 0
		placeChick(LAND_Y + 0.07 * math.sin(t * 3) + hop, 0.3 * math.sin(t * 1.3), 1, 0.03 * math.sin(t * 3))
	end
end)

-- ---------------------------------------------------------------- when it plays
local function onShown()
	setEgg()
	task.delay(1.5, function() if gui.Enabled and state == "egg" then hatch() end end)
end
-- the game's menu system shows the shop by Enabled and/or the panel's Visible
local wasShown = false
local function watch()
	local now = gui.Enabled and panelRoot.Visible
	if now and not wasShown then onShown() end
	wasShown = now
end
gui:GetPropertyChangedSignal("Enabled"):Connect(watch)
panelRoot:GetPropertyChangedSignal("Visible"):Connect(watch)
setEgg(); watch()
iconFrame.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then hatch() end
end)
task.spawn(function()
	local juice = gui:WaitForChild("ShopJuice", 5)
	local ev = juice and juice:WaitForChild("BuyClicked", 5)
	if ev then ev.Event:Connect(function(_, _, btn) if btn and btn:IsDescendantOf(card) then hatch() end end) end
end)
