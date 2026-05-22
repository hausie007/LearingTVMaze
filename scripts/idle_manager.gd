## idle_manager.gd
## ---------------------------------------------------------------------------
## Global unified idle manager and OLED burn-in protection.
## Registered as Autoload singleton \"IdleManager\".
## ---------------------------------------------------------------------------
extends Node

signal idle_tier_1
signal idle_tier_2
signal idle_reset

var tier1_sec: float = 60.0
var tier2_sec: float = 300.0

var _elapsed: float = 0.0
var _tier1_fired: bool = false
var _tier2_fired: bool = false
var _dim_overlay: CanvasLayer = null
var _dim_rect: ColorRect = null
var _active: bool = true

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	# Create a persistent global full-screen dimming overlay
	_dim_overlay = CanvasLayer.new()
	_dim_overlay.layer = 128 # Renders on top of everything (settings, popups, DPad)
	add_child(_dim_overlay)
	
	_dim_rect = ColorRect.new()
	_dim_rect.color = Color(0, 0, 0, 0)
	_dim_rect.anchors_preset = Control.PRESET_FULL_RECT
	_dim_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 0)
	_dim_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dim_overlay.add_child(_dim_rect)
	
	apply_screensaver_settings()

func _process(delta: float) -> void:
	if not _active:
		return
	_elapsed += delta
	if not _tier1_fired and _elapsed >= tier1_sec:
		_tier1_fired = true
		_dim_screen(0.75, 4.0) # Dim to 75% black (25% opacity) over 4 seconds
		idle_tier_1.emit()
	if not _tier2_fired and _elapsed >= tier2_sec:
		_tier2_fired = true
		_dim_screen(0.95, 4.0) # Almost completely black
		idle_tier_2.emit()
		# Deep idle: reload current scene to reset any animations only if not reset/changed
		if _tier2_fired:
			get_tree().reload_current_scene()

func _input(event: InputEvent) -> void:
	if not _active:
		return
	# Check for deliberate interaction (keys, touch, remote, joystick)
	var is_deliberate: bool = (
		event is InputEventKey or
		event is InputEventJoypadButton or
		(event is InputEventMouseButton and event.pressed) or
		(event is InputEventScreenTouch and event.pressed) or
		(event is InputEventAction and event.pressed)
	)
	if is_deliberate:
		reset()

func reset() -> void:
	var was_fired := _tier1_fired or _tier2_fired
	_elapsed = 0.0
	_tier1_fired = false
	_tier2_fired = false
	if was_fired:
		_dim_screen(0.0, 0.3)
		idle_reset.emit()

func set_thresholds(t1: float, t2: float) -> void:
	tier1_sec = t1
	tier2_sec = t2
	reset()

func apply_screensaver_settings() -> void:
	var timeout: int = 300
	var config_node = get_node_or_null("/root/Config")
	if config_node != null and "screensaver_timeout" in config_node:
		timeout = config_node.screensaver_timeout
	
	if timeout == 0:
		_active = false
		reset()
	else:
		_active = true
		tier1_sec = float(timeout)
		tier2_sec = float(timeout) * 3.0
		reset()

func _dim_screen(target_alpha: float, duration: float) -> void:
	var tw := create_tween()
	tw.tween_property(_dim_rect, "color:a", target_alpha, duration)\
		.set_trans(Tween.TRANS_SINE)\
		.set_ease(Tween.EASE_IN_OUT)
