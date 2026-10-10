"""Shared helpers for the Red style prototype builders (red_proto_a.py, red_proto_b.py, red_proto_c.py).

Not run on its own. Each prototype script imports this, lays out its parts, paints its textures
and exports a .glb into game/art/placeholder/characters/red_prototypes/.

How the models are made (so a prototype is a short list of parts, not a pile of Blender calls):
  * every part is the CONVEX HULL of a small point cloud (box, chamfered box, frustum, ellipsoid,
    extruded slab), so nothing needs bevel modifiers and the triangle count is exact and predictable;
  * every part belongs to exactly one bone (rigid skinning, same 17-bone rig as the blockout);
  * UVs come from a tiny "atlas" painter: each part gets a tile of up to five cells (front, back,
    side, top, bottom) cut from one 64 or 128 px texture, and each face picks the cell matching the
    direction it faces. The head front uses a separate 128x64 face sheet (cells of 32x32);
  * painting is plain PIL pixel work, deterministic, so the PNGs are reproducible from the script.

Run (Blender as a Python module, Python 3.11, no GUI):
    python3 -m venv /tmp/proto_venv && /tmp/proto_venv/bin/pip install bpy==5.0.1 pillow numpy
    /tmp/proto_venv/bin/python game/scripts/tools/prototypes/red_proto_a.py

Conventions (docs/style_guide.md, docs/tech_plan.md): 1 unit = 1 m, origin at the feet, model faces
Blender -Y (Godot +Z), Red's right side is -X (up-ear and sword side), base-color-only materials
named mat_<model>, one armature of 17 bones.
"""

import math
import os

import bpy  # must come before bmesh / mathutils
import bmesh
from mathutils import Euler, Matrix, Vector
from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
GAME_DIR = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
OUT_DIR = os.path.join(GAME_DIR, "art", "placeholder", "characters", "red_prototypes")

# ---------------------------------------------------------------- palette (docs/style_guide.md)
PALETTE = {
    "ink": "#14121F",
    "night": "#1F2540",
    "dusk": "#3A3566",
    "chalk": "#EDEAD8",
    "glow": "#FFE08A",
    "amber": "#FFB347",
    "brass": "#D9A441",
    "brass_shade": "#A97B2C",
    "tawny": "#C98A45",
    "tawny_shade": "#A96B2F",
    "tawny_deep": "#8A5326",
    "tawny_light": "#DFA463",
    "cream": "#F4E4C1",
    "cream_shade": "#D9C298",
    "jacket": "#C8322A",
    "jacket_shade": "#8E2420",
    "jacket_light": "#DE5545",
    "rust": "#9C4A2E",
    "rust_shade": "#74361F",
    "tan": "#CBA878",
    "tan_shade": "#A68558",
    "terracotta": "#C8643B",
    "mustard": "#E0A93B",
    "green": "#6E9A5A",
    "blush": "#D9764F",
    "tongue": "#D9605A",
}


def rgb(color):
    """'#RRGGBB', a palette name or an (r, g, b) tuple -> (r, g, b)."""
    if isinstance(color, tuple):
        return color
    value = PALETTE.get(color, color)
    return tuple(int(value[i:i + 2], 16) for i in (1, 3, 5))


def mix(a, b, t):
    ca, cb = rgb(a), rgb(b)
    return tuple(int(round(ca[i] + (cb[i] - ca[i]) * t)) for i in range(3))


def warm_line(t=0.5):
    """Ink thinned toward rust: the drawn-in line color for the picture-book style (never black)."""
    return mix("ink", "rust", t)


# ---------------------------------------------------------------- small 2D pixel helpers
def fill(draw, rect, color):
    x, y, w, h = rect
    if w <= 0 or h <= 0:
        return
    draw.rectangle([x, y, x + w - 1, y + h - 1], fill=rgb(color))


def dither_fill(draw, rect, a, b, phase=0):
    """Checkerboard of two colors over a rect (hand-dithered shading, never a smooth blend)."""
    x, y, w, h = rect
    ca, cb = rgb(a), rgb(b)
    for j in range(h):
        for i in range(w):
            draw.point((x + i, y + j), fill=ca if (i + j + phase) % 2 == 0 else cb)


