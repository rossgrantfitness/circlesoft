# Combat API contract (Combat Sandbox)

> **For Ross:** this is the builders' rulebook for the combat sandbox: who builds which file, what the buttons are, how moves are written down as data, and how the pieces talk to each other, so five people can build at once without stepping on each other. Nothing in it needs your approval now. Every feel number in it is a starting guess that you change by playing, with the feel-knobs panel.

> Owner: Technical Director. Status: **binding for the sandbox from 2026-10-08.** Sources: docs/decisions.md (2026-10-08, action RPG plan approved), docs/pivot/buildability.md (sections 3, 5, 6, 8), docs/pivot/concept_pitches.md (Pitch A, LIGHTS ON). Modeled on docs/battle_api.md. If this file and buildability.md disagree, this file wins. Don't change it quietly: add to "Changes" at the bottom and tell the integrator.
> Scope: exactly the approved sandbox (D2). **Not in the sandbox** (Later list): Rip, double jump, gadget arm, goggles toggle, enemies fleeing from Lights On, materials, crafting, saves.
> Combat mechanics are Ross's call (Playbook, Game design & battle: Level 1 for numbers and names only). Where this contract had to pick a mechanic, it's a **toggle in the feel panel** so Ross picks by playing (see 4.9, "Ross picks by playing").

---

## 1. Who owns what (don't edit another owner's files; ask)

All paths are under `game/`. "New" unless marked.

