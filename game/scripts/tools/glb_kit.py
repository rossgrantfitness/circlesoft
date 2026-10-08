"""Small pure-Python glTF/GLB kit for the Animator's retarget pipeline (retarget_ual.py). Needs only numpy: no Blender.

What it does:
  - reads a .glb (JSON chunk + binary chunk) and reads accessors as numpy arrays;
  - builds a Skeleton (node tree, rest pose, forward kinematics) from the glTF nodes;
  - samples glTF animations (linear / step) at any time;
  - writes a .glb again with the unused buffer data dropped and new animations appended.

Conventions: glTF space is Y-up, the model faces +Z, quaternions are (x, y, z, w). Rotations are 3x3 matrices inside the
tool, quaternions only at the file boundary. Scale is assumed to be 1 (every rig and clip we use satisfies that to 1e-5).
"""
import json
import struct

import numpy as np

COMPONENT = {5120: np.int8, 5121: np.uint8, 5122: np.int16, 5123: np.uint16, 5125: np.uint32, 5126: np.float32}
TYPE_N = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4, "MAT2": 4, "MAT3": 9, "MAT4": 16}


# ------------------------------------------------------------------ file io
def load_glb(path):
    """(json dict, binary blob bytes)."""
    with open(path, "rb") as f:
        data = f.read()
    magic, version, _length = struct.unpack_from("<4sII", data, 0)
    if magic != b"glTF" or version != 2:
        raise ValueError("%s is not a glTF 2 binary" % path)
    doc, blob, off = None, b"", 12
    while off < len(data):
        clen, ctype = struct.unpack_from("<II", data, off)
        chunk = data[off + 8:off + 8 + clen]
        if ctype == 0x4E4F534A:
            doc = json.loads(chunk.decode("utf-8"))
        elif ctype == 0x004E4942:
            blob = bytes(chunk)
        off += 8 + clen
    return doc, blob


def read_accessor(doc, blob, index):
    acc = doc["accessors"][index]
    n = TYPE_N[acc["type"]]
    dtype = np.dtype(COMPONENT[acc["componentType"]])
    count = acc["count"]
    view = doc["bufferViews"][acc["bufferView"]]
    start = view.get("byteOffset", 0) + acc.get("byteOffset", 0)
    stride = view.get("byteStride", 0) or n * dtype.itemsize
    if stride == n * dtype.itemsize:
        arr = np.frombuffer(blob, dtype=dtype, count=count * n, offset=start).reshape(count, n)
    else:
        arr = np.empty((count, n), dtype=dtype)
        for i in range(count):
            arr[i] = np.frombuffer(blob, dtype=dtype, count=n, offset=start + i * stride)
    arr = arr.astype(np.float64) if dtype == np.float32 else arr
    return arr[:, 0] if n == 1 else arr


# ------------------------------------------------------------------ rotations
def quat_to_mat(q):
    x, y, z, w = q / np.linalg.norm(q)
    return np.array([
        [1 - 2 * (y * y + z * z), 2 * (x * y - z * w), 2 * (x * z + y * w)],
        [2 * (x * y + z * w), 1 - 2 * (x * x + z * z), 2 * (y * z - x * w)],
        [2 * (x * z - y * w), 2 * (y * z + x * w), 1 - 2 * (x * x + y * y)]])


def mat_to_quat(m):
    t = m[0, 0] + m[1, 1] + m[2, 2]
    if t > 0:
        s = np.sqrt(t + 1.0) * 2
        q = np.array([(m[2, 1] - m[1, 2]) / s, (m[0, 2] - m[2, 0]) / s, (m[1, 0] - m[0, 1]) / s, 0.25 * s])
    elif m[0, 0] > m[1, 1] and m[0, 0] > m[2, 2]:
        s = np.sqrt(1.0 + m[0, 0] - m[1, 1] - m[2, 2]) * 2
        q = np.array([0.25 * s, (m[0, 1] + m[1, 0]) / s, (m[0, 2] + m[2, 0]) / s, (m[2, 1] - m[1, 2]) / s])
    elif m[1, 1] > m[2, 2]:
        s = np.sqrt(1.0 + m[1, 1] - m[0, 0] - m[2, 2]) * 2
        q = np.array([(m[0, 1] + m[1, 0]) / s, 0.25 * s, (m[1, 2] + m[2, 1]) / s, (m[0, 2] - m[2, 0]) / s])
    else:
        s = np.sqrt(1.0 + m[2, 2] - m[0, 0] - m[1, 1]) * 2
        q = np.array([(m[0, 2] + m[2, 0]) / s, (m[1, 2] + m[2, 1]) / s, 0.25 * s, (m[1, 0] - m[0, 1]) / s])
    return q / np.linalg.norm(q)


