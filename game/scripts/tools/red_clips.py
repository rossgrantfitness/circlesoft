"""Red's first animation set (Ross, F44: "don't over-invest in animation"; the code falls back to procedural
tweens, see combat_api.md section 5). 15 fps, STEPPED (every key is held until the next), two to four key poses per
clip: anticipation, strike, follow-through, recovery. KH / DMC energy, not realism: big silhouettes, squash on the
root, the sword always leading the eye.

Poses are written in model space (metres and degrees; Red faces -Y, her left is +X, up is +Z):
  * legs and torso are plain FK angles (leg() keeps the boot flat),
  * the sword hand is placed by a two-bone IK: the wrist target and an elbow pole,
  * the blade's direction is aimed with `aim_r` (that is the weapon_socket's +Y, so it is exactly where the sword points),
  * `plant=True` lowers the hips so the lowest boot sits on the floor.
The strike key of each attack sits at frame 2 (about 133 ms) and the follow-through at frame 4 (about 267 ms), which
is what docs/pivot/combat_api.md's example `anim.keys` assumes; see CLIP_NOTES for the exact times.
"""
from rigkit import *  # noqa: F401,F403

# ---------------------------------------------------------------- helpers
SHOULDER_R = (-0.15, 0.0, 0.60)


def leg(side, thigh, shin, out=0.0, foot_extra=0.0):
    sgn = -1.0 if side == "l" else 1.0
    return {"thigh_" + side: (thigh, sgn * out, 0), "shin_" + side: (shin, 0, 0),
            "foot_" + side: (-(thigh + shin) + foot_extra, -sgn * out * 0.0, 0)}


def pose(base=None, **kw):
    d = dict(base or {})
    d.update(kw)
    return d


def torso(lean=0.0, twist=0.0, head_x=0.0, head_z=0.0, chest_x=0.0, chest_z=0.0):
    """lean: spine forward angle; twist: turn about the vertical (positive = toward her left)."""
    return {"spine": (lean, 0, twist), "chest": (chest_x, 0, chest_z), "head": (head_x, 0, head_z)}


def v(x, y, z):
    return (x, y, z)


def ears(a=0.0, b=0.0, side=0.0):
    """Floppy ears: a swings the base, b the tip (positive = tips swing forward), side splays outward."""
    return {"ear_l": (a, side, 0), "ear_r": (a, -side, 0), "ear_l_2": (b, 0, 0), "ear_r_2": (b, 0, 0)}


def merge(*dicts):
    out = {}
    for d in dicts:
        out.update(d)
    return out


# the sword hand's usual home
POLE_R = (-0.45, -0.05, 0.40)                   # elbow bends out and down
POLE_L = (0.45, -0.05, 0.40)

# ---------------------------------------------------------------- the stances
READY = merge(
    torso(lean=7, head_x=-4),
    leg("l", -14, 22, out=3), leg("r", 12, 14, out=3),
    ears(4, 8),
    {"plant": True, "loc:hips": (0, 0, 0),
     "ik_r": (v(-0.185, -0.13, 0.50), POLE_R), "aim_r": (v(0.12, -0.55, 0.83), 0),
     "ik_l": (v(0.17, -0.14, 0.49), POLE_L)})


def ready(**kw):
    return pose(READY, **kw)


def breath(k, **kw):
    return pose(READY, squash=k, **kw)


# ---------------------------------------------------------------- the clips
CLIPS = {}
NOTES = {}


def clip(name, length, keys, loop=False, note=""):
    CLIPS[name] = dict(length=length, keys=keys, loop=loop)
    NOTES[name] = note


# idle: a slow breath with the ears settling; 1.6 s loop
clip("idle", 24, [
    (0, ready(**{"squash": 0.0}, **ears(4, 8))),
    (8, merge(READY, {"squash": -0.016}, torso(lean=9, head_x=-6), ears(2, 2))),
    (16, merge(READY, {"squash": 0.012}, torso(lean=6, head_x=-2), ears(6, 12))),
], loop=True, note="breathing; sword up, left fist guard")

# walk: optional small-stick clip, 0.8 s loop
def gait(thigh, knee, arm, lean, bob, phase):
    s = 1.0 if phase == 0 else -1.0
    p = {}
    p.update(leg("l", -thigh * s, max(0.0, knee * (0.2 if s > 0 else 1.0))))
    p.update(leg("r", thigh * s, max(0.0, knee * (1.0 if s > 0 else 0.2))))
    p.update(torso(lean=lean, twist=4 * s, head_x=-lean * 0.6))
    p.update(ears(6 * s, 14))
    p.update({"plant": True,
              "ik_r": (v(-0.19, -0.13 - 0.03 * s, 0.50), POLE_R), "aim_r": (v(0.1, -0.5, 0.86), 0),
              "ik_l": (v(0.19, -0.10 - arm * s, 0.47), POLE_L)})
    return p


