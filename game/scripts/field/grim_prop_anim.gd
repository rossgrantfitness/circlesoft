class_name GrimPropAnim
extends Node3D
## The little stepped animations on the grim dressing props, all done in code (Ross never animates these):
##   FLICKER  a neon or holo sign: a pattern of on / dim / off steps ("1110110h1") at `fps`
##   FRAMES   a propaganda screen: swaps between painted frames
##   STEAM    a vent: three puffs that grow and rise in steps, then reset
## Everything steps (no smooth easing), like the rest of the PSX look. `advance(steps)` is for tests.

enum Mode { FLICKER, FRAMES, STEAM }

var mode: Mode = Mode.FLICKER
var fps: float = 8.0
## FLICKER: one character per step. "1" on, "h" dim, "0" off.
var pattern: String = "1"
var energy_on: float = 1.5
var material: ShaderMaterial = null
## FRAMES: the textures to cycle, and the sequence of frame indices.
var frames: Array[Texture2D] = []
var sequence: PackedInt32Array = PackedInt32Array([0])
## STEAM: the puff quads (their rest positions are remembered).
var puffs: Array[MeshInstance3D] = []
var rise: float = 0.9

var step_index: int = 0
var _clock: float = 0.0
var _puff_home: Array[Vector3] = []


func _ready() -> void:
	for puff: MeshInstance3D in puffs:
		_puff_home.append(puff.position)
	_apply()


func _process(delta: float) -> void:
	_clock += delta
	var wanted: int = int(_clock * fps)
	if wanted != step_index:
		step_index = wanted
		_apply()


## Jumps ahead by whole steps (tests).
func advance(steps: int) -> void:
	step_index += steps
	_apply()


## Where the animation is, as a value the tests and the look can read: the sign's current energy,
## the screen's current frame index, or the lead puff's height above its rest position.
func current_value() -> float:
	match mode:
		Mode.FLICKER:
			return material.get_shader_parameter(&"emission_energy") if material != null else 0.0
		Mode.FRAMES:
			return float(sequence[step_index % sequence.size()])
		_:
			return puffs[0].position.y - _puff_home[0].y if (not puffs.is_empty() and not _puff_home.is_empty()) else 0.0


func _apply() -> void:
	match mode:
		Mode.FLICKER:
			if material == null or pattern.is_empty():
				return
			var code: String = pattern.substr(step_index % pattern.length(), 1)
			var level: float = energy_on if code == "1" else (energy_on * 0.4 if code == "h" else 0.06)
			material.set_shader_parameter(&"emission_energy", level)
		Mode.FRAMES:
			if material == null or frames.is_empty():
				return
			var frame: int = sequence[step_index % sequence.size()]
			material.set_shader_parameter(&"albedo_texture", frames[frame % frames.size()])
		Mode.STEAM:
			var cycle: int = 6
			for i: int in puffs.size():
				var local: int = (step_index + i * 2) % cycle
				var t: float = float(local) / float(cycle - 1)
				var puff: MeshInstance3D = puffs[i]
				puff.position = _puff_home[i] + Vector3(0.05 * float(i - 1) * t, rise * t, 0.0)
				puff.scale = Vector3.ONE * (0.5 + t * 0.9)
				puff.visible = local != cycle - 1
