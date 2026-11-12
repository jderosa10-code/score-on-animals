"""Weight tiers v8 for Score on Animals: chunky STEPPED style, fine rounded steps, big heads on a
short thick bar, every tier in its own colours and bigger than the last (see K_TIER below).

History of pigeon's notes that shaped this:
  - a reference weight from another game = "a great model": huge heads, thick handle, stepped
    blocks, light/dark steps of ONE colour family, white 4-point sparkles
  - v5 (0.2-stud steps) was "too pixely"  -> steps are 0.125 studs now
  - "handles have stuff in the way of where you would hold it" -> NOTHING sticks out of the bar
    between the collars; the grip zone is 0.5..2.2 studs each side (a Roblox character's hands)
  - "bottom ones can be lame but then cooler quicker" -> 3 plain food tiers, then every tier is a
    showpiece: Golden Egg, Diamond, Trophy, Rocket (hovering on its flame), Golden Soccer Ball,
    Planets (moons + rocket orbit), Black Hole (glowing disc, stars orbit)
  - VFX "sucks" on rocket / soccer ball -> the flame is MODELLED (neon steps); particles are only
    sparkles + small wisps, added in Studio
Every tier is a function "which material is at this point", sampled on the grid. One mesh per
material per tier, named  Weight<N>_<Tier>_<Group>__<Material>  (Material may end in Hi / Lo).
Bar along X, Z up, ground at z = 0, bar centre above each tier's own origin. 1 unit = 1 stud.

blender -b --factory-startup -P weights_vox.py -- <out.blend> <out.fbx> <render.png>
"""
import bpy, bmesh, sys, math
from mathutils import Vector, Matrix

argv = sys.argv[sys.argv.index("--") + 1:]
blend_out, fbx_out, png_out = argv
bpy.ops.wm.read_factory_settings(use_empty=True)

C = 0.125          # step size in studs, in the finished model
SMOOTH, SMOOTH_ITERS = 0.5, 3     # how much the steps are rounded off (0 = hard blocks)
GAP = 12.0         # spacing between tiers in the file (along -Y)
# v8 (pigeon: "they all missing something, you need to find out"). Side by side with the reference
# weight, ours were thin sticks with small ends and the same grey bar on every tier. So:
#   * every tier is designed at the old size and then built K times bigger, K growing with the tier
#   * the grip zone stays 2 studs each side in the finished model, so the bar is short and thick
#   * the bar, grips and collars take the tier's own colours; from tier 5 a glowing collar ring
K_TIER = [1.1, 1.25, 1.35, 1.45, 1.5, 1.5, 1.35, 1.55, 1.5, 1.6]     # v9: tier 1 is clearly the baby
# v9 "shaders" (pigeon: "add good like shaders to it"). Roblox can't run custom shaders, so the
# shading is BAKED into the mesh as vertex colours, which Roblox multiplies with the part's colour:
#   * darker in creases and where the weight meets the ground (ambient occlusion)
#   * lighter on top, darker underneath (soft sky light), shadows leaning warm
# Vertex colours can only darken. A baked highlight would need every part colour lifted first
# (LIFT < 1), and that was tried: any colour with a channel near full (gold, pink, white) clips and
# shifts hue, gold went olive. So LIFT stays 1 and the shine is left to Roblox's own lighting.
LIFT = 1.0
HS_WORLD = 2.0
HS = 2.6           # heads never come closer to the middle than this, in design units (set per tier)

