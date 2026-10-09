# Red's hacks: the plain read

> **For Ross.** Four hacks on the second button, powered by a battery that sword hits refill. Designer's numbers (Level 1), all starting guesses you change by playing. Data: `game/data/combat/hacks.json`, the four cast moves in `moves.json` (red set), the "Hacks" tab in the feel panel (`feel.json`). Owner: Combat Designer. Status: draft 2026-10-09, for VS-7.

**One decision is open and it is not new:** how Red picks a hack (the tech plan's Decision 1, A pick-then-fire or C automatic). Both are built from the same data. The feel panel's first Hacks knob, "How a hack is picked", flips between them while you play, so you can answer by feel. Recommendation stays A as the default, with C one switch away.

## The battery

A bar of 100. Sword hits fill it, hacks drain it, and **hacks never refill it** (so there is no free loop). You start a new game at 50 and it carries through doors.

| Sword hit | Fills |
|---|---|
| Clean hit | 7 |
| Hit blocked / through armour | 3 / 4 |
| Guard break | 10 |
| String finisher / hit in the air | +6 / +2 |

Rule of thumb: one Light string of three plus its finisher is about 27, so **one Zap Drone per string, one EMP every two strings, a full Reboot about every fourth string.** A cap of 30 per second stops one big multi-hit from filling the bar in a frame. It rewards staying in the fight, which is your pitch pick.

## The four hacks

| Hack | Job | Cost | Cast time | What it does |
|---|---|---|---|---|
| **Zap Drone** | ranged damage | 20 | fast (110 ms to launch) | A drone flies straight at the lock or the nearest enemy in front (straight ahead if none), through up to 3 enemies, 12 damage each; double to drones, triple to boss relays. Fine in the air. A Light or Heavy can follow it. |
| **EMP** | crowd control | 40 | 160 ms charge-up | A 4.5 m ring: pushes everything 3 m back, breaks guards, knocks drones, turrets and robots out for 2.5 to 4 s. Barely hurts. Bosses are pushed, never stunned. Fine in the air; dash-cancels early to escape. |
| **Overclock** | hijack | 50 | 200 ms reach | Take one turret, drone or robot for 10 s. It fights for Red and its hits hurt enemies and boss parts; it is dazed for under a second afterward. One at a time. Nothing in range means no cast and no cost ("No signal"). |
| **Reboot** | heal | whole battery (needs it full) | slowest (260 ms) | Heals half her health, untouchable for 0.6 s while it runs. Long recovery, so it is a choice, not a reflex. |

Why these numbers: Zap is cheap and weak up close, because a sword hit is free. EMP is the panic button and the opener, so it damages almost nothing. Overclock costs half the bar because a turret on your side for ten seconds is worth two strings of fighting. Reboot is the most expensive on purpose: healing is the battery's long game.

## Option A: pick, then fire

The HUD shows the selected hack; d-pad left/right (keys 1 to 4, or the wheel) changes it; the hack button fires it. Order: Zap, EMP, Overclock, Reboot. The HUD marks what Overclock would take, and greys a hack the battery can't pay for.

## Option C: automatic

The hack button reads the situation. Rules run top to bottom; the first one that matches and that Red can afford fires. If the matching rule can't be afforded it either tries the next rule or fizzes (nothing spent, the bar shakes).

1. **Hold the button 0.45 s: Reboot** (fizz if the battery isn't full). A tap never reboots, so the whole battery is never lost by accident.
2. **Four or more enemies within 3.5 m: EMP.** Getting out of the pile comes first, even with a turret in front.
3. **Locked on to a turret, robot or drone: Overclock.** If she locked it, she meant it.
4. **A turret or robot within 10 m in front (60 degree cone): Overclock.** Loose drones are not taken unless locked on; they get zapped.
5. **Three or more enemies within 4.5 m: EMP.**
6. **Anything else: Zap Drone.**

The cost of C is exactly what you'd expect: you can't Zap a locked drone (it takes it over instead), and you can't EMP a lone Brute. The HUD shows the last hack used so the guess is never a surprise. If you play C and hate one rule, tell me which; each rule is one line of data.

## What I'd change by playing (the Hacks tab)

Pick mode; battery from hits; hack cost; cooldown; damage; Zap pierce; EMP radius, push and stun time; Overclock length; Reboot heal and whether it needs a full battery; the two Automatic thresholds; and "Free hacks (testing)", which makes them all free so you can try each one without earning it. Every knob has a plain hint.

## Notes for the builders (VS-8 to VS-10, art, audio)

- **Enemy tags** (`drone`, `turret`, `robot`, `relay`) are read from enemies.json; `grunt` and `brute` have none yet, so they take plain damage and EMP only pushes them. Whoever adds the drone, turret and cop-robot enemies adds the tags.
- The Zap and EMP hits use existing sparks (`slash`, `heavy`) until the Technical Artist adds `zap` and `pulse`. The sounds `hack_zap_hit`, `hack_emp_hit` do not exist yet (VS-32).
- The four cast moves have no pose keys yet: VS-10 adds them from the free clip library; until then they play the procedural fallbacks (thrust, brace, thrust, stretch up).
- Cast moves have no hitbox: the effect starts at the move's impact time (the end of startup), so cancels and timing tests behave like any other move.
- Two small rules I invented, for Ross to overturn: a second Overclock cast while one is running is refused; if the target dies during Overclock's 200 ms reach, the cost is refunded.
- No new button, system or rule beyond Ross's approved four hacks and the plan's section 4. The two "air_ok" casts (Zap, EMP) let hacks join juggles; if you'd rather keep hacks on the ground, flip `air_ok` to false.
