## splash.gd
## ---------------------------------------------------------------------------
## Initial entry point of the application. 
## Immediately transitions to the branded loading screen to load the Main Menu.
## ---------------------------------------------------------------------------
extends Node

func _ready() -> void:
	# Small delay to ensure the engine is fully initialized before transition
	get_tree().create_timer(0.1).timeout.connect(_start_loading)

func _start_loading() -> void:
	UIHelpers.go_to_scene_with_loading(get_tree(), Scenes.HOME)
