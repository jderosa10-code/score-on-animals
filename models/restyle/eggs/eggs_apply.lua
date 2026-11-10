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

-- 2. check every imported part: known id, right size. And check the MESH DATA faces the right way:
--    ApplyMesh copies the mesh as it is stored, whatever way the imported part is turned in the
--    world, so the part's own rotation says nothing. Instead the mesh is read back (these meshes
--    are ours, so EditableMesh may load them) and "which way it leans" is compared with the
--    manifest: the average corner position as a fraction of the size, per axis.
local new, problems, turned, tested = {}, {}, 0, 0
local AS = game:GetService("AssetService")
for _, p in ipairs(imp:GetChildren()) do
	local id = p:IsA("MeshPart") and p.Name:match("^EGG_(%d+)")
	if id then
		local m = MAN[id]
		if not m then
			problems[#problems + 1] = p.Name .. ": not in the manifest"
		else
			local ds = (p.Size - m.size).Magnitude
			if ds > 0.05 then problems[#problems + 1] = string.format("%s (%s): size %s, expected %s", p.Name, m.name, tostring(p.Size), tostring(m.size)) end
			new[id] = p
			if m.lean and tested < 24 and math.max(math.abs(m.lean.X), math.abs(m.lean.Z)) > 0.04 then
				tested += 1
				local em = AS:CreateEditableMeshAsync(Content.fromUri(p.MeshId))
				local mn, mx, sum, n = Vector3.one * math.huge, Vector3.one * -math.huge, Vector3.zero, 0
				for _, v in ipairs(em:GetVertices()) do
					local q = em:GetPosition(v)
					mn = mn:Min(q); mx = mx:Max(q); sum += q; n += 1
				end
				local s, c = mx - mn, sum / n - (mn + mx) / 2
				local got = Vector3.new(c.X / s.X, c.Y / s.Y, c.Z / s.Z)
				if (got - m.lean).Magnitude > 0.03 then
					turned += 1
					problems[#problems + 1] = string.format("%s (%s): mesh leans %s, expected %s", p.Name, m.name, tostring(got), tostring(m.lean))
				end
				em:Destroy()
			end
		end
	end
end
local count = 0
for _ in pairs(new) do count += 1 end
local head = string.format("imported eggs %d | meshes read back %d, facing wrong %d | problems %d", count, tested, turned, #problems)
if turned > 0 or tested == 0 then
	return head .. "\nSTOPPED: the mesh data does not face the way the game's eggs do (or could not be read back), so the eggs would come out turned. Nothing was changed.\n" .. table.concat(problems, "\n", 1, math.min(#problems, 8))
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
