extends SceneTree
## Screenshots of the slice action HUD (VS-11) on top of the real sandbox arena, with stand-in data fed through the
## director's own signals. Needs a real renderer (not --headless):
##   xvfb-run -a -s "-screen 0 1920x1080x24" godot --path game --rendering-driver opengl3 \
##       -s res://tests/visual/capture_slice_hud.gd -- --sandbox
## Writes docs/screenshots/: slice_hud_hacks.png, slice_hud_hacks_jammed.png, slice_hud_hacks_auto.png,
## slice_hud_boss_bar.png, slice_continue.png, slice_pause.png (and 1:1 crops of the corners).
## Names no game classes (it compiles before the autoloads exist): everything is load(), get() and call().

const MAIN_SCENE: String = "res://scenes/core/main.tscn"
const HUD_SCENE: String = "res://scenes/ui/slice/action_hud.tscn"
const OUT_DIR: String = "res://../docs/screenshots/"

var _main: Node = null
var _sandbox: Node = null
var _director: Object = null
var _hud: Node = null


func _initialize() -> void:
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	root.size = Vector2i(1920, 1080)
	_main = (load(MAIN_SCENE) as PackedScene).instantiate()
	_main.set("debug_overlay_enabled", false)
	root.add_child(_main)
	for i: int in 40:
		await process_frame
	_sandbox = _main.call("get_sandbox") as Node
	if _sandbox == null:
		push_error("capture: the sandbox did not start")
		quit(1)
		return
	_director = _sandbox.call("get_director") as Object
	# The sandbox's own HUD steps aside; the slice HUD binds to the same host.
	for old: Node in root.find_children("SandboxHud", "Control", true, false):
		old.set("listen_input", false)
		old.set_process(false)
		old.visible = false
	_hud = (load(HUD_SCENE) as PackedScene).instantiate()
	_hud.set("listen_input", false)
	_hud.set("auto_router", false)
	_hud.set("animations_enabled", false)
	root.add_child(_hud)
	await process_frame
	await process_frame
	_hud.set_process(false)  # after _ready (which turns it on): the script ticks the HUD by hand
	_hud.call("bind", _sandbox)
	await _hacks_shots()
	await _boss_shot()
	await _menu_shots()
	quit(0)


func _frames(count: int = 4) -> void:
	for i: int in count:
		await process_frame


func _tick(seconds: float, step: float = 0.0833) -> void:
	var left: float = seconds
	while left > 0.0:
		_hud.call("tick", minf(step, left))
		left -= step
	await _frames(2)


func _grab(file: String) -> void:
	await _frames(6)
	var image: Image = root.get_texture().get_image()
	image.save_png(ProjectSettings.globalize_path(OUT_DIR + file))
	print("saved ", file, " ", image.get_size())


func _crop(file: String, rect: Rect2i) -> void:
	await _frames(2)
	var image: Image = root.get_texture().get_image()
	image.get_region(rect).save_png(ProjectSettings.globalize_path(OUT_DIR + file))
	print("saved ", file, " ", rect.size)


func _fight() -> void:
	var enemies: Array = _sandbox.call("get_enemies")
	_director.emit_signal("hp_changed", &"red", 84, 120)
	if not enemies.is_empty():
		var first: Object = enemies[0] as Object
		var id: StringName = first.get("actor_id")
		_director.emit_signal("hp_changed", id, 22, 40)
		var lock: Object = _sandbox.call("get_lock_on") as Object
		lock.emit_signal("target_changed", first)
		_director.emit_signal("hit_landed", {"attacker": &"red", "target": id, "outcome": "hit", "damage": 14})
		_director.emit_signal("hit_landed", {"attacker": &"red", "target": id, "outcome": "hit", "damage": 9})
	_director.emit_signal("noise_changed", 420.0, 0.45, &"nice", "Nice")


func _hacks_shots() -> void:
	_fight()
	_director.emit_signal("battery_changed", 63.0, 100.0)
	_director.emit_signal("hack_selected", &"emp")
	_director.emit_signal("hack_cast", {"hack": "zap_drone"})
	_director.emit_signal("hijack_changed", {"target": &"red", "active": true, "duration_s": 10.0})
	await _tick(3.0)
	_director.emit_signal("hack_cast", {"hack": "zap_drone"})
	await _tick(0.25)
	_hud.call("deck_choose")
	await _tick(0.3)
	await _grab("slice_hud_hacks.png")
	await _crop("slice_deck_closeup.png", Rect2i(0, 600, 960, 480))
	_hud.call("deck_choose")
	await _crop("slice_hud_hacks_closeup.png", Rect2i(0, 0, 960, 540))
	_director.emit_signal("hijack_changed", {"target": &"red", "active": false, "duration_s": 10.0})
	# Quiet Hours: grey bar and static.
	_director.emit_signal("hack_locked", true, 5000.0)
	await _tick(1.7)
	await _grab("slice_hud_hacks_jammed.png")
	await _crop("slice_hud_hacks_jammed_closeup.png", Rect2i(0, 0, 960, 540))
	_hud.call("deck_choose")
	await _tick(0.2)
	await _crop("slice_deck_jammed_closeup.png", Rect2i(0, 600, 960, 480))
	_hud.call("deck_choose")
	_director.emit_signal("hack_locked", false, 0.0)
	# Automatic mode: one bar and the last hack used.
	var knobs: Object = _director.get("feel") as Object
	knobs.call("set_value", "hack_pick_mode", "automatic")
	_director.emit_signal("hack_selected", &"emp")
	await _tick(0.5)
	await _crop("slice_hud_hacks_auto_closeup.png", Rect2i(0, 0, 960, 1080))
	knobs.call("set_value", "hack_pick_mode", "pick_then_fire")


func _boss_shot() -> void:
	_director.emit_signal("battery_changed", 88.0, 100.0)
	_director.emit_signal("hack_selected", &"overclock")
	_hud.call("show_boss_bar", {"name": "The Hushmaster", "hp": 300, "hp_max": 300, "phases": [{"id": "rig", "name": "The rig"}, {"id": "mech", "name": "The junk mech"}], "phase": 0})
	await _tick(1.0)
	_hud.call("set_boss_hp", 205.0, 300.0)
	await _tick(0.4)
	_hud.call("radio_say", "vela", "Relay on its front left leg. Zap it, or put a turret on it.")
	_hud.call("show_location", {"name": "Kasp's Arena", "kind": "arena"})
	await _tick(2.2)
	await _grab("slice_hud_boss_bar.png")
	await _crop("slice_hud_boss_bar_closeup.png", Rect2i(0, 540, 1920, 540))
	_hud.call("hide_boss_bar")
	await _tick(1.0)


func _menu_shots() -> void:
	var screen: Node = _hud.call("get_continue_screen") as Node
	screen.set("animations_enabled", false)
	screen.call("open_screen", "room_entrance", false, 0)
	await _tick(1.0)
	await _grab("slice_continue.png")
	screen.call("close_screen")
	var pause: Node = _hud.call("get_pause_menu") as Node
	pause.set("animations_enabled", false)
	_hud.connect("field_menu_requested", func() -> void: pass)
	_hud.call("open_pause")
	await _grab("slice_pause.png")
