"""Splits Ross's six-sword sheet (game/art/final/weapons/neon_arsenal_ross_v1.glb, never edited) into six
game-ready sword files in game/art/final/weapons/.

What it does, per sword:
  * picks the faces: first by loose part (welded corners), then each part goes to the sword whose column
    (x range) it sits in. The two small floating shards above the orange blade sit exactly on its centre
    line, so they belong to it and travel with it (they stay loose, floating, as Ross modeled them).
  * turns the sword over: Ross's sheet has every blade pointing DOWN. In the game file the blade points up
    (+Y in Godot, +Z in Blender) and the origin sits at the middle of the grip, so the file drops onto the
    right hand's `weapon_socket` bone with no offset.
  * keeps the PBR maps (base color, metallic-roughness, normal) but crops them to what this sword uses and
    shrinks them to at most 512 px, power-of-two sides.
Run: see ta_lib.py. Output: sword_katana_cyan.glb, sword_heavy_duty.glb, sword_hook_cyan.glb,
sword_glass_core.glb, sword_machete.glb, sword_twin_orange.glb (+ a printed report).
"""
import os
import sys
import tempfile

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from ta_lib import *  # noqa: E402,F401,F403

SRC = os.path.join(GAME_DIR, "art", "final", "weapons", "neon_arsenal_ross_v1.glb")
OUT = os.path.join(GAME_DIR, "art", "final", "weapons")
MAX_TEX = 512

# column boundaries on the sheet (Blender x), left to right; centres of the gaps between the six swords
COLUMNS = [-0.31, -0.12, 0.03, 0.19, 0.32]
# id, file, what it really is, grip centre (x, z) on the sheet, where the sword's grip run is (z top, z bottom)
SWORDS = [
    dict(id="katana_cyan", file="sword_katana_cyan.glb", what="Cyan circuit katana: wrapped grip, small round guard, long single-edged blade",
         grip=(-0.388, 0.270)),
    dict(id="heavy_duty", file="sword_heavy_duty.glb", what="'Heavy Duty' CS-01 cleaver: thin pole grip, a slab of a blade with a gear plate and a blunt squared tip",
         grip=(-0.214, 0.294)),
    dict(id="hook_cyan", file="sword_hook_cyan.glb", what="Cyan hook-blade: D-shaped hand guard on the grip, battery cells at the ricasso, thin blade",
         grip=(-0.062, 0.250)),
    dict(id="glass_core", file="sword_glass_core.glb", what="Glass-core broadsword: square pommel, braided grip, wide blade with a glass window",
         grip=(0.110, 0.285)),
    dict(id="machete", file="sword_machete.glb", what="Dark tactical machete: bulky molded grip, clipped-point blade with three orange notches",
         grip=(0.262, 0.268)),
    dict(id="twin_orange", file="sword_twin_orange.glb", what="Orange twin-prong blade: an emitter head with two parallel blades and four antennae; two floating shards",
         grip=(0.402, 0.205)),
]


def column_of(x):
    for i, edge in enumerate(COLUMNS):
        if x < edge:
            return i
    return len(COLUMNS)


def face_groups(mesh):
    """Face index lists, one per loose part (corners welded by position)."""
    parent = {}
    def find(a):
        while parent.setdefault(a, a) != a:
            parent[a] = parent[parent[a]]
            a = parent[a]
        return a
    key = lambda co: (round(co.x * 5000), round(co.y * 5000), round(co.z * 5000))
    for p in mesh.polygons:
        ks = [key(mesh.vertices[v].co) for v in p.vertices]
        for k in ks[1:]:
            parent[find(k)] = find(ks[0])
    groups = {}
    for p in mesh.polygons:
        groups.setdefault(find(key(mesh.vertices[p.vertices[0]].co)), []).append(p.index)
    return list(groups.values())


