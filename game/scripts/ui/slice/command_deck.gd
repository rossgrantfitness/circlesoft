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
##
## When the hack button offers something else (the Hushmaster's "Jack in", B11) the Hack bar says so, and a button prompt
## pops up over the deck in the interact prompt's style (pop in, small bob): the button's name in a chip, then the words.

var model: CommandDeckModel = CommandDeckModel.new()
## The hack list the deck reads (the HUD hands over the HackPanel's model).
var hacks: HackPanelModel = HackPanelModel.new()

## The name of the hack button as it is bound right now ("K", "Y"); the HUD keeps it current.
var prompt_button_text: String = "K"

var _clock: float = 0.0
var _prompt_seen: String = ""
var _prompt_age: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


func tick(delta: float) -> void:
	_clock += delta
	model.tick(delta)
	var shown: String = hacks.prompt_id() if hacks.has_prompt() else ""
	if shown != _prompt_seen:
		_prompt_seen = shown
		_prompt_age = 0.0
	elif not shown.is_empty():
		_prompt_age += delta
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


## The prompt plate's rectangle (before the pop and bob), or an empty rectangle when the hack button offers nothing else.
func prompt_rect() -> Rect2:
	if not hacks.has_prompt():
		return Rect2()
	var rows: Array[Rect2] = row_rects()
	var pad: float = SliceUiData.num("hack_prompt.pad_x", 5)
	var h: float = SliceUiData.num("hack_prompt.h", 15)
	var w: float = pad + _button_chip_width() + SliceUiData.num("hack_prompt.gap", 4) + SandboxStyle.text_width("body", hacks.prompt_text()) + pad
	var x: float = SliceUiData.num("deck.x", 8)
	var bottom: float = rows[0].position.y - SliceUiData.num("hack_prompt.above_deck_px", 24) + h
	return Rect2(x, bottom - h, w, h)


func _button_chip_width() -> float:
	return maxf(SliceUiData.num("hack_prompt.button_w", 11), SandboxStyle.text_width("body", prompt_button_text.to_upper()) + 5.0)


## 0.5 / 1.15 / 1.0, the interact prompt's pop (data: hack_prompt.pop_scales), then steady.
func prompt_pop_scale() -> float:
	var steps: Array = SliceUiData.ui("hack_prompt.pop_scales", [1.0]) as Array
	var step_s: float = SliceUiData.num("hack_prompt.pop_step_s", 0.05)
	if steps.is_empty() or step_s <= 0.0:
		return 1.0
	return float(steps[mini(int(_prompt_age / step_s), steps.size() - 1)])


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
	if hacks.fizz_level() > 0.0:
		_draw_fizz(rows[1])
	_draw_prompt()


## The "Jack in" chip: an Ink-outlined plate with the button's name in a light chip and the words in amber, popping in
## and bobbing a pixel like the interact prompts, the words blinking slowly between amber and chalk.
func _draw_prompt() -> void:
	var rect: Rect2 = prompt_rect()
	if rect.size == Vector2.ZERO:
		return
	var steps: Array = SliceUiData.ui("hack_prompt.pop_scales", [1.0]) as Array
	var step_s: float = SliceUiData.num("hack_prompt.pop_step_s", 0.05)
	var popped: bool = _prompt_age > step_s * float(steps.size())
	var period: float = SliceUiData.num("hack_prompt.bob_period_s", 0.6)
	var bob: float = 0.0
	if popped and period > 0.0:
		bob = -roundf(SliceUiData.num("hack_prompt.bob_px", 1) * (0.5 + 0.5 * sin(_prompt_age * TAU / period)))
	var scale_now: float = prompt_pop_scale()
	var center: Vector2 = rect.get_center() + Vector2(0.0, bob)
	draw_set_transform(center - center * scale_now, 0.0, Vector2(scale_now, scale_now))
	var back: Color = SliceUiData.color("prompt_back")
	var edge: Color = SliceUiData.color("prompt_edge")
	var ink: Color = SandboxStyle.color("track_edge")
	var r: Rect2 = Rect2(rect.position + Vector2(0.0, bob), rect.size)
	# an Ink outline, then the amber edge with chamfered corners, then the fill
	draw_rect(r.grow(1.0), ink)
	draw_rect(r, edge)
	draw_rect(r.grow(-1.0), back)
	for corner: Vector2 in [r.position, Vector2(r.end.x - 1.0, r.position.y), Vector2(r.position.x, r.end.y - 1.0), r.end - Vector2.ONE]:
		draw_rect(Rect2(corner, Vector2.ONE), ink)
	var chip_w: float = _button_chip_width()
	var chip: Rect2 = Rect2(r.position.x + SliceUiData.num("hack_prompt.pad_x", 5), r.position.y + 3.0, chip_w, r.size.y - 6.0)
	draw_rect(chip.grow(1.0), ink)
	draw_rect(chip, SliceUiData.color("prompt_button"))
	SandboxStyle.text_center(self, "body", chip.position.x, chip.end.y - 2.0, prompt_button_text.to_upper(), ink, chip.size.x)
	var blink: bool = int(_prompt_age / maxf(0.05, SliceUiData.num("hack_prompt.blink_s", 0.5))) % 2 == 1
	var words: Color = SliceUiData.color("prompt_button") if blink else SliceUiData.color("prompt_text")
	SandboxStyle.text(self, "body", Vector2(chip.end.x + SliceUiData.num("hack_prompt.gap", 4), r.end.y - 5.0), hacks.prompt_text(), words)
	draw_set_transform_matrix(Transform2D.IDENTITY)


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
	if hacks.has_prompt():
		SandboxStyle.text_right(self, "label", name_right, rect.position.y + rect.size.y - 3.0, hacks.prompt_text().to_upper(), SliceUiData.color("prompt_text"), 90.0)
		return
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
	var label_text: String = hacks.display_name(shown).to_upper()
	SandboxStyle.text_right(self, "label", name_right - 26.0, base_y, label_text, name_color, 66.0)
	var icon_x: float = name_right - 26.0 - SandboxStyle.text_width("label", label_text) - 12.0
	var word_end: float = rect.position.x + 5.0 + SandboxStyle.text_width("body", SliceUiData.text("deck.hack")) + 4.0
	if icon_x >= word_end:
		HackIcons.draw(self, Vector2(icon_x, rect.position.y + floorf((rect.size.y - 9.0) / 2.0)), hacks.icon_of(shown), tint, 9.0)
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
	if hacks.fizz_level() <= 0.0:
		return
	var px: float = SliceUiData.num("hack_panel.fizz_px", 2)
	var step: int = int(_clock / SliceUiData.num("hack_panel.fizz_step_s", 0.0833))
	var density: float = SliceUiData.num("hack_panel.fizz_density", 0.3) * hacks.fizz_level()
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
