#!/usr/bin/env python3
"""Builds the PLACEHOLDER robots and scale props of the giant-robot scale test (task CS-21). Needs Python 3 + numpy only.

    python3 game/scripts/tools/make_robots.py             # models + the two retarget settings files
    python3 game/scripts/tools/retarget_ual.py robot_small   # then bake the Quaternius clips (needs the .glb.import files:
    python3 game/scripts/tools/retarget_ual.py robot_huge    #   run `godot --headless --path game --import` once first)

Everything lands in game/art/placeholder/robots/ (placeholders only: Ross makes the final art). Ross's city tiles are read-only
inputs, embedded into the new .glb files as copies. Red's rigged file is only READ: the robots copy her bone hierarchy and bone
names (scaled), plus a few extra bones for the hatch, the docking bay and the boarding points.

Both robots are the same drawing at two scales (Red is 0.95 m tall; the small robot is 3.68x her = 3.5 m, the huge one 52.6x = 50 m),
so the same controller, the same retargeted clips and the same bone names drive them. Original designs: a squat riveted loader
frame (hatch in the back, a ladder and a step) and a blast-furnace colossus (clamshell docking bay in the chest, smokestacks).
"""
import json
import math
import os
import sys

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from glb_kit import Skeleton, load_glb  # noqa: E402
from robot_kit import Builder, read_png, rot_x, rot_y, rot_z, scaled_rig, write_glb, write_png_bytes  # noqa: E402

GAME_DIR = os.path.abspath(os.path.join(HERE, "..", ".."))
OUT = os.path.join(GAME_DIR, "art", "placeholder", "robots")
PROPS = os.path.join(OUT, "props")
TILES = os.path.join(GAME_DIR, "art", "final", "textures", "city")
RED = os.path.join(GAME_DIR, "art", "final", "characters", "red", "red_ross_v1_rigged.glb")
RED_CFG = os.path.join(GAME_DIR, "data", "animation", "retarget_red.json")

RED_HEIGHT = 0.951                      # Red's rigged mesh top, metres
SMALL_HEIGHT = 3.5
HUGE_HEIGHT = 50.0
UNIT_SMALL = SMALL_HEIGHT / RED_HEIGHT
UNIT_HUGE = HUGE_HEIGHT / RED_HEIGHT


# ------------------------------------------------------------------ tiles and colours
def tile(name, folder="tiles_seamless"):
    path = os.path.join(TILES, folder, name + ".png")
    with open(path, "rb") as f:
        return (name, f.read())


def hazard_texture():
    """A 64x64 diagonal hazard stripe in the colours sampled from Ross's own hazard tile (so it matches the city)."""
    w, h, px = read_png(os.path.join(TILES, "tiles", "floor_hazard_stripe_yellow_band.png"))
    rgb = px[:, :, :3].reshape(-1, 3).astype(float)
    lum = rgb @ np.array([0.3, 0.59, 0.11])
    yellowness = rgb[:, 0] + rgb[:, 1] - 1.4 * rgb[:, 2]
    yellow = np.median(rgb[np.argsort(yellowness)[-200:]], axis=0)
    dark = np.median(rgb[np.argsort(lum)[:200]], axis=0)
    size = 64
    out = np.zeros((size, size, 3), dtype=np.uint8)
    for y in range(size):
        for x in range(size):
            out[y, x] = yellow if ((x + y) % 32) < 16 else dark
    return ("hazard_stripe_generated", write_png_bytes(out))


def flat(b, name, hexcolor, rough=0.9):
    c = tuple(int(hexcolor[i:i + 2], 16) / 255.0 for i in (1, 3, 5))
    return b.material(name, c, rough=rough)


def tiled(b, name, tile_info, tint, tile_m):
    return b.material(name, tint, tile=tile_info, tile_m=tile_m)


# ------------------------------------------------------------------ the shared skeleton drawing
class Rig:
    def __init__(self, unit, extras):
        self.red_doc, _ = load_glb(RED)
        self.unit = unit
        self.extras = extras
        self.nodes, self.joints, self.names, self.mesh_node, self.arm = scaled_rig(self.red_doc, unit, extras)
        self.joint_index = {self.nodes[n]["name"]: k for k, n in enumerate(self.joints)}
        self.rig = (self.nodes, self.joints, self.names, self.mesh_node, self.arm)


SMALL_EXTRAS = [
    {"name": "cockpit_hatch", "parent": "chest", "at": (0.0, 0.48, -0.129)},     # the door: turn about X to fold it down into a ramp
    {"name": "cockpit_seat", "parent": "chest", "at": (0.0, 0.50, -0.02)},       # where Red sits (her root goes here)
    {"name": "boarding_point", "parent": "root", "at": (0.0, 0.0, -0.30)},       # on the ground behind the robot: Red walks here, then climbs
    {"name": "dock_anchor", "parent": "root", "at": (0.0, 0.0, 0.0)},            # the floor point between its feet: lines up with the huge robot's dock_point
]
HUGE_EXTRAS = [
    {"name": "dock_door_l", "parent": "chest", "at": (0.0575, 0.55, 0.11)},      # chest bay door, hinge on its outer edge: turn +100 deg about Y to open
    {"name": "dock_door_r", "parent": "chest", "at": (-0.0575, 0.55, 0.11)},     # the other door: turn -100 deg about Y
    {"name": "dock_point", "parent": "chest", "at": (0.0, 0.505, 0.077)},        # the bay floor, centre: the small robot's dock_anchor goes here
    {"name": "dock_lift", "parent": "hand_l", "at": (0.305, 0.365, 0.0)},        # the left palm: an optional lift stage (small robot rides it up to the bay)
    {"name": "dock_approach", "parent": "root", "at": (0.0, 0.0, 0.30)},         # on the ground in front of the huge robot: where the small robot stops
]


