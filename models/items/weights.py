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


def bar(coll, p, h, m):
    lathe(p + "Bar", [(-4.2, 0.17), (4.2, 0.17)], 12, m, coll, axis='Y', center=(0, 0, h))
    for s in (1, -1):
        a, b = sorted((s * 4.2, s * 4.55))
        lathe(p + f"End{s}", [(a, 0.28), (b, 0.28)], 12, m, coll, axis='Y', center=(0, 0, h))


# ---------------- tiers ----------------
def t_marshmallow(c, p):
    R, t, h = 1.05, 0.95, 1.05
    bar(c, p, h, M["Bar"])
    for s in (1, -1):
        for i in range(2):
            y0 = 2.3 + i * (t + 0.08)
            prof = [(0, R - 0.25), (0.15, R - 0.03), (0.3, R), (t - 0.3, R), (t - 0.15, R - 0.03), (t, R - 0.25)]
            prof = [(s * (y0 + a), r) for a, r in prof]
            lathe(p + f"Marsh{i}_{s}", prof if s > 0 else prof[::-1], SIDES, M["Marshmallow"], c, axis='Y', center=(0, 0, h))


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


TIERS = [("Marshmallow", t_marshmallow), ("Donut", t_donut), ("Watermelon", t_watermelon), ("GoldenEgg", t_egg),
         ("Anvil", t_anvil), ("Diamond", t_diamond), ("Trophy", t_trophy), ("Rocket", t_rocket),
         ("SoccerBall", t_soccer)]


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
bpy.ops.mesh.primitive_plane_add(size=200, location=(0, -28, 0))
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


shot(png_out, (-1, -27, 0.8), (34, 26, 24), 32)
shot(png_out.replace(".png", "_low.png"), (0, -7, 1.2), (14, 10, 8), 40)     # donut + watermelon
shot(png_out.replace(".png", "_top.png"), (0, -49, 1.6), (17, 12, 9), 42)    # diamond..soccer

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
