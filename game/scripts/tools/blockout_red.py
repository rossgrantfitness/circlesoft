"""Builds the placeholder Red: a ~300-triangle chibi blockout with a 17-bone rig and
idle / walk / run animations, plus its 128 px texture, and exports a .glb.

Placeholder only (docs/style_guide.md "placeholder rule"): made from boxes and one sphere.
Ross's final Red replaces game/art/placeholder/characters/red/red_blockout.glb.

Run it (Blender as a Python module, no GUI; Python 3.11):
    python3 -m venv /tmp/blockout_venv
    /tmp/blockout_venv/bin/pip install bpy==5.0.1 pillow numpy
    /tmp/blockout_venv/bin/python game/scripts/tools/blockout_red.py
Blender's desktop app works too:
    blender --background --python game/scripts/tools/blockout_red.py

Output (next to this file's project root, game/art/placeholder/characters/red/):
    red_blockout.glb   model + skeleton + animations + embedded texture
    red_blockout.png   the 128x128 texture (source copy; the .glb carries its own)

Conventions (docs/tech_plan.md "Art conventions"): 1 unit = 1 m, origin at the feet, the
model faces Blender -Y (Godot +Z), Y-up glTF export, base-color-only material `mat_red_blockout`,
flat shading, rigid skinning (every vertex follows exactly one bone), 15 fps stepped animation.
"""

import math
import os
import sys

import bpy  # must come before bmesh / mathutils
import bmesh
from mathutils import Euler, Matrix, Quaternion, Vector
from PIL import Image, ImageDraw

# ---------------------------------------------------------------- settings
MODEL_NAME = "red_blockout"
MATERIAL_NAME = "mat_red_blockout"
TEXTURE_SIZE = 128
FACE_REGION_PX = 64          # the painted face sits in the top-left 64x64 of the texture
SWATCH_PX = 16               # flat color swatches elsewhere
FPS = 15                     # stepped animation rate (style guide)
HEAD_SPHERE_SEGMENTS = 8
HEAD_SPHERE_RINGS = 5
FACE_NORMAL_Y = -0.55        # head triangles facing this far forward get the painted face

# Master palette + Red's own colors (docs/style_guide.md).
PALETTE = {
    "tawny": "#C98A45",
    "tawny_shade": "#A96B2F",
    "cream": "#F4E4C1",
    "jacket": "#C8322A",
    "jacket_shade": "#8E2420",
    "brass": "#D9A441",
    "ink": "#14121F",
    "slate_light": "#8D97A5",
    "slate": "#5B6573",
    "chalk": "#EDEAD8",
    "dusk": "#3A3566",
}
SWATCH_ORDER = ["tawny", "tawny_shade", "cream", "jacket", "jacket_shade", "brass", "ink",
                "slate_light", "slate", "chalk", "dusk"]

# ---------------------------------------------------------------- paths
HERE = os.path.dirname(os.path.abspath(__file__))
PROJECT_GAME_DIR = os.path.abspath(os.path.join(HERE, "..", ".."))
OUT_DIR = os.path.join(PROJECT_GAME_DIR, "art", "placeholder", "characters", "red")
GLB_PATH = os.path.join(OUT_DIR, MODEL_NAME + ".glb")
PNG_PATH = os.path.join(OUT_DIR, MODEL_NAME + ".png")


def hex_rgb(value):
    return tuple(int(value[i:i + 2], 16) for i in (1, 3, 5))


def swatch_uv(name):
    """UV at the center of a flat color swatch (swatches fill the texture outside the face)."""
    cells_per_row = TEXTURE_SIZE // SWATCH_PX
    face_cells = FACE_REGION_PX // SWATCH_PX
    placed = 0
    for row in range(cells_per_row):
        for col in range(cells_per_row):
            if row < face_cells and col < face_cells:
                continue
            if SWATCH_ORDER[placed] == name:
                px = col * SWATCH_PX + SWATCH_PX // 2
                py = row * SWATCH_PX + SWATCH_PX // 2
                return (px / TEXTURE_SIZE, 1.0 - py / TEXTURE_SIZE)
            placed += 1
            if placed >= len(SWATCH_ORDER):
                raise KeyError(name)
    raise KeyError(name)


