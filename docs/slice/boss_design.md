# Kasp's boss fight: the plain read (VS-23)

> **For Ross.** One fight in two halves. On foot, Red hacks apart Kasp's walker (the Hushmaster). Then Kasp escapes into a giant junk mech and Red docks into the colossus (your option C). Designer's numbers (Level 1), all starting guesses you change by playing. Data: `game/data/combat/bosses/hushmaster.json`, `bosses/junk_mech.json`, and the `hushmaster` and `junk_mech` move sets in `moves.json`. Owner: Combat Designer. Status: draft 2026-10-09.

DECISION NEEDED: Do you approve the junk mech's attack list (a new list, so it is yours)?
Option A: **Four attacks plus two last-stand chains.** *Scrap Swing* (an arm sweeps a big arc: back out, run round it or jump it), *Wrecking Drop* (both arms up, a circle follows you, then a ring: leave the circle, jump the ring), *Stomp March* (two stomps, two rings: jump both), *Scrap Barrage* (three scrap blocks land in circles painted ahead of time: keep moving). Each attack leaves one armour plate open while it recovers, so you learn "bait the swing, hit the shoulder". — Pros: every attack has a different answer (dodge back, jump, move), the plates give the fight a rhythm, and all four read from 75 m. / Cons: Barrage needs circles that land where you stood a moment ago (a bit of new code).
Option B: **Three attacks, no Barrage.** — Pros: less code; cleaner. / Cons: the fight never makes you keep moving, so it is less varied.
Recommendation: **A.** Barrage is the only attack that asks for movement instead of a jump or a dash, and the code is small.

DECISION NEEDED: With hacks off in robot form there is no healing in the colossus round. Add repair cells?
Option A: **Yes: two containers in each of the bowl's eight smashable clusters hold a green repair cell (heals 12 percent).** — Pros: forgiving (your Kingdom Hearts rule), uses the containers the arena already has, and rewards smashing things. / Cons: a new pickup in a robot round.
Option B: **No healing.** The colossus has 6,000 health, a clean fight takes 0 to 2 hits, and a defeat restarts docked at full health. — Pros: nothing new. / Cons: one bad stretch means a restart.
Recommendation: **A.** It is a loot container with a different item inside, not a new system. Data is written with `enabled: false` until you answer.

## Phase 1: the Hushmaster (on foot, about 4 minutes)

Red has 120 health. Hacks work, and they are the key: the sword fills the battery (it does only 30 percent damage to the walker while it stands), and the relays on the legs need a hack.

| Attack | The tell (what you see) | The answer | Hurts for |
|---|---|---|---|
| **Leg Stomp** | The nearest leg glows amber and rises for 1.1 s. A circle on the floor shows the landing and stops following you 0.4 s before. | Jump the ring (it is 0.6 m tall and slow), or dash through. | 17 foot, 12 ring |
| **Dish Sweep** | A red line crawls across the floor for 1.4 s and draws the whole 80 degree fan. Then the beam follows that exact line. | Stand outside the fan, run with it, or dash through the beam. | 14 |
| **Drone Drop** | A floor hatch glows amber for 1 s. Three drones rise together. | **EMP** catches all three (one Zap also kills one). | 7 per dive |
| **Quiet Hours** | The dish lowers and hums, screen edges fizz. 1.4 s later your hacks lock for 5 s. | **Hit the dish.** One Zap before the lock cancels it; three sword hits during it end it early. | locks hacks |

- **Relays:** four leg pairs, one relay box on each (72 health). Zap it twice, or Overclock one of the three gun pylons and its fire breaks relays for you (one to two per hijack). The pylons are Kasp's but powered down: they never shoot at you. The sword only clinks off a relay.
- **Fair-play rules:** every hurtful move has at least a 1 s tell (the enemies' rule is 0.5 s); the first three attacks are fixed (ring, line, ring) so everyone meets them in order; nothing chains until two pairs are down; the wind-ups never speed up, only the gap between attacks shrinks (1.9 s to 1.3 s); while hacks are locked he never drops drones.
- **Topple:** the last pair folds, the rig crashes to the floor, drones switch off, and after 2.6 s the hack button offers **Jack in**: Red plugs into the dish for a big hit (60 percent), and the phase ends. No timer. If you would rather break the dish first, that removes Dish Sweep and Quiet Hours for good.

## Transition (about 40 seconds)

Kasp is thrown from the seat and rides a crane cage up. The three yard cranes pour scrap into the Heap while you run (you have control) down the ramp to the loader. Board, drive the ring road, dock into the colossus (the 4.5 s docking). Red cannot be hurt.

## Phase 2: the Heap (colossus, about 3 minutes 20)

The colossus is fast and sharp (22 m/s, turns 70 degrees a second); the Heap is slow and heavy (12 m/s, 38 degrees, double the wind-up). Every attack shows: lamps turn orange then red, a 12 m or wider decal on the floor, and the body changes shape. The colossus has 6,000 health; a clean fight takes 0 to 2 hits, a first try 5 to 8, and about 11 end it.

| Attack | Wind-up | The answer | Opens |
|---|---|---|---|
| **Scrap Swing** (left or right) | 2.0 s | Dash back out of a 34 m arc, run round it, or jump it (9 m tall) | that shoulder plate |
| **Wrecking Drop** | 2.4 s | Leave the 16 m circle, then jump the ring (52 m) | chest plate |
| **Stomp March** | 1.7 s | Jump two rings, one second apart | back plate |
| **Scrap Barrage** | 1.8 s | Keep moving; each circle lands where you were 0.6 s ago | nothing |

Four plates (about 10,000 total), then the core in Kasp's cab (8,400): plates take 35 percent damage until the attack that opens them is recovering (2 to 2.8 s of free hitting, pale cyan lamps, lock-on pointer). The Heap prefers the attack that opens a plate still standing, so it never stalls. At 35 percent core health: a roar, then chained attacks and shorter gaps, never faster wind-ups.

## Small calls I made (overturn any)

Name "the Heap" for the junk mech. The loader at the J4 cradle wakes by pressing the button, not by Overclock (50 battery may be spent, and a story beat should never be gated by a resource). The battery is topped to at least 60 whenever the Hushmaster fight starts or restarts. Phase 1 pylons never shoot at Red. The sword does 30 percent to the standing walker.

## What the Combat Programmer needs from the data

`ring` and `beam` hitbox shapes (planned), plus a box `origin` and `damage_mult`, and move keys `ground_marker`, `floor_line`, `floor_decal`, `targets`, `opens`, `aim_pitch`; the junk mech's set is already in final world units, so do not scale it again. The timing checks (1 s floor for the walker, 1.6 s for the Heap) are in the data files' `rules`.
