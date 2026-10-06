class_name InteractionTuning
extends RefCounted
## Typed view of data/world/interaction.json: how Red picks what to use, the prompt icon, and the
## NPC placeholder behavior. A missing key logs an error and reads as 0.

const TUNING_ID: String = "world/interaction"

var reach: float = 0.0
var max_height_diff: float = 0.0
var front_min_dot: float = 0.0
var always_in_reach_distance: float = 0.0
var prompt_head_height: float = 0.0
var prompt_gap_px: float = 0.0
var prompt_bob_px: float = 0.0
var prompt_bob_period_s: float = 0.0
var prompt_pop_scales: Array[float] = []
var prompt_pop_step_s: float = 0.0
var npc_turn_rate_deg_per_s: float = 0.0
var npc_bob_height: float = 0.0
var npc_bob_period_s: float = 0.0


static func from_db(db: Node) -> InteractionTuning:
	if db == null:
		push_error("InteractionTuning: no DataDB available")
		return InteractionTuning.new()
	return from_dict(db.call("get_dict", TUNING_ID))


static func from_dict(data: Dictionary) -> InteractionTuning:
	var t: InteractionTuning = InteractionTuning.new()
	t.reach = FieldTuning._number(data, "reach")
	t.max_height_diff = FieldTuning._number(data, "max_height_diff")
	t.front_min_dot = FieldTuning._number(data, "front_min_dot")
	t.always_in_reach_distance = FieldTuning._number(data, "always_in_reach_distance")
	t.prompt_head_height = FieldTuning._number(data, "prompt.head_height")
	t.prompt_gap_px = FieldTuning._number(data, "prompt.gap_px")
	t.prompt_bob_px = FieldTuning._number(data, "prompt.bob_px")
	t.prompt_bob_period_s = FieldTuning._number(data, "prompt.bob_period_s")
	t.prompt_pop_step_s = FieldTuning._number(data, "prompt.pop_step_s")
	var pops: Variant = (data.get("prompt", {}) as Dictionary).get("pop_scales", [])
	if pops is Array:
		for scale: Variant in pops:
			t.prompt_pop_scales.append(float(scale))
	t.npc_turn_rate_deg_per_s = FieldTuning._number(data, "npc.turn_rate_deg_per_s")
	t.npc_bob_height = FieldTuning._number(data, "npc.bob_height")
	t.npc_bob_period_s = FieldTuning._number(data, "npc.bob_period_s")
	return t
