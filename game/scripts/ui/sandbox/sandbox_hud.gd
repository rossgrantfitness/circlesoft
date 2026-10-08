class_name SandboxHud
extends Control
## The combat sandbox HUD (CS-15, contract 4.6). One scene for the whole sandbox UI: Red's HP, the
## Noise meter and its rank pop-ups, the Lights On indicator, the Lamp Flare timer, the lock-on
## reticle, small HP bars over hurt enemies, parry / Lamp Flare / stagger pop-ups, damage numbers,
## the camera-style tag and a one-line "Esc: Pause" reminder. It also owns the pause menu (with the
## controls card and the remap page) and the feel-knobs panel, so one instance is the whole UI.
##
## Instancing (the arena's job):
##   var stage: UiStage = UiStage.get_or_create(get_tree())
##   var hud: SandboxHud = load("res://scenes/ui/sandbox/sandbox_hud.tscn").instantiate()
##   stage.get_stage_root().add_child(hud)
##   hud.bind(self)            # self = the CombatSandbox
##
## What `bind(sandbox)` uses from the sandbox (contract 4.6): get_director() with the CombatDirector
## signals and its `feel` (FeelKnobs), `time`, `lights_on`, get_player(), get_lock_on(), get_camera(),
## and screen_pos_of(actor_id, point) in the 3D picture's pixels. Anything missing is skipped, so a
## partial stub works. The pause menu's Reset calls the sandbox's reset_arena() (else reset()).
##
## Everything is laid out in 384x216 stage pixels; positions from the sandbox are scaled from the 3D
## picture (640x360 in the sandbox). The HUD runs on real time (no hit-stop, no flare slow-down).
## Layout and colors: data/ui/sandbox_ui.json. Words: data/text/sandbox.json.

## The pause menu's Reset arena was chosen (the sandbox has been asked to reset).
signal reset_requested
## The pause menu's Quit was chosen.
signal quit_requested

const PANEL_SCENE: String = "res://scenes/ui/sandbox/feel_panel.tscn"
const PAUSE_SCENE: String = "res://scenes/ui/sandbox/sandbox_pause.tscn"
const SCENE_PATH: String = "res://scenes/ui/sandbox/sandbox_hud.tscn"
const POS_METHOD: StringName = &"screen_pos_of"
const RESET_METHODS: Array[StringName] = [&"reset_arena", &"reset"]
## OrbitCamera.Mode.DIORAMA (the enum is ORBIT = 0, DIORAMA = 1, contract 4.8).
const MODE_DIORAMA: int = 1
const TEAM_PLAYER: String = "player"
const NO_POSITION: Vector2 = Vector2.INF

var sandbox: Object = null
var audio: UiAudio = UiAudio.new()
## Off: the HUD does not run itself; tests call tick(delta).
var manual_ticks: bool = false
var animations_enabled: bool = true
## On: Esc / pad Start opens the pause menu.
var listen_input: bool = true
## Off: Quit only emits `quit_requested` (tests).
var auto_quit: bool = true
## On (the game): the HUD moves itself out of the 384x216 UI stage onto its own layer at the real window
## resolution, scaled by a whole number, so text is crisp at 1080p and up. Tests turn it off.
var relocate_to_window: bool = true

var _director: Object = null
var _lock_on: Object = null
var _camera: Object = null
var _bindings: Array[Array] = []
var _red_id: String = "red"
var _teams: Dictionary[String, String] = {}
var _hp: int = 0
var _hp_max: int = 1
var _hp_chip: float = 0.0
var _hp_chip_wait: float = 0.0
var _noise_points: float = 0.0
var _noise_fill: float = 0.0
var _noise_shown: float = 0.0
var _rank_id: String = ""
var _rank_name: String = ""
var _noise_flash_left: float = 0.0
var _noise_flash_color: Color = Color.WHITE
var _lights_active: bool = false
var _lights_total: float = 0.0
var _lights_left: float = 0.0
var _flare_active: bool = false
var _flare_total: float = 0.0
var _flare_left: float = 0.0
var _enemy_bars: Dictionary[String, Dictionary] = {}
var _lock_id: String = ""
var _lock_age: float = 0.0
var _camera_diorama: bool = false
var _pad_mode: bool = false
var _clock: float = 0.0
var _floaters: Array[SandboxFloater] = []
## Event call-outs, newest first: {text, age}. Drawn small and white under the Noise meter.
var _callouts: Array[Dictionary] = []
var _layer: CanvasLayer = null
var _relocating: bool = false
var _stretch: float = 1.0

