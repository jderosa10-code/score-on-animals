# Pull a few animals out of the big pack OBJ into a small .blend, with transforms applied,
# and print each one's parts (loose pieces) so we can see eyes / head / legs.
# blender -b --factory-startup -P extract.py -- <animals.obj> <out.blend> Name1,Name2,...
import bpy, bmesh, sys, json
from mathutils import Vector

argv = sys.argv[sys.argv.index("--") + 1:]
obj_path, blend_out, names = argv[0], argv[1], argv[2].split(",")

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.wm.obj_import(filepath=obj_path, use_split_groups=True, use_split_objects=True)

keep = set(names)
for ob in list(bpy.data.objects):
    if ob.name not in keep:
        bpy.data.objects.remove(ob, do_unlink=True)
for me in list(bpy.data.meshes):
    if me.users == 0:
        bpy.data.meshes.remove(me)
for mat in list(bpy.data.materials):
    if mat.users == 0:
        bpy.data.materials.remove(mat)
for img in list(bpy.data.images):
    if img.users == 0:
        bpy.data.images.remove(img)

report = {}
for ob in bpy.data.objects:
    bpy.context.view_layer.objects.active = ob
    ob.select_set(True)
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    ob.select_set(False)
    bm = bmesh.new(); bm.from_mesh(ob.data)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=0.0005)
    bm.verts.ensure_lookup_table()
    seen = set(); parts = []
    for v in bm.verts:
        if v.index in seen: continue
        stack = [v]; isl = []; seen.add(v.index)
        while stack:
            x = stack.pop(); isl.append(x.co.copy())
            for e in x.link_edges:
                o = e.other_vert(x)
                if o.index not in seen:
                    seen.add(o.index); stack.append(o)
        mn = Vector((min(c.x for c in isl), min(c.y for c in isl), min(c.z for c in isl)))
        mx = Vector((max(c.x for c in isl), max(c.y for c in isl), max(c.z for c in isl)))
        ctr = (mn + mx) / 2
        parts.append(dict(n=len(isl), c=[round(a, 2) for a in ctr], s=[round(a, 2) for a in (mx - mn)]))
    bm.to_mesh(ob.data); bm.free()
    co = [ob.matrix_world @ v.co for v in ob.data.vertices]
    mn = Vector((min(c.x for c in co), min(c.y for c in co), min(c.z for c in co)))
    mx = Vector((max(c.x for c in co), max(c.y for c in co), max(c.z for c in co)))
    report[ob.name] = dict(loc=[round(a, 2) for a in ob.location], min=[round(a, 2) for a in mn],
                           max=[round(a, 2) for a in mx], parts=sorted(parts, key=lambda p: -p["n"]))

bpy.ops.file.pack_all()
bpy.ops.wm.save_as_mainfile(filepath=blend_out)
print("REPORT" + json.dumps(report))
