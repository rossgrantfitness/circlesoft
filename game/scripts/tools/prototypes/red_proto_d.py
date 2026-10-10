"""Red style prototype D, "Ink Line": flat-color cartoon Red with two-tone cel shading and a dark
outline (docs/red_style_prototypes.md, section D). Static, neutral pose, no animation.

What it builds (about 2 heads tall, pear-shaped, short limbs, big boots):
  - body mesh, THREE material slots, named so scripts/tools/psx_post_import.gd picks the shader:
        mat_red_proto_d_cel          swatch strip 64x64, shader psx_cel (two bands)
        mat_red_proto_d_outline      the inverted hull (same triangles, smooth normals), psx_outline
        mat_red_proto_d_face_unlit   eye / nose / mouth decal quads, face sheet 128x64, alpha cut
  - a separate sword mesh (cel + outline), skinned to weapon_socket
  - the shared 17-bone skeleton, every vertex on exactly one bone

Swatch strip layout (64x64): the LEFT half (x 0-31) holds the lit colors, the RIGHT half (x 32-63)
holds each color's darker sibling in the same spot (psx_cel reads both). In the left half:
  (0,0)   16x16  grid of 4x4 swatches of 4 px (16 colors)
  (16,0)  16x32  front of the jacket: zip placket (two decal quads)
  (0,16)  16x16  chest patch (decal quad)
  (0,32)  32x32  painted back of the jacket (hand-painted lamp, patches)

Run (see red_proto_de_kit.py):  /tmp/blockout_venv/bin/python game/scripts/tools/prototypes/red_proto_d.py
Output: game/art/placeholder/characters/red_prototypes/red_proto_d.glb
        red_proto_d_swatch.png, red_proto_d_face.png (source copies; the .glb embeds them)
"""

import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from red_proto_de_kit import *  # noqa: E402,F403  (bpy first, inside the kit)
from PIL import Image, ImageDraw  # noqa: E402

NAME = "red_proto_d"
MAT_CEL = "mat_red_proto_d_cel"
MAT_OUTLINE = "mat_red_proto_d_outline"
MAT_FACE = "mat_red_proto_d_face_unlit"
SLOT_CEL, SLOT_OUTLINE, SLOT_FACE = 0, 1, 2
SWATCH_PATH = os.path.join(OUT_DIR, NAME + "_swatch.png")
FACE_PATH = os.path.join(OUT_DIR, NAME + "_face.png")
SWATCH_PX = 64
FACE_W, FACE_H = 128, 64

# (name, lit, shade sibling). Shade siblings are darker and a little cooler/purpler.
SWATCHES = [
    ("tawny", "#C98A45", "#9C6538"),
    ("cream", "#F4E4C1", "#CDB58F"),
    ("jacket", "#C8322A", "#85233A"),
    ("brass", "#D9A441", "#A06E2C"),
    ("glow", "#FFE08A", "#FFB347"),
    ("ink", "#14121F", "#14121F"),
    ("chalk", "#EDEAD8", "#9C98C0"),
    ("rust", "#9C4A2E", "#6A3030"),
    ("tan", "#CBA878", "#9A7C5E"),
    ("dusk", "#3A3566", "#2A264D"),
    ("blade", "#EDEAD8", "#7A74B0"),
    ("terracotta", "#C8643B", "#8F4535"),
    ("mustard", "#E0A93B", "#A87A30"),
    ("patch_green", "#6E9A5A", "#4B6F4E"),
    ("jacket_hi", "#D9473A", "#962A3C"),
    ("night", "#1F2540", "#171B33"),
]
LIT = {n: hex_rgb(l) for n, l, s in SWATCHES}
SHADE = {n: hex_rgb(s) for n, l, s in SWATCHES}


def swatch_cell(name):
    i = [n for n, _, _ in SWATCHES].index(name)
    return i % 4, i // 4


def swatch_uv_for(name):
    col, row = swatch_cell(name)
    u = (col * 4 + 2) / SWATCH_PX
    v = 1.0 - (row * 4 + 2) / SWATCH_PX
    return lambda co, n: (u, v)


# Back-of-jacket art canvas: 32x32 at (0, 32); x in [-0.16, 0.16] (mirrored: seen from behind),
# z in [0.17, 0.57].
ART_X, ART_Z0, ART_Z1 = 0.16, 0.17, 0.57


