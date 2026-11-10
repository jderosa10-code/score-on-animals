# "Score on Animals" restyle: the same small changes applied to every animal by code,
# so the whole pack looks different from Fake an Egg without remodelling by hand.
#   1. Bigger head (head + eyes + ears + nose scale up together)
#   2. Bigger eyes, plus a white shine dot on each
#   3. Shorter, chunkier legs (animal dropped back onto the ground)
#   4. A little wider body
#   5. Pink blush cheeks
#   6. Brighter, more saturated colours (copy of the texture, original untouched)
# blender -b five_originals.blend -P restyle.py -- <out.blend> <out.png> Name1,Name2,...
import bpy, bmesh, sys, math, colorsys, os
from mathutils import Vector, Matrix
from mathutils.bvhtree import BVHTree

argv = sys.argv[sys.argv.index("--") + 1:]
blend_out, png_out, names = argv[0], argv[1], argv[2].split(",")

HEAD_SCALE = 1.3
EYE_SCALE = 1.4
EYE_DEPTH = 0.75     # eye flattened to 75% along the face normal (set-in look)
EYE_OUT = 0.35       # eye centre sits this many half-depths outside the head surface
EYE_MAX_FRAC = 0.13  # eye radius never more than 13% of the head's height
BLUSH_SIZE = 0.5     # blush dome radius as a fraction of the eye radius
ADD_BLUSH = False
# per-animal tweaks on top of the defaults (pigeon: corgi "body shape weird and eyes too big")
OVERRIDES = {
    "Corgi1": dict(HEAD_SCALE=1.12, EYE_SCALE=1.12, EYE_MAX_FRAC=0.10, LEG_SCALE=0.9, WIDTH_SCALE=1.0),
}
DEFAULTS = None    # pigeon, 2026-11-09: "just remove the blush" (it never looked right on these models)
ADD_SHINE = False    # the game's own eye texture already has a shine (pigeon: old eyes look much better)
LEG_SCALE = 0.72
WIDTH_SCALE = 1.08
SAT_BOOST = 1.25
VAL_BOOST = 1.06


def islands(bm):
    bm.verts.ensure_lookup_table()
    seen = set(); out = []
    for v in bm.verts:
        if v.index in seen: continue
        stack = [v]; isl = []; seen.add(v.index)
        while stack:
            x = stack.pop(); isl.append(x)
            for e in x.link_edges:
                o = e.other_vert(x)
                if o.index not in seen:
                    seen.add(o.index); stack.append(o)
        cs = [q.co for q in isl]
        mn = Vector((min(c.x for c in cs), min(c.y for c in cs), min(c.z for c in cs)))
        mx = Vector((max(c.x for c in cs), max(c.y for c in cs), max(c.z for c in cs)))
        out.append(dict(verts=isl, mn=mn, mx=mx, c=(mn + mx) / 2, s=mx - mn,
                        vol=(mx - mn).x * (mx - mn).y * (mx - mn).z))
    return out


def find_eyes(parts, mx_all):
    # a mirrored pair (same y/z, x mirrored about the midline) of small, round parts; the
    # highest + most forward pair wins
    midx = sum(p["c"].x for p in parts) / len(parts)
    best = None
    for i, a in enumerate(parts):
        for b in parts[i + 1:]:
            if abs(a["c"].y - b["c"].y) > 0.05 or abs(a["c"].z - b["c"].z) > 0.05: continue
            if abs((a["c"].x + b["c"].x) / 2 - midx) > 0.15: continue
            s = a["s"]
            if max(s) > 1.2 or min(s) < 0.6 * max(s): continue      # small and roundish
            score = a["c"].z + a["c"].y * 0.5
            if best is None or score > best[0]:
                best = (score, a, b)
    return (best[1], best[2]) if best else (None, None)


