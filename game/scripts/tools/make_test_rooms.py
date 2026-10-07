#!/usr/bin/env python3
"""Writes the two graybox exploration test rooms (scenes/rooms/test_a.tscn, test_b.tscn).

Run from the repo root:  python3 game/scripts/tools/make_test_rooms.py
The rooms are plain boxes in the PSX look: a door, a locked door and its key crate, pickups, a crate,
a climb, a hop and patrolling / guarding map enemies. What is in each crate or behind each door
comes from game/data/world/placements.json; the node names here carry the placement ids.
Edit this script (or the .tscn in the editor) and keep the ids in sync with placements.json and rooms.json.
"""
import math
import os

OUT = os.path.join(os.path.dirname(__file__), "..", "..", "scenes", "rooms")


class Room:
    def __init__(self, room_id, x0, x1, z0, z1):
        self.room_id, self.x0, self.x1, self.z0, self.z1 = room_id, x0, x1, z0, z1
        self.ext = {}
        self.subs = []
        self.nodes = []
        self._box_meshes = {}
        self._box_shapes = {}
        self.sub_count = 0

    def ext_res(self, kind, path):
        if path not in self.ext:
            self.ext[path] = (len(self.ext) + 1, kind)
        return 'ExtResource("%d_r")' % self.ext[path][0]

    def sub(self, kind, body):
        self.sub_count += 1
        sid = "%s_%d" % (kind, self.sub_count)
        self.subs.append('[sub_resource type="%s" id="%s"]\n%s\n' % (kind, sid, body))
        return 'SubResource("%s")' % sid

    def material(self, tint, uv=(1, 1), affine=0.3, tex="checker_128"):
        shader = self.ext_res("Shader", "res://shaders/psx_lit.gdshader")
        tex_res = self.ext_res("Texture2D", "res://art/placeholder/textures/%s.png" % tex)
        return self.sub("ShaderMaterial", "shader = %s\nshader_parameter/albedo_texture = %s\nshader_parameter/uv_scale = Vector2(%s, %s)\n"
                        "shader_parameter/albedo_tint = Color(%s, %s, %s, 1)\nshader_parameter/affine_amount = %s" %
                        (shader, tex_res, uv[0], uv[1], tint[0], tint[1], tint[2], affine))

    def box_mesh(self, size):
        if size not in self._box_meshes:
            self._box_meshes[size] = self.sub("BoxMesh", "size = Vector3(%s, %s, %s)" % size)
        return self._box_meshes[size]

    def box_shape(self, size):
        if size not in self._box_shapes:
            self._box_shapes[size] = self.sub("BoxShape3D", "size = Vector3(%s, %s, %s)" % size)
        return self._box_shapes[size]

    def node(self, name, kind, parent=".", pos=(0, 0, 0), yaw_deg=0.0, extra="", instance=None, groups=None):
        c, s = math.cos(math.radians(yaw_deg)), math.sin(math.radians(yaw_deg))
        t = "Transform3D(%.4f, 0, %.4f, 0, 1, 0, %.4f, 0, %.4f, %s, %s, %s)" % (c, s, -s, c, pos[0], pos[1], pos[2])
        head = '[node name="%s"' % name
        if instance:
            head += ' parent="%s" instance=%s' % (parent, instance)
        else:
            head += ' type="%s"' % kind
            if parent:
                head += ' parent="%s"' % parent
        if groups:
            head += ' groups=[%s]' % ", ".join('"%s"' % g for g in groups)
        head += "]"
        body = ""
        if pos != (0, 0, 0) or yaw_deg:
            body += t + "\n" if not instance else ""
            if instance:
                body += "transform = " + t + "\n"
        else:
            pass
        if not instance and body:
            body = "transform = " + body.replace("Transform3D", "Transform3D", 1)
        self.nodes.append(head + "\n" + body + (extra + "\n" if extra else ""))

    def solid_box(self, name, pos, size, material, parent=".", fade=False):
        mesh = self.box_mesh(size)
        self.node(name, "MeshInstance3D", parent, pos, extra="mesh = %s\nsurface_material_override/0 = %s" % (mesh, material),
                  groups=["fade_occluder"] if fade else None)
        shape = self.box_shape(size)
        self.node(name + "Shape", "CollisionShape3D", "Collision", pos, extra="shape = %s" % shape)

    def write(self, filename):
        ext_lines = []
        for path, (idx, kind) in sorted(self.ext.items(), key=lambda kv: kv[1][0]):
            ext_lines.append('[ext_resource type="%s" path="%s" id="%d_r"]' % (kind, path, idx))
        text = "[gd_scene load_steps=%d format=3]\n\n" % (len(self.ext) + len(self.subs) + 1)
        text += "\n".join(ext_lines) + "\n\n" + "\n".join(self.subs) + "\n" + "\n".join(self.nodes)
        with open(os.path.join(OUT, filename), "w") as f:
            f.write(text)


