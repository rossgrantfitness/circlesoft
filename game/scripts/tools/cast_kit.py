"""Shared helpers for the cast blockouts (Otis, Mox, the old Zero): placeholder art in the locked
Red house style (docs/decisions.md 2026-10-06; reference game/scripts/tools/prototypes/red_proto_f.py).

Not run on its own; cast_otis.py, cast_mox.py and cast_old_zero.py import it. It builds on the
Red kit (prototypes/red_proto_de_kit.py), which belongs to the Red team and is imported read-only:
PartMesh, build_armature, make_material and attach all come from there. Everything new lives here:

  * Sheet      a 128x128 body sheet of 16 px cells (lit on top, one dithered shade step, Chalk gloss
               spots on the glossy cells), the same surface handling as Red F.
  * FaceMap    maps head-front coordinates onto a 64 px face cell; the face sheet is 128x64, two cells
               (neutral left, second expression right, swap with uv_offset.x = 0.5).
  * bean()     the soft bean head (wider than tall, fuller cheeks, a dip at the top).
  * Rig + export_glb_with_clips()   a stepped (15 fps) idle clip written into the .glb, which the
               red kit's export_glb does not do (it exports no animation).

Run (Blender as a Python module, Python 3.11):
    python3 -m venv /tmp/blockout_venv
    /tmp/blockout_venv/bin/pip install bpy==5.0.1 pillow numpy
    /tmp/blockout_venv/bin/python game/scripts/tools/cast_otis.py        (and cast_mox.py, cast_old_zero.py)

House style, for the next person: mascot treatment (a big head on a storybook body, mitten hands,
chunky legs, big round glossy boots), faces painted on the face sheet, warm light shades (never grey),
no outlines, standard psx_lit materials. Wide-set short pointy ears read dog, narrow ears read cat.
"""

import math
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "prototypes"))
from red_proto_de_kit import (  # noqa: E402,F401  (bpy first, inside the kit)
    BONE_NAMES, GAME_DIR, PAL, Euler, Matrix, PartMesh, Quaternion, Vector, attach, bmesh, bpy,
    build_armature, hex_rgb, make_material, rot_matrix, triangle_count,
)
from PIL import Image, ImageDraw  # noqa: E402

CHARACTERS_DIR = os.path.join(GAME_DIR, "art", "placeholder", "characters")
BODY_PX = 128
CELL = 16
FACE_W, FACE_H = 128, 64
FACE_CELL = 64
SLOT_BODY, SLOT_FACE = 0, 1
FPS = 15
CHALK = hex_rgb("#EDEAD8")
INK = hex_rgb("#14121F")
SHADE_FROM = 0.58


