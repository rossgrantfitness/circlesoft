"""Rigging and posing kit for the Technical Artist's tools (rig_red.py, rig_cyberwolf.py).
Everything here works on a scratch Blender scene; nothing touches Ross's originals.

Conventions (see ta_lib.py): the model faces Blender -Y (Godot +Z), up is +Z, feet at z = 0, x = 0 on the
body's centre line. Red's RIGHT side is -X and her LEFT side is +X (suffix _r / _l).
"""
import math
import os

from ta_lib import *  # noqa: F401,F403
import bpy
import bmesh
from mathutils import Euler, Matrix, Quaternion, Vector

FPS = 15


# ---------------------------------------------------------------- skeleton
def build_armature(name, joints):
    """joints: list of (bone, parent or None, head xyz, tail xyz[, roll]) in model space. Returns the armature object."""
    data = bpy.data.armatures.new(name)
    arm = bpy.data.objects.new(name, data)
    bpy.context.scene.collection.objects.link(arm)
    bpy.context.view_layer.objects.active = arm
    arm.select_set(True)
    bpy.ops.object.mode_set(mode="EDIT")
    made = {}
    for item in joints:
        bone, parent, head, tail = item[:4]
        eb = data.edit_bones.new(bone)
        eb.head = Vector(head)
        eb.tail = Vector(tail)
        eb.roll = item[4] if len(item) > 4 else 0.0
        if parent:
            eb.parent = made[parent]
            # connect only a chain whose parent's tail is exactly this head (cleaner rigs, same pose result)
            if (made[parent].tail - eb.head).length < 1e-6:
                eb.use_connect = True
        made[bone] = eb
    bpy.ops.object.mode_set(mode="OBJECT")
    data.display_type = "STICK"
    return arm


def bind_auto(mesh_obj, arm):
    """parent_set with automatic weights (bone heat)."""
    bpy.ops.object.select_all(action="DESELECT")
    mesh_obj.select_set(True)
    arm.select_set(True)
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.parent_set(type="ARMATURE_AUTO")


# ---------------------------------------------------------------- weights
def weights_of(mesh_obj, bone_names):
    """List (one per vertex) of {bone: weight}."""
    names = {g.index: g.name for g in mesh_obj.vertex_groups}
    out = []
    for v in mesh_obj.data.vertices:
        out.append({names[g.group]: g.weight for g in v.groups if g.weight > 1e-6})
    return out


def write_weights(mesh_obj, table, max_influences=4):
    """table: list of {bone: weight} per vertex. Normalised, trimmed to max_influences, written to groups."""
    for g in list(mesh_obj.vertex_groups):
        mesh_obj.vertex_groups.remove(g)
    groups = {}
    for i, w in enumerate(table):
        items = sorted(((b, x) for b, x in w.items() if x > 1e-4), key=lambda t: -t[1])[:max_influences]
        total = sum(x for _, x in items) or 1.0
        for b, x in items:
            if b not in groups:
                groups[b] = mesh_obj.vertex_groups.new(name=b)
            groups[b].add([i], x / total, "REPLACE")


def bone_axis(arm, bone):
    b = arm.data.bones[bone]
    return b.head_local.copy(), b.tail_local.copy()


def seg_param(p, a, b):
    """(t along a->b clamped 0..1, distance to the segment)."""
    ab = b - a
    t = max(0.0, min(1.0, (p - a).dot(ab) / max(ab.length_squared, 1e-12)))
    return t, (p - (a + ab * t)).length


def smoothstep(e0, e1, x):
    k = max(0.0, min(1.0, (x - e0) / (e1 - e0)))
    return k * k * (3 - 2 * k)


def weld_and_smooth(me, table, passes=2, factor=0.5, skip=None):
    """Corners that sit at the same spot share one set of weights (so seams cannot tear), then the weights are relaxed
    toward their neighbours a little (so a shoulder bends instead of creasing). Vertices in `skip` keep their weights."""
    key = lambda co: (round(co.x * 5000), round(co.y * 5000), round(co.z * 5000))
    keys = [key(v.co) for v in me.vertices]
    groups = {}
    for i, k in enumerate(keys):
        groups.setdefault(k, []).append(i)
    merged = {}
    for k, idx in groups.items():
        acc = {}
        for i in idx:
            for b, x in table[i].items():
                acc[b] = acc.get(b, 0.0) + x / len(idx)
        merged[k] = acc
    nbrs = {k: set() for k in groups}
    for e in me.edges:
        a, b = keys[e.vertices[0]], keys[e.vertices[1]]
        if a != b:
            nbrs[a].add(b)
            nbrs[b].add(a)
    frozen = set(keys[i] for i in (skip or ()))
    for _ in range(passes):
        nxt = {}
        for k, w in merged.items():
            if k in frozen or not nbrs[k]:
                nxt[k] = w
                continue
            avg = {}
            for n in nbrs[k]:
                for b, x in merged[n].items():
                    avg[b] = avg.get(b, 0.0) + x / len(nbrs[k])
            out = {}
            for b in set(w) | set(avg):
                out[b] = (1.0 - factor) * w.get(b, 0.0) + factor * avg.get(b, 0.0)
            nxt[k] = out
        merged = nxt
    return [dict(merged[k]) for k in keys]



