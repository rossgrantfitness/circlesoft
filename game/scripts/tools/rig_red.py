"""Rigs Ross's Red (game/art/final/characters/red/red_ross_v1.glb, never edited) into the game-ready
game/art/final/characters/red/red_ross_v1_rigged.glb: origin at the feet, facing Godot +Z, height kept (0.95 m),
textures cut to 512 px (all three PBR maps kept), a 29-bone humanoid skeleton with automatic weights plus
hand fixes, and the first set of cheap animation clips (red_clips.py).

Run (see ta_lib.py):  /tmp/ta_venv/bin/python game/scripts/tools/rig_red.py [--debug-weights out_prefix] [--no-clips]
"""
import os
import sys
import tempfile

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from rigkit import *  # noqa: E402,F401,F403

SRC = os.path.join(GAME_DIR, "art", "final", "characters", "red", "red_ross_v1.glb")
OUT = os.path.join(GAME_DIR, "art", "final", "characters", "red", "red_ross_v1_rigged.glb")
MAX_TEX = 512

# ---- the skeleton, in final model space (feet z = 0, centre line x = y = 0, faces -Y; her left is +X) ----
def mirror(x, y, z):
    return (-x, y, z)

J = {}                                                   # name -> (parent, head, tail)

def bone(name, parent, head, tail):
    J[name] = (parent, head, tail)

bone("root", None, (0, 0, 0), (0, 0, 0.12))
bone("hips", "root", (0, 0, 0.376), (0, 0, 0.436))
bone("spine", "hips", (0, 0, 0.436), (0, 0, 0.536))
bone("chest", "spine", (0, 0, 0.536), (0, 0, 0.636))
bone("neck", "chest", (0, 0, 0.636), (0, 0, 0.696))
bone("head", "neck", (0, 0, 0.696), (0, 0, 0.95))
bone("tail", "hips", (0, 0.08, 0.44), (0, 0.20, 0.44))
for side, sx in (("l", 1.0), ("r", -1.0)):
    def m(p):
        return (p[0] * sx, p[1], p[2])
    bone("ear_" + side, "head", m((0.12, 0.07, 0.796)), m((0.1525, 0.115, 0.676)))
    bone("ear_%s_2" % side, "ear_" + side, m((0.1525, 0.115, 0.676)), m((0.185, 0.16, 0.556)))
    bone("shoulder_" + side, "chest", m((0.03, 0.0, 0.62)), m((0.15, 0.0, 0.60)))
    bone("upper_arm_" + side, "shoulder_" + side, m((0.15, 0.0, 0.60)), m((0.245, 0.0, 0.521)))
    bone("forearm_" + side, "upper_arm_" + side, m((0.245, 0.0, 0.521)), m((0.30, 0.0, 0.431)))
    bone("hand_" + side, "forearm_" + side, m((0.30, 0.0, 0.431)), m((0.335, 0.0, 0.351)))
    bone("thigh_" + side, "hips", m((0.085, 0.0, 0.361)), m((0.10, -0.005, 0.191)))
    bone("shin_" + side, "thigh_" + side, m((0.10, -0.005, 0.191)), m((0.105, 0.0, 0.051)))
    bone("foot_" + side, "shin_" + side, m((0.105, 0.01, 0.051)), m((0.105, -0.11, 0.021)))
# sockets: +Y = where a held thing's long axis points (up and 35 degrees forward), the held thing's flat side faces outward
bone("weapon_socket", "hand_r", (-0.315, -0.01, 0.391), (-0.315, -0.01 - 0.057, 0.391 + 0.082))
bone("prop_socket", "hand_l", (0.315, -0.01, 0.391), (0.315, -0.01 - 0.057, 0.391 + 0.082))
bone("back", "chest", (0.0, 0.085, 0.60), (0.04, 0.115, 0.69))          # a sheathed sword rides here later
bone("head_gear", "head", (0.0, 0.0, 0.86), (0.0, 0.0, 0.95))          # caps and helmets later
bone("lamp_socket", "chest", (0.0, -0.09, 0.57), (0.0, -0.13, 0.57))    # where the Lamp Flare and Lights On glow start
SOCKET_ROLL_Z = {"weapon_socket": (-1, 0, 0), "prop_socket": (1, 0, 0), "back": (0, 1, 0)}

EAR = {"ear_l": 1.0, "ear_r": -1.0}
EAR2 = {"ear_l": "ear_l_2", "ear_r": "ear_r_2"}


