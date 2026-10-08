#!/usr/bin/env python3
"""Writes the grim dressing data for the Spillway and the jammer works (M4-1) into game/data/world/look_dressing.json.

Run from the repo root:  python3 game/scripts/tools/make_works_dressing.py
Only the nine works rooms are written; every other entry in the file is left alone. (make_grim_dressing.py keeps
these nine too, so re-running that one never drops them.) Props are the shared builders in scripts/field/grim_props.gd,
visual only. Coordinates are the room's: x east along the north wall, z south toward the camera, y up.
The Spillway is a drain channel under the slums: pipes, cables, neon leaking through the ceiling grates onto the floor;
the works are factory floors with hazard stripes and quota screens, the old mast's stone and bells the one thing that is
not Signals gray. Screen text is placeholder, the Writer owns the words (M6-2); re-running keeps edited text.
"""
import json
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
import make_grim_dressing as g  # noqa: E402

P, line = g.P, g.line
DATA = g.DATA
SODIUM, TEAL, PINK = g.SODIUM, g.TEAL, g.PINK
ROOMS = ["road_mast_road", "road_mast_foot", "tower_sump", "tower_cable_hall", "tower_bell_gallery", "tower_generator",
         "tower_jammer_deck", "tower_landing", "tower_roof"]


def strip(kit, drop):
    kit["items"] = [i for i in kit["items"] if i["type"] not in drop]
    return kit


def spillway():
    kit = strip(g.interior(0, 34, 0, 8, "SPILLWAY", SODIUM, "QUIET 22:00", wall_h=4.0, variant=2), ("neon", "screen", "hang_lamp", "steam", "puddle"))
    colors = [SODIUM, TEAL, PINK, SODIUM, TEAL]
    for i, x in enumerate((5, 11, 17, 23, 29)):
        c = colors[i]
        kit["items"] += [
            P("smear", [x, 0, 2.6], size=[1.6, 2.2], color=c, energy=0.55),
            P("hang_lamp", [x, 3.9, 1.6], drop=0.15, color=c, energy=1.1, range=3.6),
        ]
    kit["items"] += [
        P("neon", [20.0, 3.0, 0.18], text="RELAY", color=TEAL, height=0.4, pattern="1111h1111011", phase=1),
        P("screen", [3.0, 2.8, 0.12], width=1.3, text="A QUIET MOON IS A SAFE MOON", kind="slogan"),
        P("puddle", [17.0, 0, 4.0], size=[30.0, 0.9]),
        P("steam", [14.0, 0, 6.2], rise=1.0), P("steam", [27.0, 0, 6.5], rise=0.9),
        P("poster", [14.0, 1.8, 0.08], variant=1, size=[0.7, 1.05]),
        P("stripes", [17.0, 0.03, 7.6], size=[32.0, 0.03, 0.2]),
    ]
    return kit


def works_gate():
    kit = strip(g.outdoor(0, 18, 0, 12, "GATE", SODIUM, wall_h=5.0, variant=1), ("rain", "shack"))
    kit["items"] += [
        P("floodlight", [5.0, 0, 1.5], aim_deg=-20.0, height=3.8), P("floodlight", [15.0, 0, 1.5], aim_deg=20.0, height=3.8),
        line("fence", [3.0, 0, 0.8], [8.8, 0, 0.8], height=1.8), line("fence", [13.2, 0, 0.8], [17.5, 0, 0.8], height=1.8),
        line("barbed", [3.0, 2.0, 0.8], [17.5, 2.0, 0.8]),
        P("loudspeaker", [11.0, 3.8, 0.9]),
        P("screen", [7.5, 3.2, 0.12], width=1.4, text="QUIET IS A DUTY", kind="slogan"),
        P("barrier", [3.0, 0, 9.6]),
        P("puddle", [6.0, 0, 8.0], size=[2.0, 1.2]),
    ]
    return kit


def sump():
    kit = strip(g.interior(0, 16, 0, 10, "OLD", TEAL, "HUSH", wall_h=4.0, variant=0), ("neon", "screen", "poster", "loudspeaker"))
    kit["items"] += [P("puddle", [4.0, 0, 7.0], size=[2.4, 1.4]), P("steam", [12.0, 0, 8.0], rise=0.8),
                     P("hang_lamp", [8.0, 3.9, 6.0], drop=0.7, color="#d9b070", energy=1.4, range=5.5)]
    return kit


