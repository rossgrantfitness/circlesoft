"""Red style prototype A: WIND-UP TOY (docs/red_style_prototypes.md).

A sturdy painted toy: about 2 heads tall (head = 50% of her height), a big chamfered-box head, a short
wide jacket block, short tube arms ending in oversized mittens, stub legs in big round boots. Every part
is a chunky piece that looks bolted on. Texture: 128x128 body sheet of flat color areas with ONE hard
shade step (hand-dithered at the step), chunky seams, patch squares, the hand-painted lamp on the back,
plus a 128x64 face sheet (neutral + grin).

    /tmp/proto_venv/bin/python game/scripts/tools/prototypes/red_proto_a.py
Writes game/art/placeholder/characters/red_prototypes/red_proto_a.glb (+ red_proto_a_body.png, red_proto_a_face.png).
Placeholder only: Ross makes the real Red.
"""

import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from proto_abc_lib import *  # noqa: E402,F401,F403

# ---------------------------------------------------------------- painters (body sheet)


def toy_painter(base, shade, seam=None, band=0.28, hi=None):
    """Flat color with one hard shade step near the bottom, a dithered row at the step, optional seams."""
    def paint(img, draw, cell, rect):
        x, y, w, h = rect
        if cell == "bottom":
            fill(draw, rect, shade)
        else:
            fill(draw, rect, base)
            if cell != "top":
                bh = max(2, int(h * band))
                dither_fill(draw, (x, y + h - bh - 1, w, 1), base, shade)
                fill(draw, (x, y + h - bh, w, bh), shade)
            elif hi:
                dither_fill(draw, (x, y, w, 1), base, hi)
        if seam and cell not in ("top", "bottom"):
            border(draw, rect, seam, "lr")
    return paint