# ------------------------------------------------------------------ the small robot: a squat riveted loader frame
def build_small(b):
    m = {
        "armor": tiled(b, "armor_rust", tile("rust_riveted_plates_tall"), (1.0, 0.88, 0.82), 1.2),
        "armor2": tiled(b, "armor_steel", tile("steel_plate_riveted_grey"), (0.88, 0.92, 1.0), 1.2),
        "vent": tiled(b, "vent_louvers", tile("rust_vent_louvers_wide"), (0.85, 0.85, 0.9), 0.8),
        "hazard": tiled(b, "hazard", hazard_texture(), (0.92, 0.88, 0.8), 1.6),
        "frame": flat(b, "frame_dark", "#3C3C52"),
        "brass": flat(b, "brass", "#B98B38", 0.5),
        "amber": flat(b, "lamp_amber", "#FFB347", 0.3),
        "glass": flat(b, "glass_dark", "#1B2230", 0.2),
    }
    for sx, s in ((1, "l"), (-1, "r")):
        X = lambda v: sx * v
        # feet, shins, knees, thighs
        b.box("foot_" + s, (X(.105), .032, .025), (.115, .064, .205), m["armor2"])
        b.box("foot_" + s, (X(.105), .022, .141), (.12, .044, .034), m["frame"])
        b.box("foot_" + s, (X(.105), .074, -.005), (.085, .05, .095), m["frame"])
        b.box("foot_" + s, (X(.105), .066, .06), (.1, .004, .07), m["hazard"])
        b.box("foot_" + s, (X(.105), .03, -.085), (.09, .05, .02), m["frame"])
        b.frustum("shin_" + s, (X(.10), .19, .005), (X(.105), .09, 0.0), (.052, .055), (.04, .045), m["armor"])
        b.box("shin_" + s, (X(.1035), .125, 0.0), (.098, .028, .104), m["hazard"])
        b.box("shin_" + s, (X(.102), .17, .052), (.1, .085, .045), m["armor2"])
        b.box("shin_" + s, (X(.1), .17, -.06), (.07, .12, .03), m["frame"])
        b.prism("thigh_" + s, (X(.052), .191, .005), (X(.148), .191, .005), .036, .036, m["frame"], n=8)
        b.frustum("thigh_" + s, (X(.085), .37, 0.0), (X(.10), .205, .005), (.058, .06), (.05, .052), m["armor"])
        b.box("thigh_" + s, (X(.085), .30, .062), (.08, .08, .02), m["armor2"])
        # shoulders, arms, fists
        b.box("shoulder_" + s, (X(.075), .625, 0.0), (.07, .07, .1), m["frame"])
        b.box("upper_arm_" + s, (X(.172), .627, 0.0), (.095, .065, .125), m["armor2"])
        b.box("upper_arm_" + s, (X(.172), .6615, 0.0), (.09, .008, .12), m["hazard"])
        b.row("upper_arm_" + s, (X(.13), .6, .064), (X(.215), .6, .064), 3, (.012, .012, .008), m["brass"])
        b.frustum("upper_arm_" + s, (X(.152), .6, 0.0), (X(.245), .525, 0.0), (.043, .047), (.04, .043), m["armor"])
        b.prism("forearm_" + s, (X(.245), .521, -.05), (X(.245), .521, .05), .038, .038, m["frame"], n=8)
        b.frustum("forearm_" + s, (X(.245), .521, 0.0), (X(.3), .431, 0.0), (.052, .058), (.058, .065), m["armor"])
        b.box("forearm_" + s, (X(.2915), .445, 0.0), (.13, .02, .14), m["hazard"])
        b.box("hand_" + s, (X(.307), .395, .01), (.1, .085, .11), m["frame"])
        b.box("hand_" + s, (X(.307), .395, .072), (.09, .06, .016), m["armor2"])
        # exhaust hoses where Red's ears are, ending in a brass cap
        b.prism("ear_" + s, (X(.115), .785, -.05), (X(.153), .676, -.115), .019, .019, m["frame"], n=8)
        b.box("ear_%s_2" % s, (X(.153), .668, -.118), (.04, .03, .04), m["brass"])
        # side engine pods on the back, each with a stack
        b.box("back", (X(.105), .585, -.152), (.075, .15, .075), m["armor2"])
        b.prism("back", (X(.105), .66, -.152), (X(.105), .73, -.152), .018, .016, m["frame"], n=8)
        b.prism("back", (X(.105), .73, -.152), (X(.105), .738, -.152), .02, .02, m["brass"], n=8)
    # pelvis and waist
    b.box("hips", (0.0, .385, 0.0), (.27, .085, .19), m["armor2"])
    b.box("hips", (0.0, .335, 0.0), (.1, .04, .12), m["frame"])
    b.box("hips", (0.0, .425, 0.0), (.275, .016, .195), m["hazard"])
    b.box("spine", (0.0, .455, 0.0), (.21, .07, .16), m["frame"])
    # chest: the main block, yoke, front vent and floodlight
    b.box("chest", (0.0, .565, 0.0), (.31, .16, .225), m["armor"])
    b.box("chest", (0.0, .655, -.02), (.27, .03, .17), m["armor2"])
    b.box("chest", (0.0, .545, .117), (.14, .08, .012), m["vent"])
    b.box("chest", (0.0, .488, .115), (.302, .026, .004), m["hazard"])
    b.row("chest", (-.13, .62, .1135), (.13, .62, .1135), 6, (.012, .012, .006), m["brass"])
    b.prism("lamp_socket", (0.0, .6, .112), (0.0, .6, .13), .032, .032, m["brass"], n=8)
    b.prism("lamp_socket", (0.0, .6, .13), (0.0, .6, .134), .024, .024, m["amber"], n=8)
    b.box("neck", (0.0, .65, 0.0), (.1, .05, .09), m["frame"])
    # the cockpit hatch in the back: brass rim, dark opening, a door that folds down into a ramp, a ladder and a step
    b.box("chest", (0.0, .555, -.1155), (.2, .17, .006), m["brass"])
    b.box("chest", (0.0, .555, -.1195), (.15, .13, .002), m["glass"])
    b.box("cockpit_hatch", (0.0, .555, -.129), (.17, .15, .016), m["armor2"])
    b.box("cockpit_hatch", (0.0, .495, -.1385), (.17, .02, .003), m["hazard"])
    b.prism("cockpit_hatch", (0.0, .56, -.137), (0.0, .56, -.145), .026, .026, m["brass"], n=8)
    b.box("chest", (0.0, .50, -.127), (.1, .01, .024), m["brass"])
    b.box("chest", (0.0, .458, -.127), (.1, .01, .024), m["brass"])
    b.box("tail", (0.0, .405, -.15), (.13, .022, .075), m["hazard"])
    b.box("tail", (0.0, .385, -.135), (.1, .03, .05), m["frame"])
    # head: a squat helmet with one tall sensor slot, a brow, a vent chin; a beacon mast on top
    b.box("head", (0.0, .745, .005), (.22, .135, .18), m["armor2"])
    b.box("head", (0.0, .81, .01), (.24, .025, .2), m["armor"])
    b.box("head", (0.0, .695, .07), (.12, .03, .04), m["vent"])
    b.box("head", (0.0, .75, .0965), (.034, .1, .01), m["amber"])
    for sx in (1, -1):
        b.box("head", (sx * .115, .74, 0.0), (.025, .09, .12), m["frame"])
        b.box("head", (sx * .06, .75, .0975), (.012, .1, .006), m["frame"])
    b.prism("head_gear", (0.0, .812, 0.0), (0.0, .86, 0.0), .022, .02, m["brass"], n=8)
    b.prism("head_gear", (0.0, .86, 0.0), (0.0, .935, 0.0), .006, .005, m["frame"], n=6)
    b.box("head_gear", (0.0, .943, 0.0), (.016, .016, .016), m["amber"])
    # extra plating and plumbing (gives the silhouette its bolted-on look)
    for sx in (1, -1):
        b.prism("thigh_" + ("l" if sx > 0 else "r"), (sx * .125, .35, .05), (sx * .12, .23, .062), .01, .01, m["brass"], n=6)
        b.prism("thigh_" + ("l" if sx > 0 else "r"), (sx * .05, .35, .05), (sx * .055, .23, .062), .01, .01, m["brass"], n=6)
        b.row("shin_" + ("l" if sx > 0 else "r"), (sx * .075, .2, .076), (sx * .13, .2, .076), 3, (.012, .012, .008), m["brass"])
        b.box("forearm_" + ("l" if sx > 0 else "r"), (sx * .262, .5, .06), (.06, .05, .02), m["armor2"])
        b.box("chest", (sx * .1, .6, .1135), (.05, .04, .004), m["frame"])
        b.box("chest", (sx * .158, .565, 0.0), (.008, .1, .15), m["frame"])
        b.box("hips", (sx * .11, .385, .098), (.07, .06, .01), m["frame"])
        b.box("head", (sx * .075, .805, .09), (.05, .02, .02), m["frame"])
    b.row("hips", (-.1, .385, .098), (.1, .385, .098), 3, (.012, .012, .008), m["brass"])
    b.box("hips", (0.0, .385, .098), (.05, .05, .01), m["amber"])
    b.box("chest", (0.0, .655, .075), (.2, .012, .06), m["hazard"])
    return {"heel_z": -0.095, "toe_z": 0.155, "foot_lift": 0.0}


