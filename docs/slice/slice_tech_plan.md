# Vertical slice tech plan

> **For Ross:** this is the builders' plan for the slice: who builds which file, how the game moves from the title screen through the night market and the junkyard to the Kasp fight, and how the hacks, robots and boss are built so they can be tested and reused for a 10-hour game. Three questions for you are at the top. Everything else is the studio's job and needs nothing from you. Every number in it is a starting guess you change by playing.

> Owner: Technical Director. Status: **proposed 2026-10-09; binding for builders once the three decisions below are answered** (until then, builders use the recommended option, which is built as a switch so nothing is wasted). Sources: docs/decisions.md (2026-10-09: slice shape approved; robot finale answered C), docs/slice/slice_pitch.md, docs/pivot/combat_api.md (still the combat contract; this file extends it for the slice), docs/pivot/robot_scale_test.md, docs/pivot/kh_combo_design.md, docs/pivot/enemy_ai_design.md, docs/pivot/buildability.md, docs/maps/harrow_landing.md, docs/maps/road_and_tower.md (the Hushmaster's turn-based design). If this file and combat_api.md disagree about the slice, this file wins. Don't change it quietly: add to "Changes" at the bottom.

---

## Decisions for Ross

DECISION NEEDED: How does Red pick which hack the second button fires?
Option A: **Pick, then fire.** The HUD shows the selected hack; d-pad left/right (keyboard: 1 to 4 or the mouse wheel) changes it; the hack button fires it. Like Kingdom Hearts' shortcut list. — Pros: you always know what you'll get; Reboot (which spends the whole battery) never fires by accident. / Cons: one more thing to manage mid-fight.
Option B: **Hold and press.** Hold the hack button and press attack, jump, dash or lock-on to fire one of the four. — Pros: all four hacks on instant reach. / Cons: chords are harder to learn and to do in the air.
Option C: **Automatic, like the combo.** The hack button picks by situation: Overclock if something hijackable is in front of Red, EMP if three or more enemies are close, Zap Drone otherwise; Reboot only by holding the button. — Pros: matches the one-button combo you liked. / Cons: you can't choose; it may guess wrong.
Recommendation: **A as the default, with C built as a feel-panel switch,** so you can try both in the graybox build and pick by playing.

DECISION NEEDED: What happens when Red is knocked out in the slice?
Option A: **Continue from the room's entrance** with the health and battery she had when she walked in (Kingdom Hearts style). Bosses restart at the arena door, and in the robot round you restart the robot round, already docked. — Pros: fast, no lost progress, no grinding. / Cons: little sting.
Option B: **Back to the last save terminal.** — Pros: more tension. / Cons: replaying rooms, which you've called grind.
Option C: **A, plus a small cost** (lose a few credits, as Mega Man Legends does). — Pros: a little sting without replaying. / Cons: the credit loss needs balancing against the shops.
Recommendation: **A.** The slice is about feel; restarting from the door keeps you playing.

DECISION NEEDED: How does Red talk to people and use things?
Option A: **The attack button does it** when a prompt is showing and no enemy is close (Kingdom Hearts uses one button for both). In town, where there's no fighting, the attack button only talks. — Pros: no new button; a controller has none spare. / Cons: in a dungeon, a swing near a door or a terminal could talk instead of attack if the nearest enemy is far.
Option B: **Its own button** (keyboard E; pad: right trigger). — Pros: never confused with attacking. / Cons: a button you only use for talking, on a part of the pad that fights don't use.
Recommendation: **A.** It is how the games you named do it, and the "no enemy close" distance is a number you can tune.

*Answered by Ross today (logged in docs/decisions.md by the Producer):* the robot finale is option C. Giant-robot battles live at the ends of levels and in boss fights, and some bosses are fought on foot first, then in robots. Section 6 plans the slice boss that way: the Hushmaster on foot, then Kasp's giant junk mech against Red's loader docked into the colossus.

---

## 0. The slice in one picture

```
Title ─ New Game ─▶ Hideout (over the repair shop, save + rest)
                        │
                        ▼
               Night market (8 or 9 rooms from the Harrow graybox, diorama camera, no fighting)
               talk, shops, job board (the main job opens the junkyard)
                        │
                        ▼
               Junkyard, on foot (J1 to J4: free camera, fights, hacks, hack targets, save terminal)
                        │  J4: Red hacks the loader awake
                        ▼
               Junkyard, in the loader (J5, one big room: smash through)
                        │  Red climbs out at the arena gate; the loader stays parked there
                        ▼
               Kasp's arena (one big scene, two scales)
               Phase 1 on foot: the Hushmaster (hack out the leg relays)
               Transition: Kasp escapes into a giant junk mech built from the yard;
                           Red boards the loader, docks into the colossus
               Phase 2 robot vs robot at colossus scale
                        │
                        ▼
               Ending: back to the market (walk home), then the hideout
```

**General pattern (Ross, 2026-10-09):** giant-robot fights are saved for the ends of levels and for boss fights; some bosses start on foot and then go to robots. The tech supports this everywhere, not just here: a boss is a list of **phases**, each with a **form** (`red`, `small`, `huge`), and a phase change can play a boarding or docking sequence. A level's end can be a robot stage built from the same parts. Midway robot moments (the loader in J4/J5) stay possible but are the exception.

**Time, honestly.** The pitch put Loop A at 4 to 5 weeks and the robot dungeon at 1 to 2 weeks more. Ross's answer moves the docking from a set-piece before the boss into the boss fight, and adds a giant enemy that fights at colossus scale. That is new work the robot test never did: a 40 m enemy with its own attack patterns, telegraphs readable from 75 m away, a scene that switches scale mid-fight, and a retry point inside the fight. The colossus set-piece it replaces paid for part of it. **Estimate: about 6 to 8 weeks of studio time for the whole slice, about 1 week more than the shape approved this morning.** The robot round alone is about 1.5 to 2 weeks. Ross's art sets the calendar more than our code: we build on blockouts and swap his models in as they arrive.

---

## 1. Who owns what (don't edit another owner's files; ask)

All paths are under `game/` unless they start with `docs/`. "New" unless marked. Shared, read-only for everyone (ask the owner): `GameState`, `Config`, `DataDB`, `AudioManager`, `SaveManager`, `SceneRouter`, `PsxScreen`, `LookProfiles`, `InputRemap`, `PlayerMotion`, `CombatDirector`, `ActionPlayer`, `ActionEnemy`, `LockOn`, `OrbitCamera`.

| Owner | Files |
|---|---|
| **Gameplay Programmer** (also the Integrator) | `scripts/core/game_mode.gd` (pure: slice / sandbox / classic, which data and save folder each uses); edits to `scripts/core/main.gd` (slice boot), `scene_router.gd` and `save_manager.gd` (data id and save folder come from the mode), `game_state.gd` (new save fields, one migration step); `project.godot` (feature tag `slice`, input sorting) and two "Slice Windows / Slice macOS" export presets. `scripts/slice/action_room.gd` (the one room script for every slice room), `scripts/slice/hero_link.gd` (the hero contract), `scripts/slice/room_snapshot.gd` (pure), `scripts/slice/retry_flow.gd`, `scripts/slice/robot_stage.gd` (robots in a level), `scripts/slice/hack_targets/`: `hack_target.gd`, `hack_door.gd`, `hack_crane.gd`, `drone_line.gd`, `hack_terminal.gd`. Edits for the hero contract in `scripts/field/*`, `scripts/works/*`, `scripts/dialogue/dialogue_runner.gd`, `scripts/encounter/map_enemy.gd` (type hints only). Edits to `action_player.gd` (town mode, death mode, contract methods) and `lock_on.gd` (extra lock targets), coordinated with the Combat Programmer. Data: `data/slice/slice.json` (new game place, features, retry rule), `data/combat/player_action.json` (`death` and `town` blocks). Tests: `unit/test_game_mode.gd`, `test_room_snapshot.gd`; `integration/test_hero_contract.gd`, `test_action_room.gd`, `test_slice_retry.gd`, `test_slice_save.gd`, `test_robot_stage.gd`, `test_hack_targets.gd`, `test_town_systems.gd`. |
| **Combat Programmer** | Pure: `scripts/combat/model/hack_battery.gd`, `hack_rules.gd`, `hack_selector.gd` (option C), `boss_brain.gd`, `boss_phases.gd`, `features.gd`. Nodes: `scripts/combat/hacks/hack_caster.gd`, `zap_drone.gd`, `emp_pulse.gd`, `overclock_link.gd`, `hijackable.gd`; `scripts/combat/enemies/signals_drone.gd` (flying), `wall_turret.gd`; `scripts/combat/boss/boss_fight.gd` (phases, forms, transitions, per-phase retry), `boss_part.gd` (relays, mech parts), `hushmaster.gd`, `junk_mech.gd`. Edits: `hitbox.gd` (new `ring` and `beam` shapes), `combat_director.gd` (battery, `report_hack_hit`, hack lockout, feature switches), `action_enemy.gd` and `enemy_brain.gd` (hijacked targeting, scale form). Code schemas for the data files the Combat Designer fills. Tests: `unit/test_hack_battery.gd`, `test_hack_rules.gd`, `test_hack_selector.gd`, `test_boss_brain.gd`, `test_boss_phases.gd`, `test_features.gd`; `integration/test_hacks.gd`, `test_hijack.gd`, `test_drone_turret.gd`, `test_hushmaster.gd`, `test_junk_mech.gd`, `test_boss_transition.gd`; `sim/test_hack_bots.gd`, `test_boss_bots.gd`. |
| **Combat Designer** | Numbers and rules as data: `data/combat/hacks.json`, `data/combat/bosses/hushmaster.json`, `data/combat/bosses/junk_mech.json`, the slice enemy entries in `enemies.json` and their sets in `moves.json` (drone, turret, Signals cop, Hushmaster, junk mech, Red's four hack casts), the `hacks` and `boss` groups in `feel.json`, `data/slice/encounters.json`, shop stock `data/shops/market_*.json` (Equipment & items is Level 2: decide, then show Ross). Design notes: `docs/slice/hacks_design.md`, `docs/slice/boss_design.md`, `docs/slice/enemy_roster.md`. |
| **Animator/Rigger** | Red's four hack clips from the free Quaternius library (no new authored clips, Ross 2026-10-08) and their keys in `data/animation/red_clip_keys.json`; Kasp's blockout rig and clips; clips on the junk mech blockout (same bone names, so Red's set fits, as with the robots); townsfolk idle, talk and walk on the NPC blockout. `data/animation/retarget_kasp.json`, `retarget_junk_mech.json`, `retarget_townsfolk.json`. Test: `integration/test_slice_rigs.gd`. |
| **Technical Artist** | Placeholder models in `art/placeholder/` only: the Hushmaster blockout (8 legs in 4 pairs, 4 relay boxes, dish, seat), the giant junk mech blockout (about 40 m, on Red's bone names), Kasp blockout, hack targets (wall turret, fuse box, crane, drone line, terminal), the Zap Drone. FX: `scripts/combat/fx/hack_fx.gd`, `quiet_hours_fx.gd`, `part_break_fx.gd`, `scale_switch_fx.gd`; additions to `data/combat/fx.json`. Looks: `market_ps2` and `junkyard_ps2` profiles in `data/world/look_profiles.json`; market and junkyard dressing generators (`scripts/tools/make_market_dressing.py`, `make_junkyard_dressing.py`). Tests: `integration/test_slice_blockouts.gd`; screenshots `tests/visual/capture_slice.gd` → `docs/screenshots/slice_*.png`. |
| **UI Programmer** | `scripts/ui/slice/`: `action_hud.gd` (binds to any combat host; the sandbox HUD's parts reused), `hack_panel.gd` (battery, selected hack, lockout fizz), `boss_bar.gd` (health, relay pips, phase), `radio_bark.gd` (Vela's voice in Red's ear: portrait and a line, doesn't stop play), `continue_screen.gd`, `slice_pause.gd` (Resume, Items, Config, Quit to title), `location_card.gd`; scenes in `scenes/ui/slice/`; `data/ui/slice_ui.json`, `data/text/slice_ui.json`; title screen in slice mode (no title text yet: "untitled"); shop and field menus on the hero contract (type hints). Tests: `integration/test_action_hud.gd`, `test_continue_screen.gd`, `test_slice_pause.gd`, `test_slice_shop.gd`. |
| **Level Designer** (new for the slice) | Layout docs `docs/maps/night_market.md`, `docs/maps/junkyard.md`, `docs/maps/kasp_arena.md`; room generators `scripts/tools/make_market_rooms.py` (starts as a copy of `make_harrow_rooms.py`), `make_junkyard_rooms.py`, `make_kasp_arena.py`; scenes `scenes/slice/market/*.tscn`, `scenes/slice/junkyard/*.tscn`, `scenes/slice/arena/kasp_arena.tscn`; data `data/slice/rooms.json`, `data/slice/placements.json` (pickups, NPC spots, hack targets, enemy spawns), `data/slice/story_scenes.json` (staging of scenes; the words are the Writer's), `data/slice/robot_rooms/*.json`, `data/slice/jobs.json` (structure; the words are the Writer's). Test: `integration/test_slice_rooms.gd` (every door, spawn and placement resolves). |
| **Audio Designer** | Placeholder sounds `audio/sfx/placeholder/hack_*.wav`, `boss_*.wav`, `mech_*.wav`; ambience and music stand-ins for the market, the junkyard and both boss phases; the new ids in `data/audio/sfx.json` (append only); rows in `docs/audio_requests.md`. Test: `unit/test_audio_slice_sfx.gd`. |
| **Writer** | Placeholder then final words: `data/dialogue/market.json`, `junkyard.json`, `kasp_fight.json` (barks and spec recitals), `vela_radio.json`; the words in `data/slice/jobs.json` and on Kasp's memo posters; `data/text/slice_story.json`. Final text goes to Ross (Dialogue & writing is Level 0). |
| **QA Tester** | `unit/test_slice_data.gd` (every id in every slice file resolves), `integration/test_slice_smoke.gd`, `sim/test_slice_playthrough.gd` (the bot run, section 8), `tests/fixtures/slice/route.json`; reviews every builder's tests; `docs/bug_log.md`. |
| **Playtester** | Feel and pacing reports in `docs/playtests/slice_*.md` (reports, not fixes). |

---

## 2. Scene and flow architecture

### 2.1 Three ways to boot, one project

`GameMode` (pure) says which game is running and which data and save folder it uses:

| Mode | How it starts | Rooms data | Saves go to | Notes |
|---|---|---|---|---|
| `slice` | **default** after VS-3 (the editor's Play button switches to it at VS-35); feature tag `slice` in the slice export presets | `data/slice/rooms.json` | `user://slice_saves/` | The game Ross plays from now on. |
| `sandbox` | feature `sandbox` or `-- --sandbox` (as today) | (none) | `user://feel/` as today | Unchanged; the editor's Play button keeps booting it until the slice graybox build (VS-35), then switches to the slice. |
| `classic` | `-- --classic` | `data/world/rooms.json` | `user://saves/` | The shelved turn-based game, untouched, so its 1,400-odd tests keep passing. Not deleted. |

`SceneRouter` and `SaveManager` already keep their data id and folder in one place each; those become values set by the mode instead of constants. The old game's defaults stay the defaults inside tests, so no old test changes. *Why this matters for the game: the slice can't break the shelved game, and Ross's slice saves never mix with old ones.*

### 2.2 The tree while playing

```
Main
├── PsxScreen (3D picture at full window size, look profile per room)
│   └── ActionRoom  (one at a time; SceneRouter swaps it with the dithered fade)
│       ├── Level (generated scene: floor, walls, props, Spawns, Placements)
│       ├── Hero: ActionPlayer (Red; Ross's model, the sandbox controller)
│       ├── Camera: DioramaCamera (town rooms) or OrbitCamera + LockOn (dungeon and arena rooms)
│       ├── CombatDirector (every room, even in town: hacks, HUD and FX bind the same way everywhere)
│       ├── CombatFx, DialogueRunner, PlayerInteractor, StoryDirector, InteractPrompt
│       └── RobotStage (only in rooms whose data has robots)
└── UI (persistent across rooms): ActionHud, RadioBark, ContinueScreen, SlicePause, LocationCard
```

**`ActionRoom`** is the one script for every slice room. It reads the room's entry in `data/slice/rooms.json`:

```json
"junk_j2": {
  "name": "Scrap Canyon",
  "scene": "res://scenes/slice/junkyard/junk_j2.tscn",
  "kind": "dungeon",
  "camera": "orbit",
  "combat": true,
  "look_profile": "junkyard_ps2",
  "form": "red",
  "robots": "",
  "checkpoint": true,
  "autosave": false,
  "music": "junkyard",
  "spawns": ["from_j1", "from_j3"],
  "default_spawn": "from_j1"
}
```
`kind`: `town` / `dungeon` / `arena`. `camera`: `diorama` / `orbit`. `combat`: attack and hack buttons live, enemies spawn. `form`: what Red is when she walks in (`red` / `small` / `huge`). `robots`: `robot_rooms/<id>.json` if the room has robots. `checkpoint`: a death here continues from this room's entrance.

It exposes the same **combat host** methods the sandbox does, so the sandbox HUD, FX and bots bind to a slice room unchanged: `get_director()`, `get_player()`, `get_lock_on()`, `get_camera()`, `get_feel()`, `screen_pos_of(actor_id, point)`, `get_ui_parent()`, plus `get_room_id()`, `get_robot_stage()`. The sandbox keeps its own `CombatSandbox` script; nothing in it changes.

*Why this matters for the game: one room script means a fix or a feature lands in every room at once, and a new dungeon is data plus a generated scene, not new code.*

### 2.3 Moving between rooms

- Doors call `SceneRouter.go_to(room, spawn)` exactly as in the old game (dithered fade, about 0.25 s each way). **No streaming in the slice:** each room is a scene; big spaces (the loader run, the arena) are one large scene each. Fades between rooms are how Mega Man Legends did it and keep every room testable on its own. If the fades feel slow, the router can preload the next room while Red walks toward a door (`ResourceLoader.load_threaded_request`), a small add-on later.
- **What carries from room to room** lives in `GameState` (session, not only saves): Red's health, the battery charge, the equipped sword, the current form (`red` / `small` / `huge`) and flags. `ActionRoom` reads them on entry and writes them on exit. A room whose data says `form: small` spawns Red already in the loader (`RobotStage.place_in(form)`, new; it skips the boarding sequence).
- The HUD stays up across rooms and re-binds to the new room's director on `SceneRouter.room_entered`.

### 2.4 Saving, checkpoints, death and retry

- **Saving reuses `SaveManager` as is:** 3 slots plus the auto-save, atomic writes, versioned files, the save screen and the lamp check (re-dressed as a save terminal). Save terminals: the hideout (also rests), the junkyard's midpoint, and outside the arena gate. Auto-save on entering rooms marked `autosave` (the hideout, J1, the arena gate). **Never mid-robot:** robot rooms are not save points; saving needs Red on foot.
- **New save fields** (one migration step, 2 → 3, defaults for old files): `sword` (equipped sword id), `hacks` (unlocked hack ids), `battery` is not saved (it starts full on load). The party becomes Red alone; old party fields are kept, unused.
- **Checkpoint = a room entrance.** On entering a `checkpoint` room, `RoomSnapshot` (pure) records Red's health, battery, items, credits and the flags set so far. Puzzle flags set inside the room are kept on retry if they are marked `sticky` in placements (an opened door stays open).
- **Death** (recommended Decision 2, A): `player_action.json` gets `"death": {"mode": "retry"}` (the sandbox keeps `"sandbox"`: she gets up). At 0 health: a short slow-down, then the Continue screen (Continue / Quit to title). Continue reloads the room at the spawn she entered by, from the snapshot. **Boss fights checkpoint per phase:** losing in phase 1 restarts at the arena gate (intro skipped); losing in the robot round restarts the robot round already docked, with the colossus at full health. Options B and C are the same code with a different rule in `slice.json` (`retry.from`: `room` / `save`; `retry.credit_cost`).

### 2.5 How the sandbox systems plug in

| System | In the slice | Change needed |
|---|---|---|
| **ActionPlayer** (Red) | The only hero, town and dungeon alike, so she looks and moves the same everywhere. | Contract methods (2.6), `town` mode (attacks and hacks off, interact on), `death` mode, takes any `Camera3D` (it already does). |
| **One-button combo** (`combo.json`, ComboSelector) | Unchanged in dungeons and the arena. | None. Interact-on-attack (Decision 3, A) is a check before the combo pick: a prompt is showing and no enemy is within `interact_clear_m`. |
| **Enemies** (ActionEnemy, EnemyBrain, tokens) | Signals cops (the Grunt, re-skinned by data), the Brute as the heavy until Ross's model, plus two new kinds: the flying Signals drone and the wall turret. | Hijacked targeting (4.4); a `scale_form` field so an enemy can be built at robot scale (the junk mech). |
| **Hacks** | New (section 4). | New files; the second button's "coming later" call-out is replaced. |
| **Robots** (CS-21: ScaleProfile, RobotBoarding, RobotSequence, ScaleController, SmashProp, RobotDisplay, `scale_profiles.json`) | The loader (J4, J5) and the docking and colossus (boss phase 2). | `RobotStage` builds them from a room's `robot_rooms/<id>.json` instead of the sandbox; `RobotBoarding.bind` takes a combat host instead of the sandbox; new `place_in(form)` for starting already boarded; a `scripted` trigger so a hack or a boss transition can start a boarding or docking. |
| **HUD** (SandboxHud parts) | ActionHud reuses the health bar, Noise meter, lock reticle, call-outs and damage numbers. | Binds to any combat host; adds the hack panel, boss bar, radio bark, location card; hides the Lights On element when that feature is off (section 7). |
| **Feel panel** | Still on F12 in the slice (Ross tunes by playing). | New groups `hacks` and `boss`. |
| **Look profiles** | `market_ps2` (warm neon night, string lights) for town, `junkyard_ps2` (the grim PS2 look) for the junkyard; the scale controller scales fog and draw distance per form, as in the robot test. | Two new profiles; room data picks one. |

### 2.6 The hero contract (how old town code accepts the new Red)

Today about 20 town and Works scripts (doors, pickups, NPCs, the job board, cage lifts, card gates, the dialogue runner, the shop and field menus) expect the old `PlayerController`. They use only a dozen of its methods. The plan:

1. Their type hints change from `PlayerController` to `CharacterBody3D` (a mechanical edit; the old controller is a `CharacterBody3D`, so the shelved game is unaffected).
2. They reach the hero only through **`HeroLink`**, a tiny wrapper with the dozen calls they use: `set_scripted(on, clip)`, `play_clip(clip)`, `get_facing()`, `get_move_direction()`, `set_camera(cam)`, `reset_ground_height()`, `block_jump_for_frames(n)`, `start_blink(s)`, `is_catchable()`, `has_animation(clip)`, `is_on_floor()`. Both `PlayerController` and `ActionPlayer` implement them (ActionPlayer maps `set_scripted` to its existing SCRIPTED control mode and `play_clip` to `play_scripted_clip`).
3. `test_hero_contract.gd` fails if either hero is missing a method, so the two can't drift.

*Why this matters for the game: the town's doors, shops, talking, job board and dungeon puzzle pieces already work and are tested; this lets the new Red use all of them instead of rebuilding them.*

---

## 3. The town under the hybrid camera (D3)

**Camera.** Town rooms keep the fixed diorama camera exactly as tuned for the Harrow graybox (per-room yaw, pitch, bounds, the prop fader). `ActionRoom` gives ActionPlayer the diorama `Camera3D`, so her run stays camera-relative. No lock-on, no orbit, no fighting in town (`combat: false`): the market is the warm pocket. Scale check: the Harrow rooms were built for a 1.0 m Red at 5.2 m/s; the sandbox Red is 0.95 m at 6 m/s, close enough that doors, steps (1.0 m or less) and crate hops still work; the Level Designer checks every hop in the graybox.

**What carries over from the turn-based town code, and how:**

| Piece | Verdict | How |
|---|---|---|
| The 9 Harrow rooms (`make_harrow_rooms.py`, scenes, layout) | **Copy, then re-dress** | The Level Designer copies the generator to `make_market_rooms.py`, writes new room ids (`market_*`) into `data/slice/rooms.json`, and changes names and dressing only. The originals in `scenes/rooms/harrow/` stay untouched for the shelved game. Red's hideout is the old home re-dressed as a back room over a repair shop (one new small room for the shop below, if the market map wants it). |
| Doors, pickups, crates, traversal spots, scene spots, window lamps | As is | Through the hero contract. |
| Talking: DialogueRunner, speech bubbles, speakers, portraits, gibberish voices, NPC and PlacedNpc | As is | Through the hero contract. New NPC lines are new files (Writer). NPCs get idle and talk clips from the Animator when they exist; until then the capsule fallback. |
| StoryDirector (walk, face, say, show, goto steps) | As is, plus new steps | New steps for the slice: `radio` (a non-blocking Vela line), `form` (board / dock / disembark), `boss_phase`, `camera_shot` (the battle shot director's storyboard shots, reused for intros). The old `battle` step is not used in slice rooms. |
| Shops: ShopLogic, Bag, ItemData, ShopMenu, shop counters | As is | ShopMenu freezes the hero through the contract. Stock lives in `data/shops/market_*.json` (Combat Designer; Level 2). What a shop sells in an action game (swords, hack upgrades, healing items used from the pause menu) is the Combat Designer's proposal. |
| Job board (JobBoard, `jobs.json`, flags) | As is | `data/slice/jobs.json`: the main job ("go to the junkyard") sets the flag that opens the junkyard gate; side jobs are optional. |
| Save lamps and the lamp check | As is, re-dressed | Become save terminals (same script, new look and words). |
| Field menu | Adapt | Party page hidden (Red alone); Items, Equip (sword), Config, Save stay. Opened from the slice pause menu. |
| Party follow, field encounters, map enemies touching Red to start a battle, room fights, the battle scene | **Not used** | Single hero; fights are real-time. Kept in the project for the shelved game. |
| Works puzzle pieces (card gates, power switches, cage lifts, push crates, bells) | As is, available | Through the hero contract; the Level Designer may use them in the junkyard next to the new hack targets. |
| Grim dressing, grime paint, window lamps | As is | The market look profile decides how warm it reads. |

**NPC bubbles.** The speech bubble already follows the speaker's head on screen; `ActionRoom.screen_pos_of` gives it the same answer for NPCs as for fighters. Ambient one-liners as Red walks past (a market crowd murmuring) are a `PlacedNpc` with `bark_radius_m`: a short bubble that doesn't stop Red.

**Input sorting** (the sandbox's open item). Pad B is both `dash` and `interact`/`cancel`; Tab and pad Y are both `menu` and the hack button. In slice rooms: `interact` is the attack button (Decision 3, A) or its own button (B); menus open from Start; B keeps dash in dungeons and is "cancel" only inside menus. The sorting is one table in `project.godot` plus `config_screen.json` rows, owned by the Gameplay Programmer, with a test that no two live actions in the same room kind share a button by accident.

---

## 4. The hack system

### 4.1 Data: `data/combat/hacks.json`

```json
{
  "version": 1,
  "battery": {
    "capacity": 100, "start": 100,
    "gain": {"hit": 6, "blocked": 3, "armored": 4, "guard_broken": 8, "finisher_bonus": 6, "air_bonus": 2},
    "gain_cap_per_s": 30
  },
  "selection": {"mode": "pick", "order": ["zap_drone", "emp", "overclock", "reboot"], "auto_rules": "see hacks_design.md"},
  "hacks": {
    "zap_drone": {
      "name": "Zap Drone", "icon": "hack_zap", "cost": 25, "cooldown_ms": 600,
      "cast_move": "hack_zap",
      "target": {"kind": "enemy", "use_lock": true, "soft_range_m": 14, "soft_cone_deg": 50, "no_target": "fire_forward"},
      "effect": {"type": "projectile", "speed_mps": 18, "max_m": 18, "hits": 3, "rehit_ms": 250,
                 "hit": {"damage": 6, "hitstun_ms": 260, "hit_stop_ms": 30, "poise_damage": 6, "style_points": 8,
                         "spark": "zap", "sfx": "hack_zap_hit", "tag_mult": {"drone": 2.0, "relay": 3.0}}}
    },
    "emp": {
      "name": "EMP", "icon": "hack_emp", "cost": 40, "cooldown_ms": 1200, "cast_move": "hack_emp",
      "target": {"kind": "self"},
      "effect": {"type": "pulse", "radius_m": 4.5,
                 "hit": {"damage": 4, "knockback_m": 3.0, "guard_break": true, "hit_stop_ms": 60, "sfx": "hack_emp_hit"},
                 "stun_ms": {"drone": 3000, "turret": 4000, "robot": 2000}}
    },
    "overclock": {
      "name": "Overclock", "icon": "hack_overclock", "cost": 50, "cooldown_ms": 1500, "cast_move": "hack_overclock",
      "target": {"kind": "hijackable", "use_lock": true, "soft_range_m": 12, "soft_cone_deg": 60, "no_target": "refuse"},
      "effect": {"type": "hijack", "duration_s": 10.0}
    },
    "reboot": {
      "name": "Reboot", "icon": "hack_reboot", "cost": "all", "requires_full": true, "cast_move": "hack_reboot",
      "target": {"kind": "self"},
      "effect": {"type": "heal", "heal_frac": 0.5, "iframes_ms": 600}
    }
  }
}
```

- **Casting reuses the move system.** Each hack's cast is a move in `moves.json`'s `red` set (`hack_zap`, `hack_emp`, `hack_overclock`, `hack_reboot`, field `kind: "hack"`) with startup, recovery, cancels and pose keys like any attack. The effect starts on the move's `active` event. So hit-stop, cancels into dash, the animation fallbacks and the timing tests all come for free.
- **Hack damage goes through the same hit chain.** `director.report_hack_hit(source, target, hit)` runs `HitResolver` with `source: "hack"`, so hit-stop, sparks, damage numbers, launches and the enemy reactions all behave like sword hits. Hack hits never refill the battery (no free loop).
- `tag_mult` and `stun_ms` read an enemy's `tags` in `enemies.json` (`drone`, `turret`, `robot`, `relay`), so a new enemy kind only needs tags, not code.

### 4.2 The battery

`HackBattery` (pure, on Red's combat clock): `from_data(d)`, `charge()`, `fill()` (0..1), `add_from_hit(outcome, move_id, airborne, finisher, now_ms)` (capped per second, so a multi-hit can't fill it in a frame), `can_spend(cost)`, `spend(cost)`, `lock(ms, now_ms)` / `is_locked(now_ms)` / `lock_left_ms(now_ms)` (Kasp's Quiet Hours), `reset_full()`. The director owns it, feeds it from `hit_landed` when the attacker is Red and the source is her sword, and emits `battery_changed(charge, capacity)` and `hack_locked(active, ms)`.

The Noise meter stays separate. *Why this matters for the game: the battery rewards staying aggressive (Ross's pitch pick), and Noise keeps working for whatever Ross decides it feeds once Lights On is gone.*

### 4.3 Targeting with lock-on

- **Zap Drone:** the hard-locked target if there is one; otherwise `LockOn.soft_target(stick)` inside its range and cone; otherwise it flies straight ahead (data: `no_target`).
- **Overclock:** only things in group `&"hijackable"`. If the locked target is hijackable, that; otherwise the best hijackable in range scored by `LockOnMath`. With Overclock selected, the HUD marks the one it would take. No target = no cast and no charge spent ("No signal").
- **EMP and Reboot:** no target.
- **Lock-on reaches hack targets too.** `LockOn` gets one extra candidate source: nodes in group `&"lock_targets"` (relays on the Hushmaster, turrets, fuse boxes marked `lockable`). Enemies stay the first choice when both are in front; the stick flick switches between them.

### 4.4 Overclock's hijackable interface

Anything Overclock can take carries a `Hijackable` component (a child node; joins group `&"hijackable"`):

```gdscript
class_name Hijackable extends Node
@export var aim_bone: StringName = &"head"      # where the link line and marker go
@export var allowed: bool = true                 # bosses and some enemies say no
func hijack_point() -> Vector3
func can_hijack(by_team: StringName) -> bool
func begin_hijack(by: CombatActor, duration_s: float) -> bool   # calls owner.on_hijack_begin(by, duration_s)
func end_hijack() -> void                                       # calls owner.on_hijack_end()
func is_hijacked() -> bool
func time_left_s() -> float
signal hijack_started(owner: Node, duration_s: float)
signal hijack_ended(owner: Node)
```

- **Enemies** (drone, cop, turret): `on_hijack_begin` switches `team` to `&"player"`, gives up its attack token, sets its brain's target to "nearest enemy" instead of Red, and turns its edge light cyan. Its hits go through the director as a player-team attacker, so they hurt enemies and boss parts. At the end it goes back to `&"enemy"` and is briefly stunned (no instant revenge). Taking damage doesn't end it; a hijacked enemy that dies just dies.
- **World machines** (the crane, a drone line's dispenser) use the same component, but their `on_hijack_begin` runs their own little behaviour (4.5 and 5.2).
- **Bosses** have `allowed: false` on the body; the relays are hacked by Zap or by a hijacked turret's fire, not Overclocked.

### 4.5 Hack targets that aren't enemies

```gdscript
class_name HackTarget extends Node3D               # component on doors, cranes, drone lines, terminals, the loader
@export var target_id: StringName
@export var accepts: PackedStringArray = ["zap"]   # zap / emp / overclock / interact
@export var lockable: bool = true
@export var sticky: bool = true                    # stays done after a retry or a reload (a GameState flag)
func aim_point() -> Vector3
func can_take(hack_id: StringName) -> bool
func take_hack(hack_id: StringName, info: Dictionary) -> bool
signal hacked(target_id: StringName, hack_id: StringName)
```
Zap and EMP effects check for `HackTarget`s in their path or radius after enemies; `interact` means "walk up and press the button" (a terminal), for places where aiming would be fussy.

### 4.6 HUD

The hack panel sits under the health bar: the battery as a bar with tick marks at each hack's cost, the selected hack's icon and name (option A) or the last-used one (option C), greyed out when there isn't enough charge, a cooldown sweep, a static fizz and countdown while Quiet Hours locks it, and a small ring timer over anything hijacked. Icons are placeholders until Ross's four hack icons (art row VS-A7). All text in `data/text/slice_ui.json`.

---

## 5. Junkyard dungeon tech

### 5.1 Rooms

About six rooms (the Level Designer's map sets the count): J1 to J4 on foot, each a scene built for the free camera (walls or scrap cliffs all round, or open with light fog beyond, never fog to hide pop-in); J5, the loader run, one big scene; then the arena (section 6). A save terminal at the midpoint (J3) and outside the arena gate. Generated from `make_junkyard_rooms.py` so layouts are re-runnable, with Ross's city tiles and junk dressing from the Technical Artist.

### 5.2 Hack targets (graybox versions in VS-19, final looks in VS-40)

| Target | Accepts | What happens | Built from |
|---|---|---|---|
| **Wall turret** (an enemy) | Zap (stun), EMP (off for 4 s), Overclock (fights for Red 10 s) | Fires at Red in telegraphed bursts; hijacked, it fires at enemies, and in the boss arena at the leg relays. | `wall_turret.gd` (static `ActionEnemy`, `tags: ["turret"]`) + `Hijackable` |
| **Fuse-box door** | Zap | The door opens and stays open (`sticky`). | `HackDoor` (a `Door` with a `HackTarget`) |
| **Crane** | Overclock | For the hijack time, the crane's hook follows a path in data: drops a container to make a bridge, or swings it into a scrap wall (a `SmashProp`). | `HackCrane` + `Hijackable`; path points in placements |
| **Drone line** | EMP (stops for N s), Zap its power node (stops for good) | A dispenser that sends Signals drones out every few seconds until shut down. | `DroneLine` + `HackTarget`; drone count and interval in placements |
| **Terminal** | interact | Opens a gate, starts a scene, or (J4) wakes the loader. | `HackTerminal` |
| **The loader** (J4) | Overclock (or interact; the Combat Designer picks) | Hacking it starts the boarding sequence, scripted: Red's first robot. | `HackTarget` on the loader → `RobotStage.board()` |

### 5.3 The loader section

`RobotStage` reads `data/slice/robot_rooms/junk_j4.json` (which robots, where, their boarding and dock points, the props) and builds what the sandbox's robot yard builds today, with the same `ScaleController` (camera, fog, shadows, shake, sound pitch per form) and the same `scale_profiles.json` numbers Ross tuned. J5 starts with Red already in the loader (`form: small`). J5's content: smashable scrap (SmashProp), Signals cops and drones at Red's scale (the loader mows them down: the power fantasy), and a few scrap walls only the loader can break. **Hacks are off in robot forms** for the slice (the battery panel hides): one less thing to tune at three scales. At the arena gate Red climbs out (the existing disembark sequence) and the loader stays parked there; the boss transition uses it.

---

## 6. Boss tech: Kasp, the Hushmaster, and the junk mech

### 6.1 The shape (Ross's option C)

| Phase | Form | Red fights | Ends when |
|---|---|---|---|
| **1. The Hushmaster** | `red` (on foot) | Kasp's spider-legged jammer walker. Each leg pair has a relay box; Zap it, or Overclock a wall turret to shoot it, and the pair drops. All four pairs down: the rig topples, a prompt on the hack button jacks Red into the dish for a big hit. | Hushmaster health 0 (or the jack-in hit) |
| **Transition** | `red` → `small` → `huge` | Scripted: Kasp escapes from the wreck, the yard's scrap rises into a giant junk mech around him; Red runs to the parked loader (boarding), the colossus stands up at the arena's edge, and the loader docks into it (the CS-21 docking, 4.5 s). | Control returns in the colossus |
| **2. The junk mech** | `huge` | Robot vs robot at colossus scale: readable, slow, huge telegraphs; scrap armour plates come off to expose Kasp's cockpit core. | Junk mech health 0; ending scene |

The pitch's "Kasp on foot with his clipboard" last phase is replaced by the junk mech. If the Creative Director wants a beat of Kasp on foot after the mech falls, it is a short cutscene, not a fight.

### 6.2 One scene, two scales

The arena is **one big scene**: a cleared plateau in the middle of the junkyard bowl (about 40 m across, for phase 1) surrounded by the yard at colossus scale (several hundred metres to the bowl's rim, the scrap piles the junk mech is built from, and the dormant colossus at the edge). During phase 1 the camera, fog and draw distance are Red's (`grim_ps2` haze, long draw distance), so the big yard reads as backdrop; at the docking, `ScaleController` eases everything to the huge form's numbers, as it does in the robot test. *Why this matters for the game: no cut or loading screen between the two halves of the fight; the junk mech is visibly built from the yard you've been fighting in.*

### 6.3 The parts

- **`BossFight`** (node, in the arena): owns the phases list from `bosses/*.json`, starts each phase's boss, plays transitions through `RobotStage` and the StoryDirector (`boss_phase` and `form` steps), sets the per-phase retry point (2.4), and tells the HUD which bar to show.
- **`BossPart extends CombatActor`**: a separately hittable, lockable piece with its own health, `damaged_by` (`sword`, `hack`, `hijacked`), and a `broken` signal. Hushmaster relays and the junk mech's armour plates are BossParts registered with the director, so lock-on, damage numbers and FX work on them with no special cases.
- **`Hushmaster`** (body, `ActionEnemy` driven by a `BossBrain`): legs posed procedurally (each pair lifts and slams from data; no hand animation needed), a dish part, a seat with Kasp's blockout riding it. Leg pairs drop when their relay breaks; the body leans toward the missing side; with all four down it topples and opens the jack-in prompt (`HackTarget`, `accepts: ["interact"]`, only while toppled).
- **`JunkMech`** (`ActionEnemy` at `scale_form: huge`, about 40 m, on Red's bone names so the Quaternius clips play on it as they do on the robots): armour plates as BossParts; the core is only hittable once its plates are gone.

### 6.4 Patterns as data

`bosses/hushmaster.json` (sketch; numbers are the Combat Designer's):

```json
{
  "name": "the Hushmaster",
  "phases": [
    {"id": "rig", "form": "red", "boss": "hushmaster", "bar": "boss", "retry": "arena_gate",
     "parts": {"relay_fl": {"hp": 60, "damaged_by": ["hack", "hijacked"], "drops": "legs_front_left"}, "...": "four relays"},
     "patterns": [
       {"id": "leg_stomp",   "weight": 3, "when": {"legs_up_min": 1, "dist_max_m": 8},
        "steps": [{"move": "stomp_windup", "leg": "nearest"}, {"move": "stomp_ring"}],
        "answer": "jump the ring"},
       {"id": "dish_sweep",  "weight": 2, "when": {"dist_min_m": 5},
        "steps": [{"move": "sweep_line"}, {"move": "sweep_beam"}], "answer": "dash through"},
       {"id": "drone_drop",  "weight": 2, "when": {"drones_alive_max": 0}, "steps": [{"spawn": "signals_drone", "count": 3}], "answer": "EMP"},
       {"id": "quiet_hours", "weight": 1, "when": {"cooldown_s": 25}, "steps": [{"move": "jam_hum"}, {"lock_hacks_ms": 5000, "cut_short_by": "dish"}],
        "answer": "hit the dish"}
     ],
     "rules": {"legs_lost_speeds_up": 0.1, "min_gap_ms": 900, "topple_at_legs": 0}},
    {"id": "transition", "sequence": ["kasp_escape", "mech_assemble", "board_loader", "dock_colossus"], "retry": "skip_to_next"},
    {"id": "mech", "form": "huge", "boss": "junk_mech", "bar": "boss", "retry": "phase_start", "patterns": "see junk_mech.json"}
  ]
}
```

- **`BossBrain`** (pure, on the boss's combat clock): `step(now_ms, view) -> intent`, picking the next pattern by weight among those whose `when` fits, never repeating a pattern back to back, keeping `min_gap_ms` between impacts. Every step is a move in `moves.json` (`hushmaster` and `junk_mech` sets), so telegraph time, impact time, hitboxes, parry and dodge flags use the existing machinery and the existing data tests (the 500 ms minimum wind-up rule applies; at colossus scale the Combat Designer scales wind-ups up, roughly the robot test's 0.45 speed).
- **New hitbox shapes:** `ring` (an expanding band on the floor with an inner radius; misses anyone above `clear_height_m`, so jumping clears it) and `beam` (a long box that follows a pre-drawn line; dashing through it with i-frames is the answer). Both in `hitbox.gd`; both tested.
- **Quiet Hours** calls `battery.lock(ms)`; the HUD fizzes; hitting the dish part during the hum ends the lock early. Unlike the turn-based version, it doesn't scramble timing cues: in real time, locking the hacks is the readable version of "the jammer silences you."
- **Arena:** two or three wall turrets on the plateau's edge (Overclock them onto the relays), drone drop points, a flat floor for the rings, the stair or gate behind as the retry spawn. Intro camera shots reuse the battle shot director's storyboard as `camera_shot` steps.

### 6.5 What the robot round needs that the robot test didn't have

- **A giant enemy.** Enemies at robot scale were never tuned (the robot test's wolves were "ants"). `ActionEnemy` gets `scale_form`, which applies `ScaleProfile.scale_box` / `scale_attack` to its hitboxes and moves the same way Red's are scaled, and `LockOn.range_scale` already covers reach.
- **Telegraphs readable at 75 m.** Wind-up flashes and sounds scale with the form (bigger flash, lower pitch); the Technical Artist makes a huge-scale telegraph.
- **Retry inside a fight** (2.4) and the **scale switch mid-scene** (6.2).
- *If Ross later wants the whole boss at robot scale* (the colossus against the Hushmaster too): the patterns, parts and brain are scale-free, so it's the same code with `form: huge` on phase 1 and a rebuilt arena; the cost is content and tuning, about a week.

---

## 7. The "Lights On" switch-off point

Nothing is removed until Ross says so. One switch file, `data/slice/features.json` (read by `Features`, pure), with each cut or undecided mechanic on its own line:

```json
{"lights_on": true, "lamp_flare": true, "noise_meter": true}
```

| Switch off | What stops | What stays |
|---|---|---|
| `lights_on: false` | The director never starts Lights On (auto or chord); `request_lights_on()` returns false; HitResolver gets damage multiplier 1 and no super armour; the HUD hides the Lights On part of the meter; CombatFx skips its glow. | `lights_on.gd`, its tests, its data, its knob. The sandbox can still turn it on. |
| `lamp_flare: false` | Perfect dodges and parries don't start the slow-mo; the "Lamp Flare!" call-out doesn't show. | Perfect-dodge detection (other things can use it), the flare code and knobs. |
| `noise_meter: false` | The Noise meter is hidden and stops scoring. | `StyleMeter`; waiting on Ross's call about what Noise feeds. |

Defaults: all `true` (as Ross played them) in both the sandbox and the slice until he says. The on-screen names ("Lamp Flare") are already text in data, so renaming is a text edit. The sandbox's user folder name `LightsOnSandbox` stays, so Ross's saved feel files aren't orphaned. `test_features.gd` plays a fight with each switch off and proves nothing crashes and nothing of that feature shows.

---

## 8. Test expectations

Run: `godot --headless --path game -s res://tests/run_all.gd` (`-- --only=slice` for a subset). **The whole suite is green before anything merges to main**, including every sandbox test and every test of the shelved game.

| Test | Must prove |
|---|---|
| `unit/test_game_mode.gd` | Each mode picks its rooms data and save folder; classic is the default in tests; the slice boot never touches `user://saves/`. |
| `unit/test_hack_battery.gd` | Gains per outcome, the per-second cap, hack hits don't refill, spend and "all", lock and unlock, reset. |
| `unit/test_hack_rules.gd`, `test_hack_selector.gd` | Cost, cooldown and lockout gate a cast; `pick` cycles in order; `auto` picks by situation, one test per rule (as the combo selector has); Reboot needs a full battery. |
| `unit/test_boss_brain.gd`, `test_boss_phases.gd` | Patterns chosen only when `when` fits; no back-to-back repeat; the minimum gap between impacts; phase order, transitions and the retry point for each phase. |
| `unit/test_room_snapshot.gd`, `test_features.gd` | Snapshot and restore; sticky flags survive; each feature switch off. |
| `unit/test_slice_data.gd` (QA) | Every id in `rooms.json`, `placements.json`, `encounters.json`, `hacks.json`, `bosses/*.json`, `jobs.json`, `story_scenes.json` resolves (scenes, spawns, moves, enemies, sounds, text); every boss and hack move obeys the wind-up floor; every hack has an icon and text. |
| `integration/test_hero_contract.gd` | Both heroes implement every `HeroLink` method; a door, pickup, NPC talk, shop and job board work with ActionPlayer. |
| `integration/test_action_room.gd`, `test_town_systems.gd` | A town room boots with the diorama camera and no combat; a dungeon room with orbit, lock-on and director; health, battery, sword and form carry through a door; talking, shopping and the job board end to end. |
| `integration/test_hacks.gd`, `test_hijack.gd` | Each hack hits through the director (hit-stop, numbers); Zap uses the lock then the soft target; EMP breaks a guard and stuns a drone; a hijacked cop or turret attacks enemies and returns to its team; no target = no charge spent. |
| `integration/test_hack_targets.gd`, `test_drone_turret.gd` | Fuse door opens and stays open after a reload; the crane follows its path; the drone line stops; the turret's bursts are telegraphed. |
| `integration/test_robot_stage.gd` | The loader built from room data; hacking it boards; starting a room already in the loader; disembark at the gate. |
| `integration/test_hushmaster.gd`, `test_junk_mech.gd`, `test_boss_transition.gd` | A relay break drops its leg pair; four drop = topple and the jack-in prompt; the ring misses a jumping Red, the beam misses a dashing Red; Quiet Hours locks hacks and the dish cuts it short; the transition boards and docks and switches scale; a phase-2 death restarts phase 2 already docked. |
| `integration/test_slice_retry.gd`, `test_slice_save.gd` | Continue reloads the room from the snapshot; boss retry points; save and load in every checkpoint room round-trips; no save offered in a robot room. |
| `integration/test_action_hud.gd`, `test_continue_screen.gd`, `test_slice_pause.gd`, `test_slice_shop.gd` | The HUD reacts to every new signal from a stub; the Lights On element follows the switch; pause and Continue flows; buying with ActionPlayer. |
| `integration/test_slice_rooms.gd` (Level Designer) | Every door's target exists, every spawn exists, every placement matches a node. |
| `integration/test_slice_smoke.gd` (QA) | Each slice room loads, runs 300 frames with no errors and hits 60 fps in the real-renderer pass (not headless). |
| `sim/test_hack_bots.gd`, `test_boss_bots.gd` | Scripted runs: "Overclock a turret onto a relay drops the leg pair"; "EMP clears a Drone Drop"; "a bot that jumps every ring and dashes every beam beats phase 1 without taking ring or beam damage". |
| `visual/capture_slice.gd` (TA) | Screenshots of the market, the junkyard, both boss phases into `docs/screenshots/slice_*.png` for Ross. |

**The bot playthrough: `sim/test_slice_playthrough.gd` (QA, with bot hooks from the Gameplay Programmer).** Headless, fixed time step, about 5 to 10 minutes of real time for 30 to 45 minutes of game. It starts a New Game in slice mode and follows `tests/fixtures/slice/route.json` (a list of waypoints and actions per room: walk to, talk to, take job, buy item, use door, hack target, board, fight). A **fight bot** handles combat: lock on to the nearest enemy, mash attack, dash on any telegraph aimed at Red, EMP when three or more are close, Zap relays, jump rings, Reboot under 30% health. It must: reach the end flag `slice_done`; pass through every room on the main path; open every main-path hack target; board, disembark, re-board and dock; beat both boss phases; save at every terminal and reload once at each to keep going from the loaded game; die on purpose once in J2 and once in each boss phase and continue from the right place; finish with zero script errors. A second bot run does the side jobs and the shops. This test is the slice's "is it still playable end to end" alarm, so it runs before every build sent to Ross.

---

## Changes
> Additions agreed while building. Newest at the bottom. Add yours here instead of editing the plan above silently.

- **2026-10-09, Combat Programmer, VS-6 (feature switches).** `Features` (`scripts/combat/model/features.gd`, pure) reads `data/slice/features.json`; `Features.is_on(Features.LIGHTS_ON / LAMP_FLARE / NOISE_METER)`, `set_on()` for a runtime override, `version()` for watchers. Contract changes:
  - `CombatDirector` gains `feature_changed(id, on)` (HUD and FX hide or show their part; flipping off mid-run also ends the running Lights On / flare and empties Noise) and `perfect_dodge_detected(info)`, which fires on every perfect dodge. `perfect_dodge` (the "Lamp Flare!" call-out and dodge spark) now fires only with `lamp_flare` on. The dodge still scores Noise either way.
  - `StyleMeter.enabled` (false = nothing scores); `noise_meter: false` also means Lights On never starts (it needs a full meter).
  - `FeelKnobs.knobs()` now lists only the knobs to show: a knob with `"feature": "<id>"` in feel.json is hidden while that switch is off (`all_knobs()` lists all, `is_hidden(id)`; values still save and load). Tagged: `lights_on_trigger` (lights_on); `flare_duration_s`, `flare_enemy_speed`, `flare_glare_radius_m`, `flare_cooldown_s`, `flare_on_parry` (lamp_flare). `perfect_dodge_window_ms` stays shown because detection stays.
  - For the UI Programmer (action_hud and the sandbox HUD parts, not edited by me): the sandbox HUD already goes quiet through the signals (no `lights_on_changed`, `perfect_dodge`, `flare_*` or `noise_changed` with the switch off). Still to do on the UI side: hide the Lights On bulb (`_draw_lights`) when `Features.is_on(LIGHTS_ON)` is false and the Noise meter (`_draw_noise`) when `noise_meter` is false, listen to `feature_changed`, and re-bind the feel panel (`panel.bind(knobs)`) when it flips so hidden knobs leave the list.
  - After adding a `class_name` file run `godot --headless --path game --import` once so the class cache knows `Features`.

- **2026-10-09, Gameplay Programmer, VS-3 (game modes and slice boot).**
  - `GameMode` (`scripts/core/game_mode.gd`, pure) resolves the mode: a command line word beats a feature tag (`--classic`, then `--sandbox`, then `--slice`; then tags `sandbox`, `slice`), else the fallback. Main (`apply_mode`) sets `SceneRouter.rooms_id`, `SaveManager.save_dir` and `rooms_data_id`, and `GameState.rooms_data_id` from the mode; all default to the old values, so no old test changed. `Main.sandbox_boot_enabled` now means "boot by mode" (tests turn it off). Sandbox: unchanged, editor Play still passes `-- --sandbox`.
  - **The no-flag default is `classic`, not `slice`** (the table in 2.1 says slice): there are no slice rooms yet, so a plain launch would boot nothing. It is the data value `default_mode` in the new `data/slice/slice.json`; VS-35 flips it to `slice`. The slice export presets carry the `slice` tag, so they boot the slice already.
  - Two export presets added: `Slice Windows` and `Slice Mac` (feature tag `slice`, output `builds/slice/`). No `.slice` user-folder override: the slice shares the config folder but keeps its saves in `user://slice_saves`.
  - A slice New Game starts at `rooms.json` `start_room`, else at `slice.json` `new_game` (placeholder room `market_hideout`; the Level Designer replaces it).
  - New save fields (`sword`, `hacks`, migration 2 to 3) are VS-16, not done here.
- **2026-10-09, Gameplay Programmer, VS-4 (hero contract).**
  - `HeroLink` (`scripts/slice/hero_link.gd`) is a set of static helpers, not an object: `HeroLink.set_frozen(hero, true)`, `HeroLink.is_scripted(hero)` and so on. The contract is the 11 methods in the plan **plus four properties the town code already used**: `frozen`, `scripted`, `stick`, `read_engine_input`. Lists: `HeroLink.METHODS` and `HeroLink.PROPERTIES`; `test_hero_contract.gd` fails if either hero lacks one. Safe on null or freed heroes.
  - Field, works, dialogue, shop, menu, encounter and router scripts now hint `CharacterBody3D` and call through `HeroLink`. `FieldRoom` and the old `PlayerController` are otherwise unchanged. **VS-5 note:** `Door`, `RoomProp` and `StoryDirector` still find the room as a `FieldRoom` (`get_room()`); `ActionRoom` must extend it, or those three need the same treatment.
  - `PlayerController` gained `has_animation(clip)`. `ActionPlayer` gained the contract: `frozen`, `stick`, `scripted`, `set_scripted`, `play_clip` (town clip names mapped by `player_action.json` `town.clip_map`), `has_animation`, `set_camera`, `get_ground_height` / `reset_ground_height` (the diorama camera asks for it), `block_jump_for_frames`, `start_blink` / `is_blinking` / `is_catchable`, plus `town_mode` (`set_town_mode`; buttons in `town.blocked_buttons` do nothing) and `press_filter` (a Callable asked about every press first). New `town` block in `data/combat/player_action.json`. The `death` block is VS-16.
  - **Decision 3 is a data switch**, `data/slice/slice.json` `interact.mode`: `attack_button` (option A, default) or `own_button` (option B), with `clear_m` (5.0 m). Pure rules in `InteractRules` (`scripts/field/interact_rules.gd`); `PlayerInteractor` gained `rules`, `combat_room`, `consume_attack_press`, `install_press_filter`, `nearest_enemy_m`. VS-5's ActionRoom sets `interactor.rules = InteractRules.load_default()`, `interactor.combat_room = (room has combat)`, calls `install_press_filter()` and `player.set_town_mode(not combat)`.
  - **Input sorting is applied at slice boot, not written into `project.godot`**: the shelved game and the sandbox share the InputMap and need pad B as interact/cancel. `data/slice/input_sorting.json` lists the actions live together in town / dungeon / menu, the allowed overlaps, and the interact changes per option (pad B leaves `interact`; option B adds the right trigger). `InputSorting` (`scripts/slice/input_sorting.gd`) applies them from `Main.apply_mode(SLICE)`, re-applies after a Config remap, and `revert()`s for the old game. `test_input_sorting.gd` proves no accidental shared button in either option. No `config_screen.json` rows added yet (the Controls page still shows pad B for Interact in the slice; a UI Programmer row/label pass).
  - The sandbox is not sorted (its pad B dash vs interact for robot boarding is the same open item); it needs the same `InputSorting.apply` call if Ross wants it fixed there.
- **2026-10-09, Gameplay Programmer, VS-5 (ActionRoom).**
  - `ActionRoom` (`scripts/slice/action_room.gd`) **extends `FieldRoom`**, so `Door`, `RoomProp`, `StoryDirector`, `PlacedNpc`, `SceneSpot` and the other town pieces that look for "the room" work in it with no edits (the three the coordinator named included). Inherited but unused in the slice: `party`, `fights`, `encounters`, `field_menu` (all null; the old field menu is not installed because `menu` clashes with lock-on and the hack button; the slice pause menu replaces it).
  - **Where the Level comes from:** a rooms.json `scene` is a plain level scene (floor, walls, props, a `Spawns` node with Marker3Ds, optional `CameraRig` and `CameraBounds`, lights, `WorldEnvironment`). In slice mode `Main.enter_room` wraps it in an `ActionRoom` (`ActionRoom.wrap`) unless its root already is a FieldRoom. The room asks the router which room it is (`SceneRouter.pending_room_id`, new) and reads its entry through `get_room_entry`. Entry keys used now: `kind`, `camera` (diorama / orbit), `combat`, `look_profile`, `form`, `checkpoint`, `spawns`, `default_spawn`, plus graybox-only `enemies` ([{enemy, pos}], using `combat/sandbox` enemy_scenes) and `diorama` ({pitch_deg, yaw_deg, fov_deg, distance} when the level has no CameraRig). Not yet used: `robots`, `autosave`, `music`.
  - **Every room** gets a `CombatDirector`, the fx (`slice.json` `room_parts`, more parts can be listed there), Red (`slice.json` `hero.scene`), a `PlayerInteractor` with Decision 3's rules, and the DialogueRunner. Town rooms: the level's DioramaCamera (or a default one) and PropFader, no LockOn, no OrbitCamera, `town_mode` on. Dungeon and arena rooms: `LockOn` + `OrbitCamera`, the enemies, mouse capture (`slice.json` `camera.capture_mouse`).
  - **Combat host** (what the HUD, FX and bots bind to): `get_director`, `get_player`, `get_lock_on`, `get_camera` (the OrbitCamera; null in town), `get_camera_3d` (new: the camera she runs relative to, in every room), `get_feel`, `screen_pos_of`, `get_ui_parent`, `get_room_id`, `get_form`, `get_robot_stage` (null until VS-21), `get_enemies`, `reset_arena` (back to the entrance), `handle_input_event` (the same input relay as the sandbox).
  - **Carried through doors:** `HeroSession` (`scripts/slice/hero_session.gd`, pure: hp, hp_max, battery, sword, form) lives in `GameState.slice_run["session"]` (new plain Dictionary on GameState, cleared by `reset()`, not saved yet). It is written when the router starts a transition and when the room leaves, and read on entry. The battery goes through the director's `HackBattery` (`charge()`, `capacity()`, `set_charge()`); a new run leaves it at the director's start value. The sword uses `ActionPlayer.equip_sword`. **Form** is carried and announced (`form_entered`), but only recorded: a room whose `form` is not `red` forces that form, otherwise the carried form stays. `RobotStage` (VS-21) must act on `form_entered` / `get_form()`.
  - **Knock-out (Decision 2) is a data switch:** `slice.json` `retry`: `rule` = `room_entrance` (A, default) / `last_save` (B, asks Main to Continue the newest save) / `none` (she gets up as in the sandbox); `credit_cost` (C); `auto_continue_s` (3 s now: the stand-in until the Continue screen exists; the UI Programmer sets it to 0 and calls `ActionRoom.continue_after_knockout()` from the Continue button). `ActionPlayer` has a new `death_mode` (player_action.json `death.mode`, default `sandbox`; ActionRoom sets `retry`), `knocked_out` signal and `is_knocked_out()`. Restart = put the entrance session back in GameState and `router.start_at` the room/spawn. A checkpoint room restarts at its own entrance; a non-checkpoint room restarts at the last checkpoint room entered (its own entrance if none yet). Flags/items/credits snapshot (RoomSnapshot) and sticky puzzle flags are still VS-16.
  - **HUD:** one node in group `slice_hud` on the UI stage outlives rooms. Each ActionRoom binds it (`bind(host)`) on entry and unbinds on exit (only if it is still the one bound). `slice.json` `hud.scene` is the sandbox HUD for now; the UI Programmer's ActionHud replaces it by changing that path (it needs `bind(host)` / `unbind()`).
  - **Other edits:** `Placements.extra_ids` lays `slice/placements` over `world/placements` in slice mode (`GameMode.placements_ids`); Main no longer goes back to the title on Start/Esc in slice mode (the HUD's pause owns it); `PlayerInteractor` / `InteractPrompt` unchanged since VS-4.
  - **Graybox proof (throwaway):** `data/slice/graybox_rooms.json`, `graybox_placements.json`, `scenes/slice/graybox/gb_*.tscn` (made by `scripts/tools/make_graybox_rooms.py`): town hub, yard with two grunts, vault checkpoint, joined by doors. Not used by the game. Tests: `integration/test_action_room.gd`, `unit/test_hero_session.gd`.
- **2026-10-09, Combat Programmer, VS-8 and VS-9 (the hacks).** Not committed. Zap Drone, EMP, Overclock and Reboot are in and playable in the sandbox and in any room with a `CombatDirector`.
  - **Pure classes** (`scripts/combat/model/`): `HackBattery` (gains per outcome, `gain_cap_per_s`, hack hits never refill, spend / spend_all / refund, `lock` for Quiet Hours, `set_charge` / `reset_full` / `reset_start`), `HackRules` (cost, cooldowns, the first reason a cast is refused: locked, air, cooldown, global, overclock, no_signal, not_full, battery; tag multipliers, EMP stun times, Reboot heal, `knobs_from(feel)`), `HackSelector` (pick mode: step / slot; automatic mode: the six rules of `hacks.json` `auto`, the knobs replace the hold time and the crowd count), `HackGeometry`. `CombatData.hacks()` reads `hacks.json`. Tests: `unit/test_hack_battery.gd`, `test_hack_rules.gd`, `test_hack_selector.gd`, `test_hack_geometry.gd`.
  - **Nodes** (`scripts/combat/hacks/`): `HackCaster` (on Red; `ActionPlayer.hack_caster()` makes it the first time it finds a director, so no host has to add it; `bind(host)` also works as a `room_parts` entry), `ZapDrone`, `EmpPulse`, `OverclockLink` (plain placeholder looks until VS-41), `Hijackable` (the plan's 4.4 interface, plus `time_left_s()`, `duration_s()`, `hijacker()`, `hijack_changed` through the director). Tests: `integration/test_hacks.gd`, `test_hijack.gd`, `test_lock_targets.gd` (kit: `hack_kit.gd`), bot run `sim/test_hack_bots.gd` (the real sandbox).
  - **`CombatDirector`** gains `battery: HackBattery` (`charge()`, `capacity()`, `set_charge()`, `reset_full()` are what `ActionRoom` already calls) and signals the HUD binds to: `battery_changed(charge, capacity)`, `hack_locked(active, ms)`, `hack_selected(hack_id)` (pick mode: the selection; auto mode: the one just used), `hack_cast(info)`, `hack_refused(info)` (`reason` is one of `battery`, `not_full`, `no_signal`, `locked`, `air`, `cooldown`, `global`, `overclock`, `target_lost`), `hijack_changed(info)`. Also `report_hack_hit(source, target, hit, info)`, `lock_hacks(ms)` / `unlock_hacks()` / `hacks_locked()` (Quiet Hours, VS-26), `reset_hacks()` (the sandbox's arena reset calls it), `sync_battery()`. `player()` skips an enemy Overclock has taken over. `hit_landed` carries `source` (`sword`, `hack`, `hijacked`); `HitResolver` results carry it too (BossPart reads it for `damaged_by`) and an attack with `guard_break: true` breaks a raised guard (EMP).
  - **Battery rules as built.** Only Red's own sword feeds it (`attacker` is Red and not hijacked, `source` is not hack); a hijacked enemy's hits score no Noise and no battery either. Hit-stop from a hack hit freezes the victim only (the drone made the contact). Cost is spent at cast start (`spend_at`); a cast cut short by a hit on Red before its effect keeps its cost spent (the designer wrote no refund for that, only for a dead Overclock target).
  - **`ActionPlayer` edits (Gameplay Programmer: please keep when you merge)**: `TOKEN_HACK` and `queue_hack()`; `_press_hack` routes to the caster (the old "coming later" call-out stays only when there is no director or `hacks_enabled` is false); `_begin_hack()`; `hack_caster()`; `grant_iframes(ms)` (Reboot); a `TOKEN_HACK` case in `_free_accepts`, `_tick_free`, `_move_accepts` (a hack may follow a swing inside its chain window) and `_handle_move_inputs`; `_hacks.tick(delta)` at the end of `tick()`; `_hacks.reset()` in `reset_to()`; `_on_hit_landed` ignores hack-sourced hits; `handle_input_event` and `_read_engine_input` pass the selection keys on. Hacks are off while the form is not `red` (the plan's "hacks off in robot forms"). `combat_sandbox.gd`: one line in `_reset_director`.
  - **`ActionEnemy` edits**: `tags` (from enemies.json), `hijacked_by`, `hijackable`, `on_hijack_begin` / `on_hijack_end` / `hijack_allowed`, `apply_stun(ms)` (EMP and the end of a hijack), a hijacked unit targets the nearest enemy, asks for no attack token, ignores the `enemies_attack` knob and glows cyan. `enemies.json`: the Grunt got `"hijackable": true` (plan 4.4 lists the cop; **Combat Designer: yours to keep or change; the Brute is not hijackable; no unit has `tags` yet, so EMP only pushes the Grunt and Zap does plain damage**).
  - **`LockOn` edit (Gameplay Programmer to review)**: group `lock_targets` (`GROUP_LOCK_TARGETS`) is a second candidate source for a hard lock and for the flick switch. Enemies win a fresh lock when any is in reach; a node with `hp <= 0` or `lockable == false` is skipped; attack magnetism and `soft_target` still look at enemies only. **UI Programmer:** `target_changed` can now hand over a node that is not a `CombatActor` (no `actor_id`), so the reticle must place it from `global_position` or an `aim_point()` method.
  - **Inputs.** `HackCaster.ensure_actions()` adds `hack_prev` (mouse wheel up, d-pad left), `hack_next` (wheel down, d-pad right) and `hack_1` to `hack_4` (keys 1 to 4) to the InputMap if the project lacks them (not in project.godot; the Integrator may move them there, and the Config screen has no rows for them yet). **Conflict for the Gameplay Programmer's InputSorting:** d-pad left and right are also `move_left` / `move_right`, so on a pad they walk Red and change the hack together until the slice's sorting takes d-pad off movement.
  - **Words.** `data/combat/hack_text.json` (new, Combat Designer owns the wording) holds the call-outs the hacks put on the sandbox HUD's call-out line (cast, selection, every refusal). The slice HUD's hack panel (VS-11) binds to the director signals instead. The sandbox controls card and Config screen still say "Hack (coming later)": **UI Programmer** to reword.
  - **Known gaps.** `hack_zap_hit` and `hack_emp_hit` sounds do not exist yet (AudioManager warns once per id; VS-32). The cast moves still have no hang time for an air cast (the designer's `motion.hang_ms` would give a Zap or EMP in the air a short hover). `HackTarget` (VS-19) is read by duck-typing in group `hack_targets` (`can_take`, `take_hack`, `aim_point`) so Zap and EMP will open fuse boxes the day that class lands.
- **2026-10-09, Gameplay Programmer, VS-15 (town systems with the new Red) and VS-16 (knock-out, retry, saving).**
  - **For the Level Designer (market rooms):** in a slice room use the old props as they are: `Door` (placement in `data/slice/placements.json` "doors"), `PlacedNpc` ("npcs"), `JobBoard` ("spots" for its reach, jobs in `data/slice/jobs.json`), `ShopCounter` (`shop_id`), `SaveLamp` (`rest = true` in the hideout; `room_id` / `spawn_id` say where Continue puts her). Slice files are laid over the old ones: `Placements.extra_ids` (`slice/placements`), `extra_job_ids` (`slice/jobs`, with its own `text`) and `extra_scene_ids` (`slice/story_scenes`), set by `Main.apply_mode(SLICE)` (`GameMode.placements_ids / job_ids / story_scene_ids`). Rooms-file keys now used: `autosave` (SaveManager auto-saves on entering only rooms that say true; the old game's rooms have no key and keep saving), `robots` (non-empty: no saving in the room).
  - **Ambient barks:** `AmbientBarks` (`scripts/slice/ambient_barks.gd`, one per ActionRoom). A `PlacedNpc` placement with `bark_radius_m`, `barks` [String], optional `bark_cooldown_s` / `bark_speaker` says the next line in turn when Red comes within the radius. The bubble is a normal SpeechBubble that follows the speaker, takes no input, is NOT in the modal group (Red keeps walking, talking and using doors) and closes itself. Waits while a talk, shop or menu is up or she is frozen/scripted. Defaults in `slice.json` `barks`.
  - **Field menu from the pause menu:** `ActionRoom` installs a `FieldMenu` with `listen_open_action = false` (the `menu` button is lock-on / the hack button in the slice) and `commands_override` from `slice.json` `menu.commands` (Items, Sword, Config, Save; Party, Skills, Status hidden). `ActionRoom.open_field_menu()` is connected to the HUD's `field_menu_requested`, so the pause menu's Menu row works. In a combat room the world stands still while it is open (`SandboxPauseGate`). New page `PageSword` (swords from `swords.json`, optional per-sword `unlock_flag`; text in `text/field_menu.json` "sword"). Items work on Red because `HeroVitals` copies her live health into the party member "red" when the menu opens and back when it closes.
  - **Rest:** `GameState.rest_party()` now also resets the slice session's health to "full" and emits `party_rested`; the room heals the live Red and refills the battery.
  - **Save format 3** (`GameState.SAVE_VERSION`, `_migrate_2_to_3`): new keys `sword` (equipped sword id), `hacks` (unlocked hack ids; `GameState.unlock_hack / has_hack / unlocked_hacks`, a slice New Game starts with `slice.json` `new_game.hacks`, the four hacks of the pitch as a placeholder) and **`hero_hp`** (not in the plan: a loaded game would otherwise refill her health; a terminal's rest sets it back to full). Battery is not saved. `GameState.live_flush` lets the live Red write her health and sword into the run just before any `to_dict()`. Loading clears the run (`slice_run`) and rebuilds the session from `sword` / `hero_hp`. Classic saves now also carry the three keys (harmless, empty).
  - **Saving off:** `SaveManager.saving_allowed` / `can_save()`; ActionRoom turns it off in rooms with `robots` or when she arrives in a robot form, and back on when it leaves; `save_slot`, `auto_save` and `SaveLamp.start_check` refuse. Lamps in such a room are disabled.
  - **Knock-out, now complete:** `RoomSnapshot` (`scripts/slice/room_snapshot.gd`, pure) holds her `HeroSession`, items, credits, flags and opened ids at the room's entrance. Continue puts all of it back (credits earned in the room are lost; `credit_cost` comes off the snapshot's credits), except **sticky** ids: a placement entry (any section, doors included) with `"sticky": true` keeps its `flag` / `opened_id` / `target_id` (and `door_<id>` for a door) set across the restart (`ActionRoom.sticky_ids()`; the hack-target code in VS-19 only has to write those keys). The Continue screen is wired: the HUD opens it on `knocked_out_rule` and calls `ActionRoom.continue_after_knockout()`; `slice.json` `retry.auto_continue_s` is now 0 (the stand-in timer is off). The ActionHud's Quit button only emits `quit_requested` and quits the app (`auto_quit`); going back to the title needs Main to listen (UI Programmer / Integrator, not done here).
  - Throwaway proof content grew: the graybox hub has a save terminal (rests), a shop counter, a job board and a barking vendor (`graybox_placements.json`, `graybox_jobs.json`, `data/dialogue/slice_graybox.json`; scenes regenerated by `scripts/tools/make_graybox_rooms.py`). Tests: `integration/test_town_systems.gd`, `test_slice_save.gd`, `test_slice_retry.gd`, `unit/test_room_snapshot.gd`.
- **2026-10-09, Combat Programmer, Decision 1 answered by Ross ("kingdom hearts / final fantasy inspired menu system"): the API the command deck's hack submenu drives (UI Programmer, VS-11: please use these names; tell me if you need others).** Get the caster with `hero.hack_caster()` (null in a room without a director). Pure `HackSelector` only holds the choice; the casting calls live on `HackCaster` because they need the world.
  - **Choose:** `HackCaster.set_current(id) -> bool` (also `HackSelector.set_current`), `current() -> StringName`. Announces `director.hack_selected(id)`. Works in either pick mode. `select_step(+1/-1)` and `select_slot(0..3)` (the 1 to 4 keys, wheel, d-pad) stay for the quick shortcuts and only act in pick mode.
  - **Fire:** `cast_current() -> bool` fires the current hack; `cast_direct(id) -> bool` fires a named hack without changing the current one (a shortcut, or a menu entry picked and confirmed). Both put a request in Red's input buffer, exactly like the hack button, and return true if a request was made (false: unknown id, town mode, robot form, or Red down). The cost, cooldown, jam, target and air rules still decide whether it casts; a refusal arrives as `director.hack_refused(info)` with a `reason`. The hack button itself fires the current hack in pick mode and picks by the situation in automatic mode (`hack_pick_mode` knob).
  - **Ask:** `hack_status(id) -> {id, name, icon, role, cost, cost_all, affordable, ready, castable, reason, cooldown}` (a menu row: grey it when not `castable`, show `cost`, "all" when `cost_all`, a sweep from `cooldown`), `hack_list()` (all four, menu order), `battery_charge()`, `battery_capacity()`, `shown()` (the hack the panel highlights: the current one, or the last used in automatic mode), `is_auto()`, `overclock_preview()` (the thing Overclock would take, for the marker), `cooldown_fraction(id)`. Signals to bind: `battery_changed`, `hack_locked`, `hack_selected`, `hack_cast`, `hack_refused`, `hijack_changed` (all on the director).
  - Test: `integration/test_hacks.gd` ("the command deck's API"), `unit/test_hack_selector.gd`.
- **2026-10-09, Level Designer, VS-14 (night market graybox).** Nine `market_*` scenes (`scenes/slice/market/`, from `scripts/tools/make_market_rooms.py`), `data/slice/rooms.json`, `placements.json`, `jobs.json`, `story_scenes.json`, `market.json`, placeholder dialogue and two shops. Contract notes for other roles:
  - Level scenes are **plain Node3D roots** (Main wraps them in ActionRoom); they carry `Spawns`, `CameraRig`, `CameraBounds`, `WorldEnvironment`, `Collision`, a moon and a fill light. They carry **no RoomLook**, so the fog and ambient are the ActionRoom's defaults (a little dark); if the market needs its own ambient, the look profile `market_ps2` (VS-39) or an ActionRoom `ambient` entry in `rooms.json` is the place.
  - `rooms.json` has a new optional top-level `pending_rooms` ({room: [spawns]}): doors may point at a room that is not built yet only while it is listed there (Gate 4's barrier leads to `junk_j1:from_market`). `SceneRouter._can_enter` refuses an unknown room with a logged error, no crash; the barrier is locked until `job_main_taken` anyway. **Delete the entry when the junkyard's `junk_j1` is added.**
  - Ross's four map answers are one-line switches in `data/slice/market.json` `switches` (market loud, repair shop in the dock office, one way after the loader, colossus visible). Sound sources for the Audio Designer are `market.json` `ambience`.
  - The Courier Pass is the flag `courier_pass`, set with `job_main_taken` by the main job (`yard_9`); `job_main_taken` opens the barrier (`requires.flag`). No new key item was added: `test_items_data` pins the key-item list, so a real bag item needs the Combat Designer to widen items.json and that test.
  - Ume's window is mounted NPC `mk_sq_ume` at y = 1.95 (reach 3.2); the test treats a placed NPC above 1.5 m as mounted.
  - Hatch pair: `mk_hd_hatch` (hideout, in the floor) and `mk_rp_hatch` (repair shop, foot of the ladder) are `mat`-style 1 m doors; arriving inside a door's zone does not trigger it (Door arms only after Red leaves).


- **2026-10-09, UI Programmer, VS-11 (action HUD).** `ActionHud` (`scripts/ui/slice/action_hud.gd`, scene `scenes/ui/slice/action_hud.tscn`) extends `SandboxHud`, so the sandbox HUD parts (health, Noise, Lights On bulb, reticle, enemy bars, numbers, call-outs, feel panel) are inherited and it binds to any host with the sandbox's host methods. `data/slice/slice.json` `hud.scene` now points at it. The sandbox keeps `SandboxHud`. Words: `data/text/slice_ui.json`; layout, timing, colors, placeholder hack icons: `data/ui/slice_ui.json`.
  - **What it listens to** (all optional): director `battery_changed`, `hack_locked`, `hack_selected`, `hack_cast`, `hack_refused`, `hijack_changed`, `feature_changed`; host `knocked_out_rule(rule)` (opens Continue unless rule is `none`), `continue_started`, `continue_after_knockout()` (called when Continue is chosen), `get_boss_fight()`. Not in the director yet: `radio_said(speaker, text)` (use `hud.radio_say("vela", "...")` today).
  - **Boss bar contract (for BossFight):** an object (`host.get_boss_fight()`, else the director) with signals `boss_bar_shown(info: {name, hp, hp_max, phases: [{id, name}], phase})`, `boss_hp_changed(hp, hp_max)`, `boss_phase_changed(index, name)`, `boss_bar_hidden()`. Or call `hud.show_boss_bar / set_boss_hp / set_boss_phase / hide_boss_bar`.
  - **Location card:** shows on `SceneRouter.room_entered` from the rooms file entry: `name`, optional `kind` (subtitle), optional `subtitle`, `area` (same area = no second card), `card: false` to opt out.
  - **Ross's Decision 1 answer (command deck).** Bottom-left `CommandDeck`: Attack / Hack / Item. The Hack bar shows the current hack and its cost; **R / d-pad up** ("choose") opens a list of the four with keys 1 to 4 and costs; **G / d-pad down** moves the deck focus. The pick is still the host's `HackSelector`: the HUD mirrors `hack_selected` and never keeps its own pick, so wheel, d-pad left/right and 1 to 4 move the list's cursor. Item says "coming later". The game keeps running; feel knobs `deck_slowmo` (off) and `deck_slowmo_scale` (0.35) slow it while the list is open (`Engine.time_scale`, restored on close, pause and unbind). New actions `deck_open` and `deck_scroll` are added by the HUD at boot (like HackCaster's); they should join `input_sorting.json`'s dungeon context (d-pad up/down already move Red there).
  - **Asked of the Combat Programmer (HackCaster), not done by me:** (1) `select_id(id)` on `HackCaster` (selector `select_id` + the `hack_selected` signal), which `ActionHud.pick_hack()` calls for mouse picks; (2) the shortcut layer Ross asked for: keys 1 to 4 should FIRE directly (today they only select), and holding the guard button (L / pad left shoulder) plus a face button fires hack 1 to 4 directly; the HUD list already prints the numbers 1 to 4; (3) `hack_cast` info could carry `cooldown_ms` (the HUD uses hacks.json x the cooldown knob meanwhile).
  - Feel panel: the tab strip now scrolls when there are more groups than fit (`FeelPanel._tab_rects`), so new groups can't overflow again.
- **2026-10-09, Gameplay Programmer, the slice front door.** `TitleScreen` gained `text_id` and `ask_hero_name`; in slice mode Main sets them (`data/text/title_slice.json`: "UNTITLED", a GRAYBOX tag, New Game / Continue / Config / Quit, no Battle Test; New Game skips the name window and uses "Red"). The classic title is untouched. Continue loads the newest save in `user://slice_saves`. `ActionRoom` sets the HUD's `auto_quit` off and relays its `quit_requested` as `quit_to_title_requested`; Main connects that (deferred) to `go_to_title()`, which in slice mode also frees the persistent HUD and lets go of any pause (`SandboxPauseGate.clear`). `Main._process` still has no Esc-to-title in slice mode (the pause menu owns Esc). `default_mode` stays `classic` until VS-35. Test: `integration/test_slice_front_door.gd` (graybox rooms, plus one test on the real slice data: title, New Game, the market hideout).
- **2026-10-09, Gameplay Programmer (second), VS-19 (world hack targets) and VS-21 (RobotStage).** Not committed. Files: `scripts/slice/targets/` (`hack_target.gd` base, `hack_door.gd`, `hack_terminal.gd`, `hack_crane.gd`, `drone_line.gd`, `hack_loader.gd`), `scripts/slice/robot_stage.gd`, data `data/slice/robot_rooms/` (`junk_j4`, `junk_j5`, throwaway `gb_loader`, `gb_cab`) and a new `hack_targets` section in `data/slice/placements.json`. Tests: `integration/test_hack_targets.gd`, `integration/test_robot_stage.gd` (kit: `robot_stage_kit.gd`).
  - **HackTarget (4.5, as written plus):** joins `hack_targets` (what ZapDrone and EmpPulse already read, no hack code changed) and, while lockable and not done, `lock_targets`. Settings come from `Placements` section `hack_targets` under `target_id` (or a `data` dictionary for tests). **Sticky = a GameState `flag`** (key `flag` in the entry, default `hack_<id>_done`), so it is saved with the game and `ActionRoom.sticky_ids()` already keeps it across a knock-out restart. `take_hack` calls the kind's `_apply`, emits `hacked`, and `complete()`s unless the kind says otherwise. `interact` in `accepts` makes an `Interactable` child (the button finds it like any prop). New signal `completed(target_id)`.
  - **Kinds and their data keys** are listed in the `_about` of the `hack_targets` section. Fuse box (`HackDoor`): Zap sets its flag; a `Door` placement with `requires: {flag}` opens by it, or the box slides its own `slab` / a `door_path` node up and switches its collision off. Terminal (`HackTerminal`): sets `flag` and `also_flags`, shows `message` lines, `scene_requested(scene_id)` signal (nobody listens yet: the StoryDirector owner can). Crane (`HackCrane`): Overclock through a `Hijackable` child; `jobs` (done in order, each its own sticky `flag`, world-metre `path`, load `cargo` size or `cargo_path`, optional `smash` on arrival: nodes in group `crane_breakable` get `smash()` or `stomp()`). A job's progress is kept when the hijack ends early; the next Overclock carries on. Drone line (`DroneLine`): EMP on the dispenser pauses it `emp_stops_s`; a separate `PowerNode` (a lock target at `node_pos`, `zaps_needed` zaps, one pass of a Zap Drone counts once) ends it for good. It spawns through new `ActionRoom.spawn_enemy(kind, pos)` (the enemy must be in `combat/sandbox` `enemy_scenes`; **`signals_drone` is not there yet, Combat Programmer** - until then the line logs one warning and sends nothing). Loader (`HackLoader`, interact, per the Level Designer's "button press"): calls `RobotStage.wake_and_board()`.
  - **ActionRoom (small edits):** a room whose entry names `robots` builds a `RobotStage` child (`robot_stage` var; `get_robot_stage()` now returns it); `_apply_session` calls `place_in(form)` first; stage `form_changed` updates the room's form and re-emits `form_entered`, so the carried session says `small` after boarding; `reset_arena()` returns to the entry form; `spawn_enemy()` was cut out of `_spawn_enemies()`; `sticky_ids()` also reads each crane job's `flag` and skips non-dictionary notes. **Health across bodies:** a session saved in one body size (Red 120) is applied as a fraction in another (the loader's 480), not as a raw number.
  - **RobotStage (5.3):** `bind(room)` / `setup(host, player, camera, lock, data)`; builds the CS-21 `RobotYard`, `ScaleController` and `RobotBoarding` unchanged in behaviour. API: `board()`, `wake()`, `wake_and_board()`, `place_in(form)`, `dock()`, `disembark()`, `reset()`, `form()`, `mode()`, `is_awake()`; signals `form_changed`, `woke`, `boarding_started`. A robot's `wake_flag` (`robot_rooms` `small_robot`) keeps the loader asleep (no ring, walking in does nothing) until set. **CS-21 files touched (additive, sandbox behaviour and its tests unchanged):** `RobotBoarding` gains `boarding_enabled`, `board_now()`, `dock_now()`, `place_in(form)` and no longer needs a colossus in the room; `RobotYard.build` skips ground when data says `"ground": false`, builds only the robots the data lists, and takes `kinds` from `combat/robot_yard.json` when the data has none; `ScaleController.bind` falls back to the level's first `DirectionalLight3D` for shadow range. **Hacks off in robot forms** was already in `ActionPlayer` (VS-9); the stage adds nothing. Still the HUD's job: hide the battery panel on `form_entered`.
  - **Open for others:** (1) J3's crane `path` points and the pit's rims are placeholders from the map; the Level Designer sets them (VS-20). (2) "Loader-only scrap walls" (VS-22) are not done: a SmashProp has no form check yet. (3) The arena's `robot_rooms/kasp_arena.json` (loader parked at the gate, colossus standing) is for whoever builds the arena; `RobotStage.place_in(&"small")` then `dock()` is the whole transition. (4) `disembark` and `interact` are read straight from the InputMap by `RobotBoarding`; `input_sorting.json` has not been checked against them.
- **2026-10-09, Combat Programmer, VS-18 (drone and turret) and the command deck's asks.** Not committed.
  - **`SignalsDrone`** (`scripts/combat/enemies/signals_drone.gd`, scene `scenes/actors/enemies/signals_drone.tscn`) and **`WallTurret`** (`wall_turret.gd`, `wall_turret.tscn`) are `ActionEnemy` subclasses driven by the Designer's data (`enemies.json` entries with their tags, `moves.json` sets `signals_drone` / `wall_turret`). Both are in `sandbox.json` `enemy_scenes`, so `ActionRoom` can spawn them by id. Drone: hovers at `flying.hover_height_m` (body centre) with a bob, rears up in the dive's wind-up, drops to Red's height for the dive, sinks to 0.6 m for the 1.1 s recovery (sword height), falls to the floor when staggered or EMP'd (3 s), is not "airborne" for juggles unless launched. Turret: never moves (hits shake it but never shove it), turns 60 degrees a second inside `mount.yaw_range_deg`, tilts to Red, shows the laser from the first frame of the burst, stops tracking at `track_ms` (the aim lock; `aim_locked()`), then three bolts down the locked line; hijacked it fires `burst_ally` about every 1.4 s (`hijack.interval_ms` rebuilds the brain's attack timing while it is Red's). `CombatDirector.hijack_priority_tags` (empty by default; `BossFight` sets `["relay"]`) makes a hijacked unit go for those tags before the nearest enemy. Tags were already in the Designer's data (cop, heavy, drone, turret); EMP stuns and Zap bonuses read them. Test: `integration/test_drone_turret.gd` (17 checks).
  - **For the Combat Designer:** the turret's `brain.circle_range_m` of 0 would leave its brain walking toward Red forever (it never reached "circle", so it never fired); `WallTurret` overrides it with `mount.range_m`. Change the data to 30 if you would rather it say so. Zap now leads a moving target (aims where a walking or circling enemy will be when the drone arrives); it still flies straight.
  - **Command deck asks (UI Programmer):** `HackCaster.select_id(id)` is `set_current` under the deck's name. Keys 1 to 4 now FIRE hack 1 to 4 directly (`fire_slot(i)`; they no longer select; the current hack is unchanged). Holding the guard button (`parry`) or lock-on and pressing a face button fires 1 to 4 and the face button does not do its own job (pad A jump = 1, B dash = 2, X light = 3, Y heavy = 4; keyboard Space, Shift, J, K); mapping in `data/combat/hack_shortcuts.json`; a press out of the guard brace cancels the brace into the cast. Caveat: tapping lock-on still toggles the lock, so the guard button is the cleaner modifier. `hack_cast` info now carries `cooldown_ms`.
  - **Input.** `data/slice/input_sorting.json`: `hack_prev`, `hack_next`, `hack_1` to `hack_4`, `deck_open`, `deck_scroll` joined the dungeon context; the four d-pad pairs (`move_*` with the deck and picker actions) are allowed overlaps, because **`ActionPlayer` no longer walks on the pad's d-pad** (`dpad_walks`, default false; the menus still use d-pad through `move_*`; the left stick moves Red). `InputSorting.ensure_slice_actions()` registers HackCaster's and the deck's actions (called by `apply()`).
  - **Text.** The controls card and Config screen now say "Hack" (`data/text/sandbox.json`, `config.json`), not "Hack (coming later)".
- **2026-10-09, Gameplay Programmer (second), VS-30 (boss phase transition) and the PHASE-CHANGE HOOK for BossFight (Combat Programmer: please confirm or change in this section; I built against a stub in the test).** Not committed. Files: `scripts/slice/boss_transition.gd`, `data/slice/boss_transition.json`, `data/slice/robot_rooms/kasp_arena.json` (+ throwaway `gb_arena`), `ActionRoom.set_phase_checkpoint()`. Test: `integration/test_boss_transition.gd` (stub `StubFight`).
  - **The hook, both directions.** `BossFight` creates a `BossTransition` as a child of the arena room and calls `transition.bind(room)` (or `setup(host, stage, player, cfg)`). When the rig phase ends (the jack-in hit lands or the dish and the rig are done) it calls **`transition.begin() -> bool`** (needs Red on foot and a loader and colossus in the room's robot data; false otherwise). `BossTransition` tells it back with signals **`step_started(step)`** / **`step_finished(step)`** (`kasp_escape`, `mech_assemble`, `board_loader`, `drive`, `dock_colossus`: for the StoryDirector `boss_phase` steps and the HUD), `crane_poured(crane_id)`, `radio_said(speaker, text)` and **`finished`**: control is back in the colossus, so BossFight starts phase 2 (spawns / activates the junk mech, shows the bar) on `finished`. Optional refs BossFight may set before `begin()`: **`transition.kasp`** (the seat's Kasp node; he is moved, then hidden) and **`transition.mech`** (the junk mech; if it has `set_assemble_progress(t: float)` it is called every frame from 0 to 1 during `mech_assemble`; without them plain stand-ins are drawn). Nothing in the transition knows boss health or patterns.
  - **Per-phase retry.** BossFight owns *which* point; `ActionRoom` supplies the mechanism: **`set_phase_checkpoint(spawn: String, form: StringName, full_health: bool = true)`** makes the next knock-out reload the arena at `spawn` with Red in `form` (`full_health` false keeps the health and battery she walked in with; true is full health and a full battery), flags and items as they are now; `clear_phase_checkpoint()` goes back to the room's entrance. BossFight calls it at each phase start: phase 1 `("retry_phase1", &"red", false)`; phase 2 `("retry_phase2", &"huge")` when `finished` arrives. After the reload BossFight sees the room entered at `retry_phase2` (form `huge`) and calls **`transition.start_docked()`** instead of `begin()` (the colossus display moves to `colossus_dock_pos`, the gate is open, the Heap stands, Kasp is hidden; no sequence, no `finished`), then starts phase 2 itself. `ActionRoom.continue_target()` checks the phase checkpoint first. Inside the transition she cannot be hurt, so there is no retry step there (`skip_to_next` is moot).
  - **What the scene must have** (names from docs/maps/kasp_arena.md; Level Designer VS-29, please keep): `hushmaster_start`, `kasp_escape_target`, `mech_start`, `crane_a`, `crane_b`, `crane_c`, `stockade_e_gate`, `loader_parked` (yaw = the way the loader faces), `colossus_cradle`, `colossus_dock_pos`, `dock_approach`, spawns `retry_phase1` and `retry_phase2`; **new: `ring_road`**, a Node3D whose Node3D children in order are the loader's drive waypoints (or markers `ring_road_1`, `ring_road_2` ...; with none the loader drives straight to `dock_approach`). Names are data (`boss_transition.json` `markers`), so a different name is a data edit. `stockade_e_gate` is hidden and its collision shapes switched off when the cranes finish (or its own `open()` is called if it has one). The arena's rooms.json entry needs `robots: "kasp_arena"` (`robot_rooms/kasp_arena.json`: loader at (8, 56) facing north, colossus in its cradle (105, 0) facing west; the Level Designer adds the smashable clusters there).
  - **The steps and how they run.** `kasp_escape` (4 s): Kasp is thrown from the seat (`hushmaster_start` plus an offset), runs to `kasp_escape_target`, a cage comes down and lifts him 45 m. `mech_assemble` (8 s): the three cranes pour at 0, 0.8 and 1.6 s (signal each; a shake on the first), the Heap rises, the east gate opens, Vela barks "Get to the loader." (placeholder words in the data, the Writer's). `board_loader`: **Red has control throughout steps 1 to 3**; this step has no timer; the loader is re-parked at `loader_parked` if she climbed out elsewhere, and she boards through the normal CS-21 ring and sequence. `drive`: scripted at 11 m/s along `ring_road` to `dock_approach` (skippable: `skip_drive()`), while the colossus wakes and walks 3.5 s from its cradle to `colossus_dock_pos`. `dock_colossus`: `RobotStage.dock()`, the unchanged 4.5 s CS-21 docking; **the scale switches inside it** (form `small` until the swap at 3.6 s, then `huge`, camera, haze and sound eased by the ScaleController); if the docking cannot start for 3 s (she is not on the ground) she is placed in the colossus without the show so the fight is never stranded. **Red cannot be hurt from `begin()` to `finished`** (iframes refreshed every frame; she is a ghost during the docking anyway).
  - **Also changed:** `ActionRoom.phase_checkpoint` (var), `set_phase_checkpoint`, `clear_phase_checkpoint`, and `continue_target()` reading it. Nothing else in shared files.
  - **Open:** Vela's and Kasp's lines are placeholders in `boss_transition.json`; no siren or crane audio yet (audio request to the Audio Designer); the Heap and the cage are plain boxes until VS-28 and VS-40; a "skip" button for the drive is not bound to any input.
- **2026-10-09, Combat Programmer, VS-26 / VS-27: CONFIRMING the phase-change and retry hook the second Gameplay Programmer wrote above (VS-30), as built on my side.** Agreed with no changes; the details I am building to:
  - `BossFight` (`scripts/combat/boss/boss_fight.gd`, group `boss_fight`) is a child of the arena room. `BossFight.bind(room)` reads `data/combat/bosses/hushmaster.json`, finds the named markers (`hushmaster_start`, `drone_hatch_a..c`, `turret_k_nw/ne/e`, `retry_phase1`, `retry_phase2`) anywhere under the room, builds the Hushmaster at `hushmaster_start`, and calls `room.set_phase_checkpoint("retry_phase1", &"red", false)` when phase 1 begins. It creates the `BossTransition` (`transition.bind(room)`), sets `transition.kasp` to the Hushmaster's seat Kasp and `transition.mech` when phase 2 exists, and on the end of phase 1 (jack-in done or the body at 0) calls `transition.begin()`. On `transition.finished` it calls `room.set_phase_checkpoint("retry_phase2", &"huge")` and starts phase 2 (VS-28). On entry at `retry_phase2` (form `huge`) it calls `transition.start_docked()` and starts phase 2 itself. A retry at `retry_phase1` skips the intro and starts phase 1 again with the battery floor (`start.battery_floor` 60) applied.
  - **Boss bar:** `BossFight` has the four signals the HUD asks for (`boss_bar_shown(info)`, `boss_hp_changed(hp, hp_max)`, `boss_phase_changed(index, name)`, `boss_bar_hidden()`), and the same four are on `CombatDirector` so the HUD's fallback works with no host method. **Gameplay Programmer:** add `get_boss_fight()` to `ActionRoom` (return the first node in group `boss_fight`) if you prefer the host route; the director route works today.
  - **`BossFight` public API** (so the transition, story steps and tests can drive it): `phase_id() -> StringName`, `phase_index() -> int`, `start(from_phase: StringName = &"")`, `phase_finished` signal (`phase_id`), `fight_finished` signal, `boss_actor() -> CombatActor`, `parts() -> Array`, `skip_phase()` for tests. Hacks stay on in phase 1; `hijack_priority_tags` is set to `["relay"]` for the fight.