def border(draw, rect, color, sides="tblr"):
    x, y, w, h = rect
    c = rgb(color)
    if "t" in sides:
        draw.line([(x, y), (x + w - 1, y)], fill=c)
    if "b" in sides:
        draw.line([(x, y + h - 1), (x + w - 1, y + h - 1)], fill=c)
    if "l" in sides:
        draw.line([(x, y), (x, y + h - 1)], fill=c)
    if "r" in sides:
        draw.line([(x + w - 1, y), (x + w - 1, y + h - 1)], fill=c)


def sub(rect, dx, dy, w, h):
    """A rect relative to another rect's top-left."""
    return (rect[0] + dx, rect[1] + dy, w, h)


# ---------------------------------------------------------------- transforms
def T(x=0.0, y=0.0, z=0.0, rx=0.0, ry=0.0, rz=0.0):
    """Translate (x, y, z) after rotating by Euler XYZ degrees."""
    rot = Euler((math.radians(rx), math.radians(ry), math.radians(rz)), "XYZ").to_matrix().to_4x4()
    return Matrix.Translation(Vector((x, y, z))) @ rot


def R(rx=0.0, ry=0.0, rz=0.0):
    """Pure rotation (Euler XYZ degrees) as a 4x4, for chaining: T(...) @ R(ry=-14) @ R(rz=90)."""
    return Euler((math.radians(rx), math.radians(ry), math.radians(rz)), "XYZ").to_matrix().to_4x4()


def aim(a, b, front=(0.0, -1.0, 0.0)):
    """Matrix whose local +Z runs from a to b (origin at their midpoint) and whose local -Y points
    as near to `front` as it can. Used for limbs: the part is built along +Z, then placed."""
    a, b = Vector(a), Vector(b)
    z = (b - a).normalized()
    y = -Vector(front)
    y = (y - z * y.dot(z))
    if y.length < 1e-6:
        y = Vector((0, 1, 0)) if abs(z.y) < 0.9 else Vector((1, 0, 0))
    y.normalize()
    x = y.cross(z).normalized()
    basis = Matrix(((x.x, y.x, z.x), (x.y, y.y, z.y), (x.z, y.z, z.z))).to_4x4()
    return Matrix.Translation((a + b) * 0.5) @ basis


# ---------------------------------------------------------------- point clouds for hulls (local space)
def pts_box(w, d, h):
    return [Vector((sx * w / 2, sy * d / 2, sz * h / 2)) for sx in (-1, 1) for sy in (-1, 1) for sz in (-1, 1)]


def pts_chamfer(w, d, h, c):
    """Box with every edge cut back by c: the 'cube with heavily cut corners'. 24 points."""
    hx, hy, hz = w / 2, d / 2, h / 2
    out = []
    for sx in (-1, 1):
        for sy in (-1, 1):
            for sz in (-1, 1):
                out.append(Vector((sx * hx, sy * (hy - c), sz * (hz - c))))
                out.append(Vector((sx * (hx - c), sy * hy, sz * (hz - c))))
                out.append(Vector((sx * (hx - c), sy * (hy - c), sz * hz)))
    return out


def ring(rx, ry, z, n, phase=0.0, cx=0.0, cy=0.0):
    return [Vector((cx + rx * math.cos(phase + 2 * math.pi * i / n),
                    cy + ry * math.sin(phase + 2 * math.pi * i / n), z)) for i in range(n)]


def pts_frustum(bottom, top, h, n=6, phase=0.0, shift=(0.0, 0.0)):
    """Frustum along Z, centered. bottom/top are radius or (rx, ry); shift moves the top ring."""
    def rr(v):
        return (v, v) if not isinstance(v, tuple) else v
    rb, rt = rr(bottom), rr(top)
    return ring(rb[0], rb[1], -h / 2, n, phase) + ring(rt[0], rt[1], h / 2, n, phase, shift[0], shift[1])