def main():
    reset_scene()
    src_obj = [o for o in import_glb(SRC) if o.type == "MESH"][0]
    src_mat = src_obj.data.materials[0]
    doc, images = glb_images(SRC)
    # which glTF image is which map, from the material
    mat_doc = doc["materials"][0]
    pbr = mat_doc["pbrMetallicRoughness"]
    tex_to_img = lambda t: doc["textures"][t["index"]]["source"]
    maps = {"BASE COLOR": images[tex_to_img(pbr["baseColorTexture"])],
            "METALLIC ROUGHNESS": images[tex_to_img(pbr["metallicRoughnessTexture"])],
            "NORMAL MAP": images[tex_to_img(mat_doc["normalTexture"])]}
    mesh = src_obj.data
    groups = face_groups(mesh)
    owner = {}
    for faces in groups:
        xs = [sum(mesh.vertices[v].co.x for v in mesh.polygons[f].vertices) / len(mesh.polygons[f].vertices) for f in faces]
        col = column_of(sum(xs) / len(xs))
        for f in faces:
            owner[f] = col
    assert len(SWORDS) == len(COLUMNS) + 1
    uv_layer = mesh.uv_layers.active.data
    tmp = tempfile.mkdtemp(prefix="swords_")
    report = []
    for col, spec in enumerate(SWORDS):
        faces = [f for f, c in owner.items() if c == col]
        bm = bmesh.new()
        bm.from_mesh(mesh)
        bm.faces.ensure_lookup_table()
        keep = set(faces)
        gone = [f for f in bm.faces if f.index not in keep]
        bmesh.ops.delete(bm, geom=gone, context="FACES")
        bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context="VERTS")
        # move to the grip, turn blade-up (half turn about Y: no mirroring), then crop the UVs to this sword
        gx, gz = spec["grip"]
        m = Matrix.Rotation(math.pi, 4, "Y") @ Matrix.Translation(Vector((-gx, 0.0, -gz)))
        bmesh.ops.transform(bm, matrix=m, verts=bm.verts)
        uvl = bm.loops.layers.uv.active
        us = [l[uvl].uv.x for f in bm.faces for l in f.loops]
        vs = [l[uvl].uv.y for f in bm.faces for l in f.loops]
        pad = 0.004
        u0, u1 = max(0.0, min(us) - pad), min(1.0, max(us) + pad)
        v0, v1 = max(0.0, min(vs) - pad), min(1.0, max(vs) + pad)
        for f in bm.faces:
            for l in f.loops:
                l[uvl].uv.x = (l[uvl].uv.x - u0) / (u1 - u0)
                l[uvl].uv.y = (l[uvl].uv.y - v0) / (v1 - v0)
        new_mesh = bpy.data.meshes.new("sword_" + spec["id"])
        bm.to_mesh(new_mesh)
        bm.free()
        obj = bpy.data.objects.new("sword_" + spec["id"], new_mesh)
        bpy.context.scene.collection.objects.link(obj)
        mat = src_mat.copy()
        mat.name = "sword_" + spec["id"]
        obj.data.materials.append(mat)
        # textures: crop the UV box (image rows run top-down, V runs bottom-up), then shrink
        cropped = {}
        for label, im in maps.items():
            W, H = im.size
            box = (int(u0 * W), int((1 - v1) * H), int(math.ceil(u1 * W)), int(math.ceil((1 - v0) * H)))
            cropped[label] = im.crop(box)
        small = downscale_all(cropped, MAX_TEX)
        replace_material_images(mat, small, tmp, spec["id"])
        # export just this sword
        path = os.path.join(OUT, spec["file"])
        export_glb(path, [obj])
        lo, hi = bounds([obj])
        report.append((spec["file"], tri_count(obj), small["BASE COLOR"].size, lo, hi, spec["what"]))
    print()
    for name, tris, size, lo, hi, what in report:
        print("%-24s %3d tris  tex %dx%d  blade length %.2f  grip->pommel %.2f  width %.2f  | %s" % (
            name, tris, size[0], size[1], -lo.z if False else hi.z, -lo.z, hi.x - lo.x, what))
    print("total tris", sum(r[1] for r in report), "(source sheet %d)" % tri_count(src_obj))


main()
