"""Red prototype F, "Shiba": Ross's pick, combined (docs/decisions.md, 2026-10-06):
"the style of E, the head of E, the body of C, the sword of E, make the ears shorter and pointy like
a shiba inu - make her a shiba inu".

  - STYLE / surface: E's. One 16x16 painted cell per part (lit on top, one dithered shade step, Chalk
    gloss spots on boots / mitts / lamp), the same palette handling, standard psx_lit, no outline.
  - HEAD: E's big head and face approach, re-made as a shiba: short pointy upright triangular ears
    (cream inside), tawny coat with cream "urajiro" (cheeks, muzzle, under-jaw, chest tuft), cream
    eyebrow dots, dark nose. The muzzle is now a short drum with a FLAT front, so the nose and mouth
    are painted on a flat cap (E's ball muzzle squashed them).
  - BODY: C's proportions and shapes (teardrop jacket with the hem swinging off the left side, rolled
    collar and cuffs, thin legs, boots, mitts, hip lamp, satchel), surfaced in E's style, with E's
    gloss on the boots and mitts a little bigger than C's.
  - SWORD: E's (long chalk blade, big brass guard), a separate mesh on weapon_socket.
  - TAIL: a curled shiba tail, three overlapping capsules, cream tip, curling up over the back.

Materials (psx_post_import.gd gives both the standard psx_lit):
    mat_red_proto_f_body   128x128 painted sheet (+ the painted jacket back, zip placket, chest patch)
    mat_red_proto_f_face   128x64 face sheet: two 64x64 expressions, neutral (left) and grin (right).
                           Swap them with uv_offset.x = 0.5 on this material.

Run (see red_proto_de_kit.py):  /tmp/blockout_venv/bin/python game/scripts/tools/prototypes/red_proto_f.py
Output: game/art/placeholder/characters/red_prototypes/red_proto_f.glb (+ _body.png, _face.png)
"""

import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from red_proto_de_kit import *  # noqa: E402,F403  (bpy first, inside the kit)
from PIL import Image, ImageDraw  # noqa: E402

NAME = "red_proto_f"
MAT_BODY = "mat_red_proto_f_body"
MAT_FACE = "mat_red_proto_f_face"
SLOT_BODY, SLOT_FACE = 0, 1
BODY_PATH = os.path.join(OUT_DIR, NAME + "_body.png")
FACE_PATH = os.path.join(OUT_DIR, NAME + "_face.png")
BODY_PX = 128
CELL = 16
FACE_W, FACE_H = 128, 64
FACE_CELL = 64

