class_name QuietHoursFx
extends ColorRect
## The Quiet Hours screen-edge fizz (B10; docs/slice/boss_design.md: "the dish lowers and hums, screen edges fizz").
## A full-screen ColorRect with shaders/quiet_hours_edge.gdshader, laid over the HUD while the dish warns. It is only the
## picture: the HUD tells it how strong to be (`set_level`, 0 = off, 1 = full) from the warning's progress, and it eases
## up and down so the fizz never pops on or off. The static is stepped (re-rolled every `step_s`), pale cyan and navy
## like the hack panel's own static, and thins out toward the middle of the screen so the fight stays readable.
## Graybox pass by the UI Programmer; the Technical Artist owns the final look (see the tech plan's Changes section).
## Numbers: data/ui/slice_ui.json "quiet_fx". Everything per frame is in tick(delta) so a test can step it by hand.

const SHADER_PATH: String = "res://shaders/quiet_hours_edge.gdshader"

var _target: float = 0.0
var _shown: float = 0.0
var _clock: float = 0.0
var _material: ShaderMaterial = null


func _init() -> void:
	name = "QuietHoursFx"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	color = Color(1, 1, 1, 1)
	visible = false
	if ResourceLoader.exists(SHADER_PATH):
		_material = ShaderMaterial.new()
		_material.shader = load(SHADER_PATH) as Shader
		material = _material


## How strong the fizz should be (0 to 1). The real strength eases toward it.
func set_level(level: float) -> void:
	_target = clampf(level, 0.0, 1.0)


func target_level() -> float:
	return _target


## The strength on screen right now.
func shown_level() -> float:
	return _shown


func is_showing() -> bool:
	return visible


func tick(delta: float) -> void:
	_clock += delta
	var rise: float = maxf(0.01, SliceUiData.num("quiet_fx.rise_s", 0.15))
	var fall: float = maxf(0.01, SliceUiData.num("quiet_fx.fall_s", 0.3))
	if _shown < _target:
		_shown = minf(_target, _shown + delta / rise)
	elif _shown > _target:
		_shown = maxf(_target, _shown - delta / fall)
	visible = _shown > 0.001
	if not visible or _material == null:
		return
	var px: float = maxf(1.0, SliceUiData.num("quiet_fx.px", 2))
	_material.set_shader_parameter(&"level", _shown)
	_material.set_shader_parameter(&"step_index", float(int(_clock / maxf(0.01, SliceUiData.num("quiet_fx.step_s", 0.0833)))))
	_material.set_shader_parameter(&"cells", Vector2(maxf(1.0, floorf(size.x / px)), maxf(1.0, floorf(size.y / px))))
	_material.set_shader_parameter(&"band_cells", SliceUiData.num("quiet_fx.band_cells", 9))
	_material.set_shader_parameter(&"density", SliceUiData.num("quiet_fx.density", 0.55))
	_material.set_shader_parameter(&"alpha", SliceUiData.num("quiet_fx.alpha", 0.5))
	_material.set_shader_parameter(&"light", SliceUiData.color("fizz_light"))
	_material.set_shader_parameter(&"dark", SliceUiData.color("fizz_dark"))