# ---------------------------------------------------------------- the body sheet
class Sheet:
    """colors: name -> (lit hex, shade hex). gloss: names that also get a "<name>_gloss" cell with
    Chalk highlight spots. Cells are handed out left to right, top to bottom."""

    def __init__(self, colors, gloss=()):
        self.rgb = {k: (hex_rgb(a), hex_rgb(b)) for k, (a, b) in colors.items()}
        self.cells = {}
        self.plain_of = {}
        names = []
        for name in colors:
            names.append(name)
            if name in gloss:
                names.append(name + "_gloss")
                self.plain_of[name + "_gloss"] = name
        assert len(names) <= 64, "the sheet holds 64 cells"
        for index, name in enumerate(names):
            self.cells[name] = (index % 8, index // 8)

    def paint(self, path):
        img = Image.new("RGB", (BODY_PX, BODY_PX), INK)
        px = img.load()
        for name, (col, row) in self.cells.items():
            lit, shade = self.rgb[self.plain_of.get(name, name)]
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
            if name in self.plain_of:
                d = ImageDraw.Draw(img)
                d.rectangle([x0 + 3, y0 + 2, x0 + 6, y0 + 3], fill=CHALK)
                d.rectangle([x0 + 3, y0 + 4, x0 + 4, y0 + 6], fill=CHALK)
                d.point([(x0 + 8, y0 + 2)], fill=CHALK)
        img.save(path)
        return img

    def _uv(self, cell, fx, fy):
        col, row = self.cells[cell]
        fx = min(max(fx, 0.0), 1.0)
        fy = min(max(fy, 0.0), 1.0)
        return ((col * CELL + 1 + fx * (CELL - 2)) / BODY_PX, 1.0 - (row * CELL + 1 + fy * (CELL - 2)) / BODY_PX)

    def planar(self, cell):
        """Planar mapping over the primitive's bounding box: top reads the lit rows, bottom the shade
        rows. Glossy cells fall back to the plain color on back-facing triangles."""
        plain = self.plain_of.get(cell)

        def fn(co, n, bb):
            lo, hi = bb
            use = plain if (plain and n.y > 0.3) else cell
            return self._uv(use, (co.x - lo.x) / max(hi.x - lo.x, 1e-6), 1.0 - (co.z - lo.z) / max(hi.z - lo.z, 1e-6))
        return fn

    def planar_z(self, cell, z0, z1):
        """Like planar, but the vertical range is fixed (so a whole garment shares ONE shade step)."""
        def fn(co, n, bb):
            lo, hi = bb
            return self._uv(cell, (co.x - lo.x) / max(hi.x - lo.x, 1e-6), (z1 - co.z) / (z1 - z0))
        return fn

    def flat(self, cell):
        """One lit color, no shading: stripes, rivets, lenses."""
        def fn(co, n, bb):
            return self._uv(cell, 0.5, 0.2)
        return fn


# ---------------------------------------------------------------- heads and faces
def bean(radii):
    """Bean / kidney head deform from a squashed ball (p is already scaled to `radii`): a soft dip at
    the top, fuller cheeks at the sides and bottom, a slightly narrower brow, a gently pushed-out
    lower front for the muzzle to grow from. Same shaping as Red F's head."""
    rx, ry, rz = radii

    def fn(p):
        ux, uy, uz = p.x / rx, p.y / ry, p.z / rz
        upper = max(uz, 0.0)
        cheek = math.exp(-(((uz + 0.35) / 0.5) ** 2))
        x = p.x * (1.0 - 0.06 * upper * upper) * (1.0 + 0.15 * cheek)
        y = p.y * (1.0 + 0.05 * cheek) - 0.012 * max(-uy, 0.0) * cheek
        z = p.z - 0.20 * rz * math.exp(-((ux / 0.34) ** 2)) * upper ** 3
        return Vector((x, y, z))
    return fn


class FaceMap:
    """Front-of-head coordinates (x, z in model units, head-local) <-> pixels of a 64 px face cell."""

    def __init__(self, center_z, x_half, z_half):
        self.cz, self.xh, self.zh = center_z, x_half, z_half
        self.z_top = center_z + z_half
        self.z_bot = center_z - z_half

    def uv(self, co):
        px = min(max((co.x + self.xh) / (2 * self.xh), 0.0), 1.0) * (FACE_CELL - 1) + 0.5
        py = min(max((self.z_top - co.z) / (self.z_top - self.z_bot), 0.0), 1.0) * (FACE_CELL - 1) + 0.5
        return (px / FACE_W, 1.0 - py / FACE_H)

    def pixel(self, cell, x, z):
        px = (x + self.xh) / (2 * self.xh) * (FACE_CELL - 1)
        py = (self.z_top - z) / (self.z_top - self.z_bot) * (FACE_CELL - 1)
        return cell * FACE_CELL + px, py

    def box(self, cell, x0, z0, x1, z1):
        """Pixel rectangle [a0, b0, a1, b1] (PIL order) for a model-space box."""
        a0, b0 = self.pixel(cell, min(x0, x1), max(z0, z1))
        a1, b1 = self.pixel(cell, max(x0, x1), min(z0, z1))
        return [a0, b0, a1, b1]


def paint_face_background(img, fm, cell, fur, fur_shade):
    """The two-tone fur ground for one face cell (lit above the step, shade below, dithered edge)."""
    step_row = int(round(SHADE_FROM * FACE_CELL))
    for y in range(FACE_CELL):
        for x in range(FACE_CELL):
            c = fur if y < step_row else (fur if (x + y) % 2 == 0 and y == step_row else fur_shade)
            img.putpixel((cell * FACE_CELL + x, y), c)
    return step_row


def shade_pass(img, cell, step_row, pairs):
    """Below the shade step, swap each lit color for its shade color (warm shade, never grey)."""
    for y in range(step_row + 1, FACE_CELL):
        for x in range(FACE_CELL):
            here = img.getpixel((cell * FACE_CELL + x, y))
            for lit, shade in pairs:
                if here == lit:
                    img.putpixel((cell * FACE_CELL + x, y), shade)


def head_uv_factory(sheet, face_map, fur_cell, under_cell):
    """UV rule for a head ball: front-facing triangles carry the face sheet, the under-jaw reads the
    under cell (cream, gray), everything else a vertical strip of the fur cell."""
    col, row = sheet.cells[fur_cell]

    def fn(co, n, bb):
        if n.y < -0.30:
            return face_map.uv(co)
        if under_cell and n.z < -0.45 and n.y < 0.1:
            return sheet.planar(under_cell)(co, n, bb)
        fy = (face_map.z_top - co.z) / (face_map.z_top - face_map.z_bot)
        return ((col * CELL + 8) / BODY_PX, 1.0 - (row * CELL + 1 + min(max(fy, 0.0), 1.0) * (CELL - 2)) / BODY_PX)
    return fn


def head_slot(n):
    return SLOT_FACE if n.y < -0.30 else SLOT_BODY


def muzzle_slot(n):
    return SLOT_FACE if n.y < -0.95 else SLOT_BODY      # only the flat front cap


def muzzle_uv_factory(sheet, face_map, cell):
    def fn(co, n, bb):
        if n.y < -0.95:
            return face_map.uv(co)
        return sheet.planar(cell)(co, n, bb)
    return fn


# ---------------------------------------------------------------- animation
class Rig:
    """Posing helper: rotate / move a bone about the ARMATURE's axes (so the poses do not depend on how
    each bone happens to be oriented). Positive x tips things above the joint toward -Y (forward)."""

    def __init__(self, arm_obj):
        self.obj = arm_obj
        self.rest3 = {b.name: b.matrix_local.to_3x3() for b in arm_obj.data.bones}
        for pb in arm_obj.pose.bones:
            pb.rotation_mode = "QUATERNION"

    def reset(self):
        for pb in self.obj.pose.bones:
            pb.rotation_quaternion = Quaternion((1, 0, 0, 0))
            pb.location = Vector((0, 0, 0))

    def rotate(self, bone, x=0.0, y=0.0, z=0.0):
        world = Euler((math.radians(x), math.radians(y), math.radians(z)), "XYZ").to_matrix()
        rest = self.rest3[bone]
        self.obj.pose.bones[bone].rotation_quaternion = (rest.inverted() @ world @ rest).to_quaternion()

    def move(self, bone, x=0.0, y=0.0, z=0.0):
        self.obj.pose.bones[bone].location = self.rest3[bone].inverted() @ Vector((x, y, z))

    def key(self, frame):
        for pb in self.obj.pose.bones:
            pb.keyframe_insert("rotation_quaternion", frame=frame)
            pb.keyframe_insert("location", frame=frame)


def idle_pose(rig, t, bounce=0.014, nod=2.0, sway=6.0, arm=2.5, ear=0.0, tail_axis="z"):
    """One breath of a gentle idle, t in 0..1 around the loop. The whole body squashes down and stretches
    up once per loop (the "gentle bounce"), the head nods a beat behind, the tail sways and the arms
    swing a little the other way. npc.gd adds its own slow whole-body bob on top; this one is the
    character's own breathing, so no root translation here."""
    s = math.sin(2 * math.pi * t)
    c = math.cos(2 * math.pi * t)
    lag = math.sin(2 * math.pi * (t - 0.12))
    rig.move("hips", z=bounce * (0.5 - 0.5 * math.cos(2 * math.pi * t * 2)))
    rig.rotate("spine", x=1.0 * s)
    rig.rotate("head", x=nod * lag, z=1.2 * c)
    rig.rotate("tail", z=sway * s)
    rig.rotate("upper_arm_l", x=arm * lag, y=-1.5 * (0.5 + 0.5 * s))
    rig.rotate("upper_arm_r", x=-arm * lag, y=1.5 * (0.5 + 0.5 * s))
    if ear:
        flick = max(0.0, math.sin(2 * math.pi * (t * 1.0 - 0.55)) ** 7)
        rig.rotate("ear_l", y=-ear * flick)
        rig.rotate("ear_r", y=ear * flick)


def build_idle(arm_obj, frames=22, step=2, **pose_args):
    """One looping `idle` action, keyed every `step` frames (15 fps, stepped: no smoothing), exported as
    an NLA track so the .glb carries a clip named exactly "idle"."""
    scene = bpy.context.scene
    scene.render.fps = FPS
    bpy.context.preferences.edit.keyframe_new_interpolation_type = "CONSTANT"
    rig = Rig(arm_obj)
    anim = arm_obj.animation_data_create()
    action = bpy.data.actions.new("idle")
    action.use_fake_user = True
    anim.action = action
    for frame in list(range(0, frames, step)) + [frames]:
        t = 0.0 if frame == frames else frame / frames
        idle_pose(rig, t, **pose_args)
        rig.key(frame)
    anim.action = None
    track = anim.nla_tracks.new()
    track.name = "idle"
    strip = track.strips.new("idle", 0, action)
    strip.name = "idle"
    rig.reset()
    return action


def export_glb_with_clips(path):
    bpy.context.scene.frame_start = 0
    bpy.ops.export_scene.gltf(
        filepath=path, export_format="GLB", export_yup=True, export_apply=False,
        export_skins=True, export_animations=True, export_animation_mode="NLA_TRACKS",
        export_force_sampling=False, export_optimize_animation_size=False,
        export_image_format="AUTO", export_materials="EXPORT", export_cameras=False,
        export_lights=False, export_extras=False,
    )
    print("wrote", path)


# ---------------------------------------------------------------- common geometry helpers
def ball_chain(pm, bone, cell_uv, pts, radii_list, seg=6, rings=4):
    """A string of overlapping ellipsoids along points (tails)."""
    for i in range(len(pts) - 1):
        a, b = Vector(pts[i]), Vector(pts[i + 1])
        mid = (a + b) / 2
        direction = (b - a).normalized()
        basis = Vector((0, 0, 1)).rotation_difference(direction).to_matrix().to_4x4()
        r = radii_list[i]
        pm.add(bone, SLOT_BODY, "ell", center=tuple(mid), basis=basis, uv=cell_uv, seg=seg, rings=rings,
               radii=(r, r, (b - a).length / 2 + r * 0.6))


def finish(name, folder, mesh_parts, mats_paths, joints, idle_args=None):
    """Builds armature + meshes + materials, writes the idle clip and exports the .glb.
    mesh_parts: list of (PartMesh, [material indices used]); mats_paths: [(material name, png path)]."""
    out_dir = os.path.join(CHARACTERS_DIR, folder)
    os.makedirs(out_dir, exist_ok=True)
    arm = build_armature(name, joints)
    mats = [make_material(n, p) for n, p in mats_paths]
    for pm, slots in mesh_parts:
        obj = pm.to_object()
        attach(obj, arm, [mats[i] for i in slots])
        print("%s: %d tris" % (obj.name, triangle_count(obj)))
    build_idle(arm, **(idle_args or {}))
    export_glb_with_clips(os.path.join(out_dir, name + ".glb"))
