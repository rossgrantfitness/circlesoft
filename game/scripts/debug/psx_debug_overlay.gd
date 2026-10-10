class_name PsxDebugOverlay
extends Control
## The PSX options overlay for playtests. Lives on the sharp UI layer.
##   F1  show / hide this panel (a one-line hint shows while it is hidden)
##   F2  vertex jitter      F3  affine warp      F4  dither
##   F5  15-bit color       F6  fog              F7  vertex lighting
##   F8  cycle the internal resolution
##   F9  cycle the camera: perspective FOV 30, FOV 45, orthographic
##   F11 cycle the look profile: auto (each scene's own), classic, grim (data/world/look_profiles.json)
## Effects go through PsxLook, the resolution through the PsxScreen (group "psx_screen") and the
## camera through the room's DioramaCamera (group "diorama_camera"). Keys are the input-map
## actions debug_overlay, debug_jitter, ... so they can be rebound in project.godot.

const ACTION_TOGGLE_PANEL: StringName = &"debug_overlay"
const ACTION_RESOLUTION: StringName = &"debug_resolution"
const ACTION_CAMERA: StringName = &"debug_camera_mode"
const ACTION_LOOK: StringName = &"debug_look_profile"
const FOV_OPTIONS_PATH: String = "camera.debug_fov_options"
const TUNING_ID: String = "world/field_tuning"
const HINT_TEXT: String = "F1: PSX options"
const FONT_SIZE: int = 18
const PANEL_MARGIN: int = 12
const PANEL_PADDING: int = 10
const PANEL_COLOR: Color = Color(0.06, 0.05, 0.1, 0.78)
const TEXT_COLOR: Color = Color(0.93, 0.92, 0.85)
const HINT_COLOR: Color = Color(0.93, 0.92, 0.85, 0.7)
const OUTLINE_COLOR: Color = Color(0.06, 0.05, 0.1)
const OUTLINE_SIZE: int = 4

## Action name -> the effect it flips, in the order shown on screen.
const EFFECT_ACTIONS: Array[Dictionary] = [
	{"action": &"debug_jitter", "effect": PsxLook.Effect.JITTER, "key": "F2"},
	{"action": &"debug_warp", "effect": PsxLook.Effect.WARP, "key": "F3"},
	{"action": &"debug_dither", "effect": PsxLook.Effect.DITHER, "key": "F4"},
	{"action": &"debug_color_depth", "effect": PsxLook.Effect.COLOR_DEPTH, "key": "F5"},
	{"action": &"debug_fog", "effect": PsxLook.Effect.FOG, "key": "F6"},
	{"action": &"debug_vertex_lighting", "effect": PsxLook.Effect.VERTEX_LIGHTING, "key": "F7"},
]

var _panel: PanelContainer = null
var _panel_label: Label = null
var _hint: Label = null


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build()
	set_panel_visible(false)


func _process(_delta: float) -> void:
	if is_panel_visible():
		_panel_label.text = build_text()


func _input(event: InputEvent) -> void:
	if event.is_echo() or not event.is_pressed():
		return
	if event.is_action_pressed(ACTION_TOGGLE_PANEL):
		set_panel_visible(not is_panel_visible())
		return
	if event.is_action_pressed(ACTION_RESOLUTION):
		cycle_resolution()
		return
	if event.is_action_pressed(ACTION_CAMERA):
		cycle_camera_mode()
		return
	if event.is_action_pressed(ACTION_LOOK):
		cycle_look_profile()
		return
	for entry: Dictionary in EFFECT_ACTIONS:
		if event.is_action_pressed(entry["action"]):
			toggle_effect(entry["effect"])
			return


# ---- actions (also called by tests) ----

func is_panel_visible() -> bool:
	return _panel != null and _panel.visible


func set_panel_visible(shown: bool) -> void:
	_panel.visible = shown
	_hint.visible = not shown
	if shown:
		_panel_label.text = build_text()


func toggle_effect(effect: PsxLook.Effect) -> bool:
	var now_on: bool = PsxLook.toggle_effect(effect)
	if is_panel_visible():
		_panel_label.text = build_text()
	return now_on


## Moves to the next internal resolution. Returns it (zero if there is no PSX screen).
func cycle_resolution() -> Vector2i:
	var screen: PsxScreen = _find_screen()
	if screen == null:
		return Vector2i.ZERO
	return screen.cycle_resolution()


