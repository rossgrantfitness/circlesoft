class_name PressSource
extends RefCounted
## Where Clutch presses come from. The controller asks the source about each press slot of an
## action. The Human source says "the view will call press_down/press_up"; the others plan
## presses ahead of time from the cue (the simulator's players), or force a rating (Auto-Timing).

const NO_RATING: String = ""


## True when real button events arrive through press_down / press_up.
func is_human() -> bool:
	return false


## Non-empty = every press is judged as that rating (Auto-Timing); no events are needed.
func forced_rating() -> String:
	return NO_RATING


## Planned events for a slot: {"downs": Array[int], "ups": Array[int]} in clock microseconds.
## slot is a ClutchJudge slot plus "type" and "side". Human and forced sources return nothing.
func plan(_slot: Dictionary, _rng: RandomNumberGenerator) -> Dictionary:
	return {"downs": [] as Array[int], "ups": [] as Array[int]}
