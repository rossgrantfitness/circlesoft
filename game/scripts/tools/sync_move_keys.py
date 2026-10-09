#!/usr/bin/env python3
"""Writes the `anim.keys` of the moves in data/combat/moves.json from the real clips' contact frames, so a hit lands on the
clip's strike pose exactly when the move data says (startup_ms for the player, impact_ms for enemies).

    python3 game/scripts/tools/sync_move_keys.py            # rewrite the keys of every move whose clip came from the free pack
    python3 game/scripts/tools/sync_move_keys.py --check    # only report what would change

Only `anim.keys` is touched (never a gameplay number). Clips are NOT retimed: they play at their own speed between keys, and
each key snaps the clip to the data-timed pose (docs/pivot/combat_api.md section 3):
    player move:  at 0 -> contact - startup (the wind-up as it would be at that moment), at startup -> contact,
                  at startup+active -> contact + active, at the end -> contact + (active + recovery).
    enemy attack: the wind-up clip plays from 0; LEAD_IN_S before the impact the swing clip takes over, so the strike
                  lands at impact_ms. The swing clip is `attack_swing` for the sandbox enemies; for a wind-up clip whose key
                  entry has `"strike": "<clip>"` (the junk mech's swing_r_windup -> swing_r_strike ...) it is that clip.
For the junk mech the second and third strikes of a multi-hit clip are `extra_contacts_s` in the key data (stomp: the second stomp,
barrage: the second and third lob); they are not keyed (the clip plays at its own speed between keys), the tests check that they
sit where the move's hitboxes are.
Clips whose contact does not exist (hand-posed stand-ins) keep the keys they have.
The file is read and written in its own format (indent 1, no trailing newline); the script refuses to run if a plain
round trip would change it.
"""
import argparse
import json
import os

HERE = os.path.dirname(os.path.abspath(__file__))
GAME = os.path.abspath(os.path.join(HERE, "..", ".."))
MOVES = os.path.join(GAME, "data", "combat", "moves.json")
# move set -> clip-key file, relative to game/data/
CLIP_KEYS = {"red": "combat/red_clip_keys.json", "grunt": "combat/wolf_clip_keys.json", "brute": "combat/brute_clip_keys.json",
             "junk_mech": "animation/junk_mech_clip_keys.json"}
LEAD_IN_S = 0.1


def load_clips(set_id):
    path = os.path.join(GAME, "data", CLIP_KEYS[set_id])
    if not os.path.exists(path):
        return {}
    with open(path) as f:
        return json.load(f)["clips"]


def is_real(entry):
    return entry is not None and "stand-in" not in entry.get("source", "stand-in")


def player_keys(clips, move):
    clip = move["anim"]["clip"]
    e = clips.get(clip)
    if not is_real(e) or "contact_s" not in e:
        return None
    s, a, r = move["startup_ms"], move["active_ms"], move["recovery_ms"]
    c, length = e["contact_s"], e["length_s"]
    pts = [(0, max(0.0, c - s / 1000.0)), (s, c), (s + a, c + a / 1000.0), (s + a + r, c + (a + r) / 1000.0)]
    return [{"at_ms": at, "clip_s": round(min(t, length), 4)} for at, t in pts]


def enemy_keys(clips, move):
    anim = move["anim"]
    wind = clips.get(anim["clip"])
    strike = (wind or {}).get("strike", "attack_swing" if anim["clip"] == "attack_windup" else None)
    swing = clips.get(strike) if strike else None
    if strike is None or not is_real(wind) or not is_real(swing) or "contact_s" not in swing:
        return None
    impact = int(move.get("impact_ms", move["startup_ms"]))
    a, total = move["active_ms"], move["startup_ms"] + move["active_ms"] + move["recovery_ms"]
    c, length = swing["contact_s"], swing["length_s"]
    lead = min(LEAD_IN_S, c)
    return [
        {"at_ms": 0, "clip": anim["clip"], "clip_s": 0.0},
        {"at_ms": int(impact - lead * 1000), "clip": strike, "clip_s": round(c - lead, 4)},
        {"at_ms": impact, "clip": strike, "clip_s": round(c, 4)},
        {"at_ms": impact + a, "clip": strike, "clip_s": round(min(c + a / 1000.0, length), 4)},
        {"at_ms": total, "clip": strike, "clip_s": round(min(c + (total - impact) / 1000.0, length), 4)},
    ]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--check", action="store_true")
    args = ap.parse_args()
    with open(MOVES) as f:
        text = f.read()
    data = json.loads(text)
    if json.dumps(data, indent=1, ensure_ascii=False) != text:
        raise SystemExit("moves.json is not in the canonical format (indent 1, no trailing newline); refusing to rewrite it")
    changed = 0
    for set_id, set_data in data["sets"].items():
        if set_id not in CLIP_KEYS:
            continue
        clips = load_clips(set_id)
        for move_id, move in set_data["moves"].items():
            anim = move.get("anim")
            if not anim or not anim.get("clip"):
                continue
            keys = enemy_keys(clips, move) if set_id != "red" else player_keys(clips, move)
            if keys is None or keys == anim.get("keys"):
                continue
            changed += 1
            print("%s.%s: %s" % (set_id, move_id, " ".join("%d->%s%.3f" % (k["at_ms"], k.get("clip", "") + ":" if "clip" in k else "", k["clip_s"]) for k in keys)))
            anim["keys"] = keys
    if changed and not args.check:
        with open(MOVES, "w") as f:
            f.write(json.dumps(data, indent=1, ensure_ascii=False))
    print("%d move(s) %s" % (changed, "would change" if args.check else "updated"))


if __name__ == "__main__":
    main()
