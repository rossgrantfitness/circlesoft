"""A-pose reference sheets for Ross: one orthographic turnaround sheet per character, one lineup sheet,
and 4x plain texture copies, all written to docs/art_reference/.

This only READS the finished placeholder models (it imports each .glb into a scratch Blender scene, bends
the rig into an A-pose there, and renders). It never saves a model, so nothing under game/art changes.

Run (Blender as a Python module, Python 3.11):
    python3 -m venv /tmp/apose_venv
    /tmp/apose_venv/bin/pip install bpy==5.0.1 pillow numpy
    /tmp/apose_venv/bin/python game/scripts/tools/render_apose_sheets.py                 (everything)
    /tmp/apose_venv/bin/python game/scripts/tools/render_apose_sheets.py --only red otis (just those)
    /tmp/apose_venv/bin/python game/scripts/tools/render_apose_sheets.py --lineup-only
    /tmp/apose_venv/bin/python game/scripts/tools/render_apose_sheets.py --out /some/dir

What the renders are (Ross's brief, 2026-10-08):
  * A-pose: upper and lower arms turned to 45 degrees off the body, straight; legs a little apart with the
    boots kept flat; held props keep the orientation they have in the model's own rest pose (door upright,
    sword blade up, ...) and just follow the hand to its new place. Drones keep their hover pose.
  * Views: front, 3/4 front, side (left), 3/4 back, back, side (right); all one scale on one sheet.
  * Unlit: every material is swapped for a plain emission of its own texture with Closest (nearest
    neighbor) filtering, so the colors are the texture colors. No PSX jitter, dither, fog, post grade or
    shadows (none of that exists in this scratch scene). White background.
  * Poses are made in this scratch scene only, with the pose bones of the 17-bone rig (names in
    prototypes/red_proto_de_kit.py BONE_NAMES): upper_arm_l/r and forearm_l/r are aimed straight at 45
    degrees; thigh_l/r are turned out a few degrees (shin_l/r turn back so the boots stay flat) and shifted
    sideways until there is a small gap between the boots; prop_socket and weapon_socket keep their rest
    orientation. A triangle-overlap check (BVH) reports any hand, prop or leg that pokes into something.
"""

import argparse
import hashlib
import io
import json
import math
import os
import struct
import sys

import bpy
import numpy as np
from mathutils import Matrix, Vector
from mathutils.bvhtree import BVHTree
from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", ".."))
ART = os.path.join(ROOT, "game", "art", "placeholder")
DEFAULT_OUT = os.path.join(ROOT, "docs", "art_reference")

ARM_DEG = 45.0          # arms off the body, measured from straight down
ARM_MAX_DEG = 75.0      # widest the auto-widening goes if a hand would clip the body
LEG_DEG = 5.0           # thighs turned out this much (shins turn back so the boots stay flat)
LEG_GAP = 0.05          # smallest gap between the two legs (units) after posing
PANEL_W = 620           # one view panel on a character sheet, px
MAX_PX_PER_UNIT = 760.0
MIN_PX_PER_UNIT = 400.0
FLOOR_PAD = 70          # px of white under the feet
FIG_TOP_PAD = 70        # px above the tallest point (room for the view labels)
RULER_W = 170           # left margin that holds the ruler
SAMPLES = 8

VIEWS = [  # (label, camera azimuth in degrees from the front, turning toward the character's left side)
    ("FRONT", 0.0),
    ("3/4 FRONT", 45.0),
    ("SIDE (left side, faces left)", 90.0),
    ("3/4 BACK", 135.0),
    ("BACK", 180.0),
    ("SIDE (right side, faces right)", 270.0),
]

