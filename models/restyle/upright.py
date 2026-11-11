"""Stand a tipped-over original upright before the warp (Fenrir came out of the Studio export
nose-down, tail up). Turns the mesh data of one object about an axis and saves a copy.
blender -b <in>.blend -P upright.py -- <out.blend> <Object> <axis X|Y|Z> <degrees>
"""
import bpy, sys, math
from mathutils import Matrix
out, name, axis, deg = sys.argv[sys.argv.index("--") + 1:][:4]
o = bpy.data.objects[name]
o.data.transform(Matrix.Rotation(math.radians(float(deg)), 4, axis))
o.data.update()
bpy.ops.wm.save_as_mainfile(filepath=out)
print("UPRIGHT", name, axis, deg)