# ------------------------------------------------------------------ the huge robot: a blast-furnace colossus with a chest bay
def build_huge(b):
    m = {
        "iron": tiled(b, "iron_plate", tile("steel_plate_riveted_grey"), (0.95, 0.97, 1.0), 6.0),
        "iron2": tiled(b, "iron_plate_light", tile("floor_rust_plate_quad"), (0.95, 0.95, 1.0), 6.0),
        "rust": tiled(b, "rust_streaked", tile("rust_streaked_plate_tall"), (1.0, 0.92, 0.88), 6.0),
        "vent": tiled(b, "vent_louvers", tile("rust_vent_louvers_wide"), (0.8, 0.8, 0.86), 5.0),
        "hazard": tiled(b, "hazard", hazard_texture(), (0.9, 0.86, 0.78), 12.0),
        "frame": flat(b, "frame_dark", "#363648"),
        "brass": flat(b, "brass", "#B98B38", 0.5),
        "amber": flat(b, "lamp_amber", "#FFB347", 0.3),
        "glass": flat(b, "glass_dark", "#1B2230", 0.2),
    }
    for sx, s in ((1, "l"), (-1, "r")):
        X = lambda v: sx * v
        # stomper feet, ankles, shins with exhaust fins, big knee discs, thighs with pistons
        b.box("foot_" + s, (X(.11), .03, .04), (.15, .06, .27), m["iron"])
        b.box("foot_" + s, (X(.11), .048, .185), (.16, .096, .05), m["rust"])
        b.box("foot_" + s, (X(.11), .052, -.105), (.13, .104, .04), m["frame"])
        b.box("foot_" + s, (X(.11), .063, .07), (.1, .005, .1), m["hazard"])
        b.box("foot_" + s, (X(.11), .09, 0.0), (.115, .075, .125), m["frame"])
        b.row("foot_" + s, (X(.04), .066, .17), (X(.18), .066, .17), 5, (.012, .01, .012), m["brass"])
        b.frustum("shin_" + s, (X(.10), .20, .005), (X(.105), .14, 0.0), (.078, .082), (.07, .074), m["iron"])
        b.frustum("shin_" + s, (X(.105), .14, 0.0), (X(.108), .10, 0.0), (.07, .074), (.062, .068), m["rust"])
        b.box("shin_" + s, (X(.105), .135, .005), (.15, .022, .155), m["hazard"])
        for k in range(4):
            b.box("shin_" + s, (X(.105), .105 + k * .028, -.08), (.11, .012, .04), m["frame"])
        b.box("shin_" + s, (X(.105), .17, .078), (.12, .09, .03), m["iron2"])
        b.prism("thigh_" + s, (X(.04), .191, .02), (X(.16), .191, .02), .052, .052, m["frame"], n=10)
        b.prism("thigh_" + s, (X(.16), .191, .02), (X(.168), .191, .02), .036, .036, m["hazard"], n=10)
        b.box("thigh_" + s, (X(.10), .205, .082), (.14, .1, .05), m["iron"])
        b.box("thigh_" + s, (X(.10), .252, .082), (.142, .012, .052), m["hazard"])
        b.frustum("thigh_" + s, (X(.085), .375, 0.0), (X(.10), .225, .005), (.088, .088), (.076, .076), m["iron"])
        b.prism("thigh_" + s, (X(.155), .34, .05), (X(.145), .23, .064), .014, .014, m["brass"], n=6)
        b.prism("thigh_" + s, (X(.05), .34, .05), (X(.058), .23, .064), .014, .014, m["brass"], n=6)
        b.box("hips", (X(.165), .35, 0.0), (.06, .12, .19), m["frame"])
        # shoulders, arms, hands
        b.box("shoulder_" + s, (X(.08), .632, 0.0), (.1, .08, .12), m["frame"])
        b.box("upper_arm_" + s, (X(.185), .632, 0.0), (.12, .085, .15), m["iron"])
        b.box("upper_arm_" + s, (X(.185), .677, 0.0), (.125, .012, .155), m["rust"])
        b.box("upper_arm_" + s, (X(.246), .632, 0.0), (.004, .045, .15), m["hazard"])
        b.row("upper_arm_" + s, (X(.145), .66, .078), (X(.225), .66, .078), 4, (.012, .012, .008), m["brass"])
        b.frustum("upper_arm_" + s, (X(.152), .6, 0.0), (X(.245), .525, 0.0), (.06, .06), (.055, .055), m["iron"])
        b.prism("upper_arm_" + s, (X(.2), .585, .05), (X(.285), .505, .047), .012, .012, m["brass"], n=6)
        b.prism("forearm_" + s, (X(.245), .521, -.058), (X(.245), .521, .058), .052, .052, m["frame"], n=10)
        b.frustum("forearm_" + s, (X(.245), .521, 0.0), (X(.3), .431, 0.0), (.062, .07), (.072, .08), m["iron"])
        b.box("forearm_" + s, (X(.2955), .446, 0.0), (.15, .018, .165), m["hazard"])
        b.box("hand_" + s, (X(.305), .402, 0.0), (.13, .07, .11), m["frame"])
        for k in range(4):
            b.box("hand_" + s, (X(.305), .345, -.04 + k * .0267), (.026, .07, .024), m["iron"])
        b.box("hand_" + s, (X(.252), .395, .04), (.04, .03, .05), m["iron"])
        # radiator plates where Red's ears are
        b.frustum("ear_" + s, (X(.115), .79, -.065), (X(.153), .676, -.115), (.032, .006), (.032, .006), m["frame"], hint=(1.0, 0.0, 0.0))
        b.box("ear_%s_2" % s, (X(.153), .668, -.118), (.07, .03, .05), m["brass"])
        # back smokestacks with a hazard ring and a brass rim
        b.prism("back", (X(.085), .62, -.12), (X(.085), .80, -.12), .03, .025, m["frame"], n=10)
        b.prism("back", (X(.085), .745, -.12), (X(.085), .775, -.12), .032, .028, m["hazard"], n=10)
        b.prism("back", (X(.085), .80, -.12), (X(.085), .81, -.12), .033, .033, m["brass"], n=10)
        b.box("back", (X(.085), .625, -.07), (.04, .03, .05), m["frame"])
        # chest side vents
        b.box("chest", (X(.1465), .57, -.02), (.004, .1, .12), m["vent"])
    # pelvis, waist and the counterweight
    b.box("hips", (0.0, .39, 0.0), (.3, .1, .22), m["iron"])
    b.box("hips", (0.0, .432, 0.0), (.305, .02, .225), m["hazard"])
    b.box("hips", (0.0, .335, 0.0), (.12, .05, .14), m["frame"])
    b.box("spine", (0.0, .462, 0.0), (.24, .06, .18), m["frame"])
    b.prism("spine", (-.08, .44, .04), (-.08, .49, .045), .012, .012, m["brass"], n=6)
    b.prism("spine", (.08, .44, .04), (.08, .49, .045), .012, .012, m["brass"], n=6)
    b.box("tail", (0.0, .415, -.145), (.16, .1, .1), m["rust"])
    b.box("tail", (0.0, .468, -.145), (.164, .014, .104), m["hazard"])
    # chest: rear mass, bay floor lip, ceiling slab, cheeks (together they frame the bay); yoke; back cowl
    b.box("chest", (0.0, .5725, -.0335), (.29, .175, .153), m["iron"])
    b.box("chest", (0.0, .495, .0765), (.29, .02, .067), m["iron"])
    b.box("chest", (0.0, .63, .0765), (.29, .06, .067), m["iron"])
    b.box("chest", (-.1015, .55, .0765), (.088, .1, .067), m["iron"])
    b.box("chest", (.1015, .55, .0765), (.088, .1, .067), m["iron"])
    b.box("chest", (0.0, .671, -.02), (.26, .02, .15), m["iron2"])
    b.box("chest", (0.0, .575, -.1265), (.18, .15, .03), m["vent"])
    b.box("chest", (0.0, .51, .1115), (.29, .02, .003), m["hazard"])
    b.row("chest", (-.13, .65, .1115), (.13, .65, .1115), 9, (.012, .012, .006), m["brass"])
    b.row("chest", (-.13, .52, .1115), (.13, .52, .1115), 9, (.012, .012, .006), m["brass"])
    for x in (-.04, 0.0, .04):
        b.box("chest", (x, .607, .1115), (.02, .01, .004), m["amber"])         # bay status lamps over the doors
    # the bay inside: hazard floor, louvred back wall, docking clamps with lamps, ceiling lamp
    b.box("chest", (0.0, .5055, .0765), (.114, .002, .067), m["hazard"])
    b.box("chest", (0.0, .55, .0445), (.108, .095, .003), m["vent"])
    for sx in (1, -1):
        b.box("chest", (sx * .0545, .535, .08), (.006, .03, .05), m["brass"])
        b.box("chest", (sx * .0545, .575, .08), (.006, .03, .05), m["brass"])
        b.box("chest", (sx * .0513, .555, .098), (.002, .012, .012), m["amber"])
    b.box("chest", (0.0, .5985, .077), (.07, .003, .04), m["amber"])
    # the two bay doors (each hinged on its outer edge, so they swing open like a clamshell)
    for sx, s in ((1, "l"), (-1, "r")):
        bone = "dock_door_" + s
        b.box(bone, (sx * .02875, .55, .1105), (.0565, .099, .008), m["iron"])
        b.box(bone, (sx * .0065, .55, .1148), (.013, .099, .002), m["hazard"])
        b.box(bone, (sx * .03, .585, .1148), (.04, .012, .002), m["frame"])
        b.box(bone, (sx * .03, .515, .1148), (.04, .012, .002), m["frame"])
        b.prism(bone, (sx * .03, .55, .1145), (sx * .03, .55, .118), .008, .008, m["brass"], n=8)
    # head: a furnace hood with a vertical vent grille (three amber slots, no eyes), brow, mast and beacon
    b.box("neck", (0.0, .685, 0.0), (.12, .05, .1), m["frame"])
    b.box("head", (0.0, .752, .005), (.2, .12, .17), m["iron"])
    b.box("head", (0.0, .82, .0), (.22, .02, .19), m["rust"])
    b.box("head", (0.0, .836, -.04), (.08, .012, .09), m["frame"])
    b.box("head", (0.0, .75, .0905), (.15, .1, .004), m["frame"])
    for x in (-.04, 0.0, .04):
        b.box("head", (x, .75, .0935), (.016, .08, .004), m["amber"])
    b.box("head", (0.0, .695, .075), (.12, .03, .04), m["vent"])
    b.box("head", (0.0, .812, .101), (.2, .014, .004), m["hazard"])
    b.prism("head_gear", (0.0, .82, 0.0), (0.0, .86, 0.0), .02, .018, m["brass"], n=8)
    b.prism("head_gear", (0.0, .86, 0.0), (0.0, .935, 0.0), .008, .006, m["frame"], n=6)
    b.box("head_gear", (0.0, .943, 0.0), (.018, .016, .018), m["amber"])
    # rivet rows and plate seams: the riveted-plate look at this scale comes from big studs, not from the texture
    for sx, s in ((1, "l"), (-1, "r")):
        b.row("hips", (sx * .02, .42, .113), (sx * .14, .42, .113), 5, (.012, .012, .008), m["brass"])
        b.row("thigh_" + s, (sx * .06, .3, .092), (sx * .13, .3, .092), 4, (.014, .014, .01), m["brass"])
        b.row("shin_" + s, (sx * .07, .12, .08), (sx * .14, .12, .08), 4, (.014, .014, .01), m["brass"])
        b.row("forearm_" + s, (sx * .26, .5, .074), (sx * .29, .45, .08), 3, (.012, .012, .01), m["brass"])
        b.box("chest", (sx * .12, .59, .1115), (.03, .08, .003), m["amber"])
        b.box("chest", (sx * .0725, .62, .1115), (.004, .04, .003), m["frame"])
        for k in range(3):
            b.box("back", (sx * .085, .66 + k * .03, -.168), (.05, .008, .012), m["frame"])
        b.box("shin_" + s, (sx * .105, .175, -.07), (.1, .05, .04), m["iron2"])
        b.box("foot_" + s, (sx * .16, .03, .1), (.012, .05, .12), m["hazard"])
        b.box("foot_" + s, (sx * .06, .03, .1), (.012, .05, .12), m["hazard"])
    for k in range(6):
        b.box("chest", (0.0, .53 + k * .02, -.1415), (.12, .008, .012), m["frame"])
    b.row("chest", (-.12, .665, .1), (.12, .665, .1), 7, (.014, .014, .01), m["brass"])
    b.row("head", (-.08, .83, .09), (.08, .83, .09), 5, (.012, .012, .008), m["brass"])
    b.box("chest", (0.0, .575, .1115), (.004, .099, .003), m["frame"])
    return {"heel_z": -0.095, "toe_z": 0.175, "foot_lift": 0.0}


