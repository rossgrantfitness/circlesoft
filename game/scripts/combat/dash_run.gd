class_name DashRun
extends RefCounted
## One dash, as pure maths (docs/pivot/combat_api.md 4.2). It covers `distance_m` in `time_ms` of the
## owner's combat time, starting fast and easing off (`decay` 0 = constant speed, 0.5 = ends at half
## the starting speed), and is untouchable for the first `iframes_ms`.
##
## advance() returns the AVERAGE velocity over the step, worked out from the exact integral of the
## speed curve, so the distance travelled is the same at 30, 60 or 144 fps and a long frame can't
## overshoot the end of the dash. Time is the owner's combat time, so hit-stop freezes a dash.

var direction: Vector3 = Vector3.FORWARD
var distance_m: float = 0.0
var duration_s: float = 0.0
var iframes_s: float = 0.0
var decay: float = 0.0
var elapsed_s: float = 0.0
var air: bool = false


static func create(dir: Vector3, distance: float, time_ms: float, iframes_ms: float, decay_amount: float, in_air: bool = false) -> DashRun:
	var run: DashRun = DashRun.new()
	var flat: Vector3 = Vector3(dir.x, 0.0, dir.z)
	run.direction = flat.normalized() if flat.length() > 0.0001 else Vector3.FORWARD
	run.distance_m = maxf(distance, 0.0)
	run.duration_s = maxf(time_ms, 1.0) / 1000.0
	run.iframes_s = maxf(iframes_ms, 0.0) / 1000.0
	run.decay = clampf(decay_amount, 0.0, 0.95)
	run.air = in_air
	return run


## Speed (m/s) at the very start of the dash.
func start_speed() -> float:
	return distance_m / duration_s / (1.0 - decay * 0.5)


## Distance covered from the start to `t` seconds in (clamped to the dash).
func distance_at(t: float) -> float:
	var x: float = clampf(t, 0.0, duration_s)
	return start_speed() * (x - decay * x * x / (2.0 * duration_s))


## Moves the clock on by `delta_s` and returns the average velocity over that step.
func advance(delta_s: float) -> Vector3:
	if delta_s <= 0.0 or is_done():
		return Vector3.ZERO
	var before: float = distance_at(elapsed_s)
	elapsed_s = minf(elapsed_s + delta_s, duration_s)
	var travelled: float = distance_at(elapsed_s) - before
	return direction * (travelled / delta_s)


func is_done() -> bool:
	return elapsed_s >= duration_s


func elapsed_ms() -> float:
	return elapsed_s * 1000.0


## True while the i-frames last (from the first instant of the dash).
func invulnerable() -> bool:
	return iframes_s > 0.0 and elapsed_s < iframes_s and not is_done()


func progress() -> float:
	return clampf(elapsed_s / duration_s, 0.0, 1.0)
