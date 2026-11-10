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
K_TIER = [1.3, 1.4, 1.4, 1.45, 1.5, 1.5, 1.35, 1.55, 1.5, 1.6]
HS_WORLD = 2.0
HS = 2.6           # heads never come closer to the middle than this, in design units (set per tier)

BASE = {
    "Bar": "#8C8F99", "Grip": "#2E2E36", "Wood": "#B5793C",
    "Marshmallow": "#FFF4EA", "MarshPink": "#FFB7D5", "Toast": "#C98A3E",
    "Dough": "#E3A35A", "Icing": "#FF7EB6",
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
    c = [((x + 0.055) / 1.055) ** 2.4 if x > 0.04045 else x / 12.92 for x in shade(name)]
    bs = m.node_tree.nodes["Principled BSDF"]
    bs.inputs["Base Color"].default_value = (*c, 1)
    bs.inputs["Roughness"].default_value = 0.35
    if name.startswith(GLOW):
        bs.inputs["Emission Color"].default_value = (*c, 1); bs.inputs["Emission Strength"].default_value = 1.2
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
    objs = []
    for (group, mat), qs in sorted(quads.items()):
        bm = bmesh.new()
        vmap = {}
        for q in qs:
            fv = []
            for v in q:
                bv = vmap.get(v)
                if bv is None: bv = vmap[v] = bm.verts.new(pos[v])
                fv.append(bv)
            try: bm.faces.new(fv)
            except ValueError: pass
        bmesh.ops.dissolve_limit(bm, angle_limit=math.radians(2.5), verts=bm.verts[:], edges=bm.edges[:])
        bm.normal_update()
        # box-mapped UVs, one tile = 3 studs (same as the animals' Studs textures), so studs show
        uv = bm.loops.layers.uv.new("UVMap")
        for f in bm.faces:
            nx, ny, nz = abs(f.normal.x), abs(f.normal.y), abs(f.normal.z)
            for l in f.loops:
                co = l.vert.co
                l[uv].uv = ((co.y, co.z) if nx >= ny and nx >= nz else ((co.x, co.z) if ny >= nz else (co.x, co.y)))
                l[uv].uv = (l[uv].uv[0] / 3.0, l[uv].uv[1] / 3.0)
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


# ---------------------------------------------------------------- the 10 tiers
def t_marshmallow(x, y, z, i, j, k):
    h, hx, R = 1.2, HS + 1.25, 1.15
    ax = abs(x); u = ax - hx; dz = z - h; r = math.hypot(y, dz)
    if -1.25 <= u < 1.25:
        outer = u >= 0
        t = u if outer else u + 1.25
        edge = min(t, 1.25 - t)
        rad = R - (0.4 if edge < 0.125 else (0.15 if edge < 0.25 else 0.0))       # puffy rounded ends
        if r < rad:
            if outer and t >= 1.125:
                return ("Vox", "ToastLo" if r < 0.45 else "Toast")
            m = "MarshPink" if outer else "Marshmallow"
            if dz > 0.55: m += "Hi"
            elif dz < -0.75: m += "Lo"
            return ("Vox", m)
    return handle(ax, y, z, h, hx + 1.25, metal="Wood", grip="Toast", collars=False)


def t_donut(x, y, z, i, j, k):
    h, hx, Rt, a = 1.4, HS + 1.0, 0.9, 0.48
    ax = abs(x); u = ax - hx; dz = z - h; r = math.hypot(y, dz)
    if abs(u) < 1.0:
        for uc in (-0.5, 0.5):
            du = u - uc
            d = math.hypot(r - Rt, du)
            if d < a:
                if du > 0 and d > 0.24:
                    if d > 0.36 and hsh(i // 2, j // 2, k // 2) % 5 == 0:
                        return ("Vox", ("SprinkleY", "SprinkleB", "SprinkleG", "SprinkleW")[hsh(j // 2, k // 2, i // 2) % 4])
                    return ("Vox", "IcingHi" if dz > 0.7 else "Icing")
                return ("Vox", "DoughHi" if dz > 0.7 else ("DoughLo" if dz < -0.8 else "Dough"))
    return handle(ax, y, z, h, hx + 1.0, metal="Dough", grip="Icing")


def t_watermelon(x, y, z, i, j, k):
    h, hx, R, face = 1.4, HS + 1.0, 1.375, 0.4
    ax = abs(x); u = ax - hx; dz = z - h; r = math.hypot(y, dz)
    rho = math.hypot(u - face, r)
    if u < face and rho < R:
        if rho > R - 0.22:
            sector = int((math.atan2(dz, y) + math.pi) / (2 * math.pi) * 12) % 2
            return ("Vox", "RindLo" if sector else "Rind")
        if rho > R - 0.4: return ("Vox", "RindIn")
        if u > face - 0.125:
            for n in range(7):
                a = math.radians(n * 360 / 7 + 15)
                if math.hypot(y - 0.62 * math.cos(a), dz - 0.62 * math.sin(a)) < 0.11: return ("Vox", "Seed")
        return ("Vox", "FleshHi" if r < 0.35 else "Flesh")
    return handle(ax, y, z, h, hx + face, metal="Rind", grip="Flesh")


def t_egg(x, y, z, i, j, k):
    h, hx, H, W = 1.4, HS + 1.4, 3.0, 1.2
    ax = abs(x); u = ax - hx
    q = math.hypot(u, y)
    t = z / H
    if q < 1.7 and 0 < t < 1:
        w = W * 2 * math.sqrt(t * (1 - t)) * (1.1 - 0.3 * t)
        upper = 2.0 <= z < 2.25
        if upper:
            ang = math.atan2(y, u); n = round(ang / (math.pi / 4))
            if w - 0.1 < q < w + 0.38 and abs(ang - n * math.pi / 4) < 0.17 and 2.0 <= z < 2.25:
                return ("Vox", "GemRed" if n % 2 else "GemBlue")
        if (upper or 0.75 <= z < 1.0) and q < w + 0.14: return ("Vox", "Pearl")
        if q < w:
            return ("Vox", "GoldHi" if z >= 2.25 else ("GoldLo" if z < 0.75 else "Gold"))
    if H <= z < H + 0.25 and q < 0.25: return ("Vox", "Pearl")
    return handle(ax, y, z, h, hx + 1.2, metal="Gold", grip="Pearl")


def t_diamond(x, y, z, i, j, k):
    h, hx = 1.8, HS + 1.6
    ax = abs(x); u = ax - hx
    au, ay = abs(u), abs(y)
    if au < 1.6 and 0 < z < 2.625:
        octr = max(au, ay, (au + ay) * 0.7071)
        rad = (z / 1.8 * 1.5) if z < 1.8 else (1.5 - (z - 1.8) / 0.825 * 0.6)
        if octr < rad:
            diag = (au + ay) * 0.7071 >= max(au, ay)
            if z >= 2.375: return ("Vox", "DiamondHi")
            if z >= 1.8: return ("Vox", "Diamond" if diag else "DiamondHi")
            if z >= 1.625: return ("Vox", "DiamondLo")
            return ("Vox", "DiamondLo" if diag else "Diamond")
    return handle(ax, y, z, h, hx + 1.5, metal="Chrome", grip="GemBlue", glow="GlowCyan")


def t_trophy(x, y, z, i, j, k):
    h, hx = 2.0, HS + 1.6
    ax = abs(x); u = ax - hx; au, ay = abs(u), abs(y)
    q = math.hypot(u, y)
    if au < 1.6:
        if z < 0.375 and au < 1.0 and ay < 1.0: return ("Vox", "TrophyBase")
        if z < 0.625 and au < 0.8 and ay < 0.8: return ("Vox", "TrophyBaseHi")
        if 0.875 <= z < 1.125 and q < 0.55: return ("Vox", "GoldHi")
        if z < 1.25 and q < 0.3: return ("Vox", "GoldLo")
        if 1.25 <= z < 3.0:
            rc = min(1.3, 0.5 + (z - 1.25) * 0.85)
            if z >= 2.75:
                if 1.1 <= q < 1.5: return ("Vox", "GoldHi")
            elif q < rc and not (z >= 2.5 and q < 1.1):
                if 1.75 <= z < 2.0: return ("Vox", "GoldLo")
                return ("Vox", "Gold")
        d = math.hypot(ay - 1.5, z - 2.1)
        if au < 0.19 and 0.32 <= d < 0.6 and ay >= 1.2: return ("Vox", "GoldHi")
    return handle(ax, y, z, h, hx + 1.3, metal="Gold", grip="TrophyBase", glow="GlowGold")


def t_rocket(x, y, z, i, j, k):
    """Rockets HOVERING on a modelled flame, lifting the bar."""
    h, hx = 2.5, HS + 1.8
    ax = abs(x); u = ax - hx; au, ay = abs(u), abs(y)
    q = math.hypot(u, y)
    if au < 1.9:
        if z < 1.0:                                                # the flame (neon steps)
            rf = 0.8 * (z / 0.75) ** 0.75 if z < 0.75 else 0.8 - (z - 0.75) * 1.0
            if q < rf * 0.5: return ("Vox", "FlameCore")
            if q < rf: return ("Vox", "Flame")
        elif z < 1.375:
            if q < 0.55: return ("Vox", "Nozzle")
        elif z < 4.0:
            if 3.375 <= z < 3.625 and q < 0.97: return ("Vox", "RocketRed")
            if q < 0.85:
                if q > 0.6 and ay > au:                            # round windows front and back
                    dw = math.hypot(u, z - 3.0 + 0.25)
                    if dw < 0.3: return ("Vox", "RocketWindow")
                    if dw < 0.42: return ("Vox", "Nozzle")
                return ("Vox", "RocketBodyLo" if z < 1.625 else "RocketBody")
        elif z < 5.3:
            if q < 0.85 * (1 - ((z - 4.0) / 1.3) ** 1.6): return ("Vox", "RocketRedHi" if z >= 4.9 else "RocketRed")
        if 1.0 <= z < 2.6:                                         # four fins
            reach = 0.8 + (2.6 - z) * 0.6
            if (ay < 0.15 and 0.8 <= au < reach) or (au < 0.15 and 0.8 <= ay < reach):
                return ("Vox", "RocketRedLo" if z < 1.25 else "RocketRed")
    return handle(ax, y, z, h, hx + 0.85, metal="Chrome", grip="RocketRed", glow="Flame")


_pent_r, _hex_r = math.radians(20.1), math.radians(23.8)


def t_soccer(x, y, z, i, j, k):
    h, hx, R = 1.5, HS + 1.4, 1.4
    ax = abs(x); u = ax - hx; dz = z - h
    if abs(u) < 1.45:
        d = math.sqrt(u * u + y * y + dz * dz)
        if d < R:
            if d < R - 0.3: return ("BallP" if x > 0 else "BallN", "Gold")     # inside, never seen
            n = Vector((u, y, dz)) / d
            ap = min(math.acos(min(1.0, n.dot(v))) for v in ICO) / _pent_r
            hs = sorted(math.acos(min(1.0, n.dot(v))) for v in HEXC)
            ah, ah2 = hs[0] / _hex_r, hs[1] / _hex_r
            g = "BallP" if x > 0 else "BallN"                      # its own group: the balls SPIN on the bar
            if ap < ah: return (g, "BallBlack")
            if ah2 - ah < 0.17: return (g, "GoldLo")               # seam between two gold panels
            return (g, "Gold")
    return handle(ax, y, z, h, hx + 1.4, metal="BallBlack", grip="Gold", glow="GlowGold")


PL = dict(h=1.4, off=2.6, R=1.3, tilt=math.radians(25))


def t_planets(x, y, z, i, j, k):
    h, hx, R, tau = PL["h"], HS + PL["off"], PL["R"], PL["tilt"]
    s = 1 if x > 0 else -1
    ax = abs(x)
    if ax > hx - 2.2:
        q = Vector((x - s * hx, y, z - h))
        ql = q.length
        if s > 0:                                                  # ringed gas giant
            if ql < R:
                band = int((q.z + R) / (2 * R) * 9)
                return ("Globe", ("GasALo", "GasA", "GasC", "GasA", "GasAHi", "GasA", "GasC", "GasAHi", "GasA")[min(8, band)])
            n = Vector((s * math.sin(tau), 0, math.cos(tau)))
            dn = q.dot(n)
            if abs(dn) < 0.1:
                rho = (q - dn * n).length
                if 1.5 <= rho < 1.72: return ("Ring", "RingA")
                if 1.8 <= rho < 2.05: return ("Ring", "RingB")
        elif ql < R:                                               # Earth
            d = q / ql
            if abs(d.z) > 0.86: return ("Globe", "Ice")
            land = (math.sin(d.x * 4.3 + 0.7) * math.cos(d.z * 3.1 + 0.4) + math.sin(d.y * 3.7 + 2.0) * math.cos(d.x * 2.9)
                    + 0.6 * math.sin((d.y + d.z) * 6.0))
            if land > 0.05: return ("Globe", "LandHi" if land > 0.8 else "Land")
            return ("Globe", "OceanHi" if land < -1.0 else "Ocean")
    return handle(ax, y, z, h, hx + 1.3, metal="SpaceBar", grip="GasA", glow="RingB")


BH = dict(h=1.4, off=2.6, R=1.0, tilt=math.radians(20))


def t_blackhole(x, y, z, i, j, k):
    """A black sphere with a glowing tilted disc and a bright halo ring facing the viewer."""
    h, hx, R, tau = BH["h"], HS + BH["off"], BH["R"], BH["tilt"]
    s = 1 if x > 0 else -1
    ax = abs(x)
    if ax > hx - 2.4:
        q = Vector((x - s * hx, y, z - h))
        ql = q.length
        if ql < R: return ("Globe", "Void")
        n = Vector((s * math.sin(tau), 0, math.cos(tau)))
        dn = q.dot(n)
        if abs(dn) < 0.1:                                          # the disc: spiral arms, so its SPIN shows
            qp = q - dn * n
            rho = qp.length
            if 1.2 <= rho < 2.3:
                g = "DiscP" if s > 0 else "DiscN"
                th = math.atan2(qp.x * math.cos(tau) - s * qp.z * math.sin(tau), qp.y)
                arm = math.sin(3 * th + rho * 3.0) > 0.25
                if rho < 1.5: return (g, "DiscHot")
                if rho < 1.9: return (g, "DiscHot" if arm else "Disc")
                return (g, "Disc" if arm else "DiscOut")
        if abs(q.y) < 0.1 and 1.06 <= math.hypot(q.x, q.z) < 1.26: return ("Halo", "DiscHot")
    return handle(ax, y, z, h, hx + 1.0, metal="Void", grip="VoidGrip", glow="DiscOut")


TIERS = [
    ("Marshmallow", t_marshmallow, ((-5.75, 5.75), (-1.25, 1.25), (0, 2.5))),
    ("Donut", t_donut, ((-5.25, 5.25), (-1.5, 1.5), (0, 2.875))),
    ("Watermelon", t_watermelon, ((-4.625, 4.625), (-1.5, 1.5), (0, 2.875))),
    ("GoldenEgg", t_egg, ((-5.75, 5.75), (-1.75, 1.75), (0, 3.375))),
    ("Diamond", t_diamond, ((-6.25, 6.25), (-1.625, 1.625), (0, 2.75))),
    ("Trophy", t_trophy, ((-6.125, 6.125), (-2.25, 2.25), (0, 3.125))),
    ("Rocket", t_rocket, ((-6.375, 6.375), (-2.0, 2.0), (0, 5.375))),
    ("SoccerBall", t_soccer, ((-6.0, 6.0), (-1.5, 1.5), (0, 3.0))),
    ("Planets", t_planets, ((-7.125, 7.5), (-2.25, 2.25), (0, 3.375))),
    ("BlackHole", t_blackhole, ((-7.625, 7.625), (-2.5, 2.5), (0, 3.0))),
]


BAR_H = {"Marshmallow": 1.2, "Donut": 1.4, "Watermelon": 1.4, "GoldenEgg": 1.4, "Diamond": 1.8, "Trophy": 2.0,
         "Rocket": 2.5, "SoccerBall": 1.5, "Planets": PL["h"], "BlackHole": BH["h"]}
# where each weight's centre is, for Studio's HeadA / HeadB anchors: (distance past HS, height, size), design units
HEAD = {"Marshmallow": (1.25, 1.2, 2.3), "Donut": (1.0, 1.4, 2.8), "Watermelon": (1.0, 1.4, 2.8), "GoldenEgg": (1.4, 1.5, 2.8),
        "Diamond": (1.6, 1.5, 2.8), "Trophy": (1.6, 2.1, 2.8), "Rocket": (1.8, 3.0, 2.4), "SoccerBall": (1.4, 1.5, 2.8),
        "Planets": (2.6, 1.4, 2.6), "BlackHole": (2.6, 1.4, 2.0)}
ORBITS = {}        # tier number -> {group: (centre, axis, speed)} in design units; written out (scaled) for Studio


def orbit(n, name, group, s, hx, cz, Rr, phi, tau, shift, speed):
    """Register an orbiting piece and return its start position + direction of travel.
    Orbit centre = (s*(hx+shift), 0, cz), tilted by tau so the side nearest the hands is RAISED.
    shift pushes the whole orbit outward so nothing ever passes over the grip zone."""
    phi = math.radians(phi)
    e1 = Vector((0, 1, 0)); e2 = Vector((math.cos(tau), 0, -s * math.sin(tau)))
    centre = Vector((s * (hx + shift), 0, cz))
    axis = Vector((s * math.sin(tau), 0, math.cos(tau)))
    ORBITS.setdefault(n + 1, {})[group] = (centre - Vector((0, 0, BAR_H[name])), axis, speed)
    return centre + Rr * (math.cos(phi) * e1 + math.sin(phi) * e2), (-math.sin(phi) * e1 + math.cos(phi) * e2)


allobjs = []
for n, (name, fn, bounds) in enumerate(TIERS):
    coll = bpy.data.collections.new(f"Weight{n + 1}_{name}")
    bpy.context.scene.collection.children.link(coll)
    prefix = f"Weight{n + 1}_{name}_"
    off = Vector((0, -n * GAP, 0))
    K = K_TIER[n]
    HS = HS_WORLD / K                       # the tier functions read this: grip zone = 2 studs when built
    objs = build(prefix, fn, bounds, coll, offset=tuple(off), scale=K)

    def ball(tag, mat, pos, rad):
        f = lambda x, y, z, i, j, k: ("Orb" + tag, mat + ("Hi" if z > 0.1 else "")) if math.sqrt(x * x + y * y + z * z) < rad else None
        return build(prefix, f, ((-0.75, 0.75),) * 3, coll, offset=tuple(pos * K + off), scale=K, iters=2)

    # ONE signature thing per tier (pigeon: orbiting belongs to the planets, the others must be unique):
    #   Soccer Ball: the balls spin on the bar.   Planets: moons + a rocket orbit.
    #   Black Hole: the spiral disc turns.        (Trophy confetti, rocket flame etc. are Studio effects.)
    if name == "SoccerBall":
        for s, g in ((1, "BallP"), (-1, "BallN")):
            ORBITS.setdefault(n + 1, {})[g] = (Vector((s * (HS + 1.4), 0, 0)), Vector((1, 0, 0)), 1.6)
    if name == "BlackHole":
        for s, g in ((1, "DiscP"), (-1, "DiscN")):
            ORBITS.setdefault(n + 1, {})[g] = (Vector((s * (HS + BH["off"]), 0, 0)), Vector((s * math.sin(BH["tilt"]), 0, math.cos(BH["tilt"]))), 1.5)
    if name == "Planets":
        h, hx, tau = PL["h"], HS + PL["off"], PL["tilt"]
        objs += ball("Ice", "MoonIce", orbit(n, name, "OrbIce", 1, hx, h + 0.6, 2.6, 70, tau, 0, 1.1)[0], 0.5)
        objs += ball("Lava", "MoonLava", orbit(n, name, "OrbLava", 1, hx, h + 0.6, 2.6, 250, tau, 0, 1.1)[0], 0.42)
        objs += ball("Moon", "Moon", orbit(n, name, "OrbMoon", -1, hx, h + 0.6, 2.9, 250, tau, 0, 0.9)[0], 0.45)
        # The rocket that flies round the Earth. v7's was 0.5 studs wide and the smoothing melted it
        # into a red blob (pigeon: "why doesn't the rocket fly around the planet any more"). Now a
        # proper little rocket, 3 studs long: body, red nose + band, four fins, window, flame.
        pos, tan = orbit(n, name, "OrbSatBody", -1, hx, h + 0.8, 2.2, 60, math.radians(40), 0, 1.7)
        for g in ("OrbSatNose", "OrbSatFlame"): ORBITS[n + 1][g] = ORBITS[n + 1]["OrbSatBody"]
        def sat(x, y, z, i, j, k):
            ax_, ay_ = abs(x), abs(y); rr = math.hypot(x, y)
            if 0.4 <= z < 1.1 and rr < 0.36 * (1 - ((z - 0.4) / 0.7) ** 1.5): return ("OrbSatNose", "RocketRed")
            if 0.24 <= z < 0.4 and rr < 0.43: return ("OrbSatNose", "RocketRed")
            if -0.7 <= z < 0.4 and rr < 0.36:
                if -0.1 <= z < 0.16 and rr >= 0.24 and ay_ > ax_ and ax_ < 0.14: return ("OrbSatNose", "RocketWindow")
                return ("OrbSatBody", "RocketBody")
            if -0.7 <= z < -0.1:
                reach = 0.36 + (-0.1 - z) * 0.6
                if (ax_ < 0.09 and ay_ < reach) or (ay_ < 0.09 and ax_ < reach): return ("OrbSatNose", "RocketRed")
            if -1.1 <= z < -0.7 and rr < 0.27 * (1 - (-0.7 - z) / 0.4 * 0.8): return ("OrbSatFlame", "Flame")
            return None
        so = build(prefix, sat, ((-0.8, 0.8), (-0.8, 0.8), (-1.15, 1.15)), coll, scale=K, iters=1)
        aim = Matrix.Translation(pos * K + off) @ Vector((0, 0, 1)).rotation_difference(tan).to_matrix().to_4x4()
        for o in so: o.data.transform(aim)
        objs += so
    tris = sum(sum(len(p.vertices) - 2 for p in o.data.polygons) for o in objs)
    print("TIER", n + 1, name, "parts", len(objs), "tris", tris, "max", max(sum(len(p.vertices) - 2 for p in o.data.polygons) for o in objs))
    allobjs += objs

# orbit table for Studio, in each model's Root space (Blender x, y, z -> Roblox x, z, -y)
import os
with open(os.path.join(os.path.dirname(fbx_out), "weights_orbits.lua"), "w") as fh:
    fh.write("-- generated by weights_vox.py, in studs.\n")
    fh.write("-- tiers[n]  = k (how much bigger than the design), h (bar height), hx / hz / size (the weights' centres)\n")
    fh.write("-- orbits[n][group] = {centre x,y,z, axis x,y,z, speed} in the model's Root space\n")
    fh.write(f"return {{\n\tgap = {GAP},\n\ttiers = {{\n")
    for n, (name, _, _) in enumerate(TIERS):
        K = K_TIER[n]; dx, hz, size = HEAD[name]
        fh.write(f"\t\t{{ k = {K}, h = {BAR_H[name] * K:.4f}, hx = {HS_WORLD + dx * K:.4f}, hz = {hz * K:.4f}, size = {size * K:.4f} }},\n")
    fh.write("\t},\n\torbits = {\n")
    for tier in sorted(ORBITS):
        K = K_TIER[tier - 1]
        fh.write(f"\t\t[{tier}] = {{\n")
        for g, (c, a, sp) in sorted(ORBITS[tier].items()):
            c = c * K
            fh.write(f"\t\t\t{g} = {{{c.x:.4f}, {c.z:.4f}, {-c.y:.4f}, {a.x:.4f}, {a.z:.4f}, {-a.y:.4f}, {sp}}},\n")
        fh.write("\t\t},\n")
    fh.write("\t},\n}\n")

# ---------------------------------------------------------------- preview
sc = bpy.context.scene
dm = material("Bar")
for size, loc in [((2, 1, 2), (0, 0, 3)), ((1.1, 1.1, 1.1), (0, 0, 4.55)), ((0.95, 1, 2), (-0.5, 0, 1)),
                  ((0.95, 1, 2), (0.5, 0, 1)), ((0.95, 1, 2), (-1.5, 0, 3)), ((0.95, 1, 2), (1.5, 0, 3))]:
    for n in (0, 6):     # a 5-stud dummy behind tier 1 and tier 7 for scale
        bpy.ops.mesh.primitive_cube_add(size=1, location=(loc[0], loc[1] + 4.5 - n * GAP, loc[2]))
        o = bpy.context.active_object; o.scale = size; o.data.materials.append(dm)
bpy.ops.mesh.primitive_plane_add(size=400, location=(0, -40, 0))
g = bpy.data.materials.new("Ground"); g.use_nodes = True
g.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (0.55, 0.58, 0.66, 1)
bpy.context.active_object.data.materials.append(g)
sun = bpy.data.objects.new("Sun", bpy.data.lights.new("Sun", 'SUN')); sun.data.energy = 3.0
sun.rotation_euler = (math.radians(50), 0, math.radians(30)); sc.collection.objects.link(sun)
sc.world = bpy.data.worlds.new("W"); sc.world.use_nodes = True
sc.world.node_tree.nodes["Background"].inputs["Color"].default_value = (0.75, 0.82, 0.92, 1)
cam = bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam")); sc.collection.objects.link(cam)
sc.camera = cam
sc.render.engine = 'CYCLES'; sc.cycles.device = 'CPU'; sc.cycles.samples = 16; sc.cycles.use_denoising = True
sc.render.resolution_x = 1100; sc.render.resolution_y = 620
bpy.ops.wm.save_as_mainfile(filepath=blend_out)
for n in range(len(TIERS)):          # one shot per tier, from the front-left like a player would see it
    tgt = Vector((0, -n * GAP, 2.2))
    cam.data.lens = 34
    cam.location = tgt + Vector((9.5, -19, 8))
    cam.rotation_euler = (tgt - cam.location).to_track_quat('-Z', 'Y').to_euler()
    sc.render.filepath = png_out.replace(".png", f"_{n + 1:02d}.png")
    bpy.ops.render.render(write_still=True)

mk = material("Seed")
for nm, loc in (("SOA_AxisO", (0, 0, 0)), ("SOA_AxisUp", (0, 0, 3)), ("SOA_AxisFwd", (0, 3, 0))):
    bpy.ops.mesh.primitive_cube_add(size=0.2, location=loc)
    o = bpy.context.active_object; o.name = nm; o.data.materials.append(mk); allobjs.append(o)
bpy.ops.object.select_all(action='DESELECT')
for o in allobjs: o.select_set(True)
bpy.context.view_layer.objects.active = allobjs[0]
bpy.ops.export_scene.fbx(filepath=fbx_out, use_selection=True, object_types={'MESH'},
                         apply_unit_scale=True, mesh_smooth_type='OFF', axis_forward='-Z', axis_up='Y')
print("DONE")