# One entry per sheet. "glb" is relative to game/art/placeholder. "hide" lists mesh-name pieces to leave
# out of the render (the surrender flag only shows when the grunt gives up, and its pole hangs below the floor).
MODELS = [
    dict(id="red", name="RED", glb="characters/red/red_shiba_grim.glb", kind="biped", lineup=True,
         about="Party member. Current approved grim shiba. Sword on the right, lamp mitt on the left."),
    dict(id="red_classic", name="RED - old (classic)", glb="characters/red/red_shiba.glb", kind="biped",
         lineup=False, about="Secondary sheet: the earlier classic Red (red_shiba.glb). Superseded by the grim version."),
    dict(id="otis", name="OTIS", glb="characters/otis/chr_otis.glb", kind="biped", lineup=True,
         about="Party member. Boulder with a door (left hand) and a hammer (right hand)."),
    dict(id="mox", name="MOX", glb="characters/mox/chr_mox.glb", kind="biped", lineup=True,
         about="Party member. Mask, big wrench (right hand) and a floating drone at the shoulder."),
    dict(id="old_zero", name="OLD ZERO", glb="characters/old_zero/npc_old_zero.glb", kind="biped", lineup=True,
         about="NPC. Species still open. Holds a thermos (left hand)."),
    dict(id="signals_grunt", name="SIGNALS GRUNT", glb="enemies/signals_grunt/enm_signals_grunt.glb", kind="biped",
         lineup=True, hide=["_prop_flag"], about="Enemy. Signals Corps foot soldier with a clipboard (left hand). White surrender flag hidden."),
    dict(id="whistle_blower", name="WHISTLE BLOWER", glb="enemies/grunt_variant/enm_grunt_variant.glb", kind="biped",
         lineup=True, hide=["_prop_flag"], about="Enemy. Grunt variant with a megaphone (left hand). White surrender flag hidden."),
    dict(id="signals_drone", name="SIGNALS DRONE", glb="enemies/signals_drone/enm_signals_drone.glb", kind="drone",
         lineup=True, about="Enemy. Flying drone, no arms, neutral hover pose (origin on the floor under it)."),
    dict(id="buzzkill", name="BUZZKILL", glb="enemies/drone_variant/enm_drone_variant.glb", kind="drone",
         lineup=True, about="Enemy. Drone variant, no arms, neutral hover pose (origin on the floor under it)."),
]

FONT_PATHS = ["/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf", "/usr/share/fonts/truetype/liberation/LiberationSans-Regular.ttf"]
FONT_BOLD_PATHS = ["/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", "/usr/share/fonts/truetype/liberation/LiberationSans-Bold.ttf"]


def font(size, bold=False):
    for p in (FONT_BOLD_PATHS if bold else FONT_PATHS):
        if os.path.exists(p):
            return ImageFont.truetype(p, size)
    return ImageFont.load_default(size)


# ------------------------------------------------------------------------ reading the .glb files directly
def read_glb(path):
    with open(path, "rb") as f:
        data = f.read()
    json_len = struct.unpack("<I", data[12:16])[0]
    doc = json.loads(data[20:20 + json_len])
    bin_start = 20 + json_len
    bin_len = struct.unpack("<I", data[bin_start:bin_start + 4])[0]
    blob = data[bin_start + 8:bin_start + 8 + bin_len]
    return doc, blob


def glb_textures(path):
    """{'body': PIL image, 'face': PIL image or None} from the images embedded in the .glb (the exact pixels)."""
    doc, blob = read_glb(path)
    out = {"body": None, "face": None}
    for img in doc.get("images", []):
        view = doc["bufferViews"][img["bufferView"]]
        raw = blob[view.get("byteOffset", 0):view.get("byteOffset", 0) + view["byteLength"]]
        im = Image.open(io.BytesIO(raw))
        im.load()
        im = im.convert("RGB") if im.mode in ("RGB", "P") and "A" not in im.getbands() else im.convert("RGBA")
        key = "face" if img.get("name", "").endswith("_face") else "body"
        out[key] = im
    return out


def prop_key(mesh_name):
    """'chr_otis_prop_hammer' -> 'hammer'; Red's 'red_shiba_grim_sword' -> 'sword'; body parts -> None."""
    if "_prop_" in mesh_name:
        return mesh_name.split("_prop_")[1]
    if mesh_name.endswith("_sword"):
        return "sword"
    return None


def glb_triangles(path):
    """{mesh name: triangle count} straight from the index accessors."""
    doc, _ = read_glb(path)
    res = {}
    for mesh in doc["meshes"]:
        n = 0
        for prim in mesh["primitives"]:
            n += doc["accessors"][prim["indices"]]["count"] // 3
        res[mesh["name"]] = n
    return res


def palette(img, limit, min_share=0.004):
    """Most used exact colors in an image: list of ((r, g, b), share)."""
    arr = np.array(img.convert("RGB")).reshape(-1, 3)
    colors, counts = np.unique(arr, axis=0, return_counts=True)
    order = np.argsort(-counts)
    total = counts.sum()
    res = []
    for i in order:
        share = counts[i] / total
        if share < min_share and res:
            break
        res.append((tuple(int(c) for c in colors[i]), float(share)))
        if len(res) >= limit:
            break
    return res


