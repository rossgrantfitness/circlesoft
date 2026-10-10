#!/usr/bin/env python3
"""Writes the nine graybox rooms of the Spillway and the jammer works (M4-1, M4-2 puzzles).

Run from the repo root:  python3 game/scripts/tools/make_works_rooms.py
Blueprint: docs/maps/road_and_tower.md ("Graybox build notes"). Same conventions as make_harrow_rooms.py (this
file reuses its room builder): meters, origin at the north-west floor corner, +X east along the north wall, +Z south
toward the camera; boxes and flat colors only (placeholder art). What is in each crate, who says what and which door
needs what lives in game/data/ (placements.json, rooms.json, story_scenes.json, works.json, dialogue/works.json);
scripts/tools/make_works_data.py merges the placements, rooms and scenes into those files (only entries that are
missing, so later tuning by hand is never overwritten). The node names / placement ids here must match (a test checks).
"""
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
from make_harrow_rooms import OUT, finish, walls, yaw_to  # noqa: E402
from make_harrow_rooms import start as _start  # noqa: E402

SLATE = (0.46, 0.5, 0.58)
BLUE = (0.42, 0.52, 0.66)
GRIME = (0.38, 0.37, 0.36)
IRON = (0.5, 0.42, 0.34)
BRASS = (0.85, 0.64, 0.25)
HAZARD = (0.9, 0.72, 0.15)
CRATE_GRAY = (0.55, 0.58, 0.62)

LIFT = 1.75  # the grim material pass drains and darkens every lit tint, so floors and walls start bright (Harrow's do too)


def start(room_id, title, w, d, yaw, cam_c, cam_s, wall_h, floor, wall, **kw):
    bright = lambda t: tuple(min(1.0, c * LIFT) for c in t)  # noqa: E731
    return _start(room_id, title, w, d, yaw, cam_c, cam_s, wall_h, bright(floor), bright(wall), **kw)


PROP_DIR = "res://scripts/works/"
LAMP_SCRIPT = "res://scripts/save/save_lamp.gd"
WARP_SCRIPT = PROP_DIR + "works_warp.gd"


# ---------------------------------------------------------------- small builders
def solid(r, name, x, y, z, sx, sy, sz, tint, fade=False, uv=(1, 1), tex="checker_128"):
    r.box(name, x, y, z, sx, sy, sz, r.lit(tint, uv, tex), solid=True, fade=fade)


def scenery(r, name, x, y, z, sx, sy, sz, tint):
    r.box(name, x, y, z, sx, sy, sz, r.lit(tint))


def glow_box(r, name, x, y, z, sx, sy, sz, tint, energy=1.3):
    r.box(name, x, y, z, sx, sy, sz, r.glow(tint, energy))


def opening(r, name, x, w=2.0, h=3.0, z=0.0, tint=(0.1, 0.11, 0.16)):
    """A dark doorway flat on the wall (the walls are solid; the door's trigger does the rest)."""
    r.box(name, x, h / 2.0, z + 0.02, w, h, 0.1, r.lit(tint, (1, 1), "checker_64"))


def scripted(r, name, script, pos=(0, 0, 0), yaw=0.0, extra="", parent="."):
    s = r.ext_res("Script", script)
    r.node(name, "Node3D", parent, pos, yaw_deg=yaw, extra="script = %s\n%s" % (s, extra))


def crate_at(r, name, pid, x, y, z, yaw=0):
    r.node(name, "", ".", (x, y, z), yaw_deg=yaw, instance=r.inst("res://scenes/props/crate.tscn"), extra='placement_id = "%s"' % pid)


def enemy(r, name, pid, x, z, face=(0, 1)):
    r.node(name, "", ".", (x, 0, z), yaw_deg=yaw_to(*face), instance=r.inst("res://scenes/props/map_enemy.tscn"), extra='placement_id = "%s"' % pid)


def save_lamp(r, name, x, z, yaw, room_id, spawn_id, rest=False):
    scripted(r, name, LAMP_SCRIPT, (x, 0, z), yaw, 'room_id = "%s"\nspawn_id = "%s"\nrest = %s\nreach = 1.6' % (room_id, spawn_id, "true" if rest else "false"))


