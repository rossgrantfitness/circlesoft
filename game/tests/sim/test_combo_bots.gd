extends TestCase
## Bot runs in the real combat sandbox for the one-button combo (docs/pivot/kh_combo_design.md CS-22).
## A scripted Red mashes ONE button (`light`) and the situation picks every move:
##   - a far target gets a lunge,
##   - a close one a grounded string, ending in the launcher and then an air string that follows it up,
##   - a guarding Brute gets five Lights and the Heavy slam, never the launcher,
##   - a crowd gets the Sweep,
##   - and the second button only pops up "Hack: coming later".
## The sandbox runs in real time (60 physics steps a second), so each run stops as soon as it has seen what it came
## for. The enemies do not attack and do not defend (their dodge and block sliders are 0), so a run is about Red.

const SANDBOX: String = "res://scenes/sandbox/combat_sandbox.tscn"
const FRAME: float = 1.0 / 60.0
const MASH_EVERY_FRAMES: int = 6
## Open floor in the sandbox (the pillars, ledges and ramp are elsewhere): Red stands here facing -Z, enemies in front of her.
const RED_AT: Vector3 = Vector3(4.0, 0.1, 12.0)

var _sandbox: Node = null
var _director: CombatDirector = null
var _red: ActionPlayer = null
var _moves: Array[StringName] = []
var _hits: Array[Dictionary] = []


## Boots the real sandbox and keeps only the enemies named in `keep` (actor ids); a bot run owns the arena.
func _boot(keep: Array[String]) -> void:
	_sandbox = (load(SANDBOX) as PackedScene).instantiate()
	add_to_root(_sandbox)
	for i: int in range(3):
		await tree.physics_frame
	_director = _sandbox.call("get_director") as CombatDirector
	_red = _sandbox.call("get_player") as ActionPlayer
	assert_not_null(_director, "the sandbox has a director")
	assert_not_null(_red, "and Red")
	_red.read_engine_input = false
	for enemy: Node3D in _sandbox.call("get_enemies"):
		if not keep.has(String((enemy as ActionEnemy).actor_id)):
			enemy.queue_free()
	await tree.physics_frame
	_director.feel.set_value("enemies_attack", false)
	_director.feel.set_value("enemy_dodge_scale", 0.0)
	_director.feel.set_value("enemy_block_scale", 0.0)
	_moves.clear()
	_hits.clear()
	_red.move_started.connect(func(move_id: StringName) -> void: _moves.append(move_id))
	_director.hit_landed.connect(func(info: Dictionary) -> void: _hits.append(info))


func _enemy(actor_id: String) -> ActionEnemy:
	return _director.get_actor(StringName(actor_id)) as ActionEnemy


func _place(actor: Node3D, at: Vector3, yaw_toward: Vector3 = Vector3.INF) -> void:
	actor.global_position = at
	if yaw_toward != Vector3.INF:
		var look: Vector3 = yaw_toward - at
		actor.rotation.y = atan2(look.x, look.z)


## Puts Red on the open floor facing -Z and enemies `ahead` metres in front of her (+ `side` metres to the right), then lets everyone settle.
func _stage(placements: Array) -> void:
	_place(_red, RED_AT, RED_AT + Vector3(0.0, 0.0, -1.0))
	for entry: Array in placements:
		_place(entry[0] as Node3D, RED_AT + Vector3(float(entry[2]), 0.0, -float(entry[1])), RED_AT)
	for i: int in range(10):
		await tree.physics_frame


func _dist(a: Node3D, b: Node3D) -> float:
	var d: Vector3 = a.global_position - b.global_position
	d.y = 0.0
	return d.length()


func _frames(seconds: float) -> int:
	return int(seconds / FRAME)


func _hits_by(move_id: StringName) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for info: Dictionary in _hits:
		if info["move_id"] == move_id:
			out.append(info)
	return out


## Runs up to `seconds`, pressing the attack button every few frames and nothing else, until `done` says stop.
## Red never walks: the combo has to close the gap itself. `each_frame` (optional) is called every frame, for staging.
func _mash(seconds: float, done: Callable, each_frame: Callable = Callable()) -> void:
	var since_press: int = MASH_EVERY_FRAMES
	for frame: int in range(_frames(seconds)):
		await tree.physics_frame
		for enemy: Node3D in _sandbox.call("get_enemies"):
			if is_instance_valid(enemy) and (enemy as ActionEnemy).dead:
				(enemy as ActionEnemy).hp = (enemy as ActionEnemy).hp_max       # this run is about Red's moves, not kills
		if each_frame.is_valid():
			each_frame.call()
		if bool(done.call()):
			return
		since_press += 1
		_red.release(&"light")
		if since_press >= MASH_EVERY_FRAMES:
			_red.press(&"light")
			since_press = 0


# ---- a lunge on a far target ----

