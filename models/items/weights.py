"""Weight tiers for Score on Animals (v3).

pigeon's notes: Roblox quality (not too detailed, but higher than v1 is fine), funny progression,
SAME LOOK AS THE ANIMALS (flat facets; Studs texture added in Studio), real ITEMS not ideas, and VFX
on the good ones (added in Studio from Jacob's VFX library).
  1 Marshmallow  2 Donut (sprinkles)  3 Watermelon (cut halves, red + seeds)  4 Golden Egg  5 Anvil
  6 Diamond  7 Trophy  8 Rocket  9 Flaming Golden Soccer Ball
Every object is split so it has ONE material, and named  Weight<N>_<Tier>_<Part>__<Material>
(Roblox gives a MeshPart one colour; Studio colours each part from the material name).
1 unit = 1 stud. Each tier lies on the ground, bar along X, bar centre above its own origin.

blender -b --factory-startup -P weights.py -- <out.blend> <out.fbx> <render.png>
"""
import bpy, sys, math, bmesh, random
from mathutils import Matrix, Vector

argv = sys.argv[sys.argv.index("--") + 1:]
blend_out, fbx_out, png_out = argv
ns = {}
exec(open(r"C:\Users\ortho\HomeRunToTheMoon\models\item_kit.py").read(), ns)
lathe, torus, mat, collection, _obj = ns["lathe"], ns["torus"], ns["mat"], ns["collection"], ns["_obj"]
bpy.ops.wm.read_factory_settings(use_empty=True)
random.seed(11)

# material name -> preview colour (Studio has the same table)
COL = {
    "Bar": "#8C8F99", "Chrome": "#D7DCE6", "BarGold": "#F7C440",
    "Marshmallow": "#FFF4EA", "Dough": "#E3A35A", "Icing": "#FF7EB6",
    "SprinkleY": "#FFE14D", "SprinkleB": "#4DB8FF", "SprinkleG": "#6BE36B", "SprinkleW": "#FFFFFF",
    "Rind": "#2E9B35", "RindStripe": "#1D6A23", "RindIn": "#E4F7C8", "Flesh": "#FF4D5E", "Seed": "#1A1A1A",
    "Gold": "#F7C440", "Anvil": "#3A3D46",
    "Diamond": "#8DF4FF",
    "TrophyGold": "#FFC93D", "TrophyBase": "#2A2A30",
    "RocketBody": "#F2F2F2", "RocketRed": "#E8262B", "RocketWindow": "#4DB8FF", "Nozzle": "#5A5F6B",
    "BallGold": "#F7C440", "BallBlack": "#1E1E24",
    "Grip": "#2E2E36", "Wood": "#B5793C", "MarshPink": "#FFB7D5", "Toast": "#C98A3E", "ToastDark": "#8A5522",
    "Pearl": "#FFF6E0", "GemRed": "#E8262B", "GemBlue": "#2F7BFF", "HotMetal": "#FF7A1A",
    "SpaceBar": "#1B1F4B", "GasA": "#7B4DFF", "GasB": "#B79BFF", "GasC": "#FF7EC8",
    "RingA": "#FFD27E", "RingB": "#FF9BD6", "MoonIce": "#8DF4FF", "MoonLava": "#FF8A3D",
    "Ocean": "#2F7BFF", "Land": "#3FCF5A", "Ice": "#F4FBFF", "Moon": "#C9CCD6",
}
M = {k: mat(k, v, rough=0.3) for k, v in COL.items()}
SIDES = 20


def box(name, size, center, m, coll, rot=None):
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    bmesh.ops.scale(bm, vec=Vector(size), verts=bm.verts[:])
    if rot is not None:
        bmesh.ops.transform(bm, matrix=rot, verts=bm.verts[:])
    return _obj(name, bm, m, coll, center, smooth=False)


def bar(coll, p, h, m, L=4.2):
    """A proper barbell bar: shaft, end caps, collars inside the weights and dark hand grips."""
    lathe(p + "Bar", [(-L, 0.17), (L, 0.17)], 12, m, coll, axis='Y', center=(0, 0, h))
    for s in (1, -1):
        a, b = sorted((s * L, s * (L + 0.35)))
        lathe(p + f"End{s}", [(a, 0.28), (b, 0.28)], 12, m, coll, axis='Y', center=(0, 0, h))
        a, b = sorted((s * 1.42, s * 1.68))
        lathe(p + f"Collar{s}", [(a, 0.31), (b, 0.31)], 12, m, coll, axis='Y', center=(0, 0, h))
        a, b = sorted((s * 0.3, s * 1.2))
        lathe(p + f"Grip{s}", [(a, 0.205), (b, 0.205)], 12, M["Grip"], coll, axis='Y', center=(0, 0, h))


