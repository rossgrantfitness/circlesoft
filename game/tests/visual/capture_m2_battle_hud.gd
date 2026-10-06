extends SceneTree
## Screenshots of the battle HUD for sharing progress with Ross. Needs a real renderer (not --headless):
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --path game --rendering-driver opengl3 \
##       -s res://tests/visual/capture_m2_battle_hud.gd
## Writes docs/screenshots/m2_battle_hud_commands.png, m2_battle_hud_ratings.png,
## m2_battle_victory.png (plus m2_battle_hud_targeting.png and m2_battle_game_over.png).
## It runs the HUD against the test stub controller over a plain dark backdrop with colored blobs
## standing in for the fighters (the real stage is the Technical Artist's). Game classes are never
## named here: everything is loaded by path and driven with call() / get().

const STAGE_SCRIPT: String = "res://scripts/ui/ui_stage.gd"
const HUD_SCENE: String = "res://scenes/ui/battle/battle_hud.tscn"
const STUB_SCRIPT: String = "res://tests/integration/test_battle_hud_stub.gd"
const OUT_DIR: String = "res://../docs/screenshots/"
const SETTLE_FRAMES: int = 6

## Where the stand-in fighters stand (head-top points, like the real stage's screen_pos_of).
const POINTS: Dictionary = {
	"red": Vector2(232, 84), "otis": Vector2(300, 142), "mox": Vector2(346, 108),
	"e1": Vector2(150, 86), "e2": Vector2(104, 104), "e3": Vector2(196, 106),
}
const COLORS: Dictionary = {
	"red": Color("#C8322A"), "otis": Color("#E0782B"), "mox": Color("#C9A23A"),
	"e1": Color("#6F8BA8"), "e2": Color("#6F8BA8"), "e3": Color("#8D97A5"),
}
const FAKE_STAGE_SOURCE: String = "extends Node\nvar points: Dictionary = {}\nfunc screen_pos_of(id: String) -> Vector2:\n\treturn points.get(id, Vector2.ZERO)\n"

var _hud: Node = null
var _stub: RefCounted = null


func _initialize() -> void:
	var backdrop: ColorRect = ColorRect.new()
	backdrop.color = Color("#14121F")
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(backdrop)
	var stage: Control = (load(STAGE_SCRIPT) as GDScript).new() as Control
	root.add_child(stage)
	await _frames(3)
	var stage_root: Control = stage.call("get_stage_root") as Control
	var field: Control = Control.new()
	field.size = Vector2(384, 216)
	field.draw.connect(_draw_field.bind(field))
	stage_root.add_child(field)
	_hud = (load(HUD_SCENE) as PackedScene).instantiate()
	_hud.set("manual_ticks", true)
	var fake_stage: GDScript = GDScript.new()
	fake_stage.source_code = FAKE_STAGE_SOURCE
	fake_stage.reload()
	var stage_node: Node = fake_stage.new() as Node
	stage_node.set("points", POINTS)
	root.add_child(stage_node)
	_hud.set("stage", stage_node)
	stage_root.add_child(_hud)
	_stub = (load(STUB_SCRIPT) as GDScript).new() as RefCounted
	_hud.call("bind", _stub)
	await _frames(3)
	_start_fight()
	await _commands_shot()
	await _targeting_shot()
	await _ratings_shot()
	await _victory_shot()
	await _game_over_shot()
	quit(0)


func _frames(count: int) -> void:
	for i: int in count:
		await process_frame


func _save(file_name: String) -> void:
	await _frames(SETTLE_FRAMES)
	var image: Image = root.get_texture().get_image()
	var err: Error = image.save_png(OUT_DIR + file_name)
	print("saved %s (%s) error %d" % [file_name, image.get_size(), err])


func _draw_field(canvas: Control) -> void:
	canvas.draw_rect(Rect2(0, 0, 384, 216), Color("#1F2540"))
	canvas.draw_rect(Rect2(0, 62, 384, 100), Color("#2B2B3D"))
	canvas.draw_rect(Rect2(0, 62, 384, 2), Color("#3A3566"))
	for id: String in POINTS:
		_draw_blob(canvas, POINTS[id], COLORS[id])


func _draw_blob(canvas: Control, head: Vector2, color: Color) -> void:
	canvas.draw_rect(Rect2(head.x - 9, head.y + 1, 18, 26), Color("#14121F"))
	canvas.draw_rect(Rect2(head.x - 8, head.y + 2, 16, 24), color)
	canvas.draw_rect(Rect2(head.x - 7, head.y + 4, 14, 10), color.lightened(0.25))


func _start_fight() -> void:
	_stub.call("start")
	_stub.emit_signal("round_started", 1, ["red", "e1", "otis", "e2", "mox", "e3"], ["red", "otis", "e1", "mox", "e2", "e3"])
	_stub.emit_signal("status_changed", "otis", "burnt_toast", true)
	_stub.emit_signal("stats_changed", "otis", 41, 66, 5, 10)
	_stub.emit_signal("stats_changed", "mox", 0, 34, 14, 16)
	_stub.emit_signal("combatant_down", "mox")
	_stub.emit_signal("turn_started", "red")
	_hud.get_party_panel().call("snap_bars")


