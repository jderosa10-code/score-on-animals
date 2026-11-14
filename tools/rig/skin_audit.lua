local AS = game:GetService("AssetService")
local A = {}
_G.CS = A
function A.poseTracks(ks)
  local tracks, len = {}, 0
  for _, kf in ks:GetChildren() do
    if kf:IsA("Keyframe") then
      len = math.max(len, kf.Time)
      for _, p in kf:GetDescendants() do
        if p:IsA("Pose") then tracks[p.Name] = tracks[p.Name] or {}; table.insert(tracks[p.Name], {t = kf.Time, cf = p.CFrame}) end
      end
    end
  end
  for _, tr in tracks do table.sort(tr, function(a, b) return a.t < b.t end) end
  return tracks, len
end
local function sample(tr, t)
  if not tr then return CFrame.identity end
  local prev, nxt
  for _, k in tr do if k.t <= t then prev = k else nxt = k break end end
  if not prev then return nxt.cf end
  if not nxt or nxt.t <= prev.t then return prev.cf end
  return prev.cf:Lerp(nxt.cf, (t - prev.t) / (nxt.t - prev.t))
end
function A.fk(mesh, tracks, t, scale)
  local world = {}
  local function walk(parent, pw)
    for _, b in parent:GetChildren() do
      if b:IsA("Bone") then
        local p = tracks and sample(tracks[b.Name], t) or CFrame.identity
        local w = pw * b.CFrame * CFrame.new(p.Position * scale) * p.Rotation
        world[b.Name] = w
        walk(b, w)
      end
    end
  end
  walk(mesh, mesh.CFrame)
  return world
end
function A.skin(v, world, restInv)
  local out = Vector3.zero
  for j, n in v.names do if v.w[j] > 0 and world[n] then out += (world[n] * (restInv[n] * v.p)) * v.w[j] end end
  return out