# ------------------------------------------------------------------------ the Blender scene
class Model:
    def __init__(self, spec):
        self.spec = spec
        self.path = os.path.join(ART, spec["glb"])
        bpy.ops.wm.read_factory_settings(use_empty=True)
        bpy.ops.import_scene.gltf(filepath=self.path)
        for o in list(bpy.data.objects):
            if o.name.startswith("Icosphere"):          # the importer's bone-shape helper, not part of the model
                bpy.data.objects.remove(o, do_unlink=True)
        self.arm = next(o for o in bpy.data.objects if o.type == "ARMATURE")
        self.arm.animation_data_clear()                  # drop the idle clip: we start from the rest pose
        for pb in self.arm.pose.bones:
            pb.rotation_mode = "QUATERNION"
            pb.location = (0, 0, 0)
            pb.rotation_quaternion = (1, 0, 0, 0)
            pb.scale = (1, 1, 1)
        bpy.context.view_layer.update()
        assert all(abs(self.arm.matrix_world[i][j] - (1.0 if i == j else 0.0)) < 1e-6 for i in range(4) for j in range(4))
        self.meshes = [o for o in bpy.data.objects if o.type == "MESH"]
        self.hidden = []
        for m in self.meshes:
            if any(h in m.name for h in spec.get("hide", [])):
                m.hide_render = True
                m.hide_viewport = True
                self.hidden.append(m)
        self.visible = [m for m in self.meshes if m not in self.hidden]
        self.props = [m for m in self.visible if prop_key(m.name)]
        self.body = [m for m in self.visible if not prop_key(m.name)]
        self.report = []
        self._unlit_materials()

    # -- materials: emission of the texture, nearest neighbor
    def _unlit_materials(self):
        for mat in bpy.data.materials:
            if not mat.node_tree:
                continue
            tree = mat.node_tree
            tex = next((n for n in tree.nodes if n.type == "TEX_IMAGE"), None)
            if tex is None:
                continue
            tex.interpolation = "Closest"
            out = next(n for n in tree.nodes if n.type == "OUTPUT_MATERIAL")
            emit = tree.nodes.new("ShaderNodeEmission")
            emit.inputs["Strength"].default_value = 1.0
            tree.links.new(tex.outputs["Color"], emit.inputs["Color"])
            tree.links.new(emit.outputs[0], out.inputs["Surface"])
            mat.use_backface_culling = False

    # -- geometry helpers
    def world_mesh(self, obj):
        dg = bpy.context.evaluated_depsgraph_get()
        eo = obj.evaluated_get(dg)
        me = eo.to_mesh()
        verts = [obj.matrix_world @ v.co for v in me.vertices]
        me.calc_loop_triangles()
        tris = [tuple(t.vertices) for t in me.loop_triangles]
        eo.to_mesh_clear()
        return verts, tris

    def bounds(self, objs=None):
        pts = []
        for o in (objs if objs is not None else self.visible):
            pts.extend(self.world_mesh(o)[0])
        a = np.array([[p.x, p.y, p.z] for p in pts])
        return a.min(axis=0), a.max(axis=0), a

    def vertex_bone(self, obj):
        names = {g.index: g.name for g in obj.vertex_groups}
        out = []
        for v in obj.data.vertices:
            best = max(v.groups, key=lambda g: g.weight) if v.groups else None
            out.append(names[best.group] if best else "")
        return out

    # -- posing
    def pb(self, name):
        return self.arm.pose.bones[name]

    def update(self):
        bpy.context.view_layer.update()

    def aim(self, bone, target):
        """Turn a pose bone about its head so its head->tail axis points along `target` (armature space)."""
        pb = self.pb(bone)
        cur = (pb.matrix.to_3x3() @ Vector((0, 1, 0))).normalized()
        q = cur.rotation_difference(Vector(target).normalized())
        head = pb.matrix.translation.copy()
        pb.matrix = Matrix.Translation(head) @ q.to_matrix().to_4x4() @ Matrix.Translation(-head) @ pb.matrix
        self.update()

    def keep_rest_orientation(self, bone):
        pb = self.pb(bone)
        rest = self.arm.data.bones[bone].matrix_local.to_3x3()
        pb.matrix = Matrix.Translation(pb.matrix.translation.copy()) @ rest.to_4x4()
        self.update()

    def leg_extent(self, side):
        xs = []
        names = ("thigh_" + side, "shin_" + side)
        for o in self.body:
            vb = self.vertex_bone(o)
            verts, _ = self.world_mesh(o)
            xs += [verts[i].x for i, b in enumerate(vb) if b in names]
        return xs

    def reset_pose(self):
        for pb in self.arm.pose.bones:
            pb.location = (0, 0, 0)
            pb.rotation_quaternion = (1, 0, 0, 0)
            pb.scale = (1, 1, 1)
        self.update()

    def pose_a(self):
        """A-pose at ARM_DEG. If a hand or prop would poke into the body, widen the arms 5 degrees at a time
        (up to ARM_MAX_DEG) until nothing does, and say so in the report."""
        if self.spec["kind"] != "biped":
            self.report.append("hover pose kept (drone, no arms)")
            return
        angle = ARM_DEG
        while True:
            self.reset_pose()
            self.report = []
            self._pose_a_at(angle)
            bad = [o for o in self.clip_report() if self._is_clip(o)]
            if not bad or angle >= ARM_MAX_DEG:
                break
            angle += 5.0
        self.arm_deg = angle
        if bad:
            self.report.append("WARNING still clipping at %.0f deg: %s" % (angle, bad))
        elif angle != ARM_DEG:
            self.report.append("arms widened to %.0f deg (45 clipped the body)" % angle)

    @staticmethod
    def _is_clip(overlap):
        a, b, _ = overlap
        if a.startswith("hand_") and (b == "torso" or b.startswith("leg_") or b.startswith("hand_")):
            return True
        if a.startswith("prop:") and (b == "torso" or b.startswith("leg_")):
            return True
        if a.startswith("prop:") and b.startswith("hand_") or a.startswith("prop:") and b.startswith("arm_"):
            return False
        return a.startswith("leg_") and b.startswith("leg_")

    def _pose_a_at(self, arm_deg):
        d = math.radians(arm_deg)
        floor_before = self._foot_floor()
        # arms: straight, 45 degrees out from the body, in the front plane
        for side, sign in (("l", 1.0), ("r", -1.0)):
            self.aim("upper_arm_" + side, (sign * math.sin(d), 0, -math.cos(d)))
            self.aim("forearm_" + side, (sign * math.sin(d), 0, -math.cos(d)))
        # props follow the hand but keep their own rest orientation
        for socket in ("prop_socket", "weapon_socket"):
            self.keep_rest_orientation(socket)
        # legs: a few degrees out, shins turned back so the boots stay flat, then slide apart to a small gap
        phi = math.radians(LEG_DEG)
        for side, sign in (("l", 1.0), ("r", -1.0)):
            self.aim("thigh_" + side, (sign * math.sin(phi), 0, -math.cos(phi)))
            self.keep_rest_orientation("shin_" + side)
        gap = min(self.leg_extent("l")) - max(self.leg_extent("r"))
        shift = max(0.0, (LEG_GAP - gap) / 2.0)
        if shift > 0:
            for side, sign in (("l", 1.0), ("r", -1.0)):
                pb = self.pb("thigh_" + side)
                pb.matrix = Matrix.Translation(Vector((sign * shift, 0, 0))) @ pb.matrix
                self.update()
        gap_after = min(self.leg_extent("l")) - max(self.leg_extent("r"))
        # put the boots back on the same floor they stood on before posing
        dz = floor_before - self._foot_floor()
        if abs(dz) > 1e-5:
            root = self.pb("root")
            root.matrix = Matrix.Translation(Vector((0, 0, dz))) @ root.matrix
            self.update()
        self.report.append(f"arms {arm_deg:.0f} deg, legs turned {LEG_DEG:.0f} deg, boot gap {gap:+.3f} -> {gap_after:+.3f}, floor shift {dz:+.4f}")

    def _foot_floor(self):
        zs = []
        for o in self.body:
            vb = self.vertex_bone(o)
            verts, _ = self.world_mesh(o)
            zs += [verts[i].z for i, b in enumerate(vb) if b.startswith("shin_")]
        return min(zs) if zs else 0.0

    # -- does anything poke into anything?
    def clip_report(self):
        if self.spec["kind"] != "biped":
            return []
        regions = {}

        def add(region, verts, tris, pick):
            keep = [t for t in tris if pick(t)]
            if keep:
                regions.setdefault(region, []).append((verts, keep))

        groups = {
            "hand_l": ("forearm_l",), "hand_r": ("forearm_r",),
            "arm_l": ("upper_arm_l",), "arm_r": ("upper_arm_r",),
            "torso": ("hips", "spine", "head", "ear_l", "ear_r", "tail"),
            "leg_l": ("thigh_l", "shin_l"), "leg_r": ("thigh_r", "shin_r"),
        }
        bone_to_region = {b: r for r, bs in groups.items() for b in bs}
        for o in self.body:
            vb = self.vertex_bone(o)
            verts, tris = self.world_mesh(o)
            for region in groups:
                add(region, verts, tris, lambda t, region=region: bone_to_region.get(vb[t[0]]) == region)
        for o in self.props:
            verts, tris = self.world_mesh(o)
            regions.setdefault("prop:" + prop_key(o.name), []).append((verts, tris))

        def tree(name):
            verts, tris = [], []
            for v, t in regions[name]:
                base = len(verts)
                verts += [tuple(p) for p in v]
                tris += [(a + base, b + base, c + base) for a, b, c in t]
            return BVHTree.FromPolygons(verts, tris)

        names = list(regions)
        trees = {n: tree(n) for n in names}
        pairs = [("hand_l", "torso"), ("hand_l", "leg_l"), ("hand_l", "leg_r"), ("hand_r", "torso"),
                 ("hand_r", "leg_l"), ("hand_r", "leg_r"), ("hand_l", "hand_r"), ("leg_l", "leg_r"),
                 ("arm_l", "torso"), ("arm_r", "torso")]
        props = [n for n in names if n.startswith("prop:")]
        for p in props:
            for other in ("torso", "leg_l", "leg_r", "hand_l", "hand_r", "arm_l", "arm_r"):
                pairs.append((p, other))
        for i, p in enumerate(props):
            for q in props[i + 1:]:
                pairs.append((p, q))
        found = []
        for a, b in pairs:
            if a in trees and b in trees:
                n = len(trees[a].overlap(trees[b]))
                if n:
                    found.append((a, b, n))
        return found

    # -- stats
    def stats(self):
        tris = glb_triangles(self.path)
        return tris

    # -- rendering
    def setup_render(self):
        sc = bpy.context.scene
        sc.render.engine = "CYCLES"
        sc.cycles.device = "CPU"
        sc.cycles.samples = SAMPLES
        sc.cycles.use_denoising = False
        sc.cycles.max_bounces = 0
        sc.cycles.pixel_filter_type = "BLACKMAN_HARRIS"
        sc.cycles.filter_width = 1.0
        sc.view_settings.view_transform = "Standard"
        sc.view_settings.look = "None"
        sc.view_settings.exposure = 0.0
        sc.view_settings.gamma = 1.0
        sc.display_settings.display_device = "sRGB"
        sc.render.film_transparent = True
        sc.render.image_settings.file_format = "PNG"
        sc.render.image_settings.color_mode = "RGBA"
        sc.render.image_settings.color_depth = "8"
        sc.render.dither_intensity = 0.0
        sc.render.resolution_percentage = 100
        cam_data = bpy.data.cameras.new("apose_cam")
        cam_data.type = "ORTHO"
        cam_data.sensor_fit = "HORIZONTAL"
        cam_data.clip_start = 0.05
        cam_data.clip_end = 100.0
        self.cam = bpy.data.objects.new("apose_cam", cam_data)
        sc.collection.objects.link(self.cam)
        sc.camera = self.cam

    def render(self, azimuth_deg, px_per_unit, width, height, center_x, floor_row, tmp_path):
        """Orthographic render at `px_per_unit`; the world point (center_x, 0, 0) lands on column width/2 and
        the floor (z = 0) on row `floor_row` of the image. Camera orbits the model's origin."""
        sc = bpy.context.scene
        sc.render.resolution_x = int(width)
        sc.render.resolution_y = int(height)
        self.cam.data.ortho_scale = width / px_per_unit
        a = math.radians(azimuth_deg)
        zc = (height / 2.0 - (height - floor_row)) / px_per_unit
        # view-space offset so the centre column is at world x = center_x for the front view; for other views
        # the orbit stays about the origin, so only the horizontal shift of the chosen azimuth is applied.
        right = Vector((math.cos(a), math.sin(a), 0.0))
        forward_pos = Vector((math.sin(a), -math.cos(a), 0.0)) * 10.0
        pos = forward_pos + right * center_x + Vector((0, 0, zc))
        self.cam.location = pos
        self.cam.rotation_euler = (math.pi / 2.0, 0.0, a)
        sc.render.filepath = tmp_path
        bpy.ops.render.render(write_still=True)
        img = Image.open(tmp_path)
        img.load()
        return img.convert("RGBA")


