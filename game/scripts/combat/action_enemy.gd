class_name ActionEnemy
extends CombatActor
## A sandbox enemy (the Grunt or the Brute), driven by data/combat/enemies.json and moves.json.
## The EnemyBrain decides, the MoveRunner plays the attack on this fighter's own clock (so hit-stop and the
## Lamp Flare slow it correctly), the Hitbox does the damage, and the body reacts to hits with a small
## state machine: free, hurt, stagger, recoil, launched, down, getting up, dead. Reactions are procedural
## (a lean, a tumble, a flash) so a blockout works today and Ross's rigged model drops in later by path.
##
## Everything per-frame is in tick(delta); _physics_process only calls it, so tests can step it by hand.

const ENEMIES_FILE: String = "enemies.json"
const DEFAULT_RESPAWN_S: float = 6.0
const FACE_TURN_EPS: float = 0.02
const KNOCK_DECAY: float = 12.0
const AIR_DRAG: float = 1.5
const ST_FREE: StringName = &"free"
const ST_HURT: StringName = &"hurt"
const ST_STAGGER: StringName = &"stagger"
const ST_RECOIL: StringName = &"recoil"
const ST_LAUNCHED: StringName = &"launched"
const ST_DOWN: StringName = &"down"
const ST_GETUP: StringName = &"getup"
const ST_DEAD: StringName = &"dead"

@export var enemy_id: StringName = &"grunt"
@export var rng_seed: int = 0

var data: Dictionary = {}
var brain: EnemyBrain = null
var runner: MoveRunner = null
var spawn_position: Vector3 = Vector3.ZERO
var spawn_yaw: float = 0.0
var body_state: StringName = ST_FREE
var model_root: Node3D = null
## Pose of the last intent, for tests and the debug overlay.
var last_intent: Dictionary = {}
var test_target: CombatActor = null        ## tests may aim an enemy at a stand-in; normally the player

var _moves: MoveSet = null
var _hit_feel: Dictionary = {}
var _state_ms: float = 0.0
var _stun_ms: float = 0.0
var _knock: Vector3 = Vector3.ZERO
var _knockdown_on_land: bool = false
var _slam: bool = false
var _move_start_usec: int = 0
var _prev_move_ms: float = 0.0
var _dead_real_s: float = 0.0
var _respawn_s: float = DEFAULT_RESPAWN_S
var _anim: AnimationPlayer = null
var _overlay: StandardMaterial3D = null
var _overlay_meshes: Array[MeshInstance3D] = []
var _flash: float = 0.0
var _telegraph_left_ms: float = 0.0
var _telegraph_color: Color = Color(1.0, 0.3, 0.2)
var _current_clip: StringName = &""
var _pitch: float = 0.0
var _drop: float = 0.0
var _visual_kind: String = ""


func _ready() -> void:
	_load_data()
	super._ready()
	spawn_position = global_position
	spawn_yaw = rotation.y
	_build_body_shape()
	_build_visual()
	brain = EnemyBrain.create(data, rng_seed if rng_seed != 0 else hash(String(actor_id)))
	runner = MoveRunner.create(_moves, move_set_id)
	set_physics_process(true)


func _physics_process(delta: float) -> void:
	tick(delta)


## What the visual ended up being: "model", "fallback" or "blockout" (for tests and the debug overlay).
func visual_kind() -> String:
	return _visual_kind


func current_swing_id() -> int:
	return runner.swing_id() if runner != null else 0


func is_invulnerable() -> bool:
	return body_state == ST_GETUP or body_state == ST_DEAD


func is_armored() -> bool:
	if body_state != ST_FREE and body_state != ST_HURT:
		return false
	return bool(data.get("base_armor", false)) or (runner != null and runner.armor_active())


func is_attacking() -> bool:
	return runner != null and runner.is_busy()


# ---- per-frame ----

