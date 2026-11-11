"""NEW FEATURES for the eggs (pigeon, 2026-11-10: "the blocky isn't better, I'm just saying the
features of the egg need to be different"). The shell is NOT touched and nothing is resized. The
animal's features (ears, horns, tusks, tails) are removed and replaced by newly designed ones, still
the same animal. Each new piece takes its colours from the piece it replaces (texels of the egg's own
texture), so the egg's textures and mutation looks still fit.

Hand-designed per egg (DESIGNS below). Eggs face Blender -X, left/right is Y, up is Z.

blender -b eggs2_originals.blend -P egg_features.py -- <out.blend> <render_dir> [json_out]
"""
import bpy, bmesh, sys, os, math, json
from mathutils import Vector, Matrix

argv = sys.argv[sys.argv.index("--") + 1:]
blend_out, render_dir = argv[0], argv[1]
json_out = argv[2] if len(argv) > 2 else None
os.makedirs(render_dir, exist_ok=True)
sc = bpy.context.scene


def catmull(pts, per=5):
    P = [Vector(p) for p in pts]
    P = [P[0] + (P[0] - P[1])] + P + [P[-1] + (P[-1] - P[-2])]
    out = []
    for i in range(1, len(P) - 2):
        for k in range(per):
            t = k / per
            a, b, c, d = P[i - 1], P[i], P[i + 1], P[i + 2]
            out.append(0.5 * ((2 * b) + (-a + c) * t + (2 * a - 5 * b + 4 * c - d) * t * t + (-a + 3 * b - 3 * c + d) * t ** 3))
    out.append(P[-2].copy())
    return out


def sweep(bm, pts, side, wa, wb, sides=6, mirror=False):
    """Tube along a smooth path. wa(u), wb(u): half-width along `side` and across it, u = 0..1."""
    path = catmull(pts)
    if mirror: path = [Vector((p.x, -p.y, p.z)) for p in path]
    s = Vector(side)
    if mirror: s = Vector((s.x, -s.y, s.z))
    rings, n = [], len(path)
    for i, p in enumerate(path):
        t = (path[min(i + 1, n - 1)] - path[max(i - 1, 0)]).normalized()
        s = (s - t * s.dot(t)).normalized()                # carried along the path
        nrm = t.cross(s)
        u = i / (n - 1)
        a, b = wa(u), wb(u)
        rings.append([bm.verts.new(p + s * a * math.cos(2 * math.pi * k / sides) + nrm * b * math.sin(2 * math.pi * k / sides)) for k in range(sides)])
    faces = []
    for i in range(n - 1):
        for k in range(sides):
            q = [rings[i][k], rings[i][(k + 1) % sides], rings[i + 1][(k + 1) % sides], rings[i + 1][k]]
            faces.append(bm.faces.new(q))
    faces.append(bm.faces.new(rings[-1]))
    faces.append(bm.faces.new(list(reversed(rings[0]))))
    return faces


def ball(bm, centre, r):
    res = bmesh.ops.create_icosphere(bm, subdivisions=1, radius=r, matrix=Matrix.Translation(Vector(centre)))
    return list({f for v in res["verts"] for f in v.link_faces})


taper = lambda r0, r1, p=1.0: (lambda u: r1 + (r0 - r1) * (1 - u) ** p)
leaf = lambda w, tip=0.25: (lambda u: w * (0.7 + 0.45 * math.sin(math.pi * min(u, 0.999))) * (1.0 if u < 0.8 else 1 - (1 - tip) * (u - 0.8) / 0.2))
flat = lambda w: (lambda u: w)

