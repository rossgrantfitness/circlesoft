#!/usr/bin/env python3
"""Placeholder scrap props for the loader section (vertical slice task VS-22): the loader-only scrap walls, the Foreman's gate and a three-high container stack.

Run from the repo root:  python3 game/scripts/tools/make_scrap_walls.py
Writes four .glb files beside the robot-test props in game/art/placeholder/robots/props/ (placeholders only: Ross makes the final art), drawn with the same
builder, materials and Ross's city tiles as make_robots.py (nothing there is changed). Origin: the middle of the footprint on the floor; width along X.
  prop_scrap_wall_3m     12 x 3 x 1.6 m   Breaker's Lane and the Foreman's layers (hp 60)
  prop_scrap_wall_6m      9 x 6 x 4 m     J4's smash wall (hp 120)
  prop_scrap_gate_12m    16 x 12 x 4 m    the Foreman's gate (hp 400)
  prop_container_stack   2.58 x 7.86 x 6.13 m   three containers high, the canyon's walls (hp 90)
The yard kinds that use them are in data/combat/robot_yard.json ("scrap_wall_3m" ...); the sizes below must match their aabb_size.
"""
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(__file__))
import make_robots as mr  # noqa: E402
from robot_kit import Builder, write_glb  # noqa: E402


def plates(name, w, h, d, seed):
    b = Builder()
    m = mr.prop_materials(b)
    b.materials[m["plates"]]["tile_m"] = 3.0
    b.materials[m["steel"]]["tile_m"] = 3.0
    b.materials[m["hazard"]]["tile_m"] = 1.5
    rng = np.random.default_rng(seed)
    # a heap of crushed plates: layered slabs, a few leaning panels and sticking-out beams
    b.box(None, (0, h / 2, 0), (w, h, d), m["plates"])
    layers = max(2, int(h / 1.5))
    for i in range(layers):
        y = (i + 0.5) * h / layers
        b.box(None, (rng.uniform(-0.3, 0.3), y, d / 2 + 0.05), (w * rng.uniform(0.8, 0.98), h / layers * 0.9, 0.1), m["steel"] if i % 2 else m["plates"])
        b.box(None, (rng.uniform(-0.3, 0.3), y, -d / 2 - 0.05), (w * rng.uniform(0.8, 0.98), h / layers * 0.9, 0.1), m["steel"] if i % 2 == 0 else m["plates"])
    for k in range(int(w / 2)):
        x = -w / 2 + (k + 0.5) * w / int(w / 2)
        b.box(None, (x, h + 0.1, 0), (0.25, 0.3 + rng.uniform(0, 0.6), d * 0.9), m["frame"])
    b.box(None, (0, 0.05, 0), (w + 0.2, 0.1, d + 0.2), m["hazard"])
    b.box(None, (0, h * 0.5, d / 2 + 0.12), (w * 0.5, 0.25, 0.04), m["hazard"])
    return b


def stack(name):
    b = Builder()
    m = mr.prop_materials(b)
    b.materials[m["plates"]]["tile_m"] = 3.0
    for level in range(3):
        y0 = level * 2.62
        b.box(None, (0, y0 + 1.3, 0), (2.5, 2.6, 6.0), m["plates"] if level != 1 else m["steel"])
        for z in np.linspace(-2.8, 2.8, 8):
            b.box(None, (0, y0 + 1.3, z), (2.58, 2.62, 0.08), m["frame"])
        b.box(None, (0, y0 + 1.3, 3.02), (2.3, 2.4, 0.06), m["vent"])
        b.box(None, (0, y0 + 2.45, 3.06), (2.2, 0.2, 0.04), m["hazard"])
    return b


PROPS = [
    ("prop_scrap_wall_3m", lambda: plates("prop_scrap_wall_3m", 12.0, 3.0, 1.6, 11), "scrap wall 12 x 3 m, loader-only"),
    ("prop_scrap_wall_6m", lambda: plates("prop_scrap_wall_6m", 9.0, 6.0, 4.0, 12), "scrap wall 9 x 6 m, 4 m thick"),
    ("prop_scrap_gate_12m", lambda: plates("prop_scrap_gate_12m", 16.0, 12.0, 4.0, 13), "the Foreman's gate 16 x 12 m"),
    ("prop_container_stack", lambda: stack("prop_container_stack"), "three containers high, 7.9 m"),
]


if __name__ == "__main__":
    os.makedirs(mr.PROPS, exist_ok=True)
    for name, make, note in PROPS:
        b = make()
        write_glb(os.path.join(mr.PROPS, name + ".glb"), b, name, note=note)
        top = max(p[1] for pr in b.prims.values() for p in pr["pos"])
        print("%-22s %5d tris  top %.2f m  (%s)" % (name, b.tri_count, top, note))
