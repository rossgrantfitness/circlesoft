class_name BattleScene
extends Node3D
## The battle stage (Technical Artist, task M2-8). Builds the BattleController, shows its fight and feeds it the
## player's Clutch presses. Contract: docs/battle_api.md ("The stage").
##
##   start_battle(setup)            builds the controller, binds the HUD, plays the static-in, then runs the fight
##   signal finished(result, report) after the static-out, once the fight (and the HUD's victory screen) is over
##   screen_pos_of(id) -> Vector2    where a fighter is on the 384x216 stage, for the "!" and the HUD's pop-ups
##
## What it does with the controller's signals (all view work: it never judges anything):
##   battle_started     spawns a CombatantView per fighter on the formation slots, picks the backdrop
##   action_started     lunge / cast / defend tweens; schedules one flash + battle_ding + "!" per press, all from
##                      the single moment t0_usec + cue_ms
##   press_judged / hit rating-driven reactions: recoil, brace, TOTALLY RAD shake and push-in
##   combatant_down / fled / revived   fall-over, the K.O. freeze on the last enemy, the white-flag leave
##   battle_ended       victory hop, wait for the HUD's victory screen, static-out, then `finished`
## and, from _input, Clutch presses (action `clutch`) to controller.press_down / press_up with a timestamp from
## the same clock the cues use.
##
## The controller is reached without naming its class, so the scene loads whether or not the real one exists:
## `controller_factory` (a Callable taking the setup) is used when set; otherwise res://scripts/battle/model/
## battle_controller.gd's static create(setup). Tests pass a stub through `attach_controller()` or the factory.

signal finished(result: String, report: Dictionary)
## A cue just fired: the fighter that is about to hit or be hit, the press index, where its head is on the stage.
signal cue_fired(owner_id: String, press_index: int, stage_pos: Vector2)
## The K.O. freeze started on this fighter (the HUD shows "K.O.!" here).
signal ko_beat_started(target_id: String, stage_pos: Vector2)
## The static-in finished and the fight has been handed to the controller.
signal intro_finished
## The screen shook (strength in world units), for tests and the HUD.
signal shook(strength: float)

const STAGE_SIZE: Vector2 = Vector2(384.0, 216.0)
const CONTROLLER_SCRIPT: String = "res://scripts/battle/model/battle_controller.gd"
const HUD_PATH: String = "res://scenes/ui/battle/battle_hud.tscn"
const GROUP_STAGE: StringName = &"battle_stage"
const CLUTCH_ACTION: StringName = &"clutch"
const SIGNAL_NAMES: PackedStringArray = [
	"battle_started", "round_started", "turn_started", "action_started", "press_judged", "hit", "stats_changed",
	"status_changed", "combatant_down", "combatant_revived", "combatant_fled", "action_finished", "message",
	"battle_ended",
]
const RATING_TOTALLY_RAD: String = "totally_rad"
const SIDE_PARTY: String = "party"
const SIDE_ENEMY: String = "enemy"
const MAX_HUD_WAIT_S: float = 90.0
const USEC_PER_MS: int = 1000
const USEC_PER_S: float = 1000000.0
const NODE_BACKDROP: NodePath = ^"Backdrop"
const NODE_MARKERS: NodePath = ^"Markers"
const NODE_COMBATANTS: NodePath = ^"Combatants"
const NODE_EFFECTS: NodePath = ^"Effects"
const NODE_CAMERA: NodePath = ^"CameraRig"
const NODE_STATIC: NodePath = ^"StaticLayer"
const NODE_FLASH: NodePath = ^"FlashLayer/ScreenFlash"
const PARTY_SLOTS: int = 3
const ENEMY_SLOTS: int = 4
const MARKER_LIFT: float = 0.02
const ANCHOR_HEAD: StringName = &"head"
const ANCHOR_CENTER: StringName = &"center"
const ANCHOR_FEET: StringName = &"feet"

## Tests turn this off to skip the static transitions.
var transitions_enabled: bool = true
## The stage draws its own "!" over the fighter that owns a cue. Turn off if the HUD draws it instead.
var cue_marker_enabled: bool = true
## Set to build the controller some other way (tests, the simulator): func(setup) -> controller.
var controller_factory: Callable = Callable()
## Where sound effects go (anything with play_sfx(id)). Null = the AudioManager autoload; tests pass a fake.
var audio: Object = null
var tuning: BattleStageTuning = null
var controller: Object = null
var hud: Node = null
var views: Dictionary[String, CombatantView] = {}
var snapshot_info: Dictionary = {}
var is_boss: bool = false
var result: String = ""
var report: Dictionary = {}
var ko_beat_done: bool = false
## What the player picked on the HUD's end screen ("continue", "retry", "title", or "" when it has none).
var hud_choice: String = ""

