class_name SandboxPopups
extends RefCounted
## Builds the sandbox's pop-ups out of the battle HUD's BattlePopup (the stencil lettering): the same
## pop-in, hold, drift and fade, with sandbox words and colors. The words and which stencil style to
## borrow live in data/text/sandbox.json and data/ui/sandbox_ui.json ("hud"), so renaming the
## Noise ranks or the Lamp Flare is a text edit.


## A stencil-lettered pop-up. `style_id` picks the lettering size and motion from the battle HUD
## ("nice", "rad", "totally_rad", "blocked", ...); `text` replaces its words; a non-transparent
## `color` replaces its fill colors.
static func lettered(style_id: String, text: String, color: Color = Color(0, 0, 0, 0)) -> BattlePopup:
	var popup: BattlePopup = BattlePopup.make_rating(style_id)
	popup.text = text
	if color.a > 0.0:
		var colors: Array[Color] = popup.get_colors()
		colors.clear()
		colors.append(color)
	return popup


## A damage number (white for a hit on an enemy, `color` for other cases).
static func damage(amount: int, color: Color = Color(0, 0, 0, 0)) -> BattlePopup:
	var popup: BattlePopup = BattlePopup.make_number(amount, false)
	if color.a > 0.0:
		var colors: Array[Color] = popup.get_colors()
		colors.clear()
		colors.append(color)
	return popup


## "Guard!" / "Parry!" / "Perfect Parry!" / "Missed" for a parry rating ("nice", "rad", "totally_rad", "miss").
static func parry(rating: String) -> BattlePopup:
	var style: String = str(SandboxUiData.ui("hud.parry_styles.%s" % rating, "blocked"))
	var words: String = SandboxUiData.text("popups.parry.%s" % rating)
	if words.is_empty():
		return null
	var color: Color = Color(0, 0, 0, 0)
	if rating == "miss":
		color = SandboxUiData.hex(SandboxUiData.ui("hud.miss_color", "#8D97A5"))
	return lettered(style, words, color)


## The Lamp Flare! pop-up.
static func lamp_flare() -> BattlePopup:
	return lettered(str(SandboxUiData.ui("hud.flare_style", "rad")), SandboxUiData.text("popups.lamp_flare"), SandboxUiData.color("flare"))


## The Noise rank pop-up: the rank's own name in its stencil style ("Nice!", "Rad!", "TOTALLY RAD!").
static func rank(rank_id: String, rank_name: String) -> BattlePopup:
	var style: String = str(SandboxUiData.ui("hud.rank_styles.%s" % rank_id, SandboxUiData.ui("hud.rank_default_style", "nice")))
	return lettered(style, rank_name)


## "Staggered!" / "Poise Break!" over an enemy ("parry" or "poise").
static func stagger(by: String) -> BattlePopup:
	var words: String = SandboxUiData.text("popups.stagger.%s" % by)
	if words.is_empty():
		return null
	return lettered(str(SandboxUiData.ui("hud.stagger_style", "blocked")), words, SandboxUiData.hex(SandboxUiData.ui("hud.stagger_color", "#FFB347")))


## The color a rank is drawn in on the Noise meter.
static func rank_color(rank_id: String) -> Color:
	return SandboxUiData.hex(SandboxUiData.ui("hud.rank_colors.%s" % rank_id, SandboxUiData.ui("hud.rank_default_color", "#EDEAD8")))
