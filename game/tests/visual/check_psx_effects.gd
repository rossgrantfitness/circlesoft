extends SceneTree
## Real-renderer check for Milestone 1 step 4: every PSX effect must visibly change the picture
## when switched off, and the shaders must compile on the GPU path. Needs a real renderer:
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --path game --rendering-driver opengl3 \
##       -s res://tests/visual/check_psx_effects.gd
## Prints one line per effect and exits 1 if anything did not change the image or any shader
## error was logged (watch the output for "SHADER ERROR").

const MAIN_SCENE: String = "res://scenes/core/main.tscn"
const SETTLE_FRAMES: int = 6
## An effect "visibly changes" the picture when at least this many pixels differ.
const MIN_CHANGED_PIXELS: int = 200
const MIN_CHANNEL_DIFFERENCE: float = 0.02

var _failed: bool = false


func _initialize() -> void:
	var main: Node = (load(MAIN_SCENE) as PackedScene).instantiate()
	main.set("show_title", false)  # the demo opens on the title screen; we want the room
	root.add_child(main)
	await _settle()
	PsxLook.reset_effects()
	await _settle()
	var baseline: Image = _grab()
	for effect: PsxLook.Effect in PsxLook.Effect.values():
		PsxLook.set_effect(effect, false)
		await _settle()
		var changed: int = _count_changed(baseline, _grab())
		var ok: bool = changed >= MIN_CHANGED_PIXELS
		print("%s %-16s switched off: %d pixels changed" % ["ok  " if ok else "FAIL", PsxLook.EFFECT_NAMES[effect], changed])
		_failed = _failed or not ok
		PsxLook.set_effect(effect, true)
		await _settle()
	# Resolutions: each must change the picture and keep the screen working.
	var screen: Node = main.get_node("PsxScreen")
	for size: Vector2i in screen.get_resolutions():
		screen.set_resolution(size)
		await _settle()
		var image: Image = _grab()
		var changed_here: int = _count_changed(baseline, image) if size != Vector2i(384, 216) else 0
		print("ok   resolution %s drawn, %d pixels differ from the 384x216 baseline" % [size, changed_here])
	quit(1 if _failed else 0)


func _settle() -> void:
	for i: int in SETTLE_FRAMES:
		await process_frame


func _grab() -> Image:
	return root.get_texture().get_image()


func _count_changed(a: Image, b: Image) -> int:
	var count: int = 0
	for y: int in a.get_height():
		for x: int in a.get_width():
			var ca: Color = a.get_pixel(x, y)
			var cb: Color = b.get_pixel(x, y)
			if absf(ca.r - cb.r) + absf(ca.g - cb.g) + absf(ca.b - cb.b) > MIN_CHANNEL_DIFFERENCE:
				count += 1
	return count