def jacket_uv(co, n):
    if n.y > 0.65:   # back-facing panel gets the painted art
        px = min(max((ART_X - co.x) / (2 * ART_X) * 32.0, 0.5), 31.5)
        py = 32.0 + min(max((ART_Z1 - co.z) / (ART_Z1 - ART_Z0) * 32.0, 0.5), 31.5)
        return (px / SWATCH_PX, 1.0 - py / SWATCH_PX)
    return swatch_uv_for("jacket")(co, n)


def paint_swatch():
    img = Image.new("RGB", (SWATCH_PX, SWATCH_PX), LIT["ink"])
    d = ImageDraw.Draw(img)
    for i, (name, lit, shade) in enumerate(SWATCHES):
        col, row = i % 4, i // 4
        for half, color in ((0, hex_rgb(lit)), (32, hex_rgb(shade))):
            x0, y0 = half + col * 4, row * 4
            d.rectangle([x0, y0, x0 + 3, y0 + 3], fill=color)
    # Jacket back, drawn twice: lit at (0,32), shade at (32,32).
    for half, table in ((0, LIT), (32, SHADE)):
        ox, oy = half, 32

        def px(x0, y0, x1, y1, name):
            d.rectangle([ox + x0, oy + y0, ox + x1, oy + y1], fill=table[name])

        px(0, 0, 31, 31, "jacket")
        px(0, 29, 31, 31, "jacket_hi")            # hem band
        # Patches (Harrow patches): terracotta top-left, mustard right, green bottom-left.
        px(2, 3, 9, 9, "terracotta"); px(2, 3, 9, 3, "ink"); px(2, 9, 9, 9, "ink")
        px(23, 12, 29, 19, "mustard"); px(23, 12, 29, 12, "ink"); px(23, 19, 29, 19, "ink")
        px(3, 21, 9, 26, "patch_green"); px(3, 21, 9, 21, "ink"); px(3, 26, 9, 26, "ink")
        # Hand-painted lamp, center: handle, brass cap, glass, brass base, outlined in Ink.
        px(13, 4, 18, 5, "ink"); px(12, 5, 13, 8, "ink"); px(18, 5, 19, 8, "ink")   # handle loop
        px(10, 8, 21, 10, "ink"); px(11, 9, 20, 10, "brass")                           # cap
        px(9, 11, 22, 22, "ink"); px(10, 11, 21, 21, "glow")                           # glass
        px(13, 13, 14, 17, "chalk")                                                    # shine
        px(18, 15, 20, 20, "brass")
        px(10, 22, 21, 25, "ink"); px(11, 22, 20, 24, "brass")                         # base
        # Front placket 16x32 at (16,0): lighter red panel, ink edges, brass zip, brass pull.
        fx, fy = half + 16, 0
        d.rectangle([fx, fy, fx + 15, fy + 31], fill=table["jacket"])
        d.rectangle([fx + 3, fy, fx + 12, fy + 31], fill=table["jacket_hi"])
        d.line([(fx + 3, fy), (fx + 3, fy + 31)], fill=table["ink"])
        d.line([(fx + 12, fy), (fx + 12, fy + 31)], fill=table["ink"])
        for row in range(0, 32):
            d.rectangle([fx + 7, fy + row, fx + 8, fy + row], fill=table["brass"] if row % 2 == 0 else table["ink"])
        d.rectangle([fx + 5, fy + 13, fx + 10, fy + 18], fill=table["ink"])
        d.rectangle([fx + 6, fy + 14, fx + 9, fy + 17], fill=table["brass"])
        # Chest patch 16x16 at (0,16): mustard square, ink border and a little lamp.
        cx, cy = half, 16
        d.rectangle([cx, cy, cx + 15, cy + 15], fill=table["jacket"])
        d.rectangle([cx + 2, cy + 2, cx + 13, cy + 13], fill=table["ink"])
        d.rectangle([cx + 3, cy + 3, cx + 12, cy + 12], fill=table["mustard"])
        d.rectangle([cx + 6, cy + 5, cx + 9, cy + 6], fill=table["ink"])
        d.rectangle([cx + 6, cy + 7, cx + 9, cy + 10], fill=table["glow"])
        d.rectangle([cx + 6, cy + 11, cx + 9, cy + 11], fill=table["ink"])
    img.save(SWATCH_PATH)