var _meters: Control = null  ## top-left corner
var _tr: Control = null  ## top-right corner
var _bl: Control = null  ## bottom-left corner
var _br: Control = null  ## bottom-right corner
var _world: Control = null
var _popup_layer: Control = null
var _panel: FeelPanel = null
var _pause: SandboxPause = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	size = Vector2(SandboxStyle.REFERENCE_SIZE)
	set_process(not manual_ticks)
	_build()
	if relocate_to_window:
		_move_to_window.call_deferred()


func _process(delta: float) -> void:
	tick(delta)


func _exit_tree() -> void:
	if _relocating:
		return
	unbind()
	if is_instance_valid(_layer):
		_layer.queue_free()


## Moves the whole HUD (with its menus) onto a CanvasLayer on the root window, so it draws at window
## resolution instead of inside the 3D picture's 384x216 UI stage, and keeps it sized to the window.
func _move_to_window() -> void:
	if not is_inside_tree() or get_parent() is CanvasLayer:
		return
	var root: Window = get_tree().root
	_layer = CanvasLayer.new()
	_layer.name = "SandboxHudLayer"
	_layer.layer = SandboxUiData.ui_int("layer", 90)
	_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	root.add_child(_layer)
	_relocating = true
	reparent(_layer, false)
	_relocating = false
	if not root.size_changed.is_connected(_fit_to_window):
		root.size_changed.connect(_fit_to_window)
	_fit_to_window()


## Whole-number scale from the window height (data: ui.window_px_per_scale), and the UI size that gives.
func _fit_to_window() -> void:
	if not is_inside_tree():
		return
	# The project stretches the canvas to the window (canvas_items). This layer undoes that, so its units
	# are real window pixels and the whole-number scale below is exact.
	var window: Vector2 = Vector2(get_tree().root.size)
	_stretch = maxf(0.01, get_tree().root.get_final_transform().get_scale().x)
	if is_instance_valid(_layer):
		_layer.scale = Vector2(1.0 / _stretch, 1.0 / _stretch)
	var factor: float = float(maxi(1, roundi(window.y / SandboxUiData.ui_float("window_px_per_scale", 400.0))))
	scale = Vector2(factor, factor)
	position = Vector2.ZERO
	size = (window / factor).floor()
	_place_corners()


## The 384x216 reference layout is anchored to the four corners of the (larger) UI size.
func _place_corners() -> void:
	var ref: Vector2 = Vector2(SandboxStyle.REFERENCE_SIZE)
	var extra: Vector2 = (size - ref).max(Vector2.ZERO)
	if _meters == null:
		return
	_meters.position = Vector2.ZERO
	_tr.position = Vector2(extra.x, 0.0)
	_bl.position = Vector2(0.0, extra.y)
	_br.position = extra
	_world.size = size
	_popup_layer.size = size
	for corner: Control in [_meters, _tr, _bl, _br]:
		corner.size = ref


## The UI size in UI units (the whole window divided by the whole-number scale).
func ui_size() -> Vector2:
	return size


## UI units per window pixel is 1 / this.
func ui_scale() -> float:
	return scale.x


func _make_layer(layer_name: String, callback: Callable, layer_size: Vector2) -> Control:
	var control: Control = Control.new()
	control.name = layer_name
	control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	control.size = layer_size
	if callback.is_valid():
		control.draw.connect(callback)
	add_child(control)
	return control


func _build() -> void:
	var ref: Vector2 = Vector2(SandboxStyle.REFERENCE_SIZE)
	_meters = _make_layer("TopLeft", _draw_tl, ref)
	_tr = _make_layer("TopRight", _draw_tr, ref)
	_bl = _make_layer("BottomLeft", _draw_bl, ref)
	_br = _make_layer("BottomRight", _draw_br, ref)
	_world = _make_layer("World", _draw_world, size)
	_popup_layer = _make_layer("Floaters", Callable(), size)
	_panel = (load(PANEL_SCENE) as PackedScene).instantiate() as FeelPanel
	_panel.name = "FeelPanel"
	_panel.audio = audio
	_panel.manual_ticks = manual_ticks
	_panel.listen_input = listen_input
	_panel.animations_enabled = animations_enabled
	add_child(_panel)
	_pause = (load(PAUSE_SCENE) as PackedScene).instantiate() as SandboxPause
	_pause.name = "Pause"
	_pause.audio = audio
	_pause.manual_ticks = manual_ticks
	_pause.listen_input = listen_input
	_pause.animations_enabled = animations_enabled
	_pause.reset_requested.connect(_on_reset_requested)
	_pause.quit_requested.connect(_on_quit_requested)
	add_child(_pause)
	_update_camera_text()


# ---- binding ----

