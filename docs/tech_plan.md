# Tech Plan: LIGHTS LEFT ON (vertical slice)

> Owner: Technical Director (proposes) · Ross (approves). ✅ **APPROVED by Ross, 2026-10-06: renderer = Compatibility (OpenGL), Option A.** Internal resolution per the style guide: 384×216.

DECISION NEEDED: Which Godot renderer do we build on?
Option A: Compatibility (OpenGL): pros: runs on older and cheaper Macs and PCs, including laptops without a gaming graphics card. Starts fast and builds small. We've already confirmed it can take screenshots in our cloud setup, so you can see progress without a build. / cons: no modern high-end lighting (global illumination, volumetric fog), which the PSX look turns off anyway.
Option B: Forward+ (Vulkan/Metal): pros: every modern Godot effect is available. / cons: needs newer graphics hardware and builds heavier, and no cloud screenshots. It also brings effects we'd only switch off.
Recommendation: A. The PSX look is deliberately simple, and A means the game runs on more of your players' computers. We can switch later if we ever need to; the shaders are written to work on both.

---

## Part 1: For Ross

**What's inside.** Each system (walking, talking, battles, menus, saving, sound) has its own folder. Every number and line of text lives in plain data files, so prices and dialogue change without touching code. The 3D world draws at a tiny PSX-sized picture, blown up with crisp chunky pixels and shaders for the wobble, warp and dither. Menus and portraits stay sharp on top.

**Testing with nobody watching.** A robot tester runs every system with no screen. It plays thousands of battles as a perfect player, a decent player, a never-presses player and Auto-Timing, and checks that fights are winnable and the right length. We can also grab screenshots in the cloud to show you progress.

**Getting builds.** You get a download link for a Windows program and a Mac app. Neither is signed at first. On a Mac, double-click it, close the warning, then go to System Settings > Privacy & Security and click "Open Anyway" (first time only). On Windows, click "More info" > "Run anyway".

---

## Part 2: For the staff

### Ground rules
- Godot 4.5.1, GDScript, static types everywhere. Project setting `debug/gdscript/warnings/untyped_declaration = Error`.
- Game logic is plain `RefCounted` classes with no nodes, no `Time` and no global `randf()`. A seeded `RandomNumberGenerator` and a clock are passed in. Scenes only show and feed the logic. *Why: the tests and the simulator can run that logic thousands of times without a screen.*
- All tunables live in `game/data/` (JSON for nested data, CSV for tables). Code never contains a stat, price, string or timing value.
- Autoloads (singletons), kept few: `DataDB`, `GameState`, `SaveManager`, `Config`, `SceneRouter`, `AudioManager`.
- Commit rule: run the tests before every commit, keep commits small, and never commit a red test suite to main.

### Folder layout (under `game/`)
- `scenes/`
  - `core/`: `main.tscn` (root), `psx_screen.tscn`, `fader.tscn`
  - `rooms/harrow/`, `rooms/road/`, `rooms/tower/`: one `.tscn` per room
  - `actors/`: player, follower, npc, field_enemy
  - `props/`: door, crate, pickup, save_lamp, switch, push_crate, traversal_spot, bell
  - `battle/`: battle scene, combatant views, backdrops
  - `ui/`: title, field menu, battle HUD, dialogue box, shop, save screen, config
  - `cutscenes/`: one scene per cutscene (AnimationPlayer staging)
  - `debug/`: `psx_test_room.tscn`, `debug_room.tscn` (left out of release exports)
- `scripts/` (by system)
  - `core/`: data_db, game_state, save_manager, save_migrations, config, scene_router, game_rng
  - `field/`: player_controller, interaction, interactable, traversal, party_follow, diorama_camera, prop_fader, door, pickup, push_crate
  - `encounter/`: field_enemy, encounter_rules
  - `dialogue/`: dialogue_runner, conditions
  - `cutscene/`: cutscene_player
  - `battle/model/`: battle_state, battle_controller, turn_order, damage, clutch_judge, press_source, status_rules, enemy_ai, rewards
  - `battle/view/`: battle_scene, combatant_view, clutch_cue, rating_popup, turn_row
  - `progression/`: progression, stat_calc
  - `inventory/`: bag, equipment, shop_logic
  - `ui/`: menu_list (shared cursor widget) plus one script per screen
  - `audio/`: audio_manager
  - `debug/`: debug_room, psx_debug_overlay
  - `tools/`: psx_post_import (glTF import script)