def prepare_mesh():
    """Imports the original and returns (object with the fixed placement, maps as PIL images)."""
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
    # the boots (two loose parts at the bottom) tell us where the feet are; centre on them
    boots = [v.co for v in me.vertices if v.co.z < lo.z + 0.03]
    cy = (min(v.y for v in boots) + max(v.y for v in boots)) / 2.0
    shift = Vector((0.0, -cy, -lo.z))
    bm = bmesh.new()
    bm.from_mesh(me)
    bmesh.ops.translate(bm, vec=shift, verts=bm.verts)
    bm.to_mesh(me)
    bm.free()
    src.name = "red_ross"
    me.name = "red_ross"
    return src, maps, shift


def part_ids(me):
    """Loose-part id per vertex (corners welded by position), so the boots, tail and pouches can be found."""
    parent = {}
    def find(a):
        while parent.setdefault(a, a) != a:
            parent[a] = parent[parent[a]]
            a = parent[a]
        return a
    key = lambda co: (round(co.x * 5000), round(co.y * 5000), round(co.z * 5000))
    for p in me.polygons:
        ks = [key(me.vertices[v].co) for v in p.vertices]
        for k in ks[1:]:
            parent[find(k)] = find(ks[0])
    return [find(key(v.co)) for v in me.vertices]


SHOULDER_JOINT = {"l": Vector((0.15, 0.0, 0.60)), "r": Vector((-0.15, 0.0, 0.60))}
RAW = "--raw" in sys.argv


def arm_fix(p, w):
    """Arms never pull the jacket: inside the torso column (|x| under the armhole) the arm bones' share goes to the
    chest/spine, so lifting an arm does not drag the vest."""
    arm_bones = [b for b in w if b.startswith(("upper_arm", "forearm", "hand"))]
    if not arm_bones:
        return w
    inside = 1.0 - smoothstep(0.09, 0.21, abs(p.x))        # 1 in the torso, 0 out in the sleeve
    moved = 0.0
    for b in arm_bones:
        share = w[b] * inside
        w[b] -= share
        moved += share
    if moved > 0.0:
        low = "spine" if p.z < 0.54 else "chest"
        w[low] = w.get(low, 0.0) + moved
    # the shoulder cap follows the collarbone for part of a big arm raise, so it rolls instead of spiking
    side = "l" if p.x > 0 else "r"
    d = (p - SHOULDER_JOINT[side]).length
    near = 1.0 - smoothstep(0.03, 0.11, d)
    if near > 0.0:
        take = 0.55 * near * sum(x for b, x in w.items() if b.startswith("upper_arm"))
        for b in list(w):
            if b.startswith("upper_arm"):
                w[b] *= 1.0 - 0.55 * near
        w["shoulder_" + side] = w.get("shoulder_" + side, 0.0) + take
    return w