## Connects the HUD to the sandbox (see the class comment). Safe to call again with another sandbox.
func bind(target: Object) -> void:
	unbind()
	sandbox = target
	if sandbox == null:
		return
	_director = _call(sandbox, &"get_director") as Object
	_lock_on = _call(sandbox, &"get_lock_on") as Object
	_camera = _call(sandbox, &"get_camera") as Object
	var player: Object = _call(sandbox, &"get_player") as Object
	if player != null and player.get(&"actor_id") != null and not str(player.get(&"actor_id")).is_empty():
		_red_id = str(player.get(&"actor_id"))
	if _director != null:
		_link(_director, &"actor_registered", _on_actor_registered)
		_link(_director, &"actor_died", _on_actor_died)
		_link(_director, &"hp_changed", _on_hp_changed)
		_link(_director, &"hit_landed", _on_hit_landed)
		_link(_director, &"parry_judged", _on_parry_judged)
		_link(_director, &"perfect_dodge", _on_perfect_dodge)
		_link(_director, &"flare_started", _on_flare_started)
		_link(_director, &"flare_ended", _on_flare_ended)
		_link(_director, &"stagger", _on_stagger)
		_link(_director, &"noise_changed", _on_noise_changed)
		_link(_director, &"noise_rank_changed", _on_noise_rank_changed)
		_link(_director, &"lights_on_changed", _on_lights_on_changed)
		_seed_from_actors()
	var knobs: Object = null
	if _director != null:
		knobs = _director.get(&"feel") as Object
	if knobs == null:
		knobs = _call(sandbox, &"get_feel") as Object
	if knobs != null:
		_panel.bind(knobs)
	if _lock_on != null:
		_link(_lock_on, &"target_changed", _on_target_changed)
	if _camera != null:
		_link(_camera, &"mode_changed", _on_mode_changed)
		if _camera.has_method(&"get_mode"):
			_camera_diorama = int(_camera.call(&"get_mode")) == MODE_DIORAMA
			_update_camera_text()


func unbind() -> void:
	for binding: Array in _bindings:
		if not is_instance_valid(binding[0]):
			continue  # the source was freed first (scene teardown); nothing to disconnect
		var source: Object = binding[0] as Object
		if source.is_connected(binding[1], binding[2]):
			source.disconnect(binding[1], binding[2])
	_bindings.clear()
	_director = null
	_lock_on = null
	_camera = null
	sandbox = null


func _link(source: Object, signal_name: StringName, handler: Callable) -> void:
	if source == null or not source.has_signal(signal_name):
		return
	source.connect(signal_name, handler)
	_bindings.append([source, signal_name, handler])


func _call(target: Object, method: StringName, args: Array = []) -> Variant:
	if target == null or not target.has_method(method):
		return null
	return target.callv(method, args)


## Fills Red's HP and the enemy bar table from fighters already registered.
func _seed_from_actors() -> void:
	var list: Variant = _call(_director, &"actors")
	if not list is Array:
		return
	for actor: Variant in list:
		var node: Object = actor as Object
		if node == null:
			continue
		var id: String = str(node.get(&"actor_id"))
		_teams[id] = str(node.get(&"team"))
		if id == _red_id:
			_hp = int(node.get(&"hp"))
			_hp_max = maxi(1, int(node.get(&"hp_max")))
			_hp_chip = float(_hp)


func get_feel_panel() -> FeelPanel:
	return _panel


func get_pause_menu() -> SandboxPause:
	return _pause


# ---- what the HUD shows (for tests and for the rest of the game) ----

func get_hp() -> int:
	return _hp


func get_hp_max() -> int:
	return _hp_max


func get_noise() -> Dictionary:
	return {"points": _noise_points, "fill": _noise_fill, "rank_id": _rank_id, "rank_name": _rank_name}


func is_lights_on() -> bool:
	return _lights_active


func is_flaring() -> bool:
	return _flare_active


func get_lock_id() -> String:
	return _lock_id


func get_enemy_bar_ids() -> Array[String]:
	var ids: Array[String] = []
	for id: String in _enemy_bars:
		ids.append(id)
	return ids


## The damage numbers floating over fighters right now.
func get_floaters() -> Array[SandboxFloater]:
	return _floaters


## The event call-out texts on screen, newest first.
func get_callouts() -> Array[String]:
	var out: Array[String] = []
	for entry: Dictionary in _callouts:
		out.append(str(entry["text"]))
	return out


func get_camera_text() -> String:
	return SandboxUiData.text("hud.camera_diorama" if _camera_diorama else "hud.camera_orbit")


func get_hint_text() -> String:
	return SandboxUiData.text("hud.hint_pad" if _pad_mode else "hud.hint_keys")


## True while any sandbox menu (pause, controls, feel panel) is up.
func is_menu_open() -> bool:
	return _pause.is_open() or _panel.is_open()


# ---- positions ----

