"""Render named objects from a .blend in a row; if <name>_NEW exists it stands right of the old one.

blender -b <file.blend> -P eggs_render.py -- <out.png> <name,name,...> [flat|wire]
Writes <out>_front.png and <out>_iso.png.
"""
import bpy, sys, math
from mathutils import Vector

args = sys.argv[sys.argv.index("--") + 1:]
out, names = args[0], args[1].split(",")
mode = args[2] if len(args) > 2 else "flat"
sc = bpy.context.scene
for o in list(sc.objects):
    o.hide_render = True


def mat(name, rgb, emit=0.0):
    m = bpy.data.materials.new(name); m.use_nodes = True
    b = m.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = (*rgb, 1); b.inputs["Roughness"].default_value = 0.45
    return m


GOLD, NEWC = mat("OldGold", (1.0, 0.55, 0.02)), mat("NewGold", (1.0, 0.55, 0.02))
x = 0.0
shown = []
for n in names:
    pair = [bpy.data.objects.get(n), bpy.data.objects.get(n + "_NEW")]
    for k, o in enumerate(pair):
        if o is None: continue
        o.hide_render = False
        if not o.get("keep_material"):
            o.data.materials.clear(); o.data.materials.append(GOLD if k == 0 else NEWC)
        bb = [o.matrix_world @ Vector(c) for c in o.bound_box]
        w = max(p.x for p in bb) - min(p.x for p in bb)
        zmin = min(Vector(c).z for c in o.bound_box)
        cx = (max(Vector(c).x for c in o.bound_box) + min(Vector(c).x for c in o.bound_box)) / 2
        o.location = (x + w / 2 - cx, 0, -zmin)
        x += w + (1.2 if k == 0 and pair[1] else 3.5)
        shown.append(o)
bpy.context.view_layer.update()
pts = [o.matrix_world @ Vector(c) for o in shown for c in o.bound_box]
mn = Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
mx = Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
c = (mn + mx) / 2
span = max(mx.x - mn.x, (mx.z - mn.z) * 2.2)
bpy.ops.mesh.primitive_plane_add(size=600, location=(c.x, 0, 0))
g = mat("Ground", (0.55, 0.58, 0.66)); bpy.context.active_object.data.materials.append(g)
sun = bpy.data.objects.new("Sun", bpy.data.lights.new("Sun", 'SUN')); sun.data.energy = 3.2
sun.rotation_euler = (math.radians(52), 0, math.radians(25)); sc.collection.objects.link(sun)
sc.world = bpy.data.worlds.new("W"); sc.world.use_nodes = True
sc.world.node_tree.nodes["Background"].inputs["Color"].default_value = (0.78, 0.84, 0.93, 1)
sc.world.node_tree.nodes["Background"].inputs["Strength"].default_value = 0.9
cam = bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam")); sc.collection.objects.link(cam); sc.camera = cam
cam.data.type = 'ORTHO'
sc.render.engine = 'CYCLES'; sc.cycles.device = 'CPU'; sc.cycles.samples = 16; sc.cycles.use_denoising = True
sc.render.resolution_x = 2000; sc.render.resolution_y = 520
cam.data.ortho_scale = max((mx.x - mn.x) * 1.08, (mx.z - mn.z) * (2000 / 520) * 1.5)
for tag, d in (("front", Vector((0, -1, 0.22))), ("iso", Vector((0.45, -1, 0.5))), ("back", Vector((-0.3, 1, 0.35)))):
    d = d.normalized()
    cam.location = c + d * 80
    cam.rotation_euler = (c - cam.location).to_track_quat('-Z', 'Y').to_euler()
    sc.render.filepath = out.replace(".png", f"_{tag}.png")
    bpy.ops.render.render(write_still=True)
print("RENDERED", len(shown))
