"""Shared helpers for the Technical Artist's model tools (split_swords.py, rig_red.py, rig_cyberwolf.py).

Ross's Meshy models (game/art/final/**/*_ross_v1.glb) are NEVER edited: every tool here imports the
original read-only into a scratch Blender scene, builds a game-ready copy, and exports it next to it under a
new name.

Run any tool with Blender as a Python module (Python 3.11):
    python3 -m venv /tmp/ta_venv
    /tmp/ta_venv/bin/pip install bpy==5.0.1 pillow numpy
    /tmp/ta_venv/bin/python game/scripts/tools/split_swords.py
(Do not name a script inspect.py or similar: it shadows the standard library.)

Axes: Blender is Z-up and the glTF exporter turns it into Y-up, so a model that faces Godot +Z faces
Blender -Y. Ross's files import as: up = +Z, facing = -Y, as the contract wants.
"""

import io
import json
import math
import os
import struct

import bpy  # must come before bmesh / mathutils
import bmesh
from mathutils import Euler, Matrix, Quaternion, Vector
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
GAME_DIR = os.path.abspath(os.path.join(HERE, "..", ".."))
ROOT = os.path.abspath(os.path.join(GAME_DIR, ".."))
TEX_NODE_LABELS = ("BASE COLOR", "METALLIC ROUGHNESS", "NORMAL MAP")   # as the glTF importer labels them


def reset_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    sc = bpy.context.scene
    sc.render.fps = 15


def import_glb(path):
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=path)
    return [o for o in bpy.data.objects if o not in before]


def glb_images(path):
    """The embedded images of a .glb as PIL images, in the order of the file's 'images' list."""
    with open(path, "rb") as f:
        data = f.read()
    length = struct.unpack_from("<I", data, 12)[0]
    doc = json.loads(data[20:20 + length])
    off = 20 + length
    blen, btype = struct.unpack_from("<II", data, off)
    blob = data[off + 8:off + 8 + blen]
    out = []
    for image in doc.get("images", []):
        view = doc["bufferViews"][image["bufferView"]]
        raw = blob[view.get("byteOffset", 0):view.get("byteOffset", 0) + view["byteLength"]]
        out.append(Image.open(io.BytesIO(raw)).convert("RGB"))
    return doc, out


def material_image_nodes(material):
    nodes = {}
    for n in material.node_tree.nodes:
        if n.type == "TEX_IMAGE" and n.label in TEX_NODE_LABELS:
            nodes[n.label] = n
    return nodes


def pot_size(w, h, max_side):
    """A power-of-two (w, h) near the given aspect, longest side at most max_side, none below 64."""
    k = min(1.0, max_side / float(max(w, h)))
    def snap(v):
        v = max(64, v * k)
        return int(2 ** round(math.log2(v)))
    return min(snap(w), max_side), min(snap(h), max_side)


def replace_material_images(material, pil_images, tmp_dir, tag, jpeg_quality=90):
    """Swaps the three texture images of a (copied) glTF-style material for new PIL images keyed by node label
    (base color is sRGB, the others Non-Color), packed into the .blend so the exporter embeds them."""
    nodes = material_image_nodes(material)
    for label, pil in pil_images.items():
        path = os.path.join(tmp_dir, "%s_%s.jpg" % (tag, label.split()[0].lower()))
        pil.save(path, "JPEG", quality=jpeg_quality, subsampling=0)
        img = bpy.data.images.load(path)
        img.colorspace_settings.name = "sRGB" if label == "BASE COLOR" else "Non-Color"
        img.pack()
        nodes[label].image = img


def downscale_all(pil_images, max_side):
    return {label: im.resize(pot_size(im.width, im.height, max_side), Image.LANCZOS) for label, im in pil_images.items()}


def export_glb(path, objects, animations=False):
    bpy.ops.object.select_all(action="DESELECT")
    for o in objects:
        o.select_set(True)
    extra = {}
    if animations:
        extra = dict(export_animation_mode="NLA_TRACKS", export_force_sampling=False,
                     export_optimize_animation_size=False, export_frame_range=False)
    bpy.ops.export_scene.gltf(
        filepath=path, export_format="GLB", export_yup=True, export_apply=False, use_selection=True,
        export_skins=True, export_animations=animations, export_image_format="JPEG", export_jpeg_quality=90,
        export_materials="EXPORT", export_cameras=False, export_lights=False, export_extras=False,
        export_normals=True, export_tangents=False, **extra)
    print("wrote", os.path.relpath(path, ROOT), "%.0f KB" % (os.path.getsize(path) / 1024.0))


def tri_count(obj):
    return sum(len(p.vertices) - 2 for p in obj.data.polygons)


def bounds(objs):
    lo = Vector((1e9, 1e9, 1e9)); hi = -lo
    for o in objs:
        for v in o.data.vertices:
            w = o.matrix_world @ v.co
            lo = Vector(map(min, lo, w)); hi = Vector(map(max, hi, w))
    return lo, hi