## Picture pixels -> UI units. With a PsxScreen running, the picture's real place on the window is used
## (whatever the window size), else the picture is taken to fill the UI.
func world_scale() -> Vector2:
	var world: Vector2 = SandboxUiData.vec("world_size")
	var screen: Node = get_tree().get_first_node_in_group(UiStage.SCREEN_GROUP) if is_inside_tree() else null
	if screen is PsxScreen:
		world = Vector2((screen as PsxScreen).get_resolution())
	if world.x <= 0.0 or world.y <= 0.0:
		return Vector2.ONE
	return size / world


## A point in the 3D picture (picture pixels) in UI units.
func picture_to_ui(point: Vector2) -> Vector2:
	var screen: Node = get_tree().get_first_node_in_group(UiStage.SCREEN_GROUP) if is_inside_tree() else null
	if screen is PsxScreen and relocate_to_window and get_parent() is CanvasLayer:
		var display: Rect2 = ((screen as PsxScreen).get_display() as Control).get_global_rect()
		var res: Vector2 = Vector2((screen as PsxScreen).get_resolution())
		return (display.position + point / res * display.size) * _stretch / ui_scale()
	return point * world_scale()


## Where a fighter's anchor is on the UI, or NO_POSITION when the sandbox can't say.
func position_of(actor_id: String, point: StringName = &"head") -> Vector2:
	if sandbox == null or not sandbox.has_method(POS_METHOD):
		return NO_POSITION
	var at: Vector2 = sandbox.call(POS_METHOD, StringName(actor_id), point)
	if at == Vector2.ZERO:
		return NO_POSITION
	return picture_to_ui(at)


## A world point on the UI (for hits that come with a Vector3), or NO_POSITION.
func project_world(point: Vector3) -> Vector2:
	var cam: Camera3D = _call(_camera, &"get_camera") as Camera3D
	if cam == null or cam.is_position_behind(point):
		return NO_POSITION
	var viewport_size: Vector2 = cam.get_viewport().get_visible_rect().size
	if viewport_size.x <= 0.0:
		return NO_POSITION
	return picture_to_ui(cam.unproject_position(point) * (SandboxUiData.vec("world_size") / viewport_size))


func _fallback_position() -> Vector2:
	return size * 0.5


# ---- signals ----

func _on_actor_registered(actor_id: StringName, team: StringName) -> void:
	_teams[str(actor_id)] = str(team)


func _on_actor_died(actor_id: StringName) -> void:
	var id: String = str(actor_id)
	_enemy_bars.erase(id)
	if id == _red_id:
		_hp = 0
		_hp_chip_wait = SandboxUiData.ui_float("hud.hp_chip_delay_s", 0.35)
	if id == _lock_id:
		_lock_id = ""


func _on_hp_changed(actor_id: StringName, hp: int, hp_max: int) -> void:
	var id: String = str(actor_id)
	if id == _red_id:
		if hp < _hp:
			_hp_chip = maxf(_hp_chip, float(_hp))
			_hp_chip_wait = SandboxUiData.ui_float("hud.hp_chip_delay_s", 0.35)
		else:
			_hp_chip = float(hp)
		_hp = hp
		_hp_max = maxi(1, hp_max)
		return
	if str(_teams.get(id, "")) == TEAM_PLAYER:
		return
	if hp >= hp_max or hp <= 0:
		_enemy_bars.erase(id)
		return
	_enemy_bars[id] = {"hp": hp, "max": maxi(1, hp_max), "age": 0.0}


func _on_hit_landed(info: Dictionary) -> void:
	var damage: int = int(info.get("damage", 0))
	var outcome: String = str(info.get("outcome", "hit"))
	if damage <= 0 or outcome == "ignored" or outcome == "evaded":
		return
	var target: String = str(info.get("target", ""))
	var at: Vector2 = position_of(target, &"head")
	if not at.is_finite() and info.get("position") is Vector3:
		at = project_world(info["position"] as Vector3)
	if not at.is_finite():
		at = _fallback_position()
	var color: Color = SandboxStyle.color("text")
	if target == _red_id:
		color = SandboxUiData.color("red_damage")
	elif outcome == "armored":
		color = SandboxUiData.color("armored")
	var stack: int = mini(_floaters_on(target), SandboxUiData.ui_int("hud.damage_stack_max", 4))
	var lift: float = float(SandboxUiData.ui_int("hud.damage_lift_px", 4) + stack * SandboxUiData.ui_int("hud.damage_stack_px", 9))
	var sway: float = float((_floater_serial % 3) - 1) * 4.0
	_spawn_floater(str(damage), color, at + Vector2(sway, -lift), target)


func _floaters_on(target: String) -> int:
	var count: int = 0
	for floater: SandboxFloater in _floaters:
		if floater.target == target:
			count += 1
	return count


