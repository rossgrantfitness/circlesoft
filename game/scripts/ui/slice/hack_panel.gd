class_name HackPanel
extends Control
## The hack panel (VS-11, plan 4.6): the battery as a thin gradient bar with a tick at each hack's cost, the hack
## list under it, the Quiet Hours static, and the hijack timer. A shortcut-list idea in our own dress: slim navy
## bars in a slightly offset stack, the picked hack's bar tall and bright with the orange cursor and cyan
## left / right arrows, the others small and dim.
##
## Pick mode (Decision 1, option A): the whole list shows, the picked hack lit, "<" and ">" beside it.
## Automatic mode (option C): one bar says "Auto" and shows the last hack used.
## A hack the battery can't pay for is greyed; a cast on cooldown shows a dark sweep shrinking across its bar;
## while Quiet Hours locks hacks the bar goes grey, static crackles over the whole block and "Signal jammed"
## counts down; a refused cast shakes the bar. A hijack in progress shows a draining "Link" timer under the list.
## It draws; HackPanelModel holds the numbers and the HUD feeds the model from the director's signals.

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
	return SliceUiData.num("hack_panel.w", 112)


## The bar rect of each hack row, in pick mode, from the top (for tests and the screenshots).
func row_rects() -> Dictionary:
	var out: Dictionary = {}
	var at: Vector2 = origin()
	var y: float = at.y + SliceUiData.num("hack_panel.list_y", 12)
	var step: float = SliceUiData.num("hack_panel.row_step", 12)
	var inset: float = SliceUiData.num("hack_panel.list_inset", 3)
	var lit: String = model.highlight_id()
	for i: int in model.order.size():
		var id: String = model.order[i]
		var big: bool = id == lit
		var h: float = SliceUiData.num("hack_panel.row_h", 11) + (4.0 if big else 0.0)
		var offset: float = inset * float(i)
		out[id] = Rect2(at.x + offset, y, panel_width() - offset, h)
		y += (step + (4.0 if big else 0.0))
	return out


func _draw() -> void:
	if model.order.is_empty():
		return
	var shake: float = _shake_x()
	_draw_battery(shake)
	var end_y: float
	if model.is_auto():
		end_y = _draw_auto_row()
	else:
		end_y = _draw_list(shake)
	_draw_hijack(end_y)
	if model.is_locked():
		_draw_fizz(end_y)


func _shake_x() -> float:
	if model.denied_id().is_empty():
		return 0.0
	var px: float = SliceUiData.num("hack_panel.denied_shake_px", 2)
	return (px if int(_clock / 0.04) % 2 == 0 else -px) * model.denied_frac()


# ---- the battery ----

func _draw_battery(shake: float) -> void:
	var at: Vector2 = origin()
	var locked: bool = model.is_locked()
	var tint: Color = SandboxStyle.color("label_dim") if locked else SandboxStyle.color("label")
	SandboxStyle.label(self, at + Vector2(shake, 7.0), SliceUiData.text("hack.battery"), tint)
	var number_right: float = at.x + panel_width()
	if locked:
		SandboxStyle.text_right(self, "label", number_right, at.y + 7.0, "%s %s" % [SliceUiData.text("hack.jammed"), SliceUiData.fmt("hack.jammed_time", {"seconds": "%.1f" % model.lock_left_s()})], SliceUiData.color("jam"), 120.0)
	else:
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


# ---- the hack list ----

func _draw_list(shake: float) -> float:
	var rects: Dictionary = row_rects()
	var lit: String = model.highlight_id()
	var bottom: float = origin().y
	for id: String in model.order:
		var rect: Rect2 = rects[id]
		var is_lit: bool = id == lit
		_draw_row(id, rect, is_lit, shake if is_lit else 0.0, true)
		bottom = maxf(bottom, rect.end.y)
	return bottom + SliceUiData.num("hack_panel.hijack_y_gap", 4)