def annulus(name, r0, r1, t, sides, m, coll, mtx):
    """Flat ring (washer shape), placed with a matrix."""
    bm = bmesh.new()
    def ring(r, z):
        return [bm.verts.new((r * math.cos(2 * math.pi * i / sides), r * math.sin(2 * math.pi * i / sides), z))
                for i in range(sides)]
    a, b, c2, d = ring(r0, -t / 2), ring(r1, -t / 2), ring(r1, t / 2), ring(r0, t / 2)
    for i in range(sides):
        j = (i + 1) % sides
        for q0, q1 in ((a, b), (b, c2), (c2, d), (d, a)):
            bm.faces.new((q0[i], q0[j], q1[j], q1[i]))
    bmesh.ops.transform(bm, matrix=mtx, verts=bm.verts[:])
    return _obj(name, bm, m, coll, (0, 0, 0), smooth=False)


# ---------------- tiers ----------------
def t_marshmallow(c, p):
    """Marshmallows on a wooden roasting stick: puffy white + pink, toasted ends."""
    R, Lm, h, y0 = 1.0, 1.2, 1.03, 1.7
    lathe(p + "Stick", [(-4.75, 0.13), (4.35, 0.13), (4.9, 0.02)], 8, M["Wood"], c, axis='Y', center=(0, 0, h))

    def mirrored(prof, s):
        prof = [(s * a, r) for a, r in prof]
        return prof if s > 0 else prof[::-1]

    for s in (1, -1):
        for i, m in enumerate(("Marshmallow", "MarshPink")):
            y = y0 + i * (Lm + 0.1)
            puff = [(0, 0.45), (0.06, 0.78), (0.2, 0.95), (0.45, 1.0), (Lm / 2, 1.03),
                    (Lm - 0.45, 1.0), (Lm - 0.2, 0.95), (Lm - 0.06, 0.78), (Lm, 0.45)]
            lathe(p + f"Marsh{i}_{s}", mirrored([(y + a, r * R) for a, r in puff], s), 14, M[m], c,
                  axis='Y', center=(0, 0, h))
        ye = y0 + 2 * Lm + 0.1      # outer end: toasted cap with a darker centre
        lathe(p + f"Toast_{s}", mirrored([(ye - 0.2, 0.975 * R), (ye - 0.06, 0.805 * R), (ye + 0.025, 0.47 * R),
                                          (ye + 0.03, 0.0)], s), 14, M["Toast"], c, axis='Y', center=(0, 0, h))
        lathe(p + f"ToastSpot_{s}", mirrored([(ye + 0.03, 0.3 * R), (ye + 0.05, 0.22 * R), (ye + 0.055, 0.0)], s), 14,
              M["ToastDark"], c, axis='Y', center=(0, 0, h))


def t_donut(c, p):
    h, R, r = 1.2, 0.78, 0.42
    bar(c, p, h, M["Bar"])
    cols = ["SprinkleY", "SprinkleB", "SprinkleG", "SprinkleW"]
    for s in (1, -1):
        for i in range(2):
            y = s * (2.6 + i * 0.85)
            torus(p + f"Dough{i}_{s}", R, r, M["Dough"], c, axis='Y', center=(0, y, h), seg=20, ring=10)
            yi = y + s * 0.12
            torus(p + f"Icing{i}_{s}", R, 0.4, M["Icing"], c, axis='Y', center=(0, yi, h), seg=20, ring=10, squash=0.75)
            # sprinkles on the outer (visible) icing face, one object per colour
            bms = {k: bmesh.new() for k in cols}
            for _ in range(46):
                a = random.uniform(0, 2 * math.pi)
                b = random.uniform(0.25, 1.35)
                rr = R + 0.4 * math.cos(b)
                n = Vector((math.cos(b) * math.cos(a), s * math.sin(b), math.cos(b) * math.sin(a))).normalized()
                pos = Vector((rr * math.cos(a), yi + s * 0.4 * 0.75 * math.sin(b), h + rr * math.sin(a))) + n * 0.03
                t1 = n.cross(Vector((0, 0, 1)) if abs(n.z) < 0.9 else Vector((1, 0, 0))).normalized()
                ang = random.uniform(0, math.pi)
                tang = (t1 * math.cos(ang) + n.cross(t1) * math.sin(ang)).normalized()
                bt = n.cross(tang)
                mtx = Matrix((tang, bt, n)).transposed().to_4x4()
                bm = bms[random.choice(cols)]
                g = bmesh.ops.create_cube(bm, size=1.0)
                bmesh.ops.scale(bm, vec=(0.22, 0.06, 0.06), verts=g["verts"])
                bmesh.ops.transform(bm, matrix=Matrix.Translation(pos) @ mtx, verts=g["verts"])
            for k, bm in bms.items():
                _obj(p + f"Sprinkles{i}{k}_{s}", bm, M[k], c, (0, 0, 0), smooth=False)