# ---------------------------------------------------------------- texture
def paint_texture():
    img = Image.new("RGB", (TEXTURE_SIZE, TEXTURE_SIZE), hex_rgb(PALETTE["ink"]))
    draw = ImageDraw.Draw(img)
    # Swatches.
    cells_per_row = TEXTURE_SIZE // SWATCH_PX
    face_cells = FACE_REGION_PX // SWATCH_PX
    placed = 0
    for row in range(cells_per_row):
        for col in range(cells_per_row):
            if row < face_cells and col < face_cells:
                continue
            if placed < len(SWATCH_ORDER):
                color = hex_rgb(PALETTE[SWATCH_ORDER[placed]])
                x0, y0 = col * SWATCH_PX, row * SWATCH_PX
                draw.rectangle([x0, y0, x0 + SWATCH_PX - 1, y0 + SWATCH_PX - 1], fill=color)
                placed += 1
    # Face: planar front view of the head, 64x64. Two shades of fur, big dark eyes with a
    # highlight, brass goggle strap across the forehead, a small mouth.
    tawny = hex_rgb(PALETTE["tawny"])
    shade = hex_rgb(PALETTE["tawny_shade"])
    cream = hex_rgb(PALETTE["cream"])
    ink = hex_rgb(PALETTE["ink"])
    brass = hex_rgb(PALETTE["brass"])
    chalk = hex_rgb(PALETTE["chalk"])
    s = FACE_REGION_PX
    draw.rectangle([0, 0, s - 1, s - 1], fill=tawny)
    draw.rectangle([0, 0, s - 1, 3], fill=shade)                      # top of head shade
    draw.rectangle([0, 11, s - 1, 16], fill=brass)                    # goggle strap
    draw.rectangle([0, 16, s - 1, 16], fill=ink)
    draw.ellipse([18, 38, 46, 62], fill=cream)                        # muzzle patch
    for cx in (18, 46):                                                # eyes
        draw.ellipse([cx - 6, 22, cx + 6, 40], fill=ink)
        draw.rectangle([cx - 3, 25, cx - 1, 28], fill=chalk)
    draw.rectangle([30, 44, 33, 46], fill=ink)                        # nose
    draw.line([(32, 47), (32, 50)], fill=ink)
    draw.line([(28, 51), (32, 51)], fill=ink)
    draw.line([(32, 51), (36, 51)], fill=ink)
    img.save(PNG_PATH)
    return PNG_PATH


