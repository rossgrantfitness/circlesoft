class_name AutoTimingPressSource
extends PressSource
## The Auto-Timing accessibility option: every press (attack and block, tap, hold or string cue)
## lands as "Rad!". No button needed.

const RATING: String = ClutchJudge.RATING_RAD


func forced_rating() -> String:
	return RATING
