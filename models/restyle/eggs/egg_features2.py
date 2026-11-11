"""NEW FEATURES for every egg (pigeon, 2026-11-10: "the features of the egg need to be different" ...
"YES YOU JUST GOTTA MAKE THEM GOOD"). Shell and size are never touched. An egg's ears / horns /
tusks / tail are recognised by where they sit and how they're shaped, deleted, and replaced with a
newly designed piece of the same kind, coloured from the old piece's own texels (so the egg's
textures and every mutation still fit). Anything not recognised with confidence is left alone.

All standard eggs share one shell, so designs are written once in "egg space" (origin = shell centre,
egg faces -X, left/right = Y, up = Z) and fitted to each egg: moved to where the old piece sat and
scaled by how big the old piece was (so a fennec still has bigger ears than a corgi).

blender -b eggs2_originals.blend -P egg_features2.py -- <out.blend> <render_dir> <Name,Name|ALL> [json_out]
"""
import bpy, bmesh, sys, os, math, json
import numpy as np
from mathutils import Vector, Matrix
from mathutils.bvhtree import BVHTree

argv = sys.argv[sys.argv.index("--") + 1:]
blend_out, render_dir, which = argv[0], argv[1], argv[2]
json_out = argv[3] if len(argv) > 3 else None
os.makedirs(render_dir, exist_ok=True)
sc = bpy.context.scene

SKIP = set(os.environ.get("EGG_SKIP", "").split(",")) - {""}          # eggs to leave alone
# per-egg corrections found while checking the sheets: {egg: {kind: style or None}}
OVERRIDE = {}
_ov = os.environ.get("EGG_OVERRIDES")
if _ov and os.path.exists(_ov): OVERRIDE = json.load(open(_ov))


# ------------------------------------------------------------------ geometry helpers
def catmull(pts, per=5):
    P = [Vector(p) for p in pts]
    P = [P[0] + (P[0] - P[1])] + P + [P[-1] + (P[-1] - P[-2])]
    out = []
    for i in range(1, len(P) - 2):
        for k in range(per):
            t = k / per
            a, b, c, d = P[i - 1], P[i], P[i + 1], P[i + 2]
            out.append(0.5 * ((2 * b) + (-a + c) * t + (2 * a - 5 * b + 4 * c - d) * t * t + (-a + 3 * b - 3 * c + d) * t ** 3))
    out.append(P[-2].copy())
    return out


def sweep(bm, pts, side, wa, wb, sides=6, urange=None, shift=None):
    """Tube along a smooth path. urange keeps only part of its length (for an ear's inner panel);
    shift moves the whole piece (the inner panel sits a touch in front of the ear)."""
    path = catmull(pts)
    s = Vector(side)
    rings, n = [], len(path)
    off = Vector(shift) if shift else Vector((0, 0, 0))
    for i, p in enumerate(path):
        t = (path[min(i + 1, n - 1)] - path[max(i - 1, 0)]).normalized()
        s = (s - t * s.dot(t)).normalized()
        nrm = t.cross(s)
        u = i / (n - 1)
        if urange and not (urange[0] <= u <= urange[1]): continue
        a, b = wa(u), wb(u)
        rings.append([bm.verts.new(p + off + s * a * math.cos(2 * math.pi * k / sides) + nrm * b * math.sin(2 * math.pi * k / sides)) for k in range(sides)])
    faces = []
    n = len(rings)
    for i in range(n - 1):
        for k in range(sides):
            faces.append(bm.faces.new([rings[i][k], rings[i][(k + 1) % sides], rings[i + 1][(k + 1) % sides], rings[i + 1][k]]))
    faces.append(bm.faces.new(rings[-1]))
    faces.append(bm.faces.new(list(reversed(rings[0]))))
    return faces


def ball(bm, centre, r):
    res = bmesh.ops.create_icosphere(bm, subdivisions=1, radius=r, matrix=Matrix.Translation(Vector(centre)))
    return list({f for v in res["verts"] for f in v.link_faces})


taper = lambda r0, r1, p=1.0: (lambda u: r1 + (r0 - r1) * (1 - u) ** p)
leaf = lambda w, tip=0.25: (lambda u: w * (0.7 + 0.45 * math.sin(math.pi * min(u, 0.999))) * (1.0 if u < 0.8 else 1 - (1 - tip) * (u - 0.8) / 0.2))
flat = lambda w: (lambda u: w)

