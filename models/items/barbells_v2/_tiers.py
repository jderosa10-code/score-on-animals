
# ================================================================ barbells v2 (pigeon-claude, 11 Nov 2026)
# Concepts for the 16 barbells the game uses (GameConfig.Barbells / ServerStorage.Barbells), remade in
# ONE style: chunky toy, fine rounded steps, short thick bar with a 2-stud grip each side, big heads,
# one colour family per weight. Each keeps its own idea (Copper plates, Donut, Bone, Pumpkin...).
# First batch for pigeon's yes/no; nothing goes into the game until then.
# Built by _engine.py (copied from weights_vox.py): build(), handle(), shading, materials.
BASE.update({
    "Copper": "#CC6A2C", "Steel": "#9AA0AB", "Iron": "#3A3A42",
    "Bone": "#F2E6C9", "Wrap": "#D9363E",
    "Pumpkin": "#F26A12", "Stem": "#5E7A2A", "Carve": "#FFC93F",
    "IceBlock": "#8FE0FF", "Frost": "#F4FBFF",
    "Gilt": "#FFC727",
})
GLOW = GLOW + ("Carve",)
# pigeon: "ur making them a bit too high quality" -> chunkier steps, less rounding, fewer small details
C = 0.25
LOWQ_ITERS = 1


def t_copper(x, y, z, i, j, k):
    """Starter: classic gym plates in copper, a big plate and a small one, rolled rims, a groove ring."""
    h = 1.45
    ax = abs(x); u = ax - HS; dz = z - h; r = math.hypot(y, dz)
    for u0, u1, R in ((0.0, 0.5, 1.4), (0.55, 0.95, 1.1)):
        if u0 <= u < u1 and r < R:
            if r > R - 0.16: return ("Vox", "CopperHi")
            if r < 0.5: return ("Vox", "CopperLo")
            return ("Vox", "Copper")
    return handle(ax, y, z, h, HS + 0.95, metal="Steel", grip="Grip")


