#!/usr/bin/env python3
"""Writes the nine graybox rooms of Harrow Landing (M3-4) plus the road stub.

Run from the repo root:  python3 game/scripts/tools/make_harrow_rooms.py
Blueprint: docs/maps/harrow_landing.md ("Graybox build notes"). Map coordinates: the origin is the floor
corner where the two back walls meet, +X runs east along the north wall, +Z runs south toward the
camera. Boxes and flat colors only (placeholder art). Everything that is not geometry (what is in a
crate, who says what, which door is locked) lives in game/data/world/placements.json and the other data
files; the node names / placement_id here have to match it (a test checks).
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
from make_test_rooms import Room  # noqa: E402

OUT = os.path.join(os.path.dirname(__file__), "..", "..", "scenes", "rooms")


def yaw_to(dx, dz):
    return math.degrees(math.atan2(dx, dz))


class H(Room):
    def __init__(self, room_id, title, w, d):
        super().__init__(room_id, 0, w, 0, d)
        self.title, self.w, self.d = title, w, d
        self._mats = {}
        self._glow = {}
        self._planes = {}
        self.shapes = []

    # ---- materials
    def lit(self, tint, uv=(1, 1), tex="checker_128", affine=0.3):
        key = (tint, uv, tex)
        if key not in self._mats:
            self._mats[key] = self.material(tint, uv, affine, tex)
        return self._mats[key]

    def glow(self, tint, energy=1.4):
        key = (tint, energy)
        if key not in self._glow:
            shader = self.ext_res("Shader", "res://shaders/psx_unlit.gdshader")
            tex = self.ext_res("Texture2D", "res://art/placeholder/textures/checker_64.png")
            self._glow[key] = self.sub(
                "ShaderMaterial",
                "shader = %s\nshader_parameter/albedo_texture = %s\nshader_parameter/uv_scale = Vector2(0.07, 0.07)\n"
                "shader_parameter/uv_offset = Vector2(0.02, 0.02)\nshader_parameter/albedo_tint = Color(%s, %s, %s, 1)\n"
                "shader_parameter/emission_energy = %s" % (shader, tex, tint[0], tint[1], tint[2], energy))
        return self._glow[key]

    # ---- geometry
    def box(self, name, x, y, z, sx, sy, sz, mat, solid=False, fade=False, parent="."):
        mesh = self.box_mesh((sx, sy, sz))
        self.node(name, "MeshInstance3D", parent, (x, y, z),
                  extra="mesh = %s\nsurface_material_override/0 = %s" % (mesh, mat), groups=["fade_occluder"] if fade else None)
        if solid:
            self.collide(name + "Shape", x, y, z, sx, sy, sz)

    def collide(self, name, x, y, z, sx, sy, sz):
        self.node(name, "CollisionShape3D", "Collision", (x, y, z), extra="shape = %s" % self.box_shape((sx, sy, sz)))

    def plane(self, name, x, y, z, sx, sz, mat):
        key = (sx, sz)
        if key not in self._planes:
            self._planes[key] = self.sub("PlaneMesh", "size = Vector2(%s, %s)" % (sx, sz))
        self.node(name, "MeshInstance3D", ".", (x, y, z), extra="mesh = %s\nsurface_material_override/0 = %s" % (self._planes[key], mat))

    def label(self, text, x, y, z, parent="."):
        safe = "".join(ch for ch in text if ch.isalnum())[:12]
        self.nodes.append('[node name="Label_%s" type="Label3D" parent="%s"]\ntransform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, %s, %s, %s)\n'
                          'text = "%s"\npixel_size = 0.012\nbillboard = 1\nfont_size = 28\noutline_size = 10\n' % (
                              safe, parent, x, y, z, text))

    # ---- props
    def inst(self, path):
        return self.ext_res("PackedScene", path)

    def door(self, name, pid, x, z, yaw=0):
        self.node(name, "", ".", (x, 0, z), yaw_deg=yaw, instance=self.inst("res://scenes/props/door.tscn"), extra='placement_id = "%s"' % pid)

    def pickup(self, name, pid, x, z, y=0.0, lift=None):
        extra = 'placement_id = "%s"' % pid
        self.node(name, "", ".", (x, y, z), instance=self.inst("res://scenes/props/pickup.tscn"), extra=extra)

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

    def flag_visible(self, name, show_if, x, y, z):
        script = self.ext_res("Script", "res://scripts/field/flag_visible.gd")
        self.node(name, "Node3D", ".", (x, y, z), extra='script = %s\nshow_if = "%s"' % (script, show_if.replace('"', '\\"')))


def start(room_id, title, w, d, yaw, cam_center, cam_size, wall_h, floor_tint, wall_tint, floor_tex="checker_64"):
    r = H(room_id, title, w, d)
    script_room = r.ext_res("Script", "res://scripts/field/field_room.gd")
    player = r.ext_res("PackedScene", "res://scenes/actors/player.tscn")
    look = r.ext_res("Script", "res://scripts/core/psx_room_look.gd")
    cam_script = r.ext_res("Script", "res://scripts/field/diorama_camera.gd")
    bounds_script = r.ext_res("Script", "res://scripts/field/camera_bounds.gd")
    env = r.sub("Environment", "background_mode = 1\nbackground_color = Color(0.12156863, 0.14509805, 0.2509804, 1)\n"
                "ambient_light_source = 2\nambient_light_color = Color(0.7, 0.7, 0.95, 1)")
    r.nodes.append('[node name="%s" type="Node3D"]\nscript = %s\nplayer_scene = %s\nroom_id = "%s"\n' % (title, script_room, player, room_id))
    r.node("RoomLook", "Node", extra="script = %s\nfog_color = Color(0.12156863, 0.14509805, 0.2509804, 1)\nfog_near = 13.0\nfog_far = 22.0\n"
           "ambient_color = Color(0.7, 0.7, 0.95, 1)\nambient_energy = 1.0" % look)
    r.node("WorldEnvironment", "WorldEnvironment", extra="environment = %s" % env)
    r.node("CameraBounds", "Node3D", pos=(cam_center[0], 0, cam_center[1]),
           extra="script = %s\nsize = Vector3(%s, 0, %s)" % (bounds_script, cam_size[0], cam_size[1]))
    r.node("CameraRig", "Node3D", extra="script = %s\npitch_deg = 42.0\nyaw_deg = %s\nfov_deg = 30.0\ndistance = 11.0" % (cam_script, yaw))
    r.node("Collision", "StaticBody3D")
    r.plane("Floor", w / 2.0, 0, d / 2.0, w, d, r.lit(floor_tint, (w / 3.0, d / 3.0), floor_tex))
    r.collide("FloorShape", w / 2.0, -0.1, d / 2.0, w + 2, 0.2, d + 2)
    r.wall_mat = r.lit(wall_tint, (max(w / 4.0, 1), 0.8), "wall_128")
    r.wall_h = wall_h
    r.node("Walls", "Node3D")
    return r


def walls(r, n_segments=None, w_segments=None, front=True, south_gaps=None, east=True):
    """N wall as boxes (segments of (x0, x1)), W wall full height, plus collision on every side."""
    h = r.wall_h
    for i, (x0, x1) in enumerate(n_segments or [(0, r.w)]):
        r.box("WallN%d" % i, (x0 + x1) / 2.0, h / 2.0, -0.15, x1 - x0, h, 0.3, r.wall_mat, parent="Walls")
        r.collide("WallNShape%d" % i, (x0 + x1) / 2.0, 1.5, -0.1, x1 - x0, 3, 0.2)
    for i, (z0, z1) in enumerate(w_segments or [(0, r.d)]):
        r.box("WallW%d" % i, -0.15, h / 2.0, (z0 + z1) / 2.0, 0.3, h, z1 - z0, r.wall_mat, parent="Walls")
        r.collide("WallWShape%d" % i, -0.1, 1.5, (z0 + z1) / 2.0, 0.2, 3, z1 - z0)
    gaps = south_gaps or []
    edges = [0.0] + [v for g in gaps for v in g] + [r.w]
    for i in range(0, len(edges), 2):
        if edges[i + 1] - edges[i] > 0.01:
            r.collide("FrontBarrier%d" % i, (edges[i] + edges[i + 1]) / 2.0, 1.5, r.d + 0.1, edges[i + 1] - edges[i], 3, 0.2)
    if east:
        r.collide("RightBarrier", r.w + 0.1, 1.5, r.d / 2.0, 0.2, 3, r.d)


def finish(r, name):
    grim_dressing(r, r.room_id)
    r.write(name)


def grim_dressing(r, dressing_id):
    """The grim dressing (look test 2026-10-08, default everywhere since Ross approved it): one node per room that
    builds the props listed for it in data/world/look_dressing.json when the look profile asks for them, and
    grimes the room's materials. Added last so it wakes after the room's own nodes. Classic (F11) leaves the room
    exactly as it was."""
    script = r.ext_res("Script", "res://scripts/field/grim_dressing.gd")
    r.node("GrimDressing", "Node3D", extra='script = %s\ndressing_id = "%s"' % (script, dressing_id))


def lamps(r, wall_mat, items):
    """Window lamps on a facade: amber quads. items: (name, x, y, z, w, h)."""
    amber = r.glow((1.0, 0.82, 0.45), 1.3)
    for name, x, y, z, sx, sy in items:
        r.box(name, x, y, z, sx, sy, 0.05, amber)


# ============================================================ Lamp Square
def square():
    r = start("harrow_square", "HarrowSquare", 22, 12, 30, (11, 5.5), (12, 6), 4.5, (0.85, 0.82, 0.9), (0.75, 0.8, 0.95))
    walls(r, n_segments=[(0, 11.5), (13.5, 22)], south_gaps=[])
    # alley alcove: floor, back wall and side walls, collision
    r.plane("AlleyFloor", 12.5, 0, -1.5, 2, 3, r.lit((0.5, 0.5, 0.56), (1, 1.5), "checker_64"))
    r.collide("AlleyFloorShape", 12.5, -0.1, -1.5, 2, 0.2, 3)
    r.box("AlleyBack", 12.5, 2.25, -3.15, 2, 4.5, 0.3, r.wall_mat, parent="Walls")
    r.collide("AlleyBackShape", 12.5, 1.5, -3.1, 2, 3, 0.2)
    for side, x in (("A", 11.35), ("B", 13.65)):
        r.box("AlleySide" + side, x, 2.25, -1.5, 0.3, 4.5, 3.0, r.wall_mat, parent="Walls")
        r.collide("AlleySideShape" + side, x + (-0.05 if side == "A" else 0.05), 1.5, -1.5, 0.2, 3, 3.0)
    r.box("ChalkLantern", 12.5, 1.4, -2.95, 0.7, 0.9, 0.03, r.glow((0.95, 0.95, 0.85), 0.7), parent=".")
    r.box("TrashCanA", 11.8, 0.4, -2.2, 0.5, 0.8, 0.5, r.lit((0.35, 0.37, 0.4)), solid=True)
    r.box("TrashCanB", 13.2, 0.4, -2.55, 0.5, 0.8, 0.5, r.lit((0.35, 0.37, 0.4)), solid=True)
    r.crate("AlleyStash", "sq_alley_stash", 12.5, -2.3)
    # shopfronts (flat colored slabs on the facade) and window lamps
    shop = lambda name, x0, x1, tint: r.box(name, (x0 + x1) / 2.0, 2.0, 0.05, x1 - x0, 4.0, 0.1, r.lit(tint, (1, 1), "checker_128"))
    shop("FrontCourier", 2.0, 6.0, (0.78, 0.62, 0.3))
    shop("FrontStore", 6.5, 10.5, (0.45, 0.62, 0.42))
    shop("FrontGear", 14.5, 17.5, (0.42, 0.52, 0.72))
    lamps(r, r.wall_mat, [("LampA", 2.6, 3.2, 0.12, 0.5, 0.6), ("LampB", 5.4, 3.2, 0.12, 0.5, 0.6), ("LampC", 9.6, 3.2, 0.12, 0.5, 0.6),
                          ("LampD", 15.0, 3.2, 0.12, 0.5, 0.6), ("LampE", 17.0, 3.2, 0.12, 0.5, 0.6), ("LampF", 0.12, 3.2, 8.0, 0.05, 0.5)])
    r.box("DarkWindow", 7.0, 2.6, 0.14, 1.2, 0.9, 0.04, r.lit((0.08, 0.09, 0.14), (1, 1), "checker_64"))
    r.flag_visible("LitWindow", '{"flag": "job_dark_window_done"}', 7.0, 2.6, 0.17)
    r.box("LitWindowQuad", 0, 0, 0, 1.2, 0.9, 0.04, r.glow((1.0, 0.82, 0.45), 1.5), parent="LitWindow")
    # the balcony and its crate step (the dark window's side job)
    r.box("Balcony", 7.0, 0.9, 0.3, 2.0, 1.8, 0.6, r.lit((0.5, 0.42, 0.34)), solid=True)
    r.box("CrateStep", 6.5, 0.45, 1.2, 0.9, 0.9, 0.9, r.lit((0.8, 0.5, 0.35)), solid=True)
    r.spot("WindowLedge", "sq_window_ledge", 6.7, 0.3, y=1.8)
    r.pickup("WindowReward", "sq_window_reward", 7.4, 0.3, y=1.8)
    # lamp post
    r.box("LampPost", 11, 2.0, 6, 0.25, 4.0, 0.25, r.lit((0.85, 0.64, 0.25)), solid=True, fade=True)
    r.box("LampBulb", 11, 3.9, 6, 0.5, 0.5, 0.5, r.glow((1.0, 0.88, 0.54), 1.4))
    r.node("LampLight", "OmniLight3D", ".", (11, 3.4, 6), extra="light_color = Color(1, 0.7019608, 0.2784314, 1)\nlight_energy = 6.0\nomni_range = 9.0")
    r.spot("LampPostSpot", "sq_lamp_post", 11.0, 6.0)
    r.box("BetsBoard", 13.6, 0.9, 5.5, 1.2, 1.0, 0.1, r.lit((0.2, 0.25, 0.22)), solid=True)
    r.spot("BetsSpot", "sq_bets_board", 13.6, 6.1)
    r.box("NoticeBoard", 0.1, 1.5, 7.5, 0.1, 1.2, 1.6, r.lit((0.55, 0.6, 0.7)))
    r.spot("NoticeSpot", "sq_notice_board", 0.9, 7.5)
    # the gate arch to the checkpoint
    metal = r.lit((0.55, 0.58, 0.64))
    r.box("ArchPostA", 18.55, 1.7, 0.3, 0.3, 3.4, 0.3, metal, solid=True)
    r.box("ArchPostB", 21.45, 1.7, 0.3, 0.3, 3.4, 0.3, metal, solid=True)
    r.box("ArchLintel", 20.0, 3.5, 0.3, 3.4, 0.4, 0.3, metal)
    r.box("ArchLamp", 20.0, 3.1, 0.35, 0.4, 0.2, 0.1, r.glow((0.5, 0.75, 1.0), 1.2))
    # dock stairs (south edge): rails and a dark strip
    r.box("StairsStrip", 10.5, 0.03, 11.4, 3.0, 0.04, 1.2, r.lit((0.2, 0.22, 0.3), (1, 1), "checker_64"))
    r.box("StairRailA", 8.9, 0.5, 11.8, 0.12, 1.0, 0.5, metal, solid=True)
    r.box("StairRailB", 12.1, 0.5, 11.8, 0.12, 1.0, 0.5, metal, solid=True)
    # doors
    r.door("DoorCourier", "sq_to_courier", 4.0, 0)
    r.door("DoorStore", "sq_to_store", 8.5, 0)
    r.door("DoorGear", "sq_to_gear", 16.0, 0)
    r.door("DoorCheckpoint", "sq_to_checkpoint", 20.0, 0)
    r.door("DoorHome", "sq_to_home", 0, 4.0, yaw=90)
    r.door("DoorDocks", "sq_to_docks", 10.5, 12.0, yaw=180)
    r.door("DoorDebug", "sq_to_test_room", 0, 9.5, yaw=90)
    # people
    r.npc("Bettor", "sq_bettor", 12.4, 6.8, face=(0, 1))
    r.npc("Neighbor", "sq_neighbor", 2.0, 6.0, face=(-1, -0.3))
    r.npc("SnackSeller", "sq_snack", 14.0, 10.0, face=(0, -1))
    r.npc("GateDockhand", "sq_dockhand", 10.5, 10.2, face=(0, -1))
    r.npc("MoxCameo", "sq_mox_cameo", 12.5, -1.0, face=(0, 1))
    r.npc("LegendBarfly", "sq_legend_barfly", 15.0, 7.0, face=(-1, 0))
    r.spawns([("from_home", (1.2, 4.0), (1, 0)), ("from_courier", (4.0, 1.2), (0, 1)), ("from_store", (8.5, 1.2), (0, 1)),
              ("from_gear", (16.0, 1.2), (0, 1)), ("from_checkpoint", (20.0, 1.5), (0, 1)), ("from_docks", (10.5, 10.8), (0, -1)),
              ("from_debug", (1.2, 9.5), (1, 0))])
    r.node("PlayerSpawn", "Marker3D", pos=(1.2, 0, 4.0), yaw_deg=90)
    finish(r, "harrow/harrow_square.tscn")


# ============================================================ The Docks
def docks():
    r = start("harrow_docks", "HarrowDocks", 24, 9, 25, (12, 5.0), (14, 4), 5.0, (0.7, 0.68, 0.76), (0.7, 0.7, 0.8))
    walls(r, n_segments=[(0, 10.5), (13.5, 24)], south_gaps=[(20, 23)])
    r.box("StairsUp", 12.0, 1.5, -0.05, 3.0, 3.0, 0.1, r.lit((0.15, 0.17, 0.24), (1, 1), "checker_64"), parent=".")
    # pier and water
    r.plane("Water", 12, -0.35, 11.5, 30, 5, r.lit((0.1, 0.2, 0.42), (6, 1), "checker_64"))
    r.plane("PierFloor", 21.5, 0.0, 11.0, 3, 4, r.lit((0.55, 0.45, 0.35), (1, 1.3), "checker_64"))
    r.collide("PierShape", 21.5, -0.1, 11.0, 3, 0.2, 4)
    r.collide("PierSideA", 19.9, 1.5, 11.0, 0.2, 3, 4)
    r.collide("PierSideB", 23.1, 1.5, 11.0, 0.2, 3, 4)
    r.collide("PierEnd", 21.5, 1.5, 13.1, 3.4, 3, 0.2)
    r.box("PierPostA", 20.1, 0.5, 13.0, 0.2, 1.0, 0.2, r.lit((0.4, 0.3, 0.22)))
    r.box("PierPostB", 22.9, 0.5, 13.0, 0.2, 1.0, 0.2, r.lit((0.4, 0.3, 0.22)))
    # warehouse fronts, doors, lamps
    r.box("FrontOffice", 5.0, 2.0, 0.05, 3.2, 4.0, 0.1, r.lit((0.7, 0.5, 0.3)))
    r.box("FrontBar", 19.0, 2.0, 0.05, 3.6, 4.0, 0.1, r.lit((0.62, 0.4, 0.42)))
    lamps(r, r.wall_mat, [("LampA", 3.8, 3.2, 0.12, 0.5, 0.6), ("LampB", 20.3, 3.2, 0.12, 0.5, 0.6), ("LampC", 16.0, 3.4, 0.12, 0.6, 0.6)])
    r.box("RosterWindow", 6.9, 2.0, 0.12, 0.9, 0.8, 0.05, r.glow((0.5, 0.65, 0.9), 1.0))
    r.spot("RosterSpot", "dk_roster_window", 6.9, 0.9)
    r.box("TideBoard", 8.6, 1.5, 0.1, 1.2, 0.9, 0.08, r.lit((0.2, 0.28, 0.35)))
    r.spot("TideSpot", "dk_tide_board", 8.6, 0.9)
    r.door("DoorSquare", "dk_to_square", 12.0, 0.0)
    r.door("DoorOffice", "dk_to_office", 5.0, 0.0)
    r.door("DoorBar", "dk_to_bar", 19.0, 0.0)
    # container stack and crane (west)
    r.box("ContainerA", 1.4, 1.2, 1.6, 2.4, 2.4, 1.4, r.lit((0.7, 0.3, 0.25)), solid=True, fade=True)
    r.box("ContainerB", 1.4, 1.2, 4.2, 2.4, 2.4, 1.4, r.lit((0.3, 0.45, 0.65)), solid=True, fade=True)
    r.box("CraneMast", 0.6, 3.0, 6.9, 0.35, 6.0, 0.35, r.lit((0.85, 0.7, 0.25)), solid=True, fade=True)
    r.box("CraneArm", 3.2, 6.0, 6.9, 5.6, 0.3, 0.3, r.lit((0.85, 0.7, 0.25)))
    r.spot("CraneSpot", "dk_crane", 1.4, 7.9)
    # the crate stack: hop A, then B (the town's jump lesson)
    r.box("CrateA", 3.2, 0.45, 6.0, 0.9, 0.9, 0.9, r.lit((0.8, 0.5, 0.35)), solid=True)
    r.box("CrateBase", 2.0, 0.45, 6.0, 0.9, 0.9, 0.9, r.lit((0.7, 0.45, 0.32)), solid=True)
    r.box("CrateB", 2.0, 1.35, 6.0, 0.9, 0.9, 0.9, r.lit((0.8, 0.5, 0.35)), solid=True)
    r.pickup("ChiliPickup", "dk_chili", 2.0, 6.0, y=1.8)
    r.pickup("PierCoffee", "dk_pier_coffee", 21.5, 12.4)
    # people
    r.npc("Kasp", "dk_kasp", 13.0, 4.0, face=(0, -1))
    r.npc("GruntA", "dk_grunt_a", 12.0, 5.0, face=(0, -1))
    r.npc("GruntB", "dk_grunt_b", 14.0, 5.0, face=(0, -1))
    r.npc("Otis", "dk_otis", 5.0, 1.0, face=(0, 1))
    r.npc("HandA", "dk_hand_a", 9.0, 3.0, face=(1, 0.3))
    r.npc("HandB", "dk_hand_b", 8.2, 3.7, face=(1, -0.2))
    r.npc("Pell", "dk_pell", 9.8, 3.9, face=(0.5, -1))
    r.spawns([("from_square", (12.0, 1.5), (0, 1)), ("from_dock_office", (5.0, 1.2), (0, 1)), ("from_bar", (19.0, 1.2), (0, 1))])
    r.node("PlayerSpawn", "Marker3D", pos=(12.0, 0, 1.5))
    finish(r, "harrow/harrow_docks.tscn")


# ============================================================ Signals Checkpoint
def checkpoint():
    r = start("harrow_checkpoint", "HarrowCheckpoint", 14, 9, 30, (7, 4.5), (4, 2), 4.0, (0.7, 0.72, 0.8), (0.65, 0.75, 0.9))
    walls(r, n_segments=[(0, 8.5), (11.5, 14)], south_gaps=[(6, 9)])
    metal = r.lit((0.55, 0.6, 0.68))
    r.box("RoadOpening", 10.0, 1.5, -0.05, 3.0, 3.0, 0.1, r.lit((0.12, 0.14, 0.2), (1, 1), "checker_64"))
    r.box("BarrierPostA", 8.4, 0.7, 0.35, 0.3, 1.4, 0.3, metal, solid=True)
    r.box("BarrierPostB", 11.6, 0.7, 0.35, 0.3, 1.4, 0.3, metal)
    r.node("BarrierArm", "", ".", (8.55, 1.15, 0.35), instance=r.inst("res://scenes/props/flag_pose.tscn"),
           extra='when = "{\\"flag\\": \\"checkpoint_open\\"}"\npose_degrees = Vector3(0, 0, 80)')
    r.box("ArmBox", 1.5, 0, 0, 3.0, 0.15, 0.15, r.lit((0.9, 0.3, 0.25)), parent="BarrierArm")
    r.box("Booth", 5.0, 1.25, 2.0, 2.0, 2.5, 2.0, r.lit((0.45, 0.55, 0.7)), solid=True, fade=True)
    r.box("AppealsSlot", 5.0, 1.2, 3.03, 0.6, 0.12, 0.05, r.glow((1.0, 0.82, 0.45), 1.2))
    r.spot("AppealsSpot", "cp_appeals_slot", 5.0, 3.6)
    r.crate("Bin", "cp_bin", 3.0, 0.9)
    r.box("PosterA", 12.8, 1.9, 0.08, 0.9, 1.2, 0.04, r.lit((0.8, 0.75, 0.6)))
    r.box("PosterB", 2.2, 1.9, 0.08, 0.9, 1.2, 0.04, r.lit((0.8, 0.75, 0.6)))
    r.spot("PosterSpot", "cp_poster", 12.8, 1.0)
    lamps(r, r.wall_mat, [("LampA", 6.5, 3.0, 0.12, 0.5, 0.5)])
    r.door("DoorSquare", "cp_to_square", 7.5, 9.0, yaw=180)
    r.door("DoorRoad", "cp_to_road", 10.0, 0.0)
    r.npc("GruntA", "cp_grunt_a", 9.0, 2.0, face=(0, 1))
    r.npc("GruntB", "cp_grunt_b", 11.0, 2.0, face=(0, 1))
    r.npc("FanA", "cp_fan_a", 7.0, 6.0, face=(0, -1))
    r.npc("FanB", "cp_fan_b", 8.2, 6.0, face=(0, -1))
    r.npc("FanC", "cp_fan_c", 9.4, 6.0, face=(0, -1))
    r.spawns([("from_square", (7.5, 7.8), (0, -1)), ("from_road", (10.0, 1.5), (0, 1))])
    r.node("PlayerSpawn", "Marker3D", pos=(7.5, 0, 7.8), yaw_deg=180)
    finish(r, "harrow/harrow_checkpoint.tscn")


# ============================================================ interiors
def interior(room_id, title, w, d, door_x, floor_tint, wall_tint, spawn=None):
    r = start(room_id, title, w, d, 45, (w / 2.0, d / 2.0), (0, 0), 3.0, floor_tint, wall_tint)
    walls(r, south_gaps=[])
    return r


def home():
    r = interior("harrow_home", "HarrowHome", 7, 5, 5.5, (0.5, 0.42, 0.36), (0.72, 0.62, 0.52))
    r.box("Bed", 0.6, 0.25, 2.0, 1.0, 0.5, 2.0, r.lit((0.7, 0.35, 0.3)), solid=True)
    r.box("WindowFrame", 3.0, 1.6, 0.05, 1.4, 1.0, 0.08, r.glow((0.3, 0.4, 0.7), 0.9))
    r.node("SaveLamp", "Node3D", ".", (3.0, 0, 0.5), extra='script = %s\nroom_id = "harrow_home"\nspawn_id = "start"\nrest = true\nreach = 1.6' % r.ext_res("Script", "res://scripts/save/save_lamp.gd"))
    r.box("TallyWall", 0.04, 1.3, 4.0, 0.05, 1.2, 1.8, r.glow((0.9, 0.9, 0.8), 0.5))
    r.spot("TallySpot", "hm_tally", 0.9, 4.0)
    r.box("Shelf", 5.0, 1.3, 0.2, 1.0, 0.1, 0.3, r.lit((0.45, 0.32, 0.22)))
    r.box("Photo", 5.0, 1.55, 0.1, 0.3, 0.4, 0.03, r.lit((0.9, 0.85, 0.7)))
    r.spot("PhotoSpot", "hm_photo", 5.0, 0.9)
    r.box("Charts", 1.5, 1.6, 0.06, 1.2, 0.8, 0.03, r.lit((0.85, 0.8, 0.6)))
    r.spot("ChartsSpot", "hm_charts", 1.6, 0.9)
    r.box("Pantry", 6.5, 0.5, 0.35, 0.7, 1.0, 0.6, r.lit((0.5, 0.4, 0.3)), solid=True)
    r.pickup("PantryTin", "hm_pantry", 6.1, 1.2)
    r.door("DoorSquare", "hm_to_square", 5.5, 5.0, yaw=180)
    r.spawns([("start", (3.0, 1.4), (0, -1)), ("from_square", (5.5, 4.0), (0, -1))])
    r.node("PlayerSpawn", "Marker3D", pos=(3.0, 0, 1.4), yaw_deg=180)
    finish(r, "harrow/harrow_home.tscn")


def courier():
    r = interior("harrow_courier", "HarrowCourier", 8, 6, 4, (0.5, 0.46, 0.4), (0.7, 0.66, 0.5))
    r.box("Counter", 4.0, 0.5, 0.95, 4.2, 1.0, 0.5, r.lit((0.55, 0.38, 0.25)), solid=True)
    r.box("ShelfA", 0.8, 0.8, 0.4, 1.4, 1.6, 0.6, r.lit((0.6, 0.5, 0.35)), solid=True)
    r.box("ShelfB", 7.2, 0.8, 0.4, 1.4, 1.6, 0.6, r.lit((0.6, 0.5, 0.35)), solid=True)
    r.box("Parcels", 0.8, 1.7, 0.4, 1.0, 0.4, 0.5, r.lit((0.8, 0.6, 0.4)))
    r.box("BoardCork", 0.08, 1.5, 2.5, 0.1, 1.2, 1.8, r.lit((0.7, 0.5, 0.3)))
    r.node("JobBoard", "", ".", (0.9, 0, 2.5), instance=r.inst("res://scenes/props/job_board.tscn"), extra='placement_id = "cr_board"')
    r.box("Bench", 7.0, 0.22, 4.0, 1.4, 0.45, 0.6, r.lit((0.45, 0.35, 0.28)), solid=True)
    r.door("DoorSquare", "cr_to_square", 4.0, 6.0, yaw=180)
    r.npc("Dispatcher", "cr_dispatcher", 4.0, 0.45, face=(0, 1))
    r.npc("Sleeper", "cr_sleeper", 7.0, 4.0, face=(-1, 0), y=0.45)
    r.spawns([("from_square", (4.0, 5.0), (0, -1))])
    r.node("PlayerSpawn", "Marker3D", pos=(4, 0, 5), yaw_deg=180)
    finish(r, "harrow/harrow_courier.tscn")


def shop_room(room_id, title, shop_id, door_pid, tints, keeper, keeper_pid, extras):
    r = interior(room_id, title, 7, 5, 3.5, tints[0], tints[1])
    r.box("CounterL", 2.375, 0.45, 1.0, 0.75, 0.9, 0.6, r.lit((0.55, 0.38, 0.25)), solid=True)
    r.box("CounterR", 4.625, 0.45, 1.0, 0.75, 0.9, 0.6, r.lit((0.55, 0.38, 0.25)), solid=True)
    r.node("ShopCounter", "Node3D", ".", (3.5, 0, 1.55), extra='script = %s\nshop_id = "%s"\nreach = 1.6' % (r.ext_res("Script", "res://scripts/ui/shop/shop_counter.gd"), shop_id))
    extras(r)
    r.door("DoorSquare", door_pid, 3.5, 5.0, yaw=180)
    r.npc(keeper, keeper_pid, 3.5, 0.5, face=(0, 1))
    r.spawns([("from_square", (3.5, 4.0), (0, -1))])
    r.node("PlayerSpawn", "Marker3D", pos=(3.5, 0, 4), yaw_deg=180)
    return r


def store():
    def extras(r):
        for i, (z, tint) in enumerate(((1.8, (0.8, 0.45, 0.3)), (3.4, (0.35, 0.6, 0.45)))):
            r.box("ShelfW%d" % i, 0.3, 0.8, z, 0.5, 1.6, 1.2, r.lit(tint), solid=True)
        r.box("ShelfN", 6.2, 0.8, 0.4, 1.2, 1.6, 0.5, r.lit((0.6, 0.5, 0.35)), solid=True)
        r.box("Cans", 6.2, 1.75, 0.4, 1.0, 0.3, 0.4, r.lit((0.85, 0.3, 0.25)))
        r.npc("Customer", "st_customer", 5.8, 3.0, face=(-1, -1))
    r = shop_room("harrow_store", "HarrowStore", "harrow_general", "st_to_square", ((0.52, 0.5, 0.42), (0.55, 0.68, 0.55)), "Shopkeeper", "st_keeper", extras)
    finish(r, "harrow/harrow_store.tscn")


def gear():
    def extras(r):
        r.box("SwordRack", 0.15, 1.0, 2.5, 0.15, 1.2, 1.6, r.lit((0.4, 0.3, 0.25)), solid=True)
        for i, z in enumerate((1.9, 2.3, 2.7, 3.1)):
            r.box("Sword%d" % i, 0.35, 1.2, z, 0.1, 0.9, 0.06, r.lit((0.7, 0.72, 0.78)))
        r.box("Scrap", 6.0, 0.4, 3.6, 1.2, 0.8, 1.0, r.lit((0.45, 0.45, 0.5)), solid=True)
        r.box("Workbench", 5.6, 0.45, 1.0, 1.4, 0.9, 0.6, r.lit((0.5, 0.4, 0.3)), solid=True)
        r.box("GearSign", 5.8, 2.1, 0.06, 1.2, 0.5, 0.06, r.lit((0.45, 0.62, 0.78)))
        r.spot("SignSpot", "gr_sign", 5.8, 1.9)
    r = shop_room("harrow_gear", "HarrowGear", "harrow_gear", "gr_to_square", ((0.46, 0.46, 0.5), (0.5, 0.58, 0.72)), "Welder", "gr_keeper", extras)
    finish(r, "harrow/harrow_gear.tscn")


def dock_office():
    r = interior("harrow_dock_office", "HarrowDockOffice", 7, 5, 2, (0.5, 0.45, 0.4), (0.6, 0.55, 0.45))
    r.box("Desk", 3.0, 0.4, 0.6, 2.4, 0.8, 0.8, r.lit((0.5, 0.36, 0.25)), solid=True)
    r.box("BridgeLamp", 3.95, 1.0, 0.6, 0.3, 0.4, 0.3, r.lit((0.55, 0.3, 0.2)))
    r.box("BridgeLampGlass", 3.95, 1.25, 0.6, 0.2, 0.15, 0.2, r.lit((0.6, 0.6, 0.55)))
    r.box("CoughTin", 2.2, 0.85, 0.6, 0.2, 0.1, 0.2, r.lit((0.7, 0.7, 0.72)))
    r.box("Roster", 0.06, 1.5, 2.5, 0.08, 1.2, 1.5, r.lit((0.2, 0.25, 0.22)))
    r.spot("LampSpot", "do_lamp", 3.95, 1.3)
    r.spot("CoughSpot", "do_coughdrops", 2.2, 1.3)
    r.spot("RosterSpot", "do_roster", 0.9, 2.5)
    r.box("CrateVisual", 5.5, 0.45, 3.5, 0.9, 0.9, 0.9, r.lit((0.8, 0.5, 0.35)), solid=True)
    r.pickup("DeliveryCrate", "do_crate", 5.5, 3.5, y=0.0)
    r.door("DoorDocks", "do_to_docks", 2.0, 5.0, yaw=180)
    r.spawns([("from_docks", (2.0, 4.0), (0, -1))])
    r.node("PlayerSpawn", "Marker3D", pos=(2, 0, 4), yaw_deg=180)
    finish(r, "harrow/harrow_dock_office.tscn")


def bar():
    r = interior("harrow_bar", "HarrowBar", 9, 6, 7, (0.4, 0.34, 0.34), (0.6, 0.42, 0.42))
    r.box("BarCounter", 1.5, 0.5, 2.5, 0.6, 1.0, 3.0, r.lit((0.5, 0.3, 0.25)), solid=True)
    for i, z in enumerate((1.5, 2.5, 3.5)):
        r.box("Stool%d" % i, 2.2, 0.25, z, 0.4, 0.5, 0.4, r.lit((0.4, 0.3, 0.3)), solid=True)
    r.box("BetsBoard", 4.5, 1.8, 0.05, 2.0, 1.2, 0.08, r.lit((0.15, 0.2, 0.18)))
    r.spot("BetsSpot", "br_bets", 4.5, 0.9)
    r.box("Jukebox", 7.4, 0.8, 0.6, 0.9, 1.6, 0.7, r.lit((0.7, 0.3, 0.5)), solid=True)
    r.box("JukeGlow", 7.4, 1.4, 0.98, 0.6, 0.4, 0.04, r.glow((1.0, 0.7, 0.4), 1.2))
    r.pickup("JukeboxPickup", "br_jukebox", 8.55, 0.55)
    lamps(r, r.wall_mat, [("LampA", 6.5, 2.0, 0.12, 0.4, 0.4)])
    r.door("DoorDocks", "br_to_docks", 7.0, 6.0, yaw=180)
    r.npc("Bartender", "br_keeper", 0.6, 2.5, face=(1, 0))
    r.npc("FlyA", "br_fly_a", 2.8, 2.0, face=(-1, 0))
    r.npc("FlyB", "br_fly_b", 3.2, 4.0, face=(0, -1))
    r.npc("FlyC", "br_fly_c", 5.5, 2.0, face=(0, 1))
    r.npc("OldBarfly", "br_old", 6.5, 4.0, face=(-1, 0))
    r.spawns([("from_docks", (7.0, 5.0), (0, -1))])
    r.node("PlayerSpawn", "Marker3D", pos=(7, 0, 5), yaw_deg=180)
    finish(r, "harrow/harrow_bar.tscn")


def road_stub():
    r = start("road_mast_road", "RoadMastRoad", 10, 6, 35, (5, 3), (0, 0), 3.0, (0.4, 0.36, 0.3), (0.5, 0.5, 0.58))
    walls(r)
    r.box("Sign", 5.0, 1.4, 0.2, 3.6, 1.0, 0.1, r.lit((0.85, 0.7, 0.3)))
    r.label("THE ROAD: built in M4-1", 5.0, 2.2, 0.35)
    r.door("DoorBack", "road_to_checkpoint", 2.0, 0.0)
    r.spawns([("from_harrow", (2.0, 1.5), (0, 1))])
    r.node("PlayerSpawn", "Marker3D", pos=(2, 0, 1.5))
    os.makedirs(os.path.join(OUT, "road"), exist_ok=True)
    finish(r, "road/road_mast_road.tscn")


if __name__ == "__main__":
    os.makedirs(os.path.join(OUT, "harrow"), exist_ok=True)
    square(); docks(); checkpoint(); home(); courier(); store(); gear(); dock_office(); bar(); road_stub()
    print("wrote the Harrow rooms and the road stub")