var _setup: RefCounted = null
var _clock: Object = null
var _cues: Array[Dictionary] = []
var _ratings: Dictionary[String, String] = {}
var _defending: Dictionary[String, bool] = {}
var _markers: Dictionary[String, Marker3D] = {}
var _marker_rings: Dictionary[String, MeshInstance3D] = {}
var _marker_textures: Dictionary[String, ImageTexture] = {}
var _spawned_ids: PackedStringArray = PackedStringArray()
var _backdrop_id: String = ""
var _freeze_depth: int = 0
var _hud_done: bool = false
var _finishing: bool = false
var _relay: Node = null
var _created_ui_stage: UiStage = null
var _cue_texture: ImageTexture = null
var _cue_serial: int = 0
var _targets: PackedStringArray = PackedStringArray()
var _active_actor: String = ""
var _current_actions: Dictionary[String, Dictionary] = {}
var _last_marker_signature: int = 0

@onready var backdrop: BattleBackdrop = get_node(NODE_BACKDROP) as BattleBackdrop
@onready var markers_root: Node3D = get_node(NODE_MARKERS) as Node3D
@onready var combatants_root: Node3D = get_node(NODE_COMBATANTS) as Node3D
@onready var effects_root: Node3D = get_node(NODE_EFFECTS) as Node3D
@onready var camera_rig: BattleCamera = get_node(NODE_CAMERA) as BattleCamera
@onready var static_layer: BattleStatic = get_node(NODE_STATIC) as BattleStatic
@onready var screen_flash: ColorRect = get_node(NODE_FLASH) as ColorRect


func _ready() -> void:
	add_to_group(GROUP_STAGE)
	tuning = BattleStageTuning.from_db(get_node_or_null("/root/DataDB"))
	_prepare_stage()


func _process(_delta: float) -> void:
	_fire_due_cues()
	var signature: int = _marker_signature()
	if signature != _last_marker_signature:
		_last_marker_signature = signature
		_refresh_markers()


func _input(event: InputEvent) -> void:
	handle_input_event(event)


func _exit_tree() -> void:
	_cleanup_extras()


# ---- the public contract ----

## Builds the controller from the setup, binds the HUD, plays the static-in and runs the fight.
func start_battle(setup: RefCounted) -> void:
	_setup = setup
	if controller == null:
		var built: Object = _make_controller(setup)
		if built == null:
			push_error("BattleScene: could not build a BattleController (is %s there?)" % CONTROLLER_SCRIPT)
			return
		attach_controller(built)
	_clock = _clock_of(setup)
	await _run_intro()


## Hands the scene a controller that already exists (the stub in tests, or a real one built elsewhere). Connects
## the signals and binds the HUD. Does not start the fight; call start_fight() or use start_battle().
func attach_controller(new_controller: Object) -> void:
	controller = new_controller
	if _clock == null:
		_clock = _clock_of(controller)
	for signal_name: String in SIGNAL_NAMES:
		if controller.has_signal(signal_name):
			var handler: String = "_on_" + signal_name
			controller.connect(signal_name, Callable(self, handler))
	_ensure_hud()
	_ensure_input_relay()


## Starts the controller (the fight begins). Used after the static-in; start_battle() calls it for you.
func start_fight() -> void:
	if controller != null and controller.has_method("start"):
		controller.call("start")


## Where a fighter is on the 384x216 stage (what the HUD uses for "!" and pop-ups). `anchor` is "head" (default,
## just above the head), "center" or "feet". Unknown id or a point behind the camera gives Vector2.ZERO.
func screen_pos_of(id: String, anchor: StringName = ANCHOR_HEAD) -> Vector2:
	var view: CombatantView = views.get(id)
	if view == null or camera_rig == null:
		return Vector2.ZERO
	var camera: Camera3D = camera_rig.get_camera()
	if camera == null or not camera.is_inside_tree() or not view.is_inside_tree():
		return Vector2.ZERO
	var point: Vector3 = view.get_head_point()
	if anchor == ANCHOR_CENTER:
		point = view.get_center_point()
	elif anchor == ANCHOR_FEET:
		point = view.get_feet_point()
	if BubblePlacement.is_behind(camera, point):
		return Vector2.ZERO
	return BubblePlacement.project_to_stage(camera, point, STAGE_SIZE)


