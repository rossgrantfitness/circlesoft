"""Shared helpers for the battle enemy blockouts (Signals grunt, Signals drone and their variants):
placeholder art in the locked Red house style (docs/decisions.md 2026-10-06).

Not run on its own; enemy_signals_grunt.py and enemy_signals_drone.py import it. It sits on top of the
cast kit (cast_kit.py, which sits on prototypes/red_proto_de_kit.py); both belong to other owners and are
imported read-only. New here:

  * finish_enemy()    like cast_kit.finish() but writes to game/art/placeholder/enemies/<folder>/ and takes
                      any idle-clip builder (the grunt uses the shared 17-bone rig and cast_kit's idle,
                      the drone has 4 bones and its own hover idle).
  * build_small_rig() a small armature (the drone's 4 bones); build_armature() insists on the 17 shared
                      bones, so small enemies get their own.
  * SmallSheet        a 64x64 body sheet of 16 px cells (small enemies, style guide: 64x64), with some cells
                      left free for a painted plate (the Signals symbol).
  * paint_signals_symbol()   the Signals Corps mark: a wavy line cut by one slash.

Run (Blender as a Python module, Python 3.11):
    python3 -m venv /tmp/blockout_venv
    /tmp/blockout_venv/bin/pip install bpy==5.0.1 pillow numpy
    /tmp/blockout_venv/bin/python game/scripts/tools/enemy_signals_grunt.py
    /tmp/blockout_venv/bin/python game/scripts/tools/enemy_signals_drone.py

House style, same as the cast: mascot proportions, painted faces, one dithered shade step per cell, warm
light shades, no outlines, standard psx_lit materials. Hegemony and Signals things are never amber; status
lights are cold pink-red #E8456A (style guide palette).
"""

import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from cast_kit import *  # noqa: E402,F403
import cast_kit  # noqa: E402

ENEMIES_DIR = os.path.join(GAME_DIR, "art", "placeholder", "enemies")
SMALL_PX = 64
SMALL_CELL = 16


# ---------------------------------------------------------------- small body sheet
class SmallSheet(Sheet):
    """A 64x64 sheet (4x4 cells of 16 px). `reserved` cells (col, row) are left untouched so a plate can be
    painted there afterwards; every other cell is handed out left to right, top to bottom."""

    def __init__(self, colors, gloss=(), reserved=()):
        self.rgb = {k: (hex_rgb(a), hex_rgb(b)) for k, (a, b) in colors.items()}
        self.cells = {}
        self.plain_of = {}
        self.reserved = list(reserved)
        names = []
        for name in colors:
            names.append(name)
            if name in gloss:
                names.append(name + "_gloss")
                self.plain_of[name + "_gloss"] = name
        free = [(c, r) for r in range(4) for c in range(4) if (c, r) not in self.reserved]
        assert len(names) <= len(free), "the 64x64 sheet holds %d free cells" % len(free)
        for name, cell in zip(names, free):
            self.cells[name] = cell

    def paint(self, path):
        img = Image.new("RGB", (SMALL_PX, SMALL_PX), INK)
        for name, (col, row) in self.cells.items():
            lit, shade = self.rgb[self.plain_of.get(name, name)]
            x0, y0 = col * SMALL_CELL, row * SMALL_CELL
            for y in range(SMALL_CELL):
                for x in range(SMALL_CELL):
                    if y < 9:
                        c = lit
                    elif y == 9:
                        c = lit if (x + y) % 2 == 0 else shade
                    else:
                        c = shade
                    img.putpixel((x0 + x, y0 + y), c)
            if name in self.plain_of:
                d = ImageDraw.Draw(img)
                d.rectangle([x0 + 3, y0 + 2, x0 + 6, y0 + 3], fill=CHALK)
                d.rectangle([x0 + 3, y0 + 4, x0 + 4, y0 + 6], fill=CHALK)
                d.point([(x0 + 8, y0 + 2)], fill=CHALK)
        self.image = img
        img.save(path)
        return img

    def _uv(self, cell, fx, fy):
        col, row = self.cells[cell]
        fx = min(max(fx, 0.0), 1.0)
        fy = min(max(fy, 0.0), 1.0)
        return ((col * SMALL_CELL + 1 + fx * (SMALL_CELL - 2)) / SMALL_PX,
                1.0 - (row * SMALL_CELL + 1 + fy * (SMALL_CELL - 2)) / SMALL_PX)


