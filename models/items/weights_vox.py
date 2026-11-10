"""Weight tiers v5 for Score on Animals: chunky STEPPED (voxel) style.

Why v5: pigeon showed a reference weight from another game and said ours were "missing something".
What that reference has and ours didn't:
  - MASS: huge heads, thick handle (other lifting games do the same: weights wider than the player)
  - LAYERS: everything is stepped blocks, so every surface has depth
  - ONE COLOUR FAMILY per piece: base + lighter (Hi) + darker (Lo) steps of the same colour
  - a DESIGNED HANDLE: ribbed grips, stepped collars, a centre block, end caps
So every tier is defined as a function "which material is at this point", sampled on a 0.2-stud
grid. One mesh per material per tier (Roblox gives a MeshPart one colour); Studio colours them
from the name:  Weight<N>_<Tier>_<Group>__<Material>   (Material may end in Hi / Lo).
Bar along X, Z up, ground at z = 0, bar centre above each tier's own origin. 1 unit = 1 stud.

blender -b --factory-startup -P weights_vox.py -- <out.blend> <out.fbx> <render.png>
"""
import bpy, bmesh, sys, math
from mathutils import Vector, Matrix

argv = sys.argv[sys.argv.index("--") + 1:]
blend_out, fbx_out, png_out = argv
bpy.ops.wm.read_factory_settings(use_empty=True)

C = 0.2            # voxel size in studs
GAP = 8.0          # spacing between tiers in the file (along -Y)

BASE = {
    "Bar": "#8C8F99", "Grip": "#2E2E36", "Wood": "#B5793C",
    "Marshmallow": "#FFF4EA", "MarshPink": "#FFB7D5", "Toast": "#C98A3E",
    "Dough": "#E3A35A", "Icing": "#FF7EB6",
    "SprinkleY": "#FFE14D", "SprinkleB": "#4DB8FF", "SprinkleG": "#6BE36B", "SprinkleW": "#FFFFFF",
    "Rind": "#2E9B35", "RindIn": "#E4F7C8", "Flesh": "#FF4D5E", "Seed": "#1A1A1A",
    "Gold": "#F7C440", "Pearl": "#FFF6E0", "GemRed": "#E8262B", "GemBlue": "#2F7BFF",
    "Anvil": "#4A4E5A", "HotMetal": "#FF7A1A",
    "Diamond": "#6FE3FF", "Chrome": "#D7DCE6",
    "TrophyBase": "#2A2A30",
    "RocketBody": "#F2F2F2", "RocketRed": "#E8262B", "RocketWindow": "#4DB8FF", "Nozzle": "#5A5F6B",
    "BallBlack": "#1E1E24",
    "SpaceBar": "#2B2F6B", "GasA": "#7B4DFF", "GasC": "#FF7EC8", "RingA": "#FFD27E", "RingB": "#FF9BD6",
    "MoonIce": "#8DF4FF", "MoonLava": "#FF8A3D", "Ocean": "#2F7BFF", "Land": "#3FCF5A", "Ice": "#F4FBFF",
    "Moon": "#C9CCD6",
}
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
    if name.startswith(("HotMetal", "RingA", "RingB", "RocketWindow", "MoonLava")):
        bs.inputs["Emission Color"].default_value = (*c, 1); bs.inputs["Emission Strength"].default_value = 1.5
    return m


# ---------------------------------------------------------------- voxel -> mesh
DIRS = [((1, 0, 0), [(1, 0, 0), (1, 1, 0), (1, 1, 1), (1, 0, 1)]), ((-1, 0, 0), [(0, 0, 0), (0, 0, 1), (0, 1, 1), (0, 1, 0)]),
        ((0, 1, 0), [(0, 1, 0), (0, 1, 1), (1, 1, 1), (1, 1, 0)]), ((0, -1, 0), [(0, 0, 0), (1, 0, 0), (1, 0, 1), (0, 0, 1)]),
        ((0, 0, 1), [(0, 0, 1), (1, 0, 1), (1, 1, 1), (0, 1, 1)]), ((0, 0, -1), [(0, 0, 0), (0, 1, 0), (1, 1, 0), (1, 0, 0)])]


