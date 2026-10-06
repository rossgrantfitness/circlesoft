class_name BattlePopup
extends Control
## One animated pop-up in the battle HUD: a rating (Nice!, Rad!, TOTALLY RAD!, Blocked!, Perfect
## Block!, Payback!), a damage or heal number, the Clutch "!" cue, the skill-name slam, or the big
## K.O.!. All of them step at about 12 fps with no easing (style guide): a 3-step overshoot in,
## a hold with a small drift up, then a stepped fade out.
##
## Placeholder lettering: chunky letters drawn from the UI font with a 2px Ink outline, a 1px white
## inner outline, a flat fill and a lighter top edge, tilted forward. TOTALLY RAD! cycles its three
## colors and bounces letter by letter. The final lettering is docs/art_requests.md row 37.
##
## The HUD owns the clock: it calls tick(delta). A popup draws around its own origin, which the
## HUD places at the combatant (anchor), so scale and drift work from the center.

signal finished(popup: BattlePopup)

enum Kind { RATING, NUMBER, CUE, SLAM, KO }

var kind: Kind = Kind.RATING
## The words (or digits) shown.
var text: String = ""
## Which style: a rating id ("nice", "totally_rad", ...), "damage" / "heal", "cue", "cue_big", "slam", "ko".
var style_id: String = ""

var _colors: Array[Color] = []
var _font_size: int = 20
var _ink_radius: int = 3
var _white_radius: int = 1
var _cycle_steps: int = 0
var _bounce_px: int = 0
var _bounce_step_s: float = 0.0833
var _timing: Dictionary = {}
var _step_s: float = 0.0833
var _age: float = 0.0
var _done: bool = false
var _skew: float = 0.0
var _highlight_px: int = 2


## A rating pop-up ("nice", "rad", "totally_rad", "blocked", "perfect_block", "payback").
static func make_rating(rating_id: String) -> BattlePopup:
	var popup: BattlePopup = BattlePopup.new()
	var style: Dictionary = BattleUiData.ui("ratings.kinds.%s" % rating_id, {})
	popup.kind = Kind.RATING
	popup.style_id = rating_id
	popup.text = BattleUiData.text("ratings.%s" % rating_id)
	popup._colors = _colors_from(style.get("colors", ["#FFFFFF"]))
	popup._font_size = int(style.get("size", 22))
	popup._ink_radius = BattleUiData.ui_int("ratings.ink", 3)
	popup._white_radius = BattleUiData.ui_int("ratings.white", 1)
	popup._skew = BattleUiData.ui_float("ratings.skew", 0.18)
	popup._cycle_steps = int(style.get("cycle_steps", 0))
	popup._bounce_px = int(style.get("bounce_px", 0))
	popup._bounce_step_s = float(style.get("bounce_step_s", 0.0833))
	popup._setup_timing("rating")
	return popup


## A damage ("damage") or heal ("heal") number.
static func make_number(amount: int, is_heal: bool) -> BattlePopup:
	var popup: BattlePopup = BattlePopup.new()
	popup.kind = Kind.NUMBER
	popup.style_id = "heal" if is_heal else "damage"
	popup.text = str(amount)
	var colors: Array[Color] = []
	colors.append(BattleUiData.ui_color("numbers.%s" % popup.style_id))
	popup._colors = colors
	popup._font_size = BattleUiData.ui_int("numbers.size", 20)
	popup._ink_radius = BattleUiData.ui_int("numbers.ink", 2)
	popup._white_radius = 0
	popup._setup_timing("number")
	popup._highlight_px = 0
	return popup


## The Clutch "!" (or the boss "!!" with a short shake).
static func make_cue(big: bool) -> BattlePopup:
	var popup: BattlePopup = BattlePopup.new()
	popup.kind = Kind.CUE
	popup.style_id = "cue_big" if big else "cue"
	popup.text = "!!" if big else "!"
	popup._setup_timing("cue")
	return popup


## The skill name slamming onto the screen (a dark band across the width, letters stamp in).
static func make_slam(skill_name: String) -> BattlePopup:
	var popup: BattlePopup = BattlePopup.new()
	popup.kind = Kind.SLAM
	popup.style_id = "slam"
	popup.text = skill_name
	popup._colors = _colors_from(BattleUiData.ui("slam.colors", ["#FFE08A"]))
	popup._font_size = BattleUiData.ui_int("slam.size", 26)
	popup._ink_radius = BattleUiData.ui_int("ratings.ink", 3)
	popup._white_radius = 0
	popup._skew = BattleUiData.ui_float("ratings.skew", 0.18)
	popup._setup_timing("slam")
	return popup


