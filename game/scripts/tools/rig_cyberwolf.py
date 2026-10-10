"""Rigs Ross's Cyberwolf Sentinel (game/art/final/enemies/cyberwolf_sentinel_ross_v1.glb, never edited) into
game/art/final/enemies/cyberwolf_sentinel_rigged.glb: the sandbox's "Grunt".

Same pipeline as Red (rig_red.py): origin at the feet, faces Godot +Z, textures cut to 512 px (all three PBR maps kept),
smooth skin weights (automatic, then hand fixes), cheap stepped 15 fps clips (wolf_clips.py). Differences:
  * scaled 1.25x so the wolf stands about 1.19 m next to Red's 0.95 m (a threat that reads),
  * bones: Red's humanoid set (hips, spine, chest, neck, head, shoulders, arms, hands, legs, feet, weapon_socket,
    prop_socket) plus ears and a three-bone tail,
  * the clips are the enemy set: idle, walk, run, attack_windup, attack_swing, hurt, launched, knockdown, getup, stagger.
Run (see ta_lib.py): /tmp/ta_venv/bin/python game/scripts/tools/rig_cyberwolf.py [--sheet prefix [clips]] [--no-clips]
"""
import os
import sys
import tempfile

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from rigkit import *  # noqa: E402,F401,F403
from rigkit import _emission_material, _update  # noqa: E402

SRC = os.path.join(GAME_DIR, "art", "final", "enemies", "cyberwolf_sentinel_ross_v1.glb")
OUT = os.path.join(GAME_DIR, "art", "final", "enemies", "cyberwolf_sentinel_rigged.glb")
SCALE = 1.25                 # Red is 0.951 m; the wolf ends up about 1.19 m
MAX_TEX = 512

# ---- skeleton in the wolf's own (unscaled) final space: feet z = 0, centre line x = 0, faces -Y; multiplied by SCALE
J = {}


def bone(name, parent, head, tail):
    J[name] = (parent, head, tail)


bone("root", None, (0, 0, 0), (0, 0, 0.12))
bone("hips", "root", (0, 0.015, 0.376), (0, 0.015, 0.476))
bone("spine", "hips", (0, 0.015, 0.476), (0, 0.015, 0.576))
bone("chest", "spine", (0, 0.012, 0.576), (0, 0.01, 0.676))
bone("neck", "chest", (0, 0.01, 0.676), (0, -0.02, 0.746))
bone("head", "neck", (0, -0.02, 0.746), (0, -0.05, 0.952))
bone("tail", "hips", (0, 0.07, 0.43), (0, 0.17, 0.44))
bone("tail_2", "tail", (0, 0.17, 0.44), (0, 0.27, 0.50))
bone("tail_3", "tail_2", (0, 0.27, 0.50), (0, 0.36, 0.56))
for side, sx in (("l", 1.0), ("r", -1.0)):
    def m(p):
        return (p[0] * sx, p[1], p[2])
    bone("ear_" + side, "head", m((0.07, -0.03, 0.87)), m((0.10, -0.03, 0.975)))
    bone("shoulder_" + side, "chest", m((0.03, 0.01, 0.69)), m((0.17, 0.01, 0.67)))
    bone("upper_arm_" + side, "shoulder_" + side, m((0.17, 0.01, 0.67)), m((0.235, 0.01, 0.565)))
    bone("forearm_" + side, "upper_arm_" + side, m((0.235, 0.01, 0.565)), m((0.285, 0.01, 0.445)))
    bone("hand_" + side, "forearm_" + side, m((0.285, 0.01, 0.445)), m((0.325, 0.0, 0.345)))
    bone("thigh_" + side, "hips", m((0.075, 0.015, 0.355)), m((0.095, 0.0, 0.18)))
    bone("shin_" + side, "thigh_" + side, m((0.095, 0.0, 0.18)), m((0.10, 0.015, 0.05)))
    bone("foot_" + side, "shin_" + side, m((0.10, 0.03, 0.05)), m((0.10, -0.12, 0.02)))
bone("weapon_socket", "hand_r", (-0.31, 0.0, 0.40), (-0.31, -0.057, 0.482))
bone("prop_socket", "hand_l", (0.31, 0.0, 0.40), (0.31, -0.057, 0.482))
SOCKET_ROLL_Z = {"weapon_socket": (-1, 0, 0), "prop_socket": (1, 0, 0)}


def scaled(p):
    return tuple(c * SCALE for c in p)


