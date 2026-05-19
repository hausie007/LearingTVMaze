## virtual_dpad.gd
## ---------------------------------------------------------------------------
## An on-screen virtual directional pad for mobile/touch devices.
## Programmatically constructs TouchScreenButtons for directional movement.
##
## Registered as Autoload singleton "DPad". Layout updates are signal-driven
## via Config.on_screen_controls_changed (no per-frame polling).
## ---------------------------------------------------------------------------
extends CanvasLayer

signal action_changed(action: StringName, pressed: bool)

const DEFAULT_PAD_COLOR: Color = Color(1.0, 1.0, 1.0, 0.25)
const DEFAULT_PAD_TEXT_COLOR: Color = Color.WHITE
const HAPTIC_DURATION_MS: int = 24
const HAPTIC_AMPLITUDE: float = 0.18

var dpad_container: Node2D
var back_button: TouchScreenButton
var _accent_palette: Dictionary = {}
var _alpha_tween: Tween = null
var _last_build_viewport_size: Vector2 = Vector2.ZERO
var _last_build_controller_size: int = -1
var _controls_reversed_visual: bool = false

func set_accent_palette(palette: Dictionary) -> void:
	_accent_palette = palette.duplicate(true)
	_apply_dpad_style()

func reset_accent_palette() -> void:
	_accent_palette.clear()
	_apply_dpad_style()

func set_controls_reversed_visual(enabled: bool) -> void:
	_controls_reversed_visual = enabled
	_apply_direction_icons()


