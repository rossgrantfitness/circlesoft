"""Red style prototype E, "Rubber Bounce": springy mascot Red with giant mitts and giant boots
(docs/red_style_prototypes.md, section E). Static, neutral pose with a forward lean, no animation.

About 2.8 heads tall (head about 36% of her height). The exaggeration lives in the hands and feet:
mitts nearly as big as the head, huge round boots, thin springy limbs (diameter 0.10 or more).

  - body mesh, TWO material slots (plain names: the importer gives them the standard psx_lit):
        mat_red_proto_e_body   128x128 painted sheet: one 16x16 cell per part (top lit, bottom one
                               shade step, Chalk gloss spots on boots / lamp / mitts), plus the
                               painted back of the jacket
        mat_red_proto_e_face   128x64 face sheet: two 64x64 expressions, neutral (left) and grin
                               (right). Swap them by moving uv_offset.x by 0.5 on that material.
                               Used by the front-facing triangles of the head and muzzle.
  - a separate sword mesh, skinned to weapon_socket
  - the shared 17-bone skeleton, every vertex on exactly one bone

Run (see red_proto_de_kit.py):  /tmp/blockout_venv/bin/python game/scripts/tools/prototypes/red_proto_e.py
Output: game/art/placeholder/characters/red_prototypes/red_proto_e.glb
        red_proto_e_body.png, red_proto_e_face.png (source copies; the .glb embeds them)
"""

import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from red_proto_de_kit import *  # noqa: E402,F403  (bpy first, inside the kit)
from PIL import Image, ImageDraw  # noqa: E402

NAME = "red_proto_e"
MAT_BODY = "mat_red_proto_e_body"
MAT_FACE = "mat_red_proto_e_face"
SLOT_BODY, SLOT_FACE = 0, 1
BODY_PATH = os.path.join(OUT_DIR, NAME + "_body.png")
FACE_PATH = os.path.join(OUT_DIR, NAME + "_face.png")
BODY_PX = 128
CELL = 16
FACE_W, FACE_H = 128, 64
FACE_CELL = 64

# ---- palette (brightest version of the style guide palette) with one shade step each ----
COL = {
    "tawny": ("#D79448", "#A9693A"),
    "cream": ("#F7E8C6", "#D8BF98"),
    "jacket": ("#D6382E", "#8E2536"),
    "tan": ("#D5B07C", "#A48560"),
    "brass": ("#E3AC45", "#A9742E"),
    "glow": ("#FFE08A", "#FFB347"),
    "rust": ("#A9502F", "#6F3330"),
    "blade": ("#EDEAD8", "#7A74B0"),
    "ink": ("#14121F", "#14121F"),
    "dusk": ("#3A3566", "#2A264D"),
}
RGB = {k: (hex_rgb(a), hex_rgb(b)) for k, (a, b) in COL.items()}
CHALK = hex_rgb("#EDEAD8")

# name -> (cell column, cell row, gloss spot)
CELLS = {
    "tawny": (0, 0, False), "tawny_gloss": (1, 0, True), "cream": (2, 0, False),
    "jacket": (3, 0, False), "tan": (4, 0, False), "brass": (5, 0, False), "brass_gloss": (6, 0, True),
    "glow": (7, 0, True), "rust_gloss": (0, 1, True), "rust": (1, 1, False), "blade": (2, 1, False),
    "dusk": (3, 1, False), "ink": (4, 1, False), "jacket_gloss": (5, 1, True),
}
CELL_COLOR = {"tawny_gloss": "tawny", "brass_gloss": "brass", "rust_gloss": "rust",
              "jacket_gloss": "jacket"}
ART_ORIGIN = (64, 32)      # 32x32 painted back of the jacket (cells 4-5, 2-3)

SHADE_FROM = 0.58          # fraction of the part's height where the shade step starts


def paint_cell(img, name):
    col, row, gloss = CELLS[name]
    lit, shade = RGB[CELL_COLOR.get(name, name)]
    px = img.load()
    x0, y0 = col * CELL, row * CELL
    for y in range(CELL):
        for x in range(CELL):
            if y < 9:
                c = lit
            elif y == 9:
                c = lit if (x + y) % 2 == 0 else shade       # one row of hand-dither on the step
            else:
                c = shade
            px[x0 + x, y0 + y] = c
    if gloss:
        d = ImageDraw.Draw(img)
        d.rectangle([x0 + 3, y0 + 2, x0 + 6, y0 + 3], fill=CHALK)
        d.rectangle([x0 + 3, y0 + 4, x0 + 4, y0 + 6], fill=CHALK)
        d.point([(x0 + 8, y0 + 2)], fill=CHALK)


