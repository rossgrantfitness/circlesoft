#!/usr/bin/env python3
"""Writes the three graybox cars of the ore-train opening (scenes/rooms/train/) and their grim dressing data.

Run from the repo root:  python3 game/scripts/tools/make_train_rooms.py
Blueprint: docs/maps/ore_train.md ("Graybox build notes"). Same conventions as make_harrow_rooms.py: meters, the
origin is the north-west floor corner, +X runs east (the train runs east), +Z runs south toward the camera. Boxes and
flat colors only (placeholder art). What is not geometry (who stands where, what is locked, what is said) is in
game/data/world/placements.json and story_scenes.json; the node names / placement_id here match them (a test checks).

Train-kit rules that live in the geometry:
  - barriers: invisible walls all round, you can't fall off the train (the only ways out are the east couplings and, in the boxcar,
    the jump scene);
  - cover: StaticBody3D in group "cover" with metadata/height (ore heaps, container and freight stacks). The scanner's cone is blocked by cover taller
    than 1.2 m;
  - the lashed crate row is on collision layer 16: only Red (mask 17) collides with it, so she hops it and an inspector walks through.
"""
import json
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
from make_harrow_rooms import H, start, finish, yaw_to  # noqa: E402
from make_grim_dressing import P, line, TEAL, SODIUM, PINK  # noqa: E402

DRESSING = os.path.join(os.path.dirname(__file__), "..", "..", "data", "world", "look_dressing.json")
ROOMS = ("train_flatcar", "train_hopper", "train_boxcar")

DECK = (0.5, 0.43, 0.38)
WALL = (0.45, 0.4, 0.38)
IRON = (0.32, 0.33, 0.37)
HEAP = (0.27, 0.23, 0.21)
CONTAINER_RED = (0.62, 0.27, 0.22)
CONTAINER_BLUE = (0.26, 0.4, 0.58)
FREIGHT = (0.55, 0.45, 0.33)
LASHED = (0.66, 0.46, 0.3)


