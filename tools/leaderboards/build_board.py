"""Score for Animals leaderboard board, in the lobby's style: chunky studded wood posts + frame (the stalls' wood),
a dark display panel, a header plank, a purple/white striped awning like the Luck Shop stalls, block feet.
Every piece is its own object named LB_<Piece>__<Material> so Studio can colour it and give it the map's stud texture
(Roblox drops FBX materials). 1 Blender unit = 1 stud; front faces -Y.
blender -b --python-exit-code 1 -P build_board.py -- <out.fbx> <preview.png>"""
import bpy, bmesh, sys, os, math
from mathutils import Vector

out_fbx, out_png = sys.argv[sys.argv.index("--") + 1:][:2]
bpy.ops.wm.read_factory_settings(use_empty=True)
sc = bpy.context.scene

COL = {   # sRGB, matching the Luck Shop stall + lobby
    "Wood": (160, 95, 53), "WoodDark": (124, 73, 41), "Panel": (24, 28, 50), "Purple": (150, 60, 230),
    "White": (255, 235, 255), "Gold": (255, 204, 40),
}
def lin(c): return tuple(((v / 255) / 12.92 if v / 255 <= 0.04045 else (((v / 255) + 0.055) / 1.055) ** 2.4) for v in c)
mats = {}
for k, c in COL.items():
    m = bpy.data.materials.new(k); m.use_nodes = True
    bs = m.node_tree.nodes["Principled BSDF"]; bs.inputs["Base Color"].default_value = (*lin(c), 1); bs.inputs["Roughness"].default_value = 0.6
    mats[k] = m

def block(name, mat, center, size, bevel=0.12):
    bpy.ops.mesh.primitive_cube_add(size=1, location=center)
    o = bpy.context.active_object
    o.name = f"LB_{name}__{mat}"; o.data.name = o.name
    o.scale = size
    bpy.ops.object.transform_apply(scale=True)
    if bevel:
        b = o.modifiers.new("bev", "BEVEL"); b.width = bevel; b.segments = 2; b.limit_method = "ANGLE"
        bpy.ops.object.modifier_apply(modifier="bev")
    o.data.materials.append(mats[mat])
    return o

W, H = 16.0, 20.0           # overall width, height of the post tops
POST = 1.6                   # post thickness
PW, PH = 13.0, 13.2          # display panel
panel_z = 9.0                # panel centre height
# feet + posts
for s, x in (("L", -W / 2 + POST / 2), ("R", W / 2 - POST / 2)):
    block(f"Foot{s}", "WoodDark", (x, 0, 0.6), (POST + 1.2, 3.2, 1.2))
    block(f"Post{s}", "Wood", (x, 0, H / 2), (POST, POST, H))
# frame around the panel
fz0, fz1 = panel_z - PH / 2, panel_z + PH / 2
block("FrameBottom", "Wood", (0, -0.1, fz0 - 0.55), (W - 2 * POST, 1.4, 1.1))
block("FrameTop", "Wood", (0, -0.1, fz1 + 0.55), (W - 2 * POST, 1.4, 1.1))
block("FrameLeft", "WoodDark", (-PW / 2 - 0.35, -0.1, panel_z), (0.7, 1.4, PH + 2.2))
block("FrameRight", "WoodDark", (PW / 2 + 0.35, -0.1, panel_z), (0.7, 1.4, PH + 2.2))
# the display panel (SurfaceGui goes on its front face) and a back board
block("Panel", "Panel", (0, -0.25, panel_z), (PW, 0.5, PH), bevel=0)
block("Back", "WoodDark", (0, 0.35, panel_z), (PW + 1.4, 0.6, PH + 2.2), bevel=0.06)
# header plank above the frame (title SurfaceGui), with gold trim
hz = fz1 + 2.6
block("Header", "Purple", (0, -0.15, hz), (W - 1.0, 1.0, 3.2))
block("HeaderTrimTop", "Gold", (0, -0.2, hz + 1.75), (W - 0.6, 1.1, 0.35), bevel=0.06)
block("HeaderTrimBottom", "Gold", (0, -0.2, hz - 1.75), (W - 0.6, 1.1, 0.35), bevel=0.06)
# striped awning: slanted strips, alternating purple / white, like the stalls
az = H + 0.75         # roof rests on the post tops
strips = 8
sw = (W + 2.0) / strips
for i in range(strips):
    x = -(W + 2.0) / 2 + sw * (i + 0.5)
    o = block(f"Awning{i + 1}", "Purple" if i % 2 == 0 else "White", (x, -1.1, az), (sw, 4.4, 0.45), bevel=0.05)
    o.rotation_euler = (math.radians(18), 0, 0)    # front edge (-Y) down
# scalloped awning edge: little blocks under the front lip
for i in range(strips):
    x = -(W + 2.0) / 2 + sw * (i + 0.5)
    block(f"AwningLip{i + 1}", "Purple" if i % 2 == 0 else "White", (x, -1.1 - 2.2 * math.cos(math.radians(18)), az - 2.2 * math.sin(math.radians(18)) - 0.55), (sw * 0.86, 0.4, 1.0), bevel=0.05)
bpy.ops.object.select_all(action="SELECT")
bpy.ops.object.transform_apply(rotation=True)

# preview render
cam_d = bpy.data.cameras.new("C"); cam = bpy.data.objects.new("C", cam_d); sc.collection.objects.link(cam); sc.camera = cam
cam.location = (15, -36, 17); cam.rotation_euler = ((Vector((0, 0, 11)) - cam.location).to_track_quat("-Z", "Y")).to_euler()
cam_d.lens = 40
l = bpy.data.lights.new("S", "SUN"); l.energy = 3.5; lo = bpy.data.objects.new("S", l); sc.collection.objects.link(lo); lo.rotation_euler = (math.radians(50), math.radians(10), math.radians(30))
w = bpy.data.worlds.new("W"); sc.world = w; w.use_nodes = True; w.node_tree.nodes["Background"].inputs[0].default_value = (0.55, 0.75, 0.95, 1); w.node_tree.nodes["Background"].inputs[1].default_value = 0.8
for eng in ("BLENDER_EEVEE_NEXT", "BLENDER_EEVEE"):
    try: sc.render.engine = eng; break
    except Exception: pass
sc.render.resolution_x, sc.render.resolution_y = 900, 1000
sc.view_settings.view_transform = "Standard"
sc.render.filepath = out_png
bpy.ops.render.render(write_still=True)

# export: meshes only
for o in list(sc.objects):
    o.select_set(o.type == "MESH")
bpy.ops.export_scene.fbx(filepath=out_fbx, use_selection=True, object_types={"MESH"}, apply_unit_scale=True,
                         mesh_smooth_type="OFF", axis_forward="-Z", axis_up="Y")
print("BOARD DONE", len([o for o in sc.objects if o.type == "MESH"]), "pieces")
