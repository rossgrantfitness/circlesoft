class_name ActionPrompt
extends Label
## A one-line prompt near the bottom of the screen ("JUMP!") for the moments a scene waits for one
## button press: the train's leap onto the platform. It blinks gently and waits as long as it has
## to. Text comes from data/text/train.json (or any string); the look is the shared UI text style.

const COLOR: Color = Color(1.0, 0.82, 0.45)
const BLINK_S: float = 0.45
const Y: float = 150.0

var _age: float = 0.0


## Puts a prompt on the shared UI stage. Returns it (free it when the press has come).
static func show_on_stage(tree: SceneTree, text: String) -> Control:
	if tree == null or text.is_empty():
		return null
	var prompt: ActionPrompt = ActionPrompt.new()
	prompt.text = text
	UiStage.get_or_create(tree).get_stage_root().add_child(prompt)
	return prompt


func _ready() -> void:
	name = "ActionPrompt"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UiText.style_label(self, "menu", COLOR)
	size = Vector2(float(UiStage.STAGE_SIZE.x), 20.0)
	position = Vector2(0.0, Y)
	z_index = 6


func _process(delta: float) -> void:
	_age += delta
	visible = int(_age / BLINK_S) % 4 != 3
