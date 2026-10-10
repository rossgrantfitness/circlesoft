class_name BattleCamDirector
extends RefCounted
## The battle camera director (Ross's storyboard, 2026-10-07). Pure logic, no nodes: feed it time with advance(dt)
## and read the pose it wants from pose(). All shots are data (data/battle_stage/camera_shots.json) written relative
## to the formation (BattleCamFrame), so they fit any party and enemy layout.
##
## Modes:
##   INTRO   a short run of 2 or 3 shots from the storyboard's panels 1-6 (seeded pick), cut together, ending on the
##           panel-12 settle. Any press -> skip_intro() jumps to the settle. Bosses play the panel-11 low POV instead.
##   IDLE    a slow drift or track (panels 7-9 / 12) that keeps both rows readable under the HUD.
##   ACTION  when a fighter acts, ease or cut to an attacker-side angle (panel 3 for party attacks, panel 10 for
##           enemy attacks), then ease back to idle.
##
## The Clutch rule: begin_action() is told when each press cue falls. From lead_ms before the first cue until
## tail_ms after the last, the camera is LOCKED: the shot has already arrived, it holds the actor and the targets
## inside the safe frame, and it only drifts a hair (no roll, no FOV change). If there is no time to ease in before the
## lock opens, the move is a single cut instead. The pose is updated at pose_hz (stepped, PSX chunky).

signal intro_finished
signal settle_started
signal action_ended

enum Mode { IDLE, INTRO, ACTION }

const PATH_DIRECTOR: String = "director."
const PATH_SHOTS: String = "shots."
const MS: float = 1000.0

## One shot being played: keyframes eased over a duration (or held, with a drift).
class Clip extends RefCounted:
	var id: String = ""
	var keys: Array[BattleCamPose] = []
	var duration_s: float = 1.0
	var ease_kind: String = "inout"
	var pingpong: bool = false
	var hold: bool = false
	var drift: Vector3 = Vector3.ZERO
	var elapsed: float = 0.0
	var speed: float = 1.0

	func is_done() -> bool:
		return not pingpong and not hold and elapsed >= duration_s

	func pose() -> BattleCamPose:
		if hold or keys.size() == 1:
			var held: BattleCamPose = keys[0].copy()
			held.position += drift * elapsed
			held.look += drift * elapsed
			return held
		var t: float = elapsed / maxf(duration_s, 0.001)
		var u: float = clampf(t, 0.0, 1.0)
		if pingpong:
			var phase: float = fposmod(t, 2.0)
			u = phase if phase <= 1.0 else 2.0 - phase
		var eased: float = BattleCamMath.ease_value(ease_kind, u)
		var segment: float = eased * float(keys.size() - 1)
		var index: int = mini(int(floorf(segment)), keys.size() - 2)
		return BattleCamPose.mix(keys[index], keys[index + 1], segment - float(index))


var tuning: BattleStageTuning = null
var frame: BattleCamFrame = null
var aspect: float = 16.0 / 9.0
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var mode: Mode = Mode.IDLE
var time_s: float = 0.0

var _idle: Clip = null
var _override: Clip = null
var _queue: Array[Clip] = []
var _plan: Array[String] = []
var _live: BattleCamPose = BattleCamPose.new()
var _out: BattleCamPose = BattleCamPose.new()
var _blend_from: BattleCamPose = null
var _blend_t: float = 0.0
var _blend_dur: float = 0.0
var _step_acc: float = 0.0
var _have_out: bool = false
var _lock_start: float = -1.0
var _lock_end: float = -1.0
var _idle_variant: int = 0
var _skipping: bool = false
var _total_intro_s: float = 0.0


func setup(shots: BattleStageTuning, new_frame: BattleCamFrame, seed_value: int, aspect_ratio: float = 16.0 / 9.0) -> void:
	tuning = shots
	frame = new_frame
	aspect = aspect_ratio
	rng.seed = seed_value
	_idle_variant = 0
	start_idle()


func set_frame(new_frame: BattleCamFrame) -> void:
	frame = new_frame
	start_idle()


# ---- reading the result ----

## The pose the camera should show right now (stepped at pose_hz).
func pose() -> BattleCamPose:
	return _out if _have_out else _live


func live_pose() -> BattleCamPose:
	return _live


func intro_plan() -> Array[String]:
	return _plan.duplicate()


## Length of the planned intro in seconds (all its shots plus the settle).
func intro_length_s() -> float:
	return _total_intro_s


func is_intro_playing() -> bool:
	return mode == Mode.INTRO


