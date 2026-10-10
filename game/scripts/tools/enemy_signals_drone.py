"""Signals drone and the drone variant: placeholder blockouts in the Red house style (battle enemies).

Signals drone (docs/art_requests.md row 22): a small flying blue-gray drone, a round body with a front plate
that carries the Signals symbol (a wavy line cut by one slash), two side rotors, a status light and an
antenna on top. 4 bones (root, body, rotor_l, rotor_r), one 64x64 texture (the style guide's small-enemy size).
The origin sits on the floor under the drone; the hover height is built into the geometry (body centre 0.78).

Drone variant (row 24): same rig and body, recolored (deep slate, white-on-slate symbol plate) and two parts
swapped: the antenna becomes a siren dome and a cargo basket hangs under the belly.

One `idle` clip each (hover bob, a small tilt, rotors spinning in stepped 60-degree jumps at 15 fps). Everything
else (lunge, hit, fall) is a code tween in the battle stage.

Outputs:
  game/art/placeholder/enemies/signals_drone/enm_signals_drone.glb  (+ .png)
  game/art/placeholder/enemies/drone_variant/enm_drone_variant.glb  (+ .png)
Run: /tmp/blockout_venv/bin/python game/scripts/tools/enemy_signals_drone.py   (see enemy_kit.py)
"""

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from enemy_kit import *  # noqa: E402,F403

BODY_C = Vector((0.0, 0.0, 0.78))
BODY_R = (0.28, 0.28, 0.22)
PLATE_CENTER = (0.0, 0.78)          # plate-local x, world z
PLATE_HALF = 0.165
PLATE_Y0, PLATE_Y1 = -0.22, -0.30
ROTOR_X, ROTOR_Z = 0.42, 0.88
SYMBOL_ORIGIN, SYMBOL_PX = (0, 0), 32
RESERVED = [(0, 0), (1, 0), (0, 1), (1, 1)]

JOINTS = {
    "root": ((0, 0, 0), (0, 0, 0.1)),
    "body": ((0, 0, 0.78), (0, 0, 0.95)),
    "rotor_l": ((ROTOR_X, 0, ROTOR_Z), (ROTOR_X, 0, ROTOR_Z + 0.1)),
    "rotor_r": ((-ROTOR_X, 0, ROTOR_Z), (-ROTOR_X, 0, ROTOR_Z + 0.1)),
}
PARENTS = {"root": None, "body": "root", "rotor_l": "body", "rotor_r": "body"}

BASE_COLORS = {
    "body": ("#7894B2", "#546F8C"), "slate": ("#66707E", "#464F5C"), "blade": ("#9AA4B2", "#68727F"),
    "pink": ("#EE4D72", "#B3304F"), "white": ("#F4F6F9", "#C9CFD9"), "ink": ("#14121F", "#14121F"),
}
VARIANT_COLORS = dict(BASE_COLORS)
VARIANT_COLORS.update({"body": ("#566274", "#3A4456"), "slate": ("#7C8694", "#58616F"), "blade": ("#C9CFD9", "#8D97A5")})
GLOSS = ("body", "blade", "pink", "slate")