# ------------------------------------------------------------------ props (metres, static)
def prop_materials(b):
    return {
        "plates": tiled(b, "plates_rust", tile("rust_riveted_plates_tall", "tiles_busted_seamless"), (1.0, 0.95, 0.9), 2.0),
        "steel": tiled(b, "plates_steel", tile("steel_plate_riveted_grey"), (0.8, 0.82, 0.88), 2.0),
        "concrete": tiled(b, "concrete", tile("floor_concrete_plain_trim_top"), (0.8, 0.8, 0.82), 4.0),
        "vent": tiled(b, "vent_louvers", tile("rust_vent_louvers_wide"), (0.8, 0.8, 0.86), 2.0),
        "hazard": tiled(b, "hazard", hazard_texture(), (0.9, 0.86, 0.78), 1.0),
        "frame": flat(b, "frame_dark", "#2B2B3D"),
        "glass": flat(b, "window_dark", "#14182A", 0.2),
        "lit": flat(b, "window_lit", "#FFB347", 0.3),
        "sodium": flat(b, "lamp_sodium", "#FF9A3C", 0.3),
        "red": flat(b, "tail_light", "#E8456A", 0.3),
        "paint": flat(b, "car_paint", "#5A5A48", 0.6),
        "tyre": flat(b, "tyre", "#1A1A22", 1.0),
    }


