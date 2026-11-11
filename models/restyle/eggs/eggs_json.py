"""Write chosen eggs as JSON so Studio can build them as EditableMesh parts (no Import 3D needed)
and dress them in the real egg's SurfaceAppearance, to check how the textures land.
Roblox mesh axes: x = Blender x, y = Blender z, z = -Blender y (measured on the game's eggs).
UV v is flipped (Studio's OBJ export writes v the other way up).

blender -b <file>.blend -P eggs_json.py -- <out.json> Obj,Obj,...
"""
import bpy, sys, json
from mathutils import Vector

out, names = sys.argv[sys.argv.index("--") + 1:][:2]
res = {}
for n in names.split(","):
    o = bpy.data.objects.get(n)
    if not o:
        print("MISSING", n); continue
    me = o.data
    pts = [o.matrix_world @ v.co for v in me.vertices]
    mn = Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
    mx = Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
    c = (mn + mx) / 2
    verts = []
    for p in pts:
        q = p - c
        verts += [round(q.x, 4), round(q.z, 4), round(-q.y, 4)]
    uvl = me.uv_layers.active.data
    uvs, tris = [], []
    me.calc_loop_triangles()
    for t in me.loop_triangles:
        ids = []
        for li in t.loops:
            u, v = uvl[li].uv
            uvs += [round(u, 5), round(1 - v, 5)]
            ids.append(len(uvs) // 2)
        a, b, cc = (me.loops[li].vertex_index + 1 for li in t.loops)
        tris.append([a, b, cc] + ids)
    res[n] = dict(verts=verts, uvs=uvs, tris=tris)
    print("EGG", n, len(me.vertices), "verts", len(tris), "tris")
json.dump(res, open(out, "w"))