def build(room_id, title, x0, x1, z0, z1, camera_pos):
    r = Room(room_id, x0, x1, z0, z1)
    w, d = x1 - x0, z1 - z0
    cx, cz = (x0 + x1) / 2.0, (z0 + z1) / 2.0
    script_room = r.ext_res("Script", "res://scripts/field/field_room.gd")
    player = r.ext_res("PackedScene", "res://scenes/actors/player.tscn")
    look = r.ext_res("Script", "res://scripts/core/psx_room_look.gd")
    cam_script = r.ext_res("Script", "res://scripts/field/diorama_camera.gd")
    bounds_script = r.ext_res("Script", "res://scripts/field/camera_bounds.gd")
    env = r.sub("Environment", "background_mode = 1\nbackground_color = Color(0.12156863, 0.14509805, 0.2509804, 1)\n"
                "ambient_light_source = 2\nambient_light_color = Color(0.7, 0.7, 0.95, 1)")
    r.nodes.append('[node name="%s" type="Node3D"]\nscript = %s\nplayer_scene = %s\nroom_id = "%s"\n' % (title, script_room, player, room_id))
    r.node("RoomLook", "Node", extra="script = %s\nfog_color = Color(0.12156863, 0.14509805, 0.2509804, 1)\nfog_near = 13.0\nfog_far = 20.0\n"
           "ambient_color = Color(0.7, 0.7, 0.95, 1)\nambient_energy = 1.0" % look)
    r.node("WorldEnvironment", "WorldEnvironment", extra="environment = %s" % env)
    floor_mat = r.material((1, 1, 1), (w / 2.0, d / 2.0), 0.3, "checker_64")
    wall_mat = r.material((1, 1, 1), (w / 4.0, 0.75), 0.3, "wall_128")
    wall_left_mat = r.material((1, 1, 1), (d / 4.0, 0.75), 0.3, "wall_128")
    # floor and walls
    floor_mesh = r.sub("PlaneMesh", "size = Vector2(%s, %s)\nsubdivide_width = %d\nsubdivide_depth = %d" % (w, d, int(w) - 1, int(d) - 1))
    r.node("Floor", "MeshInstance3D", pos=(cx, 0, cz), extra="mesh = %s\nsurface_material_override/0 = %s" % (floor_mesh, floor_mat))
    back_mesh = r.sub("PlaneMesh", "size = Vector2(%s, 3)\nsubdivide_width = %d\norientation = 2" % (w, int(w) // 2))
    r.node("WallBack", "MeshInstance3D", pos=(cx, 1.5, z0), extra="mesh = %s\nsurface_material_override/0 = %s" % (back_mesh, wall_mat))
    left_mesh = r.sub("PlaneMesh", "size = Vector2(%s, 3)\nsubdivide_width = %d\norientation = 2" % (d, int(d) // 2))
    r.nodes.append('[node name="WallLeft" type="MeshInstance3D" parent="."]\ntransform = Transform3D(0, 0, 1, 0, 1, 0, -1, 0, 0, %s, 1.5, %s)\n'
                   'mesh = %s\nsurface_material_override/0 = %s\n' % (x0, cz, left_mesh, wall_left_mat))
    # collision
    r.node("Collision", "StaticBody3D")
    floor_shape = r.box_shape((w, 0.2, d))
    r.node("FloorShape", "CollisionShape3D", "Collision", (cx, -0.1, cz), extra="shape = %s" % floor_shape)
    for nm, pos, size in (("WallBackShape", (cx, 1.5, z0 - 0.1), (w, 3, 0.2)), ("WallLeftShape", (x0 - 0.1, 1.5, cz), (0.2, 3, d)),
                          ("FrontBarrierShape", (cx, 1.5, z1 + 0.1), (w, 3, 0.2)), ("RightBarrierShape", (x1 + 0.1, 1.5, cz), (0.2, 3, d))):
        r.node(nm, "CollisionShape3D", "Collision", pos, extra="shape = %s" % r.box_shape(size))
    # camera
    r.node("CameraBounds", "Node3D", pos=(cx, 0, cz), extra="script = %s\nsize = Vector3(%s, 0, %s)" % (bounds_script, w - 4.2, d - 3.0))
    r.node("CameraRig", "Node3D", extra="script = %s\npitch_deg = 42.0\nyaw_deg = 35.0\nfov_deg = 30.0\ndistance = 11.0" % cam_script)
    return r


def spawns(r, markers):
    r.node("Spawns", "Node3D")
    for name, pos, yaw in markers:
        r.node(name, "Marker3D", "Spawns", pos, yaw_deg=yaw)


def inst(r, path):
    return r.ext_res("PackedScene", path)


def door(r, name, pid, x, z0, yaw=0):
    r.node(name, "", ".", (x, 0, z0), yaw_deg=yaw, instance=inst(r, "res://scenes/props/door.tscn"), extra='placement_id = "%s"' % pid)


def crate(r, name, pid, pos):
    r.node(name, "", ".", pos, instance=inst(r, "res://scenes/props/crate.tscn"), extra='placement_id = "%s"' % pid)


def pickup(r, name, pid, pos):
    r.node(name, "", ".", pos, instance=inst(r, "res://scenes/props/pickup.tscn"), extra='placement_id = "%s"' % pid)


def traversal(r, name, pos, mode, end):
    r.node(name, "", ".", pos, instance=inst(r, "res://scenes/props/traversal_spot.tscn"),
           extra="mode = %d\nend_offset = Vector3(%s, %s, %s)" % (mode, end[0], end[1], end[2]))


def enemy(r, name, pid, pos, yaw):
    r.node(name, "", ".", pos, yaw_deg=yaw, instance=inst(r, "res://scenes/props/map_enemy.tscn"), extra='placement_id = "%s"' % pid)


def room_a():
    r = build("test_a", "TestYardA", -6, 10, -4, 4, None)
    plat_mat = r.material((0.45, 0.55, 0.75), (2, 1))
    spawns(r, [("start", (-4.5, 0, 1.5), 90), ("from_b", (8, 0, -2.8), 0), ("from_vault", (-1.5, 0, -2.8), 0)])
    door(r, "DoorToTestRoom", "test_a_to_test_room", -6, -0.8, 90)
    r.node("PlayerSpawn", "Marker3D", pos=(-4.5, 0, 1.5), yaw_deg=90)
    door(r, "DoorToB", "test_a_to_b", 8, -4)
    door(r, "VaultDoor", "test_a_vault", -1.5, -4)
    crate(r, "KeyCrate", "test_a_key_crate", (-4.8, 0, -2.9))
    pickup(r, "RationPickup", "test_a_ration", (-2.5, 0, 2.4))
    # the climb: a 2.0 high ledge in the back, a spot in front of it
    r.solid_box("Ledge", (3.5, 1.0, -2.6), (3.0, 2.0, 2.0), plat_mat, fade=True)
    traversal(r, "ClimbSpot", (3.5, 0, -1.0), 0, (0.0, 2.0, -1.5))
    pickup(r, "LedgePickup", "test_a_ledge_credits", (3.5, 2.0, -2.6))
    enemy(r, "Grunt", "test_a_grunt", (0.5, 0, 1.0), 90)
    return r


def room_b():
    r = build("test_b", "TestYardB", -5, 9, -4, 4, None)
    fence_mat = r.material((0.7, 0.6, 0.35), (4, 1))
    spawns(r, [("from_a", (-3.5, 0, -2.8), 0), ("vault", (6.5, 0, -2.8), 0)])
    r.node("PlayerSpawn", "Marker3D", pos=(-3.5, 0, -2.8))
    door(r, "DoorToA", "test_b_to_a", -3.5, -4)
    door(r, "VaultExit", "test_b_vault_exit", 6.5, -4)
    # the hop: a 1.6 high fence across the whole room (too tall to jump), a spot on each side
    r.solid_box("Fence", (0.5, 0.8, 0.0), (0.3, 1.6, 8.0), fence_mat, fade=False)
    traversal(r, "HopSpotWest", (-0.4, 0, 0.0), 1, (1.8, 0.0, 0.0))
    traversal(r, "HopSpotEast", (1.4, 0, 0.0), 1, (-1.8, 0.0, 0.0))
    crate(r, "FenceCrate", "test_b_fence_crate", (2.6, 0, -2.6))
    pickup(r, "CoffeePickup", "test_b_coffee", (3.2, 0, 2.4))
    crate(r, "EmptyCrate", "test_b_empty_crate", (-4.0, 0, 2.6))
    enemy(r, "Guard", "test_b_guard", (4.6, 0, -0.8), 0)
    return r


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    room_a().write("test_a.tscn")
    room_b().write("test_b.tscn")
    print("wrote test_a.tscn and test_b.tscn")