def t_watermelon(c, p):
    h, R, L, y0 = 1.35, 1.35, 1.25, 2.25
    bar(c, p, h, M["Bar"])
    for s in (1, -1):
        prof = [(y0 + L * (1 - math.cos(t)), R * math.sin(t) + 0.02)
                for t in (math.pi / 2 * k / 8 for k in range(9))]
        prof = [(s * yy, rr) for yy, rr in prof]
        o = lathe(p + f"Rind_{s}", prof if s > 0 else prof[::-1], SIDES, M["Rind"], c, axis='Y', center=(0, 0, h))
        o.data.materials.append(M["RindStripe"])
        for f in o.data.polygons:
            ang = math.atan2(f.center.z - h, f.center.x)
            if abs(f.center.y) < y0 + L - 0.02:
                f.material_index = int(((ang + math.pi) / (2 * math.pi)) * SIDES) % 2
        face = y0 + L
        for nm, rad, d0, d1, m in (("RindIn", R * 0.97, 0.0, 0.03, "RindIn"), ("Flesh", R * 0.86, 0.0, 0.06, "Flesh")):
            pr = [(s * (face + d0), rad), (s * (face + d1), rad)]
            lathe(p + f"{nm}_{s}", pr if s > 0 else pr[::-1], SIDES, M[m], c, axis='Y', center=(0, 0, h))
        bm = bmesh.new()
        for k in range(12):
            a = 2 * math.pi * k / 12 + random.uniform(-0.15, 0.15)
            rr = R * random.uniform(0.4, 0.66)
            g = bmesh.ops.create_icosphere(bm, subdivisions=1, radius=0.09)
            bmesh.ops.scale(bm, vec=(1.0, 0.35, 1.6), verts=g["verts"])
            bmesh.ops.rotate(bm, verts=g["verts"], cent=Vector(), matrix=Matrix.Rotation(-a + math.pi / 2, 3, 'Y'))
            bmesh.ops.translate(bm, verts=g["verts"], vec=(rr * math.cos(a), s * (face + 0.07), h + rr * math.sin(a)))
        _obj(p + f"Seeds_{s}", bm, M["Seed"], c, (0, 0, 0), smooth=False)


def t_egg(c, p):
    H, W = 2.9, 1.05
    bar(c, p, H * 0.42, M["Bar"])
    for s in (1, -1):
        prof = [(0, 0.02)] + [(H * u, W * 2 * math.sqrt(u * (1 - u)) * (1.1 - 0.3 * u))
                              for u in (k / 14 for k in range(1, 14))] + [(H, 0.02)]
        lathe(p + f"Egg_{s}", prof, SIDES, M["Gold"], c, axis='Z', center=(0, s * 3.0, 0))
        # jewelled egg: two pearl bands, a ring of red + blue gems, a pearl on top
        r_at = lambda u: W * 2 * math.sqrt(u * (1 - u)) * (1.1 - 0.3 * u)
        for bi, u in enumerate((0.26, 0.64)):
            z = H * u
            lathe(p + f"Band{bi}_{s}", [(z - 0.07, r_at(u - 0.024) + 0.035), (z + 0.07, r_at(u + 0.024) + 0.035)],
                  SIDES, M["Pearl"], c, axis='Z', center=(0, s * 3.0, 0))
        gems = {"GemRed": bmesh.new(), "GemBlue": bmesh.new()}
        for k in range(8):
            a = 2 * math.pi * k / 8 + math.pi / 8
            rr = r_at(0.64) + 0.06
            bm = gems["GemRed" if k % 2 else "GemBlue"]
            g = bmesh.ops.create_icosphere(bm, subdivisions=1, radius=0.17)
            bmesh.ops.scale(bm, vec=(1, 1, 1.25), verts=g["verts"])
            bmesh.ops.translate(bm, verts=g["verts"], vec=(rr * math.cos(a), s * 3.0 + rr * math.sin(a), H * 0.64))
        for k, bm in gems.items():
            _obj(p + f"Gems{k}_{s}", bm, M[k], c, (0, 0, 0), smooth=False)
        bm = bmesh.new()
        bmesh.ops.create_icosphere(bm, subdivisions=1, radius=0.17)
        _obj(p + f"Tip_{s}", bm, M["Pearl"], c, (0, s * 3.0, H + 0.06), smooth=False)


