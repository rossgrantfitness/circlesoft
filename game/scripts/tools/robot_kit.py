"""Tiny placeholder-model kit for the robot scale test (scripts/tools/make_robots.py). Pure Python + numpy, no Blender.

It builds low-poly "blockout" meshes from boxes, tapered boxes and prisms, binds every piece rigidly to ONE bone (weight 1), and
writes a .glb (skinned when a skeleton is given, a plain static mesh when not). Colours are glTF material colours; "tile"
materials embed one of Ross's city tiles (read-only copy of the PNG bytes, never edited) with world-metre UVs, so the plating
density is set by `tile_m` (metres per tile repeat) and can be changed in make_robots.py.

Axes: glTF space, Y up, the model faces +Z, left (l) is +X. Units are metres. Designs are written in "design units" (Red's own
metres: she is 0.95 tall) and multiplied by `unit` when a piece is added, so the same drawing scales to any robot.
"""
import json
import math
import struct
import zlib

import numpy as np

from glb_kit import Skeleton, _write, mat_to_quat


# ------------------------------------------------------------------ png (read and write, no Pillow)
def read_png(path):
    """(width, height, rgba uint8 array) of an 8-bit non-interlaced PNG."""
    with open(path, "rb") as f:
        data = f.read()
    assert data[:8] == b"\x89PNG\r\n\x1a\n"
    off, idat, palette, trns = 8, b"", None, None
    while off < len(data):
        n, kind = struct.unpack_from(">I4s", data, off)
        body = data[off + 8:off + 8 + n]
        if kind == b"IHDR":
            w, h, depth, ctype, _, _, inter = struct.unpack(">IIBBBBB", body)
        elif kind == b"PLTE":
            palette = np.frombuffer(body, dtype=np.uint8).reshape(-1, 3)
        elif kind == b"tRNS":
            trns = np.frombuffer(body, dtype=np.uint8)
        elif kind == b"IDAT":
            idat += body
        off += 12 + n
    assert depth == 8 and inter == 0, "only 8-bit non-interlaced PNGs"
    channels = {0: 1, 2: 3, 3: 1, 4: 2, 6: 4}[ctype]
    raw = np.frombuffer(zlib.decompress(idat), dtype=np.uint8)
    stride = w * channels
    out = np.zeros((h, stride), dtype=np.int32)
    pos = 0
    for y in range(h):
        ft = raw[pos]
        line = raw[pos + 1:pos + 1 + stride].astype(np.int32)
        pos += 1 + stride
        prev = out[y - 1] if y else np.zeros(stride, dtype=np.int32)
        if ft == 0:
            cur = line
        elif ft == 2:
            cur = (line + prev) & 255
        else:
            cur = np.zeros(stride, dtype=np.int32)
            for x in range(stride):
                a = cur[x - channels] if x >= channels else 0
                b = prev[x]
                c = prev[x - channels] if x >= channels else 0
                if ft == 1:
                    p = a
                elif ft == 3:
                    p = (a + b) // 2
                else:
                    pa, pb, pc = abs(b - c), abs(a - c), abs(a + b - 2 * c)
                    p = a if (pa <= pb and pa <= pc) else (b if pb <= pc else c)
                cur[x] = (line[x] + p) & 255
        out[y] = cur
    img = out.reshape(h, w, channels).astype(np.uint8)
    if ctype == 3:
        rgb = palette[img[:, :, 0]]
        alpha = np.full((h, w, 1), 255, dtype=np.uint8)
        if trns is not None:
            alpha = np.where(img[:, :, 0] < len(trns), trns[np.minimum(img[:, :, 0], len(trns) - 1)], 255).astype(np.uint8)[:, :, None]
        return w, h, np.concatenate([rgb, alpha], axis=2)
    if channels == 1:
        return w, h, np.concatenate([img] * 3 + [np.full_like(img, 255)], axis=2)
    if channels == 2:
        return w, h, np.concatenate([img[:, :, :1]] * 3 + [img[:, :, 1:]], axis=2)
    if channels == 3:
        return w, h, np.concatenate([img, np.full((h, w, 1), 255, dtype=np.uint8)], axis=2)
    return w, h, img


def write_png_bytes(rgb):
    """PNG file bytes of an (h, w, 3) uint8 array."""
    h, w, _ = rgb.shape
    raw = b"".join(b"\x00" + rgb[y].tobytes() for y in range(h))

    def chunk(kind, body):
        c = struct.pack(">I", len(body)) + kind + body
        return c + struct.pack(">I", zlib.crc32(kind + body) & 0xFFFFFFFF)

    return b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 2, 0, 0, 0)) + chunk(b"IDAT", zlib.compress(raw, 9)) + chunk(b"IEND", b"")


