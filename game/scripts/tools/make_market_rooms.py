#!/usr/bin/env python3
"""Writes the nine graybox rooms of the night market (vertical slice task VS-14).

Derived from make_harrow_rooms.py (the approved Harrow Landing layout), as docs/maps/night_market.md says: every wall,
door and floor size is the Harrow one. What changed: names, what each room is for, the people, the dressing, and how the
scenes are built for the slice:

  * the scene root is a PLAIN level (Node3D, no FieldRoom script). In slice mode Main wraps it in an ActionRoom, which
    builds Red, the camera, the director and the HUD around it (docs/slice/slice_tech_plan.md 2.2). The room's id, kind,
    camera and look come from game/data/slice/rooms.json. The level only carries the geometry, a Spawns node, the
    CameraRig and CameraBounds, lights and the placed props.
  * floors and walls use Ross's city tiles through the crisp PS2 shader (ps2_lit_crisp.gdshader, the "city_tiles" group is
    nearest-filtered in grim_ps2), using the SEAM-FIXED copies (art/final/textures/city/tiles_seamless/) when the atlas
    says one exists. Everything else is flat tinted boxes on the smooth PS2 shader (placeholders only).
  * no window lamps, no relighting windows: neon and string lights are dressing only (the lamp theme is cut).

Run from the repo root:  python3 game/scripts/tools/make_market_rooms.py
Writes game/scenes/slice/market/market_*.tscn. Everything that is not geometry (what is in a crate, who says what, which
door is locked) lives in game/data/slice/placements.json, rooms.json, jobs.json and market.json; the node names and
placement_id values here have to match them (test_slice_rooms.gd checks).

Coordinates: meters; the origin is the floor corner where the two back walls meet, +X runs east along the north wall, +Z
runs south toward the camera, +Y up.
"""
import json
import math
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
from make_test_rooms import Room  # noqa: E402

GAME = os.path.join(os.path.dirname(__file__), "..", "..")
OUT = os.path.join(GAME, "scenes", "slice", "market")
CITY = "res://art/final/textures/city/"
TILE_M = 2.0      # one 128 px city tile is 2 m on a wall or floor (the sandbox's tile_m)

with open(os.path.join(GAME, "data", "world", "city_texture_atlas.json")) as _f:
    ATLAS = {t["id"]: t for t in json.load(_f)["tiles"]}


def yaw_to(dx, dz):
    return math.degrees(math.atan2(dx, dz))


def tile_path(tile_id):
    """The seam-fixed copy when the atlas has one, else the plain slice (the sandbox does the same)."""
    entry = ATLAS[tile_id]
    sub = "tiles_seamless/" if entry.get("seamless_copy") else "tiles/"
    return CITY + sub + tile_id + ".png"


def tile_world_size(tile_id):
    rect = ATLAS[tile_id]["rect"]
    return rect[2] / 128.0 * TILE_M, rect[3] / 128.0 * TILE_M


def aim_transform(origin, direction):
    """A Transform3D(...) string for a light at `origin` shining along `direction` (a light shines along its local -Z)."""
    dx, dy, dz = direction
    n = math.sqrt(dx * dx + dy * dy + dz * dz)
    zx, zy, zz = -dx / n, -dy / n, -dz / n                 # local +Z points back along the beam
    # x = up x z, y = z x x
    xx, xy, xz = 0 * zz - 1 * zy, 1 * zx - 0 * zz, 0 * zy - 0 * zx
    xn = math.sqrt(xx * xx + xy * xy + xz * xz)
    xx, xy, xz = xx / xn, xy / xn, xz / xn
    yx, yy, yz = zy * xz - zz * xy, zz * xx - zx * xz, zx * xy - zy * xx
    return "Transform3D(%.4f, %.4f, %.4f, %.4f, %.4f, %.4f, %.4f, %.4f, %.4f, %s, %s, %s)" % (
        xx, yx, zx, xy, yy, zy, xz, yz, zz, origin[0], origin[1], origin[2])