def slerp(a, b, t):
    d = float(np.dot(a, b))
    if d < 0.0:
        b, d = -b, -d
    if d > 0.9995:
        r = a + (b - a) * t
        return r / np.linalg.norm(r)
    th = np.arccos(d)
    return (np.sin((1 - t) * th) * a + np.sin(t * th) * b) / np.sin(th)


def axis_angle(axis, deg):
    a = np.asarray(axis, dtype=float)
    a = a / np.linalg.norm(a)
    r = np.radians(deg)
    k = np.array([[0, -a[2], a[1]], [a[2], 0, -a[0]], [-a[1], a[0], 0]])
    return np.eye(3) + np.sin(r) * k + (1 - np.cos(r)) * (k @ k)


def euler_deg(x=0.0, y=0.0, z=0.0):
    """Rotation about world X, then Y, then Z (applied in that order to a vector: Rz @ Ry @ Rx)."""
    return axis_angle((0, 0, 1), z) @ axis_angle((0, 1, 0), y) @ axis_angle((1, 0, 0), x)


def swing(a, b):
    """Shortest-arc rotation matrix taking direction a onto direction b."""
    a = np.asarray(a, dtype=float)
    b = np.asarray(b, dtype=float)
    a = a / np.linalg.norm(a)
    b = b / np.linalg.norm(b)
    v = np.cross(a, b)
    c = float(np.dot(a, b))
    if np.linalg.norm(v) < 1e-9:
        if c > 0:
            return np.eye(3)
        helper = np.array([1.0, 0, 0]) if abs(a[0]) < 0.9 else np.array([0, 1.0, 0])
        return axis_angle(np.cross(a, helper), 180.0)
    k = np.array([[0, -v[2], v[1]], [v[2], 0, -v[0]], [-v[1], v[0], 0]])
    return np.eye(3) + k + (k @ k) * (1.0 / (1.0 + c))


# ------------------------------------------------------------------ skeleton
class Skeleton:
    """Node tree of a glTF scene with a rest pose and forward kinematics (rotation + position, no scale)."""

    def __init__(self, doc):
        self.doc = doc
        self.nodes = doc["nodes"]
        self.name = [n.get("name", "node%d" % i) for i, n in enumerate(self.nodes)]
        self.index = {n: i for i, n in enumerate(self.name)}
        self.parent = [None] * len(self.nodes)
        for i, n in enumerate(self.nodes):
            for c in n.get("children", []):
                self.parent[c] = i
        roots = [i for i, p in enumerate(self.parent) if p is None]
        # evaluation order: parents before children
        self.order = []
        stack = list(reversed(roots))
        while stack:
            i = stack.pop()
            self.order.append(i)
            stack.extend(reversed(self.nodes[i].get("children", [])))
        self.rest_t = np.array([n.get("translation", [0, 0, 0]) for n in self.nodes], dtype=float)
        self.rest_q = np.array([n.get("rotation", [0, 0, 0, 1]) for n in self.nodes], dtype=float)
        self.rest_r = np.array([quat_to_mat(q) for q in self.rest_q])
        self.rest_world_r, self.rest_world_p = self.fk(self.rest_r, self.rest_t)

    def bone(self, name):
        return self.index[name]

    def fk(self, local_r, local_t):
        """local_r (N,3,3), local_t (N,3) -> world rotations (N,3,3) and positions (N,3)."""
        wr = np.empty_like(local_r)
        wp = np.empty_like(local_t)
        for i in self.order:
            p = self.parent[i]
            if p is None:
                wr[i], wp[i] = local_r[i], local_t[i]
            else:
                wr[i] = wr[p] @ local_r[i]
                wp[i] = wp[p] + wr[p] @ local_t[i]
        return wr, wp

    def local_from_world(self, world_r, i, parent_world_r):
        return parent_world_r.T @ world_r


