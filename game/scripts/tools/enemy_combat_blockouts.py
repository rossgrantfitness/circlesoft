"""Placeholder Grunt and Brute for the combat sandbox, built from the Signals grunt kit (enemy_signals_grunt.py,
enemy_kit.py, cast_kit.py: read-only here; nothing of theirs is edited and the old battle enemies are not rebuilt).

  * enm_sandbox_grunt   the Signals grunt body as is (about 1.0 m, 17 shared bones, 128 px sheets). It is the FALLBACK
                        Grunt: the sandbox's real Grunt is Ross's Cyberwolf Sentinel (rig_cyberwolf.py).
  * enm_sandbox_brute   the same body scaled 1.5x, in the darker "variant" colours, with armor plates (pauldrons, chest
                        and back plates, a helmet, gauntlets, a belt). Bigger, armored, slower.

Clips (15 fps, stepped; the same names as the wolf so the code treats them alike): idle, walk, attack_windup,
attack_swing. Everything else (hit, launch, tumble, down, get up) is a code tween, per the contract.

Outputs: game/art/placeholder/enemies/sandbox_grunt/enm_sandbox_grunt.glb and
         game/art/placeholder/enemies/sandbox_brute/enm_sandbox_brute.glb  (+ their .png sheets)
Run (see ta_lib.py; needs bpy + pillow + numpy):
    /tmp/ta_venv/bin/python game/scripts/tools/enemy_combat_blockouts.py
"""
import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from enemy_kit import *  # noqa: E402,F403
import enemy_kit  # noqa: E402

# Pull the Grunt class and its constants out of the existing script WITHOUT running its main() (which would rebuild
# the old battle enemies' files).
_src = open(os.path.join(HERE, "enemy_signals_grunt.py")).read()
_src = _src[:_src.rindex("\nmain()")]
KIT = {"__name__": "enemy_signals_grunt_kit", "__file__": os.path.join(HERE, "enemy_signals_grunt.py")}
exec(compile(_src, "enemy_signals_grunt.py", "exec"), KIT)
Grunt = KIT["Grunt"]
BASE_COLORS = KIT["BASE_COLORS"]
VARIANT_COLORS = KIT["VARIANT_COLORS"]
JOINTS = KIT["JOINTS"]
HEAD_C = KIT["HEAD_C"]

FPS_ = 15


# ---------------------------------------------------------------- clips (FK only: the 17-bone rig has no hand bones)
def add_clip(arm, name, length, keys, loop=False):
    bpy.context.scene.render.fps = FPS_
    bpy.context.preferences.edit.keyframe_new_interpolation_type = "CONSTANT"
    rig = Rig(arm)
    anim = arm.animation_data_create()
    action = bpy.data.actions.new(name)
    action.use_fake_user = True
    anim.action = action
    frames = sorted(keys, key=lambda k: k[0])
    for frame, fn in frames:
        rig.reset()
        fn(rig)
        rig.key(frame)
    if frames[-1][0] != length:
        rig.reset()
        (frames[0][1] if loop else frames[-1][1])(rig)
        rig.key(length)
    anim.action = None
    track = anim.nla_tracks.new()
    track.name = name
    track.strips.new(name, 0, action).name = name
    rig.reset()


def pose_fn(**bones):
    """bones: name -> (x, y, z) degrees; 'hips_z' / 'hips_y' move the hips (metres)."""
    def fn(rig):
        for b, v in bones.items():
            if b == "hips_z":
                rig.move("hips", z=v)
            elif b == "hips_y":
                rig.move("hips", y=v)
            else:
                rig.rotate(b, *v)
    return fn


