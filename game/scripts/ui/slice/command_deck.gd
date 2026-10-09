class_name CommandDeck
extends Control
## The command deck (VS-11, Ross's pick for Decision 1: a Kingdom Hearts / Final Fantasy style command menu, in our own
## look). Bottom-left corner: three slim bars, Attack, Hack and Item, in a slightly offset stack; the focused one is bright
## with the orange triangle cursor. The Hack bar shows the CURRENT hack (name, battery cost); "choose" opens a small list to
## its right with all four hacks, their keys (1 to 4) and battery costs. Moving the pick (wheel, d-pad left / right, 1 to 4)
## changes the current hack at once, and the hack button fires the current hack. The game keeps running while the list is
## open (a tuning switch can slow it). Item is a stub that says "coming later".
##
## This draws and keeps the focus; the pick itself is the host's HackSelector, mirrored in HackPanelModel.
## Automatic mode (option C, still one tuning switch away): the Hack bar says "Auto" and the last hack used; no list.

var model: CommandDeckModel = CommandDeckModel.new()
## The hack list the deck reads (the HUD hands over the HackPanel's model).
var hacks: HackPanelModel = HackPanelModel.new()

var _clock: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


func tick(delta: float) -> void:
	_clock += delta
	model.tick(delta)
	queue_redraw()


# ---- layout ----

func deck_width() -> float:
	return SliceUiData.num("deck.w", 136)


## The three bars, from the top. The focused bar is taller (its name is in the big face).
func row_rects() -> Array[Rect2]:
	var out: Array[Rect2] = []
	var gap: float = SliceUiData.num("deck.gap", 1)
	var small: float = SliceUiData.num("deck.row_h", 11)
	var tall: float = SliceUiData.num("deck.row_h_focus", 16)
	var heights: Array[float] = []
	var total: float = gap * float(CommandDeckModel.ROWS.size() - 1)
	for i: int in CommandDeckModel.ROWS.size():
		var h: float = tall if i == model.row else small
		heights.append(h)
		total += h
	var y: float = size.y - SliceUiData.num("deck.bottom_gap", 22) - total
	var inset: float = SliceUiData.num("deck.stagger", 3)
	for i: int in CommandDeckModel.ROWS.size():
		var offset: float = inset * float(i)
		out.append(Rect2(SliceUiData.num("deck.x", 8) + offset, y, deck_width() - offset, heights[i]))
		y += heights[i] + gap
	return out


## The list's bars, from the top (empty when it is closed or the pick is automatic).
func submenu_rects() -> Array[Rect2]:
	var out: Array[Rect2] = []
	if not model.submenu_open or hacks.is_auto():
		return out
	var rows: Array[Rect2] = row_rects()
	var anchor: Rect2 = rows[CommandDeckModel.ROWS.find(CommandDeckModel.HACK)]
	var step: float = SliceUiData.num("deck.sub_step", 12)
	var h: float = SliceUiData.num("deck.sub_h", 11)
	var count: int = hacks.order.size()
	var total: float = step * float(count - 1) + h
	var bottom: float = anchor.end.y
	var top: float = bottom - total
	var x: float = SliceUiData.num("deck.x", 8) + deck_width() + SliceUiData.num("deck.sub_gap", 8)
	var inset: float = SliceUiData.num("deck.stagger", 3)
	for i: int in count:
		var offset: float = inset * float(i)
		out.append(Rect2(x + offset, top + step * float(i), SliceUiData.num("deck.sub_w", 128) - offset, h))
	return out


# ---- drawing ----

func _draw() -> void:
	if hacks.order.is_empty():
		return
	var rows: Array[Rect2] = row_rects()
	for i: int in rows.size():
		_draw_row(i, rows[i])
	_draw_submenu()
	var note: String = model.note()
	if not note.is_empty():
		SandboxStyle.text(self, "label", Vector2(rows[0].position.x, rows[0].position.y - 4.0), note.to_upper(), SandboxStyle.color("text"))
	if hacks.is_locked():
		_draw_fizz(rows[1])


func _draw_row(index: int, rect: Rect2) -> void:
	var id: String = CommandDeckModel.ROWS[index]
	var focused: bool = index == model.row
	SandboxStyle.list_bar(self, rect, focused, not focused)
	var word: String = SliceUiData.text("deck.%s" % id)
	var base_y: float = rect.position.y + rect.size.y - 3.0
	var dim: float = 1.0 if focused else SliceUiData.num("deck.dim_alpha", 0.6)
	var ink: Color = SandboxStyle.row_color(focused)
	ink.a = dim
	if focused:
		SandboxStyle.cursor(self, Vector2(rect.position.x - 8.0, rect.position.y + rect.size.y / 2.0))
		SandboxStyle.text(self, "body", Vector2(rect.position.x + 5.0, base_y), word, ink)
	else:
		SandboxStyle.text(self, "label", Vector2(rect.position.x + 5.0, base_y), word.to_upper(), ink)
	if id == CommandDeckModel.HACK:
		_draw_hack_summary(rect, focused, dim)


