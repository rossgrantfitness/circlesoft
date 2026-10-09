class_name SliceUiData
extends RefCounted
## Reads the slice HUD's numbers and colors (data/ui/slice_ui.json) and words (data/text/slice_ui.json).
## Same shape as SandboxUiData, which it falls back to for the shared palette. Nothing about the slice
## HUD's layout, timing or wording is hard-coded in the scripts.

const UI_ID: String = "ui/slice_ui"
const TEXT_ID: String = "text/slice_ui"


static func ui(path: String, fallback: Variant = null) -> Variant:
	return DataDB.get_value(UI_ID, path, fallback)


static func num(path: String, fallback: float = 0.0) -> float:
	return float(DataDB.get_value(UI_ID, path, fallback))


static func whole(path: String, fallback: int = 0) -> int:
	return int(DataDB.get_value(UI_ID, path, fallback))


## A color in slice_ui.json "colors".
static func color(name: String, fallback: String = "#FF00FF") -> Color:
	return Color.html(str(DataDB.get_value(UI_ID, "colors.%s" % name, fallback)))


static func text(path: String) -> String:
	return str(DataDB.get_value(TEXT_ID, path, ""))


## A string with {word} placeholders filled from `vars`.
static func fmt(path: String, vars: Dictionary = {}) -> String:
	return SandboxUiData.fmt(text(path), vars)