class M(Room):
    def __init__(self, room_id, title, w, d):
        super().__init__(room_id, 0, w, 0, d)
        self.title, self.w, self.d = title, w, d
        self._mats = {}
        self._planes = {}
        self._cyl = {}
        self._sph = {}
        self.wall_h = 4.0
        self.wall_mat = None
        self.omni_count = 0

    def write(self, filename):
        """Room.write puts the file in scenes/rooms; the market lives in scenes/slice/market."""
        import make_test_rooms
        saved = make_test_rooms.OUT
        make_test_rooms.OUT = OUT
        try:
            super().write(filename)
        finally:
            make_test_rooms.OUT = saved

    # ---------------------------------------------------------------- materials
    def lit(self, tint, rough=0.85):
        """A flat tinted PS2 material (placeholder look; the smooth shader)."""
        key = ("lit", tint, rough)
        if key not in self._mats:
            shader = self.ext_res("Shader", "res://shaders/ps2_lit.gdshader")
            self._mats[key] = self.sub(
                "ShaderMaterial", "shader = %s\nshader_parameter/albedo_tint = Color(%s, %s, %s, 1)\nshader_parameter/use_orm = 0.0\n"
                "shader_parameter/roughness_base = %s" % (shader, tint[0], tint[1], tint[2], rough))
        return self._mats[key]

    def tile(self, tile_id, reps=(1.0, 1.0), tint=(1.0, 1.0, 1.0), offset=(0.0, 0.0)):
        """One of Ross's city tiles (crisp shader). reps = how many tile repeats the surface covers."""
        key = ("tile", tile_id, round(reps[0], 3), round(reps[1], 3), tint, offset)
        if key not in self._mats:
            shader = self.ext_res("Shader", "res://shaders/ps2_lit_crisp.gdshader")
            tex = self.ext_res("Texture2D", tile_path(tile_id))
            self._mats[key] = self.sub(
                "ShaderMaterial", "shader = %s\nshader_parameter/albedo_texture = %s\nshader_parameter/uv_scale = Vector2(%s, %s)\n"
                "shader_parameter/uv_offset = Vector2(%s, %s)\nshader_parameter/albedo_tint = Color(%s, %s, %s, 1)\n"
                "shader_parameter/use_orm = 0.0" % (shader, tex, round(reps[0], 4), round(reps[1], 4), offset[0], offset[1], tint[0], tint[1], tint[2]))
        return self._mats[key]

    def glow(self, tint, energy=1.4):
        """An unlit emissive colour: neon, string-light bulbs, screens."""
        key = ("glow", tint, energy)
        if key not in self._mats:
            self._mats[key] = self.sub(
                "StandardMaterial3D", "shading_mode = 0\nalbedo_color = Color(%s, %s, %s, 1)\nemission_enabled = true\n"
                "emission = Color(%s, %s, %s, 1)\nemission_energy_multiplier = %s" % (tint[0], tint[1], tint[2], tint[0], tint[1], tint[2], energy))
        return self._mats[key]

    def picture(self, tile_id, boost=1.0):
        """A city sign / screen tile as an unlit, crisp picture (it reads as lit: signs and screens)."""
        key = ("pic", tile_id, boost)
        if key not in self._mats:
            tex = self.ext_res("Texture2D", tile_path(tile_id))
            self._mats[key] = self.sub(
                "StandardMaterial3D", "shading_mode = 0\nalbedo_texture = %s\ntexture_filter = 0\nalbedo_color = Color(%s, %s, %s, 1)" % (tex, boost, boost, boost))
        return self._mats[key]

    # ---------------------------------------------------------------- geometry
    def box(self, name, x, y, z, sx, sy, sz, mat, solid=False, fade=False, parent=".", yaw=0.0):
        mesh = self.box_mesh((sx, sy, sz))
        self.node(name, "MeshInstance3D", parent, (x, y, z), yaw_deg=yaw,
                  extra="mesh = %s\nsurface_material_override/0 = %s" % (mesh, mat), groups=["fade_occluder"] if fade else None)
        if solid:
            self.collide(name + "Shape", x, y, z, sx, sy, sz, yaw)

    def collide(self, name, x, y, z, sx, sy, sz, yaw=0.0):
        self.node(name, "CollisionShape3D", "Collision", (x, y, z), yaw_deg=yaw, extra="shape = %s" % self.box_shape((sx, sy, sz)))

    def cyl(self, name, x, y, z, radius, height, mat, solid=False, fade=False, radius_top=None):
        key = (radius, height, radius_top)
        if key not in self._cyl:
            self._cyl[key] = self.sub("CylinderMesh", "top_radius = %s\nbottom_radius = %s\nheight = %s\nradial_segments = 12\nrings = 1" % (
                radius if radius_top is None else radius_top, radius, height))
        self.node(name, "MeshInstance3D", ".", (x, y, z), extra="mesh = %s\nsurface_material_override/0 = %s" % (self._cyl[key], mat),
                  groups=["fade_occluder"] if fade else None)
        if solid:
            shape = self.sub("CylinderShape3D", "radius = %s\nheight = %s" % (radius, height))
            self.node(name + "Shape", "CollisionShape3D", "Collision", (x, y, z), extra="shape = %s" % shape)

    def ball(self, name, x, y, z, radius, mat):
        if radius not in self._sph:
            self._sph[radius] = self.sub("SphereMesh", "radius = %s\nheight = %s\nradial_segments = 10\nrings = 5" % (radius, radius * 2))
        self.node(name, "MeshInstance3D", ".", (x, y, z), extra="mesh = %s\nsurface_material_override/0 = %s" % (self._sph[radius], mat))

    def plane(self, name, x, y, z, sx, sz, mat, parent="."):
        """A floor-facing (up) plane."""
        key = ("y", sx, sz)
        if key not in self._planes:
            self._planes[key] = self.sub("PlaneMesh", "size = Vector2(%s, %s)" % (sx, sz))
        self.node(name, "MeshInstance3D", parent, (x, y, z), extra="mesh = %s\nsurface_material_override/0 = %s" % (self._planes[key], mat))

    def quad(self, name, x, y, z, w, h, mat, yaw=0.0, parent="."):
        """A vertical one-sided quad; at yaw 0 it faces +Z (toward the camera side); yaw 90 faces +X."""
        key = ("z", w, h)
        if key not in self._planes:
            self._planes[key] = self.sub("PlaneMesh", "size = Vector2(%s, %s)\norientation = 2" % (w, h))
        self.node(name, "MeshInstance3D", parent, (x, y, z), yaw_deg=yaw, extra="mesh = %s\nsurface_material_override/0 = %s" % (self._planes[key], mat))

    def text(self, name, text, x, y, z, yaw=0.0, size=0.012, color=(1.0, 0.95, 0.8), font=30):
        t = "Transform3D(%.4f, 0, %.4f, 0, 1, 0, %.4f, 0, %.4f, %s, %s, %s)" % (
            math.cos(math.radians(yaw)), math.sin(math.radians(yaw)), -math.sin(math.radians(yaw)), math.cos(math.radians(yaw)), x, y, z)
        self.nodes.append('[node name="%s" type="Label3D" parent="."]\ntransform = %s\ntext = "%s"\npixel_size = %s\nfont_size = %d\n'
                          'outline_size = 8\nmodulate = Color(%s, %s, %s, 1)\ntexture_filter = 0\n' % (name, t, text, size, font, color[0], color[1], color[2]))

    def neon(self, name, text, x, y, z, w, h, color, yaw=0.0, energy=1.5):
        """A neon sign slot: a glowing slab with a flat label until Ross's signage arrives."""
        self.box(name, x, y, z, w, h, 0.06, self.glow(color, energy), yaw=yaw)
        dx, dz = math.sin(math.radians(yaw)), math.cos(math.radians(yaw))
        self.text(name + "Text", text, x + dx * 0.05, y, z + dz * 0.05, yaw=yaw, size=0.011, color=(0.04, 0.04, 0.08), font=int(26 * min(h / 0.5, 1.4)))

    def omni(self, name, x, y, z, color, energy=1.6, rng=7.0):
        self.omni_count += 1
        self.node(name, "OmniLight3D", ".", (x, y, z), extra="light_color = Color(%s, %s, %s, 1)\nlight_energy = %s\nomni_range = %s" % (
            color[0], color[1], color[2], energy, rng))

    def wires(self, name, x0, z0, x1, z1, y, mat, bulbs=0, bulb_mat=None):
        """A string of lights: a thin wire box between two points at height y, with small emissive bulbs along it."""
        length = math.hypot(x1 - x0, z1 - z0)
        yaw = math.degrees(math.atan2(-(z1 - z0), x1 - x0))
        self.box(name, (x0 + x1) / 2.0, y, (z0 + z1) / 2.0, length, 0.04, 0.04, mat, yaw=yaw)
        for i in range(bulbs):
            f = (i + 0.5) / bulbs
            self.box("%sBulb%d" % (name, i), x0 + (x1 - x0) * f, y - 0.14, z0 + (z1 - z0) * f, 0.14, 0.18, 0.14, bulb_mat)

    def speaker(self, name, x, z, y=0.0, yaw=0.0, size=1.0, color=(0.2, 0.95, 0.85)):
        """A speaker stack / boombox (the market is loud and cheerful from the start: music, radios, arcade beeps are sound sources
        listed in data/slice/market.json "ambience"). Two glowing cones on a dark cabinet."""
        dx, dz = math.sin(math.radians(yaw)), math.cos(math.radians(yaw))
        self.box(name, x, y + 0.45 * size, z, 0.6 * size, 0.9 * size, 0.5 * size, self.lit((0.12, 0.12, 0.15)), solid=size >= 1.0, yaw=yaw)
        for i, cy in enumerate((0.28, 0.66)):
            self.box("%sCone%d" % (name, i), x + dx * 0.26 * size, y + cy * size, z + dz * 0.26 * size, 0.3 * size, 0.3 * size, 0.04, self.glow(color, 1.1), yaw=yaw)

    # ---------------------------------------------------------------- props (the old prop scenes, through placements)
    def inst(self, path):
        return self.ext_res("PackedScene", path)

    def door(self, name, pid, x, z, yaw=0):
        self.node(name, "", ".", (x, 0, z), yaw_deg=yaw, instance=self.inst("res://scenes/props/door.tscn"), extra='placement_id = "%s"' % pid)

    def pickup(self, name, pid, x, z, y=0.0):
        self.node(name, "", ".", (x, y, z), instance=self.inst("res://scenes/props/pickup.tscn"), extra='placement_id = "%s"' % pid)

    def crate(self, name, pid, x, z, yaw=0):
        self.node(name, "", ".", (x, 0, z), yaw_deg=yaw, instance=self.inst("res://scenes/props/crate.tscn"), extra='placement_id = "%s"' % pid)

    def npc(self, name, pid, x, z, face=(0, 1), y=0.0):
        self.node(name, "", ".", (x, y, z), yaw_deg=yaw_to(*face), instance=self.inst("res://scenes/actors/placed_npc.tscn"), extra='placement_id = "%s"' % pid)

    def spot(self, name, pid, x, z, y=0.0):
        self.node(name, "", ".", (x, y, z), instance=self.inst("res://scenes/props/scene_spot.tscn"), extra='placement_id = "%s"' % pid)

    def spawns(self, markers):
        self.node("Spawns", "Node3D")
        for name, (x, z), face in markers:
            self.node(name, "Marker3D", "Spawns", (x, 0, z), yaw_deg=yaw_to(*face))

    def flag_visible(self, name, show_if, x, y, z, hide_if=None):
        script = self.ext_res("Script", "res://scripts/field/flag_visible.gd")
        extra = 'script = %s\nshow_if = "%s"' % (script, show_if.replace('"', '\\"'))
        if hide_if:
            extra += '\nhide_if = "%s"' % hide_if.replace('"', '\\"')
        self.node(name, "Node3D", ".", (x, y, z), extra=extra)


# ======================================================================= the room shell
def start(room_id, title, w, d, yaw, cam_center, cam_size, wall_h, floor_tile, wall_tile, floor_tint=(1, 1, 1), wall_tint=(1, 1, 1),
          moon=(0.55, 0.65, 0.95), moon_energy=0.75):
    r = M(room_id, title, w, d)
    bounds_script = r.ext_res("Script", "res://scripts/field/camera_bounds.gd")
    cam_script = r.ext_res("Script", "res://scripts/field/diorama_camera.gd")
    env = r.sub("Environment", "background_mode = 1\nbackground_color = Color(0.09, 0.1, 0.17, 1)\nambient_light_source = 2\n"
                "ambient_light_color = Color(0.62, 0.66, 0.9, 1)\nambient_light_energy = 0.9")
    # A PLAIN level: Main wraps it in an ActionRoom (the one slice room script). No FieldRoom script, no RoomLook (the
    # ActionRoom makes its own), no player scene.
    r.nodes.append('[node name="%s" type="Node3D"]\n' % title)
    r.node("WorldEnvironment", "WorldEnvironment", extra="environment = %s" % env)
    r.node("Moon", "DirectionalLight3D", extra="light_color = Color(%s, %s, %s, 1)\nlight_energy = %s\nshadow_enabled = true\n"
           "directional_shadow_max_distance = 40.0\ntransform = %s" % (
               moon[0], moon[1], moon[2], moon_energy, aim_transform((w / 2.0, 9, d / 2.0), (0.45, -0.8, -0.5))))
    r.node("CameraBounds", "Node3D", pos=(cam_center[0], 0, cam_center[1]),
           extra="script = %s\nsize = Vector3(%s, 0, %s)" % (bounds_script, cam_size[0], cam_size[1]))
    r.node("CameraRig", "Node3D", extra="script = %s\npitch_deg = 42.0\nyaw_deg = %s\nfov_deg = 30.0\ndistance = 11.0" % (cam_script, yaw))
    r.node("Collision", "StaticBody3D")
    r.plane("Floor", w / 2.0, 0, d / 2.0, w, d, r.tile(floor_tile, (w / TILE_M * 128.0 / ATLAS[floor_tile]["rect"][2], d / TILE_M * 128.0 / ATLAS[floor_tile]["rect"][3]), floor_tint))
    r.collide("FloorShape", w / 2.0, -0.1, d / 2.0, w + 2, 0.2, d + 2)
    r.wall_h = wall_h
    r.wall_tile = wall_tile
    r.wall_tint = wall_tint
    r.wall_mat = r.lit((wall_tint[0] * 0.5, wall_tint[1] * 0.5, wall_tint[2] * 0.5))     # the plain edge / top of a wall slab
    r.node("Walls", "Node3D")
    return r


