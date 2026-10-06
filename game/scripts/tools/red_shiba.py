"""Builds the playable placeholder Red: the locked shiba (red_proto_f.py, Ross's pick) plus the bare
movement clips, exported as game/art/placeholder/characters/red/red_shiba.glb.

Scope (Ross, 2026-10-06): "dont do too much animation at this phase of development because we may
ultimately outsource our character models". So this is the minimum the game plays:
    idle, walk, run, jump (rise), fall, land
Rough blockout poses, a light rubber squash and stretch on the root bone, 15 fps stepped like the
first placeholder. No gesture clips, no ear emotes, no tail wag. The game looks clips up by NAME
only (see "Model contract" in docs/style_guide.md), so whoever builds the final Red only has to
supply a .glb with those six names.

Frames (15 fps; a loop is `frames` keys plus a closing key equal to the first; a one-shot holds
its last key):
    idle 22 loop (1.47 s)   walk 12 loop (0.80 s)   run 9 loop (0.60 s)
    jump  6 once (0.40 s)   fall  8 loop (0.53 s)   land 4 once (0.27 s)

Run (Blender as a Python module; Python 3.11):
    python3 -m venv /tmp/blockout_venv
    /tmp/blockout_venv/bin/pip install bpy==5.0.1 pillow numpy
    /tmp/blockout_venv/bin/python game/scripts/tools/red_shiba.py
Output: game/art/placeholder/characters/red/red_shiba.glb (model, 17-bone rig, sword, textures, clips)
"""

import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "prototypes"))
import red_proto_f as shiba  # noqa: E402  (builds nothing on import)
from red_proto_de_kit import bpy, export_glb, Euler, Quaternion, Vector  # noqa: E402

GAME_DIR = os.path.abspath(os.path.join(HERE, "..", ".."))
OUT_DIR = os.path.join(GAME_DIR, "art", "placeholder", "characters", "red")
GLB_PATH = os.path.join(OUT_DIR, "red_shiba.glb")
FPS = 15
BOOT_Z = 0.12          # shin tip height at rest (feet planted); the boots hang below it


class Rig:
    """Posing helpers in ARMATURE axes (X right, Y back, Z up; Red faces -Y)."""

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
        """Degrees about the armature's X (positive tips things above the joint forward), Y, Z."""
        world = Euler((math.radians(x), math.radians(y), math.radians(z)), "XYZ").to_matrix()
        rest = self.rest3[bone]
        self.obj.pose.bones[bone].rotation_quaternion = (rest.inverted() @ world @ rest).to_quaternion()

    def move(self, bone, x=0.0, y=0.0, z=0.0):
        self.obj.pose.bones[bone].location = self.rest3[bone].inverted() @ Vector((x, y, z))

    def squash(self, k):
        """Rubber squash and stretch on the root: k > 0 stretches tall and thin, k < 0 squashes
        short and wide. Keeps the volume about the same. The feet are at the root, so they stay put."""
        sz = 1.0 + k
        sxy = 1.0 / math.sqrt(max(sz, 0.1))
        world = (sxy, sxy, sz)                      # armature X, Y, Z
        rest = self.rest3["root"]
        local = [sum((rest[j][i] ** 2) * world[j] for j in range(3)) for i in range(3)]
        self.obj.pose.bones["root"].scale = Vector(local)

    def lowest_boot(self):
        bpy.context.view_layer.update()
        return min((self.obj.matrix_world @ self.obj.pose.bones[b].tail).z for b in ("shin_r", "shin_l"))

    def key(self, frame):
        for pb in self.obj.pose.bones:
            pb.keyframe_insert("rotation_quaternion", frame=frame)
            pb.keyframe_insert("location", frame=frame)
        self.obj.pose.bones["root"].keyframe_insert("scale", frame=frame)


def smooth(k):
    k = max(0.0, min(1.0, k))
    return k * k * (3 - 2 * k)


def plant_feet(rig, extra=0.0):
    """Lift or drop the hips so the lowest boot touches the ground (plus `extra` for a bounce)."""
    rig.move("hips", z=0.0)
    rig.move("hips", z=BOOT_Z - rig.lowest_boot() + extra)


# ---------------------------------------------------------------- poses (t runs 0..1 around the clip)
def pose_idle(rig, t):
    """Breathing: a slow, light squash and stretch and a tiny head nod. The sword arm stays put."""
    s = math.sin(2 * math.pi * t)
    rig.reset()
    rig.squash(0.018 * s)
    rig.rotate("head", x=-2.0 * s)
    rig.rotate("upper_arm_l", x=-3 * s)