def prepare_mesh():
    src = [o for o in import_glb(SRC) if o.type == "MESH"][0]
    doc, images = glb_images(SRC)
    mat_doc = doc["materials"][0]
    pbr = mat_doc["pbrMetallicRoughness"]
    src_of = lambda t: images[doc["textures"][t["index"]]["source"]]
    maps = {"BASE COLOR": src_of(pbr["baseColorTexture"]),
            "METALLIC ROUGHNESS": src_of(pbr["metallicRoughnessTexture"]),
            "NORMAL MAP": src_of(mat_doc["normalTexture"])}
    me = src.data
    lo, hi = bounds([src])
    boots = [v.co for v in me.vertices if v.co.z < lo.z + 0.03]
    cy = (min(v.y for v in boots) + max(v.y for v in boots)) / 2.0
    bm = bmesh.new()
    bm.from_mesh(me)
    bmesh.ops.translate(bm, vec=Vector((0.0, -cy, -lo.z)), verts=bm.verts)
    bmesh.ops.scale(bm, vec=Vector((SCALE, SCALE, SCALE)), verts=bm.verts, space=Matrix.Identity(4))
    bm.to_mesh(me)
    bm.free()
    src.name = "cyberwolf_sentinel"
    me.name = "cyberwolf_sentinel"
    return src, maps


def islands(me):
    parent = {}
    def find(a):
        while parent.setdefault(a, a) != a:
            parent[a] = parent[parent[a]]
            a = parent[a]
        return a
    key = lambda co: (round(co.x * 4000), round(co.y * 4000), round(co.z * 4000))
    for p in me.polygons:
        ks = [key(me.vertices[v].co) for v in p.vertices]
        for k in ks[1:]:
            parent[find(k)] = find(ks[0])
    return [find(key(v.co)) for v in me.vertices]


def nearest_bones(p, segs, names, count=2):
    scored = []
    for n in names:
        t, d = seg_param(p, segs[n][0], segs[n][1])
        scored.append((d, n))
    scored.sort()
    return scored[:count]


BODY = ["hips", "spine", "chest", "neck", "head", "thigh_l", "thigh_r", "shin_l", "shin_r", "foot_l", "foot_r",
        "upper_arm_l", "upper_arm_r", "forearm_l", "forearm_r", "hand_l", "hand_r"]


def fix_weights(obj, arm):
    me = obj.data
    names = [b.name for b in arm.data.bones]
    segs = {n: bone_axis(arm, n) for n in names}
    table = weights_of(obj, names)
    table = weld_and_smooth(me, table, passes=0)
    pid = islands(me)
    out = []
    frozen = []
    S = SCALE
    for i, v in enumerate(me.vertices):
        p = v.co
        side = "l" if p.x > 0 else "r"
        w = dict(table[i])
        if sum(w.values()) < 0.05:                         # an island the heat solver could not reach
            near = nearest_bones(p, segs, BODY)
            tot = sum(1.0 / (d + 0.02) for d, _ in near)
            w = {n: (1.0 / (d + 0.02)) / tot for d, n in near}
        # --- the tail ball: a chain along the tail bones
        if p.y > 0.06 * S and p.z > 0.38 * S and abs(p.x) < 0.07 * S and p.z < 0.62 * S:
            t = (p.y / S - 0.07) / (0.36 - 0.07)
            t = max(0.0, min(1.0, t))
            k1, k2 = smoothstep(0.15, 0.4, t), smoothstep(0.5, 0.8, t)
            w = {"tail": 1.0 - k1, "tail_2": k1 * (1.0 - k2), "tail_3": k1 * k2}
            frozen.append(i)
        # --- gloves and claws: follow the hand, the cuff blends into the forearm
        elif abs(p.x) > 0.21 * S and p.z < 0.46 * S and p.z > 0.30 * S and p.y < 0.03 * S + 0.0:
            k = smoothstep(0.455 * S, 0.40 * S, p.z)
            w = {"hand_" + side: k, "forearm_" + side: 1.0 - k}
            frozen.append(i)
        # --- the head and the collar-less muzzle: all head
        elif p.z > 0.75 * S:
            k = smoothstep(0.75 * S, 0.80 * S, p.z)
            w = {"head": k, "neck": 1.0 - k}
            if p.z > 0.88 * S and abs(p.x) > 0.045 * S:         # the ear tips swing a little
                e = smoothstep(0.88 * S, 0.97 * S, p.z)
                w = {"head": 1.0 - 0.8 * e, "ear_" + side: 0.8 * e}
            frozen.append(i)
        else:
            # arms never pull the vest: inside the torso column the arm bones hand their share to the spine/chest
            arm_bones = [b for b in w if b.startswith(("upper_arm", "forearm", "hand"))]
            inside = 1.0 - smoothstep(0.10 * S, 0.19 * S, abs(p.x))
            if arm_bones and inside > 0:
                moved = 0.0
                for b in arm_bones:
                    share = w[b] * inside
                    w[b] -= share
                    moved += share
                low = "spine" if p.z < 0.58 * S else "chest"
                w[low] = w.get(low, 0.0) + moved
        out.append(w)
    out = weld_and_smooth(me, out, passes=3, factor=0.5, skip=frozen)
    write_weights(obj, out)


