extends TestCase
## Bot runs in the real combat sandbox (docs/pivot/enemy_ai_design.md): a scripted Red drives the real ActionPlayer
## (press / set_move_input) against the real enemies, and the runs show that
##   - a Grunt dodges sometimes but not always,
##   - the Brute's guard breaks on a Heavy (and a Light, Light, Heavy string is the way in),
##   - a low-health Grunt flees (and a hit on it knocks it down) or flanks (and its swing from behind is parryable),
##   - two enemies never land hits less than 450 ms apart.
## The sandbox runs in real time (60 physics steps a second), so each run stops as soon as it has seen what it
## came for. Enemy randomness is seeded from the actor ids.

const SANDBOX: String = "res://scenes/sandbox/combat_sandbox.tscn"
const FRAME: float = 1.0 / 60.0

var _sandbox: Node = null
var _director: CombatDirector = null
var _red: ActionPlayer = null
var _log: Array[Dictionary] = []


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


func _enemy(actor_id: String) -> ActionEnemy:
	return _director.get_actor(StringName(actor_id)) as ActionEnemy


func _place(actor: Node3D, at: Vector3, yaw_toward: Vector3 = Vector3.INF) -> void:
	actor.global_position = at
	if yaw_toward != Vector3.INF:
		var look: Vector3 = yaw_toward - at
		actor.rotation.y = atan2(look.x, look.z)


func _stick_toward(point: Vector3) -> void:
	var to: Vector3 = point - _red.global_position
	to.y = 0.0
	if to.length() < 0.05:
		_red.set_move_input(Vector2.ZERO)
		return
	var basis: Basis = _red._camera_basis()
	var dir: Vector3 = to.normalized()
	_red.set_move_input(Vector2(dir.dot(PlayerMotion.flat_right(basis)), -dir.dot(PlayerMotion.flat_forward(basis))))


func _dist(a: Node3D, b: Node3D) -> float:
	var d: Vector3 = a.global_position - b.global_position
	d.y = 0.0
	return d.length()


func _busy() -> bool:
	return _red.get_state() != ActionPlayer.State.LOCOMOTION


func _frames(seconds: float) -> int:
	return int(seconds / FRAME)


# ---- a Grunt dodges sometimes but not always ----

func test_a_grunt_dodges_some_heavies_but_not_all() -> void:
	await _boot(["grunt_1"])
	var grunt: ActionEnemy = _enemy("grunt_1")
	_director.feel.set_value("enemy_dodge_scale", 2.0)
	# Pin the studio's design chance (0.30): the shipped Kingdom Hearts tuning halves it, which would make a
	# 12-swing run depend on luck. This test is about the mechanic, not the tuned rate.
	(grunt.brain._defence._cfg as Dictionary)["dodge_chance"] = 0.30
	_place(_red, Vector3(-6.0, 0.1, 4.0), grunt.global_position)
	var tally: Dictionary = {"swings": 0, "threatened": 0, "dodges": 0, "hits": 0}
	var was_dodging: bool = false
	_red.move_started.connect(func(move_id: StringName) -> void:
		if move_id == &"heavy":
			tally["swings"] += 1
			if bool(_director.player_swing_info(grunt)["threat"]):
				tally["threatened"] += 1)
	_director.hit_landed.connect(func(info: Dictionary) -> void:
		if info["target"] == grunt.actor_id and info["move_id"] == &"heavy":
			tally["hits"] += 1)
	var next_swing_frame: int = 0
	for frame: int in range(_frames(75.0)):
		await tree.physics_frame
		# This run is about dodging, not about killing it. A grunt that dies respawns in its "react" state, where it cannot
		# defend at all (enemy_ai_design 2.1), which is what made the first version of this bot see so few dodges.
		grunt.hp = grunt.hp_max
		var dodging: bool = grunt.is_dodging()
		if dodging and not was_dodging:
			tally["dodges"] += 1
		was_dodging = dodging
		if int(tally["threatened"]) >= 12 and int(tally["dodges"]) >= 1 and int(tally["hits"]) >= 1:
			break
		if _busy():
			_red.set_move_input(Vector2.ZERO)
			continue
		var gap: float = _dist(_red, grunt)
		if gap > 1.9 or grunt.body_state != ActionEnemy.ST_FREE:
			_stick_toward(grunt.global_position)
		elif frame >= next_swing_frame:
			_red.set_move_input(Vector2.ZERO)
			_stick_toward(grunt.global_position)
			_red.play_move(&"heavy")                        # a slow swing the grunt can read (the combo has no Heavy button)
			next_swing_frame = frame + _frames(3.4)         # a dodge lasts ~0.6 s and then has a 2.5 s cooldown
			await tree.physics_frame
		else:
			_red.set_move_input(Vector2.ZERO)
	gdscript_print("heavies swung %d, threatened %d, dodged %d, connected %d" % [tally["swings"], tally["threatened"], tally["dodges"], tally["hits"]])
	assert_ge(int(tally["threatened"]), 6, "Red threw enough Heavies at it")
	assert_ge(int(tally["dodges"]), 2, "it dodged some (the roll is 60 percent here; the cooldown and fatigue take some off)")
	assert_ge(int(tally["hits"]), 1, "and at least one Heavy connected: it does not dodge everything")
	assert_lt(int(tally["dodges"]), int(tally["threatened"]), "never all of them")