clip("walk", 12, [(0, gait(26, 34, 0.04, 6, 0.0, 0)), (3, pose(gait(10, 10, 0.0, 6, 0.0, 0), squash=-0.015)),
                  (6, gait(26, 34, 0.04, 6, 0.0, 1)), (9, pose(gait(10, 10, 0.0, 6, 0.0, 1), squash=-0.015))],
     loop=True, note="0.8 s loop")

# run: leaning hard, sword trailing, ears streaming; 0.53 s loop (8 frames), four keys = "on twos"
def run_key(s, passing):
    p = {}
    if not passing:
        p.update(leg("l", -52 * s, 10 if s > 0 else 78))
        p.update(leg("r", 52 * s, 78 if s > 0 else 10))
        p["squash"] = -0.05
    else:
        p.update(leg("l", -6 * s, 20 if s > 0 else 100))
        p.update(leg("r", 6 * s, 100 if s > 0 else 20))
        p["squash"] = 0.04
    p.update(torso(lean=18, twist=7 * s, head_x=-14, chest_z=4 * s))
    p.update(ears(-14, -30))
    p.update({"plant": True,
              "ik_r": (v(-0.19, 0.0, 0.53), POLE_R), "aim_r": (v(-0.05, 0.62, 0.78), 0),
              "ik_l": (v(0.20, -0.14 * s if not passing else -0.02, 0.50), POLE_L)})
    return p


clip("run", 8, [(0, run_key(1, False)), (2, run_key(1, True)), (4, run_key(-1, False)), (6, run_key(-1, True))],
     loop=True, note="0.53 s loop; footfalls at frames 0 and 4")

# jump_up: crouch, launch, rising pose (held)
JUMP_RISE = merge(
    torso(lean=-4, head_x=4), leg("l", -55, 70), leg("r", 12, 40),
    ears(-20, -40),
    {"squash": 0.12, "loc:root": (0, 0, 0.02),
     "ik_r": (v(-0.22, -0.10, 0.74), POLE_R), "aim_r": (v(-0.05, -0.1, 1.0), 0),
     "ik_l": (v(0.20, -0.18, 0.62), POLE_L)})
clip("jump_up", 6, [
    (0, merge(torso(lean=16, head_x=-8), leg("l", -42, 78), leg("r", -30, 70), ears(8, 18),
              {"squash": -0.16, "plant": True, "ik_r": (v(-0.19, 0.04, 0.42), POLE_R), "aim_r": (v(0.0, 0.6, 0.78), 0),
               "ik_l": (v(0.2, 0.06, 0.44), POLE_L)})),
    (2, merge(torso(lean=-6, head_x=6), leg("l", -20, 25), leg("r", 8, 10), ears(-25, -45),
              {"squash": 0.18, "loc:hips": (0, 0, 0.0), "ik_r": (v(-0.2, -0.04, 0.70), POLE_R), "aim_r": (v(0.0, 0.2, 1.0), 0),
               "ik_l": (v(0.19, -0.1, 0.66), POLE_L)})),
    (4, JUMP_RISE),
], note="one-shot, holds the last pose")

# fall: tucked, flailing; 0.53 s loop
def fall_key(s):
    return merge(torso(lean=6, head_x=-6, twist=3 * s), leg("l", -30 + 10 * s, 50 + 12 * s), leg("r", 6 - 10 * s, 36 - 12 * s),
                 ears(30, 55 + 10 * s),
                 {"squash": 0.05, "ik_r": (v(-0.24, -0.04, 0.72 + 0.02 * s), POLE_R), "aim_r": (v(-0.1, 0.3, 0.95), 0),
                  "ik_l": (v(0.24, -0.04, 0.70 - 0.02 * s), POLE_L)})


clip("fall", 8, [(0, fall_key(1)), (4, fall_key(-1))], loop=True, note="0.53 s loop")

