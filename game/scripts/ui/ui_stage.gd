class_name UiStage
extends Control
## The sharp 384x216 layer for speech bubbles and menus. It owns a transparent SubViewport at the
## internal UI size and shows it with nearest-neighbor filtering at the same rectangle as the PSX
## picture, so UI pixels are exactly as big as the 3D pixels (the same grid the title screen uses).
##
## Add things to `get_stage_root()` and lay them out in 384x216 coordinates. Input: real events
## reach this node (it lives in the root viewport) and are forwarded into the sub-viewport, with
## mouse positions converted to stage pixels, so any Control inside can use _input normally.
##
## UiStage.get_or_create(tree) finds the stage or builds one: inside PsxScreen's UI layer when a
## PsxScreen exists (and follows its layout), otherwise filling the window.
##
## Modal groups: speech bubbles and the field menu join group MODAL_GROUP while they are active
## (and for a couple of frames after), so field code can ask "is the UI busy?" with is_busy().

const GROUP: StringName = &"ui_stage"
const MODAL_GROUP: StringName = &"ui_modal"
const SCREEN_GROUP: StringName = &"psx_screen"
const STAGE_SIZE: Vector2i = Vector2i(384, 216)
const MIN_FILL: float = 0.8

var _viewport: SubViewport = null
var _root: Control = null
var _display: TextureRect = null
var _screen: PsxScreen = null


func _init() -> void:
	name = "UiStage"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_viewport = SubViewport.new()
	_viewport.name = "UiViewport"
	_viewport.size = STAGE_SIZE
	_viewport.transparent_bg = true
	_viewport.disable_3d = true
	_viewport.gui_disable_input = false
	_viewport.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_viewport)
	_root = Control.new()
	_root.name = "Stage"
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.size = Vector2(STAGE_SIZE)
	_viewport.add_child(_root)
	_display = TextureRect.new()
	_display.name = "Display"
	_display.texture = _viewport.get_texture()
	_display.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_display.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_display.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_display)


func _ready() -> void:
	add_to_group(GROUP)
	resized.connect(_apply_layout)
	_apply_layout()


## The stage the UI is built on. Children use 384x216 coordinates.
func get_stage_root() -> Control:
	return _root


func get_stage_size() -> Vector2:
	return Vector2(STAGE_SIZE)


func get_stage_viewport() -> SubViewport:
	return _viewport


## Follow a PsxScreen: the stage sits exactly over the 3D picture and re-lays out when it moves.
func attach_to_screen(screen: PsxScreen) -> void:
	_screen = screen
	if not screen.layout_changed.is_connected(_on_screen_layout):
		screen.layout_changed.connect(_on_screen_layout)
	_apply_layout()


func _on_screen_layout(_rect: Rect2) -> void:
	_apply_layout()


## Where the picture sits, in this node's coordinates.
func get_display_rect() -> Rect2:
	return Rect2(_display.position, _display.size)


## Window pixels per stage pixel right now.
func get_display_scale() -> float:
	return _display.size.x / float(STAGE_SIZE.x)


## A point in this node's coordinates (what mouse events carry) -> stage pixels.
func to_stage(point: Vector2) -> Vector2:
	var scale: float = get_display_scale()
	if scale <= 0.0:
		return Vector2.ZERO
	return (point - _display.position) / scale


func _apply_layout() -> void:
	if _display == null:
		return
	var rect: Rect2
	if _screen != null and is_instance_valid(_screen):
		rect = _screen.get_display_rect()
	else:
		rect = PsxScreen.compute_display_rect(size, STAGE_SIZE, true, MIN_FILL)
	_display.position = rect.position
	_display.size = rect.size


func _input(event: InputEvent) -> void:
	var forwarded: InputEvent = event
	if event is InputEventMouse:
		forwarded = event.duplicate() as InputEvent
		var mouse: InputEventMouse = forwarded as InputEventMouse
		mouse.position = to_stage(get_global_transform().affine_inverse() * event.position)
		mouse.global_position = mouse.position
	_viewport.push_input(forwarded, true)
	if _viewport.is_input_handled():
		get_viewport().set_input_as_handled()


# ---- finding and building the stage ----

## The stage in the tree, or a new one (in the PsxScreen's UI layer if there is a PsxScreen, else
## on the root window). Safe to call any time after the tree is running.
static func get_or_create(tree: SceneTree) -> UiStage:
	var found: Node = tree.get_first_node_in_group(GROUP)
	if found is UiStage:
		return found as UiStage
	var stage: UiStage = UiStage.new()
	var screen: Node = tree.get_first_node_in_group(SCREEN_GROUP)
	if screen is PsxScreen:
		(screen as PsxScreen).get_ui_layer().add_child(stage)
		stage.attach_to_screen(screen as PsxScreen)
	else:
		tree.root.add_child(stage)
	return stage


## True while any speech bubble or menu is up (or just closed this frame). Field input (interact,
## jump, opening the menu) should be ignored while this is true.
static func is_busy(tree: SceneTree) -> bool:
	return not tree.get_nodes_in_group(MODAL_GROUP).is_empty()
