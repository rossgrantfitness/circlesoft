"""Signals grunt and the grunt variant: placeholder blockouts in the Red house style (battle enemies).

Signals grunt (docs/art_requests.md row 21): a pressed blue-gray Signals Corps uniform, oversized headphones,
an antenna pin, a clipboard, and a white flag it can raise when it gives up. Humanoid, about 1.0 unit to the
top of the head (Red is the unit), 17 shared bones, one 128x128 body sheet plus a 128x64 face sheet (bored on
the left, "ouch" on the right: swap with uv_offset.x = 0.5, the battle stage does this on a hit).

SPECIES: no species is decided for the grunts. This placeholder is a plain round-snouted vole-ish critter
(small round nose, cream muzzle, ears hidden under the headphones), chosen to be neutral. Species is Ross's call.

Grunt variant (row 23): same rig, same species. Recolored (deep slate uniform with white stripes, lighter fur) and
two parts swapped: the clipboard becomes a megaphone and the single antenna pin becomes a pair of antennas.

The white flag is a separate mesh (name contains "_prop_flag") that hangs below the right hand, hidden by the
battle stage until the grunt surrenders; the stage raises that arm in code. Nothing else is authored: one `idle`
clip each (the contract; lunge, hit, fall over and so on are code tweens).

Outputs (placeholder art, same names the final art will have):
  game/art/placeholder/enemies/signals_grunt/enm_signals_grunt.glb  (+ .png body, _face.png)
  game/art/placeholder/enemies/grunt_variant/enm_grunt_variant.glb  (+ .png body, _face.png)
Run: /tmp/blockout_venv/bin/python game/scripts/tools/enemy_signals_grunt.py   (see enemy_kit.py)
"""

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from enemy_kit import *  # noqa: E402,F403

HEAD_C = Vector((0.0, 0.0, 0.80))
HEAD_R = (0.28, 0.24, 0.22)
FACE = FaceMap(HEAD_C.z, 0.30, 0.22)
MUZ_Y0, MUZ_Y1, MUZ_Z, MUZ_RX, MUZ_RZ = -0.17, -0.285, 0.74, 0.10, 0.075

SHOULDER_L, SHOULDER_R = Vector((0.24, 0.0, 0.60)), Vector((-0.24, 0.0, 0.60))
ELBOW_L, HAND_L = Vector((0.29, -0.06, 0.46)), Vector((0.19, -0.17, 0.50))     # left arm folded across the chest
ELBOW_R, HAND_R = Vector((-0.28, 0.0, 0.45)), Vector((-0.28, -0.03, 0.33))     # right arm hangs, flag below the fist

JOINTS = {
    "root": ((0, 0, 0), (0, 0, 0.05)),
    "hips": ((0, 0, 0.26), (0, 0, 0.34)),
    "spine": ((0, 0, 0.34), (0, 0, 0.66)),
    "head": ((0, 0, 0.66), (0, 0, 1.04)),
    "ear_l": ((0.30, 0, 0.94), (0.33, 0, 1.2)),
    "ear_r": ((-0.30, 0, 0.94), (-0.33, 0, 1.2)),
    "tail": ((0, 0.2, 0.28), (0, 0.3, 0.3)),
    "upper_arm_l": (tuple(SHOULDER_L), tuple(ELBOW_L)),
    "forearm_l": (tuple(ELBOW_L), tuple(HAND_L)),
    "upper_arm_r": (tuple(SHOULDER_R), tuple(ELBOW_R)),
    "forearm_r": (tuple(ELBOW_R), tuple(HAND_R)),
    "thigh_l": ((0.13, 0, 0.31), (0.13, 0, 0.2)),
    "shin_l": ((0.13, 0, 0.2), (0.13, -0.01, 0.12)),
    "thigh_r": ((-0.13, 0, 0.31), (-0.13, 0, 0.2)),
    "shin_r": ((-0.13, 0, 0.2), (-0.13, -0.01, 0.12)),
    "weapon_socket": (tuple(HAND_R), tuple(HAND_R + Vector((0, 0, 0.08)))),
    "prop_socket": (tuple(HAND_L), tuple(HAND_L + Vector((0, 0, 0.08)))),
}