# ---------------------------------------------------------------- posing
class Rig:
    """Posing in model axes (X toward her left, Y toward her back, Z up). Rotations are in degrees about the model's
    X (positive tips things above the joint forward), Y and Z, applied about the bone's joint, relative to the
    parent's current orientation (so an arm bends the same way whatever the spine is doing)."""

    def __init__(self, arm_obj):
        self.obj = arm_obj
        self.rest3 = {b.name: b.matrix_local.to_3x3() for b in arm_obj.data.bones}
        for pb in arm_obj.pose.bones:
            pb.rotation_mode = "QUATERNION"

    def reset(self):
        for pb in self.obj.pose.bones:
            pb.rotation_quaternion = Quaternion((1, 0, 0, 0))
            pb.location = Vector((0, 0, 0))
            pb.scale = Vector((1, 1, 1))

    def rotate(self, bone, x=0.0, y=0.0, z=0.0):
        world = Euler((math.radians(x), math.radians(y), math.radians(z)), "XYZ").to_matrix()
        rest = self.rest3[bone]
        self.obj.pose.bones[bone].rotation_quaternion = (rest.inverted() @ world @ rest).to_quaternion()

    def move(self, bone, x=0.0, y=0.0, z=0.0):
        self.obj.pose.bones[bone].location = self.rest3[bone].inverted() @ Vector((x, y, z))

    def squash(self, k, bone="root"):
        """Rubber squash and stretch about the bone: k > 0 taller and thinner, k < 0 shorter and wider."""
        sz = 1.0 + k
        sxy = 1.0 / math.sqrt(max(sz, 0.1))
        world = (sxy, sxy, sz)
        rest = self.rest3[bone]
        local = [sum((rest[j][i] ** 2) * world[j] for j in range(3)) for i in range(3)]
        self.obj.pose.bones[bone].scale = Vector(local)

    def key(self, frame, scale_bones=("root",)):
        for pb in self.obj.pose.bones:
            pb.keyframe_insert("rotation_quaternion", frame=frame)
            pb.keyframe_insert("location", frame=frame)
        for b in scale_bones:
            self.obj.pose.bones[b].keyframe_insert("scale", frame=frame)


def _update():
    bpy.context.view_layer.update()


def _bone_dir(pb):
    return (pb.matrix.to_3x3() @ Vector((0, 1, 0))).normalized()


def _align_bone(rig, name, target_dir, roll_deg=0.0):
    """Turns a pose bone (about its own head) so its Y axis points along target_dir (shortest arc)."""
    pb = rig.obj.pose.bones[name]
    cur = _bone_dir(pb)
    q = cur.rotation_difference(Vector(target_dir).normalized())
    m3 = q.to_matrix() @ pb.matrix.to_3x3()
    if roll_deg:
        axis = Vector(target_dir).normalized()
        m3 = Matrix.Rotation(math.radians(roll_deg), 3, axis) @ m3
    m = m3.to_4x4()
    m.translation = pb.matrix.translation
    pb.matrix = m
    _update()


def _two_bone_ik(rig, upper, fore, hand, target, pole):
    """Places the elbow so the wrist (head of `hand`) reaches `target` (model space), bending toward `pole`."""
    ob = rig.obj
    pu, pf, ph = ob.pose.bones[upper], ob.pose.bones[fore], ob.pose.bones[hand]
    S = pu.head.copy()
    l1 = (ob.data.bones[fore].head_local - ob.data.bones[upper].head_local).length
    l2 = (ob.data.bones[hand].head_local - ob.data.bones[fore].head_local).length
    T = Vector(target)
    d = T - S
    dist = max(1e-4, min(d.length, (l1 + l2) * 0.999))
    dn = d.normalized()
    a = (l1 * l1 - l2 * l2 + dist * dist) / (2 * dist)
    h = math.sqrt(max(l1 * l1 - a * a, 0.0))
    pv = Vector(pole) - S
    pv = (pv - dn * pv.dot(dn))
    pv = pv.normalized() if pv.length > 1e-6 else Vector((0, 0, -1))
    E = S + dn * a + pv * h
    _align_bone(rig, upper, E - S)
    _align_bone(rig, fore, (S + dn * dist) - E)


