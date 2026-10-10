# Combat sandbox bug log (CS-18 pre-delivery QA)

> Logged by QA Tester, 2026-10-09. Scope: the COMBAT SANDBOX build (`-- --sandbox`) and its exports. Severity: crash / major / minor / polish.
> Nothing here is fixed. Owners fix; QA re-checks. QA made no game-file edits (one data change was tried and reverted, see BUG-01).

## Run summary

- Suite: `godot --headless --path game -s res://tests/run_all.gd` → **2246 passed, 0 failed**, exit 0.
- Playthrough (`game/tests/visual/qa_sandbox_playthrough.gd`, real renderer under xvfb, OpenGL 3, injected keyboard and mouse): three full runs (plus one early exit from a pause-menu cursor bug in the QA script, since fixed). Boot 3.1 s. Each 185 s fight had 23 to 32 deaths and 13 to 21 respawns. Pause > Reset arena, Resume, F12 feel panel save, and Esc > Quit all pass. Remaining failures are BUG-01 and BUG-02.
- Frame time (container limit): average 66 ms (about 15 fps), worst 550 to 580 ms, on software OpenGL (llvmpipe, 4 vCPU, no GPU). This says nothing about the game on a real GPU. A GPU run is still needed.
- Exports: `Sandbox Windows` → `builds/sandbox/LightsOnSandbox.exe` (189.6 MB); `Sandbox Mac` → `builds/sandbox/LightsOnSandbox-mac.zip` (154.5 MB). Both exit 0, no export errors.

## Bugs

### BUG-01 · major · Back ramp blocks Red at its foot; the back ledge can't be reached

- **Steps:** Boot with `-- --sandbox`. Walk Red forward (away from the camera) to about (-9, 0, -10). Keep pushing forward.
- **Expected:** A walkable ramp from the arena floor up onto the 1.2 m back ledge.
- **Actual:** Red stops at the ramp's near face (z ≈ -10.7 in runs 1 and 3). The ramp is tilted the wrong way. Its high end sits on the floor side, and its low end is sunk into the ledge. Repro: `qa_sandbox_playthrough.gd` (waypoints) and `qa_sandbox_ramp_walk.gd` (fails "ramp top"). Evidence: `docs/screenshots/qa_sandbox_ramp_floor.png`, `qa_sandbox_ramp_behind.png`.
- **Tried:** flipping `rot_deg` x from -11.5 to +11.5 moves the high end onto the ledge, but Red still stops at a ~15 cm front lip at the foot, and the top meets the ledge face ~25 cm below its top. Needs a retune of `y`, `size` and `rot_deg` together. **Reverted**, file untouched.
- **File:** `game/data/combat/sandbox.json` (`arena.ramps[0]`). Built in `game/scripts/sandbox/combat_sandbox.gd` (`_build_arena`, `_add_box`).
- **Owner:** Gameplay Programmer.

### BUG-02 · minor (needs a design call) · Both ledges can't be walked onto

- **Steps:** Walk Red to (0, 0, -13.7) against the back ledge (top 1.2 m), or to (-14.3, 0, 8) against the side ledge (top 0.7 m, at (-17, 0, 8)).
- **Expected:** Either the ledges are meant to be reached by a jump (then the arena should say so, and a jump should clear them), or they are walkable.
- **Actual:** Red stops at the face. Nothing in the arena says how to get up. Jump-up was not tested.
- **File:** `game/data/combat/sandbox.json` (`arena.ledges`).
- **Owner:** Gameplay Programmer, with Combat Designer for intent.

### BUG-03 · major · Freed-actor script error every frame after Reset arena, and a stuck wind-up ring

- **Steps:** Fight, then Esc > Reset arena > Resume. Most likely needs an enemy mid wind-up at the moment of reset. Seen in 2 of 3 runs.
- **Expected:** The wind-up cue goes with its enemy. No script errors.
- **Actual:** `SCRIPT ERROR: Trying to cast a freed object` at `combat_fx.gd:395` (61 times in one run, 29 in another). The loop aborts each frame, so the cue is never released. A yellow ring hangs in mid-air at the back of the arena: `docs/screenshots/qa_sandbox_13_after_reset.png`.
- **File:** `game/scripts/combat/fx/combat_fx.gd`, `step()`, the `_cues` loop (line 395). The `is_instance_valid(actor)` check comes after the cast on the same line.
- **Owner:** Technical Artist.

### BUG-04 · minor · Dev runs of the sandbox save into the old game's folder

- **Steps:** `godot --path game -- --sandbox`. Move a feel slider, Save (F12 panel).
- **Expected:** Sandbox files go to their own folder (`LightsOnSandbox`), as the contract says (section 2, CS-1).
- **Actual:** Saved to `~/.local/share/LightsLeftOn/feel/feel_current.json`. The `custom_user_dir_name.sandbox` override only applies when the `sandbox` feature tag is set (exports). So the sandbox's saved slider values are loaded by the next run. QA's `run_speed_mps` drifted 6.0 → 6.75 → 7.5 across consecutive QA runs. Not checked in the exported builds.
- **File:** `game/project.godot` (`[application]` overrides), `game/scripts/core/main.gd` (sandbox boot).
- **Owner:** Integrator.

