-- REMOVED from the game 2026-11-11 (pigeon: "remove loading screen pls"). Kept inactive in ServerStorage.Restyle.LoadingScreen; move it back to ReplicatedFirst to use it.
-- LoadingScreen (pigeon-claude, 11 Nov 2026). ReplicatedFirst, so it shows before anything else has loaded.
-- The screen itself is the LoadingGui under this script, made of real frames (StarterGui would load too late
-- to cover the join). This script only shows it, animates it and fills the bar from real loading progress:
-- game.Loaded, ContentProvider's download queue, and your character. It stays at least MIN_TIME, then fades out.
local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local ContentProvider = game:GetService("ContentProvider")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local MIN_TIME = 3          -- seconds the screen stays at least
local SKIP_AFTER = 6        -- the SKIP button shows after this long
local TIPS = {
	"TIP: Hit PERFECT for a slow-mo super kick!",
	"TIP: Lift weights to get stronger kicks!",
	"TIP: Tap the circle while lifting to lift faster!",
	"TIP: Place animals on your base to earn cash!",
	"TIP: Stronger kicks beat tougher eggs!",
	"TIP: Rebirth for more cash and speed!",
}

local player = Players.LocalPlayer
local StarterGui = game:GetService("StarterGui")
local gui = script:WaitForChild("LoadingGui"):Clone()
gui.Parent = player:WaitForChild("PlayerGui")
ReplicatedFirst:RemoveDefaultLoadingScreen()
-- the screen's own pictures first, so no egg pops in late
task.spawn(function() pcall(ContentProvider.PreloadAsync, ContentProvider, {gui}) end)
-- chat and the player list stay hidden until the screen is gone (put back the way they were)
local hiddenCore = {}
for _, t in {Enum.CoreGuiType.Chat, Enum.CoreGuiType.PlayerList} do
	local ok, on = pcall(StarterGui.GetCoreGuiEnabled, StarterGui, t)
	if ok and on and pcall(StarterGui.SetCoreGuiEnabled, StarterGui, t, false) then table.insert(hiddenCore, t) end
end
local function restoreCore()
	for _, t in hiddenCore do pcall(StarterGui.SetCoreGuiEnabled, StarterGui, t, true) end
end

local root = gui.Root
local sun, title, fill, pct, tip, skip = root.Sunburst, root.Title, root.Bar.Fill, root.Bar.Percent, root.Tip, root.SkipButton
local fillFull = 0.976      -- the fill's width at 100% (it starts 0.012 in from the backdrop's edge)
local eggs = {}
for _, slot in root.Eggs:GetChildren() do
	if slot:IsA("Frame") then table.insert(eggs, {img = slot.Egg, shadow = slot.Shadow, order = slot.LayoutOrder}) end
end
table.sort(eggs, function(a, b) return a.order < b.order end)

-- outlines are set in pixels for a 1080p screen: keep them the same thickness on any screen
local strokes = {}
for _, s in root:GetDescendants() do
	if s:IsA("UIStroke") and s:GetAttribute("BaseThickness") then table.insert(strokes, s) end
end
local function scaleStrokes()
	local h = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize.Y or 1080
	for _, s in strokes do s.Thickness = s:GetAttribute("BaseThickness") * h / 1080 end
end
scaleStrokes()
if workspace.CurrentCamera then workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(scaleStrokes) end

local start = os.clock()
local skipped = false
skip.Activated:Connect(function() skipped = true end)

local tipIndex = math.random(#TIPS)
tip.Text = TIPS[tipIndex]
task.spawn(function()
	while gui.Parent do
		task.wait(2.6)
		tipIndex = tipIndex % #TIPS + 1
		tip.Text = TIPS[tipIndex]
	end
end)

local maxQueue = 1
local shown = 0
local finishing = false
local conn
local function finish()
	if finishing then return end
	finishing = true
	pct.Text = "LET'S PLAY!"
	fill.Size = UDim2.new(fillFull, 0, fill.Size.Y.Scale, 0)
	task.wait(0.35)
	local t = TweenService:Create(root, TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {GroupTransparency = 1})
	t:Play()
	t.Completed:Wait()
	if conn then conn:Disconnect() end
	restoreCore()
	gui:Destroy()
	script:Destroy()
end

conn = RunService.RenderStepped:Connect(function(dt)
	local t = os.clock() - start
	sun.Rotation = (sun.Rotation + dt * 14) % 360
	title.Rotation = -3 + math.sin(t * 1.6) * 1.5
	-- the eggs hop one after another, their shadows shrink as they go up
	for i, e in eggs do
		local h = math.max(0, math.sin(t * 4 - i * 0.7))
		h = h * h
		e.img.Position = UDim2.fromScale(0.5, 1 - 0.28 * h)
		e.img.Rotation = math.sin(t * 4 - i * 0.7) * 6
		e.shadow.Size = UDim2.fromScale(0.6 - 0.25 * h, 0.1 - 0.04 * h)
	end
	if t > SKIP_AFTER and not skip.Visible then skip.Visible = true end
	if finishing then return end

	local queue = ContentProvider.RequestQueueSize
	maxQueue = math.max(maxQueue, queue)
	local downloaded = 1 - queue / maxQueue
	local ready = game:IsLoaded() and player.Character ~= nil and queue == 0
	-- real progress: half for the place arriving, half for its downloads; never ahead of the minimum time
	local target = (game:IsLoaded() and 0.5 or 0.25) + 0.5 * downloaded * (game:IsLoaded() and 1 or 0.5)
	if ready then target = 1 end
	target = math.min(target, t / MIN_TIME)
	shown += (target - shown) * math.min(1, dt * 5)
	fill.Size = UDim2.new(math.max(0.05, shown * fillFull), 0, fill.Size.Y.Scale, 0)
	pct.Text = "LOADING... " .. math.floor(shown * 100 + 0.5) .. "%"
	if workspace:GetAttribute("HoldLoadingScreen") then return end   -- dev only: keep it up to check the look
	if skipped or (ready and t >= MIN_TIME and shown > 0.985) then task.spawn(finish) end
end)