# ------------------------------------------------------------------ the builder
def _to_linear(c):
    c = float(c)
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def _unit(v):
    v = np.asarray(v, dtype=float)
    return v / np.linalg.norm(v)


class Builder:
    """Collects pieces. `unit` multiplies every design coordinate. `joint_index` maps a bone name to its skin joint index
    (None for a static model, where the bone argument is ignored)."""

    def __init__(self, unit=1.0, joint_index=None):
        self.unit = float(unit)
        self.joint_index = joint_index
        self.materials = {}                  # name -> dict(color, tile (png bytes key) or None, tile_m)
        self.images = {}                     # key -> png bytes
        self.prims = {}                      # material name -> dict(pos, nor, uv, joint, idx)
        self.tri_count = 0

    # ---- materials
    def material(self, name, color, tile=None, tile_m=1.0, rough=0.9):
        """color is a tint (r, g, b) 0..1 (the base colour for a flat material). tile is (key, png bytes)."""
        color = tuple(_to_linear(c) for c in color)     # glTF colour factors are linear; the colours here are written as screen (sRGB) values
        self.materials[name] = {"color": tuple(color), "tile": tile[0] if tile else None, "tile_m": tile_m, "rough": rough}
        if tile:
            self.images[tile[0]] = tile[1]
        return name

    # ---- raw triangles
    def _prim(self, mat):
        return self.prims.setdefault(mat, {"pos": [], "nor": [], "uv": [], "joint": [], "idx": [], "n": 0})

    def _joint(self, bone):
        return 0 if self.joint_index is None else self.joint_index[bone]

    def _uv(self, mat, p, n):
        info = self.materials[mat]
        if info["tile"] is None:
            return np.zeros(2)
        a = int(np.argmax(np.abs(n)))
        s = 1.0 / info["tile_m"]
        if a == 0:
            return np.array([p[2] * s, -p[1] * s])
        if a == 1:
            return np.array([p[0] * s, p[2] * s])
        return np.array([p[0] * s, -p[1] * s])

    def _face(self, bone, mat, pts, normal=None, smooth_normals=None):
        """A convex polygon (list of points, metres) as a triangle fan; winding fixed to face `normal` (computed if None)."""
        pts = [np.asarray(p, dtype=float) for p in pts]
        nrm = np.cross(pts[1] - pts[0], pts[2] - pts[0])
        if normal is None:
            normal = nrm
        if np.dot(nrm, normal) < 0:
            pts = pts[::-1]
            if smooth_normals is not None:
                smooth_normals = smooth_normals[::-1]
        length = np.linalg.norm(normal)
        if length < 1e-12:
            return
        flat = normal / length
        pr = self._prim(mat)
        base = pr["n"]
        for i, p in enumerate(pts):
            n = flat if smooth_normals is None else smooth_normals[i]
            pr["pos"].append(p)
            pr["nor"].append(n)
            pr["uv"].append(self._uv(mat, p, flat))
            pr["joint"].append(self._joint(bone))
        for i in range(1, len(pts) - 1):
            pr["idx"].extend([base, base + i, base + i + 1])
            self.tri_count += 1
        pr["n"] += len(pts)

    # ---- shapes (design units in, metres stored)
    def frustum(self, bone, p0, p1, r0, r1, mat, n=4, hint=(0.0, 0.0, 1.0), rot=None, smooth=None, caps=(True, True)):
        """A tapered prism from p0 to p1. r0/r1 are (half width, half depth) at each end (a number means a circle/square).
        n=4 gives a box-like block with flat sides (half sizes exactly r), n>=6 a prism (smooth shaded when n>=8).
        rot is a 3x3 rotation applied about the middle of the piece."""
        u = self.unit
        p0, p1 = np.asarray(p0, dtype=float) * u, np.asarray(p1, dtype=float) * u
        r0 = np.broadcast_to(np.asarray(r0, dtype=float), (2,)) * u
        r1 = np.broadcast_to(np.asarray(r1, dtype=float), (2,)) * u
        axis = p1 - p0
        a = _unit(axis)
        h = np.asarray(hint, dtype=float)
        if abs(np.dot(h, a)) > 0.95:
            h = np.array([1.0, 0.0, 0.0])
        s = _unit(np.cross(h, a))
        t = np.cross(a, s)
        off, k = (math.pi / 4.0, math.sqrt(2.0)) if n == 4 else (0.0, 1.0)
        if smooth is None:
            smooth = n >= 8
        mid = (p0 + p1) / 2.0

        def ring(p, r):
            out, radial = [], []
            for i in range(n):
                ang = 2.0 * math.pi * i / n + off
                d = s * math.cos(ang) * r[0] * k + t * math.sin(ang) * r[1] * k
                out.append(p + d)
                radial.append(_unit(s * math.cos(ang) * max(r[1], 1e-9) + t * math.sin(ang) * max(r[0], 1e-9)))
            return out, radial

        ra, na = ring(p0, r0)
        rb, nb = ring(p1, r1)
        if rot is not None:
            rm = np.asarray(rot, dtype=float)
            ra = [mid + rm @ (q - mid) for q in ra]
            rb = [mid + rm @ (q - mid) for q in rb]
            na = [rm @ q for q in na]
            nb = [rm @ q for q in nb]
            a = rm @ a
        for i in range(n):
            j = (i + 1) % n
            quad = [ra[i], ra[j], rb[j], rb[i]]
            outward = (quad[0] + quad[1] + quad[2] + quad[3]) / 4.0 - (mid if rot is None else mid)
            axis_part = np.dot(outward, a) * a
            outward = outward - axis_part
            sn = [na[i], na[j], nb[j], nb[i]] if smooth else None
            self._face(bone, mat, quad, normal=outward, smooth_normals=sn)
        if caps[0]:
            self._face(bone, mat, ra, normal=-a)
        if caps[1]:
            self._face(bone, mat, rb, normal=a)

    def box(self, bone, center, size, mat, rot=None):
        """An axis-aligned block (size = full width, height, depth), optionally rotated about its centre."""
        c = np.asarray(center, dtype=float)
        h = np.asarray(size, dtype=float) / 2.0
        self.frustum(bone, c - np.array([0.0, h[1], 0.0]), c + np.array([0.0, h[1], 0.0]), (h[0], h[2]), (h[0], h[2]), mat, n=4, rot=rot)

    def prism(self, bone, p0, p1, r0, r1, mat, n=8, caps=(True, True)):
        self.frustum(bone, p0, p1, r0, r1, mat, n=n, caps=caps)

    def quad(self, bone, corners, mat):
        self._face(bone, mat, [np.asarray(c, dtype=float) * self.unit for c in corners])

    def row(self, bone, p0, p1, count, size, mat):
        """`count` small blocks evenly from p0 to p1 (rivet rows, vent slats)."""
        p0, p1 = np.asarray(p0, dtype=float), np.asarray(p1, dtype=float)
        for i in range(count):
            f = 0.5 if count == 1 else i / (count - 1)
            self.box(bone, p0 + (p1 - p0) * f, size, mat)

    # ---- output
    def used_materials(self):
        return [m for m in self.materials if m in self.prims]