def build(prefix, fn, bounds, coll, offset=(0, 0, 0), cell=C):
    """Sample fn(x, y, z, i, j, k) -> None | (group, material) on the grid and make one mesh per
    (group, material) with only the outside faces."""
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
    bms = {}
    for (i, j, k), key in grid.items():
        clear = key[1].startswith(SEE_THROUGH)
        for (dx, dy, dz), quad in DIRS:
            nb = grid.get((i + dx, j + dy, k + dz))
            if nb is None or (nb[1].startswith(SEE_THROUGH) and not clear):
                bm = bms.get(key)
                if bm is None: bm = bms[key] = bmesh.new()
                bm.faces.new([bm.verts.new(((i + a) * cell, (j + b) * cell, (k + c) * cell)) for a, b, c in quad])
    objs = []
    for (group, mat), bm in sorted(bms.items()):
        bmesh.ops.remove_doubles(bm, verts=bm.verts[:], dist=1e-5)
        bmesh.ops.dissolve_limit(bm, angle_limit=0.001, verts=bm.verts[:], edges=bm.edges[:])
        bmesh.ops.translate(bm, vec=Vector(offset), verts=bm.verts[:])
        me = bpy.data.meshes.new(f"{prefix}{group}__{mat}")
        bm.to_mesh(me); bm.free()
        me.materials.append(material(mat))
        o = bpy.data.objects.new(f"{prefix}{group}__{mat}", me)
        coll.objects.link(o)
        objs.append(o)
    return objs


def hsh(i, j, k):
    return ((i * 73856093) ^ (j * 19349663) ^ (k * 83492791)) & 0xFFFF


# ---------------------------------------------------------------- shared handle
def handle(ax, y, z, h, end, metal="Bar", grip="Grip", orn=None, collars=True):
    """Thick bar: centre block, ribbed grips, stepped collars, shaft, end caps. end = where the head stops."""
    dz = z - h
    r = math.hypot(y, dz); sq = max(abs(y), abs(dz))
    if orn:
        if ax < 0.2 and sq < 0.8 and (abs(y) < 0.2 or abs(dz) < 0.2): return ("Vox", orn[1])   # cross studs
        if ax < 0.4 and sq < 0.6: return ("Vox", orn[0])
    if 0.4 <= ax < 1.0 and r < 0.3:
        return ("Vox", grip if int(round(ax / C - 0.5)) % 2 else grip + "Hi")
    if collars:
        if 1.0 <= ax < 1.2 and r < 0.55: return ("Vox", metal + "Hi")
        if 1.2 <= ax < 1.4 and r < 0.42: return ("Vox", metal + "Lo")
    if end <= ax < end + 0.2 and r < 0.55: return ("Vox", metal + "Hi")
    if end + 0.2 <= ax < end + 0.4 and r < 0.42: return ("Vox", metal + "Lo")
    if ax < end + 0.6 and r < 0.3: return ("Vox", metal)
    return None


ICO = []
_t = (1 + 5 ** 0.5) / 2
for a, b in ((1, _t), (-1, _t), (1, -_t), (-1, -_t)):
    for v in ((0, a, b), (a, b, 0), (b, 0, a)):
        ICO.append(Vector(v).normalized())


# ---------------------------------------------------------------- the 10 tiers
def t_marshmallow(x, y, z, i, j, k):
    h, hx, R = 1.2, 2.6, 1.15
    ax = abs(x); u = ax - hx; dz = z - h; r = math.hypot(y, dz)
    if -1.2 <= u < 1.2:
        outer = u >= 0
        t = u if outer else u + 1.2                       # 0..1.2 inside this puff
        edge = min(t, 1.2 - t)
        rad = R - (0.3 if edge < 0.2 else 0.0)            # soft rounded ends
        if r < rad:
            if outer and t >= 1.0:                        # toasted end
                return ("Vox", "ToastLo" if r < 0.5 else "Toast")
            m = "MarshPink" if outer else "Marshmallow"
            if dz > 0.5: m += "Hi"
            elif dz < -0.7: m += "Lo"
            return ("Vox", m)
    return handle(ax, y, z, h, hx + 1.2, metal="Wood", grip="Toast", collars=False)