class T(H):
    """H plus the train kit: cover bodies, heaps, the layer-16 crate row, scrolling planes."""

    def body(self, name, x, z, sx, sy, sz, tint, cover=False, layer=None, tex="checker_128", uv=(1, 1)):
        """A solid box standing on the deck. cover=True: group "cover" with its height in metadata (the scanner reads both)."""
        extra = []
        if layer is not None:
            extra.append("collision_layer = %d\ncollision_mask = 0" % layer)
        if cover:
            extra.append("metadata/height = %s" % sy)
        self.node(name, "StaticBody3D", ".", (x, 0, z), groups=["cover", "fade_occluder"] if cover else None, extra="\n".join(extra))
        mesh = self.box_mesh((sx, sy, sz))
        self.node(name + "Mesh", "MeshInstance3D", name, (0, sy / 2.0, 0), extra="mesh = %s\nsurface_material_override/0 = %s" % (mesh, self.lit(tint, uv, tex)))
        self.node(name + "Shape", "CollisionShape3D", name, (0, sy / 2.0, 0), extra="shape = %s" % self.box_shape((sx, sy, sz)))

    def heap(self, name, x, z, sx, sz, h=1.5):
        """An ore heap: an 8-sided cone, scaled to sx by sz at its foot. Cover (taller than 1.2 m), not climbable."""
        self.node(name, "StaticBody3D", ".", (x, 0, z), groups=["cover", "fade_occluder"], extra="metadata/height = %s" % h)
        cone = self.sub("CylinderMesh", "top_radius = 0.28\nbottom_radius = 1.0\nheight = %s\nradial_segments = 8\nrings = 1" % h)
        self.nodes.append('[node name="%sMesh" type="MeshInstance3D" parent="%s"]\ntransform = Transform3D(%s, 0, 0, 0, 1, 0, 0, 0, %s, 0, %s, 0)\n'
                          'mesh = %s\nsurface_material_override/0 = %s\n' % (name, name, sx / 2.0, sz / 2.0, h / 2.0, cone, self.lit(HEAP, (2, 1), "checker_64")))
        self.node(name + "Shape", "CollisionShape3D", name, (0, h / 2.0, 0), extra="shape = %s" % self.box_shape((sx, h, sz)))

    def barrier(self, name, x, z, sx, sz):
        self.collide(name, x, 1.5, z, sx, 3, sz)

    def scroll(self, name, x, y, z, sx, sz, tint, speed, uv):
        """A plane whose texture slides past (the rail bed, the harbor): unlit, so the grime pass leaves it alone."""
        shader = self.ext_res("Shader", "res://shaders/psx_unlit.gdshader")
        tex = self.ext_res("Texture2D", "res://art/placeholder/textures/checker_64.png")
        material = self.sub("ShaderMaterial", "shader = %s\nshader_parameter/albedo_texture = %s\nshader_parameter/uv_scale = Vector2(%s, %s)\n"
                            "shader_parameter/albedo_tint = Color(%s, %s, %s, 1)\nshader_parameter/emission_energy = 1.0" % (shader, tex, uv[0], uv[1], tint[0], tint[1], tint[2]))
        mesh = self.sub("PlaneMesh", "size = Vector2(%s, %s)" % (sx, sz))
        script = self.ext_res("Script", "res://scripts/field/scroll_texture.gd")
        self.node(name, "MeshInstance3D", ".", (x, y, z), extra="script = %s\nspeed = Vector2(%s, 0)\nmesh = %s\nmaterial_override = %s" % (script, speed, mesh, material))

    def enemy(self, name, pid, x, z, face=(1, 0)):
        self.node(name, "", ".", (x, 0, z), yaw_deg=yaw_to(*face), instance=self.inst("res://scenes/props/map_enemy.tscn"), extra='placement_id = "%s"' % pid)

    def carried_crate(self):
        script = self.ext_res("Script", "res://scripts/field/carried_crate.gd")
        self.node("CarriedCrate", "Node3D", ".", extra="script = %s" % script)

    def deck(self, w, d):
        """The car's floor edge: a dark slab under the plane, so the deck has thickness from the camera."""
        self.box("DeckSlab", w / 2.0, -0.3, d / 2.0, w, 0.6, d, self.lit(IRON, (w / 2.0, d / 2.0), "checker_64"))
        self.box("DeckLip", w / 2.0, -0.12, d + 0.08, w, 0.28, 0.16, self.lit((0.22, 0.2, 0.2), (w / 2.0, 1), "checker_64"))

    def barriers(self, w, d, north=True):
        if north:
            self.barrier("BarrierN", w / 2.0, -0.1, w + 2, 0.2)
        self.barrier("BarrierS", w / 2.0, d + 0.1, w + 2, 0.2)
        self.barrier("BarrierW", -0.1, d / 2.0, 0.2, d)
        self.barrier("BarrierE", w + 0.1, d / 2.0, 0.2, d)

    def moving_world(self, w, d, north_water=True):
        """South of the deck the rail bed rushes by, past it the black water; the north side is water as well."""
        self.scroll("RailBed", w / 2.0, -1.0, d + 2.5, w + 30, 5.0, (0.3, 0.28, 0.27), 1.6, (14, 2))
        self.scroll("HarborS", w / 2.0, -1.5, d + 11.0, w + 30, 12.0, (0.08, 0.14, 0.28), 0.25, (10, 4))
        if north_water:
            self.scroll("HarborN", w / 2.0, -1.5, -9.0, w + 30, 18.0, (0.08, 0.14, 0.28), 0.25, (10, 6))


def lantern(r, x, y, z, parent="."):
    """The chalked lantern on Watch Zero's lids: a pale unlit quad."""
    r.box("ChalkLantern", x, y, z, 0.38, 0.4, 0.03, r.glow((0.95, 0.95, 0.85), 0.8), parent=parent)