def _plant(rig, extra=0.0):
    ob = rig.obj
    def sole():
        zs = []
        for side in ("l", "r"):
            f = ob.pose.bones["foot_" + side]
            zs.append(f.head.z - 0.051)
            zs.append(f.tail.z - 0.021)
        return min(zs)
    _update()
    cur = ob.pose.bones["hips"].location.copy()
    rig.move("hips", z=0.0) if False else None
    dz = -sole() + extra
    # hips location is in the hips bone's rest frame (a vertical bone): z of the model == local y
    ob.pose.bones["hips"].location = cur + rig.rest3["hips"].inverted() @ Vector((0, 0, dz))
    _update()


def apply_pose(rig, pose):
    """pose: dict. Keys are bone names -> (x, y, z) degrees (FK); 'loc:<bone>' -> (x, y, z) metres; 'squash' -> k (root);
    'squash:<bone>' -> k. Extras: 'plant' (True: lower the lowest sole to the floor, or a float extra lift),
    'ik_r' / 'ik_l': (wrist target xyz, elbow pole xyz) in model metres, 'aim_r' / 'aim_l': (blade direction xyz[, roll deg])
    to point the held thing's long axis (applied last, after the arms)."""
    rig.reset()
    extras = {}
    for k, v in pose.items():
        if k == "squash":
            rig.squash(v)
        elif k.startswith("squash:"):
            rig.squash(v, k.split(":", 1)[1])
        elif k.startswith("loc:"):
            rig.move(k.split(":", 1)[1], *v)
        elif k in ("plant", "ik_r", "ik_l", "aim_r", "aim_l"):
            extras[k] = v
        else:
            rig.rotate(k, *v)
    _update()
    if extras.get("plant") not in (None, False):
        _plant(rig, 0.0 if extras["plant"] is True else float(extras["plant"]))
    for side in ("r", "l"):
        if "ik_" + side in extras:
            t, pole = extras["ik_" + side]
            _two_bone_ik(rig, "upper_arm_" + side, "forearm_" + side, "hand_" + side, t, pole)
    for side, sock in (("r", "weapon_socket"), ("l", "prop_socket")):
        if "aim_" + side in extras:
            v = extras["aim_" + side]
            d, roll = (v[0], v[1]) if len(v) == 2 and isinstance(v[0], (tuple, list)) else (v, 0.0)
            _align_socket(rig, "hand_" + side, sock, d, roll)


def _align_socket(rig, hand, sock, target_dir, roll_deg):
    """Turns the hand so the socket's +Y axis (the blade) points along target_dir."""
    ob = rig.obj
    ph = ob.pose.bones[hand]
    ps = ob.pose.bones[sock]
    cur = _bone_dir(ps)
    q = cur.rotation_difference(Vector(target_dir).normalized())
    m3 = q.to_matrix() @ ph.matrix.to_3x3()
    if roll_deg:
        m3 = Matrix.Rotation(math.radians(roll_deg), 3, Vector(target_dir).normalized()) @ m3
    m = m3.to_4x4()
    m.translation = ph.matrix.translation
    ph.matrix = m
    _update()


def build_clips(arm_obj, clips, scale_bones=("root",)):
    """clips: name -> dict(fps frames=[(frame, pose dict), ...], length=N, loop=bool). Keys are held (stepped).
    A loop's closing key (frame == length) repeats the first pose. Returns a printable table."""
    scene = bpy.context.scene
    scene.render.fps = FPS
    bpy.context.preferences.edit.keyframe_new_interpolation_type = "CONSTANT"
    rig = Rig(arm_obj)
    anim = arm_obj.animation_data_create()
    made = []
    table = []
    for name, spec in clips.items():
        action = bpy.data.actions.new(name)
        action.use_fake_user = True
        anim.action = action
        frames = sorted(spec["keys"], key=lambda k: k[0])
        for frame, pose in frames:
            apply_pose(rig, pose)
            rig.key(frame, scale_bones)
        last = frames[-1][0]
        if spec.get("loop"):
            length = spec["length"]
            if last != length:                       # closing key = first pose, so the loop is seamless
                apply_pose(rig, frames[0][1])
                rig.key(length, scale_bones)
        elif spec["length"] > last:                  # one-shots: pad the end so the clip length is what was asked
            apply_pose(rig, frames[-1][1])
            rig.key(spec["length"], scale_bones)
        for fc in action.fcurves if hasattr(action, "fcurves") else []:
            for kp in fc.keyframe_points:
                kp.interpolation = "CONSTANT"
        made.append((name, action))
        table.append((name, spec["length"], len(frames), bool(spec.get("loop"))))
    anim.action = None
    for name, action in made:
        track = anim.nla_tracks.new()
        track.name = name
        track.strips.new(name, 0, action).name = name
    rig.reset()
    return table