def rot_x(deg):
    r = math.radians(deg)
    return np.array([[1, 0, 0], [0, math.cos(r), -math.sin(r)], [0, math.sin(r), math.cos(r)]])


def rot_y(deg):
    r = math.radians(deg)
    return np.array([[math.cos(r), 0, math.sin(r)], [0, 1, 0], [-math.sin(r), 0, math.cos(r)]])


def rot_z(deg):
    r = math.radians(deg)
    return np.array([[math.cos(r), -math.sin(r), 0], [math.sin(r), math.cos(r), 0], [0, 0, 1]])


# ------------------------------------------------------------------ skeleton from Red
def scaled_rig(red_doc, unit, extras):
    """The skeleton node list of Red's rigged file with every offset multiplied by `unit`, plus extra bones.
    extras: list of dict(name, parent, at=(x, y, z) in DESIGN units, world position). Extra bones keep world-aligned axes.
    Returns (nodes, joints (node indices in skin order), name->node index, skin json, mesh node index, armature node index)."""
    nodes = json.loads(json.dumps(red_doc["nodes"]))
    for n in nodes:
        n.pop("scale", None)
        if "translation" in n:
            n["translation"] = [float(x) * unit for x in n["translation"]]
    skin = red_doc["skins"][0]
    joints = list(skin["joints"])
    for ex in extras:
        sk = Skeleton({"nodes": nodes})
        parent = sk.bone(ex["parent"])
        world = np.asarray(ex["at"], dtype=float) * unit
        rp = sk.rest_world_r[parent]
        local_t = rp.T @ (world - sk.rest_world_p[parent])
        q = mat_to_quat(rp.T)
        nodes.append({"name": ex["name"], "translation": [float(x) for x in local_t], "rotation": [float(x) for x in q]})
        idx = len(nodes) - 1
        nodes[parent].setdefault("children", []).append(idx)
        joints.append(idx)
    names = {n["name"]: i for i, n in enumerate(nodes)}
    mesh_node = next(i for i, n in enumerate(nodes) if "mesh" in n)
    arm = next(i for i, n in enumerate(nodes) if mesh_node in n.get("children", []))
    return nodes, joints, names, mesh_node, arm


