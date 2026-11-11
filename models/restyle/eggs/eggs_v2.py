"""Egg restyle v2 for Score on Animals. Replaces eggs_restyle.py, whose per-piece scaling broke eggs
(2026-11-10: the mammoth's hair cap was scaled on its own and overhung a body that had been
squeezed thinner; pigeon: "you just made them horrible").

Rules this version follows:
  * ONE coherent move. Every corner of the egg first moves with the body (same stretch), so caps,
    shells, manes and the roots of ears / tusks / tails always stay fitted to the egg.
  * Only what STICKS OUT changes further: the further a corner is from the egg's surface, the more
    it takes the "part" change (longer along the part's own length, a little thicker, side parts on
    top lean outward a bit). It fades in smoothly, so nothing tears off or floats.
  * The body NEVER gets thinner. Each egg takes its animal's proportions by growing: tall animals
    give taller eggs, long animals longer eggs, flat ones wider eggs; all a bit chubbier.
  * No smoothing, no new geometry: faces and UVs are untouched, so textures and mutations fit.
Eggs face Blender -X, up is +Z.

blender -b eggs2_originals.blend -P eggs_v2.py -- <out.blend> <Name,Name|ALL> <animal_sizes.txt> [render_dir]
"""
import bpy, bmesh, sys, os, re, math, statistics
import numpy as np
from mathutils import Vector, Matrix
from mathutils.bvhtree import BVHTree

argv = sys.argv[sys.argv.index("--") + 1:]
blend_out, which, sizes_file = argv[0], argv[1], argv[2]
render_dir = argv[3] if len(argv) > 3 else None

CHUBBY = 1.08          # every egg, sideways
TALL_MAX, LONG_MAX, WIDE_MAX = 1.28, 1.32, 1.15
PART_LONG = 1.35       # sticking-out parts: longer along their own length
PART_THICK = 1.15      # ... and a little thicker
TILT = 10.0            # side parts on the top half lean outward (degrees)
NEAR, FAR = 0.05, 0.28  # fade-in of the part change, as a fraction of the egg body's width

ALIAS = {"bichon": "bichonfrise", "bulldog": "englishbulldog", "cavalier": "cavalierkingcharlesspaniel",
         "greatwhiteshark": "greatwhite", "saltwatercrocodile": "saltwatercroc", "tapir": "tapir_v1",
         "terrier": "bostonterrier", "prehistoricmoth": "moth", "goldenretriever": "dog", "otter": "seal",
         "cockatrice": "chicken"}
sizes = {}
for item in open(sizes_file).read().strip().split(","):
    n, s = item.split("=")
    sizes[n.lower()] = tuple(float(a) for a in s.split("/"))          # width, height, length
tall = {k: h / ((w + l) / 2) for k, (w, h, l) in sizes.items()}
long_ = {k: l / w for k, (w, h, l) in sizes.items()}
MT, ML = statistics.median(tall.values()), statistics.median(long_.values())
clamp = lambda x, a, b: max(a, min(b, x))


def shape_for(name):
    key = re.sub(r"\d+$", "", name[3:]).lower()
    key = ALIAS.get(key, key)
    if key not in sizes:
        return (CHUBBY, CHUBBY, 1.0), False
    rt, rl = tall[key] / MT, long_[key] / ML
    fz = clamp(rt ** 0.6, 1.0, TALL_MAX)                 # taller than typical -> taller egg
    fx = clamp(rl ** 0.6, 1.0, LONG_MAX)                 # longer than typical -> longer egg
    fy = clamp((1 / rt) ** 0.3, 1.0, WIDE_MAX)           # flatter than typical -> wider egg
    return (CHUBBY * fx, CHUBBY * fy, fz), True


def islands(bm):
    seen, out = set(), []
    for v in bm.verts:
        if v.index in seen: continue
        stack, isl = [v], []
        seen.add(v.index)
        while stack:
            x = stack.pop(); isl.append(x)
            for e in x.link_edges:
                o = e.other_vert(x)
                if o.index not in seen: seen.add(o.index); stack.append(o)
        out.append(isl)
    return out


def smoothstep(a, b, x):
    t = clamp((x - a) / (b - a), 0.0, 1.0)
    return t * t * (3 - 2 * t)