func tick(delta: float) -> void:
	if runner == null:
		return
	var director: CombatDirector = find_director()
	if director == null:
		clock.step(int(roundf(delta * 1000000.0)), 1.0)
	var dt: float = local_delta(delta)
	if body_state == ST_DEAD:
		_tick_dead(delta)
		return
	if dt <= 0.0:
		return
	_state_ms += dt * 1000.0
	_stun_ms = maxf(_stun_ms - dt * 1000.0, 0.0)
	get_hitbox().tick(dt)
	tick_poise(dt)
	var now_ms: float = clock.now_ms()
	match body_state:
		ST_FREE:
			_tick_free(dt, now_ms, director)
		ST_HURT, ST_STAGGER, ST_RECOIL:
			_tick_stun(dt)
		ST_LAUNCHED:
			_tick_launched(dt)
		ST_DOWN, ST_GETUP:
			_tick_down(dt)
	_update_visual(dt)
	slide_scaled(dt / delta if delta > 0.0 else 1.0)


func _target() -> CombatActor:
	if test_target != null:
		return test_target
	var director: CombatDirector = find_director()
	return director.player() if director != null else null


func _tick_free(dt: float, now_ms: float, director: CombatDirector) -> void:
	var target: CombatActor = _target()
	var to_target: Vector3 = Vector3.ZERO
	var dist: float = 999.0
	if target != null:
		to_target = target.global_position - global_position
		to_target.y = 0.0
		dist = to_target.length()
	var dir_to: Vector3 = to_target.normalized() if dist > 0.001 else forward()
	_apply_gravity(dt)
	if runner.is_busy():
		_tick_attack(dt, dir_to, target != null)
		return
	var tokens: AttackTokens = director.tokens if director != null else null
	var has_token: bool = tokens != null and tokens.has_token(actor_id)
	var enabled: bool = director.feel.get_b("enemies_attack") if director != null else true
	var view: Dictionary = {"dist_to_player": dist, "player_airborne": target != null and target.is_airborne(),
			"player_attacking": false, "has_token": has_token, "state": EnemyBrain.FREE,
			"poise_frac": poise / poise_max if poise_max > 0.0 else 1.0, "attacks_enabled": enabled and target != null and not target.dead}
	var intent: Dictionary = brain.step(now_ms, view)
	last_intent = intent
	if bool(intent["want_token"]) and not has_token and tokens != null:
		if tokens.request(actor_id):
			brain.notify(&"token_granted")
	elif not bool(intent["want_token"]) and has_token and tokens != null and brain.state() != EnemyBrain.ATTACK:
		tokens.release(actor_id)
	if target != null and bool(intent["face_player"]):
		_turn_toward(dir_to, dt)
	var wanted: Vector3 = _world_move(intent["move_dir"], dir_to) * float(data.get("move_speed_mps", 2.8))
	velocity.x = move_toward(velocity.x, wanted.x, 30.0 * dt)
	velocity.z = move_toward(velocity.z, wanted.z, 30.0 * dt)
	if StringName(intent["start_move"]) != &"":
		_start_attack(StringName(intent["start_move"]))


func _tick_attack(dt: float, dir_to: Vector3, has_target: bool) -> void:
	var intent_face: bool = bool(last_intent.get("face_player", false))
	# the brain keeps deciding whether to keep tracking during the wind-up
	if has_target:
		var view: Dictionary = {"dist_to_player": 0.0, "player_airborne": false, "player_attacking": false,
				"has_token": true, "state": EnemyBrain.FREE, "poise_frac": 1.0, "attacks_enabled": true}
		last_intent = brain.step(clock.now_ms(), view)
		intent_face = bool(last_intent.get("face_player", false))
	if has_target and intent_face:
		_turn_toward(dir_to, dt)
	var now: int = clock.now_usec()
	var events: Array[Dictionary] = runner.step(now)
	_handle_events(events)
	if runner.is_busy():
		var ms: float = runner.elapsed_ms()
		var lunge_m: float = runner.forward_between(_prev_move_ms, ms)
		_prev_move_ms = ms
		var along: Vector3 = forward() * (lunge_m / maxf(dt, 0.0001))
		velocity.x = along.x
		velocity.z = along.z
	else:
		velocity.x = 0.0
		velocity.z = 0.0


