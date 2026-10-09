# Tuning log (Combat Sandbox)

> **For Ross:** every number change the Combat Designer makes after the first build, newest first, one line of why each. All of it is data (`game/data/...`) and all of it can be re-tuned in the F12 panel. No button does anything different.

## Tuning v1: Kingdom Hearts direction (Ross, 2026-10-09)

Ross: "keep the system more kingdom heartsy opposed to DmC Sekiro" and "parry may be omitted if its not working". So the target is forgiving, floaty, flashy and easy to pick up, not frame-strict. This **overrides the playtester's tightening** (docs/playtests/sandbox_feel_pass.md); what I took from the playtest and what I did not is listed at the bottom.

### Air and launches: floaty and generous (unchanged)
| Setting | Was | Now | Why |
|---|---|---|---|
| `juggle_float` | 1.0 | **1.0** (kept; playtester suggested 0.5) | Long floaty juggles are the Kingdom Hearts air game. |
| `launch_height_scale` | 1.0 | **1.0** (kept; playtester suggested 0.7) | Same. Trim later only if launches truly leave the screen. |
| Red `air_1` / `air_2` `hang_ms` | 300 | **300** (kept; playtester suggested 150) | Hang time is what lets the air string flow. |

### Defence: a generous guard, not a deflect
| Setting | Was | Now | Why |
|---|---|---|---|
| Parry window, Nice / Rad / Totally Rad (`timing_windows.json` `parry`) | 220 / 130 / 70 ms early | **320 / 200 / 110 ms** | A press shortly before the hit now guards it; good timing still rates higher. |
| Parry `listen_before_ms` | 400 | **340** | Just past the Nice window, so a very early press is ignored instead of "using up" the real press. |
| Red `parry` `recovery_ms` | 280 | **150** (total move 350 ms) | A missed guard costs little; the playtester asked for this and it fits. |
| Guard damage taken (`parry.block_reduction`) | 25% less on a Nice guard (shared table) | **60% less Nice, 100% on Rad and up** (new entry, see note) | A KH guard soaks most of a hit. **Needs code**: `HitResolver` reads the shared table today and ignores this new entry. |
| Perfect dodge window (`perfect_dodge_window_ms`) | 120 | **120** (kept; playtester suggested 70) | Generous dodges feel good and trigger the flare often. |
| Dash i-frames (`dash_iframes_ms`) | 150 | **180** (the whole 180 ms dash) | Dashing through danger is always safe. |
| Parry "omitted if not working" | | | The timing-stamp bug is fixed in code by the Gameplay Programmer. If the parry still feels bad, the guard and the dash i-frames carry the defence. |

### Targeting: swings snap to the target
| Setting | Was | Now | Why |
|---|---|---|---|
| Red attack `magnet` (ground moves) | 3.5 m, 70 degree cone | **5.5 m, 120 degrees** | Swings turn toward the nearest enemy even if the stick is a bit off. |
| Red attack `magnet` (air moves) | 3.5 m, 70 degrees | **6.0 m, 140 degrees** | Air strings keep finding the target. |

### Enemies: less punishing, less evasive
| Setting | Was | Now | Why |
|---|---|---|---|
| Grunt `dodge_chance` / `block_chance` | 0.30 / 0.08 | **0.15 / 0.04** | About half as often. |
| Brute `block_chance` | 0.45 | **0.22** | About half. The guard break (Heavy, Launcher, or an empty meter) is unchanged. |
| Grunt combo escape | 50% | **25%** | Fewer slippery exits from a string. |
| Grunt dodge counter | 25% | **15%** | |
| Grunt retaliate after a flinch / Brute after armored hit | 15% / 35% | **10% / 20%** | Less hitting back. |
| Brute counter after a block | 45% | **25%** | |
| `enemy_windup_scale` (slider) | 1.0 | **1.25** | Wind-ups a bit slower: Grunt swipe 700 ms, Brute slam 1125 ms. The 500 ms floor still holds. |
| `enemy_damage_scale` (slider) | 1.0 | **0.7** | Enemies hit softer: Grunt swipe 7, Brute slam about 20. |
| `enemy_aggression` (slider) | 1.0 | **0.85** | A little more breathing room between attacks. Still 2 attackers at once. |
| Grunt low-health threshold | 40% hp | **30%** | Flee and flank show up later in the fight. |
| Grunt flee chance, alone / in a pack | 70% / 30% | **50% / 20%** | Flees less. |
| Grunt flees per life | 2 | **1** | |
| Flank hold in position | 600 ms | **800 ms** | A longer, more readable warning. |
| Enemy blocking slider `enemy_block_scale` | 1.0 | **1.0** (kept; playtester suggested 1.5) | Opposite direction to the new brief. |