# ------------------------------------------------------------------ animation sampling
class Clip:
    """One glTF animation: per node, a list of (times, values) for translation and rotation."""

    def __init__(self, doc, blob, anim, skeleton):
        self.name = anim.get("name", "")
        self.rot, self.pos = {}, {}
        self.length = 0.0
        for ch in anim["channels"]:
            node = ch["target"].get("node")
            path = ch["target"]["path"]
            if node is None or path not in ("rotation", "translation"):
                continue
            s = anim["samplers"][ch["sampler"]]
            times = read_accessor(doc, blob, s["input"])
            vals = read_accessor(doc, blob, s["output"])
            step = s.get("interpolation", "LINEAR") == "STEP"
            if s.get("interpolation") == "CUBICSPLINE":
                vals = vals[1::3]
            (self.rot if path == "rotation" else self.pos)[node] = (times, vals, step)
            self.length = max(self.length, float(times[-1]))

    @staticmethod
    def _sample(times, vals, step, t, quat):
        if t <= times[0]:
            return vals[0]
        if t >= times[-1]:
            return vals[-1]
        k = int(np.searchsorted(times, t, side="right")) - 1
        if step:
            return vals[k]
        f = (t - times[k]) / (times[k + 1] - times[k])
        if quat:
            return slerp(vals[k] / np.linalg.norm(vals[k]), vals[k + 1] / np.linalg.norm(vals[k + 1]), f)
        return vals[k] * (1 - f) + vals[k + 1] * f

    def pose(self, skeleton, t):
        """Local rotations (N,3,3) and translations (N,3) of every node at time t."""
        r = skeleton.rest_r.copy()
        p = skeleton.rest_t.copy()
        for node, (times, vals, step) in self.rot.items():
            r[node] = quat_to_mat(self._sample(times, vals, step, t, True))
        for node, (times, vals, step) in self.pos.items():
            p[node] = self._sample(times, vals, step, t, False)
        return r, p


def load_clips(doc, blob, skeleton):
    return {a["name"]: Clip(doc, blob, a, skeleton) for a in doc.get("animations", [])}


# ------------------------------------------------------------------ writing
def _pad4(b, fill=b"\x00"):
    return b + fill * (-len(b) % 4)


