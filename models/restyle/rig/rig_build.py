"""Rig the restyled (round 3, warped) animals like the old ones, so the old animations play on them.

blender -b <r3 blend with <pack> and <pack>_SOA> -P rig_build.py -- <bones.json> <Name,Name|ALL> <out.fbx> <report.json>

Per animal (Studio name -> pack object via bones.json "new.part"):
  1. FIT: which axis-aligned turn A (and centre C) puts the old MeshPart's local space onto the
     ORIGINAL mesh in this blend. Chosen by size match and by how well the old bones sit inside
     the mesh (bones live inside the body).
  2. WARP: the exact round-3 warp (same rule as variants/warp.py) is rebuilt from the original
     mesh and applied to the bone positions. It is checked against the warped mesh: every vertex
     must land where <pack>_SOA has it. If not, bones move by the average move of nearby vertices.
  3. WEIGHTS: Blender automatic (bone heat) weights from a helper skeleton whose bones run along
     the limbs; small loose blocks (box parts) are then made rigid to their main bone, max 4
     bones per vertex, normalised. Nothing left unweighted.
  4. EXPORT: same bone names, same parents, same bone ORIENTATIONS as the old rig (animations are
     rotations in each bone's own frame), new positions; mesh object named like the old MeshPart
     (the animations' root pose uses that name). Coordinates are written so that after Studio's
     import the part's local axes are the old part's axes, at the old part's native size ratio
     (MeshSize / Size: the animations' moves are in those native units).
"""
import bpy, bmesh, sys, os, json, math
from mathutils import Vector, Matrix
from mathutils.bvhtree import BVHTree
from mathutils.kdtree import KDTree

argv = sys.argv[sys.argv.index("--") + 1:]
bones_json, which, fbx_out, report_out = argv[:4]
UNIT = float(os.environ.get("RIG_UNIT", "100.0"))      # Studio importer: 1 exported unit = 100 studs (measured 2026-11-11; bigger than 2048 studs gets shrunk, but only the meshes, not the bones)
RIGID_MAX = int(os.environ.get("RIG_RIGID_MAX", "60"))  # loose pieces with at most this many corners move rigidly
data = json.load(open(bones_json))
if which != "ALL":
    want = set(which.split(","))
    data = [e for e in data if e["name"] in want]
sc = bpy.context.scene

# ------------------------------------------------------------------ warp (copy of variants/warp.py)
HEAD_GAIN, LENS_REACH, LEG_SQUASH, WIDE, LONG = 0.5, 1.6, 0.62, 1.12, 0.93


def smoothstep(a, b, x):
    t = max(0.0, min(1.0, (x - a) / (b - a)))
    return t * t * (3 - 2 * t)


def islands_of(bm):
    seen, out = set(), []
    for v in bm.verts:
        if v.index in seen: continue
        st, isl = [v], []; seen.add(v.index)
        while st:
            x = st.pop(); isl.append(x)
            for e in x.link_edges:
                o = e.other_vert(x)
                if o.index not in seen: seen.add(o.index); st.append(o)
        out.append(isl)
    return out


