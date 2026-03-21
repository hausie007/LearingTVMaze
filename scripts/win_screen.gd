## win_screen.gd
## ---------------------------------------------------------------------------
## Overlay UI for both the "You Win!" screen and "Gotcha!" (chaser caught)
## screen.  Handles button creation, mode suggestions, and auto-countdown.
##
## Emits signals so GameManager can respond without tight coupling.
## ---------------------------------------------------------------------------
class_name WinScreen
extends CanvasLayer


# ── Signals ──────────────────────────────────────────────────────────────────

signal next_round_pressed
signal harder_pressed
signal home_pressed
signal suggestion_pressed(target_mode: int)


# ── UI References ────────────────────────────────────────────────────────────

var _container: Control = null
var _win_label: Label = null
var _score_label: Label = null
var _next_button: Button = null
var _harder_button: Button = null
var _timer_label: Label = null
var _suggestion_container: VBoxContainer = null

## Countdown state.
var _timer_remaining: float = 0.0
var _timer_paused: bool = false
var _is_active: bool = false


# ── Lifecycle ────────────────────────────────────────────────────────────────

func _ready() -> void:
	layer = 10
	_build_ui()


func _process(delta: float) -> void:
	if _is_active and not _timer_paused and _timer_remaining > 0.0:
		_timer_remaining -= delta
		if _timer_label:
			_timer_label.text = str(ceili(_timer_remaining))
		if _timer_remaining <= 0.0:
			next_round_pressed.emit()


func _input(event: InputEvent) -> void:
	# Any D-pad interaction during the active screen pauses the auto-countdown.
	if _is_active and not _timer_paused:
		if event.is_action_pressed("ui_up") or event.is_action_pressed("ui_down") or \
		   event.is_action_pressed("ui_left") or event.is_action_pressed("ui_right") or \
		   event.is_action_pressed("ui_accept"):
			_timer_paused = true
			if _timer_label:
				_timer_label.text = ""


# ── Public API ───────────────────────────────────────────────────────────────

## Check if the win/gotcha screen is currently visible.
func is_active() -> bool:
	return _is_active


## Show the "You Win!" screen with score info.
func show_win(time_str: String, move_count: int) -> void:
	_is_active = true
	_timer_remaining = 10.0
	_timer_paused = false

	_win_label.text = tr("you_win")
	_score_label.text = tr("score_time") % time_str + " | " + tr("score_steps") % move_count
	_next_button.text = tr("next_round")

	if _harder_button:
		_harder_button.visible = Config.difficulty < 4
		_harder_button.text = tr("challenge_pp")

	_container.visible = true
	_next_button.grab_focus()


## Show the "Gotcha!" screen when the chaser catches the player.
func show_gotcha() -> void:
	_is_active = true
	_timer_remaining = 0.0  # No auto-advance on gotcha
	_timer_paused = true

	_win_label.text = tr("gotcha")
	_score_label.text = tr("try_again_desc")
	_next_button.text = tr("try_again")

	# Show "Easier" if possible (button handler checks text to decide direction)
	if _harder_button:
		_harder_button.visible = Config.difficulty > 0
		_harder_button.text = tr("challenge_mm")

	_container.visible = true
	_next_button.grab_focus()


## Update mode suggestions on the win screen.
func update_suggestions(current_mode: int) -> void:
	for child in _suggestion_container.get_children():
		child.queue_free()

	var suggestion_modes: Array[int] = []
	match current_mode:
		1: suggestion_modes = [2, 3]
		2: suggestion_modes = [1, 3]
		3: suggestion_modes = [1, 2]
		_: suggestion_modes = [1, 2, 3]

	for m in suggestion_modes:
		var key: String = ""
		match m:
			1: key = "try_numbers"
			2: key = "try_alphabet"
			3: key = "try_words"

		if not key.is_empty():
			var hbox := HBoxContainer.new()
			hbox.alignment = BoxContainer.ALIGNMENT_CENTER
			_suggestion_container.add_child(hbox)

			var btn: Button = _create_styled_button(tr(key), 650, 100, Color(0.4, 0.6, 0.9))
			btn.pressed.connect(func(): suggestion_pressed.emit(m))
			hbox.add_child(btn)


## Hide the screen and reset state.
func hide_screen() -> void:
	_is_active = false
	if _container:
		_container.visible = false


# ── UI Construction ──────────────────────────────────────────────────────────

