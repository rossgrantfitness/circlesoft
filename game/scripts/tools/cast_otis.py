"""Otis Kettle, brown bear, dock boss: placeholder blockout in the Red house style.

Silhouette: "boulder with a door". Big, round, short (about 2 heads tall), 1.25x Red: a barrel body wider
than his head, stubby legs, big glossy boots, small round bear ears poking through two holes in a
dirty-ivory hard hat with a little headlamp, a grizzled warm-gray muzzle, faded orange coveralls under a
padded rust vest with a tin of cough drops in the chest pocket, thick gloves. The dented cargo-container
door (his shield) is a separate mesh on prop_socket and the dockworker's hammer a separate mesh on
weapon_socket (docs/story_bible.md, Otis Kettle; docs/style_guide.md palette).

Output: game/art/placeholder/characters/otis/chr_otis.glb (+ chr_otis.png body sheet, chr_otis_face.png
face sheet with calm smile on the left and laughing on the right, swap with uv_offset.x = 0.5).
Run: /tmp/blockout_venv/bin/python game/scripts/tools/cast_otis.py   (see cast_kit.py)
"""

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from cast_kit import *  # noqa: E402,F403

NAME = "chr_otis"
FOLDER = "otis"
OUT = os.path.join(CHARACTERS_DIR, FOLDER)
BODY_PATH = os.path.join(OUT, NAME + ".png")
FACE_PATH = os.path.join(OUT, NAME + "_face.png")
MAT_BODY, MAT_FACE = "mat_" + NAME, "mat_" + NAME + "_face"

# Warm and bright on purpose: the test room's blue ambient multiplies these, so grey-ish shades would go grey.
COLORS = {
    "fur": ("#94643A", "#6F462A"), "gray": ("#C9B79F", "#A38F76"), "cov": ("#F08A32", "#B85C24"),
    "vest": ("#C45A2C", "#86402A"), "hat": ("#F3EACB", "#D2C39A"), "glove": ("#C2905A", "#94693C"),
    "boot": ("#6A4430", "#46291F"), "brass": ("#E3AC45", "#A9742E"), "glow": ("#FFE08A", "#FFB347"),
    "door": ("#7FB06A", "#4F8052"), "chalk": ("#F5EFD8", "#DACFA8"), "wood": ("#C98F52", "#8F5E34"),
    "iron": ("#8479A0", "#564E78"), "ink": ("#14121F", "#14121F"),
}
SHEET = Sheet(COLORS, gloss=("hat", "glove", "boot", "brass", "iron"))

HEAD_C = Vector((0.0, 0.0, 0.97))
HEAD_R = (0.32, 0.27, 0.25)
FACE = FaceMap(HEAD_C.z, 0.36, 0.27)
MUZ_Y0, MUZ_Y1, MUZ_Z, MUZ_RX, MUZ_RZ = -0.18, -0.33, 0.90, 0.14, 0.10
HAND_L, HAND_R = Vector((0.50, -0.08, 0.34)), Vector((-0.50, -0.12, 0.34))
ELBOW_L, ELBOW_R = Vector((0.46, -0.03, 0.46)), Vector((-0.46, -0.03, 0.46))
SHOULDER_L, SHOULDER_R = Vector((0.34, 0.0, 0.62)), Vector((-0.34, 0.0, 0.62))