end
function A.prep(model)
  local mesh = model:FindFirstChildWhichIsA("MeshPart", true)
  local em = AS:CreateEditableMeshAsync(Content.fromUri(mesh.MeshId))
  local verts = em:GetVertices()
  local lo, hi = Vector3.one * 1e9, -Vector3.one * 1e9
  local idx, pos = {}, {}
  for i, v in verts do idx[v] = i; local p = em:GetPosition(v); pos[i] = p; lo = lo:Min(p); hi = hi:Max(p) end
  local k, mid = mesh.Size / (hi - lo), (lo + hi) / 2
  local V = {}
  for i, v in verts do
    local bones, w = em:GetVertexBones(v), em:GetVertexBoneWeights(v)
    local names = {}
    for j, b in bones do names[j] = em:GetBoneName(b) end
    V[i] = {p = mesh.CFrame * ((pos[i] - mid) * k), names = names, w = w}
  end
  local edges, seen, allEdges = {}, {}, {}
  for _, fId in em:GetFaces() do
    local fv = em:GetFaceVertices(fId)
    for a = 1, #fv do
      local i, j = idx[fv[a]], idx[fv[a % #fv + 1]]
      local key = i < j and (i .. ":" .. j) or (j .. ":" .. i)
      if not seen[key] then seen[key] = true; table.insert(allEdges, {i, j}); local L = (V[i].p - V[j].p).Magnitude; if L > 0.02 then table.insert(edges, {i, j, L}) end end
    end
  end
  em:Destroy()
  local rest = A.fk(mesh, nil, 0, 0)
  local restInv = {}
  for n, cf in rest do restInv[n] = cf:Inverse() end
  return {mesh = mesh, V = V, edges = edges, allEdges = allEdges, restInv = restInv, scale = model:GetScale()}
end
function A.measure(ps, ks)
  local tracks, len = A.poseTracks(ks)
  local worstCount, worstR = 0, 1
  for s = 0, 9 do
    local world = A.fk(ps.mesh, tracks, len * s / 10, ps.scale)
    local sk, c = {}, 0
    for _, e in ps.edges do
      local a, b = sk[e[1]], sk[e[2]]
      if not a then a = A.skin(ps.V[e[1]], world, ps.restInv); sk[e[1]] = a end
      if not b then b = A.skin(ps.V[e[2]], world, ps.restInv); sk[e[2]] = b end
      local r = (a - b).Magnitude / e[3]
      if r > 1.3 then c += 1 end
      if r > worstR then worstR = r end
    end
    if c > worstCount then worstCount = c end
    task.wait()
  end
  return worstCount, worstR
end
-- loose pieces
function A.pieces(ps)
  local n = #ps.V
  local parent = table.create(n, 0)
  for i = 1, n do parent[i] = i end
  local function find(i) while parent[i] ~= i do parent[i] = parent[parent[i]]; i = parent[i] end return i end
  for _, e in ps.allEdges do local a, b = find(e[1]), find(e[2]); if a ~= b then parent[a] = b end end
  local groups = {}
  for i = 1, n do local r = find(i); groups[r] = groups[r] or {}; table.insert(groups[r], i) end
  local list = {}
  for _, g in groups do table.insert(list, g) end
  table.sort(list, function(a, b) return #a > #b end)
  local small = {}
  for gi, g in list do
    if gi > 1 and #g < n * 0.15 then
      local c = Vector3.zero
      for _, i in g do c += ps.V[i].p end
      c /= #g
      local inG = {}
      for _, i in g do inG[i] = true end
      local best, bd = nil, math.huge
      for i = 1, n do if not inG[i] then local d = (ps.V[i].p - c).Magnitude; if d < bd then best, bd = i, d end end end
      table.insert(small, {verts = g, centre = c, host = best, size = #g})
    end
  end
  ps.small = small
  return small
end
function A.drift(ps, ks)
  local tracks, len = A.poseTracks(ks)
  local worst, worstPiece = 0, nil
  for s = 0, 9 do
    local world = A.fk(ps.mesh, tracks, len * s / 10, ps.scale)
    for _, pc in ps.small do
      local c = Vector3.zero
      for _, i in pc.verts do c += A.skin(ps.V[i], world, ps.restInv) end
      c /= #pc.verts
      local h = A.skin(ps.V[pc.host], world, ps.restInv)
      local d = ((c - h) - (pc.centre - ps.V[pc.host].p)).Magnitude
      if d > worst then worst, worstPiece = d, pc end
    end
    task.wait()
  end
  return worst, worstPiece
end
-- (pigeon-claude, 14 Nov) faceted meshes: every triangle has its own corners, so a bad skin shows as CRACKS
-- (corners at the same rest spot pulled apart), not stretched edges. A.cracks(ps, ks) -> worst gap (studs),
-- number of spots gapping more than 2% of the model height on the worst frame, and the bones on the worst spot.
function A.corners(ps)
	local q = 1e-3
	local groups = {}
	for i, v in ps.V do
		local k = math.floor(v.p.X / q + 0.5) .. "," .. math.floor(v.p.Y / q + 0.5) .. "," .. math.floor(v.p.Z / q + 0.5)
		groups[k] = groups[k] or {}
		table.insert(groups[k], i)
	end
	local list = {}
	for _, g in groups do if #g > 1 then table.insert(list, g) end end
	ps.corners = list
	return list
end
function A.cracks(ps, ks, height)
	local tracks, len = A.poseTracks(ks)
	local worst, worstG, worstCount, worstT = 0, nil, 0, 0
	for s = 0, 11 do
		local world = A.fk(ps.mesh, tracks, len * s / 12, ps.scale)
		local count = 0
		for _, g in ps.corners do
			local a = A.skin(ps.V[g[1]], world, ps.restInv)
			local spread = 0
			for j = 2, #g do spread = math.max(spread, (A.skin(ps.V[g[j]], world, ps.restInv) - a).Magnitude) end
			if spread > height * 0.02 then count += 1 end
			if spread > worst then worst, worstG, worstT = spread, g, len * s / 12 end
		end
		if count > worstCount then worstCount = count end
		task.wait()
	end
	return worst, worstCount, worstG, worstT
end
-- pieces again, but corners at the same spot count as joined (faceted meshes): real loose pieces only
function A.pieces2(ps)
	local n = #ps.V
	local parent = table.create(n, 0)
	for i = 1, n do parent[i] = i end
	local function find(i) while parent[i] ~= i do parent[i] = parent[parent[i]]; i = parent[i] end return i end
	local function join(a, b) a, b = find(a), find(b); if a ~= b then parent[a] = b end end
	for _, e in ps.allEdges do join(e[1], e[2]) end
	local q, cell = 1e-3, {}
	for i, v in ps.V do
		local k = math.floor(v.p.X / q + 0.5) .. "," .. math.floor(v.p.Y / q + 0.5) .. "," .. math.floor(v.p.Z / q + 0.5)
		if cell[k] then join(i, cell[k]) else cell[k] = i end
	end
	local groups = {}
	for i = 1, n do local r = find(i); groups[r] = groups[r] or {}; table.insert(groups[r], i) end
	local list = {}
	for _, g in groups do table.insert(list, g) end
	table.sort(list, function(a, b) return #a > #b end)
	local small = {}
	for gi, g in list do
		if gi > 1 and #g < n * 0.15 then
			local c = Vector3.zero
			for _, i in g do c += ps.V[i].p end
			c /= #g
			local inG = {}
			for _, i in g do inG[i] = true end
			local best, bd = nil, math.huge
			for i = 1, n do if not inG[i] then local d = (ps.V[i].p - c).Magnitude; if d < bd then best, bd = i, d end end end
			local bones = {}
			for _, i in g do local v = ps.V[i] local top, tw = "?", -1 for j, nm in v.names do if v.w[j] > tw then top, tw = nm, v.w[j] end end bones[top] = (bones[top] or 0) + 1 end
			table.insert(small, {verts = g, centre = c, host = best, size = #g, bones = bones})
		end
	end
	ps.small = small
	return small, #list
end
-- flag loose pieces tied to a bone that is far away from them (e.g. eyes on a shoulder) and that drift off the body
function A.misbound(ps, clips, height)
	local rest = A.fk(ps.mesh, nil, 0, 0)
	local flags = {}
	for _, pc in ps.small do
		local own, on = nil, -1
		for b, c in pc.bones do if c > on then own, on = b, c end end
		local hv = ps.V[pc.host]
		local hb, hw = nil, -1
		for j, n in hv.names do if hv.w[j] > hw then hb, hw = n, hv.w[j] end end
		if own and hb and own ~= hb and rest[own] and rest[hb] then
			local dOwn = (pc.centre - rest[own].Position).Magnitude
			local dHost = (pc.centre - rest[hb].Position).Magnitude
			if dOwn > dHost * 1.5 then
				pc.own, pc.hb = own, hb
				table.insert(flags, pc)
			end
		end
	end
	local out = {}
	for _, pc in flags do
		local worst = 0
		for _, ks in clips do
			local tracks, len = A.poseTracks(ks)
			for s = 0, 7 do
				local world = A.fk(ps.mesh, tracks, len * s / 8, ps.scale)
				local c = Vector3.zero
				for _, i in pc.verts do c += A.skin(ps.V[i], world, ps.restInv) end
				c /= #pc.verts
				local h = A.skin(ps.V[pc.host], world, ps.restInv)
				worst = math.max(worst, ((c - h) - (pc.centre - ps.V[pc.host].p)).Magnitude)
			end
		end
		if worst > height * 0.03 then table.insert(out, string.format("%d verts on %s (sits on %s) drifts %.0f%%", pc.size, pc.own, pc.hb, worst / height * 100)) end
	end
	return out
end
-- v2: a piece tied to a hanging limb bone (its children hang below it) but sitting well ABOVE that bone
-- (eyes on a shoulder, a horn on a leg), and that drifts when the clips play
function A.misbound2(ps, clips, height)
	local rest = A.fk(ps.mesh, nil, 0, 0)
	local kids = {}
	for _, b in ps.mesh.Parent:GetDescendants() do
		if b:IsA("Bone") and b.Parent:IsA("Bone") then kids[b.Parent.Name] = kids[b.Parent.Name] or {}; table.insert(kids[b.Parent.Name], b.Name) end
	end
	local function hanging(n)
		local ks = kids[n]
		if not ks or not rest[n] then return false end
		for _, k in ks do if not rest[k] or rest[k].Position.Y > rest[n].Position.Y - height * 0.02 then return false end end
		return true
	end
	local out = {}
	for _, pc in ps.small do
		local own, on = nil, -1
		for b, c in pc.bones do if c > on then own, on = b, c end end
		if own and hanging(own) and pc.centre.Y > rest[own].Position.Y + height * 0.12 then
			local worst = 0
			for _, ks in clips do
				local tracks, len = A.poseTracks(ks)
				for s = 0, 7 do
					local world = A.fk(ps.mesh, tracks, len * s / 8, ps.scale)
					local c = Vector3.zero
					for _, i in pc.verts do c += A.skin(ps.V[i], world, ps.restInv) end
					c /= #pc.verts
					local h = A.skin(ps.V[pc.host], world, ps.restInv)
					worst = math.max(worst, ((c - h) - (pc.centre - ps.V[pc.host].p)).Magnitude)
				end
			end
			table.insert(out, string.format("%d verts on %s, %.0f%% of its height above it, drifts %.0f%%", pc.size, own, (pc.centre.Y - rest[own].Position.Y) / height * 100, worst / height * 100))
		end
	end
	return out
end
return A