def wall_face(r, name, x0, x1, yaw, base, tile=None, tint=None, y0=0.0, y1=None):
    """A city-tile face on a wall, between x0 and x1 along the wall. yaw 0 = the north wall (faces +Z) at z = base; yaw 90 = the
    west wall (faces +X) at x = base."""
    tile = tile or r.wall_tile
    tint = tint or r.wall_tint
    y1 = r.wall_h if y1 is None else y1
    tw, th = tile_world_size(tile)
    length = x1 - x0
    mat = r.tile(tile, (length / tw, (y1 - y0) / th), tint, offset=(x0 / tw, 0.0))
    mid = (x0 + x1) / 2.0
    if yaw == 0:
        r.quad(name, mid, (y0 + y1) / 2.0, base + 0.012, length, y1 - y0, mat)
    else:
        r.quad(name, base + 0.012, (y0 + y1) / 2.0, mid, length, y1 - y0, mat, yaw=90)


def walls(r, n_segments=None, w_segments=None, south_gaps=None, east=True):
    """N wall as slabs (segments of (x0, x1)) with the tile on the room side, W wall full height, plus collision on every side."""
    h = r.wall_h
    for i, (x0, x1) in enumerate(n_segments or [(0, r.w)]):
        r.box("WallN%d" % i, (x0 + x1) / 2.0, h / 2.0, -0.15, x1 - x0, h, 0.3, r.wall_mat, parent="Walls")
        wall_face(r, "WallFaceN%d" % i, x0, x1, 0, 0.0)
        r.collide("WallNShape%d" % i, (x0 + x1) / 2.0, 1.5, -0.1, x1 - x0, 3, 0.2)
    for i, (z0, z1) in enumerate(w_segments or [(0, r.d)]):
        r.box("WallW%d" % i, -0.15, h / 2.0, (z0 + z1) / 2.0, 0.3, h, z1 - z0, r.wall_mat, parent="Walls")
        wall_face(r, "WallFaceW%d" % i, z0, z1, 90, 0.0)
        r.collide("WallWShape%d" % i, -0.1, 1.5, (z0 + z1) / 2.0, 0.2, 3, z1 - z0)
    gaps = south_gaps or []
    edges = [0.0] + [v for g in gaps for v in g] + [r.w]
    for i in range(0, len(edges), 2):
        if edges[i + 1] - edges[i] > 0.01:
            r.collide("FrontBarrier%d" % i, (edges[i] + edges[i + 1]) / 2.0, 1.5, r.d + 0.1, edges[i + 1] - edges[i], 3, 0.2)
    if east:
        r.collide("RightBarrier", r.w + 0.1, 1.5, r.d / 2.0, 0.2, 3, r.d)


def finish(r, name):
    r.write(name)