def t_donut(x, y, z, i, j, k):
    h, hx, Rt, a = 1.4, 2.4, 0.9, 0.5
    ax = abs(x); u = ax - hx; dz = z - h; r = math.hypot(y, dz)
    for uc in (-0.5, 0.5):
        du = u - uc
        d = math.hypot(r - Rt, du)
        if d < a:
            if du > 0 and d > 0.2:                        # icing on the outward-facing half
                if d > 0.34 and hsh(i, j, k) % 3 == 0:
                    return ("Vox", ("SprinkleY", "SprinkleB", "SprinkleG", "SprinkleW")[hsh(j, k, i) % 4])
                return ("Vox", "IcingHi" if dz > 0.7 else "Icing")
            return ("Vox", "DoughHi" if dz > 0.7 else ("DoughLo" if dz < -0.8 else "Dough"))
    return handle(ax, y, z, h, hx + 1.0)


def t_watermelon(x, y, z, i, j, k):
    h, hx, R, face = 1.4, 2.4, 1.4, 0.4
    ax = abs(x); u = ax - hx; dz = z - h; r = math.hypot(y, dz)
    rho = math.hypot(u - face, r)
    if u < face and rho < R:
        if rho > R - 0.25:
            sector = int((math.atan2(dz, y) + math.pi) / (2 * math.pi) * 10) % 2
            return ("Vox", "RindLo" if sector else "Rind")
        if rho > R - 0.45: return ("Vox", "RindIn")
        if u > face - 0.2:                                # the cut face: seeds
            for n in range(6):
                a = math.radians(n * 60 + 20)
                if math.hypot(y - 0.65 * math.cos(a), dz - 0.65 * math.sin(a)) < 0.13: return ("Vox", "Seed")
        return ("Vox", "FleshHi" if r < 0.35 else "Flesh")
    return handle(ax, y, z, h, hx + face)


def t_egg(x, y, z, i, j, k):
    h, hx, H, W = 1.4, 2.8, 3.0, 1.2
    ax = abs(x); u = ax - hx
    q = math.hypot(u, y)
    t = z / H
    if 0 < t < 1:
        w = W * 2 * math.sqrt(t * (1 - t)) * (1.1 - 0.3 * t)
        upper = 2.0 <= z < 2.2
        if upper:
            ang = math.atan2(y, u); n = round(ang / (math.pi / 4))
            if q < w + 0.4 and abs(ang - n * math.pi / 4) < 0.16 and q > w - 0.1:
                return ("Vox", "GemRed" if n % 2 else "GemBlue")
        if (upper or 0.8 <= z < 1.0) and q < w + 0.2: return ("Vox", "Pearl")
        if q < w:
            return ("Vox", "GoldHi" if z >= 2.2 else ("GoldLo" if z < 0.8 else "Gold"))
    if H <= z < H + 0.2 and q < 0.25: return ("Vox", "Pearl")
    return handle(ax, y, z, h, hx + 1.2, metal="Gold", orn=("GoldLo", "Pearl"))


def t_anvil(x, y, z, i, j, k):
    h, hx = 1.6, 2.4
    ax = abs(x); u = abs(ax - hx); ay = abs(y)
    if z < 0.4 and u < 1.0 and ay < 1.0: return ("Vox", "AnvilLo")
    if z < 0.6 and u < 0.8 and ay < 0.8: return ("Vox", "Anvil")
    if z < 1.2 and u < 0.6 and ay < 0.6: return ("Vox", "AnvilLo")
    if 1.2 <= z < 2.0 and u < 1.0 and ay < 1.2:
        return ("Vox", "AnvilHi" if z >= 1.8 else "Anvil")
    if 1.4 <= z < 2.0 and u < 0.6 and -1.6 <= y < -1.2: return ("Vox", "AnvilHi" if z >= 1.8 else "Anvil")   # horn
    if 1.6 <= z < 2.0 and u < 0.4 and -2.0 <= y < -1.6: return ("Vox", "AnvilHi" if z >= 1.8 else "Anvil")
    if 1.8 <= z < 2.0 and u < 0.2 and -2.2 <= y < -2.0: return ("Vox", "AnvilHi")
    if 2.0 <= z < 2.2 and u < 0.6 and ay < 0.4: return ("Vox", "HotMetal")       # red-hot ingot
    return handle(ax, y, z, h, hx + 1.0, metal="Anvil", orn=("AnvilLo", "HotMetal"))