func in_lock() -> bool:
	return _lock_end > 0.0 and time_s >= _lock_start and time_s <= _lock_end


## The lock window in director time: x = opens, y = closes (both -1 when there is no action).
func lock_window() -> Vector2:
	return Vector2(_lock_start, _lock_end)


## True when a lock is open or opens within `seconds`.
func lock_near(seconds: float) -> bool:
	return _lock_end > 0.0 and time_s <= _lock_end and time_s >= _lock_start - seconds


# ---- intro ----

## Chooses the shots for an intro (seeded) without starting it: shot ids, the settle last.
func plan_intro(boss: bool) -> Array[String]:
	var ids: Array[String] = []
	if boss:
		for id: String in tuning.string_list(PATH_DIRECTOR + "intro.boss_shots"):
			ids.append(id)
	else:
		var pool: Array[String] = []
		for id: String in tuning.string_list(PATH_DIRECTOR + "intro.pool"):
			pool.append(id)
		var count: int = rng.randi_range(tuning.integer(PATH_DIRECTOR + "intro.shots_min"), tuning.integer(PATH_DIRECTOR + "intro.shots_max"))
		count = mini(count, pool.size())
		for i: int in range(pool.size() - 1, 0, -1):
			var j: int = rng.randi_range(0, i)
			var swap: String = pool[i]
			pool[i] = pool[j]
			pool[j] = swap
		for i: int in count:
			ids.append(pool[i])
		ids.sort_custom(func(a: String, b: String) -> bool: return tuning.integer(PATH_SHOTS + a + ".panel") < tuning.integer(PATH_SHOTS + b + ".panel"))
	ids.append(tuning.text(PATH_DIRECTOR + "intro.settle"))
	return ids


## Starts the intro: the picked shots cut together, then the settle. Bosses play the low POV.
func start_intro(boss: bool) -> void:
	_plan = plan_intro(boss)
	_queue.clear()
	_skipping = false
	var total_ms: float
	if boss:
		total_ms = tuning.number(PATH_DIRECTOR + "intro.boss_total_ms")
	else:
		total_ms = rng.randf_range(tuning.number(PATH_DIRECTOR + "intro.total_min_ms"), tuning.number(PATH_DIRECTOR + "intro.total_max_ms"))
	var settle_id: String = _plan[_plan.size() - 1]
	var settle_ms: float = tuning.number(PATH_SHOTS + settle_id + ".duration_ms")
	var nominal: float = 0.0
	for i: int in _plan.size() - 1:
		nominal += tuning.number(PATH_SHOTS + _plan[i] + ".duration_ms")
	var scale: float = maxf(total_ms - settle_ms, 200.0) / maxf(nominal, 1.0)
	_total_intro_s = 0.0
	for i: int in _plan.size():
		var clip: Clip = build_clip(_plan[i])
		if i < _plan.size() - 1:
			clip.duration_s *= scale
		_total_intro_s += clip.duration_s
		_queue.append(clip)
	mode = Mode.INTRO
	_override = _queue.pop_front()
	_blend_dur = 0.0
	_blend_t = 0.0
	_refresh_live()
	_have_out = false
	_snap_out()


## Any press: jump straight to the settle and play it fast.
func skip_intro() -> void:
	if mode != Mode.INTRO or _skipping:
		return
	_skipping = true
	var settle_id: String = _plan[_plan.size() - 1]
	if _override != null and _override.id == settle_id:
		_override.speed = tuning.number(PATH_DIRECTOR + "intro.skip_speed")
		return
	_blend_from = _live.copy()
	_blend_t = 0.0
	_blend_dur = tuning.number(PATH_DIRECTOR + "intro.skip_blend_ms") / MS
	_queue.clear()
	var settle: Clip = build_clip(settle_id)
	settle.speed = tuning.number(PATH_DIRECTOR + "intro.skip_speed")
	_override = settle
	settle_started.emit()


# ---- idle ----

func start_idle() -> void:
	var variants: PackedStringArray = tuning.string_list(PATH_DIRECTOR + "idle_variants")
	if variants.is_empty() or frame == null:
		return
	var id: String = variants[_idle_variant % variants.size()]
	_idle = build_clip(id)
	_refresh_live()
	if not _have_out:
		_snap_out()


## Picks the next idle variant (called once per fight start; seeded).
func pick_idle_variant() -> void:
	var variants: PackedStringArray = tuning.string_list(PATH_DIRECTOR + "idle_variants")
	if not variants.is_empty():
		_idle_variant = rng.randi_range(0, variants.size() - 1)
	start_idle()