func _on_parry_judged(info: Dictionary) -> void:
	_call_out(SandboxPopups.parry_text(str(info.get("rating", "miss"))))


func _on_perfect_dodge(_info: Dictionary) -> void:
	_call_out(SandboxPopups.lamp_flare_text())


func _on_flare_started(info: Dictionary) -> void:
	_flare_active = true
	_flare_total = maxf(0.01, float(info.get("duration_s", 0.0)))
	_flare_left = _flare_total
	if str(info.get("source", "")) == "parry":
		_call_out(SandboxPopups.lamp_flare_text())


func _on_flare_ended() -> void:
	_flare_active = false
	_flare_left = 0.0


func _on_stagger(info: Dictionary) -> void:
	_call_out(SandboxPopups.stagger_text(str(info.get("by", "poise"))))


func _on_noise_changed(points: float, fill: float, rank_id: StringName, rank_name: String) -> void:
	_noise_points = points
	_noise_fill = clampf(fill, 0.0, 1.0)
	_rank_id = str(rank_id)
	_rank_name = rank_name


func _on_noise_rank_changed(rank_id: StringName, rank_name: String, went_up: bool) -> void:
	_rank_id = str(rank_id)
	_rank_name = rank_name
	var steps: float = float(SandboxUiData.ui_int("hud.noise_flash_steps", 4)) * SandboxUiData.ui_float("step_s", 0.0833)
	if went_up:
		_call_out(rank_name)
		audio.sfx_id(str(SandboxUiData.ui("sfx.rank_up", "")))
		_noise_flash_left = steps
		_noise_flash_color = SandboxPopups.rank_color(_rank_id)
	else:
		_noise_flash_left = steps
		_noise_flash_color = SandboxUiData.color("warn")


func _on_lights_on_changed(active: bool, duration_s: float) -> void:
	_lights_active = active
	_lights_total = maxf(0.01, duration_s)
	_lights_left = duration_s if active else 0.0


func _on_target_changed(target: Object) -> void:
	_lock_age = 0.0
	if target == null:
		_lock_id = ""
		return
	_lock_id = str(target.get(&"actor_id"))
	audio.sfx_id(str(SandboxUiData.ui("sfx.lock_on", "")))


func _on_mode_changed(mode: int) -> void:
	_camera_diorama = mode == MODE_DIORAMA
	_update_camera_text()


func _update_camera_text() -> void:
	if _pause != null and _pause.get_card() != null:
		_pause.get_card().camera_mode_text = get_camera_text()


# ---- pause menu plumbing ----

func _on_reset_requested() -> void:
	if sandbox != null:
		for method: StringName in RESET_METHODS:
			if sandbox.has_method(method):
				sandbox.call(method)
				break
	_clear_transients()
	reset_requested.emit()


func _on_quit_requested() -> void:
	quit_requested.emit()
	if auto_quit and is_inside_tree():
		get_tree().quit()


## Drops floating numbers, call-outs, enemy bars, the reticle and the meters' leftovers (a reset starts a fresh fight).
func _clear_transients() -> void:
	for floater: SandboxFloater in _floaters:
		floater.queue_free()
	_floaters.clear()
	_callouts.clear()
	_enemy_bars.clear()
	_lock_id = ""
	_flare_active = false
	_lights_active = false


# ---- floating numbers and call-outs ----

var _floater_serial: int = 0


func _spawn_floater(text: String, color: Color, at: Vector2, target: String) -> void:
	_floater_serial += 1
	var floater: SandboxFloater = SandboxFloater.new()
	floater.text = text
	floater.tint = color
	floater.target = target
	floater.position = Vector2(clampf(at.x, 16.0, size.x - 16.0), clampf(at.y, 16.0, size.y - 8.0))
	floater.finished.connect(_on_floater_finished)
	_popup_layer.add_child(floater)
	_floaters.append(floater)
	var cap: int = SandboxUiData.ui_int("hud.max_popups", 24)
	while _floaters.size() > cap:
		var oldest: SandboxFloater = _floaters.pop_front()
		oldest.queue_free()


func _on_floater_finished(floater: SandboxFloater) -> void:
	_floaters.erase(floater)
	floater.queue_free()


## Adds a short event line under the Noise meter ("Lamp Flare!", "Perfect Parry!"). At most two show.
func _call_out(text: String) -> void:
	if text.is_empty():
		return
	_callouts.push_front({"text": text, "age": 0.0})
	while _callouts.size() > SandboxUiData.ui_int("hud.callouts.max", 2):
		_callouts.pop_back()


func _over_red(lift: int) -> Vector2:
	var at: Vector2 = position_of(_red_id, &"head")
	if not at.is_finite():
		at = _fallback_position()
	return at - Vector2(0, float(lift))


