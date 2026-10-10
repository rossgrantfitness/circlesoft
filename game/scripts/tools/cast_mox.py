"""Mox, ferret kid gadgeteer: placeholder blockout in the Red house style.

Silhouette: welding mask, big wrench, drone. Longer and wiry (about 3 heads tall, 1.15x Red): a bean head
with a dark mask band across the eyes and a pointed cream snout, small round ears set at the sides, a
silver welding mask flipped up on his head like a crown, an oversized mustard vest with far too many
pockets (items poking out of two), a long thin tail and big round glossy boots. The big wrench (wrench-mace,
a separate mesh on weapon_socket, nearly as tall as he is) stands beside him; Tuesday the drone (a separate
mesh on the spine bone, so it floats over his shoulder) is teal. docs/story_bible.md, Mox; docs/style_guide.md.

Output: game/art/placeholder/characters/mox/chr_mox.glb (+ chr_mox.png, chr_mox_face.png: boasting on the
left, panicking on the right, swap with uv_offset.x = 0.5).
Run: /tmp/blockout_venv/bin/python game/scripts/tools/cast_mox.py   (see cast_kit.py)
"""

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from cast_kit import *  # noqa: E402,F403

NAME = "chr_mox"
FOLDER = "mox"
OUT = os.path.join(CHARACTERS_DIR, FOLDER)
BODY_PATH = os.path.join(OUT, NAME + ".png")
FACE_PATH = os.path.join(OUT, NAME + "_face.png")
MAT_BODY, MAT_FACE = "mat_" + NAME, "mat_" + NAME + "_face"

COLORS = {
    "fur": ("#BE8E5A", "#93683F"), "mask": ("#6A4A36", "#47301F"), "cream": ("#FBE8C4", "#E8C08C"),
    "vest": ("#EDB43A", "#B3822A"), "pocket": ("#D0932A", "#96641F"), "shirt": ("#E0B684", "#AD8760"),
    "pants": ("#C46E4A", "#8F4A2F"), "boot": ("#6F4833", "#4A2C20"), "silver": ("#DADBD4", "#A9A6A0"),
    "teal": ("#4CC4B9", "#2F8580"), "rust": ("#B95832", "#7C3A2D"), "brass": ("#E3AC45", "#A9742E"),
    "glow": ("#FFE08A", "#FFB347"), "dusk": ("#5A5492", "#3A3566"), "ink": ("#14121F", "#14121F"),
    "chalk": ("#F5EFD8", "#DACFA8"),
}
SHEET = Sheet(COLORS, gloss=("fur", "boot", "silver", "teal", "brass"))

HEAD_C = Vector((0.0, 0.0, 0.95))
HEAD_R = (0.215, 0.19, 0.17)
FACE = FaceMap(HEAD_C.z, 0.245, 0.2)
MUZ_Y0, MUZ_Y1, MUZ_Z, MUZ_R0, MUZ_R1, MUZ_RZ = -0.12, -0.27, 0.905, 0.095, 0.055, 0.07
SHOULDER_L, SHOULDER_R = Vector((0.15, 0.0, 0.68)), Vector((-0.15, 0.0, 0.68))
ELBOW_L, HAND_L = Vector((0.26, -0.02, 0.56)), Vector((0.29, -0.09, 0.68))      # left fist up: boasting
ELBOW_R, HAND_R = Vector((-0.27, -0.04, 0.54)), Vector((-0.40, -0.10, 0.40))
WRENCH_BASE, WRENCH_TOP = Vector((-0.42, -0.10, 0.02)), Vector((-0.36, -0.10, 1.0))
DRONE_C = Vector((0.37, 0.12, 0.99))

