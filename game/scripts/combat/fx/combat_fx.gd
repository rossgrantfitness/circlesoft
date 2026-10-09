class_name CombatFx
extends Node3D
## Everything you see and hear when a fight happens, in one listener (combat_api.md 4.6): sword trails, hit sparks, the wind-up
## cue, the Lamp Flare and Lights On looks, dash streaks, camera shake and the combat sounds. It listens to the CombatDirector's
## signals and to Red's own (jumped, landed, dashed); it never decides anything about the fight.
##
##   fx.bind(sandbox)      # the sandbox does this for the attachment listed in sandbox.json
##
## WHO PLAYS WHICH SOUND: this node plays every `combat_*` id EXCEPT combat_noise_rank_up and combat_lock_on (the HUD plays those).
## A move's own sfx / swing.sfx wins over the defaults in fx.json `sounds`. Nobody plays the same id twice in a frame: `_play()` drops
## a repeat in the same frame (a launcher hit says `combat_hit_launch` through both hit_landed and launched; you hear it once).
##
## SHAKE goes through OrbitCamera.shake(profile, mult): the camera reads the profiles from fx.json `shake.<id>`, which replaces its
## built-in fallback numbers. All numbers live in data/combat/fx.json; nothing here is tuned in code.
##
## LOOK: it also adds a Ps2Look node to the sandbox (the grim_ps2 picture, shadows and glow) and gives every fighter's model the PS2
## shader and its edge light, once (fx.json `look`), because nothing else in the sandbox does.

const DATA_ID: String = "combat/fx"
const KNOB_TRAILS: String = "trails_on"
const NOT_OURS: PackedStringArray = ["combat_noise_rank_up", "combat_lock_on"]
const PLAYED_LOG_MAX: int = 64
const DRESSED_META: StringName = &"fx_dressed"

signal sound_played(id: StringName)

var cfg: Dictionary = {}
## Where sounds go. The default asks the AudioManager autoload; tests replace it.
var sound_sink: Callable = Callable()
var played: Array[StringName] = []

var _director: Node = null
var _player: Node3D = null
var _camera: Node = null
var _sandbox: Node = null
var _flare: FlareFx = null
var _moves: MoveSet = null
var _trails: Dictionary = {}          # actor id -> SwordTrail
var _swings: Dictionary = {}          # actor id -> {t_ms, start_ms, end_ms}
var _cues: Array[Dictionary] = []     # {cue: TelegraphCue, actor: CombatActor}
var _frame_plays: Dictionary = {}     # sound id -> frame it last played
var _counter: int = 0


func bind(sandbox: Node) -> void:
	_sandbox = sandbox
	var director: Node = sandbox.call("get_director") as Node if sandbox.has_method("get_director") else null
	var player: Node3D = sandbox.call("get_player") as Node3D if sandbox.has_method("get_player") else null
	var camera: Node = sandbox.call("get_camera") as Node if sandbox.has_method("get_camera") else null
	bind_parts(director, player, camera)
	_look_pass()


## The same without a sandbox (tests, other scenes): any of the three may be null and its effects are simply off.
func bind_parts(director: Node, player: Node3D, camera: Node) -> void:
	if cfg.is_empty():
		cfg = _shipped()
	_director = director
	_player = player
	_camera = camera
	if _moves == null:
		_moves = MoveSet.load_default()
	_make_flare()
	if director != null:
		_connect(director, "move_started", _on_move_started)
		_connect(director, "hit_landed", _on_hit_landed)
		_connect(director, "launched", _on_launched)
		_connect(director, "telegraphed", _on_telegraphed)
		_connect(director, "parry_judged", _on_parry_judged)
		_connect(director, "perfect_dodge", _on_perfect_dodge)
		_connect(director, "flare_started", _on_flare_started)
		_connect(director, "flare_ended", _on_flare_ended)
		_connect(director, "lights_on_changed", _on_lights_on_changed)
		_connect(director, "actor_died", _on_actor_died)
		_connect(director, "actor_registered", _on_actor_registered)
	if player != null:
		_connect(player, "jumped", _on_jumped)
		_connect(player, "landed", _on_landed)
		_connect(player, "dashed", _on_dashed)


func _connect(source: Object, signal_name: String, handler: Callable) -> void:
	if source.has_signal(signal_name) and not source.is_connected(signal_name, handler):
		source.connect(signal_name, handler)


func _make_flare() -> void:
	if _flare != null:
		return
	_flare = FlareFx.new()
	_flare.name = "FlareFx"
	_flare.config = cfg.get("flare", {}) as Dictionary
	_flare.lights_config = cfg.get("lights_on", {}) as Dictionary
	_flare.follow = _player
	if _sandbox != null:
		_flare.world_environment = _sandbox.find_child("WorldEnvironment", true, false) as WorldEnvironment
	add_child(_flare)