func _build_ui() -> void:
	_container = CenterContainer.new()
	_container.anchors_preset = Control.PRESET_FULL_RECT
	_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_container)

	var main_panel := PanelContainer.new()
	main_panel.anchors_preset = Control.PRESET_CENTER
	main_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_panel.custom_minimum_size.x = 800

	var main_style := StyleBoxFlat.new()
	main_style.bg_color = Color(0.15, 0.17, 0.22, 0.95)
	main_style.corner_radius_top_left = 32
	main_style.corner_radius_top_right = 32
	main_style.corner_radius_bottom_right = 32
	main_style.corner_radius_bottom_left = 32
	main_style.border_width_left = 4
	main_style.border_width_top = 4
	main_style.border_width_right = 4
	main_style.border_width_bottom = 4
	main_style.border_color = Color("#1188FF")
	main_style.content_margin_left = 60
	main_style.content_margin_right = 60
	main_style.content_margin_top = 40
	main_style.content_margin_bottom = 40
	main_panel.add_theme_stylebox_override("panel", main_style)
	_container.add_child(main_panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 30)
	main_panel.add_child(vbox)

	# Header
	_win_label = Label.new()
	_win_label.text = tr("you_win")
	_win_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_win_label.add_theme_font_size_override("font_size", 90)
	_win_label.add_theme_color_override("font_color", Color("#FFCC00"))
	vbox.add_child(_win_label)

	_score_label = Label.new()
	_score_label.text = ""
	_score_label.add_theme_font_size_override("font_size", 40)
	_score_label.add_theme_color_override("font_color", Color(0.8, 0.82, 0.85))
	_score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_score_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(_score_label)

	var button_vbox := VBoxContainer.new()
	button_vbox.add_theme_constant_override("separation", 20)
	vbox.add_child(button_vbox)

	# Next Round + Timer
	var next_hbox := HBoxContainer.new()
	next_hbox.add_theme_constant_override("separation", 20)
	next_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	button_vbox.add_child(next_hbox)

	var next_spacer_l := Control.new()
	next_spacer_l.custom_minimum_size.x = 80
	next_hbox.add_child(next_spacer_l)

	_next_button = _create_styled_button(tr("next_round"), 650, 100)
	_next_button.pressed.connect(func(): next_round_pressed.emit())
	next_hbox.add_child(_next_button)

	_timer_label = Label.new()
	_timer_label.text = "10"
	_timer_label.custom_minimum_size.x = 80
	_timer_label.add_theme_font_size_override("font_size", 36)
	_timer_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	_timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_timer_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	next_hbox.add_child(_timer_label)

	# Harder / Easier
	var harder_hbox := HBoxContainer.new()
	harder_hbox.add_theme_constant_override("separation", 20)
	harder_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	button_vbox.add_child(harder_hbox)

	var h_spacer_l := Control.new()
	h_spacer_l.custom_minimum_size.x = 80
	harder_hbox.add_child(h_spacer_l)

	_harder_button = _create_styled_button(tr("challenge_pp"), 650, 100, Color("#FFCC00"))
	_harder_button.pressed.connect(func(): harder_pressed.emit())
	harder_hbox.add_child(_harder_button)

	var h_spacer_r := Control.new()
	h_spacer_r.custom_minimum_size.x = 80
	harder_hbox.add_child(h_spacer_r)

	# Mode Suggestions
	_suggestion_container = VBoxContainer.new()
	_suggestion_container.add_theme_constant_override("separation", 20)
	button_vbox.add_child(_suggestion_container)

	# Padding before Main Menu
	var padding := Control.new()
	padding.custom_minimum_size.y = 40
	button_vbox.add_child(padding)

	# Home Button
	var home_hbox := HBoxContainer.new()
	home_hbox.add_theme_constant_override("separation", 20)
	home_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	button_vbox.add_child(home_hbox)

	var home_spacer_l := Control.new()
	home_spacer_l.custom_minimum_size.x = 80
	home_hbox.add_child(home_spacer_l)

	var home_btn: Button = _create_styled_button(tr("main_menu"), 650, 100, Color("#1188FF"))
	home_btn.pressed.connect(func(): home_pressed.emit())
	home_hbox.add_child(home_btn)

	var home_spacer_r := Control.new()
	home_spacer_r.custom_minimum_size.x = 80
	home_hbox.add_child(home_spacer_r)

	_container.visible = false


# ── Shared Button Style ──────────────────────────────────────────────────────

func _create_styled_button(btn_text: String, w: int, h: int, f_color: Color = Color("#1188FF")) -> Button:
	return UIHelpers.create_styled_button(btn_text, w, h, f_color)