def restyle(ob):
    me = ob.data
    bm = bmesh.new(); bm.from_mesh(me)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=0.0005)
    parts = islands(bm)
    all_co = [v.co for v in bm.verts]
    mn_all = Vector((min(c.x for c in all_co), min(c.y for c in all_co), min(c.z for c in all_co)))
    mx_all = Vector((max(c.x for c in all_co), max(c.y for c in all_co), max(c.z for c in all_co)))
    ground = mn_all.z
    body = max(parts, key=lambda p: p["vol"])
    eyeL, eyeR = find_eyes(parts, mx_all)
    info = dict(eyes=bool(eyeL))

    # --- head group ---
    head = None
    if eyeL:
        em = (eyeL["c"] + eyeR["c"]) / 2
        # the head straddles the midline between the eyes and reaches up to eye height
        # (a front leg can sit right under an eye, so loose padding picks the wrong part)
        cands = [p for p in parts if p is not eyeL and p is not eyeR and p["vol"] > eyeL["vol"] * 2
                 and p["mn"].x - 0.05 <= em.x <= p["mx"].x + 0.05
                 and p["mn"].y - 0.3 <= em.y <= p["mx"].y + 0.3
                 and p["mn"].z - 0.1 <= em.z <= p["mx"].z + 0.3
                 and p["mx"].z >= em.z - 0.1]
        if cands:
            head = min(cands, key=lambda p: p["vol"])
        if head is body:
            head = None   # head and body are one piece (toad): skip the head scale
    head_group = []
    if head:
        hmn, hmx = head["mn"], head["mx"]
        pad = (hmx - hmn) * 0.45
        for p in parts:
            if p is body: continue
            inside = all(hmn[k] - pad[k] <= p["c"][k] <= hmx[k] + pad[k] for k in range(3))
            touches_ground = p["mn"].z < ground + 0.15     # a front leg next to the head is still a leg
            if inside and not touches_ground and p["c"].z >= hmn.z - pad.z * 0.5 and p["vol"] < body["vol"]:
                head_group.append(p)
        # pivot = back-bottom of the head, where it meets the neck/body, so it grows up and forward
        pivot = Vector((head["c"].x, hmn.y + (hmx.y - hmn.y) * 0.25, hmn.z + (hmx.z - hmn.z) * 0.3))
        S = Matrix.Translation(pivot) @ Matrix.Scale(HEAD_SCALE, 4) @ Matrix.Translation(-pivot)
        for p in head_group:
            for v in p["verts"]:
                v.co = S @ v.co
        info["head_parts"] = len(head_group)

    # --- eyes: bigger, then RE-SEATED into the head so they never float ---
    # Find the head surface right under each eye (nearest point on everything except the eyes),
    # then put the bigger eye there with part of it sunk in, flattened a little along the
    # surface normal so it reads as set into the face instead of a ball stuck on.
    eye_data = []
    eyes = [e for e in (eyeL, eyeR) if e]
    if eyes:
        eye_idx = set(v.index for e in eyes for v in e["verts"])
        bm.verts.ensure_lookup_table(); bm.faces.ensure_lookup_table()
        co = [v.co.copy() for v in bm.verts]
        polys = [[v.index for v in f.verts] for f in bm.faces if not any(v.index in eye_idx for v in f.verts)]
        surf = BVHTree.FromPolygons(co, polys)
        hc = (S @ head["c"]) if head else body["c"]
        head_h = (head["s"].z * HEAD_SCALE) if head else body["s"].z
        r_cap = head_h * EYE_MAX_FRAC          # big eyes, but never bigger than this
        for e in eyes:
            cs = [v.co.copy() for v in e["verts"]]
            c = sum(cs, Vector()) / len(cs)
            r = max((q - c).length for q in cs)
            loc, nrm, _, _ = surf.find_nearest(c)
            if loc is None:
                continue
            n = nrm.normalized()
            if n.dot(loc - hc) < 0:               # face normals can wind inward: point it out of the head
                n = -n
            out = c - loc
            if out.length > r * 0.15 and out.dot(n) > 0:
                n = out.normalized()              # eye centre is outside: straight line back to the surface
            k = min(EYE_SCALE, max(1.0, r_cap / r))
            r_new = r * k
            h = r_new * EYE_DEPTH                 # half-depth along the normal
            newc = loc + n * (h * EYE_OUT)        # most of the eye sits outside, the rest sunk in
            for v, q in zip(e["verts"], cs):
                d = q - c
                along = d.dot(n)
                perp = d - n * along
                v.co = newc + perp * k + n * along * k * EYE_DEPTH
            eye_data.append(dict(c=newc, r=r_new, h=h, n=n))
        info["eye_seat"] = [round((d["c"] - surf.find_nearest(d["c"])[0]).length / d["h"], 2) for d in eye_data]

    # --- legs: parts that sit on the ground below the body's middle, shortened from the top ---
    # Only TALL ground pieces are legs. Small ground pieces (claws, toes, separate feet) are feet:
    # they ride up with the leg above them instead of being squashed (pigeon: sloth/aardvark legs broke).
    body_mid = body["c"].z
    animal_h = mx_all.z - ground
    on_ground = [p for p in parts if p["mn"].z < ground + 0.15 and p["c"].z < body_mid and p is not body
                 and p not in head_group]
    legs = [p for p in on_ground if p["s"].z > animal_h * 0.18]
    feet = [p for p in on_ground if p not in legs]
    shrink = {}
    for p in legs:
        top = p["mx"].z
        for v in p["verts"]:
            v.co.z = top - (top - v.co.z) * LEG_SCALE
        shrink[id(p)] = (p["mx"].z - p["mn"].z) * (1 - LEG_SCALE)
    for f in feet:   # follow the nearest leg (by position on the ground)
        if not legs: break
        near = min(legs, key=lambda l: (l["c"].x - f["c"].x) ** 2 + (l["c"].y - f["c"].y) ** 2)
        if ((near["c"].x - f["c"].x) ** 2 + (near["c"].y - f["c"].y) ** 2) ** 0.5 < max(near["s"].x, near["s"].y) * 1.5:
            for v in f["verts"]:
                v.co.z += shrink[id(near)]
    if legs:
        drop = max(shrink.values())
        for v in bm.verts:
            v.co.z -= drop
    info["legs"] = len(legs)
    info["feet"] = len(feet)

    # --- a little wider overall ---
    cx = (mn_all.x + mx_all.x) / 2
    for v in bm.verts:
        v.co.x = cx + (v.co.x - cx) * WIDTH_SCALE
    # put it back on the ground
    lowest = min(v.co.z for v in bm.verts)
    for v in bm.verts:
        v.co.z += ground - lowest

    # carry the eye data through the same moves (width scale, leg drop, re-grounding)
    dz = (-drop if legs else 0.0) + (ground - lowest)
    for d in eye_data:
        c = d["c"]
        d["c"] = Vector((cx + (c.x - cx) * WIDTH_SCALE, c.y, c.z + dz))
        n = d["n"]
        d["n"] = Vector((n.x / WIDTH_SCALE, n.y, n.z)).normalized()

    info["gaps_closed"] = close_gaps(bm)
    # a BVH of the HEAD piece only (the body for one-piece animals like the toad), so the blush
    # can only ever land on the face, never on spines, shoulders or legs
    bm.verts.ensure_lookup_table(); bm.faces.ensure_lookup_table()
    head_idx = set(v.index for v in (head or body)["verts"])
    hco = [v.co.copy() for v in bm.verts]
    hpolys = [[v.index for v in f.verts] for f in bm.faces if all(v.index in head_idx for v in f.verts)]
    head_bvh = BVHTree.FromPolygons(hco, hpolys) if hpolys else None
    head_ctr = sum((hco[i] for i in head_idx), Vector()) / max(1, len(head_idx))
    for d in eye_data:
        d["head_bvh"], d["head_ctr"] = head_bvh, head_ctr
    bm.to_mesh(me)
    bvh = BVHTree.FromBMesh(bm)
    eye_vidx = sorted(v.index for e in eyes for v in e["verts"]) if eyes else []
    bm.free()
    return info, eye_data, bvh, cx, eye_vidx


