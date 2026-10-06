"""Red style prototype B: BUTTON PUP (docs/red_style_prototypes.md).

The simplest possible Red: a huge smooth ball of a head (55% of her height, wider than tall, wider than the
jacket) on a tiny bell-shaped body. Soft, round, almost no surface detail: flat colors per part (the sheet
is a tiny 64x64 of flat cells, plus the painted lamp on the jacket back); all the character is in the
128x64 face sheet (tall wide-set eyes with a shine, tiny muzzle, brows that can look determined).
Shapes are smooth-shaded so the vertex lighting and the 4x4 dither do the shading.

    /tmp/proto_venv/bin/python game/scripts/tools/prototypes/red_proto_b.py
Writes game/art/placeholder/characters/red_prototypes/red_proto_b.glb (+ red_proto_b_body.png, red_proto_b_face.png).
Placeholder only: Ross makes the real Red.
"""

import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from proto_abc_lib import *  # noqa: E402,F401,F403

FLAT = {"front": (2, 2), "back": (2, 2), "side": (2, 2), "top": (2, 2), "bottom": (2, 2)}


def flat(color, bottom=None, top=None):
    """Every cell one flat color (the vertex lighting does the shading); optional different top/bottom."""
    def paint(img, draw, cell, rect):
        c = color
        if cell == "bottom" and bottom:
            c = bottom
        if cell == "top" and top:
            c = top
        fill(draw, rect, c)
    return paint