# ------------------------------------------------------------------ the designs, in egg space
# path points are for the +Y side; x is relative to where the old piece sat (dx), y / z are absolute.
# ref = the size of the old piece the design was drawn for (used to scale it per egg)
STYLES = {
    # --- ears
    "ears_lop":   dict(path=[(0, 0.6, 2.16), (0, 1.45, 2.61), (0, 2.1, 1.86), (0, 2.3, 0.56), (0, 2.25, -0.74)], side=(1, 0.35, 0),
                       wa=leaf(0.85, 0.5), wb=flat(0.3), ear=True, ref=3.3),
    "ears_wide":  dict(path=[(0, 0.35, 1.61), (0, 0.95, 2.41), (0, 1.6, 3.06), (0, 1.95, 3.41)], side=(0, 0.8, -0.6),
                       wa=taper(1.05, 0.08, 0.75), wb=flat(0.3), ear=True, ref=2.4),
    "ears_droop": dict(path=[(0, 1.2, 1.5), (0, 2.1, 1.55), (0, 2.9, 1.2), (0, 3.2, 0.5)], side=(0, 0, 1),
                       wa=leaf(0.5), wb=flat(0.26), ear=True, ref=1.4),
    "ears_fan":   dict(path=[(0, 1.6, 1.42), (0, 2.6, 1.52), (0, 3.3, 0.82), (0, 3.3, -0.38)], side=(0, 0, 1),
                       wa=leaf(1.15, 0.45), wb=flat(0.32), ear=True, ref=2.3),
    # bear / mouse ears. v1 was a thin disc leaning out and back ("the new ears just look weird"):
    # now a chunky upright half-round, about as thick as the old game's block ears
    # (v2 was upright but tall and narrow, like rabbit ears: now low and wide, a half circle)
    "ears_round": dict(path=[(0, 1.05, 1.7), (0, 1.22, 2.2), (0, 1.33, 2.6), (0, 1.38, 2.88)], side=(0, 0.97, -0.25),
                       wa=(lambda u: 0.95 * (1.0 if u < 0.5 else math.sqrt(max(0.0, 1 - ((u - 0.5) / 0.5) ** 2)) * 0.9 + 0.1)),
                       wb=flat(0.4), ear=True, ref=1.6),
    # --- horns / tusks
    "horns_long": dict(path=[(0, 0.7, 1.6), (0, 1.7, 2.1), (0, 2.5, 2.6), (-0.15, 2.9, 3.5), (-0.45, 2.8, 4.2)], side=(1, 0, 0),
                       wa=taper(0.36, 0.05, 0.8), wb=taper(0.36, 0.05, 0.8), ref=1.15),
    "horns_ram":  dict(path=[(0, 0.6, 2.0), (0.5, 1.4, 2.6), (1.2, 2.0, 2.1), (1.2, 2.2, 1.1), (0.5, 2.3, 0.6), (0.0, 2.5, 1.0)], side=(1, 0, 0),
                       wa=taper(0.4, 0.1, 0.8), wb=taper(0.4, 0.1, 0.8), ref=1.6),
    "tusks_curl": dict(path=[(0.5, 1.0, -0.58), (-0.9, 1.45, -1.68), (-2.3, 1.5, -1.88), (-3.3, 1.0, -1.08), (-3.4, 0.35, 0.12), (-2.8, 0.1, 0.92)],
                       side=(0, 1, 0), wa=taper(0.4, 0.06), wb=taper(0.4, 0.06), ref=2.5),
    # --- tails (on the mid line; x absolute)
    "tail_s":     dict(path=[(1.48, 0, -1.19), (3.08, 0, -1.79), (4.38, 0, -1.09), (4.58, 0, 0.51), (3.78, 0, 1.51), (4.08, 0, 2.61)],
                       side=(0, 1, 0), wa=flat(0.46), wb=flat(0.46), single=True, absx=True, ref=3.4),
    "tail_bushy": dict(path=[(1.5, 0, -1.3), (2.9, 0, -1.1), (3.9, 0, 0.0), (4.1, 0, 1.4), (3.5, 0, 2.5)],
                       side=(0, 1, 0), wa=leaf(0.75, 0.3), wb=leaf(0.75, 0.3), single=True, absx=True, ref=3.0),
    "tail_pom":   dict(ball=(2.78, 0, -1.04, 0.8), single=True, absx=True, ref=1.4),
}
STYLES.update({
    "ears_tall":  dict(path=[(0, 0.5, 1.9), (0, 0.8, 2.9), (0, 1.15, 3.8), (0, 1.3, 4.3)], side=(0, 0.95, -0.3),          # horse / llama / zebra
                       wa=leaf(0.5, 0.15), wb=flat(0.27), ear=True, ref=2.4),
    # bunny: one ear up, one folded over (the lop ears read as bag handles and were dropped)
    "ears_bent":  dict(path=[(0, 0.55, 1.9), (0, 0.75, 3.0), (0, 0.95, 4.1), (0, 1.0, 5.0)],
                       path_neg=[(0, 0.55, 1.9), (0, 0.8, 3.0), (0, 1.3, 3.75), (0, 2.1, 3.55), (0, 2.6, 2.7)], side=(0, 1, -0.1),
                       wa=leaf(0.6, 0.3), wb=flat(0.3), ear=True, ref=3.3),
    # dog: flat floppy ears hanging at the sides (start at the side, no arch over the top)
    "ears_flop":  dict(path=[(0, 1.5, 1.5), (0, 2.2, 1.3), (0, 2.45, 0.2), (0, 2.35, -0.9)], side=(1, 0.2, 0),
                       wa=leaf(0.8, 0.6), wb=flat(0.3), ear=True, ref=2.3),
    "tail_curl":  dict(path=[(1.5, 0, -1.3), (2.9, 0, -1.3), (3.9, 0, -0.6), (4.0, 0, 0.5), (3.3, 0, 1.1)],                 # dog: sticks out, curls up
                       side=(0, 1, 0), wa=taper(0.46, 0.22), wb=taper(0.46, 0.22), single=True, absx=True, ref=2.6),
    "tail_flow":  dict(path=[(1.5, 0, -0.6), (2.6, 0, -0.4), (3.1, 0, -1.4), (2.9, 0, -2.5)],                                # horse / zebra: hangs down
                       side=(0, 1, 0), wa=leaf(0.5, 0.35), wb=leaf(0.42, 0.35), single=True, absx=True, ref=2.5),
})
SHELL = Vector((4.15, 4.16, 5.51))