### Heavy and the string
| Setting | Was | Now | Why |
|---|---|---|---|
| Red `heavy` damage | 22 | **32** | The Light string is about 35 damage per second, Heavy was 33. Heavy is now about 48 per second (roughly 40% more), so it is worth the slower start. |

### Other
| Setting | Was | Now | Why |
|---|---|---|---|
| Grunt `dodge` `tell` | 0 to 40 ms | **0 to 100 ms** | The cyan blink was two frames long. Note: it now overlaps the start of the roll; a true warning before the roll would be a code change (start the blink during the reaction delay). |
| `player_action.json` `anim.playback_scale_max` | 2.0 | **2.4** | Kept from the playtester: stops the sprint foot-slide (stride needs 2.38x at full speed). |

### What I took from the playtest, and what I did not
- Taken: parry recovery 150, dodge tell 100, playback_scale_max 2.4, Heavy stronger.
- Not taken (against the Kingdom Hearts brief): `juggle_float` 0.5, `launch_height_scale` 0.7, air `hang_ms` 150, perfect dodge 70 ms, `enemy_block_scale` 1.5.
- Not yet touched: the dash exit snap (`end_speed_mult`), Brute HP 300. Both wait for Ross to play it.

### Tests that pinned old numbers, and what I changed
- `unit/test_enemy_defence.gd`, `unit/test_enemy_brain_behaviour.gd`: they check the **design table** (30% dodge, flee at 40%, and so on). They now carry their own copy of that table (`DESIGN`) instead of reading the shipped, tuned `enemies.json`, so they keep proving the mechanics whatever the tuning is.
- `unit/test_combat_director.gd`, `unit/test_hit_resolver.gd`, `unit/test_action_enemy.gd`, `unit/test_action_enemy_ai.gd`: they count raw damage and wind-up lengths, so each now sets `enemy_damage_scale` and `enemy_windup_scale` to 1.0 on its own knobs. The director parry tests now press in the middle of each rating band, read from `timing_windows.json`.
- `integration/test_action_player.gd` (run clip speed): expects the clamp from `player_action.json` instead of a hard-coded 2.0; full speed is `min(clamp, speed / stride)`.
- `sim/test_enemy_ai_bots.gd`: the Grunt-dodge and Brute-guard bots pin the design chance (0.30 and 0.45) on the brain, because with the tuned chance a 12-swing run depends on luck.
- Observation for the Combat Programmer: the bots show the real dodge rate is far below the table (about 1 dodge in 12 Heavies at a 60% roll), so something besides the roll gates a defence (which brain states count as "can defend"). Worth a look; it is part of why the playtester saw the Brute block so rarely.

## Defence gate, answered (Combat Programmer, 2026-10-09)

Question: the bots saw about 1 dodge in 12 Heavies at a 60% roll. Is something besides the roll gating defences, and is it a bug?

