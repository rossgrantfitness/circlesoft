# Battle API contract (Milestone 2)

> Shared contract so the Battle Programmer (model), Technical Artist (stage), UI Programmer (HUD) and Audio Designer can build in parallel. Design source: docs/design_doc.md "Battle system" (approved). Architecture source: docs/tech_plan.md "Battle system", data formats and Testing. If this file and the tech plan disagree, this file wins for M2; propose changes to the integrator rather than silently diverging.

## Who owns what (don't edit another owner's files; ask)

| Owner | Files |
|---|---|
| Battle Programmer | `game/data/battle/*`, `game/data/party/characters.json`, `game/data/party/growth.csv`, `game/data/party/xp_curve.csv`, `game/scripts/battle/model/*`, `game/scripts/progression/*`, `game/tests/**/test_battle_*.gd`, `game/tests/sim/*` |
| Technical Artist | `game/scenes/battle/*`, `game/scripts/battle/view/*`, `game/shaders/screen_static.gdshader`, `game/art/placeholder/enemies/*`, `game/data/battle_stage/*`, `game/tests/**/test_battle_stage*.gd`, `game/tests/visual/capture_battle*.gd` |
| UI Programmer | `game/scenes/ui/battle/*`, `game/scripts/ui/battle/*`, `game/data/ui/battle_ui.json`, `game/data/text/battle.json`, `game/tests/**/test_battle_hud*.gd` |
| Audio Designer | `game/audio/sfx/placeholder/battle_*`, new ids in `game/data/audio/sfx.json` (append only), `game/scripts/tools/make_battle_sfx.py` |
| Integrator (main session) | `main.gd`, title menu entry, test-room encounter trigger, `project.godot` input map |

Shared, read-only for everyone: `GameState`, `Config`, `DataDB`, `AudioManager`, `PsxLook`, `UiFonts`/`UiText`, the model contract in docs/style_guide.md.

## Input
- New action **`clutch`**: Space, Z, E, Enter / controller A (south). Integrator adds it to project.godot. Until then, tests call the controller's press methods directly.
- Command menus use the existing `confirm` / `cancel` / `move_*` actions.

## The model: `BattleController` (`scripts/battle/model/battle_controller.gd`, `class_name BattleController`, extends `RefCounted`)

Pure logic. No nodes, no rendering, no audio. Runs identically with a real clock (game) or a virtual clock (simulator, tests).

```gdscript
static func create(setup: BattleSetup) -> BattleController
func start() -> void                      # async; emits signals as the fight runs until battle_ended
func submit_command(cmd: Dictionary) -> void   # answer to command_needed
func press_down(t_usec: int) -> void      # Clutch button pressed (timestamp from _input)
func press_up(t_usec: int) -> void        # Clutch button released (hold-and-release)
func snapshot() -> Dictionary             # full current state (see Combatant)
func skip_requested() -> void             # speed up / skip an already-seen animation (optional for M2)
```

`BattleSetup` (`battle_setup.gd`): `encounter_id: String`, `party: Array[Dictionary]` (from GameState; ids + current hp/juice/level/statuses), `clock: BattleClock`, `press_source: PressSource` (Human / AutoTiming / sim players), `command_source` (null = wait for `submit_command`; the simulator passes a policy), `auto_timing: bool`, `wide_windows: bool`, `timing_offset_ms: int`, `rng_seed: int`.

`BattleClock`: `now_usec() -> int` and `wait_until_usec(t: int)` (awaitable). `RealClock` uses `Time.get_ticks_usec()`; `VirtualClock` jumps instantly.