def crate(name, size, tile_m):
    b = Builder()
    m = prop_materials(b)
    b.materials[m["plates"]]["tile_m"] = tile_m
    b.materials[m["hazard"]]["tile_m"] = tile_m * 0.5
    h = size / 2.0
    p = size * 0.06
    b.box(None, (0, h, 0), (size, size, size), m["plates"])
    for x in (-1, 1):
        for z in (-1, 1):
            b.box(None, (x * (h - p / 2), h, z * (h - p / 2)), (p, size + p * 0.4, p), m["frame"])
    for y in (p / 2, size - p / 2):
        b.box(None, (0, y, 0), (size + p * 0.4, p, size + p * 0.4), m["frame"])
    b.box(None, (0, h, h + p * 0.2), (size * 0.7, size * 0.1, p * 0.4), m["hazard"])
    return b


def container(name):
    b = Builder()
    m = prop_materials(b)
    b.materials[m["plates"]]["tile_m"] = 3.0
    b.box(None, (0, 1.3, 0), (2.5, 2.6, 6.0), m["plates"])
    for z in np.linspace(-2.8, 2.8, 8):
        b.box(None, (0, 1.3, z), (2.58, 2.62, 0.08), m["frame"])
    b.box(None, (0, 0.1, 0), (2.4, 0.2, 5.9), m["frame"])
    b.box(None, (0, 1.3, 3.02), (2.3, 2.4, 0.06), m["vent"])
    b.box(None, (0, 1.3, -3.02), (2.3, 2.4, 0.06), m["steel"])
    b.box(None, (0, 2.45, 3.06), (2.2, 0.2, 0.04), m["hazard"])
    return b


