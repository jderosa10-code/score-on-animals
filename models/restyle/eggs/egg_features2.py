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
    "whiterhino": dict(ears="ears_round"), "pony": dict(ears="ears_tall", face=True), "unicorn": dict(ears="ears_tall"),
    "okapi": dict(ears="ears_tall"), "aardvark": dict(ears="ears_tall"), "armadillo": dict(ears="ears_tall"),
    "bull": dict(horns="horns_long", ears="ears_droop"), "yak": dict(horns="horns_long"),     # the yak egg has horns only
    "americanbison": dict(horns="horns_long", ears="ears_droop"), "moose": dict(ears="ears_droop"),
    "elephant": dict(ears="ears_fan", tusks="tusks_curl"), "woollymammoth": dict(ears="ears_fan", tusks="tusks_curl"),
    "jackalope": dict(ears="ears_tall"),                   # bent ear next to the antlers read as a broken horn
}


# batch 3 groups (found by where a piece sits; the group only says which rules may run)
BIRDS = set("albatross argentavis caladrius cassowary chicken cockatrice duck emu flamingo garuda griffin kookaburra ostrich owl parrot "
            "peafowl pigeon puffin roc secretary shoebill simurgh stymphalian thunderbird toucan phoenix azhdarchid pteranodon "
            "pterodactyl quetzalcoatlus".split())
FISH = set("anglerfish blobfish bluewhale goblinshark greatwhiteshark megalodon shark swordfish whale seal "   # fangtooth / goldfish / plesiosaur came out worse: left alone
           "leviathan mosasaurus seadragon".split())
MANES = {"wolf", "lion"}
NO_TAIL = set("stegosaurus kitsune manticore ankylosaurus peafowl jellyfish kraken krakenking giantsquid cuttlefish octopus nautilus "
              "snail crab horse zebra unicorn pony".split())