def t_anvil(c, p):
    bar(c, p, 1.45, M["Bar"])
    for s in (1, -1):
        y = s * 2.9
        box(p + f"Base_{s}", (1.7, 1.0, 0.45), (0, y, 0.225), M["Anvil"], c)
        box(p + f"Waist_{s}", (0.9, 0.65, 0.6), (0, y, 0.75), M["Anvil"], c)
        box(p + f"Top_{s}", (2.0, 1.0, 0.6), (0, y, 1.35), M["Anvil"], c)
        bm = bmesh.new()
        bmesh.ops.create_cone(bm, cap_ends=True, segments=8, radius1=0.32, radius2=0.02, depth=1.1)
        bmesh.ops.rotate(bm, verts=bm.verts[:], cent=Vector(), matrix=Matrix.Rotation(math.radians(-90), 3, 'Y'))
        _obj(p + f"Horn_{s}", bm, M["Anvil"], c, (1.55, y, 1.45), smooth=False)
        box(p + f"Ingot_{s}", (1.25, 0.34, 0.22), (-0.15, y, 1.76), M["HotMetal"], c)   # red-hot bar being forged


def t_diamond(c, p):
    # classic cut gem standing on its point, bar through the girdle
    bar(c, p, 1.25, M["Chrome"])
    for s in (1, -1):
        prof = [(0.0, 0.0), (1.15, 1.25), (1.32, 1.25), (1.7, 0.92), (1.85, 0.62)]
        lathe(p + f"Gem_{s}", prof, 8, M["Diamond"], c, axis='Z', center=(0, s * 3.0, 0))


def t_trophy(c, p):
    h = 2.05
    bar(c, p, h, M["BarGold"])
    for s in (1, -1):
        y = s * 3.1
        box(p + f"Base_{s}", (1.5, 1.5, 0.4), (0, y, 0.2), M["TrophyBase"], c)
        lathe(p + f"Stem_{s}", [(0.4, 0.55), (0.6, 0.45), (0.75, 0.2), (1.1, 0.16), (1.2, 0.3), (1.3, 0.2)],
              SIDES, M["TrophyGold"], c, axis='Z', center=(0, y, 0))
        lathe(p + f"Cup_{s}", [(1.3, 0.25), (1.55, 0.72), (1.95, 0.98), (2.5, 1.1), (2.62, 1.18), (2.7, 1.1)],
              SIDES, M["TrophyGold"], c, axis='Z', center=(0, y, 0))
        for sx in (1, -1):
            o = torus(p + f"Handle{sx}_{s}", 0.38, 0.1, M["TrophyGold"], c, axis='Y', center=(0, 0, 0), seg=14, ring=6)
            o.data.transform(Matrix.Translation((sx * 1.15, y, 2.15)))