def combat_clips(arm, heavy):
    k = 1.0 if not heavy else 0.8
    add_clip(arm, "idle", 24, [
        (0, pose_fn(spine=(4, 0, 0), head=(-3, 0, 0), upper_arm_r=(-8, 0, 0), upper_arm_l=(-4, 0, 0))),
        (8, pose_fn(spine=(6, 0, 0), head=(-6, 0, 0), hips_z=-0.012, upper_arm_r=(-10, 0, 0), upper_arm_l=(-6, 0, 0))),
        (16, pose_fn(spine=(3, 0, 0), head=(-1, 0, 0), hips_z=0.01, upper_arm_r=(-6, 0, 0), upper_arm_l=(-3, 0, 0))),
    ], loop=True)
    step = 22 if not heavy else 16
    add_clip(arm, "walk", 16 if not heavy else 20, [
        (0, pose_fn(thigh_l=(-step, 0, 0), thigh_r=(step, 0, 0), shin_r=(step, 0, 0), spine=(8, 0, 4), upper_arm_r=(-20, 0, 0), upper_arm_l=(20, 0, 0))),
        (4 if not heavy else 5, pose_fn(spine=(8, 0, 0), hips_z=-0.02)),
        (8 if not heavy else 10, pose_fn(thigh_l=(step, 0, 0), thigh_r=(-step, 0, 0), shin_l=(step, 0, 0), spine=(8, 0, -4), upper_arm_r=(20, 0, 0), upper_arm_l=(-20, 0, 0))),
        (12 if not heavy else 15, pose_fn(spine=(8, 0, 0), hips_z=-0.02)),
    ], loop=True)
    # the wind-up must read from across the arena: arms way up, body leaning back, a held pause
    up = (-160, 0, 0) if not heavy else (-175, 0, 0)
    add_clip(arm, "attack_windup", 8, [
        (0, pose_fn(spine=(-4, 0, 0), upper_arm_r=(-70, 0, 0), upper_arm_l=(-50, 0, 0), hips_z=-0.04)),
        (2, pose_fn(spine=(-18, 0, 0), head=(8, 0, 0), upper_arm_r=up, upper_arm_l=(-150, 0, 0) if heavy else (-30, 0, 0), forearm_r=(-20, 0, 0), hips_z=0.02)),
        (4, pose_fn(spine=(-24, 0, 0), head=(12, 0, 0), upper_arm_r=up, upper_arm_l=(-160, 0, 0) if heavy else (-30, 0, 0), forearm_r=(-30, 0, 0), hips_z=0.03)),
    ])
    add_clip(arm, "attack_swing", 8, [
        (0, pose_fn(spine=(-24, 0, 0), head=(12, 0, 0), upper_arm_r=up, upper_arm_l=(-160, 0, 0) if heavy else (-30, 0, 0), hips_z=0.03)),
        (1, pose_fn(spine=(30, 0, 0), head=(-14, 0, 0), upper_arm_r=(-45, 0, 0), upper_arm_l=(-45, 0, 0) if heavy else (-20, 0, 0), thigh_l=(-24, 0, 0), thigh_r=(14, 0, 0), hips_z=-0.05)),
        (3, pose_fn(spine=(36, 0, 0), head=(-16, 0, 0), upper_arm_r=(-30, 0, 0), upper_arm_l=(-30, 0, 0) if heavy else (-14, 0, 0), thigh_l=(-30, 0, 0), thigh_r=(16, 0, 0), hips_z=-0.07)),
        (6, pose_fn(spine=(8, 0, 0), upper_arm_r=(-10, 0, 0))),
    ])


# ---------------------------------------------------------------- the two builds
class SandboxEnemy(Grunt):
    SCALE = 1.0
    ARMOR = False
    HEAVY = False

    def build_body(self):
        pm = Grunt.build_body(self)
        s = self.SCALE
        if s != 1.0:
            pm.warp = lambda v, s=s: v * s
        return pm

    def build_armor(self):
        pm = PartMesh(self.name + "_armor", [self.mat_body])
        P = self.sheet.planar
        for sx, side in ((-1, "r"), (1, "l")):
            sh = Vector((0.27 * sx, 0.0, 0.65))
            pm.add("upper_arm_" + side, SLOT_BODY, "ell", center=tuple(sh), uv=P("slate_gloss"), seg=6, rings=4, radii=(0.15, 0.15, 0.10))
            hand = Vector((-0.28, -0.03, 0.33)) if side == "r" else Vector((0.19, -0.17, 0.50))
            pm.add("forearm_" + side, SLOT_BODY, "ell", center=tuple(hand), uv=P("slate_gloss"), seg=6, rings=3, radii=(0.115, 0.11, 0.11))
        pm.add("spine", SLOT_BODY, "box", center=(0, -0.185, 0.54), uv=P("pad"), size=(0.34, 0.06, 0.26))
        pm.add("spine", SLOT_BODY, "box", center=(0, -0.20, 0.54), uv=P("slate_gloss"), size=(0.24, 0.03, 0.17))
        pm.add("spine", SLOT_BODY, "box", center=(0, 0.17, 0.54), uv=P("pad"), size=(0.32, 0.06, 0.26))
        pm.tube("hips", SLOT_BODY, (0, 0, 0.40), (0, 0, 0.45), 0.25, 0.25, seg=8, sxy=(1.0, 0.87), uv=P("slate_gloss"), drop_caps=("start", "end"), spin=22.5)
        pm.add("head", SLOT_BODY, "ell", center=(0, 0.02, 0.88), uv=P("slate_gloss"), seg=8, rings=4, radii=(0.30, 0.27, 0.16))
        pm.add("head", SLOT_BODY, "box", center=(0, -0.18, 0.84), uv=P("pad"), size=(0.14, 0.05, 0.06))     # a visor bar
        if self.SCALE != 1.0:
            pm.warp = lambda v, s=self.SCALE: v * s
        return pm

    def run(self):
        os.makedirs(self.out, exist_ok=True)
        bpy.ops.wm.read_factory_settings(use_empty=True)
        self.sheet.paint(self.body_path)
        self.paint_face()
        parts = [(self.build_body(), [0, 1])]
        if self.ARMOR:
            parts.append((self.build_armor(), [0]))
        joints = {n: (tuple(c * self.SCALE for c in h), tuple(c * self.SCALE for c in t)) for n, (h, t) in JOINTS.items()
                  if n not in ("prop_socket",) or True}
        arm = build_armature(self.name, joints)
        return finish_enemy(self.name, self.folder, parts,
                            [(self.mat_body, self.body_path), (self.mat_face, self.face_path)], arm,
                            lambda a: combat_clips(a, self.HEAVY))


class SandboxGrunt(SandboxEnemy):
    pass


class SandboxBrute(SandboxEnemy):
    SCALE = 1.5
    ARMOR = True
    HEAVY = True


def main():
    SandboxGrunt("enm_sandbox_grunt", "sandbox_grunt", BASE_COLORS, variant=False).run()
    SandboxBrute("enm_sandbox_brute", "sandbox_brute", VARIANT_COLORS, variant=True).run()


main()
