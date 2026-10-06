extends SceneTree
## Captures a small gallery of in-game shots of the M1 demo for sharing progress with Ross.
## Needs a real renderer (not --headless):
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --path game --rendering-driver opengl3 \
##       -s res://tests/visual/capture_gallery.gd
## Writes PNGs to docs/screenshots/gallery/ (path is relative to the game/ folder).

const MAIN_SCENE: String = "res://scenes/core/main.tscn"
const OUTPUT_DIR: String = "res://../docs/screenshots/gallery/"
const ROOM_PATH: String = "PsxScreen/WorldViewport/World/PsxTestRoom"
const SETTLE_FRAMES: int = 90

## Shot name -> where Red stands. Positions are in the test room's coordinates.
const SPOT_START: Vector3 = Vector3(-1.0, 0.05, 0.5)
const SPOT_WING: Vector3 = Vector3(10.5, 0.05, 0.5)
const SPOT_PILLAR: Vector3 = Vector3(1.3, 0.05, -0.3)
const SPOT_LAMP: Vector3 = Vector3(-3.0, 0.05, -2.0)

var _main: Node
var _room: Node3D
var _player: Node3D
var _failures: int = 0


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	_main = (load(MAIN_SCENE) as PackedScene).instantiate()
	_main.set("show_title", false)
	root.add_child(_main)
	await _wait(10)
	_room = _main.get_node(ROOM_PATH)
	_player = _room.get("player")

	await _shot("01_room_start", SPOT_START)
	await _shot("02_by_the_lamp", SPOT_LAMP)
	await _shot("03_camera_slides_into_wing", SPOT_WING)
	await _shot("04_pillar_fades_behind", SPOT_PILLAR)

	for effect: int in PsxLook.Effect.values():
		PsxLook.set_effect(effect, false)
	await _shot("05_psx_effects_all_off", SPOT_START)
	PsxLook.reset_effects()

	var screen: PsxScreen = _main.get_node("PsxScreen")
	screen.set_resolution(Vector2i(320, 240))
	await _shot("06_resolution_320x240", SPOT_START)
	screen.set_resolution(Vector2i(384, 216))

	var camera: DioramaCamera = _room.get_node("CameraRig")
	camera.set_projection_mode(DioramaCamera.ProjectionMode.ORTHOGRAPHIC)
	await _shot("07_flat_orthographic_camera", SPOT_START)

	quit(0 if _failures == 0 else 1)


func _shot(shot_name: String, spot: Vector3) -> void:
	_player.global_position = spot
	await _wait(SETTLE_FRAMES)
	var path: String = OUTPUT_DIR + shot_name + ".png"
	var image: Image = root.get_texture().get_image()
	var err: Error = image.save_png(path)
	if err != OK:
		_failures += 1
	print("saved %s (%s), error %d" % [path, image.get_size(), err])


func _wait(frames: int) -> void:
	for i: int in frames:
		await process_frame
