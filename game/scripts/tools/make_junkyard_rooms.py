#!/usr/bin/env python3
"""Writes the four on-foot rooms of the junkyard, J1 to J4 (vertical slice task VS-20): scenes/slice/junkyard/junk_j*.tscn.

Blueprint: docs/maps/junkyard.md (rooms, coordinates, hack targets, fights). Built from the night market kit (make_market_rooms.py) and
junk_kit.py: a plain Node3D level (Main wraps it in an ActionRoom; the room's row is in data/slice/rooms.json), scrap cliffs made from the walkable
rectangles, Ross's city tiles (seam-fixed copies where the atlas has them) and the Technical Artist's prop models.

What the scenes carry for the code that is coming (names are the agreed ones; data/slice/placements.json "hack_targets" and "doors" hold
the rules; data/slice/encounters.json holds who fights):
  * `Spawns`: the arrival markers rooms.json lists.
  * hack targets: Node3D nodes with the HackDoor / HackTerminal / HackCrane / DroneLine / HackLoader scripts (scripts/slice/targets/) and
    target_id = the placement id (hack_j1_door, term_j2_gate, crane_j3, dline_j3, hack_j3_vault, loader_j4).
  * `Encounters/<enc id>`: a Node3D at the encounter's trigger centre, with one Marker3D per spawn ("w1_grunt_0", ...), read from encounters.json so
    the two cannot drift. `Fixtures/<id>`: the wall turrets (turret_j2_a ...) at their mounts, y = the mount height, facing where they should.
  * `Barks/bark_*`: Marker3Ds with metadata radius_m, where Vela's radio lines trigger.
  * `Shutters/*` (J4's Stand), `Breakables/*` (group crane_breakable / loader_smash), doors (`Door` props), save terminals (`SaveLamp`).

Run from the repo root:  python3 game/scripts/tools/make_junkyard_rooms.py
"""
import json
import math
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
import junk_kit as jk  # noqa: E402
from junk_kit import Y, GAME, PROPS, yaw_to  # noqa: E402

SUB = "junkyard"
ENC = json.load(open(os.path.join(GAME, "data", "slice", "encounters.json")))["encounters"]
# what each fixture (turret / drone line) looks at, as a point in the room
FACE = {"turret_j2_a": (30.0, 17.0), "turret_j2_b": (66.0, 22.0), "turret_j4_a": (40.0, 30.0), "turret_j4_b": (40.0, 30.0)}
PROP_SIZE = {"container": (2.58, 2.62, 6.13), "car": (2.0, 1.4, 4.5), "crate_large": (2.05, 2.05, 2.07), "crate_small": (0.82, 0.82, 0.83), "lamp_post": (0.66, 6.76, 0.66)}
PROP_GLB = {"container": "prop_cargo_container.glb", "car": "prop_car_block.glb", "crate_large": "prop_crate_large.glb", "crate_small": "prop_crate_small.glb", "lamp_post": "prop_lamp_post.glb"}


def prop(r, name, kind, x, z, yaw=0.0, y=0.0, solid=True):
    """A placeholder junk prop at its real size with a collision box (the box turns with it)."""
    r.glb(name, PROPS + PROP_GLB[kind], x, y, z, yaw=yaw)
    if solid:
        s = PROP_SIZE[kind]
        r.collide(name + "Shape", x, y + s[1] / 2.0, z, s[0], s[1], s[2], yaw)


def crate_at(r, name, pid, x, y, z):
    r.node(name, "", ".", (x, y, z), instance=r.inst("res://scenes/props/crate.tscn"), extra='placement_id = "%s"' % pid)


def hack_node(r, name, script, tid, x, y, z, yaw=0.0, extra=""):
    path = "res://scripts/slice/targets/%s.gd" % script
    r.node(name, "Node3D", ".", (x, y, z), yaw_deg=yaw, extra='script = %s\ntarget_id = &"%s"%s' % (r.ext_res("Script", path), tid, ("\n" + extra) if extra else ""))


def save_terminal(r, name, room_id, spawn_id, x, z, yaw=0.0):
    r.node(name, "Node3D", ".", (x, 0, z), yaw_deg=yaw,
           extra='script = %s\nroom_id = "%s"\nspawn_id = "%s"\nrest = false\nreach = 1.8\nbuild_placeholder = false' % (r.ext_res("Script", "res://scripts/save/save_lamp.gd"), room_id, spawn_id))
    # the terminal's look: a post, a lit screen and a base
    r.box(name + "Post", x, 0.6, z, 0.5, 1.2, 0.5, r.lit((0.3, 0.33, 0.38)), solid=True)
    r.box(name + "Screen", x, 1.3, z + 0.1, 0.6, 0.4, 0.06, r.glow((0.3, 1.0, 0.85), 1.2))
    r.omni(name + "Glow", x, 1.8, z + 0.6, (0.3, 1.0, 0.85), 0.9, 4.5)