func has_combatant(id: String) -> bool:
	return views.has(id)


func get_view(id: String) -> CombatantView:
	return views.get(id)


func slot_marker(side: String, slot: int) -> Marker3D:
	return _markers.get("%s%d" % [side, slot])


## Lights the rings under these fighters in the target color (the HUD calls this while the player picks a target).
func set_target_highlight(ids: PackedStringArray) -> void:
	_targets = ids
	_refresh_markers()


## Forwards a Clutch press or release to the controller with a timestamp from the cue clock. Called by _input and
## by the input relay (the world viewport gets no input events of its own, see _ensure_input_relay).
func handle_input_event(event: InputEvent) -> void:
	if controller == null or event.is_echo():
		return
	if event.is_action_pressed(CLUTCH_ACTION):
		controller.call("press_down", _now_usec())
	elif event.is_action_released(CLUTCH_ACTION):
		controller.call("press_up", _now_usec())


## The moment on the cue clock (the controller's clock when it has one, else the real clock).
func _now_usec() -> int:
	if _clock != null and _clock.has_method("now_usec"):
		return int(_clock.call("now_usec"))
	return Time.get_ticks_usec()


## Screen shake (world units), hit-stop and the like are public so the HUD and tests can use them.
func shake(profile: String) -> void:
	var path: String = "shake." + profile
	var amplitude: float = tuning.number(path + ".amplitude")
	camera_rig.shake(amplitude, tuning.number(path + ".duration_ms"), tuning.number(path + ".step_hz"))
	shook.emit(amplitude)
	var stop_ms: float = tuning.number(path + ".hit_stop_ms")
	if stop_ms > 0.0:
		hit_stop(stop_ms)


## Freezes every fighter for `ms` (the hit-stop and the K.O. beat). Nested freezes stack.
func hit_stop(ms: float) -> void:
	_set_frozen(true)
	var tween: Tween = create_tween().set_ignore_time_scale(true)
	tween.tween_interval(ms / 1000.0)
	tween.tween_callback(_set_frozen.bind(false))


## The planned length of a boss or normal static-in or static-out, in ms (for the integrator and tests).
func transition_ms(covering: bool) -> float:
	return static_layer.duration_ms(covering)


# ---- set-up ----

func _prepare_stage() -> void:
	camera_rig.configure(tuning)
	static_layer.configure(tuning)
	static_layer.set_progress(0.0)
	screen_flash.visible = false
	_build_markers()
	_cue_texture = BattleTextures.cue_texture(tuning.integer("cue.marker_px"), tuning.color("cue.marker_color"), tuning.color("cue.marker_outline"), Color.html("#14121F"))
	_build_backdrop("default")


func _build_backdrop(id: String) -> void:
	if id == _backdrop_id:
		return
	_backdrop_id = id
	backdrop.build(tuning, id)


func _build_markers() -> void:
	for slot: int in PARTY_SLOTS:
		_make_marker(SIDE_PARTY, slot)
	for slot: int in ENEMY_SLOTS:
		_make_marker(SIDE_ENEMY, slot)
	_refresh_markers()


func _make_marker(side: String, slot: int) -> void:
	var key: String = "%s%d" % [side, slot]
	var marker: Marker3D = markers_root.get_node_or_null("%sSlot%d" % [side.capitalize(), slot]) as Marker3D
	if marker == null:
		marker = Marker3D.new()
		marker.name = "%sSlot%d" % [side.capitalize(), slot]
		markers_root.add_child(marker)
	marker.position = tuning.slot_position(side, slot)
	_markers[key] = marker
	var ring: MeshInstance3D = MeshInstance3D.new()
	ring.name = "Ring"
	var quad: QuadMesh = QuadMesh.new()
	var radius: float = tuning.number("formation.marker.radius")
	quad.size = Vector2(radius * 2.0, radius * 2.0)
	quad.orientation = PlaneMesh.FACE_Y
	ring.mesh = quad
	ring.position = Vector3(0.0, MARKER_LIFT, 0.0)
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = load("res://shaders/psx_unlit.gdshader") as Shader
	material.set_shader_parameter(&"affine_amount", 0.0)
	material.set_shader_parameter(&"uv_scale", Vector2.ONE)
	material.set_shader_parameter(&"albedo_texture", _ring_texture("base"))
	ring.set_surface_override_material(0, material)
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	marker.add_child(ring)
	_marker_rings[key] = ring


