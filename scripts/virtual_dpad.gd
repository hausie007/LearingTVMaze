## virtual_dpad.gd
## ---------------------------------------------------------------------------
## An on-screen virtual directional pad for mobile/touch devices.
## Programmatically constructs TouchScreenButtons for directional movement.
##
## Registered as Autoload singleton "DPad". Layout updates are signal-driven
## via Config.on_screen_controls_changed (no per-frame polling).
## ---------------------------------------------------------------------------
extends CanvasLayer

var dpad_container: Node2D
var back_button: TouchScreenButton

func _ready() -> void:
	# Configure layer to sit securely above the maze and pause menus (which use 100)
	layer = 150
	# Allow D-Pad to function even when the game tree is paused
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	dpad_container = Node2D.new()
	add_child(dpad_container)
	
	_update_visibility_and_layout()
	
	# React to controls mode changes instead of polling every frame
	if is_instance_valid(Config):
		Config.on_screen_controls_changed.connect(_update_visibility_and_layout.unbind(1))

func _rebuild_dpad(viewport_size: Vector2) -> void:
	for child in dpad_container.get_children():
		child.queue_free()
		
	# Scale up to use almost all of the 25% zone
	var quarter_screen = viewport_size.x * UIHelpers.DPAD_SCREEN_FRACTION
	# D-pad needs to fit 3 buttons width-wise (Left, OK, Right) + 2 spacings
	var btn_size_val = floori(quarter_screen / 3.5) 
	var btn_size = Vector2(btn_size_val, btn_size_val)
	var spacing = floori(btn_size_val * 0.2)
	var center_gap = btn_size.x + spacing
	
	# Helper to create a button
	var make_btn = func(action: String, localized_pos: Vector2, icon_text: String = "", scale_font: float = 1.0) -> TouchScreenButton:
		var btn = TouchScreenButton.new()
		btn.action = action
		btn.passby_press = true
		
		# For clickability without a texture, a shape is required
		var shape := RectangleShape2D.new()
		shape.size = btn_size
		btn.shape = shape
		
		btn.position = localized_pos
		
		# Visual placeholder
		var visual := ColorRect.new()
		visual.color = Color(1.0, 1.0, 1.0, 0.25)
		visual.size = btn_size
		# align to shape center
		visual.position = -btn_size / 2.0
		visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn.add_child(visual)
		
		if icon_text != "":
			var label := Label.new()
			label.text = icon_text
			label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			label.set_anchors_preset(Control.PRESET_FULL_RECT)
			label.add_theme_font_size_override("font_size", int((btn_size_val * 0.4) * scale_font))
			visual.add_child(label)
		
		dpad_container.add_child(btn)
		return btn
	
	# Directional Buttons Layout (relative positions around a center)
	var up_pos    := Vector2(0, -center_gap)
	var down_pos  := Vector2(0, center_gap)
	var left_pos  := Vector2(-center_gap, 0)
	var right_pos := Vector2(center_gap, 0)
	
	var _up    = make_btn.call("ui_up", up_pos, "↑")
	var _down  = make_btn.call("ui_down", down_pos, "↓")
	var _left  = make_btn.call("ui_left", left_pos, "←")
	var _right = make_btn.call("ui_right", right_pos, "→")
	var _ok    = make_btn.call("ui_accept", Vector2.ZERO, "OK", 0.8)
	
	_ok.passby_press = false
	
	back_button = make_btn.call("ui_cancel", Vector2(0, -center_gap * 2.5), "↰")
	back_button.passby_press = false


func _update_visibility_and_layout() -> void:
	if not is_instance_valid(Config):
		return
		
	var controls_mode = 0 # Default Off
	if "on_screen_controls" in Config:
		controls_mode = Config.on_screen_controls
	
	if controls_mode == Config.ControlsMode.OFF:
		visible = false
		return
		
	visible = true
	var viewport_size = get_viewport().get_visible_rect().size
	
	if dpad_container.get_child_count() == 0:
		_rebuild_dpad(viewport_size)
	
	var quarter_screen = viewport_size.x * UIHelpers.DPAD_SCREEN_FRACTION
	var center_x = quarter_screen / 2.0
	
	# D-Pad button size was calculated as quarter_screen / 3.5. 
	# The lowest point is the DOWN button which is center_gap (btn_size * 1.2) away from center.
	# Plus half a button height (btn_size * 0.5) = btn_size * 1.7.
	var btn_size = float(quarter_screen / 3.5)
	var dpad_bottom_offset = btn_size * 1.7
	
	var base_margin_y = viewport_size.y - dpad_bottom_offset - 40.0
	
	if controls_mode == Config.ControlsMode.LEFT_HANDED:
		dpad_container.position = Vector2(center_x, base_margin_y)
	elif controls_mode == Config.ControlsMode.RIGHT_HANDED:
		dpad_container.position = Vector2(viewport_size.x - center_x, base_margin_y)
