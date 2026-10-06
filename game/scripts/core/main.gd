extends Node
## The game's root scene. Holds the PSX screen and loads the first scene into its world.
## Later milestones swap start_scene for the title screen; for now it is the PSX test room.

@export var start_scene: PackedScene

@onready var screen: PsxScreen = $PsxScreen


func _ready() -> void:
	if start_scene != null:
		screen.load_world(start_scene)
