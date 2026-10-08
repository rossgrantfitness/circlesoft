#!/usr/bin/env python3
"""Writes the grim dressing data for every room (game/data/world/look_dressing.json).

Run from the repo root:  python3 game/scripts/tools/make_grim_dressing.py

Ross approved the grim look on 2026-10-08 and asked for the slum-cyberpunk kit in every Harrow room, interiors
included, kept cheap. The three hand-placed sets (harrow_square, harrow_checkpoint, battle) are kept exactly as
they are in the file; every other room gets a kit built from its footprint here: a few posters, one neon sign,
a propaganda screen, a loudspeaker, a hanging bulb, cables and pipes along the walls, a steam vent, a puddle and
a hazard strip. Outdoor rooms add floodlights, fence, barbed wire, shacks and rain. Props are visual only; the
builders live in game/scripts/field/grim_props.gd. Rooms use the same map coordinates as the scenes: x east
along the north wall, z south toward the camera, y up. The north wall's face is at z = z0 and the west wall's
face at x = x0.
"""
import json
import os

DATA = os.path.join(os.path.dirname(__file__), "..", "..", "data", "world", "look_dressing.json")
KEEP = ("harrow_square", "harrow_checkpoint", "battle")

TEAL, SODIUM, PINK = "#5fe0c8", "#ff9a3c", "#ff3e9a"


def P(t, pos=None, yaw=0, **kw):
    d = {"type": t}
    if pos is not None:
        d["pos"] = [round(v, 3) for v in pos]
    if yaw:
        d["yaw"] = yaw
    d.update(kw)
    return d


def line(t, a, b, **kw):
    d = {"type": t, "from": [round(v, 3) for v in a], "to": [round(v, 3) for v in b]}
    d.update(kw)
    return d


def interior(x0, x1, z0, z1, neon, color, screen_text="ALL CLEAR", wall_h=3.0, variant=0):
    """The cheap indoor kit: walls with posters and pipes, one sign, one screen, a bulb, a leak."""
    w, d = x1 - x0, z1 - z0
    nz, wx = z0 + 0.08, x0 + 0.08
    items = [
        P("poster", [x0 + w * 0.22, 1.7, nz], variant=variant % 3, size=[0.7, 1.05]),
        P("poster", [x0 + w * 0.82, 1.6, nz], variant=(variant + 1) % 3, size=[0.62, 0.93]),
        P("poster", [wx, 1.7, z0 + d * 0.72], 90, variant=(variant + 2) % 3, size=[0.7, 1.05]),
        P("neon", [x0 + w * 0.55, wall_h - 0.55, nz + 0.06], text=neon, color=color, height=0.34,
          pattern="1111h111011" if variant % 2 == 0 else "11h11111", phase=variant, light_energy=1.0, light_range=3.0),
        P("screen", [wx, 2.0, z0 + d * 0.32], 90, width=0.95, text=screen_text, kind="slogan" if variant % 2 == 0 else "alert", light_energy=0.7),
        P("loudspeaker", [x0 + w * 0.38, wall_h - 0.25, z0 + 0.3]),
        P("hang_lamp", [x0 + w * 0.5, wall_h - 0.1, z0 + d * 0.45], drop=0.45, color=SODIUM, energy=1.6, range=4.0),
        line("cable", [x0 + 0.2, wall_h - 0.2, z0 + 0.3], [x0 + w * 0.5, wall_h - 0.15, z0 + d * 0.45], sag=0.25, strands=2, segments=5),
        line("cable", [x0 + w * 0.5, wall_h - 0.15, z0 + d * 0.45], [x1 - 0.3, wall_h - 0.2, z0 + 0.3], sag=0.3, strands=2, segments=5),
        line("pipe", [x0 + 0.2, wall_h - 0.3, z0 + 0.2], [x1 - 0.2, wall_h - 0.3, z0 + 0.2], radius=0.07),
        line("pipe", [x0 + 0.3, 0.0, z0 + 0.2], [x0 + 0.3, wall_h - 0.3, z0 + 0.2], radius=0.06),
        P("steam", [x0 + w * 0.82, 0, z0 + d * 0.28], rise=0.9),
        P("puddle", [x0 + w * 0.58, 0, z0 + d * 0.7], size=[1.2, 0.8]),
        P("stripes", [x0 + w * 0.5, 0.03, z0 + 0.3], size=[w * 0.55, 0.03, 0.18]),
        P("smear", [x0 + w * 0.55, 0, z0 + 0.8], size=[0.6, 0.9], color=color, energy=0.35),
    ]
    return {"key_light": {"color": "#d4e4e0", "energy": 0.8, "dir_deg": [-48.0, 36.0]}, "items": items}


def outdoor(x0, x1, z0, z1, neon, color, wall_h=3.0, variant=0):
    """An interior kit plus the outdoor extras: floodlight, fence, barbed wire, a shack and rain."""
    w, d = x1 - x0, z1 - z0
    kit = interior(x0, x1, z0, z1, neon, color, wall_h=wall_h, variant=variant)
    kit["items"] += [
        P("floodlight", [x0 + w * 0.8, 0, z0 + d * 0.5], aim_deg=-25.0, height=3.0),
        line("fence", [x1 - 0.3, 0, z0 + 0.8], [x1 - 0.3, 0, z1 - 0.4], height=1.5),
        line("barbed", [x0 + 0.1, wall_h + 0.25, z0 + 0.2], [x1, wall_h + 0.25, z0 + 0.2]),
        P("shack", [x0 + 1.0, 0, z1 - 1.0], size=[1.4, 1.5, 1.1], lights=["#ffb347", "#5fe0c8"], seed=40 + variant),
        {"type": "rain", "pos": [0, 0, 0], "origin": [x0, z0], "size": [w, d], "amount": int(min(110, 12 * w))},
    ]
    return kit