def pts_ellipsoid(rx, ry, rz, segments=8, rings=5, phase=0.0):
    out = [Vector((0, 0, rz)), Vector((0, 0, -rz))]
    for j in range(1, rings):
        phi = math.pi * j / rings
        out += ring(rx * math.sin(phi), ry * math.sin(phi), rz * math.cos(phi), segments, phase)
    return out


def pts_slab(outline_xz, thickness):
    """A flat shape in the XZ plane (list of (x, z)) extruded along Y, centered."""
    out = []
    for y in (-thickness / 2, thickness / 2):
        for x, z in outline_xz:
            out.append(Vector((x, y, z)))
    return out


def pts_taper_slab(w0, w1, length, thickness, tip=0.0):
    """Flat tapered strip along local Z (centered): width w0 at the bottom, w1 at the top, optional
    pointed tip (extra length). Thickness is along local Y. Place it with aim(a, b)."""
    h = length / 2
    outline = [(-w0 / 2, -h), (w0 / 2, -h), (w1 / 2, h), (-w1 / 2, h)]
    if tip > 0:
        outline = [(-w0 / 2, -h), (w0 / 2, -h), (w1 / 2, h), (0.0, h + tip), (-w1 / 2, h)]
    return pts_slab(outline, thickness)


def hull(points):
    """Convex hull of a point cloud -> (verts, tris) with outward-facing triangles."""
    bm = bmesh.new()
    seen = []
    verts = []
    for p in points:
        key = (round(p.x, 5), round(p.y, 5), round(p.z, 5))
        if key in seen:
            continue
        seen.append(key)
        verts.append(bm.verts.new(p))
    res = bmesh.ops.convex_hull(bm, input=verts)
    faces = [g for g in res["geom"] if isinstance(g, bmesh.types.BMFace)]
    centre = sum((v.co for v in verts), Vector()) / len(verts)
    index = {}
    out_verts = []
    tris = []
    for f in faces:
        ids = []
        for v in f.verts:
            if v not in index:
                index[v] = len(out_verts)
                out_verts.append(v.co.copy())
            ids.append(index[v])
        for k in range(1, len(ids) - 1):
            tri = [ids[0], ids[k], ids[k + 1]]
            a, b, c = (out_verts[i] for i in tri)
            n = (b - a).cross(c - a)
            if n.length < 1e-9:
                continue
            if n.dot((a + b + c) / 3 - centre) < 0:
                tri = [tri[0], tri[2], tri[1]]
            tris.append(tri)
    bm.free()
    return out_verts, tris


