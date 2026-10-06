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

## Changes
> Additions agreed while building. Newest at the bottom. Add yours here instead of editing the contract above silently.

### 2026-10-06, UI Programmer (M2-7): the HUD's side of the contract
**Where it lives.** `BattleHud` (`scripts/ui/battle/battle_hud.gd`, scene `scenes/ui/battle/battle_hud.tscn`) is a `Control` that lives on the `UiStage` root and is laid out in **384x216 stage pixels** (the same pixels as the 3D picture, so `screen_pos_of` can be used as is). `BattleHud.install(tree)` builds it on the stage if you would rather not instance the scene yourself. The stage may hide it (`visible = false`) until the intro is over.

**Binding.** `bind(controller: Object)` (typed `Object` so any controller-shaped thing works, including test stubs; the real `BattleController` is one). It connects every signal in the table above, takes `controller.snapshot()` if it already has combatants, and answers `command_needed` with `controller.submit_command(cmd)`. `unbind()` disconnects. While bound the HUD is in the `ui_modal` group (so the field menu stays shut).

**Stage to HUD (all optional, the HUD checks before it calls).**
| What | Detail |
|---|---|
| `hud.stage = battle_scene` | The HUD reads `screen_pos_of(id)` (the head point; if the method takes a second `anchor` argument, `&"center"` is used for damage numbers). A `Vector2.ZERO` answer (unknown id, behind the camera) falls back to fixed slots from `battle_ui.json`, so the HUD still works on a plain background. |
| `stage.cue_fired(owner_id, press_index, stage_pos)` | **The "!" over the right head.** The stage already tells the HUD when. The HUD draws the 2D "!" (and the bigger "!!" when the owner `is_boss`) **only while `stage.cue_marker_enabled` is false**, so there is never a double. Flip that flag to switch from the stage's 3D marker to the HUD's. A stage that prefers to call directly can use `hud.show_cue(owner_id: String, big: bool = false)`. |
| `stage.ko_beat_started(target_id, stage_pos)` | The HUD shows "K.O.!" (it also detects the final enemy going down on its own, so either path works; it only ever shows once per fight). |
| `stage.set_target_highlight(ids: PackedStringArray)` | The HUD calls it while a target is being picked (and with `[]` when done), so the stage can light the rings. |
| `hud.ko_started(target_id, freeze_s)` | Signal: the K.O.!'s moment. `freeze_s` comes from `battle_ui.json` (`ko.freeze_s`). The stage already runs its own freeze (`ko.freeze_ms` in stage.json); this is only for a stage that wants to follow the HUD instead. |

**HUD to stage.**
- `hud.finished(result: String, choice: String)` is emitted **after the end screens are done**: victory dismissed (`"win"`, `"continue"`), game over answered (`"lose"`, `"retry"` or `"title"`), or a successful run once "Got away safely!" has been shown (`"ran"`, `""`). The stage's `end.hud_done_signals` list already includes `finished`, so `battle_scene` waits for it before leaving the fight.
- `hud.retry_requested` and `hud.title_requested` (no arguments) fire first on the game over screen, for the integrator to wire up Retry and Back to title (the retry itself is not wired yet).
- `hud.command_submitted(command)` fires just before the command goes to the controller (handy for tests and tutorials).

**Target kinds** (the `target` field of skills and items). The HUD understands: `one_enemy`, `all_enemies`, `one_ally` (standing allies), `one_down_ally` (Down for the Count only), `all_allies`, `self`. Anything else (`primary`, `random_other_enemy`, ...) is treated as `one_enemy`. `all_*` kinds light up the whole side and send every live id; `self` skips the pick. Items in `command_needed.options.items` may carry `usable: false` (greyed with "Can't run from this one!"); `count <= 0` is greyed as "None left.". A skill with `usable: false` is greyed with the reason Noise Ticket (if the user has that status), else not enough Juice. The model stays the single source of truth for `usable`.

**Events the HUD reads a little more closely than the table says.**
- `press_judged`: the pop-up goes over the **press owner** (`owner_id` from the matching entry of the action's `presses`, looked up by `index`; an `owner_id` key in the info itself wins). Attack side: `nice` / `rad` / `totally_rad` show Nice! / Rad! / TOTALLY RAD!. Block side: `nice` and `rad` show Blocked!, `totally_rad` shows Perfect Block!. A `miss` shows nothing.
- `hit` with `payback: true`: **Payback!** pops up over the `target` (the enemy being paid back), so it never sits on the defender's Perfect Block!. A hit with `amount > 0` shows a damage number (white) or heal number (lime); a blocked hit with 0 damage shows no number.
- `action_started` with `show_name: true`: the skill name slams onto the screen from `action.name`. No speaker, no voice.
- `combatant_down` of the last standing enemy shows the K.O.!; `battle_ended("win")` waits for the K.O. beat (about 1.1 s), then shows the victory screen.
- `battle_ended("lose")` shows Game Over after about 0.9 s. `battle_ended("ran")` shows the controller's own "Got away safely!" message once.

**Sounds.** The HUD plays `battle_menu_open`, `battle_rating_nice` / `_rad` / `_totally_rad` (on the press), `battle_ko` (with the K.O.!), `battle_victory` and `battle_game_over`. The stage keeps `battle_block`, `battle_perfect_block`, `battle_payback`, `battle_hit*`, `battle_ding` and the rest (it already plays them from `hit`), so the HUD leaves those ids empty in `battle_ui.json` to avoid doubling. Menu ticks, confirm and back use the shared UI sounds (`menu_tick`, `menu_confirm`, `menu_back`).

**Config (new settings the model already reads).** `Config` now holds `auto_timing`, `wide_windows` and `timing_offset_ms` (clamped to the range in `battle_ui.json` "settings": -200..200 in steps of 10). `Config.get_battle_timing()` returns `{auto_timing, wide_windows, timing_offset_ms}` for a `BattleSetup`. The field menu's Config page has rows for all three. Old settings files without the new keys load fine.

**Input.** While the command menu is open the HUD consumes `move_*`, `confirm` and `cancel` (and the mouse: hover moves, left click picks, right click backs out). While the victory screen is up, confirm, cancel, `clutch` or a left click skip the counting (first press) and then leave (second press); presses in the first 0.4 s are ignored so the Clutch press that landed the last hit cannot skip it. At any other time the HUD does not touch input, so Clutch always reaches the stage.