def fix_weights(obj, arm):
    """Automatic weights, then the hand fixes: boots follow the feet, the tail follows the tail, belt pouches follow the
    hips, ears hang from the head and swing on the ear bones, arms never pull the jacket (torso verts lose arm weight);
    finally seams are welded and the arm/ear transitions relaxed."""
    me = obj.data
    names = [b.name for b in arm.data.bones]
    table = weights_of(obj, names)
    pid = part_ids(me)
    sizes = {}
    for p in pid:
        sizes[p] = sizes.get(p, 0) + 1
    main = max(sizes, key=sizes.get)
    seg = {n: bone_axis(arm, n) for n in names}
    ear_seg = {n: (seg[n][0], seg[EAR2[n]][1]) for n in EAR}
    table = weld_and_smooth(me, table, passes=0)             # weld seams first
    out = []
    loose = []
    for i, v in enumerate(me.vertices):
        p = v.co
        w = dict(table[i])
        if pid[i] != main:
            loose.append(i)
            side = "l" if p.x > 0 else "r"
            if p.z < 0.12:                                                   # a boot
                k = smoothstep(0.07, 0.115, p.z)                             # ankle blend up the cuff
                w = {"foot_" + side: 1.0 - 0.7 * k, "shin_" + side: 0.7 * k}
            elif p.y > 0.05:                                                 # the tail ball
                w = {"tail": 1.0}
            else:                                                            # belt pouches
                w = {"hips": 0.75, "thigh_" + side: 0.25}
            out.append(w)
            continue
        side = "l" if p.x > 0 else "r"
        ear = "ear_" + side
        t, d = seg_param(p, ear_seg[ear][0], ear_seg[ear][1])
        if d < 0.075 and p.y > 0.06 + 0.055 * smoothstep(0.78, 0.66, p.z) and abs(p.x) > 0.075 and p.z > 0.52:    # an ear flap: behind the face, outside the head
            g = smoothstep(0.80, 0.68, p.z)                                  # the cap and the ear's root stay on the head
            k1 = smoothstep(0.20, 0.50, t) * g
            k2 = smoothstep(0.45, 0.85, t)
            out.append({"head": 1.0 - k1, ear: k1 * (1.0 - k2), EAR2[ear]: k1 * k2})
            loose.append(i)                                                  # keep these exactly as set
            continue
        out.append(arm_fix(p, w) if not RAW else w)
    if "--list-ear" in sys.argv:
        for i, v in enumerate(me.vertices):
            if v.co.x < 0 and v.co.z < 0.66 and out[i].get("ear_r_2", 0) > 0.05:
                print("EAR", i, tuple(round(c, 3) for c in v.co), round(out[i]["ear_r"], 2))
    out = weld_and_smooth(me, out, passes=4, factor=0.5, skip=loose)
    write_weights(obj, out)


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else sys.argv[1:]
    debug = argv[argv.index("--debug-weights") + 1] if "--debug-weights" in argv else None
    reset_scene()
    obj, maps, shift = prepare_mesh()
    tmp = tempfile.mkdtemp(prefix="red_")
    # textures: all three PBR maps, 512 px
    mat = obj.data.materials[0].copy()
    mat.name = "red_ross"
    obj.data.materials.clear()
    obj.data.materials.append(mat)
    replace_material_images(mat, downscale_all(maps, MAX_TEX), tmp, "red")

    # skeleton
    spec = [(n, p, h, t) for n, (p, h, t) in J.items()]
    arm = build_armature("red_rig", spec)
    bpy.ops.object.mode_set(mode="EDIT")
    for n, z in SOCKET_ROLL_Z.items():
        arm.data.edit_bones[n].align_roll(Vector(z))
    bpy.ops.object.mode_set(mode="OBJECT")
    bind_auto(obj, arm)
    fix_weights(obj, arm)

    if debug:
        dbg_render(obj, arm, debug)
        return
    if "--sheet" in argv:
        i = argv.index("--sheet")
        names = argv[i + 2].split(",") if len(argv) > i + 2 and not argv[i + 2].startswith("--") else None
        sheet(obj, arm, argv[i + 1], names)
        return
    if "--pose-test" in argv:
        pose_test(obj, arm, argv[argv.index("--pose-test") + 1])
        return
    if "--no-clips" not in argv:
        import red_clips
        table = red_clips.build(arm)
        for row in table:
            print("clip %-9s %2d frames (%.2f s)  %d keys%s" % (row[0], row[1], row[1] / FPS, row[2], "  loop" if row[3] else ""))
    if "--no-clips" not in argv:
        write_clip_keys(os.path.join(GAME_DIR, "data", "combat", "red_clip_keys.json"), red_clips.CLIPS, "Red", red_clips.NOTES)
    obj.name = "red_ross"
    arm.name = "red_ross_armature"
    export_glb(OUT, [obj, arm], animations=("--no-clips" not in argv))
    print("tris", tri_count(obj), "bones", len(arm.data.bones))


def dbg_render(obj, arm, prefix):
    weight_colors(obj)
    obj.data.materials.clear()
    obj.data.materials.append(_emission_material("dbg", "dbg"))
    cam = setup_render(700, 800, 1.05)
    for az, tag in ((0, "front"), (90, "side"), (180, "back")):
        aim_ortho(cam, az, (0, 0, 0.475))
        render_to(prefix + "_%s.png" % tag)


from rigkit import _emission_material, _update  # noqa: E402

TEST_POSES = [
    ("rest", {}),
    ("arms_up", {"upper_arm_l": (0, -75, 0), "upper_arm_r": (0, 75, 0), "forearm_l": (-40, 0, 0), "forearm_r": (-40, 0, 0)}),
    ("arms_fwd_bend", {"upper_arm_l": (-90, 0, 0), "upper_arm_r": (-90, 0, 0), "spine": (25, 0, 0), "head": (-10, 0, 0),
                       "ear_l": (0, 0, -35), "ear_r": (0, 0, 35), "thigh_l": (-45, 0, 0), "shin_l": (60, 0, 0)}),
    ("twist", {"spine": (0, 0, 35), "chest": (0, 0, 20), "head": (0, 0, -30), "upper_arm_r": (-120, 0, 0), "shoulder_r": (-30, 0, 0), "forearm_r": (-60, 0, 0),
               "ear_l": (30, 0, 0), "ear_r": (30, 0, 0)}),
]


def attach_preview_sword(arm, sword="sword_katana_cyan.glb"):
    objs = import_glb(os.path.join(GAME_DIR, "art", "final", "weapons", sword))
    sw = [o for o in objs if o.type == "MESH"][0]
    for o in objs:
        if o is not sw and o.parent is None:
            o.parent = None
    sw.parent = arm
    sw.parent_type = "BONE"
    sw.parent_bone = "weapon_socket"
    bl = arm.data.bones["weapon_socket"].length
    sw.matrix_parent_inverse = Matrix.Translation((0, -bl, 0))
    sw.location = (0, 0, 0)
    sw.rotation_mode = "XYZ"
    sw.rotation_euler = (-math.pi / 2, 0, 0)       # glTF sword frame (blade +Y) -> the bone's frame (Y along the bone)
    return sw