## The Hack bar's right half: the current hack's icon, name and cost (or "Auto" and the last one used).
func _draw_hack_summary(rect: Rect2, focused: bool, dim: float) -> void:
	var shown: String = hacks.highlight_id()
	var name_right: float = rect.end.x - 3.0
	if hacks.is_auto():
		var text: String = SliceUiData.text("hack.auto")
		if not shown.is_empty():
			text += " " + hacks.display_name(shown)
		SandboxStyle.text_right(self, "label", name_right, rect.position.y + rect.size.y - 3.0, text.to_upper(), Color(SandboxStyle.color("label"), dim), 90.0)
		return
	if shown.is_empty():
		return
	var ready: bool = hacks.is_ready(shown)
	var tint: Color = SliceUiData.color("ready_icon") if ready else SliceUiData.color("afford_not")
	tint.a = dim
	var cost: String = SliceUiData.text("hack.cost_all") if hacks.takes_all(shown) else str(hacks.cost_of(shown))
	var cost_color: Color = SandboxStyle.color("label") if hacks.can_afford(shown) else SliceUiData.color("afford_not")
	cost_color.a = dim
	var base_y: float = rect.position.y + rect.size.y - 3.0
	SandboxStyle.text_right(self, "label", name_right, base_y, cost, cost_color, 24.0)
	var name_color: Color = SandboxStyle.row_color(focused, hacks.can_afford(shown))
	name_color.a = dim
	SandboxStyle.text_right(self, "label", name_right - 26.0, base_y, hacks.display_name(shown).to_upper(), name_color, 66.0)
	HackIcons.draw(self, Vector2(rect.end.x - 120.0 + 38.0, rect.position.y + floorf((rect.size.y - 9.0) / 2.0)), hacks.icon_of(shown), tint, 9.0)
	var cooling: float = hacks.cooldown_frac(shown)
	if cooling > 0.0:
		var sweep_w: float = floorf(rect.size.x * cooling)
		draw_rect(Rect2(rect.end.x - sweep_w, rect.position.y + 1.0, sweep_w, rect.size.y - 2.0), Color(0, 0, 0, 0.5))
	if focused and hacks.denied_id() == shown:
		var shake: float = (2.0 if int(_clock / 0.04) % 2 == 0 else -2.0) * hacks.denied_frac()
		draw_rect(Rect2(rect.position.x + shake, rect.end.y - 1.0, rect.size.x, 1.0), SliceUiData.color("jam"))


func _draw_submenu() -> void:
	var rects: Array[Rect2] = submenu_rects()
	if rects.is_empty():
		return
	var picked: String = hacks.selected
	for i: int in rects.size():
		var id: String = hacks.order[i]
		var rect: Rect2 = rects[i]
		var is_picked: bool = id == picked
		SandboxStyle.list_bar(self, rect, is_picked, not is_picked)
		var affordable: bool = hacks.can_afford(id)
		var dim: float = 1.0 if is_picked else SliceUiData.num("deck.dim_alpha", 0.6)
		var base_y: float = rect.position.y + rect.size.y - 3.0
		var key_color: Color = Color(SandboxStyle.color("label_dim"), 1.0)
		SandboxStyle.text(self, "label", Vector2(rect.position.x + 3.0, base_y), str(i + 1), key_color)
		var icon_tint: Color = SliceUiData.color("ready_icon") if hacks.is_ready(id) else SliceUiData.color("afford_not")
		icon_tint.a = dim
		HackIcons.draw(self, Vector2(rect.position.x + 11.0, rect.position.y + floorf((rect.size.y - 9.0) / 2.0)), hacks.icon_of(id), icon_tint, 9.0)
		var ink: Color = SandboxStyle.row_color(is_picked, affordable)
		ink.a = dim
		SandboxStyle.text(self, "label", Vector2(rect.position.x + 23.0, base_y), hacks.display_name(id).to_upper(), ink)
		var cost: String = SliceUiData.text("hack.cost_all") if hacks.takes_all(id) else str(hacks.cost_of(id))
		var cost_color: Color = SandboxStyle.color("label") if affordable else SliceUiData.color("afford_not")
		cost_color.a = dim
		SandboxStyle.text_right(self, "label", rect.end.x - 3.0, base_y, cost, cost_color, 24.0)
		if is_picked:
			SandboxStyle.cursor(self, Vector2(rect.position.x - 8.0, rect.position.y + rect.size.y / 2.0))
		var cooling: float = hacks.cooldown_frac(id)
		if cooling > 0.0:
			var sweep_w: float = floorf(rect.size.x * cooling)
			draw_rect(Rect2(rect.end.x - sweep_w, rect.position.y + 1.0, sweep_w, rect.size.y - 2.0), Color(0, 0, 0, 0.5))
	_draw_fizz_over(rects[0].position, Vector2(rects[0].size.x, rects.back().end.y - rects[0].position.y))


## Quiet Hours static over the Hack bar.
func _draw_fizz(rect: Rect2) -> void:
	_draw_fizz_over(rect.position, rect.size)


func _draw_fizz_over(at: Vector2, area: Vector2) -> void:
	if not hacks.is_locked():
		return
	var px: float = SliceUiData.num("hack_panel.fizz_px", 2)
	var step: int = int(_clock / SliceUiData.num("hack_panel.fizz_step_s", 0.0833))
	var density: float = SliceUiData.num("hack_panel.fizz_density", 0.3)
	var light: Color = SliceUiData.color("fizz_light")
	var dark: Color = SliceUiData.color("fizz_dark")
	for row: int in int(area.y / px):
		for col: int in int(area.x / px):
			var h: int = HackPanel._hash(col, row, step)
			var roll: float = float(h % 1000) / 1000.0
			if roll < density * 0.5:
				draw_rect(Rect2(at.x + float(col) * px, at.y + float(row) * px, px, px), Color(light, 0.55))
			elif roll > 1.0 - density * 0.5:
				draw_rect(Rect2(at.x + float(col) * px, at.y + float(row) * px, px, px), Color(dark, 0.6))