def lift_door(r, stop):
    scripted(r, "CageLift", PROP_DIR + "cage_lift.gd", (15, 0, 2.1), 0, 'placement_id = "lift_%s"\nstop = "%s"' % (stop, stop))


def lift_shaft(r, doored):
    """The 2 x 2 m lift shaft against the north wall at x=14..16 (every floor). Doors only on T0, T3, T4."""
    solid(r, "LiftShaft", 15.0, 2.0, 1.0, 2.0, 4.0, 2.0, SLATE)
    if doored:
        glow_box(r, "LiftDoorLight", 15.0, 2.9, 2.04, 0.5, 0.2, 0.05, (1.0, 0.3, 0.25), 1.2)
    else:
        scenery(r, "LiftMesh", 15.0, 1.2, 2.04, 2.0, 2.4, 0.06, (0.36, 0.38, 0.44))


def mast_column(r, tint=IRON):
    """The old mast: 3 m wide, half sunk into the north wall at x=6.5..9.5 (the one non-factory piece)."""
    solid(r, "MastColumn", 8.0, 2.0, 0.0, 3.0, 4.0, 3.0, tint, uv=(1, 3))
    scenery(r, "MastRing", 8.0, 2.4, 0.0, 3.3, 0.14, 3.3, (0.55, 0.62, 0.5))


def warp(r):
    scripted(r, "WorksWarp", WARP_SCRIPT)


def works_floor(room_id, title, w=16, d=10, wall_h=4.0, yaw=35, cam_c=(8, 5), cam_s=(6, 2), floor=GRIME, wall=(0.45, 0.46, 0.5)):
    r = start(room_id, title, w, d, yaw, cam_c, cam_s, wall_h, floor, wall)
    walls(r)
    return r


def spawn_points(r, markers, default):
    r.spawns(markers)
    name, (x, z), face = default
    r.node("PlayerSpawn", "Marker3D", pos=(x, 0, z), yaw_deg=yaw_to(*face))


# ---------------------------------------------------------------- R1 the Spillway
def spillway():
    r = start("road_mast_road", "RoadMastRoad", 34, 8, 20, (17, 4), (24, 0), 4.0, (0.4, 0.38, 0.35), (0.42, 0.42, 0.46))
    walls(r)
    # the service stair coming down on the west wall, and the channel's far end
    opening(r, "StairOpening", 0.0, 2.6, 3.0)
    r.box("StairOpeningW", 0.02, 1.5, 4.0, 0.1, 3.0, 2.6, r.lit((0.1, 0.11, 0.16), (1, 1), "checker_64"))
    for i in range(5):
        scenery(r, "StairStep%d" % i, 0.5 + i * 0.0, 0.1 + i * 0.1, 2.9 + i * 0.5, 0.9, 0.1, 0.5, (0.34, 0.33, 0.33))
    # ceiling grates: a dark frame on the north wall's top edge every 6 m
    for i, x in enumerate((5, 11, 17, 23, 29)):
        scenery(r, "GrateFrame%d" % i, x, 3.85, 0.1, 1.6, 0.3, 0.08, (0.12, 0.12, 0.14))
    # runoff strip and the sunken tram car
    r.plane("Runoff", 17.0, 0.01, 4.0, 32.0, 1.0, r.lit((0.2, 0.32, 0.36), (16, 1), "checker_64"))
    solid(r, "TramCar", 23.0, 0.45, 1.0, 4.0, 0.9, 2.0, (0.55, 0.48, 0.38), uv=(2, 1))
    for i, x in enumerate((21.8, 23.0, 24.2)):
        scenery(r, "TramWindow%d" % i, x, 0.55, 2.03, 0.8, 0.4, 0.04, (0.08, 0.09, 0.12))
    glow_box(r, "ChalkLantern", 24.0, 1.1, 0.4, 0.5, 0.6, 0.03, (0.95, 0.95, 0.85), 0.7)
    crate_at(r, "TramStash", "rd_tram_stash", 24.0, 0.9, 1.0)
    scenery(r, "TramSign", 18.0, 1.6, 0.1, 1.2, 0.5, 0.06, (0.8, 0.7, 0.3))
    scenery(r, "FloodGauge", 30.0, 1.6, 0.1, 0.3, 2.2, 0.06, (0.7, 0.7, 0.6))
    r.spot("TramSignSpot", "rd_tram_sign", 18.0, 0.9)
    r.spot("GaugeSpot", "rd_gauge", 30.0, 0.9)
    r.spot("GrateSpot", "rd_grate", 11.0, 0.9)
    r.door("DoorHarrow", "road_to_checkpoint", 0, 4.0, yaw=90)
    r.door("DoorFoot", "rd_to_foot", 34, 4.0, yaw=-90)
    enemy(r, "PatrolPair", "rd_patrol", 19.0, 2.0, face=(1, 0))
    r.npc("CrateMox", "rd_mox", 12.5, 4.5, face=(-1, 0))
    spawn_points(r, [("from_harrow", (1.2, 4.0), (1, 0)), ("from_mast_foot", (32.8, 4.0), (-1, 0))], ("from_harrow", (1.2, 4.0), (1, 0)))
    warp(r)
    os.makedirs(os.path.join(OUT, "road"), exist_ok=True)
    finish(r, "road/road_mast_road.tscn")