# ------------------------------------------------------------------ glb writer
class Pack:
    def __init__(self):
        self.data = bytearray()
        self.views = []
        self.accessors = []

    def view(self, raw, target=None):
        off = len(self.data)
        self.data.extend(raw)
        self.data.extend(b"\x00" * (-len(self.data) % 4))
        v = {"buffer": 0, "byteOffset": off, "byteLength": len(raw)}
        if target:
            v["target"] = target
        self.views.append(v)
        return len(self.views) - 1

    def accessor(self, arr, component, kind, target=None, bounds=False):
        arr = np.ascontiguousarray(arr)
        a = {"bufferView": self.view(arr.tobytes(), target), "componentType": component, "count": int(arr.shape[0]), "type": kind}
        if bounds:
            flat = arr.reshape(arr.shape[0], -1)
            a["min"] = [float(x) for x in flat.min(axis=0)]
            a["max"] = [float(x) for x in flat.max(axis=0)]
        self.accessors.append(a)
        return len(self.accessors) - 1


def write_glb(path, builder, model_name, rig=None, red_doc=None, note=""):
    """Writes the builder's meshes. rig = (nodes, joints, names, mesh_node, arm) for a skinned model, else a static one."""
    pack = Pack()
    images, textures, materials = [], [], []
    image_of = {}
    for key, raw in builder.images.items():
        image_of[key] = len(images)
        images.append({"bufferView": pack.view(raw), "mimeType": "image/png", "name": key})
        textures.append({"source": len(images) - 1, "sampler": 0})
    mat_index = {}
    for name in builder.used_materials():
        info = builder.materials[name]
        pbr = {"baseColorFactor": [info["color"][0], info["color"][1], info["color"][2], 1.0], "metallicFactor": 0.0, "roughnessFactor": info["rough"]}
        if info["tile"] is not None:
            pbr["baseColorTexture"] = {"index": image_of[info["tile"]]}
        materials.append({"name": name, "pbrMetallicRoughness": pbr, "doubleSided": False})
        mat_index[name] = len(materials) - 1
    prims = []
    for name in builder.used_materials():
        pr = builder.prims[name]
        attrs = {
            "POSITION": pack.accessor(np.array(pr["pos"], dtype="<f4"), 5126, "VEC3", 34962, bounds=True),
            "NORMAL": pack.accessor(np.array(pr["nor"], dtype="<f4"), 5126, "VEC3", 34962),
            "TEXCOORD_0": pack.accessor(np.array(pr["uv"], dtype="<f4"), 5126, "VEC2", 34962),
        }
        if rig is not None:
            n = len(pr["pos"])
            j = np.zeros((n, 4), dtype="<u2")
            j[:, 0] = np.array(pr["joint"], dtype="<u2")
            w = np.zeros((n, 4), dtype="<f4")
            w[:, 0] = 1.0
            attrs["JOINTS_0"] = pack.accessor(j, 5123, "VEC4", 34962)
            attrs["WEIGHTS_0"] = pack.accessor(w, 5126, "VEC4", 34962)
        idx = pack.accessor(np.array(pr["idx"], dtype="<u2"), 5123, "SCALAR", 34963)
        prims.append({"attributes": attrs, "indices": idx, "material": mat_index[name], "mode": 4})
    doc = {"asset": {"version": "2.0", "generator": "circlesoft scripts/tools/make_robots.py (placeholder blockout)", "extras": {"note": note}},
           "samplers": [{"magFilter": 9729, "minFilter": 9987, "wrapS": 10497, "wrapT": 10497}],
           "materials": materials, "meshes": [{"name": model_name, "primitives": prims}]}
    if images:
        doc["images"], doc["textures"] = images, textures
    if rig is None:
        doc["nodes"] = [{"name": model_name, "mesh": 0}]
        doc["scenes"] = [{"name": "Scene", "nodes": [0]}]
        doc["scene"] = 0
    else:
        nodes, joints, names, mesh_node, arm = rig
        nodes = json.loads(json.dumps(nodes))
        sk = Skeleton({"nodes": nodes})
        ibm = np.zeros((len(joints), 16), dtype="<f4")
        for k, node in enumerate(joints):
            m = np.eye(4)
            m[:3, :3] = sk.rest_world_r[node]
            m[:3, 3] = sk.rest_world_p[node]
            ibm[k] = np.linalg.inv(m).T.flatten()
        nodes[mesh_node]["name"] = model_name
        nodes[arm]["name"] = model_name + "_armature"
        skin = {"name": model_name + "_armature", "joints": joints, "inverseBindMatrices": pack.accessor(ibm, 5126, "MAT4")}
        doc["nodes"] = nodes
        doc["skins"] = [skin]
        doc["scenes"] = [{"name": "Scene", "nodes": [arm]}]
        doc["scene"] = 0
        nodes[mesh_node]["mesh"] = 0
        nodes[mesh_node]["skin"] = 0
    doc["accessors"], doc["bufferViews"] = pack.accessors, pack.views
    doc["buffers"] = [{"byteLength": len(pack.data)}]
    _write(path, doc, bytes(pack.data))
