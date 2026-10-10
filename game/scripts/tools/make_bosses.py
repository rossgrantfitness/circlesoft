#!/usr/bin/env python3
"""Builds the PLACEHOLDER boss blockouts of the vertical slice (task VS-24). Needs Python 3 + numpy only.

    python3 game/scripts/tools/make_bosses.py     # then: godot --headless --path game --import   (once, for the .glb.import files)

Everything lands in game/art/placeholder/bosses/ (placeholders only: Ross makes the final art; these stand in until his
VS-A1 and VS-A2 files arrive). Ross's city tiles are read-only inputs, embedded into the new .glb files as copies.

    hushmaster.glb      static node tree, front +Z, standing on the floor: hull, seat (+ kasp_mount), dish (+ dish_port), eight
                        legs (leg_fl_1 ... leg_br_2, each with a lower segment that hangs from its knee) in four pairs (legs_fl,
                        legs_fr, legs_bl, legs_br), four relay boxes (relay_fl ...) each with a lamp child (lamp_fl ...).
                        Every leg and relay pivot is at its hip / mount point, so rotating or hiding a node is all a "drop" needs.
    kasp.glb            1.05 m, rigged on Red's bone names (scaled), so the free Quaternius clips retarget like the robots.
    junk_mech.glb       40 m, Red's bone names scaled x42, plus mount bones. One skin, several mesh nodes: junk_mech_body,
                        floodlights, plate_* (four armour plates, each on its own mount bone plate_*_mount), cockpit_core (on
                        the bone cockpit_core_mount), and the bone kasp_seat inside the core. No face anywhere.
    arena/              wall, gate post, plateau rail, scrap piles, a giant heap and a turret pylon for Kasp's arena.

Axes: glTF space, Y up, models face +Z, left (l) is +X, metres.
"""
import math
import os
import sys

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from glb_kit import Skeleton, _write, load_glb  # noqa: E402
from make_robots import RED, hazard_texture, tile  # noqa: E402
from robot_kit import Builder, Pack, rot_x, rot_y, rot_z, scaled_rig  # noqa: E402

GAME_DIR = os.path.abspath(os.path.join(HERE, "..", ".."))
OUT = os.path.join(GAME_DIR, "art", "placeholder", "bosses")
ARENA = os.path.join(OUT, "arena")
RED_HEIGHT = 0.951
KASP_HEIGHT = 1.05
MECH_HEIGHT = 40.0
KASP_UNIT = KASP_HEIGHT / RED_HEIGHT
MECH_UNIT = MECH_HEIGHT / RED_HEIGHT
D2R = math.pi / 180.0


# ------------------------------------------------------------------ small helpers
def unit_v(v):
    v = np.asarray(v, dtype=float)
    return v / np.linalg.norm(v)


def basis(z, up=(0.0, 1.0, 0.0)):
    """A rotation whose local +Z points along `z` and whose local +Y is as close to `up` as it can be."""
    z = unit_v(z)
    up = np.asarray(up, dtype=float)
    if abs(float(np.dot(up, z))) > 0.97:
        up = np.array([0.0, 0.0, 1.0]) if abs(z[2]) < 0.9 else np.array([1.0, 0.0, 0.0])
    x = unit_v(np.cross(up, z))
    y = np.cross(z, x)
    return np.column_stack([x, y, z])


def flat(b, name, hexcolor, rough=0.9, emissive=None):
    c = tuple(int(hexcolor[i:i + 2], 16) / 255.0 for i in (1, 3, 5))
    out = b.material(name, c, rough=rough)
    if emissive is not None:
        b.materials[name]["emissive"] = emissive
    return out


def tiled(b, name, tile_info, tint, tile_m):
    return b.material(name, tint, tile=tile_info, tile_m=tile_m)


class Draw:
    """Wraps a Builder with a transform stack, so a car or a container can be drawn once in its own space and placed anywhere."""

    def __init__(self, b):
        self.b = b
        self.R = np.eye(3)
        self.t = np.zeros(3)
        self._stack = []

    def push(self, R=None, t=(0.0, 0.0, 0.0)):
        self._stack.append((self.R, self.t))
        R = np.eye(3) if R is None else np.asarray(R, dtype=float)
        self.t = self.t + self.R @ np.asarray(t, dtype=float)
        self.R = self.R @ R

    def pop(self):
        self.R, self.t = self._stack.pop()

    def P(self, p):
        return self.t + self.R @ np.asarray(p, dtype=float)

    def box(self, bone, c, size, mat, rot=None):
        R = self.R if rot is None else self.R @ np.asarray(rot, dtype=float)
        self.b.box(bone, self.P(c), size, mat, rot=None if np.allclose(R, np.eye(3)) else R)

    def frustum(self, bone, p0, p1, r0, r1, mat, n=4, hint=(0.0, 0.0, 1.0)):
        self.b.frustum(bone, self.P(p0), self.P(p1), r0, r1, mat, n=n, hint=self.R @ np.asarray(hint, dtype=float))

    def prism(self, bone, p0, p1, r0, r1, mat, n=8):
        self.b.prism(bone, self.P(p0), self.P(p1), r0, r1, mat, n=n)

    def quad(self, bone, corners, mat):
        self.b.quad(bone, [self.P(c) for c in corners], mat)

    def row(self, bone, p0, p1, count, size, mat):
        p0, p1 = np.asarray(p0, dtype=float), np.asarray(p1, dtype=float)
        for i in range(count):
            f = 0.5 if count == 1 else i / (count - 1)
            self.box(bone, p0 + (p1 - p0) * f, size, mat)


# ------------------------------------------------------------------ scene (static node tree) and writers
class Scene:
    """A node tree where every node may carry its own mesh. All meshes share one material list."""

    def __init__(self):
        self.shared = Builder()
        self.nodes = []

    def builder(self):
        bb = Builder()
        bb.materials = self.shared.materials
        bb.images = self.shared.images
        return bb

    def node(self, name, parent=None, t=(0.0, 0.0, 0.0), q=None, builder=None):
        self.nodes.append({"name": name, "parent": parent, "t": [float(x) for x in t], "q": q, "builder": builder})
        return name


def _emit_materials(pack, shared, builders):
    images, textures, materials, image_of, mat_index = [], [], [], {}, {}
    used = [m for m in shared.materials if any(m in bb.prims for bb in builders)]
    for key in sorted({shared.materials[m]["tile"] for m in used if shared.materials[m]["tile"]}):
        image_of[key] = len(images)
        images.append({"bufferView": pack.view(shared.images[key]), "mimeType": "image/png", "name": key})
        textures.append({"source": len(images) - 1, "sampler": 0})
    for name in used:
        info = shared.materials[name]
        pbr = {"baseColorFactor": [info["color"][0], info["color"][1], info["color"][2], 1.0], "metallicFactor": 0.0, "roughnessFactor": info["rough"]}
        if info["tile"] is not None:
            pbr["baseColorTexture"] = {"index": image_of[info["tile"]]}
        mat = {"name": name, "pbrMetallicRoughness": pbr, "doubleSided": False}
        if "emissive" in info:
            mat["emissiveFactor"] = [float(x) for x in info["emissive"]]
        materials.append(mat)
        mat_index[name] = len(materials) - 1
    return images, textures, materials, mat_index


def _emit_mesh(pack, bb, name, mat_index, skinned):
    prims = []
    for m in bb.used_materials():
        pr = bb.prims[m]
        attrs = {
            "POSITION": pack.accessor(np.array(pr["pos"], dtype="<f4"), 5126, "VEC3", 34962, bounds=True),
            "NORMAL": pack.accessor(np.array(pr["nor"], dtype="<f4"), 5126, "VEC3", 34962),
            "TEXCOORD_0": pack.accessor(np.array(pr["uv"], dtype="<f4"), 5126, "VEC2", 34962),
        }
        if skinned:
            n = len(pr["pos"])
            j = np.zeros((n, 4), dtype="<u2")
            j[:, 0] = np.array(pr["joint"], dtype="<u2")
            w = np.zeros((n, 4), dtype="<f4")
            w[:, 0] = 1.0
            attrs["JOINTS_0"] = pack.accessor(j, 5123, "VEC4", 34962)
            attrs["WEIGHTS_0"] = pack.accessor(w, 5126, "VEC4", 34962)
        idx = pack.accessor(np.array(pr["idx"], dtype="<u4"), 5125, "SCALAR", 34963)
        prims.append({"attributes": attrs, "indices": idx, "material": mat_index[m], "mode": 4})
    return {"name": name, "primitives": prims}