JOINTS = {
    "root": ((0, 0, 0), (0, 0, 0.05)),
    "hips": ((0, 0, 0.26), (0, 0, 0.36)),
    "spine": ((0, 0, 0.36), (0, 0, 0.76)),
    "head": ((0, 0, 0.76), (0, 0, 1.22)),
    "ear_l": ((0.24, 0, 1.2), (0.26, 0, 1.3)),
    "ear_r": ((-0.24, 0, 1.2), (-0.26, 0, 1.3)),
    "tail": ((0, 0.3, 0.34), (0, 0.42, 0.4)),
    "upper_arm_l": (tuple(SHOULDER_L), tuple(ELBOW_L)),
    "forearm_l": (tuple(ELBOW_L), tuple(HAND_L)),
    "upper_arm_r": (tuple(SHOULDER_R), tuple(ELBOW_R)),
    "forearm_r": (tuple(ELBOW_R), tuple(HAND_R)),
    "thigh_l": ((0.15, 0, 0.30), (0.15, 0, 0.2)),
    "shin_l": ((0.15, 0, 0.2), (0.15, -0.01, 0.12)),
    "thigh_r": ((-0.15, 0, 0.30), (-0.15, 0, 0.2)),
    "shin_r": ((-0.15, 0, 0.2), (-0.15, -0.01, 0.12)),
    "weapon_socket": (tuple(HAND_R), tuple(HAND_R + Vector((0, 0, 0.08)))),
    "prop_socket": (tuple(HAND_L), tuple(HAND_L + Vector((0, 0, 0.08)))),
}


def paint_face():
    img = Image.new("RGB", (FACE_W, FACE_H), SHEET.rgb["fur"][0])
    d = ImageDraw.Draw(img)
    fur, fur_s = SHEET.rgb["fur"]
    gray, gray_s = SHEET.rgb["gray"]
    ink, chalk = SHEET.rgb["ink"][0], CHALK
    red = hex_rgb("#D6382E")
    for cell, laugh in ((0, False), (1, True)):
        step = paint_face_background(img, FACE, cell, fur, fur_s)
        # grizzled gray lower face and cheek patches (warm gray), dithered into the fur
        for box in ((-0.20, 0.72, 0.20, 0.90), (-0.30, 0.82, -0.14, 0.95), (0.14, 0.82, 0.30, 0.95)):
            d.ellipse(FACE.box(cell, *box), fill=gray)
        for x in range(FACE_CELL):
            for y in range(FACE_CELL):
                if (x + y) % 2 == 0:
                    here = img.getpixel((cell * FACE_CELL + x, y))
                    near = [img.getpixel((cell * FACE_CELL + min(max(x + dx, 0), 63), min(max(y + dy, 0), 63)))
                            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))]
                    if here == gray and any(c in (fur, fur_s) for c in near):
                        img.putpixel((cell * FACE_CELL + x, y), fur_s if y > step else fur)
        shade_pass(img, cell, step, [(gray, gray_s)])
        # muzzle cap, nose, mouth
        d.rectangle(FACE.box(cell, -MUZ_RX * 1.05, MUZ_Z - MUZ_RZ * 1.1, MUZ_RX * 1.05, MUZ_Z + MUZ_RZ * 1.1), fill=gray)
        n = FACE.box(cell, -0.05, MUZ_Z + 0.02, 0.05, MUZ_Z + 0.075)
        d.ellipse(n, fill=ink)
        d.rectangle([n[0] + 2, n[1] + 1, n[0] + 4, n[1] + 1], fill=chalk)
        if not laugh:
            for k in (-1, 1):                                  # calm little smile
                a = FACE.box(cell, min(0.0, 0.07 * k), MUZ_Z - 0.01, max(0.0, 0.07 * k), MUZ_Z - 0.06)
                d.arc(a, 15, 165, fill=ink, width=2)
        else:
            m = FACE.box(cell, -0.07, MUZ_Z - 0.01, 0.07, MUZ_Z - 0.09)
            d.pieslice([m[0], m[1] - (m[3] - m[1]) * 0.35, m[2], m[3]], 0, 180, fill=ink)
            t = FACE.box(cell, -0.035, MUZ_Z - 0.055, 0.035, MUZ_Z - 0.085)
            d.ellipse(t, fill=red)
        # eyes (small, friendly) and gray brow tufts
        for sx in (-1, 1):
            ex, ez = 0.125 * sx, 1.0
            if not laugh:
                e = FACE.box(cell, ex - 0.032, ez - 0.045, ex + 0.032, ez + 0.045)
                d.ellipse(e, fill=ink)
                d.rectangle([e[0] + 2, e[1] + 2, e[0] + 4, e[1] + 4], fill=chalk)
            else:
                pts = [FACE.pixel(cell, ex + dx, ez + dz) for dx, dz in ((-0.035, -0.02), (-0.015, 0.02), (0, 0.03), (0.015, 0.02), (0.035, -0.02))]
                d.line(pts, fill=ink, width=3)
            d.ellipse(FACE.box(cell, ex - 0.04, ez + 0.07, ex + 0.04, ez + 0.1), fill=gray)
    img.save(FACE_PATH)