### Signals (payloads are Dictionaries unless noted; ids are combatant ids like `"red"`, `"e1"`)
| Signal | Payload | Meaning |
|---|---|---|
| `battle_started(snap)` | `snapshot()` | Party and enemies, slots, models, HP/Juice. Encounter info: `encounter_id`, `can_run`, `is_boss`, `backdrop`. |
| `round_started(round, order, next_order)` | int, Array[String], Array[String] | Turn-order row: this round and next. |
| `turn_started(actor_id)` | String | Whose turn. |
| `command_needed(actor_id, options)` | `{attack: bool, skills: [{id, name, juice_cost, usable, target}], items: [{id, name, count, target}], defend: true, run: bool}` | Party only. UI answers with `submit_command`. |
| `action_started(action)` | `{actor, kind, skill_id, name, targets: [ids], t0_usec, timeline_ms: {windup, impact, end}, presses: [{index, type: "tap"/"hold_release"/"string", side: "attack"/"block", cue_ms, hold_by_ms, owner_id}], anim, show_name: bool}` | Starts an action timeline. **The view schedules the flash + ding + "!" itself at `t0_usec + cue_ms*1000`** for each press (one moment drives all three). `owner_id` = who gets the "!" (attacker for attack presses, defender for block presses). |
| `press_judged(info)` | `{actor, index, side, rating: "miss"/"nice"/"rad"/"totally_rad", delta_ms}` | Rating pop-up. Block side ratings map to Blocked! / Perfect Block! in the UI (`nice`/`rad` = Blocked!, `totally_rad` = Perfect Block!). |
| `hit(info)` | `{source, target, amount, kind: "damage"/"heal", blocked: "none"/"partial"/"perfect", payback: bool}` | At impact. Damage numbers, hit reaction, shake on TOTALLY RAD (view reads the rating from `press_judged`). |
| `stats_changed(id, hp, hp_max, juice, juice_max)` | | Bars. |
| `status_changed(id, status_id, added)` | String, String, bool | Icons. |
| `combatant_down(id)` / `combatant_revived(id)` / `combatant_fled(id)` | String | White flag leave, K.O. |
| `action_finished(action)` | same dict | View returns actor to its spot. |
| `message(text)` | String | Short banner, e.g. "Can't run from this one!", "Noise Ticket! No skills." |
| `battle_ended(result, report)` | `"win"/"lose"/"ran"`, `{xp, credits, drops: [{item, count}], level_ups: [{id, from, to, gains: {stat: n}, learned: [skill ids]}], final_ko_target}` | Victory screen / game over. Last hit freezes for the K.O. beat (view/UI). |

Timing rule: the model judges presses only from `press_down`/`press_up` timestamps vs. `t0_usec + cue_ms*1000 + timing_offset`. The view never decides a rating. Missing never hurts (miss = normal hit/normal hurt).

### Combatant (inside `snapshot()["combatants"]`)
`{id, side: "party"/"enemy", slot: 0..3, name, kind (character or enemy id), model: "res://...glb", hp, hp_max, juice, juice_max, level, speed, statuses: [ids], down: bool, is_boss: bool}`

## The stage (`scenes/battle/battle_scene.tscn`, Technical Artist)
- Root script `battle_scene.gd`: `func start_battle(setup: BattleSetup) -> void`, signal `finished(result: String, report: Dictionary)`.
- Builds the controller (`BattleController.create(setup)`), spawns combatant views from `battle_started`, instances the HUD (`res://scenes/ui/battle/battle_hud.tscn`) and calls `hud.bind(controller)`, forwards Clutch input (`_input` timestamps → `press_down`/`press_up`), plays flash/ding/"!" cues, lunges, hit reactions, K.O. freeze, screen shake, the radio-static transition in and out.
- Minimal animation (Ross, 2026-10-06): use each model's `idle`; attacks, hits and K.O. are procedural tweens (lunge, recoil, squash, fall over). No new authored clips.
- Until the real controller lands, build against a small stub in your own tests that emits the signals above.

## The HUD (`scenes/ui/battle/battle_hud.tscn`, UI Programmer)
- `func bind(controller: BattleController) -> void`: connects to the signals, answers `command_needed` with `submit_command`.
- Command list, targeting cursor, turn-order row (this round + next), HP/Juice per party member, rating pop-ups, "!" over heads (positions come from the stage: `stage.screen_pos_of(id) -> Vector2` on the battle scene), K.O.!, victory screen (totals count up, level-ups, one press skips), game over / Retry stub, battle messages.
- Uses the shared look: UiWindow, UiText, Nunito + drop shadow, `ui_theme.json`. Rating colors from style_guide.md ("Ratings" row).
- Until the real controller lands, test against a stub emitting the signals above.

## Commands (`submit_command`)
`{kind: "attack", targets: ["e1"]}` · `{kind: "skill", skill_id: "porch_light", targets: [...]}` · `{kind: "item", item_id: "ration_bar", targets: ["otis"]}` · `{kind: "defend"}` · `{kind: "run"}`. Targets are always arrays (all-enemies skills send every live enemy id).

## SFX ids (Audio Designer appends to sfx.json; everyone calls `AudioManager.play_sfx(id)`)
`battle_ding` (the cue; must be short and sharp), `battle_hit`, `battle_hit_big`, `battle_rating_nice`, `battle_rating_rad`, `battle_rating_totally_rad`, `battle_block`, `battle_perfect_block`, `battle_payback`, `battle_ko`, `battle_down`, `battle_flee`, `battle_heal`, `battle_static_in`, `battle_static_out`, `battle_victory` (short jingle), `battle_game_over`, `battle_menu_open`.