def _tris(bb):
    return sum(len(pr["idx"]) // 3 for pr in bb.prims.values())


def write_scene(path, scene, root_name, note):
    """Static node tree. Node order: parents are written before children; the first node without a parent is the scene root."""
    pack = Pack()
    builders = [n["builder"] for n in scene.nodes if n["builder"] is not None]
    images, textures, materials, mat_index = _emit_materials(pack, scene.shared, builders)
    meshes, nodes, index = [], [], {}
    for n in scene.nodes:
        entry = {"name": n["name"]}
        if any(abs(x) > 1e-9 for x in n["t"]):
            entry["translation"] = n["t"]
        if n["q"] is not None:
            entry["rotation"] = [float(x) for x in n["q"]]
        if n["builder"] is not None and n["builder"].prims:
            meshes.append(_emit_mesh(pack, n["builder"], n["name"], mat_index, False))
            entry["mesh"] = len(meshes) - 1
        index[n["name"]] = len(nodes)
        nodes.append(entry)
    for n in scene.nodes:
        if n["parent"] is not None:
            nodes[index[n["parent"]]].setdefault("children", []).append(index[n["name"]])
    roots = [i for i, n in enumerate(scene.nodes) if n["parent"] is None]
    assert len(roots) == 1, "one root node"
    doc = {"asset": {"version": "2.0", "generator": "circlesoft scripts/tools/make_bosses.py (placeholder blockout)", "extras": {"note": note}},
           "samplers": [{"magFilter": 9729, "minFilter": 9987, "wrapS": 10497, "wrapT": 10497}],
           "materials": materials, "meshes": meshes, "nodes": nodes, "scenes": [{"name": "Scene", "nodes": roots}], "scene": 0}
    if images:
        doc["images"], doc["textures"] = images, textures
    doc["accessors"], doc["bufferViews"] = pack.accessors, pack.views
    doc["buffers"] = [{"byteLength": len(pack.data)}]
    _write(path, doc, bytes(pack.data))
    return sum(_tris(bb) for bb in builders)


def write_rigged(path, shared, rig, meshes, model_name, note):
    """One skin (Red's bones, scaled, plus extras), several mesh nodes. meshes = [(node name, Builder)]; the first reuses Red's
    mesh node, the others are added beside it under the armature, each its own MeshInstance3D once imported."""
    nodes, joints, names, mesh_node, arm = rig
    nodes = [dict(n) for n in nodes]
    pack = Pack()
    images, textures, materials, mat_index = _emit_materials(pack, shared, [bb for _, bb in meshes])
    out_meshes = []
    for k, (name, bb) in enumerate(meshes):
        out_meshes.append(_emit_mesh(pack, bb, name, mat_index, True))
        if k == 0:
            nodes[mesh_node]["name"] = name
            nodes[mesh_node]["mesh"] = 0
            nodes[mesh_node]["skin"] = 0
        else:
            nodes.append({"name": name, "mesh": k, "skin": 0})
            nodes[arm].setdefault("children", []).append(len(nodes) - 1)
    sk = Skeleton({"nodes": nodes})
    ibm = np.zeros((len(joints), 16), dtype="<f4")
    for k, node in enumerate(joints):
        m = np.eye(4)
        m[:3, :3] = sk.rest_world_r[node]
        m[:3, 3] = sk.rest_world_p[node]
        ibm[k] = np.linalg.inv(m).T.flatten()
    nodes[arm]["name"] = model_name + "_armature"
    skin = {"name": model_name + "_armature", "joints": joints, "inverseBindMatrices": pack.accessor(ibm, 5126, "MAT4")}
    doc = {"asset": {"version": "2.0", "generator": "circlesoft scripts/tools/make_bosses.py (placeholder blockout)", "extras": {"note": note}},
           "samplers": [{"magFilter": 9729, "minFilter": 9987, "wrapS": 10497, "wrapT": 10497}],
           "materials": materials, "meshes": out_meshes, "nodes": nodes, "skins": [skin], "scenes": [{"name": "Scene", "nodes": [arm]}], "scene": 0}
    if images:
        doc["images"], doc["textures"] = images, textures
    doc["accessors"], doc["bufferViews"] = pack.accessors, pack.views
    doc["buffers"] = [{"byteLength": len(pack.data)}]
    _write(path, doc, bytes(pack.data))
    return sum(_tris(bb) for _, bb in meshes)


def quat_x(deg):
    h = deg * D2R / 2.0
    return [math.sin(h), 0.0, 0.0, math.cos(h)]


# ------------------------------------------------------------------ shared palette
def palette(b):
    t_plate = tile("rust_riveted_plates_tall")
    t_steel = tile("steel_plate_riveted_grey")
    t_streak = tile("rust_streaked_plate_tall")
    t_vent = tile("rust_vent_louvers_wide")
    m = {
        # Signals colours (slate, blue-gray, white stencil, cold pink-red lamps)
        "slate": flat(b, "signals_slate", "#4B5667"),
        "signals": flat(b, "signals_blue_gray", "#6A7A90"),
        "white": flat(b, "stencil_white", "#D9DEE4"),
        "dish_face": flat(b, "dish_face_off_white", "#B4B9BF", 0.7),
        "frame": flat(b, "frame_dark", "#2E3140"),
        "glass": flat(b, "glass_dark", "#161C28", 0.2),
        "lamp": flat(b, "lamp_pink_red", "#E8456A", 0.3, emissive=(0.9, 0.18, 0.3)),
        "lamp_dim": flat(b, "lamp_pink_red_dim", "#9C3550", 0.3, emissive=(0.25, 0.06, 0.1)),
        "flood": flat(b, "floodlight_cold", "#DCE8FF", 0.3, emissive=(0.85, 0.9, 1.0)),
        "amber": flat(b, "dial_amber", "#FF9A3C", 0.3, emissive=(0.8, 0.4, 0.1)),
        "vinyl": flat(b, "vinyl_tired", "#5E5A3C", 0.8),
        "brass": flat(b, "brass", "#B98B38", 0.5),
        "tyre": flat(b, "tyre", "#1A1A22", 1.0),
        "fridge": flat(b, "fridge_white", "#B9BCB6", 0.6),
        "sticker": flat(b, "warning_sticker", "#E0B83A", 0.6),
        "hazard": tiled(b, "hazard", hazard_texture(), (0.9, 0.86, 0.78), 1.0),
        "vent": tiled(b, "vent_louvers", t_vent, (0.8, 0.8, 0.86), 2.0),
        # junkyard scrap: Ross's rust tiles with a car-paint tint (mint, mustard, faded red)
        "rust": tiled(b, "scrap_rust", t_plate, (1.0, 0.9, 0.82), 3.0),
        "mint": tiled(b, "scrap_mint", t_plate, (0.55, 0.85, 0.72), 3.0),
        "mustard": tiled(b, "scrap_mustard", t_plate, (1.0, 0.78, 0.32), 3.0),
        "redpaint": tiled(b, "scrap_red", t_plate, (0.85, 0.38, 0.34), 3.0),
        "steel": tiled(b, "scrap_steel", t_steel, (0.82, 0.85, 0.92), 3.0),
        "streak": tiled(b, "scrap_streak", t_streak, (0.95, 0.9, 0.85), 4.0),
        "signals_plate": tiled(b, "signals_painted_plate", t_steel, (0.55, 0.65, 0.8), 3.0),
        "concrete": flat(b, "concrete", "#6E6D70", 1.0),
    }
    return m


# ------------------------------------------------------------------ scrap shapes (own space: Z is the long axis, Y up, origin at the centre)
def car(d, bone, M, c, R=None, s=1.0, paint="mint"):
    d.push(R, c)
    d.box(bone, (0, -0.37 * s, 0), (1.8 * s, 0.7 * s, 4.4 * s), M[paint])
    d.box(bone, (0, 0.33 * s, -0.25 * s), (1.6 * s, 0.7 * s, 2.3 * s), M[paint])
    d.box(bone, (0, 0.36 * s, -0.25 * s), (1.7 * s, 0.34 * s, 1.7 * s), M["glass"])
    for sx in (-1, 1):
        for z in (-1.35, 1.35):
            d.box(bone, (sx * 0.85 * s, -0.6 * s, z * s), (0.3 * s, 0.7 * s, 0.7 * s), M["tyre"])
    d.pop()


def container(d, bone, M, c, R=None, paint="mustard", size=(2.44, 2.6, 12.2)):
    w, h, ln = size
    d.push(R, c)
    d.box(bone, (0, 0, 0), size, M[paint])
    d.box(bone, (0, 0, ln / 2 + 0.02), (w - 0.1, h - 0.1, 0.05), M["frame"])
    for sx in (-0.5, 0.5):
        d.box(bone, (sx * (w - 0.5) / 2, 0, ln / 2 + 0.06), (0.08, h - 0.2, 0.04), M["steel"])
    d.pop()


def bus(d, bone, M, c, R=None, paint="mustard"):
    d.push(R, c)
    d.box(bone, (0, 0, 0), (2.5, 2.8, 12.0), M[paint])
    d.box(bone, (0, 0.5, 0), (2.58, 0.9, 10.6), M["glass"])
    d.box(bone, (0, 1.45, 0), (2.0, 0.2, 10.0), M["steel"])
    d.box(bone, (0, 0.5, 6.01), (2.2, 1.1, 0.04), M["glass"])
    for z in (-3.6, -2.6, 3.4):
        for sx in (-1, 1):
            d.box(bone, (sx * 1.28, -1.25, z), (0.3, 1.0, 1.0), M["tyre"])
    d.pop()


def tyre(d, bone, M, c, r=0.6, length=0.4, axis=(1.0, 0.0, 0.0), n=8):
    c = np.asarray(c, dtype=float)
    a = unit_v(axis) * length / 2.0
    d.prism(bone, c - a, c + a, r, r, M["tyre"], n=n)


def crushed_cube(d, bone, M, c, size, paint, R=None):
    d.box(bone, c, size, M[paint], rot=R)
    d.box(bone, c, (size[0] + 0.1, size[1] * 0.12, size[2] + 0.1), M["frame"], rot=R)


def lattice_boom(d, bone, M, p0, p1, width=1.4, up=(0.0, 1.0, 0.0), bays=6):
    """A triangular crane lattice from p0 to p1: three chords, frames and diagonals."""
    p0, p1 = np.asarray(p0, dtype=float), np.asarray(p1, dtype=float)
    R = basis(p1 - p0, up)
    length = float(np.linalg.norm(p1 - p0))
    d.push(R, p0)
    corners = [(-width / 2, -width * 0.29), (width / 2, -width * 0.29), (0.0, width * 0.58)]
    for cx, cy in corners:
        d.box(bone, (cx, cy, length / 2), (0.28, 0.28, length), M["mustard"])
    for k in range(bays + 1):
        z = length * k / bays
        d.box(bone, (0, -width * 0.29, z), (width, 0.14, 0.14), M["frame"])
        d.box(bone, (-width * 0.25, width * 0.145, z), (0.14, width * 0.62, 0.12), M["frame"], rot=rot_z(-30))
        d.box(bone, (width * 0.25, width * 0.145, z), (0.14, width * 0.62, 0.12), M["frame"], rot=rot_z(30))
    for k in range(bays):
        z0, z1 = length * k / bays, length * (k + 1) / bays
        side = -1 if k % 2 == 0 else 1
        mid = np.array([side * width * 0.25, -width * 0.145, (z0 + z1) / 2])
        ang = math.degrees(math.atan2(z1 - z0, width * 0.5)) * (1 if k % 2 == 0 else -1)
        d.box(bone, mid, (0.1, 0.1, (z1 - z0) * 1.15), M["frame"], rot=rot_y(-ang * 0.35))
    d.pop()


# ------------------------------------------------------------------ THE HUSHMASTER
LEG_PAIRS = {"fl": (1, 1), "fr": (-1, 1), "bl": (1, -1), "br": (-1, -1)}      # pair id -> (side sign on X, front sign on Z)
# (hip z, knee offset, foot offset) per leg, for the +X / +Z pair; mirrored for the others
LEG_SHAPES = {
    1: {"hip_z": 1.35, "knee": (1.8, 0.9, 0.9), "foot": (3.6, -3.7, 2.0)},
    2: {"hip_z": 0.20, "knee": (1.8, 0.9, 0.35), "foot": (3.6, -3.7, 0.9)},
}
HIP_X = 2.0
HIP_Y = 3.7


def build_hushmaster(path):
    sc = Scene()
    M = palette(sc.shared)
    root = sc.node("Hushmaster")

    # hull: 4 x 3 m body riding 3.5 m up. Underside modelled, since it is seen when the rig topples.
    b = sc.builder()
    d = Draw(b)
    d.box(None, (0, 4.0, -0.3), (4.0, 1.0, 2.4), M["slate"])
    d.box(None, (0, 4.56, -0.3), (3.9, 0.12, 2.3), M["signals"])
    d.box(None, (0, 4.0, 1.2), (3.2, 0.8, 0.6), M["signals"])                    # reception desk on the front
    d.box(None, (0, 4.15, 1.51), (2.6, 0.14, 0.03), M["white"])                  # stencil strip
    d.row(None, (-1.0, 3.85, 1.52), (1.0, 3.85, 1.52), 3, (0.2, 0.1, 0.04), M["lamp_dim"])
    d.box(None, (0, 3.43, 0), (3.6, 0.14, 2.8), M["frame"])                      # belly plate
    d.box(None, (0, 3.35, 0), (1.5, 0.1, 1.2), M["vent"])                        # service hatch under the hull
    d.box(None, (0, 3.33, 0.9), (2.4, 0.08, 0.3), M["hazard"])
    d.prism(None, (-1.6, 3.38, -1.0), (1.6, 3.38, -1.0), 0.1, 0.1, M["steel"], n=8)   # a pipe along the belly
    for sx in (-1, 1):
        for sz in (-1, 1):
            d.box(None, (sx * 2.03, 3.78, sz * 0.78), (0.12, 0.7, 1.1), M["hazard"])  # hazard collars at the four leg sockets
    d.box(None, (0, 4.0, -1.52), (3.0, 0.7, 0.04), M["vent"])                    # rear vent panel
    sc.node("hull", root, builder=b)

    # seat: an office chair, pivot on the hull's top deck. Kasp sits on kasp_mount.
    b = sc.builder()
    d = Draw(b)
    for k in range(5):
        a = k * 72.0
        d.box(None, (0, 0.14, 0), (0.7, 0.06, 0.08), M["frame"], rot=rot_y(a))
        r = 0.34
        d.box(None, (r * math.sin(a * D2R), 0.07, r * math.cos(a * D2R)), (0.1, 0.12, 0.1), M["tyre"])
    d.prism(None, (0, 0.14, 0), (0, 0.6, 0), 0.05, 0.05, M["steel"], n=8)        # gas lift
    d.box(None, (0, 0.68, 0), (0.95, 0.16, 0.9), M["vinyl"])
    d.box(None, (0, 1.2, -0.46), (0.8, 0.95, 0.14), M["vinyl"])
    d.box(None, (0, 1.82, -0.46), (0.5, 0.2, 0.12), M["vinyl"])                  # headrest
    for sx in (-1, 1):
        d.box(None, (sx * 0.52, 0.95, -0.1), (0.08, 0.06, 0.6), M["frame"])      # armrests
        d.box(None, (sx * 0.52, 0.83, -0.1), (0.06, 0.2, 0.06), M["frame"])
    d.prism(None, (0.52, 1.0, 0.1), (0.52, 1.2, 0.1), 0.09, 0.1, M["steel"], n=8)   # cupholder tube
    d.box(None, (-0.52, 1.0, 0.1), (0.1, 0.06, 0.1), M["amber"])                 # heated-seat dial (the joke)
    sc.node("seat", root, t=(0, 4.62, 0.15), builder=b)
    sc.node("kasp_mount", "seat", t=(0, 0.78, 0.0))

    # jammer dish: a post on the hull's rear deck, a swivel, a 3 m dish with a pink-red emitter and a service port
    b = sc.builder()
    d = Draw(b)
    d.prism(None, (0, 0, 0), (0, 1.9, 0), 0.32, 0.22, M["slate"], n=8)
    d.box(None, (0, 0.5, 0.27), (0.34, 0.28, 0.14), M["frame"])                  # the service port Red jacks into
    d.box(None, (0, 0.5, 0.35), (0.2, 0.14, 0.02), M["lamp_dim"])
    sc.node("dish_base", root, t=(0, 4.62, -1.3), builder=b)
    sc.node("dish_port", "dish_base", t=(0, 0.5, 0.38))
    b = sc.builder()
    d = Draw(b)
    d.push(rot_x(-20))
    d.prism(None, (0, 0, -0.5), (0, 0, 0.1), 0.25, 1.5, M["slate"], n=12)
    d.prism(None, (0, 0, 0.1), (0, 0, 0.14), 1.5, 1.5, M["dish_face"], n=12)
    d.prism(None, (0, 0, 0.14), (0, 0, 0.5), 0.12, 0.2, M["lamp"], n=8)
    for k in range(3):
        a = k * 120.0 + 90.0
        d.prism(None, (1.1 * math.cos(a * D2R), 1.1 * math.sin(a * D2R), 0.14), (0.0, 0.0, 0.45), 0.03, 0.03, M["frame"], n=6)
    d.pop()
    sc.node("dish", "dish_base", t=(0, 1.93, 0.0), builder=b)
    # the dish pivots at y 6.55 on its post; the rim tops out near 8 m

    # legs: eight, in four pairs. Pivot at the hip socket; the lower segment hangs from the knee node.
    for pair, (sx, sz) in LEG_PAIRS.items():
        sc.node("legs_" + pair, root)
        for number in (1, 2):
            shape = LEG_SHAPES[number]
            hip = np.array([sx * HIP_X, HIP_Y, sz * shape["hip_z"]])
            knee = np.array([sx * shape["knee"][0], shape["knee"][1], sz * shape["knee"][2]])
            foot = np.array([sx * shape["foot"][0], shape["foot"][1], sz * shape["foot"][2]]) - knee
            name = "leg_%s_%d" % (pair, number)
            b = sc.builder()
            d = Draw(b)
            d.frustum(None, (0, 0, 0), knee, (0.17, 0.17), (0.12, 0.12), M["slate"], n=4)
            d.box(None, (0, 0, 0), (0.42, 0.42, 0.42), M["frame"])                      # hip joint
            d.box(None, tuple(knee), (0.36, 0.36, 0.36), M["hazard"])                   # hazard-striped knee
            sc.node(name, "legs_" + pair, t=hip, builder=b)
            b = sc.builder()
            d = Draw(b)
            d.frustum(None, (0, 0, 0), foot, (0.11, 0.11), (0.06, 0.06), M["slate"], n=4)
            d.box(None, tuple(foot + np.array([0, 0.06, 0.1 * sz])), (0.55, 0.12, 0.75), M["frame"])   # foot plate
            d.box(None, tuple(foot + np.array([0, 0.13, 0.1 * sz])), (0.4, 0.03, 0.55), M["lamp_dim"])  # glow strip: code lights it for the stomp
            sc.node(name + "_lower", name, t=knee, builder=b)

    # relay boxes: where each pair meets the hull. 0.8 x 0.6 x 0.5 m, a big pink-red lamp on top (its own child node).
    for pair, (sx, sz) in LEG_PAIRS.items():
        b = sc.builder()
        d = Draw(b)
        d.box(None, (0, 0, 0), (0.5, 0.6, 0.8), M["signals"])
        d.box(None, (sx * 0.0, -0.18, 0), (0.52, 0.04, 0.82), M["frame"])
        d.box(None, (sx * 0.255, 0.1, 0), (0.02, 0.34, 0.58), M["slate"])                # drawer-like front
        d.box(None, (sx * 0.265, 0.1, 0.18), (0.02, 0.04, 0.1), M["white"])             # a handle
        d.box(None, (sx * 0.262, -0.1, -0.15), (0.02, 0.2, 0.28), M["sticker"])         # warning sticker
        d.box(None, (-sx * 0.2, -0.22, 0), (0.12, 0.16, 0.3), M["frame"])               # cable bundle into the hull side
        sc.node("relay_" + pair, root, t=(sx * 2.3, 3.95, sz * 0.78), builder=b)
        b = sc.builder()
        d = Draw(b)
        d.prism(None, (0, 0, 0), (0, 0.16, 0), 0.13, 0.11, M["lamp"], n=8)
        d.box(None, (0, 0.04, 0), (0.34, 0.08, 0.34), M["frame"])
        sc.node("lamp_" + pair, "relay_" + pair, t=(0, 0.3, 0), builder=b)
    return write_scene(path, sc, "Hushmaster", "Placeholder blockout by the Technical Artist (task VS-24): the Hushmaster. Legs, relays, dish, seat are separate nodes.")


# ------------------------------------------------------------------ KASP
def build_kasp(path):
    red_doc, _ = load_glb(RED)
    rig = scaled_rig(red_doc, KASP_UNIT, [])
    nodes, joints, names, mesh_node, arm = rig
    index = {nodes[n]["name"]: k for k, n in enumerate(joints)}
    shared = Builder()
    M = palette(shared)
    fur = flat(shared, "kasp_fur", "#7B4A2A", 0.95)
    fur_dark = flat(shared, "kasp_fur_dark", "#5C3720", 0.95)
    muzzle = flat(shared, "kasp_muzzle", "#B58557", 0.95)
    tooth = flat(shared, "kasp_tooth", "#EFE6D2", 0.6)
    paper = flat(shared, "kasp_paper", "#E4E0D0", 0.9)
    wood = flat(shared, "kasp_clipboard", "#8A6A44", 0.9)
    b = Builder(KASP_UNIT, index)
    b.materials, b.images = shared.materials, shared.images
    for s, sx in (("l", 1), ("r", -1)):
        X = lambda v: sx * v
        # boots, trousers
        b.box("foot_" + s, (X(.105), .035, .03), (.12, .07, .2), M["frame"])
        b.frustum("shin_" + s, (X(.10), .19, .005), (X(.105), .07, 0.0), (.052, .056), (.046, .05), M["slate"])
        b.frustum("thigh_" + s, (X(.085), .37, 0.0), (X(.10), .2, .005), (.066, .07), (.056, .06), M["slate"])
        # sleeves with the oversized white sergeant stripe, fur hands
        b.frustum("upper_arm_" + s, (X(.152), .6, 0.0), (X(.245), .525, 0.0), (.052, .058), (.048, .052), M["signals"])
        b.frustum("upper_arm_" + s, (X(.2), .5625, 0.0), (X(.21), .5515, 0.0), (.06, .064), (.06, .064), M["white"])
        b.frustum("forearm_" + s, (X(.245), .521, 0.0), (X(.3), .431, 0.0), (.046, .05), (.05, .054), M["signals"])
        b.box("hand_" + s, (X(.307), .395, .01), (.07, .075, .08), fur)
        b.box("shoulder_" + s, (X(.075), .625, 0.0), (.09, .08, .12), M["signals"])
        # ears and headphones
        b.box("head", (X(.09), .85, -.01), (.06, .05, .05), fur_dark)
        b.box("head", (X(.145), .765, 0.0), (.05, .12, .12), M["frame"])
        b.box("head", (X(.172), .765, 0.0), (.02, .09, .09), M["lamp_dim"])
        b.box("head", (X(.06), .775, .112), (.028, .034, .012), M["frame"])           # eyes
    # pelvis, belt, torso
    b.box("hips", (0.0, .385, 0.0), (.27, .1, .19), M["slate"])
    b.box("hips", (0.0, .425, 0.0), (.275, .022, .195), M["white"])
    b.box("spine", (0.0, .46, 0.0), (.24, .07, .17), M["signals"])
    b.box("chest", (0.0, .56, 0.0), (.31, .17, .22), M["signals"])
    b.box("chest", (0.0, .655, 0.0), (.27, .03, .19), M["slate"])
    b.box("chest", (0.0, .56, .113), (.02, .14, .006), M["amber"])                # lanyard
    b.box("chest", (0.0, .49, .117), (.055, .075, .006), paper)                   # laminated card
    b.box("chest", (.04, .52, .119), (.04, .05, .004), M["white"])
    b.box("chest", (-.05, .6, .117), (.024, .03, .01), M["brass"])               # whistle
    b.box("neck", (0.0, .65, 0.0), (.12, .04, .1), fur)
    # head: square, matte brown, big front teeth
    b.box("head", (0.0, .745, .005), (.27, .19, .22), fur)
    b.box("head", (0.0, .715, .12), (.13, .08, .06), muzzle)
    b.box("head", (0.0, .742, .153), (.045, .03, .02), M["frame"])
    b.box("head", (-.014, .672, .15), (.024, .045, .014), tooth)
    b.box("head", (.014, .672, .15), (.024, .045, .014), tooth)
    b.box("head", (0.0, .868, 0.0), (.3, .024, .05), M["frame"])                  # headphone band
    b.box("head", (.145, .835, 0.0), (.022, .1, .05), M["frame"])
    b.box("head", (-.145, .835, 0.0), (.022, .1, .05), M["frame"])
    b.prism("head_gear", (.1, .86, 0.0), (.1, .945, 0.0), .006, .006, M["brass"], n=6)      # antenna pin
    b.box("head_gear", (.1, .951, 0.0), (.016, .016, .016), M["lamp"])
    # flat paddle tail
    b.box("tail", (0.0, .37, -.2), (.15, .025, .23), fur_dark, rot=rot_x(-18))
    # clipboard with a mug holder, in the left hand
    b.box("prop_socket", (.33, .40, .075), (.09, .13, .012), wood)
    b.box("prop_socket", (.33, .405, .083), (.075, .105, .004), paper)
    b.prism("prop_socket", (.33, .46, .09), (.33, .5, .09), .018, .018, M["steel"], n=6)
    tris = write_rigged(path, shared, rig, [("kasp", b)], "kasp", "Placeholder blockout by the Technical Artist (task VS-24): Kasp, 1.05 m, on Red's bone names (scaled x%.2f)." % KASP_UNIT)
    return tris


# ------------------------------------------------------------------ THE GIANT JUNK MECH
U = MECH_UNIT
PLATES = {
    # name: (parent bone, centre (m), size (m) w x h x d, material, tilt). Four plates, as the Combat Designer's boss_design.md has it:
    # a plate per shoulder (Scrap Swing), the chest (Wrecking Drop) and the back (Stomp March).
    "plate_chest_front": ("chest", (0.0, 23.3, 5.2), (9.0, 6.0, 0.6), "signals_plate", -4.0),
    "plate_shoulder_l": ("shoulder_l", (7.6, 29.4, 0.0), (6.4, 0.6, 4.6), "mustard", -12.0),
    "plate_shoulder_r": ("shoulder_r", (-7.6, 29.4, 0.0), (6.4, 0.6, 4.6), "streak", 12.0),
    "plate_back": ("chest", (-2.4, 23.3, -5.7), (8.0, 6.5, 0.6), "redpaint", 0.0),
}
CORE = ("chest", (0.0, 23.3, 1.9))          # the pod's centre; Kasp's seat is inside
KASP_SEAT = (0.0, 22.6, 1.6)


def build_mech(path):
    red_doc, _ = load_glb(RED)
    extras = [{"name": n + "_mount", "parent": spec[0], "at": tuple(np.array(spec[1]) / U)} for n, spec in PLATES.items()]
    extras.append({"name": "cockpit_core_mount", "parent": CORE[0], "at": tuple(np.array(CORE[1]) / U)})
    extras.append({"name": "kasp_seat", "parent": "cockpit_core_mount", "at": tuple(np.array(KASP_SEAT) / U)})
    rig = scaled_rig(red_doc, U, extras)
    nodes, joints, names, mesh_node, arm = rig
    index = {nodes[n]["name"]: k for k, n in enumerate(joints)}
    shared = Builder()
    M = palette(shared)

    def new():
        bb = Builder(1.0, index)
        bb.materials, bb.images = shared.materials, shared.images
        return bb

    body = new()
    d = Draw(body)
    sk = Skeleton({"nodes": nodes})

    def P(bone):
        return sk.rest_world_p[sk.bone(bone)]

    # ---- feet: the left one a mustard container, the right one three cars nose to tail on a slab
    container(d, "foot_l", M, (4.4, 1.3, 2.3), None, "mustard")
    tyre(d, "foot_l", M, (4.4, 1.0, 8.6), 1.0, 1.1)
    d.box("foot_r", (-4.4, 0.3, 2.3), (4.4, 0.6, 12.8), M["frame"])
    for k, z in enumerate((-1.6, 2.5, 6.6)):
        car(d, "foot_r", M, (-4.4, 1.55, z), None, 0.9, ("redpaint", "rust", "mint")[k])
    # ---- shins: crushed cubes and an upright container with strapped fridges; knee discs are stacked tyres
    crushed_cube(d, "shin_l", M, (4.3, 6.5, 0.0), (3.0, 2.9, 3.0), "mint")
    crushed_cube(d, "shin_l", M, (4.2, 3.7, 0.2), (3.2, 2.9, 3.0), "mustard")
    tyre(d, "shin_l", M, (4.2, 8.2, 0.7), 1.9, 2.8)
    d.box("shin_r", (-4.2, 5.2, 0.0), (2.6, 5.8, 2.6), M["steel"])
    d.box("shin_r", (-4.2, 5.2, 1.31), (2.2, 5.2, 0.06), M["vent"])
    d.box("shin_r", (-6.2, 4.4, 0.7), (1.1, 2.1, 1.1), M["fridge"])
    d.box("shin_r", (-6.2, 6.7, 0.7), (1.1, 1.9, 1.1), M["fridge"])
    d.box("shin_r", (-4.2, 6.2, 0.0), (2.9, 0.3, 2.9), M["hazard"])
    tyre(d, "shin_r", M, (-4.2, 8.1, -0.6), 1.7, 2.6)
    # ---- thighs: a bundle of pipes (left) and two cars stood on their noses (right)
    ax = unit_v((4.2 - 3.57, 8.0 - 15.2, 0.0))
    R = basis(ax)
    d.push(R, (3.9, 11.6, 0.0))
    for k in range(6):
        a = k * 60.0 * D2R
        d.prism("thigh_l", (1.0 * math.cos(a), 1.0 * math.sin(a), -3.7), (1.0 * math.cos(a), 1.0 * math.sin(a), 3.7), 0.62, 0.62, M["steel"], n=8)
    d.prism("thigh_l", (0, 0, -3.6), (0, 0, 3.6), 0.7, 0.7, M["frame"], n=8)
    for z in (-2.0, 2.0):
        d.box("thigh_l", (0, 0, z), (3.1, 3.1, 0.35), M["hazard"])
    d.pop()
    for k, (y, paint) in enumerate(((13.4, "redpaint"), (9.8, "mustard"))):
        car(d, "thigh_r", M, (-3.9 - 0.3 * k, y, 0.0), basis((0.0, -1.0, 0.0), (0.0, 0.0, 1.0)), 0.85, paint)
    # ---- hips: two containers across, a hazard strap, a counterweight on the back
    container(d, "hips", M, (0.3, 16.3, 1.5), basis((1.0, 0.0, 0.0)), "mustard")
    container(d, "hips", M, (-0.4, 16.4, -1.4), basis((1.0, 0.0, 0.0)), "redpaint")
    d.box("hips", (0.0, 17.75, 0.1), (12.4, 0.3, 5.9), M["hazard"])
    # ---- spine: a stack of tyres
    for k in range(5):
        d.prism("spine", (0, 17.9 + k * 0.85, 0.0), (0, 18.6 + k * 0.85, 0.0), 2.3, 2.3, M["tyre"], n=10)
    d.prism("spine", (0, 19.6, 0), (0, 19.8, 0), 2.45, 2.45, M["hazard"], n=10)
    # ---- chest: rows of containers laid across, a gap in the middle row for the cockpit core, crushed cubes behind
    levels = (20.7, 23.3, 25.9)
    front = ("redpaint", None, "mint")
    back = ("mustard", None, "rust")
    for level, paint in zip(levels, front):
        if paint is not None:
            container(d, "chest", M, (0.0, level, 2.7), basis((1.0, 0.0, 0.0)), paint)
    for sx in (-1, 1):
        container(d, "chest", M, (sx * 4.2, levels[1], 2.7), basis((1.0, 0.0, 0.0)), "mustard", size=(2.44, 2.6, 3.8))
        container(d, "chest", M, (sx * 4.2, levels[1], 0.1), basis((1.0, 0.0, 0.0)), "rust", size=(2.44, 2.6, 3.8))
    for level, paint in zip(levels, back):
        if paint is not None:
            container(d, "chest", M, (0.5, level, 0.1), basis((1.0, 0.0, 0.0)), paint)
    rng = np.random.default_rng(7)
    for ix, x in enumerate((-4.6, -1.6, 1.6, 4.6)):
        for iy, y in enumerate((21.5, 25.0)):
            paint = ("rust", "streak", "mint", "mustard", "redpaint")[(ix * 2 + iy) % 5]
            crushed_cube(d, "chest", M, (x + rng.uniform(-0.3, 0.3), y + rng.uniform(-0.2, 0.2), -3.1), (3.0, 3.4, 3.2), paint)
    # a bus laid across the shoulders, the yoke the head sits on
    bus(d, "chest", M, (0.0, 28.6, -0.2), basis((1.0, 0.0, 0.0)), "mustard")
    # ---- shoulders: tyre pads
    for sx, s in ((1, "l"), (-1, "r")):
        tyre(d, "shoulder_" + s, M, (sx * 7.0, 27.4, 0.0), 1.8, 3.2, (0.0, 0.0, 1.0), n=10)
        tyre(d, "shoulder_" + s, M, (sx * 7.0, 27.4, 0.0), 1.2, 3.5, (0.0, 0.0, 1.0), n=8)
    # ---- left arm: a crane jib (lattice), a hanging hook and a container fist
    lattice_boom(d, "upper_arm_l", M, (6.0, 26.4, 0.0), (10.3, 21.9, 0.0), 1.5, up=(0.0, 0.0, 1.0), bays=5)
    lattice_boom(d, "forearm_l", M, (10.3, 21.9, 0.0), (12.4, 18.9, 0.0), 1.5, up=(0.0, 0.0, 1.0), bays=3)
    container(d, "hand_l", M, (12.8, 16.4, 1.0), basis((0.0, 0.2, 1.0)), "mustard", size=(3.4, 3.4, 5.0))
    d.prism("forearm_l", (9.3, 22.2, 1.0), (9.3, 14.5, 1.0), 0.09, 0.09, M["frame"], n=6)   # the cable
    d.box("forearm_l", (9.3, 14.1, 1.0), (0.7, 0.9, 0.5), M["frame"])                      # the hook block
    # ---- right arm: a bundle of car frames, ending in a crushed-cube fist with tyre claws
    up_axis = np.array([-12.5 + 6.3, 21.9 - 25.2, 0.0])
    for k, (off, paint) in enumerate((((0.0, 0.0), "rust"), ((1.7, 0.4), "mint"), ((-1.6, 0.6), "redpaint"))):
        mid = (np.array([-6.3, 25.2, 0.0]) + np.array([-10.3, 21.9, 0.0])) / 2.0
        R2 = basis(np.array([-10.3 + 6.3, 21.9 - 25.2, 0.0]), (0.0, 0.0, 1.0))
        car(d, "upper_arm_r", M, mid + R2 @ np.array([off[0], off[1], 0.0]), R2, 1.0, paint)
    for k, (off, paint) in enumerate((((0.0, 0.0), "mustard"), ((1.7, 0.3), "rust"))):
        mid = (np.array([-10.3, 21.9, 0.0]) + np.array([-12.6, 18.1, 0.0])) / 2.0
        R2 = basis(np.array([-12.6 + 10.3, 18.1 - 21.9, 0.0]), (0.0, 0.0, 1.0))
        car(d, "forearm_r", M, mid + R2 @ np.array([off[0], off[1], 0.0]), R2, 0.85, paint)
    crushed_cube(d, "hand_r", M, (-12.9, 16.4, 0.4), (3.8, 3.6, 3.8), "redpaint")
    for z in (-1.4, 1.4):
        tyre(d, "hand_r", M, (-12.9, 14.2, z), 1.1, 3.4)
    d.box("upper_arm_r", (-8.3, 23.9, 1.2), (4.6, 0.25, 0.25), M["hazard"], rot=rot_z(-36))
    # ---- tail counterweight
    d.box("tail", (0.0, 19.2, -5.6), (3.8, 2.8, 3.0), M["concrete"])
    d.box("tail", (0.0, 17.2, -5.2), (3.4, 1.6, 2.6), M["rust"])
    car(d, "tail", M, (-2.2, 16.2, -6.0), basis((0.0, 0.0, 1.0)), 0.8, "mint")
    # ---- back: a crane mast (lopsided, to the right), a counter-jib and a hook
    lattice_boom(d, "back", M, (3.0, 21.0, -5.4), (3.0, 35.6, -5.4), 1.7, up=(0.0, 0.0, 1.0), bays=8)
    d.box("back", (3.0, 35.9, -5.4), (1.2, 0.8, 1.2), M["frame"])
    lattice_boom(d, "back", M, (3.0, 35.4, -5.4), (-5.5, 35.0, -5.4), 1.0, up=(0.0, 1.0, 0.0), bays=5)
    d.prism("back", (-5.0, 35.0, -5.4), (-5.0, 29.0, -5.4), 0.07, 0.07, M["frame"], n=6)
    d.box("back", (-5.0, 28.6, -5.4), (0.6, 0.8, 0.5), M["frame"])
    # ---- ears: a loudspeaker horn (left) and a whip antenna with a flag (right); neck: a cable spool
    d.box("ear_l", (5.2, 31.6, -2.6), (1.3, 1.0, 1.2), M["slate"])
    d.box("ear_l", (5.2, 31.6, -1.8), (0.9, 0.7, 0.5), M["frame"])
    d.prism("ear_r", (-5.0, 30.0, -2.6), (-5.0, 37.0, -2.6), 0.12, 0.05, M["frame"], n=6)
    d.box("ear_r", (-4.6, 36.4, -2.6), (0.9, 0.6, 0.05), M["lamp_dim"])
    d.prism("neck", (0.0, 29.9, 0.0), (0.0, 30.4, 0.0), 2.2, 2.2, M["tyre"], n=10)

    # ---- head: floodlights, no face. A slanted rack with a bank of unequal lamps (a grid, three of them dark), a stalk lamp off to
    # the left, and a small jammer dish on a mast. The lamp faces are their own mesh node (floodlights), so code can light them.
    flood = new()
    df = Draw(flood)
    d.push(rot_x(8.0), (0.8, 32.0, 0.4))
    df.push(rot_x(8.0), (0.8, 32.0, 0.4))
    d.box("head", (0.0, 0.0, 0.0), (7.6, 3.4, 0.7), M["frame"])
    d.box("head", (0.0, -1.9, 0.0), (7.8, 0.4, 1.2), M["hazard"])
    for sx in (-3.4, 3.4):
        d.box("head", (sx, -2.6, -0.3), (0.4, 1.6, 0.4), M["frame"])
    cols = (-2.7, -0.95, 0.9, 2.7)
    widths = (1.5, 1.2, 1.5, 1.0)
    for ci, (cx, w) in enumerate(zip(cols, widths)):
        for ri, cy in enumerate((0.8, -0.75)):
            hh = 1.2 if ri == 0 else 1.0
            d.box("head", (cx, cy, 0.5), (w + 0.2, hh + 0.2, 0.35), M["frame"])
            df.box("head", (cx, cy, 0.72), (w, hh, 0.06), M["flood"] if (ci + ri) % 3 != 2 else M["lamp_dim"])
    d.pop()
    df.pop()
    d.prism("head", (-4.8, 30.4, 0.8), (-4.8, 33.6, 0.8), 0.2, 0.15, M["frame"], n=6)
    d.box("head", (-4.8, 33.9, 1.1), (1.5, 1.0, 1.1), M["frame"])
    df.box("head", (-4.8, 33.9, 1.67), (1.2, 0.8, 0.05), M["flood"])
    # the jammer dish: a mast up from the rack and a tilted dish
    d.prism("head_gear", (-1.0, 34.0, -0.6), (-1.0, 37.4, -0.6), 0.3, 0.22, M["slate"], n=8)
    d.push(rot_x(-30.0), (-1.0, 37.9, -0.2))
    d.prism("head_gear", (0, 0, -0.7), (0, 0, 0.1), 0.3, 1.9, M["slate"], n=12)
    d.prism("head_gear", (0, 0, 0.1), (0, 0, 0.14), 1.9, 1.9, M["dish_face"], n=12)
    d.prism("head_gear", (0, 0, 0.14), (0, 0, 0.7), 0.16, 0.26, M["lamp"], n=8)
    d.pop()

    # ---- armour plates: each its own mesh node, bound to its own mount bone
    plate_meshes = []
    for name, (parent, c, size, mat, tilt) in PLATES.items():
        pb = new()
        bone = name + "_mount"
        pd = Draw(pb)
        rot = rot_x(tilt) if tilt else None
        pd.box(bone, c, size, M[mat], rot=rot)
        # rim, rivets and stencils (a Signals poster on the billboard)
        w, h, dd = size
        pd.push(rot, c)
        if name == "plate_chest_front":
            pd.box(bone, (0, 0, dd / 2 + 0.03), (w - 0.8, h - 0.8, 0.05), M["slate"])
            pd.box(bone, (0, h / 2 - 0.9, dd / 2 + 0.07), (w - 1.4, 0.5, 0.05), M["white"])           # a stencil strip along the top
            pd.box(bone, (-1.2, -0.3, dd / 2 + 0.07), (0.9, 4.0, 0.05), M["lamp"], rot=rot_z(28))      # the Signals mark: a slash
            for k in range(3):
                pd.box(bone, (1.8, 0.8 - k * 0.9, dd / 2 + 0.07), (2.6 - 0.5 * k, 0.28, 0.05), M["white"])   # lines of small print
            for sx in (-1, 1):
                pd.prism(bone, (sx * (w / 2 - 0.5), h / 2, 0.0), (sx * (w / 2 - 0.5), h / 2 + 2.0, -0.6), 0.1, 0.1, M["frame"], n=6)   # chains
        elif name == "plate_back":
            pd.box(bone, (0, 0, -dd / 2 - 0.03), (w - 0.8, h - 0.8, 0.05), M["steel"])
            pd.box(bone, (0, 1.4, -dd / 2 - 0.07), (w - 2.0, 0.7, 0.05), M["hazard"])
            pd.box(bone, (0, -1.2, -dd / 2 - 0.07), (3.0, 1.2, 0.05), M["white"])
        else:
            pd.box(bone, (0, h / 2 + 0.03, 0), (w - 0.8, 0.05, dd - 0.8), M["frame"])
        pd.pop()
        plate_meshes.append((name, pb))

    # ---- cockpit core: the clean Signals pod in the chest; window, weak-point glow, a beacon from the Hushmaster's dish
    core = new()
    cd = Draw(core)
    cx, cy, cz = CORE[1]
    cd.box("cockpit_core_mount", (cx, cy, cz), (4.0, 2.6, 3.8), M["signals"])
    cd.box("cockpit_core_mount", (cx, cy + 0.35, cz + 1.92), (2.8, 1.2, 0.08), M["glass"])
    cd.box("cockpit_core_mount", (cx, cy - 0.85, cz + 1.93), (2.8, 0.3, 0.08), M["lamp"])
    cd.box("cockpit_core_mount", (cx, cy + 1.35, cz), (3.2, 0.14, 3.0), M["white"])
    cd.prism("cockpit_core_mount", (cx + 1.0, cy + 1.4, cz - 0.6), (cx + 1.0, cy + 1.7, cz - 0.6), 0.28, 0.2, M["lamp"], n=8)
    for sx in (-1, 1):
        cd.box("cockpit_core_mount", (cx + sx * 2.02, cy, cz), (0.06, 1.8, 3.0), M["slate"])

    meshes = [("junk_mech_body", body), ("floodlights", flood)] + plate_meshes + [("cockpit_core", core)]
    return write_rigged(path, shared, rig, meshes, "junk_mech", "Placeholder blockout by the Technical Artist (task VS-24): the giant junk mech, 40 m, Red's bone names scaled x%.1f. No face." % U)


# ------------------------------------------------------------------ ARENA PIECES (origin on the floor, centre of the footprint)
def build_wall(path):
    sc = Scene()
    M = palette(sc.shared)
    b = sc.builder()
    d = Draw(b)
    for level, paint in enumerate(("redpaint", "mint", "mustard")):
        container(d, None, M, (0.0, 1.3 + level * 2.6, 0.0), basis((1.0, 0.0, 0.0)), paint)
    d.box(None, (0.0, 7.9, 0.0), (12.3, 0.2, 2.6), M["hazard"])
    for x in (-5.8, 5.8):
        d.box(None, (x, 3.9, 1.3), (0.3, 7.8, 0.12), M["frame"])
    car(d, None, M, (-3.0, 0.97, 2.4), basis((1.0, 0.0, 0.0)), 1.0, "rust")
    car(d, None, M, (3.2, 0.97, 2.4), basis((1.0, 0.0, 0.0)), 1.0, "streak")
    tyre(d, None, M, (0.0, 0.6, -1.7), 0.6, 12.0, (1.0, 0.0, 0.0), n=8)
    sc.node("arena_wall_segment", builder=b)
    return write_scene(path, sc, "arena_wall_segment", "Stockade wall segment, 8 m high, 12.2 m long. Stack them around r = 62 m.")


def build_gate_post(path):
    sc = Scene()
    M = palette(sc.shared)
    b = sc.builder()
    d = Draw(b)
    d.box(None, (0, 4.6, 0), (3.2, 9.2, 3.2), M["signals_plate"])
    d.box(None, (0, 0.5, 0), (4.0, 1.0, 4.0), M["concrete"])
    for y in (2.5, 5.5):
        d.box(None, (0, y, 0), (3.3, 0.5, 3.3), M["hazard"])
    d.box(None, (0, 9.6, 0), (3.6, 0.8, 3.6), M["frame"])
    d.box(None, (0, 10.5, 0.4), (2.8, 1.0, 1.6), M["frame"])
    d.box(None, (0, 10.5, 1.25), (2.4, 0.7, 0.06), M["flood"])
    d.box(None, (0, 4.6, 1.62), (1.4, 3.0, 0.06), M["vent"])
    sc.node("arena_gate_post", builder=b)
    return write_scene(path, sc, "arena_gate_post", "Gate post, 11 m with its floodlight. Two of them frame the E and S gates.")


def build_rail(path):
    sc = Scene()
    M = palette(sc.shared)
    b = sc.builder()
    d = Draw(b)
    for x in (-2.0, -1.0, 0.0, 1.0, 2.0):
        d.box(None, (x, 0.55, 0), (0.1, 1.1, 0.1), M["frame"])
    d.box(None, (0, 1.07, 0), (4.1, 0.08, 0.08), M["white"])
    d.box(None, (0, 0.6, 0), (4.0, 0.05, 0.05), M["frame"])
    d.box(None, (0, 0.04, 0), (4.1, 0.08, 0.24), M["hazard"])
    sc.node("plateau_rail_segment", builder=b)
    return write_scene(path, sc, "plateau_rail_segment", "Plateau rail, 1.1 m high, 4 m long: a real rail, with the see-through look left to the game.")


def pile(d, M, seed, radius, height, count, scale=1.0, bone=None):
    rng = np.random.default_rng(seed)
    d.prism(bone, (0, 0, 0), (0, height * 0.72, 0), radius * 0.95, radius * 0.12, M["streak"], n=8)
    kinds = ("car", "cube", "container", "tyre", "fridge", "cube", "car")
    paints = ("rust", "mint", "mustard", "redpaint", "streak", "steel")
    for i in range(count):
        r = radius * (rng.uniform(0, 1) ** 0.8)
        ang = rng.uniform(0, 2 * math.pi)
        surf = height * max(0.0, 1.0 - r / radius) ** 1.1
        kind = kinds[int(rng.integers(0, len(kinds)))]
        paint = paints[int(rng.integers(0, len(paints)))]
        yaw = rng.uniform(0, 360)
        tilt = rot_x(rng.uniform(-18, 18)) @ rot_z(rng.uniform(-18, 18))
        R = rot_y(yaw) @ tilt
        pos = np.array([r * math.cos(ang), surf, r * math.sin(ang)])
        s = scale
        if kind == "car":
            car(d, bone, M, np.array([pos[0], max(pos[1] + 0.5 * s, 1.9 * s), pos[2]]), R, s, paint)
        elif kind == "cube":
            c = s * rng.uniform(1.4, 2.4)
            crushed_cube(d, bone, M, np.array([pos[0], max(pos[1] + c * 0.4, c * 0.9), pos[2]]), (c, c * 0.9, c), paint, R)
        elif kind == "container":
            ln = rng.uniform(4.0, 12.2) * s
            container(d, bone, M, np.array([pos[0], max(pos[1] + 1.0 * s, 1.3 * s + 0.32 * ln), pos[2]]), R, paint, size=(2.44 * s, 2.6 * s, ln))
        elif kind == "tyre":
            tyre(d, bone, M, pos + np.array([0, 0.9 * s, 0]), 0.6 * s, 0.4 * s, R @ np.array([1.0, 0, 0]))
        else:
            d.box(bone, np.array([pos[0], max(pos[1] + 0.6 * s, 1.3 * s), pos[2]]), (0.9 * s, 1.8 * s, 0.9 * s), M["fridge"], rot=R)


def build_pile(path, name, seed, radius, height, count, scale, note):
    sc = Scene()
    M = palette(sc.shared)
    b = sc.builder()
    d = Draw(b)
    pile(d, M, seed, radius, height, count, scale)
    sc.node(name, builder=b)
    return write_scene(path, sc, name, note)


def build_turret_pylon(path):
    sc = Scene()
    M = palette(sc.shared)
    root = sc.node("arena_turret_pylon")
    b = sc.builder()
    d = Draw(b)
    d.box(None, (0, 0.2, 0), (1.6, 0.4, 1.6), M["concrete"])
    d.box(None, (0, 1.4, 0), (0.9, 2.2, 0.9), M["signals_plate"])
    d.box(None, (0, 1.0, 0.46), (0.5, 0.7, 0.04), M["white"])            # a memo plate (the Writer's text goes on it)
    d.box(None, (0, 2.45, 0), (1.1, 0.1, 1.1), M["hazard"])
    sc.node("pylon", root, builder=b)
    b = sc.builder()
    d = Draw(b)
    d.prism(None, (0, 0, 0), (0, 0.3, 0), 0.5, 0.45, M["slate"], n=8)
    sc.node("turret_base", root, t=(0, 2.5, 0), builder=b)
    b = sc.builder()
    d = Draw(b)
    d.box(None, (0, 0.35, 0), (0.8, 0.5, 0.8), M["signals"])
    d.box(None, (0, 0.35, 0.42), (0.3, 0.3, 0.06), M["lamp"])
    sc.node("turret_head", "turret_base", t=(0, 0.3, 0), builder=b)
    b = sc.builder()
    d = Draw(b)
    d.prism(None, (0, 0, 0), (0, 0, 1.1), 0.09, 0.07, M["frame"], n=8)
    sc.node("turret_barrel", "turret_head", t=(0, 0.35, 0.45), builder=b)
    return write_scene(path, sc, "arena_turret_pylon", "2.5 m pylon with a 1.2 m turret (base, swivel head, barrel are separate nodes).")


# ------------------------------------------------------------------ main
def report(name, path, tris):
    print("%-26s %6d tris  %5d KB" % (name, tris, os.path.getsize(path) // 1024))


def main():
    os.makedirs(ARENA, exist_ok=True)
    jobs = [
        ("hushmaster", os.path.join(OUT, "hushmaster.glb"), build_hushmaster),
        ("kasp", os.path.join(OUT, "kasp.glb"), build_kasp),
        ("junk_mech", os.path.join(OUT, "junk_mech.glb"), build_mech),
        ("arena_wall_segment", os.path.join(ARENA, "arena_wall_segment.glb"), build_wall),
        ("arena_gate_post", os.path.join(ARENA, "arena_gate_post.glb"), build_gate_post),
        ("plateau_rail_segment", os.path.join(ARENA, "plateau_rail_segment.glb"), build_rail),
        ("arena_turret_pylon", os.path.join(ARENA, "arena_turret_pylon.glb"), build_turret_pylon),
        ("scrap_pile_s", os.path.join(ARENA, "scrap_pile_s.glb"), lambda p: build_pile(p, "scrap_pile_s", 11, 2.4, 2.4, 14, 0.6, "Scrap pile, about 2.5 m.")),
        ("scrap_pile_m", os.path.join(ARENA, "scrap_pile_m.glb"), lambda p: build_pile(p, "scrap_pile_m", 12, 3.6, 4.0, 28, 0.8, "Scrap pile, about 4.5 m.")),
        ("scrap_pile_l", os.path.join(ARENA, "scrap_pile_l.glb"), lambda p: build_pile(p, "scrap_pile_l", 13, 5.2, 5.4, 46, 1.0, "Scrap pile, about 6 m.")),
        ("scrap_heap_giant", os.path.join(ARENA, "scrap_heap_giant.glb"), lambda p: build_pile(p, "scrap_heap_giant", 14, 26.0, 34.0, 150, 4.5, "Giant heap for the colossus-scale bowl, about 35 m.")),
    ]
    for name, path, fn in jobs:
        report(name, path, fn(path))


if __name__ == "__main__":
    main()