# ---------------------------------------------------------------- debug renders (scratch only)
def _emission_material(name, color_attr=None, image=None):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    for n in list(nt.nodes):
        nt.nodes.remove(n)
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    em = nt.nodes.new("ShaderNodeEmission")
    if color_attr:
        a = nt.nodes.new("ShaderNodeAttribute")
        a.attribute_name = color_attr
        nt.links.new(a.outputs["Color"], em.inputs["Color"])
    nt.links.new(em.outputs[0], out.inputs["Surface"])
    return m


def setup_render(width, height, ortho_scale=None, samples=6):
    sc = bpy.context.scene
    sc.render.engine = "CYCLES"
    sc.cycles.samples = samples
    sc.cycles.max_bounces = 0
    sc.cycles.use_denoising = False
    sc.view_settings.view_transform = "Standard"
    sc.render.resolution_x = width
    sc.render.resolution_y = height
    sc.render.film_transparent = False
    w = bpy.data.worlds.new("dbg")
    w.use_nodes = True
    w.node_tree.nodes["Background"].inputs[0].default_value = (0.85, 0.85, 0.85, 1)
    sc.world = w
    cam = bpy.data.objects.new("dbgcam", bpy.data.cameras.new("dbgcam"))
    sc.collection.objects.link(cam)
    sc.camera = cam
    cam.data.type = "ORTHO"
    cam.data.ortho_scale = ortho_scale or 1.4
    return cam


def aim_ortho(cam, az_deg, center, dist=6.0):
    a = math.radians(az_deg)
    cam.location = Vector(center) + Vector((math.sin(a) * dist, -math.cos(a) * dist, 0.0))
    cam.rotation_euler = (math.pi / 2, 0.0, a)


def show_materials_unlit(objs):
    """Swap every glTF material for an emission of its base color texture (for previews)."""
    for o in objs:
        for slot in o.material_slots:
            nt = slot.material.node_tree
            tex = [n for n in nt.nodes if n.type == "TEX_IMAGE" and n.label == "BASE COLOR"]
            out_n = [n for n in nt.nodes if n.type == "OUTPUT_MATERIAL"][0]
            em = nt.nodes.new("ShaderNodeEmission")
            if tex:
                nt.links.new(tex[0].outputs["Color"], em.inputs["Color"])
            nt.links.new(em.outputs[0], out_n.inputs["Surface"])


def weight_colors(mesh_obj):
    """Writes a 'dbg' point color attribute: each bone gets a stable color, blended by weight."""
    names = {g.index: g.name for g in mesh_obj.vertex_groups}
    def col(bone):
        import zlib; h = (zlib.crc32(bone.encode()) % 997) / 997.0
        import colorsys
        return colorsys.hsv_to_rgb(h, 0.85, 0.95)
    attr = mesh_obj.data.color_attributes.new("dbg", "FLOAT_COLOR", "POINT")
    for i, v in enumerate(mesh_obj.data.vertices):
        r = g = b = 0.0
        tot = sum(x.weight for x in v.groups) or 1.0
        for x in v.groups:
            c = col(names[x.group])
            r += c[0] * x.weight / tot; g += c[1] * x.weight / tot; b += c[2] * x.weight / tot
        attr.data[i].color = (r, g, b, 1.0)
    return col


def render_to(path):
    sc = bpy.context.scene
    sc.render.filepath = path
    bpy.ops.render.render(write_still=True)


def write_clip_keys(path, clips, who, notes=None):
    """Writes where each clip's key poses sit (frames and seconds), for whoever writes `anim.keys` in the move data."""
    import json
    os.makedirs(os.path.dirname(path), exist_ok=True)
    data = {"_about": "Key poses of %s's clips (15 fps, stepped; written by scripts/tools/%s). Use these seconds as clip_s in moves.json anim.keys." % (who, "rig_*.py"),
            "fps": FPS, "clips": {}}
    for name, c in clips.items():
        data["clips"][name] = {"length_s": round(c["length"] / FPS, 4), "loop": bool(c.get("loop")),
                               "keys": [{"frame": f, "clip_s": round(f / FPS, 4)} for f, _ in sorted(c["keys"], key=lambda k: k[0])]}
        if notes and notes.get(name):
            data["clips"][name]["note"] = notes[name]
    with open(path, "w") as f:
        json.dump(data, f, indent=1)
        f.write("\n")
    print("wrote", os.path.relpath(path, ROOT))
