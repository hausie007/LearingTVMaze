extends Control

@onready var play_btn: Button = %PlayButton
@onready var settings_btn: Button = %SettingsButton
@onready var title_label: Label = %Title

func _ready() -> void:
	play_btn.pressed.connect(_on_play_pressed)
	settings_btn.pressed.connect(_on_settings_pressed)
	
	# Localize UI
	title_label.text = tr("app_title")
	play_btn.text = tr("play")
	settings_btn.text = tr("settings")
	
	# Pre-select Play button for TV D-pad
	play_btn.grab_focus()

func _on_play_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/main.tscn")

func _on_settings_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/settings_menu.tscn")