JOINTS = {
    "root": ((0, 0, 0), (0, 0, 0.05)),
    "hips": ((0, 0, 0.28), (0, 0, 0.34)),
    "spine": ((0, 0, 0.34), (0, 0, 0.74)),
    "head": ((0, 0, 0.74), (0, 0, 1.2)),
    "ear_l": ((0.16, 0, 1.07), (0.17, 0, 1.15)),
    "ear_r": ((-0.16, 0, 1.07), (-0.17, 0, 1.15)),
    "tail": ((0, 0.12, 0.30), (0, 0.3, 0.3)),
    "upper_arm_l": (tuple(SHOULDER_L), tuple(ELBOW_L)),
    "forearm_l": (tuple(ELBOW_L), tuple(HAND_L)),
    "upper_arm_r": (tuple(SHOULDER_R), tuple(ELBOW_R)),
    "forearm_r": (tuple(ELBOW_R), tuple(HAND_R)),
    "thigh_l": ((0.06, 0, 0.33), (0.06, 0, 0.21)),
    "shin_l": ((0.06, 0, 0.21), (0.06, -0.01, 0.12)),
    "thigh_r": ((-0.06, 0, 0.33), (-0.06, 0, 0.21)),
    "shin_r": ((-0.06, 0, 0.21), (-0.06, -0.01, 0.12)),
    "weapon_socket": (tuple(HAND_R), tuple(HAND_R + Vector((0, 0, 0.08)))),
    "prop_socket": (tuple(HAND_L), tuple(HAND_L + Vector((0, 0, 0.08)))),
}


def paint_face():
    img = Image.new("RGB", (FACE_W, FACE_H), SHEET.rgb["fur"][0])
    d = ImageDraw.Draw(img)
    fur, fur_s = SHEET.rgb["fur"]
    mask, mask_s = SHEET.rgb["mask"]
    cream, cream_s = SHEET.rgb["cream"]
    ink, chalk, red = SHEET.rgb["ink"][0], CHALK, hex_rgb("#D6382E")
    nose = hex_rgb("#C26B5A")
    for cell, panic in ((0, False), (1, True)):
        step = paint_face_background(img, FACE, cell, fur, fur_s)
        d.ellipse(FACE.box(cell, -0.15, 0.78, 0.15, 0.93), fill=cream)                 # cream lower face
        d.ellipse(FACE.box(cell, -0.235, 0.88, 0.235, 1.02), fill=mask)                # dark bandit mask
        d.rectangle(FACE.box(cell, -0.235, 0.92, 0.235, 0.98), fill=mask)
        shade_pass(img, cell, step, [(cream, cream_s), (mask, mask_s)])
        d.rectangle(FACE.box(cell, -MUZ_R0 * 1.05, MUZ_Z - MUZ_RZ * 1.1, MUZ_R0 * 1.05, MUZ_Z + MUZ_RZ * 1.1), fill=cream)
        n = FACE.box(cell, -0.034, MUZ_Z + 0.012, 0.034, MUZ_Z + 0.058)
        d.ellipse(n, fill=nose)
        d.point([(n[0] + 2, n[1] + 1)], fill=chalk)
        if not panic:
            for k in (-1, 1):                                        # cocky little smirk
                a = FACE.box(cell, min(0.0, 0.045 * k), MUZ_Z - 0.0, max(0.0, 0.045 * k), MUZ_Z - 0.045)
                d.arc(a, 15, 165, fill=ink, width=2)
        else:
            m = FACE.box(cell, -0.04, MUZ_Z - 0.005, 0.04, MUZ_Z - 0.065)
            d.pieslice([m[0], m[1] - (m[3] - m[1]) * 0.3, m[2], m[3]], 0, 180, fill=ink)
            d.ellipse(FACE.box(cell, -0.018, MUZ_Z - 0.035, 0.018, MUZ_Z - 0.06), fill=red)
        # big white eyes on the dark mask: pupils up and to the side when he boasts, tiny and wide when he panics
        for sx in (-1, 1):
            ex, ez = 0.095 * sx, 0.955
            rx, rz = (0.05, 0.062) if not panic else (0.058, 0.074)
            d.ellipse(FACE.box(cell, ex - rx, ez - rz, ex + rx, ez + rz), fill=chalk)
            pr = 0.026 if not panic else 0.014
            px, pz = ex + (0.012 * sx if not panic else 0.0), ez + (0.012 if not panic else 0.0)
            d.ellipse(FACE.box(cell, px - pr, pz - pr * 1.2, px + pr, pz + pr * 1.2), fill=ink)
    img.save(FACE_PATH)