def _part_bvhs(bm, parts):
    """One BVH per loose piece, with outward-facing normals (so we can tell inside from outside)."""
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.faces.ensure_lookup_table()
    owner = {v.index: i for i, p in enumerate(parts) for v in p["verts"]}
    co = [v.co.copy() for v in bm.verts]
    polys = [[] for _ in parts]
    for f in bm.faces:
        polys[owner[f.verts[0].index]].append([v.index for v in f.verts])
    return [BVHTree.FromPolygons(co, pl) if pl else None for pl in polys]


def _gap(points, bvh):
    """Smallest distance from any point to a piece's surface; 0 if any point is INSIDE it."""
    best = (math.inf, None, None)
    for q in points:
        loc, nrm, _, dist = bvh.find_nearest(q)
        if loc is None: continue
        if (q - loc).dot(nrm) < 0:
            return (0.0, q, loc)
        if dist < best[0]:
            best = (dist, q, loc)
    return best


def _pair_gap(pa, pb, ba, bb):
    g1 = _gap([v.co for v in pa["verts"]], bb)
    g2 = _gap([v.co for v in pb["verts"]], ba)
    return g1 if g1[0] <= g2[0] else (g2[0], g2[2], g2[1])   # always (dist, point on a, point on b)


def _attached(parts, bvhs, tol):
    """Which pieces connect back to the biggest one (the body) through touching/overlapping pieces."""
    n = len(parts)
    gaps = {}
    for i in range(n):
        for j in range(i + 1, n):
            if bvhs[i] and bvhs[j]:
                gaps[(i, j)] = gaps[(j, i)] = _pair_gap(parts[i], parts[j], bvhs[i], bvhs[j])
    body = max(range(n), key=lambda i: parts[i]["vol"])
    seen = {body}; stack = [body]
    while stack:
        i = stack.pop()
        for j in range(n):
            if j not in seen and (i, j) in gaps and gaps[(i, j)][0] <= tol:
                seen.add(j); stack.append(j)
    return seen, gaps


