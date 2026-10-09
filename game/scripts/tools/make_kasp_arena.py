#!/usr/bin/env python3
"""Writes Kasp's arena (vertical slice task VS-29): scenes/slice/arena/kasp_arena.tscn and data/slice/robot_rooms/kasp_arena.json.

Blueprint: docs/maps/kasp_arena.md. One scene, two scales: the 40 m plateau (phase 1, Red on foot) inside the junkyard bowl (phase 2, the
colossus), with the dormant colossus visible in its cradle (Ross's A, 2026-10-09), the loader parked at the south gate, turret pylons, drone hatches,
the three rim cranes and the scrap heaps the junk mech is built from. Coordinates: metres, origin at the PLATEAU'S CENTRE, +X east, +Z south, +Y up.

Uses the Technical Artist's arena pieces (art/placeholder/bosses/arena/): wall segments, gate posts, plateau rail, turret pylons and scrap heaps and piles, plus
Ross's city tiles through the crisp shader (seam-fixed copies). Smashable clutter (containers, cars, crates in eight clusters) is NOT in the scene: it is
`props` in data/slice/robot_rooms/kasp_arena.json, built by RobotYard (the colossus smashes them), and written by this script from a fixed seed.

Named nodes for the boss code (the Combat Programmer's BossFight, VS-26 and VS-27), all Marker3Ds unless noted, under `Markers`:
  hushmaster_start (0, 3, 0); turret_k_nw (-13, 5.5, -14), turret_k_ne (13, 5.5, -14), turret_k_e (18, 5.5, 8) (y = the turret's mount on its pylon);
  drone_hatch_a (-10, 3, -6), drone_hatch_b (10, 3, -6), drone_hatch_c (0, 3, 11); kasp_escape_target (0, 3, -19); mech_start (0, 0, -110);
  loader_parked (8, 0, 56); term_save_arena (the SaveLamp node, -9, 0, 57); colossus_cradle (105, 0, 0), colossus_dock_pos (84, 0, 0), dock_approach (68.2, 0, 0);
  stockade_e_gate (62, 0, 0) and the closed barricade node `stockade_e_barricade` (a StaticBody3D the transition slides away); crane_a, crane_b, crane_c (Node3D, each with
  a `magnet` child Marker3D); camera shots `shot_wide`, `shot_ramp`, `shot_reveal`, `shot_title`, `shot_jack_in`, `shot_core_reveal` (a Marker3D looks along its -Z, like a camera).
  Spawns (under `Spawns`): from_j5 (0, 0, 58) facing north, retry_phase1 (0, 0, 54), retry_phase2 (84, 0, 0) facing west.

Run from the repo root:  python3 game/scripts/tools/make_kasp_arena.py
"""
import json
import math
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
import junk_kit as jk  # noqa: E402
from junk_kit import Y, GAME, PROPS, yaw_to, unit_hash  # noqa: E402

ARENA = "res://art/placeholder/bosses/arena/"
BOWL_R = 170.0
PLATEAU_R = 20.0
PLATEAU_H = 3.0
STOCKADE_R = 62.0
HEAPS = {"a": (-64.0, -95.0, 0.55), "b": (0.0, -110.0, 1.0), "c": (64.0, -95.0, 0.55)}
CRANES = {"a": (-64.0, -138.0), "b": (0.0, -152.0), "c": (64.0, -138.0)}


def tangent_yaw(angle):
    """Yaw that turns a model's local X along the circle's tangent at `angle` (radians, x = cos, z = sin)."""
    return math.degrees(math.atan2(-math.cos(angle), -math.sin(angle)))


def slab_transform(origin, yaw, tilt_deg):
    """Transform3D string for a slab that faces `yaw` and leans back by tilt_deg (Ry * Rx(-tilt))."""
    th, ph = math.radians(yaw), math.radians(-tilt_deg)
    c, s, cp, sp = math.cos(th), math.sin(th), math.cos(ph), math.sin(ph)
    rows = (c, s * sp, s * cp, 0.0, cp, -sp, -s, c * sp, c * cp)
    return "Transform3D(%.5f, %.5f, %.5f, %.5f, %.5f, %.5f, %.5f, %.5f, %.5f, %.3f, %.3f, %.3f)" % (rows + tuple(origin))