# ======================================================================= M1  Tarp Square (market_square)
def square():
    r = start("market_square", "MarketSquare", 22, 12, 30, (11, 5.5), (12, 6), 4.5, "floor_concrete_cracked_dark", "rust_riveted_plates_tall",
              floor_tint=(0.85, 0.86, 0.95), wall_tint=(0.9, 0.88, 0.95))
    walls(r, n_segments=[(0, 11.5), (13.5, 22)], south_gaps=[])
    metal = r.lit((0.55, 0.58, 0.64))
    wire = r.lit((0.12, 0.12, 0.14))
    amber = r.glow((1.0, 0.8, 0.42), 1.5)
    pink = (1.0, 0.3, 0.62)
    teal = (0.2, 0.95, 0.85)
    # ---- the alley alcove between Corner Shop and Forge: floor, back wall, side walls, chalk lantern, stash crate
    r.plane("AlleyFloor", 12.5, 0.005, -1.5, 2, 3, r.tile("floor_concrete_plain_trim_top", (1, 1.5), (0.6, 0.6, 0.66)))
    r.collide("AlleyFloorShape", 12.5, -0.1, -1.5, 2, 0.2, 3)
    r.box("AlleyBack", 12.5, 2.25, -3.15, 2, 4.5, 0.3, r.wall_mat, parent="Walls")
    r.quad("AlleyBackFace", 12.5, 2.25, -3.0, 2, 4.5, r.tile("steel_plate_riveted_grey", (1, 2.25), (0.6, 0.6, 0.65)))
    r.collide("AlleyBackShape", 12.5, 1.5, -3.1, 2, 3, 0.2)
    for side, x in (("A", 11.35), ("B", 13.65)):
        r.box("AlleySide" + side, x, 2.25, -1.5, 0.3, 4.5, 3.0, r.wall_mat, parent="Walls")
        r.collide("AlleySideShape" + side, x + (-0.05 if side == "A" else 0.05), 1.5, -1.5, 0.2, 3, 3.0)
    r.box("ChalkLantern", 12.5, 1.4, -2.95, 0.7, 0.9, 0.03, r.glow((0.95, 0.95, 0.85), 0.7))
    r.box("TrashCanA", 11.8, 0.4, -2.2, 0.5, 0.8, 0.5, r.lit((0.35, 0.37, 0.4)), solid=True)
    r.box("TrashCanB", 13.2, 0.4, -2.55, 0.5, 0.8, 0.5, r.lit((0.35, 0.37, 0.4)), solid=True)
    r.crate("AlleyStash", "mk_sq_alley_stash", 12.5, -2.3)
    # ---- shopfront slabs on the facade, awnings and neon signs (slots for Ross's signage)
    def shopfront(name, x0, x1, tint):
        r.box(name, (x0 + x1) / 2.0, 1.9, 0.06, x1 - x0, 3.8, 0.12, r.lit(tint))
        r.box(name + "Awning", (x0 + x1) / 2.0, 3.0, 0.45, x1 - x0 + 0.3, 0.12, 0.9, r.lit((tint[0] * 0.8, tint[1] * 0.8, tint[2] * 0.8)), fade=False)
    shopfront("FrontDispatch", 2.0, 6.0, (0.7, 0.55, 0.3))
    shopfront("FrontCorner", 8.0, 10.5, (0.38, 0.58, 0.5))
    shopfront("FrontForge", 14.5, 17.5, (0.4, 0.48, 0.7))
    r.neon("SignDispatch", "DISPATCH", 4.0, 3.55, 0.14, 1.9, 0.38, (1.0, 0.72, 0.25))
    r.neon("SignCorner", "24H CORNER", 9.25, 3.55, 0.14, 1.9, 0.38, teal)
    r.neon("SignForge", "FORGE", 16.0, 3.55, 0.14, 1.5, 0.38, pink)
    r.box("SignHideout", 0.14, 3.3, 4.0, 0.06, 0.34, 1.3, r.glow((1.0, 0.55, 0.3), 1.3))
    r.text("SignHideoutText", "HOME", 0.2, 3.3, 4.0, yaw=90, size=0.011, color=(0.05, 0.04, 0.08))
    r.quad("SignKatakana", 19.4, 4.1, 0.13, 1.6, 0.8, r.picture("sign_garbled_green_katakana"))
    # ---- the gate arch to Gate 4 with the propaganda screen above it
    r.box("ArchPostA", 18.55, 1.7, 0.3, 0.3, 3.4, 0.3, metal, solid=True)
    r.box("ArchPostB", 21.45, 1.7, 0.3, 0.3, 3.4, 0.3, metal, solid=True)
    r.box("ArchLintel", 20.0, 3.5, 0.3, 3.4, 0.4, 0.3, metal)
    r.box("ArchLamp", 20.0, 3.1, 0.35, 0.4, 0.2, 0.1, r.glow((0.5, 0.75, 1.0), 1.2))
    r.box("ScreenFrame", 20.0, 4.0, 0.12, 1.8, 1.2, 0.1, r.lit((0.18, 0.2, 0.24)))
    r.quad("PropagandaScreen", 20.0, 4.0, 0.2, 1.6, 1.0, r.picture("wall_screen_blue_wide"))
    r.box("MemoTicker", 20.0, 3.55, 0.19, 1.5, 0.16, 0.03, r.glow((0.4, 1.0, 0.5), 0.9))
    r.spot("ScreenSpot", "mk_sq_screen", 20.0, 2.2)
    # ---- the stairs down to the Wharf (south edge): rails and a dark strip
    r.box("StairsStrip", 10.5, 0.03, 11.4, 3.0, 0.04, 1.2, r.lit((0.16, 0.18, 0.26)))
    r.box("StairRailA", 8.9, 0.5, 11.8, 0.12, 1.0, 0.5, metal, solid=True)
    r.box("StairRailB", 12.1, 0.5, 11.8, 0.12, 1.0, 0.5, metal, solid=True)
    # ---- Grandma Ume's window above the Corner Shop: sill, ledge, step crate, phone rack on a clothesline
    r.box("UmeWindow", 7.0, 2.9, 0.14, 1.7, 1.0, 0.06, r.glow((1.0, 0.82, 0.5), 1.2))
    r.box("UmeSill", 7.0, 2.35, 0.3, 2.0, 0.1, 0.5, r.lit((0.5, 0.42, 0.34)))
    r.box("Balcony", 7.0, 0.9, 0.3, 2.0, 1.8, 0.6, r.lit((0.5, 0.42, 0.34)), solid=True)
    r.box("CrateStep", 6.5, 0.45, 1.2, 0.9, 0.9, 0.9, r.lit((0.8, 0.5, 0.35)), solid=True)
    r.wires("PhoneLine", 5.2, 0.5, 8.6, 0.5, 2.55, wire)
    for i, x in enumerate((5.8, 6.4, 7.0, 7.6, 8.2)):
        r.box("PhoneCharging%d" % i, x, 2.2, 0.5, 0.22, 0.36, 0.04, r.glow((0.5, 1.0, 0.9) if i % 2 else (1.0, 0.45, 0.7), 1.1))
        r.box("PhoneCord%d" % i, x, 1.4, 0.5, 0.02, 1.7, 0.02, wire)
    r.box("PricePlank", 5.6, 1.1, 0.15, 0.8, 0.4, 0.04, r.lit((0.62, 0.55, 0.4)))
    r.text("PriceText", "1 BAR = 10 MIN", 5.6, 1.1, 0.19, size=0.007, color=(0.1, 0.1, 0.1), font=26)
    r.spot("WindowLedge", "mk_sq_window_ledge", 6.7, 0.3, y=1.8)
    r.pickup("WindowReward", "mk_sq_window_reward", 7.4, 0.3, y=1.8)
    r.spot("PhoneRackSpot", "mk_sq_phone_rack", 6.2, 2.4)
    # ---- the tarp pole (fades when Red is behind it), bets chalkboard, memo board, notice
    r.box("TarpPole", 11, 2.0, 6, 0.25, 4.0, 0.25, r.lit((0.55, 0.45, 0.35)), solid=True, fade=True)
    r.box("PoleLights", 11, 3.9, 6, 0.5, 0.5, 0.5, amber)
    r.omni("PoleLamp", 11, 3.4, 6, (1.0, 0.72, 0.4), 4.0, 8.0)
    r.spot("TarpPoleSpot", "mk_sq_tarp_pole", 11.0, 6.9)
    r.box("BetsBoard", 13.6, 0.9, 5.4, 1.2, 1.0, 0.1, r.lit((0.2, 0.25, 0.22)), solid=True)
    r.text("BetsText", "SCREEN GLITCH BY 10?", 13.6, 1.1, 5.46, size=0.006, color=(0.9, 0.95, 0.85), font=26)
    r.spot("BetsSpot", "mk_sq_bets_board", 13.6, 6.1)
    r.box("MemoBoard", 0.1, 1.5, 7.9, 0.1, 1.2, 1.6, r.lit((0.55, 0.6, 0.7)))
    r.spot("MemoSpot", "mk_sq_memo_board", 0.9, 7.9)
    # ---- the stalls: noodle cart A (Pop's), dumpling cart B, cable-and-tape stall; canopies fade out when Red is behind them
    cart = r.lit((0.62, 0.42, 0.3))
    steel = r.lit((0.7, 0.72, 0.76))
    tarp_a = r.lit((0.78, 0.35, 0.4))
    tarp_b = r.lit((0.3, 0.55, 0.6))
    tarp_c = r.lit((0.75, 0.62, 0.3))
    steam = r.glow((0.9, 0.95, 1.0), 0.6)

    def stall(prefix, cx, cz, tarp, pot=True, w=2.4):
        r.box(prefix + "Cart", cx, 0.5, cz, w, 1.0, 1.2, cart, solid=True)
        r.box(prefix + "Counter", cx, 1.04, cz + 0.05, w + 0.1, 0.08, 1.3, steel)
        if pot:
            r.cyl(prefix + "Pot", cx - 0.5, 1.35, cz - 0.1, 0.32, 0.5, steel)
            r.ball(prefix + "Steam", cx - 0.5, 1.95, cz - 0.1, 0.22, steam)
        for sx in (-w / 2.0 + 0.05, w / 2.0 - 0.05):
            r.box("%sPole%s" % (prefix, "L" if sx < 0 else "R"), cx + sx, 1.2, cz - 0.55, 0.06, 2.4, 0.06, steel, fade=True)
        r.box(prefix + "Canopy", cx, 2.45, cz - 0.1, w + 0.5, 0.08, 1.7, tarp, fade=True)

    stall("Noodle", 15, 8.5, tarp_a)
    for i, x in enumerate((14, 15.2, 16.4)):
        r.cyl("NoodleStool%d" % i, x, 0.25, 9.6, 0.2, 0.5, r.lit((0.4, 0.3, 0.3)), solid=True)
    r.box("NoodleLantern", 15.0, 0.55, 9.12, 0.3, 0.4, 0.04, r.glow((0.95, 0.95, 0.85), 0.8))
    stall("Dumpling", 4, 8.5, tarp_b)
    stall("Tape", 18.5, 6.5, tarp_c, pot=False, w=2.0)
    for i, x in enumerate((17.9, 18.4, 18.9)):
        r.cyl("TapeSpool%d" % i, x, 1.25, 6.45, 0.17, 0.3, r.lit((0.2 + 0.25 * i, 0.4, 0.8 - 0.2 * i)))
    r.speaker("TapeBoombox", 19.6, 6.0, y=1.04, size=0.5, yaw=-20)
    r.speaker("NoodleRadio", 16.2, 8.1, y=1.04, size=0.45, yaw=10, color=(1.0, 0.45, 0.7))
    r.speaker("StackA", 21.0, 9.6, size=1.0, yaw=-30, color=(1.0, 0.45, 0.7))
    r.speaker("StackB", 1.2, 10.4, size=1.0, yaw=30)
    # ---- string lights over the back half only, neon wash, skyline beyond the roofs with the Signals tower and dish
    bulbs = r.glow((1.0, 0.85, 0.5), 1.4)
    r.wires("StringA", 1.0, 3.2, 21.0, 2.6, 5.0, wire, bulbs=10, bulb_mat=bulbs)
    r.wires("StringB", 1.0, 1.4, 21.0, 4.4, 5.3, wire, bulbs=10, bulb_mat=r.glow((1.0, 0.5, 0.7), 1.3))
    r.wires("StringC", 11.0, 6.0, 11.0, 0.5, 5.0, wire, bulbs=4, bulb_mat=bulbs)
    r.omni("NeonPink", 16.0, 3.0, 1.6, (1.0, 0.3, 0.65), 2.2, 7.0)
    r.omni("NeonTeal", 9.0, 3.0, 1.6, (0.25, 1.0, 0.9), 1.8, 7.0)
    r.omni("WindowWarm", 7.0, 2.5, 1.4, (1.0, 0.78, 0.45), 1.8, 5.5)
    r.omni("ArchBlue", 20.0, 3.0, 2.0, (0.5, 0.7, 1.0), 1.6, 6.0)
    sky = r.lit((0.07, 0.08, 0.13))
    for i, (x, z, sx, sy, sz) in enumerate(((3, -9, 5, 11, 4), (10, -12, 6, 15, 4), (18, -10, 5, 9, 4), (26, -14, 6, 17, 4), (-6, -10, 5, 13, 4), (30, -8, 4, 8, 4))):
        r.box("Skyline%d" % i, x, sy / 2.0, z, sx, sy, sz, sky)
    r.box("TowerMast", 14, 12, -20, 1.6, 24, 1.6, sky)
    r.cyl("TowerDish", 14, 24.5, -19.0, 2.4, 0.35, sky)
    r.ball("TowerBeacon", 14, 25.4, -20, 0.35, r.glow((1.0, 0.15, 0.1), 2.0))
    # ---- doors
    r.door("DoorDispatch", "mk_sq_to_dispatch", 4.0, 0)
    r.door("DoorCorner", "mk_sq_to_corner", 8.5, 0)
    r.door("DoorForge", "mk_sq_to_forge", 16.0, 0)
    r.door("DoorGate", "mk_sq_to_gate", 20.0, 0)
    r.door("DoorHideout", "mk_sq_to_hideout", 0, 4.0, yaw=90)
    r.door("DoorWharf", "mk_sq_to_wharf", 10.5, 12.0, yaw=180)
    # ---- people (about 14 here: Pop, the dumpling cook, the tape keeper, the Odds Man, the neighbour, Ume, four shoppers, two wolves)
    r.npc("Pop", "mk_sq_pop", 15.0, 7.4, face=(0, 1))
    r.npc("DumplingCook", "mk_sq_dumpling", 4.0, 7.4, face=(0, 1))
    r.npc("TapeKeeper", "mk_sq_tape", 18.5, 5.5, face=(0, 1))
    r.npc("OddsMan", "mk_sq_odds", 12.0, 6.5, face=(0, 1))
    r.npc("Neighbor", "mk_sq_neighbor", 2.0, 6.0, face=(-1, -0.3))
    r.npc("GrandmaUme", "mk_sq_ume", 7.0, -0.1, face=(0, 1), y=1.95)
    r.npc("ShopperA", "mk_sq_shopper_a", 11.2, 4.4, face=(1, 0.3))
    r.npc("ShopperB", "mk_sq_shopper_b", 13.0, 3.6, face=(-1, 0.5))
    r.npc("ShopperC", "mk_sq_shopper_c", 7.0, 5.6, face=(0, 1))
    r.npc("ShopperD", "mk_sq_shopper_d", 19.5, 9.4, face=(-1, 0))
    r.npc("PatrolWolfA", "mk_sq_wolf_a", 5.4, 10.5, face=(1, -0.3))
    r.npc("PatrolWolfB", "mk_sq_wolf_b", 6.6, 10.5, face=(1, -0.3))
    r.spawns([("from_hideout", (1.2, 4.0), (1, 0)), ("from_dispatch", (4.0, 1.2), (0, 1)), ("from_corner", (8.5, 1.2), (0, 1)),
              ("from_forge", (16.0, 1.2), (0, 1)), ("from_gate", (20.0, 1.5), (0, 1)), ("from_wharf", (10.5, 10.8), (0, -1))])
    finish(r, "market_square.tscn")


