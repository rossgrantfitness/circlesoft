class_name SandboxUiData
extends RefCounted
## Reads the combat sandbox UI's numbers (data/ui/sandbox_ui.json), words (data/text/sandbox.json)
## and the shared palette (data/ui/ui_theme.json). Nothing about the sandbox UI's look or wording is
## hard-coded in the scripts; this is the one place that knows the file names.

const UI_ID: String = "ui/sandbox_ui"
const TEXT_ID: String = "text/sandbox"
const THEME_ID: String = "ui/ui_theme"


## A value in sandbox_ui.json by dotted path.
static func ui(path: String, fallback: Variant = null) -> Variant:
	return DataDB.get_value(UI_ID, path, fallback)


static func ui_int(path: String, fallback: int = 0) -> int:
	return int(DataDB.get_value(UI_ID, path, fallback))


static func ui_float(path: String, fallback: float = 0.0) -> float:
	return float(DataDB.get_value(UI_ID, path, fallback))


## A color in sandbox_ui.json "colors" (by name) or any dotted path to a hex string.
static func color(name: String, fallback: String = "#FF00FF") -> Color:
	var path: String = name if name.contains(".") else "colors.%s" % name
	return Color.html(str(DataDB.get_value(UI_ID, path, fallback)))


static func hex(value: Variant, fallback: String = "#FF00FF") -> Color:
	return Color.html(str(value)) if str(value).begins_with("#") else Color.html(fallback)


## {x, y, w, h} entry as a Rect2.
static func rect(path: String) -> Rect2:
	var d: Dictionary = DataDB.get_value(UI_ID, path, {})
	return Rect2(float(d.get("x", 0)), float(d.get("y", 0)), float(d.get("w", 0)), float(d.get("h", 0)))


## [x, y] entry as a Vector2.
static func vec(path: String) -> Vector2:
	var a: Array = DataDB.get_value(UI_ID, path, [0, 0])
	return Vector2(float(a[0]), float(a[1]))


## A string in sandbox.json by dotted path (empty when missing).
static func text(path: String) -> String:
	return str(DataDB.get_value(TEXT_ID, path, ""))


## A string with {word} placeholders filled from `vars`.
static func fmt(template: String, vars: Dictionary = {}) -> String:
	var out: String = template
	for key: Variant in vars:
		out = out.replace("{%s}" % str(key), str(vars[key]))
	return out


## A color from the shared theme palette (ui_theme.json "palette"), by key.
static func palette(key: String) -> Color:
	return Color.html(str(DataDB.get_value(THEME_ID, "palette.%s" % key, "#FF00FF")))