def encounters(r, room_id, fixture_yaw=None):
    """Encounters/<id> (at the trigger centre) with a Marker3D per spawn, and Fixtures/<id> for turrets and drone lines, from encounters.json."""
    mine = {k: v for k, v in ENC.items() if v["room"] == room_id}
    r.holder("Encounters")
    r.holder("Fixtures")
    for eid, enc in mine.items():
        trig = enc.get("trigger", {})
        cx, cz = trig.get("centre", [0.0, 0.0])
        r.marker(eid, "Encounters", cx, 0.0, cz, kind="Node3D", meta={"kind": enc["kind"], "range_m": float(trig.get("range_m", 0.0)), "trigger": trig.get("type", "")})
        for wave in enc.get("waves", []):
            for i, sp in enumerate(wave["spawn"]):
                ax, az = sp["at"]
                r.marker("%s_%s_%d" % (wave["id"], sp["enemy"], i), "Encounters/" + eid, ax - cx, 0.1, az - cz,
                         meta={"enemy": sp["enemy"], "count": int(sp.get("count", 1)), "spread_m": float(sp.get("spread_m", 0.0)), "wave": wave["id"],
                               "entrance": sp.get("entrance", "")})
        for fx in enc.get("fixtures", []):
            ax, az = fx["at"]
            face = (FACE.get(fx["id"], (ax, az + 1.0)))
            yaw = yaw_to(face[0] - ax, face[1] - az)
            r.marker(fx["id"], "Fixtures", ax, float(fx.get("up_m", 0.0)), az, yaw=yaw, meta={"enemy": fx["enemy"], "encounter": eid})
    return mine


def barks(r, items):
    """Vela's radio triggers: (id, x, z, radius)."""
    r.holder("Barks")
    for bid, x, z, rad in items:
        r.marker(bid, "Barks", x, 1.0, z, meta={"radius_m": rad})


def door(r, name, pid, x, z, yaw):
    r.door(name, pid, x, z, yaw=yaw)


def burn_barrel(r, name, x, z):
    r.cyl(name, x, 0.45, z, 0.35, 0.9, r.lit((0.35, 0.3, 0.27)), solid=True)
    r.cyl(name + "Fire", x, 0.95, z, 0.28, 0.12, r.glow((1.0, 0.5, 0.15), 1.8))
    r.omni(name + "Light", x, 1.8, z, (1.0, 0.55, 0.2), 2.2, 9.0)


def skyline(r, items):
    sky = r.lit((0.06, 0.07, 0.1))
    for i, (x, z, sx, sy, sz) in enumerate(items):
        r.box("Skyline%d" % i, x, sy / 2.0, z, sx, sy, sz, sky)


