#!/usr/bin/env python3
"""Throwaway graybox rooms for the slice room script (VS-5): scenes/slice/graybox/gb_*.tscn.
Three plain boxes joined by doors in data/slice/graybox_rooms.json: a town hub (no fighting), a yard with enemies, a
vault checkpoint. The real market and junkyard come from the Level Designer's generators; delete nothing, just stop using
these. Run from the game folder: python3 scripts/tools/make_graybox_rooms.py"""
import math, os

OUT = "scenes/slice/graybox"
ROOMS = {
    # id: (half x, half z, doors [(placement_id, x, z, facing)], spawns {name: (x, z)})
    "gb_hub": (8, 8, [("gb_hub_to_yard", 0, -8, "north")], {"start": (0, 3), "from_yard": (0, -5.5)}),
    "gb_yard": (14, 14, [("gb_yard_to_hub", 0, 14, "south"), ("gb_yard_to_vault", 0, -14, "north")],
                {"from_hub": (0, 11.5), "from_vault": (0, -11.5)}),
    "gb_vault": (8, 8, [("gb_vault_to_yard", 0, 8, "south")], {"from_yard": (0, 5.5)}),
}


def build(room_id, hx, hz, doors, spawns):
    lines = ['[gd_scene load_steps=4 format=3]', '',
             '[ext_resource type="PackedScene" path="res://scenes/props/door.tscn" id="1_door"]',
             '[ext_resource type="PackedScene" path="res://scenes/props/job_board.tscn" id="2_board"]',
             '[ext_resource type="PackedScene" path="res://scenes/actors/placed_npc.tscn" id="3_npc"]',
             '[ext_resource type="Script" path="res://scripts/ui/shop/shop_counter.gd" id="4_shop"]',
             '[ext_resource type="Script" path="res://scripts/save/save_lamp.gd" id="5_lamp"]', '',
             '[sub_resource type="Environment" id="Env_1"]', 'background_mode = 1',
             'background_color = Color(0.12, 0.145, 0.25, 1)', 'ambient_light_source = 2',
             'ambient_light_color = Color(0.7, 0.7, 0.95, 1)', 'ambient_light_energy = 0.9', '',
             '[sub_resource type="StandardMaterial3D" id="Mat_floor"]', 'albedo_color = Color(0.35, 0.36, 0.4, 1)', '',
             '[sub_resource type="StandardMaterial3D" id="Mat_wall"]', 'albedo_color = Color(0.5, 0.42, 0.38, 1)', '']
    boxes = []   # (name, pos, size, mat)
    boxes.append(("Floor", (0, -0.2, 0), (hx * 2, 0.4, hz * 2), "Mat_floor"))
    h = 4.0
    boxes.append(("WallN", (0, h / 2, -hz - 0.5), (hx * 2 + 2, h, 1), "Mat_wall"))
    boxes.append(("WallS", (0, h / 2, hz + 0.5), (hx * 2 + 2, h, 1), "Mat_wall"))
    boxes.append(("WallW", (-hx - 0.5, h / 2, 0), (1, h, hz * 2), "Mat_wall"))
    boxes.append(("WallE", (hx + 0.5, h / 2, 0), (1, h, hz * 2), "Mat_wall"))
    for i, (name, pos, size, mat) in enumerate(boxes):
        lines += ['[sub_resource type="BoxMesh" id="Mesh_%d"]' % i, 'size = Vector3(%g, %g, %g)' % size, '',
                  '[sub_resource type="BoxShape3D" id="Shape_%d"]' % i, 'size = Vector3(%g, %g, %g)' % size, '']
    lines[0] = '[gd_scene load_steps=%d format=3]' % (3 + 2 * len(boxes) + 4)
    lines += ['[node name="Level" type="Node3D"]', '',
              '[node name="WorldEnvironment" type="WorldEnvironment" parent="."]', 'environment = SubResource("Env_1")', '',
              '[node name="Sun" type="DirectionalLight3D" parent="."]',
              'transform = Transform3D(1, 0, 0, 0, 0.8, 0.6, 0, -0.6, 0.8, 0, 6, 0)', 'light_energy = 0.9', '',
              '[node name="Solid" type="StaticBody3D" parent="."]', '']
    for i, (name, pos, size, mat) in enumerate(boxes):
        lines += ['[node name="%sMesh" type="MeshInstance3D" parent="."]' % name,
                  'transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, %g, %g, %g)' % pos,
                  'mesh = SubResource("Mesh_%d")' % i,
                  'surface_material_override/0 = SubResource("%s")' % mat, '',
                  '[node name="%sShape" type="CollisionShape3D" parent="Solid"]' % name,
                  'transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, %g, %g, %g)' % pos,
                  'shape = SubResource("Shape_%d")' % i, '']
    lines += ['[node name="Spawns" type="Node3D" parent="."]', '']
    for name, (x, z) in spawns.items():
        lines += ['[node name="%s" type="Marker3D" parent="Spawns"]' % name,
                  'transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, %g, 0, %g)' % (x, z), '']
    for pid, x, z, facing in doors:
        # a door's local +Z side is the room side; "south" wall doors face -Z (rotated half a turn)
        c, s = (1, 0) if facing == "north" else (-1, 0)
        lines += ['[node name="%s" parent="." instance=ExtResource("1_door")]' % pid.title().replace("_", ""),
                  'transform = Transform3D(%d, 0, %d, 0, 1, 0, %d, 0, %d, %g, 0, %g)' % (c, s, -s, c, x, z),
                  'placement_id = "%s"' % pid, '']
    if room_id == "gb_hub":
        # town systems props: a save terminal that rests, a shop counter, a job board and a townsperson who barks
        lines += ['[node name="Terminal" type="Node3D" parent="."]',
                  'transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 5, 0, 5)',
                  'script = ExtResource("5_lamp")', 'rest = true', 'room_id = "gb_hub"', 'spawn_id = "start"', '',
                  '[node name="Counter" type="Node3D" parent="."]',
                  'transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, -5, 0, 5)',
                  'script = ExtResource("4_shop")', 'shop_id = "test_general"', '',
                  '[node name="Board" parent="." instance=ExtResource("2_board")]',
                  'transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 6.5)', 'placement_id = "gb_board"', '',
                  '[node name="Vendor" parent="." instance=ExtResource("3_npc")]',
                  'transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 3, 0, -2)', 'placement_id = "gb_vendor"', '']
    return "\n".join(lines)


os.makedirs(OUT, exist_ok=True)
for room_id, (hx, hz, doors, spawns) in ROOMS.items():
    with open(os.path.join(OUT, room_id + ".tscn"), "w") as f:
        f.write(build(room_id, hx, hz, doors, spawns))
    print("wrote", room_id)