# ---------------------------------------------------------------- R2 the Works gate
def works_gate():
    r = start("road_mast_foot", "RoadMastFoot", 18, 12, 30, (9, 6), (8, 2), 5.0, (0.42, 0.4, 0.38), (0.44, 0.46, 0.5))
    walls(r)
    scenery(r, "MastBase", 9.0, 4.0, -2.6, 5.0, 8.0, 3.0, IRON)
    scenery(r, "MastBand", 9.0, 5.5, -1.0, 5.2, 0.16, 0.3, (0.55, 0.62, 0.5))
    solid(r, "BlastGate", 11.0, 1.5, 0.3, 3.0, 3.0, 0.5, BLUE)
    glow_box(r, "GateLight", 11.0, 3.2, 0.6, 0.5, 0.12, 0.05, (1.0, 0.3, 0.25), 1.2)
    scenery(r, "OutfallWall", 0.1, 2.0, 5.0, 0.2, 4.0, 4.0, (0.34, 0.34, 0.36))
    r.box("GrateDark", 0.12, 0.7, 8.0, 0.1, 1.4, 1.6, r.lit((0.06, 0.07, 0.1), (1, 1), "checker_64"))
    solid(r, "Generator", 16.0, 0.75, 8.0, 2.0, 1.5, 1.5, BLUE)
    glow_box(r, "GeneratorLight", 16.0, 1.2, 8.78, 0.3, 0.2, 0.04, (1.0, 0.7, 0.3))
    r.flag_visible("MoxCrate", '{"not_flag": "mox_joined"}', 14.5, 0.0, 2.5)
    r.box("MoxCrateBox", 0, 0.45, 0, 0.9, 0.9, 0.9, r.lit(CRATE_GRAY), solid=True, parent="MoxCrate")
    r.box("MoxCrateRing", 0, 0.92, 0, 0.3, 0.03, 0.3, r.glow((0.95, 0.95, 0.9), 0.7), parent="MoxCrate")
    crate_at(r, "SupplyCrate", "fo_supply", 17.3, 0.0, 9.0)
    r.spot("BlastGateSpot", "fo_blast_gate", 11.0, 1.8)
    r.door("DoorSpillway", "fo_to_road", 3.0, 12.0, yaw=180)
    r.door("DoorDrain", "fo_to_sump", 0, 8.0, yaw=90)
    for i in range(7):
        r.npc("Zero%d" % (i + 1), "fo_zero_%d" % (i + 1), 6.0 + 1.1 * i, 5.0, face=(0, -1))
    r.npc("OldZero", "fo_old_zero", 4.5, 7.0, face=(1, -0.4))
    r.npc("GateGruntA", "fo_grunt_a", 9.5, 1.5, face=(0, 1))
    r.npc("GateGruntB", "fo_grunt_b", 12.5, 1.5, face=(0, 1))
    r.npc("CrateMox", "fo_mox", 14.5, 2.5, face=(0, 1))
    spawn_points(r, [("from_road", (3.0, 11.0), (0, -1)), ("from_tunnel", (1.2, 8.0), (1, 0))], ("from_road", (3.0, 11.0), (0, -1)))
    warp(r)
    finish(r, "road/road_mast_foot.tscn")


