"""The Cyberwolf Sentinel's cheap clips (the sandbox "Grunt"): 15 fps, stepped, two to four key poses each, built with
the same pose helpers as Red's (red_clips.py). The point is READABLE WIND-UPS: the telegraph silhouette (arm cocked
high, body coiled back, head tucked) is very different from idle, so a player can parry it on sight.

Everything is in the wolf's own scaled model space (1.25x Red): metres, +X to its left, -Y forward, +Z up.
"""
from rigkit import *  # noqa: F401,F403
from red_clips import leg, merge, pose  # noqa: E402

S = 1.25


def W(x, y, z):
    return (x * S, y * S, z * S)


POLE_R = W(-0.5, -0.05, 0.40)
POLE_L = W(0.5, -0.05, 0.40)


def body(lean=0.0, twist=0.0, head_x=0.0, head_z=0.0, chest_x=0.0, chest_z=0.0, sh=0.0):
    return {"spine": (lean, 0, twist), "chest": (chest_x, 0, chest_z), "head": (head_x, 0, head_z),
            "shoulder_l": (sh, 0, 0), "shoulder_r": (sh, 0, 0)}


def tail(swing=0.0, lift=0.0):
    return {"tail": (lift, 0, swing), "tail_2": (lift * 0.7, 0, swing * 1.2), "tail_3": (lift * 0.5, 0, swing * 1.4)}


def ear(a=0.0):
    return {"ear_l": (a, 0, 0), "ear_r": (a, 0, 0)}


def arms(r=None, l=None, rpole=POLE_R, lpole=POLE_L):
    d = {}
    if r:
        d["ik_r"] = (W(*r), rpole)
    if l:
        d["ik_l"] = (W(*l), lpole)
    return d


# the slouching idle: knees soft, fists low, head forward
BASE = merge(body(lean=6, head_x=-6), leg("l", -8, 16), leg("r", 8, 12), tail(0, 0), ear(0),
             {"plant": True}, arms(r=(-0.28, -0.06, 0.40), l=(0.28, -0.06, 0.40)))

CLIPS = {}


def clip(name, length, keys, loop=False):
    CLIPS[name] = dict(length=length, keys=keys, loop=loop)


clip("idle", 24, [
    (0, pose(BASE, squash=0.0, **tail(8, 0))),
    (8, merge(BASE, body(lean=8, head_x=-9, sh=-4), tail(-10, 4), ear(-6), {"squash": -0.016})),
    (16, merge(BASE, body(lean=5, head_x=-3, sh=2), tail(6, -2), ear(3), {"squash": 0.012})),
], loop=True)


def gait(thigh, knee, arm, lean, s):
    p = {}
    p.update(leg("l", -thigh * s, max(0.0, knee * (0.2 if s > 0 else 1.0))))
    p.update(leg("r", thigh * s, max(0.0, knee * (1.0 if s > 0 else 0.2))))
    p.update(body(lean=lean, twist=5 * s, head_x=-lean * 0.7))
    p.update(tail(14 * s, 6))
    p.update(ear(-4 * s))
    p.update({"plant": True})
    p.update(arms(r=(-0.28, -0.06 - arm * s, 0.40), l=(0.28, -0.06 + arm * s, 0.40)))
    return p


clip("walk", 14, [(0, gait(24, 30, 0.07, 8, 1)), (3, pose(gait(8, 8, 0.0, 8, 1), squash=-0.012)),
                  (7, gait(24, 30, 0.07, 8, -1)), (10, pose(gait(8, 8, 0.0, 8, -1), squash=-0.012))], loop=True)


