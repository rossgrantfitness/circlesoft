class_name LauncherInput
extends RefCounted
## The three ways to make a launcher (feel knob `launcher_input`, Ross picks by playing). Only the input
## token changes; the move graph is the same in all three (contract 3).
##   hold_heavy : heavy starts on press; if the button is still down `launcher_hold_ms` into heavy's
##                startup, it turns into the launcher.
##   back_heavy : heavy with the stick pulled away from the facing direction is a launcher.
##   string_end : heavy pressed inside the string-end move's chain window is a launcher.
## Pure functions of what the player is doing; ActionPlayer calls them.

const MODE_HOLD: String = "hold_heavy"
const MODE_BACK: String = "back_heavy"
const MODE_STRING_END: String = "string_end"
const TOKEN_HEAVY: StringName = &"heavy"
const TOKEN_LAUNCH: StringName = &"launch"


## The token a fresh `heavy` press becomes.
## ctx: {stick_back: bool, current_move: StringName, chain_open: bool, string_end_move: StringName}
static func token_for_heavy_press(mode: String, ctx: Dictionary) -> StringName:
	match mode:
		MODE_BACK:
			if bool(ctx.get("stick_back", false)):
				return TOKEN_LAUNCH
		MODE_STRING_END:
			var end_move: StringName = StringName(str(ctx.get("string_end_move", "")))
			if end_move != &"" and StringName(str(ctx.get("current_move", ""))) == end_move and bool(ctx.get("chain_open", false)):
				return TOKEN_LAUNCH
	return TOKEN_HEAVY


## hold_heavy only: true when a running heavy should now turn into the launcher.
static func should_upgrade_heavy(mode: String, current_move: StringName, heavy_move: StringName,
		in_startup: bool, held_ms: float, hold_ms: float) -> bool:
	return mode == MODE_HOLD and current_move == heavy_move and in_startup and held_ms >= hold_ms