# ============================================================ C1 the flatcar
def flatcar():
    w, d = 20.0, 6.0
    r = start_car("train_flatcar", "TrainFlatcar", w, d, yaw=20, cam=((10, 3), (10, 0)), wall_h=3.0)
    r.deck(w, d)
    r.moving_world(w, d)
    r.barriers(w, d)
    # the rear car's end wall (scenery) and the locked rear coupling
    r.box("RearWall", -0.15, 1.5, d / 2.0, 0.3, 3.0, d, r.wall_mat, parent="Walls")
    r.box("RearCoupling", -0.4, 0.35, 3.0, 0.8, 0.3, 0.5, r.lit(IRON))
    # two container stacks along the far side with a 4 m gap between them: the pocket to slip into
    r.body("ContainerA", 5.5, 0.6, 5.0, 2.4, 1.2, CONTAINER_RED, cover=True)
    r.body("ContainerB", 14.5, 0.6, 5.0, 2.4, 1.2, CONTAINER_BLUE, cover=True)
    for i, x in enumerate((3.4, 5.5, 7.6, 12.4, 14.5, 16.6)):
        r.box("ContainerRib%d" % i, x, 1.2, 1.22, 0.1, 2.3, 0.05, r.lit((0.25, 0.14, 0.12)))
    # the lashed crate row: full width at x=9, on layer 16 (Red hops it; an inspector walks through it)
    count = 7
    step = d / count
    for i in range(count):
        r.body("Lashed%d" % i, 9.0, step * (i + 0.5), 0.9, 0.9, step - 0.04, LASHED, layer=16)
    r.box("LashStrap", 9.0, 0.93, d / 2.0, 0.12, 0.04, d, r.lit((0.18, 0.16, 0.14)))
    # Red's crate (she sits on it in the opening scene; the scene hides it and the box rides on her back)
    r.box("SeatCrate", 2.0, 0.45, 3.8, 0.9, 0.9, 0.9, r.lit((0.78, 0.55, 0.35)))
    lantern(r, 2.0, 0.55, 4.26)
    r.spot("CrateSpot", "tr_fc_crate", 2.0, 4.6)
    r.spot("LightsSpot", "tr_fc_lights", 18.0, 3.0)
    r.door("DoorEast", "tr_fc_east", w, 3.0, yaw=-90)
    r.door("DoorRear", "tr_fc_west", 0, 3.0, yaw=90)
    r.enemy("InspectorA", "tr_insp_fc", 0.8, 3.0)
    r.carried_crate()
    r.spawns([("start", (3.0, 3.8), (1, 0)), ("from_debug", (3.0, 3.8), (1, 0))])
    r.node("PlayerSpawn", "Marker3D", pos=(3.0, 0, 3.8), yaw_deg=90)
    finish(r, "train/train_flatcar.tscn")


def start_car(room_id, title, w, d, yaw, cam, wall_h):
    return start(room_id, title, w, d, yaw, cam[0], cam[1], wall_h, DECK, WALL, "checker_64", room_class=T)


# ============================================================ C2 the hopper
def hopper():
    w, d = 22.0, 7.0
    r = start_car("train_hopper", "TrainHopper", w, d, yaw=20, cam=((11, 3.75), (12, 0.5)), wall_h=2.5)
    r.deck(w, d)
    r.moving_world(w, d, north_water=False)
    r.barriers(w, d)
    r.box("EndWall", -0.15, 1.25, d / 2.0, 0.3, 2.5, d, r.wall_mat, parent="Walls")
    r.box("BinWallN", w / 2.0, 1.25, -0.15, w, 2.5, 0.3, r.wall_mat, parent="Walls")
    r.box("BinRimS", w / 2.0, 0.3, d + 0.05, w, 0.6, 0.1, r.lit(IRON, (w / 2.0, 1), "checker_64"))
    # the catwalk along the north wall: a darker grating strip with a hazard edge
    r.plane("Catwalk", w / 2.0, 0.02, 0.6, w - 0.4, 1.2, r.lit((0.3, 0.3, 0.33), (w / 1.5, 1), "checker_64"))
    r.box("CatwalkEdge", w / 2.0, 0.03, 1.2, w - 0.4, 0.03, 0.08, r.lit((0.85, 0.7, 0.2)))
    # ore heaps: cover, 1.5 m, not climbable (the patrol lane runs between the two rows)
    r.heap("HeapA", 4.5, 5.2, 3.0, 1.8)
    r.heap("HeapB", 9.0, 2.2, 3.0, 1.8)
    r.heap("HeapC", 13.5, 5.2, 3.0, 1.8)
    r.heap("HeapD", 17.0, 2.2, 2.5, 1.8)
    # the quota stencil on the bin wall
    r.box("Stencil", 7.0, 1.5, 0.03, 1.8, 0.7, 0.03, r.lit((0.78, 0.76, 0.7)))
    r.box("StencilBar", 7.0, 1.5, 0.05, 1.5, 0.12, 0.02, r.lit((0.2, 0.2, 0.22)))
    r.spot("StencilSpot", "tr_hp_stencil", 7.0, 1.6)
    r.spot("OreSpot", "tr_hp_ore", 11.6, 4.0)
    # the brake hut at the east end, and the crew locker on the catwalk
    r.body("BrakeHut", 20.5, 1.0, 2.0, 2.4, 2.0, WALL, cover=True)
    r.box("HutWindow", 20.5, 1.7, 2.03, 0.9, 0.5, 0.04, r.glow((1.0, 0.82, 0.45), 1.2))
    r.crate("Locker", "tr_locker", 11.0, 0.5)
    r.door("DoorEast", "tr_hp_east", w, 3.5, yaw=-90)
    r.door("DoorRear", "tr_hp_west", 0, 3.5, yaw=90)
    r.npc("HutInspector", "tr_hut_inspector", 20.5, 2.4, face=(-1, 0))
    r.enemy("InspectorB", "tr_insp_hp", 3.0, 3.7)
    r.carried_crate()
    r.spawns([("from_flatcar", (1.2, 3.5), (1, 0)), ("after_fight", (19.0, 3.5), (1, 0))])
    r.node("PlayerSpawn", "Marker3D", pos=(1.2, 0, 3.5), yaw_deg=90)
    finish(r, "train/train_hopper.tscn")