def paint_body():
    img = Image.new("RGB", (BODY_PX, BODY_PX), hex_rgb(PAL["ink"]))
    for name in CELLS:
        paint_cell(img, name)
    d = ImageDraw.Draw(img)
    ox, oy = ART_ORIGIN
    lit_j, shade_j = RGB["jacket"]

    def box(x0, y0, x1, y1, color):
        d.rectangle([ox + x0, oy + y0, ox + x1, oy + y1], fill=color)

    box(0, 0, 31, 31, lit_j)
    box(0, 20, 31, 31, shade_j)                                     # one shade step across the bottom
    for x in range(0, 32, 2):                                       # dither line
        d.point([(ox + x, oy + 19)], fill=shade_j)
        d.point([(ox + x + 1, oy + 20)], fill=lit_j)
    # Harrow patches
    box(2, 3, 9, 9, hex_rgb(PAL["terracotta"])); box(2, 3, 9, 3, hex_rgb(PAL["ink"]))
    box(23, 5, 29, 12, hex_rgb(PAL["mustard"])); box(23, 5, 29, 5, hex_rgb(PAL["ink"]))
    box(3, 22, 9, 27, hex_rgb(PAL["patch_green"]))
    # Hand-painted lamp
    ink, brass, glow, chalk = (hex_rgb(PAL[k]) for k in ("ink", "brass", "glow", "chalk"))
    box(13, 4, 18, 5, ink); box(12, 5, 13, 8, ink); box(18, 5, 19, 8, ink)
    box(10, 8, 21, 10, ink); box(11, 9, 20, 10, brass)
    box(9, 11, 22, 22, ink); box(10, 11, 21, 21, glow)
    box(13, 13, 14, 17, chalk)
    box(10, 22, 21, 25, ink); box(11, 22, 20, 24, brass)
    img.save(BODY_PATH)


# ---------------------------------------------------------------- the model layout
LEAN_DEG = 9.0
HIP_PIVOT = Vector((0.0, 0.0, 0.33))
LEAN = Matrix.Translation(HIP_PIVOT) @ rot_matrix((LEAN_DEG, 0, 0)) @ Matrix.Translation(-HIP_PIVOT)
LEAN_INV = LEAN.inverted()

HEAD_C = Vector((0.0, 0.0, 0.82))
HEAD_R = (0.215, 0.19, 0.18)
MUZZLE_C = Vector((0.0, -0.18, 0.775))
MUZZLE_R = (0.10, 0.07, 0.12)          # x, height (z), depth (y) before the 90 degree turn
SHOULDER_R, SHOULDER_L = Vector((-0.20, 0.0, 0.60)), Vector((0.20, 0.0, 0.60))
ELBOW_R, HAND_R = Vector((-0.31, -0.05, 0.53)), Vector((-0.33, -0.12, 0.70))
ELBOW_L, HAND_L = Vector((0.31, -0.03, 0.50)), Vector((0.36, -0.14, 0.38))
HIP_L, HIP_R = Vector((0.085, 0.0, 0.36)), Vector((-0.085, 0.0, 0.36))
KNEE_L, KNEE_R = Vector((0.09, -0.01, 0.26)), Vector((-0.09, -0.01, 0.26))
FOOT_L, FOOT_R = Vector((0.10, -0.03, 0.15)), Vector((-0.10, -0.03, 0.15))
SWORD_DIR = Vector((-0.10, 0.34, 0.66)).normalized()


def L(v):
    """A layout point after the lean (what the mesh will really be)."""
    return LEAN @ Vector(v)