# ---- palette: E's brightest version of the style guide palette, one shade step each ----
COL = {
    "tawny": ("#D79448", "#A9693A"),
    "cream": ("#FBE9C0", "#EBC48E"),     # warm even in shade: no grey, no cold
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

CELLS = {
    "tawny": (0, 0, False), "tawny_gloss": (1, 0, True), "cream": (2, 0, False),
    "jacket": (3, 0, False), "tan": (4, 0, False), "brass": (5, 0, False), "brass_gloss": (6, 0, True),
    "glow": (7, 0, True), "rust_gloss": (0, 1, True), "rust": (1, 1, False), "blade": (2, 1, False),
    "dusk": (3, 1, False), "ink": (4, 1, False), "cream_gloss": (5, 1, True),
}
CELL_COLOR = {"tawny_gloss": "tawny", "brass_gloss": "brass", "rust_gloss": "rust", "cream_gloss": "cream"}
ART_ORIGIN = (64, 32)       # 32x32 painted jacket back (cells 4-5, 2-3)
PLACKET_ORIGIN = (96, 32)   # 16x32: upper half lit, lower half shade (the jacket's shade step)
PATCH_ORIGIN = (112, 32)    # 16x16 chest patch
SHADE_FROM = 0.58


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
                c = lit if (x + y) % 2 == 0 else shade
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
    lit_j, shade_j = RGB["jacket"]
    ink, brass, glow, chalk = (hex_rgb(PAL[k]) for k in ("ink", "brass", "glow", "chalk"))
    terracotta, mustard, green = (hex_rgb(PAL[k]) for k in ("terracotta", "mustard", "patch_green"))

    # Jacket back with the hand-painted lamp (the tail curls over the left of it, so the lamp sits a
    # little right of center in the art).
    ox, oy = ART_ORIGIN

    def box(x0, y0, x1, y1, color):
        d.rectangle([ox + x0, oy + y0, ox + x1, oy + y1], fill=color)

    box(0, 0, 31, 31, lit_j)
    box(0, 20, 31, 31, shade_j)
    for x in range(0, 32, 2):
        d.point([(ox + x, oy + 19)], fill=shade_j)
        d.point([(ox + x + 1, oy + 20)], fill=lit_j)
    box(2, 3, 9, 9, terracotta); box(2, 3, 9, 3, ink)
    box(23, 5, 29, 12, mustard); box(23, 5, 29, 5, ink)
    box(3, 22, 9, 27, green)
    box(13, 4, 18, 5, ink); box(12, 5, 13, 8, ink); box(18, 5, 19, 8, ink)
    box(10, 8, 21, 10, ink); box(11, 9, 20, 10, brass)
    box(9, 11, 22, 22, ink); box(10, 11, 21, 21, glow)
    box(13, 13, 14, 17, chalk)
    box(10, 22, 21, 25, ink); box(11, 22, 20, 24, brass)

    # Zip placket 16x32: upper half lit, lower half the shade color (matches the jacket's step).
    fx, fy = PLACKET_ORIGIN
    for half in (0, 1):
        base = shade_j if half else lit_j
        y0 = fy + half * 16
        d.rectangle([fx, y0, fx + 15, y0 + 15], fill=base)
        d.line([(fx + 3, y0), (fx + 3, y0 + 15)], fill=ink)
        d.line([(fx + 12, y0), (fx + 12, y0 + 15)], fill=ink)
        for row in range(16):
            d.point([(fx + 7, y0 + row), (fx + 8, y0 + row)], fill=(brass if row % 2 == 0 else ink))
    d.rectangle([fx + 5, fy + 13, fx + 10, fy + 18], fill=ink)
    d.rectangle([fx + 6, fy + 14, fx + 9, fy + 17], fill=brass)
    # Chest patch (a Harrow lamp patch).
    px_, py_ = PATCH_ORIGIN
    d.rectangle([px_, py_, px_ + 15, py_ + 15], fill=lit_j)
    d.rectangle([px_ + 2, py_ + 2, px_ + 13, py_ + 13], fill=ink)
    d.rectangle([px_ + 3, py_ + 3, px_ + 12, py_ + 12], fill=mustard)
    d.rectangle([px_ + 6, py_ + 5, px_ + 9, py_ + 6], fill=ink)
    d.rectangle([px_ + 6, py_ + 7, px_ + 9, py_ + 10], fill=glow)
    img.save(BODY_PATH)


# ---------------------------------------------------------------- layout (C's body, E's head)
LEAN_DEG = 5.0
HIP_PIVOT = Vector((0.0, 0.0, 0.25))
LEAN = Matrix.Translation(HIP_PIVOT) @ rot_matrix((LEAN_DEG, 0, 0)) @ Matrix.Translation(-HIP_PIVOT)
LEAN_INV = LEAN.inverted()

HEAD_C = Vector((0.0, 0.0, 0.80))
HEAD_R = (0.25, 0.205, 0.205)               # wider than tall: a bean, not a ball
MUZZLE_Y0, MUZZLE_Y1, MUZZLE_Z = -0.12, -0.265, 0.735
MUZZLE_RX, MUZZLE_RZ = 0.115, 0.082


def bean(p):
    """Bean / kidney head from a squashed ball (p is already scaled to HEAD_R, centered on 0):
    a soft dip at the top between the ears, fuller cheeks at the sides and bottom, a slightly
    narrower brow, and a gently pushed-out lower front for the muzzle to grow from."""
    ux, uy, uz = p.x / HEAD_R[0], p.y / HEAD_R[1], p.z / HEAD_R[2]
    upper = max(uz, 0.0)
    cheek = math.exp(-(((uz + 0.35) / 0.5) ** 2))
    x = p.x * (1.0 - 0.06 * upper * upper) * (1.0 + 0.15 * cheek)
    y = p.y * (1.0 + 0.05 * cheek) - 0.012 * max(-uy, 0.0) * cheek
    z = p.z - 0.20 * HEAD_R[2] * math.exp(-((ux / 0.34) ** 2)) * upper ** 3
    return Vector((x, y, z))                  # half width, half height of the front cap
SHOULDER_R, SHOULDER_L = Vector((-0.15, 0.0, 0.51)), Vector((0.15, 0.0, 0.51))
ELBOW_R, HAND_R = Vector((-0.25, -0.04, 0.40)), Vector((-0.21, -0.19, 0.49))
ELBOW_L, HAND_L = Vector((0.23, -0.01, 0.39)), Vector((0.255, -0.05, 0.25))
HIP_L, HIP_R = Vector((0.07, 0.0, 0.27)), Vector((-0.07, 0.0, 0.27))
KNEE_L, KNEE_R = Vector((0.07, 0.0, 0.195)), Vector((-0.07, 0.0, 0.195))
FOOT_L, FOOT_R = Vector((0.075, -0.01, 0.12)), Vector((-0.075, -0.01, 0.12))
SWORD_DIR = Vector((-0.30, 0.38, 0.85)).normalized()
JACKET_Z = (0.17, 0.57)
COLLAR_TOP = 0.64


def L(v):
    return LEAN @ Vector(v)


TAIL_PTS = [Vector(p) for p in ((0.07, 0.16, 0.26), (0.15, 0.285, 0.34), (0.17, 0.32, 0.49), (0.09, 0.26, 0.61))]

JOINTS = {
    "root": ((0, 0, 0), (0, 0, 0.05)),
    "hips": ((0, 0, 0.22), tuple(L((0, 0, 0.30)))),
    "spine": (tuple(L((0, 0, 0.30))), tuple(L((0, 0, 0.58)))),
    "head": (tuple(L((0, 0, 0.60))), tuple(L((0, 0, 0.99)))),
    "ear_r": (tuple(L((-0.165, 0, 0.93))), tuple(L((-0.185, -0.015, 1.095)))),
    "ear_l": (tuple(L((0.165, 0, 0.93))), tuple(L((0.185, -0.015, 1.095)))),
    "tail": (tuple(L(TAIL_PTS[0])), tuple(L(TAIL_PTS[3]))),
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
def local_normal(n):
    return (LEAN_INV.to_3x3() @ n).normalized()


def _cell_uv(col, row, fx, fy):
    fx = min(max(fx, 0.0), 1.0)
    fy = min(max(fy, 0.0), 1.0)
    return ((col * CELL + 1 + fx * (CELL - 2)) / BODY_PX, 1.0 - (row * CELL + 1 + fy * (CELL - 2)) / BODY_PX)


def planar(cell_name):
    """Planar mapping into a cell over the primitive's own bounding box: top reads the lit rows,
    bottom the shade rows. Gloss cells fall back to the plain color on back-facing triangles."""
    plain = CELLS.get(CELL_COLOR.get(cell_name, ""), None)

    def fn(co, n, bb):
        lo, hi = bb
        col, row = (plain[0], plain[1]) if (plain and local_normal(n).y > 0.3) else CELLS[cell_name][:2]
        return _cell_uv(col, row, (co.x - lo.x) / max(hi.x - lo.x, 1e-6), 1.0 - (co.z - lo.z) / max(hi.z - lo.z, 1e-6))
    return fn


def planar_z(cell_name, z0, z1):
    """Like planar, but the vertical range is fixed (so a whole jacket shares ONE shade step)."""
    col, row, _ = CELLS[cell_name]

    def fn(co, n, bb):
        lo, hi = bb
        return _cell_uv(col, row, (co.x - lo.x) / max(hi.x - lo.x, 1e-6), (z1 - (LEAN_INV @ co).z) / (z1 - z0))
    return fn


def jacket_uv(co, n, bb):
    loc = LEAN_INV @ co
    if local_normal(n).y > 0.35:                    # back: the painted lamp
        ox, oy = ART_ORIGIN
        fx = min(max((0.11 - loc.x) / 0.30, 0.0), 1.0)
        fy = min(max((JACKET_Z[1] - loc.z) / (JACKET_Z[1] - JACKET_Z[0]), 0.0), 1.0)
        return ((ox + 0.5 + fx * 31) / BODY_PX, 1.0 - (oy + 0.5 + fy * 31) / BODY_PX)
    return planar_z("jacket", JACKET_Z[0], COLLAR_TOP)(co, n, bb)


FACE_X_HALF = 0.27
FACE_Z_RANGE = (HEAD_C.z - 0.20, HEAD_C.z + 0.20)


def face_uv(co):
    loc = LEAN_INV @ co
    px = min(max((loc.x + FACE_X_HALF) / (2 * FACE_X_HALF), 0.0), 1.0) * (FACE_CELL - 1) + 0.5
    py = min(max((FACE_Z_RANGE[1] - loc.z) / (FACE_Z_RANGE[1] - FACE_Z_RANGE[0]), 0.0), 1.0) * (FACE_CELL - 1) + 0.5
    return (px / FACE_W, 1.0 - py / FACE_H)


def head_front(n):
    return local_normal(n).y < -0.30


def head_slot(n):
    return SLOT_FACE if head_front(n) else SLOT_BODY


def head_uv(co, n, bb):
    ln = local_normal(n)
    if head_front(n):
        return face_uv(co)
    if ln.z < -0.45 and ln.y < 0.1:                    # under-jaw: cream (urajiro)
        return planar("cream")(co, n, bb)
    col, row, _ = CELLS["tawny"]
    loc = LEAN_INV @ co
    fy = (FACE_Z_RANGE[1] - loc.z) / (FACE_Z_RANGE[1] - FACE_Z_RANGE[0])
    return ((col * CELL + 8) / BODY_PX, 1.0 - (row * CELL + 1 + min(max(fy, 0.0), 1.0) * (CELL - 2)) / BODY_PX)


def muzzle_slot(n):
    return SLOT_FACE if local_normal(n).y < -0.95 else SLOT_BODY      # only the flat front cap


def muzzle_uv(co, n, bb):
    if local_normal(n).y < -0.95:
        return face_uv(co)
    return planar("cream")(co, n, bb)


def ear_uv(co, n, bb):
    if local_normal(n).y < -0.35:                      # the front face of the pyramid: cream inside
        return planar("cream")(co, n, bb)
    return planar("tawny")(co, n, bb)


# ---------------------------------------------------------------- face sheet
def paint_face():
    img = Image.new("RGB", (FACE_W, FACE_H), RGB["tawny"][0])
    d = ImageDraw.Draw(img)
    tawny, tawny_shade = RGB["tawny"]
    cream, cream_shade = RGB["cream"]
    ink, chalk, red = RGB["ink"][0], CHALK, RGB["jacket"][0]
    mz = MUZZLE_Z

    for cell, grin in ((0, False), (1, True)):
        ox = cell * FACE_CELL

        def P(x, z):
            px = (x + FACE_X_HALF) / (2 * FACE_X_HALF) * (FACE_CELL - 1)
            py = (FACE_Z_RANGE[1] - z) / (FACE_Z_RANGE[1] - FACE_Z_RANGE[0]) * (FACE_CELL - 1)
            return ox + px, py

        step_row = int(round(SHADE_FROM * FACE_CELL))
        for y in range(FACE_CELL):
            for x in range(FACE_CELL):
                c = tawny if y < step_row else (tawny if (x + y) % 2 == 0 and y == step_row else tawny_shade)
                img.putpixel((ox + x, y), c)

        def cream_blob(cx, cz, rx, rz):
            a0, b0 = P(cx - rx, cz + rz)
            a1, b1 = P(cx + rx, cz - rz)
            d.ellipse([a0, b0, a1, b1], fill=cream)

        # urajiro: cream lower face and cheeks, with a dithered edge toward the tawny
        cream_blob(0.0, HEAD_C.z - 0.14, 0.22, 0.10)
        cream_blob(-0.175, HEAD_C.z - 0.07, 0.09, 0.075)
        cream_blob(0.175, HEAD_C.z - 0.07, 0.09, 0.075)
        for x in range(FACE_CELL):
            for y in range(FACE_CELL):
                if (x + y) % 2 == 0:
                    here = img.getpixel((ox + x, y))
                    near = [img.getpixel((ox + min(max(x + dx, 0), 63), min(max(y + dy, 0), 63))) for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))]
                    if here == cream and any(c in (tawny, tawny_shade) for c in near):
                        img.putpixel((ox + x, y), tawny_shade if y > step_row else tawny)
        # cream in the shade rows is the warm shade cream, never a cold or grey one
        for y in range(step_row + 1, FACE_CELL):
            for x in range(FACE_CELL):
                if img.getpixel((ox + x, y)) == cream:
                    img.putpixel((ox + x, y), cream_shade)
        # muzzle cap: cream, nose, mouth
        a0, b0 = P(-MUZZLE_RX * 1.05, mz + MUZZLE_RZ * 1.1)
        a1, b1 = P(MUZZLE_RX * 1.05, mz - MUZZLE_RZ * 1.1)
        d.rectangle([a0, b0, a1, b1], fill=cream)
        na0, nb0 = P(-0.036, mz + 0.062)
        na1, nb1 = P(0.036, mz + 0.022)
        d.ellipse([na0, nb0, na1, nb1], fill=ink)
        d.rectangle([na0 + 2, nb0 + 1, na0 + 4, nb0 + 1], fill=chalk)
        if not grin:
            for k in (-1, 1):                       # two small arcs under the nose: the shiba "w" smile
                ax0, ay0 = P(min(0.0, 0.055 * k), mz + 0.004)
                ax1, ay1 = P(max(0.0, 0.055 * k), mz - 0.04)
                d.arc([ax0, ay0, ax1, ay1], 15, 165, fill=ink, width=2)
        else:
            ma0, mb0 = P(-0.058, mz + 0.0)
            ma1, mb1 = P(0.058, mz - 0.07)
            d.pieslice([ma0, mb0 - (mb1 - mb0) * 0.35, ma1, mb1], 0, 180, fill=ink)
            ta0, tb0 = P(-0.03, mz - 0.042)
            ta1, tb1 = P(0.03, mz - 0.068)
            d.ellipse([ta0, tb0, ta1, tb1], fill=red)
        # eyes (friendly almond-ish ovals), cream eyebrow dots above them
        for sx in (-1, 1):
            ex, ez = 0.105 * sx, HEAD_C.z + 0.045
            if not grin:
                a0, b0 = P(ex - 0.031, ez + 0.049)
                a1, b1 = P(ex + 0.031, ez - 0.049)
                d.ellipse([a0, b0, a1, b1], fill=ink)
                d.rectangle([a0 + 2, b0 + 2, a0 + 4, b0 + 5], fill=chalk)
                d.point([(a1 - 3, b1 - 3)], fill=chalk)
            else:
                pts = [P(ex - 0.035, ez - 0.02), P(ex - 0.015, ez + 0.02), P(ex, ez + 0.032), P(ex + 0.015, ez + 0.02), P(ex + 0.035, ez - 0.02)]
                d.line(pts, fill=ink, width=3)
            da0, db0 = P(ex - 0.02, ez + 0.09 + (0.012 if grin else 0.0))
            da1, db1 = P(ex + 0.02, ez + 0.065 + (0.012 if grin else 0.0))
            d.ellipse([da0, db0, da1, db1], fill=cream)
    img.save(FACE_PATH)


