#!/usr/bin/env python3
"""Builds the PLACEHOLDER townsfolk body of the vertical slice (task VS-25). Needs Python 3 + numpy only.

    python3 game/scripts/tools/make_townsfolk.py                  # writes art/placeholder/characters/townsfolk/townsfolk_blockout.glb
    python3 game/scripts/tools/retarget_ual.py townsfolk          # bakes idle / talk / walk onto it (townsfolk_blockout_ual.glb)
    godot --headless --path game --import                         # once, for the .glb.import files

One plain 1.0 m mannequin on Red's bone names (scaled), so the free Quaternius clips retarget like they do for Red, Kasp and the
robots. It is the rig the market NPCs use until Ross's market residents (VS-A4.4) arrive: they follow the same bone contract, so the
same clips and `data/animation/retarget_townsfolk.json` carry over by changing the target path. Colours are flat glTF material
colours (body, cloth, trousers, boots), so a colour swap is one material colour per NPC.

The FACE AREA IS SEPARABLE (the approved swappable-faces design, not built yet): the head is one mesh node (`townsfolk_body`) and the
face is its own thin plate on the front of it (`townsfolk_face`, material `townsfolk_face`), bound to the head bone, so a later face
system can swap its material or hide it without touching the body. Axes: glTF space, Y up, faces +Z, left (l) is +X, metres.
"""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from glb_kit import load_glb  # noqa: E402
from make_bosses import flat, write_rigged  # noqa: E402
from make_robots import RED  # noqa: E402
from robot_kit import Builder, scaled_rig  # noqa: E402

GAME_DIR = os.path.abspath(os.path.join(HERE, "..", ".."))
OUT = os.path.join(GAME_DIR, "art", "placeholder", "characters", "townsfolk", "townsfolk_blockout.glb")
HEIGHT = 1.0
UNIT = HEIGHT / 0.951


def build(path):
    red_doc, _ = load_glb(RED)
    rig = scaled_rig(red_doc, UNIT, [])
    nodes, joints, names, mesh_node, arm = rig
    index = {nodes[n]["name"]: k for k, n in enumerate(joints)}
    shared = Builder()
    skin = flat(shared, "townsfolk_skin", "#C9A27A", 0.95)
    cloth = flat(shared, "townsfolk_cloth", "#6F7F8F", 0.9)
    trousers = flat(shared, "townsfolk_trousers", "#4A4A55", 0.9)
    boots = flat(shared, "townsfolk_boots", "#2B2B33", 0.8)
    face = flat(shared, "townsfolk_face", "#E8D8BC", 0.9)
    eye = flat(shared, "townsfolk_eye", "#161C28", 0.4)
    b = Builder(UNIT, index)
    b.materials, b.images = shared.materials, shared.images
    f = Builder(UNIT, index)
    f.materials, f.images = shared.materials, shared.images
    for s, sx in (("l", 1), ("r", -1)):
        b.box("foot_" + s, (sx * .105, .035, .03), (.12, .07, .2), boots)
        b.frustum("shin_" + s, (sx * .10, .19, .005), (sx * .105, .07, 0.0), (.052, .056), (.046, .05), trousers)
        b.frustum("thigh_" + s, (sx * .085, .37, 0.0), (sx * .10, .2, .005), (.066, .07), (.056, .06), trousers)
        b.frustum("upper_arm_" + s, (sx * .152, .6, 0.0), (sx * .245, .525, 0.0), (.052, .058), (.048, .052), cloth)
        b.frustum("forearm_" + s, (sx * .245, .521, 0.0), (sx * .3, .431, 0.0), (.046, .05), (.05, .054), cloth)
        b.box("hand_" + s, (sx * .307, .395, .01), (.07, .075, .08), skin)
        b.box("shoulder_" + s, (sx * .075, .625, 0.0), (.09, .08, .12), cloth)
    b.box("hips", (0.0, .385, 0.0), (.27, .1, .19), trousers)
    b.box("spine", (0.0, .46, 0.0), (.24, .07, .17), cloth)
    b.box("chest", (0.0, .56, 0.0), (.31, .17, .22), cloth)
    b.box("neck", (0.0, .65, 0.0), (.12, .04, .1), skin)
    b.box("head", (0.0, .745, .005), (.27, .19, .22), skin)
    # the face area: a thin plate on the front of the head, its own mesh node and material (swappable later)
    f.box("head", (0.0, .745, .1165), (.2, .13, .008), face)
    for sx in (-1, 1):
        f.box("head", (sx * .05, .762, .1225), (.028, .034, .006), eye)
    return write_rigged(path, shared, rig, [("townsfolk_body", b), ("townsfolk_face", f)], "townsfolk",
                        "Placeholder blockout (task VS-25): a plain 1.0 m mannequin on Red's bone names (scaled x%.2f); body mesh townsfolk_body, separable face plate townsfolk_face." % UNIT)


if __name__ == "__main__":
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    print("townsfolk_blockout.glb", build(OUT), "tris")