def jacket_painter(img, draw, cell, rect):
    x, y, w, h = rect
    base, shade, deep = "jacket", "jacket_shade", mix("jacket_shade", "ink", 0.35)
    fill(draw, rect, base)
    bh = max(5, int(h * 0.27))
    dither_fill(draw, (x, y + h - bh - 1, w, 1), base, shade)
    fill(draw, (x, y + h - bh, w, bh), shade)
    border(draw, rect, deep, "lr")
    if cell == "front":
        # zip, brass pull, two pockets, a mustard and a green patch, the satchel strap
        fill(draw, (x + w // 2, y + 1, 2, h - 2), deep)
        fill(draw, (x + w // 2 - 1, y + 3, 4, 3), "brass")
        for px in (x + 5, x + w - 15):
            draw.rectangle([px, y + h - 13, px + 9, y + h - 6], outline=rgb(deep))
        fill(draw, (x + w - 13, y + 5, 9, 9), "mustard")
        draw.rectangle([x + w - 13, y + 5, x + w - 5, y + 13], outline=rgb("rust"))
        fill(draw, (x + 4, y + 6, 7, 7), "green")
        for i in range(0, h - 4):                       # strap: top-right shoulder down to the left hip
            sx = x + w - 6 - int(i * (w - 12) / (h - 4))
            fill(draw, (sx - 1, y + 2 + i, 4, 1), "tan")
            draw.point((sx - 2, y + 2 + i), fill=rgb("rust"))
    elif cell == "back":
        # the hand-painted lamp: ink outline, brass body, glow window, ring handle, amber rays.
        # (The back cell is mirrored: +X, her left, is on the left of this cell; the satchel hides the right.)
        cx, cy = x + int(w * 0.36), y + 17
        draw.rectangle([cx - 7, cy - 8, cx + 7, cy + 9], fill=rgb("ink"))
        draw.rectangle([cx - 6, cy - 5, cx + 6, cy + 8], fill=rgb("brass"))
        draw.rectangle([cx - 3, cy - 2, cx + 3, cy + 6], fill=rgb("glow"))
        draw.rectangle([cx - 6, cy - 8, cx + 6, cy - 6], fill=rgb("brass_shade"))
        draw.rectangle([cx - 6, cy + 7, cx + 6, cy + 8], fill=rgb("brass_shade"))
        draw.arc([cx - 3, cy - 14, cx + 3, cy - 7], 180, 360, fill=rgb("ink"))
        for dx, dy in ((-11, -2), (11, -2), (-10, 5), (10, 5)):
            draw.point((cx + dx, cy + dy), fill=rgb("amber"))
            draw.point((cx + dx + (1 if dx < 0 else -1), cy + dy), fill=rgb("amber"))
        fill(draw, (x + 3, y + h - 12, 8, 8), "terracotta")
        draw.rectangle([x + 3, y + h - 12, x + 10, y + h - 5], outline=rgb("rust"))
        fill(draw, (x + w - 10, y + 4, 7, 7), "mustard")
    elif cell == "side":
        for i in range(3):                              # fold lines
            draw.line([(x + 4 + i * 11, y + 3), (x + 8 + i * 11, y + h - bh - 2)], fill=rgb(shade))


def cuff_painter(img, draw, cell, rect):
    x, y, w, h = rect
    if cell == "top":
        fill(draw, rect, "tan")
        return
    fill(draw, rect, "jacket_light")
    fill(draw, (x, y + h // 2, w, h - h // 2), "jacket")
    dither_fill(draw, (x, y + h // 2 - 1, w, 1), "jacket_light", "jacket")
    border(draw, rect, "jacket_shade", "tb")


def boot_painter(img, draw, cell, rect):
    x, y, w, h = rect
    if cell == "bottom":
        fill(draw, rect, "rust_shade")
        return
    fill(draw, rect, "rust")
    if cell == "top":
        for i in range(3):
            fill(draw, (x + 2, y + 3 + i * 4, w - 4, 1), "tan")
        return
    fill(draw, (x, y + h - 3, w, 3), "rust_shade")      # sole
    if cell == "front":
        fill(draw, (x + 2, y + h - 8, w - 4, 5), "tan")  # toe cap
        draw.rectangle([x + 2, y + h - 8, x + w - 3, y + h - 4], outline=rgb("rust_shade"))
    else:
        dither_fill(draw, (x, y + h - 5, w, 1), "rust", "rust_shade")


def ear_up_painter(img, draw, cell, rect):
    x, y, w, h = rect
    fill(draw, rect, "tawny")
    if cell == "front":
        fill(draw, (x + w // 2 - 3, y + h // 3, 6, h // 2), "tawny_shade")  # inner ear
        fill(draw, (x + w // 2 - 1, y + h // 3 - 3, 2, 3), "tawny_shade")
    border(draw, rect, "tawny_shade", "lr")


def ear_flop_painter(img, draw, cell, rect):
    x, y, w, h = rect
    fill(draw, rect, "tawny_shade")
    if cell == "front":
        dither_fill(draw, (x + 3, y + 2, w - 6, h // 2), "tawny_shade", "tawny")
    border(draw, rect, "tawny_deep", "lr")


def goggle_painter(img, draw, cell, rect):
    x, y, w, h = rect
    fill(draw, rect, "brass")
    if cell in ("front", "side", "back"):
        fill(draw, (x, y + h - 2, w, 2), "brass_shade")
        draw.line([(x, y), (x + w - 1, y)], fill=rgb("glow"))
        for rx in range(x + 4, x + w - 3, 9):           # rivets
            draw.point((rx, y + h // 2), fill=rgb("ink"))
    if cell in ("top", "bottom"):
        dither_fill(draw, rect, "brass", "brass_shade")


def lens_painter(img, draw, cell, rect):
    fill(draw, rect, "glow" if cell == "top" else ("brass" if cell == "side" else "brass_shade"))
    if cell == "top":
        draw.point((rect[0], rect[1]), fill=rgb("chalk"))


def lamp_painter(img, draw, cell, rect):
    x, y, w, h = rect
    if cell == "bottom":
        fill(draw, rect, "brass_shade")
        return
    fill(draw, rect, "brass")
    if cell == "top":
        fill(draw, (x + 2, y + 2, w - 4, h - 4), "brass_shade")
        return
    fill(draw, (x, y + h - 4, w, 4), "brass_shade")
    dither_fill(draw, (x, y + h - 5, w, 1), "brass", "brass_shade")
    fill(draw, (x, y, w, 3), "brass_shade")             # cap
    border(draw, rect, "brass_shade", "lr")
    if cell == "front":
        fill(draw, (x + 2, y + 4, w - 4, h - 9), "ink")
        fill(draw, (x + 3, y + 5, w - 6, h - 11), "glow")


def satchel_painter(img, draw, cell, rect):
    x, y, w, h = rect
    fill(draw, rect, "tan")
    fill(draw, (x, y + h - 4, w, 4), "tan_shade")
    dither_fill(draw, (x, y + h - 5, w, 1), "tan", "tan_shade")
    if cell in ("front", "back"):
        draw.rectangle([x + 2, y + 2, x + w - 3, y + h - 3], outline=rgb("rust"))
        fill(draw, (x + w // 2 - 2, y + h // 2 - 1, 4, 4), "brass")
    border(draw, rect, "rust_shade", "lr")


def flap_painter(img, draw, cell, rect):
    fill(draw, rect, "rust")
    border(draw, rect, "rust_shade", "tb")
    if cell == "front":
        fill(draw, (rect[0] + rect[2] // 2 - 2, rect[1] + rect[3] - 5, 4, 4), "brass")


def blade_painter(img, draw, cell, rect):
    x, y, w, h = rect
    fill(draw, rect, "chalk")
    if cell in ("front", "back"):
        fill(draw, (x + w - 3, y, 3, h), "dusk")                  # shade step down one edge
        fill(draw, (x + w // 2 - 1, y + 3, 1, h - 10), "cream_shade")   # fuller
    else:
        fill(draw, rect, "dusk")


def thumb_painter(img, draw, cell, rect):
    fill(draw, rect, "tawny")


# ---------------------------------------------------------------- face sheet


def paint_face(img, draw):
    ink, chalk = "ink", "chalk"
    for ox, grin in ((0, False), (32, True)):
        fill(draw, (ox, 0, 32, 32), "tawny")
        fill(draw, (ox, 0, 32, 3), "tawny_shade")                  # shade under the goggle band
        dither_fill(draw, (ox, 3, 32, 1), "tawny", "tawny_shade")
        # cream muzzle block (the 3D block sits over this)
        fill(draw, (ox + 8, 17, 16, 14), "cream")
        draw.point((ox + 8, 17), fill=rgb("tawny"))
        draw.point((ox + 23, 17), fill=rgb("tawny"))
        fill(draw, (ox + 8, 28, 16, 3), "cream_shade")
        # nose
        fill(draw, (ox + 13, 18, 6, 3), ink)
        draw.point((ox + 14, 18), fill=rgb(chalk))
        # eyes
        for ex in (ox + 8, ox + 23):
            if not grin:
                draw.ellipse([ex - 2, 8, ex + 2, 17], fill=rgb(ink))      # tall oval
                fill(draw, (ex - 1, 9, 2, 2), chalk)                       # shine
            else:
                draw.arc([ex - 3, 9, ex + 3, 16], 200, 340, fill=rgb(ink))  # happy arches
                draw.arc([ex - 3, 10, ex + 3, 17], 200, 340, fill=rgb(ink))
        # brows: short dashes, tilted in toward the middle (determined)
        for sign, ex in ((-1, ox + 8), (1, ox + 23)):
            if not grin:
                draw.line([(ex - 3, 5 if sign < 0 else 7), (ex + 3, 7 if sign < 0 else 5)], fill=rgb(ink))
            else:
                draw.line([(ex - 3, 5), (ex + 3, 5)], fill=rgb(ink))
        # mouth
        if not grin:
            draw.point((ox + 16, 21), fill=rgb(ink))
            draw.line([(ox + 14, 23), (ox + 18, 23)], fill=rgb(ink))
        else:
            fill(draw, (ox + 11, 22, 10, 6), ink)
            fill(draw, (ox + 12, 22, 8, 2), chalk)                         # teeth
            fill(draw, (ox + 13, 26, 6, 2), "tongue")
            draw.point((ox + 10, 22), fill=rgb(ink))
            draw.point((ox + 21, 22), fill=rgb(ink))


# ---------------------------------------------------------------- layout
SHADE = {"head": ("tawny", "tawny_shade")}

BONES = {
    "root": ((0, 0, 0), (0, 0, 0.06), None),
    "hips": ((0, 0, 0.17), (0, 0, 0.25), "root"),
    "spine": ((0, 0, 0.25), (0, 0, 0.48), "hips"),
    "head": ((0, 0, 0.5), (0, 0, 0.95), "spine"),
    "ear_r": ((-0.17, 0, 0.92), (-0.17, 0, 1.2), "head"),
    "ear_l": ((0.25, 0, 0.95), (0.29, 0, 0.58), "head"),
    "tail": ((0, 0.17, 0.26), (0, 0.30, 0.34), "hips"),
    "upper_arm_r": ((-0.215, 0, 0.43), (-0.30, -0.03, 0.30), "spine"),
    "forearm_r": ((-0.30, -0.03, 0.30), (-0.31, -0.15, 0.40), "upper_arm_r"),
    "upper_arm_l": ((0.215, 0, 0.43), (0.285, -0.02, 0.27), "spine"),
    "forearm_l": ((0.285, -0.02, 0.27), (0.29, -0.03, 0.17), "upper_arm_l"),
    "thigh_r": ((-0.09, 0, 0.19), (-0.09, 0, 0.14), "hips"),
    "shin_r": ((-0.09, 0, 0.14), (-0.09, 0, 0.04), "thigh_r"),
    "thigh_l": ((0.09, 0, 0.19), (0.09, 0, 0.14), "hips"),
    "shin_l": ((0.09, 0, 0.14), (0.09, 0, 0.04), "thigh_l"),
    "weapon_socket": ((-0.31, -0.18, 0.41), (-0.31, -0.15, 0.47), "forearm_r"),
    "prop_socket": ((0.29, -0.03, 0.17), (0.29, -0.03, 0.23), "forearm_l"),
}

FACE = dict(region=(-0.25, 0.25, 0.5, 1.0), cell=(0, 0, 32, 32), sel=lambda n, c: n.y < -0.5)


def build_parts(b, sw, atlas, face_atlas):
    A = atlas
    # --- head and face
    head_tile = A.tile("head", {"side": (30, 34), "back": (32, 34), "top": (32, 26), "bottom": (12, 10)},
                       toy_painter("tawny", "tawny_shade", hi="tawny_light"))
    b.add("head", "head", pts_chamfer(0.50, 0.44, 0.50, 0.11), T(0, 0, 0.75), head_tile, face=FACE)
    muzzle_tile = A.tile("muzzle", {"side": (10, 10), "top": (10, 6), "bottom": (4, 4)},
                         toy_painter("cream", "cream_shade", band=0.35))
    b.add("muzzle", "head", pts_chamfer(0.22, 0.12, 0.15, 0.03), T(0, -0.275, 0.625), muzzle_tile,
          face=dict(FACE))
    # goggles pushed up on top of the head: a brass bridge and two glowing lenses tilted up and forward
    band_tile = A.tile("goggle_band", {"front": (24, 7), "side": (6, 7), "top": (24, 6)}, goggle_painter)
    b.add("goggle_bridge", "head", pts_box(0.36, 0.06, 0.05), T(0.045, -0.085, 0.995), band_tile)
    lens_tile = A.tile("lens", {"top": (4, 4), "side": (12, 6), "bottom": (4, 4)}, lens_painter)
    for i, lx in enumerate((-0.03, 0.12)):
        b.limb("lens_%d" % i, "head", (lx, -0.07, 0.985), (lx, -0.125, 1.07), 0.075, 0.075, n=6, tile=lens_tile)
    # ears: up-ear (right), floppy ear (left) with a fold block
    up_tile = A.tile("ear_up", {"front": (14, 28), "back": (14, 28), "side": (6, 28)}, ear_up_painter)
    b.add("ear_up", "ear_r", pts_slab([(-0.075, 0), (0.075, 0), (0.07, 0.2), (0.0, 0.34), (-0.07, 0.2)], 0.10),
          T(-0.17, 0, 0.9, ry=-4), up_tile)
    fl_tile = A.tile("ear_flop", {"front": (14, 30), "back": (14, 30), "side": (6, 30)}, ear_flop_painter)
    b.add("ear_fold", "ear_l", pts_box(0.15, 0.10, 0.11), T(0.235, 0, 0.955, ry=-38), fl_tile)
    b.add("ear_flap", "ear_l", pts_slab([(-0.075, 0), (0.075, 0), (0.08, -0.2), (0.045, -0.4), (-0.045, -0.4),
                                         (-0.08, -0.2)], 0.10), T(0.285, 0, 0.935, ry=-9), fl_tile)
    # --- torso: jacket (wide trapezoid flaring at the hem), hem rib, collar
    jt = A.tile("jacket", {"front": (40, 28), "back": (40, 28), "side": (28, 28)}, jacket_painter)
    jacket_pts = [Vector((sx * 0.215, sy * 0.185, 0.18)) for sx in (-1, 1) for sy in (-1, 1)] + \
                 [Vector((sx * 0.155, sy * 0.14, 0.50)) for sx in (-1, 1) for sy in (-1, 1)]
    b.add("jacket", "spine", jacket_pts, None, jt)
    hem_pts = [Vector((sx * 0.235, sy * 0.2, 0.17)) for sx in (-1, 1) for sy in (-1, 1)] + \
              [Vector((sx * 0.225, sy * 0.195, 0.23)) for sx in (-1, 1) for sy in (-1, 1)]
    hem_tile = A.tile("hem", {"front": (24, 5), "back": (24, 5), "side": (20, 5)}, cuff_painter)
    b.add("hem", "spine", hem_pts, None, hem_tile)
    collar_tile = A.tile("collar", {"front": (12, 5), "side": (12, 5), "top": (4, 4)},
                         toy_painter("jacket_light", "jacket", band=0.4))
    b.add("collar", "spine", pts_box(0.34, 0.28, 0.07), T(0, 0, 0.50), collar_tile)
    # tail
    tail_tile = A.tile("tail", {"side": (8, 8), "top": (6, 6), "bottom": (2, 2)}, toy_painter("tawny", "tawny_shade"))
    b.limb("tail", "tail", (0, 0.16, 0.25), (0, 0.30, 0.35), 0.06, 0.05, n=6, front=(0, 0, 1), tile=tail_tile)
    # --- arms
    sleeve_tile = A.tile("sleeve", {"front": (12, 12), "side": (12, 12), "top": (4, 4)},
                         toy_painter("jacket", "jacket_shade", seam="jacket_shade"))
    mitten_tile = A.tile("mitten", {"front": (12, 12), "side": (12, 12), "top": (10, 8), "bottom": (4, 4)},
                         toy_painter("tawny", "tawny_shade"))
    thumb_tile = A.tile("thumb", {"side": (4, 4)}, thumb_painter)
    cuff_tile = A.tile("cuff", {"side": (24, 7), "top": (8, 8), "bottom": (4, 4)}, cuff_painter)
    # left arm (hangs at her side, +X)
    b.limb("sleeve_l", "upper_arm_l", (0.215, 0, 0.43), (0.285, -0.02, 0.28), 0.085, 0.075, n=6, tile=sleeve_tile)
    b.limb("cuff_l", "forearm_l", (0.285, -0.02, 0.285), (0.288, -0.025, 0.215), 0.105, 0.105, n=8, tile=cuff_tile)
    b.limb("mitten_l", "forearm_l", (0.29, -0.03, 0.235), (0.29, -0.03, 0.11), 0.075, 0.065, n=6, tile=mitten_tile)
    b.add("thumb_l", "forearm_l", pts_box(0.05, 0.05, 0.07), T(0.285, -0.085, 0.15), thumb_tile)
    # right arm (holds the sword, -X): sleeve to the elbow, forearm up and forward, big mitten at the grip
    b.limb("sleeve_r", "upper_arm_r", (-0.215, 0, 0.43), (-0.30, -0.03, 0.31), 0.085, 0.075, n=6, tile=sleeve_tile)
    b.limb("forearm_r", "forearm_r", (-0.30, -0.03, 0.31), (-0.31, -0.10, 0.37), 0.075, 0.075, n=6, tile=sleeve_tile)
    b.limb("cuff_r", "forearm_r", (-0.307, -0.085, 0.357), (-0.311, -0.135, 0.40), 0.105, 0.105, n=8, tile=cuff_tile)
    b.limb("mitten_r", "forearm_r", (-0.31, -0.12, 0.385), (-0.31, -0.215, 0.44), 0.075, 0.065, n=6, tile=mitten_tile)
    b.add("thumb_r", "forearm_r", pts_box(0.05, 0.05, 0.06), T(-0.255, -0.18, 0.44), thumb_tile)
    # --- legs and boots
    leg_tile = A.tile("leg", {"front": (6, 6), "side": (6, 6)}, toy_painter("tawny", "tawny_shade"))
    boot_tile = A.tile("boot", {"front": (20, 12), "side": (26, 12), "top": (16, 14), "bottom": (6, 6)}, boot_painter)
    for tag, bone_t, bone_s, x in (("r", "thigh_r", "shin_r", -0.09), ("l", "thigh_l", "shin_l", 0.09)):
        b.limb("leg_" + tag, bone_t, (x, 0, 0.09), (x, 0, 0.19), 0.06, 0.06, n=6, tile=leg_tile)
        b.add("boot_" + tag, bone_s, pts_frustum((0.085, 0.115), (0.07, 0.10), 0.105, n=8, phase=math.pi / 8),
              T(x, -0.025, 0.0525), boot_tile)
    # --- brass lamp at the left hip (front), satchel on the right back hip
    lamp_tile = A.tile("lamp", {"front": (10, 12), "back": (8, 8), "side": (10, 12), "top": (8, 8),
                                "bottom": (4, 4)}, lamp_painter)
    b.add("lamp", "hips", pts_chamfer(0.125, 0.11, 0.15, 0.022), T(0.13, -0.235, 0.29), lamp_tile)
    b.add("lamp_ring", "hips", pts_box(0.05, 0.05, 0.04), T(0.13, -0.235, 0.385), lamp_tile)
    st = A.tile("satchel", {"front": (18, 12), "back": (18, 12), "side": (10, 12), "top": (10, 6)}, satchel_painter)
    b.add("satchel", "hips", pts_box(0.21, 0.10, 0.16), T(-0.15, 0.245, 0.27), st)
    sf = A.tile("satchel_flap", {"front": (18, 5), "back": (18, 5), "side": (10, 5), "top": (4, 4)}, flap_painter)
    b.add("satchel_flap", "hips", pts_box(0.22, 0.11, 0.05), T(-0.15, 0.245, 0.35), sf)
    # --- sword (separate prop), over the right shoulder, flat faces toward the sides
    hand = Vector((-0.31, -0.19, 0.41))
    d = Vector((-0.06, 0.55, 0.83)).normalized()
    front = (1, 0, 0)
    at = lambda s: hand + d * s  # noqa: E731
    sw_grip = A.tile("sw_grip", {"front": (6, 10), "side": (6, 10), "top": (6, 6)},
                     toy_painter("rust", "rust_shade", band=0.3))
    sw_brass = A.tile("sw_brass", {"front": (10, 5), "side": (6, 5), "top": (10, 6)}, goggle_painter)
    sw_blade = A.tile("sw_blade", {"front": (10, 32), "side": (4, 32), "top": (4, 4)}, blade_painter)
    sw.limb("sword_pommel", "weapon_socket", at(-0.1), at(-0.05), 0.04, 0.04, n=6, front=front, tile=sw_brass)
    sw.limb("sword_grip", "weapon_socket", at(-0.05), at(0.07), 0.03, 0.03, n=6, front=front, tile=sw_grip)
    sw.add("sword_guard", "weapon_socket", pts_box(0.05, 0.19, 0.035), aim(at(0.07), at(0.105), front),
           sw_brass)
    blade = pts_slab([(-0.058, 0), (0.058, 0), (0.058, 0.50), (0.0, 0.62), (-0.058, 0.50)], 0.055)
    sw.add("sword_blade", "weapon_socket", blade,
           aim(at(0.105), at(0.725), (1, 0.9, 0)) @ Matrix.Translation((0, 0, -0.31)), sw_blade)


if __name__ == "__main__":
    build_prototype("a", "Wind-Up Toy", BONES, build_parts, paint_face, (128, 128))
