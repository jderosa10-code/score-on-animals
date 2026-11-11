"""Round 3 restyle: one smooth WARP of space per animal, instead of cutting it into parts.

Why: rounds 1-2 found the head, eyes and legs by guessing which loose pieces were which, then moved
or scaled those pieces on their own. The guess was often wrong (ears, horns, the kappa's dish were
taken for eyes) and the moved pieces came out broken (pigeon, 2026-11-10: "some are broken and
rushed"). A warp moves every point of the animal by one smooth rule, so pieces that touched still
touch, nothing can float or come apart, and eyes, ears and horns simply ride along with the head.

The rule (moderate on purpose; pigeon: "more different ... but don't change animals too much"):
  1. HEAD LENS: the front-top of the animal (where the head is: faces +Y, up +Z) is magnified
     like a soft magnifying glass, HEAD at the centre, fading out smoothly. Bigger head + eyes.
  2. SHORT LEGS: if the animal stands on legs, everything below the belly is squashed down.
  3. CHUBBY: a little wider, a little shorter nose to tail.
Mesh topology and UVs are untouched, so the game's textures (and every mutation look) still fit.

blender -b <originals>.blend -P warp.py -- <out.blend> <render_dir> Name,Name,...|ALL
"""
import bpy, bmesh, sys, os, math
from mathutils import Vector

argv = sys.argv[sys.argv.index("--") + 1:]
blend_out, render_dir, which = argv[0], argv[1], argv[2]
os.makedirs(render_dir, exist_ok=True)

HEAD_GAIN = 0.5       # centre of the head grows by this much (0.5 = 1.5x), fading to 0
LENS_REACH = 1.6      # the lens fades out over this many head radii
LEG_SQUASH = 0.62     # height of the leg zone afterwards (1 = unchanged)
WIDE, LONG = 1.12, 0.93
# first test (gain 0.32, legs 0.72, 1.08 wide) was safe but barely visible next to the old ones


def smoothstep(a, b, x):
    t = max(0.0, min(1.0, (x - a) / (b - a)))
    return t * t * (3 - 2 * t)


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