# ============================================================ C3 the boxcar
def boxcar():
    w, d = 16.0, 6.0
    r = start_car("train_boxcar", "TrainBoxcar", w, d, yaw=30, cam=((8, 3.25), (6, 0.5)), wall_h=3.0)
    r.deck(w, d)
    r.moving_world(w, d, north_water=False)
    r.barriers(w, d)
    r.box("EndWallW", -0.15, 1.5, d / 2.0, 0.3, 3.0, d, r.wall_mat, parent="Walls")
    r.box("EndWallE", w + 0.15, 1.5, d / 2.0, 0.3, 3.0, d, r.wall_mat, parent="Walls")
    r.box("SideWallN", w / 2.0, 1.5, -0.15, w, 3.0, 0.3, r.wall_mat, parent="Walls")
    r.box("RoofEdge", w / 2.0, 3.1, -0.1, w, 0.2, 0.7, r.lit((0.2, 0.2, 0.22)))
    # the south side: a 1 m rail except the open door (x 9 to 14), and the rolled-back door leaf
    rail = r.lit(IRON)
    r.box("RailA", 4.5, 0.5, d + 0.05, 9.0, 1.0, 0.08, rail)
    r.box("RailB", 15.0, 0.5, d + 0.05, 2.0, 1.0, 0.08, rail)
    r.box("DoorLeaf", 14.6, 1.4, d + 0.05, 1.2, 2.8, 0.1, r.lit((0.4, 0.28, 0.22)), fade=True)
    r.box("DoorFrameA", 9.0, 1.5, d + 0.05, 0.14, 3.0, 0.14, rail)
    r.box("DoorFrameB", 14.0, 1.5, d + 0.05, 0.14, 3.0, 0.14, rail)
    # the freight platform's lights slide into view in the doorway (they are far out, past the harbor)
    for i, x in enumerate((6.0, 11.0, 16.0, 21.0)):
        r.box("PlatformLamp%d" % i, x, 1.6, d + 9.0, 0.5, 0.5, 0.5, r.glow((1.0, 0.82, 0.45), 1.5))
    r.box("Platform", 14.0, 0.4, d + 9.5, 26.0, 0.6, 3.0, r.lit((0.35, 0.33, 0.33)))
    # freight stacks: cover, 1.8 m
    r.body("StackA", 3.5, 0.9, 2.0, 1.8, 1.5, FREIGHT, cover=True)
    r.body("StackB", 6.0, 3.3, 2.0, 1.8, 1.5, (0.5, 0.4, 0.3), cover=True)
    r.body("StackC", 9.0, 0.9, 2.0, 1.8, 1.5, FREIGHT, cover=True)
    r.body("StackD", 12.5, 3.2, 1.5, 1.8, 1.5, (0.5, 0.4, 0.3), cover=True)
    r.box("ManifestBoard", 13.5, 1.6, 0.03, 1.2, 0.8, 0.03, r.lit((0.78, 0.76, 0.7)))
    r.spot("DitchSpot", "tr_ditch", 11.5, 5.4)
    r.door("DoorRear", "tr_bx_west", 0, 3.0, yaw=90)
    r.enemy("InspectorC", "tr_insp_bx_a", 0.8, 2.0)
    r.enemy("InspectorD", "tr_insp_bx_b", 0.8, 4.5)
    r.carried_crate()
    r.spawns([("from_hopper", (1.5, 3.0), (1, 0))])
    r.node("PlayerSpawn", "Marker3D", pos=(1.5, 0, 3.0), yaw_deg=90)
    finish(r, "train/train_boxcar.tscn")


