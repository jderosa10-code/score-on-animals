# Append restyled animals (the <Name>_SOA object + its children) from another .blend into this one,
# so several fixes can go out in one FBX.
# blender -b target.blend -P merge_into.py -- <source.blend> Name1,Name2 <out.blend>
import bpy, sys
argv = sys.argv[sys.argv.index("--") + 1:]
src, names, out = argv[0], argv[1].split(","), argv[2]
with bpy.data.libraries.load(src, link=False) as (data_from, data_to):
    data_to.objects = [n for n in data_from.objects if any(n.startswith(x + "_SOA") for x in names)]
for ob in data_to.objects:
    if ob is not None:
        bpy.context.scene.collection.objects.link(ob)
        print("APPENDED", ob.name, "parent", ob.parent.name if ob.parent else None)
bpy.ops.wm.save_as_mainfile(filepath=out)
