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
local function skin(v, world, restInv)
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
  local edges, seen = {}, {}
  for _, fId in em:GetFaces() do
    local fv = em:GetFaceVertices(fId)
    for a = 1, #fv do
      local i, j = idx[fv[a]], idx[fv[a % #fv + 1]]
      local key = i < j and (i .. ":" .. j) or (j .. ":" .. i)
      if not seen[key] then seen[key] = true; local L = (V[i].p - V[j].p).Magnitude; if L > 0.02 then table.insert(edges, {i, j, L}) end end
    end
  end
  em:Destroy()
  local rest = A.fk(mesh, nil, 0, 0)
  local restInv = {}
  for n, cf in rest do restInv[n] = cf:Inverse() end
  return {mesh = mesh, V = V, edges = edges, restInv = restInv, scale = model:GetScale()}
end
function A.measure(ps, ks)
  local tracks, len = A.poseTracks(ks)
  local worstCount, worstR = 0, 1
  for s = 0, 9 do
    local world = A.fk(ps.mesh, tracks, len * s / 10, ps.scale)
    local sk, c = {}, 0
    for _, e in ps.edges do
      local a, b = sk[e[1]], sk[e[2]]
      if not a then a = skin(ps.V[e[1]], world, ps.restInv); sk[e[1]] = a end
      if not b then b = skin(ps.V[e[2]], world, ps.restInv); sk[e[2]] = b end
      local r = (a - b).Magnitude / e[3]
      if r > 1.3 then c += 1 end
      if r > worstR then worstR = r end
    end
    if c > worstCount then worstCount = c end
    task.wait()
  end
  return worstCount, worstR
end
return A
