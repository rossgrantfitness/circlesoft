#!/usr/bin/env python3
"""Retargets the free Quaternius Universal Animation Library (CC0) onto one of our rigs, offline, by baking the clips onto
OUR bone names (so game code that reads `head`, `upper_arm_r`, `weapon_socket` ... does not change).

    python3 game/scripts/tools/retarget_ual.py red            # builds red_ross_v1_rigged_ual.glb + red_clip_keys.json
    python3 game/scripts/tools/retarget_ual.py wolf
    python3 game/scripts/tools/retarget_ual.py red --report   # also prints the quality report (clipping, sliding, loops)
    python3 game/scripts/tools/retarget_ual.py red --analyze Sword_Regular_A UAL2   # hand speed of a source clip (find contact)

Needs Python 3 + numpy only (no Blender, no Godot). Ross's originals are never written: the input is the TA's rigged GLB
(itself a copy), the output is a new file beside it. Everything that varies is data in game/data/animation/retarget_<name>.json:
the bone map with per-bone rest corrections, the clip table (source clip, slice, loop, contact time) and the stand-ins to keep.

How the retarget works (the same idea as Godot's BoneMap + rest fixer, but baked, and with chibi corrections):
  - Every mapped bone follows the WORLD rotation change of its source bone: delta = W_src(t) * W_src_rest^-1.
  - The target's rest pose (A-pose) is first raised to the source's rest pose (T-pose) for the arm bones with the
    shortest-arc rotation, so "arm hangs down" in the source is "arm hangs down" on her.
    `fix_deg` is an extra per-bone correction in that aligned frame (this is where the chibi fixes live).
  - A hand that holds a sword is aligned so that the blade (weapon_socket +Y) points where the source's grip points.
  - Hips move by the source pelvis sway scaled by the leg-length ratio; height comes from ground lock: the lowest sole point
    of the target is put at (ratio * lowest sole point of the source), so planted feet stay planted and jumps keep their air.
  - Bones that are not mapped (ears, tail, sockets, head_gear, back, lamp) follow their parent with their rest local pose.
"""
import argparse
import json
import os
import sys

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from glb_kit import (Skeleton, axis_angle, euler_deg, load_clips, load_glb, mat_to_quat, quat_to_mat,  # noqa: E402
                     read_accessor, rebuild_and_save, swing)

GAME_DIR = os.path.abspath(os.path.join(HERE, "..", ".."))
ROOT = os.path.abspath(os.path.join(GAME_DIR, ".."))
CFG_DIR = os.path.join(GAME_DIR, "data", "animation")
UP = np.array([0.0, 1.0, 0.0])


def mirror_deg(v):
    """Rotation (x, y, z degrees) mirrored across the YZ plane (left <-> right)."""
    return [v[0], -v[1], -v[2]]