func _press(command: int) -> void:
	_hud.call("handle_command", command)


func _commands_shot() -> void:
	var options: Dictionary = (_stub.get_script() as GDScript).call("default_options") as Dictionary
	_stub.emit_signal("command_needed", "red", options)
	_hud.call("tick", 0.5)
	await _save("m2_battle_hud_commands.png")
	# Skills submenu with a greyed skill and its reason.
	_press(MenuInput_DOWN)
	_press(MenuInput_CONFIRM)
	_press(MenuInput_DOWN)
	_press(MenuInput_DOWN)
	_hud.call("tick", 0.5)
	await _save("m2_battle_hud_skills.png")


# MenuInput.Cmd values (NONE, UP, DOWN, LEFT, RIGHT, CONFIRM, CANCEL, MENU), spelled out so this script names no game class.
const MenuInput_DOWN: int = 2
const MenuInput_UP: int = 1
const MenuInput_RIGHT: int = 4
const MenuInput_CONFIRM: int = 5
const MenuInput_CANCEL: int = 6


func _targeting_shot() -> void:
	_press(MenuInput_CANCEL)  # out of the skills list
	_press(MenuInput_UP)  # Attack
	_press(MenuInput_CONFIRM)  # Attack -> target
	_press(MenuInput_RIGHT)
	_hud.call("tick", 0.1)
	await _save("m2_battle_hud_targeting.png")
	_press(MenuInput_CANCEL)


func _ratings_shot() -> void:
	# Red lands a TOTALLY RAD, Otis perfect-blocks and pays back, Mox lands a Rad; numbers fly.
	_stub.emit_signal("stats_changed", "mox", 20, 34, 14, 16)
	_stub.emit_signal("combatant_revived", "mox")
	_stub.emit_signal("action_started", {"actor": "red", "kind": "attack", "targets": ["e1"], "presses": [{"index": 0, "type": "tap", "side": "attack", "cue_ms": 600, "owner_id": "red"}], "show_name": false})
	_stub.emit_signal("press_judged", {"actor": "red", "index": 0, "side": "attack", "rating": "totally_rad", "delta_ms": 12})
	_stub.emit_signal("hit", {"source": "red", "target": "e1", "amount": 37, "kind": "damage", "blocked": "none", "payback": false})
	_stub.emit_signal("press_judged", {"actor": "e2", "index": 1, "side": "block", "rating": "totally_rad", "delta_ms": 4, "owner_id": "otis"})
	_stub.emit_signal("hit", {"source": "otis", "target": "e2", "amount": 14, "kind": "damage", "blocked": "perfect", "payback": true})
	_stub.emit_signal("press_judged", {"actor": "mox", "index": 2, "side": "attack", "rating": "rad", "delta_ms": 40, "owner_id": "mox"})
	_stub.emit_signal("hit", {"source": "otis", "target": "e3", "amount": 18, "kind": "heal", "blocked": "none", "payback": false})
	_hud.call("show_cue", "e2", false)
	for popup: Node in _hud.call("get_popups"):
		popup.call("set_age", 0.3)
	_hud.call("tick", 0.0)
	await _save("m2_battle_hud_ratings.png")
	_hud.call("tick", 3.0)
	# The rest of the set: Nice!, Blocked!, and the skill name slam.
	_stub.emit_signal("press_judged", {"actor": "red", "index": 0, "side": "attack", "rating": "nice", "delta_ms": 90})
	_stub.emit_signal("press_judged", {"actor": "e1", "index": 1, "side": "block", "rating": "rad", "delta_ms": 40, "owner_id": "otis"})
	_hud.call("show_skill_name", "Porch Light")
	for popup: Node in _hud.call("get_popups"):
		popup.call("set_age", 0.45)
	_hud.call("tick", 0.0)
	await _save("m2_battle_hud_slam.png")
	_hud.call("tick", 3.0)
	_stub.emit_signal("action_finished", {})
	await _frames(2)


func _victory_shot() -> void:
	_stub.emit_signal("combatant_down", "e1")
	_stub.emit_signal("combatant_down", "e2")
	_stub.emit_signal("combatant_down", "e3")
	await _frames(2)
	_hud.call("tick", 0.45)
	await _save("m2_battle_ko.png")
	var report: Dictionary = (_stub.get_script() as GDScript).call("default_report") as Dictionary
	report["level_ups"] = [
		{"id": "otis", "from": 3, "to": 4, "gains": {"hp": 6, "juice": 2, "attack": 2, "defense": 1, "heart": 1, "speed": 1}, "learned": ["heave_ho"]},
		{"id": "red", "from": 3, "to": 4, "gains": {"hp": 5, "attack": 2, "speed": 1}, "learned": []},
	]
	_stub.emit_signal("battle_ended", "win", report)
	_hud.call("tick", 1.6)
	_hud.call("tick", 0.45)
	_hud.call("tick", 2.0)
	await _save("m2_battle_victory.png")


func _game_over_shot() -> void:
	_stub.emit_signal("battle_started", (_stub.get_script() as GDScript).call("default_snapshot"))
	_stub.emit_signal("battle_ended", "lose", {})
	_hud.call("tick", 1.0)
	_hud.call("tick", 0.5)
	await _save("m2_battle_game_over.png")