# Warm shades, never grey (the room's blue ambient multiplies these). Pink-red status lights, no amber (Signals gear).
BASE_COLORS = {
    "fur": ("#BC9272", "#946E52"), "cream": ("#F3E2C2", "#DDBB8C"),
    "uni": ("#7894B2", "#546F8C"), "uni2": ("#97B0C9", "#7089A6"),
    "slate": ("#66707E", "#464F5C"), "boot": ("#4A5260", "#2F3542"),
    "hp": ("#9AA4B2", "#68727F"), "pad": ("#3A3F52", "#1F2236"),
    "pink": ("#EE4D72", "#B3304F"), "white": ("#F4F6F9", "#C9CFD9"), "chalk": ("#F5EFD8", "#DACFA8"),
    "wood": ("#CC9455", "#946236"), "paper": ("#EEEAD6", "#D0CAAE"), "ink": ("#14121F", "#14121F"),
}
VARIANT_COLORS = dict(BASE_COLORS)
VARIANT_COLORS.update({
    "fur": ("#CDA982", "#A5805D"), "uni": ("#566274", "#3A4456"), "uni2": ("#F4F6F9", "#C9CFD9"),
    "slate": ("#7C8694", "#58616F"), "boot": ("#2F3542", "#1C202B"),
})
GLOSS = ("fur", "boot", "hp", "pink", "slate", "wood")