# WHAT EACH ANIMAL GETS. The first try guessed from shapes alone and gave the bunny horns and every
# animal a huge tail, so the design is now chosen per animal by name; shapes are only used to find
# the old pieces. An animal not listed here is left alone. None = keep that old piece.
ANIMALS = {
    "bunny":    dict(ears="ears_bent", tail="tail_pom"),
    "cat":      dict(ears="ears_wide", tail="tail_s"),
    "cow":      dict(horns="horns_long", ears="ears_droop"),
    "dog":      dict(ears="ears_flop", tail="tail_curl"),
    "hamster":  dict(ears="ears_round"),
    "goat":     dict(horns="horns_ram", ears="ears_droop"),
    "horse":    dict(ears="ears_tall"),                    # mane + tail are one built-up piece: kept
    "kangaroo": dict(ears="ears_wide"),
    "koala":    dict(ears="ears_round"),
    "llama":    dict(ears="ears_tall", tail="tail_pom"),
    "zebra":    dict(ears="ears_tall"),
    "mammoth":  dict(tusks="tusks_curl", ears="ears_fan"),
    # ---- batch 2: dogs
    "akita": dict(ears="ears_wide", tail="tail_curl"), "bichon": dict(ears="ears_flop", tail="tail_pom"),
    "bulldog": dict(ears="ears_flop", tail="tail_pom"), "cattledog": dict(ears="ears_wide", tail="tail_curl"),
    "cavalier": dict(ears="ears_flop", tail="tail_curl"), "chowchow": dict(ears="ears_round", tail="tail_curl"),
    "corgi": dict(ears="ears_wide", tail="tail_pom"), "dingo": dict(ears="ears_wide", tail="tail_curl"),
    "goldenretriever": dict(ears="ears_flop", tail="tail_curl"), "greatdane": dict(ears="ears_flop", tail="tail_curl"),
    "maltese": dict(ears="ears_flop", tail="tail_pom"), "papillon": dict(ears="ears_wide", tail="tail_curl"),
    "shibainu": dict(ears="ears_wide", tail="tail_curl"), "terrier": dict(ears="ears_wide", tail="tail_pom"),
    "wolf": dict(ears="ears_wide", tail="tail_s"), "jackal": dict(ears="ears_wide", tail="tail_curl"),
    "hyena": dict(ears="ears_round", tail="tail_curl"), "fennecfox": dict(ears="ears_wide", tail="tail_s"),
    # ---- cats
    "caracal": dict(ears="ears_wide", tail="tail_s"), "serval": dict(ears="ears_wide", tail="tail_s"),
    "lion": dict(ears="ears_round", tail="tail_s"), "tiger": dict(ears="ears_round", tail="tail_s"),
    "sabertooth": dict(ears="ears_round", tail="tail_s"), "fossa": dict(ears="ears_round", tail="tail_s"),
    "binturong": dict(ears="ears_round", tail="tail_s"),
    # ---- other mammals
    "bear": dict(ears="ears_round"), "polarbear": dict(ears="ears_round"), "capybara": dict(ears="ears_round"),
    "guineapig": dict(ears="ears_round"), "quokka": dict(ears="ears_round"), "badger": dict(ears="ears_round"),
    "honeybadger": dict(ears="ears_round"), "tanuki": dict(ears="ears_round", tail="tail_curl"),
    "redpanda": dict(ears="ears_wide", tail="tail_s"), "lemur": dict(ears="ears_round", tail="tail_s"),
    "meerkat": dict(ears="ears_round"), "otter": dict(ears="ears_round"), "beaver": dict(ears="ears_round"),
    "hedgehog": dict(ears="ears_round"), "tapir": dict(ears="ears_round"), "hippopotamus": dict(ears="ears_round"),
    "whiterhino": dict(ears="ears_round"), "pony": dict(ears="ears_tall"), "unicorn": dict(ears="ears_tall"),
    "okapi": dict(ears="ears_tall"), "aardvark": dict(ears="ears_tall"), "armadillo": dict(ears="ears_tall"),
    "bull": dict(horns="horns_long", ears="ears_droop"), "yak": dict(horns="horns_long"),     # the yak egg has horns only
    "americanbison": dict(horns="horns_long", ears="ears_droop"), "moose": dict(ears="ears_droop"),
    "elephant": dict(ears="ears_fan", tusks="tusks_curl"), "woollymammoth": dict(ears="ears_fan", tusks="tusks_curl"),
    "jackalope": dict(ears="ears_tall"),                   # bent ear next to the antlers read as a broken horn
}