func _ring_texture(key: String) -> ImageTexture:
	if not _marker_textures.has(key):
		_marker_textures[key] = BattleTextures.ring_texture(tuning.integer("formation.marker.texture_px"), Color.WHITE)
	return _marker_textures[key]


## Rings show under fighters that are still in the fight: chalk for the party, slate for enemies, amber for
## whose turn it is, pink-red for the targets the HUD is pointing at.
func _refresh_markers() -> void:
	for key: String in _markers:
		var ring: MeshInstance3D = _marker_rings[key]
		var side: String = key.rstrip("0123456789")
		var slot: int = int(key.trim_prefix(side))
		var view: CombatantView = _view_at(side, slot)
		ring.visible = view != null and not view.gone
		if view == null:
			continue
		var color: Color = tuning.color("formation.marker.%s_color" % side)
		if view.down:
			color = color.darkened(0.55)
		if _targets.has(view.combatant_id):
			color = tuning.color("formation.marker.target_color")
		elif view.combatant_id == _active_actor:
			color = tuning.color("formation.marker.active_color")
		var material: ShaderMaterial = ring.get_surface_override_material(0) as ShaderMaterial
		material.set_shader_parameter(&"albedo_tint", color)


## Changes whenever a fighter goes down, comes back or leaves, so the rings follow without an event for each.
func _marker_signature() -> int:
	var total: int = views.size()
	for id: String in views:
		var view: CombatantView = views[id]
		total = total * 3 + (1 if view.down else 0) + (2 if view.gone else 0)
		total = total % 1000003
	return total


func _view_at(side: String, slot: int) -> CombatantView:
	for id: String in views:
		var view: CombatantView = views[id]
		if view.side == side and view.slot == slot:
			return view
	return null


func _make_controller(setup: RefCounted) -> Object:
	if controller_factory.is_valid():
		return controller_factory.call(setup) as Object
	if not ResourceLoader.exists(CONTROLLER_SCRIPT):
		return null
	var script: Script = load(CONTROLLER_SCRIPT) as Script
	if script == null:
		return null
	return script.call("create", setup) as Object


func _clock_of(source: Object) -> Object:
	if source == null:
		return null
	if source.has_method("now_usec"):
		return source
	var found: Variant = source.get("clock")
	if found is Object:
		return found as Object
	return null


func _ensure_hud() -> void:
	if hud != null or not ResourceLoader.exists(HUD_PATH):
		return
	var packed: PackedScene = load(HUD_PATH) as PackedScene
	if packed == null:
		return
	hud = packed.instantiate()
	if "stage" in hud:
		hud.set("stage", self)
	if hud is Control:
		var existing: Node = get_tree().get_first_node_in_group(UiStage.GROUP)
		var ui_stage: UiStage = UiStage.get_or_create(get_tree())
		if existing == null:
			_created_ui_stage = ui_stage
		ui_stage.get_stage_root().add_child(hud)
	else:
		add_child(hud)
	if hud.has_method("bind"):
		hud.call("bind", controller)
	for signal_name: String in tuning.string_list("end.hud_done_signals"):
		if hud.has_signal(signal_name):
			hud.connect(signal_name, _on_hud_done)
			break
	_set_hud_visible(false)


func _set_hud_visible(shown: bool) -> void:
	if hud != null and ("visible" in hud):
		hud.set("visible", shown)


func _on_hud_done(_result: Variant = null, choice: Variant = null) -> void:
	_hud_done = true
	if choice != null:
		hud_choice = str(choice)


## The world viewport (inside PsxScreen) never gets input events, so Clutch would never arrive. A tiny node in the
## root window listens instead and calls handle_input_event(). Not needed when the scene is in the root viewport.
func _ensure_input_relay() -> void:
	if _relay != null or not is_inside_tree() or get_viewport() == get_tree().root:
		return
	_relay = ClutchRelay.new()
	_relay.name = "ClutchRelay"
	(_relay as ClutchRelay).target = self
	get_tree().root.add_child.call_deferred(_relay)


