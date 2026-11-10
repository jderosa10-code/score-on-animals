"""Deadlift barbell for Score on Animals (test prop).

Style: what the top Roblox gym sims ship (Gym Star, Power Lifters, Gym Legacy, Muscle Legends):
thick stacks of chunky glossy plates, thin chrome bar, bold caps. Plus our theme: gold collars
and a white paw print on the outer plates. Uses the Home Run to the Moon item_kit helpers.
1 unit = 1 stud. Lies on the ground, bar along X, centre of the bar above the origin.

blender -b --factory-startup -P deadlift.py -- <out.blend> <out.fbx> <render.png>
"""
import bpy, sys, math
from mathutils import Matrix, Vector

argv = sys.argv[sys.argv.index("--") + 1:]
blend_out, fbx_out, png_out = argv
ns = {}
exec(open(r"C:\Users\ortho\HomeRunToTheMoon\models\item_kit.py").read(), ns)
lathe, torus, mat, collection = ns["lathe"], ns["torus"], ns["mat"], ns["collection"]

bpy.ops.wm.read_factory_settings(use_empty=True)
C = collection("Item_Deadlift")

M = {
    "plate":  mat("Plate_Blue", "#1E5BFF", rough=0.22),
    "plate2": mat("Plate_Red", "#E8262B", rough=0.22),
    "white":  mat("White", "#F4F4F2", rough=0.3),
    "chrome": mat("Chrome", "#C9CCD6", rough=0.2, metal=0.7),
    "grip":   mat("Grip", "#2E2E36", rough=0.5),
    "gold":   mat("Gold", "#F7C440", rough=0.25, metal=0.4),
}

R_BIG, T_BIG, R_MED, T_MED = 2.1, 0.5, 1.6, 0.42
AX = R_BIG                      # bar height = big plate radius (plates rest on the ground)
S = 32


def plate(name, y0, t, R, m, side):
    """Chunky plate: flat faces, rounded outer edge. side = +1/-1 (which way is 'out')."""
    e = 0.08
    prof = [(0, 0.45), (0, R - e * 2), (e, R), (t - e, R), (t, R - e * 2), (t, 0.45)]
    prof = [(y0 + side * h, r) for h, r in prof]
    if side < 0:
        prof = prof[::-1]
    return lathe(name, prof, S, m, C, axis='Y', center=(0, 0, AX))


def bar_piece(name, y_from, y_to, r, m, round_end=False):
    prof = [(y_from, r), (y_to, r)]
    if round_end:
        prof = [(y_from, r), (y_to - r * 0.4, r), (y_to, r * 0.6)]
    return lathe(name, prof, 24, m, C, axis='Y', center=(0, 0, AX))


# --- bar ---
bar_piece("Bar", -2.6, 2.6, 0.2, M["chrome"])
for s in (1, -1):
    a, b = sorted((s * 0.7, s * 2.2))
    bar_piece(f"Grip_{s}", a, b, 0.225, M["grip"])

# --- each side: shoulder collar, sleeve, plates, clamp, end cap ---
for s, tag in ((1, "R"), (-1, "L")):
    def rng(a, b):
        return sorted((s * a, s * b))
    bar_piece(f"Shoulder_{tag}", *rng(2.6, 2.85), 0.42, M["gold"])
    bar_piece(f"Sleeve_{tag}", *rng(2.85, 5.25), 0.3, M["chrome"])
    y = 2.9
    for i in range(3):
        plate(f"Plate{i + 1}_{tag}", s * y, T_BIG, R_BIG, M["plate"], s)
        # white stripe ring + silver hub on the outer face of each big plate
        torus(f"Stripe{i + 1}_{tag}", R_BIG - 0.38, 0.07, M["white"], C, axis='Y',
              center=(0, 0, AX), offset=(0, s * (y + T_BIG), 0), seg=32, ring=6, squash=0.35)
        y += T_BIG + 0.04
    plate(f"Plate4_{tag}", s * y, T_MED, R_MED, M["plate2"], s)
    face = y + T_MED
    torus(f"Hub_{tag}", 0.58, 0.12, M["chrome"], C, axis='Y', center=(0, 0, AX), offset=(0, s * face, 0),
          seg=28, ring=6, squash=0.6)
    # paw print (our theme): pad + 4 toes, raised on the red plate's outer face, above the hub
    for k, (x, z, rx, rz) in enumerate([(0, 0.95, 0.3, 0.24), (-0.36, 1.27, 0.12, 0.15), (-0.12, 1.4, 0.12, 0.15),
                                        (0.12, 1.4, 0.12, 0.15), (0.36, 1.27, 0.12, 0.15)]):
        prof = [(face, rx), (face + 0.05, rx), (face + 0.08, rx * 0.8)]
        if s < 0:
            prof = [(-h, r) for h, r in prof]
        o = lathe(f"Paw{k}_{tag}", prof, 16, M["white"], C, axis='Y', center=(x, 0, AX + z), oval=(1, rz / rx))
    bar_piece(f"Clamp_{tag}", *rng(face + 0.02, face + 0.3), 0.48, M["gold"])
    a, b = rng(face + 0.3, face + 0.55)
    if s > 0:
        bar_piece(f"Cap_{tag}", a, b, 0.36, M["gold"], round_end=True)
    else:
        lathe(f"Cap_{tag}", [(a, 0.36 * 0.6), (a + 0.36 * 0.4, 0.36), (b, 0.36)], 24, M["gold"], C,
              axis='Y', center=(0, 0, AX))

