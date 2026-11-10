# Export the OLD/NEW test animals as JSON that a Studio script turns into EditableMesh MeshParts.
# blender -b five_compare.blend -P export_for_studio.py -- <out_dir> Name1,Name2,...
# Roblox coords: X = x, Y = z (up), Z = -y.   UV v is flipped and texture rows go top-first.
import bpy, bmesh, sys, json, os
from mathutils import Vector

argv = sys.argv[sys.argv.index("--") + 1:]
out_dir, names = argv[0], argv[1].split(",")
COMPACT = len(argv) > 2 and argv[2] == "compact"   # NEW parts only, texture as base64 (for in-place storage)
# pigeon chose the game's real textures over the baked recolour/gradient: the body keeps its
# original UVs and wears the original SurfaceAppearance in Studio
REAL_TEX = "realtex" in argv[2:]
import base64
os.makedirs(out_dir, exist_ok=True)
MAX_TEX = 256


def tex_and_color(ob):
    mat = ob.active_material
    if not mat or not mat.node_tree:
        return None, [0.8, 0.8, 0.8]
    bsdf = next((n for n in mat.node_tree.nodes if n.type == 'BSDF_PRINCIPLED'), None)
    col = list(bsdf.inputs["Base Color"].default_value)[:3] if bsdf else [0.8, 0.8, 0.8]
    img = None
    if bsdf and bsdf.inputs["Base Color"].is_linked:
        n = bsdf.inputs["Base Color"].links[0].from_node
        if n.type == 'TEX_IMAGE':
            img = n.image
    if not img:
        return None, col
    w, h = img.size
    if max(w, h) > MAX_TEX:
        img = img.copy(); img.scale(MAX_TEX, MAX_TEX); w, h = img.size
    px = list(img.pixels)
    # linear float -> 0..255, rows top-first; colour images store sRGB values in .pixels already
    rows = []
    for y in range(h - 1, -1, -1):
        row = px[y * w * 4:(y + 1) * w * 4]
        rows.extend(int(max(0, min(1, v)) * 255 + 0.5) for v in row)
    return dict(w=w, h=h, px=rows), col


def mesh_data(ob, original_uv=False):
    dg = bpy.context.evaluated_depsgraph_get()
    me = ob.evaluated_get(dg).to_mesh()
    bm = bmesh.new(); bm.from_mesh(me)
    bm.transform(ob.matrix_world)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bmesh.ops.triangulate(bm, faces=bm.faces)
    uv_layer = bm.loops.layers.uv.active
    if original_uv:   # the game's own UV layout (not the bake), so the real SurfaceAppearance fits
        uv_layer = next((l for k, l in bm.loops.layers.uv.items() if k != "BakeUV"), uv_layer)
    verts = []
    for v in bm.verts:
        verts += [round(v.co.x, 4), round(v.co.z, 4), round(-v.co.y, 4)]
    uvs, uv_index, tris = [], {}, []
    for f in bm.faces:
        t = [l.vert.index + 1 for l in f.loops]
        for l in f.loops:
            if uv_layer:
                u, v = l[uv_layer].uv
                key = (round(u, 5), round(1 - v, 5))
            else:
                key = (0.5, 0.5)
            if key not in uv_index:
                uv_index[key] = len(uv_index) + 1
                uvs += [key[0], key[1]]
            t.append(uv_index[key])
        tris.append(t)
    bm.free(); ob.evaluated_get(dg).to_mesh_clear()
    return verts, uvs, tris


for name in names:
    parts = []
    for ob in bpy.data.objects:
        if ob.type != 'MESH': continue
        base = ob.name.split("_")[0]
        if base != name: continue
        kind = "NEW" if "_SOA" in ob.name else "OLD"
        if COMPACT and kind == "OLD":
            continue
        is_body = ob.name == name + "_SOA"
        real = REAL_TEX and is_body
        verts, uvs, tris = mesh_data(ob, original_uv=real)
        tex, col = tex_and_color(ob)
        if real:
            tex, col = None, [1.0, 1.0, 1.0]   # Studio puts the game's SurfaceAppearance on it
        if COMPACT:
            verts = [round(a, 3) for a in verts]
            uvs = [round(a, 4) for a in uvs]
            if tex:
                tex = dict(w=tex["w"], h=tex["h"], b64=base64.b64encode(bytes(tex["px"])).decode())
            col = [round(a, 4) for a in col]
        parts.append(dict(name=ob.name, kind=kind, verts=verts, uvs=uvs, tris=tris, tex=tex, color=col,
                          look=bool(real) or ob.name.endswith("_Eyes")))
    fname = name + ("_new.json" if COMPACT else ".json")
    with open(os.path.join(out_dir, fname), "w") as fh:
        json.dump(dict(name=name, parts=parts), fh, separators=(",", ":"))
    print("EXPORTED", name, [(p["name"], len(p["tris"]), p["tex"] and (p["tex"]["w"], p["tex"]["h"])) for p in parts])