def car(name):
    b = Builder()
    m = prop_materials(b)
    b.box(None, (0, 0.6, 0), (1.8, 0.62, 4.4), m["paint"])
    b.box(None, (0, 1.15, -0.2), (1.55, 0.5, 2.3), m["paint"])
    b.box(None, (0, 1.17, 0.95), (1.5, 0.4, 0.04), m["glass"], rot=rot_x(-25))
    b.box(None, (0, 1.17, -1.35), (1.5, 0.4, 0.04), m["glass"], rot=rot_x(25))
    for sx in (-1, 1):
        b.box(None, (sx * 0.78, 1.17, -0.2), (0.04, 0.38, 1.9), m["glass"])
        b.box(None, (sx * 0.6, 0.62, 2.2), (0.4, 0.14, 0.04), m["lit"])
        b.box(None, (sx * 0.6, 0.62, -2.2), (0.4, 0.14, 0.04), m["red"])
        for z in (-1.4, 1.4):
            b.prism(None, (sx * 0.78, 0.34, z), (sx * 1.0, 0.34, z), 0.34, 0.34, m["tyre"], n=10)
    b.box(None, (0, 0.34, 0), (1.9, 0.12, 4.5), m["frame"])
    b.box(None, (0, 0.95, 2.18), (1.6, 0.04, 0.08), m["frame"])
    return b


