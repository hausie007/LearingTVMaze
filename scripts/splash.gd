extends Control

func _ready() -> void:
	# Keep the splash screen visible for 1.5 seconds, then load the main menu
	await get_tree().create_timer(1.5).timeout
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