BASE = {
    "Bar": "#8C8F99", "Grip": "#2E2E36", "Wood": "#B5793C",
    "Marshmallow": "#FFF4EA", "MarshPink": "#FFB7D5", "Toast": "#C98A3E",
    "Dough": "#E3A35A", "Icing": "#FF7EB6", "Choc": "#6B3A1E",
    "SprinkleY": "#FFE14D", "SprinkleB": "#4DB8FF", "SprinkleG": "#6BE36B", "SprinkleW": "#FFFFFF",
    "Rind": "#2E9B35", "RindIn": "#E4F7C8", "Flesh": "#FF4D5E", "Seed": "#1A1A1A",
    "Gold": "#F7C440", "Pearl": "#FFF6E0", "GemRed": "#E8262B", "GemBlue": "#2F7BFF",
    "Diamond": "#6FE3FF", "Chrome": "#D7DCE6",
    "TrophyBase": "#2A2A30",
    "RocketBody": "#F2F2F2", "RocketRed": "#E8262B", "RocketWindow": "#4DB8FF", "Nozzle": "#5A5F6B",
    "Flame": "#FF8A1A", "FlameCore": "#FFE14D",
    "BallBlack": "#1E1E24",
    "SpaceBar": "#2B2F6B", "GasA": "#7B4DFF", "GasC": "#FF7EC8", "RingA": "#FFD27E", "RingB": "#FF9BD6",
    "MoonIce": "#8DF4FF", "MoonLava": "#FF8A3D", "Ocean": "#2F7BFF", "Land": "#3FCF5A", "Ice": "#F4FBFF",
    "Moon": "#C9CCD6",
    "Void": "#0B0B14", "VoidGrip": "#7B4DFF", "Disc": "#FF8A2A", "DiscHot": "#FFE9A8", "DiscOut": "#C24DFF",
    "Star": "#FFF3B0", "GlowCyan": "#7DF3FF", "GlowGold": "#FFD866",
}
GLOW = ("RingA", "RingB", "RocketWindow", "MoonLava", "Flame", "FlameCore", "Disc", "DiscHot", "DiscOut", "Star", "Glow")
SEE_THROUGH = ("Diamond",)      # Glass in Studio: neighbours still need their faces


def hex_rgb(h):
    h = h.lstrip("#")
    return [int(h[i:i + 2], 16) / 255 for i in (0, 2, 4)]


def shade(name):
    """sRGB colour of a material name, with Hi (lighter) / Lo (darker) variants. Same maths in Studio."""
    base, mode = name, None
    if name not in BASE and name[-2:] in ("Hi", "Lo"):
        base, mode = name[:-2], name[-2:]
    c = hex_rgb(BASE[base])
    if mode == "Hi": c = [x + (1 - x) * 0.28 for x in c]
    if mode == "Lo": c = [x * 0.74 for x in c]
    return c


def material(name):
    m = bpy.data.materials.get(name)
    if m: return m
    m = bpy.data.materials.new(name); m.use_nodes = True
    lin = lambda x: ((x + 0.055) / 1.055) ** 2.4 if x > 0.04045 else x / 12.92
    c = [lin(x) for x in shade(name)]
    nt = m.node_tree
    bs = nt.nodes["Principled BSDF"]
    bs.inputs["Base Color"].default_value = (*c, 1)
    bs.inputs["Roughness"].default_value = 0.35
    if name.startswith(GLOW):
        bs.inputs["Emission Color"].default_value = (*c, 1); bs.inputs["Emission Strength"].default_value = 1.2
    elif not name.startswith(SEE_THROUGH) and name != "Dummy":
        # preview only: show the baked shading the way Studio will (lifted colour x vertex colour)
        vc = nt.nodes.new("ShaderNodeVertexColor"); vc.layer_name = "Col"
        mul = nt.nodes.new("ShaderNodeVectorMath"); mul.operation = 'MULTIPLY'
        mul.inputs[1].default_value = [lin(min(1.0, x / LIFT)) for x in shade(name)]
        nt.links.new(vc.outputs["Color"], mul.inputs[0])
        nt.links.new(mul.outputs[0], bs.inputs["Base Color"])
    return m


# ---------------------------------------------------------------- grid -> mesh
DIRS = [((1, 0, 0), [(1, 0, 0), (1, 1, 0), (1, 1, 1), (1, 0, 1)]), ((-1, 0, 0), [(0, 0, 0), (0, 0, 1), (0, 1, 1), (0, 1, 0)]),
        ((0, 1, 0), [(0, 1, 0), (0, 1, 1), (1, 1, 1), (1, 1, 0)]), ((0, -1, 0), [(0, 0, 0), (1, 0, 0), (1, 0, 1), (0, 0, 1)]),
        ((0, 0, 1), [(0, 0, 1), (1, 0, 1), (1, 1, 1), (0, 1, 1)]), ((0, 0, -1), [(0, 0, 0), (0, 1, 0), (1, 1, 0), (1, 0, 0)])]


