extends SceneTree
## The pose strip for the animated placeholder Red: four key poses from each clip (idle, walk, run,
## jump, fall, land), in the real PSX look, three-quarter view, on the style stage.
## Needs a real renderer (not --headless):
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --path game --rendering-driver opengl3 \
##       -s res://tests/visual/capture_red_shiba_sheet.gd
## Writes docs/screenshots/red_shiba_anim_sheet.png. No game classes are named here; the stage is
## driven through call() so this script compiles before the autoloads exist.

const STAGE_SCENE: String = "res://scenes/debug/style_stage.tscn"
const MODEL_FILE: String = "res://art/placeholder/characters/red/red_shiba.glb"
const OUTPUT_PATH: String = "res://../docs/screenshots/red_shiba_anim_sheet.png"
const SETTLE_FRAMES: int = 5
const FPS: float = 15.0
## clip: [frames in the clip, the frame numbers to show]
const CLIPS: Array = [
	["idle", 22, [0, 5, 11, 16]],
	["walk", 12, [0, 3, 6, 9]],
	["run", 9, [0, 2, 4, 7]],
	["jump", 6, [0, 1, 2, 6]],
	["fall", 8, [0, 2, 4, 6]],
	["land", 4, [0, 1, 2, 4]],
]
## The picture is 384x216 native; Red is cut out of the middle and shown at 2x.
const CROP_WIDTH: int = 130
const SCALE: int = 2
const LABEL_HEIGHT: int = 40
const CLIPS_PER_BAND: int = 2
const GAP: int = 16
const BACKGROUND: Color = Color(0.0784, 0.0706, 0.1216)
const LABEL_COLOR: Color = Color(0.93, 0.92, 0.85)
const LABEL_FONT: String = "res://art/final/ui/fonts/Nunito-VariableFont_wght.ttf"
const LABEL_SIZE: int = 26

var _stage: Node = null


func _initialize() -> void:
	_stage = (load(STAGE_SCENE) as PackedScene).instantiate()
	root.add_child(_stage)
	await _settle()
	var fitted: Array[String] = ["f"]
	_stage.call("frame_for", fitted)          # same framing as the locked prototype
	if not _stage.call("load_model_file", MODEL_FILE, "shiba"):
		quit(1)
		return
	_stage.call("show_close", "34")
	var pictures: Array = []                   # per clip: Array of Image
	for clip: Array in CLIPS:
		var row: Array[Image] = []
		for frame: int in clip[2]:
			if not _stage.call("pose_clip", clip[0], float(frame) / FPS):
				push_error("capture_red_shiba_sheet: missing clip " + String(clip[0]))
				quit(1)
				return
			await _settle()
			var big: Image = _stage.call("grab_picture")
			var native: Image = big.duplicate()
			native.resize(384, 216, Image.INTERPOLATE_NEAREST)
			row.append(native.get_region(Rect2i((384 - CROP_WIDTH) / 2, 0, CROP_WIDTH, 216)))
		pictures.append(row)
	await _build_sheet(pictures)
	quit(0)


func _settle() -> void:
	for i: int in SETTLE_FRAMES:
		await process_frame


func _build_sheet(pictures: Array) -> void:
	var cell_w: int = CROP_WIDTH * SCALE
	var cell_h: int = 216 * SCALE
	var clip_w: int = 4 * cell_w
	var bands: int = int(ceil(float(CLIPS.size()) / CLIPS_PER_BAND))
	var width: int = CLIPS_PER_BAND * clip_w + (CLIPS_PER_BAND + 1) * GAP
	var height: int = bands * (cell_h + LABEL_HEIGHT) + (bands + 1) * GAP
	var viewport: SubViewport = SubViewport.new()
	viewport.size = Vector2i(width, height)
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	var canvas: Control = Control.new()
	viewport.add_child(canvas)
	var background: ColorRect = ColorRect.new()
	background.color = BACKGROUND
	background.size = Vector2(width, height)
	canvas.add_child(background)
	var font: Font = load(LABEL_FONT) as Font
	for c: int in CLIPS.size():
		var band: int = c / CLIPS_PER_BAND
		var column: int = c % CLIPS_PER_BAND
		var left: int = GAP + column * (clip_w + GAP)
		var top: int = GAP + band * (cell_h + LABEL_HEIGHT + GAP)
		var clip: Array = CLIPS[c]
		var frames: Array = clip[2]
		var label: Label = Label.new()
		label.text = "%s   (frames %s of %d)" % [String(clip[0]).to_upper(), ", ".join(frames.map(func(f: int) -> String: return str(f))), clip[1]]
		label.position = Vector2(left, top)
		if font != null:
			label.add_theme_font_override("font", font)
		label.add_theme_font_size_override("font_size", LABEL_SIZE)
		label.add_theme_color_override("font_color", LABEL_COLOR)
		canvas.add_child(label)
		for i: int in frames.size():
			var rect: TextureRect = TextureRect.new()
			rect.texture = ImageTexture.create_from_image(pictures[c][i])
			rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			rect.stretch_mode = TextureRect.STRETCH_SCALE
			rect.size = Vector2(cell_w, cell_h)
			rect.position = Vector2(left + i * cell_w, top + LABEL_HEIGHT)
			canvas.add_child(rect)
	root.add_child(viewport)
	await _settle()
	await RenderingServer.frame_post_draw
	var sheet: Image = viewport.get_texture().get_image()
	var err: Error = sheet.save_png(OUTPUT_PATH)
	print("saved %s (%s), error %d" % [OUTPUT_PATH, sheet.get_size(), err])
	viewport.queue_free()