# ---------------------------------------------------------------- T0 the Sump
def sump():
    r = works_floor("tower_sump", "TowerSump", floor=(0.36, 0.35, 0.34), wall=(0.4, 0.4, 0.42))
    mast_column(r)
    lift_shaft(r, True)
    lift_door(r, "tower_sump")
    scenery(r, "Plaque", 1.5, 1.5, 0.08, 0.7, 0.4, 0.05, BRASS)
    scenery(r, "Mural", 4.0, 1.9, 0.06, 4.0, 2.5, 0.05, (0.6, 0.5, 0.4))
    r.spot("PlaqueSpot", "ts_plaque", 1.5, 0.9)
    r.spot("MuralSpot", "ts_mural", 4.0, 0.9)
    opening(r, "StairOpening", 12.0, 2.0, 3.0)
    r.box("GrateOpening", 0.02, 0.7, 8.0, 0.1, 1.4, 1.6, r.lit((0.06, 0.07, 0.1), (1, 1), "checker_64"))
    save_lamp(r, "SaveLamp", 0.4, 5.0, 90, "tower_sump", "lamp1")
    solid(r, "CableSpool", 10.0, 0.45, 5.0, 0.9, 0.9, 0.9, (0.55, 0.4, 0.28))
    enemy(r, "CardGrunt1", "ts_card_1", 10.0, 4.0, face=(0, -1))
    crate_at(r, "SupplyCrate", "ts_supply", 12.5, 0.0, 7.0)
    r.door("DoorGrate", "ts_to_gate", 0, 8.0, yaw=90)
    r.door("DoorStairs", "ts_to_cable", 12.0, 0.0)
    spawn_points(r, [("from_tunnel", (1.2, 8.0), (1, 0)), ("from_lift", (15.0, 3.0), (0, 1)), ("from_above", (12.0, 1.2), (0, 1)),
                     ("lamp1", (1.6, 5.0), (1, 0))], ("from_tunnel", (1.2, 8.0), (1, 0)))
    warp(r)
    finish(r, "tower/tower_sump.tscn")


# ---------------------------------------------------------------- T1 Cable Mill
def cable_hall():
    r = works_floor("tower_cable_hall", "TowerCableHall")
    mast_column(r)
    lift_shaft(r, False)
    solid(r, "Ledge", 1.5, 0.9, 2.0, 3.0, 1.8, 4.0, (0.5, 0.52, 0.58), uv=(2, 1))
    crate_at(r, "LedgeStash", "tc_ledge_stash", 1.0, 1.8, 1.0)
    # conveyor line on the north wall west of the mast (the east end is the lift shaft and the card door)
    solid(r, "Conveyor", 4.7, 0.5, 0.5, 3.0, 1.0, 1.0, (0.3, 0.32, 0.36))
    for i in range(6):
        scenery(r, "Spool%d" % i, 3.5 + i * 0.5, 1.15, 0.5, 0.35, 0.3, 0.35, (0.6, 0.42, 0.3))
    scenery(r, "QuotaChart", 12.0, 2.0, 0.08, 1.4, 0.9, 0.05, (0.85, 0.82, 0.7))
    r.node("PushCrate", "Node3D", ".", (7.0, 0, 3.0), extra='script = %s\nplacement_id = "tc_push_crate"' % r.ext_res("Script", PROP_DIR + "push_crate.gd"))
    solid(r, "BigSpool", 13.4, 0.5, 6.5, 1.0, 1.0, 1.0, (0.62, 0.4, 0.28))
    r.spot("ChartSpot", "tc_chart", 12.0, 1.2)
    r.spot("SpoolSpot", "tc_spool", 13.4, 7.6)
    r.spot("ConveyorSpot", "tc_conveyor", 4.7, 1.4)
    r.door("DoorDown", "tc_to_sump", 2.0, 10.0, yaw=180)
    r.door("DoorCard1", "tc_card_door_1", 12.0, 0.0)
    enemy(r, "Drones", "tc_drones", 8.0, 2.0, face=(0, 1))
    spawn_points(r, [("from_below", (2.0, 8.0), (0, -1)), ("from_above", (12.0, 1.2), (0, 1))], ("from_below", (2.0, 8.0), (0, -1)))
    warp(r)
    finish(r, "tower/tower_cable_hall.tscn")