# ======================================================================= M2  The Wharf (market_wharf)
def wharf():
    r = start("market_wharf", "MarketWharf", 24, 9, 25, (12, 5.0), (14, 4), 5.0, "floor_rust_plate_quad", "rust_streaked_plate_tall",
              floor_tint=(0.82, 0.8, 0.9), wall_tint=(0.85, 0.85, 0.95))
    walls(r, n_segments=[(0, 10.5), (13.5, 24)], south_gaps=[(20, 23)])
    metal = r.lit((0.55, 0.58, 0.64))
    wire = r.lit((0.12, 0.12, 0.14))
    r.box("StairsUp", 12.0, 1.5, -0.05, 3.0, 3.0, 0.1, r.lit((0.13, 0.15, 0.22)))
    # ---- pier and oily water (the water is a dark plane; a real shader comes with Ross's art)
    r.plane("Water", 12, -0.35, 11.5, 30, 5, r.tile("floor_concrete_cracked_dark", (10, 2), (0.1, 0.18, 0.3)))
    r.plane("PierFloor", 21.5, 0.0, 11.0, 3, 4, r.tile("floor_diamond_plate_rust", (1.5, 2), (0.8, 0.7, 0.6)))
    r.collide("PierShape", 21.5, -0.1, 11.0, 3, 0.2, 4)
    r.collide("PierSideA", 19.9, 1.5, 11.0, 0.2, 3, 4)
    r.collide("PierSideB", 23.1, 1.5, 11.0, 0.2, 3, 4)
    r.collide("PierEnd", 21.5, 1.5, 13.1, 3.4, 3, 0.2)
    r.box("PierPostA", 20.1, 0.5, 13.0, 0.2, 1.0, 0.2, r.lit((0.4, 0.3, 0.22)))
    r.box("PierPostB", 22.9, 0.5, 13.0, 0.2, 1.0, 0.2, r.lit((0.4, 0.3, 0.22)))
    # ---- warehouse fronts, doors and signs: Tuesday's Repair (west), Bootleg Arcade (east)
    r.box("FrontRepair", 5.0, 2.0, 0.06, 3.2, 4.0, 0.12, r.lit((0.62, 0.5, 0.36)))
    r.box("FrontArcade", 19.0, 2.0, 0.06, 3.6, 4.0, 0.12, r.lit((0.55, 0.38, 0.5)))
    r.neon("SignRepair", "TUESDAY'S REPAIR", 5.0, 3.5, 0.14, 2.8, 0.4, (0.25, 0.95, 0.85))
    r.neon("SignArcade", "BOOTLEG ARCADE", 19.0, 3.5, 0.14, 3.0, 0.4, (1.0, 0.35, 0.7))
    r.quad("SignKatakana", 19.0, 4.35, 0.14, 1.6, 0.8, r.picture("sign_garbled_green_katakana"))
    r.box("TidingsScreenFrame", 14.0, 3.0, 0.1, 1.8, 1.2, 0.1, r.lit((0.18, 0.2, 0.24)))
    r.quad("PropagandaScreen", 14.0, 3.0, 0.17, 1.6, 1.0, r.picture("wall_screen_blue_panel_orange"))
    r.box("Moustache", 14.0, 2.85, 0.19, 0.6, 0.1, 0.02, r.lit((0.05, 0.05, 0.05)))
    r.spot("ScreenSpot", "mk_wf_screen", 14.0, 1.4)
    r.box("TideBoard", 8.6, 1.5, 0.1, 1.2, 0.9, 0.08, r.lit((0.2, 0.28, 0.35)))
    r.spot("TideSpot", "mk_wf_tide_board", 8.6, 0.9)
    r.door("DoorSquare", "mk_wf_to_square", 12.0, 0.0)
    r.door("DoorRepair", "mk_wf_to_repair", 5.0, 0.0)
    r.door("DoorArcade", "mk_wf_to_arcade", 19.0, 0.0)
    # ---- container stack and crane (west), the crate stack for the town's jump lesson
    r.box("ContainerA", 1.4, 1.2, 1.6, 2.4, 2.4, 1.4, r.lit((0.7, 0.3, 0.25)), solid=True, fade=True)
    r.box("ContainerB", 1.4, 1.2, 4.2, 2.4, 2.4, 1.4, r.lit((0.3, 0.45, 0.65)), solid=True, fade=True)
    r.box("CraneMast", 0.6, 3.0, 6.9, 0.35, 6.0, 0.35, r.lit((0.85, 0.7, 0.25)), solid=True, fade=True)
    r.box("CraneArm", 3.2, 6.0, 6.9, 5.6, 0.3, 0.3, r.lit((0.85, 0.7, 0.25)))
    r.spot("CraneSpot", "mk_wf_crane", 1.4, 7.9)
    r.box("CrateA", 3.2, 0.45, 6.0, 0.9, 0.9, 0.9, r.lit((0.8, 0.5, 0.35)), solid=True)
    r.box("CrateBase", 2.0, 0.45, 6.0, 0.9, 0.9, 0.9, r.lit((0.7, 0.45, 0.32)), solid=True)
    r.box("CrateB", 2.0, 1.35, 6.0, 0.9, 0.9, 0.9, r.lit((0.8, 0.5, 0.35)), solid=True)
    r.pickup("CratePickup", "mk_wf_crate_top", 2.0, 6.0, y=1.8)
    r.pickup("PierPickup", "mk_wf_pier_end", 21.5, 12.5)
    # ---- the scrap-drone derby: tyre ring, chalk oval, three little drones, the judge's crate
    tyre = r.lit((0.1, 0.1, 0.12))
    r.plane("ChalkOval", 16, 0.012, 5.5, 8, 4, r.tile("floor_hazard_stripe_yellow_band", (4, 2), (0.7, 0.7, 0.7)))
    for i in range(18):
        a = math.tau * i / 18
        r.cyl("Tyre%d" % i, 16 + 4.0 * math.cos(a), 0.18, 5.5 + 2.0 * math.sin(a), 0.22, 0.36, tyre)
    for i, (dx, dz) in enumerate(((13.2, 4.4), (17.0, 3.7), (18.6, 6.8))):
        r.box("Drone%d" % i, dx, 0.9, dz, 0.4, 0.14, 0.4, r.lit((0.7 - 0.2 * i, 0.5, 0.3 + 0.2 * i)))
        r.box("DroneLight%d" % i, dx, 0.82, dz, 0.12, 0.05, 0.12, r.glow((0.2, 0.95, 0.9), 1.5))
    r.box("JudgeCrate", 11, 0.45, 6, 0.9, 0.9, 0.9, r.lit((0.75, 0.5, 0.35)), solid=True)
    r.spot("ResultsSpot", "mk_wf_results", 11.0, 7.0)
    # ---- the late noodle cart at the pier root
    r.box("LateCart", 21.5, 0.5, 7.0, 2.4, 1.0, 1.2, r.lit((0.62, 0.42, 0.3)), solid=True)
    r.box("LateCounter", 21.5, 1.04, 7.05, 2.5, 0.08, 1.3, r.lit((0.7, 0.72, 0.76)))
    r.cyl("LatePot", 21.0, 1.35, 6.9, 0.32, 0.5, r.lit((0.7, 0.72, 0.76)))
    r.ball("LateSteam", 21.0, 1.95, 6.9, 0.22, r.glow((0.9, 0.95, 1.0), 0.6))
    r.box("LateCanopy", 21.5, 2.45, 6.9, 2.9, 0.08, 1.7, r.lit((0.78, 0.35, 0.4)), fade=True)
    for sx in (20.35, 22.65):
        r.box("LatePole%s" % ("L" if sx < 21.5 else "R"), sx, 1.2, 6.45, 0.06, 2.4, 0.06, r.lit((0.7, 0.72, 0.76)), fade=True)
    # ---- lantern-bulb strings (back half), a warm wash, a teal wash at the repair shop
    bulbs = r.glow((1.0, 0.8, 0.45), 1.4)
    r.wires("StringA", 2.0, 1.8, 22.0, 1.8, 5.2, wire, bulbs=12, bulb_mat=bulbs)
    r.wires("StringB", 4.0, 3.2, 20.0, 3.2, 5.5, wire, bulbs=9, bulb_mat=r.glow((1.0, 0.45, 0.7), 1.3))
    r.speaker("TrackStackA", 11.4, 3.2, size=1.0, yaw=20)
    r.speaker("TrackStackB", 21.4, 3.0, size=1.0, yaw=-20, color=(1.0, 0.45, 0.7))
    r.speaker("LateRadio", 20.6, 7.7, y=1.04, size=0.45, yaw=-10)
    r.omni("WarmWash", 15.0, 3.5, 3.0, (1.0, 0.75, 0.45), 3.0, 9.0)
    r.omni("RepairTeal", 5.0, 3.0, 2.0, (0.3, 1.0, 0.9), 2.0, 6.0)
    r.omni("ArcadePink", 19.0, 3.0, 2.0, (1.0, 0.35, 0.7), 2.2, 6.0)
    # ---- people (about 8)
    r.npc("Juno", "mk_wf_juno", 12.5, 8.2, face=(1, -0.5))
    r.npc("DroneKidA", "mk_wf_kid_a", 19.5, 8.2, face=(-1, -0.5))
    r.npc("DroneKidB", "mk_wf_kid_b", 16.0, 2.8, face=(0, 1))
    r.npc("RaceJudge", "mk_wf_judge", 11.0, 6.0, face=(1, 0), y=0.9)
    r.npc("Pell", "mk_wf_pell", 9.0, 3.0, face=(1, 0.3))
    r.npc("LateCook", "mk_wf_late_cook", 21.5, 6.0, face=(0, 1))
    r.npc("Fisher", "mk_wf_fisher", 22.4, 11.6, face=(0, 1))
    r.spawns([("from_square", (12.0, 1.5), (0, 1)), ("from_repair", (5.0, 1.2), (0, 1)), ("from_arcade", (19.0, 1.2), (0, 1))])
    finish(r, "market_wharf.tscn")