## The big K.O.!
static func make_ko() -> BattlePopup:
	var popup: BattlePopup = BattlePopup.new()
	popup.kind = Kind.KO
	popup.style_id = "ko"
	popup.text = BattleUiData.text("ko")
	popup._colors = _colors_from(BattleUiData.ui("ko.colors", ["#FF5A36"]))
	popup._font_size = BattleUiData.ui_int("ko.size", 40)
	popup._ink_radius = BattleUiData.ui_int("ratings.ink", 3)
	popup._white_radius = BattleUiData.ui_int("ratings.white", 1)
	popup._skew = BattleUiData.ui_float("ratings.skew", 0.18)
	popup._cycle_steps = BattleUiData.ui_int("ko.cycle_steps", 3)
	popup._setup_timing("ko")
	return popup


static func _colors_from(hexes: Array) -> Array[Color]:
	var out: Array[Color] = []
	for hex: Variant in hexes:
		out.append(Color.html(str(hex)))
	if out.is_empty():
		out.append(Color.WHITE)
	return out


func _setup_timing(timing_key: String) -> void:
	_timing = BattleUiData.ui("timing.popup.%s" % timing_key, {})
	_step_s = BattleUiData.ui_float("timing.step_s", 0.0833)
	_highlight_px = BattleUiData.ui_int("ratings.highlight_px", 2)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	size = Vector2.ZERO


# ---- time ----

func tick(delta: float) -> void:
	if _done:
		return
	_age += delta
	if _age >= get_duration():
		_done = true
		finished.emit(self)
	queue_redraw()


## Jumps the clock to `seconds` since the pop-up appeared (tests, screenshots).
func set_age(seconds: float) -> void:
	_age = maxf(0.0, seconds)
	queue_redraw()


func get_age() -> float:
	return _age


func is_done() -> bool:
	return _done


func get_duration() -> float:
	return float(_in_scales().size()) * _step_s + float(_timing.get("hold_s", 0.5)) + float(_fade_alphas().size()) * _step_s


func _in_scales() -> Array:
	return _timing.get("in_scales", [1.0])


func _fade_alphas() -> Array:
	return _timing.get("fade_alphas", [0.0])


## 0 = growing in, 1 = holding, 2 = fading out.
func get_phase() -> int:
	var in_time: float = float(_in_scales().size()) * _step_s
	if _age < in_time:
		return 0
	if _age < in_time + float(_timing.get("hold_s", 0.5)):
		return 1
	return 2


## The size multiplier right now (the overshoot steps while growing in, then 1).
func get_pop_scale() -> float:
	var scales: Array = _in_scales()
	if get_phase() == 0:
		return float(scales[mini(int(_age / _step_s), scales.size() - 1)])
	return 1.0


## Opacity right now (1 until the fade, then the stepped values).
func get_alpha() -> float:
	if get_phase() < 2:
		return 1.0
	var fades: Array = _fade_alphas()
	var in_time: float = float(_in_scales().size()) * _step_s + float(_timing.get("hold_s", 0.5))
	return float(fades[mini(int((_age - in_time) / _step_s), fades.size() - 1)])


## Pixels risen so far (whole pixels).
func get_drift() -> float:
	var hold: float = maxf(0.001, float(_timing.get("hold_s", 0.5)))
	var in_time: float = float(_in_scales().size()) * _step_s
	var t: float = clampf((_age - in_time) / hold, 0.0, 1.0)
	return floorf(float(_timing.get("drift_px", 0)) * t)


## The fill color right now: one color, or the cycle (TOTALLY RAD!, K.O.!).
func get_fill_color() -> Color:
	if _colors.size() <= 1 or _cycle_steps <= 0:
		return _colors[0]
	var index: int = int(_age / (float(_cycle_steps) * _step_s)) % _colors.size()
	return _colors[index]


func get_colors() -> Array[Color]:
	return _colors


## Width in pixels of the lettering (outline included), for fit checks.
func measure_width() -> float:
	return _text_width() + float(_ink_radius) * 2.0


func get_font_size() -> int:
	return _font_size


func _text_width() -> float:
	var font: Font = UiFonts.get_font("title")
	var total: float = 0.0
	for i: int in text.length():
		total += font.get_char_size(text.unicode_at(i), _font_size).x
	return total


# ---- drawing ----

func _draw() -> void:
	modulate.a = get_alpha()
	var drift: Vector2 = Vector2(0, -get_drift())
	match kind:
		Kind.CUE:
			_draw_cue(drift)
		Kind.SLAM:
			_draw_slam()
		_:
			_draw_letters(drift, get_pop_scale())