# ---------------------------------------------------------------- T2 Bell Gallery
def bell_gallery():
    r = works_floor("tower_bell_gallery", "TowerBellGallery", floor=(0.4, 0.38, 0.36), wall=(0.42, 0.4, 0.4))
    mast_column(r, (0.46, 0.4, 0.34))
    lift_shaft(r, False)
    scenery(r, "BellBeam", 0.8, 2.6, 5.0, 0.3, 0.3, 9.0, (0.35, 0.28, 0.22))
    scripted(r, "BellRack", PROP_DIR + "bell_rack.gd")
    for bell_id, z in (("big", 2.0), ("middle", 4.0), ("little", 6.0), ("tiny", 8.0)):
        scripted(r, "Bell_" + bell_id, PROP_DIR + "bell.gd", (0.8, 0, z), 90, 'bell_id = "%s"' % bell_id, parent="BellRack")
    # the hatch chest stays hidden until the tune is rung
    crate_at(r, "HatchChest", "tb_bell_chest", 4.0, 0.0, 5.0)
    scenery(r, "SlitWindow", 3.0, 2.2, 0.08, 0.5, 1.2, 0.05, (0.12, 0.16, 0.3))
    glow_box(r, "SlitGlow", 3.0, 2.2, 0.12, 0.3, 1.0, 0.03, (1.0, 0.45, 0.8), 0.9)
    scenery(r, "FactoryDuct", 11.0, 3.0, 0.2, 2.6, 0.9, 0.9, BLUE)
    r.spot("WindowSpot", "tb_window", 3.0, 1.0)
    opening(r, "StairOpening", 12.0, 2.0, 3.0)
    r.door("DoorDown", "tb_to_cable", 3.5, 10.0, yaw=180)
    r.door("DoorUp", "tb_to_gen", 12.0, 0.0)
    enemy(r, "CardPair", "tb_card_pair", 5.0, 3.0, face=(1, 0))
    spawn_points(r, [("from_below", (3.5, 8.5), (0, -1)), ("from_above", (12.0, 1.2), (0, 1))], ("from_below", (3.5, 8.5), (0, -1)))
    warp(r)
    finish(r, "tower/tower_bell_gallery.tscn")


# ---------------------------------------------------------------- T3 Power Room (the breather floor)
def generator():
    r = works_floor("tower_generator", "TowerGenerator", floor=(0.36, 0.37, 0.4))
    mast_column(r)
    lift_shaft(r, True)
    lift_door(r, "tower_generator")
    # switch cage 3 x 3 m at x=0.5..3.5, z=0.5..3.5, open on the east side behind the card gate
    bars = r.lit((0.42, 0.46, 0.56))
    for name, x, z, sx, sz in (("CageN", 2.0, 0.5, 3.0, 0.1), ("CageW", 0.5, 2.0, 0.1, 3.0), ("CageS", 2.0, 3.5, 3.0, 0.1),
                               ("CageEA", 3.5, 1.0, 0.1, 1.0), ("CageEB", 3.5, 3.0, 0.1, 1.0)):
        r.box(name, x, 1.1, z, sx, 2.2, sz, bars, solid=True)
    scripted(r, "CardGate", PROP_DIR + "card_gate.gd", (3.5, 0, 2.0), 90, 'placement_id = "tg_cage_gate"')
    scripted(r, "PowerLever", PROP_DIR + "power_switch.gd", (1.5, 0, 1.5), 90)
    # the old generator and the new board
    solid(r, "OldGenerator", 6.0, 1.0, 6.0, 3.0, 2.0, 2.0, IRON, uv=(2, 1))
    scenery(r, "MakerPlate", 6.0, 1.3, 7.03, 0.5, 0.3, 0.04, BRASS)
    solid(r, "PowerBoard", 0.25, 1.0, 5.0, 0.4, 2.0, 2.0, BLUE)
    glow_box(r, "BoardLight", 0.5, 1.6, 5.0, 0.06, 0.2, 0.3, (0.3, 1.0, 0.5), 1.0)
    r.spot("PlateSpot", "tg_plate", 6.0, 8.3)
    r.spot("BoardSpot", "tg_board", 1.3, 5.0)
    # torn-out stairs: rubble and cable where the stairs were
    solid(r, "Rubble", 12.0, 0.4, 0.8, 2.0, 0.8, 1.0, (0.42, 0.4, 0.38))
    scenery(r, "CableHeap", 11.2, 1.0, 0.7, 0.8, 0.5, 0.6, (0.12, 0.12, 0.14))
    r.spot("RubbleSpot", "tg_rubble", 12.0, 2.0)
    # the jump: step crate, then the girder catwalk with the supply crate at its far end
    solid(r, "StepCrate", 9.5, 0.45, 6.0, 0.9, 0.9, 0.9, (0.8, 0.5, 0.35))
    solid(r, "Catwalk", 11.25, 0.9, 4.6, 4.5, 1.8, 1.2, (0.5, 0.5, 0.56), uv=(2, 1))
    crate_at(r, "GirderCrate", "tg_girder_crate", 13.0, 1.8, 4.6)
    r.door("DoorDown", "tg_to_bell", 2.0, 10.0, yaw=180)
    spawn_points(r, [("from_below", (2.0, 8.0), (0, -1)), ("from_lift", (15.0, 3.0), (0, 1))], ("from_below", (2.0, 8.0), (0, -1)))
    warp(r)
    finish(r, "tower/tower_generator.tscn")