# ======================================================================= M3  Gate 4 (market_gate)
def gate():
    r = start("market_gate", "MarketGate", 14, 9, 30, (7, 4.5), (4, 2), 4.0, "floor_concrete_hazard_stripe_a", "steel_plate_riveted_grey",
              floor_tint=(0.7, 0.75, 0.85), wall_tint=(0.7, 0.78, 0.95), moon=(0.5, 0.62, 1.0), moon_energy=0.7)
    walls(r, n_segments=[(0, 8.5), (11.5, 14)], south_gaps=[(6, 9)])
    metal = r.lit((0.55, 0.6, 0.68))
    r.box("RoadOpening", 10.0, 1.5, -0.05, 3.0, 3.0, 0.1, r.lit((0.1, 0.12, 0.18)))
    r.box("BarrierPostA", 8.4, 0.7, 0.35, 0.3, 1.4, 0.3, metal, solid=True)
    r.box("BarrierPostB", 11.6, 0.7, 0.35, 0.3, 1.4, 0.3, metal)
    # the boom arm lifts (swings up) once the main job is taken (flag job_main_taken)
    r.node("BarrierArm", "", ".", (8.55, 1.15, 0.35), instance=r.inst("res://scenes/props/flag_pose.tscn"),
           extra='when = "{\\"flag\\": \\"job_main_taken\\"}"\npose_degrees = Vector3(0, 0, 80)')
    r.box("ArmBox", 1.5, 0, 0, 3.0, 0.15, 0.15, r.lit((0.9, 0.3, 0.25)), parent="BarrierArm")
    r.box("Booth", 5.0, 1.25, 2.0, 2.0, 2.5, 2.0, r.lit((0.45, 0.55, 0.7)), solid=True, fade=True)
    r.box("BoothWindow", 5.0, 1.7, 3.02, 1.2, 0.5, 0.04, r.glow((0.5, 0.85, 1.0), 0.9))
    r.box("AppealsSlot", 5.0, 1.0, 3.03, 0.6, 0.12, 0.05, r.glow((1.0, 0.82, 0.45), 1.2))
    r.text("AppealsText", "APPEALS", 5.0, 0.8, 3.05, size=0.008, color=(1.0, 0.9, 0.5), font=28)
    r.spot("AppealsSpot", "mk_gt_appeals_slot", 5.0, 3.6)
    r.crate("Bin", "mk_gt_bin", 3.0, 0.9)
    # Kasp's posters (chalked moustaches) and a searchlight
    r.quad("PosterA", 12.8, 1.9, 0.08, 0.9, 1.2, r.lit((0.8, 0.75, 0.6)))
    r.quad("PosterB", 2.2, 1.9, 0.08, 0.9, 1.2, r.lit((0.8, 0.75, 0.6)))
    r.box("ChalkMoustacheA", 12.8, 1.7, 0.1, 0.5, 0.08, 0.02, r.lit((0.9, 0.9, 0.9)))
    r.box("ChalkMoustacheB", 2.2, 1.7, 0.1, 0.5, 0.08, 0.02, r.lit((0.9, 0.9, 0.9)))
    r.text("PosterText", "QUIET HOURS SAVE LIVES", 7.0, 2.7, 0.1, size=0.012, color=(0.9, 0.85, 0.6), font=30)
    r.spot("PosterSpot", "mk_gt_poster", 12.8, 1.0)
    r.quad("ChikaEmblem", 10.0, 3.35, 0.1, 0.9, 1.4, r.picture("sign_chikagate_emblem_plate"))
    r.quad("KeypadPanel", 7.5, 1.4, 0.1, 0.5, 0.9, r.picture("terminal_teal_keypad"))
    r.node("Searchlight", "SpotLight3D", ".", extra="transform = %s\nlight_color = Color(0.85, 0.92, 1, 1)\nlight_energy = 5.0\nspot_range = 12.0\nspot_angle = 28.0" % aim_transform((11.5, 3.6, 4.5), (-3.5, -3.6, -2.5)))
    r.omni("BoothGlow", 5.0, 2.6, 3.2, (0.5, 0.8, 1.0), 2.0, 6.0)
    r.omni("RoadRed", 10.0, 2.5, 1.0, (1.0, 0.3, 0.25), 1.2, 5.0)
    r.door("DoorSquare", "mk_gt_to_square", 7.5, 9.0, yaw=180)
    r.door("DoorJunkyard", "mk_gt_to_junk", 10.0, 0.0)
    r.npc("GruntA", "mk_gt_grunt_a", 9.0, 2.0, face=(0, 1))
    r.npc("GruntB", "mk_gt_grunt_b", 11.0, 2.0, face=(0, 1))
    r.npc("LineA", "mk_gt_line_a", 7.0, 6.0, face=(0, -1))
    r.npc("LineB", "mk_gt_line_b", 8.2, 6.0, face=(0, -1))
    r.npc("LineC", "mk_gt_line_c", 9.4, 6.0, face=(0, -1))
    r.spawns([("from_square", (7.5, 7.8), (0, -1)), ("from_junk", (10.0, 1.5), (0, 1))])
    finish(r, "market_gate.tscn")


# ======================================================================= interiors
def interior(room_id, title, w, d, floor_tile, wall_tile, floor_tint, wall_tint, glow_color=(1.0, 0.8, 0.5), side_wall_tile=None):
    r = start(room_id, title, w, d, 45, (w / 2.0, d / 2.0), (0, 0), 3.0, floor_tile, wall_tile, floor_tint, wall_tint)
    walls(r, south_gaps=[])
    r.omni("RoomLight", w / 2.0, 2.4, d / 2.0 - 0.5, glow_color, 2.4, max(w, d) + 2.0)
    return r