# ---------------------------------------------------------------- texture atlas
class Atlas:
    """One texture sheet. Tiles are cut out of it by a simple row packer; painters run at the end."""

    def __init__(self, width, height, background="ink"):
        self.w, self.h = width, height
        self.img = Image.new("RGB", (width, height), rgb(background))
        self.tiles = {}
        self._x = self._y = self._row = 0

    def tile(self, key, cells, painter=None):
        """cells: {cell name: (w, h)}. Same key twice returns the same tile (left/right limbs share).
        Rectangles are assigned later by pack(), so the order of tile() calls does not matter."""
        if key not in self.tiles:
            self.tiles[key] = Tile(key, {}, painter, dict(cells))
        return self.tiles[key]

    def pack(self):
        """MaxRects-style packing (largest cell first, best short-side fit), 1 px gutter."""
        items = [(t, name, size) for t in self.tiles.values() for name, size in t.sizes.items()]
        items.sort(key=lambda it: (-(it[2][0] * it[2][1]), -it[2][1]))
        free = [(0, 0, self.w + 1, self.h + 1)]      # +1 so the gutter of the last cell fits
        for tile, name, (w, h) in items:
            pw, ph = w + 1, h + 1
            best = None
            for fr in free:
                if fr[2] >= pw and fr[3] >= ph:
                    score = (min(fr[2] - pw, fr[3] - ph), max(fr[2] - pw, fr[3] - ph))
                    if best is None or score < best[0]:
                        best = (score, fr)
            if best is None:
                raise RuntimeError("atlas %dx%d is full (cell %s/%s %dx%d, %.0f%% of area requested)" % (
                    self.w, self.h, tile.key, name, w, h, self.used_fraction() * 100))
            fx, fy = best[1][0], best[1][1]
            tile.rects[name] = (fx, fy, w, h)
            placed = (fx, fy, pw, ph)
            new_free = []
            for fr in free:
                if (placed[0] >= fr[0] + fr[2] or placed[0] + placed[2] <= fr[0] or
                        placed[1] >= fr[1] + fr[3] or placed[1] + placed[3] <= fr[1]):
                    new_free.append(fr)
                    continue
                if placed[0] > fr[0]:
                    new_free.append((fr[0], fr[1], placed[0] - fr[0], fr[3]))
                if placed[0] + placed[2] < fr[0] + fr[2]:
                    new_free.append((placed[0] + placed[2], fr[1], fr[0] + fr[2] - placed[0] - placed[2], fr[3]))
                if placed[1] > fr[1]:
                    new_free.append((fr[0], fr[1], fr[2], placed[1] - fr[1]))
                if placed[1] + placed[3] < fr[1] + fr[3]:
                    new_free.append((fr[0], placed[1] + placed[3], fr[2], fr[1] + fr[3] - placed[1] - placed[3]))
            # drop free rects contained in another
            free = [f for i, f in enumerate(new_free) if not any(
                j != i and g[0] <= f[0] and g[1] <= f[1] and g[0] + g[2] >= f[0] + f[2] and g[1] + g[3] >= f[1] + f[3]
                for j, g in enumerate(new_free))]

    def paint(self):
        draw = ImageDraw.Draw(self.img)
        for tile in self.tiles.values():
            if tile.painter:
                for name, rect in tile.rects.items():
                    tile.painter(self.img, draw, name, rect)

    def used_fraction(self):
        used = sum(w * h for t in self.tiles.values() for (w, h) in t.sizes.values())
        return used / float(self.w * self.h)

    def uv(self, rect, a, b):
        """(a, b) in 0..1 across a rect (b down). Pulled in half a texel so nearest sampling stays inside."""
        x, y, w, h = rect
        px = x + 0.5 + a * (w - 1)
        py = y + 0.5 + b * (h - 1)
        return (px / self.w, 1.0 - py / self.h)


class Tile:
    FALLBACK = {
        "front": ("front", "back", "side", "top", "bottom"),
        "back": ("back", "front", "side", "top", "bottom"),
        "side": ("side", "front", "back", "top", "bottom"),
        "top": ("top", "bottom", "side", "front", "back"),
        "bottom": ("bottom", "top", "side", "front", "back"),
    }

    def __init__(self, key, rects, painter, sizes=None):
        self.key, self.rects, self.painter, self.sizes = key, rects, painter, sizes or {}

    def pick(self, want):
        for name in self.FALLBACK[want]:
            if name in self.rects:
                return name, self.rects[name]
        raise KeyError(want)


# ---------------------------------------------------------------- mesh builder
class Part:
    def __init__(self, name, bone, verts, tris, xf, tile, smooth, face, ybias):
        self.name, self.bone, self.verts, self.tris = name, bone, verts, tris
        self.xf, self.tile, self.smooth, self.face = xf, tile, smooth, face
        self.ybias = ybias