class Retargeter:
    def __init__(self, cfg):
        self.cfg = cfg
        self.fps = float(cfg.get("fps", 30))
        self.t_doc, self.t_blob = load_glb(os.path.join(GAME_DIR, cfg["target"]))
        self.t = Skeleton(self.t_doc)
        self.src_docs = {}
        for key, path in cfg["sources"].items():
            doc, blob = load_glb(os.path.join(GAME_DIR, path))
            sk = Skeleton(doc)
            self.src_docs[key] = (sk, load_clips(doc, blob, sk))
        # all UAL files share the same skeleton: use the first as the reference skeleton
        self.s = next(iter(self.src_docs.values()))[0]
        self.bones = self._expand_bones(cfg["bones"])
        self._build_rest_alignment()
        self.ground = cfg["ground"]
        self._build_ground()

    # ------------------------------------------------------------ config
    @staticmethod
    def _expand_bones(entries):
        """{side} templates become a left and a right entry; fix_deg of the right side is mirrored."""
        out = []
        for e in entries:
            if "{s}" in e["target"]:
                for side in ("l", "r"):
                    d = json.loads(json.dumps(e).replace("{s}", side))
                    if side == "r" and "fix_deg" in d:
                        d["fix_deg"] = mirror_deg(d["fix_deg"])
                    if side == "r" and "to" in d:
                        d["to"] = [-d["to"][0], d["to"][1], d["to"][2]]
                    if side == "r" and "blade_roll_deg" in d:
                        d["blade_roll_deg"] = -d["blade_roll_deg"]
                    if "only_side" in d and d["only_side"] != side:
                        continue
                    out.append(d)
            else:
                out.append(e)
        return out

    def _dir(self, sk, bone, spec):
        """World rest direction of a bone: toward a named node, an explicit vector, or the parent's direction."""
        i = sk.bone(bone)
        if isinstance(spec, list):
            v = np.array(spec, dtype=float)
        elif spec == "parent":
            p = sk.parent[i]
            v = sk.rest_world_p[i] - sk.rest_world_p[p]
        else:
            v = sk.rest_world_p[sk.bone(spec)] - sk.rest_world_p[i]
        return v / np.linalg.norm(v)

    def _build_rest_alignment(self):
        """C[target bone] = (extra correction) * (rest alignment swing) * (target rest world rotation); and the pairs."""
        self.pairs = []                       # (target index, source index, C)
        self.mapped = {}
        for e in self.bones:
            b = self.t.bone(e["target"])
            s = self.s.bone(e["source"])
            rest = self.t.rest_world_r[b]
            fix = np.eye(3)
            if "t_dir" in e:
                # raise this bone from the target's A-pose to the canonical T-pose direction `to`
                fix = swing(self._dir(self.t, e["target"], e["t_dir"]), np.array(e["to"], dtype=float))
            c = fix @ rest
            if "blade_socket" in e:
                # align the blade: where the target's socket +Y points in the (aligned) rest versus where the source grip points
                sock = self.t.bone(e["blade_socket"])
                local_axis = rest.T @ (self.t.rest_world_r[sock] @ np.array([0.0, 1.0, 0.0]))
                want = np.array(e["blade_dir_in_source_rest"], dtype=float)
                have = c @ local_axis
                c = swing(have, want) @ c
                if e.get("blade_roll_deg"):
                    c = axis_angle(want, e["blade_roll_deg"]) @ c
            fx = e.get("fix_deg")
            if fx:
                c = euler_deg(*fx) @ c
            self.pairs.append((b, s, c))
            self.mapped[b] = len(self.pairs) - 1

    def _build_ground(self):
        g = self.ground
        self.k = float(g["scale"])
        # contact points: (bone node, offset vector in the rest world frame, lift). The lowest point of a pose is
        # min(joint y + rotated offset y - lift): soles have lift 0, body points (hips, chest, head, hands) a radius, so a
        # character lying on the floor lies ON it.
        self.t_soles = [(self.t.bone(p["bone"]), np.array(p["offset"], dtype=float), float(p.get("lift", 0.0))) for p in g["target_points"]]
        self.s_soles = [(self.s.bone(p["bone"]), np.array(p["offset"], dtype=float), float(p.get("lift", 0.0))) for p in g["source_points"]]
        self.t_hips = self.t.bone(self.cfg["hips"]["target"])
        self.s_pelvis = self.s.bone(self.cfg["hips"]["source"])
        self.hips_k = float(self.cfg["hips"].get("scale", self.k))
        # soles sit on the floor at rest on both skeletons: check
        self.t_floor_err = max(abs(self.t.rest_world_p[f][1] + o[1]) for f, o, lift in self.t_soles if lift == 0.0)

    # ------------------------------------------------------------ one frame
    def frame(self, src_sk, src_clip, t, ground="lock"):
        """The target's mapped bones at source time t: ({bone idx: local rotation matrix}, hips local translation, source info)."""
        lr, lp = src_clip.pose(src_sk, t)
        wr, wp = src_sk.fk(lr, lp)
        # source lowest sole point
        s_low = np.inf
        for f, off, lift in self.s_soles:
            d = wr[f] @ src_sk.rest_world_r[f].T
            s_low = min(s_low, wp[f][1] + (d @ off)[1] - lift)
        pelvis_delta = wp[self.s_pelvis] - src_sk.rest_world_p[self.s_pelvis]

        world = {}
        local = {}
        n = len(self.t.nodes)
        wr_t = np.empty((n, 3, 3))
        for i in self.t.order:
            p = self.t.parent[i]
            if i in self.mapped:
                _, s, c = self.pairs[self.mapped[i]]
                w = (wr[s] @ src_sk.rest_world_r[s].T) @ c
                wr_t[i] = w
                local[i] = (wr_t[p].T @ w) if p is not None else w
            else:
                wr_t[i] = (wr_t[p] @ self.t.rest_r[i]) if p is not None else self.t.rest_r[i]
        # hips translation: horizontal sway scaled; vertical from ground lock
        hips_rest = self.t.rest_world_p[self.t_hips]
        want = hips_rest + np.array([pelvis_delta[0], 0.0, pelvis_delta[2]]) * self.hips_k
        # target soles with that hips position
        lt = self.t.rest_t.copy()
        par = self.t.parent[self.t_hips]
        lt[self.t_hips] = wr_t[par].T @ (want - self.t.rest_world_p[par]) if par is not None else want
        lr_t = np.array([local.get(i, self.t.rest_r[i]) for i in range(n)])
        twr, twp = self.t.fk(lr_t, lt)
        low = np.inf
        for f, off, lift in self.t_soles:
            d = twr[f] @ self.t.rest_world_r[f].T
            low = min(low, twp[f][1] + (d @ off)[1] - lift)
        if ground == "lock":
            dy = self.k * s_low - low
        else:     # "free": airborne clips; the game moves the body, the pose keeps the source's hips height change (scaled)
            dy = pelvis_delta[1] * self.hips_k
            dy = (hips_rest[1] + dy) - twp[self.t_hips][1]
        want[1] += dy
        lt[self.t_hips] = wr_t[par].T @ (want - self.t.rest_world_p[par]) if par is not None else want
        return local, lt[self.t_hips], {"s_low": s_low, "dy": dy, "wr_s": wr, "wp_s": wp}

    # ------------------------------------------------------------ clips
    def _parts(self, spec):
        parts = spec["parts"] if "parts" in spec else [spec]
        out = []
        for p in parts:
            key, name = p["source"].split(":")
            sk, clips = self.src_docs[key]
            clip = clips[name]
            a = float(p.get("from_s", 0.0))
            b = float(p["to_s"]) if p.get("to_s") is not None else clip.length
            if p.get("reverse"):
                a, b = b, a
            out.append((sk, clip, a, b, float(p.get("speed", 1.0))))
        return out

    def bake(self, spec):
        """Samples a clip definition at self.fps. Returns dict(times, rot {bone: (n,4)}, hips (n,3), frames=list of info)."""
        times, rots, hips, info = [], {b: [] for b in self.mapped}, [], []
        t_out = 0.0
        for sk, clip, a, b, speed in self._parts(spec):
            span = abs(b - a) / speed
            count = int(round(span * self.fps))
            for k in range(count + 1):
                if times and k == 0:
                    continue                                   # the joint between two parts is one frame
                ts = a + (b - a) * (k / max(count, 1))
                local, ht, inf = self.frame(sk, clip, ts, spec.get("ground", "lock"))
                times.append(t_out + (k / self.fps))
                for bone in self.mapped:
                    rots[bone].append(mat_to_quat(local[bone]))
                hips.append(ht)
                info.append(inf)
            t_out += count / self.fps
        out_rot = {}
        for bone, qs in rots.items():
            qs = np.array(qs)
            for i in range(1, len(qs)):                        # shortest path for interpolation
                if np.dot(qs[i], qs[i - 1]) < 0:
                    qs[i] = -qs[i]
            out_rot[bone] = qs
        res = {"times": np.array(times), "rot": out_rot, "hips": np.array(hips), "info": info}
        if spec.get("loop"):
            err = self._loop_error(res)
            res["loop_error_deg"] = err
            for bone in out_rot:                              # close the loop exactly on the first pose
                out_rot[bone][-1] = out_rot[bone][0]
            res["hips"][-1] = res["hips"][0]
        return res

    def _loop_error(self, res):
        worst = 0.0
        for bone, qs in res["rot"].items():
            d = abs(float(np.dot(qs[0], qs[-1])))
            worst = max(worst, np.degrees(2 * np.arccos(min(1.0, d))))
        return worst

    def contact_out_time(self, spec):
        """Where the strike lands in the OUTPUT clip: spec['contact_src_s'] is a time in the source clip (of part
        spec['contact_part'], default 0); None when the clip has no contact."""
        c = spec.get("contact_src_s")
        if c is None:
            return None
        part = int(spec.get("contact_part", 0))
        offset = 0.0
        for i, (sk, clip, a, b, speed) in enumerate(self._parts(spec)):
            if i == part:
                return offset + abs(float(c) - a) / speed
            offset += round(abs(b - a) / speed * self.fps) / self.fps
        raise ValueError("contact_part out of range")

    # ------------------------------------------------------------ report
    def quality(self, res, spec):
        """Clipping numbers for a baked clip: how many frames an arm segment is inside the head sphere or the torso
        ellipsoid (proxy shapes from the target's skin, in the config) and the deepest penetration in metres."""
        q = {"head": 0, "torso": 0, "frames": len(res["times"]), "head_pen_max": 0.0, "torso_pen_max": 0.0}
        px = self.cfg.get("proxies")
        if not px:
            return q
        t = self.t
        n = len(t.nodes)
        head_b = t.bone(px["head"]["bone"])
        torso = px["torso"]
        for k in range(len(res["times"])):
            lr = np.array([quat_to_mat(res["rot"][i][k]) if i in res["rot"] else t.rest_r[i] for i in range(n)])
            lt = t.rest_t.copy()
            lt[self.t_hips] = res["hips"][k]
            wr, wp = t.fk(lr, lt)
            head = wp[head_b] + (wr[head_b] @ t.rest_world_r[head_b].T) @ np.array(px["head"]["center_offset"])
            c0, c1 = wp[t.bone(torso["from"])], wp[t.bone(torso["to"])]
            axis = c1 - c0
            length = np.linalg.norm(axis)
            axis = axis / length
            hit_h = hit_t = False
            for seg in px["arm_segments"]:
                a, b = wp[t.bone(seg[0])], wp[t.bone(seg[1])]
                for f in np.linspace(seg[2] if len(seg) > 2 else 0.0, 1.0, 6):
                    pt = a + (b - a) * f
                    pen = px["head"]["radius"] + px["arm_radius"] - np.linalg.norm(pt - head)
                    if pen > 0.0:
                        hit_h = True
                        q["head_pen_max"] = max(q["head_pen_max"], pen)
                    s_ = float(np.dot(pt - c0, axis))
                    if 0.0 <= s_ <= length:
                        rel = pt - (c0 + axis * s_)
                        wx, wz = torso["half_width"] + px["arm_radius"], torso["half_depth"] + px["arm_radius"]
                        e = np.sqrt((rel[0] / wx) ** 2 + (rel[2] / wz) ** 2)
                        if e < 1.0:
                            hit_t = True
                            q["torso_pen_max"] = max(q["torso_pen_max"], (1.0 - e) * min(wx, wz))
            q["head"] += hit_h
            q["torso"] += hit_t
        return q


