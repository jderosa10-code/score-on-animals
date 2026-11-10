-- Swaps the restyled egg meshes (Eggs_NEW.fbx, imported with Home > Import 3D) into
-- ReplicatedStorage.Assets.Eggs. Run in the Studio edit context:
--     loadstring(applySrc)(loadstring(manifestSrc)(), "check")    -- look first, changes nothing in the game
--     loadstring(applySrc)(loadstring(manifestSrc)(), "apply")    -- back up, then swap every egg
-- manifest = eggs_manifest.lua: [MeshId] = { name, size (new, studs), old (size before) }
--
-- How it works: every imported part is named EGG_<MeshId of the egg it replaces>. All five egg
-- folders share the same 196 meshes, so each imported part is applied (MeshPart:ApplyMesh) to every
-- egg part that uses that MeshId. ApplyMesh keeps the part itself: its children (Studs textures,
-- VFXShell, EggCenter, SurfaceAppearance), colour, material and name all stay.
--   * "check" fixes the import's size/rotation, verifies every part against the manifest, and builds
--     Workspace.EggSwapPreview (old | new for a few eggs). ReplicatedStorage is not touched.
--   * "apply" first clones the whole Eggs folder to ServerStorage.EggsBackup_BeforeRestyle (once),
--     then swaps. To undo: delete Assets.Eggs and move the backup back.
-- The meshes were exported with Roblox axes baked in. If an imported part is still turned after the
-- marker fix, its mesh would come out sideways on the eggs, so the script stops instead of applying.
local MAN, MODE = ...
assert(MAN, "pass the table from eggs_manifest.lua")
MODE = MODE or "check"
local Eggs = game.ReplicatedStorage.Assets.Eggs

local imp
for _, c in ipairs(workspace:GetChildren()) do if c:IsA("Model") and c.Name:find("^Eggs_NEW") then imp = c end end
assert(imp, "import the FBX first (Home > Import 3D > Eggs_NEW.fbx)")

-- 1. undo the importer's scale and rotation, using the three marker cubes (only once)
if imp:FindFirstChild("SOA_AxisO") then
	local function axis(v)
		local a = Vector3.new(math.abs(v.X), math.abs(v.Y), math.abs(v.Z))
		if a.X >= a.Y and a.X >= a.Z then return Vector3.new(math.sign(v.X), 0, 0) end
		if a.Y >= a.Z then return Vector3.new(0, math.sign(v.Y), 0) end
		return Vector3.new(0, 0, math.sign(v.Z))
	end
	local d = (imp.SOA_AxisUp.Position - imp.SOA_AxisO.Position).Magnitude
	imp:ScaleTo(imp:GetScale() * 3 / d)
	local O, Up, Fw = imp.SOA_AxisO, imp.SOA_AxisUp, imp.SOA_AxisFwd
	local U, F = axis(Up.Position - O.Position), axis(Fw.Position - O.Position)
	local C = CFrame.fromMatrix(Vector3.zero, U:Cross(-F), U, -F)
	imp.PrimaryPart = O
	imp:SetPrimaryPartCFrame(CFrame.new(O.Position) * C:Inverse() * O.CFrame.Rotation)
	for _, mk in ipairs({ O, Up, Fw }) do mk:Destroy() end
end

-- 2. check every imported part: known id, not turned, right size
local new, problems, turned = {}, {}, 0
for _, p in ipairs(imp:GetChildren()) do
	local id = p:IsA("MeshPart") and p.Name:match("^EGG_(%d+)")
	if id then
		local m = MAN[id]
		if not m then
			problems[#problems + 1] = p.Name .. ": not in the manifest"
		else
			local r = p.CFrame.Rotation
			local off = (r.XVector - Vector3.xAxis).Magnitude + (r.YVector - Vector3.yAxis).Magnitude + (r.ZVector - Vector3.zAxis).Magnitude
			if off > 0.02 then turned += 1 end
			local ds = (p.Size - m.size).Magnitude
			if ds > 0.05 then problems[#problems + 1] = string.format("%s (%s): size %s, expected %s", p.Name, m.name, tostring(p.Size), tostring(m.size)) end
			new[id] = p
		end
	end
end
local count = 0
for _ in pairs(new) do count += 1 end
local head = string.format("imported eggs %d | turned parts %d | size problems %d", count, turned, #problems)
if turned > 0 then
	return head .. "\nSTOPPED: imported parts are still turned after the marker fix, so their meshes would sit sideways on the eggs. Nothing was changed.\n" .. table.concat(problems, "\n", 1, math.min(#problems, 8))
end

local function swap(egg, src, m)
	local ratio = m.size / m.old
	local size = egg.Size * ratio
	egg:ApplyMesh(src)
	egg.Size = size
	local k = (ratio.X + ratio.Y + ratio.Z) / 3
	for _, c in ipairs(egg:GetChildren()) do
		if c:IsA("BasePart") and c.Name == "VFXShell" then c.Size = c.Size * k end
	end
end

if MODE == "check" then
	local old = workspace:FindFirstChild("EggSwapPreview"); if old then old:Destroy() end
	local pv = Instance.new("Model"); pv.Name = "EggSwapPreview"
	local x = 0
	for _, name in ipairs({ "Bunny", "Akita", "Cat", "Bear", "Jellyfish", "Moose" }) do
		local src = Eggs.GoldEggs:FindFirstChild(name)
		local id = src and src.MeshId:match("%d+")
		if src and new[id] then
			for k = 1, 2 do
				local c = src:Clone(); c.Anchored = true; c.Name = name .. (k == 1 and "_OLD" or "_NEW")
				if k == 2 then swap(c, new[id], MAN[id]) end
				c.CFrame = CFrame.new(-40 + x, c.Size.Y / 2 + 0.05, 150) * src.CFrame.Rotation
				c.Parent = pv
				x += (k == 1) and 9 or 14
			end
		end
	end
	pv.Parent = workspace
	return head .. " | preview built in Workspace.EggSwapPreview (old then new, per egg). Nothing in ReplicatedStorage changed.\n" .. table.concat(problems, "\n", 1, math.min(#problems, 8))
end

-- 3. apply: back up once, then swap every egg part that uses one of the meshes
local SS = game:GetService("ServerStorage")
if not SS:FindFirstChild("EggsBackup_BeforeRestyle") then
	local b = Eggs:Clone(); b.Name = "EggsBackup_BeforeRestyle"; b.Parent = SS
end
local swapped, skipped, failed = 0, {}, {}
for i, egg in ipairs(Eggs:GetDescendants()) do
	if egg:IsA("MeshPart") then
		local id = egg.MeshId:match("%d+")
		if id and new[id] then
			local ok, err = pcall(swap, egg, new[id], MAN[id])
			if ok then swapped += 1 else failed[#failed + 1] = egg:GetFullName() .. ": " .. tostring(err) end
		elseif egg.Name ~= "VFXShell" then
			skipped[egg.Name] = true
		end
		if i % 100 == 0 then task.wait() end
	end
end
local sk = {}
for n in pairs(skipped) do sk[#sk + 1] = n end
return string.format("%s | swapped %d egg parts | failed %d | left as they were: %s\n%s", head, swapped, #failed, table.concat(sk, ","), table.concat(failed, "\n", 1, math.min(#failed, 8)))
