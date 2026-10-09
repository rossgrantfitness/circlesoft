class_name GameMode
extends RefCounted
## Which game is running: the action SLICE, the combat SANDBOX, or the shelved turn-based CLASSIC game.
## Pure (no nodes, no autoloads): it only maps command line words and feature tags to a mode, and a
## mode to the data id and save folder that mode uses (docs/slice/slice_tech_plan.md 2.1).
##
##   mode      how it starts                                   rooms data         saves go to
##   SLICE     feature tag `slice`, or `-- --slice`            slice/rooms        user://slice_saves
##   SANDBOX   feature tag `sandbox`, or `-- --sandbox`        (none)             user://feel
##   CLASSIC   `-- --classic`                                  world/rooms        user://saves
##
## A command line word beats a feature tag, so `-- --classic` on a slice build still opens the shelved
## game. When nothing names a mode, the caller's fallback is used (Main reads it from
## data/slice/slice.json "default_mode"; tests use CLASSIC so no old test changes).

enum Mode { CLASSIC, SLICE, SANDBOX }

const ARG_CLASSIC: String = "--classic"
const ARG_SLICE: String = "--slice"
const ARG_SANDBOX: String = "--sandbox"
const FEATURE_SLICE: String = "slice"
const FEATURE_SANDBOX: String = "sandbox"

const NAME_CLASSIC: String = "classic"
const NAME_SLICE: String = "slice"
const NAME_SANDBOX: String = "sandbox"

const ROOMS_ID_CLASSIC: String = "world/rooms"
const ROOMS_ID_SLICE: String = "slice/rooms"
const PLACEMENTS_ID_SLICE: String = "slice/placements"
const SAVE_DIR_CLASSIC: String = "user://saves"
const SAVE_DIR_SLICE: String = "user://slice_saves"
const SAVE_DIR_SANDBOX: String = "user://feel"


## The mode a run picks. `args` are the user args after `--` on the command line; `features` are the
## feature tags that are on. Command line words win over tags (classic, then sandbox, then slice);
## then tags (sandbox, then slice); else `fallback`.
static func resolve(args: PackedStringArray, features: PackedStringArray, fallback: Mode = Mode.CLASSIC) -> Mode:
	if args.has(ARG_CLASSIC):
		return Mode.CLASSIC
	if args.has(ARG_SANDBOX):
		return Mode.SANDBOX
	if args.has(ARG_SLICE):
		return Mode.SLICE
	if features.has(FEATURE_SANDBOX):
		return Mode.SANDBOX
	if features.has(FEATURE_SLICE):
		return Mode.SLICE
	return fallback


## resolve() for the real running game: the real command line and the real feature tags.
static func resolve_current(fallback: Mode = Mode.CLASSIC) -> Mode:
	var features: PackedStringArray = []
	for tag: String in [FEATURE_SANDBOX, FEATURE_SLICE]:
		if OS.has_feature(tag):
			features.append(tag)
	return resolve(OS.get_cmdline_user_args(), features, fallback)


## The id of the rooms file (DataDB id) for a mode. Empty for the sandbox, which has no rooms.
static func rooms_id(mode: Mode) -> String:
	match mode:
		Mode.SLICE:
			return ROOMS_ID_SLICE
		Mode.CLASSIC:
			return ROOMS_ID_CLASSIC
	return ""


## Extra placement files a mode lays over world/placements (Placements.extra_ids): the slice's own.
static func placements_ids(mode: Mode) -> Array[String]:
	var out: Array[String] = []
	if mode == Mode.SLICE:
		out.append(PLACEMENTS_ID_SLICE)
	return out


## The folder a mode keeps its files in. The slice never touches the old game's `user://saves`.
static func save_dir(mode: Mode) -> String:
	match mode:
		Mode.SLICE:
			return SAVE_DIR_SLICE
		Mode.SANDBOX:
			return SAVE_DIR_SANDBOX
	return SAVE_DIR_CLASSIC


## "classic" / "slice" / "sandbox".
static func mode_name(mode: Mode) -> String:
	match mode:
		Mode.SLICE:
			return NAME_SLICE
		Mode.SANDBOX:
			return NAME_SANDBOX
	return NAME_CLASSIC


## The mode for a name from data; unknown or empty names give `fallback`.
static func from_name(text: String, fallback: Mode = Mode.CLASSIC) -> Mode:
	match text.strip_edges().to_lower():
		NAME_SLICE:
			return Mode.SLICE
		NAME_SANDBOX:
			return Mode.SANDBOX
		NAME_CLASSIC:
			return Mode.CLASSIC
	return fallback


## True for the modes that run through SceneRouter and SaveManager (everything but the sandbox).
static func uses_router(mode: Mode) -> bool:
	return mode != Mode.SANDBOX