# ---------------------------------------------------------------------- driver
def load_cfg(name):
    with open(os.path.join(CFG_DIR, "retarget_%s.json" % name)) as f:
        return json.load(f)


def analyze(rt, clip_name, key, bone="hand_r"):
    sk, clips = rt.src_docs[key]
    clip = clips[clip_name]
    node = sk.bone(bone)
    prev = None
    print("clip %s length %.3f s" % (clip_name, clip.length))
    n = int(round(clip.length * 30))
    for k in range(n + 1):
        t = k / 30.0
        lr, lp = clip.pose(sk, t)
        wr, wp = sk.fk(lr, lp)
        pos = wp[node]
        sp = 0.0 if prev is None else np.linalg.norm(pos - prev) * 30.0
        print("f%-3d t=%.3f hand=(%.2f %.2f %.2f) speed=%.2f m/s" % (k, t, pos[0], pos[1], pos[2], sp))
        prev = pos


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("name", choices=["red", "wolf", "brute"])
    ap.add_argument("--report", action="store_true")
    ap.add_argument("--only", help="comma list of clip names to rebuild (report only)")
    ap.add_argument("--analyze", nargs=2, metavar=("SOURCE_CLIP", "UAL1|UAL2"))
    ap.add_argument("--no-write", action="store_true")
    args = ap.parse_args()
    cfg = load_cfg(args.name)
    rt = Retargeter(cfg)
    if args.analyze:
        analyze(rt, args.analyze[0], args.analyze[1])
        return
    print("target %s, %d bones mapped, floor error %.4f m" % (cfg["target"], len(rt.mapped), rt.t_floor_err))

    new_anims = []
    keys_doc = {}
    for spec in cfg["clips"]:
        name = spec["name"]
        if args.only and name not in args.only.split(","):
            continue
        res = rt.bake(spec)
        times = res["times"]
        channels = []
        for bone, qs in res["rot"].items():
            channels.append((bone, "rotation", qs))
        channels.append((rt.t_hips, "translation", res["hips"]))
        new_anims.append({"name": name, "times": times, "channels": channels})
        length = float(times[-1])
        entry = {"length_s": round(length, 4), "loop": bool(spec.get("loop")), "source": spec.get("source") or " + ".join(p["source"] for p in spec["parts"])}
        contact = rt.contact_out_time(spec)
        entry["keys"] = _keys_for(spec, length, rt.fps, contact)
        if contact is not None:
            entry["contact_s"] = round(contact, 4)
            entry["contact_frame"] = int(round(contact * rt.fps))
        if spec.get("note"):
            entry["note"] = spec["note"]
        keys_doc[name] = entry
        line = "%-16s %5.2fs %3d frames" % (name, length, len(times))
        if "loop_error_deg" in res:
            line += "  loop err %.1f deg" % res["loop_error_deg"]
        if args.report:
            q = rt.quality(res, spec)
            line += "  head-clip %2d/%d (%.0f mm)  torso-clip %2d (%.0f mm)" % (q["head"], q["frames"], q["head_pen_max"] * 1000, q["torso"], q["torso_pen_max"] * 1000)
        print(line)
    if args.no_write or args.only:
        return
    # ---- write the glb
    out_path = os.path.join(GAME_DIR, cfg["output"])
    keep = [a for a in cfg.get("keep_standins", [])]
    present = {a["name"] for a in rt.t_doc.get("animations", [])}
    missing = [k for k in keep if k not in present]
    if missing:
        raise SystemExit("keep_standins not in the target file: %s" % missing)
    rebuild_and_save(out_path, rt.t_doc, rt.t_blob, new_anims, keep,
                     generator_note="Animations: Quaternius Universal Animation Library 1+2 (CC0) retargeted by scripts/tools/retarget_ual.py")
    print("wrote", os.path.relpath(out_path, ROOT), "%.0f KB" % (os.path.getsize(out_path) / 1024.0))
    # ---- key data (merge the kept stand-ins' entries from the old file)
    kd_path = os.path.join(GAME_DIR, cfg["clip_keys"])
    old = {}
    if os.path.exists(kd_path):
        with open(kd_path) as f:
            old = json.load(f).get("clips", {})
    clips_out = {}
    for spec in cfg["clips"]:
        clips_out[spec["name"]] = keys_doc[spec["name"]]
    for k in keep:
        if k in old and k not in clips_out:
            e = dict(old[k])
            e["source"] = "stand-in (hand-posed by the Technical Artist; no free clip fits)"
            e["fps"] = 15
            clips_out[k] = e
    doc = {"_about": cfg["clip_keys_about"], "fps": int(rt.fps), "clips": clips_out}
    with open(kd_path, "w") as f:
        json.dump(doc, f, indent=1)
        f.write("\n")
    print("wrote", os.path.relpath(kd_path, ROOT))


def _keys_for(spec, length, fps, contact):
    ks = spec.get("keys")
    if ks is None:
        ks = [0.0, length] if contact is None else [0.0, contact, length]
    out = []
    for s in ks:
        s = max(0.0, min(length, float(s)))
        out.append({"frame": int(round(s * fps)), "clip_s": round(s, 4)})
    return out


if __name__ == "__main__":
    main()