# ---------------------------------------------------------------- geometry
# Every primitive is (bone name, bmesh geometry). Face colors come from (main, shade) swatch names.
class Builder:
    def __init__(self):
        self.bm = bmesh.new()
        self.uv_layer = self.bm.loops.layers.uv.new("UVMap")
        self.deform = self.bm.verts.layers.deform.new()
        self.bone_groups = {}   # bone name -> vertex group index
        self.face_info = []

    def group_index(self, bone):
        if bone not in self.bone_groups:
            self.bone_groups[bone] = len(self.bone_groups)
        return self.bone_groups[bone]

    def _finish(self, geom, bone, main, shade):
        verts = [g for g in geom if isinstance(g, bmesh.types.BMVert)]
        faces = [g for g in geom if isinstance(g, bmesh.types.BMFace)]
        index = self.group_index(bone)
        for v in verts:
            v[self.deform][index] = 1.0
        main_uv, shade_uv = swatch_uv(main), swatch_uv(shade)
        for f in faces:
            f.smooth = False
            uv = shade_uv if f.normal.z < -0.5 else main_uv
            for loop in f.loops:
                loop[self.uv_layer].uv = uv
        return faces

    def box(self, bone, center, size, main, shade=None, taper=1.0, rotate=None, pivot=None):
        """Box of `size` (x, y, z) centered at `center`. taper < 1 narrows the top (x and y)."""
        shade = shade or main
        res = bmesh.ops.create_cube(self.bm, size=1.0)
        verts = res["verts"]
        for v in verts:
            top = v.co.z > 0
            v.co = Vector((v.co.x * size[0] * (taper if top else 1.0),
                           v.co.y * size[1] * (taper if top else 1.0),
                           v.co.z * size[2]))
        self._place(verts, center, rotate, pivot)
        faces = list({f for v in verts for f in v.link_faces})
        self.bm.normal_update()
        return self._finish(verts + faces, bone, main, shade)

    def _place(self, verts, center, rotate, pivot):
        if rotate is not None:
            rot = Euler([math.radians(a) for a in rotate], "XYZ").to_matrix()
            for v in verts:
                v.co = rot @ v.co
        for v in verts:
            v.co += Vector(center)
        if pivot is not None:
            pass

    def head(self, bone, center, radii, main):
        res = bmesh.ops.create_uvsphere(self.bm, u_segments=HEAD_SPHERE_SEGMENTS,
                                        v_segments=HEAD_SPHERE_RINGS, radius=1.0)
        verts = res["verts"]
        for v in verts:
            v.co = Vector((v.co.x * radii[0], v.co.y * radii[1], v.co.z * radii[2])) + Vector(center)
        faces = list({f for v in verts for f in v.link_faces})
        self.bm.normal_update()
        index = self.group_index(bone)
        for v in verts:
            v[self.deform][index] = 1.0
        fur_uv = swatch_uv(main)
        face_px = FACE_REGION_PX / TEXTURE_SIZE
        for f in faces:
            f.smooth = False
            if f.normal.y < FACE_NORMAL_Y:
                # painted face: planar front projection into the 64x64 region
                for loop in f.loops:
                    p = loop.vert.co - Vector(center)
                    u = 0.5 + 0.5 * p.x / radii[0]
                    # Blender -Y faces the viewer; the character's left (+X) is on the viewer's
                    # right, so x increases to the right.
                    u = 0.5 - 0.5 * p.x / radii[0]
                    v = 0.5 + 0.5 * p.z / radii[2]
                    loop[self.uv_layer].uv = (u * face_px, 1.0 - face_px + v * face_px)
            else:
                for loop in f.loops:
                    loop[self.uv_layer].uv = fur_uv
        return faces

    def to_object(self, name):
        bmesh.ops.triangulate(self.bm, faces=self.bm.faces[:])
        mesh = bpy.data.meshes.new(name)
        self.bm.to_mesh(mesh)
        obj = bpy.data.objects.new(name, mesh)
        bpy.context.collection.objects.link(obj)
        for bone, index in sorted(self.bone_groups.items(), key=lambda kv: kv[1]):
            obj.vertex_groups.new(name=bone)
        # vertex groups were created in index order, matching the deform layer indices
        self.bm.free()
        return obj