# ---------------------------------------------------------------- the model
def add_jacket(pm):
    """C's teardrop jacket: hem band widest, shoulders narrow, hem swinging off the left side."""
    J = planar_z("jacket", JACKET_Z[0], COLLAR_TOP)
    pm.tube("spine", SLOT_BODY, (0, 0, 0.17), (0, 0, 0.35), 0.25, 0.205, seg=8, sxy=(1.0, 0.86), uv=jacket_uv,
            drop_caps=("start", "end"), spin=22.5)
    pm.tube("spine", SLOT_BODY, (0, 0, 0.35), (0, 0, 0.57), 0.20, 0.135, seg=8, sxy=(1.0, 0.86), uv=jacket_uv,
            drop_caps=("start", "end"), spin=22.5)
    return J


def build_body(jacket_probe=None, head_probe_obj=None):
    pm = PartMesh(NAME + "_body", [MAT_BODY, MAT_FACE])
    P = planar
    J = planar_z("jacket", JACKET_Z[0], COLLAR_TOP)

    # --- planted: thin legs and glossy boots (C's legs, E's gloss) ---
    for sx, side, hip, knee, foot in ((-1, "r", HIP_R, KNEE_R, FOOT_R), (1, "l", HIP_L, KNEE_L, FOOT_L)):
        pm.tube("thigh_" + side, SLOT_BODY, tuple(hip), tuple(knee), 0.072, 0.07, seg=6, uv=P("tawny"), drop_caps=("start", "end"))
        pm.tube("shin_" + side, SLOT_BODY, tuple(knee), tuple(foot), 0.07, 0.07, seg=6, uv=P("tawny"), drop_caps=("start", "end"))
        pm.add("shin_" + side, SLOT_BODY, "ell", center=(0.078 * sx, -0.045, 0.092), uv=P("rust_gloss"), seg=8, rings=4,
               radii=(0.125, 0.175, 0.105))

    # --- leaning upper body ---
    pm.set_group_transform(LEAN)
    add_jacket(pm)
    pm.tube("spine", SLOT_BODY, (0, 0, 0.565), (0, 0, COLLAR_TOP), 0.145, 0.125, seg=8, sxy=(1.0, 0.9), uv=P("tan"),
            drop_caps=("start", "end"), spin=22.5)
    # chest tuft (urajiro): a cream bib peeking over the collar under the chin
    pm.add("spine", SLOT_BODY, "ell", center=(0.0, -0.11, 0.605), uv=P("cream"), seg=6, rings=3, radii=(0.10, 0.07, 0.065))

    # Head (front-facing triangles carry the face sheet) and the flat-fronted shiba muzzle.
    pm.add("head", head_slot, "ell", center=tuple(HEAD_C), uv=head_uv, seg=10, rings=7, radii=HEAD_R, deform=bean)
    pm.tube("head", muzzle_slot, (0, MUZZLE_Y0, MUZZLE_Z), (0, MUZZLE_Y1, MUZZLE_Z), MUZZLE_RX, MUZZLE_RX * 0.9, seg=8,
            sxy=(1.0, MUZZLE_RZ / MUZZLE_RX), uv=muzzle_uv, drop_caps=("start",), spin=22.5)
    # Shiba ears: short, pointy, upright pyramids set wide on top of the head, leaning slightly out.
    for sx, bone in ((-1, "ear_r"), (1, "ear_l")):
        pm.tube(bone, SLOT_BODY, (0.165 * sx, 0.015, 0.90), (0.185 * sx, -0.015, 1.095), 0.16, 0.025, seg=4,
                sxy=(1.0, 0.72), uv=ear_uv, drop_caps=("start",), spin=45)
    # Goggles pushed up on the forehead between the ears: brass strap bar and two glow lenses.
    pm.add("head", SLOT_BODY, "box", center=(0.0, -0.05, 0.955), rot=(40, 0, 0), uv=P("brass_gloss"), size=(0.2, 0.04, 0.045))
    for sx in (-1, 1):
        pm.add("head", SLOT_BODY, "tube", center=(0.052 * sx, -0.09, 0.945), rot=(52, 0, 0), uv=P("glow"),
               drop_caps=("bottom",), seg=6, r0=0.046, r1=0.046, length=0.05, sxy=(1, 1))

    # Arms: C's tapered sleeves, fat tan cuffs, bigger glossy mitts (E) with a thumb bump.
    def arm(S, E, H, side, thumb):
        up, fore = "upper_arm_" + side, "forearm_" + side
        pm.tube(up, SLOT_BODY, tuple(S), tuple(E), 0.062, 0.056, seg=6, uv=P("jacket"), drop_caps=("start", "end"))
        u = (H - E).normalized()
        cuff0, cuff1 = H - u * 0.085, H - u * 0.035
        pm.tube(fore, SLOT_BODY, tuple(E), tuple(cuff0 + u * 0.01), 0.056, 0.056, seg=6, uv=P("jacket"), drop_caps=("start", "end"))
        pm.tube(fore, SLOT_BODY, tuple(cuff0), tuple(cuff1), 0.087, 0.087, seg=6, uv=P("tan"), drop_caps=("start",))
        pm.add(fore, SLOT_BODY, "ell", center=tuple(H + u * 0.03), uv=P("tawny_gloss"), seg=8, rings=5, radii=(0.095, 0.09, 0.09))
        pm.add(fore, SLOT_BODY, "ell", center=tuple(H + u * 0.03 + Vector(thumb)), uv=P("tawny"), seg=4, rings=3, radii=(0.042, 0.042, 0.05))

    arm(SHOULDER_R, ELBOW_R, HAND_R, "r", (0.07, -0.05, 0.06))
    arm(SHOULDER_L, ELBOW_L, HAND_L, "l", (-0.07, -0.05, 0.065))

    # Curled shiba tail over the back: three overlapping capsules, cream tip.
    for i in range(3):
        a, b = TAIL_PTS[i], TAIL_PTS[i + 1]
        mid = (a + b) / 2
        direction = (b - a).normalized()
        basis = Vector((0, 0, 1)).rotation_difference(direction).to_matrix().to_4x4()
        r = (0.084, 0.088, 0.078)[i]
        pm.add("tail", SLOT_BODY, "ell", center=tuple(mid), basis=basis, uv=planar_z("tawny", 0.20, 0.72), seg=6, rings=4,
               radii=(r, r, (b - a).length / 2 + 0.05))

    # Satchel (back right hip) and the chunky brass lamp bulb at the left hip front (on the hips bone).
    pm.add("hips", SLOT_BODY, "box", center=(-0.175, 0.15, 0.30), rot=(0, 0, -8), uv=P("tan"), size=(0.08, 0.15, 0.13))
    lamp = Vector((0.15, -0.17, 0.285))
    pm.add("hips", SLOT_BODY, "ell", center=tuple(lamp), uv=P("glow"), seg=6, rings=4, radii=(0.062, 0.062, 0.075))
    pm.tube("hips", SLOT_BODY, tuple(lamp + Vector((0, 0, 0.055))), tuple(lamp + Vector((0, 0, 0.10))), 0.05, 0.028, seg=6,
            uv=P("brass_gloss"), drop_caps=("start",))

    # Jacket decals (2 tris each): zip placket in two halves and a chest patch, found by ray cast.
    if jacket_probe is not None:
        def decal(x, z, w, h, origin, size_px):
            loc, normal = surface_hit(jacket_probe, x, z)
            assert loc is not None, "jacket ray missed"
            basis = Vector((0, -1, 0)).rotation_difference(normal).to_matrix().to_4x4()
            ox, oy = origin
            u0, u1 = ox / BODY_PX, (ox + size_px[0]) / BODY_PX
            v0, v1 = 1.0 - (oy + size_px[1]) / BODY_PX, 1.0 - oy / BODY_PX
            pm.add("spine", SLOT_BODY, "quad", center=tuple(Vector(loc) + normal * 0.006), basis=basis, size=(w, h), rect=(u0, v0, u1, v1))

        decal(0.0, 0.46, 0.085, 0.16, (PLACKET_ORIGIN[0], PLACKET_ORIGIN[1]), (16, 16))
        decal(0.0, 0.30, 0.085, 0.16, (PLACKET_ORIGIN[0], PLACKET_ORIGIN[1] + 16), (16, 16))
        decal(0.105, 0.47, 0.065, 0.065, PATCH_ORIGIN, (16, 16))
    return pm


