"""Red style prototype C: PICTURE-BOOK (docs/red_style_prototypes.md).

Red as a character stepped out of a hand-painted storybook: the current style guide's proportions
(about 2.5 heads tall, head about 40% of her height), soft organic shapes (a rounded head with a
pointed muzzle, teardrop jacket with the hem swinging off one side, tapered limbs with joint caps,
boots with an upturn), smooth shading. The 128x128 body sheet is fully hand-painted: drawn-in line work
in dark warm colors (Ink thinned toward rust, never black), painted folds, painted light from above in
only one or two hand-dithered steps. The 128x64 face sheet is the most detailed of the set: lid lines,
shines, brows, cheek blush, a nose highlight and a grin with teeth.

    /tmp/proto_venv/bin/python game/scripts/tools/prototypes/red_proto_c.py
Writes game/art/placeholder/characters/red_prototypes/red_proto_c.glb (+ red_proto_c_body.png, red_proto_c_face.png).
Placeholder only: Ross makes the real Red.
"""

import math
import os
import random
import sys
import zlib

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from proto_abc_lib import *  # noqa: E402,F401,F403

LINE = warm_line(0.45)          # drawn-in line color: Ink thinned toward rust
LINE_SOFT = warm_line(0.75)


def painted(base, shade, hi=None, line=LINE, band=0.34, speckle=0.04, edges="lr"):
    """A hand-painted cell: base color, one painted light step at the top, one shade step at the bottom
    (hand-dithered between), speckled brush texture, and a drawn line along the cell edges."""
    def paint(img, draw, cell, rect):
        x, y, w, h = rect
        rng = random.Random(zlib.crc32(("%s%d%d" % (cell, x, y)).encode()))
        if cell == "bottom":
            fill(draw, rect, shade)
            dither_fill(draw, (x, y, w, 1), shade, base)
        else:
            fill(draw, rect, base)
            if cell != "top":
                by = y + int(h * (1 - band))
                fill(draw, (x, by, w, y + h - by), shade)
                dither_fill(draw, (x, by - 2, w, 1), base, shade)
                dither_fill(draw, (x, by - 1, w, 1), shade, base, 1)
            if hi:
                dither_fill(draw, (x + 1, y + 1, max(w - 2, 1), 1), hi, base)
                if w > 8 and h > 8:
                    fill(draw, (x + 2, y + 2, max(w // 3, 1), 1), hi)
        for j in range(h):
            for i in range(w):
                if rng.random() < speckle:
                    other = shade if rng.random() < 0.55 else (hi or base)
                    draw.point((x + i, y + j), fill=mix(base, other, 0.5))
        if edges and cell not in ("top", "bottom"):
            border(draw, rect, line, edges)
    return paint


def stitch(draw, x0, y0, x1, y1, color="rust"):
    """A dashed stitch line."""
    n = max(abs(x1 - x0), abs(y1 - y0))
    for i in range(0, n + 1, 2):
        t = i / max(n, 1)
        draw.point((int(x0 + (x1 - x0) * t), int(y0 + (y1 - y0) * t)), fill=rgb(color))


def patch(draw, x, y, w, h, color):
    fill(draw, (x, y, w, h), color)
    draw.rectangle([x, y, x + w - 1, y + h - 1], outline=rgb(LINE_SOFT))
    stitch(draw, x + 1, y + 1, x + w - 2, y + 1, "tan")
    stitch(draw, x + 1, y + h - 2, x + w - 2, y + h - 2, "tan")


def jacket_paint(img, draw, cell, rect):
    x, y, w, h = rect
    base, shade, hi = "jacket", "jacket_shade", "jacket_light"
    painted(base, shade, hi, edges="lr", band=0.3)(img, draw, cell, rect)
    if cell == "top" or cell == "bottom":
        return
    # painted folds: long strokes, dark under a lighter edge
    for i, fx in enumerate((0.18, 0.5, 0.8)):
        px = x + int(w * fx)
        draw.line([(px, y + 4), (px + (2 if i % 2 else -2), y + int(h * 0.72))], fill=rgb(shade))
        draw.line([(px + 1, y + 5), (px + 1 + (2 if i % 2 else -2), y + int(h * 0.66))], fill=rgb(hi))
    if cell == "front":
        draw.line([(x + w // 2, y + 2), (x + w // 2, y + h - 3)], fill=rgb(LINE))           # zip
        for k in range(3, h - 4, 4):
            draw.point((x + w // 2 - 1, y + k), fill=rgb("brass"))
        patch(draw, x + w - 12, y + 6, 8, 8, "mustard")
        patch(draw, x + 4, y + 9, 7, 6, "green")
        draw.rectangle([x + 4, y + h - 11, x + 12, y + h - 5], outline=rgb(LINE))           # pocket
        draw.rectangle([x + w - 13, y + h - 11, x + w - 5, y + h - 5], outline=rgb(LINE))
        for i in range(0, h - 6):                           # satchel strap, top right to hip left
            sx = x + w - 6 - int(i * (w - 14) / (h - 6))
            draw.line([(sx - 1, y + 3 + i), (sx + 2, y + 3 + i)], fill=rgb("tan"))
            draw.point((sx - 2, y + 3 + i), fill=rgb("rust"))
            draw.point((sx + 3, y + 3 + i), fill=rgb("rust"))
    elif cell == "back":
        # the hand-painted lamp with a dithered glow halo
        cx, cy = x + int(w * 0.40), y + 15
        for r, c in ((11, "jacket_light"), (9, "amber")):
            for j in range(-r, r + 1):
                for i in range(-r, r + 1):
                    if i * i + j * j <= r * r and (i + j) % 2 == 0:
                        draw.point((cx + i, cy + j), fill=rgb(mix("jacket", c, 0.5)))
        draw.rectangle([cx - 6, cy - 7, cx + 6, cy + 9], fill=rgb(LINE))
        draw.rectangle([cx - 5, cy - 4, cx + 5, cy + 8], fill=rgb("brass"))
        draw.rectangle([cx - 3, cy - 2, cx + 3, cy + 6], fill=rgb("glow"))
        draw.rectangle([cx - 1, cy, cx + 1, cy + 4], fill=rgb("chalk"))
        draw.rectangle([cx - 5, cy - 7, cx + 5, cy - 5], fill=rgb("brass_shade"))
        draw.arc([cx - 3, cy - 13, cx + 3, cy - 6], 180, 360, fill=rgb(LINE))
        patch(draw, x + 3, y + h - 12, 9, 8, "terracotta")
        patch(draw, x + w - 12, y + 5, 8, 9, "mustard")
        stitch(draw, x + w // 2, y + h - 4, x + w - 4, y + h - 4, "jacket_shade")
    elif cell == "side":
        draw.line([(x + 3, y + h - 12), (x + w - 4, y + h - 9)], fill=rgb(LINE_SOFT))


def cuff_paint(img, draw, cell, rect):
    x, y, w, h = rect
    if cell in ("top", "bottom"):
        fill(draw, rect, "tan")
        dither_fill(draw, rect, "tan", "tan_shade")
        return
    painted("jacket_light", "jacket", None, edges="tb", band=0.4)(img, draw, cell, rect)
    for k in range(x + 2, x + w - 1, 4):
        draw.point((k, y + h // 2), fill=rgb("jacket_shade"))


def boot_paint(img, draw, cell, rect):
    x, y, w, h = rect
    painted("rust", "rust_shade", "tan", band=0.3, edges="lr")(img, draw, cell, rect)
    if cell == "front":
        fill(draw, (x + 2, y + h - 7, w - 4, 4), "tan")
        draw.rectangle([x + 2, y + h - 7, x + w - 3, y + h - 4], outline=rgb(LINE))
        for i in range(2):
            draw.line([(x + 3, y + 2 + i * 3), (x + w - 4, y + 2 + i * 3)], fill=rgb(LINE_SOFT))
    elif cell == "side":
        fill(draw, (x, y + h - 3, w, 3), "rust_shade")
    elif cell == "top":
        for i in range(0, w - 3, 3):
            draw.line([(x + 2 + i, y + 2), (x + 2 + i, y + h - 3)], fill=rgb("tan"))


def ear_paint(inner):
    def paint(img, draw, cell, rect):
        x, y, w, h = rect
        painted("tawny", "tawny_shade", "tawny_light", edges="lr", band=0.3)(img, draw, cell, rect)
        if cell == "front":
            draw.ellipse([x + 3, y + 3, x + w - 4, y + h - 4], fill=rgb(inner))
            draw.ellipse([x + 4, y + 4, x + w - 5, y + h // 2], fill=rgb(mix(inner, "tawny_light", 0.4)))
            draw.arc([x + 1, y + 1, x + w - 2, y + h - 2], 0, 360, fill=rgb(LINE_SOFT))
    return paint


def lamp_paint(img, draw, cell, rect):
    x, y, w, h = rect
    painted("brass", "brass_shade", "glow", edges="lr", band=0.3, speckle=0.04)(img, draw, cell, rect)
    if cell in ("front", "back"):
        draw.rectangle([x + 2, y + 3, x + w - 3, y + h - 4], fill=rgb(LINE))
        fill(draw, (x + 3, y + 4, w - 6, h - 8), "glow")
        draw.point((x + 3, y + 4), fill=rgb("chalk"))
        dither_fill(draw, (x + 3, y + h - 6, w - 6, 2), "glow", "amber")


def satchel_paint(img, draw, cell, rect):
    x, y, w, h = rect
    painted("tan", "tan_shade", "cream", edges="lr", band=0.3)(img, draw, cell, rect)
    if cell in ("front", "back"):
        draw.line([(x + 1, y + h // 3), (x + w - 2, y + h // 3)], fill=rgb(LINE_SOFT))
        fill(draw, (x + w // 2 - 1, y + h // 3, 3, 3), "brass")
        stitch(draw, x + 2, y + h - 3, x + w - 3, y + h - 3, "rust")


def lens_paint(img, draw, cell, rect):
    x, y, w, h = rect
    if cell == "top":
        fill(draw, rect, "glow")
        draw.rectangle([x, y, x + w - 1, y + h - 1], outline=rgb("brass"))
        draw.point((x + 1, y + 1), fill=rgb("chalk"))
    else:
        painted("brass", "brass_shade", "glow", edges=None, band=0.4, speckle=0.0)(img, draw, cell, rect)


def blade_paint(img, draw, cell, rect):
    x, y, w, h = rect
    fill(draw, rect, "chalk")
    if cell in ("front", "back"):
        fill(draw, (x + w - 4, y, 4, h), "dusk")
        draw.line([(x + w // 2 - 1, y + 2), (x + w // 2 - 1, y + h - 6)], fill=rgb("cream_shade"))
        draw.line([(x, y), (x, y + h - 1)], fill=rgb(LINE))
        draw.line([(x + w - 1, y), (x + w - 1, y + h - 1)], fill=rgb(LINE))
    else:
        fill(draw, rect, "dusk")


# ---------------------------------------------------------------- face sheet


def paint_face(img, draw):
    ink, chalk = "ink", "chalk"
    for ox, grin in ((0, False), (32, True)):
        r = (ox, 0, 32, 32)
        fill(draw, r, "tawny")
        fill(draw, (ox, 0, 32, 5), "tawny_shade")                      # forehead shade (painted light from above)
        dither_fill(draw, (ox, 5, 32, 2), "tawny", "tawny_shade")
        rng = random.Random(7 + ox)
        for _ in range(60):                                             # brush speckle
            draw.point((ox + rng.randrange(32), rng.randrange(32)), fill=rgb(mix("tawny", "tawny_light", 0.6)))
        # cream muzzle: soft oval, a dithered edge, a lighter underside
        draw.ellipse([ox + 9, 16, ox + 23, 29], fill=rgb("cream"))
        draw.arc([ox + 9, 16, ox + 23, 29], 0, 360, fill=rgb(mix("cream", "tawny", 0.55)))
        dither_fill(draw, (ox + 11, 26, 10, 2), "cream", "cream_shade")
        # nose: ink with a chalk highlight
        draw.ellipse([ox + 14, 19, ox + 18, 22], fill=rgb(ink))
        draw.point((ox + 15, 19), fill=rgb(chalk))
        # eyes
        for sign, ex in ((-1, ox + 9), (1, ox + 22)):
            ey = 14
            if not grin:
                draw.ellipse([ex - 3, ey - 5, ex + 3, ey + 4], fill=rgb(ink))
                fill(draw, (ex - 2, ey - 4, 2, 3), chalk)                       # big shine
                draw.point((ex + 1, ey + 2), fill=rgb(chalk))                   # small shine
                draw.arc([ex - 5, ey - 8, ex + 5, ey - 1], 195, 345, fill=rgb(LINE))   # lid line
            else:
                draw.arc([ex - 4, ey - 4, ex + 4, ey + 4], 200, 340, fill=rgb(LINE))
                draw.arc([ex - 4, ey - 3, ex + 4, ey + 5], 200, 340, fill=rgb(ink))
                draw.arc([ex - 4, ey - 2, ex + 4, ey + 6], 200, 340, fill=rgb(ink))
            # brow: warm line, tipped in toward the middle
            if not grin:
                draw.line([(ex - 4, ey - 9 + (1 if sign < 0 else 0)),
                           (ex + 4, ey - 9 + (0 if sign < 0 else 1))], fill=rgb(LINE))
            else:
                draw.arc([ex - 4, ey - 12, ex + 4, ey - 6], 200, 340, fill=rgb(LINE))
            # cheek blush
            for bx, by in ((ex + 5 * sign, 21), (ex + 6 * sign, 22)):
                for k in range(3):
                    draw.point((bx + k * sign, by), fill=rgb(mix("tawny", "blush", 0.7 if grin else 0.45)))
        # mouth
        if not grin:
            draw.line([(ox + 16, 22), (ox + 16, 23)], fill=rgb(LINE))
            draw.arc([ox + 12, 21, ox + 16, 26], 20, 160, fill=rgb(LINE))
            draw.arc([ox + 16, 21, ox + 20, 26], 20, 160, fill=rgb(LINE))
        else:
            draw.pieslice([ox + 11, 21, ox + 21, 31], 0, 180, fill=rgb(ink))
            fill(draw, (ox + 12, 25, 8, 2), chalk)                              # teeth
            fill(draw, (ox + 13, 28, 6, 2), "tongue")
            draw.point((ox + 10, 25), fill=rgb(LINE))
            draw.point((ox + 22, 25), fill=rgb(LINE))
            draw.line([(ox + 16, 22), (ox + 16, 24)], fill=rgb(LINE))


# ---------------------------------------------------------------- layout
BONES = {
    "root": ((0, 0, 0), (0, 0, 0.05), None),
    "hips": ((0, 0, 0.22), (0, 0, 0.3), "root"),
    "spine": ((0, 0, 0.3), (0, 0, 0.56), "hips"),
    "head": ((0, 0, 0.58), (0, 0, 0.95), "spine"),
    "ear_r": ((-0.12, 0, 0.95), (-0.17, 0, 1.22), "head"),
    "ear_l": ((0.17, 0, 0.95), (0.3, 0, 0.58), "head"),
    "tail": ((0, 0.15, 0.24), (0, 0.27, 0.34), "hips"),
    "upper_arm_r": ((-0.15, 0, 0.51), (-0.24, -0.03, 0.40), "spine"),
    "forearm_r": ((-0.24, -0.03, 0.40), (-0.20, -0.15, 0.47), "upper_arm_r"),
    "upper_arm_l": ((0.15, 0, 0.51), (0.22, -0.01, 0.40), "spine"),
    "forearm_l": ((0.22, -0.01, 0.40), (0.24, -0.04, 0.30), "upper_arm_l"),
    "thigh_r": ((-0.07, 0, 0.27), (-0.07, 0, 0.16), "hips"),
    "shin_r": ((-0.07, 0, 0.16), (-0.07, -0.01, 0.06), "thigh_r"),
    "thigh_l": ((0.07, 0, 0.27), (0.07, 0, 0.16), "hips"),
    "shin_l": ((0.07, 0, 0.16), (0.07, -0.01, 0.06), "thigh_l"),
    "weapon_socket": ((-0.20, -0.16, 0.47), (-0.21, -0.14, 0.53), "forearm_r"),
    "prop_socket": ((0.245, -0.05, 0.255), (0.245, -0.05, 0.31), "forearm_l"),
}

FACE = dict(region=(-0.2, 0.2, 0.6, 1.0), cell=(0, 0, 32, 32), sel=lambda n, c: n.y < -0.45)


def build_parts(b, sw, atlas, face_atlas):
    A = atlas
    # --- head, muzzle
    head_tile = A.tile("head", {"side": (26, 22), "back": (26, 22), "top": (26, 20), "bottom": (10, 8),
                                "front": (10, 10)}, painted("tawny", "tawny_shade", "tawny_light", band=0.3, edges=None))
    b.add("head", "head", pts_ellipsoid(0.22, 0.20, 0.20, 10, 7, phase=math.pi / 10), T(0, 0, 0.8), head_tile,
          smooth=True, face=FACE)
    mz_tile = A.tile("muzzle", {"side": (10, 8), "top": (10, 6), "bottom": (10, 6)},
                     painted("cream", "cream_shade", None, band=0.4, edges=None))
    b.limb("muzzle", "head", (0, -0.14, 0.74), (0, -0.30, 0.735), 0.09, 0.045, n=6, tile=mz_tile, smooth=True,
           face=dict(FACE))
    # --- ears: tall curved up-ear (right), long droopy flop-ear (left)
    eu = A.tile("ear_up", {"front": (14, 24), "back": (14, 24), "side": (6, 24)}, ear_paint("tawny_shade"))
    b.add("ear_up_a", "ear_r", pts_taper_slab(0.12, 0.11, 0.15, 0.09), aim((-0.12, 0, 0.93), (-0.13, 0, 1.08)), eu)
    b.add("ear_up_b", "ear_r", pts_taper_slab(0.11, 0.08, 0.15, 0.08, tip=0.08), aim((-0.13, 0, 1.08), (-0.175, 0, 1.23)), eu)
    ef = A.tile("ear_flop", {"front": (14, 30), "back": (14, 30), "side": (6, 30)}, ear_paint("tawny_deep"))
    b.add("ear_flop_a", "ear_l", pts_taper_slab(0.12, 0.13, 0.12, 0.085), aim((0.15, 0, 0.955), (0.255, 0, 0.9)), ef)
    b.add("ear_flop_b", "ear_l", pts_taper_slab(0.13, 0.11, 0.30, 0.08, tip=0.0), aim((0.255, 0, 0.9), (0.305, 0, 0.6)), ef)
    # --- goggles pushed up between the ears
    gb = A.tile("goggle_bridge", {"front": (14, 4), "side": (4, 4), "top": (14, 4)},
                painted("brass", "brass_shade", "glow", band=0.4, edges=None))
    b.add("goggle_bridge", "head", pts_box(0.2, 0.04, 0.04), T(0.045, -0.075, 0.985), gb)
    lens = A.tile("lens", {"top": (6, 6), "side": (12, 4), "bottom": (2, 2)}, lens_paint)
    for i, lx in enumerate((-0.015, 0.105)):
        b.limb("lens_%d" % i, "head", (lx, -0.05, 0.975), (lx, -0.12, 1.025), 0.058, 0.058, n=6, tile=lens)
    # --- jacket: teardrop, collar, hem swinging off the left side
    jt = A.tile("jacket", {"front": (36, 30), "back": (36, 30), "side": (24, 28), "top": (4, 4), "bottom": (4, 4)}, jacket_paint)
    jpts = ring(0.22, 0.19, 0.20, 8, math.pi / 8) + ring(0.19, 0.165, 0.36, 8, math.pi / 8) + ring(0.125, 0.11, 0.56, 8, math.pi / 8)
    b.add("jacket", "spine", jpts, None, jt, smooth=True, ybias=1.6)
    skirt = [Vector(p) for p in ((0.15, -0.12, 0.33), (0.15, 0.12, 0.33), (0.2, -0.1, 0.33), (0.2, 0.1, 0.33),
                                 (0.30, -0.12, 0.17), (0.30, 0.12, 0.17), (0.21, -0.17, 0.19), (0.21, 0.15, 0.19))]
    b.add("jacket_swing", "spine", skirt, None, jt, smooth=True, ybias=1.6)
    ct = A.tile("collar", {"front": (14, 5), "side": (12, 5), "top": (4, 4)}, cuff_paint)
    b.add("collar", "spine", pts_frustum((0.135, 0.12), (0.12, 0.105), 0.07, 8, phase=math.pi / 8), T(0, 0, 0.575), ct, smooth=True)
    # --- tail
    tt = A.tile("tail", {"side": (6, 10), "top": (4, 4), "bottom": (4, 4)}, painted("tawny", "tawny_shade", None, band=0.3, edges=None))
    b.limb("tail", "tail", (0, 0.15, 0.24), (0, 0.27, 0.35), 0.06, 0.045, n=6, front=(0, 0, 1), tile=tt, smooth=True)
    # --- arms: tapered, elbow caps, rolled cuffs, mittens with a thumb bump
    arm = A.tile("arm", {"front": (12, 14), "side": (12, 14), "top": (4, 4)}, painted("jacket", "jacket_shade", "jacket_light", band=0.3, edges="lr"))
    cuff = A.tile("cuff", {"side": (24, 6), "top": (6, 6), "bottom": (6, 6)}, cuff_paint)
    mit = A.tile("mitten", {"front": (10, 10), "side": (10, 10), "top": (6, 6), "bottom": (4, 4)},
                 painted("tawny", "tawny_shade", "tawny_light", band=0.3, edges=None))
    cap = A.tile("joint", {"side": (4, 4), "top": (4, 4)}, painted("jacket", "jacket_shade", None, band=0.3, edges=None, speckle=0.0))
    # left (+X), hanging
    b.limb("upper_l", "upper_arm_l", (0.15, 0, 0.51), (0.22, -0.01, 0.40), 0.07, 0.062, n=6, tile=arm, smooth=True)
    b.add("elbow_l", "upper_arm_l", pts_ellipsoid(0.06, 0.06, 0.06, 5, 2), T(0.22, -0.01, 0.40), cap, smooth=True)
    b.limb("fore_l", "forearm_l", (0.22, -0.01, 0.40), (0.24, -0.04, 0.31), 0.062, 0.058, n=6, tile=arm, smooth=True)
    b.limb("cuff_l", "forearm_l", (0.24, -0.04, 0.318), (0.245, -0.045, 0.265), 0.088, 0.084, n=6, tile=cuff, smooth=True)
    b.add("mitten_l", "forearm_l", pts_ellipsoid(0.055, 0.05, 0.06, 6, 3), T(0.245, -0.05, 0.235), mit, smooth=True)
    b.add("thumb_l", "forearm_l", pts_ellipsoid(0.028, 0.028, 0.035, 5, 2), T(0.222, -0.088, 0.245), mit, smooth=True)
    # right (-X), holding the sword
    b.limb("upper_r", "upper_arm_r", (-0.15, 0, 0.51), (-0.24, -0.03, 0.40), 0.07, 0.062, n=6, tile=arm, smooth=True)
    b.add("elbow_r", "upper_arm_r", pts_ellipsoid(0.06, 0.06, 0.06, 5, 2), T(-0.24, -0.03, 0.40), cap, smooth=True)
    b.limb("fore_r", "forearm_r", (-0.24, -0.03, 0.40), (-0.205, -0.135, 0.455), 0.062, 0.058, n=6, tile=arm, smooth=True)
    b.limb("cuff_r", "forearm_r", (-0.207, -0.13, 0.452), (-0.195, -0.17, 0.478), 0.088, 0.084, n=6, tile=cuff, smooth=True)
    b.add("mitten_r", "forearm_r", pts_ellipsoid(0.055, 0.05, 0.06, 6, 3), T(-0.192, -0.19, 0.488), mit, smooth=True)
    b.add("thumb_r", "forearm_r", pts_ellipsoid(0.028, 0.028, 0.035, 5, 2), T(-0.165, -0.205, 0.5), mit, smooth=True)
    # --- legs and boots (upturned toes)
    leg = A.tile("leg", {"front": (8, 10), "side": (8, 10), "top": (2, 2)}, painted("tawny", "tawny_shade", None, band=0.3, edges="lr"))
    boot = A.tile("boot", {"front": (18, 12), "side": (24, 12), "top": (14, 12), "bottom": (6, 6)}, boot_paint)
    for tag, bone, x in (("r", "shin_r", -0.07), ("l", "shin_l", 0.07)):
        b.limb("leg_" + tag, bone, (x, 0, 0.215), (x, -0.005, 0.075), 0.056, 0.05, n=6, tile=leg, smooth=True)
        bp = ring(0.075, 0.11, 0.0, 8, math.pi / 8, cy=-0.01) + ring(0.063, 0.085, 0.078, 8, math.pi / 8, cy=0.0) + [Vector((0, -0.155, 0.07))]
        b.add("boot_" + tag, bone, bp, T(x, 0, 0), boot, smooth=True)
    # --- lamp at the left hip, satchel on the back
    lt = A.tile("lamp", {"front": (12, 14), "back": (12, 14), "side": (12, 14), "top": (8, 6), "bottom": (6, 6)}, lamp_paint)
    b.add("lamp", "hips", pts_frustum((0.058, 0.058), (0.05, 0.05), 0.105, 8, phase=math.pi / 8), T(0.14, -0.165, 0.27), lt, smooth=True)
    b.add("lamp_cap", "hips", pts_ellipsoid(0.052, 0.052, 0.04, 8, 2, phase=math.pi / 8), T(0.14, -0.165, 0.335), lt, smooth=True)
    b.add("lamp_ring", "hips", pts_box(0.05, 0.03, 0.03), T(0.14, -0.165, 0.375), lt)
    st = A.tile("satchel", {"front": (16, 12), "back": (16, 12), "side": (8, 12), "top": (16, 8)}, satchel_paint)
    b.add("satchel", "hips", pts_box(0.15, 0.08, 0.12), T(-0.125, 0.175, 0.28, rz=-6), st)
    sf = A.tile("satchel_flap", {"front": (16, 5), "side": (8, 5), "top": (16, 8)}, painted("rust", "rust_shade", None, band=0.4, edges="tb"))
    b.add("satchel_flap", "hips", pts_box(0.16, 0.09, 0.04), T(-0.125, 0.175, 0.345, rz=-6), sf)
    # --- sword over the right shoulder
    hand = Vector((-0.195, -0.185, 0.488))
    d = Vector((-0.2, 0.5, 0.85)).normalized()
    at = lambda s: hand + d * s  # noqa: E731
    front = (1, 0, 0)
    sg = A.tile("sw_grip", {"front": (6, 10), "side": (6, 10), "top": (4, 4)}, painted("rust", "rust_shade", None, band=0.3, edges=None))
    sb = A.tile("sw_brass", {"front": (10, 5), "side": (6, 5), "top": (10, 6)}, painted("brass", "brass_shade", "glow", band=0.4, edges=None))
    sbl = A.tile("sw_blade", {"front": (10, 30), "side": (4, 30), "top": (4, 4)}, blade_paint)
    sw.limb("sword_pommel", "weapon_socket", at(-0.1), at(-0.05), 0.04, 0.04, n=6, front=front, tile=sb)
    sw.limb("sword_grip", "weapon_socket", at(-0.05), at(0.07), 0.03, 0.03, n=6, front=front, tile=sg)
    sw.add("sword_guard", "weapon_socket", pts_box(0.05, 0.19, 0.035), aim(at(0.07), at(0.105), front), sb)
    blade = pts_slab([(-0.057, 0), (0.057, 0), (0.057, 0.52), (0.0, 0.64), (-0.057, 0.52)], 0.05)
    sw.add("sword_blade", "weapon_socket", blade, aim(at(0.105), at(0.745), (1, 0.9, 0)) @ Matrix.Translation((0, 0, -0.32)), sbl)


if __name__ == "__main__":
    build_prototype("c", "Picture-Book", BONES, build_parts, paint_face, (128, 128))