# name -> list of (what to remove: centres of the old pieces, how to build the new piece, mirrored?)
DESIGNS = {
    "Eggbunny1": [
        dict(old=[(-0.66, 0.95, 1.95)], pair=True, ear=True,          # LOP EARS hanging down the sides
             # v1 arched high and stood off the egg like bag handles: now wider and hugging the sides
             build=lambda bm, m: sweep(bm, [(-0.5, 0.6, 1.3), (-0.5, 1.45, 1.75), (-0.5, 2.1, 1.0), (-0.5, 2.3, -0.3), (-0.5, 2.25, -1.6)],
                                       (1, 0.35, 0), leaf(0.85, 0.5), flat(0.22), mirror=m)),
        dict(old=[(1.87, 0.0, -2.03)], pair=False,                    # round pom-pom tail
             build=lambda bm, m: ball(bm, (2.25, 0, -1.9), 0.8)),
    ],
    "Eggcow1": [
        dict(old=[(-0.15, 1.0, 1.99)], pair=True,                     # big LONGHORN horns
             build=lambda bm, m: sweep(bm, [(-0.15, 0.7, 1.6), (-0.15, 1.7, 2.1), (-0.15, 2.5, 2.6), (-0.3, 2.9, 3.5), (-0.6, 2.8, 4.2)],
                                       (1, 0, 0), taper(0.36, 0.05, 0.8), taper(0.36, 0.05, 0.8), mirror=m)),
        dict(old=[(0.42, 1.57, 2.0)], pair=True, ear=True,            # droopy ears under the horns
             build=lambda bm, m: sweep(bm, [(0.45, 1.2, 1.5), (0.45, 2.1, 1.55), (0.45, 2.9, 1.2), (0.45, 3.2, 0.5)],
                                       (0, 0, 1), leaf(0.5), flat(0.16), mirror=m)),
    ],
    "Eggmammoth1": [
        dict(old=[(-1.36, 1.27, -1.21)], pair=True,                   # long tusks that curl up and cross
             build=lambda bm, m: sweep(bm, [(-0.5, 1.0, -0.8), (-1.9, 1.45, -1.9), (-3.3, 1.5, -2.1), (-4.3, 1.0, -1.3), (-4.4, 0.35, -0.1), (-3.8, 0.1, 0.7)],
                                       (0, 1, 0), taper(0.4, 0.06), taper(0.4, 0.06), mirror=m)),
        dict(old=[(0.71, 2.25, 0.87)], pair=True, ear=True,           # big drooping fan ears
             build=lambda bm, m: sweep(bm, [(0.7, 1.6, 1.2), (0.7, 2.6, 1.3), (0.7, 3.3, 0.6), (0.7, 3.3, -0.6)],
                                       (0, 0, 1), leaf(1.15, 0.45), flat(0.2), mirror=m)),
    ],
    "Eggcat1": [
        dict(old=[(-1.02, 0.77, 2.06)], pair=True, ear=True,          # tall lynx ears angled outward
             # v1 was long and thin and read as horns: now short, wide triangles set low and tilted out
             build=lambda bm, m: sweep(bm, [(-1.0, 0.35, 1.1), (-1.0, 0.95, 1.9), (-1.0, 1.6, 2.55), (-1.0, 1.95, 2.9)],
                                       (0, 0.8, -0.6), taper(1.05, 0.08, 0.75), flat(0.2), mirror=m)),
        dict(old=[(1.94, 0.0, -0.67)], pair=False,                    # long tail curled up in an S
             build=lambda bm, m: sweep(bm, [(0.3, 0, -1.7), (1.9, 0, -2.3), (3.2, 0, -1.6), (3.4, 0, 0.0), (2.6, 0, 1.0), (2.9, 0, 2.1)],
                                       (0, 1, 0), flat(0.46), flat(0.46))),
    ],
}


def islands(bm):
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


def redesign(src):
    ob = src.copy(); ob.data = src.data.copy(); ob.name = src.name + "_FEAT"
    sc.collection.objects.link(ob)
    me = ob.data
    img = next((n.image for m in me.materials if m and m.use_nodes for n in m.node_tree.nodes if n.type == 'TEX_IMAGE' and n.image), None)
    W, H = img.size
    px = list(img.pixels)

    def colour(uv):
        x, y = min(W - 1, max(0, int(uv.x * W))), min(H - 1, max(0, int(uv.y * H)))
        i = (y * W + x) * 4
        return (px[i], px[i + 1], px[i + 2])

    bm = bmesh.new(); bm.from_mesh(me)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-4)
    bm.verts.ensure_lookup_table(); bm.verts.index_update()
    uvl = bm.loops.layers.uv.active
    isls = islands(bm)

    def centre(isl):
        cs = [v.co for v in isl]
        return Vector(((min(c.x for c in cs) + max(c.x for c in cs)) / 2, (min(c.y for c in cs) + max(c.y for c in cs)) / 2, (min(c.z for c in cs) + max(c.z for c in cs)) / 2))

    for d in DESIGNS[src.name]:
        targets = [Vector(c) for c in d["old"]]
        if d["pair"]: targets += [Vector((c.x, -c.y, c.z)) for c in list(targets)]
        olds = [min(isls, key=lambda isl: (centre(isl) - t).length) for t in targets]
        # the colours of the old piece: its main colour, and (for ears) its second colour
        tally = {}
        for isl in olds:
            for f in {f for v in isl for f in v.link_faces}:
                uv = sum((l[uvl].uv for l in f.loops), Vector((0, 0))) / len(f.loops)
                c = colour(uv)
                key = tuple(round(a * 8) for a in c)
                e = tally.setdefault(key, [0.0, uv, c]); e[0] += f.calc_area()
        ranked = sorted(tally.values(), key=lambda e: -e[0])
        main = ranked[0]
        inner = next((e for e in ranked[1:] if sum(abs(a - b) for a, b in zip(e[2], main[2])) > 0.25), None)
        for isl in olds:
            bmesh.ops.delete(bm, geom=[v for v in isl if v.is_valid], context='VERTS')
        new = []
        for m in ((False, True) if d["pair"] else (False,)):
            fs = d["build"](bm, m)
            if m: bmesh.ops.reverse_faces(bm, faces=fs)
            new += fs
        bmesh.ops.recalc_face_normals(bm, faces=new)
        for f in new:
            f.normal_update()
            use = inner if (d.get("ear") and inner and f.normal.x < -0.35) else main
            for l in f.loops: l[uvl].uv = use[1]
        isls = islands(bm)
    bm.normal_update()
    bm.to_mesh(me); bm.free()
    for p in me.polygons: p.use_smooth = False
    return ob