def close_gaps(bm, tol=0.02, overlap=0.03):
    """Slide every piece that isn't connected to the body onto the nearest connected piece."""
    moved = 0
    for _ in range(4):
        parts = islands(bm)
        bvhs = _part_bvhs(bm, parts)
        seen, gaps = _attached(parts, bvhs, tol)
        loose = [i for i in range(len(parts)) if i not in seen]
        if not loose:
            break
        # move the loose piece that's closest to the connected group, then re-check
        i, j = min(((i, j) for i in loose for j in seen if (i, j) in gaps), key=lambda ij: gaps[ij][0])
        d, pa, pb = gaps[(i, j)]
        shift = (pb - pa).normalized() * (d + overlap)
        print("   gap-close part", i, len(parts[i]["verts"]), "v ->", j, "gap", round(d, 3))
        for v in parts[i]["verts"]:
            v.co += shift
        moved += 1
    return moved


def recolor(ob):
    for slot in ob.material_slots:
        mat = slot.material
        if not mat or not mat.use_nodes: continue
        new = mat.copy(); new.name = mat.name + "_SOA"
        slot.material = new
        for n in new.node_tree.nodes:
            if n.type == 'TEX_IMAGE' and n.image:
                img = n.image.copy(); img.name = n.image.name.replace(".png", "") + "_SOA"
                px = list(img.pixels)
                for i in range(0, len(px), 4):
                    h, s, v = colorsys.rgb_to_hsv(px[i], px[i + 1], px[i + 2])
                    s = min(1.0, s * SAT_BOOST); v = min(1.0, v * VAL_BOOST)
                    px[i], px[i + 1], px[i + 2] = colorsys.hsv_to_rgb(h, s, v)
                img.pixels = px
                img.pack()
                n.image = img
                n.interpolation = 'Closest'


GRAD_BOTTOM = 0.78   # colour multiplier at the feet
GRAD_TOP = 1.06      # ... and at the top of the head
BAKE_RES = 256


def mix_socket(node, kind, name):
    return next(s for s in getattr(node, kind) if s.name == name and s.type == 'RGBA')