## Perspective at each FOV in the data list, then orthographic, then around again.
## Returns a short name for the new camera.
func cycle_camera_mode() -> String:
	var rig: DioramaCamera = _find_camera()
	if rig == null:
		return ""
	var fovs: Array[float] = _fov_options()
	if rig.get_projection_mode() == DioramaCamera.ProjectionMode.ORTHOGRAPHIC:
		rig.set_projection_mode(DioramaCamera.ProjectionMode.PERSPECTIVE)
		rig.set_fov_deg(fovs[0])
	else:
		var index: int = _closest_index(fovs, rig.fov_deg)
		if index + 1 < fovs.size():
			rig.set_fov_deg(fovs[index + 1])
		else:
			rig.set_projection_mode(DioramaCamera.ProjectionMode.ORTHOGRAPHIC)
	if is_panel_visible():
		_panel_label.text = build_text()
	return camera_description(rig)


## Look profile switch: auto (the scene's own) -> classic -> grim -> auto. Returns the forced id ("" = auto).
func cycle_look_profile() -> String:
	var forced: String = LookProfiles.cycle_forced()
	if is_panel_visible():
		_panel_label.text = build_text()
	return forced


static func look_description() -> String:
	var forced: String = LookProfiles.forced_id()
	var shown: String = LookProfiles.name_of(LookProfiles.active_id())
	if forced.is_empty():
		return "auto (this scene: %s)" % shown
	return "%s (forced)" % shown


## What the panel says right now.
func build_text() -> String:
	var lines: Array[String] = []
	lines.append("PSX OPTIONS   (F1 hides)")
	var screen: PsxScreen = _find_screen()
	if screen != null:
		var size: Vector2i = screen.get_resolution()
		lines.append("F8  Resolution: %dx%d" % [size.x, size.y])
	for entry: Dictionary in EFFECT_ACTIONS:
		var effect: PsxLook.Effect = entry["effect"]
		var line: String = "%s  %s: %s" % [entry["key"], PsxLook.EFFECT_NAMES[effect], "ON" if PsxLook.is_effect_on(effect) else "off"]
		if effect == PsxLook.Effect.DITHER:
			line += "   (needs 15-bit color ON)"
		lines.append(line)
	var rig: DioramaCamera = _find_camera()
	if rig != null:
		lines.append("F9  Camera: %s" % camera_description(rig))
	lines.append("F11 Look: %s" % look_description())
	lines.append("Esc: back to title")
	return "\n".join(lines)


static func camera_description(rig: DioramaCamera) -> String:
	if rig.get_projection_mode() == DioramaCamera.ProjectionMode.ORTHOGRAPHIC:
		return "orthographic"
	return "perspective, FOV %d" % int(round(rig.fov_deg))


# ---- internals ----

func _build() -> void:
	_panel = PanelContainer.new()
	_panel.position = Vector2(PANEL_MARGIN, PANEL_MARGIN)
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = PANEL_COLOR
	style.set_content_margin_all(PANEL_PADDING)
	_panel.add_theme_stylebox_override("panel", style)
	_panel_label = _make_label(TEXT_COLOR)
	_panel.add_child(_panel_label)
	add_child(_panel)
	_hint = _make_label(HINT_COLOR)
	_hint.text = HINT_TEXT
	_hint.position = Vector2(PANEL_MARGIN, PANEL_MARGIN)
	add_child(_hint)


func _make_label(color: Color) -> Label:
	var label: Label = Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", FONT_SIZE)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", OUTLINE_COLOR)
	label.add_theme_constant_override("outline_size", OUTLINE_SIZE)
	return label


func _find_screen() -> PsxScreen:
	if not is_inside_tree():
		return null
	return get_tree().get_first_node_in_group(PsxScreen.GROUP_NAME) as PsxScreen


func _find_camera() -> DioramaCamera:
	if not is_inside_tree():
		return null
	return get_tree().get_first_node_in_group(DioramaCamera.GROUP_NAME) as DioramaCamera


func _fov_options() -> Array[float]:
	var options: Array[float] = []
	var raw: Variant = DataDB.get_value(TUNING_ID, FOV_OPTIONS_PATH, [])
	for value: Variant in raw:
		options.append(float(value))
	if options.is_empty():
		push_error("PsxDebugOverlay: no camera.debug_fov_options in data/world/field_tuning.json")
		var rig: DioramaCamera = _find_camera()
		options.append(rig.fov_deg if rig != null else 0.0)
	return options


static func _closest_index(values: Array[float], wanted: float) -> int:
	var best: int = 0
	for i: int in values.size():
		if absf(values[i] - wanted) < absf(values[best] - wanted):
			best = i
	return best