def t_diamond(x, y, z, i, j, k):
    h, hx = 1.8, 2.9
    ax = abs(x); u = ax - hx
    au, ay = abs(u), abs(y)
    octr = max(au, ay, (au + ay) * 0.7071)
    rad = (z / 1.8 * 1.5) if z < 1.8 else (1.5 - (z - 1.8) / 0.8 * 0.6)
    if 0 < z < 2.6 and octr < rad:
        diag = (au + ay) * 0.7071 >= max(au, ay)
        if z >= 2.4: return ("Vox", "DiamondHi")                  # table
        if z >= 1.8: return ("Vox", "Diamond" if diag else "DiamondHi")
        if z >= 1.6: return ("Vox", "DiamondLo")                  # girdle band
        return ("Vox", "DiamondLo" if diag else "Diamond")
    return handle(ax, y, z, h, hx + 1.5, metal="Chrome", orn=("Chrome", "Diamond"))


def t_trophy(x, y, z, i, j, k):
    h, hx = 2.0, 2.9
    ax = abs(x); u = ax - hx; au, ay = abs(u), abs(y)
    q = math.hypot(u, y)
    if z < 0.4 and au < 1.0 and ay < 1.0: return ("Vox", "TrophyBase")
    if z < 0.6 and au < 0.8 and ay < 0.8: return ("Vox", "TrophyBaseHi")
    if 0.8 <= z < 1.0 and q < 0.55: return ("Vox", "GoldHi")
    if z < 1.2 and q < 0.3: return ("Vox", "GoldLo")
    if 1.2 <= z < 3.0:
        rc = min(1.3, 0.5 + (z - 1.2) * 0.8)
        if z >= 2.8:
            if 1.1 <= q < 1.5: return ("Vox", "GoldHi")           # rim, cup is hollow
        elif q < rc and not (z >= 2.6 and q < 1.1):
            if 1.8 <= z < 2.0: return ("Vox", "GoldLo")           # band
            return ("Vox", "Gold")
    d = math.hypot(ay - 1.5, z - 2.1)                              # handles on both sides
    if au < 0.2 and 0.3 <= d < 0.62 and ay >= 1.2: return ("Vox", "GoldHi")
    return handle(ax, y, z, h, hx + 1.3, metal="Gold", orn=("GoldLo", "GoldHi"))


def t_rocket(x, y, z, i, j, k):
    h, hx = 1.6, 2.9
    ax = abs(x); u = ax - hx; au, ay = abs(u), abs(y)
    q = math.hypot(u, y)
    if z < 0.4 and q < 0.5: return ("Vox", "Nozzle")
    if 0.4 <= z < 2.8:
        if 2.2 <= z < 2.4 and q < 0.9: return ("Vox", "RocketRed")
        if q < 0.75:
            if 1.6 <= z < 2.0 and (au < 0.2 or ay < 0.2) and q > 0.45: return ("Vox", "RocketWindow")
            return ("Vox", "RocketBodyLo" if z < 0.8 else "RocketBody")
    if 2.8 <= z < 4.0:
        if q < 0.75 - (z - 2.8) * 0.55: return ("Vox", "RocketRedHi" if z >= 3.6 else "RocketRed")
    if z < 1.6:                                                    # four stepped fins
        reach = 0.75 + (1.6 - z) * 0.55
        if (ay < 0.2 and 0.7 <= au < reach) or (au < 0.2 and 0.7 <= ay < reach):
            return ("Vox", "RocketRedLo" if z < 0.4 else "RocketRed")
    return handle(ax, y, z, h, hx + 0.8, metal="RocketBody", grip="RocketRed", orn=("RocketRed", "RocketWindow"))


def t_soccer(x, y, z, i, j, k):
    h, hx, R = 1.4, 2.8, 1.4
    ax = abs(x); u = ax - hx; dz = z - h
    d = Vector((u, y, dz))
    if d.length < R:
        n = d.normalized()
        if max(n.dot(v) for v in ICO) > 0.945: return ("Vox", "BallBlack")
        return ("Vox", "GoldHi" if dz > 0.7 else ("GoldLo" if dz < -0.9 else "Gold"))
    return handle(ax, y, z, h, hx + 1.4, metal="BallBlack", grip="Gold", orn=("Gold", "BallBlack"))


PL = dict(h=1.4, hx=3.2, R=1.3, tilt=math.radians(25))