def gradient_and_bake(ob):
    """Soft vertical gradient (darker feet, lighter top) on top of the recoloured texture,
    baked into one new texture on a fresh UV map, so it exports to Roblox as a plain texture."""
    me = ob.data
    src_uv = me.uv_layers[0].name
    zs = [v.co.z for v in me.vertices]
    zmin, zmax = min(zs), max(zs)
    img = bpy.data.images.new(ob.name + "_tex", BAKE_RES, BAKE_RES)
    for slot in ob.material_slots:
        mat = slot.material
        nt = mat.node_tree; N = nt.nodes; L = nt.links
        tex = next(n for n in N if n.type == 'TEX_IMAGE')
        bsdf = next(n for n in N if n.type == 'BSDF_PRINCIPLED')
        uvn = N.new("ShaderNodeUVMap"); uvn.uv_map = src_uv
        L.new(uvn.outputs["UV"], tex.inputs["Vector"])
        tc = N.new("ShaderNodeTexCoord"); sep = N.new("ShaderNodeSeparateXYZ")
        L.new(tc.outputs["Object"], sep.inputs[0])
        mr = N.new("ShaderNodeMapRange")
        mr.inputs["From Min"].default_value = zmin; mr.inputs["From Max"].default_value = zmax
        mr.inputs["To Min"].default_value = GRAD_BOTTOM; mr.inputs["To Max"].default_value = GRAD_TOP
        mr.interpolation_type = 'SMOOTHSTEP'
        L.new(sep.outputs["Z"], mr.inputs["Value"])
        mix = N.new("ShaderNodeMix"); mix.data_type = 'RGBA'; mix.blend_type = 'MULTIPLY'
        mix.inputs["Factor"].default_value = 1.0
        L.new(tex.outputs["Color"], mix_socket(mix, "inputs", "A"))
        L.new(mr.outputs["Result"], mix_socket(mix, "inputs", "B"))
        L.new(mix_socket(mix, "outputs", "Result"), bsdf.inputs["Base Color"])
        bake_node = N.new("ShaderNodeTexImage"); bake_node.image = img
        N.active = bake_node
    # fresh, non-overlapping UVs to bake into
    me.uv_layers.new(name="BakeUV")
    me.uv_layers.active = me.uv_layers["BakeUV"]
    bpy.ops.object.select_all(action='DESELECT')
    ob.select_set(True); bpy.context.view_layer.objects.active = ob
    bpy.ops.object.mode_set(mode='EDIT')
    bpy.ops.mesh.select_all(action='SELECT')
    bpy.ops.uv.smart_project(angle_limit=math.radians(66), island_margin=0.01)
    bpy.ops.object.mode_set(mode='OBJECT')
    sc = bpy.context.scene
    sc.render.engine = 'CYCLES'; sc.cycles.device = 'CPU'; sc.cycles.samples = 4
    bpy.ops.object.bake(type='DIFFUSE', pass_filter={'COLOR'}, use_clear=True, margin=4)
    img.pack()
    # swap to the baked texture only (what Roblox would get)
    for slot in ob.material_slots:
        nt = slot.material.node_tree; N = nt.nodes; L = nt.links
        bsdf = next(n for n in N if n.type == 'BSDF_PRINCIPLED')
        bake_node = next(n for n in N if n.type == 'TEX_IMAGE' and n.image == img)
        uvb = N.new("ShaderNodeUVMap"); uvb.uv_map = "BakeUV"
        L.new(uvb.outputs["UV"], bake_node.inputs["Vector"])
        L.new(bake_node.outputs["Color"], bsdf.inputs["Base Color"])
    # re-fetch: edit-mode toggles reallocate the UV layers, so the old Python reference is stale
    me.uv_layers["BakeUV"].active_render = True
    me.uv_layers.active = me.uv_layers["BakeUV"]
    # keep the original UVs too: the eyes use them so the game's real eye texture can go back on
    ob.select_set(False)


def flat_mat(name, rgb, emit=0.0):
    m = bpy.data.materials.get(name)
    if m: return m
    m = bpy.data.materials.new(name); m.use_nodes = True
    b = m.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = (*rgb, 1)
    b.inputs["Roughness"].default_value = 0.5
    if emit:
        b.inputs["Emission Color"].default_value = (*rgb, 1)
        b.inputs["Emission Strength"].default_value = emit
    return m


def add_sphere(name, loc, scale, rot, mat, parent, segs=10, rings=6):
    me = bpy.data.meshes.new(name)
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=segs, v_segments=rings, radius=1.0)
    bm.to_mesh(me); bm.free()
    o = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(o)
    o.location = loc; o.scale = scale; o.rotation_euler = rot
    o.data.materials.append(mat)
    o.parent = parent   # loc is in the parent's local space
    return o


def split_eyes(ob, eye_vidx):
    """Move the eye geometry into its own child object with one glossy dark material, so every
    animal gets the same bead eyes (some originals have blank white eyes)."""
    if not eye_vidx: return None
    keep = set(eye_vidx)
    src = ob.data
    eme = src.copy(); eme.name = ob.name + "_Eyes"
    bm = bmesh.new(); bm.from_mesh(eme)
    bm.verts.ensure_lookup_table()
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if v.index not in keep], context='VERTS')
    bm.to_mesh(eme); bm.free()
    eme.materials.clear(); eme.materials.append(flat_mat("SOA_EyeBlack", (0.02, 0.02, 0.025)))
    eme.materials[0].node_tree.nodes["Principled BSDF"].inputs["Roughness"].default_value = 0.2
    # eyes keep the ORIGINAL UVs (not the bake), so in Studio they can wear the real
    # SurfaceAppearance from Jacob's model: the in-game eyes look much better than the OBJ export
    if "BakeUV" in eme.uv_layers:
        eme.uv_layers.remove(eme.uv_layers["BakeUV"])
    if len(eme.uv_layers):
        eme.uv_layers.active = eme.uv_layers[0]
    bm = bmesh.new(); bm.from_mesh(src)
    bm.verts.ensure_lookup_table()
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if v.index in keep], context='VERTS')
    bm.to_mesh(src); bm.free()
    eo = bpy.data.objects.new(ob.name + "_Eyes", eme)
    bpy.context.scene.collection.objects.link(eo)
    eo.parent = ob
    return eo


