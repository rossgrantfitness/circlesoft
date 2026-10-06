"""The old Zero: a Relay Watch Zero old-timer. Placeholder blockout in the Red house style.

Dust-colored wraps, little brass bells sewn to the sleeves, and big brass ear-cups for listening
(docs/art_requests.md row 13; docs/story_bible.md Watch Zero row; palette tan #CBA878, brass #D9A441).
A short, round, slightly hunched crowd NPC (about 0.95x Red), with a thermos in one mitten (the old Zero
who heals the party before the boss carries one, docs/design_doc.md).

SPECIES IS NOT SET. Neither art_requests.md nor the story bible names one for the old Zero, so this is a
deliberately neutral placeholder critter: a soft bean head, a short pale muzzle, no visible ears (the
brass ear-cups cover where ears would be), a tiny tuft of tail. It is NOT a species decision. Ross picks
the species; when he does, only the head details (ears, snout, tail) need to change.

Crowd NPC budget (docs/style_guide.md): 350 target, 500 cap, 64 px textures (this uses the shared 128 px
body sheet like the others so recolors stay easy; the texture is well under the 128 px limit).

Output: game/art/placeholder/characters/old_zero/npc_old_zero.glb (+ npc_old_zero.png, npc_old_zero_face.png:
cranky on the left, pleased on the right, swap with uv_offset.x = 0.5).
Run: /tmp/blockout_venv/bin/python game/scripts/tools/cast_old_zero.py   (see cast_kit.py)
"""

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from cast_kit import *  # noqa: E402,F403

NAME = "npc_old_zero"
FOLDER = "old_zero"
OUT = os.path.join(CHARACTERS_DIR, FOLDER)
BODY_PATH = os.path.join(OUT, NAME + ".png")
FACE_PATH = os.path.join(OUT, NAME + "_face.png")
MAT_BODY, MAT_FACE = "mat_" + NAME, "mat_" + NAME + "_face"

COLORS = {
    "fur": ("#F8EDD2", "#E3CBA0"), "wrap": ("#D1A465", "#9F7545"), "wrap2": ("#B58348", "#85582F"),
    "sash": ("#CF6A40", "#8F432C"), "brass": ("#E8B24A", "#AA762F"), "boot": ("#7E563B", "#563827"),
    "green": ("#86BA70", "#54845A"), "ink": ("#14121F", "#14121F"), "chalk": ("#F5EFD8", "#DACFA8"),
}
SHEET = Sheet(COLORS, gloss=("fur", "brass", "boot"))

LEAN_DEG = 12.0
HIP_PIVOT = Vector((0.0, 0.0, 0.22))
LEAN = Matrix.Translation(HIP_PIVOT) @ rot_matrix((LEAN_DEG, 0, 0)) @ Matrix.Translation(-HIP_PIVOT)


def L(v):
    return LEAN @ Vector(v)


HEAD_C = Vector((0.0, 0.0, 0.80))
HEAD_R = (0.24, 0.21, 0.19)
FACE = FaceMap(HEAD_C.z, 0.27, 0.21)
MUZ_Y0, MUZ_Y1, MUZ_Z, MUZ_RX, MUZ_RZ = -0.14, -0.24, 0.755, 0.09, 0.065
SHOULDER_L, SHOULDER_R = Vector((0.2, 0.0, 0.57)), Vector((-0.2, 0.0, 0.57))
ELBOW_L, HAND_L = Vector((0.28, -0.03, 0.45)), Vector((0.30, -0.10, 0.34))
ELBOW_R, HAND_R = Vector((-0.28, -0.03, 0.45)), Vector((-0.30, -0.10, 0.34))

JOINTS = {
    "root": ((0, 0, 0), (0, 0, 0.05)),
    "hips": ((0, 0, 0.2), tuple(L((0, 0, 0.27)))),
    "spine": (tuple(L((0, 0, 0.27))), tuple(L((0, 0, 0.6)))),
    "head": (tuple(L((0, 0, 0.6))), tuple(L((0, 0, 1.0)))),
    "ear_l": (tuple(L((0.3, 0, 0.84))), tuple(L((0.36, 0, 0.84)))),
    "ear_r": (tuple(L((-0.3, 0, 0.84))), tuple(L((-0.36, 0, 0.84)))),
    "tail": (tuple(L((0, 0.2, 0.26))), tuple(L((0, 0.3, 0.3)))),
    "upper_arm_l": (tuple(L(SHOULDER_L)), tuple(L(ELBOW_L))),
    "forearm_l": (tuple(L(ELBOW_L)), tuple(L(HAND_L))),
    "upper_arm_r": (tuple(L(SHOULDER_R)), tuple(L(ELBOW_R))),
    "forearm_r": (tuple(L(ELBOW_R)), tuple(L(HAND_R))),
    "thigh_l": ((0.075, 0, 0.25), (0.075, 0, 0.16)),
    "shin_l": ((0.075, 0, 0.16), (0.075, -0.005, 0.1)),
    "thigh_r": ((-0.075, 0, 0.25), (-0.075, 0, 0.16)),
    "shin_r": ((-0.075, 0, 0.16), (-0.075, -0.005, 0.1)),
    "weapon_socket": (tuple(L(HAND_R)), tuple(L(HAND_R) + Vector((0, 0, 0.08)))),
    "prop_socket": (tuple(L(HAND_L)), tuple(L(HAND_L) + Vector((0, 0, 0.08)))),
}


