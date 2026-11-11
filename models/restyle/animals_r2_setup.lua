-- Round 2 animals in Studio (edit context). Run with one argument, the mode:
--   "rebuild"    Restyle_R2_A / Restyle_R2_B (Home > Import 3D) replace every "<Name> NEW" in
--                Workspace.RestyleShowcase. Looks (SurfaceAppearance, Studs) are copied from the
--                round-1 NEW part of the same kind, or from the OLD animal if there is none.
--   "mutations"  every "<Name> NEW" gets a Base copy and five mutation copies (Gold, Diamond,
--                Rainbow, Inverted, Hacked) in ServerStorage.AnimalsRestyled.<Folder>.<Name>, and
--                Workspace.MutationPreview is rebuilt for a few animals (old next to new).
-- Facts this relies on (checked 2026-11-10):
--   * after the marker fix 1 unit = 1 stud and the pack is already at game size (pack_dims.json
--     equals the OLD part sizes), so no extra scaling
--   * a mutation in Assets.Animals.<X>Animals is the base rigged model plus layers on its MeshPart:
--     SurfaceAppearance (tinted), Studs / extra Texture, an empty Attachment. The restyle keeps the
--     original UVs, so the layers fit the new shapes unchanged.
--   * these copies are STATIC (no bones). They live in ServerStorage so they don't add to what
--     every player downloads until they can actually be used.
local MODE = ...
local S = workspace.RestyleShowcase
local out = {}

local function bounds(parts)
	local mn, mx = Vector3.one * math.huge, Vector3.one * -math.huge
	for _, p in ipairs(parts) do
		local c, s = p.CFrame, p.Size / 2
		for x = -1, 1, 2 do for y = -1, 1, 2 do for z = -1, 1, 2 do
			local v = (c * CFrame.new(s.X * x, s.Y * y, s.Z * z)).Position
			mn = mn:Min(v); mx = mx:Max(v)
		end end end
	end
	return mn, mx