class Builder:
    """Collects parts, then turns them into one skinned Blender mesh with two material slots
    (0 = body sheet, 1 = face sheet)."""

    def __init__(self, atlas, face_atlas=None):
        self.atlas, self.face_atlas = atlas, face_atlas
        self.parts = []

    def add(self, name, bone, points, xf=None, tile=None, smooth=False, face=None, ybias=1.0):
        """points: local-space point cloud (hulled). ybias > 1 sends diagonal side facets to the front/back
        cell (round jackets). xf: local -> model. face: dict(region=(x0, x1, z0, z1),
        cell=rect, sel=function(normal, center)->bool) sends matching faces to the face sheet."""
        verts, tris = hull(points)
        part = Part(name, bone, verts, tris, xf or Matrix.Identity(4), tile, smooth, face, ybias)
        self.parts.append(part)
        return part

    def limb(self, name, bone, a, b, r0, r1, n=6, front=(0, -1, 0), **kw):
        a, b = Vector(a), Vector(b)
        length = (b - a).length
        return self.add(name, bone, pts_frustum(r0, r1, length, n), aim(a, b, front), **kw)

    # -- UVs
    def _cell_uv(self, part, local_n, local_p, lo, hi):
        ax = max(range(3), key=lambda i: abs(local_n[i]))
        if ax == 0 and abs(local_n.y) * part.ybias >= abs(local_n.x) and abs(local_n.z) < abs(local_n.y):
            ax = 1                      # wrap-around parts: diagonal facets count as front/back
        size = [max(hi[i] - lo[i], 1e-6) for i in range(3)]
        t = [(local_p[i] - lo[i]) / size[i] for i in range(3)]
        if ax == 2:
            name = "top" if local_n.z > 0 else "bottom"
            a, b = t[0], t[1]
        elif ax == 1:
            if local_n.y < 0:
                name, a, b = "front", t[0], 1 - t[2]
            else:
                name, a, b = "back", 1 - t[0], 1 - t[2]
        else:
            name = "side"
            a = t[1] if local_n.x > 0 else 1 - t[1]
            b = 1 - t[2]
        cell_name, rect = part.tile.pick(name)
        return self.atlas.uv(rect, a, b)

    def _face_uv(self, part, model_p):
        x0, x1, z0, z1 = part.face["region"]
        a = min(max((model_p.x - x0) / (x1 - x0), 0.0), 1.0)
        b = min(max((z1 - model_p.z) / (z1 - z0), 0.0), 1.0)
        # Model +X is the character's left, which appears on the viewer's RIGHT when she faces us.
        return self.face_atlas.uv(part.face["cell"], a, b)

    # -- build
    def to_object(self, name, bone_names, materials):
        bm = bmesh.new()
        uv_layer = bm.loops.layers.uv.new("UVMap")
        deform = bm.verts.layers.deform.new()
        group_index = {b: i for i, b in enumerate(bone_names)}
        for part in self.parts:
            local = part.verts
            lo = [min(v[i] for v in local) for i in range(3)]
            hi = [max(v[i] for v in local) for i in range(3)]
            model = [part.xf @ v for v in local]
            bverts = []
            for v in model:
                bv = bm.verts.new(v)
                bv[deform][group_index[part.bone]] = 1.0
                bverts.append(bv)
            for tri in part.tris:
                la, lb, lc = (local[i] for i in tri)
                ln = (lb - la).cross(lc - la).normalized()
                lc_centre = (la + lb + lc) / 3
                ma, mb, mc = (model[i] for i in tri)
                mn = (mb - ma).cross(mc - ma).normalized()
                m_centre = (ma + mb + mc) / 3
                try:
                    face = bm.faces.new([bverts[i] for i in tri])
                except ValueError:
                    continue
                face.smooth = part.smooth
                use_face = part.face is not None and part.face["sel"](mn, m_centre)
                face.material_index = 1 if use_face else 0
                for k, loop in enumerate(face.loops):
                    li = tri[k]
                    if use_face:
                        loop[uv_layer].uv = self._face_uv(part, model[li])
                    else:
                        loop[uv_layer].uv = self._cell_uv(part, ln, local[li], lo, hi)
        bm.normal_update()
        mesh = bpy.data.meshes.new(name)
        bm.to_mesh(mesh)
        tri_count = len(bm.faces)
        bm.free()
        obj = bpy.data.objects.new(name, mesh)
        bpy.context.collection.objects.link(obj)
        for b in bone_names:
            obj.vertex_groups.new(name=b)
        for m in materials:
            mesh.materials.append(m)
        return obj, tri_count


# ---------------------------------------------------------------- skeleton + materials + export
BONE_NAMES = ["root", "hips", "spine", "head", "ear_r", "ear_l", "tail", "upper_arm_r", "forearm_r",
              "upper_arm_l", "forearm_l", "thigh_r", "shin_r", "thigh_l", "shin_l", "weapon_socket",
              "prop_socket"]


