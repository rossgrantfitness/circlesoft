"""Shared Blender helpers for the Red style prototypes D (Ink Line) and E (Rubber Bounce).

Not run on its own; red_proto_d.py and red_proto_e.py import it. Placeholder art only
(docs/red_style_prototypes.md): primitives (ellipsoids, tubes, boxes, quads) built with bmesh,
every vertex weighted to exactly ONE bone (rigid skinning), the shared 17-bone skeleton, 1 unit =
1 m, feet at the origin, model faces Blender -Y (Godot +Z), exported as .glb.

Run (Blender as a Python module; Python 3.11):
    python3 -m venv /tmp/blockout_venv
    /tmp/blockout_venv/bin/pip install bpy==5.0.1 pillow numpy
    /tmp/blockout_venv/bin/python game/scripts/tools/prototypes/red_proto_d.py
"""

import math
import os
import sys

import bpy  # must come before bmesh / mathutils
import bmesh
from mathutils import Euler, Matrix, Quaternion, Vector
from mathutils.bvhtree import BVHTree

HERE = os.path.dirname(os.path.abspath(__file__))
GAME_DIR = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
OUT_DIR = os.path.join(GAME_DIR, "art", "placeholder", "characters", "red_prototypes")

# Style guide palette plus a few siblings. Names matter more than exact hex.
PAL = {
    "ink": "#14121F", "night": "#1F2540", "dusk": "#3A3566", "chalk": "#EDEAD8",
    "lamp_amber": "#FFB347", "glow": "#FFE08A", "brass": "#D9A441",
    "tawny": "#C98A45", "cream": "#F4E4C1", "jacket": "#C8322A",
    "rust": "#9C4A2E", "tan": "#CBA878",
    "terracotta": "#C8643B", "mustard": "#E0A93B", "patch_green": "#6E9A5A",
}


def hex_rgb(value):
    return tuple(int(value[i:i + 2], 16) for i in (1, 3, 5))


def lerp_rgb(a, b, k):
    return tuple(int(round(a[i] + (b[i] - a[i]) * k)) for i in range(3))


# ---------------------------------------------------------------- the shared skeleton
BONE_NAMES = ["root", "hips", "spine", "head", "ear_l", "ear_r", "tail", "upper_arm_l",
              "upper_arm_r", "forearm_l", "forearm_r", "thigh_l", "thigh_r", "shin_l", "shin_r",
              "weapon_socket", "prop_socket"]
BONE_PARENTS = {
    "root": None, "hips": "root", "spine": "hips", "head": "spine", "ear_l": "head",
    "ear_r": "head", "tail": "hips", "upper_arm_l": "spine", "upper_arm_r": "spine",
    "forearm_l": "upper_arm_l", "forearm_r": "upper_arm_r", "thigh_l": "hips", "thigh_r": "hips",
    "shin_l": "thigh_l", "shin_r": "thigh_r", "weapon_socket": "forearm_r", "prop_socket": "forearm_l",
}


def build_armature(name, joints):
    """joints: bone name -> (head xyz, tail xyz). All 17 names must be present."""
    assert sorted(joints) == sorted(BONE_NAMES), "need exactly the 17 shared bones"
    data = bpy.data.armatures.new(name + "_rig")
    obj = bpy.data.objects.new(name, data)
    bpy.context.collection.objects.link(obj)
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    bpy.ops.object.mode_set(mode="EDIT")
    edit = {}
    for bone_name in BONE_NAMES:
        head, tail = joints[bone_name]
        bone = data.edit_bones.new(bone_name)
        bone.head = Vector(head)
        bone.tail = Vector(tail)
        bone.roll = 0.0
        edit[bone_name] = bone
    for bone_name, parent in BONE_PARENTS.items():
        if parent:
            edit[bone_name].parent = edit[parent]
    bpy.ops.object.mode_set(mode="OBJECT")
    return obj


# ---------------------------------------------------------------- mesh builder
def call_uv(fn, co, normal, bbox):
    """UV rules take (co, normal) or (co, normal, bbox); bbox is (min, max) of the primitive."""
    if fn.__code__.co_argcount >= 3:
        return fn(co, normal, bbox)
    return fn(co, normal)


def rot_matrix(rot_deg):
    return Euler([math.radians(a) for a in rot_deg], "XYZ").to_matrix().to_4x4()