# ------------------------------------------------------------------------ drawing the sheets
GREY = (140, 140, 140)
DARK = (50, 50, 50)
LIGHT_GREY = (205, 205, 205)


def hex_of(rgb):
    return "#%02X%02X%02X" % rgb


def text_w(draw, s, fnt):
    return draw.textlength(s, font=fnt)


def draw_ruler(draw, x, floor_y, px_per_unit, top_units, label_font):
    """Thin grey ruler: a vertical line with a tick every 0.1 unit, longer ticks every 0.5, numbers at 0, 0.5, 1.0..."""
    n_ticks = int(math.floor(top_units * 10 + 1e-6))
    y_top = floor_y - n_ticks / 10.0 * px_per_unit
    draw.line([(x, floor_y), (x, y_top)], fill=GREY, width=2)
    for i in range(n_ticks + 1):
        u = i / 10.0
        y = floor_y - u * px_per_unit
        major = i % 5 == 0
        length = 26 if major else 12
        draw.line([(x - length, y), (x, y)], fill=GREY, width=2 if major else 1)
        if major:
            label = "%.1f" % u
            draw.text((x - length - 8 - text_w(draw, label, label_font), y - 11), label, fill=GREY, font=label_font)
    draw.text((x - 62, y_top - 40), "units", fill=GREY, font=label_font)