def build_body():
    pm = PartMesh(NAME + "_body", [MAT_BODY, MAT_FACE])
    P = SHEET.planar
    for sx, side in ((-1, "r"), (1, "l")):
        pm.tube("thigh_" + side, SLOT_BODY, (0.06 * sx, 0, 0.33), (0.06 * sx, 0, 0.21), 0.065, 0.06, seg=6, uv=P("pants"), drop_caps=("start", "end"))
        pm.tube("shin_" + side, SLOT_BODY, (0.06 * sx, 0, 0.21), (0.06 * sx, -0.01, 0.12), 0.06, 0.06, seg=6, uv=P("pants"), drop_caps=("start", "end"))
        pm.add("shin_" + side, SLOT_BODY, "ell", center=(0.07 * sx, -0.05, 0.085), uv=P("boot_gloss"), seg=8, rings=3, radii=(0.105, 0.15, 0.09))
    # the vest: hem band wider, shoulders narrow; shirt collar
    pm.tube("hips", SLOT_BODY, (0, 0, 0.30), (0, 0, 0.52), 0.185, 0.19, seg=8, sxy=(1.0, 0.82), uv=SHEET.planar_z("vest", 0.3, 0.74), drop_caps=("start", "end"), spin=22.5)
    pm.tube("spine", SLOT_BODY, (0, 0, 0.52), (0, 0, 0.74), 0.19, 0.13, seg=8, sxy=(1.0, 0.82), uv=SHEET.planar_z("vest", 0.3, 0.74), drop_caps=("start", "end"), spin=22.5)
    pm.tube("spine", SLOT_BODY, (0, 0, 0.72), (0, 0, 0.79), 0.13, 0.11, seg=8, sxy=(1.0, 0.85), uv=P("shirt"), drop_caps=("start", "end"), spin=22.5)
    # far too many pockets, two with something poking out
    for x, z in ((-0.075, 0.40), (0.075, 0.40), (-0.07, 0.56), (0.07, 0.56)):
        pm.add("spine", SLOT_BODY, "box", center=(x, -0.168 if z < 0.5 else -0.150, z), uv=P("pocket"), size=(0.085, 0.05, 0.08))
    pm.add("spine", SLOT_BODY, "box", center=(-0.075, -0.17, 0.455), uv=P("teal_gloss"), size=(0.03, 0.03, 0.05))
    pm.add("spine", SLOT_BODY, "box", center=(0.075, -0.17, 0.455), uv=P("silver_gloss"), size=(0.03, 0.03, 0.06))
    # head, pointed snout, round ears
    pm.add("head", head_slot, "ell", center=tuple(HEAD_C), uv=head_uv_factory(SHEET, FACE, "fur", "cream"), seg=10, rings=5, radii=HEAD_R, deform=bean(HEAD_R))
    pm.tube("head", muzzle_slot, (0, MUZ_Y0, MUZ_Z), (0, MUZ_Y1, MUZ_Z), MUZ_R0, MUZ_R1, seg=6, sxy=(1.0, MUZ_RZ / MUZ_R0),
            uv=muzzle_uv_factory(SHEET, FACE, "cream"), drop_caps=("start",), spin=30)
    for sx, bone in ((-1, "ear_r"), (1, "ear_l")):
        pm.add(bone, SLOT_BODY, "ell", center=(0.165 * sx, 0.01, 1.085), uv=P("fur"), seg=6, rings=4, radii=(0.06, 0.04, 0.065))
    # welding mask flipped up on his head like a crown: silver shell, dark visor slot, two brass rivets
    pm.add("head", SLOT_BODY, "ell", center=(0, 0.0, 1.14), uv=P("silver_gloss"), seg=8, rings=4, radii=(0.2, 0.11, 0.14), rot=(-25, 0, 0))
    pm.add("head", SLOT_BODY, "box", center=(0, -0.095, 1.185), uv=P("dusk"), size=(0.2, 0.03, 0.06), rot=(-35, 0, 0))
    for sx in (-1, 1):
        pm.add("head", SLOT_BODY, "ell", center=(0.14 * sx, -0.07, 1.15), uv=P("brass_gloss"), seg=4, rings=3, radii=(0.025, 0.02, 0.025))
    # arms: tan sleeves, round fur mitts (left fist up)
    for sx, side, S, E, H in ((-1, "r", SHOULDER_R, ELBOW_R, HAND_R), (1, "l", SHOULDER_L, ELBOW_L, HAND_L)):
        pm.tube("upper_arm_" + side, SLOT_BODY, tuple(S), tuple(E), 0.058, 0.052, seg=6, uv=P("shirt"), drop_caps=("start", "end"))
        pm.tube("forearm_" + side, SLOT_BODY, tuple(E), tuple(H), 0.052, 0.052, seg=6, uv=P("shirt"), drop_caps=("start", "end"))
        pm.add("forearm_" + side, SLOT_BODY, "ell", center=tuple(H), uv=P("fur_gloss"), seg=6, rings=3, radii=(0.082, 0.078, 0.078))
    # long thin ferret tail, dark tip
    ball_chain(pm, "tail", P("fur"), [(0, 0.15, 0.31), (0, 0.27, 0.26), (0.05, 0.39, 0.29), (0.10, 0.47, 0.40)], (0.065, 0.058, 0.05), seg=5, rings=3)
    return pm