func _cleanup_extras() -> void:
	if _relay != null and is_instance_valid(_relay):
		_relay.queue_free()
	_relay = null
	if hud != null and is_instance_valid(hud):
		# freed now, while this scene is still alive: the HUD unhooks from it as it leaves the tree
		var parent: Node = hud.get_parent()
		if parent != null:
			parent.remove_child(hud)
		hud.free()
	hud = null
	if _created_ui_stage != null and is_instance_valid(_created_ui_stage):
		_created_ui_stage.queue_free()
	_created_ui_stage = null


class ClutchRelay extends Node:
	var target: BattleScene = null

	func _input(event: InputEvent) -> void:
		if target != null and is_instance_valid(target):
			target.handle_input_event(event)


# ---- the intro and outro ----

func _run_intro() -> void:
	var snap: Dictionary = {}
	if controller != null and controller.has_method("snapshot"):
		snap = controller.call("snapshot") as Dictionary
	if not snap.is_empty() and snap.has("combatants"):
		_on_battle_started(snap)
	if transitions_enabled:
		static_layer.set_boss(is_boss)
		static_layer.set_progress(1.0)
		_play_sfx(&"battle_static_in")
		await get_tree().create_timer(static_layer.hold_ms() / 1000.0).timeout
		_set_hud_visible(true)
		await static_layer.reveal()
	else:
		_set_hud_visible(true)
	intro_finished.emit()
	start_fight()


func _finish_flow() -> void:
	if _finishing:
		return
	_finishing = true
	if hud != null and tuning.string_list("end.hud_done_signals").size() > 0 and _hud_has_done_signal():
		var waited: float = 0.0
		while not _hud_done and waited < MAX_HUD_WAIT_S and is_inside_tree():
			await get_tree().process_frame
			waited += get_process_delta_time()
	else:
		await get_tree().create_timer(tuning.number("end.hold_s")).timeout
	if transitions_enabled:
		_play_sfx(&"battle_static_out")
		static_layer.set_boss(is_boss)
		await static_layer.cover(static_layer.duration_ms(false))
		_set_hud_visible(false)
	var final_report: Dictionary = report.duplicate()
	if not hud_choice.is_empty():
		final_report["choice"] = hud_choice
	finished.emit(result, final_report)


func _hud_has_done_signal() -> bool:
	for signal_name: String in tuning.string_list("end.hud_done_signals"):
		if hud.has_signal(signal_name):
			return true
	return false


# ---- the controller's signals ----

func _on_battle_started(snap: Dictionary) -> void:
	snapshot_info = snap
	is_boss = bool(snap.get("is_boss", false))
	static_layer.set_boss(is_boss)
	_build_backdrop(str(snap.get("backdrop", "default")))
	var combatants: Array = snap.get("combatants", [])
	var ids: PackedStringArray = PackedStringArray()
	for entry: Variant in combatants:
		ids.append(str((entry as Dictionary).get("id", "")))
	if ids == _spawned_ids and not views.is_empty():
		for entry: Variant in combatants:
			_refresh_view_stats(entry as Dictionary)
		return
	_clear_views()
	_spawned_ids = ids
	for entry: Variant in combatants:
		_spawn_view(entry as Dictionary)
	_refresh_markers()


func _on_round_started(_round: int, _order: Array, _next_order: Array) -> void:
	pass


func _on_turn_started(actor_id: String) -> void:
	_active_actor = actor_id
	var view: CombatantView = views.get(actor_id)
	if view != null and _defending.has(actor_id):
		_defending.erase(actor_id)
		view.return_home()           # the Defend brace ends on the fighter's next turn
	elif view != null and view.side == SIDE_PARTY and not view.down:
		view.ready_pop()
	_refresh_markers()