# ---------------------------------------------------------------- T4 Drone Line
def jammer_deck():
    r = start("tower_jammer_deck", "TowerJammerDeck", 18, 12, 35, (9, 6), (8, 4), 4.0, (0.38, 0.38, 0.42), (0.45, 0.46, 0.5))
    walls(r)
    mast_column(r)
    lift_shaft(r, True)
    lift_door(r, "tower_jammer_deck")
    solid(r, "Console", 9.0, 0.6, 6.0, 3.0, 1.2, 1.5, BLUE)
    glow_box(r, "ConsoleScreen", 9.0, 1.3, 5.2, 2.0, 0.5, 0.05, (0.4, 0.9, 1.0), 1.1)
    # assembly line along the north wall east of the mast; drones as small boxes on it
    solid(r, "AssemblyLine", 10.9, 0.5, 0.6, 3.6, 1.0, 1.2, (0.3, 0.32, 0.36))
    for i in range(3):
        scenery(r, "Drone%d" % i, 9.9 + i * 1.2, 1.2, 0.6, 0.5, 0.3, 0.5, (0.6, 0.62, 0.7))
    scenery(r, "ArmA", 10.0, 2.6, 0.9, 0.2, 1.6, 0.2, (0.85, 0.64, 0.25))
    scenery(r, "ArmB", 12.0, 2.6, 0.9, 0.2, 1.6, 0.2, (0.85, 0.64, 0.25))
    solid(r, "CoffeeStation", 16.8, 0.6, 9.0, 0.9, 1.2, 1.6, (0.4, 0.3, 0.26))
    # the quota pen: x=0..4, z=8..12, fence 1.1 m with a gap at (4, 10)
    fence = r.lit((0.7, 0.62, 0.3))
    for name, x, z, sx, sz in (("PenN", 2.0, 8.0, 4.0, 0.12), ("PenEA", 4.0, 8.65, 0.12, 1.3), ("PenEB", 4.0, 11.35, 0.12, 1.3)):
        r.box(name, x, 0.55, z, sx, 1.1, sz, fence, solid=True)
    scenery(r, "PenSign", 3.4, 1.4, 8.05, 1.0, 0.4, 0.05, (0.9, 0.3, 0.25))
    r.spot("PenSpot", "td_pen", 4.6, 8.3)
    crate_at(r, "QuotaCrate", "td_quota_crate", 1.0, 0.0, 11.2)
    enemy(r, "QuotaA", "td_quota_a", 1.5, 9.0, face=(1, 0))
    enemy(r, "QuotaB", "td_quota_b", 2.5, 11.0, face=(1, -0.5))
    enemy(r, "QuotaC", "td_quota_c", 3.0, 9.5, face=(0.5, 1))
    enemy(r, "Squad", "td_squad", 5.0, 4.0, face=(1, 0))
    r.spot("ConsoleSpot", "td_console", 9.0, 7.2)
    r.spot("LineSpot", "td_line", 13.3, 2.4)
    r.spot("CoffeeSpot", "td_coffee", 15.7, 9.0)
    r.door("DoorCard3", "td_card_door_3", 3.5, 0.0)
    spawn_points(r, [("from_lift", (15.0, 3.0), (0, 1)), ("from_above", (3.5, 1.2), (0, 1))], ("from_lift", (15.0, 3.0), (0, 1)))
    warp(r)
    finish(r, "tower/tower_jammer_deck.tscn")