# ---- time ----

func tick(delta: float) -> void:
	_clock += delta
	for floater: SandboxFloater in _floaters.duplicate():
		if is_instance_valid(floater):
			floater.tick(delta)
	_tick_callouts(delta)
	_tick_hp(delta)
	_tick_noise(delta)
	_tick_lights_and_flare(delta)
	_tick_world(delta)
	for layer: Control in [_meters, _tr, _bl, _br, _world]:
		layer.queue_redraw()


func _tick_callouts(delta: float) -> void:
	var data: Dictionary = SandboxUiData.ui("hud.callouts", {})
	var life: float = float(data.get("slide_s", 0.15)) + float(data.get("hold_s", 1.4)) + float(data.get("fade_s", 0.4))
	for entry: Dictionary in _callouts.duplicate():
		entry["age"] = float(entry["age"]) + delta
		if float(entry["age"]) > life:
			_callouts.erase(entry)


func _tick_hp(delta: float) -> void:
	if _hp_chip_wait > 0.0:
		_hp_chip_wait -= delta
		return
	if _hp_chip > float(_hp):
		_hp_chip = maxf(float(_hp), _hp_chip - float(_hp_max) * SandboxUiData.ui_float("hud.hp_chip_per_s", 0.9) * delta)
	else:
		_hp_chip = float(_hp)


func _tick_noise(delta: float) -> void:
	var speed: float = SandboxUiData.ui_float("hud.noise_per_s", 1.2) * delta
	_noise_shown = move_toward(_noise_shown, _noise_fill, speed)
	if _noise_flash_left > 0.0:
		_noise_flash_left = maxf(0.0, _noise_flash_left - delta)


func _tick_lights_and_flare(delta: float) -> void:
	if _lights_active:
		var lights: Object = _director.get(&"lights_on") as Object if _director != null else null
		var left: float = float(lights.call(&"remaining_s")) if lights != null and lights.has_method(&"remaining_s") else 0.0
		# The model's own clock when it has one (it follows Red's hit-stop); our count-down otherwise.
		_lights_left = left if left > 0.0 else maxf(0.0, _lights_left - delta)
	if _flare_active:
		var time: Object = _director.get(&"time") as Object if _director != null else null
		var flare_left: float = float(time.call(&"flare_left_s")) if time != null and time.has_method(&"flare_left_s") else 0.0
		_flare_left = flare_left if flare_left > 0.0 else maxf(0.0, _flare_left - delta)


func _tick_world(delta: float) -> void:
	_lock_age += delta
	var bar_data: Dictionary = SandboxUiData.ui("hud.enemy_bar", {})
	var life: float = float(bar_data.get("show_s", 3.0)) + float(bar_data.get("fade_s", 0.5))
	for id: String in _enemy_bars.keys():
		_enemy_bars[id]["age"] = float(_enemy_bars[id]["age"]) + delta
		if float(_enemy_bars[id]["age"]) > life:
			_enemy_bars.erase(id)


# ---- input ----

func _input(event: InputEvent) -> void:
	if event is InputEventJoypadButton:
		_pad_mode = true
	elif event is InputEventKey or event is InputEventMouseButton:
		_pad_mode = false
	if not listen_input:
		return
	if SandboxPauseGate.is_start_press(event) and not SandboxPauseGate.is_held():
		open_pause()
		get_viewport().set_input_as_handled()


## Opens the pause menu (Esc / pad Start).
func open_pause() -> void:
	if _pause != null and not is_menu_open():
		_pause.open_menu()


# ---- drawing: meters (the look is SandboxStyle's) ----

func _draw_tl() -> void:
	_draw_hp()
	_draw_lights()


func _draw_tr() -> void:
	_draw_noise()
	_draw_flare()
	_draw_callouts()


func _draw_bl() -> void:
	if is_menu_open():
		return
	SandboxStyle.label(_bl, Vector2(8.0, SandboxUiData.ui_float("hud.hint_y", 211.0)), get_hint_text(), SandboxStyle.color("label_dim"))


func _draw_br() -> void:
	if is_menu_open():
		return
	var tag: Vector2 = SandboxUiData.vec("hud.camera_tag_right")
	var tag_text: String = get_camera_text().to_upper()
	SandboxStyle.label(_br, Vector2(tag.x - SandboxStyle.text_width("label", tag_text), tag.y), tag_text, SandboxStyle.color("label_dim"))


