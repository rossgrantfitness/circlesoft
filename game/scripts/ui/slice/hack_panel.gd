class_name HackPanel
extends Control
## The battery readout (VS-11, plan 4.6), top-left under Red's health: the battery as a thin gradient bar with a tick
## at each hack's cost and the charge in big numbers, the Quiet Hours static ("Jammed" and a countdown over a crackling
## bar), a shake when a cast is refused, and the hijack timer ("Link") when Overclock holds something. The hack list
## itself is the CommandDeck (bottom-left). HackPanelModel holds the numbers; the HUD feeds it from the director.

var model: HackPanelModel = HackPanelModel.new()

var _clock: float = 0.0
var _chip: float = 0.0
var _chip_wait: float = 0.0
var _last_charge: float = -1.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_chip = model.fill()


func tick(delta: float) -> void:
	_clock += delta
	model.tick(delta)
	if _last_charge < 0.0:
		_last_charge = model.charge
		_chip = model.fill()
	if model.charge < _last_charge - 0.01:
		_chip = maxf(_chip, _last_charge / model.capacity)
		_chip_wait = 0.3
	_last_charge = model.charge
	if _chip_wait > 0.0:
		_chip_wait -= delta
	elif _chip > model.fill():
		_chip = maxf(model.fill(), _chip - SliceUiData.num("hack_panel.chip_per_s", 1.4) * delta)
	else:
		_chip = model.fill()
	queue_redraw()


## Where the stack's top-left is (the panel's anchor in the UI).
func origin() -> Vector2:
	return Vector2(SliceUiData.num("hack_panel.x", 8), SliceUiData.num("hack_panel.y", 54))


func panel_width() -> float:
	return SliceUiData.num("hack_panel.w", 128)


func _draw() -> void:
	if model.order.is_empty():
		return
	_draw_battery(_shake_x())
	var end_y: float = origin().y + SliceUiData.num("hack_panel.label_gap", 9) + SliceUiData.num("hack_panel.battery_h", 4) + SliceUiData.num("hack_panel.hijack_y_gap", 4)
	_draw_hijack(end_y)
	if model.is_locked():
		_draw_fizz(origin().y + SliceUiData.num("hack_panel.label_gap", 9) + SliceUiData.num("hack_panel.battery_h", 4) + 1.0)


func _shake_x() -> float:
	if model.denied_id().is_empty():
		return 0.0
	var px: float = SliceUiData.num("hack_panel.denied_shake_px", 2)
	return (px if int(_clock / 0.04) % 2 == 0 else -px) * model.denied_frac()


# ---- the battery ----

func _draw_battery(shake: float) -> void:
	var at: Vector2 = origin()
	var locked: bool = model.is_locked()
	var number_right: float = at.x + panel_width()
	if locked:
		SandboxStyle.label(self, at + Vector2(shake, 7.0), SliceUiData.text("hack.jammed"), SliceUiData.color("jam"))
		SandboxStyle.text_right(self, "label", number_right, at.y + 7.0, SliceUiData.fmt("hack.jammed_time", {"seconds": "%.1f" % model.lock_left_s()}).to_upper(), SliceUiData.color("jam"), 50.0)
	else:
		SandboxStyle.label(self, at + Vector2(shake, 7.0), SliceUiData.text("hack.battery"), SandboxStyle.color("label"))
		OffsetStat.draw(self, Vector2(number_right, at.y + 8.0), "", str(roundi(model.charge)), "", SandboxStyle.color("text"), true)
	var bar: Rect2 = Rect2(at.x + shake, at.y + SliceUiData.num("hack_panel.label_gap", 9), panel_width(), SliceUiData.num("hack_panel.battery_h", 4))
	var top: Color = SliceUiData.color("battery_locked_top" if locked else "battery_top")
	var bottom: Color = SliceUiData.color("battery_locked_bottom" if locked else "battery_bottom")
	SandboxStyle.thin_bar(self, bar, model.fill(), top, bottom, _chip if not locked else -1.0)
	var tick_color: Color = SliceUiData.color("tick")
	for entry: Dictionary in model.cost_ticks():
		if bool(entry["all"]):
			continue
		var x: float = bar.position.x + floorf(bar.size.x * float(entry["frac"])) - 1.0
		self.draw_rect(Rect2(x, bar.position.y - 1.0, 1.0, bar.size.y + 2.0), tick_color)


# ---- the hijack timer ----

func _draw_hijack(y: float) -> void:
	var id: String = model.longest_hijack()
	if id.is_empty():
		return
	var at: Vector2 = origin()
	SandboxStyle.label(self, Vector2(at.x, y + 6.0), SliceUiData.text("hack.link"), SliceUiData.color("hijack"))
	SandboxStyle.text_right(self, "label", at.x + panel_width(), y + 6.0, "%.1f" % model.hijack_left_s(id), SandboxStyle.color("text"), 40.0)
	var bar: Rect2 = Rect2(at.x, y + 9.0, panel_width(), SliceUiData.num("hack_panel.hijack_bar_h", 3))
	SandboxStyle.thin_bar(self, bar, model.hijack_frac(id), SliceUiData.color("hijack"), SliceUiData.color("hijack").darkened(0.45))


# ---- Quiet Hours static ----

## Crackling pixels over the whole block, re-rolled every step. Deterministic per step (no random state).
func _draw_fizz(end_y: float) -> void:
	var at: Vector2 = origin()
	var px: float = SliceUiData.num("hack_panel.fizz_px", 2)
	var step: int = int(_clock / SliceUiData.num("hack_panel.fizz_step_s", 0.0833))
	var density: float = SliceUiData.num("hack_panel.fizz_density", 0.38)
	var light: Color = SliceUiData.color("fizz_light")
	var dark: Color = SliceUiData.color("fizz_dark")
	var top_y: float = at.y + SliceUiData.num("hack_panel.label_gap", 9) - 1.0
	var cols: int = int(panel_width() / px)
	var rows: int = int((end_y - top_y) / px)
	for row: int in rows:
		for col: int in cols:
			var h: int = _hash(col, row, step)
			if float(h % 1000) / 1000.0 < density * 0.5:
				draw_rect(Rect2(at.x + float(col) * px, top_y + float(row) * px, px, px), Color(light, 0.55))
			elif float(h % 1000) / 1000.0 > 1.0 - density * 0.5:
				draw_rect(Rect2(at.x + float(col) * px, top_y + float(row) * px, px, px), Color(dark, 0.6))


static func _hash(a: int, b: int, c: int) -> int:
	var h: int = (a * 73856093) ^ (b * 19349663) ^ (c * 83492791)
	return absi(h)