def islands(bm):
    seen, out = set(), []
    for v in bm.verts:
        if v.index in seen: continue
        st, isl = [v], []; seen.add(v.index)
        while st:
            x = st.pop(); isl.append(x)
            for e in x.link_edges:
                o = e.other_vert(x)
                if o.index not in seen: seen.add(o.index); st.append(o)
        out.append(isl)
    return out


def describe(isl, c, sc=1.0):
    """Centre / size in egg space and the shape class of one loose piece."""
    P = np.array([list((v.co - c) / sc) for v in isl])
    mn, mx = P.min(axis=0), P.max(axis=0)
    ev = np.sqrt(np.maximum(np.linalg.eigvalsh(np.cov((P - P.mean(axis=0)).T)), 1e-9)) if len(isl) >= 4 else np.array([1e-3, 1e-3, 1e-3])
    l0, l1, l2 = float(ev[0]), float(ev[1]), float(ev[2])
    shape = "plate" if l1 / l0 > 2.0 and l2 / l1 < 2.6 else ("rod" if l2 / l1 > 1.9 else "blob")
    return dict(isl=isl, n=len(isl), c=Vector((mn + mx) / 2), s=Vector(mx - mn), mn=Vector(mn), mx=Vector(mx), shape=shape)


def classify(d, has_horns):
    """What an (upper / front / back) piece is -> (kind, style) or None."""
    c, s = d["c"], d["s"]
    simple = d["n"] <= 48
    if d["pair"] and simple:
        if c.z > 0.7 and c.x > -1.4:                           # on the upper part of the egg
            if d["shape"] == "rod" and max(s) >= 0.9 and sorted(s)[1] >= 0.3:
                return ("horns", "horns_ram" if s.x > 1.3 * s.z else "horns_long")
            if d["shape"] in ("plate", "blob") and max(s) >= 0.7:
                if d["shape"] == "blob" and max(s) < 1.3: return None            # eyes on top, bumps
                if s.z >= 2.3 and abs(c.y) < 1.5: return ("ears", "ears_lop")
                if abs(c.y) > 1.9 and s.z > 1.6: return ("ears", "ears_fan")
                if has_horns or abs(c.y) > 1.35: return ("ears", "ears_droop")
                if s.z < 1.35: return ("ears", "ears_round")
                return ("ears", "ears_wide")
        if c.x < -0.6 and c.z < 0.2 and d["shape"] == "rod" and max(s) >= 1.6:
            return ("tusks", "tusks_curl")
    if not d["pair"] and abs(c.y) < 0.2 and c.x > 1.3 and d["n"] <= 60 and c.z < 1.6:
        if max(s) < 1.7: return ("tail", "tail_pom")
        return ("tail", "tail_bushy" if sorted(s)[1] > 1.2 else "tail_s")
    return None