JOINTS = {
    "root": ((0, 0, 0), (0, 0, 0.05)),
    "hips": ((0, 0, 0.33), tuple(L((0, 0, 0.42)))),
    "spine": (tuple(L((0, 0, 0.42))), tuple(L((0, 0, 0.62)))),
    "head": (tuple(L((0, 0, 0.62))), tuple(L((0, 0, 0.99)))),
    "ear_r": (tuple(L((-0.13, 0, 0.98))), tuple(L((-0.15, 0, 1.2)))),
    "ear_l": (tuple(L((0.22, 0, 0.95))), tuple(L((0.28, 0, 0.66)))),
    "tail": (tuple(L((0, 0.15, 0.33))), tuple(L((0, 0.31, 0.43)))),
    "upper_arm_r": (tuple(L(SHOULDER_R)), tuple(L(ELBOW_R))),
    "forearm_r": (tuple(L(ELBOW_R)), tuple(L(HAND_R))),
    "upper_arm_l": (tuple(L(SHOULDER_L)), tuple(L(ELBOW_L))),
    "forearm_l": (tuple(L(ELBOW_L)), tuple(L(HAND_L))),
    "thigh_r": (tuple(HIP_R), tuple(KNEE_R)),
    "shin_r": (tuple(KNEE_R), tuple(FOOT_R)),
    "thigh_l": (tuple(HIP_L), tuple(KNEE_L)),
    "shin_l": (tuple(KNEE_L), tuple(FOOT_L)),
    "weapon_socket": (tuple(L(HAND_R)), tuple(L(HAND_R) + SWORD_DIR * 0.08)),
    "prop_socket": (tuple(L(HAND_L)), tuple(L(HAND_L) + Vector((0, 0, 0.08)))),
}


# ---------------------------------------------------------------- UV rules
def planar(cell_name):
    """Top-down planar mapping into a cell, using the primitive's own bounding box (world space):
    top of the part reads the lit rows, the bottom reads the shade rows."""
    col, row, _ = CELLS[cell_name]
    plain = CELLS.get(CELL_COLOR.get(cell_name, ""), None)      # the same color without the gloss spot

    def fn(co, n, bb):
        lo, hi = bb
        col, row = (plain[0], plain[1]) if (plain and local_normal(n).y > 0.3) else (CELLS[cell_name][0], CELLS[cell_name][1])
        fx = (co.x - lo.x) / max(hi.x - lo.x, 1e-6)
        fy = 1.0 - (co.z - lo.z) / max(hi.z - lo.z, 1e-6)
        return ((col * CELL + 1 + fx * (CELL - 2)) / BODY_PX, 1.0 - (row * CELL + 1 + fy * (CELL - 2)) / BODY_PX)
    return fn


def local_normal(n):
    return (LEAN_INV.to_3x3() @ n).normalized()


def torso_uv(co, n, bb):
    """Back-facing triangles get the painted jacket back; the rest the plain jacket cell."""
    if local_normal(n).y > 0.35:
        ox, oy = ART_ORIGIN
        lo, hi = bb
        loc = LEAN_INV @ co
        fx = min(max((0.15 - loc.x) / 0.30, 0.0), 1.0)          # mirrored: seen from behind
        fy = min(max((0.64 - loc.z) / 0.28, 0.0), 1.0)
        return ((ox + 0.5 + fx * 31) / BODY_PX, 1.0 - (oy + 0.5 + fy * 31) / BODY_PX)
    return planar("jacket")(co, n, bb)


FACE_X_HALF = 0.215
FACE_Z_RANGE = (HEAD_C.z - 0.18, HEAD_C.z + 0.18)


def face_front(n, limit=-0.30):
    return local_normal(n).y < limit


def head_slot(n):
    return SLOT_FACE if face_front(n) else SLOT_BODY


def face_pixel(x, z):
    """Pixel (inside one 64x64 face cell) for a head-local point."""
    px = (x + FACE_X_HALF) / (2 * FACE_X_HALF) * (FACE_CELL - 1)
    py = (FACE_Z_RANGE[1] - z) / (FACE_Z_RANGE[1] - FACE_Z_RANGE[0]) * (FACE_CELL - 1)
    return px, py


def head_uv(co, n, bb):
    if face_front(n):
        loc = LEAN_INV @ co
        px = min(max((loc.x + FACE_X_HALF) / (2 * FACE_X_HALF), 0.0), 1.0) * (FACE_CELL - 1) + 0.5
        py = min(max((FACE_Z_RANGE[1] - loc.z) / (FACE_Z_RANGE[1] - FACE_Z_RANGE[0]), 0.0), 1.0) * (FACE_CELL - 1) + 0.5
        return (px / FACE_W, 1.0 - py / FACE_H)
    # Fur: the head cell, shade step at the same height as in the face sheet.
    col, row, _ = CELLS["tawny"]
    loc = LEAN_INV @ co
    fy = (FACE_Z_RANGE[1] - loc.z) / (FACE_Z_RANGE[1] - FACE_Z_RANGE[0])
    fy = min(max(fy, 0.0), 1.0)
    return ((col * CELL + 8) / BODY_PX, 1.0 - (row * CELL + 1 + fy * (CELL - 2)) / BODY_PX)