def add_face_bits(ob, eye_data, bvh, cx, eye_obj):
    blush = flat_mat("SOA_Blush", (1.0, 0.33, 0.45))
    shine = flat_mat("SOA_Shine", (1.0, 1.0, 1.0), emit=0.6)
    # built from the raw mesh so it's in the same local space as everything else here
    eye_bvh = (BVHTree.FromPolygons([v.co.copy() for v in eye_obj.data.vertices],
                                    [list(p.vertices) for p in eye_obj.data.polygons]) if eye_obj else None)
    blush_spots = []
    for ed in eye_data:
        c, r, h, n = ed["c"], ed["r"], ed["h"], ed["n"]
        side = 1 if c.x > cx else -1
        # shine: a small flat dot stuck ON the eye's real surface (ray-cast onto the eye mesh),
        # up and toward the front from the way the eye faces
        s = (n + Vector((0.1 * side, 0.5, 0.7))).normalized()
        if eye_bvh and ADD_SHINE:
            hit = eye_bvh.ray_cast(c + s * r * 4, -s, r * 8)
            if hit[0] is not None:
                sn = hit[1].copy()
                if sn.dot(s) < 0: sn.negate()
                add_sphere(ob.name + "_Shine", hit[0], (r * 0.2, r * 0.2, r * 0.06),
                           sn.to_track_quat('Z', 'Y').to_euler(), shine, ob, 8, 5)
        # cheek = on the HEAD piece, a bit below and slightly in front of the eye, on this side
        hb, hc = ed.get("head_bvh"), ed.get("head_ctr")
        # Try a small grid of spots under the eye and keep the most FRONT-facing one, so on long
        # heads (polar bear) it sits on the cheek toward the snout, not on the side edge of the head.
        best = None
        rb = r * BLUSH_SIZE
        if hb:
            for down in (1.0, 1.3, 1.6, 1.9):
                for fwd in (0.2, 0.5, 0.8, 1.1):
                    for out in (-0.3, 0.0, 0.25):
                        want = c + Vector((side * r * out, r * fwd, -r * down))
                        loc, nrm, _, _ = hb.find_nearest(want)
                        if loc is None: continue
                        n = nrm.normalized()
                        if n.dot(loc - hc) < 0: n = -n       # point out of the head
                        # the blush's top edge must clear the eye's bottom edge, with a gap
                        gap = (c.z - r) - (loc.z + rb * 0.85)
                        ok = (gap > r * 0.12
                              and (loc - c).length < r * 2.8      # still near the eye
                              and n.y > 0.35                      # faces FORWARD (not the side edge)
                              and n.x * side > -0.15              # not facing the other side
                              and (loc.x - cx) * side > r * 0.3)  # on this eye's side of the face
                        if ok:
                            score = n.y - abs(fwd - 0.5) * 0.15 - (loc - c).length / r * 0.1
                            if best is None or score > best[2]:
                                best = (loc, n, score)
        if best:
            blush_spots.append((best[0], best[1], r))   # (loc, normal, eye radius)
        print("BLUSH", ob.name, side, bool(best))

    # Both cheeks from ONE spot: take the most front-facing hit and mirror it across the animal's
    # midline, so the two sides always match (pigeon: "works on one side, other it doesn't").
    # The disc sits fully ON the skin (offset by its own thickness), never half-sunk.
    if blush_spots and ADD_BLUSH:
        loc, nrm, r = max(blush_spots, key=lambda s: s[1].y)
        # a rounded dome set into the cheek the same way the eyes are (pigeon: "make the blush look
        # kinda like the eyes"): smooth, puffy, partly sunk, never a flat sticker
        rb = r * BLUSH_SIZE                 # radius across the cheek
        hb_depth = rb * 0.35                # half-depth along the cheek normal (a low raised patch)
        hb = eye_data[0].get("head_bvh")
        for sx in (1, -1):
            l = loc if sx == 1 else Vector((2 * cx - loc.x, loc.y, loc.z))
            n = nrm if sx == 1 else Vector((-nrm.x, nrm.y, nrm.z))
            # re-snap the mirrored spot onto the head's real surface on this side
            if hb:
                near = hb.find_nearest(l)
                if near[0] is not None and (near[0] - l).length < r:
                    l = near[0]
            # centre ON the skin: half the patch is sunk in, so its edge meets the face (no floating rim)
            o = add_sphere(ob.name + "_Blush", l, (rb * 1.2, rb * 0.85, hb_depth),
                           n.to_track_quat('Z', 'Y').to_euler(), blush, ob, 16, 8)
            for p in o.data.polygons:
                p.use_smooth = True


