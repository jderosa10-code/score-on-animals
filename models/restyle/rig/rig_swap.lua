-- Put the rigged new animals into the game (edit context, after Import 3D of rig\batch\Rig_<Name>.fbx).
--   loadstring(swapSrc)()(assembleFn)   -> report text; progress in workspace attribute "RigSwapProgress"
-- For every Workspace.Rig_<Name>:
--   1. assemble it like the old ReplicatedStorage.BaseAnimals.<Name> (rig_assemble.lua)
--   2. the old base model moves to ServerStorage.OldAnimals_Backup.BaseAnimals, the new one takes its place
--   3. each mutation (ReplicatedStorage.Assets.Animals.<Mut>Animals.<Name>) is rebuilt from the NEW
--      base: the old mutation part's look (SurfaceAppearance, textures, attachments, effects,
--      colour/material) and any extra things in the old mutation model are copied onto it; the
--      old mutation model moves to the backup
-- Nothing is deleted. Undo = move the backups back.
return function(assemble)
	local RS, SS = game.ReplicatedStorage, game:GetService("ServerStorage")
	local Base = RS.BaseAnimals
	local Muts = RS.Assets.Animals
	local function sub(parent, name) local f = parent:FindFirstChild(name); if not f then f = Instance.new("Folder"); f.Name = name; f.Parent = parent end; return f end
	local Backup = sub(SS, "OldAnimals_Backup")
	Backup:SetAttribute("Note", "The old (pre-restyle) rigged animals, replaced by rig_swap.lua. Delete once the new ones are approved in play.")
	local function partOf(m) for _, d in ipairs(m:GetDescendants()) do if d:IsA("MeshPart") then return d end end end
	local LOOK = { SurfaceAppearance = true, Texture = true, Decal = true, Attachment = true, ParticleEmitter = true, PointLight = true,
		SpotLight = true, SurfaceLight = true, Highlight = true, Beam = true, Trail = true, Fire = true, Sparkles = true, Smoke = true }
	local imps = {}
	for _, c in ipairs(workspace:GetChildren()) do
		if c:IsA("Model") and c.Name:find("^Rig_") then imps[#imps + 1] = c end
	end
	local done, skipped, mutsDone = {}, {}, 0
	for i, imp in ipairs(imps) do
		local name = imp.Name:sub(5)
		local old = Base:FindFirstChild(name)
		if not old or old:GetAttribute("Rigged2") then
			skipped[#skipped + 1] = name .. (old and " (already new)" or " (no old animal)")
			imp:Destroy()
		else
			local ok, new = pcall(assemble, imp, old, 1 / old:GetScale())
			if not ok then
				skipped[#skipped + 1] = name .. ": " .. tostring(new)
			else
				new:SetAttribute("Rigged2", true)
				local pivot = old:GetPivot()
				local oldParent = old.Parent
				old.Parent = sub(Backup, "BaseAnimals")
				new:PivotTo(pivot)
				new.Parent = oldParent
				-- mutations
				local np = new.PrimaryPart
				for _, mf in ipairs(Muts:GetChildren()) do
					local om = mf:FindFirstChild(name)
					if om and om:IsA("Model") then
						local op = partOf(om)
						local mm = new:Clone(); mm.Name = om.Name
						for key, v in pairs(om:GetAttributes()) do if not key:find("^RBX_") then mm:SetAttribute(key, v) end end
						local mp = mm.PrimaryPart
						for _, c in ipairs(mp:GetChildren()) do if LOOK[c.ClassName] then c:Destroy() end end
						if op then
							for _, c in ipairs(op:GetChildren()) do
								if LOOK[c.ClassName] then
									local cc = c:Clone()
									if cc:IsA("Attachment") then      -- keep it at the same spot relative to the part's size
										local h = op.Size / 2
										local f = Vector3.new(h.X > 0 and c.Position.X / h.X or 0, h.Y > 0 and c.Position.Y / h.Y or 0, h.Z > 0 and c.Position.Z / h.Z or 0)
										cc.Position = f * (mp.Size / 2)
									end
									cc.Parent = mp
								end
							end
							mp.Color = op.Color; mp.Material = op.Material; mp.Reflectance = op.Reflectance; mp.Transparency = op.Transparency
						end
						-- anything else the old mutation model carried (effect parts, folders, values)
						for _, c in ipairs(om:GetChildren()) do
							if not (c:IsA("BasePart") or c:IsA("AnimationController") or c:IsA("Humanoid")) and not mm:FindFirstChild(c.Name) then
								c:Clone().Parent = mm
							end
						end
						mm:PivotTo(om:GetPivot())
						-- extra effect parts (the Inverted "built" ones have a floor and dust), same spot from the pivot
						for _, c in ipairs(om:GetChildren()) do
							if c:IsA("BasePart") and c ~= op and not mm:FindFirstChild(c.Name) then
								local cc = c:Clone()
								cc.CFrame = mm:GetPivot() * om:GetPivot():ToObjectSpace(c.CFrame)
								cc.Parent = mm
							end
						end
						om.Parent = sub(sub(Backup, "Mutations"), mf.Name)
						mm.Parent = mf
						mutsDone += 1
					end
				end
				done[#done + 1] = name
			end
		end
		workspace:SetAttribute("RigSwapProgress", ("%d/%d, swapped %d"):format(i, #imps, #done))
		task.wait()
	end
	local res = ("swapped %d animals, %d mutation models | skipped %d: %s"):format(#done, mutsDone, #skipped, table.concat(skipped, "; "))
	workspace:SetAttribute("RigSwapProgress", "DONE " .. res:sub(1, 900))
	return res
end