def paint_face():
    """Face sheet 128x64, 32x32 cells, transparent background. Row 0: eye cells. Row 1: nose and
    mouth cells. Column 0: neutral. Column 1: grin."""
    img = Image.new("RGBA", (FACE_W, FACE_H), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    ink = LIT["ink"] + (255,)
    chalk = LIT["chalk"] + (255,)
    red = LIT["jacket"] + (255,)

    def cell(col, row):
        return col * 32, row * 32

    # Neutral eye: tall oval with a shine, a short brow dash (inner end a little lower).
    ox, oy = cell(0, 0)
    d.ellipse([ox + 9, oy + 6, ox + 23, oy + 29], fill=ink)
    d.rectangle([ox + 12, oy + 10, ox + 15, oy + 15], fill=chalk)
    d.rectangle([ox + 17, oy + 19, ox + 18, oy + 21], fill=chalk)
    d.line([(ox + 8, oy + 3), (ox + 14, oy + 1), (ox + 22, oy + 2)], fill=ink, width=2)
    # Grin eye: a happy arch, raised brow.
    ox, oy = cell(1, 0)
    d.line([(ox + 8, oy + 22), (ox + 11, oy + 15), (ox + 16, oy + 12), (ox + 21, oy + 15), (ox + 24, oy + 22)], fill=ink, width=3)
    d.line([(ox + 8, oy + 5), (ox + 15, oy + 2), (ox + 23, oy + 4)], fill=ink, width=2)
    # Neutral mouth cell: nose and a small "w".
    ox, oy = cell(0, 1)
    d.ellipse([ox + 10, oy + 2, ox + 21, oy + 9], fill=ink)
    d.rectangle([ox + 12, oy + 3, ox + 13, oy + 4], fill=chalk)
    d.line([(ox + 16, oy + 9), (ox + 16, oy + 13)], fill=ink, width=2)
    d.line([(ox + 7, oy + 14), (ox + 11, oy + 18), (ox + 16, oy + 14), (ox + 21, oy + 18), (ox + 25, oy + 14)], fill=ink, width=2)
    # Grin mouth cell: nose and a wide open smile with teeth and tongue.
    ox, oy = cell(1, 1)
    d.ellipse([ox + 10, oy + 2, ox + 21, oy + 9], fill=ink)
    d.rectangle([ox + 12, oy + 3, ox + 13, oy + 4], fill=chalk)
    d.pieslice([ox + 5, oy + 5, ox + 27, oy + 29], 0, 180, fill=ink)
    d.rectangle([ox + 8, oy + 17, ox + 24, oy + 19], fill=chalk)
    d.ellipse([ox + 11, oy + 22, ox + 21, oy + 27], fill=red)
    d.rectangle([ox + 9, oy + 28, ox + 23, oy + 29], fill=(0, 0, 0, 0))
    img.save(FACE_PATH)


def face_rect(col, row, mirror=False):
    u0, u1 = col * 32 / FACE_W, (col + 1) * 32 / FACE_W
    v1 = 1.0 - row * 32 / FACE_H
    v0 = 1.0 - (row + 1) * 32 / FACE_H
    return (u1, v0, u0, v1) if mirror else (u0, v0, u1, v1)


# ---------------------------------------------------------------- the model
# Layout (meters). Red faces -Y; her right is -X (up-ear, sword); her left is +X (flop-ear, lamp).
HEAD_C = (0.0, 0.0, 0.74)
HEAD_R = (0.265, 0.235, 0.26)
MUZZLE_Y0, MUZZLE_Y1, MUZZLE_Z = -0.14, -0.30, 0.655
SHOULDER_R, SHOULDER_L = (-0.19, 0.0, 0.46), (0.19, 0.0, 0.46)
HAND_R, HAND_L = (-0.325, -0.12, 0.385), (0.225, -0.20, 0.36)
SWORD_DIR = Vector((-0.20, 0.30, 0.55)).normalized()

ELBOW_R = tuple((a + b) / 2 for a, b in zip(SHOULDER_R, HAND_R))
ELBOW_L = tuple((a + b) / 2 for a, b in zip(SHOULDER_L, HAND_L))
JOINTS = {
    "root": ((0, 0, 0), (0, 0, 0.05)),
    "hips": ((0, 0, 0.20), (0, 0, 0.30)),
    "spine": ((0, 0, 0.30), (0, 0, 0.50)),
    "head": ((0, 0, 0.50), (0, 0, 0.98)),
    "ear_r": ((-0.14, 0, 0.95), (-0.17, 0, 1.17)),
    "ear_l": ((0.22, 0, 0.93), (0.29, 0, 0.64)),
    "tail": ((0, 0.27, 0.19), (0, 0.40, 0.31)),
    "upper_arm_r": (SHOULDER_R, ELBOW_R),
    "forearm_r": (ELBOW_R, HAND_R),
    "upper_arm_l": (SHOULDER_L, ELBOW_L),
    "forearm_l": (ELBOW_L, HAND_L),
    "thigh_r": ((-0.10, 0, 0.20), (-0.10, 0, 0.15)),
    "shin_r": ((-0.10, 0, 0.15), (-0.10, 0, 0.03)),
    "thigh_l": ((0.10, 0, 0.20), (0.10, 0, 0.15)),
    "shin_l": ((0.10, 0, 0.15), (0.10, 0, 0.03)),
    "weapon_socket": (HAND_R, (HAND_R[0] - 0.02, HAND_R[1] + 0.03, HAND_R[2] + 0.06)),
    "prop_socket": (HAND_L, (HAND_L[0], HAND_L[1], HAND_L[2] + 0.06)),
}


def add_head(pm, uv, outline=True):
    pm.add("head", SLOT_CEL, "ell", center=HEAD_C, uv=uv, outline=outline, seg=10, rings=5, radii=HEAD_R)


def add_jacket(pm, outline=True):
    """A bell, narrow shoulders and a wide hem (two stacked cones), facets turned so a flat panel
    faces front and back."""
    pm.tube("spine", SLOT_CEL, (0, 0.0, 0.16), (0, 0.0, 0.34), 0.32, 0.25, seg=8, sxy=(1.0, 0.9),
            uv=jacket_uv, outline=outline, drop_caps=("start", "end"), spin=22.5)
    pm.tube("spine", SLOT_CEL, (0, 0.0, 0.34), (0, 0.0, 0.53), 0.25, 0.165, seg=8, sxy=(1.0, 0.9),
            uv=jacket_uv, outline=outline, drop_caps=("start", "end"), spin=22.5)


def build_body():
    pm = PartMesh(NAME + "_body", [MAT_CEL, MAT_OUTLINE, MAT_FACE], hull_slot=SLOT_OUTLINE)
    U = swatch_uv_for

    # Head, muzzle (a drum with a flat front, so the nose/mouth decal sits flush), ears.
    add_head(pm, U("tawny"))
    muzzle_len = abs(MUZZLE_Y1 - MUZZLE_Y0)
    pm.tube("head", SLOT_CEL, (0, MUZZLE_Y0, MUZZLE_Z), (0, MUZZLE_Y1, MUZZLE_Z), 0.115, 0.095, seg=8,
            sxy=(1.0, 0.8), uv=U("cream"), outline=True, drop_caps=("start",), spin=22.5)
    pm.add("ear_r", SLOT_CEL, "ell", center=(-0.155, 0.0, 1.05), rot=(0, -12, 0), uv=U("tawny"),
           outline=True, seg=6, rings=3, radii=(0.085, 0.05, 0.15))
    pm.add("ear_l", SLOT_CEL, "ell", center=(0.285, 0.0, 0.80), rot=(0, -16, 0), uv=U("tawny"),
           outline=True, seg=6, rings=3, radii=(0.075, 0.05, 0.145))
    # Goggles pushed up on the head: brass strap bar and two glow lenses.
    pm.add("head", SLOT_CEL, "box", center=(0.0, -0.075, 0.965), rot=(55, 0, 0), uv=U("brass"),
           outline=True, size=(0.36, 0.05, 0.05))
    for sx in (-1, 1):
        pm.add("head", SLOT_CEL, "tube", center=(0.095 * sx, -0.105, 0.955), rot=(55, 0, 0),
               uv=U("glow"), outline=True, drop_caps=("bottom",), seg=6, r0=0.062, r1=0.062,
               length=0.06, sxy=(1, 1))

    add_jacket(pm)

    # Arms: flared sleeve, fat cuff ring, tawny mitt with a thumb bump.
    def arm(side, S, H, thumb_dir, bone_up, bone_fore):
        u = (Vector(H) - Vector(S)).normalized()
        cuff_end = Vector(H) - u * 0.035
        cuff_start = Vector(H) - u * 0.085
        pm.tube(bone_up, SLOT_CEL, S, tuple(cuff_start), 0.075, 0.113, seg=6, uv=U("jacket"),
                outline=True, drop_caps=("end",))
        pm.tube(bone_fore, SLOT_CEL, tuple(cuff_start), tuple(cuff_end), 0.115, 0.115, seg=6,
                uv=U("jacket_hi"), outline=True, drop_caps=("start",))
        pm.add(bone_fore, SLOT_CEL, "ell", center=tuple(Vector(H) + u * 0.02), uv=U("tawny"),
               outline=True, seg=6, rings=3, radii=(0.085, 0.08, 0.08))
        pm.add(bone_fore, SLOT_CEL, "ell", center=tuple(Vector(H) + Vector(thumb_dir) + u * 0.0),
               uv=U("tawny"), outline=False, seg=4, rings=2, radii=(0.05, 0.05, 0.05))

    arm("r", SHOULDER_R, HAND_R, (0.05, -0.04, 0.045), "upper_arm_r", "forearm_r")
    arm("l", SHOULDER_L, HAND_L, (-0.05, -0.04, 0.045), "upper_arm_l", "forearm_l")

    # Legs: no visible thigh (the hem hides it); big tall rust boots, open top and bottom.
    for sx, side in ((-1, "r"), (1, "l")):
        x = 0.10 * sx
        pm.tube("shin_" + side, SLOT_CEL, (x, -0.04, 0.0), (x, -0.04, 0.19), 0.105, 0.095, seg=8,
                sxy=(0.9, 1.25), uv=U("rust"), outline=True, drop_caps=("start", "end"), spin=22.5)

    # Tail (short), satchel (back right hip) and the brass lamp (left hip, on the hips bone).
    pm.tube("tail", SLOT_CEL, (0.0, 0.27, 0.19), (0.0, 0.40, 0.31), 0.065, 0.025, seg=6, uv=U("tawny"),
            outline=True, drop_caps=("start",))
    pm.add("hips", SLOT_CEL, "box", center=(-0.31, 0.08, 0.26), rot=(0, 0, -8), uv=U("tan"),
           outline=True, size=(0.08, 0.15, 0.13))
    lamp = (0.355, 0.0, 0.225)
    pm.tube("hips", SLOT_CEL, (lamp[0], lamp[1], lamp[2] - 0.05), (lamp[0], lamp[1], lamp[2] + 0.05),
            0.052, 0.052, seg=6, uv=U("glow"), outline=True, drop_caps=("start",))
    pm.tube("hips", SLOT_CEL, (lamp[0], lamp[1], lamp[2] + 0.05), (lamp[0], lamp[1], lamp[2] + 0.085),
            0.062, 0.03, seg=6, uv=U("brass"), outline=True, drop_caps=("start",))
    return pm


def swatch_rect(x0, y0, x1, y1):
    """UV rect (u0, v0, u1, v1) for a pixel box in the 64x64 swatch strip (y down)."""
    return (x0 / SWATCH_PX, 1.0 - y1 / SWATCH_PX, x1 / SWATCH_PX, 1.0 - y0 / SWATCH_PX)


def add_decals(pm, head_obj, jacket_obj):
    """Eye quads sit just in front of the head surface (found by ray cast); nose/mouth quad sits
    on the flat front of the muzzle. All use the face sheet; no outline hull for these."""
    for sx in (-1, 1):
        x, z = 0.098 * sx, 0.80
        loc, normal = surface_hit(head_obj, x, z)
        assert loc is not None, "eye ray missed the head"
        pos = Vector(loc) + normal * 0.008
        basis = Vector((0, -1, 0)).rotation_difference(normal).to_matrix().to_4x4()
        pm.add("head", SLOT_FACE, "quad", center=tuple(pos), basis=basis, size=(0.135, 0.135),
               rect=face_rect(0, 0, mirror=(sx > 0)))
    pm.add("head", SLOT_FACE, "quad", center=(0.0, MUZZLE_Y1 - 0.004, MUZZLE_Z - 0.005), size=(0.17, 0.17),
           rect=face_rect(0, 1))
    # Jacket front: zip placket (two quads, one per cone) and a chest patch. They use the swatch
    # sheet (cel shaded like the jacket), so they sit in the cel slot with no outline hull.
    for (x, z, w, h, rect) in ((0.0, 0.25, 0.09, 0.17, swatch_rect(16, 16, 32, 32)),
                                (0.0, 0.43, 0.09, 0.17, swatch_rect(16, 0, 32, 16)),
                                (0.115, 0.43, 0.07, 0.07, swatch_rect(0, 16, 16, 32))):
        loc, normal = surface_hit(jacket_obj, x, z)
        assert loc is not None, "jacket ray missed"
        pos = Vector(loc) + normal * 0.006
        basis = Vector((0, -1, 0)).rotation_difference(normal).to_matrix().to_4x4()
        pm.add("spine", SLOT_CEL, "quad", center=tuple(pos), basis=basis, size=(w, h), rect=rect)


def build_sword():
    pm = PartMesh(NAME + "_sword", [MAT_CEL, MAT_OUTLINE], hull_slot=SLOT_OUTLINE)
    U = swatch_uv_for
    d = SWORD_DIR
    grip = Vector(HAND_R) + Vector((0.0, 0.0, 0.0))
    basis = Vector((0, 0, 1)).rotation_difference(d).to_matrix().to_4x4()

    def along(t):
        return tuple(grip + d * t)

    pm.add("weapon_socket", SLOT_CEL, "tube", center=along(0.0), basis=basis, uv=U("rust"),
           outline=True, seg=6, r0=0.032, r1=0.032, length=0.15, sxy=(1, 1))
    pm.add("weapon_socket", SLOT_CEL, "box", center=along(0.085), basis=basis, uv=U("brass"),
           outline=True, size=(0.17, 0.05, 0.04))
    pm.add("weapon_socket", SLOT_CEL, "box", center=along(0.40), basis=basis, uv=U("blade"),
           outline=True, size=(0.10, 0.05, 0.62), taper=0.55)
    return pm


def main():
    os.makedirs(OUT_DIR, exist_ok=True)
    bpy.ops.wm.read_factory_settings(use_empty=True)
    paint_swatch()
    paint_face()

    # Probe head (for decal placement) built from the same call as the real head.
    probe = PartMesh("probe", [MAT_CEL])
    add_head(probe, swatch_uv_for("tawny"), outline=False)
    probe_obj = probe.to_object()
    jacket_probe = PartMesh("jacket_probe", [MAT_CEL])
    add_jacket(jacket_probe, outline=False)
    jacket_obj = jacket_probe.to_object()
    body = build_body()
    add_decals(body, probe_obj, jacket_obj)
    bpy.data.objects.remove(probe_obj)
    bpy.data.objects.remove(jacket_obj)

    arm_obj = build_armature(NAME, JOINTS)
    body_obj = body.to_object()
    sword_obj = build_sword().to_object()
    mats_main = [make_material(MAT_CEL, SWATCH_PATH), make_material(MAT_OUTLINE, color=PAL["ink"]),
                 make_material(MAT_FACE, FACE_PATH, alpha=True)]
    attach(body_obj, arm_obj, mats_main)
    attach(sword_obj, arm_obj, [mats_main[0], mats_main[1]])

    cel_tris = triangle_count(body_obj, {SLOT_CEL})
    hull_tris = triangle_count(body_obj, {SLOT_OUTLINE})
    face_tris = triangle_count(body_obj, {SLOT_FACE})
    print("D body: %d cel (incl. 6 jacket decal tris) + %d hull + %d face decals = %d drawn (cap 900)" % (
        cel_tris, hull_tris, face_tris, cel_tris + hull_tris + face_tris))
    sword_tris = triangle_count(sword_obj)
    print("D sword: %d drawn (cap 150)" % sword_tris)
    export_glb(os.path.join(OUT_DIR, NAME + ".glb"))


main()