class PartMesh:
    """One Blender mesh object made of primitives. Every primitive belongs to one bone, one
    material slot and one UV rule. With outline=True the primitive is also copied (smooth-shaded,
    welded) into the `hull_slot` material: the inverted-hull ink outline."""

    def __init__(self, name, materials, hull_slot=None):
        self.name = name
        self.materials = materials          # list of material names, slot order
        self.hull_slot = hull_slot          # slot index of the outline material, or None
        self.bm = bmesh.new()
        self.uv = self.bm.loops.layers.uv.new("UVMap")
        self.deform = self.bm.verts.layers.deform.new()
        self.groups = {}
        self.group_xf = Matrix.Identity(4)  # applied to everything built while set

    def set_group_transform(self, matrix):
        self.group_xf = matrix

    def _gi(self, bone):
        if bone not in self.groups:
            self.groups[bone] = len(self.groups)
        return self.groups[bone]

    # -- raw geometry makers; each returns (verts, faces) with local coordinates --
    def _make(self, kind, p):
        bm = self.bm
        if kind == "ell":
            res = bmesh.ops.create_uvsphere(bm, u_segments=p["seg"], v_segments=p["rings"], radius=1.0)
            verts = res["verts"]
            for v in verts:
                v.co = Vector((v.co.x * p["radii"][0], v.co.y * p["radii"][1], v.co.z * p["radii"][2]))
                if p.get("deform"):
                    v.co = p["deform"](v.co)     # e.g. the bean-shaped shiba head (red_proto_f.py)
        elif kind == "tube":
            res = bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=False, segments=p["seg"],
                                        radius1=1.0, radius2=1.0, depth=1.0)
            verts = res["verts"]
            for v in verts:
                bottom = v.co.z < 0
                r = p["r0"] if bottom else p["r1"]
                v.co = Vector((v.co.x * r * p["sxy"][0], v.co.y * r * p["sxy"][1], v.co.z * p["length"]))
        elif kind == "box":
            res = bmesh.ops.create_cube(bm, size=1.0)
            verts = res["verts"]
            taper = p.get("taper", 1.0)
            for v in verts:
                t = taper if v.co.z > 0 else 1.0
                v.co = Vector((v.co.x * p["size"][0] * t, v.co.y * p["size"][1] * t, v.co.z * p["size"][2]))
        elif kind == "quad":
            hw, hh = p["size"][0] / 2.0, p["size"][1] / 2.0
            verts = [bm.verts.new(c) for c in ((-hw, 0, -hh), (hw, 0, -hh), (hw, 0, hh), (-hw, 0, hh))]
            # Faces toward -Y (the model front), counter-clockwise seen from -Y.
            face = bm.faces.new(verts)
            if p.get("rect"):
                u0, v0, u1, v1 = p["rect"]
                for loop, (sx, sz) in zip(face.loops, ((0, 0), (1, 0), (1, 1), (0, 1))):
                    loop[self.uv].uv = (u0 + (u1 - u0) * sx, v0 + (v1 - v0) * sz)
        else:
            raise ValueError(kind)
        verts = list(verts)
        faces = list({f for v in verts for f in v.link_faces})
        return verts, faces

    def _drop_caps(self, faces, drop):
        """drop: subset of {'top', 'bottom'} for tube primitives (local +Z / -Z cap faces)."""
        doomed = []
        self.bm.normal_update()
        for f in faces:
            if "top" in drop and f.normal.z > 0.99:
                doomed.append(f)
            if "bottom" in drop and f.normal.z < -0.99:
                doomed.append(f)
        if doomed:
            bmesh.ops.delete(self.bm, geom=doomed, context="FACES")

    def add(self, bone, mat, kind, center=(0, 0, 0), rot=(0, 0, 0), uv=None, outline=False,
            drop_caps=(), spin=0.0, basis=None, **p):
        """Adds a primitive. `uv` is a function (world_co, world_normal) -> (u, v); `mat` is a slot
        index. `spin` rotates the local shape about its own Z before `rot` (for facet alignment)."""
        orient = basis if basis is not None else rot_matrix(rot)
        local = Matrix.Translation(Vector(center)) @ orient @ rot_matrix((0, 0, spin))
        total = self.group_xf @ local
        self._build(bone, mat, kind, total, uv, drop_caps, p, hull=False)
        if outline:
            assert self.hull_slot is not None
            self._build(bone, self.hull_slot, kind, total, None, drop_caps, p, hull=True)

    def tube(self, bone, mat, p0, p1, r0, r1, seg=6, sxy=(1.0, 1.0), uv=None, outline=False,
             drop_caps=(), spin=0.0):
        """Tapered tube from p0 (radius r0) to p1 (radius r1); caps unless dropped.
        drop_caps uses 'start' / 'end' here."""
        a, b = Vector(p0), Vector(p1)
        axis = b - a
        length = axis.length
        quat = Vector((0, 0, 1)).rotation_difference(axis.normalized())
        local = Matrix.Translation((a + b) / 2.0) @ quat.to_matrix().to_4x4() @ rot_matrix((0, 0, spin))
        total = self.group_xf @ local
        drops = tuple({"start": "bottom", "end": "top"}[d] for d in drop_caps)
        params = dict(seg=seg, r0=r0, r1=r1, length=length, sxy=sxy)
        self._build(bone, mat, "tube", total, uv, drops, params, hull=False)
        if outline:
            assert self.hull_slot is not None
            self._build(bone, self.hull_slot, "tube", total, None, drops, params, hull=True)

    def _build(self, bone, mat, kind, matrix, uv, drops, p, hull):
        verts, faces = self._make(kind, p)
        keep_uv = kind == "quad" and not hull and bool(p.get("rect"))
        if drops:
            self._drop_caps(faces, drops)
            verts = [v for v in verts if v.is_valid and v.link_faces]
            faces = list({f for v in verts for f in v.link_faces})
        for v in verts:
            v.co = matrix @ v.co
        bb = (Vector((min(v.co.x for v in verts), min(v.co.y for v in verts), min(v.co.z for v in verts))),
              Vector((max(v.co.x for v in verts), max(v.co.y for v in verts), max(v.co.z for v in verts))))
        index = self._gi(bone)
        for v in verts:
            v[self.deform][index] = 1.0
        if hull:
            res = bmesh.ops.remove_doubles(self.bm, verts=verts, dist=1e-5)
            verts = [v for v in verts if v.is_valid]
            faces = list({f for v in verts for f in v.link_faces})
        self.bm.normal_update()
        for f in faces:
            f.material_index = mat(f.normal.copy()) if callable(mat) else mat
            f.smooth = hull
            for loop in f.loops:
                if keep_uv:
                    pass
                elif hull or uv is None:
                    loop[self.uv].uv = (0.5, 0.5)
                else:
                    loop[self.uv].uv = call_uv(uv, loop.vert.co.copy(), f.normal.copy(), bb)

    def to_object(self):
        bmesh.ops.triangulate(self.bm, faces=self.bm.faces[:])
        mesh = bpy.data.meshes.new(self.name)
        self.bm.to_mesh(mesh)
        obj = bpy.data.objects.new(self.name, mesh)
        bpy.context.collection.objects.link(obj)
        for bone, _ in sorted(self.groups.items(), key=lambda kv: kv[1]):
            obj.vertex_groups.new(name=bone)
        self.bm.free()
        return obj


