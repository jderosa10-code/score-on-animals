"""Export each barbell v2 concept as its own FBX + a colour table for Studio.
blender -b barbells_v2.blend --python-exit-code 1 -P export.py -- <out_dir>
Parts are named Barbell_<Name>_<Group>__<Material>; Roblox drops FBX material colours, so Studio colours
each MeshPart from colours.json (sRGB, same Hi / Lo maths as the build script)."""
import bpy, sys, os, json
out = sys.argv[sys.argv.index("--") + 1]
os.makedirs(out, exist_ok=True)
cols = {}
for m in bpy.data.materials:
    bs = m.node_tree.nodes.get("Principled BSDF") if m.node_tree else None
    if not bs: continue
    # the build script stores LINEAR colour in Base Color (or in the multiply node); undo to sRGB
    mul = next((n for n in m.node_tree.nodes if n.type == 'VECT_MATH'), None)
    c = list(mul.inputs[1].default_value) if mul else list(bs.inputs["Base Color"].default_value)[:3]
    srgb = lambda x: 1.055 * x ** (1 / 2.4) - 0.055 if x > 0.0031308 else 12.92 * x
    glow = bs.inputs["Emission Strength"].default_value > 0
    cols[m.name] = {"c": [round(srgb(v), 4) for v in c[:3]], "glow": glow}
with open(os.path.join(out, "colours.json"), "w") as fh: json.dump(cols, fh)
done = []
for coll in bpy.data.collections:
    if not coll.name.startswith("Barbell_"): continue
    objs = [o for o in coll.objects if o.type == 'MESH']
    if not objs: continue
    bpy.ops.object.select_all(action='DESELECT')
    for o in objs: o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    # move this weight to the origin while exporting (they sit in a row along -Y in the file)
    y0 = sum(o.matrix_world.translation.y for o in objs) / len(objs)
    cy = (min(v.co.y for o in objs for v in o.data.vertices) + max(v.co.y for o in objs for v in o.data.vertices)) / 2
    for o in objs: o.data.transform(__import__("mathutils").Matrix.Translation((0, -cy, 0)))
    path = os.path.join(out, coll.name + ".fbx")
    bpy.ops.export_scene.fbx(filepath=path, use_selection=True, object_types={'MESH'}, apply_unit_scale=True,
                             mesh_smooth_type='OFF', axis_forward='-Z', axis_up='Y', colors_type='SRGB')
    for o in objs: o.data.transform(__import__("mathutils").Matrix.Translation((0, cy, 0)))
    done.append(coll.name)
print("EXPORTED", len(done), done)