func gdscript_print(text: String) -> void:
	print("      [bot] " + text)


# ---- the Brute's guard breaks on a Heavy ----

func test_the_brutes_guard_breaks_on_a_heavy_and_not_on_a_light() -> void:
	await _boot(["brute_5"])
	var brute: ActionEnemy = _enemy("brute_5")
	_director.feel.set_value("enemy_block_scale", 2.0)
	(brute.brain._defence._cfg as Dictionary)["block_chance"] = 0.45      # the studio's design chance; see the dodge test
	_place(_red, brute.global_position + Vector3(0.0, 0.0, 6.0), brute.global_position)
	var outcomes: Array[Dictionary] = []
	_director.hit_landed.connect(func(info: Dictionary) -> void:
		if info["target"] == brute.actor_id:
			outcomes.append({"move": info["move_id"], "outcome": info["outcome"]}))
	var broke_by_heavy: bool = false
	var step: int = 0
	var wait: int = 0
	var heavy_in: int = 0
	for frame: int in range(_frames(60.0)):
		await tree.physics_frame
		if brute.dead:
			brute.hp = brute.hp_max
		for entry: Dictionary in outcomes:
			if entry["outcome"] == &"guard_broken":
				broke_by_heavy = true
		if broke_by_heavy:
			break
		if heavy_in > 0:
			heavy_in -= 1
			if heavy_in == 0:
				_red.play_move(&"heavy")         # Light, Light, then the Heavy (the combo has no Heavy button)
			continue
		if _busy():
			continue
		if wait > 0:
			wait -= 1
			_red.set_move_input(Vector2.ZERO)
			continue
		if _dist(_red, brute) > 1.6:
			_stick_toward(brute.global_position)
			continue
		# Light, Light, then a Heavy thrown directly (the combo reaches its Heavy only as the sixth hit, long after a
		# guard has dropped on its own; tests/sim/test_combo_bots.gd covers that route with the guard held up)
		_red.set_move_input(Vector2.ZERO)
		_stick_toward(brute.global_position)
		match step % 2:
			0:
				_red.press(&"light")
				wait = 8                         # after Light 1 ends (the string lives on for 500 ms)
			1:
				_red.press(&"light")
				heavy_in = 10                    # 170 ms into Light 2, where the old chain window opened
				wait = _frames(1.4)
		step += 1
		await tree.physics_frame
		_red.release(&"light")
	var blocked: int = 0
	var broken_moves: Array[StringName] = []
	for entry: Dictionary in outcomes:
		if entry["outcome"] == &"blocked":
			blocked += 1
		if entry["outcome"] == &"guard_broken":
			broken_moves.append(entry["move"])
	gdscript_print("outcomes on the Brute: %s" % [outcomes.map(func(e: Dictionary) -> String: return "%s:%s" % [e["move"], e["outcome"]])])
	assert_gt(float(broken_moves.size()), 0.0, "a guard broke")
	for move: StringName in broken_moves:
		assert_has([&"heavy", &"launcher"], move, "only a Heavy or a Launcher breaks a fresh guard")
	assert_ge(blocked, 1, "and the Lights before it were blocked, not shrugged off")