def draw_swatches(draw, x, y, label, colors, fnts, sw=150, sh=56):
    draw.text((x, y), label, fill=DARK, font=fnts["small_bold"])
    y += 30
    for i, rgb in enumerate(colors):
        sx = x + i * (sw + 10)
        draw.rectangle([sx, y, sx + sw, y + sh], fill=rgb, outline=GREY)
        draw.text((sx, y + sh + 4), hex_of(rgb), fill=DARK, font=fnts["small"])
    return y + sh + 34


def build_character_sheet(model, out_dir, tmp_dir):
    spec = model.spec
    lo, hi, pts = model.bounds()
    radius = float(np.max(np.hypot(pts[:, 0], pts[:, 1])))
    body_lo, body_hi, _ = model.bounds(model.body)
    px = min(MAX_PX_PER_UNIT, PANEL_W * 0.94 / (2 * radius))
    panel_w = PANEL_W
    if px < MIN_PX_PER_UNIT:                      # wide props (Otis's door and hammer): widen the panels instead of shrinking
        px = MIN_PX_PER_UNIT
        panel_w = int(math.ceil(2 * radius * px / 0.94))
    top_units = math.ceil(hi[2] * 10) / 10.0 + 0.0
    fig_h = int(round(top_units * px)) + FLOOR_PAD + FIG_TOP_PAD
    floor_row = fig_h - FLOOR_PAD
    n = len(VIEWS)
    sheet_w = RULER_W + n * panel_w + 40
    header_h = 150
    footer_h = 460
    sheet_h = header_h + fig_h + footer_h
    sheet = Image.new("RGB", (sheet_w, sheet_h), (255, 255, 255))
    draw = ImageDraw.Draw(sheet)
    fnts = dict(title=font(64, True), sub=font(30), small=font(24), small_bold=font(24, True), tiny=font(22), label=font(26, True), ruler=font(22))

    fig_y = header_h
    floor_y = fig_y + floor_row
    for i, (label, az) in enumerate(VIEWS):
        tmp = os.path.join(tmp_dir, "view_%s_%d.png" % (spec["id"], i))
        img = model.render(az, px, panel_w, fig_h, 0.0, floor_row, tmp)
        x0 = RULER_W + i * panel_w
        sheet.paste(img, (x0, fig_y), img)
        tw = text_w(draw, label, fnts["label"])
        draw.text((x0 + (panel_w - tw) / 2, fig_y + 12), label, fill=GREY, font=fnts["label"])
    draw.line([(RULER_W - 4, floor_y), (sheet_w - 20, floor_y)], fill=LIGHT_GREY, width=2)
    draw_ruler(draw, RULER_W - 50, floor_y, px, top_units, fnts["ruler"])

    # header
    draw.text((RULER_W, 24), spec["name"] + "  -  A-pose reference", fill=DARK, font=fnts["title"])
    draw.text((RULER_W, 104), spec["about"], fill=GREY, font=fnts["sub"])

    # footer
    tris = model.stats()
    body_tris = sum(v for k, v in tris.items() if not prop_key(k))
    prop_tris = {prop_key(k): v for k, v in tris.items() if prop_key(k)}
    shown_props = {k: v for k, v in prop_tris.items() if any(prop_key(m.name) == k for m in model.props)}
    hidden_props = {k: v for k, v in prop_tris.items() if k not in shown_props}
    tex = glb_textures(model.path)
    bones = len(model.arm.data.bones)
    total = body_tris + sum(prop_tris.values())
    props_txt = " + ".join("%s %d" % (k, v) for k, v in prop_tris.items())
    tri_txt = "Triangles: %d total  (body %d%s)" % (total, body_tris, (" + " + props_txt) if props_txt else "")
    tex_txt = "Textures: body %dx%d" % tex["body"].size + ("  +  face sheet %dx%d" % tex["face"].size if tex["face"] else "  (no face sheet)")
    glb_rel = os.path.relpath(model.path, ROOT).replace(os.sep, "/")
    height_body = body_hi[2]
    height_all = hi[2]
    fy = fig_y + fig_h + 24
    draw.text((RULER_W, fy), "Model: " + glb_rel, fill=DARK, font=fnts["small_bold"])
    draw.text((RULER_W, fy + 34), tri_txt + "     Bones: %d     " % bones + tex_txt, fill=DARK, font=fnts["small"])
    ht = "Height in this pose: %.2f units to the top of the model%s" % (height_body, " (with ears)" if spec["kind"] == "biped" else "")
    if height_all > height_body + 0.005:
        ht += ", %.2f with props" % height_all
    ht += "     Scale: 1 unit = 1 m = %d px on this sheet, all views the same scale" % round(px)
    draw.text((RULER_W, fy + 68), ht, fill=DARK, font=fnts["small"])
    note = ""
    if hidden_props:
        note = "   (hidden: " + ", ".join(hidden_props) + " prop, only shown when the enemy surrenders)"
    pose_txt = "A-pose: arms %.0f deg off the body" % getattr(model, "arm_deg", 0) if spec["kind"] == "biped" else "Neutral hover pose (no arms)"
    origin_txt = " (on the floor under the drone)" if spec["kind"] == "drone" else ""
    draw.text((RULER_W, fy + 102), pose_txt + ". Unlit render, nearest-neighbor, no PSX jitter / dither / fog. Model origin at the feet" + origin_txt + "." + note, fill=GREY, font=fnts["small"])
    y = fy + 150
    y = draw_swatches(draw, RULER_W, y, "Body texture colors (most used first)", [c for c, _ in palette(tex["body"], 14)], fnts)
    if tex["face"] is not None:
        draw_swatches(draw, RULER_W, y, "Face sheet colors", [c for c, _ in palette(tex["face"], 8)], fnts)
    path = os.path.join(out_dir, "%s_apose_sheet.png" % spec["id"])
    sheet.save(path, optimize=True)
    return dict(path=path, px=px, tris_total=total, tris_body=body_tris, props=prop_tris, shown=list(shown_props),
                bones=bones, tex_body=tex["body"].size, tex_face=tex["face"].size if tex["face"] else None,
                height_body=float(height_body), height_all=float(height_all), bounds_lo=[float(v) for v in lo],
                bounds_hi=[float(v) for v in hi], size=sheet.size)