def build_armature(name, bones):
    """bones: {bone name: (head, tail, parent)} covering exactly BONE_NAMES."""
    assert sorted(bones) == sorted(BONE_NAMES), "the rig must be the shared 17 bones"
    data = bpy.data.armatures.new(name + "_rig")
    obj = bpy.data.objects.new(name, data)
    bpy.context.collection.objects.link(obj)
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    bpy.ops.object.mode_set(mode="EDIT")
    edit = {}
    for bone_name in BONE_NAMES:
        head, tail, _ = bones[bone_name]
        eb = data.edit_bones.new(bone_name)
        eb.head, eb.tail, eb.roll = Vector(head), Vector(tail), 0.0
        edit[bone_name] = eb
    for bone_name in BONE_NAMES:
        parent = bones[bone_name][2]
        if parent:
            edit[bone_name].parent = edit[parent]
    bpy.ops.object.mode_set(mode="OBJECT")
    return obj


def make_material(name, png_path):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    nodes, links = mat.node_tree.nodes, mat.node_tree.links
    nodes.clear()
    out = nodes.new("ShaderNodeOutputMaterial")
    bsdf = nodes.new("ShaderNodeBsdfPrincipled")
    tex = nodes.new("ShaderNodeTexImage")
    tex.image = bpy.data.images.load(png_path)
    tex.image.name = os.path.basename(png_path)
    tex.interpolation = "Closest"
    links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    links.new(bsdf.outputs["BSDF"], out.inputs["Surface"])
    bsdf.inputs["Roughness"].default_value = 1.0
    return mat


def skin(mesh_obj, arm_obj):
    mesh_obj.parent = arm_obj
    mod = mesh_obj.modifiers.new("Armature", "ARMATURE")
    mod.object = arm_obj


def export_glb(path):
    bpy.ops.export_scene.gltf(
        filepath=path, export_format="GLB", export_yup=True, export_apply=False, export_skins=True,
        export_animations=False, export_image_format="AUTO", export_materials="EXPORT",
        export_cameras=False, export_lights=False, export_extras=False)


def build_prototype(letter, name_text, bones, build_parts, paint_face, body_size, smooth_note=""):
    """Common driver. build_parts(body_builder, sword_builder, body_atlas, face_atlas) lays out the
    parts; paint_face(face_img, draw) paints the two face cells."""
    key = "red_proto_" + letter
    os.makedirs(OUT_DIR, exist_ok=True)
    bpy.ops.wm.read_factory_settings(use_empty=True)
    body_atlas = Atlas(*body_size)
    face_atlas = Atlas(128, 64, "tawny")
    body = Builder(body_atlas, face_atlas)
    sword = Builder(body_atlas)
    build_parts(body, sword, body_atlas, face_atlas)
    body_atlas.pack()
    body_atlas.paint()
    paint_face(face_atlas.img, ImageDraw.Draw(face_atlas.img))
    body_png = os.path.join(OUT_DIR, key + "_body.png")
    face_png = os.path.join(OUT_DIR, key + "_face.png")
    body_atlas.img.save(body_png)
    face_atlas.img.save(face_png)
    mat_body = make_material("mat_" + key, body_png)
    mat_face = make_material("mat_" + key + "_face", face_png)
    arm = build_armature(key, bones)
    body_obj, body_tris = body.to_object(key + "_body", BONE_NAMES, [mat_body, mat_face])
    sword_obj, sword_tris = sword.to_object(key + "_sword", BONE_NAMES, [mat_body])
    skin(body_obj, arm)
    skin(sword_obj, arm)
    glb = os.path.join(OUT_DIR, key + ".glb")
    export_glb(glb)
    print("%s (%s): body %d tris, sword %d tris, body sheet %dx%d (%.0f%% used)" % (
        key, name_text, body_tris, sword_tris, body_size[0], body_size[1], body_atlas.used_fraction() * 100))
    print("wrote", glb)