def jacket_front(img, draw, cell, rect):
    x, y, w, h = rect
    fill(draw, rect, "jacket")
    if cell == "front":
        fill(draw, (x + w // 2 - 1, y, 2, h), "jacket_shade")                 # zip
        fill(draw, (x + w // 2 - 1, y + 2, 2, 2), "brass")
        fill(draw, (x + w - 7, y + 3, 4, 4), "mustard")                         # one patch
        draw.rectangle([x + w - 7, y + 3, x + w - 4, y + 6], outline=rgb("rust"))
        fill(draw, (x + 3, y + 4, 3, 3), "green")
        fill(draw, (x, y + h - 2, w, 2), "jacket_shade")                       # hem
    else:
        fill(draw, (x, y + h - 2, w, 2), "jacket_shade")


def jacket_back(img, draw, cell, rect):
    x, y, w, h = rect
    fill(draw, rect, "jacket")
    if cell == "back":
        cx, cy = x + w // 2, y + h // 2 - 1
        draw.rectangle([cx - 4, cy - 5, cx + 4, cy + 6], fill=rgb("ink"))        # the painted lamp
        draw.rectangle([cx - 3, cy - 3, cx + 3, cy + 5], fill=rgb("brass"))
        draw.rectangle([cx - 2, cy - 1, cx + 2, cy + 3], fill=rgb("glow"))
        draw.arc([cx - 2, cy - 9, cx + 2, cy - 4], 180, 360, fill=rgb("ink"))
        for dx in (-7, 7):
            draw.point((cx + dx, cy), fill=rgb("amber"))
        fill(draw, (x + 2, y + h - 5, 4, 3), "terracotta")
        fill(draw, (x, y + h - 2, w, 2), "jacket_shade")


def cuff_paint(img, draw, cell, rect):
    fill(draw, rect, "tan" if cell in ("top", "bottom") else "jacket_light")


def ear_paint(img, draw, cell, rect):
    x, y, w, h = rect
    fill(draw, rect, "tawny")
    if cell == "front":
        fill(draw, (x + w // 2 - 2, y + h // 3, 4, h // 2), "tawny_shade")


def flop_paint(img, draw, cell, rect):
    fill(draw, rect, "tawny_shade")


def boot_paint(img, draw, cell, rect):
    x, y, w, h = rect
    if cell == "bottom":
        fill(draw, rect, "rust_shade")
        return
    fill(draw, rect, "rust")
    if cell == "front":
        fill(draw, (x, y + h // 2, w, h - h // 2), "tan")                    # toe cap


def lamp_paint(img, draw, cell, rect):
    x, y, w, h = rect
    fill(draw, rect, "brass")
    if cell == "front":
        fill(draw, (x + 1, y + 1, w - 2, h - 2), "glow")
        draw.rectangle([x, y, x + w - 1, y + h - 1], outline=rgb("brass"))
        draw.rectangle([x + 1, y + 1, x + w - 2, y + h - 2], outline=rgb("glow"))
    if cell == "bottom":
        fill(draw, rect, "brass_shade")


def lens_paint(img, draw, cell, rect):
    fill(draw, rect, "glow" if cell == "top" else "brass")


def paint_face(img, draw):
    ink, chalk = "ink", "chalk"
    for ox, grin in ((0, False), (32, True)):
        fill(draw, (ox, 0, 32, 32), "tawny")
        # soft cream muzzle: a rounded patch low in the middle (all the shape the face needs)
        draw.ellipse([ox + 8, 16, ox + 23, 29], fill=rgb("cream"))
        draw.ellipse([ox + 9, 25, ox + 22, 30], fill=rgb("cream_shade"))
        draw.ellipse([ox + 8, 15, ox + 23, 27], fill=rgb("cream"))
        # nose
        draw.ellipse([ox + 13, 17, ox + 18, 20], fill=rgb(ink))
        draw.point((ox + 14, 17), fill=rgb(chalk))
        # tall eyes, wide apart, with a shine
        for ex in (ox + 6, ox + 25):
            if not grin:
                draw.ellipse([ex - 3, 7, ex + 3, 18], fill=rgb(ink))
                fill(draw, (ex - 2, 8, 2, 3), chalk)
                draw.point((ex + 1, 15), fill=rgb(chalk))
            else:
                draw.arc([ex - 4, 9, ex + 4, 19], 200, 340, fill=rgb(ink))
                draw.arc([ex - 4, 10, ex + 4, 20], 200, 340, fill=rgb(ink))
                draw.arc([ex - 4, 11, ex + 4, 21], 200, 340, fill=rgb(ink))
        # brows: slanted in toward the nose so even the calm face looks like it means it
        for sign, ex in ((-1, ox + 6), (1, ox + 25)):
            if not grin:
                draw.line([(ex - 3, 3 if sign < 0 else 5), (ex + 3, 5 if sign < 0 else 3)], fill=rgb(ink))
            else:
                draw.line([(ex - 3, 4), (ex + 3, 4)], fill=rgb(ink))
        # mouth
        if not grin:
            draw.line([(ox + 16, 20), (ox + 16, 22)], fill=rgb(ink))
            draw.line([(ox + 13, 23), (ox + 19, 23)], fill=rgb(ink))
        else:
            draw.ellipse([ox + 11, 21, ox + 20, 28], fill=rgb(ink))
            fill(draw, (ox + 12, 21, 8, 2), chalk)
            fill(draw, (ox + 13, 26, 6, 2), "tongue")
            draw.line([(ox + 16, 20), (ox + 16, 21)], fill=rgb(ink))


BONES = {
    "root": ((0, 0, 0), (0, 0, 0.05), None),
    "hips": ((0, 0, 0.15), (0, 0, 0.25), "root"),
    "spine": ((0, 0, 0.25), (0, 0, 0.44), "hips"),
    "head": ((0, 0, 0.45), (0, 0, 0.95), "spine"),
    "ear_r": ((-0.16, 0, 0.92), (-0.17, 0, 1.2), "head"),
    "ear_l": ((0.24, 0, 0.95), (0.33, 0, 0.66), "head"),
    "tail": ((0, 0.14, 0.2), (0, 0.22, 0.27), "hips"),
    "upper_arm_r": ((-0.13, 0, 0.42), (-0.2, -0.03, 0.37), "spine"),
    "forearm_r": ((-0.2, -0.03, 0.37), (-0.27, -0.13, 0.41), "upper_arm_r"),
    "upper_arm_l": ((0.13, 0, 0.42), (0.19, -0.01, 0.34), "spine"),
    "forearm_l": ((0.19, -0.01, 0.34), (0.23, -0.02, 0.25), "upper_arm_l"),
    "thigh_r": ((-0.075, 0, 0.15), (-0.075, 0, 0.1), "hips"),
    "shin_r": ((-0.075, 0, 0.1), (-0.075, 0, 0.04), "thigh_r"),
    "thigh_l": ((0.075, 0, 0.15), (0.075, 0, 0.1), "hips"),
    "shin_l": ((0.075, 0, 0.1), (0.075, 0, 0.04), "thigh_l"),
    "weapon_socket": ((-0.27, -0.14, 0.41), (-0.28, -0.11, 0.47), "forearm_r"),
    "prop_socket": ((0.23, -0.02, 0.25), (0.23, -0.02, 0.31), "forearm_l"),
}

FACE = dict(region=(-0.26, 0.26, 0.47, 0.98), cell=(0, 0, 32, 32), sel=lambda n, c: n.y < -0.5)


def build_parts(b, sw, atlas, face_atlas):
    A = atlas
    # --- the ball of a head
    head_tile = A.tile("head", FLAT, flat("tawny", bottom="tawny_shade"))
    b.add("head", "head", pts_ellipsoid(0.31, 0.27, 0.275, 8, 6, phase=math.pi / 8), T(0, 0, 0.725), head_tile,
          smooth=True, face=FACE)
    # --- ears: soft leaf up (right), leaf folded down against the ball (left)
    up_tile = A.tile("ear_up", {"front": (6, 10), "back": (2, 2), "side": (2, 2)}, ear_paint)
    leaf = [(0, 0), (0.08, 0.07), (0.075, 0.18), (0, 0.31), (-0.075, 0.18), (-0.08, 0.07)]
    b.add("ear_up", "ear_r", pts_slab(leaf, 0.10), T(-0.15, 0, 0.9, ry=-5), up_tile, smooth=True)
    fl_tile = A.tile("ear_flop", {"front": (2, 2), "back": (2, 2), "side": (2, 2)}, flop_paint)
    flap = [(0, 0.17), (0.085, 0.09), (0.09, -0.06), (0, -0.21), (-0.09, -0.06), (-0.085, 0.09)]
    b.add("ear_flop", "ear_l", pts_slab(flap, 0.10), T(0.30, 0, 0.83) @ R(ry=-10), fl_tile, smooth=True)
    # --- goggles: a brass strip over the top of the ball, two glowing lenses on it
    strip_tile = A.tile("goggle_strip", {"front": (2, 2), "side": (2, 2), "top": (2, 2)}, flat("brass", bottom="brass_shade"))
    b.add("goggle_strip", "head", pts_box(0.33, 0.07, 0.045), T(0.045, -0.075, 0.985, rx=-12), strip_tile)
    lens_tile = A.tile("lens", {"top": (2, 2), "side": (2, 2), "bottom": (2, 2)}, lens_paint)
    for i, lx in enumerate((-0.03, 0.12)):
        b.limb("lens_%d" % i, "head", (lx, -0.04, 0.975), (lx, -0.13, 1.03), 0.075, 0.075, n=6, tile=lens_tile)
    # --- body: a small bell of jacket, hem down to the knees
    jt = A.tile("jacket", {"front": (16, 14), "back": (22, 16), "side": (2, 2), "top": (2, 2), "bottom": (2, 2)}, None)

    def jacket_paint(img, draw, cell, rect):
        (jacket_front if cell in ("front", "side", "top", "bottom") else jacket_back)(img, draw, cell, rect)
    jt.painter = jacket_paint
    b.add("jacket", "spine", pts_frustum((0.19, 0.17), (0.115, 0.105), 0.34, 8, phase=math.pi / 8), T(0, 0, 0.30),
          jt, smooth=True, ybias=1.6)
    # --- arms: short stubs in huge cuffs, round mittens peeking out
    sl_tile = A.tile("sleeve", {"front": (2, 2), "side": (2, 2), "top": (2, 2), "bottom": (2, 2)}, cuff_paint)
    sl_tile.painter = lambda img, draw, cell, rect: fill(draw, rect, "tan" if cell == "top" else "jacket")
    mit_tile = A.tile("mitten", FLAT, flat("tawny"))
    b.limb("sleeve_l", "upper_arm_l", (0.12, 0, 0.42), (0.225, -0.015, 0.285), 0.065, 0.095, n=6, tile=sl_tile, smooth=True)
    b.add("mitten_l", "forearm_l", pts_ellipsoid(0.055, 0.05, 0.055, 6, 3), T(0.23, -0.02, 0.235), mit_tile, smooth=True)
    b.add("thumb_l", "forearm_l", pts_ellipsoid(0.028, 0.028, 0.035, 5, 2), T(0.215, -0.065, 0.245), mit_tile, smooth=True)
    b.limb("sleeve_r", "upper_arm_r", (-0.12, 0, 0.42), (-0.255, -0.115, 0.4), 0.065, 0.095, n=6, tile=sl_tile, smooth=True)
    b.add("mitten_r", "forearm_r", pts_ellipsoid(0.055, 0.05, 0.055, 6, 3), T(-0.275, -0.145, 0.405), mit_tile, smooth=True)
    b.add("thumb_r", "forearm_r", pts_ellipsoid(0.028, 0.028, 0.035, 5, 2), T(-0.245, -0.17, 0.425), mit_tile, smooth=True)
    # --- boots (round, tiny)
    boot_tile = A.tile("boot", {"front": (4, 4), "side": (2, 2), "top": (2, 2), "bottom": (2, 2)}, boot_paint)
    for tag, bone, x in (("r", "shin_r", -0.075), ("l", "shin_l", 0.075)):
        b.add("boot_" + tag, bone, pts_ellipsoid(0.085, 0.115, 0.07, 6, 4, phase=math.pi / 6), T(x, -0.02, 0.07),
              boot_tile, smooth=True)
    # --- tail
    tail_tile = A.tile("tail", FLAT, flat("tawny"))
    b.add("tail", "tail", pts_ellipsoid(0.05, 0.05, 0.075, 5, 2), T(0, 0.17, 0.215, rx=-40), tail_tile, smooth=True)
    # --- lamp: a fat brass lozenge at the left hip, glass facing front
    lamp_tile = A.tile("lamp", {"front": (8, 8), "side": (2, 2), "bottom": (2, 2), "top": (2, 2), "back": (2, 2)}, lamp_paint)
    b.add("lamp", "hips", pts_ellipsoid(0.075, 0.065, 0.095, 6, 4, phase=math.pi / 6), T(0.09, -0.185, 0.245), lamp_tile, smooth=True)
    # --- satchel on the back, right side
    st_tile = A.tile("satchel", {"front": (2, 2), "back": (6, 6), "side": (2, 2), "top": (2, 2)},
                     lambda img, draw, cell, rect: (fill(draw, rect, "tan"),
                                                    fill(draw, (rect[0] + 1, rect[1] + 2, rect[2] - 2, 2), "rust")) if cell == "back" else fill(draw, rect, "tan"))
    b.add("satchel", "hips", pts_box(0.15, 0.07, 0.12), T(-0.075, 0.165, 0.26), st_tile)
    # --- sword: longer than she is tall, resting over the right shoulder
    hand = Vector((-0.275, -0.15, 0.40))
    d = Vector((-0.26, 0.6, 0.76)).normalized()
    at = lambda s: hand + d * s  # noqa: E731
    front = (1, 0, 0)
    g_tile = sw.atlas.tile("sw_grip", FLAT, flat("rust"))
    br_tile = sw.atlas.tile("sw_brass", FLAT, flat("brass", bottom="brass_shade"))
    bl_tile = sw.atlas.tile("sw_blade", {"front": (8, 24), "side": (2, 2), "top": (2, 2)}, None)

    def blade_paint(img, draw, cell, rect):
        x, y, w, h = rect
        fill(draw, rect, "chalk")
        if cell == "front":
            fill(draw, (x + w - 3, y, 3, h), "dusk")
            fill(draw, (x + w // 2 - 1, y + 2, 1, h - 6), "cream_shade")
        elif cell in ("side", "top"):
            fill(draw, rect, "dusk")
    bl_tile.painter = blade_paint
    sw.limb("sword_grip", "weapon_socket", at(-0.07), at(0.07), 0.035, 0.035, n=6, front=front, tile=g_tile)
    sw.add("sword_guard", "weapon_socket", pts_box(0.04, 0.2, 0.04), aim(at(0.07), at(0.11), front), br_tile)
    blade = pts_slab([(-0.065, 0), (0.065, 0), (0.065, 0.95), (0.0, 1.13), (-0.065, 0.95)], 0.06)
    sw.add("sword_blade", "weapon_socket", blade,
           aim(at(0.11), at(1.24), (1, 0.9, 0)) @ Matrix.Translation((0, 0, -0.565)), bl_tile)


if __name__ == "__main__":
    build_prototype("b", "Button Pup", BONES, build_parts, paint_face, (64, 64))