func _on_action_started(action: Dictionary) -> void:
	var actor_id: String = str(action.get("actor", ""))
	_current_actions[actor_id] = action
	var view: CombatantView = views.get(actor_id)
	var timeline: Dictionary = action.get("timeline_ms", {})
	var windup_s: float = float(timeline.get("windup", 0.0)) / 1000.0
	var impact_s: float = float(timeline.get("impact", 0.0)) / 1000.0
	var t0: int = int(action.get("t0_usec", 0))
	var lead_s: float = maxf(float(t0 - _now_usec()) / USEC_PER_S, 0.0) if t0 > 0 else 0.0
	var targets: Array = action.get("targets", [])
	if view != null and not view.down:
		var style: String = style_for(action)
		var target_view: CombatantView = null
		if targets.size() == 1:
			target_view = views.get(str(targets[0]))
		if style == "lunge" and target_view != null and target_view != view:
			view.lunge(target_view.home_position, windup_s, impact_s, lead_s)
		elif style == "lunge" or style == "cast":
			view.cast(windup_s, impact_s, lead_s)
		elif style == "defend":
			view.defend_pose()
			_defending[actor_id] = true
		elif style == "item":
			view.item_pose()
		if view.is_boss and view.side == SIDE_ENEMY and windup_s * 1000.0 >= tuning.number("camera.push_in.boss_tell_min_windup_ms"):
			camera_rig.push_in("boss_tell")
	_schedule_cues(action, t0)


func _on_press_judged(info: Dictionary) -> void:
	if str(info.get("side", "attack")) == "attack":
		_ratings[str(info.get("actor", ""))] = str(info.get("rating", ""))


func _on_hit(info: Dictionary) -> void:
	var target: CombatantView = views.get(str(info.get("target", "")))
	var source: CombatantView = views.get(str(info.get("source", "")))
	if target == null:
		return
	var kind: String = str(info.get("kind", "damage"))
	if kind == "heal":
		target.react_heal()
		_play_sfx(&"battle_heal")
		return
	var amount: int = int(info.get("amount", 0))
	var blocked: String = str(info.get("blocked", "none"))
	var rating: String = str(_ratings.get(str(info.get("source", "")), ""))
	var away: Vector3 = target.position - (source.home_position if source != null else target.position + Vector3.RIGHT * (1.0 if target.side == SIDE_ENEMY else -1.0))
	var big: bool = rating == RATING_TOTALLY_RAD or (target.hp_max > 0 and float(amount) >= tuning.number("shake.big_damage.min_damage_fraction") * float(target.hp_max))
	if bool(info.get("payback", false)):
		# the free counter after a perfect block: the defender swings back (the controller sends it as its own hit)
		if source != null:
			source.react_payback(target.home_position)
		_play_sfx(&"battle_payback")
	if blocked == "perfect":
		target.react_block(away, true)
		_play_sfx(&"battle_perfect_block")
		shake("block_perfect")
	elif blocked == "partial":
		target.react_block(away, false)
		_play_sfx(&"battle_block")
	else:
		target.react_hit(away, big)
		_play_sfx(&"battle_hit_big" if big else &"battle_hit")
		if rating == RATING_TOTALLY_RAD:
			shake("totally_rad")
			camera_rig.push_in("big_hit")
		elif big and target.side == SIDE_PARTY:
			shake("big_damage")


func _on_stats_changed(id: String, hp: int, hp_max: int, _juice: int, _juice_max: int) -> void:
	var view: CombatantView = views.get(id)
	if view != null:
		view.hp = hp
		view.hp_max = hp_max


func _on_status_changed(_id: String, _status_id: String, _added: bool) -> void:
	pass


func _on_message(_text: String) -> void:
	pass


func _on_combatant_down(id: String) -> void:
	var view: CombatantView = views.get(id)
	if view == null:
		return
	_play_sfx(&"battle_down")
	var away: Vector3 = Vector3.LEFT if view.side == SIDE_ENEMY else Vector3.RIGHT
	if view.side == SIDE_ENEMY and _is_last_enemy_standing(id):
		_ko_beat(id, _fall_after_beat.bind(id, away))
	else:
		view.knock_out(away)
	_refresh_markers()


func _fall_after_beat(id: String, away: Vector3) -> void:
	var view: CombatantView = views.get(id)
	if view != null:
		view.knock_out(away)
	_refresh_markers()


func _on_combatant_revived(id: String) -> void:
	var view: CombatantView = views.get(id)
	if view != null:
		view.revive()
		_play_sfx(&"battle_heal")
	_refresh_markers()


func _on_combatant_fled(id: String) -> void:
	var view: CombatantView = views.get(id)
	if view == null:
		return
	_play_sfx(&"battle_flee")
	view.flee(Vector3.LEFT if view.side == SIDE_ENEMY else Vector3.RIGHT)
	_refresh_markers()


func _on_action_finished(action: Dictionary) -> void:
	var actor_id: String = str(action.get("actor", ""))
	_current_actions.erase(actor_id)
	_ratings.erase(actor_id)
	var view: CombatantView = views.get(actor_id)
	if view == null or view.down or _defending.has(actor_id):
		return
	view.return_home()