## One bar of the list.
func _draw_row(id: String, rect_in: Rect2, lit: bool, shake: float, show_cost: bool) -> void:
	var rect: Rect2 = Rect2(rect_in.position + Vector2(shake, 0.0), rect_in.size)
	var ready: bool = model.is_ready(id)
	var dim: float = 1.0 if lit else SliceUiData.num("hack_panel.dim_alpha", 0.55)
	var affordable: bool = model.can_afford(id)
	SandboxStyle.list_bar(self, rect, lit and not model.is_locked(), not lit)
	var cooling: float = model.cooldown_frac(id)
	if cooling > 0.0:
		var sweep_w: float = floorf(rect.size.x * cooling)
		draw_rect(Rect2(rect.end.x - sweep_w, rect.position.y + 1.0, sweep_w, rect.size.y - 2.0), Color(0, 0, 0, 0.5))
	var icon_tint: Color = SliceUiData.color("ready_icon") if ready else SliceUiData.color("afford_not")
	icon_tint.a = dim
	var icon_size: float = 9.0
	var icon_at: Vector2 = Vector2(rect.position.x + SliceUiData.num("hack_panel.icon_x", 3), rect.position.y + floorf((rect.size.y - icon_size) / 2.0))
	HackIcons.draw(self, icon_at, model.icon_of(id), icon_tint, icon_size)
	var text_color: Color = SandboxStyle.row_color(lit, affordable)
	text_color.a = dim
	var name_text: String = model.display_name(id)
	var name_x: float = rect.position.x + SliceUiData.num("hack_panel.name_x", 16)
	if lit:
		SandboxStyle.text(self, "body", Vector2(name_x, rect.position.y + rect.size.y - 3.0), name_text, text_color)
		SandboxStyle.cursor(self, Vector2(rect.position.x - 8.0, rect.position.y + rect.size.y / 2.0))
		if not model.is_auto():
			_draw_pick_arrows(rect)
	else:
		SandboxStyle.text(self, "label", Vector2(name_x, rect.position.y + rect.size.y - 3.0), name_text.to_upper(), text_color)
	if show_cost:
		var cost_text: String = SliceUiData.text("hack.cost_all") if model.takes_all(id) else str(model.cost_of(id))
		var cost_color: Color = SandboxStyle.color("label") if affordable else SliceUiData.color("afford_not")
		cost_color.a = dim
		SandboxStyle.text_right(self, "label", rect.end.x - 3.0, rect.position.y + rect.size.y - 3.0, cost_text, cost_color, 24.0)


## Left / right hints beside the picked hack's bar: the d-pad changes it.
func _draw_pick_arrows(rect: Rect2) -> void:
	var mid: float = rect.position.y + rect.size.y / 2.0
	var pulse: bool = int(_clock / 0.4) % 2 == 0
	var tint: Color = SandboxStyle.color("arrow")
	if not pulse:
		tint = tint.darkened(0.2)
	SandboxStyle.arrow(self, Vector2(rect.position.x + rect.size.x - 24.0, mid), Vector2i.LEFT, tint)
	SandboxStyle.arrow(self, Vector2(rect.end.x + 6.0, mid), Vector2i.RIGHT, tint)


## Automatic mode: one bar, "Auto", and the last hack used.
func _draw_auto_row() -> float:
	var at: Vector2 = origin()
	var rect: Rect2 = Rect2(at.x, at.y + SliceUiData.num("hack_panel.list_y", 12), panel_width(), SliceUiData.num("hack_panel.row_h", 11) + 4.0)
	SandboxStyle.list_bar(self, rect, not model.is_locked())
	var last: String = model.last_used
	if not last.is_empty():
		var ready: bool = model.is_ready(last)
		var icon_tint: Color = SliceUiData.color("ready_icon") if ready else SliceUiData.color("afford_not")
		HackIcons.draw(self, Vector2(rect.position.x + 3.0, rect.position.y + floorf((rect.size.y - 9.0) / 2.0)), model.icon_of(last), icon_tint, 9.0)
	SandboxStyle.text(self, "body", Vector2(rect.position.x + SliceUiData.num("hack_panel.name_x", 16), rect.end.y - 3.0), SliceUiData.text("hack.auto"), SandboxStyle.color("text"))
	var sub: String = SliceUiData.fmt("hack.auto_last", {"name": model.display_name(last)}) if not last.is_empty() else SliceUiData.text("hack.auto_none")
	SandboxStyle.text_right(self, "label", rect.end.x - 3.0, rect.end.y - 3.0, sub.to_upper(), SandboxStyle.color("label"), 70.0)
	return rect.end.y + SliceUiData.num("hack_panel.hijack_y_gap", 4)


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
	var cols: int = int(panel_width() / px)
	var rows: int = int((end_y - at.y) / px)
	for row: int in rows:
		for col: int in cols:
			var h: int = _hash(col, row, step)
			if float(h % 1000) / 1000.0 < density * 0.5:
				draw_rect(Rect2(at.x + float(col) * px, at.y + float(row) * px, px, px), Color(light, 0.55))
			elif float(h % 1000) / 1000.0 > 1.0 - density * 0.5:
				draw_rect(Rect2(at.x + float(col) * px, at.y + float(row) * px, px, px), Color(dark, 0.6))


static func _hash(a: int, b: int, c: int) -> int:
	var h: int = (a * 73856093) ^ (b * 19349663) ^ (c * 83492791)
	return absi(h)
