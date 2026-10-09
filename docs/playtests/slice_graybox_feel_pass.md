# Slice graybox feel pass (VS-34)

> Playtester, 2026-10-09. A report, not fixes. Judged from data, map budgets and headless bot/sim runs, not from hands: Ross's play is still the real test. Saved to the repo by the studio lead (the Playtester role can't write report files).

## Headlines
- **Time to the boss kill:** about 31 min focused (no deaths, no side jobs); about 36 to 38 min for a typical first-timer (one retry, some roaming); about 42 to 45 min doing every side job and secret. All inside the 30 to 45 target. Confidence low to medium: the full-slice bot run stopped at the J2 Pit Stop, so there is no measured end-to-end time.
- **Biggest risks:** a plain launch boots the old classic game; the Pit Stop may be unclearable; several readability cues are not on screen; the Stand (J4) is a difficulty spike with thin healing.

**Proposed decision for Ross: how big should the colossus feel?**
- A: keep 22 m/s run and 520 ms dash (the boss doc's "fast and sharp"). Matches the designer's contrast with the Heap, but it is 2.4x the loader's speed and 2.2x Red's dash speed, so it reads nimble rather than huge.
- B: 16 m/s run and 800 ms dash (`scale_profiles.json`, huge knobs). Still faster than the Heap (12 m/s), so the contrast survives, and it reads heavier.
- Recommendation: B, then judge by feel. Two numbers in one file.

## 1. Time per section
Method: map time budgets (night_market.md, junkyard.md, kasp_arena.md), boss data (hushmaster.json expected 240 s, transition 40 s, junk_mech.json 200 s), the Hushmaster bot (perfect play 121 s, zero damage) and a Heap sim running the real attack schedule with Red landing hits on open parts 100%, 60% or 35% of the time.

| Section | Time |
|---|---|
| Hideout wake and save | 1:00 |
| Square to Dispatch, Yard 9 job | 0:45 |
| Gate 4 pass and walk | 1:00 (town total about 2:45 focused, 3 to 5 typical) |
| J1 Yard Gate | 2:30 |
| J2 Scrap Canyon | 4:00 |
| J3 Crane Yard (crane puzzle) | 5:00 |
| J4 Wreck Row (Stand, loader wake, boarding) | 3:40 |
| J5 Smash Run | 3:30 (about 31 s of straight running; the rest is smashing) |
| Arena intro (skippable) | 1:00 |
| Phase 1, Hushmaster | 4:00 typical (2:00 perfect-play floor) |
| Transition | 0:40 |
| Phase 2, Heap | 3:20 typical (1:38 to 3:37 by sim) |
| **Total** | focused about 30.5 min; typical about 37; explorer about 44 (map docs say 33 to 40) |

## 2. Pacing
- **Town:** no dead time on the main path. Missing: the wake scene never plays (section 7), and the promised hush beat (the Signals patrol that ducks everyone) is not built (VS-43).
- **J1:** short, clean first fight; good teaching order (lock-on, then Zap).
- **J2:** the Chute is 40 m of corridor past one turret that does nothing if you run past it, a fair breather. The Pit Stop is the first real spike (first Brute, 38% guard).
- **J3:** the crane puzzle has the most dead time. Overclock lasts 10 s, the carry takes 8 s: 2 s of slack, and each retry costs 50 battery.
- **J4:** the vestibule walk sells the giant parts. The Stand is the spike (section 5).
- **J5:** 3.5 minutes mowing 64 cars with no decisions: the longest stretch without choices. Cheapest cut in the slice if it feels long.
- **Phase 1:** standing off removes the jump lesson and turns into Dish Sweep spam (section 3). Quiet Hours is the spike.
- **Transition:** good, skippable, Red can't be hurt.
- **Phase 2:** the plate phase is most of the time; the core phase is about 50 s at a typical hit rate. The Heap never repeated a pattern in 10 to 24 attacks.

## 3. Combat readability
**Works:** the telegraph language is clear (leg lift and floor circle; red fan line then beam; Heap lamps orange then red with 12 m decals). Hack teaching order is good (Zap after J1, Overclock on the J2 turret, EMP at the drone line). The Hushmaster opens with a fixed stomp, sweep, stomp, so every player meets the jump and the dash.

**Problems:**
- **Standoff:** zapping relays from 11 m means Leg Stomp (8 m reach) never fires again after the opening. Of 22 patterns, 11 were Dish Sweep, five in a row.
- **Quiet Hours:** the 1.4 s warning is only a sound, a dish animation and a bark. Nothing on the HUD shows the warning; the fizz shows only once hacks are already locked.
- **Jack in:** after the topple, the "Jack in" prompt is set in code but nothing draws it. Players will likely never see the designed big hit.
- **Hushmaster body bar:** barely moves in phase 1 and looks stuck; the leg pips are the real progress and nothing says so.
- **Heap:** the camera never cuts to the first open plate; a first-timer may swing at the wrong part.
- **Bot gap:** no bot run exercises EMP on drones or Overclock on pylons in the boss.

## 4. The scale climb (from scale_profiles.json; default vertical field of view)
- **Screen height:** Red 17.6%, loader 21.7% (1.2x Red), colossus 62.7% (2.9x the loader). On screen the loader barely looks bigger than Red; loader to colossus is strong.
- **Camera distance in body heights:** Red 4.7, loader 4.0, colossus 1.5. The loader is framed like a bigger Red, not a giant.
- **Speed:** run Red 6, loader 9, colossus 22 m/s. Dash average Red 35, loader 31 (slower than Red), colossus 77 m/s.
- **Props:** J5 cars 1.4 m (0.4x the loader), scrap walls 3 m (the loader is barely taller than the walls it smashes), container stacks 7.9 m, gate 12 m. The environment doesn't sell "giant" until the gate.
- **Mass cues that work:** audio pitch 0.75 / 0.4 with low-pass, fog 300 m / 1,500 m, shake 1.5x / 5x, stronger hit freeze.
- **Verdict:** the loader feels bigger than Red through motion, sound and the ant-sized cops, not screen size. The colossus clearly feels bigger than the loader; its 22 m/s is the one number that undercuts it.

## 5. Difficulty
- J1 The Pound: easy (right for a first fight). J2 Chute: easy.
- J2 Pit Stop: medium, unknown: the full bot run could not clear it (risk 2).
- J3 Crane Yard: medium to hard.
- **J4 The Stand: too hard, a spike.** Two Brutes, three cops, two turrets and drones; wave 3 starts 45 s after wave 2 whether or not the Brute is dead. No healing in the arena; the only nearby pickup is a Juice Box, which restores the old battle gauge and does nothing for Red's health. Healing is in the pause menu's Items page (Ration Bar, Can of Chili), which first-timers may not find.
- J5 Smash Run: too easy and long (a power fantasy that needs trimming).
- Hushmaster: medium at the opening; easy in the middle for anyone who stands off.
- Heap: fair if you read the decals. The 16 repair cells (11,520 hp, 1.9x the colossus's health) make it too forgiving for a player who uses them.

## 6. Top 5 tuning changes (numbers only)
1. `game/data/combat/bosses/hushmaster.json`, leg_stomp `when.dist_max_m`: 8.0 → 12.0 (keeps the jump lesson in play).
2. `game/data/combat/bosses/junk_mech.json`, `pickups.repair_cell.per_cluster`: 2 → 1 (16 cells → 8).
3. `game/data/combat/scale_profiles.json`, `forms.huge.knobs`: `run_speed_mps` 22 → 16, `dash_time_ms` 520 → 800 (the decision above).
4. `scale_profiles.json`, `forms.small`: `camera.distance_m` 14 → 12; `knobs.dash_time_ms` 260 → 380.
5. `game/data/slice/encounters.json`, `enc_j4_stand` wave w3 `start.or_after_s`: 45 → 90.

Next tier: trim J5 cars (`robot_rooms/junk_j5.json`, 64 cars); J5 scrap walls taller than the loader (`robot_yard.json`, `scrap_wall_3m`); colossus `hit_stop_mult` 2.0 → 1.5.

## 7. What a first-time player will find confusing
- A plain launch boots the shelved classic game (`data/slice/slice.json` `default_mode` is "classic" until VS-35 flips it).
- Vela's wake-up greeting never plays (`hideout_wake` has no trigger).
- No on-screen warning before Quiet Hours; no "Jack in" prompt; the Hushmaster body bar looks stuck.
- Healing is hidden in the pause menu; the Stand's Juice Box is a dead pickup.
- Town lines are placeholders, so "cute" can't be judged yet; the market's quiet beat isn't built.
- "The colossus" (Red's ride) and "the Heap" (Kasp's mech) are easy to mix up in the boss doc.

## Biggest risks
1. Wrong game on a plain launch.
2. The full-slice bot run stops at the J2 Pit Stop (hit the frame limit with one cop standing and a Brute that kept reappearing at full health): bot reach problem or a real stuck/respawn bug, unconfirmed.
3. Cues not on screen: Quiet Hours warning, Jack in, Vela's greeting, the town hush.
4. The Stand and loader stretch has the thinnest healing.
5. Colossus numbers unverified by hands.
6. The loader doesn't look much bigger than Red on screen; J5 props don't sell the size.

Test runs (existing suites, all pass): boss bots 1/1, Hushmaster 46/46, Heap 35/35, smash run 11/11, robot bot 1/1, hack bots 8/8, enemy AI bots 5/5, combo bots 8/8, room fights 10/10.