func _handle_events(events: Array[Dictionary]) -> void:
	var director: CombatDirector = find_director()
	for event: Dictionary in events:
		match String(event["type"]):
			"telegraph":
				_telegraph_left_ms = maxf(float(runner.data().get("impact_ms", 0.0)) - float(event["t_ms"]), 0.0)
				if director != null:
					director.telegraph(self, runner.current_move(), _move_start_usec + int(float(runner.data().get("impact_ms", 0.0)) * 1000.0))
			"swing":
				if director != null:
					director.notify_move_started(self, runner.current_move(), event.get("swing", {}))
			"hitbox_on":
				get_hitbox().activate(event["box"], runner.attack_data(), runner.swing_id())
			"hitbox_off":
				get_hitbox().deactivate(int(event["index"]))
			"interrupted":
				get_hitbox().clear()
			"pose":
				_play_pose(StringName(event["clip"]), float(event["clip_s"]))
			"done":
				get_hitbox().clear()
				_telegraph_left_ms = 0.0
				if director != null and director.tokens != null:
					director.tokens.release(actor_id)
				brain.notify(&"move_finished")


func _start_attack(move_id: StringName) -> void:
	if not runner.start(move_id, clock.now_usec()):
		push_warning("ActionEnemy %s: unknown move %s" % [actor_id, move_id])
		brain.notify(&"move_finished")
		return
	_move_start_usec = clock.now_usec()
	_prev_move_ms = 0.0
	_handle_events(runner.step(clock.now_usec()))


func _tick_stun(dt: float) -> void:
	_apply_gravity(dt)
	var decay: float = exp(-KNOCK_DECAY * dt)
	_knock *= decay
	velocity.x = _knock.x
	velocity.z = _knock.z
	if _stun_ms <= 0.0:
		_set_state(ST_FREE)
		velocity.x = 0.0
		velocity.z = 0.0


func _tick_launched(dt: float) -> void:
	var director: CombatDirector = find_director()
	var juggle: float = director.feel.get_f("juggle_float") if director != null else 1.0
	var gravity: float = float(_hit_feel.get("gravity_mps2", 26.0)) * JuggleRules.gravity_scale_after_hit(ms_since_air_hit(), juggle, _hit_feel.get("juggle", {}))
	velocity.y -= gravity * dt
	_knock *= exp(-AIR_DRAG * dt)
	velocity.x = _knock.x
	velocity.z = _knock.z
	if _state_ms > 80.0 and is_on_floor() and velocity.y <= 0.0:
		_land()


func _tick_down(dt: float) -> void:
	_apply_gravity(dt)
	velocity.x = move_toward(velocity.x, 0.0, 40.0 * dt)
	velocity.z = move_toward(velocity.z, 0.0, 40.0 * dt)
	var reaction: Dictionary = _hit_feel.get("reaction", {})
	if body_state == ST_DOWN and _state_ms >= float(reaction.get("knockdown_ms", 900.0)):
		_set_state(ST_GETUP)
	elif body_state == ST_GETUP and _state_ms >= float(reaction.get("getup_ms", 600.0)):
		_set_state(ST_FREE)
		brain.notify(&"landed")


func _tick_dead(real_delta: float) -> void:
	_dead_real_s += real_delta
	_apply_gravity(real_delta)
	velocity.x = 0.0
	velocity.z = 0.0
	slide_scaled(1.0)
	_update_visual(real_delta)
	if _dead_real_s >= _respawn_s:
		respawn()