# ====================================================================================== J1 Yard Gate (64 x 44)
def j1():
    r = Y("junk_j1", "JunkJ1", 64, 44, SUB)
    walk = [(0, 14, 18, 30), (18, 0, 64, 44), (-6, 19, 0, 25), (64, 19.5, 69, 24.5)]
    r.shell([(0, 0, 64, 44), (-6, 19, 0, 25)], "floor_rust_plate_quad", (0.7, 0.68, 0.72))
    r.holder("Cliffs")
    r.cliffs(walk, (-30, -22, 100, 66), seed="j1", hmin=11, hmax=15)
    # the weighbridge lane (x 0 to 18): a bridge plate, a screen, Kasp's memo, a crate hop onto a car stack (secret S1)
    r.box("Weighbridge", 9, 0.12, 22, 10, 0.24, 7, r.tile("floor_hazard_stripe_yellow_band", (5, 1), (0.8, 0.8, 0.8)))
    r.box("ScreenPole", 16.5, 2.0, 17.0, 0.25, 4.0, 0.25, r.lit((0.3, 0.32, 0.36)), solid=True)
    r.box("ScreenFrame", 16.5, 4.4, 17.0, 3.2, 1.6, 0.2, r.lit((0.15, 0.17, 0.2)))
    r.quad("ScreenPicture", 16.5, 4.4, 17.12, 3.0, 1.4, r.picture("wall_screen_green_terminal"))
    r.text("ScreenText", "SIGNALS YARD 9: QUIET PLEASE", 16.5, 3.4, 17.14, size=0.012, color=(0.7, 1.0, 0.7), font=30)
    r.box("MemoSign", 12.5, 1.5, 29.2, 2.0, 1.2, 0.1, r.lit((0.78, 0.78, 0.72)))
    r.text("MemoText", "KASP: NOISE IS A CHOICE", 12.5, 1.5, 29.28, yaw=0, size=0.008, color=(0.1, 0.1, 0.1), font=26)
    r.spot("ScreenSpot", "jk_j1_screen", 16.5, 19.5)
    r.spot("MemoSpot", "jk_j1_memo", 12.5, 27.8)
    prop(r, "StackCarA", "car", 6.0, 18.0, yaw=90)
    r.box("StackTop", 6.0, 1.8, 18.0, 4.5, 0.4, 2.0, r.lit((0.35, 0.3, 0.3)))
    r.collide("StackShape", 6.0, 0.9, 18.0, 4.5, 1.8, 2.0)
    r.box("ChalkLantern", 3.4, 1.0, 16.2, 0.4, 0.5, 0.04, r.glow((0.95, 0.95, 0.85), 0.7))
    r.box("HopCrate", 8.5, 0.45, 20.0, 0.9, 0.9, 0.9, r.lit((0.8, 0.5, 0.35)), solid=True)
    crate_at(r, "Stash", "jk_j1_stash", 6.0, 1.8, 18.0)
    r.pickup("GlintA", "jk_j1_glint_a", 11.0, 20.0)
    r.pickup("GlintB", "jk_j1_glint_b", 14.0, 25.0)
    # the Pound (x 32 to 64): burn barrel clearing, a few cars as cover edges, the fuse box on its pylon
    burn_barrel(r, "BurnBarrel", 36.0, 22.0)
    prop(r, "PoundCarA", "car", 28.0, 8.0, yaw=20)
    prop(r, "PoundCarB", "car", 24.0, 38.0, yaw=-15)
    prop(r, "PoundCrate", "crate_large", 58.0, 36.0, yaw=15)
    r.box("FusePylon", 54.0, 2.5, 12.0, 0.7, 5.0, 0.7, r.lit((0.3, 0.33, 0.38)), solid=True)
    hack_node(r, "hack_j1_door", "hack_door", "hack_j1_door", 54.0, 5.0, 12.0,
              extra="")
    # the east gate: a slab that slides up when the fuse box is zapped (built by HackDoor from placements "slab"), and the Door beyond
    door(r, "DoorWest", "jk_j1_to_market", 0.0, 22.0, 90)
    door(r, "DoorEast", "jk_j1_to_j2", 63.0, 22.0, -90)
    # the dormant colossus's head on the eastern skyline: a faint huge dark shape over the heaps
    sky = r.lit((0.05, 0.06, 0.09))
    r.ball("ColossusHead", 150.0, 60.0, -40.0, 22.0, sky)
    r.box("ColossusJaw", 150.0, 40.0, -40.0, 30.0, 14.0, 24.0, sky)
    r.box("ColossusEyes", 135.0, 62.0, -28.0, 18.0, 2.0, 1.0, r.glow((1.0, 0.45, 0.1), 0.6))
    skyline(r, [(10, -40, 24, 36, 10), (60, -50, 30, 46, 10), (-40, 60, 20, 30, 10), (90, 80, 30, 40, 10)])
    r.omni("GateLamp", 3.0, 4.0, 22.0, (1.0, 0.8, 0.5), 2.0, 12.0)
    r.omni("FuseTeal", 54.0, 5.5, 13.0, (0.3, 1.0, 0.9), 1.4, 7.0)
    encounters(r, "junk_j1")
    barks(r, [("bark_j1_arrive", 8.0, 22.0, 6.0), ("bark_j1_lockon", 28.0, 22.0, 9.0), ("bark_j1_zap", 50.0, 14.0, 12.0)])
    r.spawn("from_market", 2.0, 22.0, face=(1, 0))
    r.spawn("from_j2", 60.0, 22.0, face=(-1, 0))
    r.write("junk_j1.tscn")