# Body layout (meters). Model faces -Y; its right side is -X.
HEAD_CENTER = (0.0, 0.0, 0.72)
HEAD_RADII = (0.20, 0.17, 0.19)
BONES = {
    # name: (head, tail, parent)
    "root": ((0, 0, 0), (0, 0, 0.06), None),
    "hips": ((0, 0, 0.30), (0, 0, 0.36), "root"),
    "spine": ((0, 0, 0.36), (0, 0, 0.54), "hips"),
    "head": ((0, 0, 0.54), (0, 0, 0.90), "spine"),
    "ear_r": ((-0.09, 0, 0.82), (-0.10, 0, 1.0), "head"),
    "ear_l": ((0.16, 0, 0.84), (0.20, 0, 0.64), "head"),
    "tail": ((0, 0.12, 0.33), (0, 0.22, 0.43), "hips"),
    "upper_arm_r": ((-0.175, 0, 0.50), (-0.175, 0, 0.41), "spine"),
    "forearm_r": ((-0.175, 0, 0.41), (-0.175, 0, 0.30), "upper_arm_r"),
    "upper_arm_l": ((0.175, 0, 0.50), (0.175, 0, 0.41), "spine"),
    "forearm_l": ((0.175, 0, 0.41), (0.175, 0, 0.30), "upper_arm_l"),
    "thigh_r": ((-0.07, 0, 0.30), (-0.07, 0, 0.19), "hips"),
    "shin_r": ((-0.07, 0, 0.19), (-0.07, 0, 0.04), "thigh_r"),
    "thigh_l": ((0.07, 0, 0.30), (0.07, 0, 0.19), "hips"),
    "shin_l": ((0.07, 0, 0.19), (0.07, 0, 0.04), "thigh_l"),
    "weapon_socket": ((-0.175, -0.02, 0.28), (-0.175, -0.02, 0.33), "forearm_r"),
    "prop_socket": ((0.175, -0.02, 0.28), (0.175, -0.02, 0.33), "forearm_l"),
}


def build_mesh():
    b = Builder()
    # Head (64 tris) and muzzle.
    b.head("head", HEAD_CENTER, HEAD_RADII, "tawny")
    b.box("head", (0.0, -0.19, 0.675), (0.11, 0.09, 0.075), "cream", "cream")
    # Ears: up-ear on her right (-X), floppy ear on her left (+X).
    b.box("ear_r", (-0.095, 0.0, 0.91), (0.095, 0.04, 0.19), "tawny", "tawny_shade", taper=0.45,
          rotate=(0, -6, 0))
    b.box("ear_l", (0.205, 0.0, 0.76), (0.10, 0.045, 0.21), "tawny_shade", "tawny_shade", taper=1.0,
          rotate=(0, -24, 0))
    # Tail.
    b.box("tail", (0.0, 0.17, 0.38), (0.07, 0.07, 0.14), "tawny", "tawny_shade", taper=0.8,
          rotate=(-35, 0, 0))
    # Torso: the red jacket.
    b.box("spine", (0.0, 0.0, 0.42), (0.27, 0.19, 0.25), "jacket", "jacket_shade", taper=1.1)
    # Arms: sleeve, sleeve, mitten.
    for side, sx in (("r", -1), ("l", 1)):
        x = 0.175 * sx
        b.box("upper_arm_" + side, (x, 0, 0.455), (0.075, 0.075, 0.10), "jacket", "jacket_shade")
        b.box("forearm_" + side, (x, 0, 0.365), (0.075, 0.075, 0.10), "jacket", "jacket_shade")
        b.box("forearm_" + side, (x, -0.005, 0.30), (0.085, 0.085, 0.075), "cream", "cream")
    # Legs: thigh, shin, round boot.
    for side, sx in (("r", -1), ("l", 1)):
        x = 0.07 * sx
        b.box("thigh_" + side, (x, 0, 0.245), (0.095, 0.095, 0.11), "tawny", "tawny_shade")
        b.box("shin_" + side, (x, 0, 0.135), (0.085, 0.085, 0.11), "tawny", "tawny_shade")
        b.box("shin_" + side, (x, -0.02, 0.04), (0.115, 0.17, 0.08), "ink", "ink")
    # Sword in her right hand, tip up and back over her shoulder (hilt, guard, blade).
    tilt = 38.0
    up = Vector((0, math.sin(math.radians(tilt)), math.cos(math.radians(tilt))))
    grip = Vector((-0.175, -0.025, 0.30))
    def along(dist):
        return grip + up * dist
    b.box("weapon_socket", along(-0.02), (0.035, 0.035, 0.11), "brass", "brass", rotate=(-tilt, 0, 0))
    b.box("weapon_socket", along(0.05), (0.13, 0.035, 0.03), "brass", "brass", rotate=(-tilt, 0, 0))
    b.box("weapon_socket", along(0.28), (0.055, 0.02, 0.44), "slate_light", "slate", taper=0.55,
          rotate=(-tilt, 0, 0))
    return b.to_object(MODEL_NAME + "_mesh")