def set_shading(ob, smooth):
    """Flat or smooth shading, with any imported custom normals removed (they made the bodies soft)."""
    bpy.ops.object.select_all(action='DESELECT')
    ob.select_set(True); bpy.context.view_layer.objects.active = ob
    if ob.data.has_custom_normals:
        bpy.ops.mesh.customdata_custom_splitnormals_clear()
    for p in ob.data.polygons:
        p.use_smooth = smooth
    ob.select_set(False)


def check_floating(ob, tol=0.03):
    """Every loose piece must touch or overlap another piece; face bits must sit on the surface.
    Returns a list of problems (empty = clean)."""
    bm = bmesh.new(); bm.from_mesh(ob.data)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=0.0005)
    parts = islands(bm)
    bvhs = _part_bvhs(bm, parts)
    seen, gaps = _attached(parts, bvhs, tol)
    probs = []
    for i, p in enumerate(parts):
        if i not in seen:
            g = min((gaps[(i, j)][0] for j in seen if (i, j) in gaps), default=-1)
            probs.append(f"part {i} ({len(p['verts'])}v at {tuple(round(a, 1) for a in p['c'])}) floats {g:.2f}")
    whole = BVHTree.FromBMesh(bm)
    bm.free()
    eyes = next((c for c in ob.children if c.name.endswith("_Eyes")), None)
    eye_bvh = None
    if eyes:
        eb = bmesh.new(); eb.from_mesh(eyes.data); bmesh.ops.recalc_face_normals(eb, faces=eb.faces)
        eye_bvh = BVHTree.FromBMesh(eb); eb.free()
    for ch in ob.children:
        if ch.type != 'MESH': continue
        # matrix_basis = the child's own loc/rot/scale in the parent's space (parent inverse is identity)
        ref = eye_bvh if ("_Shine" in ch.name and eye_bvh) else whole   # shine sits on the eye
        g = _gap([ch.matrix_basis @ v.co for v in ch.data.vertices], ref)[0]
        if g > tol:
            probs.append(f"{ch.name} floats {g:.2f}")
    return probs