## The event lines: small, white, black shadow, sliding in from the right, then fading.
func _draw_callouts() -> void:
	var data: Dictionary = SandboxUiData.ui("hud.callouts", {})
	var at: Array = data.get("pos", [378, 96])
	var slide_s: float = float(data.get("slide_s", 0.15))
	var hold_s: float = float(data.get("hold_s", 1.4))
	var fade_s: float = float(data.get("fade_s", 0.4))
	for i: int in _callouts.size():
		var age: float = float((_callouts[i] as Dictionary)["age"])
		var slide: float = 0.0
		if age < slide_s:
			slide = floorf((1.0 - age / slide_s) * float(data.get("slide_px", 14)))
		var alpha: float = 1.0
		if age > slide_s + hold_s:
			alpha = clampf(1.0 - (age - slide_s - hold_s) / maxf(0.01, fade_s), 0.0, 1.0)
		var y: float = float(at[1]) + float(i) * float(data.get("line_step", 16))
		var tint: Color = Color(SandboxStyle.color("text"), alpha)
		SandboxStyle.text_right(_tr, "body", float(at[0]) + slide, y, str((_callouts[i] as Dictionary)["text"]), tint, 150.0)


func _draw_hp() -> void:
	var bar: Rect2 = SandboxUiData.rect("hud.hp_bar")
	var frac: float = float(_hp) / float(_hp_max)
	var low: bool = frac * 100.0 <= SandboxUiData.ui_float("hud.hp_low_pct", 25.0) and _hp > 0
	var top: Color = SandboxStyle.color("hp_low_top" if low else "hp_top")
	var bottom: Color = SandboxStyle.color("hp_low_bottom" if low else "hp_bottom")
	if low and int(_clock / 0.25) % 2 == 1:
		top = top.lerp(Color.WHITE, 0.35)
	var text_at: Vector2 = SandboxUiData.vec("hud.hp_text_pos")
	var tint: Color = SandboxStyle.color("warn") if low else SandboxStyle.color("text")
	OffsetStat.draw(_meters, text_at, SandboxUiData.text("hud.hp"), str(_hp), str(_hp_max), tint)
	SandboxStyle.thin_bar(_meters, bar, frac, top, bottom, _hp_chip / float(_hp_max))


func _draw_lights() -> void:
	var ready_to_go: bool = not _lights_active and _noise_fill >= 1.0
	var pulse: bool = int(_clock / 0.25) % 2 == 0
	var lit: bool = _lights_active or (ready_to_go and pulse)
	var glass: Color = SandboxStyle.color("lights_top")
	SandboxStyle.bulb(_meters, SandboxUiData.vec("hud.lights_icon_pos"), lit, glass)
	var key: String = "lights_on" if _lights_active else ("lights_ready" if ready_to_go else "lights_off")
	var tint: Color = glass if (_lights_active or ready_to_go) else SandboxStyle.color("label_dim")
	SandboxStyle.text(_meters, "label", SandboxUiData.vec("hud.lights_text_pos"), SandboxUiData.text("hud.%s" % key).to_upper(), tint)
	if _lights_active:
		SandboxStyle.thin_bar(_meters, SandboxUiData.rect("hud.lights_bar"), _lights_left / _lights_total, SandboxStyle.color("lights_top"), SandboxStyle.color("lights_bottom"))


func _draw_noise() -> void:
	var frame: Rect2 = SandboxUiData.rect("hud.noise_frame")
	var inner: Rect2 = SandboxStyle.metal_frame(_tr, frame)
	var top: Color = SandboxStyle.color("noise_top")
	var bottom: Color = SandboxStyle.color("noise_bottom")
	if _noise_flash_left > 0.0 and int(_noise_flash_left / SandboxUiData.ui_float("step_s", 0.0833)) % 2 == 1:
		top = _noise_flash_color.lerp(Color.WHITE, 0.4)
		bottom = _noise_flash_color
	SandboxStyle.thin_bar(_tr, inner, _noise_shown, top, bottom)
	SandboxStyle.label(_tr, SandboxUiData.vec("hud.noise_label_pos"), SandboxUiData.text("hud.noise"), SandboxStyle.color("label"))
	var points_at: Vector2 = SandboxUiData.vec("hud.noise_points_right")
	OffsetStat.draw(_tr, points_at, "", str(roundi(_noise_points)), "", SandboxStyle.color("noise_top"), true)
	var rank_at: Vector2 = SandboxUiData.vec("hud.noise_rank_right")
	var rank_text: String = _rank_name if not _rank_name.is_empty() else SandboxUiData.text("hud.rank_none")
	var rank_color: Color = SandboxPopups.rank_color(_rank_id) if not _rank_name.is_empty() else SandboxStyle.color("text_dim")
	SandboxStyle.text_right(_tr, "title", rank_at.x, rank_at.y, rank_text, rank_color, 130.0)