def build_body():
    pm = PartMesh(NAME + "_body", [MAT_BODY, MAT_FACE])
    P = SHEET.planar
    # legs and big glossy boots
    for sx, side in ((-1, "r"), (1, "l")):
        pm.tube("thigh_" + side, SLOT_BODY, (0.15 * sx, 0, 0.30), (0.15 * sx, 0, 0.20), 0.115, 0.11, seg=6, uv=P("cov"), drop_caps=("start", "end"))
        pm.tube("shin_" + side, SLOT_BODY, (0.15 * sx, 0, 0.20), (0.15 * sx, -0.01, 0.12), 0.11, 0.11, seg=6, uv=P("cov"), drop_caps=("start", "end"))
        pm.add("shin_" + side, SLOT_BODY, "ell", center=(0.155 * sx, -0.06, 0.105), uv=P("boot_gloss"), seg=8, rings=3, radii=(0.17, 0.22, 0.12))
    # the boulder: coverall skirt, then the padded vest, then a collar
    pm.tube("hips", SLOT_BODY, (0, 0, 0.20), (0, 0, 0.50), 0.40, 0.385, seg=10, sxy=(1.0, 0.88), uv=SHEET.planar_z("cov", 0.2, 0.5), drop_caps=("start", "end"), spin=18)
    pm.tube("spine", SLOT_BODY, (0, 0, 0.50), (0, 0, 0.80), 0.385, 0.23, seg=10, sxy=(1.0, 0.88), uv=SHEET.planar_z("vest", 0.5, 0.8), drop_caps=("start", "end"), spin=18)
    pm.tube("spine", SLOT_BODY, (0, 0, 0.78), (0, 0, 0.86), 0.23, 0.2, seg=10, sxy=(1.0, 0.88), uv=P("cov"), drop_caps=("start", "end"), spin=18)
    # chest pocket with the cough-drop tin
    pm.add("spine", SLOT_BODY, "box", center=(0.15, -0.28, 0.62), uv=P("cov"), size=(0.13, 0.05, 0.11))
    pm.add("spine", SLOT_BODY, "box", center=(0.15, -0.30, 0.70), uv=P("brass_gloss"), size=(0.08, 0.035, 0.05))
    # head, muzzle, hard hat, headlamp, round ears through the hat
    pm.add("head", head_slot, "ell", center=tuple(HEAD_C), uv=head_uv_factory(SHEET, FACE, "fur", "gray"), seg=10, rings=6, radii=HEAD_R, deform=bean(HEAD_R))
    pm.tube("head", muzzle_slot, (0, MUZ_Y0, MUZ_Z), (0, MUZ_Y1, MUZ_Z), MUZ_RX, MUZ_RX * 0.9, seg=8, sxy=(1.0, MUZ_RZ / MUZ_RX),
            uv=muzzle_uv_factory(SHEET, FACE, "gray"), drop_caps=("start",), spin=22.5)
    pm.add("head", SLOT_BODY, "ell", center=(0, 0.01, 1.14), uv=P("hat_gloss"), seg=10, rings=5, radii=(0.30, 0.27, 0.23))
    pm.add("head", SLOT_BODY, "ell", center=(0, -0.02, 1.12), uv=P("hat"), seg=10, rings=3, radii=(0.37, 0.35, 0.035))
    pm.add("head", SLOT_BODY, "box", center=(0, -0.25, 1.24), uv=P("brass_gloss"), size=(0.13, 0.07, 0.08))
    pm.add("head", SLOT_BODY, "ell", center=(0, -0.29, 1.24), uv=SHEET.flat("glow"), seg=6, rings=3, radii=(0.04, 0.03, 0.04))
    for sx, bone in ((-1, "ear_r"), (1, "ear_l")):
        pm.add(bone, SLOT_BODY, "ell", center=(0.255 * sx, -0.01, 1.235), uv=P("fur"), seg=6, rings=4, radii=(0.075, 0.055, 0.075))
    # arms: fat orange sleeves, thick gloves (mittens)
    for sx, side, S, E, H in ((-1, "r", SHOULDER_R, ELBOW_R, HAND_R), (1, "l", SHOULDER_L, ELBOW_L, HAND_L)):
        pm.tube("upper_arm_" + side, SLOT_BODY, tuple(S), tuple(E), 0.11, 0.10, seg=6, uv=P("cov"), drop_caps=("start", "end"))
        pm.tube("forearm_" + side, SLOT_BODY, tuple(E), tuple(H), 0.10, 0.10, seg=6, uv=P("cov"), drop_caps=("start", "end"))
        pm.add("forearm_" + side, SLOT_BODY, "ell", center=tuple(H + Vector((0, 0, -0.03))), uv=P("glove_gloss"), seg=6, rings=3, radii=(0.125, 0.115, 0.115))
    # little round tail
    pm.add("tail", SLOT_BODY, "ell", center=(0, 0.36, 0.36), uv=P("fur"), seg=6, rings=4, radii=(0.09, 0.08, 0.09))
    return pm


