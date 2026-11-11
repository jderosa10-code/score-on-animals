"""Egg restyle for Score on Animals (pigeon, 2026-11-10: "change around the egg models ... a lil
more to seem a bit different, not too much").

Every egg in Fake an Egg is one mesh: a stepped (voxel) egg body with the animal's ears / tail /
horns stuck on as separate loose pieces. The same three small changes go on every egg by code:
  1. the egg body is a little chubbier, fattest low down (BODY_WIDE, BODY_TAPER) and a touch squatter
  2. the stuck-on pieces (ears, tails, horns...) are a little bigger, grown from where they attach
  3. the hard steps of the body are softened a little (SOFTEN) - set SOFTEN = 0 to keep them hard
Only vertex positions move: UVs, faces and the material stay, so Studs and the Inverted / Hacked
SurfaceAppearance textures still fit. Up is +Z here (Roblox +Y), checked against Studio.

blender -b eggs_originals.blend -P eggs_restyle.py -- <out.blend> <Name,Name,...|ALL>
"""
import bpy, bmesh, sys
from mathutils import Vector

blend_out, which = sys.argv[sys.argv.index("--") + 1:][:2]

import os
BODY_WIDE = 1.08      # sideways growth of the body at its middle height
BODY_TAPER = float(os.environ.get("EGG_TAPER", "0.05"))   # extra at the bottom, less at the top
BODY_TALL = 0.96      # height of the body
FEATURE = 1.18        # ears / tails / horns
SOFTEN, SOFTEN_ITERS = float(os.environ.get("EGG_SOFTEN", "0.4")), 1
# 2026-11-10: the first full run (taper 0.05, soften 0.4) looked "all messed up" in the game. The
# eggs' textures are pixel art laid on the flat block faces; softening tilts those faces and the
# texture smears. EGG_SOFTEN=0 EGG_TAPER=0 keeps every face flat and square.


def islands(bm):
    seen, out = set(), []
    for v in bm.verts:
        if v.index in seen: continue
        stack, isl = [v], []
        seen.add(v.index)
        while stack:
            x = stack.pop(); isl.append(x)
            for e in x.link_edges:
                o = e.other_vert(x)
                if o.index not in seen: seen.add(o.index); stack.append(o)
        out.append(isl)
    return out


def bbox(vs):
    cs = [v.co for v in vs]
    mn = Vector((min(c.x for c in cs), min(c.y for c in cs), min(c.z for c in cs)))
    mx = Vector((max(c.x for c in cs), max(c.y for c in cs), max(c.z for c in cs)))
    return mn, mx


def restyle(ob):
    me = ob.data
    bm = bmesh.new(); bm.from_mesh(me)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-4)
    bm.verts.ensure_lookup_table(); bm.verts.index_update()
    parts = islands(bm)
    amn, amx = bbox(bm.verts)
    ground = amn.z
    # the body: the piece with the most corners (the stepped egg), which must also be a big piece
    body = max(parts, key=len)
    bmn, bmx = bbox(body)
    c = (bmn + bmx) / 2
    half = max(1e-6, (bmx.z - bmn.z) / 2)
    info = dict(parts=len(parts), body_verts=len(body), body_h=round((bmx.z - bmn.z) / max(1e-6, amx.z - amn.z), 2))

    def body_move(p):
        t = max(-1.0, min(1.0, (p.z - c.z) / half))
        s = BODY_WIDE - BODY_TAPER * t
        return Vector((c.x + (p.x - c.x) * s, c.y + (p.y - c.y) * s, bmn.z + (p.z - bmn.z) * BODY_TALL))

    # 2. features first (their anchors are measured on the untouched body)
    body_ids = {v.index for v in body}
    for isl in parts:
        if isl is body: continue
        anchor = min(isl, key=lambda v: (v.co - c).length_squared).co.copy()
        target = body_move(anchor)
        for v in isl:
            v.co = target + (v.co - anchor) * FEATURE
        lo = min(v.co.z for v in isl)
        if lo < ground:                                  # never poke through the floor
            for v in isl: v.co.z += ground - lo
    # 1. body
    for v in body:
        v.co = body_move(v.co)
    # 3. soften the steps: slide each body corner part-way to the average of its neighbours, then
    #    put the body back to the size it had, because smoothing shrinks
    if SOFTEN > 0:
        mn0, mx0 = bbox(body)
        for _ in range(SOFTEN_ITERS):
            new = {}
            for v in body:
                nb = [e.other_vert(v).co for e in v.link_edges]
                new[v.index] = v.co.lerp(sum(nb, Vector()) / len(nb), SOFTEN) if nb else v.co.copy()
            for v in body: v.co = new[v.index]
        mn1, mx1 = bbox(body)
        c0, c1 = (mn0 + mx0) / 2, (mn1 + mx1) / 2
        k = [(mx0[a] - mn0[a]) / max(1e-6, mx1[a] - mn1[a]) for a in range(3)]
        for v in body:
            v.co = Vector((c0.x + (v.co.x - c1.x) * k[0], c0.y + (v.co.y - c1.y) * k[1], c0.z + (v.co.z - c1.z) * k[2]))
    # back on the ground
    lo = min(v.co.z for v in bm.verts)
    for v in bm.verts: v.co.z += ground - lo
    nmn, nmx = bbox(bm.verts)
    info["grow"] = [round((nmx[a] - nmn[a]) / max(1e-6, amx[a] - amn[a]), 3) for a in range(3)]
    bm.normal_update()
    bm.to_mesh(me); bm.free()
    for p in me.polygons: p.use_smooth = False
    ob["size_ratio"] = info["grow"]
    return info


names = [o.name for o in bpy.data.objects if o.get("kind") == "egg"] if which == "ALL" else which.split(",")
for n in sorted(names):
    src = bpy.data.objects[n]
    new = src.copy(); new.data = src.data.copy(); new.name = n + "_NEW"
    bpy.context.scene.collection.objects.link(new)
    print("EGG", n, restyle(new))
bpy.ops.wm.save_as_mainfile(filepath=blend_out)
print("DONE")