- `shaders/`: see The PSX look
- `data/`
  - `party/characters.json`: base stats, starting gear, skills by level
  - `party/growth.csv`: character, level, hp, juice, attack, defense, heart, speed, luck
  - `party/xp_curve.csv`: level, total_xp
  - `battle/skills.json`: party and enemy skills, with timelines and presses
  - `battle/enemies.json`: stats, AI, drops, field behavior, boss parts and phases
  - `battle/statuses.json`
  - `battle/timing_windows.json`
  - `battle/encounters.json`: groups, music, can_run, backdrop
  - `battle/formulas.json`: damage and variance constants
  - `items/items.json`: consumables and key items
  - `items/equipment.json`: weapons, armor, charms
  - `shops/shops.json`
  - `world/rooms.json`: room id → scene, area, music, autosave area
  - `world/field_tuning.json`: walk and run speed, follow spacing, camera smoothing, blink time
  - `world/placements.json`: per room: field enemies, crates and pickups with contents
  - `world/story_beats.json`: ordered beat ids
  - `dialogue/*.json`: one file per NPC or scene
  - `text/ui.json`: all menu strings
  - `audio/audio_index.json`: sound id → file, bus, loop, volume
  - `balance/feel_targets.json`: simulator targets
- `art/placeholder/` (agents only) and `art/final/` (Ross only), each with `characters/`, `enemies/`, `environments/`, `props/`, `ui/`, `textures/`; `art/final/` also has `portraits/`.
- `audio/music/`, `audio/sfx/`
- `tests/`
  - `framework/`: test_case.gd
  - `run_all.gd`
  - `unit/`, `integration/`, `sim/`, `visual/`
  - `fixtures/`: test data, old save files
- Outside `game/`: `tools/` (shell scripts for templates and builds), `builds/` (exports and screenshots; already git-ignored).

### Core systems (responsibility · data · tests)
- **DataDB:** loads and validates every file in `data/` at boot and looks things up by id.
  - Reads: all of `data/`.
  - Tests: every file parses, and every cross-reference resolves (drops → items, skills → statuses, shops → items, dialogue → speakers and portraits, rooms → scene files that exist).
- **GameState + SaveManager:** party, bag, credits, flags, story beat, opened crates, beaten bosses, play time and location, with `to_dict`/`from_dict`.
  - Save format: versioned JSON in `user://saves/` (slots 1–3 plus `auto.json`), written atomically (temp file, then rename), with a migration chain.
  - `use_custom_user_dir` so saves live in a "LightsLeftOn" folder.
  - Config (settings) is a separate file, `user://config.json`.
  - Tests: save → load round trip is identical; old save fixtures still load; auto-save fires only on area entry; Retry battle restores the snapshot taken when the fight started.
- **SceneRouter:** fades to black, frees the old room, loads the new one from `rooms.json` and places the party at a named spawn marker.
  - Battle: the field room is detached and kept in memory, the battle scene goes in, and the room is re-attached afterward.
  - Reads: `rooms.json`.
  - Tests: every door's target room and spawn exist; the field is restored exactly after a battle.
- **Diorama camera rig:** one fixed pitch, yaw and FOV per room, set on the room's `CameraRig` node. It slides to follow Red inside a `CameraBounds` box and never rotates. Cutscenes may take control and give it back.
  - Reads: `field_tuning.json` (smoothing).
  - Tests: rotation stays constant as Red moves; Red stays inside the safe frame; the camera clamps to the bounds.
- **Prop fader:** a ray from the camera to Red. Props in the `fade_occluder` group that it hits dither out (screen-door transparency, so there are no sorting bugs).
  - Tests: a prop between the camera and Red fades, and fades back when clear.
- **Player movement + interaction:** CharacterBody3D. Movement is relative to the room camera (stick tilt sets walk or run). An InteractProbe area picks the nearest `Interactable` (talk / examine / take / open / climb) and shows its icon. `TraversalSpot` plays a scripted climb or hop.
  - Reads: `field_tuning.json`.
  - Tests: speeds, camera-relative direction, nearest-target choice, and that the right icon shows.
