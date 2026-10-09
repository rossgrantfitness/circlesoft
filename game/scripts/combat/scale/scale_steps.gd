class_name ScaleSteps
extends RefCounted
## Footfall timing for the robots (task CS-21). A step is the moment a foot plants in the walk or run clip. The times come from
## data/combat/fx.json scale_sets.<set>.footfalls_s (seconds at playback 1.0, left foot first), and the controller asks which of
## them the animation passed since last frame. Pure: positions in, indices out.


## Indices of the `times` (seconds into a loop of `length_s`) that the playhead passed between `prev_s` and `now_s`.
## A loop that wrapped (now < prev) counts the end of the loop and the start of the next one. A time at or past the loop's end
## is the wrap point itself.
static func crossed(prev_s: float, now_s: float, length_s: float, times: Array) -> Array[int]:
	var out: Array[int] = []
	if length_s <= 0.0:
		return out
	var wrapped: bool = now_s < prev_s - 0.000001
	for i: int in times.size():
		var t: float = fposmod(float(times[i]), length_s)
		var hit: bool = false
		if wrapped:
			hit = t >= prev_s or t < now_s
		else:
			hit = t > prev_s and t <= now_s
		if hit:
			out.append(i)
	return out


## Seconds between two steps of one foot at a playback speed (the loop length over the speed): how often a huge step lands.
static func loop_period_s(length_s: float, playback: float) -> float:
	return length_s / maxf(playback, 0.0001)