| Owner | Files |
|---|---|
| **Gameplay Programmer** | `scripts/combat/action_player.gd` (Red's state machine over `PlayerMotion`), `scripts/camera/orbit_camera.gd`, `scripts/camera/lock_on.gd` (node), `scripts/camera/lock_on_math.gd` (pure), `scripts/sandbox/combat_sandbox.gd` + `scenes/sandbox/combat_sandbox.tscn` (arena, pillars, a ledge, spawns, reset), `scripts/sandbox/sword_rack.gd`, `scenes/actors/action_player.tscn`, `data/combat/player_action.json`, `data/combat/camera.json`, `data/combat/sandbox.json`, the **sandbox export presets** (two new presets appended to `export_presets.cfg`; existing presets untouched). Tests: `tests/unit/test_lock_on_math.gd`, `tests/integration/test_action_player.gd`, `test_orbit_camera.gd`. |
| **Battle Programmer** (combat model) | `scripts/combat/model/`: `combat_clock.gd`, `combat_time.gd`, `move_set.gd`, `move_runner.gd`, `input_buffer.gd`, `juggle_rules.gd`, `hit_resolver.gd`, `parry_judge.gd`, `perfect_dodge.gd`, `style_meter.gd`, `lights_on.gd`, `attack_tokens.gd`, `enemy_brain.gd`, `feel_knobs.gd`. Nodes: `scripts/combat/combat_actor.gd`, `combat_director.gd`, `combat_layers.gd`, `hitbox.gd`, `hurtbox.gd`, `action_enemy.gd`; `scenes/actors/enemies/grunt.tscn`, `brute.tscn`. Data: `data/combat/moves.json`, `enemies.json`, `hit_feel.json`, `style.json`, `feel.json` (the file and its `combat` and `flare` groups); a new `parry` entry in `data/battle/timing_windows.json` (append only). Tests: one `tests/unit/test_<class>.gd` per model class above. |
| **Technical Artist** | Red's rig and clips (section 5); the split swords (`art/final/weapons/sword_*.glb`, done) and `data/combat/swords.json`; the Grunt (Cyberwolf Sentinel rig) and Brute blockout; `scripts/combat/gear_visuals.gd`; `scripts/combat/fx/`: `combat_fx.gd` (sparks, trails, flashes, sounds, shake calls), `sword_trail.gd`, `hit_spark.gd`, `flare_fx.gd`, `procedural_moves.gd` (clip fallbacks); `scripts/camera/camera_shake.gd`; `data/combat/fx.json`; the PS2 rendering (section 6): new shaders, the `grim_ps2` profile in `data/world/look_profiles.json`, the `640x360` entry in `data/world/psx_look.json`, `scripts/tools/psx_post_import.gd` (for `art/final/` only). Tests: `tests/integration/test_gear_visuals.gd`, `test_red_ross_rig.gd`, `tests/visual/capture_sandbox.gd`. |
| **UI Programmer** | `scripts/ui/sandbox/sandbox_hud.gd`, `feel_panel.gd`, `controls_card.gd`, `sandbox_pause.gd` and their scenes in `scenes/ui/sandbox/`; `data/ui/sandbox_ui.json`; `data/text/sandbox.json`; new rows and a swap set in `data/ui/config_screen.json` (append only). Tests: `tests/integration/test_sandbox_hud.gd`, `test_feel_panel.gd`. |
| **Audio Designer** | `audio/sfx/placeholder/combat_*.wav`, the `combat_*` ids in `data/audio/sfx.json` (append only), `scripts/tools/make_action_sfx.py`, `tests/unit/test_audio_action_sfx.gd`. (Already underway: 19 ids exist.) |
| **QA Tester** | `tests/unit/test_combat_data.gd`, `tests/integration/test_hit_flow.gd`, `test_sandbox_smoke.gd`, `tests/sim/test_combat_bots.gd`; reviews every builder's unit tests; bug log. |
| **Integrator** (main session) | `project.godot` (input actions, physics layer names, the `sandbox` feature-tag overrides), `scripts/core/main.gd` (sandbox boot). |

Shared, read-only for everyone: `GameState`, `Config`, `DataDB`, `AudioManager`, `PsxScreen`, `PsxLook`, `LookProfiles`, `InputRemap`, `PlayerMotion`, `ClutchJudge`, `BattleClock`, `UiFonts`/`UiText`, the model contract in docs/style_guide.md.

**Boot.** The integrator makes `main.gd` load `scenes/sandbox/combat_sandbox.tscn` into the PsxScreen world (skipping the title) when `OS.has_feature("sandbox")` or the command line has `-- --sandbox`. In `project.godot`: `config/custom_user_dir_name.sandbox="LightsOnSandbox"` and `config/name.sandbox="Lights On Sandbox"`, so the sandbox's files never mix with the old game's. The Gameplay Programmer's two presets ("Sandbox Windows", "Sandbox macOS") set `custom_features="sandbox"` and export to `../builds/sandbox/`. *Why this matters for the game: Ross double-clicks one file and is in the arena in seconds, and the shelved game is untouched.*

**Physics layers** (named in project.godot; constants in `CombatLayers`). Layers 1 to 8 stay as they are.

| Layer | Name | On | Mask |
|---|---|---|---|
| 1 | world | arena geometry | |
| 10 | player_body | Red's CharacterBody3D | 1, 11 (11 is off while dashing, so she dashes through enemies) |
| 11 | enemy_body | enemy CharacterBody3D | 1, 10, 11 |
| 12 | player_hurtbox | Red's Hurtbox (Area3D) | none |
| 13 | enemy_hurtbox | enemy Hurtboxes | none |
| 14 | player_hitbox | Red's Hitbox queries | 13 |
| 15 | enemy_hitbox | enemy Hitbox queries | 12 |
| 16 | interact | sword-rack stands | 10 |

---

## 2. Input actions

The integrator adds these to `project.godot`. Remapping goes through the existing `InputRemap`: the UI Programmer adds one `config_screen.json` row per new action and a new swap set `["jump", "light", "heavy", "dash", "parry", "lock_on", "camera_toggle"]`. The pause menu opens the existing Config screen's Controls page; overrides save to `user://config.json` as today.

| Action | Keyboard / mouse | Pad (Xbox / PlayStation) | Notes |
|---|---|---|---|
| `move_up/down/left/right` | WASD (+ arrows) | left stick, d-pad | existing |
| `camera_left/right/up/down` | mouse movement (read directly by OrbitCamera; mouse captured in the arena) | right stick (axes 2 and 3) | new |
| `jump` | Space | A / Cross | existing |
| `light` | J, left mouse | X / Square (button 2) | new |
| `heavy` | K, right mouse | Y / Triangle (button 3) | new |
| `dash` | Left Shift | B / Circle (button 1) | new |
| `parry` | L | LB / L1 (button 9) | new |
| `lock_on` | Tab, middle mouse | RB / R1 (button 10) | new. Press: lock to the best target or let go. No target in range: recenter the camera. Locked: flick the camera stick or mouse to switch targets. |
| `camera_toggle` | V | R3 (button 8) | new. Free camera ↔ action diorama. |
| `feel_panel` | F12 | Back / Share (button 4) | new. F1 to F11 are already the look-debug keys. |
| `start` | Esc | Start | existing; opens the sandbox pause menu (Resume, Reset arena, Controls, Quit). |

Shared buttons, on purpose: Shift is also `run`, Tab and pad Y are also `menu`, pad B is also `interact`/`cancel`, pad X is also `run`. The sandbox never listens to `run`, `menu` or `interact` (Red runs with the stick; the rack works by walking onto it), so nothing fights. Sorting the field actions against the combat ones is a slice task. Press timestamps: `Time.get_ticks_usec()` in `_input()`, as Clutch does.

---

## 3. Move data: `data/combat/moves.json`

One format for Red **and** enemies. **Times are milliseconds of the owner's combat time** (frozen during hit-stop, slowed during a flare); at 60 fps one frame is about 16.7 ms, and the debug overlay shows both. Positions are metres in the owner's local space: **+Z forward, +Y up, origin at the feet.** Every move's timing lives here; animation never decides timing.

```json
{
  "version": 1,
  "sets": {
    "red": {
      "entries": {
        "ground": {"light": "light_1", "heavy": "heavy", "launch": "launcher"},
        "air":    {"light": "air_1"}
      },
      "moves": {
        "light_1": {
          "name": "Light 1",
          "state": "ground",
          "startup_ms": 90, "active_ms": 60, "recovery_ms": 230,
          "cancels": {"chain": [130, 380], "dash": 150, "jump": 150, "parry": 150},
          "links": {"light": "light_2", "heavy": "heavy", "launch": "launcher"},
          "launcher": false,
          "motion": {"forward_m": 0.6, "from_ms": 0, "to_ms": 120},
          "magnet": {"range_m": 3.5, "cone_deg": 70},
          "hit": {
            "damage": 8, "hitstun_ms": 320, "knockback_m": 0.6, "launch_mps": 0.0,
            "knockdown": false, "hit_stop_ms": 50, "poise_damage": 8, "style_points": 10,
            "shake": "light", "spark": "slash", "sfx": "combat_hit_light"
          },
          "hitboxes": [
            {"from_ms": 90,  "to_ms": 120, "shape": "capsule", "radius": 0.45, "height": 1.4, "offset": [0.35, 0.8, 0.8], "rot_deg": [0, 0, 70]},
            {"from_ms": 120, "to_ms": 150, "shape": "capsule", "radius": 0.45, "height": 1.4, "offset": [-0.3, 0.7, 0.9], "rot_deg": [0, 0, 110]}
          ],
          "swing": {"sfx": "combat_swing_light", "trail": true},
          "anim": {
            "clip": "light_1",
            "keys": [{"at_ms": 0, "clip_s": 0.0}, {"at_ms": 90, "clip_s": 0.133}, {"at_ms": 150, "clip_s": 0.267}],
            "fallback": "swing_r"
          }
        }
      }
    },
    "grunt": {"moves": {"swipe": {"...": "same fields, plus the enemy-only fields below"}}},
    "brute": {"moves": {"slam":  {"...": "..."}}}
  }
}
```

| Field | Meaning |
|---|---|
| `state` | `"ground"` or `"air"`: where the move may start. An air move that touches the floor ends early into `land`. |
| `startup_ms` / `active_ms` / `recovery_ms` | The three phases. Total length = their sum. |
| `cancels.chain` | `[from, to]`: when a buffered press may start the linked move. A press earlier than `from` waits in the buffer and fires exactly at `from`. |
| `cancels.dash` / `.jump` / `.parry` | Earliest ms the move can be cut into a dash, jump or parry. Missing = not until the move ends. |
| `links` | Next move per input token: `light`, `heavy`, `launch`. |
| `launcher` | `true`: a hit pops the target up (`hit.launch_mps`), and a `jump` pressed inside `cancels.jump` after a hit makes Red follow it up (jump height from `hit_feel.json` `follow_jump`). |
| `motion` | Red's own lunge: `forward_m` spread over `from_ms`..`to_ms`; air moves may add `up_mps` and `hang_ms` (fall speed held at zero so she hangs with the target). |
| `magnet` | Attack snap: when the move starts, the owner turns to the best enemy inside this range and cone around the stick direction (the hard-lock target wins if there is one). |
| `hit` | Damage (flat base; the Lights On multiplier and guards apply on top), hitstun, knockback distance, launch speed, knockdown, **hit-stop** (both sides freeze; times `hit_stop_scale`), poise damage, Noise points, and the shake / spark / sound ids (shake and spark ids live in `fx.json`, sound ids in `sfx.json`). |
| `hitboxes` | Shape per slice of the active phase. `shape`: `box` (`size: [x, y, z]`), `sphere` (`radius`) or `capsule` (`radius`, `height`). Several overlapping entries make an arc so fast swings can't miss between frames. **One swing hits each target once** across all its entries, unless the move sets `"rehit_ms"` (multi-hit moves). |
| `swing` | Sound and sword-trail switch when the active phase starts. |
| `anim.clip` | Clip name in the model (section 5). |
| `anim.keys` | Pose keys: at `at_ms` of the move, snap the clip to `clip_s` seconds. This is how 2 to 3 key poses line up with data timing. No keys: the clip is stretched to fit the move's total length. |
| `anim.fallback` | Procedural tween used when the clip is missing (section 5). |
| **Enemy-only** `telegraph_ms` | When the wind-up flash and `combat_enemy_telegraph` play. |
| **Enemy-only** `impact_ms` | The moment the hit lands, for parry and perfect-dodge judging. Default: the first hitbox's `from_ms`. |
| **Enemy-only** `parryable`, `dodge_flare` | Can be parried / can trigger a Lamp Flare (both default `true`). |
| **Enemy-only** `armor` | `{"from_ms", "to_ms"}`: super armor (no flinch until poise breaks). |

**Launcher input** (buildability 3.3, all three built): the feel knob `launcher_input` decides when a `heavy` press becomes the `launch` token. `hold_heavy`: heavy starts on press, and if the button is still down at `hit_feel.json` `launcher_hold_ms` during heavy's startup, it becomes the launcher. `back_heavy`: heavy with the stick pulled away from the facing direction. `string_end`: heavy pressed inside `light_2`'s chain window. Only the token changes; the graph above is the same in all three.

**Red's sandbox moves:** `light_1`, `light_2`, `light_3`, `heavy`, `launcher`, `air_1`, `air_2`, `air_3` (knocks down), `parry` (a short brace; its recovery is the whiff penalty). **Grunt:** `swipe` (slow, parryable). **Brute:** `slam` (big telegraph, super armor, parryable, can be dashed through).

---

## 4. Interfaces

**House rules.** Logic lives in pure `RefCounted` classes that take time as numbers (testable headless, thousands of runs). Nodes only feed them input and show results. Every node puts its per-frame logic in `tick(delta: float)`, and `_physics_process` only calls it, so tests can step it by hand. **Nobody touches `Engine.time_scale`.** All new code is statically typed.

### 4.1 Time: CombatClock, CombatTime, hit-stop and the flare

- `CombatClock extends BattleClock`: one per fighter. `step(real_delta_usec: int, scale: float)`, `now_usec() -> int` (local combat time), `scale() -> float`, `local_at_real(real_usec: int) -> int` (converts a press timestamp from `_input` into this clock's time).
- `CombatTime` (pure, owned by the director): `step(real_delta_s: float)`, `scale_for(actor_id: StringName) -> float`, `add_hit_stop(ids: Array[StringName], ms: float)`, `start_flare(duration_s: float, enemy_scale: float, slowed_ids: Array[StringName])`, `is_flaring() -> bool`, `flare_left_s() -> float`.
- **The rules:**
  1. A fighter in hit-stop has scale **0**. Hit-stop counts down in **real** time, so it is never stretched by a flare. Several hits at once freeze for the longest one, not the sum.
  2. During a Lamp Flare, the enemies caught in the glare run at `flare_enemy_speed` (for example 0.25); **Red runs at full speed.**
  3. The flare's own timer runs on **Red's** clock, so it pauses while Red is in hit-stop (hits during a flare don't eat into it).
  4. Each fighter's movement, MoveRunner, AnimationPlayer `speed_scale`, trails and sparks use that fighter's scale. Velocity is scaled around `move_and_slide()` (multiply, slide, divide back). Camera shake, the HUD, menus and sound use real time.
  5. The input buffer runs on Red's clock, so a press made during hit-stop isn't lost.
- *Why this matters for the game: hits crunch, slow-mo feels like Red is faster than everyone, and the parry timing stays fair through both.*

### 4.2 The hit chain: ActionPlayer ↔ MoveRunner ↔ Hitbox/Hurtbox ↔ HitResolver ↔ ActionEnemy/EnemyBrain

**`CombatActor extends CharacterBody3D`** (base for Red and enemies):
```gdscript
@export var actor_id: StringName        # &"red", &"grunt_1"
@export var team: StringName            # &"player" / &"enemy"
var hp: int
var hp_max: int
var clock: CombatClock
func get_hurtbox() -> Hurtbox
func get_hitbox() -> Hitbox
func is_airborne() -> bool
func is_invulnerable() -> bool          # dash i-frames
func anchor(point: StringName) -> Vector3   # &"head", &"center", &"feet", &"lamp" in world space
func snapshot() -> Dictionary           # {id, team, airborne, invulnerable, poise, poise_max, armored, juggle_count, launchable, hp}
func apply_hit(result: Dictionary) -> void      # victim side
func on_hit_landed(result: Dictionary) -> void  # attacker side (air hang, follow jump)
func on_parried(result: Dictionary) -> void     # attacker got parried: recoil or stagger
signal died(actor_id: StringName)
```

**`MoveRunner`** (pure): `static func create(set: MoveSet, owner_set: StringName) -> MoveRunner`, `start(move_id: StringName, now_usec: int) -> bool`, `offer(token: StringName, now_usec: int) -> StringName` (starts a linked move if the chain window allows; returns its id or `&""`), `step(now_usec: int) -> Array[Dictionary]`, `can_cancel(kind: StringName, now_usec: int) -> bool` (`&"dash"`, `&"jump"`, `&"parry"`), `interrupt()`, `current_move() -> StringName`, `phase() -> StringName` (`startup`/`active`/`recovery`/`idle`), `elapsed_ms() -> float`, `is_busy() -> bool`. `step` returns events in order: `{type: "phase", phase}`, `{type: "hitbox_on", index, box}`, `{type: "hitbox_off", index}`, `{type: "pose", clip, clip_s}`, `{type: "swing"}`, `{type: "telegraph"}`, `{type: "done"}`.

**`InputBuffer`** (pure): `push(token: StringName, t_usec: int)`, `take(now_usec: int, accept: Callable) -> StringName` (oldest token still inside `input_buffer_ms` that `accept` allows), `clear()`.

**`ActionPlayer extends CombatActor`** (Red). States: locomotion, air, dash, air_dash, attack, parry, hurt, knockdown, getup. Wraps `PlayerMotion` (camera-relative stick, coyote time, jump buffer, release-cut all kept). One air-dash per jump (knob), dash cooldown and i-frames from `player_action.json` and the knobs; enemy-body collision off while dashing. For bots and tests: `read_engine_input: bool`, `press(action: StringName)`, `release(action: StringName)`, `set_move_input(stick: Vector2)`. Signals: `jumped(air: bool)`, `landed`, `dashed(air: bool)`, `move_started(move_id: StringName)`. **Red can't lose in the sandbox:** at 0 HP she drops, Noise resets, and she gets up at full HP after 2 s.

**`Hitbox`** (Node3D on the attacker): `activate(box: Dictionary, hit: Dictionary, swing_id: int)`, `deactivate(index: int)`, `clear()`. Each tick it queries its active shapes with `PhysicsDirectSpaceState3D.intersect_shape` (collide with areas only, on its mask) and calls `director.report_contact(self, hurtbox)` once per target per swing. Querying, not `area_entered`, so contact is found in the same frame and tests are repeatable.
**`Hurtbox`** (Area3D on every fighter): `owner_actor() -> CombatActor`. It stays on during i-frames (so a dodge can be detected); the resolver ignores the hit instead.
Both draw their shapes when the `show_hitboxes` knob is on.

**`HitResolver`** (pure): `static func resolve(attack: Dictionary, attacker: Dictionary, target: Dictionary, ctx: Dictionary) -> Dictionary`. `attack` = the move's `hit` + `{move_id, launcher, swing_id}`; `attacker`/`target` = `snapshot()`; `ctx` = `{parry: Dictionary, lights_on: Dictionary, feel: FeelKnobs, hit_feel: Dictionary}`. Checks in this order, first match wins:

| # | Case | `outcome` |
|---|---|---|
| 1 | Same team, or target dead | `ignored` |
| 2 | Target invulnerable (i-frames) | `evaded` (no damage; may count as a perfect dodge, 4.4) |
| 3 | Target is Red and the parry rating is `totally_rad` / `rad` / `nice` | `perfect_parry` (0 damage, attacker staggered) / `parried` (0 damage, attacker recoils) / `guarded` (damage × (1 − `block_reduction.nice`)) |
| 4 | Target armored and poise survives the hit | `armored` (damage, poise down, no hitstun or launch) |
| 5 | Otherwise | `hit` (or `stagger` if this hit broke poise) |

Result: `{outcome, damage: int, hitstun_ms, knockback: Vector3 (world), launch_mps, knockdown: bool, hit_stop_ms, poise_after, style_points, juggle_count}`. Launch and air lift go through **`JuggleRules`** (pure): `lift_for(launch_mps: float, juggle_count: int) -> float` (each extra air hit lifts a little less), `gravity_scale_after_hit(ms_since_hit: float, juggle_float: float) -> float` (low gravity right after each air hit), `can_juggle(juggle_count: int) -> bool`. Numbers in `hit_feel.json`.

**`CombatDirector`** (Node, group `&"combat_director"`, `process_physics_priority = -100` so it steps time before the fighters). It holds `time: CombatTime`, `style: StyleMeter`, `lights_on: LightsOn`, `tokens: AttackTokens`, `feel: FeelKnobs`, and the registry of fighters. API: `register(actor: CombatActor)`, `unregister(actor)`, `actors(team: StringName = &"") -> Array[CombatActor]`, `delta_for(actor: CombatActor, real_delta: float) -> float`, `report_contact(hitbox: Hitbox, hurtbox: Hurtbox)`, `report_parry_press(real_usec: int)`, `report_dash(real_usec: int)`, `telegraph(attacker: CombatActor, move_id: StringName, impact_local_usec: int)`. On contact it resolves, applies (`apply_hit`, `on_hit_landed` or `on_parried`), adds hit-stop to both sides, feeds the Noise meter and emits the signals in 4.6.

**`ActionEnemy extends CombatActor`** owns an `EnemyBrain`, a `MoveRunner`, a Hitbox and a Hurtbox; reactions (hit recoil, launch tumble, knockdown, get-up, death) are procedural (TA's `procedural_moves.gd`). When a move reaches `telegraph_ms` it calls `director.telegraph(...)`. Dead enemies respawn at their spawn after `sandbox.json` `respawn_s`.
**`EnemyBrain`** (pure): `static func create(data: Dictionary, rng_seed: int) -> EnemyBrain`, `step(now_ms: float, view: Dictionary) -> Dictionary`, `notify(event: StringName)`. `view` = `{dist_to_player, player_airborne, player_attacking, has_token, state, poise_frac, attacks_enabled}`; it returns an intent `{move_dir: Vector3, face_player: bool, want_token: bool, start_move: StringName}`. States: idle → notice → approach → circle → (token) → attack → recover → react → dead. Events: `hit`, `launched`, `landed`, `parried`, `staggered`, `token_granted`, `move_finished`.
**`AttackTokens`** (pure): `request(enemy_id: StringName) -> bool`, `release(enemy_id: StringName)`, `holders() -> Array[StringName]`; `max_attackers` from `enemies.json` (start: 2).
`enemies.json` per enemy: `name`, `model`, `fallback_model`, `height_m`, `hp`, `poise`, `weight`, `launchable`, `move_set`, `brain` numbers, `attacks` (`[{move, weight, when: {max_dist_m, player_airborne}}]`), `look` (edge-light id). **Grunt** = Ross's Cyberwolf Sentinel once rigged (fallback: the Signals grunt blockout): light, launchable, dies in about 5 hits. **Brute** = blockout: poise and super armor, a big slam to parry or dash through.

### 4.3 ParryJudge (wraps ClutchJudge, on the combat clock)

`ParryJudge` (pure): `static func judge(presses_usec: Array[int], impact_usec: int, window: Dictionary, mult: float, offset_ms: int, listen_before_ms: int) -> Dictionary` → `{rating, delta_ms, pressed}`.
- Red presses `parry` → if she can (`cancels.parry` or free), ActionPlayer starts the `parry` move and calls `director.report_parry_press(real_usec)`.
- When an enemy hitbox touches Red, the director converts her recent press stamps into **the attacker's clock** (`local_at_real`) and judges against **that contact moment**.
- Only the **first** press in the `listen_before_ms` before contact counts (mashing fails, as in Clutch). **One-sided:** a press after contact is a miss, because the hit has already landed. Otherwise `ClutchJudge.rating_for_delta(delta, window, mult)`.
- Windows in `timing_windows.json` → new `"parry": {"nice_ms", "rad_ms", "totally_rad_ms", "listen_before_ms"}`; `mult` = `ClutchJudge.window_multiplier(...)` with Config's Wide Windows, times the `parry_window_scale` knob; `offset_ms` = Config's timing offset.
- Ratings: `nice` = guard (less damage), `rad` = parry, `totally_rad` = perfect parry. Which ratings start a Lamp Flare is a knob (`flare_on_parry`, default `rad_and_up`).
- Because it judges on the attacker's clock, a hit-stop or a flare between the wind-up and the hit never shifts the window.

### 4.4 Perfect dodge → Lamp Flare

`PerfectDodge` (pure): `static func is_perfect(dash_usec: int, impact_usec: int, window_ms: float, in_threat: bool) -> bool` (`0 <= impact − dash <= window_ms` and `in_threat`).
- On `telegraph`, the director keeps a **threat** for that attack: attacker, move, the impact time on the attacker's clock, and the attack's hitboxes at impact grown by `hit_feel.json` `threat_margin_m`.
- On `report_dash(real_usec)`, a dash is **perfect** if (a) an open threat's impact falls inside `perfect_dodge_window_ms` after the dash started (on the attacker's clock) **and** Red's hurtbox was inside the threat zone when she dashed, or (b) an enemy hit comes back `evaded` within that window of the dash start.
- A perfect dodge or a qualifying parry calls `time.start_flare(flare_duration_s, flare_enemy_speed, ids)` for every enemy within `flare_glare_radius_m`. One flare per attack; `flare_cooldown_s` between flares; the attack's `dodge_flare` / `parryable` flags can opt out.
- Working name **Lamp Flare** (the pitch called it Porch Light). Code ids use `lamp_flare`; the on-screen name lives in `data/text/sandbox.json`, so renaming it is a text edit.

### 4.5 Noise and Lights On (sandbox stub)

`StyleMeter` (pure): `static func from_data(style: Dictionary) -> StyleMeter`, `add_hit(move_id: StringName, points: float, now_ms: float)` (the same move repeated inside `variety_window_ms` scores less each time), `add_bonus(kind: StringName, now_ms: float)` (`parry`, `perfect_parry`, `perfect_dodge`, `launch`, `air_hit`), `took_damage(now_ms: float)` (drops a rank), `step(now_ms: float)` (slow drain when idle), `points() -> float`, `fill() -> float` (0..1), `rank() -> Dictionary` `{index, id, name}`, `reset()`. Runs on Red's clock. Ranks and names in `style.json` (start: the approved stencil ranks Nice!, Rad!, TOTALLY RAD!; names are Level 1).

`LightsOn` (pure): `can_start(meter: StyleMeter) -> bool`, `start(now_ms: float)`, `step(now_ms: float)`, `is_active() -> bool`, `remaining_s() -> float`, `buffs() -> Dictionary` `{damage_mult: 1.5, super_armor: true}`. Sandbox stub: when the meter is full it starts (knob `lights_on_trigger`: `auto` by default, or `chord` = press light and heavy together), lasts `style.json` `lights_on.duration_s`, drains the meter, and gives the simple buffs above. The look (lamp blaze, brighter edge light, glowing jacket strips) is the TA's, driven by `lights_on_changed`.

### 4.6 Signals for the HUD, FX and audio (all on `CombatDirector` unless marked)

| Signal | Payload | Used by |
|---|---|---|
| `actor_registered(actor_id, team)` / `actor_died(actor_id)` | StringName | HUD, FX (`combat_enemy_death`) |
| `hp_changed(actor_id, hp, hp_max)` | StringName, int, int | HUD (Red's bar; small bars over damaged enemies) |
| `move_started(info)` | `{actor, move_id, swing_sfx, trail}` | FX (`combat_swing_*`, trail on) |
| `hit_landed(info)` | `{attacker, target, move_id, outcome, damage, launch, knockdown, airborne, hit_stop_ms, shake, spark, sfx, position: Vector3}` | FX (spark, flash, shake, `combat_hit_*`), HUD (damage number) |
| `launched(info)` | `{attacker, target, launch_mps}` | FX (`combat_hit_launch`) |
| `telegraphed(info)` | `{attacker, move_id, impact_in_ms, parryable}` | FX (wind-up flash, `combat_enemy_telegraph`) |
| `parry_judged(info)` | `{attacker, rating: "miss"/"nice"/"rad"/"totally_rad", outcome, delta_ms, position}` | HUD (rating pop-up over Red), FX (`combat_parry`, `combat_parry_perfect`) |
| `perfect_dodge(info)` | `{attacker, move_id, position}` | HUD ("Lamp Flare!" pop-up) |
| `flare_started(info)` / `flare_ended()` | `{source: "dodge"/"parry", duration_s, enemy_scale}` | FX (lamp burst, screen tint, `combat_lamp_flare`) |
| `stagger(info)` | `{target, by: "parry"/"poise"}` | FX, HUD |
| `noise_changed(points, fill, rank_id, rank_name)` | float, float, StringName, String | HUD meter |
| `noise_rank_changed(rank_id, rank_name, went_up)` | StringName, String, bool | HUD stencil pop-up (plays `combat_noise_rank_up`) |
| `lights_on_changed(active, duration_s)` | bool, float | HUD, FX (`combat_lights_on_activate`) |
| `ActionPlayer.jumped(air)` / `landed` / `dashed(air)` | | FX (`combat_jump`, `combat_land`, `combat_dash`, `combat_air_dash`, dash streak) |
| `LockOn.target_changed(target)` | `CombatActor` or null | HUD reticle (plays `combat_lock_on`), camera |
| `OrbitCamera.mode_changed(mode)` | `OrbitCamera.Mode` | HUD (controls card) |

**Binding.** `CombatSandbox` exposes `get_director()`, `get_player()`, `get_lock_on()`, `get_camera()` and `screen_pos_of(actor_id: StringName, point: StringName = &"head") -> Vector2` (640×360 stage pixels; `Vector2.ZERO` if unknown or behind the camera). `SandboxHud.bind(sandbox)` and `CombatFx.bind(sandbox)`. **Who plays which sound:** the HUD plays `combat_noise_rank_up` and `combat_lock_on`; `CombatFx` plays every other `combat_*` id, mapping event to id in `fx.json` (a move's own `sfx` / `swing.sfx` wins). Nobody plays the same id twice. Until the director lands, the HUD and FX test against a stub that emits these signals.

### 4.7 GearVisuals (sword swap on `weapon_socket`)

```gdscript
class_name GearVisuals extends Node
@export var model_root: NodePath           # the instanced character model
func equip_sword(sword_id: StringName) -> bool
func current_sword() -> StringName
func get_sword() -> Node3D
func blade_points() -> Dictionary          # {base: Node3D, tip: Node3D} for the trail
signal sword_changed(sword_id: StringName)
```
- Finds the `Skeleton3D`, makes one `BoneAttachment3D` with `bone_name = "weapon_socket"`, frees the old sword and instances the new one under it, applying the entry's `offset`, `rot_deg` and `scale`.
- `data/combat/swords.json`: `{"default": "katana_cyan", "rack": [...], "swords": {"katana_cyan": {"name", "model": "res://art/final/weapons/sword_katana_cyan.glb", "offset", "rot_deg", "scale", "trail": {"color", "base_m", "tip_m"}}}}`, for all six of Ross's swords (`katana_cyan`, `heavy_duty`, `hook_cyan`, `glass_core`, `machete`, `twin_orange`). Sword files already follow the convention: **origin at the middle of the grip, blade along +Y.**
- If `weapon_socket` is missing: use `hand_r`, then the model root at a fixed offset, with a `push_warning`. The rig test fails on the final Red if the socket is missing.
- The sword rack: one stand per sword in `sandbox.json`; walking onto a stand equips that sword (`interact` layer). Swords change the look only; the moves are the same for all.
- Later, in the slice, this reads `equipment.json` `visual` blocks instead of `swords.json`.

### 4.8 OrbitCamera, LockOn, action diorama, shake

```gdscript
class_name OrbitCamera extends Node3D     # pivot → SpringArm3D (collides with world) → Camera3D
enum Mode { ORBIT, DIORAMA }
func follow(target: Node3D) -> void
func set_lock_on(lock: LockOn) -> void
func toggle_mode() -> Mode
func get_mode() -> Mode
func get_camera() -> Camera3D
func recenter() -> void
func shake(profile: StringName, mult: float = 1.0) -> void   # profiles in fx.json; × shake_scale knob
signal mode_changed(mode: Mode)
```
- **ORBIT:** right stick or mouse turns it; it eases back behind Red when she runs and the stick is idle; with a lock target it frames Red and the target.
- **DIORAMA** (`camera_toggle`): Ross's option C, the high camera that follows Red and never rotates (yaw, pitch, height and lag from `camera.json` `diorama`). Movement stays camera-relative, and lock-on still drives the reticle and attack magnetism.
- **LockOn** (node): `toggle()`, `get_target() -> CombatActor`, `soft_target(stick_dir: Vector3) -> CombatActor` (for magnetism without a hard lock), `switch(flick: Vector2)`; signal `target_changed`. **LockOnMath** (pure): `score(candidate: Dictionary, cam_forward: Vector3, player_pos: Vector3) -> float`, `best(candidates: Array[Dictionary], ...) -> int`, `switch_index(candidates, current: int, flick: Vector2) -> int`. Candidates are the director's live enemies with line of sight.
- **Shake** (`CameraShake`, TA, used inside OrbitCamera): smooth (not the PSX stepped kind), decays in real time, never moves the pivot (so aim and lock framing don't drift). `camera.json` holds distance, height, pitch limits, mouse and stick sensitivity, invert, recenter delay, lock framing.

### 4.9 Feel knobs: `data/combat/feel.json`, the panel, saving to `user://`

**Format.** A flat list; each owner adds knobs only to their own group.
```json
{"version": 1, "knobs": [
  {"id": "dash_distance_m", "group": "movement", "label": "Dash distance", "type": "float", "value": 4.0, "min": 2.0, "max": 8.0, "step": 0.25, "unit": "m"},
  {"id": "launcher_input", "group": "combat", "label": "Launcher button", "type": "choice", "value": "hold_heavy", "options": ["hold_heavy", "back_heavy", "string_end"]},
  {"id": "enemies_attack", "group": "sandbox", "label": "Enemies attack", "type": "bool", "value": true}
]}
```
**`FeelKnobs`** (pure, Battle Programmer): `static func load_defaults() -> FeelKnobs`, `overlay(values: Dictionary)` (unknown ids ignored, numbers clamped), `get_f(id: String) -> float`, `get_b(id) -> bool`, `get_s(id) -> String`, `set_value(id, value)`, `knobs() -> Array[Dictionary]`, `to_save_dict() -> Dictionary`, `save_user() -> String` (returns the absolute path), `load_user() -> bool`; signal `changed(id: String, value: Variant)`. Systems read knobs **when they use them** (not cached at start), so a change works straight away.

**Starting knobs** (numbers are Level 1 guesses; Ross tunes them):

| Group (owner) | Knobs |
|---|---|
| movement (Gameplay) | `run_speed_mps` 6.0, `jump_height_m` 1.6, `gravity_scale` 1.0, `dash_distance_m` 4.0, `dash_time_ms` 180, `dash_iframes_ms` 150, `air_dash_count` 1 |
| camera (Gameplay) | `cam_distance_m` 4.5, `cam_sensitivity` 1.0 |
| combat (Battle) | `hit_stop_scale` 1.0, `juggle_float` 1.0, `launch_height_scale` 1.0, `input_buffer_ms` 150, `parry_window_scale` 1.0 |
| flare (Battle) | `flare_duration_s` 2.5, `flare_enemy_speed` 0.25, `perfect_dodge_window_ms` 120, `flare_glare_radius_m` 12 |
| fx (TA) | `shake_scale` 1.0, `trails_on` true |
| sandbox (Gameplay) | `enemies_attack` true, `show_hitboxes` false |

**Ross picks by playing** (choice knobs; the default is the studio's guess and is not a decision): `launcher_input` (`hold_heavy`), `lights_on_trigger` (`auto` / `chord`), `flare_on_parry` (`rad_and_up` / `perfect_only` / `off`). The camera style is the `camera_toggle` button.

**Panel** (UI, `feel_panel`): opening it pauses the arena and frees the mouse. Sliders, toggles and drop-downs are built from the knob list (no knob is hard-coded in the panel), grouped, each with a "default" marker. Buttons: **Save**, **Reset to studio defaults**, **Revert to last save**, **Open folder**.
**Saving:** `Save` writes `user://feel/feel_current.json` plus a dated copy `user://feel/feel_YYYY-MM-DD_HHMM.json`, as `{version, saved_at, build, values: {id: value}}`, and shows the full path (on Windows that's `%APPDATA%\LightsOnSandbox\feel\`). At boot the sandbox loads the defaults, then `feel_current.json` if it's there. Ross sends a file back, and the studio copies the values into `data/combat/feel.json` and logs them as Ross's numbers in docs/decisions.md.

---

## 5. Character contract (Red)

- **Source:** `game/art/final/characters/red/red_ross_v1.glb` (Ross's Meshy model: unrigged, 1,614 tris, A-pose, about 0.95 m, origin at the middle). **Never edited.** The TA's rigged copy goes beside it as `red_ross_v1_rigged.glb`, and its path lives in `player_action.json` `model`, so no code names the file.
- **Rigged file:** faces **+Z** in Godot, +Y up, 1 unit = 1 m, **origin at the feet**, scale applied. One `Skeleton3D`, one `AnimationPlayer`, smooth skinning with at most 4 influences per vertex. Hero budget about 3,000 tris (cap 5,000); body texture up to 512 px.
- **Bones (exact names, lowercase).** Required: `root`, `hips`, `spine`, `chest`, `neck`, `head`, `upper_arm_l`, `forearm_l`, `hand_l`, `upper_arm_r`, `forearm_r`, `hand_r`, `thigh_l`, `shin_l`, `foot_l`, `thigh_r`, `shin_r`, `foot_r`, **`weapon_socket`** (child of `hand_r`; origin at the centre of the closed fist, local **+Y along the blade**, matching the sword files). Optional, used if present: `ear_l`, `ear_l_2`, `ear_r`, `ear_r_2` (the lop ears), `tail`, `prop_socket` (child of `hand_l`), `head_gear` (child of `head`, for caps and helmets later), `back` (child of `chest`, for a sheathed sword later), `lamp_socket` (where the Lamp Flare and Lights On glow come from; missing → `chest` + an offset from `player_action.json`). The old 17-bone names are a subset, so old clips and tools still fit.
- **What code reads by name:** `weapon_socket` (GearVisuals), `head` (reticle, pop-ups, head-aim at the lock target), `lamp_socket`/`chest` (flare FX), `upper_arm_r` (procedural swings). Nothing else.
- **Clips (exact names).** `idle` (loop), `run` (loop), `jump_up`, `fall` (loop), `land`, `dash`, `light_1`, `light_2`, `light_3`, `heavy`, `launcher`, `air_1`, `air_2`, `air_3`, `parry`, `hurt`, `knockdown`. Optional, used if present: `walk` (loop, small stick), `air_dash` (else `dash`), `parry_success`, `getup`. Loop flags are set by the importer. Attacks can be 2 to 3 key poses (wind-up, strike, follow-through); the TA writes their times into `moves.json` `anim.keys`. Smooth or stepped "on twos" in-betweens is a look call for Ross once he sees it.
- **A missing clip never breaks the game.** Gameplay never waits on a clip. A missing clip plays its procedural fallback (`procedural_moves.gd`, TA), with a single `push_warning` per clip at load and a "missing clips" line in the debug overlay:

| Clip | Fallback tween |
|---|---|
| `idle` / `run` | rest pose + breathing bob / forward lean + run bob |
| `jump_up` / `fall` / `land` | stretch / lean + tuck / squash |
| `dash` | 20° lean + stretch along the motion |
| `light_1..3` | `swing_r`, `swing_l`, `thrust` (model twist + `upper_arm_r` swing) |
| `heavy` / `launcher` | `overhead` (pitch forward) / `uppercut` (rise + pitch back) |
| `air_1..3` | `air_swing`, `air_swing_l`, `spin` (one full yaw turn) |
| `parry` | `brace` (lean back, small squash) |
| `hurt` / `knockdown` | `recoil` (push back + hurt flash) / `fall_flat` (pitch to the floor, get up after) |

- **Enemies** follow the same facing, scale, origin and bone names (a subset is fine). They need `idle` and a movement clip; attacks can be one clip with pose keys; hit, launch, tumble, down, get-up and death are procedural. Missing `head` bone: the top of the model's bounds is used for the reticle.
- The style guide's model contract carries a draft of this section (marked draft until the sandbox confirms it).

---

## 6. PS2 render settings for the sandbox (D4, step one)

The sandbox scene asks for look profile **`grim_ps2`** (`sandbox.json` `look_profile`); the old game's rooms keep theirs. The TA adds `grim_ps2` to `data/world/look_profiles.json`: the `grim` profile's grade, fog and edge light, plus the new blocks `shadows`, `glow`, `texture_filter`, `retro_wobble`, `dither`, `color_depth` (buildability 8.2).

| Setting | Sandbox value |
|---|---|
| Renderer | Compatibility (unchanged). |
| Internal picture | **640×360** in the PsxScreen SubViewport (add `"640x360"` to `psx_look.json`; the sandbox sets it on load, and the old game's default stays 384×216). Smooth (linear) scale-up; sharp UI on top as today. |
| Vertex jitter / affine warp | **Off** (`psx_jitter_strength` and `psx_affine_strength` at 0 through `PsxLook`). The F-key toggles stay for comparison. |
| 15-bit colour / Bayer dither | Off; a faint dither only if dark gradients band. |
| Lighting | Per-pixel lit shader (`ps2_lit`) with the banded edge light kept; **one shadow-casting key light** (DirectionalLight3D, soft-low filter, about 20 m shadow distance); 2 or 3 lamps without shadows. All fighters cast shadows; FX and trails don't. |
| Glow / bloom | WorldEnvironment glow on, values in the profile's `glow` block. Lamps, neon, sword emissives, trails, sparks, the flare and Lights On sit above the glow threshold. |
| Grim grade | Kept as is (desaturation, crush, tint, grain, vignette), run before final effects. |
| Edge light | Kept, per character from the profile's `characters` block (new entries for `red_ross`, `grunt`, `brute`; "not too bright", F56). Lights On raises Red's rim and the glow of her jacket strips. |
| Textures | Models under `art/final/`: linear filtering + mipmaps (importer change scoped to `art/final/`, so placeholders and the old game look the same). |
| Fog | Smooth distance fog in the grim haze colours. |
| Budget | A steady 60 fps on an ordinary laptop with Red + 6 enemies on screen. |

---

## 7. Test expectations

Run: `godot --headless --path game -s res://tests/run_all.gd` (`-- --only=combat` for a subset). **The whole suite is green before anything merges to main**, and every existing test still passes (the old game is unchanged). Builders ship each class with its unit test; QA owns the integration, bots and smoke tests and reviews the rest.

| Test | Must prove |
|---|---|
| `unit/test_combat_clock.gd`, `test_combat_time.gd` | Hit-stop freezes both sides and counts down in real time; longest wins, not the sum; a flare slows enemies, not Red; the flare timer pauses in Red's hit-stop; `local_at_real` is right on slowed and frozen clocks; `Engine.time_scale` is never changed. |
| `unit/test_move_runner.gd`, `test_input_buffer.gd` | Phase boundaries; hitbox on/off events at the right ms; an early press fires exactly at `chain[0]`; no dash before `cancels.dash`; buffered presses expire after `input_buffer_ms` and don't expire during hit-stop; `light, light, heavy` follows the links; each `launcher_input` mode makes `launch` only when its rule is met. |
| `unit/test_juggle_rules.gd` | Lift shrinks with each air hit; low gravity right after a hit; the juggle cap. |
| `unit/test_hit_resolver.gd` | Every row of the outcome table, in order; one swing hits each target once. |
| `unit/test_parry_judge.gd` | Inclusive boundaries; a late press is a miss; only the first press counts; Wide Windows and the timing offset apply; judging on a slowed or frozen attacker clock doesn't move the window. |
| `unit/test_perfect_dodge.gd` | Inside/outside the window; outside the threat zone = no flare; the cooldown; one flare per attack. |
| `unit/test_style_meter.gd` | Variety decay; a rank drop on damage; rank thresholds; Lights On starts on full (both trigger modes), lasts its duration, and the buffs apply. |
| `unit/test_attack_tokens.gd`, `test_lock_on_math.gd`, `test_feel_knobs.gd` | Token cap and release; best target and flick switching; knob load, overlay, clamp, unknown ids, save round trip. |
| `unit/test_combat_data.gd` (QA) | `moves.json`: every link and entry exists, windows and hitboxes sit inside the move, every required Red move is there; `enemies.json` and `swords.json` paths exist; every `fx.json` sound id exists in `sfx.json`; knob ids are unique and defaults are inside min/max. |
| `integration/test_action_player.gd` | Dash distance matches the knob within 5%; i-frames last `dash_iframes_ms`; one air-dash per jump; coyote time and the jump buffer still work. |
| `integration/test_hit_flow.gd` (QA) | One hit per swing; hit-stop freezes attacker and target; knockback direction; launch height. |
| `integration/test_gear_visuals.gd` | A swap changes the mesh under `weapon_socket`; the fallback path warns. |
| `integration/test_red_ross_rig.gd` | The rigged Red: required bones, `weapon_socket` under `hand_r`, faces +Z, origin at the feet, tri cap; it **lists** missing clips (no failure, since fallbacks cover them). |
| `integration/test_orbit_camera.gd` | The mode toggle; lock-on framing; shake decays to zero in real time and leaves the pivot alone. |
| `integration/test_sandbox_hud.gd`, `test_feel_panel.gd` | The HUD reacts to every signal in 4.6 from a stub; the panel lists every knob and Save writes a readable file. |
| `integration/test_sandbox_smoke.gd` (QA) | The sandbox loads at 640×360 with `grim_ps2`, Red + Grunt + Brute registered, the HUD bound, and 300 frames with no errors. |
| `sim/test_combat_bots.gd` (QA) | Scripted inputs: "launcher + 4 air hits keeps a Grunt airborne"; "a parried Brute slam staggers"; "dashing through a Brute slam takes no damage"; "a perfect dodge on a Grunt swipe starts a flare and slows the Grunt"; "a varied combo fills Noise and starts Lights On". |
| `visual/capture_sandbox.gd` (TA) | Screenshots into `docs/screenshots/sandbox_*.png` for Ross (real renderer, not headless). |

---

## Changes
> Additions agreed while building. Newest at the bottom. Add yours here instead of editing the contract above silently.

### 2026-10-08, Battle Programmer: CS-5 API READY
**CS-5 API READY**: `CombatClock`, `CombatTime`, `MoveSet`, `MoveRunner`, `InputBuffer`, `FeelKnobs` (plus helpers `CombatData`, `LauncherInput`), in `game/scripts/combat/model/`. Data: `data/combat/moves.json` (red, grunt, brute), `data/combat/feel.json` (all starting knobs from 4.9, every group), `data/combat/hit_feel.json`. Unit tests: `tests/unit/test_combat_clock.gd`, `test_combat_time.gd`, `test_move_runner.gd` (also covers MoveSet and LauncherInput), `test_input_buffer.gd`, `test_feel_knobs.gd`. What the contract left open, and how I read it:
- **Who steps clocks.** The director steps every registered fighter's `CombatClock` each tick using `CombatTime.step_scale_for(id, delta)`; actors read `actor.clock` and get their per-frame local delta from `director.delta_for(self, real_delta)`. Without a director (a bare test) use the real delta.
- **`CombatClock`** also has `now_ms()`, `real_now_usec()`, `anchor_real(real_usec)` (pin the real axis to `Time.get_ticks_usec()`; the director does this at register) and keeps about 600 steps of history so `local_at_real` is right through freezes and slow-mo.
- **`CombatTime.delta_for(id, real_delta)`** is how much of a step a fighter really lives through (the part of the step after its hit-stop ended counts), so frozen time equals the hit-stop asked for. It also has `signal flare_started` / `flare_ended`, `player_id` (whose clock the flare follows, default `&"red"`), `hit_stop_left_ms(id)`, `is_frozen(id)`, `flare_left_s()`.
- **`MoveSet`** holds the whole file, not one set: `MoveSet.load_default()`, `entry(owner_set, state, token)`, `link(owner_set, move_id, token)`, `get_move(owner_set, id)` (normalised: adds `id`, `total_ms`, `impact_ms`, `telegraph_ms`, `parryable`, `dodge_flare`, `rehit_ms`, `chain_from_ms`/`chain_to_ms`). `MoveRunner.create(set, owner_set)` is as in 4.2.
- **`MoveRunner` extras.** `offer(token, now_usec, press_usec := -1)`: a press made earlier than `chain[0]` starts the next move at exactly `chain[0]` (the move begins in the past; the next `step()` catches up), so chaining does not depend on frame rate. `can_chain(token, now_usec)` is the `accept` for `InputBuffer.take`. `interrupt()` and starting over a running move return/queue `hitbox_off` events (then `{type:"interrupted"}`) so no hitbox is left on. Also `attack_data()` (the `hit` block + move_id, launcher, swing_id, parryable, dodge_flare, rehit_ms for HitResolver/Hitbox), `swing_id()`, `forward_between(prev_ms, cur_ms)` (lunge metres), `up_mps()`, `is_hanging()`, `armor_active()`, `chain_window_open(now)`, `data()`. Pose keys may carry their own `clip` (the Grunt uses a wind-up clip then a swing clip).
- **`InputBuffer.create(feel)`** reads `input_buffer_ms` at take time; `buffer_ms` is used when no knobs are attached.
- **Launcher input.** `LauncherInput.token_for_heavy_press(mode, ctx)` and `LauncherInput.should_upgrade_heavy(...)` hold the three rules as pure functions; `hit_feel.json` has `launcher_hold_ms` (170) and `string_end_move` (`light_2`). In `moves.json` every ground attack that links to a launcher has a `launch` link, so only the token differs by mode.
- **`feel.json`** carries every group's starting knobs from 4.9 so nobody is blocked. Each owner edits only their own group from here. Extra knobs I added: `enemy_damage_scale`, `flare_cooldown_s`, `lights_on_trigger`, `flare_on_parry`, `launcher_input` (the last three are the "Ross picks by playing" choices).
- `FeelKnobs.save_user(dir := "user://feel")` writes `feel_current.json` plus the dated copy and returns the absolute path of the first; `load_user(dir)` reads it back. Both take a `dir` only so tests can use another folder.

### 2026-10-08, Battle Programmer: CS-6 CombatDirector signal list READY (HUD and FX can bind now)
`game/scripts/combat/combat_director.gd` (`CombatDirector`, group `combat_director`) declares **every signal in 4.6 exactly as written**, with the payload keys listed there; the file's header comments repeat them. Also landed: `CombatActor`, `Hitbox`, `Hurtbox`, `HitResolver`, `JuggleRules`, `CombatLayers`, `data/combat/hit_feel.json`. Details the contract left open:
- `hit_landed` fires for outcomes `hit`, `stagger`, `armored`, `guarded`. For `parried` / `perfect_parry` it does NOT fire; `parry_judged` does (its `outcome` field says which). `evaded` and `ignored` fire nothing except `perfect_dodge` when the dodge is perfect. A `guarded` hit emits both `parry_judged` (rating `nice`) and `hit_landed`.
- `parry_judged.rating` is `miss` / `nice` / `rad` / `totally_rad`; a plain missed press fires nothing, the hit simply lands.
- Extra director methods the fighters call: `notify_move_started(actor, move_id, swing: Dictionary)` (emits `move_started`; call it on the runner's `swing` event), `request_lights_on()` (chord mode), `stamp_usec()` ("real now" on the fighters' clock axis), `player()`, `living_enemies()`, `get_actor(id)`, `tick(delta)`. `sync_to_wall_clock` (default true) makes the clocks follow `Time.get_ticks_usec()`; a headless test that steps by hand sets it false and stamps presses with `stamp_usec()`.
- `CombatActor` additions: `move_set_id` (which set in moves.json it plays), `current_swing_id()`, `is_armored()`, `local_delta(real_delta)`, `slide_scaled(local_scale)` (multiply velocity, slide, divide back), `tick_poise(local_dt)`, `ms_since_air_hit()` (feed it to `JuggleRules.gravity_scale_after_hit`), `revive()`, and a `dead` flag. `snapshot()` also carries `position`, `forward`, `weight`. Forward is **+Z** of the actor's basis. Hooks to override: `_on_hit_reaction(result)`, `_on_death(result)`, `_on_hit_landed(result)`, `_on_parried(result)`. `apply_hit(result)` is also called for `parried` / `perfect_parry` / `guarded` outcomes on Red (damage 0 for the first two): **check `result.outcome` before playing a hurt reaction**.
- `HitResolver.resolve` result carries extra keys: `attacker`, `target`, `move_id`, `swing_id`, `parry_rating`, `launched`, `staggered_target`, `staggered_attacker`, `armored`, `air_hit`, `lethal`, and (added by the director) `position`.
- `Hitbox` is a child of the actor; `ActionPlayer` should feed it from MoveRunner events: `hitbox_on` -> `hitbox.activate(event.box, runner.attack_data(), runner.swing_id())` (the event's `box` already carries its `index`), `hitbox_off` -> `hitbox.deactivate(event.index)`, `interrupted`/death -> `hitbox.clear()`, and call `hitbox.tick(local_delta)` every tick after stepping the runner.

### 2026-10-08, Gameplay Programmer (also taking the Integrator role): CS-1, CS-2, CS-3, CS-4 built
What the contract left open, and how I read it. Nothing here changes a number in sections 1 to 7.
- **project.godot** (the only edits): the eleven new input actions (`light`, `heavy`, `dash`, `parry`, `lock_on`, `camera_toggle`, `feel_panel`, `camera_left/right/up/down`) with the keys, mouse buttons and pad buttons of section 2; a new `[layer_names]` section naming 3D physics layers 10 to 16; and two `[application]` feature overrides, `config/name.sandbox="Lights On Sandbox"` and `config/custom_user_dir_name.sandbox="LightsOnSandbox"`. No existing line changed.
- **main.gd:** new `Main.State.SANDBOX`, `Main.wants_sandbox()` (feature tag `sandbox` or `-- --sandbox`), `start_sandbox()`, `get_sandbox()`, and exports `sandbox_boot_enabled` / `sandbox_scene_path`. In the SANDBOX state Esc is left to the HUD's pause menu (the "Esc goes back to the title" shortcut is off there). Anything else about the old boot is as it was. Run locally: `godot --path game -- --sandbox`.
- **Export presets:** `Sandbox Windows` (`../builds/sandbox/LightsOnSandbox.exe`) and `Sandbox Mac` (`../builds/sandbox/LightsOnSandbox-mac.zip`), both with `custom_features="sandbox"`. (The contract called the second "Sandbox macOS"; the lead's task says "Sandbox Mac".)
- **Input.** Nodes in the PSX SubViewport get no input events, so `CombatSandbox` puts a small relay in the sharp UI layer. It hands each press, with its real `Time.get_ticks_usec()`, to `ActionPlayer.handle_input_event()` and mouse movement to `OrbitCamera.add_mouse_motion()` while the mouse is captured. `LockOn` and `OrbitCamera` poll `lock_on`, `camera_toggle` and the camera stick themselves. Without a PSX screen (tests) the player polls too.
- **OrbitCamera** uses its own ray against the world layer instead of a `SpringArm3D` node (same behaviour, and it can be stepped by hand in tests). Shake is a small built-in smooth shake driven by `camera.json` `shake_fallback`; it reads `fx.json` `shake.<id>.{amplitude_m, duration_s, frequency_hz}` first when the TA writes it, and stays inside the Camera3D so the pivot never moves. Auto-recenter has a 35 degree dead zone (`recenter_dead_deg`), so a held diagonal never makes the camera chase her in a circle.
- **LockOn** returns `Node3D` (a `CombatActor` in the game). Extra API: `best_target()`, `soft_target(stick_dir, facing, range_m, cone_deg)`, `magnet_target(...)` (the hard lock wins), `candidate_provider` (tests), signal `recenter_requested`. With no target in range, `toggle()` asks the camera to recenter.
- **Extra files, all pure helpers or their tests:** `scripts/combat/dash_run.gd` (`DashRun`: the dash curve and its i-frames; distance is exact at any frame rate), `scripts/combat/action_motion.gd` (`ActionMotion`: acceleration, jump numbers, dash direction), `tests/unit/test_dash_run.gd`, `tests/integration/test_sandbox_boot.gd`.
- **ActionPlayer** extends `CombatActor`. Her clock is stepped by the director; with no director in the tree she steps her own (bare tests). She takes her knobs from the director's `feel`. Presses are buffered as tokens (`jump`, `dash`, `parry`, `light`, `heavy`, `launch`) in an `InputBuffer` on her clock, so `input_buffer_ms` is the jump buffer too. She calls `director.notify_move_started()` on the `swing` event and `report_parry_press()` / `report_dash()` with her clock's real axis. Signals added: `swing_started(move_id, swing)`, `state_changed(state)`. Dash is cancelled into an attack after `dash.attack_cancel_ms` and into a jump after `dash.jump_cancel_ms` (player_action.json). The follow-jump after a launcher hit uses `hit_feel.json` `follow_jump.height_m`.
- **Her model is 0.95 m tall** (Ross's Meshy bunny) and so is the Cyberwolf; the arena is built to that scale (5 m pillars, 4.5 m camera). Every distance is data or a knob, so rescaling is a number edit.
- **CombatSandbox** adds: `get_feel()` (the one shared `FeelKnobs`: the director's, else its own, loaded with `load_user()` at boot), `reset_arena()`, `get_enemies()`, `get_racks()`, `get_player_spawn()`, `set_mouse_captured()`. `sandbox.json` `attachments` lists the optional parts it attaches when their files exist (director, fx, HUD); anything missing is listed in `missing` and skipped. The HUD goes on the UiStage root (`layer: "stage"`); it owns the pause menu, controls card and feel panel (CS-15 says so), so those are not attached separately. If the HUD's feel panel finds no director knobs, the sandbox binds its own.
- **Texture filter** for the city tiles comes from data: the active look profile's `texture_filter.mode` (`linear`, `nearest`, `nearest_mipmap`) if present, else `sandbox.json` `arena.texture_filter`. Not hard-coded.
- **Needs from others:** Battle: `scenes/actors/enemies/grunt.tscn` and `brute.tscn` (the sandbox spawns them from `sandbox.json` `enemy_spawns`, sets `actor_id` and `spawn_position` before adding them, and frees and respawns them on reset); `enemies.json` (CombatData logs an error until it exists). TA: `scripts/combat/fx/combat_fx.gd` with `bind(sandbox)`, and `grim_ps2` in `look_profiles.json` (until then the sandbox falls back to `grim` and notes it in `missing`). UI: `scenes/ui/sandbox/sandbox_hud.tscn`.

### 2026-10-08, Battle Programmer: CS-7, CS-8, CS-9 landed
**CS-7 (parry, perfect dodge, Lamp Flare).** `ParryJudge`, `PerfectDodge`, the flare knobs (`flare_duration_s`, `flare_enemy_speed`, `perfect_dodge_window_ms`, `flare_glare_radius_m`, plus `flare_cooldown_s` and `flare_on_parry` that I added) and the `parry` entry in `data/battle/timing_windows.json` (top level, next to `windows`: `{nice_ms 220, rad_ms 130, totally_rad_ms 70, listen_before_ms 400}`; these are starting guesses, `parry_window_scale` scales them live, and the old game's tests and windows are untouched).
- **Parry is one-sided.** Only a press BEFORE contact counts; the three widths are "how early". A press at exactly contact counts. `ParryJudge.judge` returns `{rating, delta_ms, pressed, press_usec}`; the director judges on the attacker's clock and then clears the stored presses, so one press covers one hit.
- **Perfect dodge, two ways, both from the contract:** (a) `report_dash` while an enemy has a telegraphed attack whose impact is 0..`perfect_dodge_window_ms` ahead and Red is inside the attack's hitboxes grown by `threat_margin_m`; (b) an `evaded` hit within the window after the dash. Each attack flares at most once (key = attacker + move + swing id) and `flare_cooldown_s` (real time, counted after a flare ends) holds the next one back. `perfect_dodge` is still emitted if the cooldown blocks the flare itself.
- **Flare scope:** every living enemy within `flare_glare_radius_m` of Red when it starts; enemies spawned or arriving later run at normal speed until the next flare.
- **Mechanic left open, made a knob:** which parries flare is `flare_on_parry` (`rad_and_up` default / `perfect_only` / `off`).

**CS-8 (enemies).** `ActionEnemy`, `EnemyBrain`, `AttackTokens`, `scenes/actors/enemies/grunt.tscn` and `brute.tscn`, `data/combat/enemies.json` and the `grunt.swipe` / `brute.slam` moves in `moves.json`. Details:
- **Models by data path:** `model` (the TA's `art/final/enemies/cyberwolf_sentinel_rigged.glb` for the Grunt, loaded today; the Brute loads the TA's `art/placeholder/enemies/sandbox_brute` blockout), then `fallback_model` (scaled to `height_m`, feet on the floor), then a coloured capsule/box blockout with a bright face so facing can be read. `ActionEnemy.visual_kind()` says which one loaded. Clips are looked up by name (`idle`, `walk`, `run`, `hurt`, `stagger`, `launched`, `knockdown`, `getup`, and the pose keys of the move's `anim`); a missing clip is skipped, the procedural lean/tumble and colour pulse always run.
- **Wind-ups are readable:** Grunt swipe 560 ms and Brute slam 900 ms from telegraph to impact (the telegraph fires at 0 ms of the move). The enemy tracks Red only for `track_ms` (enemies.json `attacks[]`, 380 and 600 ms) and then its aim locks, so the swing can be read, parried or dashed through. The model flashes the enemy's `telegraph_color` during the wind-up.
- **`EnemyBrain` `move_dir` is in the player's frame** (z toward Red, x sideways around her), not world space; the body converts it. The intent also carries the brain `state`. `view.state` is `&"free"` / `&"busy"` / `&"dead"` (what the body is doing); the brain waits through `busy` plus a short pause (`react_ms`) before acting again.
- **Brute:** `base_armor` (soaks hits as `armored` until poise breaks), `launchable: false`, a slam with `armor` over the whole move and `dodge_flare`/`parryable` true. A poise break (or a perfect parry) staggers it and drops the armor until the stagger ends.
- **Knobs/flags read by enemies:** `enemies_attack` (off: they notice, approach and circle but never ask for a token), `juggle_float`, `launch_height_scale`, `enemy_damage_scale` (the damage Red takes; added by me).
- **Tokens:** `max_attackers` in enemies.json (2). Waiting enemies queue, so the one waiting longest attacks next.

**CS-9 (Noise and Lights On).** `StyleMeter`, `LightsOn`, `data/combat/style.json`. Ranks: `Nice!` at 20, `Rad!` at 50, `TOTALLY RAD!` at 80 of 100 points (rank 0 `quiet` has no name; names and numbers are Level 1). Full meter = Lights On (`auto`: starts by itself; `chord`: call `director.request_lights_on()` when light and heavy are pressed together; knob `lights_on_trigger`). It lasts `lights_on.duration_s` (12 s), drains the meter smoothly, gives `damage_mult` 1.5 and super armor (the resolver turns Red's hits into `armored` while it runs) and ignores extra points while active. Taking a hit in Lights On does not drop a rank. `took_damage` drops to the start of the rank below.

### 2026-10-08, UI Programmer: CS-15 and CS-16 built (HUD, pause menu, controls card, feel panel)
**One scene is the whole sandbox UI.** `scenes/ui/sandbox/sandbox_hud.tscn` (`SandboxHud`) owns the HUD, the pause menu (with the controls card and the Config remap page) and the feel-knobs panel. Instance it on the UiStage root and bind it:
```
var stage: UiStage = UiStage.get_or_create(get_tree())
var hud: SandboxHud = load("res://scenes/ui/sandbox/sandbox_hud.tscn").instantiate()
stage.get_stage_root().add_child(hud)
hud.bind(self)     # the CombatSandbox
```
`bind` uses `get_director()` (every 4.6 signal), `get_lock_on()` (`target_changed`), `get_camera()` (`mode_changed`, `get_mode()`), `get_player()` (`actor_id`), `get_feel()` (else `director.feel`) and `screen_pos_of(id, point)`; anything missing is skipped. Esc / pad Start opens the pause menu and F12 / Back the panel, both on their own (they read `start` and `feel_panel`), so the sandbox adds no input handling for them. **Reset arena** calls `reset_arena()` (else `reset()`); **Quit** calls `get_tree().quit()` (`auto_quit` off for tests). The standalone panel scene is `scenes/ui/sandbox/feel_panel.tscn` (`FeelPanel.bind(knobs)`) if anyone wants it without the HUD.
- **Pausing** is `get_tree().paused` through `SandboxPauseGate` (reference-counted; frees the mouse and restores the old mouse mode; keeps the UiStage running). The menus are `PROCESS_MODE_ALWAYS`; the sandbox's own relay and the player pause as usual. Nothing touches `Engine.time_scale`.
- **Picture size.** `screen_pos_of` answers in 3D-picture pixels (640x360 in the sandbox); the HUD scales to the 384x216 UI stage using the PsxScreen's real resolution (fallback `world_size` in `data/ui/sandbox_ui.json`).
- **The look is one Theme resource**, `game/art/placeholder/ui/sandbox_theme.tres` (built by `scripts/tools/make_sandbox_theme.gd`; path in `sandbox_ui.json` `theme_path`): fonts, sizes, every color, bar and frame constant. Ross's Vagrant Story direction: stacked navy-to-blue bars, teal-green headers, yellow-green selected text, orange triangle cursor, cyan arrows, a pixel font in white with a solid black 1-pixel down-right shadow (Ross's FFTA direction: default Pixelify Sans, numerals in Jersey 15, labels in Silkscreen, all SIL OFL; candidates in docs/screenshots/ui_font_options_ffta.png). All drawing goes through `SandboxStyle`.
- **Feel knob hints.** The panel shows a one-line hint per knob: the knob's own `"hint"` in `feel.json` wins, else `data/text/sandbox.json` `feel.knob_hints.<id>` (written for every knob in the file today). `tests/unit/test_feel_format.gd` fails if a knob has no hint, label or group title, so anyone adding a knob adds its hint (either place) in the same change. Choice knobs also take `feel.choice_labels.<id>.<option>` and `feel.choice_hints.<id>.<option>`.
- **Config rows** (append only): `config_screen.json` got `light`, `heavy`, `dash`, `parry`, `lock_on`, `camera_toggle`, `feel_panel` rows and the swap set `["jump","light","heavy","dash","parry","lock_on","camera_toggle"]` (`feel_panel` is deliberately not in it; F12 itself is reserved so only its pad button can change). The row labels and hints had to go in `data/text/config.json` (the Config screen reads them there; the contract listed only `config_screen.json`), and two existing tests were updated for the longer list (`test_input_remap.gd`, `test_config_screen.gd`).
- **Tests:** `unit/test_feel_format.gd`, `unit/test_sandbox_ui_data.gd`, `integration/test_feel_panel.gd`, `integration/test_sandbox_hud.gd` (real `CombatDirector`, `CombatActor` and `FeelKnobs` through `tests/fixtures/ui/fake_combat_sandbox.gd`). Screenshots: `tests/visual/capture_sandbox_ui.gd` writes `docs/screenshots/sandbox_hud.png`, `sandbox_feel_panel.png`, `sandbox_pause.png`, `sandbox_controls.png`; `capture_ui_font_options.gd` writes `ui_font_options.png`.

### 2026-10-08, Technical Artist: CS-14 combat FX landed, and the PS2 look follows Ross's "modern conveniences" note
- **Files:** `scripts/combat/fx/combat_fx.gd` (`CombatFx`, `bind(sandbox)`; `bind_parts(director, player, camera)` for tests), `hit_spark.gd`, `telegraph_cue.gd`, `flare_fx.gd`, `dash_streak.gd`, `sword_trail.gd`; `scripts/camera/camera_shake.gd`; `data/combat/fx.json`; shaders `fx_flash.gdshader`, `sword_trail.gdshader`.
- **Sound rule as built:** CombatFx plays every `combat_*` id except `combat_noise_rank_up` and `combat_lock_on` (the HUD's). A move's own `hit.sfx` and `swing.sfx` win over the defaults in `fx.json` `sounds`. The same id is played at most once per frame (a launcher says `combat_hit_launch` through both `hit_landed` and `launched`).
- **Shake:** CombatFx calls `OrbitCamera.shake(profile, mult)`; the camera reads `fx.json` `shake.<id>` first (its own `shake_fallback` is now only a backup). `CameraShake` is the same smooth idea as a reusable class (with a slight roll) if the camera ever wants to adopt it. Every `hit.shake` id used in moves.json has a profile (`light`, `medium`, `heavy`, ...).
- **Wind-up cue (`telegraphed`):** a flash plus a ring that closes on the impact moment, on the attacker's own combat clock. The colour comes from `fx.json` `telegraph.kinds`, picked by `info.telegraph_kind` (new kinds such as `dodge_only` or `unblockable` need only a data entry), else `parryable` / `unparryable` from `info.parryable`.
- **Look pass:** CombatFx adds a `Ps2Look` to the sandbox if there is none and gives each fighter's model the PS2 shader and edge light once (`fx.json` `look`). The sandbox's own Ps2Look node (added later in `_build_arena`) is found and reused.
- **Profile `grim_ps2` (Ross: light atmosphere, long draw distance, modern shadows):** fog is a light haze from 30 m to 150 m (`PsxRoomLook` scales its 12/24 m by `near_mul`/`far_mul`); `fog_disabled` on the PS2 shaders so the profile is the only fog on those materials (`sandbox.json` `lighting.fog.density` still fogs the old PSX-shader placeholders); the far plane is 500 m (`camera` block); shadows are four blended cascades out to 60 m with a medium soft filter. The 640x360 picture stays a data setting.
- **Room for sword pickups with random affixes (Ross, 2026-10-08; Later, not in the sandbox):** "leave it open to pick up swords in the game world that have random affixes or upgrades ala binding of issac rougelike". Keep sword data base-plus-instance friendly: `swords.json` entries are *bases* (model, trail, base stats); anything that equips a sword (GearVisuals, the rack, ActionPlayer, HitResolver) should accept a sword *instance* `{base, affixes: []}` rather than assuming a fixed id, and moves should read damage/feel modifiers through one lookup so affixes can change them later. No affix system is built now.

### 2026-10-08, Animator: the free Quaternius clips are on Red, the Cyberwolf Sentinel and the Brute (offline retarget onto our bone names)
**Approach (a), offline bake onto OUR bone names.** The game and its code read `head`, `upper_arm_r`, `weapon_socket`, `lamp_socket`; a Godot BoneMap import would rename every bone to Hips/Head/UpperArm... and break them (b), and a runtime retarget (c) costs time every frame and cannot carry the chibi fixes. So the clips are baked once, offline, into **new GLB files beside the rigs**; the old rigs and Ross's originals are untouched. Nothing in the game's code changed. The two `*_bone_map.tres` files stay as the humanoid mapping record (the import does not use them).
- **New files:** `art/final/characters/red/red_ross_v1_rigged_ual.glb`, `art/final/enemies/cyberwolf_sentinel_rigged_ual.glb`, `art/placeholder/enemies/sandbox_brute/enm_sandbox_brute_ual.glb` (same mesh, skeleton, textures and face surface as the rigs they come from, plus the clips). The license (CC0, Quaternius) is in `art/placeholder/animations/quaternius_ual/` and in an `ANIMATION_CREDITS_*.txt` beside each output. **Data paths switched:** `player_action.json` `models[0]`, `enemies.json` grunt and brute `model`. The old `*_rigged.glb` files stay (other tests use them).
- **Adding a clip later is one line.** Edit the clip table in `data/animation/retarget_red.json` / `_wolf.json` / `_brute.json` (`source` "UAL2:Sword_Block", `from_s`/`to_s`, `loop`, `contact_src_s` = the strike's time in the source clip, `speed`, `reverse`, `hold_end_s`, `pingpong`, `yaw` for a side-step), then `python3 game/scripts/tools/retarget_ual.py red|wolf|brute [--report]` (Python + numpy only, no Blender; `glb_kit.py` is its glTF reader/writer), then `python3 game/scripts/tools/sync_move_keys.py`, then `godot --headless --path game --import`. A new rig is a copy of a settings file (bone map, sole points, leg ratio). Mocap from Ross's video apps goes in the same way if it arrives on a Quaternius-like skeleton (otherwise add a source file and bone names to `sources` / `bones`).
- **How it retargets:** each mapped bone follows the world-rotation change of its source bone; the arms are first raised from her A-pose to the library's T-pose (so "arm down" stays "arm down"); the right hand is aligned so `weapon_socket` +Y points where the library's grip points (the blade leaves the fist on the index-finger side); the hips follow the source pelvis scaled by the leg ratio (Red 0.41, wolf 0.51, Brute 0.425); the **ground lock** puts the lowest sole point (or, lying down, the lowest body point) at the scaled source height, so planted feet stay planted. Ears, tail, sockets, `head_gear`, `back`, `lamp_socket` follow their parents rigidly (no secondary motion). Per-bone `fix_deg` corrections exist; I tried arm abduction 8 and 16 degrees against clipping and it did not help, so none are set.
- **Timing stays in data.** No clip is retimed. `red_clip_keys.json`, `wolf_clip_keys.json` and the new `brute_clip_keys.json` now carry `contact_s` / `contact_frame` per clip (30 fps; the kept stand-ins say `stand-in`). `sync_move_keys.py` rewrote only `anim.keys` in `moves.json` for `red.light_1..3`, `heavy`, `launcher`, `parry` and `grunt.swipe`, `swipe_flank`: the key at the hit time (`startup_ms`, or `impact_ms` for enemies) snaps the clip to its contact frame, the key at 0 starts the clip at `contact - startup`, and the wind-up and follow-through play at the clip's own speed in between. The Grunt's wind-up clip hands over to `attack_swing` 100 ms before the impact. `brute.slam` has no keys (the game stretches the clip) and its clip is sliced so the contact sits at 900 of 1900 ms.
- **Playback look.** 30 fps (the rigs' own `.import` resample to 15 fps, which loses a 3-frame sword swing, so the new files import at 30). The project's scene importer made every track stepped, and Godot drops keys that sit on a straight line, which wrecks a stepped 30 fps clip. The new files use `scripts/tools/ual_post_import.gd` (the same material conversion as `psx_post_import.gd`): loops come from the settings' `loop`, in-betweens from `data/animation/import_look.json` (`linear` now; `nearest` gives the stepped look; Ross's call), and the kept hand-posed stand-ins stay stepped.
- **Red's clips (UAL source):** idle Sword_Idle; walk Walk_Loop; run Sprint_Loop; jump_up Jump_Start 0.1-0.6 s; fall Jump_Loop; land Jump_Land 0-0.7; dash Sword_Dash 0.38-1.1 (the lunge hold; the first part spins); light_1 Sword_Regular_A + _A_Rec; light_2 Sword_Regular_B + _B_Rec; light_3 Sword_Regular_C 0.45-1.5 (the overhead raise and lunge); heavy Sword_Heavy_Combo 2.1-3.7 (raise and slam); launcher Sword_Attack 0.6-1.5 (low crouch, rising cut); parry Sword_Block; hurt Hit_Chest; knockdown Hit_Knockback; getup LayToIdle. **Kept stand-ins (nothing free fits):** `air_1`, `air_2`, `air_3`, `parry_success`. `air_dash` is absent on purpose (the game plays `dash`).
- **Wolf and Brute clips follow the Combat Designer's catalog** (`enemies.json` `behaviour.clips`): idle, notice, walk, strafe (= walk), run, retreat (Jog backwards), stalk (Crouch_Fwd), flee (Sprint), dodge_side (Sword_Dash 0-0.6), dodge_back (Roll backwards), block_start (Sword_Block 0-0.3), block_hold (Idle_Shield_Loop), block_impact (Shield_OneShot), block_break (Idle_Shield_Break), hurt (Hit_Chest), hurt_head (Hit_Head), stagger (Hit_Chest at 0.6x, end pose held 2 s), launched (the knock-back's mid-air pose held 2.8 s), knockdown (the fall to the floor), getup, death (Death01), `attack_windup` + `attack_swing` (Zombie_Scratch: the arm cocked high behind the head for 0.53 s, then the claw strike; contact at 0.1 s into the swing). Extras: `strafe_l` / `strafe_r` (the walk with the hips and legs turned 90 degrees; the library has no side-steps). The Brute adds `slam` (Heavy_Combo slam) and `enrage` (Zombie_Scratch) and uses the Zombie clips. Its blockout skeleton has no neck, chest, hands or feet, so only the main bones follow.
- **Known problems (honest list):** (1) **Run speed:** Red's run clip is a 2.5 m/s stride; the game runs her at 6 m/s (`run_speed_scale_ref_mps` 6.0 plays it at 1x), so her feet slide at about 2.4x. The wolf's Jog (2.98 m/s) matches its 2.8 m/s chase; its walk (0.47 m/s) against the 1.5 m/s circling and the Sprint (3.6 m/s) against the 4.6 m/s flee slide. The clips stay, the numbers are a gameplay call. (2) **Chibi arms:** in the crossing strikes (light_2 up to 9 cm, heavy 6 cm, light_3 5 cm, in 8 to 26 of about 30 frames) a hand passes through the jacket, and in one frame of light_2 the forearm is 2 cm inside the head; it reads as a brush past the body, not a clip through the face. (`retarget_ual.py --report` prints these numbers.) (3) The right wrist is cocked unlike the library's because her sword socket sits along the forearm; the blade direction is exact, the mitt looks bent. (4) Ears and tail do not move on their own. (5) `Hit_Chest` is a small flinch, hard to see on the wolf. (6) The side-steps twist the waist; read them as placeholder. (7) The Brute's slam is a stretched, slow version of the heavy swing.
- **Tests:** `tests/integration/test_ual_retarget.gd` (settings and sources exist, license note beside the outputs, bones and parents equal the rigs', every promised clip present with the right loop flag and playback look, key data and contact frames, the contact is where the blade is fastest, move keys land the contact on the hit, loops close, sockets stay in the fist, the blade points where the library grip points, feet stay on the floor, the enemy catalog's clips all exist, side-steps are different clips); `test_red_ross_rig.gd` and `test_enemy_rigs.gd` now check the `_ual` files (clips named, loops, contact frames, stand-ins listed). Screenshots: `docs/screenshots/sandbox_red_ual_poses.png`, `sandbox_wolf_ual_poses.png` (`tests/visual/capture_ual_poses.gd`).
- **Update (Ross: text must be crisp, no big yellow 3D words).** The HUD now moves itself (deferred, on `_ready`) from the 384x216 UiStage onto its own `CanvasLayer` (layer 90) on the root window, so text is drawn at the real window resolution. The layer undoes the project's canvas stretch, and the HUD scales by a whole number, `round(window height / 400)` (3 at 1080p, 2 at 720p; `window_px_per_scale` in `sandbox_ui.json`). The 384x216 layouts stay as written: the four HUD corners are anchored to the corners of the larger UI, and the menus are centered. `hud.bind(self)` is unchanged; instance it wherever you like (the UiStage root still works), and `hud.relocate_to_window = false` keeps it where it is (tests). `screen_pos_of` is still read in 3D-picture pixels; the HUD finds where the picture sits on the window.
- **Events are small text now.** Lamp Flare, parry results, staggers and rank-ups are white call-outs (black 1-px shadow) sliding in under the Noise meter, two lines at most. Damage numbers are small white `SandboxFloater` digits over the fighter. The battle HUD's `BattlePopup` is no longer used by the sandbox and is untouched. Sounds, flashes and the flare timer are unchanged. The Lights On element is left in place, unpolished, until Ross decides.
- **Look defaults.** Slant is on (`slant_pct` 22). Numerals are VT323 (Jersey 15 filled its counters with the shadow so a 6 read like a plus; see docs/screenshots/ui_digits_strip.png).


### 2026-10-08, Combat Programmer: enemy AI built (docs/pivot/enemy_ai_design.md)
Dodge, block and guard break, repositioning, telegraph floors, low health (flee, flank, enrage), hit reactions by type and allies noticing are in. All numbers are in `enemies.json` (`behaviour`, `token_rules`, `telegraph_rules`, `player_read`), `moves.json` and the `enemies` knob group; nothing about Red's buttons changed. New pure classes in `scripts/combat/model/`: `EnemyRules` (angles, arcs, wind-up floors, Red's move class), `EnemyDefence` (the defence roll), `GuardMeter`. Rewritten: `EnemyBrain`, `AttackTokens`, `ActionEnemy`. Extended: `HitResolver`, `CombatDirector`. Tests: `unit/test_enemy_rules.gd`, `test_enemy_defence.gd`, `test_guard_meter.gd`, `test_enemy_brain_behaviour.gd`, `test_enemy_ai_data.gd`, `test_action_enemy_ai.gd`, additions to `test_hit_resolver.gd` and `test_attack_tokens.gd`, and `sim/test_enemy_ai_bots.gd` (scripted Red in the real sandbox).
- **`enemies.json` did not have the three rule blocks** the design says were done (`token_rules`, `telegraph_rules`), so I added them with the design's numbers, plus `player_read` (Red's move classes, the combo gap, what counts as a dash toward an enemy). Small keys added to each enemy's `behaviour`: `rear_move` (Grunt `swipe_flank`, the attack used from Red's rear arc), `guard.hold_ms`, `guard.drop_after_threat_ms`, `guard.spark`/`guard.sfx`, `alert.step_up_ms`, `low_health.flank.track_ms`.
- **HitResolver.** New outcomes `blocked` and `guard_broken` (row 3b, after Red's parry and before armor): front arc only, chip damage, no hit-stun, `guard_drain` (poise damage) taken off the meter, hit-stop and push scaled, and `feedback {spark, sfx}`. A Launcher, a hit with `break_poise` or more, or an empty meter makes it `guard_broken` (hit-stun = the stagger length). I used `blocked` (the design's name) rather than `guarded`, because `guarded` already means Red's "nice" parry and the HUD and FX read it that way. Snapshot keys the resolver reads from an enemy: `guard {up, arc_deg, meter, break_poise, break_by_launcher, chip_scale, min_chip, knockback_scale, hit_stop_scale, break_ms, spark, sfx}` and `flee_knockdown` (a hit on a running enemy always knocks it down).
- **Signals.** `hit_landed` now also fires for `blocked` and `guard_broken` (no `parry_judged`: that stays Red's). The payload `spark`/`sfx`/`shake` are filled in for them (`guard` + `combat_hit_light` for a block; the enemy's `block_break` move fields for a break). `stagger.by` can be `"guard"`. `telegraphed` carries `telegraph_kind` (the move's `telegraph_kind`, else `parryable`/`unparryable`); `CombatDirector.telegraph(attacker, move_id, impact_usec, kind := &"")`. A guard break adds `style.add_bonus(&"guard_break")`, worth nothing until Noise's owner adds `bonuses.guard_break` to style.json.
- **CombatDirector.** Connects to Red's `move_started` signal to learn about each swing: `begin_player_swing(red, move_id)` (also callable by tests with a stand-in) works out which enemies stand in the swing's threat zone (hitboxes + `threat_margin_m`, also where the lunge ends) and the move class; `player_swing_info(enemy)`, `combo_len()`, `player_dash_toward(enemy)`, `alert_allies(source, &"hit"|&"died")`. It steps the tokens' clock and applies the `enemy_max_attackers` knob each tick.
- **AttackTokens.** `request(id, {flank})`, `begin_attack(id, impact_in_ms, rear)`, `end_attack(id)`, `step(delta)`, `apply_rules()`. Impacts are kept `min_impact_gap_ms` + 17 ms (one physics frame, because a hit is found at the first frame of its hitbox) apart; one enemy at a time attacks from the rear arc; a flanker queues as if it had waited 1.5 s longer. A defending or fleeing enemy holds no token (the body gives it back).
- **EnemyBrain view/intent/events.** See the header of `enemy_brain.gd`: the view gains `hp_frac`, `my_angle_deg`, `in_rear_arc`, `crowd_count`, `allies_near`, `allies`, `flankers_other`, `player_swing_id/threat/active`, `player_move_class`, `player_combo_len`, `player_dashing_toward`, `flare`, `cornered` and the `knobs`; the intent gains `defend`, `guard`, `gait`, `speed_mps`, `speed_mult`, `flank`, `chain_recover_ms`, `face_move`; new events `attack_denied`, `defence_finished`, `blocked`, `guard_broken`, `armored_hit`, `ally_alert`, `ally_died`, `step_up`.
- **Deviations from the design, and why.**
  1. A get-up is untouchable for `getup_invuln_ms` (250 / 300 ms), not for the whole 600 ms as before. The design says 250 ms.
  2. The design never says how a flanker's swing reaches Red from 3.6 m (a swipe reaches about 1.5 m). The flanker waits at 3.6 m, holds 600 ms, asks for a token (with the bonus), and once it has one it closes in from behind to striking range and then swings `swipe_flank` (710 ms). The 3.5 s limit counts until it has the token.
  3. The breaking hit of a guard break does chip damage only (the reward is the free Heavy that follows). The Brute has no armor while his guard is up or lowering, so a hit from behind or in his recovery flinches him; that is the "opening" of the design's section 9.
  4. Fatigue fades at `fatigue_per_defence / fatigue_decay_s` per second (one defence is gone in 4 s / 5 s). The design's "two defences leave about half the chance" does not match 0.4 + 0.4: two in a row leave about a third.
  5. The combo escape uses its own 50% (not the chance table), but still respects the dodge cooldown and the "Enemy dodging" slider, and adds fatigue.
  6. Wind-up slider: the move's wind-up runs at 1 / scale of normal speed until the impact, floored so it is never shorter than 500 ms (650 ms from behind). The floor also lifts a too-short wind-up in the data, so a data mistake cannot make an unfair attack; `test_enemy_ai_data.gd` still fails the build if the data is under the floor.
- **For the Technical Artist.** `fx.json` has no spark for the new outcomes: `spark_by_outcome` only knows armored/guarded/parried, and `spark_aliases` has no `guard`, so a blocked hit shows the `slash` spark until `"blocked": "guard"` and `"guard_broken": "heavy"` are added to `spark_by_outcome` (and `blocked` to the soft-shake test in `combat_fx.gd`). The enraged Brute's hot edge light is a steady overlay in `ActionEnemy` today (`enrage.color`); `ActionEnemy.is_enraged()` is there for the edge-light hook. The dodge tell (cyan blink, 40 ms) and the wind-up flash (8 Hz, brighter toward impact) are also overlay pulses on the enemy's own material.
- **For the Animator.** Every clip name in `behaviour.clips` exists on both models today except `slam` on the wolf and `hurt_head` on the Brute (neither is used there). `retreat` is played backwards because its `behaviour.clips` entry says `reverse: true` (the clip itself is the forward Jog). The Brute's `slam` has no pose keys, so the clip is stretched over the move, as `brute_clip_keys.json` says. Nothing in the Animator's files was touched. Known: locomotion clips play at their own speed (`speed_scale` from `behaviour.clips` only), so flee (4.6 m/s) and retreat (3.4 m/s) may slide; tune `speed_scale` there.

### 2026-10-08, Gameplay Programmer: foot-slide fix (locomotion clips play at ground speed / stride)
Red's feet slid because the free clips stride slower than the game moves. Fixed in data and one helper; no animation was made and no GLB was touched.
- **Data:** each looping locomotion clip in `red_clip_keys.json`, `wolf_clip_keys.json` and `brute_clip_keys.json` now has `stride_mps`, the ground speed it plays at without sliding (measured by `retarget_ual.py` from the foot travel while planted; the tool now writes it, so a re-run keeps it). Red: walk 0.38, run 2.52. Wolf: walk/strafe/strafe_l/strafe_r 0.47, run/retreat 2.98, stalk 0.55, flee 3.56. Brute: walk/run/retreat/strafe* 0.64.
- **Helper (`scripts/combat/locomotion_speed.gd`, class `LocomotionSpeed`):** `playback_scale(ground_speed, stride_mps, limits = Vector2(0.6, 2.0))` is ground speed / stride, clamped; it returns 1.0 for a clip with no stride, so attack, dodge and hurt clips can pass through safely. Also `load_strides(path)`, `stride_for(strides, clip)`, `raw_scale()` and `overspeed_blend()` (0 to 1 past the top of the range, for a caller with a faster clip to blend toward).
- **For the Combat Programmer (`action_enemy.gd`, not touched by me):** load the strides once (`LocomotionSpeed.load_strides("res://data/combat/wolf_clip_keys.json")`, brute likewise). Where a locomotion clip is played or its speed updated, multiply by `LocomotionSpeed.playback_scale(Vector2(velocity.x, velocity.z).length(), LocomotionSpeed.stride_for(strides, clip))` instead of (or on top of) the hand-tuned `speed_scale` for that clip. The wolf's flee (4.6 m/s over a 3.56 stride) wants 1.29x, so it needs no extra clip; the circling walk (1.5 over 0.47) is 3.2x and would clamp to 2.0 (slides a little; raise the circle speed's clip to `stalk` or slow the circling if it shows). Brute walk (2.0 over 0.64) also clamps to 2.0. Test: `tests/unit/test_locomotion_speed.gd`.
- **ActionPlayer:** `player_action.json` `anim` has `clip_keys`, `playback_scale_min` 0.6, `playback_scale_max` 2.0 and `walk_below_mps` 1.1 (a slow stick plays `walk`, otherwise `run`). `run_speed_scale_ref_mps` is gone. Red's run clip already is the Sprint loop, so there is no faster clip to blend to: at full speed (6 m/s over 2.52 = 2.4x) the clamp holds 2.0x and the feet still slide about 20 percent. Raising `playback_scale_max` would remove it at the cost of a twitchier legs cycle; that is a feel call.

### 2026-10-09, Combat Programmer: CS-22 the one-button combo (docs/pivot/kh_combo_design.md) built
The single `light` button now drives every attack; the second button (`heavy`: K / right mouse / Y) only shows "Hack: coming later". Data: `data/combat/combo.json` (unchanged rules), `lunge` and `sweep` in `moves.json`. Not committed.
- **New pure classes** in `scripts/combat/model/`: `ComboSelector` (situation in, `{move, prefix, rule, restart}` out; first rule of `rules` whose `from` and `when` fit; unknown `when` keys fail the rule), `ComboString` (string position and the 500 ms forget timer, on Red's combat clock), `ComboSituation` (reads the world: target = hard lock, else the enemy nearest the aim inside the lunge's magnet cone; distance, airborne, `launchable`, armored-or-guarding, enemies within `near_radius_m`). Tests: `unit/test_combo_selector.gd` (every rule has one; the last test fails if a rule is added without), `test_combo_string.gd`, `test_combo_situation.gd`, and the bot runs in `sim/test_combo_bots.gd`.
- **ActionPlayer (Gameplay Programmer, please merge with the boarding work).** The edits are confined to attack input routing: new `signal hack_pressed(info)`; `_ingest_presses` sends `heavy` to `_press_hack` and no longer makes a token of it; `light` is picked by `_combo_pick` / `_apply_combo_pick` in `_tick_free`, `_move_accepts` / `_handle_move_inputs` and the dash-cancel; string bookkeeping in `_on_move_began`, `_finish_move`, `_interrupt_move` and the hit, dash and down paths; a queued air move after the follow-jump (`_queue_air_move`, `_tick_free`); `_auto_jump_hold` so the automatic follow-jump is not cut short by the jump-release cut; the lunge reads `motion.stop_short_m`; a bot API `play_move(move_id)` starts any move directly (the Heavy no longer has a button). The camera, boarding and robot code were not touched. `LauncherInput`, `launcher_input` and the Heavy/launch entries stay in code, unreachable from the buttons, as the design says.
- **MoveRunner** `offer_move(next_id, now, press)`: the chain window rules of `offer()` but the caller names the move (the selector does). **InputBuffer** `hold_latest(token, now)`: one waiting press survives a move that has no cancel window (the launcher, air 3) and fires when it ends.
- **Cancel rules as built.** A light press inside the playing move's `chain` window starts the pick; earlier it waits (150 ms buffer) and fires at `chain[0]`. A press during a move with no chain window is held until it ends, except after a launcher that hit: from the move's `jump` cancel (180 ms) the press is a follow-jump (`launcher_follow`). Dash, jump and parry cancels work as before and end the string. Getting hit ends it too.
- **follow_jump prefix.** `hit_feel.json follow_jump.attack_after_ms` (200, new): the air attack starts that long after the follow-jump begins, near the top of the jump. Both `launcher_follow` (out of the launcher) and `rise_to_juggle` (from the ground) use it.
- **HitResolver** now reads `parry.block_reduction` from `timing_windows.json` (via `CombatData.parry_block_reduction()`): Nice 0.6, Rad and up 1.0. The old top-level `block_reduction` table (0.25 / 0.5 / 1.0) belongs to the turn-based game and is only a fallback. A table handed in as `ctx.parry.block_reduction` still wins.
- **HUD.** `SandboxHud.bind` links the player's `hack_pressed` to its call-out line. Controls card and Config screen read "Attack" and "Hack (coming later)".
- **Contract problems found (for the Technical Director).** (1) `combo.json` repeats the near and far numbers inside rules (`target_dist_m: [4.5, 12.0]`) as well as in `params`; the selector uses the rule's numbers and `params` only for the target search. (2) The hit-stop-then-launch frame: a launched enemy is still "on the floor" for the frame after the hit, so `launcher_follow` re-checks every frame until the target is airborne. (3) `ActionEnemy` is "armored" only while free or hurt, so a Brute in its block pose reads as guarding through `is_guarding()` instead; both count.

### 2026-10-09, Gameplay Programmer: CS-21 the giant-robot scale-up test built (docs/pivot/robot_scale_test.md is the Technical Artist's handoff)
Red boards a 3.5 m loader robot, docks it into a 50 m colossus's chest and drives that, all with the SAME ActionPlayer: only a **scale profile** changes. Not committed. To see it: walk out of the arena through the gate (an 8 m gap in the middle of the east wall) into the yard, step into the cyan ring at the loader's back (or press E near it), walk the loader to the amber ring in front of the colossus, `Q` (pad: left-stick click) climbs out of either robot.
- **New files (`scripts/combat/scale/`):** `ScaleProfile` (pure: loads the data, `scale_box`, `scale_attack`, `camera_view`, `merged_player_data`), `ScaleSteps` (pure: which footfalls the walk clip passed), `RobotSequence` (pure: the clock of a boarding or docking: phases, events, hit-stop, camera cues), `SmashProp` (a `CombatActor` on team `prop`: crates, cars, lamp posts, buildings; hit by the normal Hitbox flow, collapses at 0 health), `RobotDisplay` (a robot as scenery: hatch, bay doors and bay lamp are bone poses; `boarding_point()`, `seat_point()`, `approach_point()`, `dock_point()`), `RobotYard` (builds the lot from `data/combat/robot_yard.json`), `ScaleController` (camera look, fog, shadow range, sound pitch, footfalls, landing slam, stomp), `RobotBoarding` (who is in control: RED, BOARDING, SMALL, DOCKING, HUGE, UNDOCKING, DISEMBARKING). Data: `data/combat/scale_profiles.json` (forms, views, sequences, boarding, sounds), `data/combat/robot_yard.json`, `data/text/robot_test.json`. `sandbox.json` has a `robot_zone` block (`enabled` false gives the plain arena back; `enemy_spawns` puts three wolves in the yard).
- **Edits in other owners' files (all small, all default to "no change" when no scale profile is set):**
  - `action_player.gd` (**Combat Programmer: please keep these when you merge**): `signal form_changed`, `enum ControlMode {NORMAL, SCRIPTED, GHOST}`, vars `scale_profile`, `input_locked`, `_control_mode`, `_base_data`, `_forms`, `_form_id`; hooks `_knob()` (a profile's knob wins), `tick()` (`scale *= _form_time_scale(director)`, `_drop_input()` while locked or scripted, an early return for SCRIPTED and GHOST), `is_armored()` (robots do not flinch), `_start_dash()` and `_restore_enemy_collision()` (use `_body_mask()`, which drops the enemy-body bit for the colossus), `_on_move_began()` (magnet range x `magnet_mult`), `_tick_move()` (lunge x `lunge_mult`), `_handle_runner_event()` hitbox_on (box and attack scaled by the profile), `_anim_speed_factor()` (idle speed), `equip_sword()` (re-applies the sword scale). A block at the end of the file: `set_scale_profile`, `set_control_mode`, `play_scripted_clip`, `model_bone_position`, `clip_progress`, `get_form_id`, `get_scale_profile` and private helpers. `_data` is replaced by Red's `player_action.json` with the form's `body`, `move`, `jump`, `anim`, `dash` blocks laid over it; Red's own file is never edited.
  - `combat_time.gd`: `set_base_scale(actor_id, scale)` / `base_scale_of()`: a standing speed per fighter under hit-stop and flare (the robot's swings run at 0.85 / 0.45 of Red's speed; ActionPlayer sets it from `_form_time_scale`). Default 1.0 = nothing changes.
  - `orbit_camera.gd`: `set_scale_view(view, blend_s)`, `get_scale_view()`, `has_scale_view()`, `is_scale_view_blending()`, `scale_view_progress()`; `shake(profile, mult, scaled := true)` (the view's `shake_mult` applies when `scaled`, and `shake_cap_m` caps the amplitude: this is the **per-profile replacement for `CameraShake.MAX_AMPLITUDE_M`**). The view is multiples of camera.json (distance, pivot height, FOV), so the feel panel's camera distance still counts in a robot; it also sets the camera's min distance, pitch and yaw offset, near and far planes.
  - `camera_shake.gd`: `max_amplitude_m` is now a per-instance var (default `MAX_AMPLITUDE_M`, 0.25). `lock_on.gd`: `range_scale` (every reach x it). `psx_room_look.gd`: `fog_override`, `set_fog_distances(near, far)`, `fog_distances()` (survives a look-profile switch). `audio_manager.gd`: `set_scale_feel(pitch, lowpass_hz)` (`sfx_pitch_mult` on every `play_sfx`, a low-pass on the SFX bus; the ScaleController restores 1.0 when it leaves the tree). `combat_sandbox.gd`: the east wall is two pieces with a gate (`robot_zone.enabled`), `_build_robot_zone()`, `get_robot_yard()`, `get_scale_controller()`, `get_robot_boarding()`, `get_ui_parent()`, `tile_material()`; `reset_arena()` also resets the robots. `project.godot`: input action `disembark` (Q, pad left-stick click). The UI Programmer may want a controls-card row for it.
- **Per-scale numbers settled (data/combat/scale_profiles.json; guesses for Ross to retune by playing).** Red / loader / colossus. Camera distance 4.5 / 14 / 75 m; camera min distance 0.8 / 5 / 30 m; camera target height 0.8 / 1.9 / 26 m; FOV 62 / 60 / 56; pitch offset 0 / 0 / +8 degrees (shallower); far plane 400 / 1,200 / 5,000 m; shake cap 0.25 / 0.5 / 3.0 m, hit-shake multiplier 1 / 1.5 / 5. Run speed 6 / 9 / 22 m/s; acceleration 95 / 40 / 10 m/s2 (braking 75 / 50 / 14); turn rate 1,200 / 480 / 70 deg/s; jump 1.6 / 3.0 / 12 m (rise time 0.36 / 0.5 / 1.1 s; set `jump_height_m` to 0 for no jump); dash 4 m in 180 ms / 8 m in 260 ms / 40 m in 520 ms. Animation: the walk and run clips play at ground speed over the clip's stride (no foot slide), the colossus uses the walk clip for every speed (`walk_below_mps` 999), idle plays at 1 / 0.9 / 0.6; swings run at 1 / 0.85 / 0.45 of Red's speed. Sound pitch 1 / 0.75 / 0.4, plus a 4.5 kHz low-pass on the colossus. Fog (PS2 haze) 30-150 / 60-300 / 300-1,500 m, real fog density 0.012 / 0.006 / 0.0012, shadow range 30 / 120 / 700 m. Body 0.3 m / 1.0 m / 11 m radius. Health 120 / 480 / 6,000 (the fraction carries over). Attacks: shapes x1 / 3.68 / 52.6 (the swing is lifted by x1 / 2.2 / 20 and reaches out by x1 / 3 / 20, so it sweeps the floor from the robot's own feet), lunge x1 / 2.5 / 12, damage x1 / 4 / 40, knockback x1 / 2.5 / 8, hit-stop x1 / 1.3 / 2, sword scale 1 / 3.68 / 52.6. Footfalls come from the walk and run clips' foot-plant times and play the `step_small` or `step_huge` shake and dust of fx.json (shake multiplier = the file's `suggested_mult`), a landing after a 0.25 s / 0.4 s jump plays the `land_*` slam, and the colossus flattens props within 11 m of its feet while it is on the ground. Robots are armored (no flinch); the colossus ignores enemy and prop bodies.
- **Transitions (seconds):** boarding 3.0 (step in, hatch down, climb 0.9, hatch up, swap to the loader at 2.1, controls back at 2.8; the camera pulls back from 1.7 over 1.3 s); the dock is the Technical Artist's 4.5 s (approach, doors, hop, snap with an 80 ms hit-stop and a spark burst, lock, power-up; swap to the colossus at 3.6, controls at 4.3, camera 1.5 s); undock and disembark are the same backwards. The fog and shadow range ease in with the camera.
- **Not done / for later:** the colossus's head and chest lamps do not flash in the power-up (shake, sound and camera carry it); the docking uses the hop option (a) of the handoff, not the hand lift; no real sounds yet (stand-ins and a pitch drop; the Audio Designer's list is `docs/audio_requests.md` rows 70 to 75); enemies at robot scale are not tuned (the wolves are three ants in the yard).
- **Tests:** `unit/test_scale_profile.gd`, `test_scale_steps.gd`, `test_robot_sequence.gd`; `integration/test_scale_forms.gd` (the real controller in each form), `test_scale_world.gd` (camera view, shake cap, lock reach, fog, audio, time scale), `test_robot_zone.gd` (the sandbox, the gate, props, boarding, docking order, undock, fog and draw distance per form, reset) with `robot_kit.gd`; `sim/test_robot_bot.gd` (the bot run: walk out, board, walk to the dock, dock, huge steps, a jump slam, flatten a building, climb out of both). Screenshots by `tests/visual/capture_robot_test.gd`: `docs/screenshots/robot_test_small.png`, `robot_test_huge.png`, `robot_test_docking.png`.

### 2026-10-09, Technical Director: the slice continues this contract in docs/slice/slice_tech_plan.md
For the vertical slice, docs/slice/slice_tech_plan.md extends this contract (hacks through `report_hack_hit`, the battery in the director, `ring` and `beam` hitbox shapes, `scale_form` on enemies, hijacked targeting, feature switches for Lights On and the Lamp Flare). Where the two disagree about the slice, the slice plan wins; the sandbox keeps this file. On the CS-22 contract notes: (1) `combo.json` keeping distances inside rules is fine; the selector reading the rule's own numbers is the intended reading, and `test_slice_data.gd` should check the rule numbers sit inside `params`; (2) re-checking `launcher_follow` until the target is airborne is accepted; (3) `is_guarding()` counting as guarded is accepted.
