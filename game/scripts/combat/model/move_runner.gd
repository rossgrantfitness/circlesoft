class_name MoveRunner
extends RefCounted
## Plays one move at a time from a MoveSet on its owner's CombatClock. It never reads a clock itself:
## you hand it `now_usec` (the owner's combat time), so hit-stop and slow-mo are automatically right and
## tests can step it by hand. Step it each frame and act on the events it returns, in order:
##   {type:"phase", phase}   startup / active / recovery
##   {type:"telegraph"}      enemy wind-up flash
##   {type:"swing"}          the active phase begins (sound, trail)
##   {type:"hitbox_on", index, box}  /  {type:"hitbox_off", index}
##   {type:"pose", clip, clip_s}     snap the clip to a key pose
##   {type:"interrupted"}    the previous move was cut short (hitboxes it left on come first as hitbox_off)
##   {type:"done"}           the move ended; the runner is idle
## Every event also carries t_ms (the move time it belongs to).

const IDLE: StringName = &"idle"
const PHASE_STARTUP: StringName = &"startup"
const PHASE_ACTIVE: StringName = &"active"
const PHASE_RECOVERY: StringName = &"recovery"
const EPSILON_MS: float = 0.0005
## Order of events that happen at the same millisecond.
const ORDER_OFF: int = 0
const ORDER_PHASE: int = 1
const ORDER_SWING: int = 2
const ORDER_ON: int = 3
const ORDER_TELEGRAPH: int = 4
const ORDER_POSE: int = 5
const ORDER_DONE: int = 9

static var _swing_counter: int = 0
static var _row_seq: int = 0

var _set: MoveSet = null
var _owner_set: StringName = &""
var _move: Dictionary = {}
var _id: StringName = &""
var _start_usec: int = 0
var _last_usec: int = 0
var _timeline: Array[Dictionary] = []
var _next_event: int = 0
var _phase: StringName = IDLE
var _boxes_on: Dictionary = {}       # index -> true
var _pending: Array[Dictionary] = [] # events owed from an interrupted move
var _swing_id: int = 0


static func create(set: MoveSet, owner_set: StringName) -> MoveRunner:
	var runner: MoveRunner = MoveRunner.new()
	runner._set = set
	runner._owner_set = owner_set
	return runner


# ---- starting and chaining ----

## Starts a move right now, cutting any move in progress. False if the move does not exist.
func start(move_id: StringName, now_usec: int) -> bool:
	return _begin(move_id, now_usec)


## A buffered input token: starts the linked move if the chain window of the current move is open.
## `press_usec` (optional) is when the press was made. The new move begins at the later of the press and
## the moment the window opened, so a press made early fires exactly at chain[0], not at the next frame.
## Returns the new move id, or &"" if nothing started.
func offer(token: StringName, now_usec: int, press_usec: int = -1) -> StringName:
	if not can_chain(token, now_usec):
		return &""
	var next_id: StringName = _set.link(_owner_set, _id, token)
	var window_open_usec: int = _start_usec + int(float(_move["chain_from_ms"]) * 1000.0)
	var press: int = now_usec if press_usec < 0 else mini(press_usec, now_usec)
	var begin: int = mini(maxi(window_open_usec, press), now_usec)
	if _begin(next_id, begin):
		_last_usec = now_usec     # catch-up: the next step() delivers the events between begin and now
		return next_id
	return &""


## True if `token` would start a linked move right now (the Callable for InputBuffer.take).
func can_chain(token: StringName, now_usec: int) -> bool:
	if not is_busy():
		return false
	var from_ms: float = float(_move["chain_from_ms"])
	if from_ms < 0.0:
		return false
	var ms: float = _ms_at(now_usec)
	if ms + EPSILON_MS < from_ms or ms - EPSILON_MS > float(_move["chain_to_ms"]):
		return false
	var next_id: StringName = _set.link(_owner_set, _id, token)
	return next_id != &"" and _set.has_move(_owner_set, next_id)


## Can the move be cut into a dash / jump / parry now? Always true when idle.
func can_cancel(kind: StringName, now_usec: int) -> bool:
	if not is_busy():
		return true
	var cancels: Dictionary = _move["cancels"]
	if not cancels.has(String(kind)):
		return false
	return _ms_at(now_usec) + EPSILON_MS >= float(cancels[String(kind)])