func get_flare() -> FlareFx:
	return _flare


# ---- data helpers ----

func _block(name: String) -> Dictionary:
	var found: Variant = cfg.get(name, {})
	return found as Dictionary if found is Dictionary else {}


func _sound(key: String) -> StringName:
	return StringName(str(_block("sounds").get(key, "")))


func _knob_on(id: String) -> bool:
	var feel: Variant = _director.get("feel") if _director != null else null
	if feel != null and feel.has_method("has") and feel.call("has", id):
		return bool(feel.call("get_b", id))
	return true


func _actor(id: StringName) -> Node3D:
	if _director != null and _director.has_method("get_actor"):
		return _director.call("get_actor", id) as Node3D
	return null


func _shipped() -> Dictionary:
	var db: Node = get_node_or_null("/root/DataDB")
	return db.call("get_dict", DATA_ID) if db != null else {}


# ---- sound ----

## Plays a combat sound once per frame per id. Returns false if it was dropped (empty id, repeat, or not ours to play).
func play(id: StringName) -> bool:
	if id == &"" or NOT_OURS.has(String(id)):
		return false
	var frame: int = Engine.get_process_frames()
	if _frame_plays.get(id, -1) == frame:
		return false
	_frame_plays[id] = frame
	played.append(id)
	if played.size() > PLAYED_LOG_MAX:
		played.remove_at(0)
	if sound_sink.is_valid():
		sound_sink.call(id)
	else:
		var audio: Node = get_node_or_null("/root/AudioManager")
		if audio != null:
			audio.call("play_sfx", id)
	sound_played.emit(id)
	return true


# ---- the director's signals ----

func _on_move_started(info: Dictionary) -> void:
	var swing_sfx: String = str(info.get("swing_sfx", ""))
	var wants_trail: bool = bool(info.get("trail", false))
	if not swing_sfx.is_empty():
		play(StringName(swing_sfx))
	elif wants_trail:
		var move_id: String = str(info.get("move_id", ""))
		play(_sound("swing_heavy") if move_id.begins_with("heavy") or move_id == "launcher" else _sound("swing_light"))
	if wants_trail and _knob_on(KNOB_TRAILS):
		_start_swing_trail(StringName(str(info.get("actor", ""))), StringName(str(info.get("move_id", ""))))


func _on_hit_landed(info: Dictionary) -> void:
	var position: Vector3 = info.get("position", Vector3.ZERO) as Vector3
	var outcome: String = str(info.get("outcome", "hit"))
	var spark_id: String = spark_for(info, _block("spark_by_outcome"), _block("spark_aliases"), _block("sparks"))
	var direction: Vector3 = _hit_direction(StringName(str(info.get("attacker", ""))), StringName(str(info.get("target", ""))))
	spawn_spark(spark_id, position, direction)
	var shake_id: String = str(info.get("shake", ""))
	if not shake_id.is_empty():
		var soft: bool = outcome == "armored" or outcome == "guarded"
		shake(StringName(shake_id), 0.6 if soft else 1.0)
	var own_sfx: String = str(info.get("sfx", ""))
	play(StringName(own_sfx) if not own_sfx.is_empty() else hit_sound_key(info))


func _on_launched(_info: Dictionary) -> void:
	play(_sound("launch"))


func _on_telegraphed(info: Dictionary) -> void:
	var actor: Node3D = _actor(StringName(str(info.get("attacker", ""))))
	play(_sound("telegraph"))
	if actor == null:
		return
	var telegraph: Dictionary = _block("telegraph")
	var kinds: Dictionary = telegraph.get("kinds", {}) as Dictionary
	var cue: TelegraphCue = TelegraphCue.new()
	cue.settings = telegraph
	cue.kind_config = kinds.get(TelegraphCue.kind_for(info, kinds), {}) as Dictionary
	cue.impact_in_s = maxf(float(info.get("impact_in_ms", 500.0)) / 1000.0, float(telegraph.get("min_lead_s", 0.12)))
	cue.target = actor
	add_child(cue)
	_cues.append({"cue": cue, "actor": actor})


func _on_parry_judged(info: Dictionary) -> void:
	var outcome: String = str(info.get("outcome", ""))
	var rating: String = str(info.get("rating", ""))
	if rating == "miss":
		return
	var perfect: bool = outcome == "perfect_parry" or rating == "totally_rad"
	var key: String = "perfect_parry" if perfect else "parry"
	play(_sound(key))
	spawn_spark(key, info.get("position", Vector3.ZERO) as Vector3, _hit_direction(StringName(str(info.get("attacker", ""))), &"red"))
	shake(StringName(key))


func _on_perfect_dodge(info: Dictionary) -> void:
	spawn_spark("dodge", info.get("position", Vector3.ZERO) as Vector3, Vector3.UP)