def run_key(s, passing):
    p = {}
    if not passing:
        p.update(leg("l", -48 * s, 10 if s > 0 else 72))
        p.update(leg("r", 48 * s, 72 if s > 0 else 10))
        p["squash"] = -0.04
    else:
        p.update(leg("l", -6 * s, 18 if s > 0 else 95))
        p.update(leg("r", 6 * s, 95 if s > 0 else 18))
        p["squash"] = 0.03
    p.update(body(lean=20, twist=8 * s, head_x=-14))
    p.update(tail(-10 * s, 14))
    p.update(ear(-10))
    p.update({"plant": True})
    p.update(arms(r=(-0.28, -0.04 + 0.12 * s, 0.46), l=(0.28, -0.04 - 0.12 * s, 0.46)))
    return p


clip("run", 8, [(0, run_key(1, False)), (2, run_key(1, True)), (4, run_key(-1, False)), (6, run_key(-1, True))], loop=True)

# ---- the attack: wind-up (the telegraph) then the swing
WIND_0 = merge(body(lean=-4, head_x=-2, twist=-6), leg("l", -14, 30), leg("r", 14, 30), tail(0, 4), ear(8),
               {"squash": -0.08, "plant": True}, arms(r=(-0.34, 0.02, 0.60), l=(0.26, -0.10, 0.44)))
WIND_1 = merge(body(lean=-22, head_x=10, twist=-24, chest_z=-10), leg("l", -6, 22), leg("r", 24, 36), tail(-20, 18), ear(18),
               {"squash": 0.10, "plant": True}, arms(r=(-0.26, 0.12, 0.98), l=(0.30, -0.06, 0.42)))
WIND_2 = merge(body(lean=-28, head_x=14, twist=-30, chest_z=-12), leg("l", -4, 20), leg("r", 28, 40), tail(-26, 24), ear(24),
               {"squash": 0.14, "plant": True}, arms(r=(-0.24, 0.16, 1.04), l=(0.32, -0.04, 0.40)))
clip("attack_windup", 8, [(0, WIND_0), (2, WIND_1), (4, WIND_2), (6, pose(WIND_2, squash=0.12, **tail(-30, 26)))])

clip("attack_swing", 8, [
    (0, WIND_2),
    (1, merge(body(lean=26, head_x=-18, twist=14, chest_z=8), leg("l", -40, 58), leg("r", 24, 22), tail(30, -6), ear(-24),
              {"squash": 0.06, "plant": True}, arms(r=(-0.04, -0.30, 0.66), l=(0.30, -0.02, 0.44)))),
    (3, merge(body(lean=34, head_x=-24, twist=34, chest_z=12), leg("l", -46, 70), leg("r", 30, 20), tail(40, -10), ear(-30),
              {"squash": 0.02, "plant": True}, arms(r=(0.20, -0.30, 0.34), l=(0.34, 0.04, 0.46)))),
    (6, merge(BASE, tail(10, 0), {"squash": 0.0})),
])

# ---- reactions
clip("hurt", 6, [
    (0, merge(body(lean=-22, head_x=18, twist=10), leg("l", 14, 20), leg("r", 18, 24), tail(24, 16), ear(30),
              {"squash": -0.08, "plant": True}, arms(r=(-0.34, 0.04, 0.60), l=(0.34, 0.02, 0.58)))),
    (2, merge(body(lean=-12, head_x=10, twist=6), leg("l", 8, 16), leg("r", 12, 20), tail(10, 8), ear(14),
              {"squash": 0.03, "plant": True}, arms(r=(-0.30, 0.0, 0.52), l=(0.30, 0.0, 0.52)))),
    (4, merge(BASE, {"squash": 0.0})),
])

clip("stagger", 12, [
    (0, merge(body(lean=-14, head_x=20, twist=-14), leg("l", 12, 26), leg("r", 20, 30), tail(-14, 10), ear(20),
              {"squash": -0.04, "plant": True}, arms(r=(-0.34, 0.08, 0.50), l=(0.30, 0.04, 0.46)))),
    (4, merge(body(lean=-6, head_x=26, twist=10), leg("l", 6, 22), leg("r", 14, 26), tail(12, 6), ear(26),
              {"squash": 0.0, "plant": True}, arms(r=(-0.30, 0.0, 0.44), l=(0.34, 0.08, 0.50)))),
    (8, merge(body(lean=-10, head_x=22, twist=-6), leg("l", 10, 24), leg("r", 18, 28), tail(-8, 8), ear(22),
              {"squash": -0.02, "plant": True}, arms(r=(-0.32, 0.06, 0.48), l=(0.32, 0.0, 0.44)))),
], loop=True)