## Cuts the move short. Returns the events owed (hitbox_off for boxes still on, then interrupted).
func interrupt() -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	if is_busy():
		events = _interrupt_events()
	_clear()
	return events


# ---- stepping ----

func step(now_usec: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = _pending.duplicate()
	_pending.clear()
	_last_usec = now_usec
	if not is_busy():
		return out
	var ms: float = _ms_at(now_usec)
	while _next_event < _timeline.size() and float(_timeline[_next_event]["t_ms"]) <= ms + EPSILON_MS:
		var event: Dictionary = _timeline[_next_event]
		_next_event += 1
		_apply(event)
		out.append(event)
		if event["type"] == "done":
			break
	return out


# ---- queries ----

func current_move() -> StringName:
	return _id


func phase() -> StringName:
	return _phase


func is_busy() -> bool:
	return _id != &""


## Milliseconds into the current move at the last step()/start() time (0 when idle).
func elapsed_ms() -> float:
	return _ms_at(_last_usec) if is_busy() else 0.0


func elapsed_ms_at(now_usec: int) -> float:
	return _ms_at(now_usec) if is_busy() else 0.0


func remaining_ms() -> float:
	return maxf(float(_move.get("total_ms", 0.0)) - elapsed_ms(), 0.0) if is_busy() else 0.0


## The normalised move data (see MoveSet). Empty when idle.
func data() -> Dictionary:
	return _move


## The `hit` block plus what the resolver needs: move_id, launcher, swing_id, parryable, rehit_ms.
func attack_data() -> Dictionary:
	if not is_busy():
		return {}
	var attack: Dictionary = (_move.get("hit", {}) as Dictionary).duplicate(true)
	attack["move_id"] = _id
	attack["launcher"] = bool(_move["launcher"])
	attack["swing_id"] = _swing_id
	attack["parryable"] = bool(_move["parryable"])
	attack["dodge_flare"] = bool(_move["dodge_flare"])
	attack["rehit_ms"] = float(_move["rehit_ms"])
	return attack


## Unique per started move; the Hitbox uses it to hit each target once per swing.
func swing_id() -> int:
	return _swing_id


func chain_window_open(now_usec: int) -> bool:
	if not is_busy() or float(_move["chain_from_ms"]) < 0.0:
		return false
	var ms: float = _ms_at(now_usec)
	return ms + EPSILON_MS >= float(_move["chain_from_ms"]) and ms - EPSILON_MS <= float(_move["chain_to_ms"])


## Metres of lunge covered between two move times (the motion block spreads forward_m over from..to).
func forward_between(prev_ms: float, cur_ms: float) -> float:
	if not is_busy():
		return 0.0
	var motion: Dictionary = _move.get("motion", {})
	var forward_m: float = float(motion.get("forward_m", 0.0))
	if forward_m == 0.0:
		return 0.0
	var from_ms: float = float(motion.get("from_ms", 0.0))
	var to_ms: float = float(motion.get("to_ms", from_ms))
	if to_ms <= from_ms:
		return forward_m if (prev_ms < from_ms and cur_ms >= from_ms) else 0.0
	var a: float = clampf((prev_ms - from_ms) / (to_ms - from_ms), 0.0, 1.0)
	var b: float = clampf((cur_ms - from_ms) / (to_ms - from_ms), 0.0, 1.0)
	return forward_m * (b - a)


## Air moves: upward speed at the start and how long the fall is held at zero.
func up_mps() -> float:
	return float((_move.get("motion", {}) as Dictionary).get("up_mps", 0.0)) if is_busy() else 0.0


func is_hanging() -> bool:
	if not is_busy():
		return false
	return elapsed_ms() < float((_move.get("motion", {}) as Dictionary).get("hang_ms", 0.0))


## Super armor (enemy moves): true inside the move's armor window.
func armor_active() -> bool:
	if not is_busy() or not _move.has("armor"):
		return false
	var armor: Dictionary = _move["armor"]
	var ms: float = elapsed_ms()
	return ms >= float(armor.get("from_ms", 0.0)) and ms <= float(armor.get("to_ms", 0.0))


# ---- internals ----

func _ms_at(now_usec: int) -> float:
	return float(now_usec - _start_usec) / 1000.0


func _begin(move_id: StringName, begin_usec: int) -> bool:
	if _set == null or not _set.has_move(_owner_set, move_id):
		return false
	if is_busy():
		_pending.append_array(_interrupt_events())
	_move = _set.get_move(_owner_set, move_id)
	_id = move_id
	_start_usec = begin_usec
	_last_usec = begin_usec
	_phase = PHASE_STARTUP
	_boxes_on.clear()
	_next_event = 0
	_swing_counter += 1
	_swing_id = _swing_counter
	_timeline = _build_timeline(_move)
	return true


func _clear() -> void:
	_move = {}
	_id = &""
	_phase = IDLE
	_timeline = []
	_next_event = 0
	_boxes_on.clear()


func _interrupt_events() -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	var indices: Array = _boxes_on.keys()
	indices.sort()
	for index: Variant in indices:
		events.append({"type": "hitbox_off", "index": int(index), "t_ms": elapsed_ms()})
	events.append({"type": "interrupted", "move_id": _id, "t_ms": elapsed_ms()})
	return events


func _apply(event: Dictionary) -> void:
	match String(event["type"]):
		"phase":
			_phase = event["phase"]
		"hitbox_on":
			_boxes_on[int(event["index"])] = true
		"hitbox_off":
			_boxes_on.erase(int(event["index"]))
		"done":
			_clear()


static func _build_timeline(move: Dictionary) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	_row_seq = 0
	var startup: float = float(move["startup_ms"])
	var active: float = float(move["active_ms"])
	var recovery: float = float(move["recovery_ms"])
	var total: float = float(move["total_ms"])
	if startup > 0.0:
		rows.append(_row(0.0, ORDER_PHASE, {"type": "phase", "phase": PHASE_STARTUP}))
	if active > 0.0:
		rows.append(_row(startup, ORDER_PHASE, {"type": "phase", "phase": PHASE_ACTIVE}))
	if recovery > 0.0:
		rows.append(_row(startup + active, ORDER_PHASE, {"type": "phase", "phase": PHASE_RECOVERY}))
	if active > 0.0 and ((move["hitboxes"] as Array).size() > 0 or move.has("swing")):
		rows.append(_row(startup, ORDER_SWING, {"type": "swing", "swing": move.get("swing", {})}))
	if float(move["telegraph_ms"]) >= 0.0:
		rows.append(_row(float(move["telegraph_ms"]), ORDER_TELEGRAPH, {"type": "telegraph"}))
	var boxes: Array = move["hitboxes"]
	for i: int in range(boxes.size()):
		var box: Dictionary = (boxes[i] as Dictionary).duplicate()
		box["index"] = i       # so Hitbox.activate(box, ...) and deactivate(index) agree
		rows.append(_row(float(box.get("from_ms", startup)), ORDER_ON, {"type": "hitbox_on", "index": i, "box": box}))
		rows.append(_row(float(box.get("to_ms", startup + active)), ORDER_OFF, {"type": "hitbox_off", "index": i}))
	var anim: Dictionary = move.get("anim", {})
	var keys: Array = anim.get("keys", [])
	for key: Variant in keys:
		var key_dict: Dictionary = key
		rows.append(_row(float(key_dict.get("at_ms", 0.0)), ORDER_POSE, {"type": "pose",
				"clip": StringName(str(key_dict.get("clip", anim.get("clip", "")))), "clip_s": float(key_dict.get("clip_s", 0.0))}))
	rows.append(_row(total, ORDER_DONE, {"type": "done", "move_id": StringName(str(move["id"]))}))
	rows.sort_custom(_row_before)
	var events: Array[Dictionary] = []
	for row: Dictionary in rows:
		events.append(row["event"])
	return events


static func _row(t_ms: float, order: int, event: Dictionary) -> Dictionary:
	event["t_ms"] = t_ms
	_row_seq += 1
	return {"t": t_ms, "order": order, "seq": _row_seq, "event": event}


static func _row_before(a: Dictionary, b: Dictionary) -> bool:
	if not is_equal_approx(float(a["t"]), float(b["t"])):
		return float(a["t"]) < float(b["t"])
	if int(a["order"]) != int(b["order"]):
		return int(a["order"]) < int(b["order"])
	return int(a["seq"]) < int(b["seq"])
