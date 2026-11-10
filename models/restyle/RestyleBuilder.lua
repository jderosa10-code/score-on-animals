--!strict
-- ReplicatedStorage.RestyleBuilder
-- Builds the restyled ("NEW") test animals from the data in ReplicatedStorage.RestyleData
-- as EditableMesh MeshParts, and places them on the slots in Workspace.RestyleShowcase.
-- Editable meshes can't be saved into the place yet, so the client rebuilds them every Play
-- (see StarterPlayerScripts.RestyleShowcaseClient).

local AssetService = game:GetService("AssetService")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Builder = {}

local B64 = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local DEC = {}
for i = 1, 64 do
	DEC[string.byte(B64, i)] = i - 1
end

local function b64ToBuffer(s: string, size: number): buffer
	local buf = buffer.create(size)
	local o = 0
	for i = 1, #s, 4 do
		local a, b, c, d = string.byte(s, i, i + 3)
		local x = DEC[a] * 262144 + DEC[b] * 4096 + (DEC[c] or 0) * 64 + (DEC[d] or 0)
		if o < size then buffer.writeu8(buf, o, bit32.extract(x, 16, 8)) end
		if o + 1 < size and c ~= 61 then buffer.writeu8(buf, o + 1, bit32.extract(x, 8, 8)) end
		if o + 2 < size and d ~= 61 then buffer.writeu8(buf, o + 2, bit32.extract(x, 0, 8)) end
		o += 3
		if i % 60000 == 1 then task.wait() end
	end
	return buf
end

local function toSRGB(c: number): number
	return math.clamp(c, 0, 1) ^ (1 / 2.2)
end

local function buildPart(p, ctr: Vector3): MeshPart
	local v = p.verts
	local em = AssetService:CreateEditableMesh()
	local vid = {}
	local pts = {}
	for i = 1, #v, 3 do
		local q = Vector3.new(v[i], v[i + 1], v[i + 2])
		pts[#pts + 1] = q
		vid[#vid + 1] = em:AddVertex(q - ctr)
	end
	local uid = {}
	for i = 1, #p.uvs, 2 do
		uid[#uid + 1] = em:AddUV(Vector2.new(p.uvs[i], p.uvs[i + 1]))
	end
	for k, t in ipairs(p.tris) do
		local a, b, c = pts[t[1]], pts[t[2]], pts[t[3]]
		local f = em:AddTriangle(vid[t[1]], vid[t[2]], vid[t[3]])
		em:SetFaceUVs(f, { uid[t[4]], uid[t[5]], uid[t[6]] })
		local nrm = (b - a):Cross(c - a)
		if nrm.Magnitude > 1e-9 then
			local nid = em:AddNormal(nrm.Unit)
			em:SetFaceNormals(f, { nid, nid, nid })
		end
		if k % 500 == 0 then task.wait() end
	end
	local mp = AssetService:CreateMeshPartAsync(Content.fromObject(em))
	mp.Name = p.name
	mp.Anchored = true
	mp.CanCollide = false
	mp.CanQuery = false
	if p.tex then
		local w, h = p.tex.w, p.tex.h
		local img = AssetService:CreateEditableImage({ Size = Vector2.new(w, h) })
		img:WritePixelsBuffer(Vector2.zero, Vector2.new(w, h), b64ToBuffer(p.tex.b64, w * h * 4))
		mp.TextureContent = Content.fromObject(img)
		mp.Color = Color3.new(1, 1, 1)
	else
		mp.Color = Color3.new(toSRGB(p.color[1]), toSRGB(p.color[2]), toSRGB(p.color[3]))
		if string.find(p.name, "_Eyes") then
			mp.Color = Color3.fromRGB(18, 18, 22)
			mp.Material = Enum.Material.SmoothPlastic
		elseif string.find(p.name, "_Shine") then
			mp.Material = Enum.Material.Neon
		end
	end
	return mp
end

-- Build one NEW animal as a Model whose parts sit relative to its bottom centre,
-- then put that bottom centre on `slot` (a CFrame on the ground, facing the viewer).
function Builder.buildAt(name: string, slot: CFrame, parent: Instance): Model
	-- data is split into ModuleScripts "1", "2", ... (Studio caps a script at 200k characters)
	local src = ReplicatedStorage:WaitForChild("RestyleData"):WaitForChild(name)
	local pieces = {}
	for i = 1, #src:GetChildren() do
		pieces[i] = require(src:WaitForChild(tostring(i))) :: any
	end
	local data = HttpService:JSONDecode(table.concat(pieces))
	local mn = Vector3.new(math.huge, math.huge, math.huge)
	local mx = -mn
	for _, p in ipairs(data.parts) do
		local v = p.verts
		for i = 1, #v, 3 do
			local q = Vector3.new(v[i], v[i + 1], v[i + 2])
			mn = mn:Min(q)
			mx = mx:Max(q)
		end
	end
	local bottom = Vector3.new((mn.X + mx.X) / 2, mn.Y, (mn.Z + mx.Z) / 2)
	local model = Instance.new("Model")
	model.Name = name .. " NEW"
	for _, p in ipairs(data.parts) do
		local pmn = Vector3.new(math.huge, math.huge, math.huge)
		local pmx = -pmn
		local v = p.verts
		for i = 1, #v, 3 do
			local q = Vector3.new(v[i], v[i + 1], v[i + 2])
			pmn = pmn:Min(q)
			pmx = pmx:Max(q)
		end
		local ctr = (pmn + pmx) / 2
		local mp = buildPart(p, ctr)
		mp.CFrame = slot * CFrame.new(ctr - bottom)
		mp.Parent = model
		task.wait()
	end
	model.Parent = parent
	return model
end

-- Build NEW animals on every slot in Workspace.RestyleShowcase (slots are parts named "Slot_<Name>").
function Builder.buildAllSlots()
	local show = workspace:WaitForChild("RestyleShowcase")
	local old = show:FindFirstChild("NEW")
	if old then old:Destroy() end
	local out = Instance.new("Folder")
	out.Name = "NEW"
	out.Parent = show
	for _, slot in ipairs(show:GetChildren()) do
		if slot:IsA("BasePart") and string.sub(slot.Name, 1, 5) == "Slot_" then
			local name = string.sub(slot.Name, 6)
			local ok, err = pcall(Builder.buildAt, name, slot.CFrame, out)
			if not ok then
				warn("RestyleBuilder: " .. name .. " failed: " .. tostring(err))
			end
		end
	end
	return out
end

return Builder