func respawn() -> void:
	global_position = spawn_position
	rotation.y = spawn_yaw
	velocity = Vector3.ZERO
	revive(true)
	_dead_real_s = 0.0
	_knock = Vector3.ZERO
	_set_state(ST_FREE)
	brain = EnemyBrain.create(data, rng_seed if rng_seed != 0 else hash(String(actor_id)))
	runner.interrupt()
	get_hitbox().clear()
	get_hurtbox().collision_layer = CombatLayers.bit(CombatLayers.hurtbox_layer(team))
	collision_layer = CombatLayers.bit(CombatLayers.body_layer(team))
	if model_root != null:
		model_root.visible = true


# ---- being hit ----

func _on_hit_reaction(result: Dictionary) -> void:
	var outcome: StringName = result.get("outcome", &"hit")
	_flash = 1.0
	if outcome == HitResolver.OUTCOME_ARMORED or outcome == HitResolver.OUTCOME_EVADED:
		return
	if body_state == ST_DEAD:
		return
	if body_state == ST_GETUP:
		return
	_cut_attack()
	var launch: float = float(result.get("launch_mps", 0.0))
	var push: Vector3 = result.get("knockback", Vector3.ZERO)
	var stagger: bool = outcome == HitResolver.OUTCOME_STAGGER
	if launch > 0.0:
		velocity.y = launch
		_knock = push * KNOCK_DECAY * 0.35
		_knockdown_on_land = true
		_set_state(ST_LAUNCHED)
		brain.notify(&"launched")
		return
	if body_state == ST_LAUNCHED:
		# an air hit with no lift left, or a slam
		_knock = push * KNOCK_DECAY * 0.35
		if bool(result.get("knockdown", false)):
			velocity.y = -float((_hit_feel.get("reaction", {}) as Dictionary).get("slam_down_mps", 18.0))
			_slam = true
		return
	if bool(result.get("knockdown", false)):
		_knock = push * KNOCK_DECAY
		_set_state(ST_DOWN)
		brain.notify(&"hit")
		return
	var stun: float = float(result.get("hitstun_ms", 0.0))
	_knock = push * KNOCK_DECAY
	if body_state == ST_STAGGER or body_state == ST_RECOIL:
		_stun_ms = maxf(_stun_ms, stun)
	else:
		_stun_ms = stun
		_set_state(ST_STAGGER if stagger else ST_HURT)
	brain.notify(&"staggered" if stagger else &"hit")


func _on_parried(result: Dictionary) -> void:
	if body_state == ST_DEAD:
		return
	_cut_attack()
	var parry: Dictionary = _hit_feel.get("parry", {})
	var perfect: bool = result.get("outcome", &"") == HitResolver.OUTCOME_PERFECT_PARRY
	_stun_ms = float(parry.get("stagger_ms", 1500.0)) if perfect else float(parry.get("recoil_ms", 700.0))
	_knock = Vector3.ZERO
	_flash = 1.0
	_set_state(ST_STAGGER if perfect else ST_RECOIL)
	brain.notify(&"staggered" if perfect else &"parried")


func _on_death(_result: Dictionary) -> void:
	_cut_attack()
	_set_state(ST_DEAD)
	_dead_real_s = 0.0
	get_hurtbox().collision_layer = 0
	collision_layer = 0
	var director: CombatDirector = find_director()
	if director != null and director.tokens != null:
		director.tokens.release(actor_id)


func _cut_attack() -> void:
	if runner != null and runner.is_busy():
		runner.interrupt()
	get_hitbox().clear()
	_telegraph_left_ms = 0.0
	var director: CombatDirector = find_director()
	if director != null and director.tokens != null:
		director.tokens.release(actor_id)


func _land() -> void:
	juggle_count = 0
	velocity = Vector3.ZERO
	_knock = Vector3.ZERO
	_slam = false
	_set_state(ST_DOWN)
	brain.notify(&"landed")