NO_GENERIC = {"hacker", "inverted", "crystalcandy", "dimetrodon", "spinosaurus"}


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
    if os.environ.get("EGG_FACE_ALL") == "1": want["face"] = True      # test: which eggs have no face
    if os.environ.get("EGG_DUMP") == "1":
        # what loose pieces this egg has (for writing the per-animal table)
        seen_ = set(); rows_ = []
        for d in sorted(ds, key=lambda d: -max(d["s"])):
            if id(d) in seen_ or max(d["s"]) < 0.6: continue
            seen_.add(id(d))
            if d["pair"]: seen_.add(id(d["pair"]))
            cc = d["c"] if not d["pair"] or d["c"].y > 0 else d["pair"]["c"]
            rows_.append(f'{"P" if d["pair"] else "S"}{d["n"]}{d["shape"][0]} c({cc.x:.1f},{cc.y:.1f},{cc.z:.1f}) s({d["s"].x:.1f},{d["s"].y:.1f},{d["s"].z:.1f})')
        print("DUMP", src.name, f"SC{SC:.2f} pieces{len(ds)}", " | ".join(rows_[:14]))
        bm.free(); return ob, []
    plus =[d for d in ds if d["pair"] and d["c"].y > 0 and d["n"] <= 48]
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

    # ------------------------------------------------------------ batch 3: every other kind of egg
    # Birds, fish, reptiles, dragons and the manes. Same idea as above (old piece out, newly designed
    # piece of the same kind in, coloured from the old piece), but found by where a piece sits.
    name = re.sub(r"\d+$", "", src.name[3:]).lower()
    used = set()
    for _, _, d in plan:
        used.add(id(d))
        if d["pair"]: used.add(id(d["pair"]))
    free = lambda d: id(d) not in used and not d.get("dead")
    mid = lambda d: not d["pair"] and abs(d["c"].y) < 0.2
    both = lambda d: [d] + ([d["pair"]] if d["pair"] else [])
    E = lambda x, y, z: c + SC * Vector((x, y, z))                    # egg space -> this mesh

    def take(*dd):
        for d in dd:
            used.add(id(d))
            if d["pair"]: used.add(id(d["pair"]))

    def tally_main(pieces):
        t = {}
        for d in pieces:
            for f in {f for v in d["isl"] if v.is_valid for f in v.link_faces}:
                uv = sum((l[uvl].uv for l in f.loops), Vector((0, 0))) / len(f.loops)
                col = colour(uv); key = tuple(round(a * 8) for a in col)
                e = t.setdefault(key, [0.0, uv.copy(), col]); e[0] += f.calc_area()
        return max(t.values(), key=lambda e: e[0])[1] if t else None

    def kill(pieces):
        for d in pieces:
            bmesh.ops.delete(bm, geom=[v for v in d["isl"] if v.is_valid], context='VERTS')
            d["dead"] = True

    def put(paths, side, wa, wb, uv, sides=6, root=True):
        fs = []
        for pth in paths:
            pts = [Vector(p) for p in pth]
            if root: pts = rooted(pts)
            fs += sweep(bm, pts, side, wa, wb, sides=sides)
        bmesh.ops.recalc_face_normals(bm, faces=fs)
        for f in fs:
            for v in f.verts:
                if v.co.z < bmn.z + 0.05: v.co.z = bmn.z + 0.05
            for l in f.loops: l[uvl].uv = uv
        return fs

    if os.environ.get("EGG_NO_GENERIC") != "1" and name not in NO_GENERIC:
        bird, fish = name in BIRDS, name in FISH
        # --- mane (pigeon: "for the wolf change the mane a little"): the old manes are a star of big
        #     flat slabs; the new one is a ruff of chunky pointed tufts, swept back
        if name in MANES:
            old = [d for d in ds if free(d) and mid(d) and d["n"] <= 12 and max(d["s"]) >= 4.4 and abs(d["c"].x) < 0.7 and abs(d["c"].z) < 0.9]
            if len(old) >= 3:
                uv = tally_main(old)
                cx, cz = old[0]["c"].x, old[0]["c"].z
                R = 0.5 * max(max(d["s"].y, d["s"].z) for d in old) + 0.2
                deep = max(d["s"].x for d in old) >= 4.0
                kill(old); take(*old)
                paths = []
                for rx, cnt, ph, rr, back in [(cx + 0.3, 10, 0.0, R, 0.5)] + ([(cx + 1.3, 8, 0.5, R - 0.2, 1.2)] if deep else []):
                    for i in range(cnt):
                        a = 2 * math.pi * (i + ph + 0.5) / cnt
                        dy, dz = math.cos(a), math.sin(a)
                        if cz + dz * rr < -SHELL.z / 2 + 0.25: continue          # would poke out under the egg
                        paths.append([E(rx, dy * rr * 0.4, cz + dz * rr * 0.4), E(rx + back * 0.4, dy * rr * 0.78, cz + dz * rr * 0.78),
                                      E(rx + back, dy * rr, cz + dz * rr)])
                put(paths, (1, 0, 0), taper(0.8 * SC, 0.1 * SC), taper(0.8 * SC, 0.1 * SC), uv, sides=5, root=False)
                notes.append(f"mane:tufts x{len(paths)}")
        # --- beak: straight beaks become hooked, hooked ones long and pointed
        if bird:
            bk = [d for d in ds if free(d) and mid(d) and d["c"].x < -1.6 and d["n"] <= 70 and d["s"].x >= 0.9 and d["s"].z <= 2.0 and d["c"].z > -0.65]
            if bk and (-2.0 - min(d["mn"].x for d in bk)) >= 1.6 and (max(d["mx"].z for d in bk) - min(d["mn"].z for d in bk)) / (-2.0 - min(d["mn"].x for d in bk)) <= 0.8:
                mnx = min(d["mn"].x for d in bk); mxz = max(d["mx"].z for d in bk); mnz = min(d["mn"].z for d in bk)
                uv = tally_main([max(bk, key=lambda d: d["s"].x * d["s"].y * d["s"].z)])
                out_, hz = -2.0 - mnx, mxz - mnz
                L = max(1.3, min(3.6, out_ * 1.15))
                w = max(0.7, min(1.3, max(d["s"].y for d in bk))); h = max(0.7, min(1.2, hz))
                z0 = mxz - 0.5 * h
                if hz / max(0.1, out_) > 0.8:
                    pth, st_ = [(-1.7, 0, z0), (-1.7 - 0.5 * L, 0, z0 + 0.02 * L), (-1.7 - L, 0, z0 + 0.12 * L)], "long"
                else:
                    pth, st_ = [(-1.7, 0, z0), (-1.7 - 0.5 * L, 0, z0 + 0.06 * L), (-1.7 - 0.85 * L, 0, z0 - 0.1 * L), (-1.7 - L, 0, z0 - 0.42 * L)], "hook"
                kill(bk); take(*bk)
                put([[E(*p) for p in pth]], (0, 1, 0), taper(0.5 * w * SC, 0.07 * SC), taper(0.5 * h * SC, 0.07 * SC), uv)
                notes.append("beak:" + st_)
        # --- wings (birds: raised and swept back) / side fins (fish: flat, sticking out, swept back)
        if bird or fish:
            cand = [d for d in ds if free(d) and d["pair"] and d["c"].y >= 1.7 and d["n"] <= 50 and abs(d["c"].x) < 1.3
                    and (d["c"].z < -0.3 if fish else -1.5 < d["c"].z < 0.4) and max(d["s"]) >= 1.4 and (fish or d["s"].y <= 1.3)]
            if cand:
                d = max(cand, key=lambda d: d["s"].x * max(d["s"].y, d["s"].z))
                uv = tally_main(both(d)); k = max(0.85, min(1.25 if fish else 1.0, max(d["s"]) / 2.6))
                kill(both(d)); take(d)
                for sgn in (1, -1):
                    if fish:
                        pth = [(-0.3, 1.7, -1.3), (0.1, 1.7 + 0.8 * k, -1.4), (0.7, 1.7 + 1.5 * k, -1.45), (1.3, 1.7 + 1.9 * k, -1.45)]
                        put([[E(x, sgn * y, z) for x, y, z in pth]], (1, 0, 0), (lambda u: leaf(0.85, 0.3)(u) * k * SC), flat(0.27 * SC), uv)
                    else:
                        pth = [(-0.6, 1.9, -0.6), (-0.6 + 0.9 * k, 2.25, -0.2), (-0.6 + 1.8 * k, 2.45, 0.4 * k), (-0.6 + 2.5 * k, 2.5, 1.1 * k)]
                        put([[E(x, sgn * y, z) for x, y, z in pth]], (0, 0, 1), (lambda u: leaf(0.62, 0.3)(u) * k * SC), flat(0.24 * SC), uv)
                notes.append("fins:side" if fish else "wings:up")
        # --- back fin (fish): taller and swept back
        if fish:
            cand = [d for d in ds if free(d) and mid(d) and d["c"].z > 1.2 and -1.0 < d["c"].x < 2.2 and d["s"].y <= 1.0 and d["n"] <= 60 and max(d["s"]) >= 1.5]
            if cand:
                d = max(cand, key=lambda d: d["s"].z)
                uv = tally_main([d]); k = max(0.85, min(1.2, d["s"].z / 2.2)); x0 = d["c"].x - 0.6
                kill([d]); take(d)
                pth = [(x0, 0, 2.2), (x0 + 0.5 * k, 0, 2.2 + 0.8 * k), (x0 + 1.1 * k, 0, 2.2 + 1.5 * k)]
                put([[E(*p) for p in pth]], (1, 0, -0.6), (lambda u: taper(1.35, 0.22, 1.0)(u) * k * SC), flat(0.26 * SC), uv)
                notes.append("fin:back")
        # --- tail
        tail_done = any(k_ == "tail" for k_, _, _ in plan)
        if not tail_done and name not in NO_TAIL:
            rear = [d for d in ds if free(d) and d["c"].x > 1.8 and d["c"].z < 0.5 and d["n"] <= 85 and abs(d["c"].y) < 1.8 and d["mx"].x > 2.8]
            singles = [d for d in rear if mid(d) and d["s"].y >= 0.3]
            if singles:
                d = max(singles, key=lambda d: max(d["s"]))
                s = d["s"]; st_ = None
                if fish: st_ = "fluke" if s.y >= 3.0 else ("fin" if s.z >= 2.2 and s.y <= 1.6 else None)
                elif bird: st_ = "fan"
                elif d["n"] <= 60 and s.x >= 2.2 and s.y <= 1.6 and s.z <= 2.9: st_ = "whip"
                if st_:
                    z0 = d["c"].z
                    olds_ = rear if bird else [d]
                    if st_ == "whip":           # spikes that sat on the old tail go with it
                        olds_ = olds_ + [e for e in ds if free(e) and e is not d and mid(e) and e["c"].x > 2.4 and e["n"] <= 30]
                    uv = tally_main([d])
                    seen_ = set(); kl = []
                    for e in olds_:
                        for q in both(e):
                            if id(q) not in seen_: seen_.add(id(q)); kl.append(q)
                    kill(kl); take(*kl)
                    if st_ == "whip":
                        k = max(0.85, min(1.25, s.x / 3.6)); r0 = max(0.4, min(0.62, 0.5 * max(s.y, 0.8)))
                        pth = [(1.5 + k * a, 0, -1.2 + k * (b + 1.2)) for a, b in [(0, -1.2), (1.4, -1.55), (2.7, -1.2), (3.5, -0.2), (3.4, 0.9), (2.7, 1.5)]]
                        put([[E(*p) for p in pth]], (0, 1, 0), taper(r0 * SC, 0.1 * SC), taper(r0 * SC, 0.1 * SC), uv)
                    elif st_ == "fin":
                        k = max(0.8, min(1.3, s.z / 4.0))
                        lobes = [[(0, 0), (1.0, 0.5), (1.9, 1.5), (2.3, 2.1)], [(0, 0), (1.0, -0.5), (1.9, -1.4), (2.3, -1.9)]]
                        put([[E(1.5 + k * a, 0, z0 + k * b) for a, b in lb] for lb in lobes], (0, 0, 1), (lambda u: leaf(1.0, 0.3)(u) * k * SC), flat(0.3 * SC), uv)
                    elif st_ == "fluke":
                        k = max(0.8, min(1.25, s.y / 5.0))
                        put([[E(1.5, 0, z0), E(1.5 + 1.3 * k, 0, z0), E(1.5 + 2.3 * k, sg * 0.9 * k, z0 + 0.1), E(1.5 + 3.0 * k, sg * 2.3 * k, z0 + 0.2)] for sg in (1, -1)],
                            (0, 1, 0), (lambda u: leaf(0.8, 0.2)(u) * k * SC), flat(0.24 * SC), uv)
                    else:
                        k = max(0.7, min(1.0, max(s) / 3.0))
                        fe = [[(0, 0, 0), (1.2, 0, 0.4), (2.2, 0, 1.3), (2.8, 0, 2.3)], [(0, 0.3, 0), (1.1, 0.9, 0.3), (1.9, 1.6, 1.0), (2.4, 2.1, 1.9)], [(0, -0.3, 0), (1.1, -0.9, 0.3), (1.9, -1.6, 1.0), (2.4, -2.1, 1.9)]]
                        put([[E(1.4 + k * a, k * b, -1.0 + k * g) for a, b, g in f_] for f_ in fe], (0, 1, 0), (lambda u: leaf(0.55, 0.3)(u) * k * SC), flat(0.2 * SC), uv)
                    notes.append("tail:" + st_)
                    tail_done = True
        # --- rows of back plates / mane spikes: flat triangles become round pointed spikes, taller
        row = [d for d in ds if free(d) and mid(d) and abs(d["c"].y) < 0.1 and d["n"] <= 20 and 0.6 <= max(d["s"]) <= 1.7
               and d["c"].x > -1.0 and d["c"].z > -1.6 and d["s"].y <= 1.1]
        if len(row) >= 3 and name not in ANIMALS:          # (the hyena's mane spikes turned into horns: table animals keep theirs)
            made = 0
            for d in row:
                p = c + SC * d["c"]
                loc, nrm, _, dist = shell.find_nearest(p)
                if loc is None or dist > 0.9 * SC: continue              # sits on something else (a tail): leave it
                uv = tally_main([d])
                hh = max(0.8, min(1.5, 1.1 * max(d["s"]))) * SC; r0 = max(0.3, min(0.55, 0.42 * max(d["s"].x, d["s"].z))) * SC
                dr = (nrm + Vector((0.45, 0, 0))).normalized()
                kill([d]); take(d)
                put([[loc - nrm * 0.35 * SC, loc + dr * hh * 0.5, loc + dr * hh + Vector((0.12 * hh, 0, 0))]], (0, 1, 0), taper(r0, 0.04 * SC), taper(r0, 0.04 * SC), uv, sides=5, root=False)
                made += 1
            if made: notes.append(f"spikes:x{made}")

    # A FACE for eggs that have none (pigeon: "maybe the pony you can add a face but it's gotta follow
    # the face of all the other ones"): the same build as the cow's / dog's faces - square eye frames
    # with a darker pupil block set in front, a snout block, two nostrils. Colours are the lightest and
    # darkest flat areas of the egg's own texture (true white only if the texture has it).
    if want.get("face"):
        front = [d for d in ds if d["c"].x < -1.5 and abs(d["c"].y) < 1.4 and -1.8 < d["c"].z < 1.8]
        if front:
            notes.append("face:kept (already has one)")
        else:
            # flat areas of the texture (a texel whose neighbours match), so filtering can't bleed
            lum = px[:, :, :3].mean(axis=2)
            sat = px[:, :, :3].max(axis=2) - px[:, :, :3].min(axis=2)
            flatness = np.zeros_like(lum)
            for dy in (-2, 0, 2):
                for dx_ in (-2, 0, 2):
                    flatness = np.maximum(flatness, np.abs(np.roll(np.roll(px[:, :, :3], dy, 0), dx_, 1) - px[:, :, :3]).max(axis=2))
            ok = (flatness < 0.03) & (px[:, :, 3] > 0.5)
            if not ok.any(): ok = np.ones_like(lum, dtype=bool)

            def pick(score):
                s = np.where(ok, score, -9.0)
                y, x = np.unravel_index(np.argmax(s), s.shape)
                return Vector(((x + 0.5) / W, (y + 0.5) / H))
            uv_light, uv_dark = pick(lum - sat), pick(-lum)
            med = float(np.median(lum[ok]))
            uv_snout = pick(-np.abs(lum - (med + 0.6 * (float(lum[ok].max()) - med))))

            # The other eggs' eyes are white frames with black pupils. If this egg's texture has no
            # white / black (the pony's is all browns), the eyes can't be part of the mesh: they are
            # written out as small blocks that Studio adds as welded parts (eggs already carry welded
            # parts for their effects), white + black on base eggs.
            real_eyes = float((lum - sat)[ok].max()) > 0.8 and float(lum[ok].min()) < 0.12
            # ...but the game moves and RESIZES eggs by code (EggKeeper: CFrame + Size), and welded parts
            # don't scale with the egg. So eyes are always part of the mesh, in the lightest / darkest
            # colours the egg's own texture has. EGG_WELD_EYES=1 brings the welded version back.
            if os.environ.get("EGG_WELD_EYES") != "1": real_eyes = True
            face_parts = []

            def block(cy, cz, sx_, sy_, sz_, uv, sink, ahead=None, part=None):
                """A box on the egg's front at (cy, cz), `sink` of its depth inside the shell (or just in front of `ahead`)."""
                hit = shell.ray_cast(c + Vector((-6 * SC, cy * SC, cz * SC)), Vector((1, 0, 0)))[0]
                if hit is None: return None
                cx_ = (ahead - sx_ * SC / 2 + 0.04 * SC) if ahead is not None else hit.x + sx_ * SC * (sink - 0.5)
                if part:
                    face_parts.append([cx_, c.y + cy * SC, c.z + cz * SC, sx_ * SC, sy_ * SC, sz_ * SC, part])
                    return cx_ - sx_ * SC / 2
                res = bmesh.ops.create_cube(bm, size=1.0, matrix=Matrix.Translation(Vector((cx_, c.y + cy * SC, c.z + cz * SC)))
                                            @ Matrix.Diagonal(Vector((sx_ * SC, sy_ * SC, sz_ * SC, 1))))
                fs = list({f for v in res["verts"] for f in v.link_faces})
                bmesh.ops.recalc_face_normals(bm, faces=fs)
                for f in fs:
                    for l in f.loops: l[uvl].uv = uv
                return cx_ - sx_ * SC / 2                 # x of its front face

            for sgn in (1, -1):
                fx = block(sgn * 0.62, 0.72, 0.24, 0.72, 0.92, uv_light, 0.35, part=None if real_eyes else "white")
                if fx is not None: block(sgn * 0.6, 0.66, 0.16, 0.46, 0.6, uv_dark, 0, ahead=fx, part=None if real_eyes else "black")
            sx = block(0, -0.62, 1.0, 1.7, 1.15, uv_snout, 0.3)
            if sx is not None:
                for sgn in (1, -1): block(sgn * 0.42, -0.42, 0.14, 0.32, 0.46, uv_dark, 0, ahead=sx)
            ob["face_parts"] = json.dumps(face_parts)
            notes.append("face:added" + ("" if real_eyes else " (eyes as welded parts)"))
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
        fp = [[round(p[0] - ctr.x, 4), round(p[2] - ctr.z, 4), round(-(p[1] - ctr.y), 4), round(p[3], 4), round(p[5], 4), round(p[4], 4), p[6]]
              for p in json.loads(ob.get("face_parts", "[]"))]
        payload[src.name] = dict(verts=verts, uvs=uvs, tris=tris, offset=[round(off.x, 4), round(off.z, 4), round(-off.y, 4)], face=fp)
    # (no combined file: with every egg in it, it is far too big to load in Studio at once)
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
