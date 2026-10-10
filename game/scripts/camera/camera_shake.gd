class_name CameraShake
extends RefCounted
## Smooth camera shake (combat_api.md 4.8): sines, not the PSX stepped kind; decays in REAL time (never the fighters' combat
## clock, so hit-stop does not freeze it); only ever produces an offset for the Camera3D, never for the pivot, so aim and lock
## framing do not drift. Several shakes at once add up (capped), each fading on its own.
##
## OrbitCamera keeps a small shake of its own and reads the profiles from data/combat/fx.json `shake.<id>`; this class is the
## same idea as a reusable piece (with a slight roll) so the camera can swap its internals for it with one line:
##     var shaker: CameraShake = CameraShake.new();  shaker.add(CameraShake.profile("heavy"), mult);  offset = shaker.step(delta)

const DATA_ID: String = "combat/fx"
const MAX_AMPLITUDE_M: float = 0.25
const MAX_LAYERS: int = 6
## Horizontal and vertical wave settings (two incommensurate waves per axis keep it from looking like a metronome).
const WAVE_X2: float = 1.7
const WAVE_Y: float = 0.9
const WAVE_Y2: float = 2.3
const ROLL_PER_M: float = 0.9          # radians of roll per metre of amplitude

## The most one shake (and the sum of all running) may move the camera, metres. Red's camera is 4.5 m away, so 0.25 m is
## plenty; the giant-robot scale test (CS-21) sets this per body size (about 3 m for a camera 75 m back) so a 50 m footstep still reads.
var max_amplitude_m: float = MAX_AMPLITUDE_M

var _layers: Array[Dictionary] = []    # {amp, total, left, hz, time, seed}
var _count: int = 0


## The profile dictionary (amplitude_m, duration_s, frequency_hz) for an id from fx.json, empty if unknown.
static func profile(id: StringName) -> Dictionary:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	var db: Node = tree.root.get_node_or_null("DataDB") if tree != null else null
	if db == null:
		return {}
	var found: Variant = db.call("get_value", DATA_ID, "shake.%s" % id, null)
	return found as Dictionary if found is Dictionary else {}


## Starts a shake. `mult` scales its amplitude (the shake_scale knob, a bigger hit...).
func add(cfg: Dictionary, mult: float = 1.0) -> void:
	var amp: float = clampf(float(cfg.get("amplitude_m", 0.0)) * mult, 0.0, max_amplitude_m)
	var seconds: float = float(cfg.get("duration_s", 0.0))
	if amp <= 0.0 or seconds <= 0.0:
		return
	_count += 1
	_layers.append({"amp": amp, "total": seconds, "left": seconds, "hz": float(cfg.get("frequency_hz", 24.0)), "time": 0.0, "seed": float(_count) * 1.618})
	while _layers.size() > MAX_LAYERS:
		_layers.remove_at(0)


func is_active() -> bool:
	return not _layers.is_empty()


## The amplitude of everything running right now, metres (eases out: the envelope is squared, so the tail is gentle).
func amplitude_now() -> float:
	var total: float = 0.0
	for layer: Dictionary in _layers:
		total += _envelope(layer)
	return minf(total, max_amplitude_m)


## Advances by `dt` REAL seconds and returns the camera offset (x right, y up, z 0).
func step(dt: float) -> Vector3:
	var offset: Vector3 = Vector3.ZERO
	var alive: Array[Dictionary] = []
	for layer: Dictionary in _layers:
		layer["time"] = float(layer["time"]) + dt
		layer["left"] = float(layer["left"]) - dt
		if float(layer["left"]) <= 0.0:
			continue
		alive.append(layer)
		var amp: float = _envelope(layer)
		var phase: float = float(layer["time"]) * float(layer["hz"]) * TAU
		# starts from zero (no jolt), then two incommensurate sines per axis; each layer has its own slight phase twist
		var twist: float = 1.0 + 0.07 * sin(float(layer["seed"]))
		offset += Vector3(sin(phase * twist) + 0.5 * sin(phase * WAVE_X2), sin(phase * WAVE_Y) + 0.5 * sin(phase * WAVE_Y2), 0.0) * amp * 0.6
	_layers = alive
	return offset


## The slight roll that goes with the current shake, radians.
func roll_now() -> float:
	var total: float = 0.0
	for layer: Dictionary in _layers:
		total += sin(float(layer["time"]) * float(layer["hz"]) * 0.7 * TAU + float(layer["seed"])) * _envelope(layer)
	return total * ROLL_PER_M


func clear() -> void:
	_layers.clear()


static func _envelope(layer: Dictionary) -> float:
	var k: float = clampf(float(layer["left"]) / maxf(float(layer["total"]), 0.0001), 0.0, 1.0)
	return float(layer["amp"]) * k * k
