"""Joke weight tiers for Score on Animals. Normal Roblox quality: simple, low-poly, plain colours
(pigeon: "not too high quality, just a normal weight, maybe with marshmallows as a joke, then it
gets different"). One barbell per tier, same plain bar, the plates change:
  1 Marshmallow  2 Donut  3 Watermelon  4 Golden Egg  5 Anvil
1 unit = 1 stud. Each tier lies on the ground, bar along X, bar centre above its own origin.
Objects are named Weight<N>_<Tier>_<Part> so Studio can split them into one model per tier.

blender -b --factory-startup -P weights.py -- <out.blend> <out.fbx> <render.png>
"""
import bpy, sys, math, bmesh
from mathutils import Matrix, Vector

argv = sys.argv[sys.argv.index("--") + 1:]
blend_out, fbx_out, png_out = argv
ns = {}
exec(open(r"C:\Users\ortho\HomeRunToTheMoon\models\item_kit.py").read(), ns)
lathe, torus, mat, collection, _obj = ns["lathe"], ns["torus"], ns["mat"], ns["collection"], ns["_obj"]
bpy.ops.wm.read_factory_settings(use_empty=True)

M = {
    "bar": mat("Bar", "#8C8F99", rough=0.4, metal=0.3),
    "marsh": mat("Marshmallow", "#FFF4EA", rough=0.6),
    "dough": mat("Dough", "#E3A35A", rough=0.5),
    "icing": mat("Icing", "#FF7EB6", rough=0.35),
    "melon": mat("Melon", "#4CC046", rough=0.4),
    "melon_dk": mat("MelonStripe", "#1E6B22", rough=0.4),
    "gold": mat("Gold", "#F7C440", rough=0.25, metal=0.5),
    "anvil": mat("Anvil", "#3A3D46", rough=0.45, metal=0.3),
    "bar_gold": mat("BarGold", "#F7C440", rough=0.25, metal=0.5),
    "bar_dark": mat("BarDark", "#2A2A30", rough=0.4, metal=0.3),
    "crystal": mat("Crystal", "#5BE7FF", rough=0.1),
    "rock": mat("Rock", "#2B201C", rough=0.7),
    "lava": mat("Lava", "#FF6A1A", rough=0.4),
    "planet": mat("Planet", "#7B4DFF", rough=0.35),
    "ring": mat("Ring", "#FF5FD8", rough=0.3),
    "sun": mat("Sun", "#FFD23A", rough=0.3),
    "flare": mat("Flare", "#FF8A00", rough=0.3),
}
# glowing parts render bright in the preview (in Studio they get Neon material)
for k in ("lava", "ring", "sun", "flare"):
    bs = M[k].node_tree.nodes["Principled BSDF"]
    bs.inputs["Emission Color"].default_value = bs.inputs["Base Color"].default_value
    bs.inputs["Emission Strength"].default_value = 2.0
SIDES = 14   # low-poly on purpose


def box(name, size, center, m, coll):
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    bmesh.ops.scale(bm, vec=Vector(size), verts=bm.verts[:])
    return _obj(name, bm, m, coll, center, smooth=False)


def bar(coll, prefix, h, m=None):
    m = m or M["bar"]
    lathe(prefix + "Bar", [(-4.2, 0.16), (4.2, 0.16)], 10, m, coll, axis='Y', center=(0, 0, h))
    for s in (1, -1):
        a, b = sorted((s * 4.2, s * 4.5))
        lathe(prefix + f"End{s}", [(a, 0.26), (b, 0.26)], 10, m, coll, axis='Y', center=(0, 0, h))


def tier_marshmallow(coll, p):
    R, t, h = 1.05, 0.95, 1.05
    bar(coll, p, h)
    for s in (1, -1):
        for i in range(2):
            y0 = 2.3 + i * (t + 0.08)
            prof = [(0, R - 0.25), (0.15, R - 0.03), (0.3, R), (t - 0.3, R), (t - 0.15, R - 0.03), (t, R - 0.25)]
            prof = [(s * (y0 + a), r) for a, r in prof]
            lathe(p + f"Marsh{i}_{s}", prof if s > 0 else prof[::-1], SIDES, M["marsh"], coll, axis='Y', center=(0, 0, h))


def tier_donut(coll, p):
    h = 1.2
    bar(coll, p, h)
    for s in (1, -1):
        for i in range(2):
            y = s * (2.6 + i * 0.85)
            torus(p + f"Dough{i}_{s}", 0.78, 0.42, M["dough"], coll, axis='Y', center=(0, y, h), seg=14, ring=8)
            torus(p + f"Icing{i}_{s}", 0.78, 0.4, M["icing"], coll, axis='Y', center=(0, y + s * 0.12, h),
                  seg=14, ring=8, squash=0.75)