func _on_battle_ended(outcome: String, final_report: Dictionary) -> void:
	result = outcome
	report = final_report
	if outcome == "win":
		var target_id: String = str(final_report.get("final_ko_target", ""))
		if not ko_beat_done and views.has(target_id):
			_ko_beat(target_id, _celebrate.bind(target_id))
		else:
			_celebrate(target_id)
	elif outcome == "ran":
		for id: String in views:
			var runner: CombatantView = views[id]
			if runner.side == SIDE_PARTY and not runner.down:
				runner.flee(Vector3.RIGHT)       # the party scrambles off to the right
	_finish_flow()


## The win: the last enemy goes down if it has not yet, and everyone still standing does the victory hop.
func _celebrate(last_id: String) -> void:
	var last: CombatantView = views.get(last_id)
	if last != null and not last.down:
		last.knock_out(Vector3.LEFT)
	var delay: float = 0.0
	for id: String in views:
		var view: CombatantView = views[id]
		if view.side == SIDE_PARTY and not view.down:
			view.return_home()
			view.victory_hop(delay + 0.25)
			delay += tuning.number("motion.victory_hop.stagger_ms") / 1000.0
	camera_rig.push_in("victory")


# ---- cues: one moment drives the flash, the ding and the "!" ----

func _schedule_cues(action: Dictionary, t0: int) -> void:
	var start: int = t0 if t0 > 0 else _now_usec()
	var presses: Array = action.get("presses", [])
	for entry: Variant in presses:
		var press: Dictionary = entry
		# A scrambled cue (the boss's fake-out) flashes at shown_cue_ms; the judge still uses the real cue_ms.
		var shown_ms: float = float(press.get("shown_cue_ms", press.get("cue_ms", 0.0)))
		var due: int = start + int(shown_ms * float(USEC_PER_MS))
		_cues.append({
			"due": due,
			"owner": str(press.get("owner_id", action.get("actor", ""))),
			"index": int(press.get("index", 0)),
			"side": str(press.get("side", "attack")),
			"type": str(press.get("type", "tap")),
		})
	_fire_due_cues()


func _fire_due_cues() -> void:
	if _cues.is_empty():
		return
	var now: int = _now_usec()
	var remaining: Array[Dictionary] = []
	for cue: Dictionary in _cues:
		if now >= int(cue["due"]):
			_fire_cue(cue)
		else:
			remaining.append(cue)
	_cues = remaining


func _fire_cue(cue: Dictionary) -> void:
	var owner_id: String = str(cue["owner"])
	var view: CombatantView = views.get(owner_id)
	if view != null:
		view.flash(tuning.color("cue.flash_color"), tuning.number("cue.flash_ms"))
		if cue_marker_enabled:
			_spawn_cue_marker(view)
	_play_sfx(&"battle_ding")
	cue_fired.emit(owner_id, int(cue["index"]), screen_pos_of(owner_id))


func pending_cue_count() -> int:
	return _cues.size()


## A hot-orange "!" bubble that pops in over the fighter's head (3-step overshoot) and drops away.
func _spawn_cue_marker(view: CombatantView) -> void:
	var sprite: Sprite3D = Sprite3D.new()
	_cue_serial += 1
	sprite.name = "CueMarker%d" % _cue_serial
	sprite.texture = _cue_texture
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sprite.shaded = false
	sprite.no_depth_test = true
	sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	sprite.render_priority = 10
	sprite.pixel_size = 0.55 / float(_cue_texture.get_width())
	var gap: float = tuning.number("cue.marker_height_gap")
	var boss_scale: float = tuning.number("cue.marker_scale_boss") if view.is_boss else tuning.number("cue.marker_scale")
	sprite.position = Vector3(0.0, view.body_top + gap + 0.3, 0.0)
	sprite.scale = Vector3.ONE * 0.5 * boss_scale
	view.add_child(sprite)
	var tween: Tween = sprite.create_tween()
	tween.tween_property(sprite, "scale", Vector3.ONE * 1.2 * boss_scale, 0.06)
	tween.tween_property(sprite, "scale", Vector3.ONE * boss_scale, 0.06)
	tween.tween_interval(tuning.number("cue.marker_ms") / 1000.0)
	tween.tween_callback(sprite.queue_free)


# ---- the K.O. beat ----