func _draw_letters(offset: Vector2, scale: float) -> void:
	var font: Font = UiFonts.get_font("title")
	var ascent: float = font.get_ascent(_font_size)
	var descent: float = font.get_descent(_font_size)
	var baseline: float = (ascent - descent) / 2.0
	var total: float = _text_width()
	var fill: Color = get_fill_color()
	var ink: Color = BattleUiData.ui_color("ratings.ink_color")
	var white: Color = BattleUiData.ui_color("ratings.white_color")
	var light: Color = fill.lerp(Color.WHITE, 0.55)
	draw_set_transform_matrix(Transform2D(Vector2(scale, 0.0), Vector2(-_skew * scale, scale), offset))
	var wave: int = -1
	if _bounce_px > 0:
		wave = int(_age / _bounce_step_s) % (text.length() + 4)
	var x: float = -total / 2.0
	for i: int in text.length():
		var ch: String = text[i]
		var lift: float = 0.0
		if wave >= 0:
			lift = float(_bounce_px) if i == wave else (float(_bounce_px) / 2.0 if i == wave - 1 else 0.0)
		var at: Vector2 = Vector2(x, baseline - lift)
		var bottom: Vector2 = at + Vector2(0, float(_highlight_px))
		if _ink_radius > 0:
			draw_string_outline(font, bottom, ch, HORIZONTAL_ALIGNMENT_LEFT, -1, _font_size, _ink_radius * 2, ink)
		if _white_radius > 0:
			draw_string_outline(font, bottom, ch, HORIZONTAL_ALIGNMENT_LEFT, -1, _font_size, _white_radius * 2, white)
		if _highlight_px > 0:
			draw_string(font, at, ch, HORIZONTAL_ALIGNMENT_LEFT, -1, _font_size, light)
		draw_string(font, bottom, ch, HORIZONTAL_ALIGNMENT_LEFT, -1, _font_size, fill)
		x += font.get_char_size(text.unicode_at(i), _font_size).x
	draw_set_transform_matrix(Transform2D.IDENTITY)


func _draw_slam() -> void:
	var band_h: float = BattleUiData.ui_float("slam.band_h", 40.0)
	var band_color: Color = BattleUiData.ui_color("slam.band_color")
	band_color.a = BattleUiData.ui_float("slam.band_alpha", 0.85)
	var stripe: Color = BattleUiData.ui_color("slam.stripe_color")
	var stripe_h: float = BattleUiData.ui_float("slam.stripe_h", 3.0)
	var stage_w: float = float(UiStage.STAGE_SIZE.x)
	var left: float = -position.x
	draw_rect(Rect2(left, -band_h / 2.0, stage_w, band_h), band_color)
	draw_rect(Rect2(left, -band_h / 2.0, stage_w, stripe_h), stripe)
	draw_rect(Rect2(left, band_h / 2.0 - stripe_h, stage_w, stripe_h), stripe)
	var shake: float = 0.0
	var landed: int = _in_scales().size()
	var steps_since: int = int(_age / _step_s) - landed
	if steps_since >= 0 and steps_since < BattleUiData.ui_int("slam.shake_steps", 2):
		shake = float(BattleUiData.ui_int("slam.shake_px", 2)) * (1.0 if steps_since % 2 == 0 else -1.0)
	_draw_letters(Vector2(shake, 0), get_pop_scale())


func _draw_cue(offset: Vector2) -> void:
	var big: bool = style_id == "cue_big"
	var w: int = BattleUiData.ui_int("cue.big_w" if big else "cue.w", 16)
	var h: int = BattleUiData.ui_int("cue.big_h" if big else "cue.h", 16)
	var scale: float = get_pop_scale()
	var shake: float = 0.0
	if big and _age < BattleUiData.ui_float("cue.shake_s", 0.2):
		shake = float(BattleUiData.ui_int("cue.shake_px", 1)) * (1.0 if int(_age / _step_s) % 2 == 0 else -1.0)
	var center: Vector2 = offset + Vector2(shake, 0)
	var half: Vector2 = Vector2(float(w), float(h)) * scale / 2.0
	var rect: Rect2i = Rect2i(Vector2i((center - half).round()), Vector2i((half * 2.0).round()))
	var ink: Color = BattleUiData.ui_color("cue.ink")
	var ring: Color = BattleUiData.ui_color("cue.outline")
	var fill: Color = BattleUiData.ui_color("cue.fill")
	var radius: int = maxi(2, mini(rect.size.x, rect.size.y) / 2)
	PixelShape.fill(self, rect.grow(1), radius + 1, ink)
	PixelShape.fill(self, rect, radius, ring)
	PixelShape.fill(self, rect.grow(-1), maxi(1, radius - 1), ink)
	var bangs: int = 2 if big else 1
	var unit: float = scale
	var bang_w: float = 3.0 * unit
	var gap: float = 4.0 * unit
	var block: float = float(bangs) * bang_w + float(bangs - 1) * gap
	var x: float = center.x - block / 2.0
	for i: int in bangs:
		var bx: float = roundf(x + float(i) * (bang_w + gap))
		draw_rect(Rect2(bx, roundf(center.y - 5.0 * unit), roundf(bang_w), roundf(6.0 * unit)), fill)
		draw_rect(Rect2(bx, roundf(center.y + 2.0 * unit), roundf(bang_w), roundf(2.0 * unit)), fill)
