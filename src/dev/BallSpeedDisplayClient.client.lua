-- Workspace.BallSpeedDisplay (dev display next to the map, Jacob 11 Nov 2026): each lane kicks a ball over the
-- same distance as a real penalty, at the speed and arc a kick of that Strength gets (GameConfig.ballSpeed /
-- ballArc). Change the numbers in GameConfig and the lanes follow. Runs on each client so it's smooth.
-- Lives in StarterPlayer.StarterPlayerScripts.BallSpeedDisplayClient. The model (5 lanes: Strength 10, 100, 1K,
-- 5K, 18.7K, 74-stud lanes, east of the map at x -195..-131, z -60..14) is built in Studio.
local RunService = game:GetService("RunService")
local G = require(game:GetService("ReplicatedStorage"):WaitForChild("GameConfig"))
local display = workspace:WaitForChild("BallSpeedDisplay", 30)
if not display then return end

-- lanes are picked up as they stream in (and dropped if they stream out)
local lanes = {}
local function scan()
	for _, lane in display:GetChildren() do
		local s = lane:GetAttribute("Strength")
		local ball, start, bar = lane:FindFirstChild("Ball"), lane:FindFirstChild("Start"), lane:FindFirstChild("Bar")
		local sign = lane:FindFirstChild("Sign")
		local label = sign and sign:FindFirstChild("Gui") and sign.Gui:FindFirstChild("Label")
		if s and ball and start and bar and not (lanes[lane] and lanes[lane].ball == ball) then
			local from = start.Position + Vector3.new(0, 0.9, 0)
			lanes[lane] = {s = s, ball = ball, from = from, to = Vector3.new(from.X, 5, bar.Position.Z + 1), t = 0, wait = 0, label = label}
		end
	end
	for lane, l in lanes do if not l.ball.Parent then lanes[lane] = nil end end
end
task.spawn(function() while true do scan() task.wait(1) end end)

RunService.RenderStepped:Connect(function(dt)
	for _, l in lanes do
		local speed, arc = G.ballSpeed(l.s), G.ballArc(l.s)
		if l.label then l.label.Text = "STRENGTH " .. G.short(l.s) .. "\n" .. math.floor(speed + 0.5) .. " studs/s" end
		local dur = (l.to - l.from).Magnitude / speed
		if l.wait > 0 then
			l.wait -= dt
			if l.wait <= 0 then l.t = 0 end
		else
			l.t += dt
			local a = math.min(1, l.t / dur)
			-- same curve as the penalty's flyShot: a quadratic with its control point arc*2 above the middle
			local ctrl = l.from:Lerp(l.to, 0.5) + Vector3.new(0, arc * 2, 0)
			local u = 1 - a
			l.ball.CFrame = CFrame.new(l.from * (u * u) + ctrl * (2 * u * a) + l.to * (a * a)) * CFrame.Angles(-l.t * 12, 0, 0)
			if a >= 1 then l.wait = 1.2 end
		end
	end
end)