def plate_uv(origin_px, size_px, center, half_x, half_z):
    """UV rule for a flat plate facing -Y: maps (x, z) around `center` (model units, plate-local x and world z)
    onto a size_px square painted at origin_px of the 64 px sheet. Returns a function for PartMesh uv=."""
    cx, cz = center

    def fn(co, n, bb):
        fx = min(max((co.x - cx + half_x) / (2 * half_x), 0.0), 1.0)
        fy = min(max((cz + half_z - co.z) / (2 * half_z), 0.0), 1.0)
        px = origin_px[0] + 0.5 + fx * (size_px - 1)
        py = origin_px[1] + 0.5 + fy * (size_px - 1)
        return (px / SMALL_PX, 1.0 - py / SMALL_PX)
    return fn


def paint_signals_symbol(img, origin_px, size_px, bg, ink, line, slash):
    """The Signals Corps mark on a square plate: a wavy line (a signal) cut by one diagonal slash (no
    signal). Hegemony uses a white ring with a bar; the Signals Corps wave is its own."""
    d = ImageDraw.Draw(img)
    x0, y0 = origin_px
    d.rectangle([x0, y0, x0 + size_px - 1, y0 + size_px - 1], fill=bg)
    d.rectangle([x0, y0, x0 + size_px - 1, y0 + size_px - 1], outline=ink, width=2)
    pts = []
    steps = 24
    for i in range(steps + 1):
        t = i / steps
        px = x0 + 4 + t * (size_px - 8)
        py = y0 + size_px / 2 + math.sin(t * math.pi * 3.0) * (size_px * 0.17)
        pts.append((px, py))
    d.line(pts, fill=line, width=3)
    d.line([(x0 + size_px - 6, y0 + 5), (x0 + 6, y0 + size_px - 6)], fill=ink, width=5)
    d.line([(x0 + size_px - 6, y0 + 5), (x0 + 6, y0 + size_px - 6)], fill=slash, width=3)
    return img


# ---------------------------------------------------------------- a small rig
def build_small_rig(name, joints, parents):
    """joints: bone -> (head xyz, tail xyz); parents: bone -> parent bone or None. Like build_armature but
    without the 17 shared bones (small enemies have 4)."""
    data = bpy.data.armatures.new(name + "_rig")
    obj = bpy.data.objects.new(name, data)
    bpy.context.collection.objects.link(obj)
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    bpy.ops.object.mode_set(mode="EDIT")
    edit = {}
    for bone_name, (head, tail) in joints.items():
        bone = data.edit_bones.new(bone_name)
        bone.head = Vector(head)
        bone.tail = Vector(tail)
        bone.roll = 0.0
        edit[bone_name] = bone
    for bone_name, parent in parents.items():
        if parent:
            edit[bone_name].parent = edit[parent]
    bpy.ops.object.mode_set(mode="OBJECT")
    return obj


def build_clip(arm_obj, name, frames, step, pose_fn):
    """One looping clip named `name`, keyed every `step` frames at 15 fps, stepped (no smoothing), exported as
    an NLA track so the .glb carries a clip with exactly that name. pose_fn(rig, t, index) poses the rig."""
    scene = bpy.context.scene
    scene.render.fps = FPS
    bpy.context.preferences.edit.keyframe_new_interpolation_type = "CONSTANT"
    rig = Rig(arm_obj)
    anim = arm_obj.animation_data_create()
    action = bpy.data.actions.new(name)
    action.use_fake_user = True
    anim.action = action
    for index, frame in enumerate(list(range(0, frames, step)) + [frames]):
        t = 0.0 if frame == frames else frame / frames
        rig.reset()
        pose_fn(rig, t, index if frame != frames else 0)
        rig.key(frame)
    anim.action = None
    track = anim.nla_tracks.new()
    track.name = name
    strip = track.strips.new(name, 0, action)
    strip.name = name
    rig.reset()
    return action


def finish_enemy(name, folder, mesh_parts, mats_paths, arm, clip_builder):
    """Attaches the meshes to the armature, adds the idle clip, exports game/art/placeholder/enemies/<folder>/<name>.glb
    and prints the triangle counts. mesh_parts: [(PartMesh, [material indices used])]."""
    out_dir = os.path.join(ENEMIES_DIR, folder)
    os.makedirs(out_dir, exist_ok=True)
    mats = [make_material(n, p) for n, p in mats_paths]
    total = 0
    for pm, slots in mesh_parts:
        obj = pm.to_object()
        attach(obj, arm, [mats[i] for i in slots])
        tris = triangle_count(obj)
        total += tris
        print("%s: %d tris" % (obj.name, tris))
    print("%s TOTAL: %d tris" % (name, total))
    clip_builder(arm)
    export_glb_with_clips(os.path.join(out_dir, name + ".glb"))
    return total