def hideout():
    r = interior("market_hideout", "MarketHideout", 7, 5, "floor_plate_diamond_cross_b", "rust_panel_strips_riveted",
                 (0.75, 0.62, 0.55), (0.85, 0.7, 0.65), glow_color=(1.0, 0.72, 0.5))
    metal = r.lit((0.55, 0.58, 0.64))
    jacket = r.lit((0.45, 0.12, 0.14))       # oxblood: her jacket
    # bunk (west wall), sticker wall, shelf with the photo, flight charts, pantry
    r.box("Bunk", 0.6, 0.3, 2.0, 1.0, 0.6, 2.0, r.lit((0.68, 0.35, 0.3)), solid=True)
    r.box("Blanket", 0.6, 0.64, 2.3, 0.96, 0.08, 1.3, r.lit((0.3, 0.45, 0.6)))
    r.box("StickerWall", 0.05, 1.3, 4.0, 0.05, 1.3, 1.8, r.glow((0.85, 0.75, 0.9), 0.5))
    for i, (z, y, col) in enumerate(((3.4, 1.7, (1.0, 0.4, 0.6)), (3.9, 1.2, (0.3, 0.9, 0.85)), (4.4, 1.6, (1.0, 0.8, 0.3)), (4.5, 0.9, (0.6, 0.5, 1.0)))):
        r.box("Sticker%d" % i, 0.09, y, z, 0.03, 0.3, 0.3, r.glow(col, 0.9))
    r.spot("StickerSpot", "mk_hd_stickers", 0.9, 4.0)
    r.box("Shelf", 5.0, 1.3, 0.2, 1.0, 0.1, 0.3, r.lit((0.45, 0.32, 0.22)))
    r.box("Photo", 5.0, 1.55, 0.1, 0.3, 0.4, 0.03, r.lit((0.9, 0.85, 0.7)))
    r.spot("PhotoSpot", "mk_hd_photo", 5.0, 0.9)
    r.box("Charts", 1.5, 1.7, 0.06, 1.2, 0.8, 0.03, r.lit((0.85, 0.8, 0.6)))
    r.spot("ChartsSpot", "mk_hd_charts", 1.6, 0.9)
    r.box("Pantry", 6.5, 0.5, 0.35, 0.7, 1.0, 0.6, r.lit((0.5, 0.4, 0.3)), solid=True)
    r.pickup("PantryTin", "mk_hd_pantry", 6.2, 1.2)
    # the hacker deck on a desk under a window onto the neon: the save terminal (save and rest)
    r.box("Desk", 3.0, 0.4, 0.5, 1.8, 0.8, 0.7, r.lit((0.4, 0.3, 0.26)), solid=True)
    r.box("DeckBody", 3.0, 0.86, 0.55, 0.9, 0.1, 0.5, r.lit((0.15, 0.17, 0.2)))
    r.box("DeckScreen", 3.0, 1.2, 0.25, 0.8, 0.5, 0.04, r.glow((0.3, 1.0, 0.85), 1.1))
    r.box("DeckKeys", 3.0, 0.93, 0.7, 0.8, 0.03, 0.2, r.glow((1.0, 0.4, 0.7), 0.8))
    r.node("SaveDeck", "Node3D", ".", (3.0, 0, 0.9),
           extra='script = %s\nroom_id = "market_hideout"\nspawn_id = "start"\nrest = true\nreach = 1.6\nbuild_placeholder = false' % r.ext_res("Script", "res://scripts/save/save_lamp.gd"))
    r.box("NeonWindow", 3.0, 2.05, 0.06, 1.7, 0.8, 0.06, r.glow((1.0, 0.35, 0.7), 1.0))
    r.box("NeonWindowB", 3.0, 2.05, 0.1, 0.5, 0.8, 0.04, r.glow((0.3, 0.95, 0.9), 1.1))
    r.omni("NeonSpill", 3.0, 1.8, 1.0, (1.0, 0.4, 0.75), 2.0, 5.0)
    # clothesline of spare jackets, the parcel marked MOX WUZ HERE, a rug
    r.box("ClothesLine", 5.2, 2.3, 2.0, 2.6, 0.03, 0.03, r.lit((0.12, 0.12, 0.14)))
    for i, x in enumerate((4.3, 5.1, 5.9)):
        r.box("Jacket%d" % i, x, 1.9, 2.0, 0.5, 0.8, 0.06, jacket if i != 1 else r.lit((0.2, 0.3, 0.4)))
    r.box("Parcel", 5.4, 0.2, 3.5, 0.6, 0.4, 0.5, r.lit((0.75, 0.6, 0.4)), solid=True)
    r.text("ParcelText", "MOX WUZ HERE", 5.4, 0.3, 3.76, size=0.006, color=(0.15, 0.1, 0.05), font=26)
    r.spot("ParcelSpot", "mk_hd_parcel", 5.4, 4.3)
    r.plane("Rug", 3.5, 0.01, 2.6, 2.2, 1.6, r.lit((0.55, 0.3, 0.4)))
    # the ladder hatch in the floor to Tuesday's Repair, and the door to the square
    r.box("HatchFrame", 2.2, 0.02, 4.2, 1.1, 0.04, 1.1, metal)
    r.box("HatchHole", 2.2, 0.025, 4.2, 0.8, 0.04, 0.8, r.lit((0.03, 0.03, 0.05)))
    r.box("HatchLight", 2.2, 0.05, 4.2, 0.5, 0.03, 0.5, r.glow((0.25, 0.9, 0.85), 1.0))
    r.door("DoorSquare", "mk_hd_to_square", 5.5, 5.0, yaw=180)
    r.door("DoorHatch", "mk_hd_hatch", 2.2, 4.4, yaw=180)
    r.spawns([("start", (3.0, 1.4), (0, -1)), ("from_square", (5.5, 4.0), (0, -1)), ("from_repair", (2.2, 3.2), (0, -1))])
    finish(r, "market_hideout.tscn")


def dispatch():
    r = interior("market_dispatch", "MarketDispatch", 8, 6, "floor_concrete_plain_trim_top", "steel_plate_riveted_grey",
                 (0.85, 0.78, 0.68), (0.95, 0.88, 0.7), glow_color=(1.0, 0.82, 0.5))
    r.box("Counter", 4.0, 0.5, 0.95, 4.2, 1.0, 0.5, r.lit((0.55, 0.38, 0.25)), solid=True)
    r.box("ShelfA", 0.8, 0.8, 0.4, 1.4, 1.6, 0.6, r.lit((0.6, 0.5, 0.35)), solid=True)
    r.box("ShelfB", 7.2, 0.8, 0.4, 1.4, 1.6, 0.6, r.lit((0.6, 0.5, 0.35)), solid=True)
    r.box("Parcels", 0.8, 1.7, 0.4, 1.0, 0.4, 0.5, r.lit((0.8, 0.6, 0.4)))
    r.box("BoardCork", 0.08, 1.5, 2.5, 0.1, 1.2, 1.8, r.lit((0.7, 0.5, 0.3)))
    for i, z in enumerate((2.0, 2.4, 2.8, 3.1)):
        r.box("Slip%d" % i, 0.14, 1.5 + 0.1 * (i % 2), z, 0.02, 0.28, 0.2, r.lit((0.95, 0.92, 0.8)))
    r.node("JobBoard", "", ".", (0.9, 0, 2.5), instance=r.inst("res://scenes/props/job_board.tscn"), extra='placement_id = "mk_dp_board"')
    r.box("Bench", 7.0, 0.22, 4.0, 1.4, 0.45, 0.6, r.lit((0.45, 0.35, 0.28)), solid=True)
    r.neon("SignJobs", "JOBS", 4.0, 2.4, 0.08, 1.2, 0.3, (1.0, 0.72, 0.25))
    r.door("DoorSquare", "mk_dp_to_square", 4.0, 6.0, yaw=180)
    r.npc("Dispatcher", "mk_dp_dispatcher", 4.0, 0.5, face=(0, 1))
    r.npc("Sleeper", "mk_dp_sleeper", 7.0, 4.0, face=(-1, 0), y=0.45)
    r.spawns([("from_square", (4.0, 5.0), (0, -1))])
    finish(r, "market_dispatch.tscn")


def shop_room(room_id, title, shop_id, door_pid, floor_tile, wall_tile, floor_tint, wall_tint, keeper, keeper_pid, extras, glow_color):
    r = interior(room_id, title, 7, 5, floor_tile, wall_tile, floor_tint, wall_tint, glow_color)
    r.box("CounterL", 2.375, 0.45, 1.0, 0.75, 0.9, 0.6, r.lit((0.55, 0.38, 0.25)), solid=True)
    r.box("CounterR", 4.625, 0.45, 1.0, 0.75, 0.9, 0.6, r.lit((0.55, 0.38, 0.25)), solid=True)
    r.node("ShopCounter", "Node3D", ".", (3.5, 0, 1.55), extra='script = %s\nshop_id = "%s"\nreach = 1.6' % (r.ext_res("Script", "res://scripts/ui/shop/shop_counter.gd"), shop_id))
    extras(r)
    r.door("DoorSquare", door_pid, 3.5, 5.0, yaw=180)
    r.npc(keeper, keeper_pid, 3.5, 0.5, face=(0, 1))
    r.spawns([("from_square", (3.5, 4.0), (0, -1))])
    return r


def corner():
    def extras(r):
        for i, (z, tint) in enumerate(((1.8, (0.8, 0.45, 0.3)), (3.4, (0.35, 0.6, 0.45)))):
            r.box("ShelfW%d" % i, 0.3, 0.8, z, 0.5, 1.6, 1.2, r.lit(tint), solid=True)
        r.box("ShelfN", 6.2, 0.8, 0.4, 1.2, 1.6, 0.5, r.lit((0.6, 0.5, 0.35)), solid=True)
        r.box("Cans", 6.2, 1.75, 0.4, 1.0, 0.3, 0.4, r.lit((0.85, 0.3, 0.25)))
        r.neon("SignShop", "24H", 3.5, 2.3, 0.08, 1.3, 0.34, (0.25, 0.95, 0.85))
        r.box("CardReader", 1.2, 1.1, 0.12, 0.3, 0.4, 0.1, r.glow((0.5, 1.0, 0.6), 0.9))
        r.npc("Clerk", "mk_cs_clerk", 5.8, 3.0, face=(-1, -1))
    r = shop_room("market_corner", "MarketCorner", "market_corner", "mk_cs_to_square", "floor_concrete_plain_trim_left", "teal_circuit_traces_green",
                  (0.7, 0.8, 0.75), (0.7, 0.9, 0.85), "Shopkeeper", "mk_cs_keeper", extras, (0.6, 1.0, 0.9))
    finish(r, "market_corner.tscn")