**Answer: not a bug. The roll is fine; the gates are the design, and the first bot made them look worse.** With the gates open (swings 7 s apart, grunt kept alive) a probe saw 11 dodges in 18 Heavies at a 0.6 roll. What sits between "dodge_chance" and an actual dodge, all of it in `enemy_ai_design.md` 2.1:
1. `read_weight` of Red's move (Grunt: Light 0.6, Heavy 1.0, Launcher 0.8, Air 0.4), so the Grunt's real dodge chance on a Light is 0.15 x 0.6 = 9%.
2. Fatigue: each defence adds 0.4 (Grunt) that fades over 4 s.
3. The cooldown starts when a defence ENDS: a dodge lasts about 0.6 s, then 2.5 s of cooldown, so the next free roll is about 3.1 s after the swing that triggered it. The old bot swung every 2.9 s, which landed inside the cooldown after every dodge, so every dodge guaranteed a hit on the next swing.
4. The brain can only defend while it is circling, approaching, repositioning or flanking: never in hit-stun, react (a hit plus 250 ms), mid-attack, or in a flare. A tight Light string locks an enemy in on purpose ("Light = safe pressure"); the way out is `combo_escape` (Grunt 25% after 3 hits).
5. The roll comes once per Red swing, 80 to 150 ms after it starts (Brute 160 to 260), and only for an enemy inside the swing's zone and `threat_range_m`. A first Light (90 ms) always lands.
6. Bot artefact: the Heavy kills a 48 hp Grunt in two hits, and a Grunt that respawns is in "react" for its first quarter second, where it cannot defend at all; the bot swung the moment it was free. `test_a_grunt_dodges_some_heavies_but_not_all` now keeps the grunt alive and swings every 3.4 s: 6 dodges in 12 Heavies at the 0.6 roll.

What it means for tuning: the real dodge and block rates in play are well below the table, mostly because of 4 and 1. If Ross wants enemies that defend more, the cheapest knobs are `read_weight` for Light (0.6 for the Grunt, in `enemies.json`) and the `enemy_dodge_scale` / `enemy_block_scale` sliders; the cooldowns only matter against slow, spaced swings.

Also seen while building the combo (data for the Combat Designer, nothing changed): a Light 1 thrown at an enemy 2.5 to 4.5 m away whiffs (it moves 0.6 m and reaches about 2 m), because "far" starts at 4.5 m (`far_dist_m`); and a lunge from beyond about 6.5 m closes the gap but cannot connect (5 m of travel); and `near_radius_m` 3.0 is smaller than a Grunt's circling distance (2.2 to 4.5 m), so a crowd of three rarely counts as crowded unless they are on top of her.

## Tuning v1.3 (Ross: chunky hits) (Technical Artist, 2026-10-09)

Ross: "hits need to feel better, there needs to be a 0.25/sec freeze and the enemy player model turns completely opaque white for a split second at the moment of impact, making strikes feel chunky and heavy and fun add a sound effect too - may need to playtest this to see what feels good, may only need a 0,1/sec freeze depending on what is perceptable".

**What Ross tunes: F12, first tab "Hit feel".** `Hit freeze length` (0.05 to 0.30 s, default 0.25) is how long the heaviest hits freeze; every other hit scales with it (light hits freeze 40 percent of it, about 0.10 s at the default). `White impact flash` (on) and `Flash Red when she is hit` (off) are the two switches.

### Hit-stop (ms, at the default knob; moves.json and hacks.json). The knob multiplies all of these by knob / 0.25.
| Move | Was | Now | Why |
|---|---|---|---|
| Red `light_1`, `light_2`, `lunge` | 50 | **100** | Ross's "about 0.1": the light hits must register. |
| Red `air_1`, `air_2` | 45 | **90** | Air strings stay quick but show the freeze. |
| Red `light_3` | 80 | **150** | The string's third hit is a medium punctuation. |
| Red `heavy`, `launcher`, `sweep`, `air_3` | 90, 80, 70, 70 | **250** | Heavies, launchers and finishers: Ross's 0.25. |
| Guard break (any hit that breaks a raised guard) | 25 to 55 | **250** (new `hit_freeze.guard_break_hit_stop_ms` in hit_feel.json) | A broken guard is a heavy moment whatever broke it. |
| Parry / perfect parry (`hit_feel.parry`) | 90 / 140 | **120 / 200** | Same chunk on a good block. |
| Grunt `swipe`, `swipe_flank` (hits Red) | 60 | **90** | Red feels it too, a little less than she dishes out. |
| Brute `slam`, Hushmaster `leg_stomp` | 110, 90 | **200** | Big enemy hits freeze hard. |
| Hushmaster `dish_sweep` | 80 | **160** | |
| Signals Drone `dive`, `shock`; Wall turret bursts | 50, 40, 40 | **70, 60, 60** | Small chip hits get a short freeze. |
| Hack: EMP pulse | 60 | **150** | A big, heavy hack. |
| Hack: Zap Drone | 30 | **30** (kept) | A rapid piercing shot; a longer freeze made the boss bot test take about 25 percent longer. |
| Junk mech (Heap) attacks | 100 to 180 | kept | The Combat Programmer's numbers are already heavy. |