def tier_watermelon(coll, p):
    h, R, L = 1.3, 1.3, 1.9
    bar(coll, p, h)
    for s in (1, -1):
        prof = [(0, 0.15)] + [(L / 2 - L / 2 * math.cos(math.pi * k / 6), R * math.sin(math.pi * k / 6) + 0.05)
                              for k in range(1, 6)] + [(L, 0.15)]
        prof = [(s * (2.3 + a), r) for a, r in prof]
        o = lathe(p + f"Melon_{s}", prof if s > 0 else prof[::-1], SIDES, M["melon"], coll, axis='Y', center=(0, 0, h))
        # dark stripes: every other column of faces around the melon
        o.data.materials.append(M["melon_dk"])
        for f in o.data.polygons:
            c = f.center
            ang = math.atan2(c.z - h, c.x)
            f.material_index = int(((ang + math.pi) / (2 * math.pi)) * SIDES + 0.5) % 2


def tier_egg(coll, p):
    H, W = 2.9, 1.05      # standing eggs, the bar goes through their widest part
    h = H * 0.42
    bar(coll, p, h)
    for s in (1, -1):
        # egg = ellipse that gets a bit narrower toward the top (blunt, not pointy)
        prof = [(0, 0.02)] + [(H * u, W * 2 * math.sqrt(u * (1 - u)) * (1.1 - 0.3 * u))
                              for u in (k / 12 for k in range(1, 12))] + [(H, 0.02)]
        lathe(p + f"Egg_{s}", prof, SIDES, M["gold"], coll, axis='Z', center=(0, s * 3.0, 0))


def tier_anvil(coll, p):
    h = 1.45
    bar(coll, p, h)
    for s in (1, -1):
        y = s * 2.9
        box(p + f"Base_{s}", (1.7, 1.0, 0.45), (0, y, 0.225), M["anvil"], coll)
        box(p + f"Waist_{s}", (0.9, 0.65, 0.6), (0, y, 0.75), M["anvil"], coll)
        box(p + f"Top_{s}", (2.0, 1.0, 0.6), (0, y, 1.35), M["anvil"], coll)
        # horn pointing forward
        bm = bmesh.new()
        bmesh.ops.create_cone(bm, cap_ends=True, segments=8, radius1=0.32, radius2=0.02, depth=1.1)
        bmesh.ops.rotate(bm, verts=bm.verts[:], cent=Vector(), matrix=Matrix.Rotation(math.radians(-90), 3, 'Y'))
        _obj(p + f"Horn_{s}", bm, M["anvil"], coll, (1.55, y, 1.45), smooth=False)


import random
random.seed(7)


def ico(name, radius, center, m, coll, subdiv=1, scale=(1, 1, 1), jitter=0.0):
    bm = bmesh.new()
    bmesh.ops.create_icosphere(bm, subdivisions=subdiv, radius=radius)
    if jitter:
        for v in bm.verts:
            v.co *= 1 + random.uniform(-jitter, jitter)
    bmesh.ops.scale(bm, vec=Vector(scale), verts=bm.verts[:])
    return _obj(name, bm, m, coll, center, smooth=False)


def tier_crystal(coll, p):
    h = 1.6
    bar(coll, p, h, M["bar_gold"])
    for s in (1, -1):
        ico(p + f"Gem_Glass_{s}", 1.15, (0, s * 3.0, h), M["crystal"], coll, subdiv=0, scale=(1.05, 1.05, 1.4))
        for k, (dx, dz) in enumerate([(0.85, -1.0), (-0.85, -1.0)]):
            ico(p + f"Shard{k}_Glass_{s}", 0.42, (dx, s * 3.0, h + dz + 0.05), M["crystal"], coll, subdiv=0,
                scale=(1, 1, 1.7))


def tier_lava(coll, p):
    h = 1.35
    bar(coll, p, h, M["bar_dark"])
    for s in (1, -1):
        ico(p + f"Core_Neon_{s}", 1.1, (0, s * 3.0, h), M["lava"], coll, subdiv=1)   # pokes out as cracks
        ico(p + f"Rock_{s}", 1.32, (0, s * 3.0, h), M["rock"], coll, subdiv=1, jitter=0.22)


def tier_planet(coll, p):
    h = 1.6
    bar(coll, p, h, M["bar_gold"])
    for s in (1, -1):
        bm = bmesh.new()
        bmesh.ops.create_uvsphere(bm, u_segments=14, v_segments=9, radius=1.25)
        _obj(p + f"Planet_{s}", bm, M["planet"], coll, (0, s * 3.0, h), smooth=False)
        o = torus(p + f"Ring_Neon_{s}", 1.85, 0.13, M["ring"], coll, axis='Z', center=(0, 0, 0),
                  seg=24, ring=4, squash=0.35)
        o.data.transform(Matrix.Rotation(math.radians(28 * s), 4, 'X'))
        o.data.transform(Matrix.Translation((0, s * 3.0, h)))
        for f in o.data.polygons: f.use_smooth = False