def export_textures(spec, out_dir):
    tex = glb_textures(os.path.join(ART, spec["glb"]))
    written = []
    os.makedirs(os.path.join(out_dir, "textures"), exist_ok=True)
    for key in ("body", "face"):
        im = tex[key]
        if im is None:
            continue
        big = im.resize((im.width * 4, im.height * 4), Image.NEAREST)
        p = os.path.join(out_dir, "textures", "%s_%s_4x.png" % (spec["id"], key))
        big.save(p)
        written.append((p, im.size, big.size))
    return written


# ------------------------------------------------------------------------ main
def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--only", nargs="*", help="model ids to build (default all)")
    ap.add_argument("--lineup-only", action="store_true")
    ap.add_argument("--no-lineup", action="store_true")
    ap.add_argument("--textures-only", action="store_true")
    ap.add_argument("--out", default=DEFAULT_OUT)
    ap.add_argument("--tmp", default=os.path.join(os.environ.get("TMPDIR", "/tmp"), "apose_tmp"))
    args = ap.parse_args()
    out_dir = args.out
    os.makedirs(out_dir, exist_ok=True)
    os.makedirs(args.tmp, exist_ok=True)
    wanted = args.only or [m["id"] for m in MODELS]
    results = {}
    lineup_data = []
    for spec in MODELS:
        if spec["id"] not in wanted:
            continue
        print("==", spec["id"], flush=True)
        entry = {"textures": [(os.path.relpath(p, out_dir), a, b) for p, a, b in export_textures(spec, out_dir)]}
        if args.textures_only:
            results[spec["id"]] = entry
            continue
        model = Model(spec)
        model.setup_render()
        model.pose_a()
        entry["pose"] = model.report
        entry["clips"] = [(a.name, a.frame_range[1]) for a in bpy.data.actions]
        clips = model.report
        found = model.clip_report()
        entry["overlaps"] = found
        print("  pose:", clips, "\n  overlaps:", found, flush=True)
        if not args.lineup_only:
            info = build_character_sheet(model, out_dir, args.tmp)
            entry["sheet"] = info
        else:
            lo, hi, _ = model.bounds()
            blo, bhi, _ = model.bounds(model.body)
            info = dict(bounds_lo=[float(v) for v in lo], bounds_hi=[float(v) for v in hi], height_body=float(bhi[2]))
        results[spec["id"]] = entry
        if spec.get("lineup") and not args.no_lineup:
            lineup_data.append((spec["id"], info))
        # the lineup needs the posed model again; re-create it later (one Blender scene at a time)
    if not args.textures_only and not args.no_lineup:
        lineup_models = []
        for spec in MODELS:
            if spec["id"] in wanted and spec.get("lineup"):
                lineup_models.append(spec)
        if lineup_models:
            print("== lineup", flush=True)
            build_lineup_from_specs(lineup_models, out_dir, args.tmp, results)
    with open(os.path.join(args.tmp, "results.json"), "w") as f:
        json.dump(results, f, indent=1, default=str)
    print("done")