def make_warp(me):
    co = [v.co.copy() for v in me.vertices]
    mn = Vector((min(c.x for c in co), min(c.y for c in co), min(c.z for c in co)))
    mx = Vector((max(c.x for c in co), max(c.y for c in co), max(c.z for c in co)))
    size = mx - mn; ctr = (mn + mx) / 2; big = max(size)

    def score(c):
        return (c.z - mn.z) / max(1e-6, size.z) + 0.8 * (c.y - mn.y) / max(1e-6, size.y)
    ranked = sorted(co, key=score, reverse=True)
    top = ranked[:max(8, len(ranked) * 12 // 100)]
    hc = sum(top, Vector()) / len(top)
    hmn = Vector((min(c.x for c in top), min(c.y for c in top), min(c.z for c in top)))
    hmx = Vector((max(c.x for c in top), max(c.y for c in top), max(c.z for c in top)))
    R = max(0.18 * big, min(0.45 * big, 0.6 * max(hmx - hmn)))
    hc.x = ctr.x
    bm = bmesh.new(); bm.from_mesh(me)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-4)
    legs = 0
    for isl in islands_of(bm):
        zs = [v.co.z for v in isl]
        if min(zs) < mn.z + 0.04 * size.z:
            xs = [v.co.x for v in isl]; ys = [v.co.y for v in isl]
            if (max(xs) - min(xs)) < 0.45 * size.x and (max(ys) - min(ys)) < 0.45 * size.y and max(zs) - min(zs) > 0.12 * size.z:
                legs += 1
    bm.free()
    belly = mn.z + 0.32 * size.z
    squash = LEG_SQUASH if legs >= 2 else 1.0

    def f0(c):
        p = c.copy()
        d = p - hc; r = d.length
        if r > 1e-9:
            p = hc + d * (1 + HEAD_GAIN * (1 - smoothstep(0.0, LENS_REACH, r / R)))
        if squash < 1.0:
            below = belly - p.z
            if below > 0: p.z = belly - below * squash
        p.x = ctr.x + (p.x - ctr.x) * WIDE
        p.y = ctr.y + (p.y - ctr.y) * LONG
        return p
    new = [f0(c) for c in co]
    nz = min(p.z for p in new)
    nmn = Vector((min(p.x for p in new), min(p.y for p in new), nz))
    nmx = Vector((max(p.x for p in new), max(p.y for p in new), max(p.z for p in new)))
    shift = Vector((ctr.x - (nmn.x + nmx.x) / 2, ctr.y - (nmn.y + nmx.y) / 2, mn.z - nz))
    return (lambda c: f0(c) + shift), [p + shift for p in new]


# ------------------------------------------------------------------ helpers
def world_coords(ob):
    mw = ob.matrix_world
    return [mw @ v.co for v in ob.data.vertices]


def bbox(pts):
    mn = Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
    mx = Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
    return mn, mx


def cf_rot(c):        # Roblox CFrame components -> 3x3 (rows), position
    x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22 = c
    return Matrix(((r00, r01, r02), (r10, r11, r12), (r20, r21, r22))), Vector((x, y, z))


ROTS = []             # the 24 axis-aligned turns (signed permutations with det +1)
import itertools
for perm in itertools.permutations(range(3)):
    for signs in itertools.product((1, -1), repeat=3):
        M = Matrix(((0, 0, 0), (0, 0, 0), (0, 0, 0)))
        for i in range(3): M[perm[i]][i] = signs[i]      # Roblox axis i -> Blender axis perm[i]
        if abs(M.determinant() - 1) < 1e-6: ROTS.append(M)
G = Matrix(((-1, 0, 0), (0, 0, 1), (0, 1, 0)))        # Roblox mesh axes <-> exported Blender axes (measured with the eggs)
FIX = Matrix.Rotation(math.radians(-90), 3, 'X')       # the importer turns every bone +90 deg about its own X (measured): undo it


# surface points of each OLD mesh, sampled in Studio by raycasting the part (part-local studs):
# the decisive test for which way round the mesh sits (bones alone fit a dog nearly as well
# turned round, which put the first test dog's tail bones in its head)
SURF = {}
import glob
for fn in sorted(glob.glob(os.path.join(os.path.dirname(bones_json), "surf_*.json"))):
    for s in json.load(open(fn)): SURF[s["name"]] = s


def fit(e, pts, bvh):
    size = Vector(e["size"])
    mn, mx = bbox(pts); dims = mx - mn; C = (mn + mx) / 2
    samp = SURF.get(e["name"])
    if samp and len(samp["pts"]) >= 20:
        scored = []
        for A in ROTS:
            s = A @ size
            mism = sum(abs(abs(s[k]) - dims[k]) for k in range(3)) / max(dims)
            if mism > 0.15: continue
            tot = 0.0
            for p in samp["pts"]:
                q = C + A @ Vector(p)
                loc, nrm, _, d = bvh.find_nearest(q)
                tot += d if loc is not None else max(dims)
            scored.append((tot / len(samp["pts"]) / max(dims) + mism, A, mism))
        scored.sort(key=lambda r: r[0])
        if scored:
            gap = (scored[1][0] / max(1e-9, scored[0][0])) if len(scored) > 1 else 99.0
            e["_fitgap"] = round(gap, 2); e["_fiterr"] = round(scored[0][0], 4)
            return scored[0][1], C, scored[0][2], -1.0
    # no surface sample: every one of the 212 sampled animals came out the same way round (the OBJ
    # export convention), so use that
    return Matrix(((1, 0, 0), (0, 0, -1), (0, 1, 0))), C, 0.0, -1.0
    best = None
    for A in ROTS:
        s = A @ size
        mism = sum(abs(abs(s[k]) - dims[k]) for k in range(3)) / max(dims)
        out = 0.0
        for b in e["bones"]:
            _, p = cf_rot(b["w"])
            q = C + A @ p
            loc, nrm, _, d = bvh.find_nearest(q)
            if loc is not None and (q - loc).dot(nrm) > 0: out += d
        out /= max(1, len(e["bones"]))
        sc_ = mism * 4 + out / max(dims)
        if best is None or sc_ < best[0]: best = (sc_, A, mism, out)
    return best[1], C, best[2], best[3]


def seg_dist(p, a, b):
    ab = b - a; t = 0.0 if ab.length_squared < 1e-12 else max(0.0, min(1.0, (p - a).dot(ab) / ab.length_squared))
    return (p - (a + ab * t)).length


# ------------------------------------------------------------------ main
report, export_objs = [], []
row = 0
for e in data:
    rep = {"name": e["name"]}
    report.append(rep)
    pack = e.get("new", {}).get("part", "").split("_NEW_")[0]
    orig, new = bpy.data.objects.get(pack), bpy.data.objects.get(pack + "_SOA")
    if not orig or not new or len(orig.data.vertices) != len(new.data.vertices):
        rep["skip"] = "pair not in this file"; continue
    rep["pack"] = pack
    opts, npts = world_coords(orig), world_coords(new)
    bvh = BVHTree.FromPolygons(opts, [list(p.vertices) for p in orig.data.polygons])
    A, C, mism, outside = fit(e, opts, bvh)
    if os.environ.get("RIG_FIT_ONLY") == "1":
        print("FITONLY", e["name"], "surf", e.get("_fiterr"), "gap", e.get("_fitgap"), "A", [list(map(int, r)) for r in A]); continue
    rep["fit"] = {"A": [list(r) for r in A], "sizeMismatch": round(mism, 4), "boneOutside": round(outside, 4), "surfErr": e.get("_fiterr"), "gapToNext": e.get("_fitgap")}
    # warp of the bones: exact rule if it reproduces the warped mesh, else nearby-vertex moves
    tmp = bpy.data.meshes.new("tmp"); tmp.from_pydata(opts, [], [list(p.vertices) for p in orig.data.polygons])
    f, test = make_warp(tmp); bpy.data.meshes.remove(tmp)
    err = max((a - b).length for a, b in zip(test, npts))
    rep["warpErr"] = round(err, 5)
    if err > 1e-3:
        kd = KDTree(len(opts))
        for i, p in enumerate(opts): kd.insert(p, i)
        kd.balance()

        def f(p):
            acc, wsum = Vector(), 0.0
            for (_, i, d) in kd.find_n(p, 8):
                w = 1.0 / (d + 1e-4) ** 2; acc += (npts[i] - opts[i]) * w; wsum += w
            return p + acc / wsum
        rep["warp"] = "nearby-vertex"
    else:
        rep["warp"] = "exact"
    # bones: old -> warped, in Blender world
    names = [b["n"] for b in e["bones"]]
    parent = {b["n"]: (b["p"] if b["p"] in names else None) for b in e["bones"]}
    head, frame = {}, {}
    for b in e["bones"]:
        R, p = cf_rot(b["w"])
        head[b["n"]] = f(C + A @ p)
        frame[b["n"]] = R                                # rotation in the old part's own axes (kept as is)
    nmn, nmx = bbox(npts); Cn = (nmn + nmx) / 2
    k = e["meshSize"][0] / e["size"][0] if e.get("meshSize") else 1.0
    s_exp = k / UNIT
    Ai = A.transposed()

    def to_exp(p):                                        # Blender world -> exported coords
        return G @ ((Ai @ (p - Cn)) * s_exp)
    # ---- weights, on a copy of the warped mesh, with a helper skeleton along the limbs
    me = new.data.copy(); me.name = e["part"]
    me.transform(new.matrix_world)
    wob = bpy.data.objects.new(e["part"], me); sc.collection.objects.link(wob)
    harm = bpy.data.armatures.new("H_" + e["name"]); hob = bpy.data.objects.new("H_" + e["name"], harm); sc.collection.objects.link(hob)
    kids = {n: [m for m in names if parent[m] == n] for n in names}
    bpy.context.view_layer.objects.active = hob
    for o in sc.objects: o.select_set(False)
    hob.select_set(True)
    bpy.ops.object.mode_set(mode='EDIT')
    span = max(nmx - nmn)
    for n in names:
        eb = harm.edit_bones.new(n)
        h = head[n]
        if kids[n]:
            t = sum((head[c] for c in kids[n]), Vector()) / len(kids[n])
        elif parent[n]:
            d = h - head[parent[n]]
            t = h + (d.normalized() * max(0.05 * span, 0.4 * d.length) if d.length > 1e-6 else Vector((0, 0, 0.05 * span)))
        else:
            t = h + Vector((0, 0, 0.05 * span))
        if (t - h).length < 1e-4 * span: t = h + Vector((0, 0, 0.02 * span))
        eb.head, eb.tail = h, t
    for n in names:
        if parent[n]: harm.edit_bones[n].parent = harm.edit_bones[parent[n]]
    bpy.ops.object.mode_set(mode='OBJECT')
    for o in sc.objects: o.select_set(False)
    wob.select_set(True); hob.select_set(True); bpy.context.view_layer.objects.active = hob
    try:
        bpy.ops.object.parent_set(type='ARMATURE_AUTO')
    except Exception as ex:
        rep["heatError"] = str(ex)[:120]
    # per-vertex weights -> dict
    gidx = {g.index: g.name for g in wob.vertex_groups}
    W = [{} for _ in me.vertices]
    for v in me.vertices:
        for g in v.groups:
            if g.weight > 1e-4: W[v.index][gidx[g.group]] = g.weight
    # unweighted vertices: nearest limb segment
    segs = [(n, head[n], (sum((head[c] for c in kids[n]), Vector()) / len(kids[n])) if kids[n] else head[n]) for n in names]
    unw = 0
    for v in me.vertices:
        if not W[v.index]:
            unw += 1
            n = min(segs, key=lambda s: seg_dist(v.co, s[1], s[2]))[0]
            W[v.index] = {n: 1.0}
    rep["unweightedFixed"] = unw
    # small loose blocks move rigidly with their main bone
    bm = bmesh.new(); bm.from_mesh(me); bm.verts.ensure_lookup_table()
    pos_groups = {}
    for v in bm.verts: pos_groups.setdefault(tuple(round(c, 5) for c in v.co), []).append(v.index)
    rigid = 0
    for isl in islands_of(bm):
        corners = len({tuple(round(c, 5) for c in v.co) for v in isl})
        if corners <= RIGID_MAX:
            # the bone running nearest the block's middle (a paw goes with the lower leg, a thigh
            # with the upper leg), not the one the heat solver happened to favour
            cen = sum((v.co for v in isl), Vector()) / len(isl)
            main = min(segs, key=lambda s: seg_dist(cen, s[1], s[2]))[0]
            for v in isl: W[v.index] = {main: 1.0}
            rigid += 1
    # DECORATIONS (2026-11-11, the chicken's eyes flapped with its wings): a small piece that no bone
    # runs through, sitting on a piece at least 3x its size (the nearest such piece: the head, not the whole body; with 10x the mammoth's ears and tusks skipped its head and went to the body) (an eye, beak or comb on a head with no
    # bone of its own), must not go to "the nearest bone" (for the eyes that was the wing). It moves
    # exactly like the spot it sits on instead. Pieces = islands welded at shared corners (UV seams
    # split a box into faces).
    isls = islands_of(bm)
    isl_of = {}
    for k_, isl in enumerate(isls):
        for v in isl: isl_of[v.index] = k_
    par = list(range(len(isls)))

    def find(a):
        while par[a] != a:
            par[a] = par[par[a]]; a = par[a]
        return a
    for idxs in pos_groups.values():
        for i in idxs[1:]:
            ra, rb = find(isl_of[idxs[0]]), find(isl_of[i])
            if ra != rb: par[rb] = ra
    groups_ = {}
    for k_, isl in enumerate(isls): groups_.setdefault(find(k_), []).extend(isl)
    eps = 0.02 * span
    pieces = []
    for vs in groups_.values():
        lo = Vector((min(v.co.x for v in vs), min(v.co.y for v in vs), min(v.co.z for v in vs)))
        hi = Vector((max(v.co.x for v in vs), max(v.co.y for v in vs), max(v.co.z for v in vs)))
        ext = [max(hi[i] - lo[i], eps) for i in range(3)]
        pieces.append({"vs": vs, "lo": lo, "hi": hi, "vol": ext[0] * ext[1] * ext[2], "cen": (lo + hi) / 2, "size": max(ext),
                       "corners": len({tuple(round(c, 5) for c in v.co) for v in vs})})
    pieces.sort(key=lambda p: -p["vol"])

    def box_dist(p, lo, hi):
        return Vector((max(lo[i] - p[i], 0.0, p[i] - hi[i]) for i in range(3))).length

    def seg_box(a, b, lo, hi):
        return min(box_dist(a.lerp(b, t / 8.0), lo, hi) for t in range(9))
    decor = []
    for pc in pieces:
        if pc["corners"] > RIGID_MAX: continue
        if min(seg_box(s[1], s[2], pc["lo"], pc["hi"]) for s in segs) <= 0.3 * pc["size"]: continue     # a bone runs through or right along it (the chicken's leg bones sit 0.11 in front of its leg blocks)
        hosts = [h for h in pieces if h is not pc and h["vol"] >= 3 * pc["vol"]
                 and all(h["lo"][i] - eps <= pc["hi"][i] and pc["lo"][i] <= h["hi"][i] + eps for i in range(3))]
        if not hosts: continue
        host = min(hosts, key=lambda h: (round(box_dist(pc["cen"], h["lo"], h["hi"]), 4), h["vol"]))   # the piece it sits on (nearest box, then the smaller one), not the whole body
        near = min(host["vs"], key=lambda v: (v.co - pc["cen"]).length_squared)
        old = sorted({max(W[v.index], key=W[v.index].get) for v in pc["vs"]})
        new = dict(W[near.index])
        if old != [max(new, key=new.get)] or len(new) > 1:
            decor.append({"at": [round(c, 3) for c in pc["cen"]], "size": round(pc["size"], 3), "was": old, "now": max(new, key=new.get)})
            if os.environ.get("RIG_AUDIT_DEBUG") == "1":
                ds = sorted((round(seg_box(s[1], s[2], pc["lo"], pc["hi"]), 3), s[0], [round(c, 2) for c in s[1]], [round(c, 2) for c in s[2]]) for s in segs)[:3]
                print("DEBUG lo", [round(c, 2) for c in pc["lo"]], "hi", [round(c, 2) for c in pc["hi"]], "corners", pc["corners"], "hostvol/vol", round(host["vol"] / pc["vol"], 1), "nearest", ds)
        for v in pc["vs"]: W[v.index] = dict(new)
    rep["decorations"] = decor
    if os.environ.get("RIG_AUDIT") == "1":
        print("AUDIT", e["name"], "changed", len(decor), json.dumps(decor))
        bm.free(); continue
    # vertices at the same spot (split by UV seams) must move together: average them
    for idxs in pos_groups.values():
        if len(idxs) > 1:
            acc = {}
            for i in idxs:
                for n, w in W[i].items(): acc[n] = acc.get(n, 0) + w / len(idxs)
            for i in idxs: W[i] = dict(acc)
    bm.free()
    rep["rigidPieces"] = rigid
    # max 4 bones per vertex (Roblox), normalised
    for i, d in enumerate(W):
        top4 = sorted(d.items(), key=lambda kv: -kv[1])[:4]
        s = sum(w for _, w in top4) or 1.0
        W[i] = {n: w / s for n, w in top4}
    # Studio's importer DROPS bones that move no vertex (and everything below them), and the max-4
    # trim above can empty a bone that only had small weights: give every empty bone a tiny pull on
    # the nearest vertex that still has room (or whose weakest bone is also on other vertices)
    count = {}
    for d in W:
        for n in d: count[n] = count.get(n, 0) + 1
    tiny = 0
    order = sorted(range(len(me.vertices)), key=lambda i: 0)
    for n in names:
        if count.get(n, 0) > 0: continue
        cand = sorted(range(len(me.vertices)), key=lambda i: (me.vertices[i].co - head[n]).length)
        for vi in cand:
            d = W[vi]
            if n in d: break
            if len(d) < 4:
                d[n] = 0.02
            else:
                weak = min(d, key=d.get)
                if count.get(weak, 0) <= 1 or weak in names and False: continue
                del d[weak]; count[weak] -= 1
                d[n] = 0.02
            s = sum(d.values()); W[vi] = {k2: w / s for k2, w in d.items()}
            count[n] = 1; tiny += 1
            break
    rep["tinyBones"] = tiny
    left = [n for n in names if not any(n in d for d in W)]
    rep["bonesWithoutWeight"] = left
    # ---- rebuild the mesh object cleanly in export space with those weights
    bpy.data.objects.remove(hob, do_unlink=True); bpy.data.armatures.remove(harm)
    wob.parent = None
    for m in list(wob.modifiers): wob.modifiers.remove(m)
    wob.vertex_groups.clear()
    groups = {n: wob.vertex_groups.new(name=n) for n in names}
    for i, d in enumerate(W):
        for n, w in d.items(): groups[n].add([i], w, 'REPLACE')
    for v in me.vertices: v.co = to_exp(v.co)
    me.update()
    # ---- export skeleton: old orientations, warped positions
    arm = bpy.data.armatures.new("ARM_" + e["name"]); aob = bpy.data.objects.new(e["name"] + os.environ.get("RIG_TAG", "") + "__RIG", arm); sc.collection.objects.link(aob)
    for o in sc.objects: o.select_set(False)
    aob.select_set(True); bpy.context.view_layer.objects.active = aob
    bpy.ops.object.mode_set(mode='EDIT')
    blen = 0.04 * span * s_exp
    expect = {}
    for n in names:
        eb = arm.edit_bones.new(n)
        hp = to_exp(head[n])
        Rx = G @ (frame[n] @ FIX) @ G                 # the bone's frame in exported axes (columns)
        M4 = Matrix.Identity(4)
        for r in range(3):
            for c in range(3): M4[r][c] = Rx[r][c]
        M4.translation = hp
        eb.head = hp; eb.tail = hp + Vector((Rx[0][1], Rx[1][1], Rx[2][1])) * blen
        eb.matrix = M4
        rp = (Ai @ (head[n] - Cn))                    # expected position in the NEW part's local space, studs
        expect[n] = [round(x, 4) for x in rp]
    for n in names:
        if parent[n]: arm.edit_bones[n].parent = arm.edit_bones[parent[n]]
    bpy.ops.object.mode_set(mode='OBJECT')
    wob.parent = aob
    mod = wob.modifiers.new("Armature", 'ARMATURE'); mod.object = aob
    # lay the animals out in a row (the importer keeps each one where it is)
    off = Vector(((row % 8) * 12.0 * s_exp, 0, (row // 8) * 12.0 * s_exp)) * 0
    row += 1
    nsize = Ai @ (nmx - nmn)
    rep.update({"part": e["part"], "k": k, "exportScale": s_exp, "newSize": [round(abs(x), 4) for x in nsize],
                "bones": len(names), "expect": expect})
    export_objs += [aob, wob]
    print("RIG", e["name"], pack, "fit", round(mism, 3), round(outside, 3), "surf", e.get("_fiterr"), "gap", e.get("_fitgap"), "warp", rep["warp"], rep["warpErr"], "unw", unw, "rigid", rigid, "tiny", tiny, "noWeight", rep["bonesWithoutWeight"], "k", round(k, 2))

if os.environ.get("RIG_AUDIT") == "1":
    json.dump(report, open(report_out, "w"), indent=1)
    print("AUDIT DONE", len(report))
    raise SystemExit
# markers to measure the importer (scale and turn), like the egg exports
for mname, loc in (("SOA_AxisO", (0, 0, 0)), ("SOA_AxisUp", (0, 0, 3)), ("SOA_AxisFwd", (0, 3, 0))):
    bpy.ops.mesh.primitive_cube_add(size=0.2, location=loc)
    mk = bpy.context.active_object; mk.name = mname; export_objs.append(mk)
SPLIT = os.environ.get("RIG_SPLIT")          # a folder: one file per animal, Rig_<Name>.fbx (Studio merges every rig in one file into one)
if SPLIT:
    os.makedirs(SPLIT, exist_ok=True)
    markers = export_objs[-3:]
    for i in range(0, len(export_objs) - 3, 2):
        aob, wob = export_objs[i], export_objs[i + 1]
        name = aob.name.split("__RIG")[0]
        for o in sc.objects: o.select_set(False)
        for o in (aob, wob, *markers): o.select_set(True)
        bpy.context.view_layer.objects.active = aob
        bpy.ops.export_scene.fbx(filepath=os.path.join(SPLIT, "Rig_" + name + ".fbx"), use_selection=True, object_types={'ARMATURE', 'MESH'}, apply_unit_scale=True,
                                 mesh_smooth_type='FACE', bake_space_transform=True, axis_forward='-Z', axis_up='Y',
                                 add_leaf_bones=False, primary_bone_axis='Y', secondary_bone_axis='X', use_armature_deform_only=False,
                                 armature_nodetype='NULL')
        print("FILE", name)
    json.dump(report, open(report_out, "w"), indent=1)
    print("SPLIT DONE", (len(export_objs) - 3) // 2)
    raise SystemExit
for o in sc.objects: o.select_set(False)
for o in export_objs: o.select_set(True)
bpy.context.view_layer.objects.active = export_objs[0]
bpy.ops.export_scene.fbx(filepath=fbx_out, use_selection=True, object_types={'ARMATURE', 'MESH'}, apply_unit_scale=True,
                         mesh_smooth_type='FACE', bake_space_transform=(os.environ.get('RIG_BAKE', '1') == '1'), axis_forward='-Z', axis_up='Y',
                         add_leaf_bones=False, primary_bone_axis='Y', secondary_bone_axis='X', use_armature_deform_only=False,
                         armature_nodetype='NULL')
json.dump(report, open(report_out, "w"), indent=1)
print("FBX", fbx_out, "animals", sum(1 for r in report if "skip" not in r))