# ====================================================================================== J2 Scrap Canyon (150 long)
def j2():
    r = Y("junk_j2", "JunkJ2", 150, 40, SUB)
    bay1 = (0, 10, 40, 24)
    pit = (40, 2, 95, 38)
    bay3 = (95, 8, 150, 20)
    alcove_a = (26, 0, 34, 10)           # T1's ledge, set back in the north cliff
    west_stub = (-6, 14, 0, 20)
    east_stub = (150, 11, 156, 17)
    walk = [bay1, pit, bay3, alcove_a, west_stub, east_stub]
    r.shell([bay1, pit, (95, 8, 98, 20), alcove_a, west_stub, east_stub], "floor_diamond_plate_rust", (0.7, 0.66, 0.66))
    r.holder("Cliffs")
    r.cliffs(walk, (-30, -22, 190, 62), seed="j2", hmin=13, hmax=19)
    # bay 3's ramp up 4 m (x 98 to 120), then the high ground to the gate
    r.tilted_box("Bay3Ramp", 109.41, -0.26, 14.0, 22.4, 4.6, 12.0, r.tile("floor_diamond_plate_rust", (11, 6), (0.8, 0.7, 0.65)), rz_deg=10.3)
    r.box("Bay3High", 135.0, 1.9, 14.0, 30.0, 4.2, 12.0, r.tile("floor_diamond_plate_rust", (15, 6), (0.8, 0.7, 0.65)), solid=True)
    # bay 1, the Chute: T1 on its ledge in the alcove (30, 3), a container for cover, a crate hop
    r.box("T1Ledge", 30.0, 2.0, 4.5, 6.0, 4.0, 9.0, r.lit((0.35, 0.36, 0.4)), solid=True)
    prop(r, "ChuteContainer", "container", 22.0, 20.0, yaw=0)
    r.box("HopCrateA", 36.5, 0.45, 12.0, 0.9, 0.9, 0.9, r.lit((0.8, 0.5, 0.35)), solid=True)
    r.box("HopCrateB", 37.6, 0.9, 12.0, 0.9, 1.8, 0.9, r.lit((0.7, 0.45, 0.32)), solid=True)
    # bay 2, the Pit Stop: a scrap ramp up to the north ledge (T2 at (62, 2), 4 m up), the ledge stash S2
    r.tilted_box("LedgeRamp", 54.56, -0.23, 5.0, 16.5, 4.6, 6.0, r.lit((0.42, 0.34, 0.28)), rz_deg=14.04)
    r.box("NorthLedge", 71.0, 2.0, 5.0, 18.0, 4.0, 6.0, r.lit((0.38, 0.32, 0.28)), solid=True)
    prop(r, "RoofCar", "car", 78.0, 6.6, yaw=90, y=4.0)
    crate_at(r, "S2Stash", "jk_j2_stash", 78.0, 5.4, 6.6)
    r.box("S2Chalk", 76.0, 4.9, 5.55, 0.4, 0.5, 0.04, r.glow((0.95, 0.95, 0.85), 0.7))
    prop(r, "PitCarA", "car", 54.0, 30.0, yaw=30)
    prop(r, "PitContainer", "container", 86.0, 12.0, yaw=90)
    prop(r, "PitCrate", "crate_large", 48.0, 20.0, yaw=10)
    burn_barrel(r, "PitBarrel", 66.0, 34.0)
    r.pickup("GlintA", "jk_j2_glint_a", 20.0, 14.0)
    r.pickup("GlintB", "jk_j2_glint_b", 60.0, 14.0)
    r.pickup("CellPickup", "jk_j2_cell", 142.0, 12.0, y=4.2)
    # bay 3, the Gate: a terminal on the high ground and the gate it opens
    hack_node(r, "term_j2_gate", "hack_terminal", "term_j2_gate", 144.0, 4.0, 14.0)
    r.box("GateFrameN", 150.4, 5.0, 10.2, 1.0, 10.0, 1.0, r.lit((0.45, 0.4, 0.3)), solid=True)
    r.box("GateFrameS", 150.4, 5.0, 17.8, 1.0, 10.0, 1.0, r.lit((0.45, 0.4, 0.3)), solid=True)
    door(r, "DoorWest", "jk_j2_to_j1", 0.0, 17.0, 90)
    door(r, "DoorEast", "jk_j2_to_j3", 150.0, 14.0, -90)
    # the gantry crane's jib fills the sky over bay 3 (the next job)
    r.box("CraneMastFar", 160.0, 30.0, -10.0, 4.0, 60.0, 4.0, r.lit((0.65, 0.55, 0.2)))
    r.box("CraneJibFar", 140.0, 58.0, -10.0, 44.0, 2.5, 3.0, r.lit((0.65, 0.55, 0.2)))
    skyline(r, [(30, -40, 30, 40, 10), (100, -34, 24, 34, 10), (70, 70, 40, 36, 10), (140, 60, 30, 30, 10)])
    r.omni("ChuteLamp", 10.0, 6.0, 17.0, (1.0, 0.8, 0.5), 2.0, 14.0)
    r.omni("PitLamp", 70.0, 7.0, 20.0, (1.0, 0.8, 0.5), 2.4, 20.0)
    r.omni("GateLamp", 138.0, 8.0, 14.0, (1.0, 0.8, 0.5), 2.0, 16.0)
    encounters(r, "junk_j2")
    barks(r, [("bark_j2_turret", 18.0, 17.0, 10.0), ("bark_j2_overclock", 60.0, 22.0, 12.0), ("bark_j2_crane", 128.0, 14.0, 10.0)])
    r.spawn("from_j1", 2.0, 17.0, face=(1, 0))
    r.spawn("from_j3", 148.0, 14.0, face=(-1, 0), y=4.3)
    r.write("junk_j2.tscn")