# ============================================================ grim dressing data (added to look_dressing.json)
def key_light():
    return {"color": "#c4d4e4", "energy": 0.8, "dir_deg": [-48.0, 36.0]}


def dressing():
    flat = {"key_light": key_light(), "items": [
        P("skyline", [10.0, 0, -9.0], length=60.0, count=16, seed=31, base_y=2.5, max_height=8.0),
        P("loudspeaker", [0.5, 2.7, 5.4]),
        P("floodlight", [1.2, 0, 5.2], aim_deg=-25.0, height=2.6),
        line("cable", [3.0, 3.6, 1.3], [17.0, 3.6, 1.3], sag=0.45, strands=3, segments=8),
        line("pipe", [0.2, 2.8, 0.3], [19.8, 2.8, 0.3], radius=0.06),
        P("stripes", [10.0, 0.03, 5.8], size=[18.0, 0.03, 0.2]),
        P("puddle", [14.0, 0, 4.4], size=[1.8, 1.0]),
        P("smear", [18.5, 0, 1.2], size=[1.2, 1.6], color=SODIUM, energy=0.4),
        P("poster", [19.7, 1.7, 5.5], 90, variant=0, size=[0.7, 1.05]),
    ]}
    hopper_kit = {"key_light": key_light(), "items": [
        P("skyline", [11.0, 0, -9.0], length=64.0, count=16, seed=32, base_y=2.5, max_height=8.0),
        P("neon", [4.0, 2.0, 0.13], text="QUOTA", color=SODIUM, height=0.34, pattern="1111h111011", phase=3, light_energy=1.0, light_range=3.0),
        P("loudspeaker", [2.8, 2.3, 0.3]),
        line("pipe", [0.2, 2.2, 0.2], [21.8, 2.2, 0.2], radius=0.07),
        line("cable", [13.0, 2.4, 0.4], [21.0, 2.4, 0.4], sag=0.3, strands=2, segments=6),
        P("steam", [8.0, 0, 6.4], rise=0.9),
        P("steam", [20.8, 0, 3.2], rise=0.9),
        P("stripes", [11.0, 0.03, 1.0], size=[20.0, 0.03, 0.12]),
        P("smear", [19.0, 0, 5.0], size=[1.0, 1.6], color=SODIUM, energy=0.35),
        P("puddle", [15.5, 0, 3.7], size=[1.6, 0.8]),
    ]}
    box = {"key_light": key_light(), "items": [
        P("hang_lamp", [7.0, 3.0, 2.5], drop=0.5, color=SODIUM, energy=1.4, range=5.0),
        P("poster", [3.0, 1.7, 0.08], variant=1, size=[0.7, 1.05]),
        P("poster", [14.8, 1.7, 0.08], variant=2, size=[0.62, 0.93]),
        line("pipe", [0.2, 2.7, 0.2], [15.8, 2.7, 0.2], radius=0.06),
        line("cable", [0.5, 2.9, 0.4], [15.5, 2.9, 0.4], sag=0.3, strands=2, segments=6),
        P("stripes", [11.5, 0.03, 5.75], size=[5.0, 0.03, 0.18]),
        P("smear", [11.5, 0, 5.4], size=[3.0, 0.8], color=TEAL, energy=0.3),
        P("puddle", [4.5, 0, 5.0], size=[1.4, 0.8]),
    ]}
    return {"train_flatcar": flat, "train_hopper": hopper_kit, "train_boxcar": box}


def write_dressing():
    with open(DRESSING) as f:
        data = json.load(f)
    for key, kit in dressing().items():
        data["rooms"][key] = kit
    with open(DRESSING, "w") as f:
        json.dump(data, f, indent=1)


if __name__ == "__main__":
    os.makedirs(os.path.join(os.path.dirname(__file__), "..", "..", "scenes", "rooms", "train"), exist_ok=True)
    flatcar(); hopper(); boxcar()
    write_dressing()
    print("wrote the ore-train cars and their dressing")