MUZZLE_FRONT_LIMIT = -0.05     # the muzzle's whole front half carries the mouth


def muzzle_slot(n):
    return SLOT_FACE if face_front(n, MUZZLE_FRONT_LIMIT) else SLOT_BODY


def muzzle_uv(co, n, bb):
    if face_front(n, MUZZLE_FRONT_LIMIT):
        return head_uv(co, n, bb)
    return planar("cream")(co, n, bb)


# ---------------------------------------------------------------- face sheet
def paint_face():
    img = Image.new("RGB", (FACE_W, FACE_H), RGB["tawny"][0])
    d = ImageDraw.Draw(img)
    tawny, tawny_shade = RGB["tawny"]
    cream, cream_shade = RGB["cream"]
    ink, chalk, red = RGB["ink"][0], CHALK, RGB["jacket"][0]

    for cell, grin in ((0, False), (1, True)):
        ox = cell * FACE_CELL

        def P(x, z):
            px, py = face_pixel(x, z)
            return ox + px, py

        # Fur with the same shade step the head cell has (one dithered row).
        step_row = int(round(SHADE_FROM * FACE_CELL))
        for y in range(FACE_CELL):
            for x in range(FACE_CELL):
                if y < step_row:
                    c = tawny
                elif y == step_row:
                    c = tawny if (x + y) % 2 == 0 else tawny_shade
                else:
                    c = tawny_shade
                img.putpixel((ox + x, y), c)
        # Muzzle patch (cream), matching where the muzzle sits.
        mx, mz = MUZZLE_C.x, MUZZLE_C.z
        x0, y0 = P(mx - MUZZLE_R[0] * 1.12, mz + MUZZLE_R[1] * 1.12)
        x1, y1 = P(mx + MUZZLE_R[0] * 1.12, mz - MUZZLE_R[1] * 1.12)
        d.ellipse([x0, y0, x1, y1], fill=cream)
        # Nose with a shine.
        nx0, ny0 = P(-0.034, mz + 0.040)
        nx1, ny1 = P(0.034, mz + 0.012)
        d.ellipse([nx0, ny0, nx1, ny1], fill=ink)
        d.rectangle([nx0 + 3, ny0 + 1, nx0 + 5, ny0 + 2], fill=chalk)
        for sx in (-1, 1):
            ex, ez = 0.088 * sx, HEAD_C.z + 0.062
            if not grin:
                # Big tall oval eyes with two shines; brow dashes tilted worried-determined.
                a0, b0 = P(ex - 0.032, ez + 0.05)
                a1, b1 = P(ex + 0.032, ez - 0.05)
                d.ellipse([a0, b0, a1, b1], fill=ink)
                d.rectangle([a0 + 3, b0 + 3, a0 + 6, b0 + 7], fill=chalk)
                d.rectangle([a1 - 5, b1 - 6, a1 - 4, b1 - 4], fill=chalk)
                bx0, by0 = P(ex - 0.04, ez + 0.07 - 0.012 * sx)
                bx1, by1 = P(ex + 0.04, ez + 0.07 + 0.012 * sx)
                d.line([(bx0, by0), (bx1, by1)], fill=ink, width=2)
            else:
                # Squinting happy arcs, brows lifted.
                p0 = P(ex - 0.04, ez - 0.03)
                p1 = P(ex - 0.02, ez + 0.02)
                p2 = P(ex + 0.0, ez + 0.035)
                p3 = P(ex + 0.02, ez + 0.02)
                p4 = P(ex + 0.04, ez - 0.03)
                d.line([p0, p1, p2, p3, p4], fill=ink, width=3)
                bx0, by0 = P(ex - 0.04, ez + 0.075)
                bx1, by1 = P(ex + 0.04, ez + 0.085)
                d.line([(bx0, by0), (bx1, by1)], fill=ink, width=2)
        # Mouth.
        if not grin:
            p = [P(-0.05, mz + 0.0), P(-0.025, mz - 0.018), P(0.0, mz - 0.006), P(0.025, mz - 0.018), P(0.05, mz + 0.0)]
            d.line(p, fill=ink, width=3)
        else:
            a0, b0 = P(-0.07, mz + 0.002)
            a1, b1 = P(0.07, mz - 0.080)
            d.pieslice([a0, b0, a1, b1], 0, 180, fill=ink)
            d.rectangle([a0 + 3, (b0 + b1) / 2, a1 - 3, (b0 + b1) / 2 + 1], fill=chalk)
            ta0, tb0 = P(-0.035, mz - 0.040)
            ta1, tb1 = P(0.035, mz - 0.076)
            d.ellipse([ta0, tb0, ta1, tb1], fill=red)
    img.save(FACE_PATH)