The older Combat-tab `Hit-stop length` knob is kept as an extra multiplier on top (leave it at 1).

### The flash and the sound (data/combat/fx.json, not combat numbers)
`hit_flash`: on, 0.07 s of real time (so it shows inside the freeze), pure white; blocked and guarded hits do not flash, armoured hits flash dimmer and shorter, a hit that took nothing off (a sealed core, a clink) does not flash. `hit_sound`: every landed hit plays its sound with a little pitch variation (+-8 percent light, +-4 percent heavy and launch). The two hit sounds were regenerated punchier, same ids.

## Tuning v1.1: combo distances (Combat Designer, 2026-10-09)

Data only; no mechanic changed.

| Setting | Was | Now | Why |
|---|---|---|---|
| `combo.json` `far_dist_m` and the `lunge_far` rule's near edge | 4.5 m | **2.0 m** | Light 1 reaches about 2 m. At 2.5 to 4.5 m it whiffed; now a lunge covers that gap. |
| `lunge_max_dist_m` and the `lunge_far` rule's far edge | 12 m | **8 m** | Past about 6.5 m the lunge could not connect. |
| `lunge` travel | 5.0 m over 200 ms | **7.0 m over 260 ms** | So the lunge actually reaches 8 m (it stops 0.9 m short of the target). |
| `lunge` timing | startup 150, active 90, recovery 240 | **150 / 150 / 220** (thrust live 160 to 300 ms, magnet 8.5 m) | The thrust has to still be live when Red arrives from far away. Total 520 ms. |
| `near_radius_m` | 3.0 m | **5.0 m** | A Grunt circles at 2.2 to 4.5 m, so three wolves nearby now count as a crowd and the sweep can trigger. |

Tests that pinned the old distances: `unit/test_combo_selector.gd` (default target 1.5 m, and the lunge band is now read from `combo.json`), `sim/test_combo_bots.gd` (grunt staged at 1.6 m, Brute at 1.8 m, so Light 1 is the opener) and `integration/test_action_player.gd` (close target at 1.6 m). From 2 m and out a press now lunges by design.

## Tuning v1.2: faster, farther dash (Ross, build 2: "wish the dash was a little faster / farther")

Data only. Ross likes the build; this is the one thing he asked to be bigger.

| Setting | Was | Now | Why |
|---|---|---|---|
| `dash_distance_m` | 4.0 m | **5.25 m** (+31%) | Farther, as asked. |
| `dash_time_ms` | 180 ms | **150 ms** | Snappier. Average speed goes from 22 to 35 m/s, and the burst at the start (the curve is front-loaded) from about 29 to 45 m/s. |
| `dash_iframes_ms` | 180 | **150** | Still the whole dash: invulnerable from the first instant to the last. |
| Air dash (`air_distance_mult` 0.85, unchanged) | 3.4 m | **4.5 m** | The same 0.85 share of the new distance, in the same 150 ms, so air and ground feel alike. |
| `dash.cooldown_ms` | 220 | **180** | Recovery stays short; you can dash again as soon as the last one lands. |
| `attack_cancel_ms` / `jump_cancel_ms` / `dash_cancel_ms` | 110 / 70 / 220 | **90 / 60 / 180** | Scaled with the shorter dash, so the same share of it is committed before you can cut into an attack, jump or another dash. |
| `dash.end_speed_mult` (new key, in the dash block) | 0.6 (code default) | **1.0** | At 45 m/s the old drop to 3.6 m/s at the end would be a hard snap; now Red leaves the dash at run speed. Playtester suggested the same. |

Feel knobs and the `knob_defaults` fallback in `player_action.json` both carry the new numbers; the robot forms keep their own dash numbers (`scale_profiles.json` untouched).

Test that pinned the old value: `integration/test_feel_panel.gd::test_save_writes_a_readable_file_and_shows_where` expected the saved dash distance to be 4.5 (the old 4.0 plus two steps). It now computes two steps up from the shipped value.
