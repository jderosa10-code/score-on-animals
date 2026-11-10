# Export each NEW (restyled) animal as an FBX for Roblox Studio's Import 3D, so the meshes become
# real uploaded assets everyone can see (Team Create, Play, live).
#   body  = baked texture (saved next to the FBX as <Name>_NEW_tex.png, also embedded)
#   eyes  = original UVs, plain dark material (in Studio they get the game's SurfaceAppearance)
#   blush = flat pink
# Each animal's bottom centre sits at the origin, facing Blender +Y.
# blender -b five_compare.blend -P export_fbx.py -- <out_dir> Name1,Name2,...
import bpy, sys, os
from mathutils import Vector

argv = sys.argv[sys.argv.index("--") + 1:]
out_dir, names = argv[0], argv[1].split(",")
REAL_TEX = "baked" not in argv[2:]
os.makedirs(out_dir, exist_ok=True)

for name in names:
    body = bpy.data.objects[name + "_SOA"]
    kids = [c for c in body.children if c.type == 'MESH']
    # body: keep ONE UV channel so the importer can't pick the wrong one.
    #   realtex (default): the game's original UVs, plain material -> in Studio it wears the
    #   original SurfaceAppearance (pigeon chose the real textures over the baked recolour)
    #   baked: the BakeUV channel + the baked PNG
    me = body.data.copy()
    keep_baked = not REAL_TEX
    for uv in list(me.uv_layers):
        if (uv.name == "BakeUV") != keep_baked:
            me.uv_layers.remove(uv)
    tmp = bpy.data.objects.new(name + "_NEW", me)
    bpy.context.scene.collection.objects.link(tmp)
    tmp.matrix_world = body.matrix_world.copy()
    if REAL_TEX:
        me.materials.clear()
        plain = bpy.data.materials.get("SOA_Plain") or bpy.data.materials.new("SOA_Plain")
        me.materials.append(plain)
    else:
        for slot in tmp.material_slots:
            for n in slot.material.node_tree.nodes:
                if n.type == 'TEX_IMAGE' and n.image and n.image.name.endswith("_tex"):
                    png = os.path.join(out_dir, name + "_NEW_tex.png")
                    n.image.filepath_raw = png
                    n.image.file_format = 'PNG'
                    n.image.save()
    # bottom centre of the whole animal -> origin
    pts = [tmp.matrix_world @ v.co for v in me.vertices]
    for k in kids:
        pts += [k.matrix_world @ v.co for v in k.data.vertices]
    mn = Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
    mx = Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
    shift = -Vector(((mn.x + mx.x) / 2, (mn.y + mx.y) / 2, mn.z))
    saved = {k.name: k.matrix_world.copy() for k in kids}
    tmp.location += shift
    copies = []
    for k in kids:
        kc = k.copy(); kc.data = k.data.copy(); kc.parent = None
        bpy.context.scene.collection.objects.link(kc)
        kc.matrix_world = saved[k.name]
        kc.location += shift
        kc.name = name + "_NEW" + k.name.split("_SOA")[1]
        copies.append(kc)
    bpy.ops.object.select_all(action='DESELECT')
    for o in [tmp] + copies:
        o.select_set(True)
    bpy.context.view_layer.objects.active = tmp
    fbx = os.path.join(out_dir, name + "_NEW.fbx")
    bpy.ops.export_scene.fbx(filepath=fbx, use_selection=True, object_types={'MESH'},
                             path_mode='COPY', embed_textures=True, apply_unit_scale=True,
                             bake_space_transform=False, axis_forward='-Z', axis_up='Y')
    print("FBX", fbx, [o.name for o in [tmp] + copies], "size", tuple(round(a, 2) for a in (mx - mn)))
    for o in [tmp] + copies:
        bpy.data.objects.remove(o, do_unlink=True)
