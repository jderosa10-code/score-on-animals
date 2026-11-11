-- ShopJuice: an extra interaction layer on top of the Framewisp export (pigeon-claude, 2026-11).
-- It only ADDS motion: nothing in the design is moved, restyled or renamed. Safe to delete.
--   * open / close: the panel springs in, cards pop in one after another, X spins on the way out
--   * cards lift under the mouse and their art / icon shift with it (parallax)
--   * buy buttons: bouncy hover, squish on press, coin burst + ring + floating text on click,
--     with a click sound that climbs in pitch while you keep clicking (combo)
--   * gift buttons wiggle and hop, cards further down pop in as you scroll to them
--   * opening and closing stay with the game's own menu system; this only animates along
-- Hook real purchases here:   script.BuyClicked.Event:Connect(function(itemName, priceText, button) ... end)
--                             script.GiftClicked.Event:Connect(function(itemName, button) ... end)
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local SoundService = game:GetService("SoundService")

local gui = script.Parent
local panel = gui:WaitForChild("ShopPanel")
local window = panel:WaitForChild("Window")
local list = window:WaitForChild("Backdrop"):WaitForChild("List")
local content = list:WaitForChild("Content")
local topBar = window:WaitForChild("TopBar")

local BuyClicked = Instance.new("BindableEvent"); BuyClicked.Name = "BuyClicked"; BuyClicked.Parent = script
local GiftClicked = Instance.new("BindableEvent"); GiftClicked.Name = "GiftClicked"; GiftClicked.Parent = script
-- From any other LocalScript:
--   script.PlayBuyEffect:Fire(buyButton) replays the burst on that button, e.g. when the real purchase goes through
local PlayBuyEffect = Instance.new("BindableEvent"); PlayBuyEffect.Name = "PlayBuyEffect"; PlayBuyEffect.Parent = script
local effects = {}

-- ---------------------------------------------------------------- scale channels
-- Roblox allows one UIScale per object and Framewisp already shares it between its scripts:
-- every script writes its own NumberValue under "FW_Scale" and the product is applied. Same here.
local function scaleHost(el)
	local sc = el:FindFirstChild("FW_Scale")
	if not sc then
		sc = el:FindFirstChildWhichIsA("UIScale")
		if sc then sc.Name = "FW_Scale" else
			sc = Instance.new("UIScale"); sc.Name = "FW_Scale"; sc:SetAttribute("FW_Owned", true); sc.Parent = el
		end
	end
	return sc
end
local function channel(el, key)
	local host = scaleHost(el)
	local ch = host:FindFirstChild(key)
	if not ch then
		ch = Instance.new("NumberValue"); ch.Name = key; ch.Value = 1; ch:SetAttribute("FW_Owned", true); ch.Parent = host
		ch.Changed:Connect(function()
			local total = 1
			for _, c in ipairs(host:GetChildren()) do if c:IsA("NumberValue") then total *= c.Value end end
			host.Scale = total
		end)
	end
	return ch
end

-- ---------------------------------------------------------------- springs
local springs, active = {}, {}
local function spring(key, x0, apply, k, d)
	local s = springs[key]
	if not s then s = { x = x0, v = 0, t = x0, k = k or 260, d = d or 16, apply = apply }; springs[key] = s end
	return s
end
local function to(s, target, k, d)
	s.t = target; if k then s.k = k end; if d then s.d = d end
	active[s] = true
end
local function scaleSpring(el, key)
	local ch = channel(el, key or "k_shopjuice")
	return spring(ch, ch.Value, function(x) ch.Value = math.max(0.001, x) end)
end
local BOUNCY_K, BOUNCY_D = 340, 13       -- overshoots, settles in about half a second
local SOFT_K, SOFT_D = 220, 24           -- no overshoot

-- ---------------------------------------------------------------- sounds (built into Roblox, no uploads)
local function sound(file, vol)
	local s = Instance.new("Sound"); s.SoundId = "rbxasset://sounds/" .. file; s.Volume = vol; s.Parent = script
	return s