class Drone:
    def __init__(self, name, folder, colors, variant):
        self.name, self.folder, self.variant = name, folder, variant
        self.out = os.path.join(ENEMIES_DIR, folder)
        self.body_path = os.path.join(self.out, name + ".png")
        self.mat = "mat_" + name
        self.sheet = SmallSheet(colors, gloss=GLOSS, reserved=RESERVED)

    def paint(self):
        img = self.sheet.paint(self.body_path)
        if self.variant:
            bg, line = hex_rgb("#3A4456"), hex_rgb("#F4F6F9")
        else:
            bg, line = hex_rgb("#F4F6F9"), hex_rgb("#4F6A86")
        paint_signals_symbol(img, SYMBOL_ORIGIN, SYMBOL_PX, bg, hex_rgb("#14121F"), line, hex_rgb("#EE4D72"))
        img.save(self.body_path)

    def build_body(self):
        pm = PartMesh(self.name + "_body", [self.mat])
        S = self.sheet
        P = S.planar
        pm.add("body", SLOT_BODY, "ell", center=tuple(BODY_C), uv=P("body_gloss"), seg=8, rings=5, radii=BODY_R)
        # front plate with the Signals symbol (the front cap shows the symbol; its rim reads the ink border)
        pm.tube("body", SLOT_BODY, (0, PLATE_Y0, BODY_C.z), (0, PLATE_Y1, BODY_C.z), 0.17, 0.17, seg=8,
                uv=plate_uv(SYMBOL_ORIGIN, SYMBOL_PX, PLATE_CENTER, PLATE_HALF, PLATE_HALF), drop_caps=("start",), spin=22.5)
        pm.add("body", SLOT_BODY, "ell", center=(0, -0.235, 0.6), uv=P("pink_gloss"), seg=5, rings=3, radii=(0.06, 0.05, 0.05))   # status light
        for sx in (-1, 1):                                                              # side struts
            pm.add("body", SLOT_BODY, "box", center=(0.31 * sx, 0.0, 0.84), uv=P("slate_gloss"), size=(0.14, 0.07, 0.05))
        if not self.variant:                                                            # antenna with a pink-red tip
            pm.tube("body", SLOT_BODY, (0.0, 0.0, 0.96), (0.0, 0.0, 1.18), 0.026, 0.022, seg=4, uv=P("slate"), drop_caps=("start", "end"), spin=45)
            pm.add("body", SLOT_BODY, "ell", center=(0, 0, 1.2), uv=P("pink_gloss"), seg=5, rings=3, radii=(0.055, 0.055, 0.055))
        else:                                                                           # siren dome instead
            pm.tube("body", SLOT_BODY, (0.0, 0.0, 0.96), (0.0, 0.0, 1.02), 0.1, 0.09, seg=6, uv=P("slate_gloss"), drop_caps=("start", "end"), spin=30)
            pm.add("body", SLOT_BODY, "ell", center=(0, 0, 1.03), uv=P("pink_gloss"), seg=6, rings=3, radii=(0.085, 0.085, 0.075))
            # cargo basket hanging under the belly, two straps up to the body
            pm.add("body", SLOT_BODY, "box", center=(0.0, 0.0, 0.5), uv=P("slate"), size=(0.26, 0.22, 0.12))
            for sx in (-1, 1):
                pm.add("body", SLOT_BODY, "box", center=(0.1 * sx, 0.0, 0.6), uv=P("blade"), size=(0.03, 0.03, 0.12))
        return pm

    def build_rotors(self):
        pm = PartMesh(self.name + "_rotors", [self.mat])
        P = self.sheet.planar
        for sx, bone in ((1, "rotor_l"), (-1, "rotor_r")):
            c = (ROTOR_X * sx, 0.0, ROTOR_Z)
            pm.tube(bone, SLOT_BODY, (c[0], c[1], c[2] - 0.03), (c[0], c[1], c[2] + 0.03), 0.045, 0.045, seg=6, uv=P("slate_gloss"), drop_caps=("start", "end"), spin=30)
            pm.add(bone, SLOT_BODY, "box", center=(c[0], c[1], c[2] + 0.035), uv=P("blade_gloss"), size=(0.36, 0.1, 0.02))
        return pm

    def hover_idle(self, arm):
        def pose(rig, t, index):
            s = math.sin(2 * math.pi * t)
            c = math.cos(2 * math.pi * t)
            rig.move("body", z=0.035 * s)
            rig.rotate("body", x=2.5 * c, y=3.0 * s)
            rig.rotate("rotor_l", z=60.0 * index)
            rig.rotate("rotor_r", z=-60.0 * index)
        return build_clip(arm, "idle", 24, 2, pose)

    def run(self):
        os.makedirs(self.out, exist_ok=True)
        bpy.ops.wm.read_factory_settings(use_empty=True)
        self.paint()
        arm = build_small_rig(self.name, JOINTS, PARENTS)
        return finish_enemy(self.name, self.folder, [(self.build_body(), [0]), (self.build_rotors(), [0])],
                            [(self.mat, self.body_path)], arm, self.hover_idle)


def main():
    Drone("enm_signals_drone", "signals_drone", BASE_COLORS, variant=False).run()
    Drone("enm_drone_variant", "drone_variant", VARIANT_COLORS, variant=True).run()


main()