class Grunt:
    def __init__(self, name, folder, colors, variant):
        self.name, self.folder, self.variant = name, folder, variant
        self.out = os.path.join(ENEMIES_DIR, folder)
        self.body_path = os.path.join(self.out, name + ".png")
        self.face_path = os.path.join(self.out, name + "_face.png")
        self.mat_body, self.mat_face = "mat_" + name, "mat_" + name + "_face"
        self.sheet = Sheet(colors, gloss=GLOSS)

    # ---- the face sheet: bored (left) and ouch (right)
    def paint_face(self):
        sheet = self.sheet
        img = Image.new("RGB", (FACE_W, FACE_H), sheet.rgb["fur"][0])
        d = ImageDraw.Draw(img)
        fur, fur_s = sheet.rgb["fur"]
        cream, cream_s = sheet.rgb["cream"]
        ink, chalk = sheet.rgb["ink"][0], CHALK
        nose = hex_rgb("#C46B5B")
        for cell, ouch in ((0, False), (1, True)):
            step = paint_face_background(img, FACE, cell, fur, fur_s)
            d.ellipse(FACE.box(cell, -0.17, 0.60, 0.17, 0.80), fill=cream)               # cream cheeks and chin
            shade_pass(img, cell, step, [(cream, cream_s)])
            d.rectangle(FACE.box(cell, -MUZ_RX * 1.05, MUZ_Z - MUZ_RZ * 1.1, MUZ_RX * 1.05, MUZ_Z + MUZ_RZ * 1.1), fill=cream)
            n = FACE.box(cell, -0.045, MUZ_Z + 0.005, 0.045, MUZ_Z + 0.06)
            d.ellipse(n, fill=nose)
            d.rectangle([n[0] + 2, n[1] + 1, n[0] + 3, n[1] + 1], fill=chalk)
            for sx in (-1, 1):
                ex, ez = 0.115 * sx, 0.855
                if not ouch:
                    e = FACE.box(cell, ex - 0.035, ez - 0.045, ex + 0.035, ez + 0.045)
                    d.ellipse(e, fill=ink)
                    d.rectangle([e[0] + 1, e[1] + 1, e[0] + 2, e[1] + 2], fill=chalk)
                    lid = FACE.box(cell, ex - 0.05, ez - 0.002, ex + 0.05, ez + 0.06)       # half-lidded: bored
                    d.rectangle([lid[0], lid[1] - 1, lid[2], lid[3]], fill=fur)
                    d.line([(lid[0], lid[3]), (lid[2], lid[3])], fill=ink, width=2)
                else:
                    a = FACE.pixel(cell, ex - 0.04 * sx, ez + 0.035)
                    b = FACE.pixel(cell, ex + 0.04 * sx, ez)
                    c = FACE.pixel(cell, ex - 0.04 * sx, ez - 0.035)
                    d.line([a, b, c], fill=ink, width=3)
            if not ouch:
                m = FACE.box(cell, -0.05, MUZ_Z - 0.06, 0.05, MUZ_Z - 0.065)
                d.line([(m[0], m[1]), (m[2], m[1])], fill=ink, width=2)                   # flat mouth
            else:
                m = FACE.box(cell, -0.045, MUZ_Z - 0.04, 0.045, MUZ_Z - 0.11)
                d.ellipse(m, fill=ink)
        img.save(self.face_path)

    # ---- the body
    def build_body(self):
        pm = PartMesh(self.name + "_body", [self.mat_body, self.mat_face])
        S = self.sheet
        P = S.planar
        for sx, side in ((-1, "r"), (1, "l")):                                            # legs and boots
            pm.tube("thigh_" + side, SLOT_BODY, (0.13 * sx, 0, 0.31), (0.13 * sx, 0, 0.20), 0.09, 0.085, seg=6, uv=P("slate"), drop_caps=("start", "end"))
            pm.tube("shin_" + side, SLOT_BODY, (0.13 * sx, 0, 0.20), (0.13 * sx, -0.01, 0.12), 0.085, 0.085, seg=6, uv=P("slate"), drop_caps=("start", "end"))
            pm.add("shin_" + side, SLOT_BODY, "ell", center=(0.135 * sx, -0.05, 0.095), uv=P("boot_gloss"), seg=6, rings=3, radii=(0.125, 0.17, 0.10))
        # pressed uniform: jacket skirt, chest, belt, rolled collar
        pm.tube("hips", SLOT_BODY, (0, 0, 0.22), (0, 0, 0.44), 0.235, 0.215, seg=8, sxy=(1.0, 0.85), uv=S.planar_z("uni", 0.22, 0.44), drop_caps=("start", "end"), spin=22.5)
        pm.tube("spine", SLOT_BODY, (0, 0, 0.44), (0, 0, 0.66), 0.215, 0.15, seg=8, sxy=(1.0, 0.85), uv=S.planar_z("uni", 0.44, 0.66), drop_caps=("start", "end"), spin=22.5)
        pm.tube("spine", SLOT_BODY, (0, 0, 0.64), (0, 0, 0.70), 0.15, 0.135, seg=8, sxy=(1.0, 0.9), uv=P("uni2"), drop_caps=("start", "end"), spin=22.5)
        pm.add("spine", SLOT_BODY, "box", center=(0.095, -0.19, 0.55), uv=P("uni2"), size=(0.10, 0.025, 0.07))    # pocket flap
        for sx, side in ((-1, "r"), (1, "l")):                                            # shoulder tabs
            pm.add("spine", SLOT_BODY, "box", center=(0.225 * sx, 0.0, 0.665), uv=P("white" if not self.variant else "white"), size=(0.12, 0.10, 0.035))
        # head, snout, oversized headphones
        pm.add("head", head_slot, "ell", center=tuple(HEAD_C), uv=head_uv_factory(S, FACE, "fur", "cream"), seg=8, rings=5, radii=HEAD_R, deform=bean(HEAD_R))
        pm.tube("head", muzzle_slot, (0, MUZ_Y0, MUZ_Z), (0, MUZ_Y1, MUZ_Z), MUZ_RX, MUZ_RX * 0.9, seg=6, sxy=(1.0, MUZ_RZ / MUZ_RX),
                uv=muzzle_uv_factory(S, FACE, "cream"), drop_caps=("start",), spin=30)
        for sx in (-1, 1):
            pm.add("head", SLOT_BODY, "ell", center=(0.31 * sx, 0.0, 0.80), uv=P("hp_gloss"), seg=6, rings=4, radii=(0.085, 0.15, 0.15))
        band = [(0.315 * math.sin(math.radians(a)), 0.0, 0.80 + 0.285 * math.cos(math.radians(a))) for a in (-90, -45, 0, 45, 90)]
        for a, b in zip(band, band[1:]):
            pm.tube("head", SLOT_BODY, a, b, 0.03, 0.03, seg=4, uv=P("hp"), drop_caps=("start", "end"), spin=45)
        # antenna pin(s) on the headphone cups, with a pink-red status light on the tip (they ride the ear bones: they wobble)
        pins = ((-1, "ear_r", 0.26),) if not self.variant else ((-1, "ear_r", 0.30), (1, "ear_l", 0.20))
        for sx, bone, length in pins:
            base = (0.31 * sx, 0.0, 0.94)
            tip = (0.335 * sx, 0.0, 0.94 + length)
            pm.tube(bone, SLOT_BODY, base, tip, 0.024, 0.02, seg=4, uv=P("slate"), drop_caps=("start", "end"), spin=45)
            pm.add(bone, SLOT_BODY, "ell", center=(tip[0], tip[1], tip[2] + 0.02), uv=P("pink_gloss"), seg=5, rings=3, radii=(0.05, 0.05, 0.05))
        # arms: sleeves and round mitts (the left hand holds the clipboard or megaphone)
        for sx, side, Sh, E, H in ((-1, "r", SHOULDER_R, ELBOW_R, HAND_R), (1, "l", SHOULDER_L, ELBOW_L, HAND_L)):
            pm.tube("upper_arm_" + side, SLOT_BODY, tuple(Sh), tuple(E), 0.07, 0.065, seg=6, uv=P("uni"), drop_caps=("start", "end"))
            pm.tube("forearm_" + side, SLOT_BODY, tuple(E), tuple(H), 0.065, 0.065, seg=6, uv=P("uni"), drop_caps=("start", "end"))
            pm.add("forearm_" + side, SLOT_BODY, "ell", center=tuple(H), uv=P("fur_gloss"), seg=5, rings=3, radii=(0.085, 0.08, 0.08))
        pm.add("tail", SLOT_BODY, "ell", center=(0, 0.25, 0.28), uv=P("fur"), seg=5, rings=3, radii=(0.045, 0.1, 0.045))   # little thin tail
        return pm

    def build_clipboard(self):
        pm = PartMesh(self.name + "_prop_clipboard", [self.mat_body])
        P = self.sheet.planar
        c = HAND_L + Vector((0.01, -0.035, 0.07))
        pm.add("prop_socket", SLOT_BODY, "box", center=tuple(c), uv=P("wood_gloss"), size=(0.25, 0.03, 0.33), rot=(0, 0, -12))
        pm.add("prop_socket", SLOT_BODY, "box", center=(c.x, c.y - 0.022, c.z - 0.005), uv=P("paper"), size=(0.2, 0.012, 0.27), rot=(0, 0, -12))
        pm.add("prop_socket", SLOT_BODY, "box", center=(c.x + 0.015, c.y - 0.03, c.z + 0.155), uv=P("slate_gloss"), size=(0.1, 0.03, 0.045), rot=(0, 0, -12))
        return pm

    def build_megaphone(self):
        """Variant swap: a squat megaphone held up at the chin instead of the clipboard."""
        pm = PartMesh(self.name + "_prop_megaphone", [self.mat_body])
        P = self.sheet.planar
        a = tuple(HAND_L + Vector((0.0, -0.02, 0.04)))
        b = tuple(HAND_L + Vector((-0.02, -0.26, 0.10)))
        pm.tube("prop_socket", SLOT_BODY, a, b, 0.05, 0.14, seg=6, uv=P("white"), drop_caps=("start",), spin=30)
        pm.tube("prop_socket", SLOT_BODY, a, tuple(HAND_L + Vector((0.0, -0.1, 0.045))), 0.052, 0.07, seg=6, uv=P("pink_gloss"), drop_caps=("start", "end"), spin=30)
        pm.add("prop_socket", SLOT_BODY, "box", center=tuple(HAND_L + Vector((0.0, -0.03, -0.04))), uv=P("slate_gloss"), size=(0.05, 0.05, 0.1))
        return pm

    def build_flag(self):
        """The white flag: a pole hanging down from the right fist (so raising the arm turns it upright) and a
        white cloth at the far end. Hidden until the grunt gives up."""
        pm = PartMesh(self.name + "_prop_flag", [self.mat_body])
        P = self.sheet.planar
        top = HAND_R + Vector((0.0, 0.0, 0.06))
        end = HAND_R + Vector((0.0, 0.0, -0.62))
        pm.tube("weapon_socket", SLOT_BODY, tuple(top), tuple(end), 0.025, 0.025, seg=4, uv=P("wood"), drop_caps=("start", "end"), spin=45)
        pm.add("weapon_socket", SLOT_BODY, "box", center=(end.x, end.y - 0.17, end.z + 0.12), uv=SHEET_FLAT(self.sheet, "chalk"), size=(0.02, 0.34, 0.22))
        return pm

    def run(self):
        os.makedirs(self.out, exist_ok=True)
        bpy.ops.wm.read_factory_settings(use_empty=True)
        self.sheet.paint(self.body_path)
        self.paint_face()
        parts = [(self.build_body(), [0, 1]),
                 (self.build_megaphone() if self.variant else self.build_clipboard(), [0]),
                 (self.build_flag(), [0])]
        arm = build_armature(self.name, JOINTS)
        # a bored slouch: small bounce, a lazy nod, antenna wobbling on the ear bones
        return finish_enemy(self.name, self.folder, parts,
                            [(self.mat_body, self.body_path), (self.mat_face, self.face_path)], arm,
                            lambda a: build_idle(a, bounce=0.012, nod=3.2, sway=4.0, arm=1.5, ear=16.0))


def SHEET_FLAT(sheet, cell):
    return sheet.flat(cell)


def main():
    Grunt("enm_signals_grunt", "signals_grunt", BASE_COLORS, variant=False).run()
    Grunt("enm_grunt_variant", "grunt_variant", VARIANT_COLORS, variant=True).run()


main()