TUMBLE = [
    merge(body(lean=-18, head_x=16, twist=8), leg("l", -30, 50), leg("r", 20, 60), tail(30, 20), ear(40),
          {"squash": 0.10, "hips": (-38, 0, 0), "loc:hips": (0, 0.0, 0.1),
           "ik_r": (W(-0.46, 0.1, 0.70), POLE_R), "ik_l": (W(0.46, 0.1, 0.72), POLE_L)}),
    merge(body(lean=-12, head_x=10, twist=-8), leg("l", 20, 66), leg("r", -24, 46), tail(-30, 24), ear(30),
          {"squash": 0.10, "hips": (-52, 0, 8), "loc:hips": (0, 0.0, 0.1),
           "ik_r": (W(-0.44, 0.14, 0.62), POLE_R), "ik_l": (W(0.44, 0.12, 0.74), POLE_L)}),
]
clip("launched", 8, [(0, TUMBLE[0]), (4, TUMBLE[1])], loop=True)

LYING = merge({"hips": (-84, 0, 0), "loc:hips": (0, 0.34, -0.30), "head": (20, 0, 0)}, leg("l", 8, 22), leg("r", 14, 28),
              tail(20, 0), ear(20),
              {"squash": 0.0, "ik_r": (W(-0.40, 0.14, 0.18), POLE_R), "ik_l": (W(0.34, 0.14, 0.12), POLE_L)})
clip("knockdown", 10, [
    (0, merge(body(lean=-28, head_x=22), leg("l", 18, 18), leg("r", 26, 30), tail(30, 20), ear(36),
              {"squash": -0.04, "loc:hips": (0, 0.05, 0.12), "ik_r": (W(-0.34, 0.08, 0.72), POLE_R), "ik_l": (W(0.34, 0.08, 0.72), POLE_L)})),
    (3, merge({"hips": (-48, 0, 0), "loc:hips": (0, 0.2, -0.12), "head": (16, 0, 0)}, leg("l", 24, 40), leg("r", 34, 50), tail(20, 10), ear(30),
              {"squash": 0.0, "ik_r": (W(-0.36, 0.2, 0.58), POLE_R), "ik_l": (W(0.36, 0.2, 0.58), POLE_L)})),
    (5, pose(LYING, squash=-0.04)),
    (7, LYING),
])

clip("getup", 12, [
    (0, LYING),
    (3, merge({"hips": (-40, 0, 0), "loc:hips": (0, 0.16, -0.16), "head": (-8, 0, 0)}, leg("l", -50, 110), leg("r", -30, 100), tail(10, 6), ear(10),
              {"squash": -0.04, "ik_r": (W(-0.30, -0.16, 0.30), POLE_R), "ik_l": (W(0.26, -0.18, 0.26), POLE_L)})),
    (6, merge(body(lean=34, head_x=-14), leg("l", -52, 96), leg("r", 20, 60), tail(0, 6), ear(10),
              {"squash": -0.12, "plant": True}, arms(r=(-0.28, -0.20, 0.40), l=(0.26, -0.20, 0.38)))),
    (9, merge(body(lean=16, head_x=-8), leg("l", -26, 40), leg("r", 12, 30), tail(0, 2), ear(4),
              {"squash": 0.04, "plant": True}, arms(r=(-0.28, -0.1, 0.42), l=(0.28, -0.1, 0.42)))),
    (11, pose(BASE, squash=0.0)),
])