def lamp_post(name):
    b = Builder()
    m = prop_materials(b)
    b.box(None, (0, 0.3, 0), (0.6, 0.6, 0.6), m["steel"])
    b.box(None, (0, 0.08, 0), (0.66, 0.16, 0.66), m["hazard"])
    b.prism(None, (0, 0.6, 0), (0, 6.6, 0), 0.14, 0.09, m["frame"], n=8)
    b.box(None, (0.7, 6.7, 0), (1.6, 0.12, 0.16), m["frame"])
    b.box(None, (1.5, 6.58, 0), (0.7, 0.16, 0.36), m["steel"])
    b.box(None, (1.5, 6.49, 0), (0.56, 0.04, 0.26), m["sodium"])
    b.box(None, (0, 4.0, 0.12), (0.3, 0.4, 0.06), m["vent"])
    return b


def building(name, w, d, h, seed):
    b = Builder()
    m = prop_materials(b)
    b.materials[m["plates"]]["tile_m"] = 5.0
    b.materials[m["steel"]]["tile_m"] = 5.0
    b.materials[m["hazard"]]["tile_m"] = 2.0
    rng = np.random.default_rng(seed)
    wall = m["plates"] if seed % 2 == 0 else m["steel"]
    b.box(None, (0, h / 2, 0), (w, h, d), wall)
    b.box(None, (0, 1.6, 0), (w + 0.5, 3.2, d + 0.5), m["concrete"])
    b.box(None, (0, 3.25, 0), (w + 0.6, 0.12, d + 0.6), m["hazard"])
    b.box(None, (0, h + 0.3, 0), (w + 0.6, 0.6, d + 0.6), m["frame"])
    # roof: a tank, a vent block and a mast
    b.prism(None, (-w * 0.25, h + 0.6, -d * 0.2), (-w * 0.25, h + 2.4, -d * 0.2), 1.6, 1.6, m["steel"], n=10)
    b.box(None, (w * 0.22, h + 1.4, d * 0.15), (3.4, 1.6, 2.4), m["vent"])
    b.prism(None, (w * 0.3, h + 0.6, -d * 0.3), (w * 0.3, h + 3.6, -d * 0.3), 0.12, 0.07, m["frame"], n=6)
    # windows on all four sides (quads), a few lit
    floors = max(2, int((h - 4.0) / 3.4))
    for face in range(4):
        span = w if face in (0, 1) else d
        count = max(2, int(span / 3.4))
        for fl in range(floors):
            y = 5.2 + fl * 3.4
            for c in range(count):
                t = -span / 2 + (c + 0.5) * span / count
                lit = rng.random() < 0.2
                mat = m["lit"] if lit else m["glass"]
                hw, hh = 0.7, 0.9
                if face == 0:
                    z = d / 2 + 0.02
                    b.quad(None, [(t - hw, y - hh, z), (t + hw, y - hh, z), (t + hw, y + hh, z), (t - hw, y + hh, z)], mat)
                elif face == 1:
                    z = -d / 2 - 0.02
                    b.quad(None, [(t + hw, y - hh, z), (t - hw, y - hh, z), (t - hw, y + hh, z), (t + hw, y + hh, z)], mat)
                elif face == 2:
                    x = w / 2 + 0.02
                    b.quad(None, [(x, y - hh, t + hw), (x, y - hh, t - hw), (x, y + hh, t - hw), (x, y + hh, t + hw)], mat)
                else:
                    x = -w / 2 - 0.02
                    b.quad(None, [(x, y - hh, t - hw), (x, y - hh, t + hw), (x, y + hh, t + hw), (x, y + hh, t - hw)], mat)
    b.box(None, (0, 1.5, d / 2 + 0.35), (2.6, 3.0, 0.1), m["frame"])
    b.box(None, (0, 3.1, d / 2 + 0.35), (3.0, 0.2, 0.14), m["hazard"])
    return b


PROP_LIST = [
    ("prop_crate_small", lambda: crate("prop_crate_small", 0.8, 0.8), "0.8 m crate (Red-sized: she is about as tall as one and a bit)"),
    ("prop_crate_large", lambda: crate("prop_crate_large", 2.0, 1.6), "2 m crate"),
    ("prop_cargo_container", lambda: container("prop_cargo_container"), "6 m shipping container"),
    ("prop_car_block", lambda: car("prop_car_block"), "car-sized block, 4.4 m long"),
    ("prop_lamp_post", lambda: lamp_post("prop_lamp_post"), "lamp post, 7 m"),
    ("prop_building_10m", lambda: building("prop_building_10m", 12.0, 10.0, 10.0, 2), "building block, 10 m"),
    ("prop_building_20m", lambda: building("prop_building_20m", 16.0, 14.0, 20.0, 3), "building block, 20 m"),
    ("prop_building_30m", lambda: building("prop_building_30m", 20.0, 16.0, 30.0, 4), "building block, 30 m"),
]


