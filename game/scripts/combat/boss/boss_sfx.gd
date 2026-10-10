class_name BossSfx
extends RefCounted
## Plays one of the boss sounds the Audio Designer made (data/audio/sfx.json: boss_*, mech_*). A sound that is not registered is
## skipped quietly, so a boss never spams warnings while a sound is still missing.


static func play(id: StringName) -> void:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null:
		return
	var audio: Node = tree.root.get_node_or_null("AudioManager")
	if audio != null and audio.has_method(&"has_sfx") and bool(audio.call(&"has_sfx", id)):
		audio.call(&"play_sfx", id)
