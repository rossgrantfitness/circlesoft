# Battle simulator report (first tuning pass)

> Battle Programmer, Milestone 2 (M2-9). The simulator plays the real battle model (the same `BattleController` the game uses) on a virtual clock with no view, as four kinds of player, thousands of times. Numbers below are the full **5,000 fights per encounter and player** (seed 1; fight *i* uses seed 1+*i*, so any row can be replayed). The suite itself runs 200 per check.

## How to run it
```
godot --headless --path game -s res://tests/sim/run_sim.gd -- --encounter=squad_four --player=good --runs=1000 --seed=1
godot --headless --path game -s res://tests/sim/run_sim.gd -- --runs=200 --check --walkthrough
```
Options: `--encounter=ID|all`, `--player=perfect|good|miss|auto|all`, `--runs=N`, `--seed=N`, `--level=N` (default: each encounter's `suggested_level`), `--walkthrough`, `--check` (exit code 1 when anything misses `feel_targets.json`), `--markdown`. The full 5,000-run table takes about 10 minutes; 200 runs about 20 seconds.

## The players
| Player | What it does |
|---|---|
| **perfect** | Presses exactly on every cue (attack and block, taps, holds, strings). |
| **good** | Presses with a normal spread of 40 ms around each cue, and skips 8% of presses (a lapse of attention). |
| **miss** | Never presses. Normal hit, normal hurt. |
| **auto** | Auto-Timing: every press lands as Rad. |

All four use the same command policy (from the tech plan): attack the weakest enemy, heal anyone under 40% HP (Can of Chili if 60+ HP is missing, else Ration Bar, else a heal skill), revive a Down friend with Smelling Salts, and use the signature move whenever Juice allows. Start kit: 4 Ration Bars, 1 Can of Chili, 2 Canned Coffee, 1 Smelling Salts, 1 Burn Gel. **Fight time = virtual-clock timeline ms + 2 s of menu time per party command.**

## Results (5,000 runs each)
| Encounter | Level | Player | Win rate | Mean s | p10 s | p50 s | p90 s | Rounds | HP left (wins) | XP | Credits |
|---|---|---|---|---|---|---|---|---|---|---|---|
| grunt_solo | 1 | perfect | 100.0% | 34 | 34 | 34 | 34 | 3.0 | 100% | 14 | 21 |
| grunt_solo | 1 | good | 100.0% | 37 | 34 | 34 | 45 | 3.3 | 99% | 14 | 21 |
| grunt_solo | 1 | auto | 100.0% | 47 | 45 | 46 | 57 | 4.1 | 92% | 14 | 21 |
| grunt_solo | 1 | miss | 100.0% | 59 | 55 | 55 | 66 | 5.3 | 79% | 14 | 21 |
| grunt_pair | 2 | perfect | 100.0% | 48 | 44 | 48 | 50 | 4.0 | 100% | 28 | 42 |
| grunt_pair | 2 | good | 100.0% | 57 | 48 | 60 | 63 | 4.7 | 98% | 28 | 42 |
| grunt_pair | 2 | auto | 100.0% | 79 | 73 | 74 | 88 | 6.4 | 84% | 28 | 42 |
| grunt_pair | 2 | miss | 100.0% | 112 | 106 | 108 | 119 | 9.4 | 70% | 28 | 42 |
| drone_flock | 3 | perfect | 100.0% | 66 | 64 | 66 | 67 | 5.0 | 100% | 50 | 76 |
| drone_flock | 3 | good | 100.0% | 77 | 65 | 77 | 89 | 6.0 | 96% | 50 | 76 |
| drone_flock | 3 | auto | 100.0% | 117 | 102 | 115 | 132 | 9.1 | 74% | 50 | 76 |
| drone_flock | 3 | miss | 94.0% | 178 | 168 | 175 | 190 | 14.9 | 42% | 50 | 76 |
| squad_four | 4 | perfect | 100.0% | 74 | 69 | 74 | 78 | 5.1 | 100% | 66 | 98 |
| squad_four | 4 | good | 100.0% | 87 | 74 | 86 | 103 | 6.1 | 96% | 66 | 98 |
| squad_four | 4 | auto | 100.0% | 146 | 130 | 145 | 159 | 10.2 | 75% | 66 | 98 |
| squad_four | 4 | miss | 54.1% | 216 | 176 | 227 | 240 | 17.4 | 24% | 66 | 98 |
| ambush_no_exit | 4 | perfect | 100.0% | 92 | 87 | 93 | 95 | 6.9 | 100% | 68 | 98 |
| ambush_no_exit | 4 | good | 100.0% | 112 | 95 | 110 | 130 | 8.4 | 94% | 68 | 98 |
| ambush_no_exit | 4 | auto | 100.0% | 190 | 161 | 188 | 218 | 14.3 | 72% | 68 | 98 |
| ambush_no_exit | 4 | miss | 0.0% | 93 | 71 | 94 | 112 | 7.3 | 0% | 0 | 0 |

(The miss row of the last fight shows how long the party lasts before game over.) Encounters: `grunt_solo` 1 Signals Grunt; `grunt_pair` 2 grunts; `drone_flock` 2 Signals Drones + Whistle Blower; `squad_four` 2 grunts + Signals Drone + Buzzkill (4 enemies, enemy HP x1.2); `ambush_no_exit` 2 Whistle Blowers + Buzzkill, enemy HP x1.3 and attack x1.5, **can't run**.

### Walkthrough (the 14 slice fights in order, party healed and bag restocked between fights, 100 runs each)
| Player | Finished | Final level | Credits from battles | Fights fought (mean) |
|---|---|---|---|---|
| perfect | 100% | 6.0 | 1,017 | 14.0 |
| good | 100% | 6.0 | 1,017 | 14.0 |
| auto | 100% | 6.0 | 1,017 | 14.0 |
| miss | 0% | n/a | n/a | 8.2 (loses around the first Full Signals Squad, fight 7 to 9) |

## Against the feel targets (`data/battle/feel_targets.json`)
`--check` passes: **every row is inside its bands.**
- **Fight length.** Regular fights 60 to 180 s: good play lands 77 to 87 s, Auto-Timing 117 to 146 s, perfect 66 to 74 s. Tutorial fights (25 to 90 s): 34 to 79 s. The tough ambush (90 to 240 s): 92 s perfect, 112 s good, 190 s Auto-Timing. Never-pressing runs longer (up to about 3.5 min on the squad fight), which is allowed.
- **Win rates.** Perfect 100% everywhere (needs 97%+ regular, 90%+ tough). Good 100% (needs 85%+, 80%+). Auto-Timing 100% (needs 70%+, 50%+). The miss player wins the easy fights (100%; needs 80%+), wins 94% of the drone flock and 54% of the squad fight (needs 30%+ for regular fights) and cannot beat the ambush (needs 60% or less).
- **Perfect play feels strong.** Against never pressing, perfect play finishes fights 1.7x to 2.9x faster and finishes with far more HP; the check wants at least 10% on wins or time.
- **Slice progress.** The 14-fight walkthrough ends at level 6 (the target at Kasp) with about 1,017 credits from battles; the rest of the 1,500 is crates and side jobs (Economy section).

## What I tuned, and why
1. **Enemy HP.** The first draft killed a Signals Squad in 2 rounds (25 s). Enemy HP is now about 2.4x the first draft (grunt 46 -> 112): a basic hit is roughly a tenth of a grunt, so fights need several rounds.
2. **Rating bonus** x1.5 -> x1.4 for TOTALLY RAD (Nice x1.1, Rad x1.25) and **Juice refund** halved (Rad +1, TOTALLY RAD +2). With the draft values a good player cast their signature every turn.
3. **Enemy damage** up about 40% since the first draft (grunt attack 9 -> 13) so never-pressing is a real handicap; the ambush gets a per-encounter `enemy_scale` (HP x1.3, attack x1.5) instead of new enemy types.
4. **XP and credits.** XP curve 0 / 35 / 90 / 190 / 350 / 560 puts level 6 at fight 13 of 14; enemy credits cut about 30% so battles pay about 1,000 of the 1,500.
5. The **good** player got an 8% lapse chance: with a pure 40 ms spread nobody ever lost a fight.

## Things to know, and open questions (none block the build)
- **Skilled players take almost no damage** (94 to 99% HP left). A Perfect Block takes it all by design, so fights are won on length, not danger. If Ross wants good play to feel riskier, the knobs are `block_reduction` in timing_windows.json and enemy `attack` in enemies.json; a "casual" player (70 to 80 ms spread) would be the next simulator player to add.
- **The never-pressing player can't finish the slice** with this simple policy (it dies around fight 8 with no Defend and no shopping). Real players who skip Clutch will do better (Defend halves damage and widens windows), but if the slice should be finishable without pressing, soften enemy `attack` by about 15% or add a heal item to the start kit.
- **The XP curve and enemy lists are test content.** Real placements come with Milestone 3 (the walkthrough order lives in feel_targets.json and is easy to change). Kasp needs his own tier ("boss": 300 to 480 s is already in the targets) and the cue-scramble pulse; the model already supports a scrambled cue (`shown_cue_ms`) and boss flags.
- Fight time counts 2 s of menu per command as agreed; the HUD's real menu time will move these numbers (about +-20%).