# land: big squash, small overshoot, rest
clip("land", 5, [
    (0, merge(torso(lean=26, head_x=-10), leg("l", -50, 95), leg("r", -34, 88), ears(10, 22),
              {"squash": -0.24, "plant": True, "ik_r": (v(-0.2, -0.16, 0.38), POLE_R), "aim_r": (v(0.1, -0.6, 0.8), 0),
               "ik_l": (v(0.2, -0.16, 0.38), POLE_L)})),
    (2, pose(READY, squash=-0.10, **torso(lean=14, head_x=-6))),
    (4, pose(READY, squash=0.03)),
], note="one-shot, ends close to idle")

# dash: a low stretched lunge, sword trailing behind (0.4 s, holds)
DASH = merge(torso(lean=36, head_x=-30), leg("l", -62, 64), leg("r", 38, 8),
             ears(-30, -60),
             {"squash": 0.10, "plant": True,
              "ik_r": (v(-0.2, 0.06, 0.52), POLE_R), "aim_r": (v(-0.1, 0.9, 0.35), 0),
              "ik_l": (v(0.19, -0.16, 0.50), POLE_L)})
clip("dash", 6, [
    (0, merge(torso(lean=22, head_x=-12), leg("l", -30, 60), leg("r", 18, 30), ears(10, 20),
              {"squash": -0.12, "plant": True, "ik_r": (v(-0.2, 0.03, 0.5), POLE_R), "aim_r": (v(0.0, 0.7, 0.6), 0),
               "ik_l": (v(0.19, -0.1, 0.48), POLE_L)})),
    (1, DASH),
    (4, pose(DASH, squash=0.05)),
], note="holds the lunge; the game can end it any time")

AIR_DASH = merge(torso(lean=34, head_x=-26), leg("l", -36, 40), leg("r", 30, 50), ears(-34, -60),
                 {"squash": 0.12, "ik_r": (v(-0.2, 0.06, 0.55), POLE_R), "aim_r": (v(-0.05, 0.95, 0.2), 0),
                  "ik_l": (v(0.2, -0.20, 0.55), POLE_L)})
clip("air_dash", 6, [(0, pose(AIR_DASH, squash=-0.06)), (1, AIR_DASH)], note="airborne dash, superman lean")

# ---- ground attacks
def stance(front="l", depth=1.0, twist=0.0, lean=10.0, head_x=-6.0):
    """A lunge-ish stance: `front` leg forward."""
    p = {}
    if front == "l":
        p.update(leg("l", -34 * depth, 52 * depth, out=4))
        p.update(leg("r", 26 * depth, 24 * depth, out=4))
    else:
        p.update(leg("r", -34 * depth, 52 * depth, out=4))
        p.update(leg("l", 26 * depth, 24 * depth, out=4))
    p.update(torso(lean=lean, twist=twist, head_x=head_x, chest_z=twist * 0.5))
    p["plant"] = True
    return p


def slash(wrist, blade, pole=POLE_R, left=None):
    d = {"ik_r": (wrist, pole), "aim_r": (blade, 0)}
    d["ik_l"] = left or (v(0.16, -0.12, 0.50), POLE_L)
    return d


# light_1: right-to-left horizontal slash, 8 frames
clip("light_1", 8, [
    (0, merge(stance("r", 0.8, twist=-34, lean=8), ears(10, 24), {"squash": -0.04},
              slash(v(-0.25, 0.02, 0.60), v(-0.55, 0.55, 0.62), left=(v(0.10, -0.06, 0.52), POLE_L)))),
    (2, merge(stance("l", 1.1, twist=30, lean=14, head_x=-10), ears(-12, -30), {"squash": 0.08},
              slash(v(0.02, -0.25, 0.50), v(0.95, -0.35, 0.05), left=(v(0.18, 0.0, 0.50), POLE_L)))),
    (4, merge(stance("l", 1.1, twist=46, lean=12, head_x=-8), ears(-20, -40), {"squash": 0.04},
              slash(v(0.18, -0.16, 0.50), v(1.0, 0.25, 0.1), left=(v(0.14, 0.04, 0.52), POLE_L)))),
    (7, merge(READY, {"squash": 0.0})),
], note="wind-up f0, strike f2, follow f4, recover f7")