def build():
    r = Y("kasp_arena", "KaspArena", 2 * BOWL_R, 2 * BOWL_R, "arena")
    r.shell([(-BOWL_R, -BOWL_R, BOWL_R, BOWL_R)], "floor_concrete_cracked_dark", (0.85, 0.82, 0.85), sun=(0.9, 0.85, 0.9), sun_energy=2.0,
            sun_dir=(-0.5, -0.8, 0.3), fill_energy=1.6, ambient=(0.6, 0.62, 0.78))
    r.holder("Markers")
    r.holder("Props")
    rust = r.lit((0.36, 0.28, 0.24))
    steel = r.lit((0.55, 0.58, 0.64))
    hazard = r.lit((0.8, 0.68, 0.2))

    # ---- the plateau (phase 1): a 40 m disc 3 m up, a bullseye of 4 m bands, four hazard spokes (8 rays), a 1.1 m rail, and an 8 m ramp from the south
    r.cyl("Plateau", 0.0, PLATEAU_H / 2.0, 0.0, PLATEAU_R, PLATEAU_H, r.tile("floor_plate_diamond_cross_b", (PLATEAU_R * 2 / 2.0, PLATEAU_R * 2 / 2.0), (0.85, 0.85, 0.9)), solid=True)
    light, dark = r.lit((0.5, 0.48, 0.42), 0.8), r.lit((0.2, 0.22, 0.26), 0.8)
    for i, radius in enumerate((20.0, 16.0, 12.0, 8.0, 4.0)):
        r.cyl("Ring%d" % i, 0.0, PLATEAU_H + 0.012 + 0.006 * i, 0.0, radius - 0.05 * (i + 1), 0.02, light if i % 2 == 0 else dark)
    for k in range(4):
        r.box("Spoke%d" % k, 0.0, PLATEAU_H + 0.08, 0.0, 39.0, 0.02, 0.35, hazard, yaw=45.0 * k)
    th = math.atan2(3.0, 16.0)
    t = 3.6
    n = (0.0, math.cos(th), math.sin(th))
    r.tilted_box("Ramp", 0.0, 1.5 - (t / 2.0) * n[1], 28.0 - (t / 2.0) * n[2], 8.0, t, math.hypot(16.0, 3.0), r.tile("floor_rust_plate_quad", (4, 8), (0.8, 0.75, 0.7)), rx_deg=math.degrees(th))
    steps = 31
    for i in range(steps):
        a = math.tau * (i + 0.5) / steps
        x, z = 19.7 * math.cos(a), 19.7 * math.sin(a)
        if z > 0 and abs(x) < 5.6:
            continue                       # the ramp's mouth stays open
        yaw = tangent_yaw(a)
        r.glb("Rail%d" % i, ARENA + "plateau_rail_segment.glb", x, PLATEAU_H, z, yaw=yaw)
        r.collide("RailShape%d" % i, x, PLATEAU_H + 0.55, z, 4.1, 1.1, 0.24, yaw)
    # turret pylons (Kasp's guns, powered down until Red Overclocks one), drone hatches (flush lids)
    for tid, (x, z) in (("turret_k_nw", (-13.0, -14.0)), ("turret_k_ne", (13.0, -14.0)), ("turret_k_e", (18.0, 8.0))):
        yaw = yaw_to(-x, -z)
        r.glb("Pylon_" + tid, ARENA + "arena_turret_pylon.glb", x, PLATEAU_H, z, yaw=yaw)
        r.collide("PylonShape_" + tid, x, PLATEAU_H + 1.25, z, 1.6, 2.5, 1.9, yaw)
        r.marker(tid, "Markers", x, PLATEAU_H + 2.5, z, yaw=yaw, meta={"hijackable": True, "range_m": 36.0})
    for hid, (x, z) in (("a", (-10.0, -6.0)), ("b", (10.0, -6.0)), ("c", (0.0, 11.0))):
        r.cyl("HatchLid_" + hid, x, PLATEAU_H + 0.03, z, 1.5, 0.06, r.lit((0.3, 0.3, 0.34)))
        r.cyl("HatchLight_" + hid, x, PLATEAU_H + 0.07, z, 1.1, 0.03, r.glow((1.0, 0.7, 0.2), 0.9))
        r.marker("drone_hatch_" + hid, "Markers", x, PLATEAU_H, z)
    r.marker("hushmaster_start", "Markers", 0.0, PLATEAU_H, 0.0)
    r.marker("kasp_escape_target", "Markers", 0.0, PLATEAU_H, -19.0)

    # ---- the stockade ring (r 62, 8 m wall) with the south gate (the way in) and the east gate (barricaded; crane B lifts it away in the transition)
    segs = 32
    for k in range(segs):
        if k in (0, segs // 4):            # centred on the east gate (angle 0) and the south gate (angle 90)
            continue
        a = math.tau * k / segs
        x, z = STOCKADE_R * math.cos(a), STOCKADE_R * math.sin(a)
        yaw = tangent_yaw(a)
        r.glb("Wall%d" % k, ARENA + "arena_wall_segment.glb", x, 0.0, z, yaw=yaw, parent="Props")
        r.collide("WallShape%d" % k, x, 4.0, z, 12.33, 8.0, 5.7, yaw)
    for name, (cx, cz) in (("E", (STOCKADE_R, 0.0)), ("S", (0.0, STOCKADE_R))):
        for sign in (-1, 1):
            x, z = (cx, cz + sign * 7.0) if name == "E" else (cx + sign * 7.0, cz)
            r.glb("GatePost%s%d" % (name, sign), ARENA + "arena_gate_post.glb", x, 0.0, z, parent="Props")
            r.collide("GatePostShape%s%d" % (name, sign), x, 5.5, z, 4.0, 11.0, 4.0)
    r.marker("stockade_e_gate", "Markers", STOCKADE_R, 0.0, 0.0, yaw=-90)
    r.node("stockade_e_barricade", "StaticBody3D", ".", (STOCKADE_R, 0.0, 0.0))
    r.box("BarricadeMesh", 0.0, 4.0, 0.0, 3.0, 8.0, 10.0, rust, parent="stockade_e_barricade")
    r.node("BarricadeShape", "CollisionShape3D", "stockade_e_barricade", (0, 4.0, 0), extra="shape = %s" % r.box_shape((3.0, 8.0, 10.0)))

    # ---- the south gate: the way in from J5, the loader parked and the save terminal in a lean-to
    r.marker("loader_parked", "Markers", 8.0, 0.0, 56.0, yaw=180)
    r.box("LoaderPad", 8.0, 0.04, 56.0, 7.0, 0.08, 7.0, r.lit((0.42, 0.42, 0.45)))
    r.box("LeanToRoof", -9.0, 3.4, 56.0, 6.0, 0.2, 5.0, rust, fade=True)
    for sx in (-11.6, -6.4):
        r.box("LeanToPost%d" % int(sx), sx, 1.7, 54.0, 0.3, 3.4, 0.3, steel)
    r.node("term_save_arena", "Node3D", ".", (-9.0, 0, 57.0),
           extra='script = %s\nroom_id = "kasp_arena"\nspawn_id = "retry_phase1"\nrest = false\nreach = 1.8\nbuild_placeholder = false' % r.ext_res("Script", "res://scripts/save/save_lamp.gd"))
    r.box("TerminalPost", -9.0, 0.6, 57.0, 0.5, 1.2, 0.5, r.lit((0.3, 0.33, 0.38)), solid=True)
    r.box("TerminalScreen", -9.0, 1.3, 57.1, 0.6, 0.4, 0.06, r.glow((0.3, 1.0, 0.85), 1.2))
    r.omni("TerminalGlow", -9.0, 2.0, 57.6, (0.3, 1.0, 0.85), 0.9, 5.0)
    r.holder("Barks")
    r.marker("bark_arena_lastsave", "Barks", 0.0, 1.0, 56.0, meta={"radius_m": 8.0})

    # ---- the bowl: collision wall at r 161 (both robots stay in), the rim cliffs leaning back, scrap piles scattered, the three heaps
    for k in range(32):
        a = math.tau * (k + 0.5) / 32
        x, z = 161.0 * math.cos(a), 161.0 * math.sin(a)
        r.collide("BowlWall%d" % k, x, 20.0, z, 33.0, 40.0, 2.0, tangent_yaw(a))
    cliff = r.lit((0.3, 0.24, 0.2))
    r.holder("Rim")
    for k in range(36):
        a = math.tau * k / 36
        inward_yaw = math.degrees(math.atan2(-math.cos(a), -math.sin(a)))
        height = 62.0 + 48.0 * unit_hash("rim", k)
        width, thick = 33.0, 24.0
        base = (172.0 * math.cos(a), 0.0, 172.0 * math.sin(a))
        tilt = 35.0
        # centre of the leaning slab: base + half height along its tilted Y, half thickness outward
        ph = math.radians(-tilt)
        th_ = math.radians(inward_yaw)
        ys = (math.sin(th_) * math.sin(ph), math.cos(ph), math.cos(th_) * math.sin(ph))
        zs = (math.sin(th_) * math.cos(ph), -math.sin(ph), math.cos(th_) * math.cos(ph))
        centre = tuple(base[i] + ys[i] * height / 2.0 - zs[i] * thick / 2.0 for i in range(3))
        mesh = r.box_mesh((width, height, thick))
        r.nodes.append('[node name="RimSlab%d" type="MeshInstance3D" parent="Rim"]\ntransform = %s\nmesh = %s\nsurface_material_override/0 = %s\n' % (
            k, slab_transform(centre, inward_yaw, tilt), mesh, cliff))
    sizes = ("scrap_pile_s", "scrap_pile_m", "scrap_pile_l")
    placed = []
    attempt = 0
    while len(placed) < 28 and attempt < 600:
        attempt += 1
        a = math.tau * unit_hash("pile_a", attempt)
        rad = 78.0 + 70.0 * unit_hash("pile_r", attempt)
        x, z = rad * math.cos(a), rad * math.sin(a)
        if abs(x) < 16 and z > 0:        # the south lane
            continue
        if abs(z) < 16 and x > 0:        # the east lane
            continue
        if any(math.hypot(x - hx, z - hz) < 62 * hs + 10 for (hx, hz, hs) in HEAPS.values()):
            continue
        if x > 70 and abs(z) < 50:       # the cradle
            continue
        if any(math.hypot(x - px, z - pz) < 18 for (px, pz) in placed):
            continue
        placed.append((x, z))
        kind = sizes[int(unit_hash("pile_k", attempt) * 3) % 3]
        r.glb("Pile%d" % len(placed), ARENA + kind + ".glb", x, 0.0, z, yaw=360.0 * unit_hash("pile_y", attempt), parent="Props")
    for hid, (hx, hz, hs) in HEAPS.items():
        r.glb("Heap_" + hid, ARENA + "scrap_heap_giant.glb", hx, 0.0, hz, yaw=0.0 if hid == "b" else 25.0, scale=hs, parent="Props")
        r.collide("HeapShape_" + hid, hx, 9.0, hz, 83.0 * hs * 0.6, 18.0, 88.0 * hs * 0.6)
    r.marker("mech_start", "Markers", 0.0, 0.0, -110.0)

    # ---- the three rim cranes (90 m): a mast, a jib reaching over their heap and a magnet on a cable; crane B opens the east gate
    for cid, (cx, cz) in CRANES.items():
        hx, hz, _ = HEAPS[cid]
        r.holder("crane_" + cid, parent=".", x=cx, z=cz)
        r.box("Mast_" + cid, 0.0, 45.0, 0.0, 4.0, 90.0, 4.0, hazard, parent="crane_" + cid)
        jib_len = math.hypot(hx - cx, hz - cz) + 6.0
        direction = (hx - cx, hz - cz)
        ang = math.degrees(math.atan2(-direction[1], direction[0]))
        r.box("Jib_" + cid, direction[0] / 2.0, 88.0, direction[1] / 2.0, jib_len, 3.0, 3.0, hazard, parent="crane_" + cid, yaw=ang)
        r.box("Cable_" + cid, direction[0], 70.0, direction[1], 0.4, 36.0, 0.4, rust, parent="crane_" + cid)
        r.box("MagnetBody_" + cid, direction[0], 50.0, direction[1], 6.0, 2.0, 6.0, r.lit((0.3, 0.3, 0.36)), parent="crane_" + cid)
        r.marker("magnet", "crane_" + cid, direction[0], 50.0, direction[1])

    # ---- the colossus in its cradle (visible from the first frame): a gantry, a foot plate, the model comes from the robot data
    r.box("CradleFoot", 105.0, 0.5, 0.0, 22.0, 1.0, 22.0, r.lit((0.28, 0.28, 0.32)), solid=True)
    for sz in (-34.0, 34.0):
        r.box("CradleTower%d" % int(sz), 112.0, 36.0, sz, 6.0, 72.0, 6.0, hazard, solid=True)
    r.box("CradleBeam", 112.0, 70.0, 0.0, 5.0, 5.0, 74.0, hazard)
    r.marker("colossus_cradle", "Markers", 105.0, 0.0, 0.0, yaw=-90)
    r.marker("colossus_dock_pos", "Markers", 84.0, 0.0, 0.0, yaw=-90)
    r.marker("dock_approach", "Markers", 68.2, 0.0, 0.0, yaw=-90)

    # ---- camera shots (a Marker3D looks along its -Z): the wide from behind the gate, the low ramp track, Kasp's reveal, the title, the jack-in, the core
    r.holder("Shots")
    r.aimed_marker("shot_wide", "Shots", (0.0, 4.5, 78.0), (14.0, 6.0, 0.0))
    r.aimed_marker("shot_ramp", "Shots", (0.0, 1.3, 38.0), (0.0, 4.0, 18.0))
    r.aimed_marker("shot_reveal", "Shots", (6.0, 4.4, 17.0), (0.0, 7.5, 0.0))
    r.aimed_marker("shot_title", "Shots", (-14.0, 4.2, 12.0), (0.0, 6.0, -4.0))
    r.aimed_marker("shot_jack_in", "Shots", (8.0, 5.5, 8.0), (0.0, 4.5, 0.0))
    r.aimed_marker("shot_core_reveal", "Shots", (60.0, 40.0, -20.0), (0.0, 26.0, -105.0))

    # ---- lights: floodlights around the plateau and warm lamps at the south gate, the colossus's dim eyes
    for i in range(6):
        a = math.tau * i / 6 + 0.3
        r.omni("Flood%d" % i, 30.0 * math.cos(a), 16.0, 30.0 * math.sin(a), (1.0, 0.82, 0.6), 4.0, 55.0)
    r.omni("GateLamp", 0.0, 8.0, 60.0, (1.0, 0.75, 0.45), 2.5, 24.0)
    r.omni("ColossusEyeLamp", 90.0, 46.0, 0.0, (1.0, 0.4, 0.15), 3.0, 70.0)
    r.omni("ColossusRim", 70.0, 30.0, 40.0, (0.6, 0.8, 1.0), 4.0, 90.0)

    r.spawn("from_j5", 0.0, 58.0, face=(0, -1))
    r.spawn("retry_phase1", 0.0, 54.0, face=(0, -1))
    r.spawn("retry_phase2", 84.0, 0.0, face=(-1, 0))
    r.write("kasp_arena.tscn")


def robot_data():
    """data/slice/robot_rooms/kasp_arena.json: the loader parked at the gate, the colossus standing in its cradle, and eight clusters of smashable clutter."""
    props = []
    angles = (22.0, 62.0, 112.0, 152.0, 198.0, 332.0, 245.0, 295.0)
    kinds = ("car", "container", "crate_large", "car", "container", "crate_small", "car", "container")
    for ci, deg in enumerate(angles):
        a = math.radians(deg)
        rad = 96.0 + 20.0 * unit_hash("cluster_r", ci)
        cx, cz = rad * math.cos(a), rad * math.sin(a)
        # keep clutter off the heaps and the cradle
        for _ in range(8):
            if any(math.hypot(cx - hx, cz - hz) < 62 * hs + 16 for (hx, hz, hs) in HEAPS.values()) or (cx > 70 and abs(cz) < 50):
                rad += 10.0
                cx, cz = rad * math.cos(a), rad * math.sin(a)
        count = 6 + int(unit_hash("cluster_n", ci) * 4)
        for j in range(count):
            px = cx + (unit_hash("px", ci, j) - 0.5) * 24.0
            pz = cz + (unit_hash("pz", ci, j) - 0.5) * 24.0
            if math.hypot(px, pz) < 90.0 or math.hypot(px, pz) > 150.0:
                continue
            if px > 70.0 and abs(pz) < 56.0:      # the cradle
                continue
            if any(math.hypot(px - hx, pz - hz) < 62 * hs * 0.6 + 10 for (hx, hz, hs) in HEAPS.values()):
                continue
            props.append({"kind": kinds[(ci + j) % len(kinds)], "pos": [round(px, 1), 0.0, round(pz, 1)], "yaw_deg": round(360.0 * unit_hash("py", ci, j), 0)})
    data = {
        "_about": "VS-29 (written by scripts/tools/make_kasp_arena.py from a fixed seed; edit the generator or hand-edit and stop re-running it). The robots of Kasp's arena: the loader parked at the south gate (loader_parked, facing north) and the colossus standing dormant in its cradle at the east edge (colossus_cradle, facing west). Phase 2's boarding and docking (RobotStage.place_in / dock) move them: the colossus steps to colossus_dock_pos (84, 0). `props` are the eight clusters of smashable containers, cars and crates on the bowl floor, outside the stockade, off the heaps and the cradle (kasp_arena.md); two containers in each cluster hold a repair cell if Ross approves boss_design.md decision 2. Positions are the arena's own coordinates (origin at the plateau's centre).",
        "version": 1,
        "ground": False,
        "small_robot": {"pos": [8.0, 0.0, 56.0], "yaw_deg": 180.0},
        "huge_robot": {"pos": [105.0, 0.0, 0.0], "yaw_deg": -90.0},
        "props": props,
    }
    path = os.path.join(GAME, "data", "slice", "robot_rooms", "kasp_arena.json")
    with open(path, "w") as f:
        json.dump(data, f, indent=1)
    return len(props)


if __name__ == "__main__":
    build()
    count = robot_data()
    print("wrote Kasp's arena and its robot data (%d smashable props)" % count)
