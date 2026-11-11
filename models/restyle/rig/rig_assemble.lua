-- Turn an imported rig (Workspace.Rig_<Name>, from rig_build.py) into a model laid out like the
-- old animal in ReplicatedStorage.BaseAnimals.<Name>:
--   Model <Name> (PrimaryPart = the MeshPart, same attributes)
--     <PartName>: MeshPart  (same name as the old part: the animations' root pose uses it)
--       bones (moved here from the importer's RootPart; same names, CFrames kept)
--       SurfaceAppearance + Studs textures copied from the old part
--     AnimationController > Animator
-- then Model:ScaleTo(1 / k): the old animals were imported at native size and scaled the same way,
-- and that scale is what turns the animations' raw moves into studs.
-- Usage (edit context):  loadstring(src)()(importModel, oldModel, k)  -> new Model (not parented)
return function(imp, old, k)
	local mesh
	for _, p in ipairs(imp:GetChildren()) do
		if p:IsA("MeshPart") and not p.Name:find("^SOA_") then mesh = p end
	end
	assert(mesh, imp.Name .. ": no mesh part in the import")
	local root = imp:FindFirstChild("RootPart")
	local oldPart = old.PrimaryPart or old:FindFirstChildWhichIsA("MeshPart", true)
	local m = Instance.new("Model"); m.Name = old.Name
	for key, v in pairs(old:GetAttributes()) do
		if not key:find("^RBX_") then m:SetAttribute(key, v) end      -- RBX_ ones are Studio's own (reimport ids)
	end
	mesh.Parent = m
	-- bones: from the RootPart (same place, no turn) into the mesh part
	if root then
		local rel = mesh.CFrame:ToObjectSpace(root.CFrame)
		for _, b in ipairs(root:GetChildren()) do
			if b:IsA("Bone") then b.CFrame = rel * b.CFrame; b.Parent = mesh end
		end
	end
	for _, c in ipairs(mesh:GetChildren()) do
		if c:IsA("Motor6D") or c:IsA("SurfaceAppearance") or c:IsA("Texture") or c:IsA("Decal") then c:Destroy() end
	end
	mesh.Name = oldPart.Name
	-- the old look: textures, colour, material
	for _, c in ipairs(oldPart:GetChildren()) do
		if c:IsA("SurfaceAppearance") or c:IsA("Texture") or c:IsA("Decal") then c:Clone().Parent = mesh end
	end
	mesh.Color = oldPart.Color; mesh.Material = oldPart.Material; mesh.Transparency = oldPart.Transparency
	mesh.Reflectance = oldPart.Reflectance; mesh.RenderFidelity = oldPart.RenderFidelity
	mesh.Anchored = oldPart.Anchored; mesh.CanCollide = oldPart.CanCollide; mesh.CanTouch = oldPart.CanTouch
	mesh.CanQuery = oldPart.CanQuery; mesh.Massless = oldPart.Massless; mesh.CastShadow = oldPart.CastShadow
	mesh.CollisionGroup = oldPart.CollisionGroup
	-- animation controller like the old one
	local ac = Instance.new("AnimationController"); ac.Parent = m
	Instance.new("Animator").Parent = ac
	m.PrimaryPart = mesh
	-- same turn as the old part, then down to game size
	mesh.CFrame = CFrame.new(mesh.Position) * oldPart.CFrame.Rotation
	m:ScaleTo(1 / k)
	-- the pivot sits where the old one did, as a fraction of the part (the old ones pivot at the
	-- feet; game scripts place animals by their pivot, so a centred pivot would sink them)
	local rel = oldPart.CFrame:ToObjectSpace(old:GetPivot())
	local h = oldPart.Size / 2
	local frac = Vector3.new(h.X > 0 and rel.X / h.X or 0, h.Y > 0 and rel.Y / h.Y or 0, h.Z > 0 and rel.Z / h.Z or 0)
	-- (a model with a PrimaryPart takes its pivot from the part's PivotOffset, not WorldPivot)
	mesh.PivotOffset = CFrame.new(frac * (mesh.Size / 2)) * rel.Rotation
	imp:Destroy()
	return m
end
