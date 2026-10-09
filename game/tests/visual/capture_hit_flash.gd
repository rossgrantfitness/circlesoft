extends SceneTree
## Screenshots of the white impact flash (Tuning v1.3, Ross: chunky hits), real renderer, real sandbox, real CombatFx:
##   hit_flash_before.png   the wolf just before the hit
##   hit_flash.png          mid-flash: the whole wolf flat opaque white
##   hit_flash_after.png    the flash is over and its own materials are back
##   hit_flash_before_after.png   the three side by side
##
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --path game --rendering-driver opengl3 \
##       -s res://tests/visual/capture_hit_flash.gd -- --out=/some/dir
##
## The software renderer is slow, so the FX clock is held for the grab and the flash is ended by hand afterwards. No game classes are named (this file compiles before the
## autoloads exist).

const SCREEN_SCENE: String = "res://scenes/core/psx_screen.tscn"
const SANDBOX_SCENE: String = "res://scenes/sandbox/combat_sandbox.tscn"

var _out: String = "/tmp"
var _screen: Node = null


func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.trim_prefix("--out=")
	await process_frame
	_screen = (load(SCREEN_SCENE) as PackedScene).instantiate()
	root.add_child(_screen)
	await _settle(2)
	var sandbox: Node = _screen.call("load_world", load(SANDBOX_SCENE) as PackedScene) as Node
	await _settle(40)
	var director: Node = sandbox.call("get_director") as Node
	var player: Node3D = sandbox.call("get_player") as Node3D
	var enemies: Array = sandbox.call("get_enemies") as Array
	var wolf: Node3D = enemies[0] as Node3D
	for enemy: Variant in enemies:
		(enemy as Node3D).set_physics_process(false)
		(enemy as Node3D).set_process(false)
	player.set_physics_process(false)
	player.set_process(false)
	var offset: Vector3 = Vector3(1.55, 0.0, -0.55)
	wolf.global_position = player.global_position + offset
	for enemy: Variant in enemies:
		if enemy != wolf:
			(enemy as Node3D).global_position = player.global_position + Vector3(-7.0, 0.0, -9.0)
	wolf.rotation = Vector3(0.0, atan2(-offset.x, -offset.z), 0.0)
	player.rotation = Vector3(0.0, atan2(offset.x, offset.z), 0.0)
	var fx: Node = _find_fx(sandbox)
	if fx == null:
		print("no CombatFx in the sandbox")
		quit(1)
		return
	await _settle(20)
	var before: Image = _grab()
	before.save_png("%s/hit_flash_before.png" % _out)
	# The software renderer is far slower than 60 fps, so the grab would miss a 0.07 s flash. Hold the FX clock (the flash only ends when
	# step() is called), land a real-looking heavy hit through the director, grab the frame, then let the flash run out.
	var duration: float = float(((fx.get("cfg") as Dictionary)["hit_flash"] as Dictionary)["duration_s"])
	fx.set_process(false)
	var hf: Object = fx.call("get_hit_flash")
	var point: Vector3 = wolf.global_position + Vector3(0.0, 0.7, 0.0)
	director.emit_signal("hit_landed", {"attacker": &"red", "target": wolf.get("actor_id"), "move_id": &"heavy", "outcome": "hit", "damage": 22,
			"launch": 0.0, "knockdown": false, "airborne": false, "hit_stop_ms": 250.0, "shake": "heavy", "spark": "heavy", "sfx": "combat_hit_heavy", "position": point})
	await _settle(3)
	var flashing: bool = bool(hf.call("is_flashing", wolf))
	print("flash duration ", duration, " s; flashing while grabbed: ", flashing)
	var during: Image = _grab()
	during.save_png("%s/hit_flash.png" % _out)
	print("mid-flash centre pixel ", during.get_pixel(during.get_width() / 2, during.get_height() / 2))
	fx.call("step", duration + 0.001)
	fx.set_process(true)
	await _settle(40)
	var after: Image = _grab()
	after.save_png("%s/hit_flash_after.png" % _out)
	print("flashing after: ", bool(fx.call("get_hit_flash").call("is_flashing", wolf)))
	# the strip: the middle of each frame, side by side
	var w: int = before.get_width()
	var h: int = before.get_height()
	var crop: Rect2i = Rect2i(w / 4, h / 8, w / 2, h * 3 / 4)
	var strip: Image = Image.create(crop.size.x * 3, crop.size.y, false, before.get_format())
	for index: int in 3:
		strip.blit_rect([before, during, after][index], crop, Vector2i(index * crop.size.x, 0))
	strip.save_png("%s/hit_flash_before_after.png" % _out)
	print("saved to ", _out)
	quit(0)


func _find_fx(node: Node) -> Node:
	if node.has_method("get_hit_flash"):
		return node
	for child: Node in node.get_children():
		var found: Node = _find_fx(child)
		if found != null:
			return found
	return null


func _grab() -> Image:
	return root.get_viewport().get_texture().get_image()


func _settle(frames: int) -> void:
	for i: int in frames:
		await process_frame