# ---- actions ----

## An attacker-side shot for an action. info: {actor, targets: [ids], side: "party"|"enemy", lock_start_s,
## lock_end_s (seconds from now; lock_start_s < 0 means no presses), lunge: bool}. Returns what it did:
## {shot, eased: bool, ease_s, lock_start_s, lock_end_s}.
func begin_action(info: Dictionary) -> Dictionary:
	if mode == Mode.INTRO or frame == null:
		return {}
	var side: String = str(info.get("side", "party"))
	var shot_id: String = "party_action" if side == "party" else "enemy_action"
	var targets: Array = info.get("targets", [])
	var ctx: Dictionary = frame.pair_context(str(info["actor"]), targets, tuning.number(PATH_DIRECTOR + "ref_separation"),
			tuning.number(PATH_DIRECTOR + "pair_scale_min"), tuning.number(PATH_DIRECTOR + "pair_scale_max"))
	var shot: Dictionary = tuning.dict(PATH_SHOTS + shot_id)
	var pose_now: BattleCamPose = BattleCamPose.make(
			frame.resolve(shot["pos"], ctx), frame.resolve(shot["look"], ctx), 0.0, float(shot["fov"]))
	_fit(pose_now, _subject_points(str(info["actor"]), targets, bool(info.get("lunge", true))))
	var clip: Clip = Clip.new()
	clip.id = shot_id
	clip.keys = [pose_now]
	clip.hold = true
	var drift_list: Array = shot.get("drift", [0, 0, 0])
	var drift_local: Vector3 = Vector3(float(drift_list[0]), float(drift_list[1]), float(drift_list[2]))
	var along: Vector3 = ctx["pair_axis"]
	clip.drift = (along * drift_local.x + Vector3.UP * drift_local.y + BattleCamFrame.side_of(along) * drift_local.z) * float(ctx["pair_scale"])
	var has_lock: bool = float(info.get("lock_start_s", -1.0)) >= 0.0 or float(info.get("lock_end_s", -1.0)) > 0.0
	var start_s: float = maxf(float(info.get("lock_start_s", 0.0)), 0.0)
	var margin_s: float = tuning.number(PATH_DIRECTOR + "lock.arrive_margin_ms") / MS
	var ease_s: float = minf(float(shot.get("ease_ms", 300.0)) / MS, maxf(start_s - margin_s, 0.0) if has_lock else 1.0)
	var min_ease_s: float = tuning.number(PATH_DIRECTOR + "lock.min_ease_ms") / MS
	var eased: bool = ease_s >= min_ease_s
	_blend_from = _live.copy()
	_blend_t = 0.0
	_blend_dur = ease_s if eased else 0.0
	_override = clip
	mode = Mode.ACTION
	if has_lock:
		_lock_start = time_s + start_s
		_lock_end = time_s + maxf(float(info.get("lock_end_s", start_s)), start_s)
	else:
		_lock_start = -1.0
		_lock_end = time_s + maxf(float(info.get("hold_s", 0.9)), 0.1)
	_refresh_live()
	return {"shot": shot_id, "eased": eased, "ease_s": _blend_dur, "lock_start_s": _lock_start - time_s, "lock_end_s": _lock_end - time_s}


## Back to the idle shot (eased). Called by advance() when the lock ends; also by the scene for early outs.
func end_action() -> void:
	if mode != Mode.ACTION:
		return
	mode = Mode.IDLE
	_override = null
	_blend_from = _live.copy()
	_blend_t = 0.0
	_blend_dur = tuning.number(PATH_DIRECTOR + "lock.return_ms") / MS
	_lock_start = -1.0
	_lock_end = -1.0
	action_ended.emit()


# ---- time ----

func advance(delta: float) -> void:
	time_s += delta
	if _idle != null:
		_idle.elapsed += delta
	match mode:
		Mode.INTRO:
			_advance_intro(delta)
		Mode.ACTION:
			_override.elapsed += delta
			if _lock_end > 0.0 and time_s >= _lock_end:
				end_action()
	if _blend_dur > 0.0 and _blend_t < _blend_dur:
		_blend_t += delta
	_refresh_live()
	var step: float = 1.0 / maxf(tuning.number(PATH_DIRECTOR + "pose_hz"), 1.0)
	_step_acc += delta
	if _step_acc >= step or not _have_out:
		_step_acc = fmod(_step_acc, step)
		_snap_out()