def paint_face():
    img = Image.new("RGB", (FACE_W, FACE_H), SHEET.rgb["fur"][0])
    d = ImageDraw.Draw(img)
    fur, fur_s = SHEET.rgb["fur"]
    wrap, wrap_s = SHEET.rgb["wrap"]
    ink, chalk = SHEET.rgb["ink"][0], CHALK
    nose = hex_rgb("#C97A62")
    for cell, pleased in ((0, False), (1, True)):
        step = paint_face_background(img, FACE, cell, fur, fur_s)
        shade_pass(img, cell, step, [])
        d.ellipse(FACE.box(cell, -0.22, 0.60, 0.22, 0.74), fill=wrap)               # dusty cheek fluff (warm tan, dithered)
        for x in range(FACE_CELL):
            for y in range(FACE_CELL):
                if (x + y) % 2:
                    px = (cell * FACE_CELL + x, y)
                    if img.getpixel(px) == wrap:
                        img.putpixel(px, fur if y < step else fur_s)
        shade_pass(img, cell, step, [(wrap, wrap_s)])
        d.rectangle(FACE.box(cell, -MUZ_RX * 1.05, MUZ_Z - MUZ_RZ * 1.1, MUZ_RX * 1.05, MUZ_Z + MUZ_RZ * 1.1), fill=fur)
        n = FACE.box(cell, -0.04, MUZ_Z + 0.01, 0.04, MUZ_Z + 0.055)
        d.ellipse(n, fill=nose)
        d.point([(n[0] + 2, n[1] + 1)], fill=chalk)
        if not pleased:
            a = FACE.box(cell, -0.06, MUZ_Z - 0.02, 0.06, MUZ_Z - 0.05)               # a flat, grumpy line
            d.line([(a[0], a[3]), (a[2], a[3])], fill=ink, width=2)
        else:
            m = FACE.box(cell, -0.055, MUZ_Z - 0.0, 0.055, MUZ_Z - 0.065)
            d.pieslice([m[0], m[1] - (m[3] - m[1]) * 0.3, m[2], m[3]], 0, 180, fill=ink)
        # tired little eyes under long bushy cream-white brows (with a tan fringe)
        for sx in (-1, 1):
            ex, ez = 0.105 * sx, 0.835
            if not pleased:
                e = FACE.box(cell, ex - 0.03, ez - 0.032, ex + 0.03, ez + 0.032)
                d.ellipse(e, fill=ink)
                d.point([(e[0] + 2, e[1] + 2)], fill=chalk)
            else:
                pts = [FACE.pixel(cell, ex + dx, ez + dz) for dx, dz in ((-0.032, -0.012), (-0.015, 0.016), (0, 0.024), (0.015, 0.016), (0.032, -0.012))]
                d.line(pts, fill=ink, width=3)
            b = FACE.box(cell, ex - 0.06, ez + 0.04, ex + 0.06, ez + 0.085)
            d.ellipse(b, fill=chalk)
            d.line([(b[0] + 1, b[3] - 1), (b[2] - 1, b[1] + (2 if not pleased else 4))], fill=wrap, width=1)
    img.save(FACE_PATH)