# light_2: left-to-right back-slash, 8 frames
clip("light_2", 8, [
    (0, merge(stance("l", 0.9, twist=44, lean=8), ears(-10, -20), {"squash": -0.04},
              slash(v(0.14, -0.10, 0.52), v(1.0, 0.20, 0.25), left=(v(0.12, 0.02, 0.52), POLE_L)))),
    (2, merge(stance("r", 1.1, twist=-36, lean=14, head_x=-10), ears(14, 30), {"squash": 0.08},
              slash(v(-0.05, -0.27, 0.50), v(-0.95, -0.35, 0.10), left=(v(0.14, -0.04, 0.50), POLE_L)))),
    (4, merge(stance("r", 1.1, twist=-52, lean=12, head_x=-6), ears(20, 40), {"squash": 0.04},
              slash(v(-0.24, -0.12, 0.54), v(-1.0, 0.3, 0.2), left=(v(0.10, -0.02, 0.50), POLE_L)))),
    (7, merge(READY, {"squash": 0.0})),
], note="wind-up f0, strike f2, follow f4, recover f7")

# light_3: a lunging thrust finisher, 9 frames
clip("light_3", 9, [
    (0, merge(stance("r", 0.9, twist=-26, lean=2), ears(10, 22), {"squash": -0.10},
              slash(v(-0.22, 0.0, 0.56), v(0.1, 0.1, 1.0), left=(v(0.10, -0.02, 0.50), POLE_L)))),
    (2, merge(stance("l", 1.5, twist=-8, lean=28, head_x=-24), ears(-24, -50), {"squash": 0.12},
              slash(v(-0.08, -0.34, 0.50), v(0.05, -1.0, 0.12), left=(v(0.22, 0.02, 0.50), POLE_L)))),
    (4, merge(stance("l", 1.5, twist=-4, lean=30, head_x=-26), ears(-30, -50), {"squash": 0.08},
              slash(v(-0.08, -0.36, 0.50), v(0.05, -1.0, 0.18), left=(v(0.22, 0.02, 0.50), POLE_L)))),
    (8, merge(READY, {"squash": 0.0})),
], note="wind-up f0, thrust f2 (held to f4), recover f8")

# heavy: crouch, big overhead, slam down, 12 frames
clip("heavy", 12, [
    (0, merge(stance("l", 1.0, twist=-10, lean=22), ears(14, 30), {"squash": -0.18},
              slash(v(-0.22, 0.10, 0.50), v(-0.2, 0.7, 0.55), left=(v(0.10, 0.0, 0.46), POLE_L)))),
    (3, merge(stance("l", 0.5, twist=-8, lean=-8, head_x=8), ears(-18, -40), {"squash": 0.16},
              slash(v(-0.17, 0.0, 0.90), v(-0.1, 0.55, 0.85), left=(v(0.1, 0.0, 0.84), POLE_L)))),
    (5, merge(stance("l", 1.6, twist=0, lean=34, head_x=-24), ears(26, 52), {"squash": 0.0},
              slash(v(-0.05, -0.34, 0.34), v(0.0, -0.75, -0.65), left=(v(0.14, -0.28, 0.34), POLE_L)))),
    (8, merge(stance("l", 1.6, twist=0, lean=36, head_x=-26), ears(22, 44), {"squash": -0.04},
              slash(v(-0.05, -0.34, 0.30), v(0.0, -0.80, -0.55), left=(v(0.14, -0.28, 0.32), POLE_L)))),
    (11, merge(READY, {"squash": 0.0})),
], note="crouch f0, raise f3, slam f5, hold f8, recover f11")

# launcher: low swing from below, rising, 10 frames
clip("launcher", 10, [
    (0, merge(stance("l", 1.4, twist=-12, lean=28, head_x=-6), ears(16, 34), {"squash": -0.20},
              slash(v(-0.14, -0.20, 0.30), v(0.0, -0.8, -0.5), left=(v(0.14, -0.1, 0.34), POLE_L)))),
    (3, merge(stance("l", 1.0, twist=10, lean=2, head_x=4), ears(-22, -44), {"squash": 0.16},
              slash(v(-0.04, -0.20, 0.72), v(0.1, -0.35, 0.95), left=(v(0.12, -0.04, 0.60), POLE_L)))),
    (5, merge({"plant": False}, torso(lean=-10, head_x=10), leg("l", -30, 20), leg("r", 12, 14), ears(-30, -60),
              {"squash": 0.20, "loc:hips": (0, 0, 0.05), "ik_r": (v(-0.12, -0.10, 0.90), POLE_R), "aim_r": (v(0.0, 0.1, 1.0), 0),
               "ik_l": (v(0.14, -0.06, 0.80), POLE_L)})),
    (9, merge(READY, {"squash": 0.0})),
], note="crouch f0, rising strike f3, follow f5, recover f9")

# ---- air attacks (never planted)
AIR = merge(torso(lean=4, head_x=-4), leg("l", -22, 40), leg("r", 8, 36))