func _advance_intro(delta: float) -> void:
	_override.elapsed += delta * _override.speed
	if not _override.is_done():
		return
	if _queue.is_empty():
		_override = null
		mode = Mode.IDLE
		_skipping = false
		intro_finished.emit()
		return
	_override = _queue.pop_front()
	if _override.id == _plan[_plan.size() - 1]:
		settle_started.emit()


func _refresh_live() -> void:
	var clip: Clip = _override if _override != null else _idle
	if clip == null:
		return
	var target: BattleCamPose = clip.pose()
	if _blend_dur > 0.0 and _blend_t < _blend_dur and _blend_from != null:
		_live = BattleCamPose.mix(_blend_from, target, BattleCamMath.ease_value("inout", _blend_t / _blend_dur))
	else:
		_live = target


func _snap_out() -> void:
	_out = _live.copy()
	_have_out = true


# ---- building shots ----

## Resolves a shot from the data against the current formation.
func build_clip(shot_id: String, ctx: Dictionary = {}) -> Clip:
	var shot: Dictionary = tuning.dict(PATH_SHOTS + shot_id)
	var clip: Clip = Clip.new()
	clip.id = shot_id
	clip.duration_s = float(shot.get("duration_ms", 1000.0)) / MS
	clip.ease_kind = str(shot.get("ease", "inout"))
	clip.pingpong = str(shot.get("loop", "")) == "pingpong"
	for entry: Variant in shot.get("keys", []):
		var key: Dictionary = entry
		clip.keys.append(BattleCamPose.make(frame.resolve(key["pos"], ctx), frame.resolve(key["look"], ctx), float(key.get("roll", 0.0)), float(key.get("fov", 30.0))))
	return clip


## The points an action must keep in the safe frame: feet and head of the actor, each target, and where a
## lunging actor ends up (about stop distance from the target).
func _subject_points(actor: String, targets: Array, lunge: bool) -> Array[Vector3]:
	var points: Array[Vector3] = []
	var ids: Array[String] = [actor]
	for id: Variant in targets:
		ids.append(str(id))
	for id: String in ids:
		var feet: Vector3 = frame.position_of(id)
		points.append(feet)
		points.append(feet + Vector3.UP * frame.height_of(id))
	if lunge and not targets.is_empty():
		var from: Vector3 = frame.position_of(actor)
		var to: Vector3 = frame.position_of(str(targets[0]))
		var dir: Vector3 = to - from
		dir.y = 0.0
		if dir.length() > 1.2:
			var strike: Vector3 = to - dir.normalized() * 1.05
			points.append(strike)
			points.append(strike + Vector3.UP * frame.height_of(actor))
	return points


## Pulls the camera back (kept inside the set's bounds), then widens the FOV a little, until every point is inside
## the safe frame.
func _fit(pose_to_fit: BattleCamPose, points: Array[Vector3]) -> void:
	var safe_x: Array = tuning.list(PATH_DIRECTOR + "safe.x")
	var safe_y: Array = tuning.list(PATH_DIRECTOR + "safe.y")
	var rect: Rect2 = Rect2(float(safe_x[0]), float(safe_y[0]), float(safe_x[1]) - float(safe_x[0]), float(safe_y[1]) - float(safe_y[0]))
	var step: float = tuning.number(PATH_DIRECTOR + "fit.step")
	var limit: int = tuning.integer(PATH_DIRECTOR + "fit.max_iterations")
	pose_to_fit.position = clamp_to_bounds(pose_to_fit.position)
	for i: int in limit:
		if _all_inside(pose_to_fit, points, rect):
			return
		pose_to_fit.position = clamp_to_bounds(pose_to_fit.look + (pose_to_fit.position - pose_to_fit.look) * (1.0 + step))
	var widened: float = 0.0
	while widened < tuning.number(PATH_DIRECTOR + "fit.max_fov_widen") and not _all_inside(pose_to_fit, points, rect):
		pose_to_fit.fov += 2.0
		widened += 2.0


## Keeps a camera position inside the set (never behind a wall, never outside the walls' height).
func clamp_to_bounds(point: Vector3) -> Vector3:
	var low: Vector3 = tuning.vec3(PATH_DIRECTOR + "bounds.min")
	var high: Vector3 = tuning.vec3(PATH_DIRECTOR + "bounds.max")
	return Vector3(clampf(point.x, low.x, high.x), clampf(point.y, low.y, high.y), clampf(point.z, low.z, high.z))


func _all_inside(pose_to_check: BattleCamPose, points: Array[Vector3], rect: Rect2) -> bool:
	for point: Vector3 in points:
		if not rect.has_point(BattleCamMath.project_pose(pose_to_check, aspect, point)):
			return false
	return true
