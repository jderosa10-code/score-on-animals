"""Read the Studio 'Export Selection' OBJ of the 196 eggs (+ 4 animals) into a .blend.

Studio names the groups  Egg<name>1  /  Ani<animal><part>1  (lower case, punctuation dropped).
Each object is moved so its bounding-box centre sits at its own origin, which is how Roblox
stores a MeshPart, and its export position is kept in custom properties.

blender -b --factory-startup -P eggs_extract.py -- <eggs.obj> <out.blend> <report.txt>
"""
import bpy, sys
from mathutils import Vector

obj_path, blend_out, report = sys.argv[sys.argv.index("--") + 1:]
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.wm.obj_import(filepath=obj_path, forward_axis='NEGATIVE_Z', up_axis='Y',
                      use_split_objects=False, use_split_groups=True, import_vertex_groups=False)
lines = []
for o in list(bpy.data.objects):
    if o.type != 'MESH':
        continue
    me = o.data
    me.transform(o.matrix_world); o.matrix_world.identity()
    xs = [v.co for v in me.vertices]
    mn = Vector((min(c.x for c in xs), min(c.y for c in xs), min(c.z for c in xs)))
    mx = Vector((max(c.x for c in xs), max(c.y for c in xs), max(c.z for c in xs)))
    c = (mn + mx) / 2
    me.transform(__import__("mathutils").Matrix.Translation(-c))
    o["export_centre"] = list(c)
    kind = "egg" if o.name.lower().startswith("egg") else "ani"
    o["kind"] = kind
    islands = 0
    # count loose parts (after welding coincident corners) to see how the eggs are built
    import bmesh
    bm = bmesh.new(); bm.from_mesh(me)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-4)
    seen = set()
    for v in bm.verts:
        if v.index in seen: continue
        islands += 1
        stack = [v]; seen.add(v.index)
        while stack:
            w = stack.pop()
            for e in w.link_edges:
                u = e.other_vert(w)
                if u.index not in seen: seen.add(u.index); stack.append(u)
    welded = len(bm.verts); bm.free()
    size = mx - mn
    lines.append(f"{o.name}\t{kind}\tverts {len(me.vertices)}\twelded {welded}\ttris {sum(len(p.vertices) - 2 for p in me.polygons)}"
                 f"\tislands {islands}\tsize {size.x:.2f} {size.y:.2f} {size.z:.2f}\tuv {len(me.uv_layers)}")
lines.sort()
open(report, "w").write("\n".join(lines))
bpy.ops.wm.save_as_mainfile(filepath=blend_out)
print("EXTRACTED", len(lines))