def t_rocket(c, p):
    h = 1.7
    bar(c, p, h, M["BarGold"])
    for s in (1, -1):
        y = s * 3.1
        lathe(p + f"Nozzle_{s}", [(0.3, 0.42), (0.6, 0.3)], 12, M["Nozzle"], c, axis='Z', center=(0, y, 0))
        lathe(p + f"Body_{s}", [(0.6, 0.6), (2.7, 0.62)], SIDES, M["RocketBody"], c, axis='Z', center=(0, y, 0))
        lathe(p + f"Band_{s}", [(2.0, 0.65), (2.25, 0.65)], SIDES, M["RocketRed"], c, axis='Z', center=(0, y, 0))
        lathe(p + f"Nose_{s}", [(2.7, 0.62), (3.3, 0.45), (3.75, 0.15), (3.85, 0.0)], SIDES, M["RocketRed"], c,
              axis='Z', center=(0, y, 0))
        for k in range(4):
            a = math.pi / 4 + k * math.pi / 2
            rot = Matrix.Rotation(a, 4, 'Z')
            bm = bmesh.new()
            vs = [bm.verts.new(v) for v in [(0.45, -0.05, 0.0), (1.25, -0.05, 0.0), (0.45, -0.05, 1.5),
                                            (0.45, 0.05, 0.0), (1.25, 0.05, 0.0), (0.45, 0.05, 1.5)]]
            bm.faces.new((vs[0], vs[1], vs[2])); bm.faces.new((vs[5], vs[4], vs[3]))
            bm.faces.new((vs[0], vs[3], vs[4], vs[1])); bm.faces.new((vs[1], vs[4], vs[5], vs[2]))
            bm.faces.new((vs[2], vs[5], vs[3], vs[0]))
            bmesh.ops.transform(bm, matrix=rot, verts=bm.verts[:])
            _obj(p + f"Fin{k}_{s}", bm, M["RocketRed"], c, (0, y, 0), smooth=False)
        for sx in (1, -1):   # round window front and back
            bm = bmesh.new()
            bmesh.ops.create_circle(bm, cap_ends=True, segments=12, radius=0.24)
            g = bmesh.ops.extrude_face_region(bm, geom=bm.faces[:])
            bmesh.ops.translate(bm, vec=(0, 0, 0.06), verts=[e for e in g["geom"] if isinstance(e, bmesh.types.BMVert)])
            bmesh.ops.rotate(bm, verts=bm.verts[:], cent=Vector(), matrix=Matrix.Rotation(math.radians(90 * sx), 3, 'Y'))
            _obj(p + f"Window{sx}_{s}", bm, M["RocketWindow"], c, (sx * 0.6, y, 2.45), smooth=False)


def t_soccer(c, p):
    Rb, h = 1.45, 1.45
    bar(c, p, h, M["BarGold"])
    for s in (1, -1):
        bm = bmesh.new()
        bmesh.ops.create_icosphere(bm, subdivisions=0, radius=1.0)
        res = bmesh.ops.bevel(bm, geom=bm.verts[:], offset=33.3, offset_type='PERCENT', affect='VERTICES')
        pent = set(res["faces"])
        for v in bm.verts:
            v.co = v.co.normalized() * Rb
        me = bpy.data.meshes.new(p + f"Ball_{s}")
        for f in bm.faces:
            f.material_index = 1 if f in pent else 0
        bmesh.ops.translate(bm, vec=(0, s * 3.2, h), verts=bm.verts[:])
        bm.to_mesh(me); bm.free()
        me.materials.append(M["BallGold"]); me.materials.append(M["BallBlack"])
        o = bpy.data.objects.new(p + f"Ball_{s}", me); c.objects.link(o)