end
local SFX = { hover = sound("switch.wav", 0.18), click = sound("clickfast.wav", 0.5), open = sound("button.wav", 0.3),
	buy = sound("electronicpingshort.wav", 0.4), close = sound("button.wav", 0.35) }
local function play(name, pitch)
	local s = SFX[name]; if not s then return end
	s.PlaybackSpeed = pitch or 1
	SoundService:PlayLocalSound(s)
end

-- ---------------------------------------------------------------- FX layer (bursts, rings, floating text)
local fx = Instance.new("Frame")
fx.Name = "JuiceFX"; fx.BackgroundTransparency = 1; fx.Size = UDim2.fromScale(1, 1); fx.ZIndex = 100000; fx.Active = false
fx.Parent = gui
local particles = {}
local function centre(g) return g.AbsolutePosition + g.AbsoluteSize / 2 end

local function burst(icon, from, count, power)
	for i = 1, count do
		local p = Instance.new("ImageLabel")
		p.BackgroundTransparency = 1; p.Image = icon.Image; p.ImageRectOffset = icon.ImageRectOffset; p.ImageRectSize = icon.ImageRectSize
		p.ImageColor3 = icon.ImageColor3; p.ScaleType = icon.ScaleType; p.AnchorPoint = Vector2.new(0.5, 0.5)
		local sz = icon.AbsoluteSize * (0.75 + math.random() * 0.5)
		p.Size = UDim2.fromOffset(sz.X, sz.Y); p.Position = UDim2.fromOffset(from.X, from.Y); p.ZIndex = 5; p.Parent = fx
		local a = -math.pi / 2 + (math.random() - 0.5) * 2.4
		local sp = power * (0.6 + math.random() * 0.7)
		particles[#particles + 1] = { g = p, pos = from, vel = Vector2.new(math.cos(a), math.sin(a)) * sp, spin = (math.random() - 0.5) * 900,
			life = 0, max = 0.65 + math.random() * 0.3 }
	end
end

