"""Quick audit renders: every restyled animal (<Name>_SOA, with its eyes) next to its original,
front three-quarter view, fast Workbench render with textures. One PNG per animal.

blender -b <round2 file>.blend -P audit_render.py -- <out_dir>
"""
import bpy, sys, os, math
from mathutils import Vector

out_dir = sys.argv[sys.argv.index("--") + 1]
os.makedirs(out_dir, exist_ok=True)
sc = bpy.context.scene
sc.render.engine = 'BLENDER_WORKBENCH'
sh = sc.display.shading
sh.light = 'STUDIO'; sh.color_type = 'TEXTURE'; sh.show_shadows = False; sh.show_cavity = True
sh.cavity_type = 'WORLD'; sh.show_object_outline = True
sc.render.resolution_x, sc.render.resolution_y = 520, 340
sc.render.film_transparent = False
sc.world = sc.world or bpy.data.worlds.new("W")
cam = bpy.data.objects.get("AuditCam") or bpy.data.objects.new("AuditCam", bpy.data.cameras.new("AuditCam"))
if cam.name not in sc.collection.objects: sc.collection.objects.link(cam)
cam.data.type = 'ORTHO'
sc.camera = cam
for o in sc.objects:
    if o.type == 'FONT' or o.name in ("Ground",): o.hide_render = True


def bounds(objs):
    pts = [o.matrix_world @ Vector(c) for o in objs for c in o.bound_box]
    mn = Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
    mx = Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
    return mn, mx


news = [o for o in sc.objects if o.name.endswith("_SOA") and o.type == 'MESH']
for new in news:
    name = new.name[:-4]
    old = bpy.data.objects.get(name)
    group = [new] + [c for c in new.children if c.type == 'MESH']
    if old: group.append(old)
    show = set(group)
    for o in sc.objects:
        if o.type == 'MESH': o.hide_render = o not in show
    mn, mx = bounds(group)
    c = (mn + mx) / 2
    w, h = mx.x - mn.x, mx.z - mn.z
    cam.data.ortho_scale = max(w * 1.15, h * 1.15 * 520 / 340)
    az = math.radians(20)
    cam.location = c + Vector((math.sin(az) * 30 * 0.3, 30 * math.cos(az), 30 * 0.35))
    cam.rotation_euler = (c - cam.location).to_track_quat('-Z', 'Y').to_euler()
    sc.render.filepath = os.path.join(out_dir, name + ".png")
    bpy.ops.render.render(write_still=True)
print("AUDIT", len(news))