def warp(ob):
    me = ob.data
    co = [v.co.copy() for v in me.vertices]
    mn = Vector((min(c.x for c in co), min(c.y for c in co), min(c.z for c in co)))
    mx = Vector((max(c.x for c in co), max(c.y for c in co), max(c.z for c in co)))
    size = mx - mn
    ctr = (mn + mx) / 2
    big = max(size)
    info = {}
    # --- where the head is: the corners that are both high up and far forward (top 12% by a
    #     score that counts height a bit more than forwardness). Works for four-legged animals,
    #     upright ones (kappa, birds, kangaroo) and long ones (giraffe, crocodile, fish).
    def score(c):
        return (c.z - mn.z) / max(1e-6, size.z) + 0.8 * (c.y - mn.y) / max(1e-6, size.y)
    ranked = sorted(co, key=score, reverse=True)
    top = ranked[:max(8, len(ranked) * 12 // 100)]
    hc = sum(top, Vector()) / len(top)
    hmn = Vector((min(c.x for c in top), min(c.y for c in top), min(c.z for c in top)))
    hmx = Vector((max(c.x for c in top), max(c.y for c in top), max(c.z for c in top)))
    R = max(0.18 * big, min(0.45 * big, 0.6 * max(hmx - hmn)))
    hc.x = ctr.x                                   # keep it on the mid line, so it stays symmetric
    info["head"] = [round(a, 2) for a in hc]; info["R"] = round(R, 2)
    # --- legs: loose pieces that touch the ground and are thin compared with the animal
    bm = bmesh.new(); bm.from_mesh(me)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-4)
    legs = 0
    for isl in islands(bm):
        zs = [v.co.z for v in isl]
        if min(zs) < mn.z + 0.04 * size.z:
            xs = [v.co.x for v in isl]; ys = [v.co.y for v in isl]
            if (max(xs) - min(xs)) < 0.45 * size.x and (max(ys) - min(ys)) < 0.45 * size.y and max(zs) - min(zs) > 0.12 * size.z:
                legs += 1
    bm.free()
    belly = mn.z + 0.32 * size.z
    squash = LEG_SQUASH if legs >= 2 else 1.0
    info["legs"] = legs
    new = []
    for c in co:
        p = c.copy()
        # 1. head lens (radial, monotonic: the fade is gentle enough that nothing folds over)
        d = p - hc
        r = d.length
        if r > 1e-9:
            g = 1 + HEAD_GAIN * (1 - smoothstep(0.0, LENS_REACH, r / R))
            p = hc + d * g
        # 2. legs: squash everything below the belly line, blended in over a small band
        if squash < 1.0:
            below = belly - p.z
            if below > 0:
                p.z = belly - below * squash
        # 3. chubby
        p.x = ctr.x + (p.x - ctr.x) * WIDE
        p.y = ctr.y + (p.y - ctr.y) * LONG
        new.append(p)
    # back on the ground, centred where it was
    nz = min(p.z for p in new)
    nmn = Vector((min(p.x for p in new), min(p.y for p in new), nz))
    nmx = Vector((max(p.x for p in new), max(p.y for p in new), max(p.z for p in new)))
    shift = Vector((ctr.x - (nmn.x + nmx.x) / 2, ctr.y - (nmn.y + nmx.y) / 2, mn.z - nz))
    for v, p in zip(me.vertices, new):
        v.co = p + shift
    me.update()
    info["grow"] = [round((nmx[k] - nmn[k]) / size[k], 2) for k in range(3)]
    return info


sc = bpy.context.scene
names = [o.name for o in sc.objects if o.type == 'MESH' and not o.name.endswith("_SOA")] if which == "ALL" else which.split(",")
done = []
for n in names:
    src = bpy.data.objects.get(n)
    if not src or src.type != 'MESH':
        print("SKIP", n); continue
    new = src.copy(); new.data = src.data.copy(); new.name = n + "_SOA"
    sc.collection.objects.link(new)
    new.data.transform(new.matrix_world); new.matrix_world.identity()
    if new.data.has_custom_normals:
        bpy.context.view_layer.objects.active = new
        with bpy.context.temp_override(object=new, active_object=new, selected_objects=[new]):
            bpy.ops.mesh.customdata_custom_splitnormals_clear()
    info = warp(new)
    for p in new.data.polygons: p.use_smooth = False
    print("WARP", n, info)
    done.append((src, new))

# ---- renders: OLD left, NEW right, same camera (fast Workbench, with textures)
sc.render.engine = 'BLENDER_WORKBENCH'
sh = sc.display.shading
sh.light = 'STUDIO'; sh.color_type = 'TEXTURE'; sh.show_cavity = True; sh.cavity_type = 'WORLD'; sh.show_object_outline = True
sc.render.resolution_x, sc.render.resolution_y = 560, 360
cam = bpy.data.objects.new("WarpCam", bpy.data.cameras.new("WarpCam")); sc.collection.objects.link(cam)
cam.data.type = 'ORTHO'; sc.camera = cam
for src, new in done:
    smw = src.matrix_world
    pts = [smw @ v.co for v in src.data.vertices]
    mn = Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
    mx = Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
    w = mx.x - mn.x
    # the camera looks from +Y, so lower X shows on the right: NEW to the right of OLD
    new.location = Vector((-(w * 1.15 + 0.6), 0, 0))
    for o in sc.objects:
        if o.type in ('MESH', 'FONT'): o.hide_render = o not in (src, new)
    bpy.context.view_layer.update()
    allp = pts + [new.matrix_world @ v.co for v in new.data.vertices]
    a = Vector((min(p.x for p in allp), min(p.y for p in allp), min(p.z for p in allp)))
    b = Vector((max(p.x for p in allp), max(p.y for p in allp), max(p.z for p in allp)))
    c = (a + b) / 2
    cam.data.ortho_scale = max((b.x - a.x) * 1.12, (b.z - a.z) * 1.12 * 560 / 360)
    az = math.radians(22)
    cam.location = c + Vector((math.sin(az) * 30 * 0.3, 30 * math.cos(az), 30 * 0.33))
    cam.rotation_euler = (c - cam.location).to_track_quat('-Z', 'Y').to_euler()
    sc.render.filepath = os.path.join(render_dir, src.name + ".png")
    bpy.ops.render.render(write_still=True)
    new.location = Vector((0, 0, 0))
bpy.ops.wm.save_as_mainfile(filepath=blend_out)
print("DONE", len(done))