func _set_state(next: StringName) -> void:
	body_state = next
	_state_ms = 0.0


# ---- movement helpers ----

func _apply_gravity(dt: float) -> void:
	if is_on_floor() and velocity.y <= 0.0:
		velocity.y = -1.0
	else:
		velocity.y -= float(_hit_feel.get("gravity_mps2", 26.0)) * dt


func _turn_toward(direction: Vector3, dt: float) -> void:
	if direction.length() < FACE_TURN_EPS:
		return
	var wanted: float = atan2(direction.x, direction.z)
	var step: float = deg_to_rad(float(data.get("turn_rate_deg_per_s", 420.0))) * dt
	rotation.y = rotate_toward(rotation.y, wanted, step)


## The brain's move_dir (player frame) in world space.
func _world_move(move_dir: Vector3, dir_to_player: Vector3) -> Vector3:
	var side: Vector3 = dir_to_player.cross(Vector3.UP)
	return dir_to_player * move_dir.z + side * move_dir.x


# ---- data and visuals ----

func _load_data() -> void:
	var all: Dictionary = CombatData.enemies()
	data = ((all.get("enemies", {}) as Dictionary).get(String(enemy_id), {}) as Dictionary).duplicate(true)
	_hit_feel = CombatData.hit_feel()
	_moves = MoveSet.load_default()
	if data.is_empty():
		push_error("ActionEnemy: no enemy '%s' in enemies.json" % enemy_id)
		return
	if actor_id == &"":
		actor_id = StringName("%s_%d" % [enemy_id, get_instance_id() % 10000])
	team = &"enemy"
	move_set_id = StringName(str(data.get("move_set", enemy_id)))
	hp_max = int(data.get("hp", 40))
	hp = hp_max
	poise_max = float(data.get("poise", 0.0))
	poise = poise_max
	poise_regen_per_s = float(data.get("poise_regen_per_s", 15.0))
	poise_regen_delay_ms = float(data.get("poise_regen_delay_ms", 1500.0))
	weight = float(data.get("weight", 1.0))
	launchable = bool(data.get("launchable", true))
	height_m = float(data.get("height_m", 1.2))
	radius_m = float(data.get("radius_m", 0.36))
	_telegraph_color = Color.html(str(data.get("telegraph_color", "#ff4a3a")))
	var sandbox: Dictionary = CombatData.combat_file(CombatData.FILE_SANDBOX)
	_respawn_s = float(sandbox.get("respawn_s", DEFAULT_RESPAWN_S))


func _build_body_shape() -> void:
	var shape_node: CollisionShape3D = get_node_or_null("CollisionShape3D") as CollisionShape3D
	if shape_node == null:
		shape_node = CollisionShape3D.new()
		shape_node.name = "CollisionShape3D"
		add_child(shape_node)
	var capsule: CapsuleShape3D = CapsuleShape3D.new()
	capsule.radius = radius_m
	capsule.height = maxf(height_m, radius_m * 2.0)
	shape_node.shape = capsule
	shape_node.position = Vector3(0.0, capsule.height * 0.5, 0.0)
	floor_snap_length = 0.3
	floor_max_angle = deg_to_rad(50.0)


func _build_visual() -> void:
	model_root = Node3D.new()
	model_root.name = "Model"
	add_child(model_root)
	var node: Node3D = null
	for key: String in ["model", "fallback_model"]:
		var path: String = str(data.get(key, ""))
		if path.is_empty() or not ResourceLoader.exists(path):
			continue
		var scene: PackedScene = load(path) as PackedScene
		if scene == null:
			continue
		node = scene.instantiate() as Node3D
		if node != null:
			_visual_kind = "model" if key == "model" else "fallback"
			break
	if node == null:
		node = _make_blockout()
		_visual_kind = "blockout"
	model_root.add_child(node)
	if _visual_kind == "fallback":
		_fit_to_height(node)
	_anim = _find_animation_player(model_root)
	_overlay = StandardMaterial3D.new()
	_overlay.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_overlay.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_overlay.albedo_color = Color(1, 1, 1, 0)
	_collect_meshes(model_root)
	for mesh: MeshInstance3D in _overlay_meshes:
		mesh.material_overlay = _overlay