# ---------------------------------------------------------------- skeleton
def build_armature():
    arm_data = bpy.data.armatures.new(MODEL_NAME + "_rig")
    arm_obj = bpy.data.objects.new(MODEL_NAME, arm_data)
    bpy.context.collection.objects.link(arm_obj)
    bpy.context.view_layer.objects.active = arm_obj
    arm_obj.select_set(True)
    bpy.ops.object.mode_set(mode="EDIT")
    edit = {}
    for name, (head, tail, parent) in BONES.items():
        bone = arm_data.edit_bones.new(name)
        bone.head = Vector(head)
        bone.tail = Vector(tail)
        bone.roll = 0.0
        edit[name] = bone
    for name, (_, _, parent) in BONES.items():
        if parent:
            edit[name].parent = edit[parent]
    bpy.ops.object.mode_set(mode="OBJECT")
    return arm_obj


# ---------------------------------------------------------------- animation
class Rig:
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
        """Rotate a bone about the armature's X (swing forward/back), Y (roll) and Z (turn)
        axes, in degrees. Positive X tips things above the joint forward (toward -Y)."""
        world = Euler((math.radians(x), math.radians(y), math.radians(z)), "XYZ").to_matrix()
        rest = self.rest3[bone]
        local = rest.inverted() @ world @ rest
        pb = self.obj.pose.bones[bone]
        pb.rotation_quaternion = local.to_quaternion()

    def move(self, bone, x=0.0, y=0.0, z=0.0):
        rest = self.rest3[bone]
        self.obj.pose.bones[bone].location = rest.inverted() @ Vector((x, y, z))

    def key(self, frame):
        for pb in self.obj.pose.bones:
            pb.keyframe_insert("rotation_quaternion", frame=frame)
            pb.keyframe_insert("location", frame=frame)


def pose_idle(rig, t):
    """t in 0..1 around the loop. Breathing, ear flick, slow tail sway."""
    s = math.sin(2 * math.pi * t)
    rig.reset()
    rig.move("hips", z=0.012 * s)
    rig.rotate("spine", x=1.5 * s)
    rig.rotate("head", x=-1.5 * s, z=2.0 * math.sin(2 * math.pi * t + 1.0))
    rig.rotate("tail", z=14 * math.sin(2 * math.pi * t))
    rig.rotate("ear_l", x=6 * math.sin(2 * math.pi * t - 0.8))
    flick = 14.0 if 0.55 < t < 0.7 else 0.0
    rig.rotate("ear_r", y=flick)
    rig.rotate("upper_arm_l", x=-3 * s)
    rig.rotate("upper_arm_r", x=-2 * s)        # sword arm: the blade rests over the shoulder


def pose_gait(rig, t, thigh, knee, arm, elbow, bob, lean):
    """Shared walk/run pose. t in 0..1. Legs and arms swing opposite each other."""
    phase = 2 * math.pi * t
    rig.reset()
    rig.move("hips", z=bob * abs(math.sin(phase)))
    rig.rotate("spine", x=lean, z=4 * math.sin(phase))
    rig.rotate("head", x=-lean * 0.6, z=-3 * math.sin(phase))
    for side, sign in (("r", 1.0), ("l", -1.0)):
        swing = math.sin(phase) * sign
        # Forward for a hanging leg is negative X rotation.
        rig.rotate("thigh_" + side, x=-thigh * swing)
        bend = max(0.0, math.sin(phase + (0.9 if sign > 0 else 0.9 + math.pi))) * knee
        rig.rotate("shin_" + side, x=bend)
    # Sword arm (right) swings less; it keeps the blade up.
    rig.rotate("upper_arm_l", x=arm * math.sin(phase) * 1.0)
    rig.rotate("forearm_l", x=-elbow)          # elbow bends the hand forward
    rig.rotate("upper_arm_r", x=-arm * 0.25 * math.sin(phase))   # sword arm swings little
    rig.rotate("tail", z=18 * math.sin(phase * 2), x=lean * 0.5)
    rig.rotate("ear_l", x=10 * math.sin(phase * 2 - 0.6))
    rig.rotate("ear_r", y=-6 * math.sin(phase * 2 - 0.3))