def restyle(ob, src_name):
    me = ob.data
    bm = bmesh.new(); bm.from_mesh(me)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-4)
    bm.verts.ensure_lookup_table(); bm.verts.index_update()
    parts = islands(bm)
    body = max(parts, key=len)
    body_ids = {v.index for v in body}
    body_faces = [f for f in bm.faces if f.verts[0].index in body_ids]
    bmesh.ops.recalc_face_normals(bm, faces=body_faces)
    cs = [v.co for v in body]
    bmn = Vector((min(c.x for c in cs), min(c.y for c in cs), min(c.z for c in cs)))
    bmx = Vector((max(c.x for c in cs), max(c.y for c in cs), max(c.z for c in cs)))
    c = (bmn + bmx) / 2
    width = max(bmx.x - bmn.x, bmx.y - bmn.y)
    ground = min(v.co.z for v in bm.verts)
    (sx, sy, sz), known = shape_for(src_name)

    def body_move(p):
        return Vector((c.x + (p.x - c.x) * sx, c.y + (p.y - c.y) * sy, bmn.z + (p.z - bmn.z) * sz))

    # the body's surface, to measure how far each other corner sticks out of the egg
    bvh = BVHTree.FromPolygons([v.co.copy() for v in bm.verts], [[v.index for v in f.verts] for f in body_faces])
    orig = {v.index: v.co.copy() for v in bm.verts}
    moved = 0
    for isl in parts:
        if isl is body: continue
        w = {}
        for v in isl:
            loc, nrm, _, dist = bvh.find_nearest(v.co)
            inside = loc is not None and (v.co - loc).dot(nrm) < 0
            w[v.index] = 0.0 if (inside or loc is None) else smoothstep(NEAR * width, FAR * width, dist)
        out = [v for v in isl if w[v.index] > 0.5]
        anchor = min(isl, key=lambda v: (v.co - c).length_squared).co.copy()
        target = body_move(anchor)
        # the part's own length direction (only if it clearly has one)
        S = Matrix.Identity(3) * ((PART_LONG + PART_THICK) / 2)
        if len(out) >= 4:
            pts = np.array([list(v.co) for v in isl])
            ev, evec = np.linalg.eigh(np.cov((pts - pts.mean(axis=0)).T))
            if ev[2] > 2.2 * max(ev[1], 1e-9):
                a = Vector(evec[:, 2]).normalized()
                S = Matrix.Identity(3) * PART_THICK
                for i in range(3):
                    for j in range(3):
                        S[i][j] += (PART_LONG - PART_THICK) * a[i] * a[j]
        side = (anchor.y - c.y) / max(1e-6, (bmx.y - bmn.y) / 2)
        R = Matrix.Rotation(-math.radians(TILT) * clamp(side, -1, 1), 3, 'X') if abs(side) > 0.3 and anchor.z > c.z else Matrix.Identity(3)
        for v in isl:
            p = orig[v.index]
            a_ = body_move(p)                                   # glued to the egg
            b_ = target + R @ (S @ (p - anchor))                # the changed part
            v.co = a_.lerp(b_, w[v.index])
        if out: moved += 1
    for v in body:
        v.co = body_move(orig[v.index])
    lo = min(v.co.z for v in bm.verts)
    for v in bm.verts: v.co.z += ground - lo
    bm.normal_update()
    bm.to_mesh(me); bm.free()
    for p in me.polygons: p.use_smooth = False
    return dict(shape=[round(sx, 2), round(sy, 2), round(sz, 2)], known=known, parts=len(parts) - 1, sticking_out=moved)


sc = bpy.context.scene
names = [o.name for o in bpy.data.objects if o.get("kind") == "egg"] if which == "ALL" else which.split(",")
pairs = []
for n in sorted(names):
    src = bpy.data.objects.get(n)
    if not src: print("MISSING", n); continue
    new = src.copy(); new.data = src.data.copy(); new.name = n + "_NEW"
    sc.collection.objects.link(new)
    print("EGG", n, restyle(new, n))
    pairs.append((src, new))
bpy.ops.wm.save_as_mainfile(filepath=blend_out)

if render_dir:
    os.makedirs(render_dir, exist_ok=True)
    sc.render.engine = 'BLENDER_WORKBENCH'
    sh = sc.display.shading
    sh.light = 'STUDIO'; sh.color_type = 'TEXTURE'; sh.show_cavity = True; sh.cavity_type = 'WORLD'; sh.show_object_outline = True
    sc.render.resolution_x, sc.render.resolution_y = 640, 400
    cam = bpy.data.objects.new("EggCam", bpy.data.cameras.new("EggCam")); sc.collection.objects.link(cam)
    cam.data.type = 'ORTHO'; sc.camera = cam
    for src, new in pairs:
        for o in sc.objects:
            if o.type == 'MESH': o.hide_render = o not in (src, new)
        for tag, d, off in (("a", Vector((-1, -0.75, 0.4)), Vector((1, -1.3, 0))), ("b", Vector((1, 0.75, 0.4)), Vector((-1, 1.3, 0)))):
            ws = max(src.dimensions.x, src.dimensions.y, new.dimensions.x, new.dimensions.y)
            # stand them side by side across the camera's view: OLD on the left, NEW on the right
            right = Vector((0, 0, 1)).cross(-d).normalized() * -1
            src.location = -right * ws * 0.62; new.location = right * ws * 0.62
            for o in (src, new): o.location.z = -min((Vector(b)).z for b in o.bound_box)
            bpy.context.view_layer.update()
            pts = [o.matrix_world @ Vector(b) for o in (src, new) for b in o.bound_box]
            mn = Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
            mx = Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
            ctr = (mn + mx) / 2
            cam.data.ortho_scale = max((mx - mn).length * 0.95, (mx.z - mn.z) * 1.25 * 640 / 400)
            cam.location = ctr + d.normalized() * 60
            cam.rotation_euler = (ctr - cam.location).to_track_quat('-Z', 'Y').to_euler()
            sc.render.filepath = os.path.join(render_dir, f"{src.name}_{tag}.png")
            bpy.ops.render.render(write_still=True)
        src.location = (0, 0, 0); new.location = (0, 0, 0)
print("DONE", len(pairs))