def forge():
    def extras(r):
        # the sword rack on the west wall: Ross's six sword models on show
        r.box("SwordRack", 0.15, 1.0, 2.5, 0.15, 1.2, 1.9, r.lit((0.4, 0.3, 0.25)), solid=True)
        for i, name in enumerate(("katana_cyan", "twin_orange", "hook_cyan", "machete", "heavy_duty", "glass_core")):
            r.nodes.append('[node name="Sword%d" parent="." instance=%s]\ntransform = Transform3D(0, 0, 1, 0, 1, 0, -1, 0, 0, 0.32, 1.25, %s)\n' % (
                i, r.inst("res://art/final/weapons/sword_%s.glb" % name), round(1.7 + 0.3 * i, 2)))
        r.box("Scrap", 6.0, 0.4, 3.6, 1.2, 0.8, 1.0, r.lit((0.45, 0.45, 0.5)), solid=True)
        r.box("Anvil", 1.9, 0.35, 3.8, 0.8, 0.7, 0.5, r.lit((0.2, 0.2, 0.24)), solid=True)
        r.box("ForgeMouth", 6.1, 0.9, 0.35, 1.2, 1.4, 0.6, r.lit((0.3, 0.26, 0.24)), solid=True)
        r.box("ForgeFire", 6.1, 0.75, 0.68, 0.8, 0.5, 0.04, r.glow((1.0, 0.45, 0.12), 1.8))
        r.omni("ForgeGlow", 6.1, 1.0, 1.2, (1.0, 0.5, 0.2), 3.0, 5.0)
        r.quad("GeneratorFront", 4.8, 1.2, 0.05, 0.9, 1.4, r.picture("generator_dynamo_front", 0.9))
        # Otis's rusty ship's bridge lamp: moved here from the dock office (Decision 2, Option A); a story prop
        r.box("BridgeLamp", 4.6, 1.05, 0.5, 0.3, 0.4, 0.3, r.lit((0.55, 0.3, 0.2)))
        r.box("BridgeLampGlass", 4.6, 1.3, 0.5, 0.2, 0.15, 0.2, r.lit((0.6, 0.6, 0.55)))
        r.spot("LampSpot", "mk_fg_bridge_lamp", 4.6, 1.5)
        r.neon("SignForge", "THE FORGE", 3.5, 2.35, 0.08, 1.6, 0.34, (1.0, 0.35, 0.65))
    r = shop_room("market_forge", "MarketForge", "market_forge", "mk_fg_to_square", "floor_plate_diamond_small_a", "rust_vent_louvers_wide",
                  (0.8, 0.7, 0.62), (0.9, 0.75, 0.65), "Otis", "mk_fg_otis", extras, (1.0, 0.65, 0.35))
    finish(r, "market_forge.tscn")


def repair():
    r = interior("market_repair", "MarketRepair", 7, 5, "floor_concrete_cracked_dark", "pipes_on_black_vertical",
                 (0.7, 0.8, 0.85), (0.85, 0.95, 1.0), glow_color=(0.55, 1.0, 0.95))
    metal = r.lit((0.55, 0.58, 0.64))
    r.box("Workbench", 3.5, 0.45, 0.6, 3.0, 0.9, 0.8, r.lit((0.5, 0.4, 0.3)), solid=True)
    r.box("HalfBuilt", 2.6, 1.1, 0.6, 0.5, 0.35, 0.4, r.lit((0.6, 0.62, 0.7)))
    r.box("HalfBuiltB", 4.2, 1.05, 0.6, 0.4, 0.25, 0.3, r.lit((0.7, 0.45, 0.35)))
    r.box("Pegboard", 0.05, 1.5, 2.6, 0.06, 1.6, 2.0, r.lit((0.35, 0.35, 0.38)))
    for i, z in enumerate((1.9, 2.3, 2.7, 3.1)):
        r.box("Tool%d" % i, 0.11, 1.5 + 0.1 * (i % 2), z, 0.04, 0.5, 0.08, metal)
    r.box("Conveyor", 5.2, 0.3, 3.6, 0.7, 0.6, 2.4, r.lit((0.25, 0.27, 0.3)), solid=True)
    for i, z in enumerate((2.8, 3.4, 4.0)):
        r.box("BrokenRadio%d" % i, 5.2, 0.7, z, 0.4, 0.22, 0.28, r.lit((0.6 - 0.1 * i, 0.5, 0.4)))
    r.box("TuesdayBody", 3.9, 1.7, 1.3, 0.34, 0.2, 0.34, r.lit((0.7, 0.72, 0.76)))
    r.box("TuesdayLight", 3.9, 1.58, 1.3, 0.14, 0.06, 0.14, r.glow((0.2, 1.0, 0.9), 1.8))
    r.text("ScratchText", "MOX WUZ HERE", 2.0, 0.92, 0.95, size=0.006, color=(0.15, 0.1, 0.05), font=24)
    r.spot("ScratchSpot", "mk_rp_scratch", 2.0, 1.6)
    # the ladder hatch up to Red's hideout, in the east corner
    r.box("LadderRailA", 5.6, 1.4, 0.1, 0.06, 2.8, 0.06, metal)
    r.box("LadderRailB", 6.1, 1.4, 0.1, 0.06, 2.8, 0.06, metal)
    for i in range(8):
        r.box("Rung%d" % i, 5.85, 0.3 + 0.33 * i, 0.1, 0.5, 0.04, 0.04, metal)
    r.box("CeilingHatch", 5.85, 2.9, 0.4, 0.8, 0.06, 0.8, r.glow((1.0, 0.8, 0.5), 0.8))
    r.door("DoorWharf", "mk_rp_to_wharf", 2.0, 5.0, yaw=180)
    r.door("DoorHatch", "mk_rp_hatch", 5.85, 1.0)
    r.npc("Mox", "mk_rp_mox", 3.5, 1.5, face=(0, 1))
    r.spawns([("from_wharf", (2.0, 4.0), (0, -1)), ("from_hideout", (5.85, 2.2), (0, 1))])
    finish(r, "market_repair.tscn")


def arcade():
    r = start("market_arcade", "MarketArcade", 9, 6, 45, (4.5, 3), (0, 0), 3.0, "floor_mesh_red_a", "circuit_traces_black_teal",
              (0.7, 0.55, 0.75), (0.8, 0.75, 1.0))
    walls(r, south_gaps=[])
    r.omni("RoomPink", 3.0, 2.2, 2.0, (1.0, 0.35, 0.75), 2.6, 8.0)
    r.omni("RoomTeal", 6.5, 2.2, 2.5, (0.3, 1.0, 0.9), 2.2, 8.0)
    pastel = [(0.9, 0.6, 0.75), (0.55, 0.75, 0.9), (0.85, 0.85, 0.5), (0.6, 0.9, 0.7), (0.8, 0.6, 0.9), (0.9, 0.7, 0.5)]
    screens = [(1.0, 0.4, 0.7), (0.3, 1.0, 0.9), (1.0, 0.85, 0.3), (0.5, 0.6, 1.0), (0.4, 1.0, 0.5), (1.0, 0.5, 0.3)]

    def cabinet(name, x, z, yaw, i):
        # 0.7 x 0.8 x 1.7 body (width x depth x height), a lit screen on its front face
        dx, dz = math.sin(math.radians(yaw)), math.cos(math.radians(yaw))
        r.box(name, x, 0.85, z, 0.7, 1.7, 0.8, r.lit(pastel[i % 6]), solid=True, yaw=yaw)
        r.box(name + "Screen", x + dx * 0.41, 1.25, z + dz * 0.41, 0.5, 0.4, 0.03, r.glow(screens[i % 6], 1.3), yaw=yaw)
        r.box(name + "Marquee", x + dx * 0.3, 1.62, z + dz * 0.3, 0.6, 0.12, 0.2, r.glow(screens[(i + 2) % 6], 1.0), yaw=yaw)
    for i, x in enumerate((1.5, 3.2, 4.9, 6.6)):
        cabinet("CabinetN%d" % i, x, 0.55, 0, i)
    for i, z in enumerate((2.0, 3.8)):
        cabinet("CabinetE%d" % i, 8.55, z, -90, i + 4)
    r.box("SnackCounter", 1.3, 0.5, 2.5, 0.7, 1.0, 3.0, r.lit((0.5, 0.3, 0.25)), solid=True)
    r.speaker("ArcadeSpeakerA", 0.6, 0.4, size=1.0, yaw=0)
    r.speaker("ArcadeSpeakerB", 8.4, 5.2, size=0.8, yaw=-90, color=(1.0, 0.45, 0.7))
    r.text("TurnItUp", "TURN IT UP", 0.1, 2.2, 3.4, yaw=90, size=0.008, color=(1.0, 0.9, 0.5), font=28)
    r.box("ScoreBoard", 4.5, 2.2, 0.05, 2.0, 0.9, 0.08, r.glow((0.3, 1.0, 0.6), 0.9))
    r.text("ScoreText", "ZED 9990  RED 9989", 4.5, 2.2, 0.12, size=0.01, color=(0.02, 0.1, 0.05), font=30)
    r.spot("ScoreSpot", "mk_ar_scores", 4.5, 1.2)
    r.box("PrizeClaw", 8.1, 0.9, 0.5, 0.9, 1.8, 0.8, r.lit((0.65, 0.85, 0.9)), solid=True)
    r.box("ClawGlass", 8.1, 1.2, 0.92, 0.8, 1.0, 0.04, r.glow((0.7, 1.0, 1.0), 0.6))
    r.pickup("BehindClaw", "mk_ar_behind_claw", 8.75, 1.1)
    r.neon("SignOpen", "OPEN LATE", 4.5, 2.65, 0.06, 1.8, 0.28, (1.0, 0.35, 0.7))
    r.door("DoorWharf", "mk_ar_to_wharf", 7.0, 6.0, yaw=180)
    r.npc("Owner", "mk_ar_owner", 0.6, 2.5, face=(1, 0))
    r.npc("KidA", "mk_ar_kid_a", 2.0, 2.0, face=(0, -1))
    r.npc("KidB", "mk_ar_kid_b", 3.0, 4.0, face=(0, -1))
    r.npc("KidC", "mk_ar_kid_c", 5.5, 2.0, face=(0, -1))
    r.npc("Zed", "mk_ar_zed", 6.5, 4.0, face=(0, -1))
    r.spawns([("from_wharf", (7.0, 5.0), (0, -1))])
    finish(r, "market_arcade.tscn")


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    square(); wharf(); gate(); hideout(); dispatch(); corner(); forge(); repair(); arcade()
    print("wrote the night market rooms to", os.path.normpath(OUT))