def tier_sun(coll, p):
    h = 1.7
    bar(coll, p, h, M["bar_gold"])
    for s in (1, -1):
        c = Vector((0, s * 3.1, h))
        ico(p + f"Sun_Neon_{s}", 1.1, c, M["sun"], coll, subdiv=1)
        bm = bmesh.new()
        tmp = bmesh.new()
        dirs = [v.co.normalized() for v in bmesh.ops.create_icosphere(tmp, subdivisions=0, radius=1)["verts"]]
        tmp.free()
        for d in dirs:
            cone = bmesh.ops.create_cone(bm, cap_ends=True, segments=5, radius1=0.28, radius2=0.0, depth=0.8)
            vs = cone["verts"]
            rot = Vector((0, 0, 1)).rotation_difference(d).to_matrix().to_4x4()
            bmesh.ops.transform(bm, matrix=Matrix.Translation(d * 1.3) @ rot, verts=vs)
        _obj(p + f"Flares_Neon_{s}", bm, M["flare"], coll, tuple(c), smooth=False)


TIERS = [("Marshmallow", tier_marshmallow), ("Donut", tier_donut), ("Watermelon", tier_watermelon),
         ("GoldenEgg", tier_egg), ("Anvil", tier_anvil), ("Crystal", tier_crystal), ("Lava", tier_lava),
         ("Planet", tier_planet), ("Sun", tier_sun)]
rot = Matrix.Rotation(math.radians(-90), 4, 'Z')     # bar along X
GAP = 7.0
allobjs = []
for i, (name, fn) in enumerate(TIERS):
    c = collection(f"Weight{i + 1}_{name}")
    fn(c, f"Weight{i + 1}_{name}_")
    for o in c.objects:
        o.data.transform(rot)
        o.data.transform(Matrix.Translation((0, -i * GAP, 0)))
        for f in o.data.polygons:      # flat facets, same look as the animals
            f.use_smooth = False
        o.data.update()
        allobjs.append(o)
    tris = sum(sum(len(pp.vertices) - 2 for pp in o.data.polygons) for o in c.objects)
    print("TIER", i + 1, name, "parts", len(c.objects), "tris", tris)

# --- preview lineup with a 5-stud dummy ---
sc = bpy.context.scene
dm = mat("Dummy", "#9AA3B5", rough=0.6)
for nm, size, loc in [("Torso", (2, 1, 2), (0, 0, 3)), ("Head", (1.1, 1.1, 1.1), (0, 0, 4.55)),
                      ("LegL", (0.95, 1, 2), (-0.5, 0, 1)), ("LegR", (0.95, 1, 2), (0.5, 0, 1)),
                      ("ArmL", (0.95, 1, 2), (-1.5, 0, 3)), ("ArmR", (0.95, 1, 2), (1.5, 0, 3))]:
    bpy.ops.mesh.primitive_cube_add(size=1, location=(loc[0] - 7.5, loc[1] + 2, loc[2]))
    o = bpy.context.active_object; o.scale = size; o.data.materials.append(dm)
bpy.ops.mesh.primitive_plane_add(size=200, location=(0, -28, 0))
bpy.context.active_object.data.materials.append(mat("Ground", "#D9DEE6", rough=0.8))
sun = bpy.data.objects.new("Sun", bpy.data.lights.new("Sun", 'SUN')); sun.data.energy = 3.5
sun.rotation_euler = (math.radians(50), 0, math.radians(-30)); sc.collection.objects.link(sun)
sc.world = bpy.data.worlds.new("W"); sc.world.use_nodes = True
sc.world.node_tree.nodes["Background"].inputs["Color"].default_value = (0.75, 0.82, 0.92, 1)
cam = bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam")); sc.collection.objects.link(cam)
cam.data.lens = 32
tgt = Vector((-1, -27, 0.8))
cam.location = tgt + Vector((34, 26, 24))
cam.rotation_euler = (tgt - cam.location).to_track_quat('-Z', 'Y').to_euler()
sc.camera = cam
sc.render.engine = 'CYCLES'; sc.cycles.device = 'CPU'; sc.cycles.samples = 32; sc.cycles.use_denoising = True
sc.render.resolution_x = 1600; sc.render.resolution_y = 1000
sc.render.filepath = png_out
bpy.ops.wm.save_as_mainfile(filepath=blend_out)
bpy.ops.render.render(write_still=True)

# close-up of the top tiers
cam.data.lens = 50
tgt = Vector((0, -49, 1.5)); cam.location = tgt + Vector((15, 11, 9))
cam.rotation_euler = (tgt - cam.location).to_track_quat('-Z', 'Y').to_euler()
sc.render.filepath = png_out.replace(".png", "_top.png")
bpy.ops.render.render(write_still=True)

# axis markers so Studio can undo the importer's rotation exactly
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