local function ring(from, size)
	local r = Instance.new("Frame")
	r.BackgroundTransparency = 1; r.AnchorPoint = Vector2.new(0.5, 0.5); r.Position = UDim2.fromOffset(from.X, from.Y)
	r.Size = UDim2.fromOffset(size.X, size.Y); r.ZIndex = 3
	local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0.5, 0); c.Parent = r
	local st = Instance.new("UIStroke"); st.Color = Color3.new(1, 1, 1); st.Thickness = math.max(3, size.Y * 0.12); st.Parent = r
	r.Parent = fx
	local info = TweenInfo.new(0.42, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
	TweenService:Create(r, info, { Size = UDim2.fromOffset(size.X * 2.1, size.Y * 2.6) }):Play()
	local t = TweenService:Create(st, info, { Transparency = 1, Thickness = 1 })
	t.Completed:Connect(function() r:Destroy() end); t:Play()
end

local function floatText(text, from, like, height)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1; l.AnchorPoint = Vector2.new(0.5, 1); l.Position = UDim2.fromOffset(from.X, from.Y)
	l.Size = UDim2.fromOffset(height * 9, height); l.Text = text; l.TextScaled = true; l.FontFace = like.FontFace
	l.TextColor3 = Color3.fromRGB(255, 255, 255); l.ZIndex = 8
	local src = like:FindFirstChildWhichIsA("UIStroke")
	local st = Instance.new("UIStroke"); st.Color = src and src.Color or Color3.new(0, 0, 0); st.Thickness = math.max(2, height * 0.09); st.Parent = l
	local sc = Instance.new("UIScale"); sc.Scale = 0.3; sc.Parent = l
	l.Parent = fx
	TweenService:Create(sc, TweenInfo.new(0.28, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	TweenService:Create(l, TweenInfo.new(0.95, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Position = UDim2.fromOffset(from.X, from.Y - height * 2.4) }):Play()
	task.delay(0.55, function()
		local info = TweenInfo.new(0.4)
		TweenService:Create(st, info, { Transparency = 1 }):Play()
		local t = TweenService:Create(l, info, { TextTransparency = 1 })
		t.Completed:Connect(function() l:Destroy() end); t:Play()
	end)
end

-- ---------------------------------------------------------------- what is in the shop
local function textOf(lbl) return lbl and (lbl:GetAttribute("FW_Text0") or lbl.Text) or "?" end
local cards, units = {}, {}        -- cards: things you buy (hover + parallax); units: blocks that pop in
for _, section in ipairs(content:GetChildren()) do
	if section:IsA("GuiObject") then
		for _, u in ipairs(section:GetChildren()) do
			if u:IsA("GuiObject") then units[#units + 1] = { g = u, s = scaleSpring(u, "k_reveal"), shown = false } end
		end
	end
end
table.sort(units, function(a, b) return a.g.AbsolutePosition.Y < b.g.AbsolutePosition.Y end)

local function shift(g)            -- a spring that moves g by pixels around where the design put it
	if not g then return nil end
	local base = g.Position
	local sx = spring({}, 0, nil, SOFT_K, SOFT_D); local sy = spring({}, 0, nil, SOFT_K, SOFT_D)
	local function apply() g.Position = base + UDim2.fromOffset(sx.x, sy.x) end
	sx.apply = apply; sy.apply = apply
	return { x = sx, y = sy }
end

local comboN, comboT = 0, 0
local function wireButton(btn, onClick)
	local s = scaleSpring(btn)
	local over = false
	btn.MouseEnter:Connect(function() over = true; to(s, 1.1, BOUNCY_K, BOUNCY_D); play("hover", 1.5 + math.random() * 0.2) end)
	btn.MouseLeave:Connect(function() over = false; to(s, 1, BOUNCY_K, BOUNCY_D) end)
	btn.MouseButton1Down:Connect(function() to(s, 0.88, 600, 30) end)
	btn.MouseButton1Up:Connect(function() to(s, over and 1.1 or 1, BOUNCY_K, 10) end)
	btn.Activated:Connect(function() s.v += 4; to(s, over and 1.1 or 1, BOUNCY_K, 10); onClick() end)
	return s
end

for _, btn in ipairs(content:GetDescendants()) do
	if btn:IsA("GuiButton") and btn.Name == "BuyButton" then
		local card = btn.Parent
		local nameLbl = card:FindFirstChild("NameLabel") or card:FindFirstChild("AmountLabel") or card:FindFirstChild("Title")
		local price = btn:FindFirstChild("PriceLabel")
		local robux = btn:FindFirstChild("RobuxIcon")
		local iconFrame = card:FindFirstChild("IconFrame")
		local c = { g = card, s = scaleSpring(card), over = false, art = shift(card:FindFirstChild("Art")),
			icon = shift(iconFrame and iconFrame:FindFirstChild("Icon")), buy = btn }
		cards[#cards + 1] = c
		local priceS = price and scaleSpring(price) or nil
		btn.MouseEnter:Connect(function()
			if robux then
				robux.Rotation = 0
				TweenService:Create(robux, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Rotation = 360 }):Play()
			end
		end)
		local function celebrate()
			local now = os.clock()
			comboN = (now - comboT < 1.2) and math.min(comboN + 1, 10) or 0; comboT = now
			play("click"); play("buy", 1 + comboN * 0.07)
			local at = centre(btn)
			if robux then burst(robux, at, 7 + math.min(comboN, 6), btn.AbsoluteSize.Y * 9) end
			ring(at, btn.AbsoluteSize)
			if price then floatText("+ " .. textOf(nameLbl), Vector2.new(at.X, btn.AbsolutePosition.Y), price, btn.AbsoluteSize.Y * 0.62) end
			if priceS then priceS.v += 7; to(priceS, 1, BOUNCY_K, 11) end
			c.s.v -= 2.2; to(c.s, c.over and 1.03 or 1, BOUNCY_K, BOUNCY_D)
		end
		effects[btn] = celebrate
		c.buyS = wireButton(btn, function() celebrate(); BuyClicked:Fire(textOf(nameLbl), textOf(price), btn) end)
	elseif btn:IsA("GuiButton") and btn.Name == "GiftButton" then
		local card = btn.Parent
		local nameLbl = card:FindFirstChild("NameLabel") or card:FindFirstChild("AmountLabel") or card:FindFirstChild("Title")
		local icon = btn:FindFirstChild("GiftIcon")
		local hop = shift(icon)
		btn.MouseEnter:Connect(function()
			if not icon then return end
			icon.Rotation = 0
			local t = TweenService:Create(icon, TweenInfo.new(0.09, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, 3, true), { Rotation = 14 })
			t:Play()
		end)
		wireButton(btn, function()
			play("click", 1.25)
			if icon and hop then
				hop.y.v = -icon.AbsoluteSize.Y * 14; to(hop.y, 0, 300, 12)
				burst(icon, centre(btn), 4, btn.AbsoluteSize.Y * 7)
			end
			GiftClicked:Fire(textOf(nameLbl), btn)
		end)
	end
end

-- ---------------------------------------------------------------- opening (the game's menu system is in charge)
-- The game opens and closes this menu itself (StarterGui.HUD.SideButtonsHUD.MenuButtons: the left
-- Shop button, OpenMenu / CloseMenu, the X). This script only plays its entrance when the shop
-- appears and leaves size, position and visibility alone, so it never fights that system
-- (an older version shrank the panel on its own close and nudged its position every frame).
local title, shopIcon, closeBtn = topBar:FindFirstChild("Title"), topBar:FindFirstChild("Icon"), topBar:FindFirstChild("CloseButton")
local titleS = title and scaleSpring(title) or nil
local iconS = shopIcon and scaleSpring(shopIcon) or nil
local isOpen = false
do -- channels left behind by the older version: back to 1
	local host = panel:FindFirstChild("FW_Scale")
	local old = host and host:FindFirstChild("k_open")
	if old then old.Value = 1 end
end

local function inView(g)
	local top, bottom = list.AbsolutePosition.Y, list.AbsolutePosition.Y + list.AbsoluteSize.Y
	local y0, y1 = g.AbsolutePosition.Y, g.AbsolutePosition.Y + g.AbsoluteSize.Y
	return y1 > top + (y1 - y0) * 0.15 and y0 < bottom - (y1 - y0) * 0.15
end
local function reveal(u, delay)
	u.shown = true
	task.delay(delay or 0, function()
		if not isOpen then return end
		u.s.v = 0; to(u.s, 1, 300, 15)
		play("hover", 1.1 + math.random() * 0.5)
	end)
end
local function checkReveals(stagger)
	if stagger then table.sort(units, function(a, b) return a.g.AbsolutePosition.Y < b.g.AbsolutePosition.Y end) end
	local n = 0
	for _, u in ipairs(units) do
		if not u.shown and inView(u.g) then reveal(u, stagger and (0.12 + n * 0.07) or 0); n += 1 end
	end
end
list:GetPropertyChangedSignal("CanvasPosition"):Connect(function() if isOpen then checkReveals(false) end end)

local function shown() return gui.Enabled and panel.Visible end
local function onShown()
	isOpen = true
	list.CanvasPosition = Vector2.zero
	for _, u in ipairs(units) do u.shown = false; u.s.x = 0.55; u.s.v = 0; u.s.t = 0.55; u.s.apply(0.55) end
	if titleS then titleS.x = 1.5; to(titleS, 1, 280, 11) end
	if iconS then iconS.x = 0.3; to(iconS, 1, 260, 9) end
	if closeBtn and closeBtn:FindFirstChild("Label") then closeBtn.Label.Rotation = 0 end
	play("open", 1.5)
	task.defer(function() RunService.RenderStepped:Wait(); checkReveals(true) end)
end
local function onHidden()
	isOpen = false
	for _, u in ipairs(units) do u.s.x = 1; u.s.v = 0; u.s.t = 1; u.s.apply(1) end      -- nothing left half-popped
end
local function watch()
	if shown() and not isOpen then onShown() elseif not shown() and isOpen then onHidden() end
end
gui:GetPropertyChangedSignal("Enabled"):Connect(watch)
panel:GetPropertyChangedSignal("Visible"):Connect(watch)
task.defer(watch)

if closeBtn then                                   -- the X only spins; closing is the game's job
	local lbl = closeBtn:FindFirstChild("Label")
	closeBtn.MouseEnter:Connect(function()
		if lbl then TweenService:Create(lbl, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Rotation = 90 }):Play() end
	end)
	closeBtn.MouseLeave:Connect(function()
		if lbl then TweenService:Create(lbl, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Rotation = 0 }):Play() end
	end)
	closeBtn.Activated:Connect(function() play("close", 0.9) end)
end

-- ---------------------------------------------------------------- every frame
local idleT = 0
RunService.RenderStepped:Connect(function(dt)
	dt = math.min(dt, 1 / 30)
	if isOpen then
		local m = UIS:GetMouseLocation()
		-- cards: lift under the mouse, art slides away from it, the icon toward it
		local inList = m.Y > list.AbsolutePosition.Y and m.Y < list.AbsolutePosition.Y + list.AbsoluteSize.Y
		for _, c in ipairs(cards) do
			local p, sz = c.g.AbsolutePosition, c.g.AbsoluteSize
			local over = inList and m.X > p.X and m.X < p.X + sz.X and m.Y > p.Y and m.Y < p.Y + sz.Y
			if over ~= c.over then
				c.over = over
				to(c.s, over and 1.03 or 1, BOUNCY_K, BOUNCY_D)
				if over then play("hover", 0.9) end
			end
			local nx = over and math.clamp((m.X - p.X) / sz.X * 2 - 1, -1, 1) or 0
			local ny = over and math.clamp((m.Y - p.Y) / sz.Y * 2 - 1, -1, 1) or 0
			if c.art then to(c.art.x, -nx * sz.X * 0.012); to(c.art.y, -ny * sz.Y * 0.03) end
			if c.icon then to(c.icon.x, nx * sz.X * 0.03); to(c.icon.y, ny * sz.Y * 0.05) end
		end
		-- now and then a buy button you are not pointing at gives a little hop
		idleT += dt
		if idleT > 4.5 and #cards > 0 then
			idleT = 0
			local c = cards[math.random(#cards)]
			if not c.over and inView(c.g) then c.buyS.v += 3.2; to(c.buyS, 1, BOUNCY_K, 12) end
		end
	end
	for s in pairs(active) do
		local a = s.k * (s.t - s.x) - s.d * s.v
		s.v += a * dt; s.x += s.v * dt
		if math.abs(s.v) < 0.002 and math.abs(s.t - s.x) < 0.0005 then s.x = s.t; s.v = 0; active[s] = nil end
		if s.apply then s.apply(s.x) end
	end
	for i = #particles, 1, -1 do
		local p = particles[i]
		p.life += dt
		p.vel += Vector2.new(0, 1900 * dt)
		p.pos += p.vel * dt
		local k = p.life / p.max
		p.g.Position = UDim2.fromOffset(p.pos.X, p.pos.Y); p.g.Rotation += p.spin * dt
		p.g.ImageTransparency = math.clamp((k - 0.55) / 0.45, 0, 1)
		if k >= 1 then p.g:Destroy(); table.remove(particles, i) end
	end
end)
PlayBuyEffect.Event:Connect(function(btn) local f = effects[btn]; if f then f() end end)