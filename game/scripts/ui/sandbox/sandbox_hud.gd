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
var _popups: Array[BattlePopup] = []

var _meters: Control = null
var _world: Control = null
var _popup_layer: Control = null
var _panel: FeelPanel = null
var _pause: SandboxPause = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	size = Vector2(UiStage.STAGE_SIZE)
	set_process(not manual_ticks)
	_build()


func _process(delta: float) -> void:
	tick(delta)


func _exit_tree() -> void:
	unbind()


func _build() -> void:
	_meters = Control.new()
	_meters.name = "Meters"
	_meters.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_meters.size = size
	_meters.draw.connect(_draw_meters)
	add_child(_meters)
	_world = Control.new()
	_world.name = "World"
	_world.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_world.size = size
	_world.draw.connect(_draw_world)
	add_child(_world)
	_popup_layer = Control.new()
	_popup_layer.name = "Popups"
	_popup_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_popup_layer.size = size
	add_child(_popup_layer)
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


func get_popups() -> Array[BattlePopup]:
	return _popups


func get_camera_text() -> String:
	return SandboxUiData.text("hud.camera_diorama" if _camera_diorama else "hud.camera_orbit")


func get_hint_text() -> String:
	return SandboxUiData.text("hud.hint_pad" if _pad_mode else "hud.hint_keys")


## True while any sandbox menu (pause, controls, feel panel) is up.
func is_menu_open() -> bool:
	return _pause.is_open() or _panel.is_open()


# ---- positions ----

## Picture pixels -> stage pixels. The 3D picture is the PsxScreen's resolution when one is running.
func world_scale() -> Vector2:
	var world: Vector2 = SandboxUiData.vec("world_size")
	var screen: Node = get_tree().get_first_node_in_group(UiStage.SCREEN_GROUP) if is_inside_tree() else null
	if screen is PsxScreen:
		world = Vector2((screen as PsxScreen).get_resolution())
	if world.x <= 0.0 or world.y <= 0.0:
		return Vector2.ONE
	return Vector2(UiStage.STAGE_SIZE) / world


## Where a fighter's anchor is on the stage, or NO_POSITION when the sandbox can't say.
func position_of(actor_id: String, point: StringName = &"head") -> Vector2:
	if sandbox == null or not sandbox.has_method(POS_METHOD):
		return NO_POSITION
	var at: Vector2 = sandbox.call(POS_METHOD, StringName(actor_id), point)
	if at == Vector2.ZERO:
		return NO_POSITION
	return at * world_scale()


## A world point on the stage (for hits that come with a Vector3), or NO_POSITION.
func project_world(point: Vector3) -> Vector2:
	var cam: Camera3D = _call(_camera, &"get_camera") as Camera3D
	if cam == null or cam.is_position_behind(point):
		return NO_POSITION
	var viewport_size: Vector2 = cam.get_viewport().get_visible_rect().size
	if viewport_size.x <= 0.0:
		return NO_POSITION
	return cam.unproject_position(point) * (Vector2(UiStage.STAGE_SIZE) / viewport_size)


func _fallback_position() -> Vector2:
	return Vector2(UiStage.STAGE_SIZE) * 0.5


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
	var color: Color = Color(0, 0, 0, 0)
	if target == _red_id:
		color = SandboxUiData.color("red_damage")
	elif outcome == "armored":
		color = SandboxUiData.color("armored")
	var popup: BattlePopup = SandboxPopups.damage(damage, color)
	var stack: int = mini(_number_popups_on(target), SandboxUiData.ui_int("hud.damage_stack_max", 4))
	var lift: float = float(SandboxUiData.ui_int("hud.damage_popup_lift_px", 4) + stack * SandboxUiData.ui_int("hud.damage_stack_px", 9))
	var sway: float = float((_popup_serial % 3) - 1) * 6.0
	_spawn(popup, at + Vector2(sway, -lift), target)


func _number_popups_on(target: String) -> int:
	var count: int = 0
	for popup: BattlePopup in _popups:
		if popup.kind == BattlePopup.Kind.NUMBER and str(popup.get_meta(&"target", "")) == target:
			count += 1
	return count


func _on_parry_judged(info: Dictionary) -> void:
	var popup: BattlePopup = SandboxPopups.parry(str(info.get("rating", "miss")))
	if popup == null:
		return
	_spawn(popup, _over_red(SandboxUiData.ui_int("hud.parry_popup_lift_px", 14)), _red_id)


func _on_perfect_dodge(_info: Dictionary) -> void:
	_spawn(SandboxPopups.lamp_flare(), _over_red(SandboxUiData.ui_int("hud.flare_popup_lift_px", 30)), _red_id)


func _on_flare_started(info: Dictionary) -> void:
	_flare_active = true
	_flare_total = maxf(0.01, float(info.get("duration_s", 0.0)))
	_flare_left = _flare_total
	if str(info.get("source", "")) == "parry":
		_spawn(SandboxPopups.lamp_flare(), _over_red(SandboxUiData.ui_int("hud.flare_popup_lift_px", 30)), _red_id)


func _on_flare_ended() -> void:
	_flare_active = false
	_flare_left = 0.0