func _draw_flare() -> void:
	if not _flare_active:
		return
	var tag: Rect2 = SandboxUiData.rect("hud.flare_tag")
	SandboxStyle.bar(_tr, tag, SandboxStyle.color("flare_bottom").darkened(0.45), SandboxStyle.color("flare_bottom").darkened(0.7))
	SandboxStyle.bulb(_tr, tag.position + Vector2(5.0, 2.0), true, SandboxStyle.color("flare_top"))
	SandboxStyle.text(_tr, "label", tag.position + Vector2(20.0, 9.0), SandboxUiData.text("hud.flare").to_upper(), SandboxStyle.color("flare_top"))
	SandboxStyle.thin_bar(_tr, SandboxUiData.rect("hud.flare_bar"), _flare_left / _flare_total, SandboxStyle.color("flare_top"), SandboxStyle.color("flare_bottom"))


# ---- drawing: over the fighters ----

func _draw_world() -> void:
	_draw_enemy_bars()
	_draw_reticle()


func _draw_enemy_bars() -> void:
	var data: Dictionary = SandboxUiData.ui("hud.enemy_bar", {})
	var fade_s: float = float(data.get("fade_s", 0.5))
	var show_s: float = float(data.get("show_s", 3.0))
	for id: String in _enemy_bars:
		var bar: Dictionary = _enemy_bars[id]
		var at: Vector2 = position_of(id, &"head")
		if not at.is_finite():
			continue
		var alpha: float = 1.0 if float(bar["age"]) <= show_s else clampf(1.0 - (float(bar["age"]) - show_s) / maxf(0.01, fade_s), 0.0, 1.0)
		var rect: Rect2 = Rect2(Vector2(roundf(at.x - float(data.get("w", 26)) / 2.0), roundf(at.y - float(data.get("above_px", 8)))), Vector2(float(data.get("w", 26)), float(data.get("h", 3))))
		_world.draw_rect(rect.grow(1.0), Color(SandboxUiData.color("enemy_hp_back"), alpha))
		_world.draw_rect(rect, Color(SandboxUiData.color("hp_empty"), alpha))
		var fill_w: float = floorf(rect.size.x * float(bar["hp"]) / float(bar["max"]))
		_world.draw_rect(Rect2(rect.position, Vector2(maxf(1.0, fill_w), rect.size.y)), Color(SandboxUiData.color("enemy_hp"), alpha))


func _draw_reticle() -> void:
	if _lock_id.is_empty():
		return
	var at: Vector2 = position_of(_lock_id, &"center")
	if not at.is_finite():
		return
	var data: Dictionary = SandboxUiData.ui("reticle", {})
	var step_s: float = SandboxUiData.ui_float("step_s", 0.0833)
	var half: float = float(data.get("size", 22)) / 2.0
	# Snap-in: starts wide and closes in over three steps when a target is picked, then breathes.
	var snap_steps: int = 3
	var steps_alive: int = int(_lock_age / step_s)
	if steps_alive < snap_steps:
		half += float(snap_steps - steps_alive) * 4.0
	elif int(_clock / (step_s * float(data.get("pulse_steps", 3)))) % 2 == 1:
		half += 1.0
	var corner: float = float(data.get("corner", 5))
	var center: Vector2 = Vector2(roundf(at.x), roundf(at.y))
	var ink: Color = SandboxStyle.color("shadow")
	var amber: Color = SandboxUiData.color("reticle")
	var glow: Color = SandboxUiData.color("reticle_glow")
	for sx: int in [-1, 1]:
		for sy: int in [-1, 1]:
			var corner_pos: Vector2 = center + Vector2(half * float(sx), half * float(sy))
			_draw_corner(corner_pos, Vector2(float(-sx), float(-sy)), corner, ink, amber)
	_world.draw_rect(Rect2(center - Vector2(1, 1), Vector2(2, 2)), ink)
	_world.draw_rect(Rect2(center, Vector2(1, 1)), glow)


## One L-shaped bracket whose elbow is at `elbow` and whose legs run toward `inward`.
func _draw_corner(elbow: Vector2, inward: Vector2, length: float, ink: Color, color: Color) -> void:
	var horizontal: Rect2 = Rect2(Vector2(minf(elbow.x, elbow.x + inward.x * length), elbow.y - (0.0 if inward.y > 0.0 else 1.0)), Vector2(length, 2.0 if false else 1.0))
	var vertical: Rect2 = Rect2(Vector2(elbow.x - (0.0 if inward.x > 0.0 else 1.0), minf(elbow.y, elbow.y + inward.y * length)), Vector2(1.0, length))
	_world.draw_rect(horizontal.grow(1.0), ink)
	_world.draw_rect(vertical.grow(1.0), ink)
	_world.draw_rect(horizontal, color)
	_world.draw_rect(vertical, color)