# ---- a low-health Grunt flees, or flanks ----

func test_a_wounded_grunt_flees_and_red_can_run_it_down() -> void:
	await _boot(["grunt_1"])
	var grunt: ActionEnemy = _enemy("grunt_1")
	_director.feel.set_value("enemy_flank_on", false)
	_director.feel.set_value("enemies_attack", true)
	_place(grunt, Vector3(5.0, 0.1, 4.5))
	_place(_red, Vector3(5.0, 0.1, 8.0), grunt.global_position)
	grunt.hp = int(float(grunt.hp_max) * 0.3)
	var fled: bool = false
	var max_gap: float = 0.0
	var seen: Dictionary = {"knocked_down": false, "was_fleeing": false}
	var token_while_fleeing: bool = false
	_director.hit_landed.connect(func(info: Dictionary) -> void:
		if info["target"] == grunt.actor_id and bool(info["knockdown"]) and bool(seen["was_fleeing"]):
			seen["knocked_down"] = true)
	var dashed: bool = false
	for frame: int in range(_frames(14.0)):
		await tree.physics_frame
		seen["was_fleeing"] = grunt.brain.is_fleeing()
		if grunt.brain.is_fleeing():
			fled = true
			max_gap = maxf(max_gap, _dist(_red, grunt))
			if _director.tokens.has_token(grunt.actor_id):
				token_while_fleeing = true
		if bool(seen["knocked_down"]):
			break
		if _busy():
			continue
		if not fled:
			_red.set_move_input(Vector2.ZERO)
			continue
		var gap: float = _dist(_red, grunt)
		_stick_toward(grunt.global_position)
		if gap > 3.0 and not dashed and gap < 6.0:
			_red.press(&"dash")
			dashed = true
			await tree.physics_frame
			_red.release(&"dash")
		elif gap < 1.5:
			_red.press(&"light")
			await tree.physics_frame
			_red.release(&"light")
	var knocked_down: bool = bool(seen["knocked_down"])
	gdscript_print("fled %s, furthest %.1f m, knocked down %s" % [fled, max_gap, knocked_down])
	assert_true(fled, "under 40% health it ran")
	assert_gt(max_gap, 2.5, "it got away from her")
	assert_false(token_while_fleeing, "a fleeing enemy holds no attack token")
	assert_true(knocked_down, "Red caught it, and a hit on a fleeing Grunt is always a knockdown")