ANIMATIONS = {
    # name: (frames in one loop, pose function)
    "idle": (22, lambda rig, t: pose_idle(rig, t)),
    "walk": (12, lambda rig, t: pose_gait(rig, t, thigh=30, knee=38, arm=26, elbow=10, bob=0.018, lean=3)),
    "run": (9, lambda rig, t: pose_gait(rig, t, thigh=52, knee=75, arm=50, elbow=45, bob=0.04, lean=12)),
}


def build_animations(arm_obj):
    scene = bpy.context.scene
    scene.render.fps = FPS
    bpy.context.preferences.edit.keyframe_new_interpolation_type = "CONSTANT"
    rig = Rig(arm_obj)
    anim = arm_obj.animation_data_create()
    actions = []
    for name, (frames, pose) in ANIMATIONS.items():
        action = bpy.data.actions.new(name)
        action.use_fake_user = True
        anim.action = action
        for frame in range(frames + 1):          # last key repeats the first so the loop closes
            pose(rig, (frame % frames) / frames)
            rig.key(frame)
        actions.append((name, action, frames))
    # One NLA track per clip, so the exporter writes one named animation each.
    anim.action = None
    for name, action, frames in actions:
        track = anim.nla_tracks.new()
        track.name = name
        strip = track.strips.new(name, 0, action)
        strip.name = name
    rig.reset()
    return actions


# ---------------------------------------------------------------- material + export
def make_material(png_path):
    mat = bpy.data.materials.new(MATERIAL_NAME)
    mat.use_nodes = True
    nodes = mat.node_tree.nodes
    links = mat.node_tree.links
    nodes.clear()
    out = nodes.new("ShaderNodeOutputMaterial")
    bsdf = nodes.new("ShaderNodeBsdfPrincipled")
    tex = nodes.new("ShaderNodeTexImage")
    tex.image = bpy.data.images.load(png_path)
    tex.image.name = MODEL_NAME + ".png"
    tex.interpolation = "Closest"
    links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    links.new(bsdf.outputs["BSDF"], out.inputs["Surface"])
    bsdf.inputs["Roughness"].default_value = 1.0
    return mat


def main():
    os.makedirs(OUT_DIR, exist_ok=True)
    bpy.ops.wm.read_factory_settings(use_empty=True)
    png = paint_texture()
    mesh_obj = build_mesh()
    mesh_obj.data.materials.append(make_material(png))
    arm_obj = build_armature()
    mesh_obj.parent = arm_obj
    modifier = mesh_obj.modifiers.new("Armature", "ARMATURE")
    modifier.object = arm_obj
    actions = build_animations(arm_obj)
    tris = sum(len(p.vertices) - 2 for p in mesh_obj.data.polygons)
    print("triangles:", tris)
    bpy.context.scene.frame_start = 0
    bpy.ops.export_scene.gltf(
        filepath=GLB_PATH,
        export_format="GLB",
        export_yup=True,
        export_apply=False,
        export_skins=True,
        export_animations=True,
        export_animation_mode="NLA_TRACKS",
        export_force_sampling=False,
        export_optimize_animation_size=False,
        export_image_format="AUTO",
        export_materials="EXPORT",
        export_cameras=False,
        export_lights=False,
        export_extras=False,
    )
    print("wrote", GLB_PATH)


main()