func test_mashing_the_attack_button_lunges_at_a_far_target() -> void:
	await _boot(["grunt_1"])
	var grunt: ActionEnemy = _enemy("grunt_1")
	await _stage([[grunt, 6.0, 0.0]])
	var start_gap: float = _dist(_red, grunt)
	_red.press(&"light")
	var gap_after_lunge: float = 99.0
	for frame: int in range(_frames(0.5)):
		await tree.physics_frame
		_red.release(&"light")
		gap_after_lunge = minf(gap_after_lunge, _dist(_red, grunt))
	print("      [bot] lunge: gap %.1f m -> %.1f m, moves %s" % [start_gap, gap_after_lunge, _moves])
	assert_gt(start_gap, 5.0, "the grunt started far away")
	assert_eq(_moves[0] if not _moves.is_empty() else &"", &"lunge", "the first press lunges")
	assert_lt(gap_after_lunge, 3.0, "and the lunge closed most of the gap")
	assert_gt(float(_hits_by(&"lunge").size()), 0.0, "the thrust connected")


func test_a_lunge_counts_as_hit_one_so_the_string_goes_on_with_light_2() -> void:
	await _boot(["grunt_1"])
	var grunt: ActionEnemy = _enemy("grunt_1")
	await _stage([[grunt, 7.0, 0.0]])
	await _mash(4.0, func() -> bool: return _moves.size() >= 4)
	print("      [bot] far string: %s" % [_moves])
	assert_eq(_moves.slice(0, 4), [&"lunge", &"light_2", &"light_3", &"launcher"] as Array[StringName])


# ---- a grounded string, the launcher and the air string ----

func test_mashing_one_button_runs_the_string_then_launches_and_follows_up_with_an_air_string() -> void:
	await _boot(["grunt_1"])
	var grunt: ActionEnemy = _enemy("grunt_1")
	await _stage([[grunt, 2.0, 0.0]])
	var seen: Dictionary = {"airborne_at_air_1": false}       # a lambda copies plain variables, so share a Dictionary
	_red.move_started.connect(func(move_id: StringName) -> void:
		if move_id == &"air_1":
			seen["airborne_at_air_1"] = grunt.is_airborne())
	await _mash(8.0, func() -> bool: return _moves.has(&"air_3"))
	print("      [bot] string: %s" % [_moves])
	assert_eq(_moves.slice(0, 7), [&"light_1", &"light_2", &"light_3", &"launcher", &"air_1", &"air_2", &"air_3"] as Array[StringName],
			"three Lights, the launcher, then three air hits")
	assert_gt(float(_hits_by(&"launcher").size()), 0.0, "the launcher connected")
	assert_true(bool(seen["airborne_at_air_1"]), "the grunt was in the air when the air string began")
	var air_hits: int = _hits_by(&"air_1").size() + _hits_by(&"air_2").size() + _hits_by(&"air_3").size()
	assert_gt(float(air_hits), 1.0, "the air string kept hitting the juggled grunt")


# ---- the guard-break route on a Brute ----

func test_a_brute_gets_five_lights_and_the_heavy_slam_never_the_launcher() -> void:
	await _boot(["brute_5"])
	var brute: ActionEnemy = _enemy("brute_5")
	await _stage([[brute, 2.2, 0.0]])
	await _mash(10.0, func() -> bool: return _moves.has(&"heavy"))
	print("      [bot] brute: %s" % [_moves])
	assert_eq(_moves.slice(0, 6), [&"light_1", &"light_2", &"light_3", &"light_1", &"light_2", &"heavy"] as Array[StringName])
	assert_false(_moves.has(&"launcher"), "a Brute cannot be launched, so no launcher is wasted on it")
	await tree.physics_frame
	var slam_hits: Array[Dictionary] = _hits_by(&"heavy")
	for i: int in range(_frames(1.0)):
		if not slam_hits.is_empty():
			break
		await tree.physics_frame
		slam_hits = _hits_by(&"heavy")
	assert_false(slam_hits.is_empty(), "the slam connected")
	var outcome: StringName = slam_hits[0]["outcome"] if not slam_hits.is_empty() else &""
	assert_has([&"guard_broken", &"stagger", &"armored", &"hit"], outcome)