func _make_blockout() -> Node3D:
	var spec: Dictionary = data.get("blockout", {})
	var root: Node3D = Node3D.new()
	root.name = "Blockout"
	var mesh_node: MeshInstance3D = MeshInstance3D.new()
	var body_material: StandardMaterial3D = StandardMaterial3D.new()
	body_material.albedo_color = Color.html(str(spec.get("color", "#6b7280")))
	if str(spec.get("shape", "capsule")) == "box":
		var box: BoxMesh = BoxMesh.new()
		box.size = Vector3(radius_m * 2.0, height_m, radius_m * 2.0)
		mesh_node.mesh = box
	else:
		var capsule: CapsuleMesh = CapsuleMesh.new()
		capsule.radius = radius_m
		capsule.height = maxf(height_m, radius_m * 2.0)
		mesh_node.mesh = capsule
	mesh_node.material_override = body_material
	mesh_node.position = Vector3(0.0, height_m * 0.5, 0.0)
	root.add_child(mesh_node)
	# a bright "face" on the +Z side so the facing (and the wind-up turn) can be read
	var face: MeshInstance3D = MeshInstance3D.new()
	var face_mesh: BoxMesh = BoxMesh.new()
	face_mesh.size = Vector3(radius_m * 1.1, height_m * 0.16, radius_m * 0.5)
	face.mesh = face_mesh
	var face_material: StandardMaterial3D = StandardMaterial3D.new()
	face_material.albedo_color = Color.html(str(spec.get("face_color", "#e8d36a")))
	face_material.emission_enabled = true
	face_material.emission = face_material.albedo_color
	face_material.emission_energy_multiplier = 0.6
	face.material_override = face_material
	face.position = Vector3(0.0, height_m * 0.82, radius_m * 0.85)
	root.add_child(face)
	return root


## Scale a model of unknown size to the enemy's height and stand its feet on the floor.
func _fit_to_height(node: Node3D) -> void:
	var bounds: AABB = _merged_bounds(node)
	if bounds.size.y <= 0.001:
		return
	var factor: float = height_m / bounds.size.y
	node.scale = Vector3.ONE * factor
	node.position = Vector3(-(bounds.position.x + bounds.size.x * 0.5) * factor, -bounds.position.y * factor, -(bounds.position.z + bounds.size.z * 0.5) * factor)


func _merged_bounds(node: Node) -> AABB:
	var result: AABB = AABB()
	var first: bool = true
	var stack: Array[Node] = [node]
	while not stack.is_empty():
		var current: Node = stack.pop_back()
		if current is MeshInstance3D:
			var mesh_node: MeshInstance3D = current
			var local: AABB = mesh_node.get_aabb()
			var xform: Transform3D = _relative_transform(mesh_node, node)
			var box: AABB = xform * local
			result = box if first else result.merge(box)
			first = false
		for child: Node in current.get_children():
			stack.append(child)
	return result


func _relative_transform(node: Node3D, ancestor: Node) -> Transform3D:
	var xform: Transform3D = Transform3D.IDENTITY
	var current: Node = node
	while current != null and current != ancestor.get_parent():
		if current is Node3D:
			xform = (current as Node3D).transform * xform
		current = current.get_parent()
	return xform


func _find_animation_player(root: Node) -> AnimationPlayer:
	if root is AnimationPlayer:
		return root
	for child: Node in root.get_children():
		var found: AnimationPlayer = _find_animation_player(child)
		if found != null:
			return found
	return null


func _collect_meshes(root: Node) -> void:
	if root is MeshInstance3D:
		_overlay_meshes.append(root)
	for child: Node in root.get_children():
		_collect_meshes(child)


