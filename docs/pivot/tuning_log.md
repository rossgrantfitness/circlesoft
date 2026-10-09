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