def docks():
    kit = outdoor(0, 24, 0, 9, "CLAIMS", TEAL, wall_h=5.0, variant=1)
    kit["items"] = [i for i in kit["items"] if i["type"] != "neon" and i["type"] != "rain" and i["type"] != "shack"]
    kit["items"] += [
        P("neon", [5.0, 3.4, 0.18], text="CLAIMS", color=TEAL, height=0.45, pattern="1111h1111011", phase=2),
        P("neon", [19.0, 3.4, 0.18], text="BAR", color=PINK, height=0.5, pattern="1110111011h1", phase=6),
        P("screen", [15.8, 3.0, 0.12], width=1.4, text="ALL CLEAR"),
        P("poster", [8.0, 2.0, 0.08], variant=0), P("poster", [14.6, 2.0, 0.08], variant=1, size=[0.8, 1.2]),
        P("floodlight", [9.0, 0, 3.6], aim_deg=-25.0, height=3.4), P("floodlight", [16.5, 0, 3.4], aim_deg=25.0, height=3.4),
        line("fence", [15.0, 0, 8.7], [19.0, 0, 8.7], height=1.1, barbed=False),
        P("stripes", [12.0, 0.03, 8.6], size=[18.0, 0.03, 0.35]),
        P("puddle", [7.0, 0, 5.4], size=[2.2, 1.4]), P("puddle", [16.0, 0, 6.0], size=[1.8, 1.2]), P("puddle", [11.0, 0, 7.4], size=[1.6, 1.0]),
        P("smear", [5.0, 0, 1.6], size=[1.0, 2.0], color=TEAL), P("smear", [19.0, 0, 1.6], size=[0.9, 1.8], color=PINK),
        P("steam", [10.0, 0, 3.0]), P("steam", [21.0, 0, 4.6]),
        P("shack", [22.5, 0, 6.5], size=[1.5, 1.7, 1.2], lights=["#ffb347"], seed=44),
        P("skyline", [12.0, 0, -2.6], length=28.0, count=9, seed=19, base_y=3.5, max_height=6.0),
        {"type": "rain", "pos": [0, 0, 0], "origin": [0, 0], "size": [24.0, 9.0], "amount": 130},
    ]
    return kit


def keep_written_text(room, old_room):
    """The Writer owns the words on signs and screens. Whatever text the file already has for a prop (matched by
    type and order within the room) wins over this generator's defaults, so re-running never reverts it."""
    old = {}
    for item in old_room.get("items", []) if old_room else []:
        if "text" in item:
            old.setdefault(item["type"], []).append(item["text"])
    seen = {}
    for item in room["items"]:
        if "text" in item:
            n = seen.get(item["type"], 0)
            seen[item["type"]] = n + 1
            if n < len(old.get(item["type"], [])):
                item["text"] = old[item["type"]][n]


def build():
    with open(DATA) as f:
        data = json.load(f)
    existing = data["rooms"]
    rooms = {k: v for k, v in data["rooms"].items() if k in KEEP}
    rooms["harrow_home"] = interior(0, 7, 0, 5, "HOME", TEAL, "CURFEW 22", variant=0)
    rooms["harrow_courier"] = interior(0, 8, 0, 6, "PARCEL", SODIUM, "ALL CLEAR", variant=1)
    rooms["harrow_store"] = interior(0, 7, 0, 5, "GOODS", SODIUM, "ALL CLEAR", variant=2)
    rooms["harrow_gear"] = interior(0, 7, 0, 5, "WELD", TEAL, "CURFEW 22", variant=1)
    rooms["harrow_dock_office"] = interior(0, 7, 0, 5, "CLAIMS", TEAL, "ALL CLEAR", variant=0)
    rooms["harrow_bar"] = interior(0, 9, 0, 6, "BAR", PINK, "CURFEW 22", variant=1)
    rooms["harrow_docks"] = docks()
    rooms["road_mast_road"] = outdoor(0, 10, 0, 6, "ROAD", SODIUM, variant=2)
    rooms["test_room"] = outdoor(-5, 13, -4, 4, "TEST", TEAL, variant=0)
    rooms["test_a"] = outdoor(-6, 10, -4, 4, "YARD A", SODIUM, variant=1)
    rooms["test_b"] = outdoor(-5, 9, -4, 4, "YARD B", TEAL, variant=2)
    for key, room in rooms.items():
        if key not in KEEP:
            keep_written_text(room, existing.get(key))
    data["rooms"] = rooms
    data["_about"] = ("What the grim look profile adds to each place (Technical Artist). 'rooms' keys are the dressing ids GrimDressing "
                      "nodes carry (a room's id, or 'battle'). Each item is one prop built by scripts/field/grim_props.gd: type, pos [x, y, z], "
                      "yaw (degrees), and that type's own numbers (see the builder). Positions are room coordinates (x east along the north wall, "
                      "z south toward the camera, y up). Props are visual only: no collision. key_light is the harsh extra light the profile adds. "
                      "harrow_square, harrow_checkpoint and battle are hand-placed; the other rooms are written by "
                      "scripts/tools/make_grim_dressing.py (re-running it keeps those three as they are).")
    with open(DATA, "w") as f:
        json.dump(data, f, indent=1)
    print("wrote", len(rooms), "rooms:", ", ".join(rooms))


if __name__ == "__main__":
    build()