def build_wrench():
    """Big wrench-mace: silver shaft, open jaws, a rusty weight welded on under the head, MOX WUZ HERE bead."""
    pm = PartMesh(NAME + "_prop_wrench", [MAT_BODY])
    P = SHEET.planar
    pm.tube("weapon_socket", SLOT_BODY, tuple(WRENCH_BASE), tuple(WRENCH_TOP), 0.035, 0.04, seg=6, uv=P("silver_gloss"), drop_caps=("start", "end"))
    x, y = WRENCH_TOP.x, WRENCH_TOP.y
    pm.add("weapon_socket", SLOT_BODY, "box", center=(x, y, 0.98), uv=P("silver_gloss"), size=(0.19, 0.055, 0.07))
    for dx in (-0.07, 0.07):
        pm.add("weapon_socket", SLOT_BODY, "box", center=(x + dx, y, 1.05), uv=P("silver_gloss"), size=(0.05, 0.055, 0.1))
    pm.add("weapon_socket", SLOT_BODY, "ell", center=(x + 0.01, y, 0.86), uv=P("rust"), seg=6, rings=4, radii=(0.1, 0.085, 0.1))
    pm.add("weapon_socket", SLOT_BODY, "box", center=(x + 0.04, y - 0.09, 0.86), uv=P("brass_gloss"), size=(0.07, 0.02, 0.03))
    return pm


def build_drone():
    """Tuesday: small, wobbly, homemade. Teal body, two rotors, one lens. Floats over his shoulder."""
    pm = PartMesh(NAME + "_prop_drone", [MAT_BODY])
    P = SHEET.planar
    c = DRONE_C
    pm.add("spine", SLOT_BODY, "ell", center=tuple(c), uv=P("teal_gloss"), seg=8, rings=4, radii=(0.085, 0.085, 0.07))
    for dx in (-0.1, 0.1):
        pm.add("spine", SLOT_BODY, "ell", center=(c.x + dx, c.y, c.z + 0.085), uv=P("silver"), seg=8, rings=2, radii=(0.1, 0.1, 0.014))
    pm.add("spine", SLOT_BODY, "box", center=(c.x, c.y - 0.07, c.z + 0.005), uv=SHEET.flat("ink"), size=(0.07, 0.03, 0.05))
    pm.add("spine", SLOT_BODY, "ell", center=(c.x, c.y - 0.092, c.z + 0.005), uv=SHEET.flat("glow"), seg=4, rings=3, radii=(0.018, 0.012, 0.018))
    return pm


def main():
    os.makedirs(OUT, exist_ok=True)
    bpy.ops.wm.read_factory_settings(use_empty=True)
    SHEET.paint(BODY_PATH)
    paint_face()
    finish(NAME, FOLDER, [(build_body(), [0, 1]), (build_wrench(), [0]), (build_drone(), [0])],
           [(MAT_BODY, BODY_PATH), (MAT_FACE, FACE_PATH)], JOINTS,
           idle_args=dict(bounce=0.018, nod=2.4, sway=9.0, arm=3.0, ear=10.0))


main()