## Dim the D-pad to reduce OLED burn-in during idle periods.
func dim(target_alpha: float = 0.1, duration: float = 2.0) -> void:
	if dpad_container == null:
		return
	if _alpha_tween and _alpha_tween.is_valid():
		_alpha_tween.kill()
	_alpha_tween = create_tween()
	_alpha_tween.tween_property(dpad_container, "modulate:a", target_alpha, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


## Restore the D-pad to full opacity.
func undim(duration: float = 0.25) -> void:
	if dpad_container == null:
		return
	if _alpha_tween and _alpha_tween.is_valid():
		_alpha_tween.kill()
	_alpha_tween = create_tween()
	_alpha_tween.tween_property(dpad_container, "modulate:a", 1.0, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

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
		Config.controller_size_changed.connect(_update_visibility_and_layout.unbind(1))

func _rebuild_dpad(viewport_size: Vector2) -> void:
	for child in dpad_container.get_children():
		child.queue_free()
		
	# Scale up to use almost all of the reserved controller zone.
	var quarter_screen: float = viewport_size.x * UIHelpers.get_dpad_screen_fraction()
	# D-pad needs to fit 3 buttons width-wise (Left, OK, Right) + 2 spacings
	var btn_size_val: int = floori(quarter_screen / 3.5) 
	var btn_size: Vector2 = Vector2(btn_size_val, btn_size_val)
	var spacing: int = floori(btn_size_val * 0.2)
	var center_gap: float = btn_size.x + float(spacing)
	
	# Helper to create a button
	var make_btn: Callable = func(action: String, localized_pos: Vector2, icon_text: String = "", scale_font: float = 1.0) -> TouchScreenButton:
		var btn: TouchScreenButton = TouchScreenButton.new()
		btn.action = action
		btn.passby_press = true
		var action_name: StringName = StringName(action)
		btn.pressed.connect(func():
			_trigger_haptic_for_action(action_name)
			undim()
			action_changed.emit(action_name, true)
		)
		btn.released.connect(func(): action_changed.emit(action_name, false))
		
		# For clickability without a texture, a shape is required
		var shape: RectangleShape2D = RectangleShape2D.new()
		shape.size = btn_size
		btn.shape = shape
		
		btn.position = localized_pos
		
		# Visual placeholder
		var visual: ColorRect = ColorRect.new()
		visual.name = "Visual"
		visual.color = Color(1.0, 1.0, 1.0, 0.25)
		visual.size = btn_size
		# align to shape center
		visual.position = -btn_size / 2.0
		visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn.add_child(visual)
		
		if icon_text != "":
			var label: Label = Label.new()
			label.name = "IconLabel"
			label.text = icon_text
			label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			label.set_anchors_preset(Control.PRESET_FULL_RECT)
			label.add_theme_font_size_override("font_size", int((btn_size_val * 0.4) * scale_font))
			visual.add_child(label)
		
		dpad_container.add_child(btn)
		return btn
	
	# Directional Buttons Layout (relative positions around a center)
	var up_pos: Vector2 = Vector2(0, -center_gap)
	var down_pos: Vector2 = Vector2(0, center_gap)
	var left_pos: Vector2 = Vector2(-center_gap, 0)
	var right_pos: Vector2 = Vector2(center_gap, 0)
	
	var _up: TouchScreenButton = make_btn.call("ui_up", up_pos, "↑") as TouchScreenButton
	var _down: TouchScreenButton = make_btn.call("ui_down", down_pos, "↓") as TouchScreenButton
	var _left: TouchScreenButton = make_btn.call("ui_left", left_pos, "←") as TouchScreenButton
	var _right: TouchScreenButton = make_btn.call("ui_right", right_pos, "→") as TouchScreenButton
	var _ok: TouchScreenButton = make_btn.call("ui_accept", Vector2.ZERO, "OK", 0.8) as TouchScreenButton
	
	if _ok != null:
		_ok.passby_press = false
	
	back_button = make_btn.call("ui_cancel", Vector2(0, -center_gap * 2.0), "↰") as TouchScreenButton
	if back_button != null:
		back_button.passby_press = false
	_last_build_viewport_size = viewport_size
	_last_build_controller_size = Config.controller_size if is_instance_valid(Config) else -1
	_apply_direction_icons()
	_apply_dpad_style()


func _update_visibility_and_layout() -> void:
	if not is_instance_valid(Config):
		return
		
	var controls_mode: int = 0 # Default Off
	if "on_screen_controls" in Config:
		controls_mode = Config.on_screen_controls
	
	if controls_mode == Config.ControlsMode.OFF:
		visible = false
		return
		
	visible = true
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	var controller_size: int = Config.controller_size if is_instance_valid(Config) else 0
	
	if dpad_container.get_child_count() == 0 or viewport_size != _last_build_viewport_size or controller_size != _last_build_controller_size:
		_rebuild_dpad(viewport_size)
	
	var quarter_screen: float = viewport_size.x * UIHelpers.get_dpad_screen_fraction()
	var center_x: float = quarter_screen / 2.0
	
	# D-Pad button size was calculated as quarter_screen / 3.5. 
	# The lowest point is the DOWN button which is center_gap (btn_size * 1.2) away from center.
	# Plus half a button height (btn_size * 0.5) = btn_size * 1.7.
	var btn_size: float = float(quarter_screen / 3.5)
	var dpad_bottom_offset: float = btn_size * 1.7
	
	var base_margin_y: float = viewport_size.y - dpad_bottom_offset - 40.0
	
	if controls_mode == Config.ControlsMode.LEFT_HANDED:
		dpad_container.position = Vector2(center_x, base_margin_y)
	elif controls_mode == Config.ControlsMode.RIGHT_HANDED:
		dpad_container.position = Vector2(viewport_size.x - center_x, base_margin_y)

func _apply_dpad_style() -> void:
	if dpad_container == null:
		return

	var fill_color: Color = DEFAULT_PAD_COLOR
	var text_color: Color = DEFAULT_PAD_TEXT_COLOR
	if not _accent_palette.is_empty():
		var accent: Color = _palette_color("accent", UIColors.BLUE)
		var shell: Color = _palette_color("shell", UIColors.BG_DARK.lerp(accent, 0.18))
		fill_color = shell.lerp(accent, 0.36)
		fill_color.a = 0.72
		text_color = _palette_color("text", UIColors.TEXT_PRIMARY)

	for child in dpad_container.get_children():
		var button: Node = child as Node
		if button == null:
			continue
		var visual: ColorRect = button.get_node_or_null("Visual") as ColorRect
		if visual != null:
			visual.color = fill_color
			var label: Label = visual.get_node_or_null("IconLabel") as Label
			if label != null:
				label.add_theme_color_override("font_color", text_color)

func _apply_direction_icons() -> void:
	if dpad_container == null:
		return
	for child in dpad_container.get_children():
		var button := child as TouchScreenButton
		if button == null:
			continue
		var visual := button.get_node_or_null("Visual") as ColorRect
		if visual == null:
			continue
		var label := visual.get_node_or_null("IconLabel") as Label
		if label == null:
			continue
		match StringName(button.action):
			&"ui_up":
				label.text = "↓" if _controls_reversed_visual else "↑"
			&"ui_down":
				label.text = "↑" if _controls_reversed_visual else "↓"
			&"ui_left":
				label.text = "→" if _controls_reversed_visual else "←"
			&"ui_right":
				label.text = "←" if _controls_reversed_visual else "→"

func _palette_color(key: String, fallback: Color) -> Color:
	var value: Variant = _accent_palette.get(key, fallback)
	if value is Color:
		return value
	return fallback

func _trigger_haptic_for_action(action: StringName) -> void:
	match action:
		&"ui_up", &"ui_down", &"ui_left", &"ui_right":
			Input.vibrate_handheld(HAPTIC_DURATION_MS, HAPTIC_AMPLITUDE)