def t_donut(x, y, z, i, j, k):
    """One big glazed donut each end, standing up on the bar: pink icing on the outside with drips
    running toward the hands, sprinkles."""
    h, R, a = 1.72, 1.05, 0.62
    uc = HS + 0.65
    ax = abs(x); u = ax - uc; dz = z - h; r = math.hypot(y, dz)
    d = math.hypot(r - R, u)
    if d < a:
        ang = math.atan2(dz, y)
        drip = 0.0                                  # (simpler: a straight icing line, no drips)
        if u > -0.05 - drip:
            if d > a - 0.26 and hsh(i, j, k) % 9 == 0:
                return ("Vox", ("SprinkleY", "SprinkleB", "SprinkleG", "SprinkleW")[hsh(i, j, k) // 9 % 4])
            return ("Vox", "IcingHi" if dz > 0.55 else "Icing")
        return ("Vox", "DoughLo" if r < R - 0.25 else "Dough")
    return handle(ax, y, z, h, uc + 0.7, metal="Dough", grip="Icing")


def t_bone(x, y, z, i, j, k):
    """The whole barbell is a cartoon bone: knobbly ends, the shaft is the bar, red tape for grips."""
    h = 0.92
    uc = HS + 0.45
    ax = abs(x); u = ax - uc; dz = z - h
    # two round knobs melted smoothly into the shaft (a smooth union, so no popcorn lumps)
    def smin(a, b, s=0.28):
        hh = max(0.0, min(1.0, 0.5 + 0.5 * (b - a) / s))
        return b + (a - b) * hh - s * hh * (1 - hh)
    d = smin(math.sqrt(u * u + (y + 0.56) ** 2 + dz * dz) - 0.74, math.sqrt(u * u + (y - 0.56) ** 2 + dz * dz) - 0.74)
    if u < 0.2: d = smin(d, math.hypot(y * 1.2, dz) - 0.36 - 0.25 * max(0.0, 1 + u / 0.9))
    if d < 0:
        return ("Vox", "BoneLo" if dz < -0.42 else ("BoneHi" if dz > 0.42 else "Bone"))
    if ax >= uc - 0.2: return None                 # no end cap: the knobs are the end
    return handle(ax, y, z, h, uc + 0.6, metal="Bone", grip="Wrap", collars=False)


def t_pumpkin(x, y, z, i, j, k):
    """Jack-o'-lantern each end: ribbed, a stem on top, a carved face that glows, facing the front."""
    h = 1.3
    uc = HS + 1.3
    ax = abs(x); u = ax - uc; dz = z - h
    th = math.atan2(y, u)
    rib = 0.5 - 0.5 * math.cos(6 * th)                 # 0 on a rib, 1 in a groove
    Rh = 1.32 * (1 - 0.07 * rib)
    q = math.sqrt((u * u + y * y) / (Rh * Rh) + dz * dz / (1.12 * 1.12))
    if q < 1:
        if y < -0.55 and q > 0.8:                      # the carved face, on the front
            lu = u if x > 0 else -u                   # mirror so both faces read the same way round
            for ue in (-0.42, 0.42):
                if 0.12 < dz < 0.46 and abs(lu - ue) < 0.24 * (1 - (dz - 0.12) / 0.34): return ("Vox", "Carve")
            if -0.5 < dz < -0.12 and abs(lu) < 0.62 and dz < -0.14 - 0.1 * abs(math.sin(lu * 9)): return ("Vox", "Carve")
        if rib > 0.82: return ("Vox", "PumpkinLo")
        return ("Vox", "PumpkinHi" if dz > 0.62 else "Pumpkin")
    if math.hypot(u + 0.05 * (z - h - 1.1), y) < 0.2 and h + 0.95 < z < h + 1.55:
        return ("Vox", "StemHi" if z > h + 1.4 else "Stem")
    return handle(ax, y, z, h, uc + 1.3, metal="Iron", grip="Pumpkin")


def t_ice(x, y, z, i, j, k):
    """A big ice cube each end: rounded edges, lighter edges, a frost cap on top, a crack on the front."""
    h = 1.3
    uc = HS + 1.12
    ax = abs(x); u = ax - uc; dz = z - h
    q = (u ** 4 + y ** 4 + dz ** 4) ** 0.25
    if q < 1.1:
        if dz > 0.78: return ("Vox", "Frost")
        edges = sum(1 for c in (abs(u), abs(y), abs(dz)) if c > 0.78)
        if edges >= 2: return ("Vox", "IceBlockHi")
        return ("Vox", "IceBlock")
    return handle(ax, y, z, h, uc + 1.15, metal="IceBlock", grip="Frost")


def t_star(x, y, z, i, j, k):
    """Giant puffy gold stars each end, point up, thicker in the middle, a red gem in the centre."""
    h = 1.62
    uc = HS + 0.62
    ax = abs(x); u = ax - uc; dz = z - h; r = math.hypot(y, dz)
    # a real five-point star outline (straight edges between sharp points and inner corners), point up
    R, ri = 1.85, 0.78
    sector = 2 * math.pi / 5
    m = (math.atan2(dz, y) - math.pi / 2) % sector
    a = min(m, sector - m)
    qx, qy = ri * math.cos(sector / 2) - R, ri * math.sin(sector / 2)
    rs = (R * qy) / (math.cos(a) * qy - math.sin(a) * qx)
    if r < rs:
        thick = 0.36 - 0.9 * max(0.0, r - (rs - 0.22))          # even slab, bevelled edge
        if r < 0.42: thick = max(thick, 0.36 + 0.2 * math.sqrt(max(0.0, 1 - (r / 0.42) ** 2)))
        if abs(u) < thick:
            if r < 0.42 and abs(u) > 0.3: return ("Vox", "GemRedHi" if dz > 0.1 else "GemRed")
            if r > rs - 0.13: return ("Vox", "GiltLo")
            return ("Vox", "GiltHi" if dz > 0.5 else "Gilt")
    return handle(ax, y, z, h, uc + 0.5, metal="Gilt", grip="Pearl")


# ---------------------------------------------------------------- the other 10 (pigeon: "sure do the rest")
BASE.update({
    "RedPlate": "#E0312F", "Rose": "#E0244A", "Leaf": "#3FA34D",
    "Crystal": "#A64DFF", "Rock": "#4A3A5E",
    "Speaker": "#1C1C24", "NeonPink": "#FF2BD6",
    "Galaxy": "#5B2A9E", "SunCore": "#FFE066", "SunRay": "#FFB020",
})
GLOW = GLOW + ("NeonPink", "SunCore", "SunRay")


def t_red(x, y, z, i, j, k):
    """Red bumper plates, a size up from copper, with a white hub."""
    h = 1.55
    ax = abs(x); u = ax - HS; dz = z - h; r = math.hypot(y, dz)
    for u0, u1, R in ((0.0, 0.55, 1.5), (0.6, 1.0, 1.2)):
        if u0 <= u < u1 and r < R:
            if r > R - 0.2: return ("Vox", "RedPlateHi")
            if r < 0.55: return ("Vox", "Frost")
            return ("Vox", "RedPlate")
    return handle(ax, y, z, h, HS + 1.0, metal="Steel", grip="Iron")


def t_rose(x, y, z, i, j, k):
    """A rose in full bloom each end, facing outward, sitting in a green cup with two leaves."""
    h = 1.45
    uc = HS + 0.4
    ax = abs(x); u = ax - uc; dz = z - h; r = math.hypot(y, dz)
    if 0 <= u < 1.15:
        if r < 1.35 * math.sqrt(max(0.0, 1 - (u / 1.2) ** 2)) + 0.05:
            return ("Vox", "RoseLo" if int((r + u * 0.7) * 2.6) % 2 else "Rose")   # petal rings
    if -0.35 <= u < 0 and r < 0.95: return ("Vox", "Leaf")
    if -0.3 <= u < -0.05 and ((abs(y) - 1.15) / 0.55) ** 2 + ((dz + 0.15) / 0.28) ** 2 < 1: return ("Vox", "LeafHi")
    return handle(ax, y, z, h, uc + 1.15, metal="Leaf", grip="Rose")


def t_golden(x, y, z, i, j, k):
    """Gold bars stacked each end: a big ingot lying across, a smaller one on top the other way."""
    h = 0.95
    ax = abs(x); u = ax - HS
    if 0 <= z < 0.9:
        t = z / 0.9
        if 0.12 * t <= u < 1.0 - 0.12 * t and abs(y) < 1.15 - 0.25 * t:
            return ("Vox", "GoldHi" if z > 0.75 else "Gold")
    if 0.9 <= z < 1.6:
        t = (z - 0.9) / 0.7
        if 0.1 + 0.1 * t <= u < 0.9 - 0.1 * t and abs(y) < 0.7 - 0.15 * t:
            return ("Vox", "GoldHi" if z > 1.45 else "Gold")
    return handle(ax, y, z, h, HS + 1.0, metal="Gold", grip="Choc")


def t_crystal(x, y, z, i, j, k):
    """A crystal cluster each end: a dark rock with six pointed crystals sticking out of it."""
    h = 1.6
    uc = HS + 0.75
    ax = abs(x); p = Vector((ax - uc, y, z - h))
    if p.length < 0.6: return ("Vox", "Rock")
    spikes = [Vector((1, 0, 0))] + [Vector((0, math.cos(math.radians(a)), math.sin(math.radians(a)))) for a in (90, 30, 150, 210, 330)]
    for n, d in enumerate(spikes):
        t = p.dot(d)
        if 0 < t < 1.5:
            w = 0.4 * min(1.0, (1.5 - t) / 0.55)
            if (p - d * t).length < w: return ("Vox", "CrystalHi" if t > 1.0 or n % 2 else "Crystal")
    return handle(ax, y, z, h, uc + 0.4, metal="Crystal", grip="Iron")


def t_neon(x, y, z, i, j, k):
    """Black speaker plates with glowing neon rings on the outside face."""
    h = 1.55
    ax = abs(x); u = ax - HS; dz = z - h; r = math.hypot(y, dz)
    if 0 <= u < 0.8 and r < 1.5:
        if r > 1.36: return ("Vox", "NeonPink")
        if u > 0.62 and (1.0 < r < 1.18 or 0.42 < r < 0.58): return ("Vox", "NeonPink")
        return ("Vox", "SpeakerHi" if u > 0.62 else "Speaker")
    return handle(ax, y, z, h, HS + 0.8, metal="Speaker", grip="Grip", glow="NeonPink")


def t_haven(x, y, z, i, j, k):
    """A white four-point sparkle star each end with a glowing cyan heart."""
    h = 1.9
    uc = HS + 0.45
    ax = abs(x); u = ax - uc; dz = z - h; r = math.hypot(y, dz)
    R = 1.8
    if (abs(y) / R) ** 0.6 + (abs(dz) / R) ** 0.6 < 1:
        if abs(u) < 0.34 - 0.18 * min(1.0, r / R):
            if r < 0.45: return ("Vox", "GlowCyan")
            return ("Vox", "PearlHi" if dz > 0.3 else "Pearl")
    return handle(ax, y, z, h, uc + 0.4, metal="Pearl", grip="Gold")


def t_mega(x, y, z, i, j, k):
    """Three thick gold plates, biggest nearest the hands, with gems round the big one."""
    h = 1.8
    ax = abs(x); u = ax - HS; dz = z - h; r = math.hypot(y, dz)
    for u0, u1, R in ((0.0, 0.45, 1.75), (0.5, 0.9, 1.4), (0.95, 1.3, 1.05)):
        if u0 <= u < u1 and r < R:
            if u0 == 0.0 and u > 0.3 and 1.3 < r < 1.6:
                ang = math.degrees(math.atan2(dz, y)) % 45
                if ang < 14: return ("Vox", "GemRed" if int(math.degrees(math.atan2(dz, y)) // 45) % 2 else "GemBlue")
            if r > R - 0.18: return ("Vox", "GoldHi")
            return ("Vox", "Gold")
    return handle(ax, y, z, h, HS + 1.3, metal="Gold", grip="GemRed")


def t_flyer(x, y, z, i, j, k):
    """A red rocket each end, nose pointing out: white nose cone, porthole, three fins."""
    h = 1.45
    ax = abs(x); u = ax - HS; dz = z - h; r = math.hypot(y, dz)
    if 0 <= u < 1.6 and r < 0.75:
        if y < -0.55 and math.hypot(u - 0.95, dz) < 0.26: return ("Vox", "RocketWindow")
        return ("Vox", "RocketRed")
    if 1.6 <= u < 2.35 and r < 0.75 * (1 - (u - 1.6) / 0.75) ** 0.7: return ("Vox", "RocketBody")
    if 0 <= u < 0.65:
        ang = math.degrees(math.atan2(dz, y)) % 360
        for fa in (90, 210, 330):
            if abs((ang - fa + 180) % 360 - 180) < 9 and r < 1.4 - u * 0.6: return ("Vox", "RocketRedLo")
    return handle(ax, y, z, h, HS + 2.35, metal="RocketBody", grip="RocketRed")


def t_starfall(x, y, z, i, j, k):
    """A purple galaxy planet each end, sprinkled with stars, with a glowing tilted ring."""
    h = 1.6
    uc = HS + 1.85   # far enough out that the tilted ring stays clear of the grip
    ax = abs(x); p = Vector((ax - uc, y, z - h))
    if p.length < 1.25:
        if p.length > 1.0 and hsh(i, j, k) % 7 == 0: return ("Vox", "Star")
        return ("Vox", "GalaxyHi" if p.z > 0.6 else "Galaxy")
    n = Vector((0.42, 0, 0.91))
    off = p.dot(n)
    rr = (p - n * off).length
    if abs(off) < 0.12 and 1.55 < rr < 1.95: return ("Vox", "RingA")
    return handle(ax, y, z, h, uc + 1.0, metal="Galaxy", grip="RingA")


def t_starlight(x, y, z, i, j, k):
    """The top weight: a glowing sun each end with eight rays around it and one pointing out."""
    h = 1.9
    uc = HS + 1.1
    ax = abs(x); p = Vector((ax - uc, y, z - h))
    if p.length < 0.95: return ("Vox", "SunCore")
    rays = [Vector((1, 0, 0))] + [Vector((0, math.cos(math.radians(a)), math.sin(math.radians(a)))) for a in range(22, 360, 45)]
    for d in rays:
        t = p.dot(d)
        if 0.7 < t < 1.8 and (p - d * t).length < 0.38 * (1.8 - t) / 1.1: return ("Vox", "SunRay")
    return handle(ax, y, z, h, uc + 0.9, metal="Gilt", grip="Pearl", glow="SunRay")


# all 16, in the game's upgrade order (GameConfig.Barbells): name, function, design-space bounds, how much
# bigger it's built (grows down the list)
WIDE = ((-5.4, 5.4), (-2.2, 2.2), (0, 3.9))
TIERS = [
    ("Copper", t_copper, ((-3.6, 3.6), (-1.6, 1.6), (0, 3.0)), 1.15),
    ("Red", t_red, ((-3.8, 3.8), (-1.7, 1.7), (0, 3.2)), 1.2),
    ("Donut", t_donut, ((-4.3, 4.3), (-1.8, 1.8), (0, 3.5)), 1.25),
    ("Bone", t_bone, ((-3.8, 3.8), (-1.5, 1.5), (0, 1.9)), 1.3),
    ("Pumpkin", t_pumpkin, ((-5.3, 5.3), (-1.5, 1.5), (0, 3.0)), 1.35),
    ("Rose", t_rose, WIDE, 1.38),
    ("Golden", t_golden, ((-4.0, 4.0), (-1.3, 1.3), (0, 1.7)), 1.42),
    ("Ice", t_ice, ((-5.0, 5.0), (-1.3, 1.3), (0, 2.5)), 1.45),
    ("Crystal", t_crystal, WIDE, 1.48),
    ("NeonPulse", t_neon, ((-3.6, 3.6), (-1.6, 1.6), (0, 3.2)), 1.5),
    ("Havenstar", t_haven, WIDE, 1.52),
    ("MegaGolden", t_mega, ((-4.0, 4.0), (-1.9, 1.9), (0, 3.7)), 1.55),
    ("GiantGoldStar", t_star, ((-4.2, 4.2), (-1.9, 1.9), (0, 3.5)), 1.6),
    ("RedFlyer", t_flyer, WIDE, 1.62),
    ("Starfall", t_starfall, ((-5.6, 5.6), (-2.1, 2.1), (0, 3.6)), 1.66),
    ("StarLight", t_starlight, WIDE, 1.7),
]

GAP = 26.0          # room so the next weight and its dummy stay out of each shot
allobjs = []
for n, (name, fn, bounds, K) in enumerate(TIERS):
    coll = bpy.data.collections.new(f"Barbell_{name}")
    bpy.context.scene.collection.children.link(coll)
    HS = HS_WORLD / K                       # the tier functions read this: grip zone = 2 studs when built
    objs = build(f"Barbell_{name}_", fn, bounds, coll, offset=(0, -n * GAP, 0), scale=K, iters=LOWQ_ITERS)
    tris = sum(sum(len(p.vertices) - 2 for p in o.data.polygons) for o in objs)
    print("TIER", n + 1, name, "parts", len(objs), "tris", tris)
    allobjs += objs

# ---------------------------------------------------------------- preview
sc = bpy.context.scene
BASE["Dummy"] = BASE["Bar"]
dm = material("Dummy")
for size, loc in [((2, 1, 2), (0, 0, 3)), ((1.1, 1.1, 1.1), (0, 0, 4.55)), ((0.95, 1, 2), (-0.5, 0, 1)),
                  ((0.95, 1, 2), (0.5, 0, 1)), ((0.95, 1, 2), (-1.5, 0, 3)), ((0.95, 1, 2), (1.5, 0, 3))]:
    for n in range(len(TIERS)):     # a 5-stud dummy behind every weight for scale (GAP keeps the next one out of shot)
        bpy.ops.mesh.primitive_cube_add(size=1, location=(loc[0], loc[1] + 4.5 - n * GAP, loc[2]))
        o = bpy.context.active_object; o.scale = size; o.data.materials.append(dm)
bpy.ops.mesh.primitive_plane_add(size=1200, location=(0, -200, 0))
g = bpy.data.materials.new("Ground"); g.use_nodes = True
g.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (0.55, 0.58, 0.66, 1)
bpy.context.active_object.data.materials.append(g)
sun = bpy.data.objects.new("Sun", bpy.data.lights.new("Sun", 'SUN')); sun.data.energy = 3.0
sun.rotation_euler = (math.radians(50), 0, math.radians(30)); sc.collection.objects.link(sun)
sc.world = bpy.data.worlds.new("W"); sc.world.use_nodes = True
sc.world.node_tree.nodes["Background"].inputs["Color"].default_value = (0.75, 0.82, 0.92, 1)
cam = bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam")); sc.collection.objects.link(cam)
sc.camera = cam
sc.view_settings.view_transform = "Standard"   # true colours, like Roblox (AgX washed them out)
sc.render.engine = "CYCLES"; sc.cycles.device = 'CPU'; sc.cycles.samples = 24; sc.cycles.use_denoising = True
sc.render.resolution_x = 1000; sc.render.resolution_y = 600
bpy.ops.wm.save_as_mainfile(filepath=blend_out)
for n in range(len(TIERS)):          # one shot per weight, from the front-left like a player would see it
    tgt = Vector((0, -n * GAP, 2.0))
    cam.data.lens = 34
    cam.location = tgt + Vector((7.5, -15, 6.5))
    cam.rotation_euler = (tgt - cam.location).to_track_quat('-Z', 'Y').to_euler()
    sc.render.filepath = png_out.replace(".png", f"_{n + 1:02d}.png")
    bpy.ops.render.render(write_still=True)
print("DONE")