def air_slash(wrist, blade, twist=0.0, lean=8.0, squash=0.04, left=None, ear=(0, 0)):
    return merge(AIR, torso(lean=lean, twist=twist, head_x=-6), ears(*ear), {"squash": squash},
                 {"ik_r": (wrist, POLE_R), "aim_r": (blade, 0), "ik_l": left or (v(0.2, -0.08, 0.60), POLE_L)})


clip("air_1", 7, [
    (0, air_slash(v(-0.25, 0.02, 0.62), v(-0.5, 0.5, 0.7), twist=-30, squash=-0.05, ear=(10, 24))),
    (2, air_slash(v(0.02, -0.26, 0.52), v(0.95, -0.35, 0.05), twist=28, lean=14, squash=0.10, ear=(-14, -30))),
    (4, air_slash(v(0.18, -0.15, 0.52), v(1.0, 0.2, 0.1), twist=44, squash=0.04, ear=(-20, -40))),
    (6, air_slash(v(0.10, -0.2, 0.55), v(0.6, -0.5, 0.5), twist=20, squash=0.0, ear=(0, 0))),
], note="airborne forehand; strike f2")

clip("air_2", 7, [
    (0, air_slash(v(0.14, -0.10, 0.54), v(1.0, 0.2, 0.25), twist=42, squash=-0.05, ear=(-10, -20))),
    (2, air_slash(v(-0.05, -0.28, 0.52), v(-0.95, -0.35, 0.1), twist=-34, lean=14, squash=0.10, ear=(14, 30))),
    (4, air_slash(v(-0.24, -0.12, 0.56), v(-1.0, 0.3, 0.2), twist=-50, squash=0.04, ear=(20, 40))),
    (6, air_slash(v(-0.10, -0.2, 0.55), v(-0.6, -0.5, 0.5), twist=-20, squash=0.0, ear=(0, 0))),
], note="airborne backhand; strike f2")

# air_3: a spinning downward finisher (the knockdown): half-curled, then a full yaw turn, blade driving down
clip("air_3", 9, [
    (0, air_slash(v(-0.2, 0.05, 0.78), v(-0.2, 0.4, 0.9), twist=-40, lean=-8, squash=-0.06, ear=(14, 30))),
    (2, merge(air_slash(v(0.12, -0.22, 0.60), v(0.9, -0.3, 0.3), twist=90, lean=18, squash=0.10, ear=(-20, -40)), {"loc:root": (0, 0, 0.0)})),
    (4, air_slash(v(-0.04, -0.34, 0.42), v(0.0, -0.7, -0.7), twist=160, lean=32, squash=0.14, ear=(30, 60))),
    (8, air_slash(v(-0.04, -0.34, 0.40), v(0.0, -0.75, -0.6), twist=160, lean=30, squash=0.06, ear=(20, 40))),
], note="spin f0-f4 (the code adds the full yaw turn), slam f4")

# ---- defence and reactions
clip("parry", 6, [
    (0, merge(stance("r", 0.9, twist=-8, lean=-6, head_x=4), ears(-10, -22), {"squash": -0.06},
              slash(v(-0.04, -0.28, 0.58), v(0.45, -0.25, 0.85), left=(v(0.14, -0.1, 0.5), POLE_L)))),
    (2, merge(stance("r", 1.0, twist=-10, lean=-12, head_x=6), ears(-18, -34), {"squash": 0.02},
              slash(v(-0.02, -0.30, 0.62), v(0.62, -0.1, 0.78), left=(v(0.12, -0.08, 0.52), POLE_L)))),
    (5, merge(stance("r", 0.9, twist=-8, lean=-4, head_x=2), ears(-6, -12), {"squash": 0.0},
              slash(v(-0.04, -0.28, 0.60), v(0.5, -0.2, 0.85), left=(v(0.14, -0.1, 0.5), POLE_L)))),
], note="brace f0, block f2 (held)")

clip("parry_success", 6, [
    (0, merge(stance("r", 1.0, twist=-14, lean=-14, head_x=6), ears(-22, -40), {"squash": 0.06},
              slash(v(-0.02, -0.30, 0.64), v(0.7, -0.05, 0.7), left=(v(0.12, -0.08, 0.54), POLE_L)))),
    (2, merge(stance("l", 1.0, twist=24, lean=6, head_x=-4), ears(10, 24), {"squash": -0.04},
              slash(v(0.10, -0.24, 0.54), v(0.9, -0.3, 0.2), left=(v(0.14, -0.04, 0.50), POLE_L)))),
    (5, merge(READY, {"squash": 0.0})),
], note="the flick after a clean parry")