# ------------------------------------------------------------------ retarget settings
def write_retarget(name, unit, feet, height, label):
    with open(RED_CFG) as f:
        cfg = json.load(f)
    k = unit * 0.41                                    # Red's ground/hips ratio, scaled by the robot's size
    cfg["_about"] = ("Retarget of the free Quaternius Universal Animation Library (CC0) onto the %s robot blockout (task CS-21). Read by "
                     "scripts/tools/retarget_ual.py. Same bone names and clip names as red_ross_v1_rigged_ual.glb, so the same controller "
                     "drives it. Written by scripts/tools/make_robots.py from retarget_red.json (the size-dependent numbers are Red's times "
                     "%.2f); edit and rerun retarget_ual.py %s." % (label, unit, name))
    cfg["target"] = "art/placeholder/robots/%s.glb" % name
    cfg["output"] = "art/placeholder/robots/%s_ual.glb" % name
    cfg["clip_keys"] = "data/animation/%s_clip_keys.json" % name
    cfg["hips"]["scale"] = round(k, 4)
    cfg["ground"]["scale"] = round(k, 4)
    points = []
    for p in cfg["ground"]["target_points"]:
        q = dict(p)
        q["offset"] = [round(v * unit, 4) for v in p["offset"]]
        if "lift" in q:
            q["lift"] = round(q["lift"] * unit, 4)
        if q["bone"].startswith("foot"):               # the robot's soles run from the heel to the toe of ITS foot
            q["offset"][2] = round((feet["heel_z"] if p["offset"][2] < 0 else feet["toe_z"]) * unit, 4)
        points.append(q)
    cfg["ground"]["target_points"] = points
    cfg["ground"]["_about"] = cfg["ground"]["_about"] + " Robot copy: offsets and lifts are Red's times the robot's size; the heel and toe are this robot's own foot."
    px = cfg["proxies"]
    px["head"]["center_offset"] = [round(v * unit, 4) for v in px["head"]["center_offset"]]
    px["head"]["radius"] = round(px["head"]["radius"] * unit * 1.1, 4)
    px["torso"]["half_width"] = round(px["torso"]["half_width"] * unit * 1.2, 4)
    px["torso"]["half_depth"] = round(px["torso"]["half_depth"] * unit * 1.2, 4)
    px["arm_radius"] = round(px["arm_radius"] * unit * 1.3, 4)
    cfg["keep_standins"] = []
    # Red's four hand-posed stand-ins do not exist on the robots; the nearest baked clips stand in (ground "free": the game moves the body)
    extra = [
        {"name": "air_1", "source": "UAL2:Sword_Regular_A", "ground": "free", "contact_src_s": 0.25, "note": "stand-in: Red's air_1 is hand-posed; the robot uses the light_1 swing"},
        {"name": "air_2", "source": "UAL2:Sword_Regular_B", "ground": "free", "contact_src_s": 0.25, "note": "stand-in: the light_2 swing"},
        {"name": "air_3", "source": "UAL2:Sword_Regular_C", "from_s": 0.45, "to_s": 1.5, "ground": "free", "contact_src_s": 0.65, "note": "stand-in: the light_3 swing"},
        {"name": "parry_success", "source": "UAL2:Sword_Block", "from_s": 0.2, "to_s": 1.0, "note": "stand-in: the block, held"},
    ]
    cfg["clips"] = cfg["clips"] + extra
    cfg["robot"] = {"height_m": height, "unit": round(unit, 4), "_about": "unit = the robot's size in Red's metres (she is 0.951 m tall)"}
    path = os.path.join(GAME_DIR, "data", "animation", "retarget_%s.json" % name)
    with open(path, "w") as f:
        json.dump(cfg, f, indent=1)
        f.write("\n")
    print("wrote", os.path.relpath(path, GAME_DIR))


# ------------------------------------------------------------------ main
def build_robot(name, unit, extras, draw, height):
    rig = Rig(unit, extras)
    b = Builder(unit, rig.joint_index)
    feet = draw(b)
    path = os.path.join(OUT, name + ".glb")
    write_glb(path, b, name, rig=rig.rig, note="Placeholder blockout by the Technical Artist (task CS-21). Red's bone names, scaled x%.2f." % unit)
    # measure
    top = max(p[1] for pr in b.prims.values() for p in pr["pos"])
    print("%-12s %5d tris  top %.2f m (wanted %.1f)  %d KB" % (name, b.tri_count, top, height, os.path.getsize(path) // 1024))
    return feet


def main():
    os.makedirs(PROPS, exist_ok=True)
    feet = build_robot("robot_small", UNIT_SMALL, SMALL_EXTRAS, build_small, SMALL_HEIGHT)
    write_retarget("robot_small", UNIT_SMALL, feet, SMALL_HEIGHT, "small")
    feet = build_robot("robot_huge", UNIT_HUGE, HUGE_EXTRAS, build_huge, HUGE_HEIGHT)
    write_retarget("robot_huge", UNIT_HUGE, feet, HUGE_HEIGHT, "huge")
    for name, make, note in PROP_LIST:
        b = make()
        write_glb(os.path.join(PROPS, name + ".glb"), b, name, note=note)
        top = max(p[1] for pr in b.prims.values() for p in pr["pos"])
        print("%-22s %5d tris  top %.2f m  (%s)" % (name, b.tri_count, top, note))


if __name__ == "__main__":
    main()
