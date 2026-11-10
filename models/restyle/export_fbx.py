# Export the NEW (restyled) animals as FBX for Roblox Studio's Import 3D, so the meshes become
# real uploaded assets everyone can see (Team Create, Play, live).
#   body  = the game's ORIGINAL UVs + plain material -> in Studio it wears the original
#           SurfaceAppearance (pigeon chose the real textures). Flat-shaded (crisp facets).
#   eyes  = original UVs, smooth-shaded, same SurfaceAppearance in Studio
#   blush = pink rounded domes, smooth-shaded
# Default: ONE file with all animals (one Import 3D click), spaced 30 studs apart along X,
# each animal's bottom centre on the ground, facing Blender +Y.
# Objects are named <Name>_NEW_Body / _Eyes / _Blush / _Blush.001
# blender -b five_compare.blend -P export_fbx.py -- <out_dir> Name1,Name2,... [separate] [baked]
import bpy, sys, os
from mathutils import Vector

argv = sys.argv[sys.argv.index("--") + 1:]
out_dir, names = argv[0], argv[1].split(",")
REAL_TEX = "baked" not in argv[2:]
SEPARATE = "separate" in argv[2:]
os.makedirs(out_dir, exist_ok=True)
plain = bpy.data.materials.get("SOA_Plain") or bpy.data.materials.new("SOA_Plain")


def copies_for(name, slot_x):
    body = bpy.data.objects[name + "_SOA"]
    kids = [c for c in body.children if c.type == 'MESH']
    me = body.data.copy()
    keep_baked = not REAL_TEX
    for uv in list(me.uv_layers):
        if (uv.name == "BakeUV") != keep_baked:
            me.uv_layers.remove(uv)
    if REAL_TEX:
        me.materials.clear(); me.materials.append(plain)
    tmp = bpy.data.objects.new(name + "_NEW_Body", me)
    bpy.context.scene.collection.objects.link(tmp)
    tmp.matrix_world = body.matrix_world.copy()
    out = [tmp]
    for k in kids:
        kc = k.copy(); kc.data = k.data.copy(); kc.parent = None
        bpy.context.scene.collection.objects.link(kc)
        kc.matrix_world = k.matrix_world.copy()
        kc.name = name + "_NEW" + k.name.split("_SOA")[1]
        out.append(kc)
    # bottom centre of the whole animal -> (slot_x, 0, 0)
    pts = [o.matrix_world @ v.co for o in out for v in o.data.vertices]
    mn = Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
    mx = Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
    shift = Vector((slot_x, 0, 0)) - Vector(((mn.x + mx.x) / 2, (mn.y + mx.y) / 2, mn.z))
    for o in out:
        bpy.context.view_layer.update()
        o.matrix_world.translation += shift
    return out, mx - mn


def export(objs, path):
    bpy.ops.object.select_all(action='DESELECT')
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.export_scene.fbx(filepath=path, use_selection=True, object_types={'MESH'},
                             path_mode='COPY', embed_textures=True, apply_unit_scale=True,
                             mesh_smooth_type='FACE', bake_space_transform=False,
                             axis_forward='-Z', axis_up='Y')


everything = []
for i, name in enumerate(names):
    objs, size = copies_for(name, 0.0 if SEPARATE else i * 30.0)
    print("ANIMAL", name, [o.name for o in objs], "size", tuple(round(a, 2) for a in size))
    if SEPARATE:
        export(objs, os.path.join(out_dir, name + "_NEW.fbx"))
        for o in objs: bpy.data.objects.remove(o, do_unlink=True)
    else:
        everything += objs
if not SEPARATE:
    path = os.path.join(out_dir, "Restyle_NEW_all.fbx")
    export(everything, path)
    print("FBX", path, len(everything), "objects")