def main():
    argv = sys.argv[1:]
    reset_scene()
    obj, maps = prepare_mesh()
    tmp = tempfile.mkdtemp(prefix="wolf_")
    mat = obj.data.materials[0].copy()
    mat.name = "cyberwolf_sentinel"
    obj.data.materials.clear()
    obj.data.materials.append(mat)
    replace_material_images(mat, downscale_all(maps, MAX_TEX), tmp, "wolf")
    spec = [(n, p, scaled(h), scaled(t)) for n, (p, h, t) in J.items()]
    arm = build_armature("wolf_rig", spec)
    bpy.ops.object.mode_set(mode="EDIT")
    for n, z in SOCKET_ROLL_Z.items():
        arm.data.edit_bones[n].align_roll(Vector(z))
    bpy.ops.object.mode_set(mode="OBJECT")
    bind_auto(obj, arm)
    fix_weights(obj, arm)
    if "--sheet" in argv:
        i = argv.index("--sheet")
        names = argv[i + 2].split(",") if len(argv) > i + 2 else None
        sheet(obj, arm, argv[i + 1], names)
        return
    if "--pose-test" in argv:
        pose_test(obj, arm, argv[argv.index("--pose-test") + 1])
        return
    if "--no-clips" not in argv:
        import wolf_clips
        for row in build_clips(arm, wolf_clips.CLIPS):
            print("clip %-14s %2d frames (%.2f s)  %d keys%s" % (row[0], row[1], row[1] / FPS, row[2], "  loop" if row[3] else ""))
    if "--no-clips" not in argv:
        write_clip_keys(os.path.join(GAME_DIR, "data", "combat", "wolf_clip_keys.json"), wolf_clips.CLIPS, "the Cyberwolf Sentinel")
    obj.name = "cyberwolf_sentinel"
    arm.name = "cyberwolf_sentinel_armature"
    export_glb(OUT, [obj, arm], animations=("--no-clips" not in argv))
    print("tris", tri_count(obj), "bones", len(arm.data.bones))


TEST_POSES = [
    ("rest", {}),
    ("arms_up", {"upper_arm_l": (0, -75, 0), "upper_arm_r": (0, 75, 0), "forearm_l": (-40, 0, 0), "forearm_r": (-40, 0, 0)}),
    ("lunge", {"upper_arm_r": (-110, 0, 0), "shoulder_r": (-25, 0, 0), "spine": (22, 0, 25), "head": (-10, 0, 0),
               "thigh_l": (-45, 0, 0), "shin_l": (60, 0, 0), "thigh_r": (25, 0, 0), "tail": (0, 0, 40), "tail_2": (0, 0, 40),
               "ear_l": (0, 0, -30), "ear_r": (0, 0, 30)}),
]


def pose_test(obj, arm, prefix):
    from PIL import Image
    show_materials_unlit([obj])
    cam = setup_render(500, 800, 1.6)
    rig = Rig(arm)
    for az, tag in ((0, "front"), (50, "three")):
        strips = []
        for name, pose in TEST_POSES:
            apply_pose(rig, pose)
            _update()
            aim_ortho(cam, az, (0, 0, 0.6))
            render_to(prefix + "_tmp.png")
            strips.append(Image.open(prefix + "_tmp.png").convert("RGB").copy())
        sheet_img = Image.new("RGB", (500 * len(strips), 800))
        for i, im in enumerate(strips):
            sheet_img.paste(im, (500 * i, 0))
        sheet_img.save(prefix + "_%s.png" % tag)


def sheet(obj, arm, prefix, names):
    import wolf_clips
    from PIL import Image, ImageDraw
    show_materials_unlit([obj])
    cam = setup_render(360, 460, 1.9)
    rig = Rig(arm)
    for name in (names or list(wolf_clips.CLIPS)):
        cols = []
        for frame, pose in wolf_clips.CLIPS[name]["keys"]:
            apply_pose(rig, pose)
            _update()
            col = Image.new("RGB", (360, 920), (220, 220, 220))
            for row, az in enumerate((90, 35)):
                aim_ortho(cam, az, (0, 0, 0.6))
                render_to(prefix + "_tmp.png")
                col.paste(Image.open(prefix + "_tmp.png").convert("RGB"), (0, 460 * row))
            ImageDraw.Draw(col).text((6, 6), "%s f%d" % (name, frame), fill=(0, 0, 0))
            cols.append(col)
        img = Image.new("RGB", (360 * len(cols), 920))
        for i, c in enumerate(cols):
            img.paste(c, (360 * i, 0))
        img.save("%s_%s.png" % (prefix, name))
        print("sheet", name)


main()