def sheet(obj, arm, prefix, names):
    """Contact sheet of each clip's key poses (side and three-quarter views, sword in hand) for review."""
    import red_clips
    from PIL import Image, ImageDraw
    sw = attach_preview_sword(arm)
    show_materials_unlit([obj, sw])
    cam = setup_render(330, 420, 1.9)
    rig = Rig(arm)
    sc = bpy.context.scene
    apply_pose(rig, red_clips.CLIPS["idle"]["keys"][0][1])
    _update()
    pbs = arm.pose.bones["weapon_socket"]
    m3 = arm.data.bones["weapon_socket"].matrix_local.to_3x3()
    print("DBG bone axes X", tuple(round(c, 2) for c in m3.col[0]), "Y", tuple(round(c, 2) for c in m3.col[1]), "Z", tuple(round(c, 2) for c in m3.col[2]))
    print("DBG socket head", tuple(round(c, 3) for c in pbs.head), "tail", tuple(round(c, 3) for c in pbs.tail))
    zs = sorted(sw.data.vertices, key=lambda v: v.co.z)
    print("DBG sword local lowest/highest", tuple(round(c, 3) for c in zs[0].co), tuple(round(c, 3) for c in zs[-1].co))
    for tag, vv in (("low", zs[0]), ("high", zs[-1])):
        print("DBG world", tag, tuple(round(c, 3) for c in (sw.matrix_world @ vv.co)))
    for name in (names or list(red_clips.CLIPS)):
        keys = red_clips.CLIPS[name]["keys"]
        cols = []
        for frame, pose in keys:
            apply_pose(rig, pose)
            _update()
            col = Image.new("RGB", (330, 840), (220, 220, 220))
            for row, az in enumerate((90, 35)):
                aim_ortho(cam, az, (0, 0, 0.5))
                render_to(prefix + "_tmp.png")
                col.paste(Image.open(prefix + "_tmp.png").convert("RGB"), (0, 420 * row))
            ImageDraw.Draw(col).text((6, 6), "%s f%d" % (name, frame), fill=(0, 0, 0))
            cols.append(col)
        img = Image.new("RGB", (330 * len(cols), 840))
        for i, c in enumerate(cols):
            img.paste(c, (330 * i, 0))
        img.save("%s_%s.png" % (prefix, name))
        print("sheet", name)


def stretch_report(obj, arm, rig, pose, label):
    """Prints the vertices whose edges stretch the most in a pose (a spike finder)."""
    apply_pose(rig, pose)
    bpy.context.view_layer.update()
    dg = bpy.context.evaluated_depsgraph_get()
    ev = obj.evaluated_get(dg)
    me = ev.to_mesh()
    rest = obj.data
    worst = []
    for e in rest.edges:
        a, b = e.vertices
        l0 = (rest.vertices[a].co - rest.vertices[b].co).length
        l1 = (me.vertices[a].co - me.vertices[b].co).length
        if l0 > 1e-5:
            worst.append((l1 / l0, a, b))
    worst.sort(reverse=True)
    print("stretch", label, [("%.1f" % r, tuple(round(c, 2) for c in rest.vertices[a].co)) for r, a, b in worst[:4]])
    ev.to_mesh_clear()


def pose_test(obj, arm, prefix):
    stretch_report(obj, arm, Rig(arm), TEST_POSES[3][1], "twist")
    show_materials_unlit([obj])
    cam = setup_render(1600, 800, 1.6)
    rig = Rig(arm)
    for az, tag in ((0, "front"), (90, "side")):
        pass
    sc = bpy.context.scene
    sc.render.resolution_x = 400 * len(TEST_POSES)
    cam.data.ortho_scale = 1.0 * len(TEST_POSES)
    for az, tag in ((0, "front"), (50, "three")):
        # lay the posed copies side by side by rendering each into its own strip
        from PIL import Image
        strips = []
        for name, pose in TEST_POSES:
            apply_pose(rig, pose)
            bpy.context.view_layer.update()
            sc.render.resolution_x = 500
            sc.render.resolution_y = 800
            cam.data.ortho_scale = 1.0
            aim_ortho(cam, az, (0, 0, 0.5))
            render_to(prefix + "_tmp.png")
            strips.append(Image.open(prefix + "_tmp.png").convert("RGB").copy())
        sheet = Image.new("RGB", (500 * len(strips), 800))
        for i, im in enumerate(strips):
            sheet.paste(im, (500 * i, 0))
        sheet.save(prefix + "_%s.png" % tag)

main()
