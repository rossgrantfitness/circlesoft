# The junkyard roster and fights (VS-17)

> **For Ross.** Four kinds of enemy and nine fights across the junkyard rooms. Nothing here needs your decision: numbers and names only (Level 1), all starting guesses you change by playing. Data: `game/data/combat/enemies.json` (entries and tags), `game/data/slice/encounters.json`, the `signals_drone` and `wall_turret` move sets in `moves.json`. Owner: Combat Designer. Status: draft 2026-10-09.

## Who they are

| Enemy | Id | Health | Attack and tell | Hack answer |
|---|---|---|---|---|
| **Signals cop** (Ross's Cyberwolf, the Grunt by data) | `grunt`, tag `cop` | 48 | Claw swipe, 0.56 s tell, 10 damage. Dodges, flees at low health, flanks. Unchanged. | Zap, or Overclock one onto its friends |
| **Signals drone** | `signals_drone`, tags `drone flying` | 22 | Rears up and glows 0.76 s, then darts 5 m along a locked line (7). Sinks low for 1.1 s after: free hits. Up close, a short shock ring (5). | **EMP** drops it for 3 s; one **Zap** kills it (the drone tag doubles Zap); Overclock makes it an ally |
| **Wall turret** | `wall_turret`, tags `turret static` | 80 | A thin laser shows a full second, locks 0.35 s before the first bolt, then three bolts down that one line (7 each). One step sideways beats all three. About one burst every 3 to 5 s. | Two **Zaps** stun it 2.5 s, **EMP** switches it off for 4 s, **Overclock** makes it fire for Red (about 100 damage into a Brute) |
| **Signals heavy** (the Brute until your model) | `brute`, tag `heavy` | 220 | Slam, 0.9 s tell, 28, armoured. Unchanged. | **EMP** breaks its guard and opens it for 1.3 s; a hijacked turret thins it |

Tags are what the hacks read: `drone`, `turret` and (later) `robot` get the stuns and the Zap bonus. Cops get none on purpose, so EMP shoves a pack but only stuns machines. The cop and the heavy keep every old number, so the sandbox and its 1,400 tests are unaffected.

## The fights

| Room | Fight | Mix | Hack that shines |
|---|---|---|---|
| J1 | The Pound | 2 cops, only one attacks at a time, 20 percent less health | Zap the fuse box afterwards |
| J2 bay 1 | The Chute | 1 slow turret | Zap, EMP or Overclock; or just side-step |
| J2 bay 2 | The Pit Stop | 3 cops, then a Brute that raises its guard often, plus a ledge turret | Overclock the turret onto the Brute; EMP the guard |
| J3 | The Crane Yard | 2 cops, then a cop and a Brute, with the drone line adding a drone every 6 s | EMP clears two drones and a pack; Zap the node |
| J4 | The Stand (sticky) | 3 cops, then a Brute, then a Brute and 2 drones; 2 turrets wake after the first wave | Overclock a turret; EMP drones and guard together |
| J5 (loader) | Lane, Graveyard, Canyon, Wall | ants: 21 cops, 10 drones, 5 turrets in all, half health | none (hacks are off), pure power fantasy |

**Forgiving, on purpose:** new waves wait for the last to thin out (or a timer), with a 2.5 s breather and a 0.9 s warning; arrivals take 0.4 s longer to notice; spawns are never in Red's back arc or closer than 10 m; at most two attack at once (one in J1); the sword always fills the battery before the hack lesson arrives (first-wave cops give about 70 to 100 battery against costs of 20, 40 and 50); in the loader, enemy hits are scaled to 55 percent and cops have half health so a swing kills one.

## For the builders

`encounters.json` gives who, how many, where (room metres, as in docs/maps/junkyard.md), when (wave triggers) and per-spawn tuning (`tune`, `hp_mult`). Turrets and the drone line are `fixtures`; the Level Designer owns their placement nodes and checks the points against walls. The drone and turret entries carry throwaway guard and defend numbers only so the shared enemy data test passes. The drone's `flying` block and the turret's `mount` block are placeholders for the Combat Programmer's `signals_drone.gd` and `wall_turret.gd`. A hijacked turret fires `burst_ally` (a shorter wind-up, same three bolts, about every 1.5 s). Recommendation recorded in the data: the J4 loader wakes by pressing the button, not by Overclock.