end
local function partsOf(m)
	local t = {}
	for _, p in ipairs(m:GetDescendants()) do if p:IsA("BasePart") then t[#t + 1] = p end end
	return t
end
local function facing(parts)     -- flat direction from the body's middle to the eyes' middle
	local body, eyes
	for _, p in ipairs(parts) do
		if p.Name:find("_Body") then body = p elseif p.Name:find("_Eyes") then eyes = p end
	end
	if not (body and eyes) then return nil end
	local d = (eyes.Position - body.Position) * Vector3.new(1, 0, 1)
	return d.Magnitude > 0.05 and d.Unit or nil
end
local function turnAbout(parts, pivot, angle)
	local r = CFrame.new(pivot) * CFrame.Angles(0, angle, 0) * CFrame.new(-pivot)
	for _, p in ipairs(parts) do p.CFrame = r * p.CFrame end
end
local function moveBy(parts, delta)
	for _, p in ipairs(parts) do p.CFrame = p.CFrame + delta end
end

if MODE == "rebuild" then
	-- 1. undo the importer's scale and rotation on each import (markers), collect parts by pack name
	local byPack = {}
	for _, mn in ipairs({ "Restyle_R2_A", "Restyle_R2_B" }) do
		local imp = workspace:FindFirstChild(mn)
		if imp then
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
			for _, p in ipairs(imp:GetChildren()) do
				local pack = p:IsA("MeshPart") and p.Name:match("^(.-)_NEW_")
				if pack then byPack[pack] = byPack[pack] or {}; table.insert(byPack[pack], p) end
			end
		end
	end
	-- 2. how the imports are turned compared with the animals already standing in the showcase
	local votes = {}
	for _, slot in ipairs(S:GetChildren()) do
		if slot.Name:find("^Slot_") then
			local cur = S:FindFirstChild(slot.Name:sub(6) .. " NEW")
			local parts = byPack[slot:GetAttribute("PackName") or ""]
			local a, b = cur and facing(partsOf(cur)), parts and facing(parts)
			if a and b then
				local bestQ, bestDot = 0, -2          -- which quarter turn brings the import's facing onto the old one
				for q = 0, 3 do
					local rb = CFrame.Angles(0, q * math.pi / 2, 0):VectorToWorldSpace(b)
					if rb:Dot(a) > bestDot then bestQ, bestDot = q, rb:Dot(a) end
				end
				votes[bestQ] = (votes[bestQ] or 0) + 1
			end
		end
	end
	local quarter, best = 0, -1
	for q, n in pairs(votes) do if n > best then quarter, best = q, n end end
	local vs = {}
	for q, n in pairs(votes) do vs[#vs + 1] = (q * 90) .. "deg x" .. n end
	out[#out + 1] = "turn needed (votes): " .. table.concat(vs, ", ")
	-- 3. build each new model on its slot
	local done, nolook, skipped = 0, {}, {}
	for i, slot in ipairs(S:GetChildren()) do
		if slot.Name:find("^Slot_") then
			local name = slot.Name:sub(6)
			local parts = byPack[slot:GetAttribute("PackName") or ""]
			if not parts then
				skipped[#skipped + 1] = name
			else
				local cur = S:FindFirstChild(name .. " NEW")
				local oldM = S:FindFirstChild(name .. " OLD")
				local oldPart = oldM and oldM:FindFirstChildWhichIsA("MeshPart")
				local mn, mx = bounds(parts)
				turnAbout(parts, (mn + mx) / 2, quarter * math.pi / 2)
				mn, mx = bounds(parts)
				moveBy(parts, Vector3.new(slot.Position.X, slot.Position.Y, slot.Position.Z) - Vector3.new((mn.X + mx.X) / 2, mn.Y, (mn.Z + mx.Z) / 2))
				local m = Instance.new("Model"); m.Name = name .. " NEW"
				for _, p in ipairs(parts) do
					local kind = p.Name:match("_NEW(_%a+)")
					local like
					if cur then for _, q in ipairs(cur:GetChildren()) do if q:IsA("MeshPart") and q.Name:find(kind .. "$") then like = q end end end
					p.Anchored = true; p.CanCollide = false
					if like then
						for _, c in ipairs(like:GetChildren()) do c:Clone().Parent = p end
						p.Color = like.Color; p.Material = like.Material; p.Reflectance = like.Reflectance
					elseif oldPart then
						for _, c in ipairs(oldPart:GetChildren()) do
							if c:IsA("SurfaceAppearance") or (c:IsA("Texture") and kind == "_Body") then c:Clone().Parent = p end
						end
						p.Color = oldPart.Color; p.Material = oldPart.Material
						nolook[name] = true
					end
					p.Parent = m
					if kind == "_Body" then m.PrimaryPart = p end
				end
				if cur then cur:Destroy() end
				m.Parent = S
				done += 1
			end
			if i % 25 == 0 then task.wait() end
		end
	end
	for _, mn in ipairs({ "Restyle_R2_A", "Restyle_R2_B" }) do
		local imp = workspace:FindFirstChild(mn)
		if imp then
			local left = 0
			for _, p in ipairs(imp:GetChildren()) do if p:IsA("MeshPart") then left += 1 end end
			out[#out + 1] = mn .. ": " .. left .. " parts not placed"
			if left == 0 then imp:Destroy() end
		end
	end
	local nl = {}
	for n in pairs(nolook) do nl[#nl + 1] = n end
	out[#out + 1] = string.format("rebuilt %d NEW animals | looks taken from OLD for: %s | slots without an import: %s", done, table.concat(nl, ","), table.concat(skipped, ","))
	return table.concat(out, "\n")
end

if MODE == "mutations" then
	local A = game.ReplicatedStorage.Assets.Animals
	local SS = game:GetService("ServerStorage")
	local MUTS = { "GoldAnimals", "DiamondAnimals", "RainbowAnimals", "InvertedAnimals", "HackedAnimals" }
	local root = SS:FindFirstChild("AnimalsRestyled"); if root then root:Destroy() end
	root = Instance.new("Folder"); root.Name = "AnimalsRestyled"
	local folders = {}
	for _, fn in ipairs({ "BaseAnimals", table.unpack(MUTS) }) do
		local f = Instance.new("Folder"); f.Name = fn; f.Parent = root; folders[fn] = f
	end
	local function dress(model, srcPart)
		for _, p in ipairs(model:GetChildren()) do
			if p:IsA("MeshPart") then
				for _, c in ipairs(p:GetChildren()) do
					if c:IsA("SurfaceAppearance") or c:IsA("Texture") or c:IsA("Decal") then c:Destroy() end
				end
				local isBody = p.Name:find("_Body") ~= nil
				for _, c in ipairs(srcPart:GetChildren()) do
					if c:IsA("SurfaceAppearance") or (isBody and (c:IsA("Texture") or c:IsA("Decal") or c.ClassName == "Attachment")) then
						c:Clone().Parent = p
					end
				end
				p.Color = srcPart.Color; p.Material = srcPart.Material; p.Reflectance = srcPart.Reflectance; p.Transparency = srcPart.Transparency
			end
		end
	end
	local made, missing, animals = 0, {}, 0
	local kids = S:GetChildren()
	for i, m in ipairs(kids) do
		local name = m:IsA("Model") and m.Name:match("^(.+) NEW$")
		if name then
			animals += 1
			local base = m:Clone(); base.Name = name; base.Parent = folders.BaseAnimals
			for _, mf in ipairs(MUTS) do
				local src = A[mf]:FindFirstChild(name)
				local srcPart = src and src:FindFirstChildWhichIsA("MeshPart")
				if srcPart then
					local c = m:Clone(); c.Name = name
					dress(c, srcPart)
					c.Parent = folders[mf]
					made += 1
				else
					missing[#missing + 1] = mf .. "." .. name
				end
			end
			if animals % 10 == 0 then task.wait() end
		end
	end
	root.Parent = SS
	-- a row to look at: old mutated animal, then the new shape in the same mutation
	local old = workspace:FindFirstChild("MutationPreview"); if old then old:Destroy() end
	local pv = Instance.new("Folder"); pv.Name = "MutationPreview"
	local row = 0
	for _, name in ipairs({ "Corgi", "Toad", "Hedgehog", "PolarBear", "Giraffe2", "Bunny", "Cat", "Dragon" }) do
		if folders.BaseAnimals:FindFirstChild(name) then
			for i, mf in ipairs(MUTS) do
				local src, new = A[mf]:FindFirstChild(name), folders[mf]:FindFirstChild(name)
				for k, model in ipairs({ src, new }) do
					if model then
						local c = model:Clone(); c.Name = name .. " " .. mf .. (k == 1 and " OLD" or " NEW")
						local ps = partsOf(c)
						for _, p in ipairs(ps) do p.Anchored = true end
						c.Parent = pv
						local mn, mx = bounds(ps)
						local target = Vector3.new(-80 + (i - 1) * 34 + (k - 1) * 15, 0, 200 + row * 22)
						c:PivotTo(c:GetPivot() + (target - Vector3.new((mn.X + mx.X) / 2, mn.Y, (mn.Z + mx.Z) / 2)))
					end
				end
			end
			row += 1
		end
	end
	pv.Parent = workspace
	return string.format("animals %d | mutation copies made %d | missing sources %d: %s | preview rows %d", animals, made, #missing, table.concat(missing, ",", 1, math.min(#missing, 12)), row)
end
return "unknown mode " .. tostring(MODE)