def t_planets(c, p):
    """Top tier. A ringed gas giant on one end, an Earth on the other. Parts named Orb* are moons /
    a tiny rocket placed ON their orbit; a Studio script makes them circle the planet."""
    h, Y, Rp = 1.3, 3.6, 1.25
    bar(c, p, h, M["SpaceBar"], L=4.9)

    def on_orbit(center, R, tau, phi):
        # orbit plane tilted about X (the axis across the bar), so orbits never cut through the bar
        n = Vector((0, math.sin(tau), math.cos(tau)))
        e1 = Vector((1, 0, 0)); e2 = n.cross(e1)
        return center + R * (math.cos(phi) * e1 + math.sin(phi) * e2), (-math.sin(phi) * e1 + math.cos(phi) * e2)

    def ball(name, pos, r, m, sub=1):
        bm = bmesh.new()
        bmesh.ops.create_icosphere(bm, subdivisions=sub, radius=r)
        return _obj(name, bm, m, c, tuple(pos), smooth=False)

    # --- gas giant with two-tone ring and two moons ---
    s = 1
    C1 = Vector((0, s * Y, h))
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=16, v_segments=9, radius=Rp)
    o = _obj(p + f"Globe_{s}", bm, M["GasA"], c, tuple(C1), smooth=False)
    o.data.materials.append(M["GasB"]); o.data.materials.append(M["GasC"])
    pattern = [0, 0, 1, 0, 2, 0, 1, 0, 0]
    for f in o.data.polygons:
        band = min(8, max(0, int(((f.center.z - h) / Rp + 1) / 2 * 9)))
        f.material_index = pattern[band]
    tilt = Matrix.Translation(C1) @ Matrix.Rotation(-math.radians(25), 4, 'X')
    annulus(p + f"RingIn_{s}", 1.58, 1.84, 0.07, 24, M["RingA"], c, tilt)
    annulus(p + f"RingOut_{s}", 1.92, 2.15, 0.07, 24, M["RingB"], c, tilt)
    pos, _ = on_orbit(C1, 2.55, math.radians(-18), math.radians(70))
    ball(p + f"OrbIce_{s}", pos, 0.36, M["MoonIce"])
    pos, _ = on_orbit(C1, 2.9, math.radians(-18), math.radians(215))
    ball(p + f"OrbLava_{s}", pos, 0.28, M["MoonLava"])

    # --- Earth with a moon and a tiny rocket in orbit ---
    s = -1
    C2 = Vector((0, s * Y, h))
    bm = bmesh.new()
    bmesh.ops.create_icosphere(bm, subdivisions=3, radius=Rp)
    o = _obj(p + f"Globe_{s}", bm, M["Ocean"], c, tuple(C2), smooth=False)
    o.data.materials.append(M["Land"]); o.data.materials.append(M["Ice"])
    for f in o.data.polygons:
        d = (Vector(f.center) - C2).normalized()
        land = (math.sin(d.x * 4.3 + 0.7) * math.cos(d.z * 3.1 + 0.4) + math.sin(d.y * 3.7 + 2.0) * math.cos(d.x * 2.9)
                + 0.6 * math.sin((d.y + d.z) * 6.0))
        f.material_index = 2 if abs(d.z) > 0.88 else (1 if land > 0.55 else 0)
    pos, _ = on_orbit(C2, 2.3, math.radians(20), math.radians(250))
    ball(p + f"OrbMoon_{s}", pos, 0.38, M["Moon"])
    pos, tan = on_orbit(C2, 1.85, math.radians(-30), math.radians(60))
    aim = Matrix.Translation(pos) @ Vector((0, 0, 1)).rotation_difference(tan).to_matrix().to_4x4()
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, segments=8, radius1=0.19, radius2=0.19, depth=0.6)
    bmesh.ops.transform(bm, matrix=aim, verts=bm.verts[:])
    _obj(p + f"OrbSatBody_{s}", bm, M["RocketBody"], c, (0, 0, 0), smooth=False)
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, segments=8, radius1=0.19, radius2=0.0, depth=0.36)
    bmesh.ops.transform(bm, matrix=aim @ Matrix.Translation((0, 0, 0.48)), verts=bm.verts[:])
    for k in range(3):     # three little fins at the tail
        fin = bmesh.ops.create_cube(bm, size=1.0)
        bmesh.ops.scale(bm, vec=(0.3, 0.05, 0.26), verts=fin["verts"])
        bmesh.ops.transform(bm, verts=fin["verts"],
                            matrix=aim @ Matrix.Rotation(2 * math.pi * k / 3, 4, 'Z') @ Matrix.Translation((0.22, 0, -0.22)))
    _obj(p + f"OrbSatNose_{s}", bm, M["RocketRed"], c, (0, 0, 0), smooth=False)


TIERS = [("Marshmallow", t_marshmallow), ("Donut", t_donut), ("Watermelon", t_watermelon), ("GoldenEgg", t_egg),
         ("Anvil", t_anvil), ("Diamond", t_diamond), ("Trophy", t_trophy), ("Rocket", t_rocket),
         ("SoccerBall", t_soccer), ("Planets", t_planets)]


def split_by_material(o):
    """One object per material, named <name>__<Material> (Roblox: one colour per MeshPart)."""
    me = o.data
    used = sorted(set(f.material_index for f in me.polygons))
    out = []
    for mi in used:
        bm = bmesh.new(); bm.from_mesh(me)
        bmesh.ops.delete(bm, geom=[f for f in bm.faces if f.material_index != mi], context='FACES')
        bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context='VERTS')
        m2 = bpy.data.meshes.new(o.name)
        bm.to_mesh(m2); bm.free()
        m2.materials.append(me.materials[mi])
        o2 = bpy.data.objects.new(f"{o.name}__{me.materials[mi].name}", m2)
        for cc in o.users_collection: cc.objects.link(o2)
        out.append(o2)
    bpy.data.objects.remove(o, do_unlink=True)
    return out


