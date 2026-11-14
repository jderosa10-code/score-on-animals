# Re-weight loose eye pieces that were skinned to a limb bone (pigeon-claude, 14 Nov 2026).
# The Tanuki's eyeballs were tied to L/R_Shoulder, so they swung with the arms. This moves every loose
# piece whose vertices are mostly on a limb bone AND that sits above that bone (on the head) to a body bone.
#   blender -b -P fix_eye_weights.py -- <in.fbx> <out.fbx> <limb substring> <body bone>
import bpy, bmesh, sys
argv = sys.argv[sys.argv.index("--") + 1:]
src, dst, limb, body = argv[0], argv[1], argv[2], argv[3]
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.fbx(filepath=src)
arm = next(o for o in bpy.data.objects if o.type == 'ARMATURE')
meshes = [o for o in bpy.data.objects if o.type == 'MESH' and o.find_armature() == arm]
ob = max(meshes, key=lambda o: len(o.data.vertices))
me = ob.data
gname = {g.index: g.name for g in ob.vertex_groups}
target = ob.vertex_groups.get(body)
assert target, "no body bone group " + body
mw = ob.matrix_world

def top_group(v):
    best = max(v.groups, key=lambda g: g.weight, default=None)
    return gname.get(best.group) if best else None

bm = bmesh.new()
bm.from_mesh(me)
bm.verts.ensure_lookup_table()
seen, islands = set(), []
for v in bm.verts:
    if v.index in seen: continue
    stack, isl = [v], []
    seen.add(v.index)
    while stack:
        x = stack.pop(); isl.append(x.index)
        for e in x.link_edges:
            o = e.other_vert(x)
            if o.index not in seen: seen.add(o.index); stack.append(o)
    islands.append(isl)
bm.free()
print("ISLANDS", len(islands), "sizes", sorted((len(i) for i in islands), reverse=True)[:16])

zs = [(mw @ v.co).z for v in me.vertices]
height = max(zs) - min(zs)
fixed = []
for isl in islands:
    if len(isl) > len(me.vertices) * 0.15: continue
    names = [top_group(me.vertices[i]) for i in isl]
    limbish = [n for n in names if n and limb in n]
    if len(limbish) < 0.9 * len(isl): continue
    bone = max(set(limbish), key=limbish.count)
    pb = arm.pose.bones.get(bone) or arm.data.bones.get(bone)
    bone_z = (arm.matrix_world @ arm.data.bones[bone].head_local).z
    cz = sum((mw @ me.vertices[i].co).z for i in isl) / len(isl)
    # arms hang off the shoulder (centroid about level with it); eyes sit well above it on the head.
    # Only pieces higher than the shoulder by 20% of the model's height move.
    if cz - bone_z <= 0.2 * height: continue
    for i in isl:
        for g in list(me.vertices[i].groups):
            ob.vertex_groups[g.group].remove([i])
        target.add([i], 1.0, 'REPLACE')
    fixed.append((bone, len(isl), round(cz - bone_z, 3)))
print("FIXED", fixed)

for o in bpy.context.scene.objects: o.select_set(True)
bpy.context.view_layer.objects.active = arm
bpy.ops.export_scene.fbx(filepath=dst, use_selection=True, object_types={'ARMATURE', 'MESH'}, apply_unit_scale=True,
                         mesh_smooth_type='FACE', bake_space_transform=True, axis_forward='-Z', axis_up='Y',
                         add_leaf_bones=False, primary_bone_axis='Y', secondary_bone_axis='X', use_armature_deform_only=False,
                         armature_nodetype='NULL')
print("EXPORTED", dst)