- **Party follow:** Red drops breadcrumbs, and followers walk to fixed distances along the trail. They are on a collision layer that ignores the party, so they never block Red.
  - Tests: spacing holds; followers catch up after a teleport or room load; Red is never blocked.
- **Doors / pickups / puzzles:** `Door` (target room and spawn, optional `requires` key item or flag, plus a locked-message key), `Pickup` and crate (contents by id from `placements.json`, opened ids stored in GameState), switch, push crate, bells.
  - Tests: a locked door refuses without the card and opens with it; a pickup is granted once and stays taken after save and load; the bell order puzzle.
- **NPC / dialogue runner:** plays a dialogue file line by line.
  - Supports a portrait and expression, a text blip, Red gestures (never a text box for Red), yes/no as thumbs-up or head shake, and set-flag and give-item actions.
  - NPC `variants` are picked by condition; the first match wins.
  - Text speed, fast-forward and auto-advance come from Config.
  - Reads: `data/dialogue/`.
  - Tests: variant choice per story beat, branching, actions applied, and no orphan `next` ids.
- **Cutscenes:** staging lives in each cutscene scene's AnimationPlayer. Method tracks call `say(dialogue_id)`, which pauses the animation until the line closes. Holding Start skips to the end state, and the cutscene declares the flags it sets.
  - Tests: skipping sets the same flags as watching to the end.
- **Field enemies + encounter start:** states are patrol, chase and give-up, with speeds from the enemy's `field` block. Touching Red triggers `EncounterRules.first_turn()` (party / enemies / normal, from facing vectors), the static transition and the battle. After a fight Red blinks and can't be caught; regular enemies respawn when the room reloads, and bosses and story fights are tracked with flags.
  - Reads: `enemies.json`, `placements.json`, `encounters.json`.
  - Tests: first-turn cases, blink immunity, respawn vs. bosses staying beaten.
- **Battle system:**
  - **Turn order:** sort by Speed every round. Ties go party first, then by slot. The portrait row shows this round and the next.
  - **Commands:** Attack, Skills, Items, Defend, Run. Run works only if `can_run`; Smoke Bomb is the same rule.
  - **Actions are timelines in milliseconds:** wind-up, `cue_ms`, impact. The view plays them in real time; the simulator skips through them instantly.
  - **Clutch judged by the clock, not frames:** at action start we record `t0 = Time.get_ticks_usec()`, and the cue is due at `t0 + cue_ms`. Presses are timestamped in `_input()`, with `input_devices/buffering/agile_event_flushing` turned on.
    - `delta = press − cue − Config.timing_offset`. The judge (`ClutchJudge`) is a pure function of delta, the window and its modifiers.
    - The first press after `listen_before_ms` is the one judged, so mashing doesn't work.
    - The flash, ding and "!" are scheduled from the same `cue_ms`.
    - `PressSource` interface: Human, Auto-Timing (always Rad), and simulator players.
  - **Press types:** tap; hold-and-release (judged on release, and the hold must start by `hold_by_ms`); string (each cue judged on its own).
  - **Juice:** cost per skill; gain on Rad or better and on Defend (values in data).
  - **Status effects:** data-driven ticks and flags (`hp_loss_pct`, `blocks_skills`, `random_target_chance`, `duration`, `down`).
  - **Enemy AI:** a weighted list of actions with conditions, read from the enemy's data.
  - **Boss extras:** `parts` (Hushmaster legs in pairs), `phases` (Kasp on foot) and `cue_scramble` (fake cues; the real window never moves).
  - **Rewards:** XP, credits, drops rolled with Luck, then progression level-ups, returned as a report for the victory screen.
  - Tests: listed under Testing.
- **Progression:** the XP curve, growth per level, skills learned by level, and the bench-XP and catch-up rules (built now, switched on later).
  - Reads: `characters.json`, `growth.csv`, `xp_curve.csv`.
  - Tests: XP thresholds, stat gains, the skill learned at the right level, bench and catch-up.