# ====================================================================================== J3 Crane Yard (100 x 80)
def j3():
    r = Y("junk_j3", "JunkJ3", 100, 80, SUB)
    pit = (46, 0, 55, 80)
    walk_rects = [(0, 0, 46, 80), (55, 0, 100, 80), (-6, 56, 0, 64), (100, 36, 106, 44)]
    r.shell([(0, 0, 46, 80), (55, 0, 100, 80), (-6, 56, 0, 64), (100, 36, 106, 44)], "floor_rust_plate_quad", (0.72, 0.68, 0.66))
    r.holder("Cliffs")
    r.cliffs(walk_rects, (-30, -22, 136, 102), seed="j3", hmin=12, hmax=18, holes=[pit])
    # the pit: a dark water plane far below; no floor (a fall puts her back at the entrance)
    r.plane("PitWater", 50.5, -8.5, 40.0, 9.0, 80.0, r.glow((0.03, 0.08, 0.1), 0.4))
    r.box("PitRimA", 45.7, -4.0, 40.0, 0.6, 8.0, 80.0, r.lit((0.3, 0.26, 0.24)), solid=False)
    r.box("PitRimB", 55.3, -4.0, 40.0, 0.6, 8.0, 80.0, r.lit((0.3, 0.26, 0.24)), solid=False)
    # the gantry crane straddling the pit: legs, rail x 44 to 66, a trolley and hook; controls at (44, 44)
    metal = r.lit((0.65, 0.55, 0.2))
    r.box("CraneLegW", 44.0, 9.0, 30.0, 1.4, 18.0, 1.4, metal, solid=True)
    r.box("CraneLegE", 57.0, 9.0, 30.0, 1.4, 18.0, 1.4, metal, solid=True)
    r.box("CraneRail", 50.5, 18.5, 30.0, 14.0, 1.2, 1.6, metal)
    r.box("CraneLegW2", 44.0, 9.0, 50.0, 1.4, 18.0, 1.4, metal, solid=True)
    r.box("CraneLegE2", 57.0, 9.0, 50.0, 1.4, 18.0, 1.4, metal, solid=True)
    r.box("CraneRail2", 50.5, 18.5, 50.0, 14.0, 1.2, 1.6, metal)
    r.box("CraneGirderLong", 50.5, 18.5, 40.0, 1.2, 1.2, 22.0, metal)
    r.box("CraneCabinet", 44.0, 0.9, 44.0, 1.2, 1.8, 0.8, r.lit((0.3, 0.33, 0.38)), solid=True)
    hack_node(r, "crane_j3", "hack_crane", "crane_j3", 44.0, 0.0, 44.0)
    # the bridge girder on its pallet at (36, 40), within the hook's reach
    r.box("GirderPallet", 36.0, 0.15, 40.0, 13.0, 0.3, 3.4, r.lit((0.4, 0.3, 0.2)))
    r.box("GirderOnPallet", 36.0, 0.6, 40.0, 12.0, 0.6, 3.0, r.lit((0.55, 0.5, 0.4)))
    # the drone line in the NW corner, its power node on the roof at (10, 5, 6)
    r.box("DroneDispenser", 8.0, 1.5, 8.0, 4.0, 3.0, 2.0, r.lit((0.35, 0.42, 0.55)), solid=True)
    r.box("DispenserRoller", 8.0, 1.7, 9.05, 3.0, 0.3, 0.1, r.glow((0.5, 0.8, 1.0), 1.0))
    r.box("NodeRoof", 10.0, 4.7, 6.0, 2.0, 0.3, 2.0, r.lit((0.3, 0.33, 0.38)), solid=False)
    r.box("NodePylon", 10.0, 2.3, 6.0, 0.5, 4.6, 0.5, r.lit((0.3, 0.33, 0.38)), solid=True)
    hack_node(r, "dline_j3", "drone_line", "dline_j3", 8.0, 0.0, 8.0)
    r.crate("NodeCache", "jk_j3_node_cache", 12.5, 9.5)
    # west half cover (the fight 3 yard): container stacks, a wrecked tow truck, spools
    for i, (x, z, yaw) in enumerate(((14.0, 28.0, 0), (22.0, 20.0, 90), (30.0, 52.0, 0), (12.0, 52.0, 90), (24.0, 68.0, 0))):
        prop(r, "Stack%d" % i, "container", x, z, yaw=yaw)
    prop(r, "StackUpper", "container", 14.0, 28.0, yaw=0, y=2.62, solid=False)
    r.collide("StackUpperShape", 14.0, 3.93, 28.0, 2.58, 2.62, 6.13)
    prop(r, "TowTruck", "car", 34.0, 62.0, yaw=60)
    for i, (x, z) in enumerate(((38.0, 12.0), (40.0, 14.5), (6.0, 40.0))):
        r.cyl("Spool%d" % i, x, 0.7, z, 0.7, 1.4, r.lit((0.5, 0.35, 0.25)), solid=True)
    prop(r, "RoofChalkCar", "car", 20.0, 70.0, yaw=0)
    crate_at(r, "RoofStash", "jk_j3_roof_stash", 20.0, 1.4, 70.0)
    # east half: the Foreman's shed with the last on-foot save terminal, a bench, a heal pickup, the vault
    r.box("ShedFloor", 90.0, 0.08, 48.0, 8.0, 0.16, 6.0, r.lit((0.4, 0.38, 0.34)))
    for sx in (86.2, 93.8):
        r.box("ShedPost%d" % int(sx), sx, 1.6, 45.2, 0.3, 3.2, 0.3, r.lit((0.4, 0.38, 0.34)))
    r.box("ShedRoof", 90.0, 3.3, 48.0, 9.0, 0.2, 7.0, r.lit((0.45, 0.35, 0.3)), fade=True)
    save_terminal(r, "term_save_j3", "junk_j3", "from_j4", 90.0, 49.0, yaw=0)
    r.box("Bench", 84.0, 0.25, 52.0, 2.0, 0.5, 0.6, r.lit((0.45, 0.35, 0.28)), solid=True)
    r.pickup("HealPickup", "jk_j3_heal", 87.0, 52.0)
    # the vault: a breakable wall at (72, 20) in front of a small chamber; a second way in by a fuse door (hack_j3_vault)
    r.box("VaultChamberNW", 73.5, 1.75, 17.0, 1.8, 3.5, 0.4, r.lit((0.32, 0.3, 0.3)), solid=True)
    r.box("VaultChamberNE", 79.0, 1.75, 17.0, 2.8, 3.5, 0.4, r.lit((0.32, 0.3, 0.3)), solid=True)
    r.box("VaultChamberS", 76.5, 1.75, 23.0, 8.0, 3.5, 0.4, r.lit((0.32, 0.3, 0.3)), solid=True)
    r.box("VaultChamberE", 80.2, 1.75, 20.0, 0.4, 3.5, 6.4, r.lit((0.32, 0.3, 0.3)), solid=True)
    r.box("VaultRoof", 76.5, 3.6, 20.0, 8.0, 0.2, 6.4, r.lit((0.32, 0.3, 0.3)), fade=True)
    r.holder("Breakables")
    r.node("VaultWall", "StaticBody3D", "Breakables", (72.4, 0, 20.0))
    r.nodes[-1] = r.nodes[-1].replace('type="StaticBody3D" parent="Breakables"]', 'type="StaticBody3D" parent="Breakables" groups=["crane_breakable"]]')
    r.box("VaultWallMesh", 0.0, 1.75, 0.0, 0.8, 3.5, 5.6, r.lit((0.5, 0.4, 0.35)), parent="Breakables/VaultWall")
    r.node("VaultWallShape", "CollisionShape3D", "Breakables/VaultWall", (0, 1.75, 0), extra="shape = %s" % r.box_shape((0.8, 3.5, 5.6)))
    hack_node(r, "hack_j3_vault", "hack_door", "hack_j3_vault", 76.0, 1.0, 15.0)
    r.crate("VaultCache", "jk_j3_vault_cache", 77.5, 20.0)
    r.box("VaultGlow", 76.0, 2.6, 16.7, 1.0, 0.5, 0.05, r.glow((1.0, 0.8, 0.3), 1.0))
    # doors, the hangar door east
    door(r, "DoorWest", "jk_j3_to_j2", 0.0, 60.0, 90)
    door(r, "DoorHangar", "jk_j3_to_j4", 100.0, 40.0, -90)
    r.box("HangarFrameN", 100.3, 2.5, 36.4, 0.8, 5.0, 0.8, r.lit((0.45, 0.4, 0.3)), solid=True)
    r.box("HangarFrameS", 100.3, 2.5, 43.6, 0.8, 5.0, 0.8, r.lit((0.45, 0.4, 0.3)), solid=True)
    skyline(r, [(20, -34, 30, 40, 10), (70, -40, 30, 50, 10), (130, 40, 30, 36, 10), (60, 110, 50, 36, 10)])
    r.omni("WestLamp", 20.0, 8.0, 40.0, (1.0, 0.8, 0.5), 3.0, 26.0)
    r.omni("EastLamp", 82.0, 8.0, 40.0, (1.0, 0.8, 0.5), 3.0, 26.0)
    r.omni("PitSpill", 50.5, 4.0, 40.0, (0.3, 0.9, 0.8), 1.6, 14.0)
    encounters(r, "junk_j3")
    barks(r, [("bark_j3_pit", 8.0, 58.0, 9.0), ("bark_j3_crane", 40.0, 44.0, 8.0), ("bark_j3_emp", 14.0, 14.0, 10.0), ("bark_j3_lastsave", 88.0, 46.0, 7.0)])
    r.spawn("from_j2", 2.0, 60.0, face=(1, 0))
    r.spawn("from_j4", 98.0, 40.0, face=(-1, 0))
    r.write("junk_j3.tscn")