func _on_stagger(info: Dictionary) -> void:
	var popup: BattlePopup = SandboxPopups.stagger(str(info.get("by", "poise")))
	if popup == null:
		return
	var target: String = str(info.get("target", ""))
	var at: Vector2 = position_of(target, &"head")
	if not at.is_finite():
		at = _fallback_position()
	_spawn(popup, at + Vector2(0, -SandboxUiData.ui_int("hud.damage_popup_lift_px", 4) - 12), target)


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
		_spawn(SandboxPopups.rank(_rank_id, rank_name), SandboxUiData.vec("hud.rank_popup_pos"), "")
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


## Drops pop-ups, enemy bars, the reticle and the meters' leftovers (a reset starts a fresh fight).
func _clear_transients() -> void:
	for popup: BattlePopup in _popups:
		popup.queue_free()
	_popups.clear()
	_enemy_bars.clear()
	_lock_id = ""
	_flare_active = false
	_lights_active = false


# ---- pop-ups ----

var _popup_serial: int = 0


func _over_red(lift: int) -> Vector2:
	var at: Vector2 = position_of(_red_id, &"head")
	if not at.is_finite():
		at = _fallback_position()
	return at - Vector2(0, float(lift))


func _spawn(popup: BattlePopup, at: Vector2, target: String) -> void:
	if popup == null:
		return
	_popup_serial += 1
	popup.set_meta(&"target", target)
	var margin: float = clampf(popup.measure_width() / 2.0 + 4.0, 20.0, 120.0)
	popup.position = Vector2(clampf(at.x, margin, float(UiStage.STAGE_SIZE.x) - margin), clampf(at.y, 24.0, float(UiStage.STAGE_SIZE.y) - 24.0))
	popup.finished.connect(_on_popup_finished)
	_popup_layer.add_child(popup)
	_popups.append(popup)
	var cap: int = SandboxUiData.ui_int("hud.max_popups", 24)
	while _popups.size() > cap:
		var oldest: BattlePopup = _popups.pop_front()
		oldest.queue_free()


func _on_popup_finished(popup: BattlePopup) -> void:
	_popups.erase(popup)
	popup.queue_free()


# ---- time ----

func tick(delta: float) -> void:
	_clock += delta
	for popup: BattlePopup in _popups.duplicate():
		if is_instance_valid(popup):
			popup.tick(delta)
	_tick_hp(delta)
	_tick_noise(delta)
	_tick_lights_and_flare(delta)
	_tick_world(delta)
	_meters.queue_redraw()
	_world.queue_redraw()


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

func _draw_meters() -> void:
	_draw_hp()
	_draw_lights()
	_draw_noise()
	_draw_flare()
	if is_menu_open():
		return
	var hint_y: float = SandboxUiData.ui_float("hud.hint_y", 211.0)
	SandboxStyle.label(_meters, Vector2(8.0, hint_y), get_hint_text(), SandboxStyle.color("label_dim"))
	var tag: Vector2 = SandboxUiData.vec("hud.camera_tag_right")
	var tag_text: String = get_camera_text().to_upper()
	SandboxStyle.label(_meters, Vector2(tag.x - SandboxStyle.text_width("label", tag_text), tag.y), tag_text, SandboxStyle.color("label_dim"))


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
	SandboxStyle.text(_meters, "body", text_at, "%s %d/%d" % [SandboxUiData.text("hud.hp"), _hp, _hp_max], tint)
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
	var inner: Rect2 = SandboxStyle.metal_frame(_meters, frame)
	var top: Color = SandboxStyle.color("noise_top")
	var bottom: Color = SandboxStyle.color("noise_bottom")
	if _noise_flash_left > 0.0 and int(_noise_flash_left / SandboxUiData.ui_float("step_s", 0.0833)) % 2 == 1:
		top = _noise_flash_color.lerp(Color.WHITE, 0.4)
		bottom = _noise_flash_color
	SandboxStyle.thin_bar(_meters, inner, _noise_shown, top, bottom)
	SandboxStyle.label(_meters, SandboxUiData.vec("hud.noise_label_pos"), SandboxUiData.text("hud.noise"), SandboxStyle.color("label"))
	var points_at: Vector2 = SandboxUiData.vec("hud.noise_points_right")
	SandboxStyle.text_right(_meters, "body", points_at.x, points_at.y, str(roundi(_noise_points)), SandboxStyle.color("noise_top"), 80.0)
	var rank_at: Vector2 = SandboxUiData.vec("hud.noise_rank_right")
	var rank_text: String = _rank_name if not _rank_name.is_empty() else SandboxUiData.text("hud.rank_none")
	var rank_color: Color = SandboxPopups.rank_color(_rank_id) if not _rank_name.is_empty() else SandboxStyle.color("text_dim")
	SandboxStyle.text_right(_meters, "title", rank_at.x, rank_at.y, rank_text, rank_color, 130.0)


func _draw_flare() -> void:
	if not _flare_active:
		return
	var tag: Rect2 = SandboxUiData.rect("hud.flare_tag")
	SandboxStyle.bar(_meters, tag, SandboxStyle.color("flare_bottom").darkened(0.45), SandboxStyle.color("flare_bottom").darkened(0.7))
	SandboxStyle.bulb(_meters, tag.position + Vector2(5.0, 2.0), true, SandboxStyle.color("flare_top"))
	SandboxStyle.text(_meters, "label", tag.position + Vector2(20.0, 9.0), SandboxUiData.text("hud.flare").to_upper(), SandboxStyle.color("flare_top"))
	SandboxStyle.thin_bar(_meters, SandboxUiData.rect("hud.flare_bar"), _flare_left / _flare_total, SandboxStyle.color("flare_top"), SandboxStyle.color("flare_bottom"))


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