func _play_pose(clip: StringName, clip_s: float) -> void:
	if _anim == null or not _anim.has_animation(String(clip)):
		return
	_anim.play(String(clip))
	_anim.seek(clip_s, true)
	_anim.pause()
	_current_clip = &""


func _play_loop(clip: StringName, speed: float) -> void:
	if _anim == null or not _anim.has_animation(String(clip)):
		return
	if _current_clip != clip:
		_anim.play(String(clip), 0.1)
		_current_clip = clip
	_anim.speed_scale = speed


func _update_visual(dt: float) -> void:
	if model_root == null:
		return
	# clips for the loops (idle / walk / reactions) when the model has them
	if _anim != null and not runner.is_busy():
		var speed: float = clampf(dt / maxf(get_physics_process_delta_time(), 0.0001), 0.0, 2.0)
		var flat_speed: float = Vector2(velocity.x, velocity.z).length()
		match body_state:
			ST_FREE:
				_play_loop(&"run" if flat_speed > 2.0 and _anim.has_animation("run") else (&"walk" if flat_speed > 0.3 and _anim.has_animation("walk") else &"idle"), speed)
			ST_HURT, ST_RECOIL:
				_play_loop(&"hurt", speed)
			ST_STAGGER:
				_play_loop(&"stagger", speed)
			ST_LAUNCHED:
				_play_loop(&"launched", speed)
			ST_DOWN:
				_play_loop(&"knockdown", speed)
			ST_GETUP:
				_play_loop(&"getup", speed)
	# procedural lean / tumble: always on, small on a rigged model, the whole show on a blockout
	var target_pitch: float = 0.0
	var target_drop: float = 0.0
	var move: Dictionary = runner.data() if runner.is_busy() else {}
	match body_state:
		ST_FREE:
			if not move.is_empty():
				var ms: float = runner.elapsed_ms()
				var startup: float = float(move.get("startup_ms", 1.0))
				if ms < startup:
					target_pitch = -0.4 * smoothstep(0.0, 1.0, ms / maxf(startup * 0.8, 1.0))
					target_drop = -0.08 * target_pitch / -0.4
				elif runner.phase() == &"active":
					target_pitch = 0.5
				else:
					target_pitch = 0.1
		ST_HURT, ST_RECOIL:
			target_pitch = -0.3
		ST_STAGGER:
			target_pitch = -0.55
		ST_LAUNCHED:
			target_pitch = -1.1
		ST_DOWN:
			target_pitch = -1.5
			target_drop = 0.12
	if _anim != null and body_state != ST_FREE:
		target_pitch *= 0.0      # a rigged model plays its own reaction clips
	_pitch = lerpf(_pitch, target_pitch, clampf(dt * 18.0, 0.0, 1.0))
	_drop = lerpf(_drop, target_drop, clampf(dt * 18.0, 0.0, 1.0))
	model_root.rotation.x = _pitch
	model_root.position.y = _drop
	if body_state == ST_DEAD:
		model_root.visible = fmod(_dead_real_s * 12.0, 1.0) < 0.5 and _dead_real_s < 0.7
	# colour overlay: red-ish pulse in a wind-up, white flash on hit
	_flash = maxf(_flash - dt * 7.0, 0.0)
	var telegraph_glow: float = 0.0
	if _telegraph_left_ms > 0.0:
		_telegraph_left_ms = maxf(_telegraph_left_ms - dt * 1000.0, 0.0)
		telegraph_glow = 0.35 + 0.35 * sin(clock.now_ms() * 0.03)
	if _overlay != null:
		if _flash > 0.0:
			_overlay.albedo_color = Color(1.0, 1.0, 1.0, 0.6 * _flash)
		else:
			_overlay.albedo_color = Color(_telegraph_color.r, _telegraph_color.g, _telegraph_color.b, telegraph_glow)