### BUG-05 · polish · Sword-stand rings and name labels fill the bottom corners (the teal corner shapes)

- **Steps:** Walk Red to the back of the arena, to about (0, 0, 15), facing the stand row.
- **Expected:** Stands readable without covering the screen.
- **Actual:** Stand rings (trail-coloured torus, teal and cyan) sit at z = 17.5, behind her spawn. Near the back they loom into both bottom corners. The 3D name labels are large and cut off at the screen edges ("k-blade", "Glass-c"), and in a fight shot ("Dark machete") two labels overlap.
- **Answer to the teal-corner question:** these are the stand rings. They are not FX, HUD or camera clipping. At the normal spawn framing they do not show (`qa_sandbox_01_arena_boot.png`, `qa_sandbox_boot_f1.png`). Hiding the racks changes nothing at boot. With Red near the back row they show as the two corner shapes (`qa_sandbox_rack_row_back_centre.png`).
- **File:** `game/data/combat/sandbox.json` (`racks.stands[].pos`), `game/scripts/sandbox/sword_rack.gd` (ring and label size).
- **Owner:** Gameplay Programmer. Placement is a look call for Ross.

### BUG-06 · minor (not confirmed) · One parry in run 3 got no rating

- **Steps:** Parry three grunt or Brute wind-ups in a row, standing still, pressing parry at impact − 70 ms (QA script section 7).
- **Expected:** Every press in the window is rated.
- **Actual:** Run 1 3/3 `totally_rad`. Run 2 2/3 (one with no rating). Run 3 2/3 (one with no rating, Red lost 10 HP to a grunt swipe).
- **Why not confirmed:** the container runs at about 15 fps, so the press timestamps can be about 66 ms off. Needs a re-check at 60 fps.
- **File:** `game/scripts/combat/model/parry_judge.gd`, `game/scripts/combat/action_player.gd`.
- **Owner:** Battle Programmer (judge), Gameplay Programmer (input timing).

## Checked and passing (for the record)

Boot to arena 3.1 s (under 10 s). All 8 directions relative to the camera. Jump, dash, air-dash. 3-hit light string (`light_1`, `light_2`, `light_3`). Heavy. Launcher lifts an enemy and air hits connect. Lock-on on, flick to switch, off. V toggles diorama and back. All 6 sword stands swap the sword in hand. No trail left behind after a swap (6/6). Enemies die and respawn. No enemy stuck on a pillar or inside one during the fight. Red never falls below y = -0.01. Esc pause: Resume, Controls card, Reset arena (Noise cleared, Lights On ended, 5 enemies back, Red full HP). Mouse freed when paused, recaptured after Resume and Reset. A button pressed while paused does not fire after Resume. F12 panel: a slider moves, Save writes the file, F12 closes. Esc > Quit closes the game. HUD at 1920x1080 is crisp at 1:1 (`qa_sandbox_hud_crop_top_left.png`).

## Screenshots (docs/screenshots/)

`qa_sandbox_01_arena_boot.png`, `qa_sandbox_01b_arena_racks_hidden.png`, `qa_sandbox_boot_f1.png` (and f2, f4, f8, f16, f40), `qa_sandbox_hud_crop_top_left.png`, `qa_sandbox_hud_crop_bottom_right.png`, `qa_sandbox_02_running.png`, `qa_sandbox_03_air_dash.png`, `qa_sandbox_04_light_string.png`, `qa_sandbox_05_lock_on.png`, `qa_sandbox_06_diorama.png`, `qa_sandbox_07_parry_window_0..2.png`, `qa_sandbox_08_launcher_air.png`, `qa_sandbox_09_sword_*.png`, `qa_sandbox_10_fight_midway.png`, `qa_sandbox_11_after_fight.png`, `qa_sandbox_12_controls_card.png`, `qa_sandbox_13_after_reset.png`, `qa_sandbox_14_feel_panel.png`, `qa_sandbox_15_feel_saved.png`, `qa_sandbox_ramp_floor.png`, `qa_sandbox_ramp_behind.png`, `qa_sandbox_rack_row_back_centre.png` (also `_back_left`, `_back_right`).

## QA scripts added (untracked, for the lead to commit)

- `game/tests/visual/qa_sandbox_playthrough.gd`: the full playthrough. Names no game classes.
- `game/tests/visual/qa_sandbox_ramp_walk.gd`: reproduces BUG-01 (fails by design until the ramp is fixed).
- `game/tests/visual/qa_sandbox_boot_frames.gd`: first frames after boot, plus 1080p HUD crops.
- `game/tests/visual/qa_sandbox_ramp.gd`, `qa_sandbox_rack_row.gd`: placed-Red screenshots.


**2026-10-09 lead:** BUG-03 fixed in combat_fx.gd: wind-up cues whose attacker was freed (death, Reset arena) are dropped before the cast, so no per-frame error and no stuck ring.