func _on_flare_started(info: Dictionary) -> void:
	if _flare != null:
		_flare.start_flare(float(info.get("duration_s", 1.5)))
	play(_sound("flare"))
	shake(&"flare")


func _on_flare_ended() -> void:
	if _flare != null:
		_flare.stop_flare()


func _on_lights_on_changed(active: bool, _duration_s: float) -> void:
	if _flare != null:
		_flare.set_lights_on(active)
	if active:
		play(_sound("lights_on"))


func _on_actor_died(actor_id: StringName) -> void:
	var actor: Node3D = _actor(actor_id)
	if actor == null or str(actor.get("team")) == "player":
		return
	var point: Vector3 = actor.call("anchor", &"center") as Vector3 if actor.has_method("anchor") else actor.global_position
	spawn_spark("death", point, Vector3.UP)
	play(_sound("death"))
	shake(&"death")


func _on_actor_registered(actor_id: StringName, _team: StringName) -> void:
	if bool(_block("look").get("dress_actors", false)):
		_dress_actor(_actor(actor_id))


# ---- red's own signals ----

func _on_jumped(_air: bool) -> void:
	play(_sound("jump"))


func _on_landed() -> void:
	play(_sound("land"))


func _on_dashed(air: bool) -> void:
	play(_sound("air_dash" if air else "dash"))
	if _player != null:
		var direction: Vector3 = _player.call("get_facing") as Vector3 if _player.has_method("get_facing") else _player.global_basis.z
		DashStreak.spawn(self, _player.global_position, direction, _block("dash"), air)


# ---- sparks and shake ----

## Which spark profile a hit gets (pure): the outcome's own (guards, parries), else the move's spark id through the aliases, else slash.
static func spark_for(info: Dictionary, by_outcome: Dictionary, aliases: Dictionary, sparks: Dictionary) -> String:
	var outcome: String = str(info.get("outcome", "hit"))
	if by_outcome.has(outcome) and sparks.has(str(by_outcome[outcome])):
		return str(by_outcome[outcome])
	var wanted: String = str(info.get("spark", ""))
	if sparks.has(wanted):
		return wanted
	if aliases.has(wanted) and sparks.has(str(aliases[wanted])):
		return str(aliases[wanted])
	if bool(info.get("airborne", false)) and sparks.has("air"):
		return "air"
	return "slash"


## The sound key for a hit whose move names none (pure): launch, air, heavy or light.
static func hit_sound_key_for(info: Dictionary) -> String:
	if bool(info.get("launch", false)):
		return "launch"
	var shake_id: String = str(info.get("shake", ""))
	if shake_id == "launch":
		return "launch"
	if bool(info.get("airborne", false)):
		return "hit_air"
	if shake_id == "heavy" or shake_id == "slam":
		return "hit_heavy"
	return "hit_light"


func hit_sound_key(info: Dictionary) -> StringName:
	return _sound(hit_sound_key_for(info))


func spawn_spark(spark_id: String, position: Vector3, direction: Vector3) -> HitSpark:
	var sparks: Dictionary = _block("sparks")
	if not sparks.has(spark_id):
		return null
	_counter += 1
	return HitSpark.spawn(self, position, direction, sparks[spark_id] as Dictionary, _counter * 7919)


func shake(profile: StringName, mult: float = 1.0) -> void:
	if _camera != null and _camera.has_method("shake"):
		_camera.call("shake", profile, mult)


func _hit_direction(attacker_id: StringName, target_id: StringName) -> Vector3:
	var attacker: Node3D = _actor(attacker_id)
	var target: Node3D = _actor(target_id)
	if attacker == null or target == null:
		return Vector3.UP
	var flat: Vector3 = attacker.global_position - target.global_position
	flat.y = 0.0
	if flat.length() < 0.01:
		return Vector3.UP
	return (flat.normalized() + Vector3.UP * 0.45).normalized()


# ---- trails ----

func _start_swing_trail(actor_id: StringName, move_id: StringName) -> void:
	var actor: Node3D = _actor(actor_id)
	if actor == null:
		return
	var gear: Node = actor.get_node_or_null("GearVisuals")
	if gear == null or not gear.has_method("blade_points"):
		return
	var points: Dictionary = gear.call("blade_points") as Dictionary
	if points.is_empty():
		return
	var trail: SwordTrail = _trails.get(actor_id) as SwordTrail
	if trail == null or not is_instance_valid(trail):
		trail = SwordTrail.new()
		trail.name = "Trail_%s" % actor_id
		var trail_cfg: Dictionary = _block("trail")
		trail.max_age_s = float(trail_cfg.get("max_age_s", 0.22))
		trail.max_samples = int(trail_cfg.get("max_samples", 24))
		trail.glow = float(trail_cfg.get("glow", 1.8))
		trail.min_step_m = float(trail_cfg.get("min_step_m", 0.015))
		add_child(trail)
		_trails[actor_id] = trail
	trail.bind_blade(points)
	trail.set_color(gear.call("trail_color", gear.call("current_sword")) as Color)
	var move: Dictionary = _moves.get_move(StringName(str(actor.get("move_set_id"))), move_id) if _moves != null else {}
	var start_ms: float = float(move.get("startup_ms", 80.0))
	var end_ms: float = start_ms + float(move.get("active_ms", 80.0)) + float(_block("trail").get("tail_ms", 70.0))
	_swings[actor_id] = {"t_ms": 0.0, "start_ms": start_ms, "end_ms": end_ms}