def build_lineup_from_specs(specs, out_dir, tmp_dir, results):
    """Every model lives in its own Blender scene, so the lineup renders each one in turn (same scale, same
    floor row) and pastes the pieces together."""
    px = 420.0
    gap_units = 0.16
    posed = []
    for spec in specs:
        model = Model(spec)
        model.setup_render()
        model.pose_a()
        lo, hi, _ = model.bounds()
        blo, bhi, _ = model.bounds(model.body)
        posed.append((spec, dict(bounds_lo=[float(v) for v in lo], bounds_hi=[float(v) for v in hi], height_body=float(bhi[2]))))
        # render later, once the shared layout is known; keep the scene's render by doing it right now
        posed[-1][1]["model_ready"] = model
        # (a Blender scene is replaced on the next Model(); so render now into a temporary full-height strip)
        tops = hi[2]
        fig_h = int(math.ceil(1.45 * px)) + FLOOR_PAD + FIG_TOP_PAD
        floor_row = fig_h - FLOOR_PAD
        width = int(math.ceil((hi[0] - lo[0] + gap_units) * px))
        cx = (lo[0] + hi[0]) / 2.0
        tmp = os.path.join(tmp_dir, "lineup_%s.png" % spec["id"])
        posed[-1][1]["img"] = model.render(0.0, px, width, fig_h, cx, floor_row, tmp)
        posed[-1][1]["fig_h"] = fig_h
        posed[-1][1]["width"] = width
        posed[-1][1]["model_ready"] = None
    fnts = dict(title=font(64, True), sub=font(30), small=font(24), small_bold=font(26, True), ruler=font(22))
    tops = max(info["bounds_hi"][2] for _, info in posed)
    top_units = math.ceil(tops * 10) / 10.0
    fig_h = posed[0][1]["fig_h"]
    floor_row = fig_h - FLOOR_PAD
    header_h, footer_h = 150, 130
    x = RULER_W
    cells = []
    for spec, info in posed:
        cells.append((spec, info, x, info["width"]))
        x += info["width"]
    sheet_w = max(x + 40, 2048)
    # crop the figure strip to the tallest model so there is no dead white space above it
    crop_top = max(0, floor_row - int(top_units * px) - FIG_TOP_PAD)
    strip_h = fig_h - crop_top
    sheet = Image.new("RGB", (sheet_w, header_h + strip_h + footer_h), (255, 255, 255))
    draw = ImageDraw.Draw(sheet)
    for spec, info, x0, width in cells:
        img = info["img"].crop((0, crop_top, width, fig_h))
        sheet.paste(img, (x0, header_h), img)
    floor_y = header_h + floor_row - crop_top
    draw.line([(RULER_W - 4, floor_y), (sheet_w - 20, floor_y)], fill=LIGHT_GREY, width=2)
    draw_ruler(draw, RULER_W - 50, floor_y, px, top_units, fnts["ruler"])
    draw.text((RULER_W, 24), "LINEUP  -  A-pose, front view, true relative scale", fill=DARK, font=fnts["title"])
    draw.text((RULER_W, 104), "All models at one scale (1 unit = 1 m = %d px). Unlit, white background. Drones hover at their real height." % round(px),
              fill=GREY, font=fnts["sub"])
    for spec, info, x0, width in cells:
        name = spec["name"].replace("RED - old (classic)", "RED (classic)")
        cxp = x0 + width / 2.0
        for j, line in enumerate([name, "%.2f tall" % info["height_body"]]):
            fnt = fnts["small_bold"] if j == 0 else fnts["small"]
            tw = text_w(draw, line, fnt)
            draw.text((cxp - tw / 2, floor_y + 18 + j * 34), line, fill=DARK if j == 0 else GREY, font=fnt)
    path = os.path.join(out_dir, "lineup_apose.png")
    sheet.save(path, optimize=True)
    results["lineup"] = dict(path=path, size=sheet.size, px=px)
    print("  lineup", sheet.size)


if __name__ == "__main__":
    main()