def triangle_count(obj, slots=None):
    total = 0
    for poly in obj.data.polygons:
        if slots is None or poly.material_index in slots:
            total += len(poly.vertices) - 2
    return total


def surface_hit(obj_mesh_bm_or_obj, x, z, from_y=-2.0):
    """Ray from the front (-Y) toward +Y at (x, z) against a mesh object; returns (location, normal)."""
    mesh = obj_mesh_bm_or_obj.data
    bm = bmesh.new()
    bm.from_mesh(mesh)
    bmesh.ops.triangulate(bm, faces=bm.faces[:])
    tree = BVHTree.FromBMesh(bm)
    loc, normal, _, _ = tree.ray_cast(Vector((x, from_y, z)), Vector((0, 1, 0)))
    bm.free()
    return loc, normal


# ---------------------------------------------------------------- materials and export
def make_material(name, image_path=None, color=None, alpha=False):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    nodes = mat.node_tree.nodes
    links = mat.node_tree.links
    nodes.clear()
    out = nodes.new("ShaderNodeOutputMaterial")
    bsdf = nodes.new("ShaderNodeBsdfPrincipled")
    bsdf.inputs["Roughness"].default_value = 1.0
    if image_path:
        tex = nodes.new("ShaderNodeTexImage")
        tex.image = bpy.data.images.load(image_path)
        tex.image.name = os.path.basename(image_path)
        tex.interpolation = "Closest"
        links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
        if alpha:
            links.new(tex.outputs["Alpha"], bsdf.inputs["Alpha"])
    if color:
        r, g, b = hex_rgb(color)
        bsdf.inputs["Base Color"].default_value = (r / 255.0, g / 255.0, b / 255.0, 1.0)
    links.new(bsdf.outputs["BSDF"], out.inputs["Surface"])
    return mat


def export_glb(path):
    bpy.ops.export_scene.gltf(
        filepath=path, export_format="GLB", export_yup=True, export_apply=False,
        export_skins=True, export_animations=False, export_image_format="AUTO",
        export_materials="EXPORT", export_cameras=False, export_lights=False, export_extras=False,
    )
    print("wrote", path)


def attach(mesh_obj, arm_obj, materials):
    for mat in materials:
        mesh_obj.data.materials.append(mat)
    mesh_obj.parent = arm_obj
    modifier = mesh_obj.modifiers.new("Armature", "ARMATURE")
    modifier.object = arm_obj