## Whether `actor_id`'s trail is recording right now (tests).
func trail_active(actor_id: StringName) -> bool:
	var trail: SwordTrail = _trails.get(actor_id) as SwordTrail
	return trail != null and trail.is_active()


func get_trail(actor_id: StringName) -> SwordTrail:
	return _trails.get(actor_id) as SwordTrail


func _process(delta: float) -> void:
	step(delta)


## One frame of FX bookkeeping: each swing's clock runs on its fighter's combat time (frozen in hit-stop, slow in a flare).
func step(delta: float) -> void:
	for actor_id: StringName in _swings.keys():
		var swing: Dictionary = _swings[actor_id]
		var local: float = _local_delta(actor_id, delta)
		swing["t_ms"] = float(swing["t_ms"]) + local * 1000.0
		var trail: SwordTrail = _trails.get(actor_id) as SwordTrail
		if trail != null:
			trail.set_time_scale(local / delta if delta > 0.0 else 1.0)
			trail.set_active(float(swing["t_ms"]) >= float(swing["start_ms"]) and float(swing["t_ms"]) <= float(swing["end_ms"]))
		if float(swing["t_ms"]) > float(swing["end_ms"]):
			_swings.erase(actor_id)
			if trail != null:
				trail.set_active(false)
	var keep: Array[Dictionary] = []
	for entry: Dictionary in _cues:
		var cue: TelegraphCue = entry["cue"] as TelegraphCue
		if not is_instance_valid(cue):
			continue
		if not is_instance_valid(entry["actor"]):
			cue.queue_free()  # the attacker is gone (died or Reset arena): drop its wind-up ring
			continue
		var actor: Node3D = entry["actor"] as Node3D
		var local: float = _local_delta(actor.get("actor_id") as StringName, delta)
		if cue.step(local):
			keep.append(entry)
		else:
			cue.queue_free()
	_cues = keep


func _local_delta(actor_id: StringName, delta: float) -> float:
	var actor: Node3D = _actor(actor_id)
	if actor != null and _director != null and _director.has_method("delta_for"):
		return float(_director.call("delta_for", actor, delta))
	return delta


# ---- the look pass ----

func _look_pass() -> void:
	if _sandbox == null:
		return
	var look: Dictionary = _block("look")
	if bool(look.get("add_ps2_look", false)) and _sandbox.find_child("Ps2Look", true, false) == null:
		var node: Ps2Look = Ps2Look.new()
		node.name = "Ps2Look"
		_sandbox.add_child(node)
	if bool(look.get("dress_actors", false)):
		if _player != null:
			_dress_actor(_player)
		if _director != null and _director.has_method("actors"):
			for actor: Variant in _director.call("actors"):
				_dress_actor(actor as Node3D)


## Gives a fighter's model the PS2 shader (placeholders go crisp, Ross's art stays smooth) and its edge light, once. Only in a PS2
## profile: any other look is left exactly as it was.
func _dress_actor(actor: Node3D) -> void:
	if actor == null or actor.has_meta(DRESSED_META):
		return
	var profile: Dictionary = LookProfiles.profile(LookProfiles.active_id())
	if not Ps2Look.is_ps2_profile(profile):
		return
	var model: Node3D = find_model(actor)
	if model == null:
		return
	actor.set_meta(DRESSED_META, true)
	var path: String = model.scene_file_path
	var role: String = "player" if str(actor.get("team")) == "player" else "enemy"
	Ps2Look.upgrade_model(model, path, profile)
	LookProfiles.dress_model(model, path, role)


## The imported model under a fighter: its get_model(), else the first Node3D that is an instanced .glb.
static func find_model(actor: Node3D) -> Node3D:
	if actor.has_method("get_model"):
		var model: Node3D = actor.call("get_model") as Node3D
		if model != null:
			return model
	var queue: Array[Node] = [actor]
	while not queue.is_empty():
		var node: Node = queue.pop_front()
		if node is Node3D and node != actor and node.scene_file_path.ends_with(".glb"):
			return node as Node3D
		queue.append_array(node.get_children())
	return null