rows = []
for n in DESIGNS:
    src = bpy.data.objects.get(n)
    if not src: print("MISSING", n); continue
    rows.append((src, redesign(src)))
    print("FEATURES", n)
bpy.ops.wm.save_as_mainfile(filepath=blend_out)

if json_out:
    payload = {}
    for src, ob in rows:
        me = ob.data
        cs = [v.co for v in me.vertices]; ocs = [v.co for v in src.data.vertices]
        # keep the OLD egg's centre and ground so the new one sits exactly where the old one does
        omn = Vector((min(c.x for c in ocs), min(c.y for c in ocs), min(c.z for c in ocs)))
        omx = Vector((max(c.x for c in ocs), max(c.y for c in ocs), max(c.z for c in ocs)))
        mn = Vector((min(c.x for c in cs), min(c.y for c in cs), min(c.z for c in cs)))
        mx = Vector((max(c.x for c in cs), max(c.y for c in cs), max(c.z for c in cs)))
        ctr = (mn + mx) / 2
        verts = []
        for v in me.vertices:
            q = v.co - ctr; verts += [round(q.x, 4), round(q.z, 4), round(-q.y, 4)]
        uvl = me.uv_layers.active.data
        me.calc_loop_triangles()
        uvs, tris = [], []
        for t in me.loop_triangles:
            ids = []
            for li in t.loops:
                u, v = uvl[li].uv; uvs += [round(u, 5), round(1 - v, 5)]; ids.append(len(uvs) // 2)
            vi = [me.loops[li].vertex_index + 1 for li in t.loops]
            tris.append(vi + ids)
        off = ctr - (omn + omx) / 2
        payload[src.name] = dict(verts=verts, uvs=uvs, tris=tris, offset=[round(off.x, 4), round(off.z, 4), round(-off.y, 4)])
    json.dump(payload, open(json_out, "w"))

sc.render.engine = 'BLENDER_WORKBENCH'
sh = sc.display.shading
sh.light = 'STUDIO'; sh.color_type = 'TEXTURE'; sh.show_cavity = True; sh.cavity_type = 'WORLD'; sh.show_object_outline = True
sc.render.resolution_x, sc.render.resolution_y = 900, 520
cam = bpy.data.objects.new("FCam", bpy.data.cameras.new("FCam")); sc.collection.objects.link(cam)
cam.data.type = 'ORTHO'; sc.camera = cam
for src, new in rows:
    for o in sc.objects:
        if o.type == 'MESH': o.hide_render = o not in (src, new)
    for tag, d in (("a", Vector((-1, -0.75, 0.4))), ("b", Vector((1, 0.75, 0.4)))):
        right = -Vector((0, 0, 1)).cross(-d).normalized()
        ws = max(new.dimensions.x, new.dimensions.y) * 1.15
        src.location = -right * ws * 0.5; new.location = right * ws * 0.5
        base = -min(Vector(b).z for b in src.bound_box)
        src.location.z = base; new.location.z = base
        bpy.context.view_layer.update()
        pts = [o.matrix_world @ Vector(b) for o in (src, new) for b in o.bound_box]
        mn = Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
        mx = Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
        ctr = (mn + mx) / 2
        cam.data.ortho_scale = max(ws * 2.2, (mx.z - mn.z) * 1.25 * 900 / 520)
        cam.location = ctr + d.normalized() * 80
        cam.rotation_euler = (ctr - cam.location).to_track_quat('-Z', 'Y').to_euler()
        sc.render.filepath = os.path.join(render_dir, f"{src.name}_{tag}.png")
        bpy.ops.render.render(write_still=True)
    src.location = (0, 0, 0); new.location = (0, 0, 0)
print("DONE", len(rows))
