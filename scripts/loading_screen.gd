## loading_screen.gd
## ---------------------------------------------------------------------------
## A minimalist loading screen that shows the brand icon and handles scene 
## transitions. Supports smooth fading and a minimum display time for polish.
## ---------------------------------------------------------------------------
extends Control

@onready var icon_rect: TextureRect = %IconRect
@onready var label: Label = %LoadingLabel

var target_scene_path: String = ""
var _min_wait_time: float = 0.8
var _start_time: float = 0.0

func _ready() -> void:
	_start_time = Time.get_ticks_msec() / 1000.0
	
	# Apply brand styling
	label.text = tr("loading")
	label.add_theme_color_override("font_color", UIColors.TEXT_PRIMARY)
	
	# Subtle animation: pulsing
	var tween = create_tween().set_loops()
	tween.tween_property(icon_rect, "scale", Vector2(1.05, 1.05), 0.8).set_trans(Tween.TRANS_SINE)
	tween.tween_property(icon_rect, "scale", Vector2(1.0, 1.0), 0.8).set_trans(Tween.TRANS_SINE)

	# Start loading the resource in background
	if not target_scene_path.is_empty():
		ResourceLoader.load_threaded_request(target_scene_path)
	else:
		# Fallback if somehow empty
		push_error("LoadingScreen: No target scene path provided!")
		get_tree().create_timer(1.0).timeout.connect(func(): get_tree().change_scene_to_file("res://scenes/main_menu.tscn"))

func _process(_delta: float) -> void:
	var status = ResourceLoader.load_threaded_get_status(target_scene_path)
	
	if status == ResourceLoader.THREAD_LOAD_LOADED:
		var current_time = Time.get_ticks_msec() / 1000.0
		if current_time - _start_time >= _min_wait_time:
			# Scene is ready and we've waited long enough for the kid to see the icon
			var packed_scene = ResourceLoader.load_threaded_get(target_scene_path)
			get_tree().change_scene_to_packed(packed_scene)
	elif status == ResourceLoader.THREAD_LOAD_FAILED:
		push_error("LoadingScreen: Failed to load target scene: " + target_scene_path)
		get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