# ---------------------------------------------------------------- T4b Last Landing
def landing():
    r = start("tower_landing", "TowerLanding", 8, 6, 45, (4, 3), (0, 0), 3.0, (0.42, 0.4, 0.38), (0.5, 0.48, 0.46))
    walls(r)
    opening(r, "StairOpening", 6.0, 1.6, 2.6)
    for i in range(4):
        scenery(r, "Stair%d" % i, 6.0, 0.15 + i * 0.15, 0.7 - i * 0.2, 1.4, 0.15, 0.2, (0.45, 0.43, 0.4))
    save_lamp(r, "SaveLamp", 0.4, 2.0, 90, "tower_landing", "lamp2")
    scenery(r, "CoatRack", 2.0, 1.2, 0.2, 0.9, 2.4, 0.2, (0.4, 0.3, 0.22))
    scenery(r, "Lanyard", 2.0, 1.9, 0.33, 0.35, 0.5, 0.04, (0.95, 0.9, 0.7))
    r.spot("RackSpot", "tl_rack", 2.0, 1.2)
    r.npc("OldZero", "tl_old_zero", 5.0, 2.5, face=(-1, 0.3))
    r.door("DoorDown", "tl_to_deck", 4.0, 6.0, yaw=180)
    r.door("DoorRoof", "tl_to_roof", 6.0, 0.0)
    spawn_points(r, [("from_below", (4.0, 5.0), (0, -1)), ("from_above", (6.0, 1.2), (0, 1)), ("lamp2", (1.6, 2.5), (1, 0))], ("from_below", (4.0, 5.0), (0, -1)))
    warp(r)
    finish(r, "tower/tower_landing.tscn")


# ---------------------------------------------------------------- T5 the roof (stub until M5)
def roof():
    r = start("tower_roof", "TowerRoof", 20, 14, 30, (10, 7), (4, 2), 1.5, (0.34, 0.34, 0.38), (0.42, 0.44, 0.5))
    walls(r)
    scenery(r, "MastCrown", 10.0, 3.0, -0.4, 4.0, 6.0, 2.0, IRON)
    for i, y in enumerate((2.2, 3.6, 5.0)):
        scenery(r, "MastRingR%d" % i, 10.0, y, -0.4, 4.6, 0.16, 2.6, (0.55, 0.62, 0.5))
    for name, x in (("StackW", 1.5), ("StackE", 18.5)):
        scenery(r, name, x, 4.0, 1.5, 1.5, 8.0, 1.5, (0.3, 0.3, 0.34))
    for name, x, z, sx, sz in (("RailS", 10.0, 14.0, 20.0, 0.1), ("RailE", 20.0, 7.0, 0.1, 14.0)):
        scenery(r, name, x, 0.5, z, sx, 1.0, sz, (0.55, 0.58, 0.64))
    r.label("THE ROOF: Kasp and the Hushmaster arrive in M5", 10.0, 2.4, 9.0)
    r.door("DoorDown", "rf_to_landing", 3.0, 14.0, yaw=180)
    spawn_points(r, [("from_below", (3.0, 12.0), (0, -1))], ("from_below", (3.0, 12.0), (0, -1)))
    warp(r)
    finish(r, "tower/tower_roof.tscn")


if __name__ == "__main__":
    os.makedirs(os.path.join(OUT, "road"), exist_ok=True)
    os.makedirs(os.path.join(OUT, "tower"), exist_ok=True)
    spillway(); works_gate(); sump(); cable_hall(); bell_gallery(); generator(); jammer_deck(); landing(); roof()
    print("wrote the Spillway and the works rooms")