def build(prefix, fn, bounds, coll, offset=(0, 0, 0), scale=1.0, iters=SMOOTH_ITERS):
    """Sample fn(x, y, z, i, j, k) -> None | (group, material) on the grid and make one mesh per
    (group, material) with only the outside faces. fn and bounds are in design units; the mesh
    comes out `scale` times bigger with steps of C studs."""
    cell = C / scale
    (x0, x1), (y0, y1), (z0, z1) = bounds
    i0, i1 = round(x0 / cell), round(x1 / cell)
    j0, j1 = round(y0 / cell), round(y1 / cell)
    k0, k1 = round(z0 / cell), round(z1 / cell)
    grid = {}
    for i in range(i0, i1):
        x = (i + 0.5) * cell
        for j in range(j0, j1):
            y = (j + 0.5) * cell
            for k in range(k0, k1):
                v = fn(x, y, (k + 0.5) * cell, i, j, k)
                if v: grid[(i, j, k)] = v
    # outside faces, as quads of lattice corners
    quads = {}
    for (i, j, k), key in grid.items():
        clear = key[1].startswith(SEE_THROUGH)
        for (dx, dy, dz), quad in DIRS:
            nb = grid.get((i + dx, j + dy, k + dz))
            if nb is None or (nb[1].startswith(SEE_THROUGH) and not clear):
                quads.setdefault(key, []).append([(i + a, j + b, k + c) for a, b, c in quad])
    # SOFTEN THE STEPS (pigeon: "a little less pixely/blocky"): slide every surface corner part-way
    # toward the average of its neighbours. Done on the shared lattice, so the separate colour
    # meshes still meet exactly. Corners on the ground stay on the ground.
    pos, nbr = {}, {}
    for qs in quads.values():
        for q in qs:
            for a in range(4):
                v, w = q[a], q[(a + 1) % 4]
                pos[v] = Vector(v) * C
                nbr.setdefault(v, set()).add(w); nbr.setdefault(w, set()).add(v)
    for _ in range(iters):
        new = {}
        for v, p in pos.items():
            avg = sum((pos[w] for w in nbr[v]), Vector()) / len(nbr[v])
            p2 = p.lerp(avg, SMOOTH)
            if v[2] == k0: p2.z = p.z
            new[v] = p2
        pos = new
    # BAKED SHADING, one brightness per surface corner (see LIFT at the top).
    # Normals come from the whole surface, not per colour mesh, so the shading runs straight across
    # colour boundaries.
    nrm = {v: Vector() for v in pos}
    for qs in quads.values():
        for q in qs:
            fn_ = (pos[q[1]] - pos[q[0]]).cross(pos[q[3]] - pos[q[0]])
            for v in q: nrm[v] += fn_
    ztop = max((p.z for p in pos.values()), default=1.0) or 1.0
    ground = (k0 == 0)
    boxed = {}
    for v in pos:
        i, j, k = v
        solid = 0
        for a in (-2, -1, 0, 1):                       # how boxed-in this corner is: 4x4x4 cells round it
            for b in (-2, -1, 0, 1):
                for c in (-2, -1, 0, 1):
                    if (i + a, j + b, k + c) in grid or (ground and k + c < k0): solid += 1
        boxed[v] = solid / 64.0
    # First try shaded straight from this and every stair-step showed as a dotted grain (a step's
    # outer corner reads "open", its inner corner "boxed-in"). Blurring along the surface cancels
    # the steps and leaves only real creases.
    for _ in range(5):
        boxed = {v: 0.3 * f + 0.7 * sum(boxed[w] for w in nbr[v]) / len(nbr[v]) for v, f in boxed.items()}
    shade_at = {}
    for v, p in pos.items():
        ao = max(0.6, 1 - max(0.0, boxed[v] - 0.52) * 1.6)
        n = nrm[v].normalized() if nrm[v].length > 1e-9 else Vector((0, 0, 1))
        sky = (0.9 + 0.1 * (0.5 + 0.5 * n.z)) * (0.96 + 0.04 * min(1.0, max(0.0, p.z / ztop)))
        shade_at[v] = max(0.0, min(1.0, ao * sky))
    objs = []
    for (group, mat), qs in sorted(quads.items()):
        lit = not mat.startswith(GLOW) and not mat.startswith(SEE_THROUGH)      # glow and glass stay pure
        bm = bmesh.new()
        shl = bm.verts.layers.float.new("shade")        # all layers are made BEFORE any geometry
        uv = bm.loops.layers.uv.new("UVMap")
        col = bm.loops.layers.color.new("Col")
        vmap = {}
        for q in qs:
            fv = []
            for v in q:
                bv = vmap.get(v)
                if bv is None:
                    bv = vmap[v] = bm.verts.new(pos[v])
                    bv[shl] = shade_at[v] if lit else 1.0
                fv.append(bv)
            try: bm.faces.new(fv)
            except ValueError: pass
        bmesh.ops.dissolve_limit(bm, angle_limit=math.radians(2.5), verts=bm.verts[:], edges=bm.edges[:])
        bm.normal_update()
        # box-mapped UVs, one tile = 3 studs (same as the animals' Studs textures), so studs show
        for f in bm.faces:
            nx, ny, nz = abs(f.normal.x), abs(f.normal.y), abs(f.normal.z)
            for l in f.loops:
                co = l.vert.co
                l[uv].uv = ((co.y, co.z) if nx >= ny and nx >= nz else ((co.x, co.z) if ny >= nz else (co.x, co.y)))
                l[uv].uv = (l[uv].uv[0] / 3.0, l[uv].uv[1] / 3.0)
                s = l.vert[shl]
                l[col] = (s ** 0.85, s, s ** 1.15, 1.0)             # shadows lean warm, not grey
        bmesh.ops.translate(bm, vec=Vector(offset), verts=bm.verts[:])
        me = bpy.data.meshes.new(f"{prefix}{group}__{mat}")
        bm.to_mesh(me); bm.free()
        for p in me.polygons: p.use_smooth = True            # soft shading, hard edges only at real corners
        me.set_sharp_from_angle(angle=math.radians(40))
        me.materials.append(material(mat))
        o = bpy.data.objects.new(f"{prefix}{group}__{mat}", me)
        coll.objects.link(o)
        objs.append(o)
    return objs


