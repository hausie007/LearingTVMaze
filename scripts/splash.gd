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
	var loading_scene = load("res://scenes/loading_screen.tscn").instantiate()
	loading_scene.target_scene_path = "res://scenes/main_menu.tscn"
	
	# Transition to the loading screen
	get_tree().root.add_child(loading_scene)
	get_tree().current_scene = loading_scene
	queue_free()