func test_a_wounded_grunt_flanks_to_her_back_and_the_swing_is_parryable() -> void:
	await _boot(["grunt_1"])
	var grunt: ActionEnemy = _enemy("grunt_1")
	_director.feel.set_value("enemy_flee_on", false)
	_director.feel.set_value("enemies_attack", true)
	_place(grunt, Vector3(6.0, 0.1, 4.5))
	_place(_red, Vector3(4.0, 0.1, 8.0), grunt.global_position)
	grunt.hp = int(float(grunt.hp_max) * 0.3)
	var telegraphs: Array[Dictionary] = []
	_director.telegraphed.connect(func(info: Dictionary) -> void: telegraphs.append(info))
	var judged: Array[Dictionary] = []
	_director.parry_judged.connect(func(info: Dictionary) -> void: judged.append(info))
	var reached_rear: bool = false
	var started_flank: bool = false
	var pressed_parry: bool = false
	var impact_at_usec: int = 0
	for frame: int in range(_frames(14.0)):
		await tree.physics_frame
		if grunt.brain.is_flanking():
			started_flank = true
		var angle: float = EnemyRules.relative_angle_deg(_red.global_position, _red.forward(), grunt.global_position)
		if started_flank and EnemyRules.in_rear_arc(angle, 120.0):
			reached_rear = true
		if not telegraphs.is_empty() and not pressed_parry:
			# Red does not turn: she waits for the flash and parries about 120 ms before the hit
			impact_at_usec = grunt.clock.now_usec() + int(float(telegraphs[0]["impact_in_ms"]) * 1000.0) if impact_at_usec == 0 else impact_at_usec
			var left_ms: float = float(impact_at_usec - grunt.clock.now_usec()) / 1000.0
			if left_ms <= 110.0 and not _busy():
				_red.press(&"parry")
				pressed_parry = true
				await tree.physics_frame
				_red.release(&"parry")
		if not judged.is_empty():
			break
	gdscript_print("flanked %s, rear %s, telegraph %s, parry %s" % [started_flank, reached_rear, telegraphs.map(func(t: Dictionary) -> String: return "%s %.0f ms" % [t["move_id"], t["impact_in_ms"]]), judged.map(func(j: Dictionary) -> String: return str(j["rating"]))])
	assert_true(started_flank, "under 40% health it went for her back")
	assert_true(reached_rear, "and got into the 120 degrees behind her")
	assert_false(telegraphs.is_empty(), "then swung")
	assert_eq(telegraphs[0]["move_id"], &"swipe_flank")
	assert_ge(float(telegraphs[0]["impact_in_ms"]), 650.0, "she has 650 ms or more to react to a hit from behind")
	assert_false(judged.is_empty(), "her parry was judged")
	assert_ne(judged[0]["rating"], "miss", "a fair window: pressing 110 ms before the hit parries it")


# ---- two enemies never land hits less than 450 ms apart ----

func test_enemies_never_land_hits_less_than_450_ms_apart() -> void:
	await _boot(["grunt_1", "grunt_2", "grunt_3", "grunt_4", "brute_5"])
	_director.feel.set_value("enemies_attack", true)
	_director.feel.set_value("enemy_aggression", 2.0)
	_red.hp = 99999
	_red.hp_max = 99999
	for enemy: Node3D in _sandbox.call("get_enemies"):
		if not enemy.is_queued_for_deletion():
			_place(enemy, Vector3(enemy.global_position.x * 0.3, 0.1, enemy.global_position.z * 0.3 + 3.0))
	_place(_red, Vector3(0.0, 0.1, 6.0), Vector3(0.0, 0.1, 0.0))
	var hits: Array[Dictionary] = []
	_director.hit_landed.connect(func(info: Dictionary) -> void:
		if info["target"] == &"red" and int(info["damage"]) > 0:
			hits.append({"by": info["attacker"], "at_ms": float(_director.stamp_usec()) / 1000.0, "move": info["move_id"]}))
	var min_gap: float = 99999.0
	var frames: int = 0
	var attackers: Dictionary = {}
	while frames < _frames(45.0):
		await tree.physics_frame
		frames += 1
		# Red just stands there, getting up and brushing herself off if she was knocked down
		_red.set_move_input(Vector2.ZERO)
		if hits.size() >= 14 and attackers.size() >= 2:
			break
		for hit: Dictionary in hits:
			attackers[hit["by"]] = true
	for i: int in range(1, hits.size()):
		var gap: float = float(hits[i]["at_ms"]) - float(hits[i - 1]["at_ms"])
		if hits[i]["by"] != hits[i - 1]["by"]:
			min_gap = minf(min_gap, gap)
	gdscript_print("%d hits from %s, closest pair from different enemies %.0f ms apart" % [hits.size(), attackers.keys(), min_gap])
	assert_ge(hits.size(), 6, "they kept attacking")
	assert_ge(attackers.size(), 2, "more than one enemy landed hits")
	assert_ge(min_gap, 450.0, "no two enemies' hits closer than 450 ms")