clip("hurt", 6, [
    (0, merge(torso(lean=-24, head_x=18, twist=10), leg("l", 18, 20), leg("r", 22, 24), ears(-30, -60),
              {"squash": -0.10, "plant": True, "ik_r": (v(-0.26, 0.02, 0.62), POLE_R), "aim_r": (v(-0.4, 0.6, 0.7), 0),
               "ik_l": (v(0.26, 0.04, 0.62), POLE_L)})),
    (2, merge(torso(lean=-14, head_x=10, twist=6), leg("l", 12, 18), leg("r", 16, 20), ears(-14, -28),
              {"squash": 0.04, "plant": True, "ik_r": (v(-0.24, 0.0, 0.58), POLE_R), "aim_r": (v(-0.2, 0.5, 0.8), 0),
               "ik_l": (v(0.24, 0.0, 0.58), POLE_L)})),
    (4, merge(torso(lean=-6, head_x=4), leg("l", 6, 16), leg("r", 8, 18), ears(0, 0),
              {"squash": 0.0, "plant": True, "ik_r": (v(-0.2, -0.06, 0.52), POLE_R), "aim_r": (v(0.0, -0.3, 0.95), 0),
               "ik_l": (v(0.2, -0.08, 0.50), POLE_L)})),
], note="flinch back f0, recover f4; plays once")

# knockdown: blown back, hit the ground, lie there (hold)
LYING = merge({"hips": (-84, 0, 0), "loc:hips": (0, 0.30, -0.24), "head": (22, 0, 0)},
              leg("l", 8, 22), leg("r", 14, 28), ears(24, 14),
              {"squash": 0.0,
               "ik_r": (v(-0.30, 0.10, 0.20), POLE_R), "aim_r": (v(-0.3, 0.8, 0.2), 0),
               "ik_l": (v(0.26, 0.10, 0.10), POLE_L)})
clip("knockdown", 12, [
    (0, merge(torso(lean=-30, head_x=24), leg("l", 20, 20), leg("r", 28, 30), ears(-40, -70),
              {"squash": -0.04, "loc:hips": (0, 0.05, 0.12), "ik_r": (v(-0.28, 0.06, 0.70), POLE_R), "aim_r": (v(-0.5, 0.5, 0.7), 0),
               "ik_l": (v(0.28, 0.06, 0.70), POLE_L)})),
    (3, merge({"hips": (-50, 0, 0), "loc:hips": (0, 0.18, -0.10), "head": (18, 0, 0)}, leg("l", 24, 40), leg("r", 34, 50), ears(-30, -50),
              {"squash": 0.0, "ik_r": (v(-0.3, 0.2, 0.55), POLE_R), "aim_r": (v(-0.5, 0.8, 0.3), 0),
               "ik_l": (v(0.3, 0.2, 0.55), POLE_L)})),
    (6, pose(LYING, squash=-0.04)),
    (8, LYING),
], note="blown back f0, falling f3, hits the floor f6, lies still (holds)")

# getup: from lying to ready, 0.8 s (optional)
clip("getup", 12, [
    (0, LYING),
    (3, merge({"hips": (-40, 0, 0), "loc:hips": (0, 0.14, -0.14), "head": (-10, 0, 0)}, leg("l", -50, 110), leg("r", -30, 100), ears(10, 20),
              {"squash": -0.04, "ik_r": (v(-0.26, -0.16, 0.30), POLE_R), "aim_r": (v(0.2, -0.3, 0.9), 0),
               "ik_l": (v(0.2, -0.18, 0.26), POLE_L)})),
    (6, merge(stance("l", 1.5, twist=0, lean=34, head_x=-14), ears(16, 30), {"squash": -0.12},
              slash(v(-0.19, -0.2, 0.40), v(0.1, -0.3, 0.9), left=(v(0.16, -0.18, 0.38), POLE_L)))),
    (9, merge(stance("l", 0.8, twist=0, lean=14), ears(6, 12), {"squash": 0.06},
              slash(v(-0.19, -0.14, 0.48), v(0.12, -0.55, 0.83)))),
    (11, merge(READY, {"squash": 0.0})),
], note="up and ready")


def build(arm):
    return build_clips(arm, CLIPS)


def key_times():
    """{clip: [(frame, seconds)]} for the notes the move data uses."""
    return {n: [(f, f / FPS) for f, _ in c["keys"]] for n, c in CLIPS.items()}