def redesign(src):
    ob = src.copy(); ob.data = src.data.copy(); ob.name = src.name + "_FEAT"
    sc.collection.objects.link(ob)
    me = ob.data
    img = next((n.image for m in me.materials if m and m.use_nodes for n in m.node_tree.nodes if n.type == 'TEX_IMAGE' and n.image), None)
    W, H = img.size
    px = np.array(img.pixels[:]).reshape(H, W, 4)

    def colour(uv):
        return tuple(px[min(H - 1, max(0, int(uv.y * H))), min(W - 1, max(0, int(uv.x * W))), :3])

    bm = bmesh.new(); bm.from_mesh(me)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-4)
    bm.verts.ensure_lookup_table(); bm.verts.index_update()
    uvl = bm.loops.layers.uv.active
    isls = islands(bm)
    body = max(isls, key=len)

    def box(vs):
        cs = [v.co for v in vs]
        return (Vector((min(p.x for p in cs), min(p.y for p in cs), min(p.z for p in cs))),
                Vector((max(p.x for p in cs), max(p.y for p in cs), max(p.z for p in cs))))
    bmn, bmx = box(body)
    if max(abs((bmx - bmn)[k] - SHELL[k]) for k in range(3)) > 0.35 and REF_SHELL:
        # On about a third of the eggs some features share corners with the shell, so "the biggest
        # piece" is shell + features. Every egg has the SAME shell, so find it by matching corners
        # against a reference shell (any offset), then cut the features off it.
        ref = REF_SHELL
        probes = ref[::max(1, len(ref) // 8)][:8]
        votes = {}
        for v in body:
            for r in probes:
                t = v.co - r
                key = (round(t.x, 2), round(t.y, 2), round(t.z, 2))
                votes[key] = votes.get(key, 0) + 1
        t = Vector(max(votes, key=votes.get))
        refset = {(round(r.x + t.x, 2), round(r.y + t.y, 2), round(r.z + t.z, 2)) for r in ref}
        is_shell = {v.index for v in body if (round(v.co.x, 2), round(v.co.y, 2), round(v.co.z, 2)) in refset}
        if len(is_shell) >= 0.9 * len(ref):
            feat_faces = list({f for v in body for f in v.link_faces if any(w.index not in is_shell for w in f.verts)})
            if feat_faces:
                bmesh.ops.split(bm, geom=feat_faces)
                bm.verts.ensure_lookup_table(); bm.verts.index_update()
                isls = islands(bm)
                body = max(isls, key=lambda isl: sum(1 for v in isl if (round(v.co.x, 2), round(v.co.y, 2), round(v.co.z, 2)) in refset))
                bmn, bmx = box(body)
    # about a third of the eggs use the same shell a little bigger (x1.1): work in "standard egg"
    # units (everything divided by SC) and scale the new pieces back up
    SC = (bmx.z - bmn.z) / SHELL.z
    if not (0.8 < SC < 1.4) or max(abs((bmx - bmn)[k] / SC - SHELL[k]) for k in range(3)) > 0.3:
        bm.free(); return ob, ["odd shell: left alone"]
    c = (bmn + bmx) / 2
    for isl in isls:
        if isl is not body: bmesh.ops.recalc_face_normals(bm, faces=list({f for v in isl for f in v.link_faces}))
    # the shell's surface, so every new piece can be rooted INSIDE it (pigeon: "these ears aren't touching")
    body_faces = list({f for v in body for f in v.link_faces})
    bmesh.ops.recalc_face_normals(bm, faces=body_faces)
    shell = BVHTree.FromPolygons([v.co.copy() for v in bm.verts], [[v.index for v in f.verts] for f in body_faces])

    def rooted(pts):
        loc, nrm, _, dist = shell.find_nearest(pts[0])
        if loc is None: return pts
        if (pts[0] - loc).dot(nrm) < -0.3: return pts                # already well inside
        return [loc - nrm * 0.4] + pts
    ds = [describe(isl, c, SC) for isl in isls if isl is not body]
    for d in ds:
        d["pair"] = None
        if abs(d["c"].y) > 0.25:
            m = Vector((d["c"].x, -d["c"].y, d["c"].z))
            d["pair"] = next((e for e in ds if e is not d and e["n"] == d["n"] and (e["c"] - m).length < 0.2), None)
    # the design comes from the animal's name; shapes only say WHICH old pieces are its ears / horns / tail
    import re
    want = dict(ANIMALS.get(re.sub(r"\d+$", "", src.name[3:]).lower(), {}))
    want.update(OVERRIDE.get(src.name, {}))
    if not want:
        bm.free(); return ob, []
    plus = [d for d in ds if d["pair"] and d["c"].y > 0 and d["n"] <= 48]
    # on top of the egg, or big and hanging at its sides (dog ears); not far back (that's a mane)
    top = sorted((d for d in plus if -1.4 < d["c"].x < 0.9 and max(d["s"]) >= 0.7
                  and (d["c"].z > 0.7 or (d["c"].z > 0.2 and abs(d["c"].y) > 1.5 and max(d["s"]) >= 1.5))), key=lambda d: abs(d["c"].y))
    plan = []
    if want.get("horns") and want.get("ears") and len(top) >= 2:      # horns sit inside the ears
        plan += [("horns", want["horns"], top[0]), ("ears", want["ears"], max(top[1:], key=lambda d: max(d["s"])))]
    elif top:
        kind = "ears" if want.get("ears") else ("horns" if want.get("horns") else None)
        if kind: plan.append((kind, want[kind], max(top, key=lambda d: max(d["s"]))))
    if want.get("tusks"):
        cand = [d for d in plus if d["c"].x < -0.6 and d["c"].z < 0.2 and max(d["s"]) >= 1.6]
        if cand: plan.append(("tusks", want["tusks"], max(cand, key=lambda d: max(d["s"]))))
    if want.get("tail"):
        cand = [d for d in ds if not d["pair"] and abs(d["c"].y) < 0.2 and d["c"].x > 1.3 and d["n"] <= 60 and d["c"].z < 0.5]   # low at the back
        if cand: plan.append(("tail", want["tail"], max(cand, key=lambda d: max(d["s"]))))
    notes = []
    for kind, style, d in plan:
        st = STYLES[style]
        olds = [d["isl"]] + ([d["pair"]["isl"]] if d["pair"] else [])
        # colours of the old piece: what its back shows (outer) and what its front shows (inner)
        tally, front, back = {}, {}, {}
        for isl in olds:
            for f in {f for v in isl for f in v.link_faces}:
                uv = sum((l[uvl].uv for l in f.loops), Vector((0, 0))) / len(f.loops)
                col = colour(uv); key = tuple(round(a * 8) for a in col); ar = f.calc_area()
                for t, ok in ((tally, True), (front, f.normal.x < -0.5), (back, f.normal.x > 0.2)):
                    if ok:
                        e = t.setdefault(key, [0.0, uv, col]); e[0] += ar
        top = lambda t: max(t.values(), key=lambda e: e[0]) if t else None
        main = top(tally)
        outer = top(back) or main
        # the ear's inside colour: the most common colour on its front that isn't the outer colour
        differs = lambda e: sum(abs(a - b) for a, b in zip(e[2], outer[2])) > 0.2
        inner = max((e for e in front.values() if differs(e)), key=lambda e: e[0], default=None) \
            or max((e for e in tally.values() if differs(e)), key=lambda e: e[0], default=None)
        # fit: where the old piece sat, and how big it was
        size_old = max(d["s"])
        k = max(0.85, min(1.2, size_old / st["ref"]))
        dx = 0.0 if st.get("absx") else d["c"].x
        if kind == "tusks": dx = d["mx"].x - 0.5
        for isl in olds:
            bmesh.ops.delete(bm, geom=[v for v in isl if v.is_valid], context='VERTS')
        new, panels = [], []
        for sgn in ((1,) if st.get("single") else (1, -1)):
            if "ball" in st:
                bx, by, bz, br = st["ball"]
                ctr = c + Vector((bx, by, bz)) * SC
                kk = k * SC
                loc, nrm, _, dist = shell.find_nearest(ctr)
                if loc is not None and (ctr - loc).dot(nrm) > br * kk * 0.5: ctr = loc + nrm * br * kk * 0.5     # sunk half into the shell
                fs = ball(bm, ctr, br * kk)
            else:
                kk = k * SC
                path = st["path_neg"] if (sgn < 0 and "path_neg" in st) else st["path"]
                p0 = Vector(path[0])
                pts = [c + SC * (Vector((dx, 0, 0)) + Vector(((p0.x + (Vector(p).x - p0.x) * k), sgn * (p0.y + (Vector(p).y - p0.y) * k), p0.z + (Vector(p).z - p0.z) * k))) for p in path]
                pts = rooted(pts)
                sd = Vector(st["side"]); sd.y *= sgn
                fs = sweep(bm, pts, sd, (lambda u, f=st["wa"]: f(u) * kk), (lambda u, f=st["wb"]: f(u) * kk))
                # ears keep the old ears' look: an outer rim with the inside colour set into the front
                # (pigeon: "outline the ears"). The panel is a narrower copy sitting a touch forward.
                if st.get("ear") and inner and abs(sd.x) < 0.5:
                    panels += sweep(bm, pts, sd, (lambda u, f=st["wa"]: f(u) * kk * 0.6), (lambda u, f=st["wb"]: f(u) * kk),
                                    urange=(0.24, 0.88), shift=(-0.12 * kk, 0, 0))
            new += fs
        bmesh.ops.recalc_face_normals(bm, faces=new + panels)
        lowest = bmn.z + 0.05
        for f in new + panels:
            for v in f.verts:
                if v.co.z < lowest: v.co.z = lowest
        for f in new:
            use = outer if st.get("ear") else main
            for l in f.loops: l[uvl].uv = use[1]
        for f in panels:
            for l in f.loops: l[uvl].uv = inner[1]
        notes.append(f"{kind}:{style}x{k:.2f}")
    bm.normal_update()
    bm.to_mesh(me); bm.free()
    for p in me.polygons: p.use_smooth = False
    return ob, notes


# the reference shell: the bunny's (a clean one), corners relative to nothing in particular
REF_SHELL = []
_b = bpy.data.objects.get("Eggbunny1")
if _b:
    _bm = bmesh.new(); _bm.from_mesh(_b.data)
    bmesh.ops.remove_doubles(_bm, verts=_bm.verts, dist=1e-4)
    REF_SHELL = [v.co.copy() for v in max(islands(_bm), key=len)]
    _bm.free()

names = sorted(o.name for o in bpy.data.objects if o.get("kind") == "egg") if which == "ALL" else which.split(",")
if which == "TABLE":
    import re as _re
    names = sorted(o.name for o in bpy.data.objects if o.get("kind") == "egg" and _re.sub(r"\d+$", "", o.name[3:]).lower() in ANIMALS)
rows, untouched = [], []
for n in names:
    src = bpy.data.objects.get(n)
    if not src: print("MISSING", n); continue
    if n in SKIP: untouched.append(n); print("EGG", n, "SKIPPED"); continue
    ob, notes = redesign(src)
    print("EGG", n, "|", ", ".join(notes) if notes else "nothing recognised")
    if notes and not notes[0].startswith("odd"): rows.append((src, ob))
    else: untouched.append(n); bpy.data.objects.remove(ob, do_unlink=True)
print("CHANGED", len(rows), "UNTOUCHED", len(untouched))
bpy.ops.wm.save_as_mainfile(filepath=blend_out)

if json_out:
    payload = {}
    for src, ob in rows:
        me = ob.data
        cs = [v.co for v in me.vertices]; ocs = [v.co for v in src.data.vertices]
        omn = Vector((min(p.x for p in ocs), min(p.y for p in ocs), min(p.z for p in ocs)))
        omx = Vector((max(p.x for p in ocs), max(p.y for p in ocs), max(p.z for p in ocs)))
        mn = Vector((min(p.x for p in cs), min(p.y for p in cs), min(p.z for p in cs)))
        mx = Vector((max(p.x for p in cs), max(p.y for p in cs), max(p.z for p in cs)))
        ctr = (mn + mx) / 2
        verts = []
        for v in me.vertices:
            q = v.co - ctr; verts += [round(q.x, 4), round(q.z, 4), round(-q.y, 4)]
        uvl = me.uv_layers.active.data
        me.calc_loop_triangles()
        uvs, tris = [], []
        for t in me.loop_triangles:
            ids = []
            for li in t.loops:
                u, v = uvl[li].uv; uvs += [round(u, 5), round(1 - v, 5)]; ids.append(len(uvs) // 2)
            tris.append([me.loops[li].vertex_index + 1 for li in t.loops] + ids)
        off = ctr - (omn + omx) / 2
        payload[src.name] = dict(verts=verts, uvs=uvs, tris=tris, offset=[round(off.x, 4), round(off.z, 4), round(-off.y, 4)])
    json.dump(payload, open(json_out, "w"))
    _pd = json_out[:-5] + "_parts"; os.makedirs(_pd, exist_ok=True)
    for _k, _v in payload.items(): json.dump(_v, open(os.path.join(_pd, _k + ".json"), "w"))
    json.dump(sorted(payload), open(os.path.join(_pd, "index.json"), "w"))

sc.render.engine = 'BLENDER_WORKBENCH'
sh = sc.display.shading
sh.light = 'STUDIO'; sh.color_type = 'TEXTURE'; sh.show_cavity = True; sh.cavity_type = 'WORLD'; sh.show_object_outline = True
sc.render.resolution_x, sc.render.resolution_y = 640, 400
cam = bpy.data.objects.new("FCam", bpy.data.cameras.new("FCam")); sc.collection.objects.link(cam)
cam.data.type = 'ORTHO'; sc.camera = cam
for src, new in rows:
    for o in sc.objects:
        if o.type == 'MESH': o.hide_render = o not in (src, new)
    for tag, d in (("a", Vector((-1, -0.75, 0.4))), ("b", Vector((1, 0.75, 0.4)))):
        right = -Vector((0, 0, 1)).cross(-d).normalized()
        ws = max(new.dimensions.x, new.dimensions.y, src.dimensions.x, src.dimensions.y) * 1.12
        src.location = -right * ws * 0.5; new.location = right * ws * 0.5
        base = -min(Vector(b).z for b in src.bound_box)
        src.location.z = base; new.location.z = base
        bpy.context.view_layer.update()
        pts = [o.matrix_world @ Vector(b) for o in (src, new) for b in o.bound_box]
        mn = Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
        mx = Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
        ctr = (mn + mx) / 2
        cam.data.ortho_scale = max(ws * 2.2, (mx.z - mn.z) * 1.25 * 640 / 400)
        cam.location = ctr + d.normalized() * 80
        cam.rotation_euler = (ctr - cam.location).to_track_quat('-Z', 'Y').to_euler()
        sc.render.filepath = os.path.join(render_dir, f"{src.name}_{tag}.png")
        bpy.ops.render.render(write_still=True)
    src.location = (0, 0, 0); new.location = (0, 0, 0)
print("DONE", len(rows))