func _is_last_enemy_standing(id: String) -> bool:
	for other_id: String in views:
		var other: CombatantView = views[other_id]
		if other.side == SIDE_ENEMY and other_id != id and not other.down and not other.gone:
			return false
	return true


## The last hit of the fight freezes everything for a beat: a white flash, a push-in, the K.O. sound, and a signal
## for the HUD to slam up "K.O.!".
func _ko_beat(id: String, then: Callable = Callable()) -> void:
	if ko_beat_done:
		if then.is_valid():
			then.call()
		return
	ko_beat_done = true
	var freeze_s: float = tuning.number("ko.freeze_ms") / 1000.0
	ko_beat_started.emit(id, screen_pos_of(id))
	if hud == null:
		_play_sfx(&"battle_ko")      # with a HUD, its "K.O.!" plays the sound (battle_ui.json sfx.ko)
	_flash_screen(tuning.color("ko.flash_color"), tuning.number("ko.flash_ms"))
	camera_rig.push_in("ko")
	_set_frozen(true)
	var tween: Tween = create_tween().set_ignore_time_scale(true)
	tween.tween_interval(freeze_s)
	tween.tween_callback(_end_ko_beat.bind(then))


func _end_ko_beat(then: Callable) -> void:
	_set_frozen(false)
	if then.is_valid():
		then.call()


func _set_frozen(on: bool) -> void:
	_freeze_depth = maxi(_freeze_depth + (1 if on else -1), 0)
	var frozen: bool = _freeze_depth > 0
	for id: String in views:
		views[id].freeze(frozen)


func is_frozen() -> bool:
	return _freeze_depth > 0


func _flash_screen(color: Color, ms: float) -> void:
	screen_flash.color = color
	screen_flash.visible = true
	var tween: Tween = create_tween().set_ignore_time_scale(true)
	tween.tween_interval(ms / 1000.0)
	tween.tween_callback(screen_flash.hide)


# ---- views ----

func _spawn_view(info: Dictionary) -> void:
	var view: CombatantView = CombatantView.new()
	var path: String = _resolve_model(info)
	view.setup(info, tuning, path)
	combatants_root.add_child(view)
	var side: String = view.side
	var slot_point: Vector3 = tuning.slot_position(side, view.slot)
	var yaw: float = deg_to_rad(tuning.number("formation.%s_facing_deg" % side))
	view.set_home(slot_point, yaw)
	view.idle()
	views[view.combatant_id] = view


func _refresh_view_stats(info: Dictionary) -> void:
	var view: CombatantView = views.get(str(info.get("id", "")))
	if view != null:
		view.hp = int(info.get("hp", view.hp))
		view.hp_max = int(info.get("hp_max", view.hp_max))


func _clear_views() -> void:
	for id: String in views:
		var view: CombatantView = views[id]
		if is_instance_valid(view):
			combatants_root.remove_child(view)
			view.queue_free()
	views.clear()


## The snapshot's own model path when it loads; otherwise a model for the character or enemy kind from the data.
func _resolve_model(info: Dictionary) -> String:
	var wanted: String = str(info.get("model", ""))
	if not wanted.is_empty() and ResourceLoader.exists(wanted):
		return wanted
	var kind: String = str(info.get("kind", info.get("id", "")))
	if str(info.get("side", SIDE_PARTY)) == SIDE_PARTY:
		var party: Dictionary = tuning.dict("model.party_models")
		if party.has(kind):
			return str(party[kind])
		if party.has(str(info.get("id", ""))):
			return str(party[str(info.get("id", ""))])
		return ""
	for rule: Variant in tuning.list("model.enemy_rules"):
		var entry: Dictionary = rule
		if kind.contains(str(entry["contains"])):
			return str(entry["model"])
	return tuning.text("model.default_enemy_model")


func style_for(action: Dictionary) -> String:
	var by_anim: Dictionary = tuning.dict("motion.styles.by_anim")
	var anim: String = str(action.get("anim", ""))
	if by_anim.has(anim):
		return str(by_anim[anim])
	var by_kind: Dictionary = tuning.dict("motion.styles.by_kind")
	return str(by_kind.get(str(action.get("kind", "attack")), "lunge"))


func _play_sfx(id: StringName) -> void:
	var player: Object = audio if audio != null else get_node_or_null("/root/AudioManager")
	if player != null:
		player.call("play_sfx", id)
