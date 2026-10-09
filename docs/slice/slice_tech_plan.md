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