# ---- build the side-by-side ----
sc = bpy.context.scene
row_x = 0.0
GAP = 2.5
report = {}
pairs = []
for name in names:
    if DEFAULTS is None:
        DEFAULTS = {k: globals()[k] for k in ("HEAD_SCALE", "EYE_SCALE", "EYE_MAX_FRAC", "LEG_SCALE", "WIDTH_SCALE")}
    globals().update(DEFAULTS)
    globals().update(OVERRIDES.get(name, {}))
    src = bpy.data.objects[name]
    co = [src.matrix_world @ v.co for v in src.data.vertices]
    mn = Vector((min(c.x for c in co), min(c.y for c in co), min(c.z for c in co)))
    mx = Vector((max(c.x for c in co), max(c.y for c in co), max(c.z for c in co)))
    w = mx.x - mn.x
    # the camera looks from +Y, so lower X shows on the RIGHT: NEW goes first (right), OLD second (left)
    new = src.copy(); new.data = src.data.copy(); new.name = name + "_SOA"
    sc.collection.objects.link(new)
    new.location = Vector((row_x - mn.x, -(mn.y + mx.y) / 2, -mn.z))
    # move the original into the row (as a whole object, mesh untouched)
    src.location = new.location + Vector((w * WIDTH_SCALE + 1.2, 0, 0))
    for slot in src.material_slots:   # pixel-sharp textures on the original too, for a fair compare
        if slot.material and slot.material.use_nodes:
            for n in slot.material.node_tree.nodes:
                if n.type == 'TEX_IMAGE': n.interpolation = 'Closest'
    info, eye_data, bvh, cx, eye_vidx = restyle(new)
    recolor(new)
    gradient_and_bake(new)
    eye_obj = split_eyes(new, eye_vidx)
    add_face_bits(new, eye_data, bvh, cx, eye_obj)
    # crisp faceted body like Jacob's models (pigeon: "define the edges a bit more"), smooth eyes
    set_shading(new, smooth=False)
    if eye_obj:
        set_shading(eye_obj, smooth=True)
    info["float_NEW"] = check_floating(new)
    info["float_OLD"] = check_floating(src)
    report[name] = info
    pairs.append((name, new.location.x + mn.x, src.location.x + mx.x, mx.z - mn.z))
    for label, o in (("OLD", src), ("NEW", new)):
        cu = bpy.data.curves.new(label, 'FONT'); cu.body = label; cu.align_x = 'CENTER'
        cu.size = 0.6
        t = bpy.data.objects.new(name + "_" + label, cu); sc.collection.objects.link(t)
        # standing up in front of the animal, readable from the camera side (+Y)
        t.location = Vector((o.location.x + (mn.x + mx.x) / 2, (mx.y - mn.y) / 2 + 1.2, 0.05))
        t.rotation_euler = (math.radians(90), 0, math.radians(180))
        t.data.materials.append(flat_mat("SOA_Label_" + label, (0.1, 0.1, 0.1) if label == "OLD" else (0.05, 0.45, 0.15)))
    row_x += 2.1 * w + 1.2 + GAP

for k, v in report.items():
    print("RESTYLE", k, v)

# ---- ground, light, camera ----
bpy.ops.mesh.primitive_plane_add(size=400, location=(row_x / 2, 0, 0))
g = bpy.context.active_object; g.name = "Ground"
g.data.materials.append(flat_mat("SOA_Ground", (0.82, 0.86, 0.80)))
sun = bpy.data.objects.new("Sun", bpy.data.lights.new("Sun", 'SUN'))
sun.data.energy = 3.5; sun.rotation_euler = (math.radians(50), 0, math.radians(-30))
sc.collection.objects.link(sun)
sc.world = sc.world or bpy.data.worlds.new("World")
sc.world.use_nodes = True
sc.world.node_tree.nodes["Background"].inputs["Color"].default_value = (0.75, 0.82, 0.92, 1)
sc.world.node_tree.nodes["Background"].inputs["Strength"].default_value = 0.9

cam = bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam")); sc.collection.objects.link(cam)
cam.data.type = 'ORTHO'
width = row_x - GAP
cam.data.ortho_scale = width * 1.06
ctr = Vector((width / 2, 0, 3.0))
az = math.radians(25)
r = 60
cam.location = ctr + Vector((math.sin(az) * r * 0.35, r * math.cos(az), r * 0.42))
cam.rotation_euler = (ctr - cam.location).to_track_quat('-Z', 'Y').to_euler()
sc.camera = cam

sc.render.engine = 'CYCLES'
sc.cycles.device = 'CPU'
sc.cycles.samples = 48
sc.cycles.use_denoising = True
sc.render.resolution_x = 2400
sc.render.resolution_y = 900
sc.render.filepath = png_out
bpy.ops.wm.save_as_mainfile(filepath=blend_out)
FAST = os.environ.get("SOA_FAST") == "1"     # big batches: skip the row render, small quick close-ups
if not FAST:
    bpy.ops.render.render(write_still=True)

# close-up of each OLD | NEW pair
sc.render.resolution_x = 600 if FAST else 1200
sc.render.resolution_y = 400 if FAST else 800
if FAST:
    sc.cycles.samples = 12
for name, x0, x1, h in pairs:
    w = x1 - x0
    c = Vector(((x0 + x1) / 2, 0, h * 0.45))
    cam.data.ortho_scale = max(w * 1.25, h * 1.25 * 1.5)
    az = math.radians(20)
    cam.location = c + Vector((math.sin(az) * 30 * 0.3, 30 * math.cos(az), 30 * 0.38))
    cam.rotation_euler = (c - cam.location).to_track_quat('-Z', 'Y').to_euler()
    sc.render.filepath = png_out.replace(".png", "_" + name + ".png")
    bpy.ops.render.render(write_still=True)
print("DONE")
