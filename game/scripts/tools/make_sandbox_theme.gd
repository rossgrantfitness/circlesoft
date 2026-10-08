extends SceneTree
## Builds art/placeholder/ui/sandbox_theme.tres: the ONE Theme resource that holds the sandbox UI's
## look (fonts and sizes, letter spacing, every color, bar and frame constants). Ross reviews the
## look, then we swap fonts or colors here and re-run:
##   godot --headless --path game -s res://scripts/tools/make_sandbox_theme.gd
## The scripts under scripts/ui/sandbox/ read the look only through SandboxStyle (which loads this
## file; its path is "theme_path" in data/ui/sandbox_ui.json), and layout lives in data/ui/sandbox_ui.json.
##
## Direction (Ross, 2026-10-08, Vagrant Story menu + HUD, DMC1 frame as a hint): stacked horizontal
## navy-to-blue bars, teal-green headers, yellow-green selected text, a solid orange triangle cursor,
## cyan triangle arrows, a tall mixed-case pixel font with wide spacing and a dark drop shadow, thin
## gradient HUD bars, and a riveted metal frame for the Noise gauge. Fonts here are open-license only.

const OUT: String = "res://art/placeholder/ui/sandbox_theme.tres"
const TYPE: String = "SandboxUi"
const FONT_DIR: String = "res://art/final/ui/fonts/"
## The default body font. Candidates (docs/screenshots/ui_font_options.png): Jersey15-Regular.ttf,
## DotGothic16-Regular.ttf, VT323-Regular.ttf, PixelifySans-VariableFont_wght.ttf (all SIL OFL 1.1).
const BODY_FONT: String = "Jersey15-Regular.ttf"
const BODY_SIZE: int = 16
const BODY_SPACING: int = 1
const TITLE_SIZE: int = 20
const LABEL_FONT: String = "Silkscreen-Regular.ttf"
const LABEL_SIZE: int = 8
const LABEL_SPACING: int = 1

const COLORS: Dictionary = {
	"text": "#E4E6EE",
	"text_light": "#FFFFFF",
	"text_dim": "#7C84A0",
	"text_selected": "#C8E85A",
	"text_on_header": "#E8FFF6",
	"shadow": "#05040C",
	"label": "#6FD6EE",
	"label_dim": "#5B6A8C",
	"bar_top": "#1C2658",
	"bar_bottom": "#101839",
	"bar_sel_top": "#3A57B0",
	"bar_sel_bottom": "#1B2A6B",
	"bar_off_top": "#161B30",
	"bar_off_bottom": "#0C0F1E",
	"header_top": "#3FA08A",
	"header_bottom": "#1E6A5E",
	"cursor": "#FF9A2E",
	"cursor_edge": "#5A2A08",
	"arrow": "#5FE0F0",
	"track": "#0B0F22",
	"track_edge": "#05040C",
	"slider_top": "#5FD0C0",
	"slider_bottom": "#6C7A88",
	"slider_focus_top": "#C8E85A",
	"slider_focus_bottom": "#7FA02A",
	"notch": "#EDEAD8",
	"pip": "#FFE08A",
	"good": "#9BE35A",
	"warn": "#FF7A59",
	"hp_top": "#5FD0C0",
	"hp_bottom": "#6C7A88",
	"hp_low_top": "#FF9A7A",
	"hp_low_bottom": "#C04030",
	"hp_chip": "#FFF2B0",
	"noise_top": "#FF8AD0",
	"noise_bottom": "#B0408A",
	"lights_top": "#FFE9A0",
	"lights_bottom": "#E0A030",
	"flare_top": "#FFE680",
	"flare_bottom": "#D08A20",
	"mode_tag": "#9A5A5A",
	"metal_light": "#A9B3C2",
	"metal_mid": "#5B6573",
	"metal_dark": "#232733",
	"rivet": "#D9A441",
	"dim": "#05040C",
}

const CONSTANTS: Dictionary = {
	"shadow_x": 1,
	"shadow_y": 1,
	"top_light": 0,
	"stack_offset": 3,
	"edge_light_pct": 30,
	"edge_dark_pct": 50,
	"cursor_w": 5,
	"cursor_h": 9,
	"arrow_size": 3,
	"frame_border": 3,
	"rivet_size": 2,
}


func _initialize() -> void:
	var theme: Theme = Theme.new()
	theme.set_default_font(_font(BODY_FONT, BODY_SPACING))
	theme.set_default_font_size(BODY_SIZE)
	theme.set_font("body", TYPE, _font(BODY_FONT, BODY_SPACING))
	theme.set_font_size("body", TYPE, BODY_SIZE)
	theme.set_font("title", TYPE, _font(BODY_FONT, BODY_SPACING))
	theme.set_font_size("title", TYPE, TITLE_SIZE)
	theme.set_font("digits", TYPE, _font(BODY_FONT, BODY_SPACING))
	theme.set_font_size("digits", TYPE, TITLE_SIZE)
	theme.set_font("label", TYPE, _font(LABEL_FONT, LABEL_SPACING))
	theme.set_font_size("label", TYPE, LABEL_SIZE)
	for name: String in COLORS:
		theme.set_color(name, TYPE, Color.html(str(COLORS[name])))
	for name: String in CONSTANTS:
		theme.set_constant(name, TYPE, int(CONSTANTS[name]))
	var err: Error = ResourceSaver.save(theme, OUT)
	print("saved %s (%s)" % [OUT, error_string(err)])
	quit(0 if err == OK else 1)


func _font(file: String, spacing: int) -> FontVariation:
	var variation: FontVariation = FontVariation.new()
	variation.base_font = load(FONT_DIR + file) as Font
	variation.spacing_glyph = spacing
	return variation
