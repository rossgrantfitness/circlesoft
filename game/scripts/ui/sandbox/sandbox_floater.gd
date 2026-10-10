class_name SandboxFloater
extends Control
## One damage number floating up over a fighter: small, crisp, in the sandbox UI's numeral font, with
## the black drop shadow, rising a few pixels and fading. Sandbox-only (the battle HUD's BattlePopup is
## untouched). The HUD owns the clock and calls tick(delta). Timing and rise: data/ui/sandbox_ui.json "hud.floater".

signal finished(floater: SandboxFloater)

var text: String = ""
var tint: Color = Color.WHITE
## The fighter this number belongs to (so numbers on one fighter can stack).
var target: String = ""
var age: float = 0.0

var _done: bool = false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	size = Vector2.ZERO


func life_s() -> float:
	return SandboxUiData.ui_float("hud.floater.life_s", 0.9)


func tick(delta: float) -> void:
	if _done:
		return
	age += delta
	if age >= life_s():
		_done = true
		finished.emit(self)
	queue_redraw()


func is_done() -> bool:
	return _done


## 0 at the start, 1 at the end.
func progress() -> float:
	return clampf(age / maxf(0.01, life_s()), 0.0, 1.0)


## Whole pixels risen so far (it rises fast, then hangs).
func rise_px() -> float:
	return floorf(SandboxUiData.ui_float("hud.floater.rise_px", 12.0) * minf(1.0, progress() * 2.0))


func alpha() -> float:
	var fade_from: float = SandboxUiData.ui_float("hud.floater.fade_from", 0.6)
	if progress() <= fade_from:
		return 1.0
	return clampf(1.0 - (progress() - fade_from) / maxf(0.01, 1.0 - fade_from), 0.0, 1.0)


func _draw() -> void:
	var paint: Color = Color(tint, alpha())
	SandboxStyle.text_center(self, "stat_big", -40.0, -rise_px(), text, paint, 80.0)