def build_door():
    """The dented cargo-container door, held in the left hand: slab, corrugation ribs, handle."""
    pm = PartMesh(NAME + "_prop_door", [MAT_BODY])
    P = SHEET.planar
    cx, cy, zc = 0.70, -0.23, 0.50
    pm.add("prop_socket", SLOT_BODY, "box", center=(cx, cy, zc), uv=P("door"), size=(0.44, 0.06, 0.72))
    for dx in (-0.14, 0.0, 0.14):
        pm.add("prop_socket", SLOT_BODY, "box", center=(cx + dx, cy - 0.04, zc), uv=P("door"), size=(0.06, 0.03, 0.66))
    pm.add("prop_socket", SLOT_BODY, "box", center=(cx, cy - 0.04, zc + 0.30), uv=SHEET.flat("chalk"), size=(0.38, 0.02, 0.05))   # stencil stripe
    pm.add("prop_socket", SLOT_BODY, "box", center=(cx - 0.20, cy + 0.07, zc - 0.16), uv=P("brass_gloss"), size=(0.10, 0.07, 0.04))   # welded handle
    return pm


def build_hammer():
    """The big dockworker's hammer in the right hand: wood handle, heavy iron head."""
    pm = PartMesh(NAME + "_prop_hammer", [MAT_BODY])
    P = SHEET.planar
    base, top = (-0.52, -0.05, 0.12), (-0.58, 0.0, 0.98)
    pm.tube("weapon_socket", SLOT_BODY, base, top, 0.035, 0.035, seg=6, uv=P("wood"), drop_caps=("start", "end"))
    pm.add("weapon_socket", SLOT_BODY, "box", center=(-0.58, 0.0, 1.0), uv=P("iron_gloss"), size=(0.32, 0.15, 0.18))
    pm.add("weapon_socket", SLOT_BODY, "box", center=(-0.58, 0.0, 1.0), uv=P("brass_gloss"), size=(0.07, 0.17, 0.2))
    return pm


def main():
    os.makedirs(OUT, exist_ok=True)
    bpy.ops.wm.read_factory_settings(use_empty=True)
    SHEET.paint(BODY_PATH)
    paint_face()
    finish(NAME, FOLDER, [(build_body(), [0, 1]), (build_door(), [0]), (build_hammer(), [0])],
           [(MAT_BODY, BODY_PATH), (MAT_FACE, FACE_PATH)], JOINTS,
           idle_args=dict(bounce=0.02, nod=1.6, sway=5.0, arm=2.0))


main()