func test_a_raised_guard_is_broken_by_the_slam_and_never_by_a_light_or_a_launcher() -> void:
	await _boot(["brute_5"])
	var brute: ActionEnemy = _enemy("brute_5")
	await _stage([[brute, 3.0, 0.0]])
	# Hold the Brute's guard up through the whole string: a test of the route into a guard, not of its blocking luck.
	# (The enemy data is shared between tests, so each value is put back afterwards.)
	var defend: Dictionary = brute.brain._defence._cfg as Dictionary
	var guard: Dictionary = brute.brain._beh["guard"] as Dictionary
	var saved_defend: Dictionary = defend.duplicate(true)
	var saved_guard: Dictionary = guard.duplicate(true)
	defend["block_chance"] = 1.0
	defend["block_cooldown_ms"] = 0
	guard["max_in_row"] = 99
	guard["hold_ms"] = [20000, 20000]
	guard["drop_after_threat_ms"] = 20000
	_director.feel.set_value("enemy_block_scale", 3.0)
	for i: int in range(_frames(1.5)):
		await tree.physics_frame                  # let it notice her and settle into its circling
	var broken: Array[StringName] = []
	await _mash(12.0, func() -> bool:
		for info: Dictionary in _hits:
			if info["outcome"] == &"guard_broken" and not broken.has(info["move_id"]):
				broken.append(info["move_id"])
		return not broken.is_empty())
	defend.merge(saved_defend, true)
	guard.merge(saved_guard, true)
	var outcomes: Array[String] = []
	var blocked: int = 0
	for info: Dictionary in _hits:
		outcomes.append("%s:%s" % [info["move_id"], info["outcome"]])
		if info["outcome"] == &"blocked":
			blocked += 1
	print("      [bot] guarded brute: %s  moves %s" % [outcomes, _moves.slice(0, 6)])
	assert_gt(float(blocked), 0.0, "the Lights bounced off the raised guard")
	assert_eq(broken, [&"heavy"] as Array[StringName], "the guard broke, and the slam did it")
	assert_false(_moves.has(&"launcher"), "no launcher was thrown at a Brute")


# ---- the sweep when crowded ----

func test_three_enemies_close_get_the_sweep_instead_of_the_launcher() -> void:
	await _boot(["grunt_1", "grunt_2", "grunt_3"])
	var grunts: Array[ActionEnemy] = [_enemy("grunt_1"), _enemy("grunt_2"), _enemy("grunt_3")]
	await _stage([[grunts[0], 1.8, 0.0], [grunts[1], 0.5, 1.6], [grunts[2], 0.5, -1.6]])
	# A string walks Red forward after the first grunt, and grunts circle at 2 to 4.5 m, so the two on her flanks are
	# kept beside her (that is the "crowd": three within the near radius).
	var keep_beside: Callable = func() -> void:
		var right: Vector3 = Vector3.LEFT.rotated(Vector3.UP, _red.rotation.y + PI)     # her right-hand side on the floor
		var forward: Vector3 = _red.get_facing()
		for i: int in [1, 2]:
			var side: float = 1.6 if i == 1 else -1.6
			grunts[i].global_position = _red.global_position + right * side + forward * 0.5
			grunts[i].velocity = Vector3.ZERO
	await _mash(6.0, func() -> bool: return _moves.has(&"sweep") or _moves.has(&"launcher"), keep_beside)
	print("      [bot] crowd: %s" % [_moves])
	assert_eq(_moves.slice(0, 4), [&"light_1", &"light_2", &"light_3", &"sweep"] as Array[StringName])
	await _mash(1.0, func() -> bool: return not _hits_by(&"sweep").is_empty(), keep_beside)
	var struck: Dictionary = {}
	for info: Dictionary in _hits_by(&"sweep"):
		struck[info["target"]] = true
	print("      [bot] the sweep hit %s" % [struck.keys()])
	assert_ge(float(struck.size()), 2.0, "the spin hit more than one of them")


func test_two_enemies_close_are_not_a_crowd_and_get_the_launcher() -> void:
	await _boot(["grunt_1", "grunt_2"])
	var grunts: Array[ActionEnemy] = [_enemy("grunt_1"), _enemy("grunt_2")]
	await _stage([[grunts[0], 1.8, 0.0], [grunts[1], 0.5, 1.6]])
	var keep_beside: Callable = func() -> void:
		var right: Vector3 = Vector3.LEFT.rotated(Vector3.UP, _red.rotation.y + PI)
		grunts[1].global_position = _red.global_position + right * 1.6 + _red.get_facing() * 0.5
		grunts[1].velocity = Vector3.ZERO
	await _mash(6.0, func() -> bool: return _moves.has(&"sweep") or _moves.has(&"launcher"), keep_beside)
	assert_eq(_moves.slice(0, 4), [&"light_1", &"light_2", &"light_3", &"launcher"] as Array[StringName])


# ---- the second button ----

func test_the_hack_button_only_shows_the_call_out_in_the_sandbox() -> void:
	await _boot(["grunt_1"])
	var texts: Array[String] = []
	_red.hack_pressed.connect(func(info: Dictionary) -> void: texts.append(str(info["text"])))
	var grunt: ActionEnemy = _enemy("grunt_1")
	await _stage([[grunt, 2.0, 0.0]])
	_red.press(&"heavy")
	for frame: int in range(_frames(0.6)):
		await tree.physics_frame
		_red.release(&"heavy")
	assert_eq(texts, ["Hack: coming later"] as Array[String])
	assert_eq(_moves, [] as Array[StringName], "no attack started")
	assert_eq(_hits.size(), 0)
