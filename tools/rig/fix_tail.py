# Fix body/tail vertices skinned to a LEG bone (pigeon-claude, 14 Nov 2026).
# Found on the Tanuki and Bunyip: the tail (centre line, behind the hips) was weighted to R_Knee, so every step
# swung the tail down through the floor. Rule: a vertex whose main bone is a leg bone (Leg/Knee/Hock/Thigh/Shin),
# that sits near the centre line (|x| < 10% of width) while that bone sits out to the side (|x| > 15% of width),
# takes the weights of the nearest vertex that is not a leg vertex. Everything else is left alone.
#   blender -b -P fix_tail.py -- <in.fbx> <out.fbx>
import bpy, sys
from mathutils import kdtree
argv = sys.argv[sys.argv.index("--") + 1:]
src, dst = argv[0], argv[1]
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.fbx(filepath=src)
arm = next(o for o in bpy.data.objects if o.type == 'ARMATURE')
ob = max([o for o in bpy.data.objects if o.type == 'MESH'], key=lambda o: len(o.data.vertices))
me, mw = ob.data, ob.matrix_world
gname = {g.index: g.name for g in ob.vertex_groups}
W = [mw @ v.co for v in me.vertices]
xs = [p.x for p in W]
width = max(xs) - min(xs)
midx = (max(xs) + min(xs)) / 2
head = {b.name: (arm.matrix_world @ b.head_local) for b in arm.data.bones}
LEG = ("Leg", "Knee", "Hock", "Thigh", "Shin")

def top(i):
    g = max(me.vertices[i].groups, key=lambda g: g.weight, default=None)
    return gname.get(g.group) if g else None

def is_leg(n):
    return n is not None and any(k in n for k in LEG)

ys = [p.y for p in W]
depth = max(ys) - min(ys)          # Blender Y = front/back after the FBX import
reach = 0.25 * max(width, depth)
bad, good = [], []
for i, p in enumerate(W):
    n = top(i)
    far = is_leg(n) and ((p.x - head[n].x) ** 2 + (p.y - head[n].y) ** 2) ** 0.5 > reach   # well away from its leg, seen from above
    if is_leg(n) and ((abs(p.x - midx) < 0.10 * width and abs(head[n].x - midx) > 0.15 * width) or far):
        bad.append(i)
    elif not is_leg(n):
        good.append(i)
kd = kdtree.KDTree(len(good))
for i in good: kd.insert(W[i], i)
kd.balance()
moved = {}
for i in bad:
    _, host, _ = kd.find(W[i])
    hw = [(gname[g.group], g.weight) for g in me.vertices[host].groups]
    old = top(i)
    for g in list(me.vertices[i].groups): ob.vertex_groups[g.group].remove([i])
    for n, w in hw: ob.vertex_groups[n].add([i], w, 'REPLACE')
    key = old + "->" + (max(hw, key=lambda x: x[1])[0] if hw else "?")
    moved[key] = moved.get(key, 0) + 1
print("FIXED", len(bad), moved)
for o in bpy.context.scene.objects: o.select_set(True)
bpy.context.view_layer.objects.active = arm
bpy.ops.export_scene.fbx(filepath=dst, use_selection=True, object_types={'ARMATURE', 'MESH'}, apply_unit_scale=True,
                         mesh_smooth_type='FACE', bake_space_transform=True, axis_forward='-Z', axis_up='Y',
                         add_leaf_bones=False, primary_bone_axis='Y', secondary_bone_axis='X', use_armature_deform_only=False,
                         armature_nodetype='NULL')
print("EXPORTED", dst)