def build_body():
    pm = PartMesh(NAME + "_body", [MAT_BODY, MAT_FACE])
    P = SHEET.planar
    for sx, side in ((-1, "r"), (1, "l")):
        pm.tube("thigh_" + side, SLOT_BODY, (0.075 * sx, 0, 0.25), (0.075 * sx, -0.005, 0.1), 0.075, 0.07, seg=5, uv=P("wrap2"), drop_caps=("start", "end"))
        pm.add("shin_" + side, SLOT_BODY, "ell", center=(0.08 * sx, -0.045, 0.07), uv=P("boot_gloss"), seg=6, rings=3, radii=(0.095, 0.13, 0.075))
    # wrapped, round body (leans forward), a terracotta sash, a wrap collar
    pm.set_group_transform(LEAN)
    pm.tube("hips", SLOT_BODY, (0, 0, 0.20), (0, 0, 0.42), 0.25, 0.28, seg=7, sxy=(1.0, 0.9), uv=SHEET.planar_z("wrap2", 0.2, 0.62), drop_caps=("start", "end"), spin=22.5)
    pm.tube("hips", SLOT_BODY, (0, 0, 0.40), (0, 0, 0.45), 0.285, 0.285, seg=7, sxy=(1.0, 0.9), uv=P("sash"), drop_caps=("start", "end"), spin=22.5)
    pm.tube("spine", SLOT_BODY, (0, 0, 0.45), (0, 0, 0.62), 0.27, 0.17, seg=7, sxy=(1.0, 0.9), uv=SHEET.planar_z("wrap", 0.2, 0.62), drop_caps=("start", "end"), spin=22.5)
    pm.tube("spine", SLOT_BODY, (0, 0, 0.60), (0, 0, 0.66), 0.17, 0.15, seg=7, sxy=(1.0, 0.9), uv=P("wrap2"), drop_caps=("start", "end"), spin=22.5)
    # head, small pale muzzle (neutral critter), brass ear-cups and the headband that joins them
    pm.add("head", head_slot, "ell", center=tuple(HEAD_C), uv=head_uv_factory(SHEET, FACE, "fur", "fur"), seg=8, rings=5, radii=HEAD_R, deform=bean(HEAD_R))
    pm.tube("head", muzzle_slot, (0, MUZ_Y0, MUZ_Z), (0, MUZ_Y1, MUZ_Z), MUZ_RX, MUZ_RX * 0.9, seg=6, sxy=(1.0, MUZ_RZ / MUZ_RX),
            uv=muzzle_uv_factory(SHEET, FACE, "fur"), drop_caps=("start",), spin=30)
    for sx, bone in ((-1, "ear_r"), (1, "ear_l")):
        pm.tube(bone, SLOT_BODY, (0.2 * sx, 0, 0.82), (0.34 * sx, 0, 0.82), 0.15, 0.15, seg=6, sxy=(1.0, 1.0), uv=P("brass_gloss"), drop_caps=("start",), spin=22.5)
        arc = [(0.30, 0.88), (0.24, 0.99), (0.12, 1.04)]
        for (x0, z0), (x1, z1) in zip(arc[:-1], arc[1:]):
            pm.tube("head", SLOT_BODY, (x0 * sx, 0, z0), (x1 * sx, 0, z1), 0.035, 0.035, seg=4, uv=P("brass"), drop_caps=("start", "end"))
    pm.tube("head", SLOT_BODY, (-0.12, 0, 1.04), (0.12, 0, 1.04), 0.035, 0.035, seg=4, uv=P("brass"), drop_caps=("start", "end"))
    # arms: wide wrapped sleeves, dark cuff bands with brass bells sewn on, round mitts
    for sx, side, S, E, H in ((-1, "r", SHOULDER_R, ELBOW_R, HAND_R), (1, "l", SHOULDER_L, ELBOW_L, HAND_L)):
        pm.tube("upper_arm_" + side, SLOT_BODY, tuple(S), tuple(E), 0.085, 0.08, seg=5, uv=P("wrap"), drop_caps=("start", "end"))
        u = (H - E).normalized()
        c0, c1 = H - u * 0.11, H - u * 0.03
        pm.tube("forearm_" + side, SLOT_BODY, tuple(E), tuple(c0 + u * 0.01), 0.08, 0.08, seg=5, uv=P("wrap"), drop_caps=("start", "end"))
        pm.tube("forearm_" + side, SLOT_BODY, tuple(c0), tuple(c1), 0.1, 0.1, seg=5, uv=P("wrap2"), drop_caps=("start", "end"))
        pm.add("forearm_" + side, SLOT_BODY, "ell", center=tuple(H + u * 0.0), uv=P("fur_gloss"), seg=5, rings=3, radii=(0.075, 0.07, 0.07))
        for pos in (Vector((0.075 * sx, -0.07, -0.085)) + c0, Vector((0.095 * sx, 0.0, -0.04)) + E):
            pm.add("forearm_" + side, SLOT_BODY, "ell", center=tuple(pos), uv=P("brass_gloss"), seg=4, rings=3, radii=(0.04, 0.04, 0.045))
    pm.set_group_transform(Matrix.Identity(4))
    pm.add("tail", SLOT_BODY, "ell", center=tuple(L((0, 0.27, 0.27))), uv=P("fur"), seg=5, rings=3, radii=(0.065, 0.065, 0.065))
    return pm


def build_thermos():
    pm = PartMesh(NAME + "_prop_thermos", [MAT_BODY])
    P = SHEET.planar
    c = L(HAND_L)
    pm.tube("prop_socket", SLOT_BODY, (c.x, c.y - 0.02, c.z - 0.03), (c.x, c.y - 0.02, c.z + 0.2), 0.05, 0.05, seg=5, uv=P("green"), drop_caps=("start", "end"))
    pm.add("prop_socket", SLOT_BODY, "box", center=(c.x, c.y - 0.02, c.z + 0.225), uv=P("brass_gloss"), size=(0.08, 0.08, 0.05))
    return pm


def main():
    os.makedirs(OUT, exist_ok=True)
    bpy.ops.wm.read_factory_settings(use_empty=True)
    SHEET.paint(BODY_PATH)
    paint_face()
    finish(NAME, FOLDER, [(build_body(), [0, 1]), (build_thermos(), [0])],
           [(MAT_BODY, BODY_PATH), (MAT_FACE, FACE_PATH)], JOINTS,
           idle_args=dict(bounce=0.012, nod=1.5, sway=4.0, arm=2.0))


main()