def t_planets(x, y, z, i, j, k):
    h, hx, R, tau = PL["h"], PL["hx"], PL["R"], PL["tilt"]
    s = 1 if x > 0 else -1
    ax = abs(x)
    q = Vector((x - s * hx, y, z - h))
    if s > 0:                                                      # ringed gas giant
        if q.length < R:
            band = int((q.z + R) / (2 * R) * 7)
            return ("Globe", ("GasALo", "GasA", "GasC", "GasA", "GasAHi", "GasC", "GasA")[min(6, band)])
        n = Vector((s * math.sin(tau), 0, math.cos(tau)))
        dn = q.dot(n)
        if abs(dn) < 0.14:
            rho = (q - dn * n).length
            if 1.6 <= rho < 1.85: return ("Ring", "RingA")
            if 1.95 <= rho < 2.2: return ("Ring", "RingB")
    else:                                                          # Earth
        if q.length < R:
            d = q.normalized()
            if abs(d.z) > 0.84: return ("Globe", "Ice")
            land = (math.sin(d.x * 4.3 + 0.7) * math.cos(d.z * 3.1 + 0.4) + math.sin(d.y * 3.7 + 2.0) * math.cos(d.x * 2.9)
                    + 0.6 * math.sin((d.y + d.z) * 6.0))
            if land > 0.05: return ("Globe", "LandHi" if land > 0.8 else "Land")
            return ("Globe", "OceanHi" if land < -1.0 else "Ocean")
    return handle(ax, y, z, h, hx + 1.3, metal="SpaceBar", grip="GasA", orn=("SpaceBar", "RingA"))


TIERS = [
    ("Marshmallow", t_marshmallow, ((-4.6, 4.6), (-1.4, 1.4), (0, 2.6))),
    ("Donut", t_donut, ((-4.2, 4.2), (-1.6, 1.6), (0, 3.0))),
    ("Watermelon", t_watermelon, ((-3.6, 3.6), (-1.6, 1.6), (0, 3.0))),
    ("GoldenEgg", t_egg, ((-4.8, 4.8), (-1.8, 1.8), (0, 3.4))),
    ("Anvil", t_anvil, ((-4.2, 4.2), (-2.4, 1.4), (0, 2.4))),
    ("Diamond", t_diamond, ((-5.2, 5.2), (-1.6, 1.6), (0, 2.8))),
    ("Trophy", t_trophy, ((-5.0, 5.0), (-2.4, 2.4), (0, 3.2))),
    ("Rocket", t_rocket, ((-4.6, 4.6), (-1.8, 1.8), (0, 4.2))),
    ("SoccerBall", t_soccer, ((-5.0, 5.0), (-1.6, 1.6), (0, 3.0))),
    ("Planets", t_planets, ((-5.6, 5.8), (-2.4, 2.4), (0, 3.2))),
]

allobjs = []
for n, (name, fn, bounds) in enumerate(TIERS):
    coll = bpy.data.collections.new(f"Weight{n + 1}_{name}")
    bpy.context.scene.collection.children.link(coll)
    prefix = f"Weight{n + 1}_{name}_"
    objs = build(prefix, fn, bounds, coll, offset=(0, -n * GAP, 0))
    if name == "Planets":                                          # orbiters: their own little objects
        h, hx, tau = PL["h"], PL["hx"], PL["tilt"]

        def orbit_pos(s, Rr, phi):
            e1 = Vector((0, 1, 0)); e2 = Vector((math.cos(tau), 0, -s * math.sin(tau)))
            return Vector((s * hx, 0, h)) + Rr * (math.cos(phi) * e1 + math.sin(phi) * e2), (-math.sin(phi) * e1 + math.cos(phi) * e2)

        def moon(tag, mat, s, Rr, phi, rad):
            pos, _ = orbit_pos(s, Rr, math.radians(phi))
            f = lambda x, y, z, i, j, k: ("Orb" + tag, mat + ("Hi" if z > 0.1 else "")) if math.sqrt(x * x + y * y + z * z) < rad else None
            return build(prefix, f, ((-0.6, 0.6),) * 3, coll, offset=tuple(pos + Vector((0, -n * GAP, 0))), cell=0.15)

        objs += moon("Ice", "MoonIce", 1, 2.55, 70, 0.42)
        objs += moon("Lava", "MoonLava", 1, 2.95, 215, 0.33)
        objs += moon("Moon", "Moon", -1, 2.45, 250, 0.45)
        pos, tan = orbit_pos(-1, 1.95, math.radians(60))
        def sat(x, y, z, i, j, k):
            q = max(abs(x), abs(y))
            if -0.3 <= z < 0.15 and q < 0.15: return ("OrbSatBody", "RocketBody")
            if 0.15 <= z < 0.45 and q < 0.15 - (z - 0.15) * 0.3 + 0.01: return ("OrbSatNose", "RocketRed")
            if -0.3 <= z < -0.05 and ((abs(x) < 0.05 and q < 0.3) or (abs(y) < 0.05 and q < 0.3)): return ("OrbSatNose", "RocketRed")
            return None
        so = build(prefix, sat, ((-0.4, 0.4), (-0.4, 0.4), (-0.4, 0.5)), coll, cell=0.1)
        aim = Matrix.Translation(pos + Vector((0, -n * GAP, 0))) @ Vector((0, 0, 1)).rotation_difference(tan).to_matrix().to_4x4()
        for o in so: o.data.transform(aim)
        objs += so
    tris = sum(sum(len(p.vertices) - 2 for p in o.data.polygons) for o in objs)
    print("TIER", n + 1, name, "parts", len(objs), "tris", tris)
    allobjs += objs