# turn so the bar runs along X (Roblox: side to side)
rot = Matrix.Rotation(math.radians(-90), 4, 'Z')
for o in C.objects:
    o.data.transform(rot)
    o.data.update()

tris = sum(sum(len(p.vertices) - 2 for p in o.data.polygons) for o in C.objects)
mn = Vector((min(min((o.matrix_world @ v.co)[k] for v in o.data.vertices) for o in C.objects) for k in range(3)))
mx = Vector((max(max((o.matrix_world @ v.co)[k] for v in o.data.vertices) for o in C.objects) for k in range(3)))
print("DEADLIFT parts", len(C.objects), "tris", tris, "size", tuple(round(a, 2) for a in (mx - mn)))

# --- preview: next to a 5-stud blocky dummy ---
sc = bpy.context.scene
dm = mat("Dummy", "#9AA3B5", rough=0.6)
D = bpy.data.collections.new("Dummy"); sc.collection.children.link(D)
for nm, size, loc in [("Torso", (2, 1, 2), (0, 3, 3)), ("Head", (1.1, 1.1, 1.1), (0, 3, 4.55)),
                      ("LegL", (0.95, 1, 2), (-0.5, 3, 1)), ("LegR", (0.95, 1, 2), (0.5, 3, 1)),
                      ("ArmL", (0.95, 1, 2), (-1.5, 3, 3)), ("ArmR", (0.95, 1, 2), (1.5, 3, 3))]:
    bpy.ops.mesh.primitive_cube_add(size=1, location=(loc[0] - 8, loc[1] - 3, loc[2]))
    o = bpy.context.active_object; o.scale = size; o.name = nm; o.data.materials.append(dm)
    for c in o.users_collection: c.objects.unlink(o)
    D.objects.link(o)
bpy.ops.mesh.primitive_plane_add(size=80, location=(0, 0, 0))
g = bpy.context.active_object; g.data.materials.append(mat("Ground", "#D9DEE6", rough=0.8))
sun = bpy.data.objects.new("Sun", bpy.data.lights.new("Sun", 'SUN')); sun.data.energy = 3.5
sun.rotation_euler = (math.radians(50), 0, math.radians(-30)); sc.collection.objects.link(sun)
sc.world = bpy.data.worlds.new("W"); sc.world.use_nodes = True
sc.world.node_tree.nodes["Background"].inputs["Color"].default_value = (0.75, 0.82, 0.92, 1)
cam = bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam")); sc.collection.objects.link(cam)
cam.data.lens = 40
tgt = Vector((-2.5, 0, 2.2))
cam.location = tgt + Vector((7, -15, 7))
cam.rotation_euler = (tgt - cam.location).to_track_quat('-Z', 'Y').to_euler()
sc.camera = cam
sc.render.engine = 'CYCLES'; sc.cycles.device = 'CPU'; sc.cycles.samples = 48; sc.cycles.use_denoising = True
sc.render.resolution_x = 1400; sc.render.resolution_y = 900
sc.render.filepath = png_out
bpy.ops.wm.save_as_mainfile(filepath=blend_out)
bpy.ops.render.render(write_still=True)
# close-up of the plate face (paw print)
cam.location = Vector((7.5, -5.5, 3.2)); tgt = Vector((5.0, 0, 2.2))
cam.rotation_euler = (tgt - cam.location).to_track_quat('-Z', 'Y').to_euler()
sc.render.filepath = png_out.replace(".png", "_close.png")
bpy.ops.render.render(write_still=True)

# --- FBX: only the barbell ---
bpy.ops.object.select_all(action='DESELECT')
for o in C.objects: o.select_set(True)
bpy.context.view_layer.objects.active = C.objects[0]
bpy.ops.export_scene.fbx(filepath=fbx_out, use_selection=True, object_types={'MESH'},
                         apply_unit_scale=True, mesh_smooth_type='FACE', axis_forward='-Z', axis_up='Y')
print("DONE")