rot = Matrix.Rotation(math.radians(-90), 4, 'Z')     # bar along X
GAP = 7.0
allobjs = []
for i, (name, fn) in enumerate(TIERS):
    c = collection(f"Weight{i + 1}_{name}")
    fn(c, f"Weight{i + 1}_{name}_")
    for o in list(c.objects):
        o.data.transform(rot)
        o.data.transform(Matrix.Translation((0, -i * GAP, 0)))
        for f in o.data.polygons:
            f.use_smooth = False
        allobjs += split_by_material(o)
    tris = sum(sum(len(pp.vertices) - 2 for pp in o.data.polygons) for o in c.objects)
    print("TIER", i + 1, name, "parts", len(c.objects), "tris", tris)

# ---------------- preview ----------------
sc = bpy.context.scene
dm = mat("Dummy", "#9AA3B5", rough=0.6)
for size, loc in [((2, 1, 2), (0, 0, 3)), ((1.1, 1.1, 1.1), (0, 0, 4.55)), ((0.95, 1, 2), (-0.5, 0, 1)),
                  ((0.95, 1, 2), (0.5, 0, 1)), ((0.95, 1, 2), (-1.5, 0, 3)), ((0.95, 1, 2), (1.5, 0, 3))]:
    bpy.ops.mesh.primitive_cube_add(size=1, location=(loc[0] - 7.5, loc[1] + 2, loc[2]))
    o = bpy.context.active_object; o.scale = size; o.data.materials.append(dm)
bpy.ops.mesh.primitive_plane_add(size=260, location=(0, -32, 0))
bpy.context.active_object.data.materials.append(mat("Ground", "#D9DEE6", rough=0.8))
sun = bpy.data.objects.new("Sun", bpy.data.lights.new("Sun", 'SUN')); sun.data.energy = 3.5
sun.rotation_euler = (math.radians(50), 0, math.radians(-30)); sc.collection.objects.link(sun)
sc.world = bpy.data.worlds.new("W"); sc.world.use_nodes = True
sc.world.node_tree.nodes["Background"].inputs["Color"].default_value = (0.75, 0.82, 0.92, 1)
cam = bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam")); sc.collection.objects.link(cam)
sc.camera = cam
sc.render.engine = 'CYCLES'; sc.cycles.device = 'CPU'; sc.cycles.samples = 32; sc.cycles.use_denoising = True
sc.render.resolution_x = 1600; sc.render.resolution_y = 1000
bpy.ops.wm.save_as_mainfile(filepath=blend_out)


def shot(path, tgt, off, lens):
    cam.data.lens = lens
    cam.location = Vector(tgt) + Vector(off)
    cam.rotation_euler = (Vector(tgt) - cam.location).to_track_quat('-Z', 'Y').to_euler()
    sc.render.filepath = path
    bpy.ops.render.render(write_still=True)


shot(png_out, (-1, -31, 0.8), (38, 29, 27), 32)
shot(png_out.replace(".png", "_low.png"), (0, -1.5, 1.2), (11, 9, 7), 40)     # marshmallow
shot(png_out.replace(".png", "_mid.png"), (0, -24.5, 1.4), (12, 9, 7), 40)    # egg + anvil
shot(png_out.replace(".png", "_top.png"), (0, -62, 1.5), (12, 10, 7), 40)     # planets

mk = mat("Marker", "#FF00FF")
for nm, loc in (("SOA_AxisO", (0, 0, 0)), ("SOA_AxisUp", (0, 0, 3)), ("SOA_AxisFwd", (0, 3, 0))):
    bpy.ops.mesh.primitive_cube_add(size=0.2, location=loc)
    o = bpy.context.active_object; o.name = nm; o.data.materials.append(mk); allobjs.append(o)
bpy.ops.object.select_all(action='DESELECT')
for o in allobjs: o.select_set(True)
bpy.context.view_layer.objects.active = allobjs[0]
bpy.ops.export_scene.fbx(filepath=fbx_out, use_selection=True, object_types={'MESH'},
                         apply_unit_scale=True, mesh_smooth_type='FACE', axis_forward='-Z', axis_up='Y')
print("DONE")