def floor_kit(neon, color, screen, variant, extra=None):
    kit = g.interior(0, 16, 0, 10, neon, color, screen, wall_h=4.0, variant=variant)
    kit["items"] += [P("stripes", [8.0, 0.03, 9.6], size=[10.0, 0.03, 0.25]), P("loudspeaker", [13.0, 3.7, 0.3]),
                     P("poster", [4.5, 1.9, 0.08], variant=variant % 3, size=[0.8, 1.2])]
    kit["items"] += extra or []
    return kit


def cable_hall():
    return floor_kit("QUOTA", SODIUM, "QUOTA 400", 1, [
        line("cable", [3.0, 3.6, 0.3], [13.0, 3.4, 4.0], sag=0.4, strands=3, segments=6),
        line("cable", [13.0, 3.4, 4.0], [3.0, 3.6, 9.5], sag=0.4, strands=3, segments=6),
        P("steam", [5.0, 0, 7.5], rise=0.8)])


def bell_gallery():
    kit = floor_kit("QUIET", PINK, "QUIET", 0, [P("smear", [3.0, 0, 1.6], size=[0.8, 1.6], color=PINK, energy=0.5),
                                                  P("hang_lamp", [3.0, 3.8, 3.0], drop=0.4, color="#d9b070", energy=1.3, range=5.0)])
    return strip(kit, ("poster",))


def generator():
    return floor_kit("POWER", TEAL, "INSPECTED", 2, [P("hang_lamp", [6.0, 3.9, 6.0], drop=0.5, color="#bcd7ff", energy=1.3, range=5.0),
                                                      P("steam", [9.0, 0, 3.0], rise=1.0)])


def jammer_deck():
    kit = g.interior(0, 18, 0, 12, "JAM", TEAL, "DECAF ONLY", wall_h=4.0, variant=1)
    kit["items"] += [
        P("stripes", [9.0, 0.03, 11.6], size=[12.0, 0.03, 0.25]), P("loudspeaker", [14.0, 3.7, 0.3]),
        P("screen", [6.0, 3.0, 0.12], width=1.6, text="QUOTA 400 / 1,203", kind="alert"),
        P("hang_lamp", [9.0, 3.9, 6.0], drop=0.6, color="#bcd7ff", energy=1.6, range=6.0),
        P("hang_lamp", [14.0, 3.9, 9.0], drop=0.4, color=SODIUM, energy=1.2, range=4.0),
        line("cable", [9.0, 3.9, 6.0], [9.0, 3.9, 0.5], sag=0.1, strands=4, segments=4),
    ]
    return kit


def landing():
    kit = g.interior(0, 8, 0, 6, "UP", PINK, "QUIET", wall_h=3.0, variant=0)
    kit["items"] += [P("neon", [3.0, 2.5, 0.18], text="HEAR US", color=TEAL, height=0.3, pattern="1111h1111011", phase=3),
                     P("hang_lamp", [4.0, 2.9, 3.0], drop=0.4, color=SODIUM, energy=1.5, range=4.5)]
    return kit


def roof():
    kit = strip(g.outdoor(0, 20, 0, 14, "ROOF", SODIUM, wall_h=1.5, variant=2), ("shack", "fence"))
    kit["items"] += [P("skyline", [10.0, 0, 16.5], length=40.0, count=12, seed=23, base_y=-4.0, max_height=6.0),
                     P("steam", [1.5, 8.0, 1.5], rise=1.4), P("steam", [18.5, 8.0, 1.5], rise=1.4),
                     P("floodlight", [4.0, 0, 11.0], aim_deg=-30.0, height=3.0), P("floodlight", [17.0, 0, 11.0], aim_deg=30.0, height=3.0)]
    return kit


KITS = {"road_mast_road": spillway, "road_mast_foot": works_gate, "tower_sump": sump, "tower_cable_hall": cable_hall,
        "tower_bell_gallery": bell_gallery, "tower_generator": generator, "tower_jammer_deck": jammer_deck,
        "tower_landing": landing, "tower_roof": roof}


def build():
    with open(DATA) as f:
        data = json.load(f)
    for room_id in ROOMS:
        kit = KITS[room_id]()
        g.keep_written_text(kit, data["rooms"].get(room_id))
        data["rooms"][room_id] = kit
    with open(DATA, "w") as f:
        json.dump(data, f, indent=1)
    print("wrote the dressing for", ", ".join(ROOMS))


if __name__ == "__main__":
    build()