# ====================================================================================== J4 Wreck Row (90 x 60)
def j4():
    r = Y("junk_j4", "JunkJ4", 90, 60, SUB)
    vest = (0, 20, 12, 40)
    gap_w = (12, 26, 14, 34)
    stand = (14, 8, 64, 52)
    gap_e = (64, 26, 66, 34)
    cradle = (66, 22, 86, 38)
    lane = (86, 26, 92, 34)
    walk_rects = [vest, gap_w, stand, gap_e, cradle, lane, (-6, 26, 0, 34)]
    r.shell(walk_rects, "floor_concrete_cracked_dark", (0.72, 0.7, 0.72))
    r.holder("Cliffs")
    r.cliffs(walk_rects, (-30, -22, 120, 82), seed="j4", hmin=13, hmax=20)
    # the giant wrecks: a 20 m arm, a 15 m head (with a hatch, secret S4), an 18 m leg
    wreck = r.lit((0.28, 0.24, 0.22))
    rust = r.tile("rust_streaked_plate_tall", (4, 2), (0.7, 0.6, 0.55))
    r.box("WreckHead", 40.0, 6.0, 4.0, 15.0, 12.0, 8.0, wreck, solid=True)
    r.quad("WreckHeadFace", 40.0, 6.0, 8.03, 15.0, 12.0, rust)
    r.box("WreckHeadEye", 36.0, 8.0, 8.08, 3.0, 1.0, 0.1, r.glow((1.0, 0.45, 0.1), 0.6))
    r.box("HeadHatch", 40.0, 2.1, 8.1, 1.2, 1.4, 0.12, r.lit((0.5, 0.42, 0.3)))
    r.crate("HeadCache", "jk_j4_head_cache", 40.0, 9.6)
    r.box("WreckArm", 24.0, 2.0, 49.0, 20.0, 4.0, 4.0, wreck, solid=True)
    r.box("WreckFist", 12.5, 2.4, 49.0, 3.2, 4.8, 4.8, wreck, solid=True)
    r.box("WreckLeg", 54.0, 1.8, 13.0, 18.0, 3.6, 3.6, wreck, solid=True)
    r.box("WreckFoot", 63.0, 1.2, 13.0, 4.0, 2.4, 5.0, wreck, solid=True)
    # the two turret pedestals (T3 (30, 10), T4 (48, 50), 3 m up) and the Stand's shutters (raised: open)
    for tid, (x, z) in (("T3", (30.0, 10.0)), ("T4", (48.0, 50.0))):
        r.box("%sPedestal" % tid, x, 1.5, z, 2.4, 3.0, 2.4, r.lit((0.32, 0.34, 0.38)), solid=True)
    r.holder("Shutters")
    for nm, x in (("shutter_w", 13.0), ("shutter_e", 65.0)):
        r.node(nm, "StaticBody3D", "Shutters", (x, 5.5, 30.0))      # raised 5.5 m: open; the Stand drops it to y 0 (its collision then blocks)
        r.box(nm + "Mesh", 0.0, 2.0, 0.0, 0.6, 4.0, 9.0, r.lit((0.45, 0.4, 0.3)), parent="Shutters/" + nm)
        r.node(nm + "Shape", "CollisionShape3D", "Shutters/" + nm, (0, 2.0, 0), extra="shape = %s" % r.box_shape((0.6, 4.0, 9.0)))
    # the Stand: cars as bleacher cover at the edges, a burn barrel or two
    prop(r, "StandCarA", "car", 20.0, 14.0, yaw=0)
    prop(r, "StandCarB", "car", 58.0, 46.0, yaw=20)
    prop(r, "StandContainer", "container", 18.0, 44.0, yaw=90)
    burn_barrel(r, "StandBarrel", 40.0, 40.0)
    # the vestibule's quiet walk and the loader cradle: a platform, gantry posts, the cradle where the loader sleeps, the way east
    r.box("CradlePlatform", 76.0, 0.2, 30.0, 20.0, 0.4, 16.0, r.lit((0.38, 0.38, 0.4)), solid=False)
    r.box("CradleLegA", 68.0, 4.5, 24.0, 1.4, 9.0, 1.4, r.lit((0.65, 0.55, 0.2)), solid=True)
    r.box("CradleLegB", 68.0, 4.5, 36.0, 1.4, 9.0, 1.4, r.lit((0.65, 0.55, 0.2)), solid=True)
    r.box("CradleLegC", 84.0, 4.5, 24.0, 1.4, 9.0, 1.4, r.lit((0.65, 0.55, 0.2)), solid=True)
    r.box("CradleLegD", 84.0, 4.5, 36.0, 1.4, 9.0, 1.4, r.lit((0.65, 0.55, 0.2)), solid=True)
    r.box("CradleBeam", 76.0, 9.2, 24.0, 17.0, 0.8, 1.0, r.lit((0.65, 0.55, 0.2)))
    r.box("CradleBeam2", 76.0, 9.2, 36.0, 17.0, 0.8, 1.0, r.lit((0.65, 0.55, 0.2)))
    hack_node(r, "loader_j4", "hack_loader", "loader_j4", 72.0, 0.0, 30.0)
    r.omni("CradleLamp", 76.0, 8.0, 30.0, (1.0, 0.7, 0.35), 2.4, 18.0)
    r.holder("Breakables")
    r.node("SmashWall", "StaticBody3D", "Breakables", (90.0, 0, 30.0))
    r.nodes[-1] = r.nodes[-1].replace('type="StaticBody3D" parent="Breakables"]', 'type="StaticBody3D" parent="Breakables" groups=["loader_smash"]]')
    r.box("SmashWallMesh", 0.0, 3.0, 0.0, 4.0, 6.0, 9.0, r.lit((0.42, 0.34, 0.28)), parent="Breakables/SmashWall")
    r.node("SmashWallShape", "CollisionShape3D", "Breakables/SmashWall", (0, 3.0, 0), extra="shape = %s" % r.box_shape((4.0, 6.0, 9.0)))
    door(r, "DoorWest", "jk_j4_to_j3", 0.0, 30.0, 90)
    r.omni("StandLampN", 30.0, 9.0, 12.0, (1.0, 0.8, 0.5), 3.0, 24.0)
    r.omni("StandLampS", 48.0, 9.0, 48.0, (1.0, 0.8, 0.5), 3.0, 24.0)
    r.omni("VestibuleLamp", 6.0, 6.0, 30.0, (0.7, 0.85, 1.0), 1.6, 12.0)
    skyline(r, [(30, -40, 30, 44, 10), (90, -34, 30, 50, 10), (60, 90, 50, 40, 10)])
    encounters(r, "junk_j4")
    barks(r, [("bark_j4_wrecks", 6.0, 30.0, 8.0), ("bark_j4_stand", 16.0, 30.0, 5.0), ("bark_j4_loader", 70.0, 30.0, 9.0), ("bark_j4_smash", 84.0, 30.0, 6.0)])
    r.spawn("from_j3", 2.0, 30.0, face=(1, 0))
    r.spawn("from_j5", 86.5, 30.0, face=(-1, 0))
    r.write("junk_j4.tscn")


if __name__ == "__main__":
    j1(); j2(); j3(); j4()
    print("wrote the junkyard rooms J1 to J4 to", os.path.join(GAME, "scenes", "slice", SUB))
