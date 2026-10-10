class_name SandboxPopups
extends RefCounted
## The words of the sandbox's event call-outs (data/text/sandbox.json "popups"): parry results, Lamp
## Flare and staggers. They are drawn as small, crisp, white lines under the Noise meter (see
## SandboxHud), not as big lettering in the 3D scene. Renaming the Noise ranks or the Lamp Flare is a
## text edit.


## "Guard!" / "Parry!" / "Perfect Parry!" / "Missed" for a parry rating ("nice", "rad", "totally_rad", "miss").
static func parry_text(rating: String) -> String:
	return SandboxUiData.text("popups.parry.%s" % rating)


## The Lamp Flare! line.
static func lamp_flare_text() -> String:
	return SandboxUiData.text("popups.lamp_flare")


## "Staggered!" / "Poise Break!" ("parry" or "poise").
static func stagger_text(by: String) -> String:
	return SandboxUiData.text("popups.stagger.%s" % by)


## The color a rank is drawn in on the Noise meter (data: hud.rank_colors).
static func rank_color(rank_id: String) -> Color:
	return SandboxUiData.hex(SandboxUiData.ui("hud.rank_colors.%s" % rank_id, SandboxUiData.ui("hud.rank_default_color", "#FFFFFF")))