- **Menus / UI:** one shared `MenuList` widget (cursor memory, tick sound, controller, keyboard and mouse) used by every menu. The title screen, field menu, status, equip, battle HUD, shop, save screen and config are thin scenes over the logic classes.
  - Reads: `text/ui.json`.
  - Tests: cursor wrap and memory, equip, buy and sell flows, config saved and reloaded.
- **Shops / inventory / equipment:** `Bag` (99 cap; key items kept separate and can't be sold or dropped), `Equipment` (owner lock; heavy armor for Otis only), `StatCalc` (base + growth + boosters + gear), `ShopLogic` (buy, sell at half price).
  - Reads: `items.json`, `equipment.json`, `shops.json`.
  - Tests: every item in the design doc's slice list, the Camp Stove working only at save lamps, charms blocking their status.
- **Audio manager:** buses are Master, Music, SFX, UI and Blip. `play_music(id)` crossfades; `play_sfx(id)` uses a voice pool. A missing file plays silence and logs a warning, so missing audio never blocks the build.
  - Reads: `audio_index.json`.
  - Tests: every sound id used in data exists in the index; volume settings map to the buses.
- **Debug room** (debug builds only): warp to any room, start any encounter, set flags and level, give items.

### Data formats (all numbers are placeholders)
**Enemy** (`battle/enemies.json`, one entry):
```json
{
  "id": "signals_grunt",
  "name": "Signals Grunt",
  "level": 2,
  "stats": {"hp": 38, "juice": 0, "attack": 9, "defense": 5, "heart": 3, "speed": 6, "luck": 4},
  "xp": 12, "credits": 25,
  "drops": [{"item": "ration_bar", "chance": 0.25}],
  "status_resist": {"noise_ticket": 0.0},
  "flee_at_hp_pct": 15,
  "ai": [
    {"skill": "grunt_swing", "weight": 3},
    {"skill": "grunt_write_ticket", "weight": 1, "if": {"target_lacks_status": "noise_ticket"}}
  ],
  "field": {"walk_speed": 2.0, "chase_speed": 3.2, "sight_m": 6.0, "give_up_s": 4.0},
  "model": "res://art/placeholder/enemies/signals_grunt.tscn"
}
```
**Skill** (`battle/skills.json`, one entry):
```json
{
  "id": "heave_ho",
  "name": "Heave-Ho",
  "user": "otis",
  "learn_level": 1,
  "juice_cost": 8,
  "target": "one_enemy",
  "formula": {"stat": "attack", "power": 1.3},
  "anim": "heave_ho",
  "timeline_ms": {"windup": 400, "impact": 1250, "end": 1700},
  "presses": [{"type": "hold_release", "hold_by_ms": 300, "cue_ms": 1200, "window": "standard"}],
  "on_rating": {
    "miss":        {"power_mult": 1.0, "splash": "random_other_enemy", "splash_mult": 0.4},
    "nice":        {"power_mult": 1.2, "splash": "random_other_enemy", "splash_mult": 0.6},
    "rad":         {"power_mult": 1.4, "splash": "random_other_enemy", "splash_mult": 0.8},
    "totally_rad": {"power_mult": 1.6, "splash": "random_other_enemy", "splash_mult": 1.0, "apply_status": "stunned"}
  }
}
```
**Item** (`items/items.json`, one entry):
```json
{
  "id": "ration_bar",
  "name": "Ration Bar",
  "kind": "consumable",
  "icon": "food", "icon_tint": "#c8a060",
  "price": 20,
  "use": {"in_field": true, "in_battle": true, "target": "one_ally", "effect": {"heal_hp": 60}},
  "desc": "Small heal. Tastes like the wrapper."
}
```
**Dialogue line** (`dialogue/*.json`, one line):
```json
{"id": "dock_04", "speaker": "otis", "portrait": "otis_grin", "blip": "otis", "text": "Nothing personal.", "next": "dock_05"}
```
Red's line: `{"id": "dock_05", "speaker": "red", "gesture": "thumbs_up", "next": "dock_06"}`. NPC variants: `{"npc": "dockhand", "variants": [{"when": {"beat_at_least": "tower_cleared"}, "start": "dockhand_after"}, {"start": "dockhand_default"}]}`.

**Timing windows** (`battle/timing_windows.json`). Half-widths in ms around the cue: Nice ≈ ¼ s total, TOTALLY RAD ≈ 1/10 s total.
```json
{
  "windows": {
    "standard": {"nice_ms": 125, "rad_ms": 80, "totally_rad_ms": 50},
    "block":    {"nice_ms": 125, "rad_ms": 80, "totally_rad_ms": 50}
  },
  "listen_before_ms": 400,
  "modifiers": {"wide_windows": 1.5, "defending_block": 1.25, "butterfingers": 0.75, "fired_up": 1.25},
  "juice_gain": {"rad": 2, "totally_rad": 4},
  "block_reduction": {"nice": 0.25, "rad": 0.5, "totally_rad": 1.0},
  "payback_power": 0.8
}
```

### The PSX look (Godot 4)
- **Low internal resolution:** `scenes/core/psx_screen.tscn` holds a SubViewport (the 3D world) at an internal size such as 384×216 (style guide recommendation), 320×240, 426×240 or 480×270 (the style guide picks). A TextureRect shows it scaled up with nearest-neighbor filtering, and the post shader runs on that TextureRect.
- **UI and portraits** draw on a CanvasLayer above at full window resolution (base 1280×720, stretch mode `canvas_items`), so text and anime portraits stay sharp.
- **Shader files (`game/shaders/`):**
  - `psx_common.gdshaderinc`: shared functions. **Vertex snap:** compute the clip position, snap xy/w to the internal-resolution grid, write `POSITION`. **Affine warp:** pass `UV*w` and `w` as varyings and divide in `fragment()` (strength uniform). **Per-vertex fog**.
  - `psx_lit.gdshader`: the default for everything. `render_mode vertex_lighting` (Gouraud, period-correct), albedo `filter_nearest`.
  - `psx_unlit.gdshader`: emissive and lamp glows, UI-in-world, battle effects.
  - `psx_fade.gdshader`: `psx_lit` plus dithered screen-door fade for occluding props.
  - `psx_post.gdshader` (canvas_item): 4×4 Bayer dither and 15-bit color (5 bits per channel), both toggleable.
  - `screen_static.gdshader` (canvas_item): the radio-static battle transition. `fader.tscn` is plain fade to black.
- **Global shader uniforms** (in project.godot, so one setting tunes the whole game): `psx_snap_res`, `psx_jitter_strength`, `psx_affine_strength`, `psx_fog_color`, `psx_fog_near`, `psx_fog_far`.
- **Project defaults:**
  - Canvas texture filter set to Nearest.
  - `[importer_defaults]`: textures lossless with no mipmaps (VRAM compression smears 64 px textures); scenes use `import_script/path = res://scripts/tools/psx_post_import.gd`.
  - The import script swaps imported glTF materials for `psx_lit` (or `psx_unlit` when the material name ends in `_unlit`), keeps the texture, and makes `idle`/`walk`/`run` animations loop.
- **Art conventions** (to confirm in the style guide after Milestone 1): glTF `.glb`, 1 unit = 1 m, origin at the feet, model faces Blender −Y (Godot +Z), textures 64–256 px PNG. Big floors are subdivided so the affine warp doesn't swim.
- Verified in our container: the Compatibility renderer compiles `vertex_lighting`, global uniforms and the affine varyings, and renders under Xvfb with software GL.

### Testing
- **Runner:**
  - Command: `godot --headless --path game -s res://tests/run_all.gd` (run `godot --headless --path game --import` once first; the session hook already does).
  - `run_all.gd` extends SceneTree. It finds `tests/{unit,integration,sim}/**/test_*.gd`, and each file extends `tests/framework/test_case.gd`.
  - It runs every `test_*` method (`await` allowed, for scene tests), prints PASS/FAIL per test and a summary, and exits with code 0 or 1. Filter with `-- --only=battle`.
  - Verified: autoloads are present in `-s` mode and exit codes reach the shell.
- **Scene tests:** instantiate under `root`, drive input with `Input.action_press()` or by calling methods directly, and `await physics_frame`.
- **Battle simulator** (`tests/sim/battle_sim.gd`, CLI `tests/sim/run_sim.gd -- --encounter=ID --player=good --runs=1000 --seed=1`):
  - Runs `BattleController` with no view and a virtual clock.
  - Press players: **perfect** (always on the cue), **good** (normal spread around the cue, ~40 ms), **miss** (never presses) and **Auto-Timing**.
  - A simple command policy: attack, heal below 40% HP, use the signature move when Juice allows.
  - A **walkthrough mode** fights every slice encounter in order, with level-ups and loot.
  - Checks against `feel_targets.json`: win rate per player type, regular fights 1–3 min (timeline ms plus ~2 s menu time per command), Kasp 5–8 min, level ~6 and ~1,500 credits at Kasp.
  - The suite runs 200 fights per check; the full 5,000 runs before each milestone.
- **Visual capture** (not a pass/fail gate beyond "renders, no shader errors"): `xvfb-run -a godot --path game --rendering-driver opengl3 -s res://tests/visual/capture.gd` saves PNGs of the test rooms to `builds/screenshots/` for WIP sharing with Ross.
- **Every system must test:**
  - its rules as pure functions;
  - its data: ids resolve, and values are in range;
  - save/load of any state it owns;
  - one scene smoke test (it loads and has its required nodes).
- **Battle must also test:**
  - judge boundaries for every rating and modifier, plus the offset;
  - press types: hold too late = miss, string judged per cue;
  - first press counts, so mashing fails;
  - Auto-Timing = Rad; the scrambled cue keeps the real window;
  - missing never does worse than no Clutch at all;
  - turn order with ties;
  - each status effect;
  - AI conditions;
  - Payback only on melee perfect blocks;
  - Run disabled on bosses;
  - rewards totals and level-ups.
- Everything random takes a seed, so every failure can be reproduced.

### Milestone 1: PSX test room + diorama camera + placeholder Red pipeline
Goal: Ross walks a placeholder Red around a PSX diorama room on his own Windows or Mac computer and can flip each effect on and off. What he says becomes the style guide's PSX rendering rules.

| # | Task | Files | Done means |
|---|---|---|---|
| 0 | Ross approves this plan and the renderer (decision at top). Producer logs it. | docs/decisions.md | Logged with date. |
| 1 | Project setup: name "Lights Left On", the chosen renderer, canvas filter Nearest, untyped-declaration = Error, agile input flushing, custom user dir, input map (move ×4, confirm, cancel, menu, start), window 1280×720 `canvas_items`, `import_etc2_astc=true` (needed for the Mac build), `[importer_defaults]`, global shader uniforms, autoload stubs. | `game/project.godot`, `scripts/core/*.gd` | `tests/unit/test_project_settings.gd` passes. |
| 2 | Test runner and framework. | `tests/run_all.gd`, `tests/framework/test_case.gd`, `tests/unit/test_runner_selfcheck.gd` | Headless run exits 0; a deliberately failing test exits 1 (then removed). |
| 3 | DataDB minimal: load and validate JSON/CSV; first data file. | `scripts/core/data_db.gd`, `data/world/field_tuning.json` | `tests/unit/test_data_db.gd`: all data parses; a bad file is reported by name. |
| 4 | PSX shaders. | `shaders/psx_common.gdshaderinc`, `psx_lit`, `psx_unlit`, `psx_fade`, `psx_post` (`.gdshader`) | Test room renders under Xvfb with no shader errors; each effect visibly changes the screenshot when toggled. |
| 5 | PSX screen: SubViewport world + scaled nearest display + post shader + sharp UI layer. | `scenes/core/psx_screen.tscn`, `scenes/core/main.tscn` | Internal resolution switchable at runtime between 384×216, 320×240, 426×240 and 480×270; UI text stays sharp. |
| 6 | Test room: floor and two back walls, checker textures at 64/128/256 px, one large unsubdivided floor quad (shows the warp), a tall pillar (fade test), a lamp, fog, and a bigger wing so the camera has to slide. | `scenes/debug/psx_test_room.tscn`, `art/placeholder/textures/*.png` | Loads headless; every mesh uses a psx shader (`tests/integration/test_psx_materials.gd`); no texture over 256 px. |
| 7 | Diorama camera rig + bounds. | `scripts/field/diorama_camera.gd` | `tests/integration/test_diorama_camera.gd`: never rotates, keeps Red in the safe frame, clamps to the bounds. |
| 8 | Prop fader. | `scripts/field/prop_fader.gd` | `tests/integration/test_prop_fader.gd`: the pillar fades in front of Red and returns when clear. |
| 9 | Player controller (camera-relative walk and run). | `scripts/field/player_controller.gd`, `scenes/actors/player.tscn` | `tests/integration/test_player_move.gd`: speeds from data, direction relative to the camera, collides with walls. |
| 10 | Placeholder Red, made the way Ross will: a scripted Blender blockout (portable Blender run headless) of ~300 tris, chibi proportions, a simple rig, `idle`/`walk`/`run`, one 128 px texture, exported with the glTF settings we'll give Ross. Fallback if Blender can't run: build it in Godot and write the `.glb` with `GLTFDocument`. | `tools/blockout_red.py`, `art/placeholder/characters/red/red_blockout.glb` | The file is in place, made only from shapes (placeholder rule). |
| 11 | Import script. | `scripts/tools/psx_post_import.gd` | `tests/integration/test_red_import.gd`: psx materials applied, nearest filter, 3 looping animations, height and tri count inside the test budget. |
| 12 | Debug overlay: toggle jitter, warp, dither, color depth, fog and vertex lighting; cycle resolutions; switch the camera between perspective FOV 30/45 and orthographic, so Ross can compare. | `scripts/debug/psx_debug_overlay.gd` | Every toggle works in the build; the key list is on screen. |
| 13 | Screenshot capture for WIP sharing. | `tests/visual/capture.gd` | PNGs (all effects on and all off, each resolution) in `builds/screenshots/`, shown to Ross with the studio log entry. |
| 14 | Export presets and template script (see Exports). | `game/export_presets.cfg`, `tools/get_export_templates.sh`, `tools/build.sh` | `tools/build.sh` produces `builds/windows/LightsLeftOn.exe` and `builds/mac/LightsLeftOn.zip` with no errors. |
| 15 | Ross playtest. | Download link | Ross runs the build on his own computer, walks Red around, tries the toggles, and gives notes. The Taste Keeper logs them, and the style guide's PSX rules and art budgets are drafted from them. |

### Exports
- `game/export_presets.cfg` is committed. Godot keeps signing secrets in `.godot/`, which is ignored.
  - **"Windows Desktop":** x86_64, PCK embedded, output `builds/windows/LightsLeftOn.exe`. No custom .exe icon for now (that needs rcedit and Wine).
  - **"macOS":** universal (Intel + Apple Silicon), bundle id `com.circlesoft.lightslefton`, codesign "Built-in (ad-hoc only)" so it runs on Apple Silicon, no notarization, output `builds/mac/LightsLeftOn.zip` (.dmg needs a Mac host).
  - Both exclude `scenes/debug/*` from release exports.
- **Templates:** not installed in the cloud container. `tools/get_export_templates.sh` downloads `Godot_v4.5.1-stable_export_templates.tpz` (**1.36 GB**) to a scratch dir. It extracts only `version.txt`, the Windows x86_64 templates and `macos.zip` into `~/.local/share/godot/export_templates/4.5.1.stable/`, then deletes the download.
  - Run it on build days only, not in the session hook (it would add 1.4 GB to every session).
- **Build:** `tools/build.sh` runs `godot --headless --path game --export-release "<preset>" <abs path in builds/>` for both presets, after the test suite passes.
- `builds/` is already in `.gitignore`. Builds reach Ross as a download (proposed: a GitHub Release on the game's repository, as a private attachment).

### Open questions for other staff (not for Ross yet)
- **Creative Director:** Heave-Ho's perfect release "stuns", and Porch Light's tap "blinds". Neither Stun nor Blind is in the slice status list (Burnt Toast, Noise Ticket, Wobbly, Down). We need a name and rule for each, or a different bonus. The skill example above uses `stunned` as a stand-in.
- **Technical Artist:** internal resolution and aspect ratio, perspective vs. orthographic, FOV, Red's height in meters, and poly and texture budgets. All go in the style guide after the Milestone 1 playtest.
- **Producer:** the playbook says each game gets its own repository (F10), but the slice is being built in `circlesoft/game/`. Confirm where the game code should live before Milestone 1 starts.
