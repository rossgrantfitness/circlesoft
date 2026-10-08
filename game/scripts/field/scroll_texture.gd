class_name ScrollTexture
extends MeshInstance3D
## A flat plane whose texture slides past: the rail bed and the harbor water that rush by the ore train
## (docs/maps/ore_train.md: "no moving geometry, two scrolling texture planes"). Give it a mesh and a
## material_override on the unlit PSX shader; it moves that material's uv_offset. `speed` is in texture
## repeats per second (x along the train, y across it).

@export var speed: Vector2 = Vector2(0.5, 0.0)

var _offset: Vector2 = Vector2.ZERO


func _process(delta: float) -> void:
	var material: ShaderMaterial = material_override as ShaderMaterial
	if material == null:
		return
	_offset += speed * delta
	_offset = Vector2(fposmod(_offset.x, 1.0), fposmod(_offset.y, 1.0))
	material.set_shader_parameter("uv_offset", _offset)