def build_sword():
    """E's sword: long chalk blade, big brass guard, rust grip, held in the right mitt."""
    pm = PartMesh(NAME + "_sword", [MAT_BODY])
    pm.set_group_transform(LEAN)
    d = SWORD_DIR
    grip = Vector(HAND_R) + d * 0.03
    basis = Vector((0, 0, 1)).rotation_difference(d).to_matrix().to_4x4()

    def along(t):
        return tuple(grip + d * t)

    P = planar
    pm.add("weapon_socket", SLOT_BODY, "tube", center=along(0.0), basis=basis, uv=P("rust"), seg=6, r0=0.036, r1=0.036, length=0.2, sxy=(1, 1))
    pm.add("weapon_socket", SLOT_BODY, "box", center=along(0.11), basis=basis, uv=P("brass_gloss"), size=(0.19, 0.055, 0.045))
    pm.add("weapon_socket", SLOT_BODY, "box", center=along(0.43), basis=basis, uv=P("blade"), size=(0.115, 0.05, 0.62), taper=0.55)
    return pm


def build():
    """Builds the whole of F in the open Blender scene and returns (armature, body, sword) objects.
    Split out of main() so red_shiba.py (the animated placeholder) can reuse it. Nothing changes
    in what F looks like."""
    os.makedirs(OUT_DIR, exist_ok=True)
    bpy.ops.wm.read_factory_settings(use_empty=True)
    paint_body()
    paint_face()
    probe = PartMesh("jacket_probe", [MAT_BODY])
    add_jacket(probe)
    jacket_obj = probe.to_object()
    arm_obj = build_armature(NAME, JOINTS)
    body_obj = build_body(jacket_obj).to_object()
    bpy.data.objects.remove(jacket_obj)
    sword_obj = build_sword().to_object()
    mats = [make_material(MAT_BODY, BODY_PATH), make_material(MAT_FACE, FACE_PATH)]
    attach(body_obj, arm_obj, mats)
    attach(sword_obj, arm_obj, [mats[0]])
    print("F body: %d drawn" % triangle_count(body_obj))
    print("F sword: %d drawn" % triangle_count(sword_obj))
    return arm_obj, body_obj, sword_obj


def main():
    build()
    export_glb(os.path.join(OUT_DIR, NAME + ".glb"))


if __name__ == "__main__":
    main()
