extends SceneTree
## One screenshot of the PSX test room with placeholder Red standing at PlayerSpawn, for sharing
## progress with Ross. Needs a real renderer (not --headless):
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --path game --rendering-driver opengl3 \
##       -s res://tests/visual/capture_m1_test_room.gd
## Writes builds/screenshots/m1_test_room.png (builds/ is git-ignored; copy to docs/screenshots/
## to share). Whole window is captured: the low-res world, the post shader and the sharp UI.

const MAIN_SCENE: String = "res://scenes/core/main.tscn"
const RED_SCENE: String = "res://art/placeholder/characters/red/red_blockout.glb"
const OUTPUT_PATH: String = "res://../builds/screenshots/m1_test_room.png"
const IDLE_CLIP: StringName = &"idle"
const SETTLE_FRAMES: int = 12
const IDLE_TIME_S: float = 0.35
## Red turns to face the placeholder camera (yaw in degrees).
const RED_YAW_DEGREES: float = 35.0
const CAPTION: String = "LIGHTS LEFT ON - PSX test room (sharp UI layer over 384x216 world)"
const CAPTION_POSITION: Vector2 = Vector2(16, 8)
const CAPTION_FONT_SIZE: int = 20
const CAPTION_SHADOW: Color = Color(0.08, 0.07, 0.12)
const CAPTION_COLOR: Color = Color(0.93, 0.92, 0.85)


func _initialize() -> void:
	var main: Node = (load(MAIN_SCENE) as PackedScene).instantiate()
	root.add_child(main)
	for i: int in SETTLE_FRAMES:
		await process_frame
	# Nodes are fetched by path (not typed as PsxScreen) so this script compiles before autoloads.
	var screen: Node = main.get_node("PsxScreen")
	_place_red(screen.get_node("WorldViewport/World/PsxTestRoom"))
	_add_caption(screen.get_node("UILayer"))
	await create_timer(IDLE_TIME_S).timeout
	for i: int in SETTLE_FRAMES:
		await process_frame
	var image: Image = root.get_texture().get_image()
	var err: Error = image.save_png(OUTPUT_PATH)
	print("saved %s (%s), error %d" % [OUTPUT_PATH, image.get_size(), err])
	quit(0 if err == OK else 1)


func _place_red(room: Node3D) -> void:
	var red: Node3D = (load(RED_SCENE) as PackedScene).instantiate() as Node3D
	room.add_child(red)
	red.global_position = (room.get_node("PlayerSpawn") as Marker3D).global_position
	red.rotation_degrees.y = RED_YAW_DEGREES
	var players: Array[Node] = red.find_children("*", "AnimationPlayer", true, false)
	if not players.is_empty():
		(players[0] as AnimationPlayer).play(IDLE_CLIP)


func _add_caption(ui_layer: CanvasLayer) -> void:
	var label: Label = Label.new()
	label.text = CAPTION
	label.position = CAPTION_POSITION
	label.add_theme_font_size_override("font_size", CAPTION_FONT_SIZE)
	label.add_theme_color_override("font_color", CAPTION_COLOR)
	label.add_theme_color_override("font_shadow_color", CAPTION_SHADOW)
	ui_layer.add_child(label)
