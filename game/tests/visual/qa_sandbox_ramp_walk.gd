extends SceneTree
## QA: can Red walk up the back ramp onto the back ledge, and reach the far ledge? Keyboard steering from the camera's view.
## Names no game classes. Prints QA PASS / QA FAIL lines. Run as the other visual QA scripts.

const MAIN_SCENE: String = "res://scenes/core/main.tscn"
const SHOTS: String = "res://../docs/screenshots/"


func _initialize() -> void:
	_run()


func _run() -> void:
	var main: Node = (load(MAIN_SCENE) as PackedScene).instantiate()
	root.add_child(main)
	var sandbox: Node = null
	for i: int in 600:
		await process_frame
		sandbox = get_first_node_in_group(&"combat_sandbox")
		if sandbox != null and sandbox.call("get_player") != null:
			break
	var player: Node3D = sandbox.call("get_player") as Node3D
	for enemy: Variant in sandbox.call("get_enemies") as Array:
		(enemy as Node3D).visible = false
		(enemy as Node3D).process_mode = Node.PROCESS_MODE_DISABLED
	await _frames(30)
	var steps: Array = [["ramp foot", Vector3(-9.0, 0.0, -10.0)], ["ramp top", Vector3(-9.0, 1.2, -15.0)], ["back ledge", Vector3(0.0, 1.2, -17.0)]]
	for step: Array in steps:
		var target: Vector3 = step[1] as Vector3
		var t0: float = float(Time.get_ticks_msec())
		while float(Time.get_ticks_msec()) - t0 < 12000.0:
			var pos: Vector3 = player.global_position
			if Vector2(pos.x - target.x, pos.z - target.z).length() < 0.9 and absf(pos.y - target.y) < 0.6:
				break
			_steer(player, sandbox, target)
			await process_frame
		_release()
		await _frames(10)
		var end: Vector3 = player.global_position
		var ok: bool = Vector2(end.x - target.x, end.z - target.z).length() < 1.2 and absf(end.y - target.y) < 0.6
		print(("QA PASS  " if ok else "QA FAIL  ") + "reaches the %s (at %s, wanted %s)" % [str(step[0]), str(end), str(target)])
	root.get_texture().get_image().save_png(SHOTS + "qa_sandbox_ramp_walk_end.png")
	quit(0)


func _frames(n: int) -> void:
	for i: int in n:
		await process_frame


func _cam_axes(sandbox: Node) -> Array:
	var cam: Camera3D = (sandbox.call("get_camera") as Object).call("get_camera") as Camera3D
	var f: Vector3 = -cam.global_transform.basis.z
	f.y = 0.0
	var r: Vector3 = cam.global_transform.basis.x
	r.y = 0.0
	return [f.normalized(), r.normalized()]


func _steer(player: Node3D, sandbox: Node, target: Vector3) -> void:
	var pos: Vector3 = player.global_position
	var d: Vector3 = Vector3(target.x - pos.x, 0.0, target.z - pos.z)
	var axes: Array = _cam_axes(sandbox)
	var f: float = d.dot(axes[0] as Vector3)
	var s: float = d.dot(axes[1] as Vector3)
	var lim: float = d.length() * 0.35
	_key(&"move_up", f > lim)
	_key(&"move_down", f < -lim)
	_key(&"move_right", s > lim)
	_key(&"move_left", s < -lim)


func _key(action: StringName, down: bool) -> void:
	if Input.is_action_pressed(action) == down:
		return
	var events: Array = InputMap.action_get_events(action)
	var source: InputEvent = null
	for event: InputEvent in events:
		if event is InputEventKey:
			source = event
			break
	if source == null:
		return
	var ev: InputEvent = source.duplicate() as InputEvent
	ev.set("pressed", down)
	Input.parse_input_event(ev)


func _release() -> void:
	for action: StringName in [&"move_up", &"move_down", &"move_left", &"move_right"]:
		_key(action, false)