def hsh(i, j, k):
    return ((i * 73856093) ^ (j * 19349663) ^ (k * 83492791)) & 0xFFFF


# ---------------------------------------------------------------- shared handle
def handle(ax, y, z, h, end, metal="Bar", grip="Grip", collars=True, glow=None):
    """Thick bar. Between the collars nothing is wider than the bar itself, so hands fit:
    centre band, ribbed grip, stepped collar (its first ring can glow), then the head, then an end cap."""
    dz = z - h
    r = math.hypot(y, dz)
    if r >= 0.72: return None
    a, b = 0.16 * HS, 0.8 * HS
    if ax < a:
        return ("Vox", metal + "Hi") if r < 0.34 else None
    if ax < b:
        if r < 0.34: return ("Vox", grip if int((ax - a) / ((b - a) / 6) + 0.001) % 2 else grip + "Hi")
        return None
    if collars and ax < HS:
        if ax < b + 0.45 * (HS - b): return ("Vox", glow or metal + "Hi") if r < 0.5 else None
        return ("Vox", metal + "Lo") if r < 0.7 else None
    if end <= ax < end + 0.25 and r < 0.6: return ("Vox", metal + "Hi")
    if end + 0.25 <= ax < end + 0.5 and r < 0.45: return ("Vox", metal + "Lo")
    if ax < end + 0.25 and r < 0.3: return ("Vox", metal)
    return None


ICO = []
_t = (1 + 5 ** 0.5) / 2
for a, b in ((1, _t), (-1, _t), (1, -_t), (-1, -_t)):
    for v in ((0, a, b), (a, b, 0), (b, 0, a)):
        ICO.append(Vector(v).normalized())
HEXC = []                                   # the 20 face centres of the icosahedron = hexagon centres of a football
for a in range(12):
    for b in range(a + 1, 12):
        for c in range(b + 1, 12):
            if ICO[a].dot(ICO[b]) > 0.4 and ICO[b].dot(ICO[c]) > 0.4 and ICO[a].dot(ICO[c]) > 0.4:
                HEXC.append((ICO[a] + ICO[b] + ICO[c]).normalized())