# ---------------------------------------------------------------- the model
def build_body():
    pm = PartMesh(NAME + "_body", [MAT_BODY, MAT_FACE])
    pm.set_group_transform(Matrix.Identity(4))
    P = planar

    # --- planted: legs and giant boots (not leaning) ---
    for sx, side, hip, knee, foot in ((-1, "r", HIP_R, KNEE_R, FOOT_R), (1, "l", HIP_L, KNEE_L, FOOT_L)):
        pm.tube("thigh_" + side, SLOT_BODY, tuple(hip), tuple(knee), 0.055, 0.052, seg=6, uv=P("tawny"),
                drop_caps=("start", "end"))
        pm.tube("shin_" + side, SLOT_BODY, tuple(knee), tuple(foot + Vector((0, 0, 0.02))), 0.052, 0.052, seg=6,
                uv=P("tawny"), drop_caps=("start", "end"))
        pm.add("shin_" + side, SLOT_BODY, "ell", center=(0.10 * sx, -0.045, 0.085), uv=P("rust_gloss"),
               seg=8, rings=5, radii=(0.115, 0.155, 0.088))

    # --- leaning upper body ---
    pm.set_group_transform(LEAN)
    # Torso: puffy bomber with tan hem band and collar.
    pm.add("spine", SLOT_BODY, "ell", center=(0, 0, 0.50), uv=torso_uv, seg=8, rings=5, radii=(0.19, 0.155, 0.17),
           spin=22.5)
    pm.tube("spine", SLOT_BODY, (0, 0, 0.335), (0, 0, 0.385), 0.168, 0.172, seg=8, sxy=(1.0, 0.85), uv=P("tan"),
            drop_caps=("start", "end"), spin=22.5)
    pm.tube("spine", SLOT_BODY, (0, 0, 0.615), (0, 0, 0.665), 0.125, 0.14, seg=8, sxy=(1.0, 0.9), uv=P("tan"),
            drop_caps=("start", "end"), spin=22.5)

    # Head and big muzzle (front-facing triangles use the face sheet).
    pm.add("head", head_slot, "ell", center=tuple(HEAD_C), uv=head_uv, seg=10, rings=6, radii=HEAD_R)
    pm.add("head", muzzle_slot, "ell", center=tuple(MUZZLE_C), rot=(90, 0, 0), uv=muzzle_uv, seg=8, rings=5,
           radii=(MUZZLE_R[0], MUZZLE_R[1], MUZZLE_R[2]))
    # Ears: extra tall springy up-ear (her right), long swinging flop-ear (her left).
    pm.add("ear_r", SLOT_BODY, "ell", center=(-0.135, 0.0, 1.13), rot=(0, -9, 0), uv=P("tawny"), seg=6, rings=4,
           radii=(0.075, 0.048, 0.19))
    pm.add("ear_l", SLOT_BODY, "ell", center=(0.25, 0.0, 0.83), rot=(0, -20, 0), uv=P("tawny"), seg=6, rings=4,
           radii=(0.07, 0.048, 0.18))
    # Goggles pushed up on the head: brass strap bar and two glow lenses.
    pm.add("head", SLOT_BODY, "box", center=(0.0, -0.07, 0.975), rot=(52, 0, 0), uv=P("brass_gloss"),
           size=(0.34, 0.045, 0.045))
    for sx in (-1, 1):
        pm.add("head", SLOT_BODY, "tube", center=(0.085 * sx, -0.095, 0.965), rot=(52, 0, 0), uv=P("glow"),
               drop_caps=("bottom",), seg=6, r0=0.058, r1=0.058, length=0.055, sxy=(1, 1))

    # Arms: thin springy sleeves, fat tan cuffs, giant mitts with a thumb bump.
    def arm(S, E, H, side, thumb):
        up, fore = "upper_arm_" + side, "forearm_" + side
        pm.tube(up, SLOT_BODY, tuple(S), tuple(E), 0.058, 0.052, seg=6, uv=P("jacket"), drop_caps=("start", "end"))
        u = (H - E).normalized()
        cuff0, cuff1 = H - u * 0.10, H - u * 0.045
        pm.tube(fore, SLOT_BODY, tuple(E), tuple(cuff0 + u * 0.01), 0.052, 0.052, seg=6, uv=P("jacket"),
                drop_caps=("start", "end"))
        pm.tube(fore, SLOT_BODY, tuple(cuff0), tuple(cuff1), 0.088, 0.088, seg=8, uv=P("tan"),
                drop_caps=("start",))
        pm.add(fore, SLOT_BODY, "ell", center=tuple(H + u * 0.035), uv=P("tawny_gloss"), seg=8, rings=4,
               radii=(0.118, 0.112, 0.112))
        pm.add(fore, SLOT_BODY, "ell", center=tuple(H + u * 0.035 + Vector(thumb)), uv=P("tawny"), seg=5, rings=3,
               radii=(0.05, 0.05, 0.06))

    arm(SHOULDER_R, ELBOW_R, HAND_R, "r", (0.085, -0.06, 0.07))
    arm(SHOULDER_L, ELBOW_L, HAND_L, "l", (-0.085, -0.06, 0.08))

    # Tail, satchel (back right hip) and the chunky brass lamp bulb (left hip, on the hips bone).
    pm.tube("tail", SLOT_BODY, (0.0, 0.15, 0.33), (0.0, 0.31, 0.43), 0.06, 0.03, seg=6, uv=P("tawny"),
            drop_caps=("start",))
    pm.add("hips", SLOT_BODY, "box", center=(-0.215, 0.075, 0.43), rot=(0, 0, -8), uv=P("tan"),
           size=(0.085, 0.15, 0.13))
    lamp = Vector((0.235, -0.02, 0.41))
    pm.add("hips", SLOT_BODY, "ell", center=tuple(lamp), uv=P("glow"), seg=6, rings=4, radii=(0.072, 0.072, 0.085))
    pm.tube("hips", SLOT_BODY, tuple(lamp + Vector((0, 0, 0.06))), tuple(lamp + Vector((0, 0, 0.11))), 0.055, 0.03,
            seg=6, uv=P("brass_gloss"), drop_caps=("start",))
    return pm