# ---------------------------------------------------------------- preview
sc = bpy.context.scene
dm = material("Bar")
for size, loc in [((2, 1, 2), (0, 0, 3)), ((1.1, 1.1, 1.1), (0, 0, 4.55)), ((0.95, 1, 2), (-0.5, 0, 1)),
                  ((0.95, 1, 2), (0.5, 0, 1)), ((0.95, 1, 2), (-1.5, 0, 3)), ((0.95, 1, 2), (1.5, 0, 3))]:
    bpy.ops.mesh.primitive_cube_add(size=1, location=(loc[0] - 8.5, loc[1] + 1, loc[2]))
    o = bpy.context.active_object; o.scale = size; o.data.materials.append(dm)
bpy.ops.mesh.primitive_plane_add(size=300, location=(0, -36, 0))
g = bpy.data.materials.new("Ground"); g.use_nodes = True
g.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (0.7, 0.73, 0.8, 1)
bpy.context.active_object.data.materials.append(g)
sun = bpy.data.objects.new("Sun", bpy.data.lights.new("Sun", 'SUN')); sun.data.energy = 3.5
sun.rotation_euler = (math.radians(50), 0, math.radians(-30)); sc.collection.objects.link(sun)
sc.world = bpy.data.worlds.new("W"); sc.world.use_nodes = True
sc.world.node_tree.nodes["Background"].inputs["Color"].default_value = (0.75, 0.82, 0.92, 1)
cam = bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam")); sc.collection.objects.link(cam)
sc.camera = cam
sc.render.engine = 'CYCLES'; sc.cycles.device = 'CPU'; sc.cycles.samples = 24; sc.cycles.use_denoising = True
sc.render.resolution_x = 1500; sc.render.resolution_y = 950
bpy.ops.wm.save_as_mainfile(filepath=blend_out)


def shot(tag, tgt, off, lens=40):
    cam.data.lens = lens
    cam.location = Vector(tgt) + Vector(off)
    cam.rotation_euler = (Vector(tgt) - cam.location).to_track_quat('-Z', 'Y').to_euler()
    sc.render.filepath = png_out.replace(".png", f"_{tag}.png")
    bpy.ops.render.render(write_still=True)


for a in range(0, 10, 2):       # two tiers per shot
    shot(f"t{a + 1}", (0, -(a + 0.5) * GAP, 1.4), (11, 13, 9), 36)

mk = material("Seed")
for nm, loc in (("SOA_AxisO", (0, 0, 0)), ("SOA_AxisUp", (0, 0, 3)), ("SOA_AxisFwd", (0, 3, 0))):
    bpy.ops.mesh.primitive_cube_add(size=0.2, location=loc)
    o = bpy.context.active_object; o.name = nm; o.data.materials.append(mk); allobjs.append(o)
bpy.ops.object.select_all(action='DESELECT')
for o in allobjs: o.select_set(True)
bpy.context.view_layer.objects.active = allobjs[0]
bpy.ops.export_scene.fbx(filepath=fbx_out, use_selection=True, object_types={'MESH'},
                         apply_unit_scale=True, mesh_smooth_type='FACE', axis_forward='-Z', axis_up='Y')
print("DONE")