def rebuild_and_save(path, doc, blob, new_animations, keep_animation_names, generator_note=None):
    """Writes `doc` + `blob` to `path` with: the animations named in `keep_animation_names` kept (in that order), then
    `new_animations` appended (list of dicts name -> {"times": (n,), "channels": [(node, "rotation"|"translation",
    values (n,4)|(n,3))]}). Buffer data nothing refers to any more is dropped.
    """
    doc = json.loads(json.dumps(doc))                        # work on a copy
    old_acc, old_views = doc["accessors"], doc["bufferViews"]
    anims = [a for name in keep_animation_names for a in doc.get("animations", []) if a["name"] == name]

    # 1. which accessors are still used
    used = set()
    for mesh in doc.get("meshes", []):
        for prim in mesh["primitives"]:
            used.update(prim["attributes"].values())
            if "indices" in prim:
                used.add(prim["indices"])
            for tgt in prim.get("targets", []):
                used.update(tgt.values())
    for skin in doc.get("skins", []):
        if "inverseBindMatrices" in skin:
            used.add(skin["inverseBindMatrices"])
    for a in anims:
        for s in a["samplers"]:
            used.update((s["input"], s["output"]))

    # 2. repack: used accessors' bufferViews (one new view per accessor, tightly packed) and images
    out = bytearray()
    new_views, new_acc, acc_map = [], [], {}

    def add_view(data, target=None):
        off = len(out)
        out.extend(data)
        out.extend(b"\x00" * (-len(out) % 4))
        v = {"buffer": 0, "byteOffset": off, "byteLength": len(data)}
        if target:
            v["target"] = target
        new_views.append(v)
        return len(new_views) - 1

    for idx in sorted(used):
        acc = dict(old_acc[idx])
        data = _accessor_bytes(doc, blob, idx)
        view = old_views[acc["bufferView"]]
        acc["bufferView"] = add_view(data, view.get("target"))
        acc.pop("byteOffset", None)
        new_acc.append(acc)
        acc_map[idx] = len(new_acc) - 1
    for img in doc.get("images", []):
        if "bufferView" in img:
            v = old_views[img["bufferView"]]
            start = v.get("byteOffset", 0)
            img["bufferView"] = add_view(blob[start:start + v["byteLength"]])

    def remap_prim(prim):
        prim["attributes"] = {k: acc_map[v] for k, v in prim["attributes"].items()}
        if "indices" in prim:
            prim["indices"] = acc_map[prim["indices"]]
        for tgt in prim.get("targets", []):
            for k in list(tgt):
                tgt[k] = acc_map[tgt[k]]

    for mesh in doc.get("meshes", []):
        for prim in mesh["primitives"]:
            remap_prim(prim)
    for skin in doc.get("skins", []):
        if "inverseBindMatrices" in skin:
            skin["inverseBindMatrices"] = acc_map[skin["inverseBindMatrices"]]
    for a in anims:
        for s in a["samplers"]:
            s["input"], s["output"] = acc_map[s["input"]], acc_map[s["output"]]

    # 3. new animations
    def add_acc(arr, kind):
        arr = np.ascontiguousarray(arr, dtype="<f4")
        v = add_view(arr.tobytes())
        a = {"bufferView": v, "componentType": 5126, "count": int(arr.shape[0]), "type": kind}
        flat = arr.reshape(arr.shape[0], -1)
        a["min"] = [float(x) for x in flat.min(axis=0)]
        a["max"] = [float(x) for x in flat.max(axis=0)]
        new_acc.append(a)
        return len(new_acc) - 1

    for clip in new_animations:
        t_acc = add_acc(clip["times"], "SCALAR")
        samplers, channels = [], []
        for node, kind, vals in clip["channels"]:
            o_acc = add_acc(vals, "VEC4" if kind == "rotation" else "VEC3")
            samplers.append({"input": t_acc, "interpolation": "LINEAR", "output": o_acc})
            channels.append({"sampler": len(samplers) - 1, "target": {"node": node, "path": kind}})
        anims.append({"name": clip["name"], "samplers": samplers, "channels": channels})

    doc["accessors"], doc["bufferViews"] = new_acc, new_views
    doc["animations"] = anims
    doc["buffers"] = [{"byteLength": len(out)}]
    if generator_note:
        doc.setdefault("asset", {})["extras"] = {"animation_note": generator_note}
    _write(path, doc, bytes(out))


def _accessor_bytes(doc, blob, idx):
    acc = doc["accessors"][idx]
    n = TYPE_N[acc["type"]]
    size = np.dtype(COMPONENT[acc["componentType"]]).itemsize
    view = doc["bufferViews"][acc["bufferView"]]
    start = view.get("byteOffset", 0) + acc.get("byteOffset", 0)
    stride = view.get("byteStride", 0) or n * size
    if stride == n * size:
        return blob[start:start + acc["count"] * n * size]
    parts = [blob[start + i * stride:start + i * stride + n * size] for i in range(acc["count"])]
    return b"".join(parts)


def _write(path, doc, blob):
    js = _pad4(json.dumps(doc, separators=(",", ":")).encode("utf-8"), b" ")
    bn = _pad4(blob)
    total = 12 + 8 + len(js) + 8 + len(bn)
    with open(path, "wb") as f:
        f.write(struct.pack("<4sII", b"glTF", 2, total))
        f.write(struct.pack("<II", len(js), 0x4E4F534A))
        f.write(js)
        f.write(struct.pack("<II", len(bn), 0x004E4942))
        f.write(bn)
