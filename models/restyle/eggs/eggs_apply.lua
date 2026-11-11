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
-- Where things live (kept tidy, 2026-11-10):
--   ServerStorage.Restyle.Backups   the ORIGINAL eggs (EggsBackup_BeforeRestyle, BaseEggsBackup_BeforeRestyle)
--   ServerStorage.Restyle.Old       replaced versions (safe to delete)
--   ServerStorage.Restyle.Imports   the imported source models, moved here after the swap
--   Workspace.RestylePreviews       previews to look at (not part of the game)
local function sub(parent, name)
	local f = parent:FindFirstChild(name)
	if not f then f = Instance.new("Folder"); f.Name = name; f.Parent = parent end
	return f
end
local Restyle = sub(game:GetService("ServerStorage"), "Restyle")
local Backups, OldF, ImportsF = sub(Restyle, "Backups"), sub(Restyle, "Old"), sub(Restyle, "Imports")

-- The eggs come in several files (Eggs_1 .. Eggs_5; one big file made Import 3D time out), so
-- every imported model whose name starts with "Eggs" is used. Their parts are gathered into one.
local imps = {}
local function isImport(c) return c:IsA("Model") and (c.Name:find("^NewEggs") or c.Name:find("^Eggs_")) end
for _, c in ipairs(workspace:GetChildren()) do
	if isImport(c) and c:FindFirstChild("SOA_AxisO", false) ~= nil then imps[#imps + 1] = c end
end
for _, c in ipairs(workspace:GetChildren()) do
	if isImport(c) and not table.find(imps, c) then
		for _, p in ipairs(c:GetChildren()) do if p.Name:find("^EGG_") then imps[#imps + 1] = c; break end end
	end
end
assert(#imps > 0, "import the egg files first (Home > Import 3D > Desktop\\ROBLOX IMPORT)")
for _, m in ipairs(imps) do
-- 1. undo the importer's scale and rotation, using the three marker cubes (only once)
if m:FindFirstChild("SOA_AxisO") then
	local imp = m
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
end
local parts = {}
for _, m in ipairs(imps) do for _, p in ipairs(m:GetChildren()) do parts[#parts + 1] = p end end

-- 2. check every imported part: known id, right size. And check the MESH DATA faces the right way:
--    ApplyMesh copies the mesh as it is stored, whatever way the imported part is turned in the
--    world, so the part's own rotation says nothing. Instead the mesh is read back (these meshes
--    are ours, so EditableMesh may load them) and "which way it leans" is compared with the
--    manifest: the average corner position as a fraction of the size, per axis.
local new, problems, turned, tested = {}, {}, 0, 0
local AS = game:GetService("AssetService")
for _, p in ipairs(parts) do
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
	-- how big this egg is compared with the mesh's own units (eggs in the folders are all scale 1,
	-- but be safe): old part size / old mesh size
	local s = egg.Size.Y / m.old.Y
	egg:ApplyMesh(src)
	egg.Size = size
	if m.off then
		-- New-feature eggs: the shell is unchanged, but taller ears / horns move the part's centre.
		-- Everything that was placed relative to the shell (EggCenter, VFXShell) moves back with it.
		local off = m.off * s
		for _, c in ipairs(egg:GetChildren()) do
			if c:IsA("Attachment") then c.Position -= off
			elseif c:IsA("BasePart") and c.Name == "VFXShell" then c.CFrame = egg.CFrame * (egg.CFrame:ToObjectSpace(c.CFrame) * CFrame.new(-off)) end
		end
	else
		local k = (ratio.X + ratio.Y + ratio.Z) / 3
		for _, c in ipairs(egg:GetChildren()) do
			if c:IsA("BasePart") and c.Name == "VFXShell" then c.Size = c.Size * k end
		end
	end
	-- eyes for eggs whose texture has no white / black (pony): small welded blocks, like the welded
	-- VFXShell the eggs already carry. Mutation eggs that are one plain colour get them in that colour.
	for _, c in ipairs(egg:GetChildren()) do if c.Name == "FacePart" then c:Destroy() end end
	for _, fp in ipairs(m.face or {}) do
		local p = Instance.new("Part")
		p.Name = "FacePart"; p.Size = Vector3.new(fp[4], fp[5], fp[6]) * s
		p.CFrame = egg.CFrame * CFrame.new(Vector3.new(fp[1], fp[2], fp[3]) * s)
		p.Material = Enum.Material.SmoothPlastic
		p.Anchored = egg.Anchored; p.CanCollide = false; p.CanQuery = false; p.CanTouch = false; p.Massless = true
		p.TopSurface = Enum.SurfaceType.Smooth; p.BottomSurface = Enum.SurfaceType.Smooth
		if egg:FindFirstChildWhichIsA("SurfaceAppearance") then
			p.Color = (fp[7] == "white") and Color3.fromRGB(245, 245, 245) or Color3.fromRGB(20, 20, 24)
		else
			p.Color = (fp[7] == "white") and egg.Color:Lerp(Color3.new(1, 1, 1), 0.35) or egg.Color:Lerp(Color3.new(0, 0, 0), 0.55)
			p.Material = egg.Material; p.Reflectance = egg.Reflectance
		end
		local w = Instance.new("WeldConstraint"); w.Part0 = egg; w.Part1 = p; w.Parent = p
		p.Parent = egg
	end
end

if MODE == "check" then
	local PV = sub(workspace, "RestylePreviews")
	local old = PV:FindFirstChild("EggSwapPreview") or workspace:FindFirstChild("EggSwapPreview"); if old then old:Destroy() end
	local pv = Instance.new("Model"); pv.Name = "EggSwapPreview"
	local x = 0
	-- the manifest is keyed by the ORIGINAL mesh ids, so preview from the untouched backup when there is one
	local from = Backups:FindFirstChild("BaseEggsBackup_BeforeRestyle") or Eggs.GoldEggs
	for _, name in ipairs({ "Bunny", "Wolf", "Albatross", "Dragon", "Pony", "Lion", "Whale", "Parrot" }) do
		local src = from:FindFirstChild(name)
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
	pv.Parent = PV
	return head .. " | preview built in Workspace.RestylePreviews.EggSwapPreview (old then new, per egg). Nothing in ReplicatedStorage changed.\n" .. table.concat(problems, "\n", 1, math.min(#problems, 8))
end

-- 3. apply: back up once, then swap every egg part that uses one of the meshes
--    Two places hold eggs: ReplicatedStorage.Assets.Eggs (the five mutation folders) and
--    ServerStorage.BaseEggs (what the game's scripts use). Every mutation folder shares the base
--    eggs' meshes, so swapping by mesh id gives every mutation the new model with its own look kept.
--    The manifest is keyed by the ORIGINAL mesh ids: if an earlier restyle is in the game, the
--    originals are put back from the backups first (the replaced folder is kept in ServerStorage).
local SS = game:GetService("ServerStorage")
local function prog(s) workspace:SetAttribute("EggSwapProgress", s) end
local log = {}
local function original(folder, backupName, keepName)
	local bk = Backups:FindFirstChild(backupName)
	if not bk then
		local b = folder:Clone(); b.Name = backupName; b.Parent = Backups
		return folder
	end
	local same = true                                   -- already the originals?
	for _, e in ipairs(folder:GetDescendants()) do
		if e:IsA("MeshPart") and e.Name ~= "VFXShell" then
			local o = bk:FindFirstChild(e.Name, true)
			if o and o:IsA("MeshPart") and o.MeshId ~= e.MeshId then same = false; break end
		end
	end
	if same then return folder end
	-- nothing may be lost: the backup must hold every egg the folder has now
	local names = {}
	local function rel(e, root) return (e.Parent == root and "" or e.Parent.Name) .. "/" .. e.Name end      -- path inside the folder (the two folders have different names)
	for _, e in ipairs(bk:GetDescendants()) do if e:IsA("MeshPart") then names[rel(e, bk)] = true end end
	for _, e in ipairs(folder:GetDescendants()) do
		if e:IsA("MeshPart") and e.Name ~= "VFXShell" and not names[rel(e, folder)] then
			error(folder:GetFullName() .. " has an egg the backup does not (" .. rel(e, folder) .. "): stopped before touching this folder")
		end
	end
	local fresh = bk:Clone(); fresh.Name = folder.Name
	local parent = folder.Parent
	local oldKeep = OldF:FindFirstChild(keepName); if oldKeep then oldKeep:Destroy() end
	folder.Name = keepName; folder.Parent = OldF
	fresh.Parent = parent
	log[#log + 1] = "originals restored into " .. fresh:GetFullName() .. " (replaced folder kept as ServerStorage.Restyle.Old." .. keepName .. ")"
	return fresh
end
prog("restoring originals")
local targets = { original(Eggs, "EggsBackup_BeforeRestyle", "Eggs_GentleRestyle_Old") }
if SS:FindFirstChild("BaseEggs") then targets[#targets + 1] = original(SS.BaseEggs, "BaseEggsBackup_BeforeRestyle", "BaseEggs_GentleRestyle_Old") end
local swapped, skipped, failed, tinted = 0, {}, {}, 0
-- eggs with no new model get a slight colour shift instead (base eggs only; pigeon: "maybe slight
-- color change on some"). Special eggs are left alone.
local TINTS = { Color3.fromRGB(255, 232, 208), Color3.fromRGB(214, 232, 255), Color3.fromRGB(255, 222, 236), Color3.fromRGB(226, 255, 226) }
local NO_TINT = { Hacker = true, Inverted = true, CrystalCandy = true }
for _, root in ipairs(targets) do
	local list = root:GetDescendants()
	for i, egg in ipairs(list) do
		if egg:IsA("MeshPart") and egg.Name ~= "VFXShell" and egg.Name ~= "FacePart" then
			local id = egg.MeshId:match("%d+")
			if id and new[id] then
				local ok, err = pcall(swap, egg, new[id], MAN[id])
				if ok then swapped += 1 else failed[#failed + 1] = egg:GetFullName() .. ": " .. tostring(err) end
				task.wait()                                  -- one egg per frame: Studio stays responsive
			else
				skipped[egg.Name] = true
				local sa = egg:FindFirstChildWhichIsA("SurfaceAppearance")
				if root.Name == "BaseEggs" and sa and not NO_TINT[egg.Name] and sa.Color == Color3.new(1, 1, 1) then
					local h = 0
					for k = 1, #egg.Name do h = (h * 31 + egg.Name:byte(k)) % 9973 end
					sa.Color = TINTS[h % #TINTS + 1]; tinted += 1
				end
			end
			if i % 25 == 0 then prog(string.format("%s %d/%d, swapped %d", root.Name, i, #list, swapped)); task.wait() end
		end
	end
end
-- the imported source models are no longer needed in the world: file them away
if #failed == 0 then
	for _, m in ipairs(imps) do m.Parent = ImportsF end
	log[#log + 1] = #imps .. " imported models moved to ServerStorage.Restyle.Imports"
end
local sk = {}
for n in pairs(skipped) do sk[#sk + 1] = n end
table.sort(sk)
local res = string.format("%s | swapped %d egg parts | failed %d | tinted %d | %s\nno new model (%d): %s\n%s", head, swapped, #failed, tinted,
	table.concat(log, "; "), #sk, table.concat(sk, ","), table.concat(failed, "\n", 1, math.min(#failed, 8)))
prog("DONE " .. res:sub(1, 900))
return res
