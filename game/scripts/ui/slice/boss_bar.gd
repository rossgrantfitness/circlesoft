class_name BossBar
extends Control
## The boss bar (VS-11): the boss's name in the slanted face, a wide gradient health bar with a trailing chip, and a
## row of phase pips (the current phase lit, a flash when it changes) with the phase's own name. Bottom center,
## sliding down when a fight starts and away when it ends. 2D UI at window resolution; nothing floats in the 3D scene.
## BossBarModel holds the numbers; the HUD feeds it (`show_boss_bar`, `set_boss_hp`, `set_boss_phase`, `hide_boss_bar`).

var model: BossBarModel = BossBarModel.new()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


func tick(delta: float) -> void:
	model.tick(delta)
	queue_redraw()


## The bar's rectangle for a given UI size (also used by the tests and the screenshot): top center, between Red's
## health on the left and the Noise meter on the right, as wide as that gap allows.
func bar_rect(ui_size: Vector2) -> Rect2:
	var room: float = ui_size.x - 2.0 * SliceUiData.num("boss_bar.side_room", 136)
	var w: float = clampf(room, SliceUiData.num("boss_bar.w_min", 128), SliceUiData.num("boss_bar.w_max", 232))
	var h: float = SliceUiData.num("boss_bar.h", 5)
	return Rect2(floorf((ui_size.x - w) / 2.0), SliceUiData.num("boss_bar.top", 22), w, h)


func _draw() -> void:
	if not model.is_visible():
		return
	var alpha: float = clampf(model.presence, 0.0, 1.0)
	var lift: float = floorf((1.0 - alpha) * 10.0)
	var bar: Rect2 = bar_rect(size)
	bar.position.y -= lift
	var top: Color = SliceUiData.color("boss_top")
	var bottom: Color = SliceUiData.color("boss_bottom")
	var flash: float = model.flash()
	if flash > 0.0 and int(flash * 8.0) % 2 == 1:
		top = top.lerp(SliceUiData.color("boss_flash"), 0.6)
	var fade: Color = Color(1, 1, 1, alpha)
	# The bar. thin_bar can't take an alpha, so the whole bar draws through a modulated canvas.
	modulate = fade
	SandboxStyle.thin_bar(self, bar, model.fill_shown, top, bottom, model.chip)
	var name_y: float = bar.position.y - SliceUiData.num("boss_bar.name_gap", 4)
	SandboxStyle.text(self, "body", Vector2(bar.position.x, name_y), model.boss_name, SandboxStyle.color("text"))
	if model.phase_count() > 1:
		var label: String = SliceUiData.fmt("boss.phase_of", {"n": model.phase_index + 1, "count": model.phase_count()})
		SandboxStyle.text_right(self, "label", bar.end.x, name_y, label.to_upper(), SandboxStyle.color("label"), 60.0)
		_draw_pips(bar)
	_draw_part_pips(bar)


## The parts-left pips (B12): the real progress of a phase, so they are big. Under the bar on the right, a label saying what
## they count ("LEGS", "PLATES") and the count, then one wide pip per part: gold while it stands, dark once it is gone.
## A pip that has just gone out blinks white and flares a pixel wider for a moment. While none has gone, a dim hint says
## what to do ("Zap the leg relays"); it leaves with the first drop.
func _draw_part_pips(bar: Rect2) -> void:
	if model.pips_total <= 0:
		return
	var pip_w: float = SliceUiData.num("boss_bar.part_pip_w", 20)
	var pip_h: float = SliceUiData.num("boss_bar.part_pip_h", 6)
	var gap: float = SliceUiData.num("boss_bar.part_pip_gap", 3)
	var y: float = bar.end.y + 4.0
	var left_x: float = bar.end.x - float(model.pips_total) * (pip_w + gap) + gap
	for i: int in model.pips_total:
		var rect: Rect2 = Rect2(left_x + float(i) * (pip_w + gap), y, pip_w, pip_h)
		var up: bool = i < model.pips_standing
		var flashing: bool = model.pip_flashing(i)
		draw_rect(rect.grow(2.0 if flashing else 1.0), SandboxStyle.color("track_edge"))
		if flashing:
			draw_rect(rect.grow(1.0), SliceUiData.color("pip_flash"))
		draw_rect(rect, SliceUiData.color("boss_phase_lit") if up else SliceUiData.color("boss_phase_dim"))
	var label_color: Color = SliceUiData.color("pip_flash") if model.pips_flash() > 0.0 and int(model.pips_flash() * 10.0) % 2 == 1 else SandboxStyle.color("text")
	var label_right: float = left_x - SliceUiData.num("boss_bar.part_label_gap", 5)
	var count: String = model.pips_count_text()
	SandboxStyle.text_right(self, "label", label_right, y + pip_h, (model.pips_label() + " " + count).to_upper(), label_color, 80.0)
	var hint: String = model.pips_hint()
	if not hint.is_empty():
		SandboxStyle.text_right(self, "label", bar.end.x, y + pip_h + SliceUiData.num("boss_bar.part_hint_y", 9), hint.to_upper(), SandboxStyle.color("text_dim"), 140.0)


## The phase pips under the bar, left aligned; the lit one is gold, earlier ones stay bright, later ones dim.
func _draw_pips(bar: Rect2) -> void:
	var pip_w: float = SliceUiData.num("boss_bar.pip_w", 14)
	var pip_h: float = SliceUiData.num("boss_bar.pip_h", 3)
	var gap: float = SliceUiData.num("boss_bar.pip_gap", 3)
	var y: float = bar.end.y + 4.0
	for i: int in model.phase_count():
		var rect: Rect2 = Rect2(bar.position.x + float(i) * (pip_w + gap), y, pip_w, pip_h)
		var lit: bool = i == model.phase_index
		var paint: Color = SliceUiData.color("boss_phase_lit") if lit else SliceUiData.color("boss_phase_dim")
		draw_rect(rect.grow(1.0), SandboxStyle.color("track_edge"))
		draw_rect(rect, paint)
	var name_text: String = model.phase_name()
	if not name_text.is_empty():
		var text_x: float = bar.position.x + float(model.phase_count()) * (pip_w + gap) + 2.0
		SandboxStyle.text(self, "label", Vector2(text_x, y + 4.0), name_text.to_upper(), SandboxStyle.color("text_dim"))
