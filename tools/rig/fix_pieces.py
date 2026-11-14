# Fix loose pieces skinned to the wrong bone (pigeon-claude, 14 Nov 2026), same rule as the Studio skin audit
# (ServerStorage.PigeonSkinAudit misbound2): a loose piece (eye, horn, ear, tusk) whose main bone is a hanging
# limb bone (all its children hang below it) while the piece sits well ABOVE that bone. Such a piece swings with the
# leg/wing. Fix: it takes the bone weights of the surface it sits on (the nearest vertex outside the piece), so it
# moves rigidly with that spot. Everything else is left alone.
#   blender -b -P fix_pieces.py -- <in.fbx> <out.fbx> [min_above=0.12]
import bpy, bmesh, sys
from mathutils import kdtree
argv = sys.argv[sys.argv.index("--") + 1:]
src, dst = argv[0], argv[1]
min_above = float(argv[2]) if len(argv) > 2 else 0.12
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.fbx(filepath=src)
arm = next(o for o in bpy.data.objects if o.type == 'ARMATURE')
ob = max([o for o in bpy.data.objects if o.type == 'MESH'], key=lambda o: len(o.data.vertices))
me, mw = ob.data, ob.matrix_world
gname = {g.index: g.name for g in ob.vertex_groups}
W = [mw @ v.co for v in me.vertices]
zs = [p.z for p in W]
height = max(zs) - min(zs)
head = {b.name: (arm.matrix_world @ b.head_local) for b in arm.data.bones}
kids = {b.name: [c.name for c in b.children] for b in arm.data.bones}

def hanging(n):
    ks = kids.get(n)
    if not ks: return False
    return all(head[k].z < head[n].z - 0.02 * height for k in ks)

def top(i):
    g = max(me.vertices[i].groups, key=lambda g: g.weight, default=None)
    return gname.get(g.group) if g else None

bm = bmesh.new(); bm.from_mesh(me); bm.verts.ensure_lookup_table()
# loose pieces; corners at the same spot count as joined (faceted meshes)
parent = list(range(len(bm.verts)))
def find(i):
    while parent[i] != i:
        parent[i] = parent[parent[i]]; i = parent[i]
    return i
def join(a, b):
    a, b = find(a), find(b)
    if a != b: parent[a] = b
for e in bm.edges: join(e.verts[0].index, e.verts[1].index)
cell = {}
for i, p in enumerate(W):
    k = (round(p.x, 5), round(p.y, 5), round(p.z, 5))
    if k in cell: join(i, cell[k])
    else: cell[k] = i
bm.free()
groups = {}
for i in range(len(W)): groups.setdefault(find(i), []).append(i)
islands = sorted(groups.values(), key=len, reverse=True)

fixed = []
for isl in islands[1:]:
    if len(isl) > 0.15 * len(W): continue
    names = [top(i) for i in isl]
    own = max(set(names), key=names.count)
    if not own or not hanging(own): continue
    c = sum((W[i] for i in isl), W[isl[0]] * 0) / len(isl)
    if c.z - head[own].z <= min_above * height: continue
    inside = set(isl)
    kd = kdtree.KDTree(len(W) - len(isl))
    for i, p in enumerate(W):
        if i not in inside: kd.insert(p, i)
    kd.balance()
    _, host, _ = kd.find(c)
    hw = [(gname[g.group], g.weight) for g in me.vertices[host].groups]
    for i in isl:
        for g in list(me.vertices[i].groups): ob.vertex_groups[g.group].remove([i])
        for n, w in hw: ob.vertex_groups[n].add([i], w, 'REPLACE')
    fixed.append((len(isl), own, "->", "+".join(f"{n}:{w:.2f}" for n, w in hw), round((c.z - head[own].z) / height, 2)))
print("FIXED", len(fixed))
for f in fixed: print("  ", f)
for o in bpy.context.scene.objects: o.select_set(True)
bpy.context.view_layer.objects.active = arm
bpy.ops.export_scene.fbx(filepath=dst, use_selection=True, object_types={'ARMATURE', 'MESH'}, apply_unit_scale=True,
                         mesh_smooth_type='FACE', bake_space_transform=True, axis_forward='-Z', axis_up='Y',
                         add_leaf_bones=False, primary_bone_axis='Y', secondary_bone_axis='X', use_armature_deform_only=False,
                         armature_nodetype='NULL')
print("EXPORTED", dst)