def pose_gait(rig, t, thigh, knee, arm, bob, lean, squash):
    phase = 2 * math.pi * t
    s = math.sin(phase)
    rig.reset()
    rig.squash(squash * math.cos(phase * 2))        # a squash on every footfall
    rig.rotate("spine", x=lean, z=4 * s)
    rig.rotate("head", x=-lean * 0.7, z=-3 * s)
    for side, sign in (("r", 1.0), ("l", -1.0)):
        swing = s * sign
        rig.rotate("thigh_" + side, x=-thigh * swing)
        rig.rotate("shin_" + side, x=max(0.0, math.sin(phase + (0.9 if sign > 0 else 0.9 + math.pi))) * knee)
    rig.rotate("upper_arm_l", x=arm * s)
    rig.rotate("forearm_l", x=-12 - arm * 0.3)
    rig.rotate("upper_arm_r", x=-arm * 0.15 * s)      # the sword arm barely swings
    plant_feet(rig, bob * abs(s))


def pose_jump(rig, t):
    """Rise, one-shot. Quick crouch squash (anticipation), then a tall stretch that is held."""
    rig.reset()
    squash = -0.16 if t < 0.2 else (0.14 if t < 0.5 else 0.10)
    rig.squash(squash)
    if t < 0.2:                                      # crouch: arms swing back
        rig.rotate("spine", x=8)
        rig.rotate("upper_arm_l", x=25)
        rig.rotate("head", x=-5)
        return
    rig.rotate("spine", x=-4)
    rig.rotate("head", x=6)
    rig.rotate("thigh_l", x=-45)
    rig.rotate("shin_l", x=45)
    rig.rotate("thigh_r", x=15)
    rig.rotate("shin_r", x=25)
    rig.rotate("upper_arm_l", x=-125, y=-12)
    rig.rotate("upper_arm_r", x=-45)
    rig.rotate("ear_l", x=-20)
    rig.rotate("ear_r", x=-20)


def pose_fall(rig, t):
    """Loop: stretched a little, arms flung up and out, boots paddling."""
    phase = 2 * math.pi * t
    s = math.sin(phase)
    rig.reset()
    rig.squash(0.05)
    rig.rotate("spine", x=-3)
    rig.rotate("head", x=-3, z=3 * s)
    rig.rotate("thigh_l", x=-28 + 12 * s)
    rig.rotate("shin_l", x=40 + 12 * s)
    rig.rotate("thigh_r", x=8 - 12 * s)
    rig.rotate("shin_r", x=30 - 12 * s)
    rig.rotate("upper_arm_l", x=-95 + 15 * s, y=-30)
    rig.rotate("upper_arm_r", x=-50 + 8 * s)
    rig.rotate("ear_l", x=25)
    rig.rotate("ear_r", x=25)


def pose_land(rig, t):
    """One-shot: a big squash on impact, a small overshoot, then exactly the rest pose."""
    rig.reset()
    if t < 0.3:
        k = -0.22
    elif t < 0.6:
        k = -0.10
    elif t < 0.9:
        k = 0.04
    else:
        return                                       # rest pose (squash 0, everything neutral)
    rig.squash(k)
    rig.rotate("spine", x=-k * 40)
    rig.rotate("upper_arm_l", x=-30 * abs(k) * 4)


ANIMATIONS = {
    # name: (frames, pose function, loops)
    "idle": (22, pose_idle, True),
    "walk": (12, lambda r, t: pose_gait(r, t, thigh=28, knee=32, arm=24, bob=0.012, lean=3, squash=-0.03), True),
    "run": (9, lambda r, t: pose_gait(r, t, thigh=50, knee=75, arm=50, bob=0.04, lean=14, squash=-0.05), True),
    "jump": (6, pose_jump, False),
    "fall": (8, pose_fall, True),
    "land": (4, pose_land, False),
}


def build_animations(arm_obj):
    scene = bpy.context.scene
    scene.render.fps = FPS
    bpy.context.preferences.edit.keyframe_new_interpolation_type = "CONSTANT"
    rig = Rig(arm_obj)
    anim = arm_obj.animation_data_create()
    actions = []
    for name, (frames, pose, loops) in ANIMATIONS.items():
        action = bpy.data.actions.new(name)
        action.use_fake_user = True
        anim.action = action
        for frame in range(frames + 1):
            pose(rig, (frame % frames) / frames if loops else frame / frames)
            rig.key(frame)
        actions.append((name, action))
        print("clip %-5s %2d frames (%.2f s)%s" % (name, frames, frames / FPS, "" if loops else "  one-shot"))
    anim.action = None
    for name, action in actions:                      # one NLA track per clip = one named glTF clip
        track = anim.nla_tracks.new()
        track.name = name
        track.strips.new(name, 0, action).name = name
    rig.reset()


def main():
    os.makedirs(OUT_DIR, exist_ok=True)
    arm_obj, body_obj, sword_obj = shiba.build()
    build_animations(arm_obj)
    bpy.context.scene.frame_start = 0
    tris = shiba.triangle_count(body_obj) + shiba.triangle_count(sword_obj)
    print("triangles %d (body %d + sword %d), bones %d" % (tris, shiba.triangle_count(body_obj),
          shiba.triangle_count(sword_obj), len(arm_obj.data.bones)))
    export_glb(GLB_PATH, animations=True)


main()