def build_sword():
    pm = PartMesh(NAME + "_sword", [MAT_BODY])
    pm.set_group_transform(LEAN)
    d = SWORD_DIR
    grip = Vector(HAND_R) + d * 0.035
    basis = Vector((0, 0, 1)).rotation_difference(d).to_matrix().to_4x4()

    def along(t):
        return tuple(grip + d * t)

    P = planar
    pm.add("weapon_socket", SLOT_BODY, "tube", center=along(0.0), basis=basis, uv=P("rust"), seg=6,
           r0=0.036, r1=0.036, length=0.2, sxy=(1, 1))
    pm.add("weapon_socket", SLOT_BODY, "box", center=along(0.11), basis=basis, uv=P("brass_gloss"),
           size=(0.19, 0.055, 0.045))
    pm.add("weapon_socket", SLOT_BODY, "box", center=along(0.43), basis=basis, uv=P("blade"),
           size=(0.115, 0.05, 0.62), taper=0.55)
    return pm


def main():
    os.makedirs(OUT_DIR, exist_ok=True)
    bpy.ops.wm.read_factory_settings(use_empty=True)
    paint_body()
    paint_face()
    arm_obj = build_armature(NAME, JOINTS)
    body_obj = build_body().to_object()
    sword_obj = build_sword().to_object()
    mats = [make_material(MAT_BODY, BODY_PATH), make_material(MAT_FACE, FACE_PATH)]
    attach(body_obj, arm_obj, mats)
    attach(sword_obj, arm_obj, [mats[0]])
    print("E body: %d drawn (cap 900)" % triangle_count(body_obj))
    print("E sword: %d drawn (cap 150)" % triangle_count(sword_obj))
    export_glb(os.path.join(OUT_DIR, NAME + ".glb"))


main()
