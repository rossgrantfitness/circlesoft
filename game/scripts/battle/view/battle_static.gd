class_name BattleStatic
extends CanvasLayer
## The radio-static screen transition. A full-screen ColorRect with screen_static.gdshader; `cover()` brings
## the static in (the field picture is lost to noise), `reveal()` clears it (the battle appears). Both are
## awaitable. Boss fights use the longer version. Lives inside the 3D world's viewport, so the noise pixels are
## internal-resolution pixels. Every value comes from data/battle_stage/stage.json ("static").

signal covered
signal revealed

const SHADER_PATH: String = "res://shaders/screen_static.gdshader"
const LAYER_ORDER: int = 100
const PARAM_PROGRESS: StringName = &"progress"
const PARAM_BOSS: StringName = &"boss"
const PARAM_TIME: StringName = &"time_s"
const NO_STEPS: int = 1

var progress: float = 0.0
var is_boss: bool = false

var _rect: ColorRect = null
var _material: ShaderMaterial = null
var _tuning: BattleStageTuning = null
var _tween: Tween = null
var _clock_s: float = 0.0
var _steps: int = 8
var _frame_hz: float = 24.0


func _init() -> void:
	layer = LAYER_ORDER
	_rect = ColorRect.new()
	_rect.name = "Static"
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_material = ShaderMaterial.new()
	_material.shader = load(SHADER_PATH) as Shader
	_rect.material = _material
	_rect.visible = false
	add_child(_rect)


func _process(delta: float) -> void:
	if not _rect.visible:
		return
	_clock_s += delta
	_material.set_shader_parameter(PARAM_TIME, _clock_s)
	var size: Vector2 = get_viewport().get_visible_rect().size if is_inside_tree() else Vector2(384, 216)
	_material.set_shader_parameter(&"pixel_grid", size)


## Reads colors, steps and timing from the stage tuning. Call once after creating.
func configure(tuning: BattleStageTuning) -> void:
	_tuning = tuning
	_steps = maxi(tuning.integer("static.steps"), NO_STEPS)
	_frame_hz = tuning.number("static.frame_hz")
	_material.set_shader_parameter(&"frame_hz", _frame_hz)
	_material.set_shader_parameter(&"band_rows", tuning.number("static.band_rows"))
	_material.set_shader_parameter(&"block_px", tuning.vec2("static.block_px"))
	_material.set_shader_parameter(&"dark", tuning.color("static.dark"))
	_material.set_shader_parameter(&"mid", tuning.color("static.mid"))
	_material.set_shader_parameter(&"light", tuning.color("static.light"))
	_material.set_shader_parameter(&"tint", tuning.color("static.tint"))
	_material.set_shader_parameter(&"tint_amount", tuning.number("static.tint_amount"))


func set_boss(value: bool) -> void:
	is_boss = value
	_material.set_shader_parameter(PARAM_BOSS, 1.0 if (value and _flicker_on()) else 0.0)


func get_static_material() -> ShaderMaterial:
	return _material


## The planned length in milliseconds of a cover or reveal (longer for bosses).
func duration_ms(covering: bool) -> float:
	if _tuning == null:
		return 0.0
	var key: String = "static.%s%s" % ["boss_" if is_boss else "", "in_ms" if covering else "out_ms"]
	return _tuning.number(key)


func hold_ms() -> float:
	if _tuning == null:
		return 0.0
	return _tuning.number("static.boss_hold_ms" if is_boss else "static.hold_ms")


## Sets the coverage right now (0 clear, 1 full), snapped to the stepped levels.
func set_progress(value: float) -> void:
	var stepped: float = clampf(floorf(value * float(_steps) + 0.5) / float(_steps), 0.0, 1.0)
	progress = stepped
	_material.set_shader_parameter(PARAM_PROGRESS, stepped)
	_rect.visible = stepped > 0.0


## Static in: clear -> covered over `ms` (default from the data). Emits `covered`; awaitable.
func cover(ms: float = -1.0) -> void:
	await _run(0.0, 1.0, duration_ms(true) if ms < 0.0 else ms)
	covered.emit()


## Static out: covered -> clear. Emits `revealed`; awaitable.
func reveal(ms: float = -1.0) -> void:
	await _run(1.0, 0.0, duration_ms(false) if ms < 0.0 else ms)
	revealed.emit()


## True while a cover or reveal is running.
func is_running() -> bool:
	return _tween != null and _tween.is_valid() and _tween.is_running()


func _run(from_value: float, to_value: float, ms: float) -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	set_progress(from_value)
	if ms <= 0.0 or not is_inside_tree():
		set_progress(to_value)
		return
	_tween = create_tween()
	_tween.tween_method(set_progress, from_value, to_value, ms / 1000.0)
	await _tween.finished
	set_progress(to_value)


func _flicker_on() -> bool:
	return _tuning != null and _tuning.flag("static.boss_flicker")
