# Task Board

> Owner: Producer. Current milestone: **VERTICAL SLICE**. Anything beyond the slice goes in Later.

**Status (2026-10-09)** *(updated by the Technical Director while the Producer role isn't running)*
- **The vertical slice has started.** Ross approved its shape today (night market, robot junkyard, Kasp, four hacks) and answered the robot finale: C, robots at the end of the boss fight. Tech plan: docs/slice/slice_tech_plan.md. Board: "Vertical slice" below.
- **Decisions needed from Ross:** three, at the top of the tech plan: how Red picks a hack, what happens when she's knocked out, and which button talks. Builders use the recommended options (built as switches) until he answers.
- **Done:** the combat sandbox (CS-0 to CS-22), builds 1 and 2 played by Ross.
- **Next:** VS-2 to VS-13 (art list for Ross, slice boot, the new Red in town, the one room script, hacks, HUD, the two map docs).
- **Waiting on Ross:** the three decisions; then the map docs (VS-12, VS-13); his art for the slice (VS-A1 to VS-A7) whenever he's ready.

## To Do

> Slice tasks follow the approved build order (docs/design_doc.md, "Vertical slice scope"; docs/decisions.md, 2026-10-06). Each task is sized for one agent in one go.
> **Ross sign-off** follows the Playbook autonomy ledger: style guide and the look (Art direction, Level 0), area layouts (Game design & battle, Level 1: whole areas are bigger than small calls), dialogue and story text (Dialogue & writing, Level 0), music direction (Audio direction, Level 0), every art drop he delivers, and the final build. Gear, menus and saves are Level 2 (show Ross after, no sign-off). Small design calls (tuning numbers, enemy stats) are Level 1: the studio decides and logs each one in docs/decisions.md. Any new mechanic that turns up during the build goes to Ross as its own decision.
> Before every Ross sign-off, the Taste Keeper records a prediction. Placeholders (game/art/placeholder/ only) until each art drop.
> Every gameplay task includes its headless tests in game/tests/ and keeps its numbers and text in game/data/. Builds target **Windows and Mac**.

> Milestones 0 and 1 are Done (see Done).

### Vertical slice (approved 2026-10-09; current milestone)
> Shape approved by Ross 2026-10-09 (docs/decisions.md; docs/slice/slice_pitch.md): Loop A (Mega Man Legends), the Harrow night market with Red's hideout over a repair shop, the robot junkyard (loader midway), Kasp in the Hushmaster, hacks A (Zap Drone, EMP, Overclock, Reboot; battery refilled by sword hits). Robot finale: **C** (Ross: "We want to save our giant robo battles for the end of levels and boss fights and some boss fights are on foot first then transition to robo battles"): phase 1 on foot against the Hushmaster, phase 2 Kasp's giant junk mech against Red's loader docked into the colossus.
> Contract: **docs/slice/slice_tech_plan.md** (owners, flow, hacks, robots, boss, tests). Combat contract: docs/pivot/combat_api.md. Each row is one agent run. Order: phases 1 and 2 give a **playable town-to-boss graybox** (VS-35); phases 3 and 4 add content, the look, Ross's art and polish. Estimate: about 6 to 8 weeks of studio time; Ross's art sets the calendar.
> Now in scope from the sandbox's Later list: hacks on the second button, the Level Designer, saving, towns under the hybrid camera, sorting field buttons against combat buttons. The turn-based milestones further down (G, M2 to M7) are shelved with the turn-based game, not deleted.
> Ross sign-off follows the Playbook ledger: area layouts, dialogue, the look, music direction, new combat mechanics and every art drop go to him; numbers and names are Level 1; shop stock, menus and saves are Level 2 (show after). The Taste Keeper records a prediction before each.

**Phase 1: foundations (start now)**

| ID | Task | Assigned to | Depends on | Ross sign-off | Notes |
|---|---|---|---|---|---|
| VS-1 | Slice tech plan (docs/slice/slice_tech_plan.md) and code review of every VS task | Technical Director | | Three decisions inside (hack picking, knock-out, talk button) | **Written 2026-10-09.** Changes go in its "Changes" section. |
| VS-2 | Slice art and audio request lists: docs/art_requests.md rows for VS-A1 to VS-A7 (name, use, size, poly budget, palette, format, path; the junk mech is new), docs/audio_requests.md rows for hacks, the boss, the mech and the market | Creative Director (Technical Artist sets sizes and budgets) | VS-1 | No (lists; Ross's art drops are signed off when they arrive) | First, so Ross can start on Kasp and the Hushmaster. |
| VS-3 | Game modes and slice boot: `GameMode` (slice / sandbox / classic), rooms data and save folder per mode, `-- --classic` for the shelved game, slice feature tag and the two Slice export presets; editor Play stays on the sandbox for now | Gameplay Programmer | VS-1 | No | Plan 2.1. Every old test still green. **Built 2026-10-09** (GameMode, rooms/saves per mode, `--classic`/`--slice`, Slice export presets, tests: unit/test_game_mode). Default launch stays classic until VS-35. |
| VS-4 | Hero contract: `HeroLink`, field / works / dialogue / shop / menu type hints moved off PlayerController, ActionPlayer's contract methods and town mode, input sorting (interact per Decision 3, recommended A as a switch) | Gameplay Programmer | VS-1 | No | Plan 2.6 and 3. Test: test_hero_contract. **Built 2026-10-09** (HeroLink, ActionPlayer contract and town mode, Decision 3 as a data switch, input sorting; tests: integration/test_hero_contract, unit/test_interact_rules, unit/test_input_sorting). |
| VS-5 | `ActionRoom`: one room script from `data/slice/rooms.json` (camera, combat, look, form, checkpoint), combat host methods, director in every room, health / battery / sword / form carried through doors, persistent HUD re-binding | Gameplay Programmer | VS-3, VS-4 | No | Plan 2.2, 2.3. Test in two tiny test rooms. |
| VS-6 | Feature switches `data/slice/features.json` (`lights_on`, `lamp_flare`, `noise_meter`, all on): the Lights On switch-off point, nothing removed | Combat Programmer | VS-1 | No (flipping one off is Ross's call) | Plan 7. Test: test_features. |
| VS-7 | Hack design and data: `hacks.json` (battery, costs, targets, effects), the four cast moves in `moves.json`, the `hacks` feel group, the automatic-pick rules for option C, docs/slice/hacks_design.md | Combat Designer | VS-1 | No (numbers and names, Level 1); how hacks are picked is Decision 1 | Plan 4.1. |
| VS-8 | Hack core: `HackBattery`, `HackRules`, `HackSelector` (pure, unit-tested), the battery in the director fed by sword hits, `battery_changed` / `hack_locked` signals | Combat Programmer | VS-7 | No | Plan 4.2. |
| VS-9 | Hacks in the world: `HackCaster` on Red, Zap Drone, EMP, Overclock link, Reboot through `report_hack_hit`; `Hijackable` and hijacked enemy targeting; lock-on reaches `lock_targets`; works in the sandbox arena too | Combat Programmer | VS-8 | No (Ross judges by playing at VS-35) | Plan 4.3 to 4.5. Gameplay Programmer reviews the lock_on.gd edit. |
| VS-10 | Red's four hack clips from the free Quaternius library (zap, EMP, Overclock, Reboot) with pose keys | Animator/Rigger | VS-7 | No | No new authored clips (Ross 2026-10-08). Fallback tweens until then. |
| VS-11 | Action HUD: binds to any combat host; hack panel (battery, selected hack, lockout fizz, hijack timer), boss bar, radio bark box, location card, Continue screen, slice pause menu; Lights On element follows its switch | UI Programmer | VS-5, VS-8 (stub is fine) | No (Level 2: show Ross after) | Plan 2.5, 4.6. |
| VS-12 | Night market map (docs/maps/night_market.md): the 9 Harrow rooms re-dressed and renamed as the market, Red's hideout over a repair shop, NPC list, shops, job board (main job opens the junkyard) | Level Designer | VS-1 | **Yes** (one page; walls and doors are the approved 2026-10-07 Harrow layout, so only names, the hideout and dressing are new); goes with VS-13 | Taste Keeper predicts first. |
| VS-13 | Junkyard and arena map (docs/maps/junkyard.md, docs/maps/kasp_arena.md): J1 to J4 on foot, J4 loader wake, J5 loader run, the one-scene two-scale arena; hack targets, encounters, save terminals, pacing | Level Designer | VS-1 | **Yes** (area layouts) | Plan 5, 6.2. |

**Phase 2: playable town-to-boss graybox**

| ID | Task | Assigned to | Depends on | Ross sign-off | Notes |
|---|---|---|---|---|---|
| VS-14 | Market graybox: `make_market_rooms.py` (from the Harrow generator), `market_*` scenes and room entries, ActionRoom on each, placeholder NPCs, shops, job board, save terminal in the hideout | Level Designer | VS-5, VS-12 | No (Ross plays it at VS-35) | Harrow's own scenes stay untouched. Test: test_slice_rooms. |
| VS-15 | Town systems end to end with the new Red: talking, bubbles and ambient barks, shops (ShopLogic), job board, save terminal and rest, field menu from the pause menu | Gameplay Programmer | VS-4, VS-5 | No | Plan 3. Test: test_town_systems. |
| VS-16 | Knock-out, retry and saving: `RoomSnapshot`, Continue from the room entrance (Decision 2, recommended A as the default rule), save terminals, auto-save rooms, save fields `sword` and `hacks` (migration 2 to 3), no saving in robot rooms | Gameplay Programmer | VS-5 | No (Level 2: show after) | Plan 2.4. |
| VS-17 | Slice enemy roster and encounters: Signals cop (Grunt by data), Signals drone, wall turret, the heavy (Brute until Ross's model); `enemies.json` entries, tags, `data/slice/encounters.json`, docs/slice/enemy_roster.md | Combat Designer | VS-13 | No (numbers; any new behaviour goes to Ross) | |
| VS-18 | The flying Signals drone and the wall turret (code), both hijackable; EMP stun and Zap bonus by tag | Combat Programmer | VS-9, VS-17 | No | Test: test_drone_turret. |
| VS-19 | World hack targets: `HackTarget`, fuse-box door, crane (Overclock moves a container along a path), drone line, terminal; sticky flags | Gameplay Programmer | VS-9 | No | Plan 4.5, 5.2. Test: test_hack_targets. |
| VS-20 | Junkyard graybox J1 to J4 (on foot): rooms, encounters, hack targets, midpoint save terminal | Level Designer | VS-13, VS-18, VS-19 | No (Ross plays it at VS-35) | |
| VS-21 | `RobotStage`: robots in a level from `robot_rooms/*.json`, boarding started by a hack or a script, `place_in(form)` for rooms that start in a robot, hacks off in robot forms | Gameplay Programmer | VS-5 | No | Plan 5.3. Reuses CS-21 unchanged in the sandbox. |
| VS-22 | Loader section: J4 loader wake, J5 loader run (smash props, cops and drones at Red's scale, loader-only scrap walls), climb out at the arena gate | Level Designer | VS-20, VS-21 | No | |
| VS-23 | Boss design as data: `bosses/hushmaster.json` (relays, leg pairs, Leg Stomp, Dish Sweep, Drone Drop, Quiet Hours, topple, jack-in) and `bosses/junk_mech.json` (**the giant junk mech's robot-scale attack patterns**, plates, core, scaled wind-ups); boss move sets; docs/slice/boss_design.md | Combat Designer | VS-7 | **Yes** (the junk mech's attack list is new: one page) | Plan 6.4. The Hushmaster's patterns are the approved pitch. |
| VS-24 | Boss blockouts in art/placeholder/: the Hushmaster (8 legs in 4 pairs, 4 relay boxes, dish, seat), **the giant junk mech (~40 m, Red's bone names, plates and cockpit core)**, Kasp, arena wall turrets | Technical Artist | VS-13 | No (placeholders) | Original designs; the mech must not read as any existing robot. |
| VS-25 | Clips on Kasp and the junk mech (retargeted like the robots), townsfolk idle / talk / walk | Animator/Rigger | VS-24 | No | |
| VS-26 | Boss core: `BossFight` (phases, forms, retry points), `BossPart`, `BossBrain`, `BossPhases`; `ring` and `beam` hitbox shapes | Combat Programmer | VS-9, VS-23 | No | Plan 6.3, 6.4. |
| VS-27 | Phase 1, the Hushmaster: relays drop leg pairs, the four patterns, Quiet Hours lockout cut short by the dish, topple and jack-in | Combat Programmer | VS-24, VS-26 | No (Ross plays it at VS-35) | Test: test_hushmaster. |
| VS-28 | Phase 2, **the junk mech robot round**: `scale_form` enemies, robot-scale patterns from data, telegraphs readable from 75 m, plates and core, colossus-vs-mech hit tuning hooks | Combat Programmer | VS-21, VS-24, VS-26 | No (Ross plays it at VS-35) | Plan 6.5. About 1.5 to 2 weeks with VS-29 and VS-30: the biggest single cost in the slice. |
| VS-29 | Kasp's arena graybox: one scene, two scales (the 40 m plateau inside the junkyard bowl, scrap piles, the dormant colossus, the parked loader spot), turrets, drone drop points, intro shots | Level Designer | VS-13, VS-24 | No | Plan 6.2. |
| VS-30 | **Phase transition**: Kasp escapes, the junk mech assembles from the yard, Red boards the loader, docks into the colossus (CS-21 docking), the scale switch mid-scene, per-phase retry (phase 2 restarts already docked) | Gameplay Programmer | VS-16, VS-27, VS-28, VS-29 | No (Ross plays it at VS-35) | Test: test_boss_transition. |
| VS-31 | Placeholder words: market NPCs and barks, job board, Kasp's barks and spec recitals, Vela's radio lines, memo posters | Writer | VS-12, VS-13 | No (placeholder; final text at VS-37) | |
| VS-32 | Placeholder sounds: hacks, battery, boss patterns, the mech, the transition; market and junkyard ambience and music stand-ins | Audio Designer | VS-7, VS-23 | No (placeholders) | |
| VS-33 | Graybox QA: slice data tests, smoke test, the bot playthrough town to boss (plan 8), bug log | QA Tester | VS-14 to VS-32 | No | |
| VS-34 | Graybox feel pass: town, junkyard, loader, both boss phases, pacing | Playtester | VS-33 | No | Report, not fixes. |
| VS-35 | **Graybox build to Ross** (Windows and Mac): title to the end of the boss; editor Play switches to the slice (sandbox stays on `--sandbox`); studio log with screenshots | Producer + Gameplay Programmer | VS-33, VS-34 | **Yes** (plays it; feel, layouts, hacks, the robot round) | Taste Keeper predicts first. |

**Phase 3: content and look**

| ID | Task | Assigned to | Depends on | Ross sign-off | Notes |
|---|---|---|---|---|---|
| VS-36 | Slice script: hideout start, the job, the loader wake, Kasp's intro, the escape into the junk mech, the ending | Writer + Creative Director | VS-35 | **Yes** | Story from the approved setup, lamp names swapped out. |
| VS-37 | Final words: market NPCs, job board, barks, radio, item text | Writer | VS-36 | **Yes** (dialogue) | Item text is Level 2. |
| VS-38 | Cutscenes from the approved script: StoryDirector's new steps (`radio`, `form`, `boss_phase`, `camera_shot`) and the shot director's storyboard shots | Gameplay Programmer | VS-36 | No | |
| VS-39 | Market look: `market_ps2` profile (warm neon night, string lights) and dressing placeholders (stalls, carts, sign slots for Ross's signage) | Technical Artist | VS-14 | **Yes** (the look; screenshots) | |
| VS-40 | Junkyard and arena look: `junkyard_ps2`, junk dressing, the yard at colossus scale, huge-scale telegraph look | Technical Artist | VS-22, VS-29 | **Yes** (the look; screenshots) | |
| VS-41 | Hack, Quiet Hours, part-break and scale-switch effects | Technical Artist | VS-9, VS-27, VS-30 | No | |
| VS-42 | Tuning pass from Ross's graybox notes: hacks, battery, enemies, both boss phases | Combat Designer | VS-35 | No (numbers, Level 1; new mechanics go to Ross) | Log each call in docs/decisions.md. |
| VS-43 | Town life: NPC routines, crowd colour swaps, ambient barks, voices per NPC | Level Designer | VS-15, VS-25 | No | |
| VS-44 | Shop stock and items for the slice | Combat Designer | VS-15 | No (Level 2: show after) | |
| VS-45 | Music direction brief for the slice (market, junkyard, loader, Hushmaster, mech round), then the music and SFX hooks | Audio Designer | VS-35 | **Yes** (music direction) | |
| VS-46 | HUD polish and UI art in (hack icons, portraits in the radio box and dialogue) | UI Programmer | VS-11, VS-A7 | No (Level 2) | |

**Ross's art for the slice (from the pitch's list; full rows in docs/art_requests.md after VS-2)**

| ID | Task | Assigned to | Depends on | Ross sign-off | Notes |
|---|---|---|---|---|---|
| VS-A1 | Art in: Kasp and the Hushmaster (rows 33 and 34, updated for the action game: 4 relay boxes, legs in pairs, dish) | Technical Artist + Animator/Rigger + Asset Checker | VS-2, VS-24, Ross's delivery | **Yes** (his art) | Highest priority on the pitch's list. |
| VS-A2 | Art in: **the giant junk mech** (new; built from junkyard scrap, Kasp's cockpit core, plates that come off; about 40 m; on Red's bone names) | Technical Artist + Animator/Rigger + Asset Checker | VS-2, VS-24, Ross's delivery | **Yes** (his art) | New with Ross's answer C. Blockout until then. |
| VS-A3 | Art in: enemy types beside the Cyberwolf (a Signals drone; a heavy to replace the Brute blockout) | Technical Artist + Animator/Rigger + Asset Checker | VS-2, VS-18, Ross's delivery | **Yes** | |
| VS-A4 | Art in: town people (Otis, Mox, Vela, 3 or 4 market residents; the rest are colour swaps) | Technical Artist + Animator/Rigger + Asset Checker | VS-2, VS-14, Ross's delivery | **Yes** | |
| VS-A5 | Art in: market kit (stalls, carts, signs) | Technical Artist + Asset Checker | VS-2, VS-39, Ross's delivery | **Yes** | His city textures cover walls and floors. |
| VS-A6 | Art in: junkyard kit (scrap piles, crane, wall turret, terminal, fuse box, drone line, the loader bay) | Technical Artist + Asset Checker | VS-2, VS-40, Ross's delivery | **Yes** | Was the "Works kit" in the pitch; recast for the junkyard. |
| VS-A7 | Art in: small items (the Zap Drone model, four hack icons, dialogue portraits for the 4 or 5 main speakers) | Technical Artist + UI Programmer + Asset Checker | VS-2, Ross's delivery | **Yes** | |

**Phase 4: QA, playtest, builds**

| ID | Task | Assigned to | Depends on | Ross sign-off | Notes |
|---|---|---|---|---|---|
| VS-47 | Full QA pass: all headless tests, both bot playthroughs (main path; side jobs and shops), real-renderer 60 fps check, bug log | QA Tester | VS-36 to VS-46 | No | |
| VS-48 | Playtest report: pacing (30 to 45 minutes to the boss kill), difficulty, hack readability, robot round readability | Playtester | VS-47 | No | |
| VS-49 | Fix pass on QA and playtest findings | Owners per bug | VS-47, VS-48 | No | New ideas go to Later. |
| VS-50 | Windows and Mac slice builds; Ross plays the slice and signs off | Producer + Gameplay Programmer | VS-49 | **Yes** | Placeholders left in only with Ross's OK. |

**Later (not in the slice):** more robot fights at the ends of later levels (the parts are built to be reused); a whole boss at robot scale; room streaming instead of fades; hacks while piloting robots; swords with random affixes; swappable faces; Ross's motion capture; removing Lights On code (only when Ross says).

### Combat sandbox (approved 2026-10-08; done, kept as a test bed)
> Ross approved the action RPG plan (docs/decisions.md, 2026-10-08). Contract: **docs/pivot/combat_api.md** (owners, buttons, move data, interfaces, tests). Plan: docs/pivot/buildability.md section 6. Scope is exactly D2; anything else goes to Later below. Combat mechanics are Ross's (Level 1 covers numbers and names only), so contested calls are feel-panel toggles he picks by playing. The turn-based milestones further down are shelved, not active.

| ID | Task | Assigned to | Depends on | Ross sign-off | Notes |
|---|---|---|---|---|---|
| CS-0 | Combat API contract (docs/pivot/combat_api.md) and code review of every CS task | Technical Director | | No | Written 2026-10-08. Changes go in its "Changes" section. |
| CS-1 | Input actions (light, heavy, dash, parry, lock_on, camera_toggle, feel_panel, camera_*), physics layer names 10 to 16, `sandbox` feature-tag overrides (user dir, name), main.gd sandbox boot (`sandbox` feature or `-- --sandbox`) | Integrator | CS-0 | No | Contract sections 1 and 2. Old game's boot unchanged. |
| CS-2 | ActionPlayer: run, jump (PlayerMotion kept), dash and air-dash with i-frames, attack / parry / hurt / knockdown states, bot inputs; `player_action.json`, movement knobs | Gameplay Programmer | CS-1, CS-5 | No | Contract 4.2. Test: test_action_player. |
| CS-3 | OrbitCamera + LockOn + LockOnMath, action-diorama toggle, attack magnetism, `camera.json`, camera knobs | Gameplay Programmer | CS-1 | No | Contract 4.8. Shake comes from CS-14. |
| CS-4 | Sandbox arena scene (pillars, a ledge, spawns, enemy respawn, reset), sword rack stands, `sandbox.json`, `screen_pos_of`; the two sandbox export presets (Windows, Mac) | Gameplay Programmer | CS-2, CS-3 | No | Ross is in the arena in under 10 seconds. |
| CS-5 | Combat model core: CombatClock, CombatTime (hit-stop, flare scaling), MoveSet, MoveRunner, InputBuffer, FeelKnobs; `moves.json` (Red's set), `feel.json` | Battle Programmer | CS-0 | No | Contract 3, 4.1, 4.9. Pure classes with unit tests first, so CS-2 can start. |
| CS-6 | Hit chain: CombatActor, CombatDirector, Hitbox, Hurtbox, HitResolver, JuggleRules, CombatLayers; `hit_feel.json`; all director signals | Battle Programmer | CS-5 | No | Contract 4.2 and 4.6. Ship a signal stub early for UI and FX. |
| CS-7 | ParryJudge (on ClutchJudge), perfect dodge, Lamp Flare; `parry` entry in timing_windows.json; flare knobs | Battle Programmer | CS-6 | No | Contract 4.3, 4.4. |
| CS-8 | ActionEnemy, EnemyBrain, AttackTokens; Grunt and Brute move sets and `enemies.json`; `enemies_attack` knob | Battle Programmer | CS-6, CS-12 (models can be blockouts at first) | No | Grunt = Ross's Cyberwolf Sentinel once rigged. |
| CS-9 | Noise (StyleMeter) and the Lights On stub (fills, shows, simple buffs); `style.json` | Battle Programmer | CS-6 | No | Contract 4.5. Rank names are Level 1. |
| CS-10 | Rig Ross's Red (clips: **prefab CC0 only, no new authored clips**, Ross 2026-10-08; Quaternius Universal Animation Library 1+2 retargeted) (`red_ross_v1_rigged.glb`, `weapon_socket` on `hand_r`) and her clips or key poses; `anim.keys` in moves.json; procedural fallbacks for missing clips | Technical Artist | | No (his model, rigged; Ross sees it in the build) | **In progress.** Contract section 5. Test: test_red_ross_rig. |
| CS-11 | Swords: split (done), `swords.json` for all six, GearVisuals swap on `weapon_socket` | Technical Artist | CS-10 | No | Contract 4.7. Test: test_gear_visuals. |
| CS-12 | Enemy models: rig the Cyberwolf Sentinel (the Grunt), Brute blockout in art/placeholder/, idle / move / wind-up and strike poses | Technical Artist | | No | Readable wind-ups for parrying. |
| CS-13 | PS2 rendering for the sandbox: `grim_ps2` profile, 640×360, per-pixel lit shader with the edge light, one shadow light, glow, jitter / affine / dither off, `art/final/` textures smooth with mipmaps | Technical Artist | | No (D4 approved; show Ross screenshots) | Contract section 6. Old game's look unchanged. |
| CS-14 | Combat FX: sword trails, hit sparks, wind-up flash, Lamp Flare and Lights On looks, dash streak, CameraShake (smooth), CombatFx sound hookup; `fx.json` | Technical Artist | CS-6, CS-11 | No | Contract 4.6 (who plays which sound). |
| CS-15 | Sandbox HUD (HP, Noise meter and rank pop-ups, Lights On, lock-on reticle, parry and Lamp Flare pop-ups, damage numbers), controls card, pause menu (Resume, Reset, Controls, Quit), Config rows for the new buttons | UI Programmer | CS-6 stub | No | Re-use battle_popup and the stencil lettering. |
| CS-16 | Feel-knobs panel built from `feel.json`: pause, Save to `user://feel/`, Reset, Revert, Open folder | UI Programmer | CS-5 | No | Contract 4.9. Ross sends the saved file back. |
| CS-17 | Placeholder combat sounds (19 `combat_*` ids) | Audio Designer | | No (placeholders) | **In progress** (files and ids exist). |
| CS-18 | Data validation, hit-flow and smoke tests, bot runs, real-renderer pass, bug log | QA Tester | CS-2 to CS-16 | No | Contract section 7. |
| CS-19 | Feel pass before Ross plays (does every move read, is anything mushy) | Playtester | CS-18 | No | Report, not fixes. |
| CS-20 | Sandbox builds for Windows and Mac, download link, short how-to-play, studio log with screenshots or a clip; **Ross plays it** and sends feel notes and his saved feel file | Producer + Gameplay Programmer | CS-18, CS-19 | **Yes** (feel and the "Ross picks by playing" toggles) | Taste Keeper records predictions first. |
| CS-21 | Giant robot scale-up test: placeholder small robot (~3-4 m) and huge robot (~40-60 m) blockouts; boarding points; same controller with scale-driven camera, speed, turn rate, footstep shake, dust, sound pitch; scaled props so size reads | Technical Artist (blockouts, FX) + Gameplay Programmer (boarding, scale profile) | CS-20 build | **Yes** (Ross plays it) | Approved 2026-10-09 (A). Original designs only. |
| CS-22 | Kingdom Hearts one-button combo: situational move selection from combo rules; second attack button shows "Hack: coming later" | Combat Designer (data) + Combat Programmer (logic) | CS-20 build | **Yes** (feel) | Approved 2026-10-09 (B). |

**Later (not in the sandbox):** hacking and gadget abilities as the game's magic, on the second attack button (Ross 2026-10-09); swords found in the world with random affixes and upgrades, Binding of Isaac-style (Ross 2026-10-08; keep sword data as base + affixes so it slots in); swappable faces for Red (approved design 2026-10-08: swappable eyes and mouths plus whole-face specials for big moments; keep room for it, build it when scheduled); Ross's own motion capture for signature moves (after the placeholder phase); a Level Designer for the slice; Rip on big bosses; double jump; gadget arm; goggles on/off; Signals grunts fleeing from Lights On; materials, crafting and the workshop; gear beyond swords; saving; towns under the hybrid camera; sorting field buttons against combat buttons.

### Milestone 2: Battle system and battle simulator
| ID | Task | Assigned to | Depends on | Ross sign-off | Notes |
|---|---|---|---|---|---|
| M2-10 | Art in: import Ross's party models (Red, Otis, Mox) and the 3 weapon props; asset check | Technical Artist + Asset Checker | M1-5, Ross's delivery (art rows 1–6) | **Yes** (Ross's art) | **Waiting on Ross.** M2-1 to M2-9 are Done. Reference for the party is now the grim look (taller, leaner, matte and scuffed) and the A-pose sheets (G-0). |

### Milestone 3: Harrow Landing
| ID | Task | Assigned to | Depends on | Ross sign-off | Notes |
|---|---|---|---|---|---|
| M3-11 | Art in: Harrow sets and interiors, townsfolk, portraits; asset check | Technical Artist + Asset Checker | M3-4, G-5, Ross's delivery (art rows 7–18) | **Yes** (Ross's art) | **Waiting on Ross** (skipped for now per Ross, 2026-10-07). M3-1 to M3-10 are Done. Harrow's sets now follow the cyberpunk-slum re-dress (G-5) and docs/tone_guide.md. |

### Next phase: the grim package and the train opening (approved 2026-10-08)
> From docs/decisions.md 2026-10-08 and docs/structure_pass_2026-10-08.md. Grim look, edge light, tone D1 A / D2 B / D3 B, structure D1 A / D2 A / D3 A. UI windows and menus stay as they are. Slice is now about 33 minutes (about 28 skipping optional fights).

| ID | Task | Assigned to | Depends on | Ross sign-off | Notes |
|---|---|---|---|---|---|
| G-1 | Make the tone pass and structure pass official: story bible (Act 1 beats 1 and 7, Act 2 beat 2), design doc (10-hour structure, slice paragraph and list), maps (new docs/maps/train.md for the 3 car rooms + the jump; docs/maps/road_and_tower.md recast as the Spillway, the Works gate and the jammer works; Harrow map's New Game start), style guide environment table | Creative Director | | No (approved 2026-10-08) | Same room ids, flags, encounters and approved map choices. Twist section stays Creative Director + Writer only. |
| G-2 | Update docs/art_requests.md and docs/audio_requests.md: row 19 becomes the Spillway and the Works gate, the tower kit becomes the Works kit around the mast, new row 42 train-car kit (one car module re-dressed as flatcar, hopper, boxcar), row 37 rating lettering becomes spray-paint stencil, grim palette notes on character and set rows; audio: train and undercity ambience | Creative Director | G-1 | No | Already underway. Slice art list goes from 41 to 42. Also update the locked budgets from M1-5 if they aren't in yet. |
| G-3 | Edge-light readability pass: characters and enemies a bit brighter than the grim background, "not too bright", with an edge light (Look A); field and battle | Technical Artist | Grim look test (Done) | No (direction approved; show Ross screenshots in docs/screenshots/) | Clutch cues and ratings must still read at a glance. |
| G-4 | Grim look everywhere: make the grim look profile the default in every room and the battle stage (classic stays switchable in the F1 overlay for comparison) | Technical Artist | G-3 | No | Applies the 2026-10-08 visual direction (desaturate, darken, grime). UI unchanged. |
| G-5 | Harrow slum re-dress across all 9 rooms: taller stacked facades and cable nests above the walkable floor, neon over grime, propaganda; scenery only, no layout, door, shop or spawn changes | Technical Artist | G-4 | No | Placeholders in game/art/placeholder/ only. Same camera. |
| G-6 | Half-dark windows (tone D2 B): about half of Lamp Square's windows dark; a few relight on the walk home after Kasp, driven by the post-Kasp story flag; which windows relight lives in game/data/ | Technical Artist | G-5 | No | Test with the debug cheat that sets the post-Kasp flag. Headless test for the relight. |
| G-7 | Re-tone placeholder lines per docs/tone_guide.md (D1 A chilling-funny): story_scenes.json, harrow_town.json, battle and menu text; plus the structure changes (courier job becomes "claim your crate at Otis's dock", the dock-stairs lock reads "claim slip", one new dock line about the crate, train opening lines and Clutch tutorial prompts) | Writer | G-1 | No (placeholder text) | Ross signs off the final text in M6-2. Text Checker checks in M6-6. |
| G-8 | Spray-paint stencil rating lettering (tone D3 B, still loud): Nice!, Rad!, TOTALLY RAD!, Blocked!, Perfect Block!, Payback!, K.O.!, "!" and boss "!!" | UI Programmer | | No (placeholder) | Placeholder until Ross's art row 37 (lands in M7-1). Same timing and pop-ups; only the lettering changes. |
| G-9 | Train opening, rooms: 3 car rooms + the jump from one car module (flatcar, hopper, boxcar) with placeholders; walk, run, jump, crate hops, hiding behind ore; Red shoves the crate into the harbor and jumps for Harrow's freight platform, then runs home | Gameplay Programmer | G-1 (train map), G-4 | No | Target about 3.5–4 min. Add a jump-to-car cheat. |
| G-10 | Train opening, inspectors: scanner-sweep enemy (a patrol with a vision cone, MGS1-style hunted feel, no timer), built on the roaming enemies from M3-5 | Gameplay Programmer | G-9 | No | What happens when spotted follows the train map. Behavior numbers in game/data/. |
| G-11 | Train opening, flow: one must-win tutorial fight on the train (reuse `grunt_solo`) that teaches Clutch; **New Game starts on the train**; Red's home becomes stop 2 (first save); update the tests that assume New Game starts at home (Harrow walkthrough and story tests, the M3 end-to-end run) | Gameplay Programmer | G-9, G-10 | No | If playtests run long: make the train a pure chase with no fight (caught = restart the car). |
| G-12 | Art in: train-car kit; asset check | Technical Artist + Asset Checker | G-9, Ross's delivery (art row 42) | **Yes** (Ross's art) | Also reused later for the dead ore line (Act 1, Later). |

### Milestone 4: The Spillway and the jammer factory
| ID | Task | Assigned to | Depends on | Ross sign-off | Notes |
|---|---|---|---|---|---|
| M4-1 | Build the Spillway (two scenes; keep the `road_mast_road` id, new display name), the Works gate (Watch Zero's sit-in, Kasp on the loudspeaker, the drain grate) and the jammer works around the ancient mast, one room per floor: T0 the Sump (save lamp, plaque and mural), T1 Cable Mill, T2 Bell Gallery, T3 Power Room, T4 Drone Line, T4b last landing (the old Zero with the thermos, second save lamp), T5 the roof; placeholders | Gameplay Programmer | G-1, G-4, M3-4 | No | Add the jump-to-floor cheat. Grim look and slum neon from the start. |
| M4-2 | Works puzzles: Kasp's access-card doors (with count), power switch and freight lift (the approved cage-lift shortcut), crate push on the Cable Mill, optional bell chest in the Bell Gallery (tune order), treasure crates and chalk stashes (one on a sunken tram car in the Spillway) | Gameplay Programmer | M4-1 | No | |
| M4-3 | Fill game/data/ for the Spillway and the works: enemy placements (one dodgeable Spillway patrol, the three must-win card fights, the Quota Ambush on the Drone Line), crate contents, drops; check pacing with the simulator including the train fight (about level 6 and about 1,500 credits by Kasp) | Battle Programmer | M4-1, M2-9 | No (Level 1/2) | Log tuning calls in docs/decisions.md. |
| M4-4 | Art in: enemies, the Works kit around the mast, the Spillway and the Works gate, props; asset check | Technical Artist + Asset Checker | M4-1, Ross's delivery (art rows 19–32) | **Yes** (Ross's art) | Rows 19 and the tower kit are renamed in G-2. |

### Milestone 5: Kasp and the Hushmaster
| ID | Task | Assigned to | Depends on | Ross sign-off | Notes |
|---|---|---|---|---|---|
| M5-1 | Kasp boss logic: Quiet Hours jam pulse (cues scramble, real window never moves), 8 legs breaking in 4 pairs weakening the pulse, topple, then Kasp on foot; boss "!!" telegraphs; simulator check for a 5–8 minute fight | Battle Programmer | M2-9 | No | Approved gimmick (story bible Villains + Technical Director's review). |
| M5-2 | Boss staging with placeholders: Hushmaster rig blockout, leg-pair breaks, toppled state, camera push-ins, Kasp's title card, the long boss transition | Technical Artist | M5-1, M2-8 | No | |
| M5-3 | Art in: Kasp and the Hushmaster; asset check | Technical Artist + Asset Checker | M5-2, Ross's delivery (art rows 33–34) | **Yes** (Ross's art) | |

### Milestone 6: Story, cutscenes, dialogue, audio
| ID | Task | Assigned to | Depends on | Ross sign-off | Notes |
|---|---|---|---|---|---|
| M6-1 | Script the slice's ~6 cutscenes, with the twist-clue check | Writer + Creative Director | M3-1 | **Yes** | Creative Director checks clues and the beacon part text. |
| M6-2 | Field text: NPC lines per story beat, examine lines, party chime-ins, side-job text, item / gear / enemy / key item descriptions, menu text | Writer | M3-1, G-7 | **Yes** (Ross signs off the dialogue) | Builds on the re-toned lines (G-7) and covers the train, the Spillway and the works. Item descriptions are Level 2 (show after). |
| M6-3 | In-engine cutscene system: camera moves, close-ups, push-ins, freeze-frames, portrait dialogue, hold Start to skip; scripted from game/data/ | Gameplay Programmer | M3-3 | No | |
| M6-4 | Build the ~6 cutscenes from the approved script | Gameplay Programmer | M6-1, M6-3 | No | Ross sees them in the M7-5 build. |
| M6-5 | Audio: music direction brief for Ross (8 tracks and jingles), then the audio system (music loops, SFX hooks, per-speaker blips, volume settings) with placeholder tones for every row in docs/audio_requests.md | Audio Designer | M2-3, M3-3 | **Yes** (music direction) | Placeholder tones need no sign-off. The ding must land with the flash. Includes the train and undercity ambience (G-2). |
| M6-6 | Text check: typos, names and terms, text-box fit | Text Checker | M6-1, M6-2 | No | |

### Milestone 7: Polish, QA, playtest, builds for Windows and Mac
| ID | Task | Assigned to | Depends on | Ross sign-off | Notes |
|---|---|---|---|---|---|
| M7-1 | Art in: UI art (icons, turn-order heads, rating lettering, pop-ups and gestures, Kasp's title card, title screen and logo, menu window and cursor); asset check | UI Programmer + Asset Checker | Ross's delivery (art rows 35–41) | **Yes** (Ross's art) | Rating lettering (row 37) is spray-paint stencil, replacing the G-8 placeholder. |
| M7-2 | Full QA pass: all headless tests, title-to-window-lamp run with no dead ends, bug log | QA Tester | M6-4, M6-5 | No | Done = no crash or major bugs open. |
| M7-3 | Playtest report: pacing (~30 min, no filler), difficulty, Feel targets, Clutch readability | Playtester | M6-4 | No | |
| M7-4 | Fix pass on QA and playtest findings | Owners per bug (Gameplay / Battle / UI Programmer) | M7-2, M7-3 | No | New ideas go to Later, not into the fix pass. |
| M7-5 | Windows and Mac release builds; Ross plays the slice on his own computer and signs off | Gameplay Programmer + Producer | M7-1, M7-4 | **Yes** | Placeholders left in only with Ross's OK. |

### Other (not slice-blocking)
| Task | Assigned to | Depends on | Notes |
|---|---|---|---|
| Name Ruo's brother | Creative Director proposes | | Small; whenever convenient. |
| Steam/trademark check on the title "Lights Left On" | Producer | | Working title until checked. |

## In Progress
| Task | Assigned to | Started | Notes |
|---|---|---|---|
| G-0 A-pose reference sheets for Ross: the current characters in an A-pose on a white background, so he can create art assets | Technical Artist | 2026-10-08 | Ross's request with the grim package approval. Feeds M2-10 (party, art rows 1–6) and his other character rows. |

## Done
| Task | Done by | Finished | Notes |
|---|---|---|---|
| Grim look test: switchable look profile (classic / grim), grim Harrow square, checkpoint and battle stage, cyberpunk-slum dressing, leaner scuffed grim Red, matte scuffed Otis, Mox and grunts | Technical Artist | 2026-10-08 | Ross approved the setting 2026-10-08 with one change: brighter characters and enemies with an edge light (G-3). Shots: docs/screenshots/grim_*.png. |
| Dynamic battle camera from Ross's 12-panel storyboard (unplanned Ross request): intro shots, boss low-angle intro, idle drift, action shots, Clutch lock, Config "Battle Camera: Dynamic / Calm" | Technical Artist | 2026-10-07 | 1449 tests; playthrough 28/28. Studio calls in docs/decisions.md 2026-10-07. |
| M3-10 Title screen (New Game with name entry, Continue, Config) and the full Config screen | UI Programmer | 2026-10-07 | In v0.3.0. |
| M3-9 Save system: 3 slots + auto-save, save lamps, Continue, game over with Retry | Gameplay Programmer | 2026-10-07 | In v0.3.0. |
| M3-8 Shops: general store and gear shop | UI Programmer | 2026-10-07 | In v0.3.0. |
| M3-7 Field menu | UI Programmer | 2026-10-07 | In v0.3.0. |
| M3-6 Gear and items (7 weapons, 5 armor, 4 charms, 13 items, 6 key items) | Battle Programmer | 2026-10-07 | Enemy HP retuned x1.3; calls in docs/decisions.md. |
| M3-5 Visible map enemies (patrols, chasing, first-strike rules) | Gameplay Programmer | 2026-10-07 | In v0.3.0. |
| M3-4 Harrow Landing graybox: 9 rooms, ~25 townsfolk, both shops, job board + 2 side deliveries, 5 hidden items, dock fight, story scenes | Gameplay Programmer | 2026-10-07 | 1421 tests; delivered to Ross as v0.3.0. Kept as built; slum re-dress in G-5. |
| M3-3 Dialogue system polish | UI Programmer | 2026-10-07 | In v0.3.0. |
| M3-2 Exploration core (crew follows Red, doors and locked doors, pickups, climb and hop, SceneRouter) | Gameplay Programmer | 2026-10-07 | In v0.3.0. |
| M3-1 Layout maps for Harrow Landing, the road and the Old Relay Tower | Creative Director | 2026-10-07 | Ross approved all six picks. Road and tower recast as the Spillway and the jammer works in G-1 (same choices). |
| M2-9 Battle simulator and first tuning pass | Battle Programmer | 2026-10-06 | Results in docs/battle_sim_report.md. |
| M2-8 Battle stage, enemy blockouts, radio-static transition, TOTALLY RAD shake | Technical Artist | 2026-10-06 | In v0.2.0. |
| M2-7 Battle HUD and victory / game over screens | UI Programmer | 2026-10-06 | In v0.2.0. |
| M2-6 Rewards and progression | Battle Programmer | 2026-10-06 | In v0.2.0. |
| M2-5 Enemy AI and tells (4 enemy types) | Battle Programmer | 2026-10-06 | In v0.2.0. |
| M2-4 Skills and status effects | Battle Programmer | 2026-10-06 | In v0.2.0. |
| M2-3 Clutch engine | Battle Programmer | 2026-10-06 | In v0.2.0. |
| M2-2 Battle core | Battle Programmer | 2026-10-06 | In v0.2.0. |
| M2-1 Slice battle data | Battle Programmer | 2026-10-06 | 889 tests at v0.2.0 delivery. |
| M1-5 Pipeline test: placeholder Red through to the test room; budgets and export checklist in the style guide | Technical Artist | 2026-10-06 | Budgets per the approved style guide (~700 tris target, 900 cap). |
| M1-4 Windows and Mac export of the test room | Gameplay Programmer | 2026-10-06 | First playable build delivered to Ross (162 tests). Mac build unsigned. |
| M1-3b Demo start screen | UI Programmer | 2026-10-06 | Screenshot: docs/screenshots/m1_title_screen.png. |
| M1-3 Diorama camera test room | Gameplay Programmer | 2026-10-06 | Playable; screenshot docs/screenshots/m1_room_playable.png. |
| M1-2 PSX shader set and low-res screen | Technical Artist | 2026-10-06 | Screenshot: docs/screenshots/m1_test_room.png. |
| M0-1 Full style guide presented to Ross | Technical Artist + Creative Director | 2026-10-06 | Approved: 384×216, 96×96 portraits, one model per character. |
| Style guide (full draft) | Technical Artist (with Creative Director) | 2026-10-06 | Went to Ross as M0-1; approved. |
| Technical plan (docs/tech_plan.md) | Technical Director | 2026-10-06 | Approved; Compatibility renderer. |
| Red style prototypes A–E | Technical Artist ×2 | 2026-10-06 | Ross picked a mix; Red locked as the polished shiba (prototype F). |
| Set up the lights-left-on repository | Ross, then studio floor | Not in studio log | Started 2026-10-05; the studio log has no finish date. |
| M1-1 Project skeleton (tech plan steps 1-3): project settings, autoload stubs, DataDB, headless test runner | Gameplay Programmer | 2026-10-06 | 28 headless tests pass (`godot --headless --path game -s res://tests/run_all.gd`). Awaiting Technical Director review and the studio-floor commit. |
| Slice task board, art requests (41 assets) and audio requests drawn up | Producer | 2026-10-06 | Includes the weapon-model art requests (Red sword, Otis hammer, Mox wrench-mace); Vela's and Ruo's weapons are Later. |
| Studio setup (Phases 0–4) | Studio floor | 2026-10-05 | Waiting on Ross to merge pull request #1. |
| Pitch meeting (3 rounds) | Creative Director, Technical Director, Producer | 2026-10-05 | Ross chose Lights Left On. |
| Story bible: Logline, World & history, Factions | Creative Director | 2026-10-05 | Approved by Ross after tone pass. |
| Story bible: Main cast | Creative Director | 2026-10-05 | Approved: Red, Otis, Mox, Vela (bunny), Ruo. |
| Story bible: Villains | Creative Director | 2026-10-05 | Approved: the ladder, the Overture, Vane, Kasp, Tilly; species per Ross. |
| Taste Keeper hired, Ross's Playbook adopted | Studio floor | 2026-10-05 | All areas at autonomy Level 0. |
| Story bible: Act 1 / 2 / 3 outlines | Creative Director | 2026-10-05 | Approved as drafted. |
| Story bible: THE TWIST + clues | Creative Director | 2026-10-05 | Approved as revised: the Keeper, beatdown finale, mom = Eurydice "Dee" Kincaid. |
| Naming pass + Glossary: **story bible complete** | Creative Director | 2026-10-06 | Approved. |
| Design doc: Core pitch, Pillars, Battle system (Clutch + Juice); Relay removed everywhere | Creative Director, Technical Director | 2026-10-06 | Approved. |
| Design doc: Exploration (fixed diorama camera), Party & progression | Creative Director, Technical Director | 2026-10-06 | Approved. |
| Design doc: Equipment & items | Creative Director | 2026-10-06 | Finalized by studio under Level 2; shown to Ross. |
| Design doc: Economy | Creative Director | 2026-10-06 | Approved. |
| Design doc: Menus + Save system | Creative Director | 2026-10-06 | Finalized by studio (Level 2). |
| Design doc: The 10-hour structure | Creative Director | 2026-10-06 | Approved (two re-dressed moons; keep pacing tight). |
| Design doc: Vertical slice scope: **design doc complete** | Producer, Technical Director | 2026-10-06 | Approved. Builds for Windows and Mac. |
| Decide how to keep games separate | Technical Director, Ross | 2026-10-05 | Separate repository per game. |

## Later
_Ideas beyond the vertical slice. Not to be built until Ross approves the slice._
- EarthBound-fast instant wins against much weaker grunts (approved 2026-10-06).
- Swap/bench, Vela and Ruo's signature moves; Tangled, Butterfingers, Fired Up; robot/titan/ship/god-scale fights; other bosses' gimmicks (from the Battle system section).
- Act 1 from the lockdown on (beats 5–11), then Acts 2 and 3. Act 1 now runs across ten settings (docs/structure_pass_2026-10-08.md); the dead ore line reuses the slice's train-car kit.
- Act 2 places **Pit Nine** (company mining moon) and **Breaker's Ring** (junk-ring city), working names, approved 2026-10-08. They replace the two re-dressed moons and are built from kits already planned (the slum kit, the Works kit, the Navy hull kit), so no new biome kits; their titan stages use the strip pit and the hull ring for walls and height.
- Vela and Ruo in the party, picking your three, levels past 6 and the rest of each skill list, Act 3 guest missions.
- Machine stations, the shared Hull bar, size boost, machine versions of skills, and all machine upgrades.
- The lane chart, travel between moons, the *Low Profile*; the Biscuit stomp, titan stages and the *Supper's On* home base.
- Vela's and Ruo's weapons, the Act 2 and Act 3 weapon models, ultimate weapons; the bigger item tiers, the other cures, throwables, boosters, armor and charms.
- Inns, dock shops, higher shop tiers, the Tip Jar charm.
- Lane Chart in the field menu, Swap in Party, a window color option (if the style guide allows it).
- Saving at inns and the *Supper's On* bridge; saving machine parts, Hull and guest missions.
- Dungeon maps in the menu.
- The bets board as a playable minigame.
- A theater for rewatching cutscenes.
- Pre-rendered movie scenes: probably never, maybe one or two for the very biggest moments.
- Fix Tilly's net (a miss costs a turn, which breaks "missing never hurts") before her fight is built.
